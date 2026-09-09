<#
.SYNOPSIS
	Writes every id in weapongrp.dat to a plain list, one per line.

.DESCRIPTION
	tune_glow_keys.ps1 checks the id the cave reports against this before it writes a row for it.
	The id itself is not in doubt - [pawn+0x6A0] is the key the client looks weapongrp up by - but
	something in hand that is no weapon of the table reports its own id there just the same, and
	then there is no row to save against. The shape rides along so that a weapon that has moved to
	another rung of the ladder since the list was made is noticed rather than saved over.

	Re-run it whenever weapongrp changes ; a stale list only costs a warning.

.PARAMETER SystemDir
	The "system" directory of the client.

.PARAMETER ToolsDir
	Directory holding l2encdec\ and l2asm-disasm\ (the "data" directory of L2 File Editor).

.PARAMETER Out
	Where the list goes. Defaults to weapongrp_ids.txt next to this script, which is where
	tune_glow_keys.ps1 looks for it.

.EXAMPLE
	.\dump_weapongrp_ids.ps1 -SystemDir "C:\l2client\system" -ToolsDir "C:\tools\L2 File Editor\data"
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)][string] $SystemDir,
	[Parameter(Mandatory = $true)][string] $ToolsDir,
	[string] $Out
)

$ErrorActionPreference = 'Stop'

if (-not $Out) { $Out = Join-Path $PSScriptRoot 'weapongrp_ids.txt' }

$encdec = Join-Path $ToolsDir 'l2encdec\l2encdec.exe'
$disasm = Join-Path $ToolsDir 'l2asm-disasm\l2disasm.exe'
$ddfSrc = Join-Path $ToolsDir 'l2asm-disasm\DAT_defs\Interlude\weapongrp.ddf'
foreach ($p in $encdec, $disasm, $ddfSrc) { if (-not (Test-Path $p)) { throw "Missing $p." } }

$dat = Join-Path $SystemDir 'weapongrp.dat'
if (-not (Test-Path $dat)) { throw "Missing $dat." }

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("wgids_" + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $tmp
try
{
	& $encdec -d $dat (Join-Path $tmp 'wg.dec') | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "Can't decrypt $dat." }
	& $disasm -d $ddfSrc -e (Join-Path $tmp 'wg.ddf') (Join-Path $tmp 'wg.dec') (Join-Path $tmp 'wg.txt') | Out-Null
	if ($LASTEXITCODE -ne 0) { throw 'l2disasm failed on weapongrp.' }

	$lines = [System.IO.File]::ReadAllLines((Join-Path $tmp 'wg.txt'))
	$header = $lines[0].Split("`t")
	$idC = [Array]::IndexOf($header, 'id')
	if ($idC -lt 0) { throw 'weapongrp has no id column ; wrong ddf ?' }

	# The shape rides along with the id, so that a save can be checked against the shape the cave
	# graded independently - the one thing that says the list and the running client agree.
	$effC = [Array]::IndexOf($header, 'effA')
	if ($effC -lt 0) { throw 'weapongrp has no effA column ; wrong ddf ?' }

	$ids = [System.Collections.Generic.List[string]]::new()
	for ($i = 1; $i -lt $lines.Count; $i++)
	{
		$cells = $lines[$i].Split("`t")
		if ($cells.Count -le $idC -or $cells.Count -le $effC) { continue }
		$n = 0
		if (-not [int]::TryParse($cells[$idC], [ref]$n)) { continue }
		$shape = ''
		if ($cells[$effC] -match '^EnchantGlow\.enchant\d+_(\w+)$') { $shape = $Matches[1] }
		$null = $ids.Add("$n`t$shape")
	}

	# Not $out : that is the -Out parameter, typed [string], and assigning a list to it would
	# quietly stringify the list instead of replacing the path.
	$outLines = [System.Collections.Generic.List[string]]::new()
	$null = $outLines.Add("# id<TAB>glow shape, from $dat - $($ids.Count) rows, made by dump_weapongrp_ids.ps1")
	foreach ($n in ($ids | Sort-Object -Unique)) { $null = $outLines.Add("$n") }
	[System.IO.File]::WriteAllLines($Out, $outLines, (New-Object System.Text.UTF8Encoding $false))
	Write-Host "$($ids.Count) id(s) -> $Out"
}
finally
{
	Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
