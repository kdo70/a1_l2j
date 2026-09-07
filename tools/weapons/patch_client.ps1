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

	$byId = @{}
	for ($i = 1; $i -lt $grp.rows.Count; $i++) { $byId[[int]$grp.rows[$i].Split("`t")[$idC]] = $i }

	$glowOf = @{}
	foreach ($it in $items) { $glowOf[[int]$it.id] = "$GLOW_PACKAGE.enchant$GLOW_FIRST_LEVEL`_$($it.glow)" }

	$newGrp = [System.Collections.Generic.List[string]]::new()
	$glowed = 0
	foreach ($it in $items)
	{
		$donor = [int]$it.donor
		if (-not $byId.ContainsKey($donor)) { throw "weapongrp.dat has no row for weapon $donor" }
		$cells = $grp.rows[$byId[$donor]].Split("`t")

		if ([int]$it.id -eq $donor)
		{
			# An original keeps everything it had ; only its enchant glow is repointed.
			if ($cells[$ctC] -ne $it.gradeIdx) { throw "weapongrp.dat says weapon $donor is grade $($cells[$ctC]), the datapack says $($it.gradeIdx)" }
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
	Write-Host "weapongrp : $glowed weapons point at $GLOW_PACKAGE"

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
