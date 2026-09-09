<#
.SYNOPSIS
	Teaches the client the weapons generate.ps1 built, and points every weapon at the enchant glow.

.DESCRIPTION
	Interlude reads an item's name, icon, grade and mesh out of its own system\*.dat, so the ids
	generate.ps1 minted are invisible until those tables know about them. Two tables are rewritten,
	out of tools\weapons\generated\client_items.tsv :

	  weapongrp.dat   one row per minted copy, cloned from the weapon it looks like, with its own id,
	                  grade, P. Atk., M. Atk. and shot counts - plus, on every weapon of the ladder,
	                  originals included, the enchant glow effect (below).
	  itemname-e.dat  the name of every minted copy, taken from the weapon it was cloned from.

	**The enchant glow.** weapongrp carries one effect per weapon that the client spawns once the
	weapon is enchanted far enough (EnchantEffectShow in system\env.int). This script writes the +4
	effect of the weapon's shape into it - EnchantGlow.enchant4_004t for a sword, _008t for a bow and
	so on - and patch_engine_enchant_glow.ps1 makes the client walk that name up the ladder
	4 / 7 / 10 / 12 / 14 / 15 / 17 as the weapon is enchanted. Without the engine patch the client
	simply shows the +4 effect from +4 up, which is still correct, just not graded. See
	docs/enchant-glow.md.

	**The eleven hero weapons are excluded.** Infinity Blade and its siblings carry an effect of their
	own - LineageEffect.e_u092_a..k - which glows from +0, because that is what an Olympiad hero weapon
	is. They keep it, and keep their retail aura mesh with it ; both are written back on every run out
	of $OWN_EFFECT, so the exclusion holds even against a client an earlier run already flattened.

	**The enchant mesh comes off.** Alongside the effect, weapongrp names a MESH the client wraps
	around an enchanted weapon (LineageWeapons.rangesample in retail, the flat aura coloured out of
	env.int). EnchantGlow takes over that job, so the mesh is cleared - on every weapon of the table,
	not only the ones on the ladder.

	Everything goes through the l2encdec / l2disasm / l2asm trio of L2 File Editor, and every table is
	checked for a byte exact disassemble / reassemble round trip before it is touched - the same guard
	the armor patcher uses.

	**This one does not start from *.presets.bak.** The armor patcher does, because it owns every row
	it writes ; this one has to keep whatever the armor patcher (and whoever pruned 71 non Interlude
	rows out of weapongrp) left behind. It is idempotent a different way : every id it owns is taken
	out of the table before its rows are put back, so a rerun lands on the same file. A one time
	rollback copy is kept as *.weapons.bak the first time it runs.

.PARAMETER SystemDir
	The "system" directory of the client to patch.

.PARAMETER ToolsDir
	Directory holding l2encdec\ and l2asm-disasm\ (the "data" directory of L2 File Editor).

.PARAMETER GeneratedDir
	Where generate.ps1 dropped its .tsv. Defaults to tools\weapons\generated.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\weapons\patch_client.ps1 `
	    -SystemDir "C:\l2client\system" `
	    -ToolsDir "C:\tools\L2 File Editor\data"
#>
param(
	[Parameter(Mandatory = $true)][string]$SystemDir,
	[Parameter(Mandatory = $true)][string]$ToolsDir,
	[string]$GeneratedDir = ''
)

$ErrorActionPreference = 'Stop'

if ($GeneratedDir -eq '') { $GeneratedDir = Join-Path $PSScriptRoot 'generated' }

$encdec = Join-Path $ToolsDir 'l2encdec\l2encdec.exe'
$disasm = Join-Path $ToolsDir 'l2asm-disasm\l2disasm.exe'
$asm = Join-Path $ToolsDir 'l2asm-disasm\l2asm.exe'
$defs = Join-Path $ToolsDir 'l2asm-disasm\DAT_defs\Interlude'
foreach ($exe in $encdec, $disasm, $asm) { if (-not (Test-Path $exe)) { throw "Missing $exe." } }

$GLOW_PACKAGE = 'EnchantGlow'
$GLOW_FIRST_LEVEL = 4

# The rungs of the ladder. Has to match -Levels of patch_engine_enchant_glow.ps1 : between
# them these two decide which names exist in the client at all.
$GLOW_LEVELS = @(4, 7, 10, 12, 14, 15, 17)

# The retail enchant MESH - the flat "aura" the client wraps around a weapon from EnchantMeshShow
# up, quite separate from the effect. EnchantGlow takes its place, so it comes off every weapon.
$ENCHANT_MESH = 'LineageWeapons.rangesample'

# The hero weapons wear an effect of their own, and it is not an enchant glow : Infinity Blade and
# its ten siblings glow the moment they are equipped, at +0, because that is what an Olympiad hero
# weapon IS. Repointing them at EnchantGlow like everybody else took that away and left them dark
# until +4, so they are excluded here - and put back on every run, so the exclusion cannot rot into
# "whatever the file happened to hold". Their retail aura mesh stays on them too, for the same
# reason : it is part of the look, not an enchant effect.
#
# The effect goes into effA, and into effB as well when the weapon is held in two hands
# (wpn_mesh_cnt 2) - the dual Infinity Wing and the Infinity Fang claws.
$OWN_EFFECT = @{
	6611 = 'LineageEffect.e_u092_a'   # Infinity Blade
	6612 = 'LineageEffect.e_u092_b'   # Infinity Cleaver
	6613 = 'LineageEffect.e_u092_c'   # Infinity Axe
	6614 = 'LineageEffect.e_u092_d'   # Infinity Rod
	6615 = 'LineageEffect.e_u092_e'   # Infinity Crusher
	6616 = 'LineageEffect.e_u092_f'   # Infinity Scepter
	6617 = 'LineageEffect.e_u092_g'   # Infinity Stinger
	6618 = 'LineageEffect.e_u092_h'   # Infinity Fang
	6619 = 'LineageEffect.e_u092_i'   # Infinity Bow
	6620 = 'LineageEffect.e_u092_j'   # Infinity Wing
	6621 = 'LineageEffect.e_u092_k'   # Infinity Spear
}

$UTF8 = New-Object System.Text.UTF8Encoding $false
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("weapons_" + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $tmp

# ---------------------------------------------------------------------------
# One table in, one table out.
# ---------------------------------------------------------------------------

function Open-Dat([string]$name)
{
	$dat = Join-Path $SystemDir "$name.dat"
	$ddf = Join-Path $defs "$name.ddf"
	if (-not (Test-Path $dat)) { throw "Missing $dat." }
	if (-not (Test-Path $ddf)) { throw "Missing $ddf." }

	$dec = Join-Path $tmp "$name.dec"
	$txt = Join-Path $tmp "$name.txt"
	$exp = Join-Path $tmp "$name.ddf"

	& $encdec -d $dat $dec | Out-Null
	if ($LASTEXITCODE -ne 0)
	{
		& $encdec -l $dat $dec | Out-Null
		if ($LASTEXITCODE -ne 0) { throw "Can't decrypt $dat." }
		Write-Warning "$name.dat still carries L2's original keys ; the rebuilt file will use l2encdec's pair, which only a patched client reads."
	}

	& $disasm -d $ddf -e $exp $dec $txt | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "l2disasm failed on $name." }

	# A round trip that isn't byte exact means the ddf doesn't match this client, and every untouched
	# record of the table would silently ride along with our edit.
	$check = Join-Path $tmp "$name.check"
	& $asm -d $exp $txt $check | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "l2asm failed on $name." }
	if ((Get-FileHash $check).Hash -ne (Get-FileHash $dec).Hash) { throw "$name : l2disasm/l2asm round trip isn't byte exact ; wrong ddf for this client ?" }

	$rows = [System.Collections.Generic.List[string]]::new()
	foreach ($l in [System.IO.File]::ReadAllLines($txt)) { $null = $rows.Add($l) }

	$cols = @{}
	$header = $rows[0].Split("`t")
	for ($i = 0; $i -lt $header.Count; $i++) { $cols[$header[$i]] = $i }

	Write-Host "$name : $($rows.Count - 1) rows, round trip verified"
	@{ name = $name; dat = $dat; bak = "$dat.weapons.bak"; dec = $dec; txt = $txt; ddf = $exp; rows = $rows; cols = $cols }
}

function Save-Dat($t)
{
	$new = Join-Path $tmp "$($t.name).new"
	$enc = Join-Path $tmp "$($t.name).enc"
	$back = Join-Path $tmp "$($t.name).back"

	[System.IO.File]::WriteAllText($t.txt, (($t.rows -join "`n") + "`n"), $UTF8)

	& $asm -d $t.ddf $t.txt $new | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "l2asm failed to rebuild $($t.name)." }

	& $encdec -e 413 $new $enc | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "l2encdec failed to encrypt $($t.name)." }

	& $encdec -d $enc $back | Out-Null
	if ($LASTEXITCODE -ne 0 -or (Get-FileHash $back).Hash -ne (Get-FileHash $new).Hash) { throw "$($t.name) doesn't decrypt back to what was built." }

	if (-not (Test-Path $t.bak)) { Copy-Item $t.dat $t.bak }
	Copy-Item $enc $t.dat -Force
	Write-Host "$($t.name) : wrote $($t.rows.Count - 1) rows (rollback copy $($t.bak))"
}

# The whole id range this script owns comes out first, so that a rerun replaces its rows instead of
# stacking another copy of them on top - and so that a shorter weapons.csv doesn't leave the ids it
# no longer mints behind in the table.
#
# The range, not just the ids of this run : armor owns 10000..11409 and has to survive.
$OWNED_FIRST = 12000
$OWNED_LAST = 19999

function Remove-Ours($t, [int]$idCol)
{
	$dropped = 0
	for ($i = $t.rows.Count - 1; $i -ge 1; $i--)
	{
		$id = [int]$t.rows[$i].Split("`t")[$idCol]
		if ($id -ge $OWNED_FIRST -and $id -le $OWNED_LAST) { $t.rows.RemoveAt($i) ; $dropped++ }
	}
	$dropped
}

# What an empty mesh cell looks like in this table isn't ours to guess : l2disasm writes a UNICODE
# field back exactly as it read it, and depending on the table that can be an empty cell or the
# literal "none". So take the token off the rows that carry no enchant mesh of their own - whatever
# they hold has just round tripped byte for byte through the check in Open-Dat.
function Get-BlankMesh($rows, [int]$col, [string]$mesh)
{
	$tally = @{}
	for ($i = 1; $i -lt $rows.Count; $i++)
	{
		$v = $rows[$i].Split("`t")[$col]
		if ($v -eq $mesh) { continue }
		$tally[$v] = 1 + $(if ($tally.ContainsKey($v)) { $tally[$v] } else { 0 })
	}
	if ($tally.Count -eq 0)
	{
		Write-Warning "every weapon carries $mesh ; clearing the column with an empty cell, unverified."
		return ''
	}
	($tally.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 1).Key
}

# Rows of a table are ordered by id ; ours have to slot in, not pile up at the end.
function Add-Rows($t, $newRows, [int]$lastId, [int]$idCol)
{
	$at = $t.rows.Count
	for ($i = 1; $i -lt $t.rows.Count; $i++)
	{
		if ([int]$t.rows[$i].Split("`t")[$idCol] -gt $lastId) { $at = $i ; break }
	}
	$t.rows.InsertRange($at, $newRows)
}

try
{
	$items = @(Import-Csv (Join-Path $GeneratedDir 'client_items.tsv') -Delimiter "`t")
	$minted = @($items | Where-Object { $_.id -ne $_.donor })
	Write-Host "$($items.Count) weapons on the ladder, $($minted.Count) of them minted"

	$lastNew = ($minted | ForEach-Object { [int]$_.id } | Measure-Object -Maximum).Maximum
	if ($lastNew -gt $OWNED_LAST) { throw "generate.ps1 minted $lastNew, past the $OWNED_FIRST..$OWNED_LAST this script clears out." }

	# -----------------------------------------------------------------------
	# weapongrp.dat : the copies, and the enchant glow on everybody.
	# -----------------------------------------------------------------------

	$grp = Open-Dat 'weapongrp'
	$idC = $grp.cols['id']; $ctC = $grp.cols['crystal_type']
	$paC = $grp.cols['patt']; $maC = $grp.cols['matt']
	$ssC = $grp.cols['SS_count']; $spC = $grp.cols['SPS_count']; $mpC = $grp.cols['mp_consume']
	$mcC = $grp.cols['wpn_mesh_cnt']; $eaC = $grp.cols['effA']; $ebC = $grp.cols['effB']

	$gone = Remove-Ours $grp $idC
	if ($gone) { Write-Host "weapongrp : took out $gone row(s) from an earlier run" }

	# The enchant mesh comes off EVERY weapon in the table, not just the ladder : it is the retail
	# aura, and EnchantGlow is what shows now. Done before the copies are cloned, so they come out
	# of their donors without it too.
	$raC = $grp.cols['rangeA']; $rbC = $grp.cols['rangeB']
	$blank = Get-BlankMesh $grp.rows $raC $ENCHANT_MESH
	$stripped = 0
	$kept = 0
	for ($i = 1; $i -lt $grp.rows.Count; $i++)
	{
		$cells = $grp.rows[$i].Split("`t")

		# The hero weapons keep their aura, and are handed it back if an earlier run took it.
		if ($OWN_EFFECT.ContainsKey([int]$cells[$idC]))
		{
			$hit = $false
			if ($cells[$raC] -ne $ENCHANT_MESH) { $cells[$raC] = $ENCHANT_MESH ; $hit = $true }
			if ([int]$cells[$mcC] -eq 2 -and $cells[$rbC] -ne $ENCHANT_MESH) { $cells[$rbC] = $ENCHANT_MESH ; $hit = $true }
			if ($hit) { $grp.rows[$i] = $cells -join "`t" }
			$kept++
			continue
		}

		$hit = $false
		if ($cells[$raC] -eq $ENCHANT_MESH) { $cells[$raC] = $blank ; $hit = $true }
		if ([int]$cells[$mcC] -eq 2 -and $cells[$rbC] -eq $ENCHANT_MESH) { $cells[$rbC] = $blank ; $hit = $true }
		if ($hit) { $grp.rows[$i] = $cells -join "`t" ; $stripped++ }
	}
	Write-Host "weapongrp : $ENCHANT_MESH taken off $stripped weapon(s), cleared to '$blank' ; $kept hero weapon(s) keep it"

	$byId = @{}
	for ($i = 1; $i -lt $grp.rows.Count; $i++) { $byId[[int]$grp.rows[$i].Split("`t")[$idC]] = $i }

	# Every rung's name has to appear in weapongrp at least once, and this is not cosmetic :
	# the client only ever shows an effect whose name came out of a dat. A name the engine
	# patch builds at run time with FName(..., FNAME_Add) is ignored, however correct it
	# looks - proved by putting rung 17 into the dat, where +17 then drew in the world and
	# +15, still invented by the patch, stayed invisible.
	#
	# So the rungs are dealt round robin WITHIN each shape. The shape of every weapon stays
	# its own - that is what the engine patch keys off to know what it is looking at - while
	# all of the ladder's names reach the name table at load. Which rung a weapon starts on
	# does not matter : the patch overwrites it with the one its enchant level calls for.
	$seen = @{}
	$glowOf = @{}
	foreach ($it in $items)
	{
		$shape = $it.glow
		$n = $(if ($seen.ContainsKey($shape)) { $seen[$shape] } else { 0 })
		$seen[$shape] = $n + 1
		$lvl = $GLOW_LEVELS[$n % $GLOW_LEVELS.Count]
		$glowOf[[int]$it.id] = "$GLOW_PACKAGE.enchant$lvl`_$shape"
	}

	# If a shape has fewer weapons than the ladder has rungs, some of its names never make it
	# into the dat and those rungs will not draw. Say so rather than let it pass quietly.
	$missing = @()
	foreach ($shape in ($items | ForEach-Object { $_.glow } | Sort-Object -Unique))
	{
		if ($seen[$shape] -lt $GLOW_LEVELS.Count)
		{
			$missing += "$shape has only $($seen[$shape]) weapon(s) for $($GLOW_LEVELS.Count) rungs"
		}
	}
	if ($missing) { Write-Warning ("not every rung will be in the name table : " + ($missing -join ' ; ')) }

	$newGrp = [System.Collections.Generic.List[string]]::new()
	$glowed = 0
	$ownGlow = 0
	foreach ($it in $items)
	{
		$donor = [int]$it.donor
		if (-not $byId.ContainsKey($donor)) { throw "weapongrp.dat has no row for weapon $donor" }
		$cells = $grp.rows[$byId[$donor]].Split("`t")

		if ([int]$it.id -eq $donor)
		{
			# An original keeps everything it had ; only its enchant glow is repointed.
			if ($cells[$ctC] -ne $it.gradeIdx) { throw "weapongrp.dat says weapon $donor is grade $($cells[$ctC]), the datapack says $($it.gradeIdx)" }

			# ... unless it is a hero weapon, whose own aura is the effect it shows.
			if ($OWN_EFFECT.ContainsKey($donor))
			{
				$cells[$eaC] = $OWN_EFFECT[$donor]
				if ([int]$cells[$mcC] -eq 2) { $cells[$ebC] = $OWN_EFFECT[$donor] }
				$grp.rows[$byId[$donor]] = $cells -join "`t"
				$ownGlow++
				continue
			}

			$cells[$eaC] = $glowOf[$donor]
			if ([int]$cells[$mcC] -eq 2) { $cells[$ebC] = $glowOf[$donor] }
			$grp.rows[$byId[$donor]] = $cells -join "`t"
			$glowed++
			continue
		}

		$cells[$idC] = $it.id
		$cells[$ctC] = $it.gradeIdx
		$cells[$paC] = $it.pAtk
		$cells[$maC] = $it.mAtk
		$cells[$eaC] = $glowOf[[int]$it.id]
		if ([int]$cells[$mcC] -eq 2) { $cells[$ebC] = $glowOf[[int]$it.id] }
		$null = $newGrp.Add($cells -join "`t")
		$glowed++
	}
	Add-Rows $grp $newGrp $lastNew $idC
	Save-Dat $grp
	Write-Host "weapongrp : $glowed weapons point at $GLOW_PACKAGE, $ownGlow hero weapon(s) at their own effect"

	# -----------------------------------------------------------------------
	# itemname-e.dat : the names of the copies.
	# -----------------------------------------------------------------------

	$nam = Open-Dat 'itemname-e'
	$idC = $nam.cols['id']; $nmC = $nam.cols['name']; $anC = $nam.cols['add_name']

	$gone = Remove-Ours $nam $idC
	if ($gone) { Write-Host "itemname-e : took out $gone row(s) from an earlier run" }

	$byId = @{}
	for ($i = 1; $i -lt $nam.rows.Count; $i++) { $byId[[int]$nam.rows[$i].Split("`t")[$idC]] = $i }

	$newNam = [System.Collections.Generic.List[string]]::new()
	foreach ($it in $minted)
	{
		$donor = [int]$it.donor
		if (-not $byId.ContainsKey($donor)) { throw "itemname-e.dat has no row for weapon $donor" }
		$cells = $nam.rows[$byId[$donor]].Split("`t")

		$cells[$idC] = $it.id
		# A copy carries the name of the weapon it was cloned from and says nothing else : the grade
		# is on the icon already.
		$cells[$nmC] = $it.name
		$cells[$anC] = ''
		$null = $newNam.Add($cells -join "`t")
	}
	Add-Rows $nam $newNam $lastNew $idC
	Save-Dat $nam

	Write-Host ''
	Write-Host 'Done. Restart the client for it to reload system\*.dat.'
	Write-Host "Run patch_engine_enchant_glow.ps1 next if the glow should climb with the enchant level."
}
finally
{
	Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
