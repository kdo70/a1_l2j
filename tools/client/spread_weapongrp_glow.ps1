<#
.SYNOPSIS
	Rebuilds the full weapongrp.dat out of *.models.bak, putting the enchant glow you tuned on each
	surviving model onto every weapon that shares that model.

.DESCRIPTION
	The other half of unique_weapongrp_models.ps1. That one cut the table down to one row per look
	and wrote the groups to weapongrp_models.tsv ; you then tuned the glow on those rows. This one
	reads the tuned rows out of the cut down weapongrp.dat, takes the full table out of the backup,
	and copies the glow of each group's surviving row onto every id the group holds - the original
	included. What comes out is the whole table again, every item back with its own mesh, icon,
	P. Atk. and name, and the glow you picked for its shape.

	**What "the glow" is.** effA / effB - the EnchantGlow effect the client spawns on an enchanted
	weapon, one per mesh - and the ten floats of the offset block, junk1A[0..4] then junk1B[0..4],
	which are where on the weapon it sits and how big it is. That is exactly what tune_glow_keys.ps1
	and restore_glow_offsets.ps1 write, and nothing else is touched : grade, damage, shot counts,
	names and meshes all come back out of the backup as they were. -IncludeMesh adds the retail
	aura block (rangeA / rangeB and junk2A / junk2B) if you tuned that too.

	**Shields and monster weapons.** unique_weapongrp_models.ps1 leaves those out of the cut down
	table - there is nothing to tune on them - but keeps them in the map, marked as what they are.
	Their rows come back out of the backup with the glow they already had, and no warning : a look
	marked `shield` or `monster` with no row in weapongrp.dat is the normal case, not a loss. If you
	brought them back with -Restore and tuned them after all, they are spread like any other look.

	**Run it on the cut down table, not on the one it wrote.** Run again on a full table and every
	group is levelled on its own lowest id all over again : harmless for the weapons, which already
	carry that glow, but the shields and the monster weapons - which were never tuned and were left
	alone the first time - would be levelled on theirs too. It says so when it notices the table is
	full sized. Cut it down again first, or restore from *.models.bak.

.PARAMETER SystemDir
	The "system" directory of the client.

.PARAMETER ToolsDir
	Directory holding l2encdec\ and l2asm-disasm\ (the "data" directory of L2 File Editor).

.PARAMETER Map
	The group table unique_weapongrp_models.ps1 wrote. Defaults to weapongrp_models.tsv next to
	this script.

.PARAMETER Backup
	The full table unique_weapongrp_models.ps1 kept. Defaults to weapongrp.dat.models.bak in
	SystemDir. It is not deleted or overwritten, so the whole thing can be redone.

.PARAMETER IncludeMesh
	Carry the retail enchant aura across as well : rangeA / rangeB and junk2A[0..5] / junk2B[0..5].
	Off by default - this build draws EnchantGlow instead of that mesh, and every row of the table
	already has it cleared.

.EXAMPLE
	.\spread_weapongrp_glow.ps1 -SystemDir "C:\Users\Me\Desktop\1\system" `
	    -ToolsDir "C:\Users\Me\Desktop\L2_File_Editor_2a__C4_to_Freya__by_CriticalError\data"
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)][string] $SystemDir,
	[Parameter(Mandatory = $true)][string] $ToolsDir,
	[string] $Map,
	[string] $Backup,
	[switch] $IncludeMesh
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
foreach ($p in $dat, $Backup, $Map) { if (-not (Test-Path $p)) { throw "Missing $p." } }

# The look, built exactly as unique_weapongrp_models.ps1 builds it - it is the key of the .tsv, and
# checking it is the one thing that says the tuned table and the map still agree.
$LOOK = @('wpn_mesh[0]', 'wpn_mesh[1]', 'wpn_tex[0]', 'wpn_tex[1]', 'wpn_tex[2]')

# The effect names, one per mesh, and the ten floats of the offset block. junk1A and junk1B are one
# array of ten, not two of five - see restore_glow_offsets.ps1.
$GLOW = @('effA', 'effB',
	'junk1A[0]', 'junk1A[1]', 'junk1A[2]', 'junk1A[3]', 'junk1A[4]',
	'junk1B[0]', 'junk1B[1]', 'junk1B[2]', 'junk1B[3]', 'junk1B[4]')
if ($IncludeMesh)
{
	$GLOW += @('rangeA', 'rangeB',
		'junk2A[0]', 'junk2A[1]', 'junk2A[2]', 'junk2A[3]', 'junk2A[4]', 'junk2A[5]',
		'junk2B[0]', 'junk2B[1]', 'junk2B[2]', 'junk2B[3]', 'junk2B[4]', 'junk2B[5]')
}

$UTF8 = New-Object System.Text.UTF8Encoding $false
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("wgspread_" + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $tmp

# One table in : decrypt, disassemble, and prove the ddf fits this client before anything is read
# off it.
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
	$col = @{}
	for ($i = 0; $i -lt $header.Count; $i++) { $col[$header[$i]] = $i }
	# Only the id is demanded. Most of this table is arrays whose length l2disasm takes from the
	# data, so two dumps need not have the same columns : the cut down table has no wpn_tex[2] at
	# all, because the one weapon that wore three textures was a shield and was left out. That the
	# ddf fits is what the byte exact round trip above says, not the column list.
	if (-not $col.ContainsKey('id')) { throw "$file has no id column ; wrong ddf ?" }

	[pscustomobject]@{ Lines = $lines ; Col = $col ; Header = $header ; Ddf = $exp ; Txt = $txt }
}

function Get-Look($cells, $col)
{
	$parts = @()
	foreach ($c in $LOOK) { if ($col.ContainsKey($c) -and $cells[$col[$c]]) { $parts += $cells[$col[$c]].ToLowerInvariant() } }
	if ($parts.Count -eq 0) { return "id:$($cells[$col['id']])" }
	$parts -join '|'
}

try
{
	# -----------------------------------------------------------------------
	# The tuned rows, and the full table they go back onto.
	# -----------------------------------------------------------------------
	$tuned = Open-Table $dat 'tuned'
	$full = Open-Table $Backup 'full'

	if ($tuned.Lines.Count -ge $full.Lines.Count)
	{
		Write-Warning ("weapongrp.dat holds $($tuned.Lines.Count - 1) rows and the backup $($full.Lines.Count - 1) ; " +
			"this looks like the full table already. Running on anyway - it only copies each group's glow onto its own members.")
	}

	# The glow columns the two tables have in common. One of them missing on the tuned side means
	# no row of it fills that array slot - a table with no two mesh weapon left in it has no effB
	# column - so there is nothing there to carry across, and the full table keeps what it had.
	$carry = @($GLOW | Where-Object { $tuned.Col.ContainsKey($_) -and $full.Col.ContainsKey($_) })
	foreach ($c in $GLOW)
	{
		if ($full.Col.ContainsKey($c) -and -not $tuned.Col.ContainsKey($c)) { Write-Warning "weapongrp.dat has no $c column ; the backup's own values stay in that column." }
	}
	if ($carry.Count -eq 0) { throw "weapongrp.dat and the backup share none of the glow columns ; nothing to spread." }

	# id -> row, in the tuned table.
	$tunedById = @{}
	for ($i = 1; $i -lt $tuned.Lines.Count; $i++)
	{
		$cells = $tuned.Lines[$i].Split("`t")
		$tunedById[$cells[$tuned.Col['id']]] = $cells
	}

	# id -> row index, in the full table. The rows themselves are edited in place below.
	$fullRows = [System.Collections.Generic.List[string]]::new()
	foreach ($l in $full.Lines) { $null = $fullRows.Add($l) }
	$fullById = @{}
	for ($i = 1; $i -lt $fullRows.Count; $i++)
	{
		$cells = $fullRows[$i].Split("`t")
		$fullById[$cells[$full.Col['id']]] = $i
	}

	# -----------------------------------------------------------------------
	# Group by group, off the map.
	# -----------------------------------------------------------------------
	$touched = 0 ; $changed = 0 ; $groups = 0 ; $missing = 0 ; $drifted = 0 ; $lost = 0 ; $asIs = 0

	foreach ($line in [System.IO.File]::ReadAllLines($Map))
	{
		if ($line -eq '' -or $line.StartsWith('#')) { continue }
		$f = $line.Split("`t")
		if ($f.Count -lt 3) { throw "Can't read this line of $Map : $line" }
		# Not $look : PowerShell variable names are case insensitive, and that would quietly
		# overwrite the $LOOK the key is built out of.
		$repId = $f[0] ; $members = $f[1].Split(',') ; $wantLook = $f[2]
		# A map written before the shields and the monster weapons were sorted out has three
		# columns, and everything in it is a weapon.
		$kind = if ($f.Count -ge 4) { $f[3] } else { 'weapon' }
		$groups++

		$rep = $tunedById[$repId]
		if (-not $rep)
		{
			# A shield or a monster's weapon was never in the cut down table to be tuned - that is
			# what unique_weapongrp_models.ps1 left out, not something that went missing. Its rows
			# come out of the backup with the glow they already had, which is the whole point of
			# keeping them in the map.
			if ($kind -ne 'weapon') { $asIs++ ; continue }
			Write-Warning "id $repId is in $Map but not in weapongrp.dat ; its $($members.Count) row(s) keep the glow they have."
			$missing++
			continue
		}

		# The row that answers for the group has to still be the shape the group was made of ;
		# otherwise the glow tuned on it belongs to some other weapon now.
		$now = Get-Look $rep $tuned.Col
		if ($now -ne $wantLook)
		{
			Write-Warning "id $repId no longer has the look it was picked for (map: $wantLook ; now: $now) ; skipped."
			$drifted++
			continue
		}

		foreach ($m in $members)
		{
			$at = $fullById[$m]
			if ($null -eq $at)
			{
				Write-Warning "id $m is in $Map but not in $Backup ; skipped."
				$lost++
				continue
			}

			$cells = $fullRows[$at].Split("`t")
			$before = $fullRows[$at]
			foreach ($c in $carry) { $cells[$full.Col[$c]] = $rep[$tuned.Col[$c]] }
			$fullRows[$at] = $cells -join "`t"
			$touched++
			if ($fullRows[$at] -ne $before) { $changed++ }
		}
	}

	# -----------------------------------------------------------------------
	# Full table out.
	# -----------------------------------------------------------------------
	$new = Join-Path $tmp 'wg.new'
	$enc = Join-Path $tmp 'wg.enc'
	$back = Join-Path $tmp 'wg.back'

	$outTxt = Join-Path $tmp 'wg.out.txt'
	[System.IO.File]::WriteAllText($outTxt, (($fullRows -join "`n") + "`n"), $UTF8)
	& $asm -d $full.Ddf $outTxt $new | Out-Null
	if ($LASTEXITCODE -ne 0) { throw 'l2asm failed to rebuild weapongrp.' }
	& $encdec -e 413 $new $enc | Out-Null
	if ($LASTEXITCODE -ne 0) { throw 'l2encdec failed to encrypt weapongrp.' }
	& $encdec -d $enc $back | Out-Null
	if ($LASTEXITCODE -ne 0 -or (Get-FileHash $back).Hash -ne (Get-FileHash $new).Hash) { throw "weapongrp doesn't decrypt back to what was built." }

	# The cut down table you tuned is kept, so that a mistake here doesn't cost that work.
	$tunedBak = Join-Path $SystemDir 'weapongrp.dat.models-tuned.bak'
	Copy-Item $dat $tunedBak -Force
	Copy-Item $enc $dat -Force

	Write-Host "weapongrp : $($fullRows.Count - 1) rows written, glow of $($groups - $asIs - $missing - $drifted) look(s) spread over $touched row(s), $changed of them changed."
	if ($asIs) { Write-Host "  $asIs shield / monster weapon look(s) were never tuned and came back out of the backup as they were." }
	Write-Host "tuned table kept as $tunedBak ; the untouched full table is still $Backup"
	if ($missing -or $drifted -or $lost) { Write-Warning "$missing look(s) had no row in weapongrp.dat, $drifted had changed shape, $lost member id(s) were not in the backup." }
}
finally
{
	Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
