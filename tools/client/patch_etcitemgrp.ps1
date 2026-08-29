<#
.SYNOPSIS
	Marks items as stackable in the client table etcitemgrp.dat.

.DESCRIPTION
	Whether a stack can be split - the "how many ?" pad on drop, destroy, trade, private store and
	warehouse - is decided by the client alone, out of the consume type it reads from its own
	etcitemgrp.dat ("stackable" column). The server never sends that flag, so is_stackable in
	data/xml/items alone gives stacks the player can't split.

	This script rewrites that column for the item ids given, by way of the l2encdec / l2disasm /
	l2asm trio. It defaults to the enchant scrolls of AbstractEnchantPacket and the life stones of
	AbstractRefinePacket, which is what the datapack marks stackable.

	See docs/stackable-scrolls-and-life-stones.md.

.PARAMETER SystemDir
	The "system" directory of the client to patch. The original file is kept next to it as
	etcitemgrp.dat.prestack.bak, and a file already carrying that backup is left alone.

.PARAMETER ToolsDir
	Directory holding l2encdec\ and l2asm-disasm\ (the "data" directory of L2 File Editor).

.PARAMETER Ids
	Item ids to make stackable. Defaults to the 30 enchant scrolls and the 40 life stones.

.PARAMETER ConsumeType
	Value written into the column : 0 normal, 2 stackable, 3 asset (adena). Defaults to 2.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\client\patch_etcitemgrp.ps1 `
	    -SystemDir "C:\l2client\system" `
	    -ToolsDir "C:\tools\L2 File Editor\data"
#>
param(
	[Parameter(Mandatory = $true)][string]$SystemDir,
	[Parameter(Mandatory = $true)][string]$ToolsDir,
	[int[]]$Ids = (@(729, 730, 731, 732) + (947..962) + (6569..6578) + (8723..8762)),
	[int]$ConsumeType = 2
)

$ErrorActionPreference = 'Stop'

$encdec = Join-Path $ToolsDir 'l2encdec\l2encdec.exe'
$disasm = Join-Path $ToolsDir 'l2asm-disasm\l2disasm.exe'
$asm = Join-Path $ToolsDir 'l2asm-disasm\l2asm.exe'
$ddf = Join-Path $ToolsDir 'l2asm-disasm\DAT_defs\Interlude\etcitemgrp.ddf'

foreach ($exe in $encdec, $disasm, $asm, $ddf)
{
	if (-not (Test-Path $exe)) { throw "Missing $exe." }
}

$dat = Join-Path $SystemDir 'etcitemgrp.dat'
$bak = "$dat.prestack.bak"
if (-not (Test-Path $dat)) { throw "Missing $dat." }

# Always work from the stock file, so that running the script twice doesn't stack backups.
$src = if (Test-Path $bak) { $bak } else { $dat }

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("etcitemgrp_" + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $tmp

try
{
	$dec = Join-Path $tmp 'dec.dat'
	$txt = Join-Path $tmp 'table.txt'
	$exp = Join-Path $tmp 'export.ddf'
	$new = Join-Path $tmp 'new.dat'
	$enc = Join-Path $tmp 'enc.dat'

	# ---------------------------------------------------------------------------
	# Decrypt. A client whose dats were re-encrypted by l2encdec needs -d, a stock one -l.
	# ---------------------------------------------------------------------------

	& $encdec -d $src $dec | Out-Null
	$rsa = 'new'
	if ($LASTEXITCODE -ne 0)
	{
		& $encdec -l $src $dec | Out-Null
		$rsa = 'original'

		if ($LASTEXITCODE -ne 0) { throw "Can't decrypt $src." }

		# The original 41x keys are decrypt only : re-encrypting gives a file the client refuses,
		# unless its l2.exe was patched (l2encdec's patcher -n) to hold l2encdec's own modulus.
		Write-Warning "$src is encrypted with L2's original keys. The rebuilt file will use l2encdec's key pair, which only a patched client can read."
	}
	Write-Host "decrypted ($rsa keys)"

	# ---------------------------------------------------------------------------
	# The table as text. -e exports the ddf with the SOFT properties l2asm requires.
	# ---------------------------------------------------------------------------

	& $disasm -d $ddf -e $exp $dec $txt | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "l2disasm failed." }

	# The round trip must be byte exact before we alter anything, otherwise every unrelated record
	# of the table silently rides along with our edit.
	$check = Join-Path $tmp 'check.dat'
	& $asm -d $exp $txt $check | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "l2asm failed." }
	if ((Get-FileHash $check).Hash -ne (Get-FileHash $dec).Hash) { throw "l2disasm/l2asm round trip isn't byte exact ; wrong ddf for this client ?" }

	Write-Host "round trip verified"

	# ---------------------------------------------------------------------------
	# The edit itself
	# ---------------------------------------------------------------------------

	# l2disasm writes UTF-8 with LF endings and a trailing newline ; write the file back the same way.
	$rows = [System.IO.File]::ReadAllLines($txt)
	$header = $rows[0].Split("`t")
	$idCol = [array]::IndexOf($header, 'id')
	$stCol = [array]::IndexOf($header, 'stackable')
	if ($idCol -lt 0 -or $stCol -lt 0) { throw "No id/stackable column in the disassembled table." }

	$wanted = New-Object 'System.Collections.Generic.HashSet[int]' (,[int[]]$Ids)
	$seen = New-Object 'System.Collections.Generic.HashSet[int]'
	$changed = 0

	for ($i = 1; $i -lt $rows.Count; $i++)
	{
		$cells = $rows[$i].Split("`t")
		if ($cells.Count -le $stCol) { continue }

		$id = [int]$cells[$idCol]
		if (-not $wanted.Contains($id)) { continue }

		$null = $seen.Add($id)
		if ($cells[$stCol] -eq "$ConsumeType") { continue }

		$cells[$stCol] = "$ConsumeType"
		$rows[$i] = $cells -join "`t"
		$changed++
	}

	$missing = $Ids | Where-Object { -not $seen.Contains($_) }
	if ($missing) { throw "not in etcitemgrp.dat : $($missing -join ', ')" }

	Write-Host "$($seen.Count) items found, $changed rewritten"
	if ($changed -eq 0) { Write-Host "nothing to do." ; return }

	[System.IO.File]::WriteAllText($txt, ($rows -join "`n") + "`n", (New-Object System.Text.UTF8Encoding $false))

	# ---------------------------------------------------------------------------
	# Back to a dat
	# ---------------------------------------------------------------------------

	& $asm -d $exp $txt $new | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "l2asm failed." }

	& $encdec -e 413 $new $enc | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "l2encdec failed to encrypt." }

	# Read the result back and compare it to what we meant to write.
	$back = Join-Path $tmp 'back.dat'
	& $encdec -d $enc $back | Out-Null
	if ($LASTEXITCODE -ne 0 -or (Get-FileHash $back).Hash -ne (Get-FileHash $new).Hash) { throw "The encrypted file doesn't decrypt back to what was built." }

	if (-not (Test-Path $bak)) { Copy-Item $dat $bak }
	Copy-Item $enc $dat -Force

	Write-Host "wrote $dat (stock file kept as $bak)"
}
finally
{
	Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
