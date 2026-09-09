<#
.SYNOPSIS
	Takes the special ability copies of weapons out of the client, out of tools\weapons\retired_sa.csv.

.DESCRIPTION
	The client half of remove_sa.ps1. That script drops the SA copies from the datapack ; this one
	drops the same list from the two tables that still describe them to the client :

	  weapongrp.dat   the row that gives the copy its mesh, grade and numbers
	  itemname-e.dat  the row that gives it a name

	Nothing else in system\ mentions a weapon by id, so those two are the whole client side. The
	list is retired_sa.csv, the same explicit list the datapack uses - not a name pattern - so a
	weapon that merely reads like an SA copy ("Falchion - for Beginners", a polearm whose item_skill
	is its own behaviour) is left alone.

	The rows go rather than being blanked : Interlude looks a weapon up by id and simply finds
	nothing, which is what it already does for the 71 non Interlude rows this client was pruned of.

	Same guards as the other dat patchers : l2disasm/l2asm round trip checked byte for byte before
	anything is written, and a rollback copy kept as *.sa.bak. A rerun finds nothing to drop and
	writes nothing.

.PARAMETER SystemDir
	The "system" directory of the client to patch.

.PARAMETER ToolsDir
	Directory holding l2encdec\ and l2asm-disasm\ (the "data" directory of L2 File Editor).

.PARAMETER Retired
	The list to drop. Defaults to retired_sa.csv next to this script. Any csv with an "id" column
	does : remove_weapons.ps1 hands it retired_weapons.csv to take whole weapons out of the same two
	tables, which is the same job with a different list.

.PARAMETER BackupSuffix
	What the rollback copy is called. Defaults to .sa.bak - give a second run against a different
	list its own suffix, or its rollback copy will be the one the first run already left.

.PARAMETER DryRun
	Work out every removal and print the tally, but do not write the dat.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\weapons\remove_sa_client.ps1 `
	    -SystemDir "C:\l2client\system" `
	    -ToolsDir "C:\tools\L2 File Editor\data"
#>
param(
	[Parameter(Mandatory = $true)][string]$SystemDir,
	[Parameter(Mandatory = $true)][string]$ToolsDir,
	[string]$Retired = '',
	[string]$BackupSuffix = '.sa.bak',
	[switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if ($Retired -eq '') { $Retired = Join-Path $PSScriptRoot 'retired_sa.csv' }

$encdec = Join-Path $ToolsDir 'l2encdec\l2encdec.exe'
$disasm = Join-Path $ToolsDir 'l2asm-disasm\l2disasm.exe'
$asm = Join-Path $ToolsDir 'l2asm-disasm\l2asm.exe'
$defs = Join-Path $ToolsDir 'l2asm-disasm\DAT_defs\Interlude'
foreach ($exe in $encdec, $disasm, $asm) { if (-not (Test-Path $exe)) { throw "Missing $exe." } }

$UTF8 = New-Object System.Text.UTF8Encoding $false
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("sa_client_" + [Guid]::NewGuid().ToString('N'))
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
	if ($LASTEXITCODE -ne 0) { throw "Can't decrypt $dat." }

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
	if (-not $cols.ContainsKey('id')) { throw "$name has no id column ; wrong ddf ?" }

	Write-Host "$name : $($rows.Count - 1) rows, round trip verified"
	@{ name = $name; dat = $dat; bak = "$dat$BackupSuffix"; dec = $dec; txt = $txt; ddf = $exp; rows = $rows; cols = $cols }
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

function Remove-Retired($t, $ids)
{
	$idC = $t.cols['id']
	$dropped = 0
	for ($i = $t.rows.Count - 1; $i -ge 1; $i--)
	{
		if ($ids.Contains([int]$t.rows[$i].Split("`t")[$idC])) { $t.rows.RemoveAt($i) ; $dropped++ }
	}
	$dropped
}

try
{
	if (-not (Test-Path $Retired)) { throw "Missing $Retired." }
	# Not $retired : PowerShell tells no variable from another by case, and the -Retired parameter is
	# typed [string], so an array landing in it would silently become one.
	$list = @(Import-Csv $Retired)
	if ($list.Count -eq 0) { throw "$Retired is empty." }

	$ids = New-Object 'System.Collections.Generic.HashSet[int]'
	foreach ($r in $list) { $null = $ids.Add([int]$r.id) }
	Write-Host "$($ids.Count) id(s) to remove"

	foreach ($name in 'weapongrp', 'itemname-e')
	{
		$t = Open-Dat $name
		$gone = Remove-Retired $t $ids
		Write-Host "$name : $gone row(s) removed"
		if ($gone -eq 0) { Write-Host "$name : nothing to write" ; continue }
		if ($DryRun) { Write-Host "$name : dry run, nothing written" ; continue }
		Save-Dat $t
	}

	Write-Host ''
	Write-Host 'Done. Restart the client for it to reload system\*.dat.'
}
finally
{
	Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
