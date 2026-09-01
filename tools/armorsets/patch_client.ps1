<#
.SYNOPSIS
	Teaches the client the armor sets generate.ps1 built.

.DESCRIPTION
	Interlude reads an item's name, icon, grade and mesh out of its own system\*.dat, so the ids
	generate.ps1 minted are invisible until those tables know about them. This script rewrites four
	of them, out of tools\armorsets\generated\*.tsv :

	  armorgrp.dat    one row per new piece, cloned from the item it looks like, with its own id,
	                  grade and P. Def. ; the chests keep their row and only have their P. Def.
	                  rewritten in place.
	  itemname-e.dat  the name of every new piece - taken from the chest of its set, with an empty
	                  title, because the grade already shows on the icon - plus the set tooltip
	                  (members, bonus, shield) on all 447 chests.
	  skillgrp.dat    one row per set skill level, wearing the icon of its own chest piece.
	  skillname-e.dat the name and the bonus text of every set skill level.

	Everything goes through the l2encdec / l2disasm / l2asm trio of L2 File Editor, and every table
	is checked for a byte exact disassemble / reassemble round trip before it is touched - the same
	guard patch_etcitemgrp.ps1 uses. The stock files are kept next to the new ones as *.presets.bak,
	and a rerun always starts from that backup, so running this twice is the same as running it once.

.PARAMETER SystemDir
	The "system" directory of the client to patch.

.PARAMETER ToolsDir
	Directory holding l2encdec\ and l2asm-disasm\ (the "data" directory of L2 File Editor).

.PARAMETER GeneratedDir
	Where generate.ps1 dropped its .tsv. Defaults to tools\armorsets\generated.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\armorsets\patch_client.ps1 `
	    -SystemDir "C:\l2client\system" `
	    -ToolsDir "C:\tools\L2 File Editor\data"
#>
param(
	[Parameter(Mandatory = $true)][string]$SystemDir,
	[Parameter(Mandatory = $true)][string]$ToolsDir,
	[string]$GeneratedDir = (Join-Path $PSScriptRoot 'generated')
)

$ErrorActionPreference = 'Stop'

$encdec = Join-Path $ToolsDir 'l2encdec\l2encdec.exe'
$disasm = Join-Path $ToolsDir 'l2asm-disasm\l2disasm.exe'
$asm = Join-Path $ToolsDir 'l2asm-disasm\l2asm.exe'
$defs = Join-Path $ToolsDir 'l2asm-disasm\DAT_defs\Interlude'
foreach ($exe in $encdec, $disasm, $asm) { if (-not (Test-Path $exe)) { throw "Missing $exe." } }

$GRADES = @('NG', 'D', 'C', 'B', 'A', 'S')
$UTF8 = New-Object System.Text.UTF8Encoding $false
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("armorsets_" + [Guid]::NewGuid().ToString('N'))
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

	# Always work from the stock file, so a rerun doesn't stack our rows on top of themselves.
	$bak = "$dat.presets.bak"
	$src = $(if (Test-Path $bak) { $bak } else { $dat })

	$dec = Join-Path $tmp "$name.dec"
	$txt = Join-Path $tmp "$name.txt"
	$exp = Join-Path $tmp "$name.ddf"

	& $encdec -d $src $dec | Out-Null
	if ($LASTEXITCODE -ne 0)
	{
		& $encdec -l $src $dec | Out-Null
		if ($LASTEXITCODE -ne 0) { throw "Can't decrypt $src." }
		Write-Warning "$name.dat still carries L2's original keys ; the rebuilt file will use l2encdec's pair, which only a patched client reads."
	}

	& $disasm -d $ddf -e $exp $dec $txt | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "l2disasm failed on $name." }

	# A round trip that isn't byte exact means the ddf doesn't match this client, and every
	# untouched record of the table would silently ride along with our edit.
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
	@{ name = $name; dat = $dat; bak = $bak; dec = $dec; txt = $txt; ddf = $exp; rows = $rows; cols = $cols }
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
	Write-Host "$($t.name) : wrote $($t.rows.Count - 1) rows (stock file kept as $($t.bak))"
}

# Rows of a table are ordered by id ; ours have to slot in, not pile up at the end.
function Add-Rows($t, $newRows, [int]$firstId, [int]$lastId, [int]$idCol)
{
	$at = $t.rows.Count
	for ($i = 1; $i -lt $t.rows.Count; $i++)
	{
		if ([int]$t.rows[$i].Split("`t")[$idCol] -gt $lastId) { $at = $i ; break }
	}
	for ($i = 1; $i -lt $at; $i++)
	{
		if ([int]$t.rows[$i].Split("`t")[$idCol] -ge $firstId) { throw "$($t.name) already holds an id in $firstId..$lastId" }
	}
	$t.rows.InsertRange($at, $newRows)
}

function Get-Prefixed([string]$template, [string]$text)
{
	# ASCF / UNICODE cells look like "a,text\0" or "u,text\0" ; keep whatever prefix the row used.
	$p = $(if ($template -match '^([au]),') { $Matches[1] } else { 'a' })
	if ($text -eq '') { return "$p," }
	"$p,$text\0"
}

try
{
	$items = Import-Csv (Join-Path $GeneratedDir 'client_items.tsv') -Delimiter "`t"
	$sets = Import-Csv (Join-Path $GeneratedDir 'client_sets.tsv') -Delimiter "`t"
	$skills = Import-Csv (Join-Path $GeneratedDir 'client_skills.tsv') -Delimiter "`t"
	Write-Host "$($items.Count) pieces, $($sets.Count) sets, $($skills.Count) skill levels"

	$added = @($items | Where-Object { $_.mode -eq 'add' })
	$firstNew = ($added | ForEach-Object { [int]$_.id } | Measure-Object -Minimum).Minimum
	$lastNew = ($added | ForEach-Object { [int]$_.id } | Measure-Object -Maximum).Maximum

	# -----------------------------------------------------------------------
	# armorgrp.dat
	# -----------------------------------------------------------------------

	$grp = Open-Dat 'armorgrp'
	$idC = $grp.cols['id']; $ctC = $grp.cols['crystal_type']; $pdC = $grp.cols['pdef']; $icC = $grp.cols['icon[0]']
	$byId = @{}
	for ($i = 1; $i -lt $grp.rows.Count; $i++) { $byId[[int]$grp.rows[$i].Split("`t")[$idC]] = $i }

	$icons = @{}
	$newGrp = [System.Collections.Generic.List[string]]::new()
	foreach ($it in $items)
	{
		$donor = [int]$it.donor
		if (-not $byId.ContainsKey($donor)) { throw "armorgrp.dat has no row for item $donor" }
		$cells = $grp.rows[$byId[$donor]].Split("`t")
		$icons[$donor] = $cells[$icC]

		# An original keeps the grade it always had ; only its P. Def. is levelled.
		if ($it.mode -eq 'update')
		{
			if ($cells[$ctC] -ne $it.gradeIdx) { throw "armorgrp.dat says item $donor is grade $($cells[$ctC]), the datapack says $($it.gradeIdx)" }
			$cells[$pdC] = $it.pdef
			$grp.rows[$byId[$donor]] = $cells -join "`t"
			continue
		}

		$cells[$idC] = $it.id
		$cells[$ctC] = $it.gradeIdx
		$cells[$pdC] = $it.pdef
		$null = $newGrp.Add($cells -join "`t")
	}
	Add-Rows $grp $newGrp $firstNew $lastNew $idC
	Save-Dat $grp

	# -----------------------------------------------------------------------
	# itemname-e.dat
	# -----------------------------------------------------------------------

	$nam = Open-Dat 'itemname-e'
	$idC = $nam.cols['id']; $nmC = $nam.cols['name']; $anC = $nam.cols['add_name']; $dsC = $nam.cols['description']
	$siC = $nam.cols['set_ids']; $sbC = $nam.cols['set_bonus_desc']
	$xiC = $nam.cols['set_extra_id']; $xdC = $nam.cols['set_extra_desc']
	$seaC = $nam.cols['special_enchant_amount']; $sedC = $nam.cols['special_enchant_desc']

	$byId = @{}
	for ($i = 1; $i -lt $nam.rows.Count; $i++) { $byId[[int]$nam.rows[$i].Split("`t")[$idC]] = $i }

	$ENCHANT_TEXT = 'When all set items are enchanted by 6 or higher, the set bonus grows.'

	$newNam = [System.Collections.Generic.List[string]]::new()
	foreach ($it in $added)
	{
		$donor = [int]$it.donor
		if (-not $byId.ContainsKey($donor)) { throw "itemname-e.dat has no row for item $donor" }
		$cells = $nam.rows[$byId[$donor]].Split("`t")

		$cells[$idC] = $it.id
		# A minted piece is named after the chest of its set, and its title says nothing at all -
		# the grade is on the icon already, and the donor's own title would be about the donor.
		$cells[$nmC] = $it.name
		$cells[$anC] = ''
		if ($it.clearDesc -eq '1') { $cells[$dsC] = Get-Prefixed $cells[$dsC] '' }
		foreach ($c in $siC, $sbC, $xiC, $xdC) { $cells[$c] = Get-Prefixed $cells[$c] '' }
		$cells[$seaC] = '0'
		$cells[$sedC] = Get-Prefixed $cells[$sedC] ''
		$null = $newNam.Add($cells -join "`t")
	}
	Add-Rows $nam $newNam $firstNew $lastNew $idC

	foreach ($it in ($items | Where-Object { $_.mode -eq 'update' -and $_.clearDesc -eq '1' }))
	{
		$at = $byId[[int]$it.id]
		$cells = $nam.rows[$at].Split("`t")
		$cells[$dsC] = Get-Prefixed $cells[$dsC] ''
		$nam.rows[$at] = $cells -join "`t"
	}

	# The set tooltip - members, bonus, shield - lives on the chest row alone.
	$byId = @{}
	for ($i = 1; $i -lt $nam.rows.Count; $i++) { $byId[[int]$nam.rows[$i].Split("`t")[$idC]] = $i }

	foreach ($s in $sets)
	{
		$chest = [int]$s.chest
		if (-not $byId.ContainsKey($chest)) { throw "itemname-e.dat has no row for chest $chest" }
		$at = $byId[$chest]
		$cells = $nam.rows[$at].Split("`t")

		$cells[$siC] = Get-Prefixed $cells[$siC] $s.members
		$cells[$sbC] = Get-Prefixed $cells[$sbC] $s.bonus
		$cells[$xiC] = Get-Prefixed $cells[$xiC] $s.extraId
		$cells[$xdC] = Get-Prefixed $cells[$xdC] $s.extraDesc
		$cells[$seaC] = '6'
		$cells[$sedC] = Get-Prefixed $cells[$sedC] $ENCHANT_TEXT
		$nam.rows[$at] = $cells -join "`t"
	}
	Save-Dat $nam

	# -----------------------------------------------------------------------
	# skillgrp.dat and skillname-e.dat
	# -----------------------------------------------------------------------

	$firstSkill = ($skills | ForEach-Object { [int]$_.id } | Measure-Object -Minimum).Minimum
	$lastSkill = ($skills | ForEach-Object { [int]$_.id } | Measure-Object -Maximum).Maximum

	$grpS = Open-Dat 'skillgrp'
	$sidC = $grpS.cols['skill_id']; $slvC = $grpS.cols['skill_level']; $sicC = $grpS.cols['icon_name']
	$tplSet = $null; $tplEnchant = $null
	for ($i = 1; $i -lt $grpS.rows.Count; $i++)
	{
		$c = $grpS.rows[$i].Split("`t")
		if ($c[$sidC] -eq '3500' -and $c[$slvC] -eq '1') { $tplSet = $c }
		if ($c[$sidC] -eq '3611' -and $c[$slvC] -eq '1') { $tplEnchant = $c }
	}
	if (-not $tplSet -or -not $tplEnchant) { throw 'skillgrp.dat has no row for skill 3500 / 3611 to clone.' }

	$newGrpS = [System.Collections.Generic.List[string]]::new()
	foreach ($sk in $skills)
	{
		$cells = $(if ($sk.kind -eq 'enchant') { $tplEnchant.Clone() } else { $tplSet.Clone() })
		$cells[$sidC] = $sk.id
		$cells[$slvC] = $sk.level
		# A set skill wears the icon of its own chest piece ; that is what retail does too.
		if ($sk.kind -eq 'set' -and $icons.ContainsKey([int]$sk.iconFrom)) { $cells[$sicC] = $icons[[int]$sk.iconFrom] }
		$null = $newGrpS.Add($cells -join "`t")
	}
	Add-Rows $grpS $newGrpS $firstSkill $lastSkill $sidC
	Save-Dat $grpS

	$namS = Open-Dat 'skillname-e'
	$sidC = $namS.cols['id']; $slvC = $namS.cols['level']; $snC = $namS.cols['name']; $sdC = $namS.cols['description']
	$tpl = $null
	for ($i = 1; $i -lt $namS.rows.Count; $i++)
	{
		$c = $namS.rows[$i].Split("`t")
		if ($c[$sidC] -eq '3500' -and $c[$slvC] -eq '1') { $tpl = $c ; break }
	}
	if (-not $tpl) { throw 'skillname-e.dat has no row for skill 3500 to clone.' }

	$newNamS = [System.Collections.Generic.List[string]]::new()
	foreach ($sk in $skills)
	{
		$cells = $tpl.Clone()
		$cells[$sidC] = $sk.id
		$cells[$slvC] = $sk.level
		$cells[$snC] = Get-Prefixed $cells[$snC] $sk.name
		$cells[$sdC] = Get-Prefixed $cells[$sdC] $sk.desc
		$null = $newNamS.Add($cells -join "`t")
	}
	Add-Rows $namS $newNamS $firstSkill $lastSkill $sidC
	Save-Dat $namS

	Write-Host ''
	Write-Host "done : $($added.Count) new pieces, $($sets.Count) set tooltips, $($skills.Count) skill levels."
	Write-Host "Restore the client with the *.presets.bak files next to the patched ones."
}
finally
{
	Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
