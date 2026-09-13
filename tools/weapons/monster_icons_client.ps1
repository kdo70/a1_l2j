<#
.SYNOPSIS
	Gives the weapons of monster_only.csv the monster icon in the client's weapongrp.dat.

.DESCRIPTION
	The icon an item wears in the inventory and the shop comes from weapongrp.dat (icon[0..4]), not
	from the server. The datapack half - data/xml/itemIcons.xml, which the drop list window reads -
	carries weapon_monster_i00 for these ids already.

	What goes into the five cells is not guessed : they are copied off a weapon that already wears the
	monster icon (-Donor, 6715 "Monster Only(Silenos Archer)" by default), so an empty slot is written
	exactly the way this table writes one.

	Same guards as patch_client.ps1 : l2disasm/l2asm round trip checked byte for byte, rollback copy
	weapongrp.dat.monstericon.bak. A rerun changes nothing.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\weapons\monster_icons_client.ps1 `
	    -SystemDir "C:\Users\KRIVOSHEEC\Desktop\1\system" `
	    -ToolsDir  "C:\Users\KRIVOSHEEC\Desktop\L2_File_Editor_2a__C4_to_Freya__by_CriticalError\data"
#>
param(
	[Parameter(Mandatory = $true)][string]$SystemDir,
	[Parameter(Mandatory = $true)][string]$ToolsDir,
	[int]$Donor = 6715
)

$ErrorActionPreference = 'Stop'

$MONSTER_ICON = 'weapon_monster_i00'

$encdec = Join-Path $ToolsDir 'l2encdec\l2encdec.exe'
$disasm = Join-Path $ToolsDir 'l2asm-disasm\l2disasm.exe'
$asm = Join-Path $ToolsDir 'l2asm-disasm\l2asm.exe'
$ddfSrc = Join-Path $ToolsDir 'l2asm-disasm\DAT_defs\Interlude\weapongrp.ddf'
foreach ($p in $encdec, $disasm, $asm, $ddfSrc) { if (-not (Test-Path $p)) { throw "Missing $p." } }

$targets = @{}
foreach ($r in Import-Csv (Join-Path $PSScriptRoot 'monster_only.csv')) { $targets[[int]$r.id] = $r.name }
if ($targets.Count -eq 0) { throw 'monster_only.csv is empty.' }

$dat = Join-Path $SystemDir 'weapongrp.dat'
if (-not (Test-Path $dat)) { throw "Missing $dat." }

$UTF8 = New-Object System.Text.UTF8Encoding $false
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("monstericon_" + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $tmp

try
{
	$dec = Join-Path $tmp 'weapongrp.dec'
	$txt = Join-Path $tmp 'weapongrp.txt'
	$ddf = Join-Path $tmp 'weapongrp.ddf'

	& $encdec -d $dat $dec | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "Can't decrypt $dat." }
	& $disasm -d $ddfSrc -e $ddf $dec $txt | Out-Null
	if ($LASTEXITCODE -ne 0) { throw 'l2disasm failed on weapongrp.' }
	$check = Join-Path $tmp 'weapongrp.check'
	& $asm -d $ddf $txt $check | Out-Null
	if ($LASTEXITCODE -ne 0) { throw 'l2asm failed on weapongrp.' }
	if ((Get-FileHash $check).Hash -ne (Get-FileHash $dec).Hash) { throw "weapongrp : l2disasm/l2asm round trip isn't byte exact ; wrong ddf for this client ?" }

	$rows = [System.Collections.Generic.List[string]]::new()
	foreach ($l in [System.IO.File]::ReadAllLines($txt)) { $null = $rows.Add($l) }
	$header = $rows[0].Split("`t")
	$cols = @{}
	for ($i = 0; $i -lt $header.Count; $i++) { $cols[$header[$i]] = $i }
	if (-not $cols.ContainsKey('id')) { throw 'weapongrp has no id column ; wrong ddf ?' }
	$idC = $cols['id']
	# l2disasm writes only as many cells of an array as the data fills, so take whatever icon[n] exist.
	$iconCols = @($header | Where-Object { $_ -match '^icon\[\d+\]$' } | ForEach-Object { $cols[$_] })
	if ($iconCols.Count -eq 0) { throw 'weapongrp has no icon[n] column ; wrong ddf ?' }
	Write-Host "weapongrp : $($rows.Count - 1) rows, round trip verified, $($iconCols.Count) icon column(s)"

	$donorCells = $null
	for ($i = 1; $i -lt $rows.Count; $i++)
	{
		$c = $rows[$i].Split("`t")
		if ([int]$c[$idC] -eq $Donor) { $donorCells = $c ; break }
	}
	if ($null -eq $donorCells) { throw "weapongrp has no row for donor $Donor." }
	if ($donorCells[$iconCols[0]] -notmatch [regex]::Escape($MONSTER_ICON)) { throw "donor $Donor wears '$($donorCells[$iconCols[0]])', not $MONSTER_ICON." }
	Write-Host "donor $Donor : $(($iconCols | ForEach-Object { "'$($donorCells[$_])'" }) -join ' ')"

	$found = @{}
	$changed = 0
	for ($i = 1; $i -lt $rows.Count; $i++)
	{
		$c = $rows[$i].Split("`t")
		$id = [int]$c[$idC]
		if (-not $targets.ContainsKey($id)) { continue }
		$found[$id] = $true
		$was = $c[$iconCols[0]]
		$hit = $false
		foreach ($k in $iconCols) { if ($c[$k] -ne $donorCells[$k]) { $c[$k] = $donorCells[$k] ; $hit = $true } }
		if (-not $hit) { continue }
		$rows[$i] = $c -join "`t"
		$changed++
		Write-Host ("  {0,4} {1,-18} {2} -> {3}" -f $id, $targets[$id], $was, $c[$iconCols[0]])
	}
	foreach ($id in $targets.Keys) { if (-not $found.ContainsKey($id)) { Write-Warning "id $id ($($targets[$id])) is not in weapongrp." } }
	Write-Host "weapongrp : $changed row(s) given the monster icon"
	if ($changed -eq 0) { Write-Host 'nothing to write' ; return }

	$new = Join-Path $tmp 'weapongrp.new'
	$enc = Join-Path $tmp 'weapongrp.enc'
	$back = Join-Path $tmp 'weapongrp.back'
	[System.IO.File]::WriteAllText($txt, (($rows -join "`n") + "`n"), $UTF8)
	& $asm -d $ddf $txt $new | Out-Null
	if ($LASTEXITCODE -ne 0) { throw 'l2asm failed to rebuild weapongrp.' }
	& $encdec -e 413 $new $enc | Out-Null
	if ($LASTEXITCODE -ne 0) { throw 'l2encdec failed to encrypt weapongrp.' }
	& $encdec -d $enc $back | Out-Null
	if ($LASTEXITCODE -ne 0 -or (Get-FileHash $back).Hash -ne (Get-FileHash $new).Hash) { throw "weapongrp doesn't decrypt back to what was built." }

	$bak = "$dat.monstericon.bak"
	if (-not (Test-Path $bak)) { Copy-Item $dat $bak }
	Copy-Item $enc $dat -Force
	Write-Host "wrote $dat (rollback copy $bak)"
}
finally
{
	Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
