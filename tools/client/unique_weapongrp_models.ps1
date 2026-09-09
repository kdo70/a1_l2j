<#
.SYNOPSIS
	Cuts weapongrp.dat down to one row per weapon model - shields and monster weapons left out - so
	the enchant glow can be tuned once per look instead of once per item.

.DESCRIPTION
	weapongrp holds 2651 rows but only 537 distinct looks : the same mesh and texture pair is worn
	by dozens of items (every grade of a sword shape, every minted copy, every NPC drop). Tuning the
	glow means opening a weapon, looking at it and writing effA / the offset block by hand, and
	doing that 2651 times for 537 answers is the whole of the work.

	So this script keeps, of every group of rows that share a look, the one with the lowest id -
	usually the retail original - and drops the rest. The full table is kept as *.models.bak, and
	the groups are written to a .tsv, so that spread_weapongrp_glow.ps1 can put the glow you tuned
	on the survivor back onto every row of its group and rebuild the whole table.

	**What "the same look" means.** The key is the weapon meshes plus the weapon textures, compared
	case insensitively and in table order : wpn_mesh[0..1] and wpn_tex[0..2]. Texture alone would
	be very slightly coarser - two shapes in this table share a texture (the zombie labourer's axe
	and sword, the player and NPC fishing rods) and would have collapsed into one row, and one glow
	answer, between them. Rows that carry neither mesh nor texture (ids 244..252 and the four
	type 3 rows) have no look to group by and are each kept on their own.

	**Shields and monster weapons are left out** of the cut down table, because there is no glow to
	tune on them : 44 looks are shields, which have no effect name at all in this table, and 65 more
	are the weapons NPCs carry, which no player ever enchants. That is 109 looks out of 537, leaving
	428 to go through.

	  a shield          every row of the look has weapon_type 0 and body_part 8 - which in this
	                    table is exactly the 95 rows whose mesh ends in _sh, no more and no less.
	  a monster weapon  no row of the look is a player's : every one of them carries the retail
	                    icon.weapon_monster_i00, or a LineageWeapons.Mon_* mesh. A look worn by both
	                    stays (art_of_battle_axe is carried by players and by NPCs alike).

	They are still written to the .tsv, marked as what they are, so nothing is lost : the full table
	spread_weapongrp_glow.ps1 rebuilds carries them with the glow they already had, and -Restore
	brings them back into the cut down table without touching the glow tuned so far. -KeepShields
	and -KeepMonsters keep them in from the start.

	**The client after this runs is for tuning, not for playing.** Every item whose row was dropped
	has no model, no icon and no name left in the table ; that is the point, but do not log a live
	account into it and do not ship it. Run spread_weapongrp_glow.ps1 to get the full table back.

.PARAMETER SystemDir
	The "system" directory of the client.

.PARAMETER ToolsDir
	Directory holding l2encdec\ and l2asm-disasm\ (the "data" directory of L2 File Editor).

.PARAMETER Map
	Where the group table goes. Defaults to weapongrp_models.tsv next to this script, which is
	where spread_weapongrp_glow.ps1 looks for it.

.PARAMETER Backup
	The rollback copy of the full table. Defaults to weapongrp.dat.models.bak in SystemDir.
	spread_weapongrp_glow.ps1 reads it back.

.PARAMETER KeepShields
	Keep the shield looks in the cut down table.

.PARAMETER KeepMonsters
	Keep the monster weapon looks in the cut down table.

.PARAMETER Restore
	Put looks that were left out back into the cut down table as it stands, taking their rows from
	the backup, and leave every row already in it - and the glow tuned on it - alone. Shields,
	Monsters or All. Nothing else about the table is rebuilt, and the .tsv is not rewritten.

.PARAMETER Force
	Run the cut again on a client that is already cut down. The full table is taken from the backup,
	so the groups come out the same - but the glow you tuned in the cut down table is discarded.

.EXAMPLE
	.\unique_weapongrp_models.ps1 -SystemDir "C:\Users\Me\Desktop\1\system" `
	    -ToolsDir "C:\Users\Me\Desktop\L2_File_Editor_2a__C4_to_Freya__by_CriticalError\data"

.EXAMPLE
	# changed your mind halfway through tuning : shields come back, tuned rows stay tuned
	.\unique_weapongrp_models.ps1 -SystemDir "..." -ToolsDir "..." -Restore Shields
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)][string] $SystemDir,
	[Parameter(Mandatory = $true)][string] $ToolsDir,
	[string] $Map,
	[string] $Backup,
	[switch] $KeepShields,
	[switch] $KeepMonsters,
	[ValidateSet('Shields', 'Monsters', 'All')][string] $Restore,
	[switch] $Force
)

$ErrorActionPreference = 'Stop'

if (-not $Map) { $Map = Join-Path $PSScriptRoot 'weapongrp_models.tsv' }
if (-not $Backup) { $Backup = Join-Path $SystemDir 'weapongrp.dat.models.bak' }

$encdec = Join-Path $ToolsDir 'l2encdec\l2encdec.exe'
$disasm = Join-Path $ToolsDir 'l2asm-disasm\l2disasm.exe'
$asm = Join-Path $ToolsDir 'l2asm-disasm\l2asm.exe'
$ddfSrc = Join-Path $ToolsDir 'l2asm-disasm\DAT_defs\Interlude\weapongrp.ddf'
foreach ($p in $encdec, $disasm, $asm, $ddfSrc) { if (-not (Test-Path $p)) { throw "Missing $p." } }

$dat = Join-Path $SystemDir 'weapongrp.dat'
if (-not (Test-Path $dat)) { throw "Missing $dat." }

# The columns that make up a look. Order matters : it is the key, and it has to be built the same
# way here and in spread_weapongrp_glow.ps1.
$LOOK = @('wpn_mesh[0]', 'wpn_mesh[1]', 'wpn_tex[0]', 'wpn_tex[1]', 'wpn_tex[2]')

# What a shield is, and what a monster's weapon is. See the .DESCRIPTION.
$SHIELD_TYPE = '0'
$SHIELD_PART = '8'
$MONSTER_ICON = 'icon.weapon_monster_i00'
$MONSTER_MESH = '\.mon_'

$UTF8 = New-Object System.Text.UTF8Encoding $false
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("wgmodels_" + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $tmp

# One table in : decrypt, disassemble, and prove the ddf fits this client before anything is read
# off it. A round trip that isn't byte exact means every row we don't touch would silently ride
# along with the edit.
function Open-Table([string]$file, [string]$tag)
{
	$dec = Join-Path $tmp "$tag.dec"
	$txt = Join-Path $tmp "$tag.txt"
	$exp = Join-Path $tmp "$tag.ddf"
	$chk = Join-Path $tmp "$tag.check"

	& $encdec -d $file $dec | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "Can't decrypt $file." }
	& $disasm -d $ddfSrc -e $exp $dec $txt | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "l2disasm failed on $file." }
	& $asm -d $exp $txt $chk | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "l2asm failed on $file." }
	if ((Get-FileHash $chk).Hash -ne (Get-FileHash $dec).Hash) { throw "$file : l2disasm/l2asm round trip isn't byte exact ; wrong ddf for this client ?" }

	$lines = [System.IO.File]::ReadAllLines($txt)
	$header = $lines[0].Split("`t")
	$byName = @{}
	for ($i = 0; $i -lt $header.Count; $i++) { $byName[$header[$i]] = $i }
	# Only the id is demanded. The rest of the table is arrays whose length l2disasm takes from the
	# data - the cut down table has no wpn_tex[2] column at all, because the one weapon that wore
	# three textures was a shield and went - so a missing column is normal, not a broken ddf. That
	# the ddf fits is what the byte exact round trip above says.
	if (-not $byName.ContainsKey('id')) { throw "$file has no id column ; wrong ddf ?" }

	[pscustomobject]@{ Lines = $lines ; Col = $byName ; Header = $header ; Ddf = $exp }
}

# Two dumps of this table need not have the same columns, so a row of one cannot be dropped into
# the other by index : it is put back together by column name, and a column the target hasn't got
# is left behind - it is an array slot no row of the target fills anyway.
function ConvertTo-Layout($cells, $fromCol, $to)
{
	$outCells = New-Object string[] $to.Header.Count
	for ($i = 0; $i -lt $outCells.Count; $i++) { $outCells[$i] = '' }
	foreach ($name in $fromCol.Keys)
	{
		if ($to.Col.ContainsKey($name)) { $outCells[$to.Col[$name]] = $cells[$fromCol[$name]] }
		elseif ($cells[$fromCol[$name]]) { Write-Warning "column $name holds '$($cells[$fromCol[$name]])' but the full table has no such column ; dropped." }
	}
	$outCells -join "`t"
}

# One table out : reassemble, encrypt, and check it decrypts back to what was built.
function Save-Table($rows, $ddf)
{
	$txt = Join-Path $tmp 'out.txt'
	$new = Join-Path $tmp 'out.new'
	$enc = Join-Path $tmp 'out.enc'
	$back = Join-Path $tmp 'out.back'

	[System.IO.File]::WriteAllText($txt, (($rows -join "`n") + "`n"), $UTF8)
	& $asm -d $ddf $txt $new | Out-Null
	if ($LASTEXITCODE -ne 0) { throw 'l2asm failed to rebuild weapongrp.' }
	& $encdec -e 413 $new $enc | Out-Null
	if ($LASTEXITCODE -ne 0) { throw 'l2encdec failed to encrypt weapongrp.' }
	& $encdec -d $enc $back | Out-Null
	if ($LASTEXITCODE -ne 0 -or (Get-FileHash $back).Hash -ne (Get-FileHash $new).Hash) { throw "weapongrp doesn't decrypt back to what was built." }
	$enc
}

function Get-Look($cells, $byName)
{
	$parts = @()
	foreach ($n in $LOOK) { if ($byName.ContainsKey($n) -and $cells[$byName[$n]]) { $parts += $cells[$byName[$n]].ToLowerInvariant() } }
	# No mesh and no texture : nothing to look at, nothing to group by. Such a row stands alone, so
	# that the handful of them keep the glow they carry instead of all taking the glow of whichever
	# one happened to have the lowest id.
	if ($parts.Count -eq 0) { return "id:$($cells[$byName['id']])" }
	$parts -join '|'
}

try
{
	# =======================================================================
	# -Restore : put looks that were left out back, and leave everything that
	# is already in the table - glow and all - alone.
	# =======================================================================
	if ($Restore)
	{
		foreach ($p in $Backup, $Map) { if (-not (Test-Path $p)) { throw "Missing $p ; there is nothing to restore from. Run the cut first." } }

		$wanted = @{}
		if ($Restore -eq 'Shields' -or $Restore -eq 'All') { $wanted['shield'] = $true }
		if ($Restore -eq 'Monsters' -or $Restore -eq 'All') { $wanted['monster'] = $true }

		$cut = Open-Table $dat 'cut'
		$full = Open-Table $Backup 'full'

		# Into the layout of the full table, since that is what the rebuilt file is written in.
		$have = @{}
		for ($i = 1; $i -lt $cut.Lines.Count; $i++)
		{
			$cells = $cut.Lines[$i].Split("`t")
			$have[$cells[$cut.Col['id']]] = ConvertTo-Layout $cells $cut.Col $full
		}

		# rep id -> kind, off the map.
		$kindOf = @{}
		foreach ($line in [System.IO.File]::ReadAllLines($Map))
		{
			if ($line -eq '' -or $line.StartsWith('#')) { continue }
			$f = $line.Split("`t")
			$kindOf[$f[0]] = if ($f.Count -ge 4) { $f[3] } else { 'weapon' }
		}

		# Walked in the order of the full table, so the rows that come back land where they belong
		# rather than at the end.
		$out = [System.Collections.Generic.List[string]]::new()
		$null = $out.Add($full.Lines[0])
		$added = 0
		for ($i = 1; $i -lt $full.Lines.Count; $i++)
		{
			$id = $full.Lines[$i].Split("`t")[$full.Col['id']]
			if ($have.ContainsKey($id)) { $null = $out.Add($have[$id]) ; continue }
			if ($kindOf.ContainsKey($id) -and $wanted.ContainsKey($kindOf[$id])) { $null = $out.Add($full.Lines[$i]) ; $added++ }
		}

		if ($out.Count - 1 -ne $have.Count + $added) { throw "Restore lost rows : $($have.Count) were in the table, $added came back, $($out.Count - 1) written." }

		Copy-Item (Save-Table $out $full.Ddf) $dat -Force
		Write-Host "weapongrp : $added look(s) restored ($Restore), $($out.Count - 1) rows now ; the glow already tuned was left alone."
		return
	}

	# =======================================================================
	# The cut.
	# =======================================================================
	$source = $dat
	if (Test-Path $Backup)
	{
		if (-not $Force)
		{
			throw ("$Backup already exists, so this client is already cut down to one row per model. " +
				"Run spread_weapongrp_glow.ps1 to put the glow back on the full table, -Restore to bring " +
				"shields or monster weapons back into the cut down one, or -Force to start over from the " +
				"backup and throw away the glow tuned since.")
		}
		$source = $Backup
		Write-Host "-Force : the full table is taken from $Backup."
	}

	$full = Open-Table $source 'full'
	$rows = $full.Lines
	$byName = $full.Col
	$idC = $byName['id']
	# Unlike the id these are only needed for the cut, to tell a shield and a monster's weapon from
	# a weapon - and a table that hasn't got them is not one this script can sort.
	foreach ($need in 'weapon_type', 'body_part', 'icon[0]', 'wpn_mesh[0]')
	{
		if (-not $byName.ContainsKey($need)) { throw "$source has no $need column ; wrong ddf ?" }
	}

	# -----------------------------------------------------------------------
	# One group per look, and what kind of thing wears it.
	# -----------------------------------------------------------------------
	# Ordered, so that the .tsv comes out in the order the table is in rather than in whatever order
	# a hashtable feels like - a diff of two runs should be readable.
	$groups = [ordered]@{}

	for ($i = 1; $i -lt $rows.Count; $i++)
	{
		$cells = $rows[$i].Split("`t")
		if ($cells.Count -le $idC) { continue }
		$id = 0
		if (-not [int]::TryParse($cells[$idC], [ref]$id)) { continue }

		$key = Get-Look $cells $byName
		if (-not $groups.Contains($key))
		{
			$groups[$key] = [pscustomobject]@{
				Key       = $key
				RepRow    = $i
				RepId     = $id
				Members   = [System.Collections.Generic.List[int]]::new()
				Shields   = 0
				Monsters  = 0
				Rows      = 0
			}
		}
		$g = $groups[$key]
		$null = $g.Members.Add($id)
		$g.Rows++
		if ($cells[$byName['weapon_type']] -eq $SHIELD_TYPE -and $cells[$byName['body_part']] -eq $SHIELD_PART) { $g.Shields++ }
		if ($cells[$byName['icon[0]']] -eq $MONSTER_ICON -or $cells[$byName['wpn_mesh[0]']] -match $MONSTER_MESH) { $g.Monsters++ }

		# The lowest id of a group is, in this table, the retail original - the one that is easiest
		# to get hold of in game to look at.
		if ($id -lt $g.RepId) { $g.RepId = $id ; $g.RepRow = $i }
	}

	# A look is a shield, or a monster's, only if *every* row wearing it is : one carried by players
	# and NPCs alike (art_of_battle_axe) is a weapon like any other and has to be tuned.
	$kinds = @{}
	foreach ($g in $groups.Values)
	{
		$kinds[$g.Key] =
			if ($g.Shields -eq $g.Rows) { 'shield' }
			elseif ($g.Monsters -eq $g.Rows) { 'monster' }
			else { 'weapon' }
	}

	$drop = @{}
	if (-not $KeepShields) { $drop['shield'] = $true }
	if (-not $KeepMonsters) { $drop['monster'] = $true }

	# -----------------------------------------------------------------------
	# Cut down table out, in the order the full table is in.
	# -----------------------------------------------------------------------
	$keep = @{}
	foreach ($g in $groups.Values) { if (-not $drop.ContainsKey($kinds[$g.Key])) { $keep[$g.RepRow] = $true } }

	$out = [System.Collections.Generic.List[string]]::new()
	$null = $out.Add($rows[0])
	for ($i = 1; $i -lt $rows.Count; $i++) { if ($keep.ContainsKey($i)) { $null = $out.Add($rows[$i]) } }

	$enc = Save-Table $out $full.Ddf
	if (-not (Test-Path $Backup)) { Copy-Item $dat $Backup }
	Copy-Item $enc $dat -Force

	# -----------------------------------------------------------------------
	# The groups, so the glow can find its way back - the dropped ones too.
	# -----------------------------------------------------------------------
	$mapLines = [System.Collections.Generic.List[string]]::new()
	$null = $mapLines.Add("# weapongrp models, made by unique_weapongrp_models.ps1 from $source")
	$null = $mapLines.Add("# $($rows.Count - 1) rows -> $($groups.Count) looks, $($out.Count - 1) of them in the cut down table. Backup of the full table : $Backup")
	$null = $mapLines.Add("# rep_id`tmembers`tlook`tkind")
	foreach ($g in $groups.Values)
	{
		$members = ($g.Members | Sort-Object) -join ','
		$null = $mapLines.Add("$($g.RepId)`t$members`t$($g.Key)`t$($kinds[$g.Key])")
	}
	[System.IO.File]::WriteAllLines($Map, $mapLines, $UTF8)

	$nShield = @($kinds.Values | Where-Object { $_ -eq 'shield' }).Count
	$nMonster = @($kinds.Values | Where-Object { $_ -eq 'monster' }).Count
	Write-Host "weapongrp : $($rows.Count - 1) rows -> $($groups.Count) looks, $($out.Count - 1) kept (rollback copy $Backup)"
	Write-Host "  left out : $(if ($KeepShields) { 0 } else { $nShield }) shield look(s), $(if ($KeepMonsters) { 0 } else { $nMonster }) monster weapon look(s) - marked in the .tsv, brought back with -Restore"
	Write-Host "groups     -> $Map"
	foreach ($g in ($groups.Values | Where-Object { -not $drop.ContainsKey($kinds[$_.Key]) } | Sort-Object { -$_.Rows } | Select-Object -First 3))
	{
		Write-Host "  largest : id $($g.RepId) stands for $($g.Rows) rows ($($g.Key))"
	}
}
finally
{
	Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
