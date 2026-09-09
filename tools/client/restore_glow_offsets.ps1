<#
.SYNOPSIS
	Puts retail's enchant glow offsets back into weapongrp.dat, out of a stock copy of the table.

.DESCRIPTION
	Next to the effect's NAME, weapongrp carries the numbers the client builds that effect with -
	where it sits relative to the weapon, how big it is and how fast its particles travel. Retail
	tuned them per weapon ; tune_enchant_glow.ps1 flattened them to one row per shape. This script
	is the way back : it copies that block, and only that block, out of a stock weapongrp.dat.

	**Only the numbers.** The effect names (effA / effB), the enchant mesh (rangeA / rangeB) and
	everything else the client half of the weapon ladder wrote stay exactly as they are - EnchantGlow
	keeps drawing, it just draws where retail put it.

	**The layout is not what the ddf says.** l2disasm's Interlude weapongrp.ddf splits the block into
	junk1A[5] / junk1B[5], as if each mesh got five floats of its own. It does not. The client writes
	one ARRAY PER FIELD, as many entries as the weapon has meshes:

	    one mesh   (5 floats)  offX offY offZ | scale | velocity
	    two meshes (10 floats) offX offY offZ offX offY offZ | scale scale | velocity velocity
	                           \--- mesh 0 ---/\--- mesh 1 --/  \-- 0  1 --/  \---- 0   1 ----/

	so a two-mesh weapon - a fist, a pair of dual swords, anything held in both hands - carries the
	whole ten. All ten cells are copied across as they stand, which is right either way : the source
	row is the same weapon with the same wpn_mesh_cnt, and the script refuses to run if it isn't.

	**The weapons generate.ps1 minted have no stock row**, so they take the block of the weapon they
	were cloned from, read out of tools\weapons\generated\client_items.tsv. Without it they would
	keep whatever their donor happened to hold on the day they were cloned.

	Same guards as the other dat patchers : l2disasm/l2asm round trip checked byte for byte before
	anything is written, and a rollback copy kept as weapongrp.dat.glowoffsets.bak.

	Note that tune_enchant_glow.ps1 overwrites this block on every glowing weapon, so running it
	again undoes this script.

.PARAMETER SystemDir
	The "system" directory of the client to patch.

.PARAMETER ToolsDir
	Directory holding l2encdec\ and l2asm-disasm\ (the "data" directory of L2 File Editor).

.PARAMETER Stock
	The untouched weapongrp.dat to read the numbers out of. Defaults to the weapongrp.dat.presets.bak
	the first patcher to run left in SystemDir.

.PARAMETER Items
	client_items.tsv, for the donor of every minted weapon. Defaults to the one generate.ps1 writes.

.PARAMETER DryRun
	Work out every edit and print the tally, but do not write the dat.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\client\restore_glow_offsets.ps1 `
	    -SystemDir "C:\l2client\system" `
	    -ToolsDir "C:\tools\L2 File Editor\data"
#>
param(
	[Parameter(Mandatory = $true)][string]$SystemDir,
	[Parameter(Mandatory = $true)][string]$ToolsDir,
	[string]$Stock = '',
	[string]$Items = '',
	[switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if ($Stock -eq '') { $Stock = Join-Path $SystemDir 'weapongrp.dat.presets.bak' }
if ($Items -eq '') { $Items = Join-Path (Split-Path -Parent $PSScriptRoot) 'weapons\generated\client_items.tsv' }

$encdec = Join-Path $ToolsDir 'l2encdec\l2encdec.exe'
$disasm = Join-Path $ToolsDir 'l2asm-disasm\l2disasm.exe'
$asm = Join-Path $ToolsDir 'l2asm-disasm\l2asm.exe'
$ddfSrc = Join-Path $ToolsDir 'l2asm-disasm\DAT_defs\Interlude\weapongrp.ddf'
foreach ($p in $encdec, $disasm, $asm, $ddfSrc) { if (-not (Test-Path $p)) { throw "Missing $p." } }

# The ten cells of the offset block, in table order. junk1A and junk1B are one array, not two.
$BLOCK = @('junk1A[0]', 'junk1A[1]', 'junk1A[2]', 'junk1A[3]', 'junk1A[4]',
	'junk1B[0]', 'junk1B[1]', 'junk1B[2]', 'junk1B[3]', 'junk1B[4]')

$UTF8 = New-Object System.Text.UTF8Encoding $false
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("glowoffsets_" + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $tmp

# Reads a weapongrp.dat into rows plus a column index, checking the round trip on the way. $tag only
# keeps the two files' scratch names apart.
function Open-Grp([string]$path, [string]$tag)
{
	if (-not (Test-Path $path)) { throw "Missing $path." }

	$dec = Join-Path $tmp "$tag.dec"
	$txt = Join-Path $tmp "$tag.txt"
	$ddf = Join-Path $tmp "$tag.ddf"

	& $encdec -d $path $dec | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "Can't decrypt $path." }

	& $disasm -d $ddfSrc -e $ddf $dec $txt | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "l2disasm failed on $path." }

	$check = Join-Path $tmp "$tag.check"
	& $asm -d $ddf $txt $check | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "l2asm failed on $path." }
	if ((Get-FileHash $check).Hash -ne (Get-FileHash $dec).Hash) { throw "$path : l2disasm/l2asm round trip isn't byte exact ; wrong ddf for this client ?" }

	$rows = [System.Collections.Generic.List[string]]::new()
	foreach ($l in [System.IO.File]::ReadAllLines($txt)) { $null = $rows.Add($l) }

	$cols = @{}
	$header = $rows[0].Split("`t")
	for ($i = 0; $i -lt $header.Count; $i++) { $cols[$header[$i]] = $i }
	foreach ($need in @('id', 'wpn_mesh_cnt') + $BLOCK)
	{
		if (-not $cols.ContainsKey($need)) { throw "$path has no $need column ; wrong ddf ?" }
	}

	Write-Host "$tag : $($rows.Count - 1) rows, round trip verified"
	@{ txt = $txt; ddf = $ddf; rows = $rows; cols = $cols }
}

try
{
	$src = Open-Grp $Stock 'stock'
	$dst = Open-Grp (Join-Path $SystemDir 'weapongrp.dat') 'weapongrp'

	$idC = $dst.cols['id']; $mcC = $dst.cols['wpn_mesh_cnt']
	$sIdC = $src.cols['id']; $sMcC = $src.cols['wpn_mesh_cnt']

	# id -> the stock row's ten cells, and the mesh count they belong to. Not $stock : PowerShell tells
	# no variable from another by case, and the -Stock parameter is typed [string].
	$retail = @{}
	for ($i = 1; $i -lt $src.rows.Count; $i++)
	{
		$c = $src.rows[$i].Split("`t")
		$vals = @()
		foreach ($n in $BLOCK) { $vals += $c[$src.cols[$n]] }
		$retail[[int]$c[$sIdC]] = @{ mesh = [int]$c[$sMcC]; vals = $vals }
	}

	# A minted weapon has no stock row of its own ; it stands in for the one it was cloned from.
	$donor = @{}
	if (Test-Path $Items)
	{
		foreach ($it in (Import-Csv $Items -Delimiter "`t"))
		{
			if ([int]$it.id -ne [int]$it.donor) { $donor[[int]$it.id] = [int]$it.donor }
		}
		Write-Host "$($donor.Count) minted weapon(s) mapped to a donor from $Items"
	}
	else { Write-Warning "No $Items ; minted weapons will be left alone." }

	$touched = 0
	$same = 0
	$unknown = [System.Collections.Generic.List[int]]::new()
	for ($i = 1; $i -lt $dst.rows.Count; $i++)
	{
		$c = $dst.rows[$i].Split("`t")
		$id = [int]$c[$idC]

		$from = $id
		if (-not $retail.ContainsKey($from) -and $donor.ContainsKey($id)) { $from = $donor[$id] }
		if (-not $retail.ContainsKey($from)) { $null = $unknown.Add($id) ; continue }

		$s = $retail[$from]
		if ($s.mesh -ne [int]$c[$mcC]) { throw "weapon $id has $([int]$c[$mcC]) mesh(es), the stock row $from has $($s.mesh) ; the block would not line up." }

		$changed = $false
		for ($k = 0; $k -lt $BLOCK.Count; $k++)
		{
			$col = $dst.cols[$BLOCK[$k]]
			if ($c[$col] -ne $s.vals[$k]) { $c[$col] = $s.vals[$k] ; $changed = $true }
		}
		if ($changed) { $dst.rows[$i] = $c -join "`t" ; $touched++ } else { $same++ }
	}

	Write-Host "weapongrp : $touched row(s) restored, $same already matched stock, $($unknown.Count) with no stock row"
	if ($unknown.Count) { Write-Host ("  no stock row for : " + (($unknown | Select-Object -First 20) -join ', ') + $(if ($unknown.Count -gt 20) { ' ...' } else { '' })) }

	if ($DryRun) { Write-Host 'dry run, nothing written' ; return }
	if ($touched -eq 0) { Write-Host 'nothing to write' ; return }

	$dat = Join-Path $SystemDir 'weapongrp.dat'
	$new = Join-Path $tmp 'weapongrp.new'
	$enc = Join-Path $tmp 'weapongrp.enc'
	$back = Join-Path $tmp 'weapongrp.back'

	[System.IO.File]::WriteAllText($dst.txt, (($dst.rows -join "`n") + "`n"), $UTF8)

	& $asm -d $dst.ddf $dst.txt $new | Out-Null
	if ($LASTEXITCODE -ne 0) { throw 'l2asm failed to rebuild weapongrp.' }

	& $encdec -e 413 $new $enc | Out-Null
	if ($LASTEXITCODE -ne 0) { throw 'l2encdec failed to encrypt weapongrp.' }

	& $encdec -d $enc $back | Out-Null
	if ($LASTEXITCODE -ne 0 -or (Get-FileHash $back).Hash -ne (Get-FileHash $new).Hash) { throw "weapongrp doesn't decrypt back to what was built." }

	$bak = "$dat.glowoffsets.bak"
	if (-not (Test-Path $bak)) { Copy-Item $dat $bak }
	Copy-Item $enc $dat -Force
	Write-Host "wrote $dat (rollback copy $bak)"
}
finally
{
	Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
