<#
.SYNOPSIS
	Puts the client rows of weapons restore_weapons.ps1 brought back into weapongrp.dat and itemname-e.dat.

.DESCRIPTION
	The client half of restore_weapons.ps1. remove_sa_client.ps1 took these ids out of the only two
	tables in system\ that describe a weapon ; this puts the very same rows back, copied out of a
	client taken before that removal :

	  weapongrp.dat   the row that gives the weapon its mesh, icon, grade and numbers
	  itemname-e.dat  the row that gives it a name

	Nothing is invented and nothing is guessed - a row that is not in the source file is an error,
	not a blank row. Rows already present are left alone, so a rerun writes nothing.

	Same guards as the other dat patchers : l2disasm/l2asm round trip checked byte for byte before
	anything is written, and a one time rollback copy kept as *.restore.bak.

	Run this BEFORE patch_client.ps1 : that script throws on a weapon of the ladder whose weapongrp
	row it cannot find, and these twelve are on the ladder again.

.PARAMETER SystemDir
	The "system" directory of the client to patch.

.PARAMETER ToolsDir
	Directory holding l2encdec\ and l2asm-disasm\ (the "data" directory of L2 File Editor).

.PARAMETER FromWeapongrp
	A weapongrp.dat that still holds these rows - one of the *.bak copies left next to the live one.

.PARAMETER FromItemname
	An itemname-e.dat that still holds them.

.PARAMETER Ids
	Comma separated item ids to restore. Defaults to the twelve NPC weapons of restore_weapons.ps1.

.PARAMETER DryRun
	Work out every restore and print the tally, but do not write the dat.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\weapons\restore_weapons_client.ps1 `
	    -SystemDir "C:\l2client\system" `
	    -ToolsDir "C:\tools\L2 File Editor\data" `
	    -FromWeapongrp "C:\l2client\system\weapongrp.dat.models.bak.retired.bak" `
	    -FromItemname "C:\l2client\system\itemname-e.dat.retired.bak"
#>
param(
	[string]$SystemDir = '',
	[string]$ToolsDir = '',
	[string]$FromWeapongrp = '',
	[string]$FromItemname = '',
	[string]$Ids = '67,73,74,76,86,96,123,127,153,223,228,298',
	[switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# Not [Parameter(Mandatory)] : one attribute anywhere in param() makes this an advanced script, and
# then the defaults are bound before $PSScriptRoot exists.
foreach ($pair in @(@('SystemDir', $SystemDir), @('ToolsDir', $ToolsDir), @('FromWeapongrp', $FromWeapongrp), @('FromItemname', $FromItemname)))
{
	if ($pair[1] -eq '') { throw "Give -$($pair[0])." }
}

$encdec = Join-Path $ToolsDir 'l2encdec\l2encdec.exe'
$disasm = Join-Path $ToolsDir 'l2asm-disasm\l2disasm.exe'
$asm = Join-Path $ToolsDir 'l2asm-disasm\l2asm.exe'
$defs = Join-Path $ToolsDir 'l2asm-disasm\DAT_defs\Interlude'
foreach ($exe in $encdec, $disasm, $asm) { if (-not (Test-Path $exe)) { throw "Missing $exe." } }

$UTF8 = New-Object System.Text.UTF8Encoding $false
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("restorew_" + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $tmp

$idSet = New-Object 'System.Collections.Generic.HashSet[int]'
foreach ($p in ($Ids -split ',')) { if ($p.Trim() -ne '') { $null = $idSet.Add([int]$p.Trim()) } }
if ($idSet.Count -eq 0) { throw 'No ids given.' }
Write-Host "$($idSet.Count) weapon(s) to restore"

function Open-Dat([string]$name, [string]$path, [string]$tag)
{
	$ddf = Join-Path $defs "$name.ddf"
	if (-not (Test-Path $path)) { throw "Missing $path." }
	if (-not (Test-Path $ddf)) { throw "Missing $ddf." }

	$dec = Join-Path $tmp "$tag.dec"
	$txt = Join-Path $tmp "$tag.txt"
	$exp = Join-Path $tmp "$tag.ddf"

	& $encdec -d $path $dec | Out-Null
	if ($LASTEXITCODE -ne 0)
	{
		& $encdec -l $path $dec | Out-Null
		if ($LASTEXITCODE -ne 0) { throw "Can't decrypt $path." }
	}

	& $disasm -d $ddf -e $exp $dec $txt | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "l2disasm failed on $path." }

	$check = Join-Path $tmp "$tag.check"
	& $asm -d $exp $txt $check | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "l2asm failed on $path." }
	if ((Get-FileHash $check).Hash -ne (Get-FileHash $dec).Hash) { throw "$path : l2disasm/l2asm round trip isn't byte exact ; wrong ddf for this client ?" }

	$rows = [System.Collections.Generic.List[string]]::new()
	foreach ($l in [System.IO.File]::ReadAllLines($txt)) { $null = $rows.Add($l) }

	$cols = @{}
	$header = $rows[0].Split("`t")
	for ($i = 0; $i -lt $header.Count; $i++) { $cols[$header[$i]] = $i }

	Write-Host "$tag : $($rows.Count - 1) rows, round trip verified"
	@{ name = $name; dat = $path; bak = "$path.restore.bak"; dec = $dec; txt = $txt; ddf = $exp; rows = $rows; cols = $cols }
}

function Save-Dat($t)
{
	if ($DryRun) { Write-Host "$($t.name) : dry run, not written" ; return }

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

# Rows of a table are ordered by id ; a restored one has to slot back in, not pile up at the end.
function Add-Row($t, [string]$row, [int]$id, [int]$idCol)
{
	$at = $t.rows.Count
	for ($i = 1; $i -lt $t.rows.Count; $i++)
	{
		if ([int]$t.rows[$i].Split("`t")[$idCol] -gt $id) { $at = $i ; break }
	}
	$t.rows.Insert($at, $row)
}

try
{
	foreach ($job in @(
			@{ name = 'weapongrp'; from = $FromWeapongrp; idCol = 'id' },
			@{ name = 'itemname-e'; from = $FromItemname; idCol = 'id' }))
	{
		$live = Open-Dat $job.name (Join-Path $SystemDir "$($job.name).dat") "$($job.name)-live"
		$src = Open-Dat $job.name $job.from "$($job.name)-from"

		$idC = $live.cols[$job.idCol]
		$srcC = $src.cols[$job.idCol]
		if ($live.rows[0] -ne $src.rows[0]) { throw "$($job.name) : the two files do not have the same columns." }

		$have = @{}
		for ($i = 1; $i -lt $live.rows.Count; $i++) { $have[[int]$live.rows[$i].Split("`t")[$idC]] = $true }

		$byId = @{}
		for ($i = 1; $i -lt $src.rows.Count; $i++) { $byId[[int]$src.rows[$i].Split("`t")[$srcC]] = $src.rows[$i] }

		$added = 0
		foreach ($id in ($idSet | Sort-Object))
		{
			if ($have.ContainsKey($id)) { continue }
			if (-not $byId.ContainsKey($id)) { throw "$($job.name) : $($job.from) has no row for $id either." }
			Add-Row $live $byId[$id] $id $idC
			$added++
		}

		if ($added -eq 0) { Write-Host "$($job.name) : nothing to restore" ; continue }
		Write-Host "$($job.name) : $added row(s) restored"
		Save-Dat $live
	}
}
finally
{
	Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
