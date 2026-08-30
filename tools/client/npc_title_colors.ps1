<#
.SYNOPSIS
    Paints the title line an NPC carries above its head, by rewriting the
    client's npcname-e.dat.

.DESCRIPTION
    Interlude has no room for a color anywhere near an NPC : the NpcInfo packet
    carries none, and the name itself is drawn white by the engine. The one
    colored slot an NPC owns is its title, and its color lives client side, in
    npcname-e.dat, keyed by npc id. This script is what edits it.

    The file is a Lineage2Ver413 container : RSA (modulus + exponent 0x1d, both
    read straight out of the client's own l2.exe) over a zlib stream. It is
    decoded here, taken apart by l2disasm, patched, put back together by l2asm
    and re-encrypted by l2encdec, whose 413 pair is NCsoft's own - re-encoding
    an untouched file reproduces it byte for byte, which is the check this
    script runs on itself before it writes anything.

.PARAMETER ClientSystemDir
    The client's "system" folder, the one holding npcname-e.dat.

.PARAMETER Colors
    Table of "npcId RRGGBB" lines. Defaults to npc_title_colors.txt next to
    this script. '#' starts a comment.

.PARAMETER ToolsDir
    The "data" folder of L2 File Editor by CriticalError, which ships
    l2asm-disasm\ and l2encdec\. Only those three exes and one ddf are used.

.PARAMETER Ddf
    npcname-e.ddf to parse with. Defaults to the Interlude one in ToolsDir.

.PARAMETER DumpTo
    Write the decoded table to this path and stop, changing nothing. Use it to
    look up an id, or to see what colors an NPC has today.

.PARAMETER Out
    Write the result here instead of over the client's file. Implies -NoBackup.

.PARAMETER NoBackup
    Skip creating npcname-e.dat.orig.bak.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File npc_title_colors.ps1 `
        -ClientSystemDir "C:\l2\system"
#>
param(
	[Parameter(Mandatory = $true)][string] $ClientSystemDir,
	[string] $Colors,
	[string] $ToolsDir = "C:\Users\KRIVOSHEEC\Desktop\L2_File_Editor_2a__C4_to_Freya__by_CriticalError\data",
	[string] $Ddf,
	[string] $DumpTo,
	[string] $OutFile,
	[switch] $NoBackup
)

$ErrorActionPreference = 'Stop'

# --------------------------------------------------------------------------
# The client's own 413 key, as found in l2.exe. Decryption only - the matching
# private half lives in l2encdec, which is why encoding is delegated to it.
# --------------------------------------------------------------------------
$MODULUS_413 = "75b4d6de5c016544068a1acf125869f43d2e09fc55b8b1e289556daf9b8757635593446288b3653da1ce91c87bb1a5c18f16323495c55d7d72c0890a83f69bfd1fd9434eb1c02f3e4679edfa43309319070129c267c85604d87bb65bae205de3707af1d2108881abb567c3b3d069ae67c3a4c6a3aa93d26413d4c66094ae2039"
$EXPONENT_413 = 29   # 0x1d

function New-BigIntFromHex([string] $hex)
{
	$raw = New-Object byte[] ($hex.Length / 2)
	for ($i = 0; $i -lt $raw.Length; $i++)
	{
		$raw[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16)
	}
	[array]::Reverse($raw)      # BigInteger wants little endian
	$raw += 0                   # and an empty high byte, or it reads as negative
	return New-Object System.Numerics.BigInteger (, $raw)
}

# Undoes the RSA layer. Every 128 byte pack decodes to a 128 byte plaintext
# whose byte 3 says how much of it is payload ; the payload sits at the end,
# zero padded in front. l2encdec understates that length by 2 on the last pack,
# so its offset is taken from where the zero padding stops instead, and the
# result is checked against the size the stream itself declares.
function Read-EncryptedDat([string] $path)
{
	$bytes = [System.IO.File]::ReadAllBytes($path)
	$header = [System.Text.Encoding]::Unicode.GetString($bytes, 0, 28)
	if ($header -notlike "Lineage2Ver413*")
	{
		throw "$path is '$header', not a Lineage2Ver413 file."
	}

	$n = New-BigIntFromHex $MODULUS_413
	$e = [System.Numerics.BigInteger]::op_Implicit($EXPONENT_413)

	$packs = [Math]::Floor(($bytes.Length - 28) / 128)
	$stream = New-Object System.IO.MemoryStream

	for ($p = 0; $p -lt $packs; $p++)
	{
		$pack = New-Object byte[] 129
		[Array]::Copy($bytes, 28 + $p * 128, $pack, 0, 128)
		[array]::Reverse($pack, 0, 128)
		$pack[128] = 0

		$plain = ([System.Numerics.BigInteger]::ModPow((New-Object System.Numerics.BigInteger (, $pack)), $e, $n)).ToByteArray()
		$buf = New-Object byte[] 128
		[Array]::Copy($plain, 0, $buf, 0, [Math]::Min(128, $plain.Length))
		[array]::Reverse($buf)

		$size = $buf[3]
		if ($size -eq 124)
		{
			$off = 4
		}
		else
		{
			$off = 4
			while ($off -lt 128 -and $buf[$off] -eq 0) { $off++ }
		}
		$stream.Write($buf, $off, 128 - $off)
	}

	$deflated = $stream.ToArray()
	$declared = [BitConverter]::ToInt32($deflated, 0)

	$src = New-Object System.IO.MemoryStream (, $deflated)
	$null = $src.Seek(6, 'Begin')   # 4 bytes of size, 2 of zlib header
	$inflater = New-Object System.IO.Compression.DeflateStream($src, [System.IO.Compression.CompressionMode]::Decompress)
	$sink = New-Object System.IO.MemoryStream
	$chunk = New-Object byte[] 65536
	while (($read = $inflater.Read($chunk, 0, $chunk.Length)) -gt 0) { $sink.Write($chunk, 0, $read) }
	$inflater.Dispose()

	if ($sink.Length -ne $declared)
	{
		throw "Decoded $($sink.Length) bytes, the stream declares $declared. The file is not one this script understands."
	}
	return $sink.ToArray()
}

function Invoke-Tool([string] $exe, [string[]] $toolArgs)
{
	Push-Location (Split-Path $exe -Parent)   # the exes load their dlls from their own folder
	try
	{
		$output = & $exe @toolArgs 2>&1 | Out-String
		if ($LASTEXITCODE -ne 0)
		{
			throw "$(Split-Path $exe -Leaf) failed (exit $LASTEXITCODE) :`n$output"
		}
	}
	finally { Pop-Location }
}

# --------------------------------------------------------------------------

$dat = Join-Path $ClientSystemDir "npcname-e.dat"
if (!(Test-Path $dat)) { throw "No npcname-e.dat in $ClientSystemDir" }

$l2disasm = Join-Path $ToolsDir "l2asm-disasm\l2disasm.exe"
$l2asm = Join-Path $ToolsDir "l2asm-disasm\l2asm.exe"
$l2encdec = Join-Path $ToolsDir "l2encdec\l2encdec.exe"
if (!$Ddf) { $Ddf = Join-Path $ToolsDir "l2asm-disasm\DAT_defs\Interlude\npcname-e.ddf" }

foreach ($needed in @($l2disasm, $l2asm, $l2encdec, $Ddf))
{
	if (!(Test-Path $needed)) { throw "Missing $needed" }
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("npcname_" + [Guid]::NewGuid().ToString("N"))
$null = New-Item -ItemType Directory -Path $work

try
{
	$utf8 = New-Object System.Text.UTF8Encoding($false)

	Write-Host "Decoding $dat ..."
	[System.IO.File]::WriteAllBytes("$work\in.raw", (Read-EncryptedDat $dat))
	Invoke-Tool $l2disasm @("-d", $Ddf, "$work\in.raw", "$work\in.txt")

	$lines = [System.IO.File]::ReadAllLines("$work\in.txt", $utf8)
	Write-Host "  $($lines.Length - 1) records."

	if ($DumpTo)
	{
		Copy-Item "$work\in.txt" $DumpTo -Force
		Write-Host "Written to $DumpTo. Nothing else touched."
		return
	}

	# ---- the wanted colors -------------------------------------------------
	if (!$Colors) { $Colors = Join-Path $PSScriptRoot "npc_title_colors.txt" }
	if (!(Test-Path $Colors)) { throw "No color table at $Colors" }

	$wanted = @{ }
	foreach ($line in [System.IO.File]::ReadAllLines($Colors, $utf8))
	{
		$text = ($line -split '#', 2)[0].Trim()
		if (!$text) { continue }

		$parts = $text -split '\s+'
		if ($parts.Length -ne 2 -or $parts[0] -notmatch '^\d+$' -or $parts[1] -notmatch '^[0-9a-fA-F]{6}$')
		{
			throw "Cannot read '$line' in $Colors - a line is '<npcId> <RRGGBB>'."
		}
		$wanted[$parts[0]] = $parts[1].ToUpperInvariant()
	}
	Write-Host "  $($wanted.Count) color(s) to apply."

	# ---- apply -------------------------------------------------------------
	# Columns : id, name, description, rgb[0..2], reserved1. Those four bytes
	# are an Unreal FColor, so they are stored B, G, R, A - hence the reversal.
	$header = $lines[0] -split "`t"
	$colId = [array]::IndexOf($header, "id")
	$colB = [array]::IndexOf($header, "rgb[0]")
	$colG = [array]::IndexOf($header, "rgb[1]")
	$colR = [array]::IndexOf($header, "rgb[2]")
	if ($colId -lt 0 -or $colB -lt 0 -or $colG -lt 0 -or $colR -lt 0)
	{
		throw "Unexpected columns in the decoded table : $($lines[0])"
	}

	$hit = @{ }
	for ($i = 1; $i -lt $lines.Length; $i++)
	{
		if (!$lines[$i]) { continue }

		$cells = $lines[$i] -split "`t"
		$id = $cells[$colId]
		if (!$wanted.ContainsKey($id)) { continue }

		$rgb = $wanted[$id]
		$was = "{0:X2}{1:X2}{2:X2}" -f [Convert]::ToByte($cells[$colR], 16), [Convert]::ToByte($cells[$colG], 16), [Convert]::ToByte($cells[$colB], 16)
		# l2disasm prints CHEX with no leading zero, and the file has to read
		# back exactly as written for the check at the end to mean anything.
		$cells[$colR] = "{0:X}" -f [Convert]::ToByte($rgb.Substring(0, 2), 16)
		$cells[$colG] = "{0:X}" -f [Convert]::ToByte($rgb.Substring(2, 2), 16)
		$cells[$colB] = "{0:X}" -f [Convert]::ToByte($rgb.Substring(4, 2), 16)
		$lines[$i] = $cells -join "`t"

		$hit[$id] = $true
		Write-Host ("  {0} {1,-28} {2} -> {3}" -f $id, ($cells[2] -replace '^a,|\\0$', ''), $was, $rgb)
	}

	foreach ($id in $wanted.Keys)
	{
		if (!$hit.ContainsKey($id)) { throw "npc id $id is not in npcname-e.dat." }
	}

	# ---- back together -----------------------------------------------------
	[System.IO.File]::WriteAllLines("$work\out.txt", $lines, $utf8)
	Invoke-Tool $l2asm @("-d", $Ddf, "$work\out.txt", "$work\out.raw")
	Invoke-Tool $l2encdec @("-h", "413", "$work\out.raw", "$work\out.dat")

	# ---- and read it back, to be sure --------------------------------------
	[System.IO.File]::WriteAllBytes("$work\check.raw", (Read-EncryptedDat "$work\out.dat"))
	Invoke-Tool $l2disasm @("-d", $Ddf, "$work\check.raw", "$work\check.txt")
	$back = [System.IO.File]::ReadAllLines("$work\check.txt", $utf8)
	if ($back.Length -ne $lines.Length)
	{
		throw "The re-encoded file reads back as $($back.Length) lines instead of $($lines.Length). Nothing installed."
	}
	for ($i = 0; $i -lt $lines.Length; $i++)
	{
		if ($lines[$i] -cne $back[$i])
		{
			throw "The re-encoded file does not read back as what was written. Nothing installed.`n  line $i written : $($lines[$i])`n  line $i read    : $($back[$i])"
		}
	}
	Write-Host "Round trip verified."

	# ---- install -----------------------------------------------------------
	if ($OutFile)
	{
		Copy-Item "$work\out.dat" $OutFile -Force
		Write-Host "Written to $OutFile."
	}
	else
	{
		$backup = "$dat.orig.bak"
		if (!$NoBackup -and !(Test-Path $backup))
		{
			Copy-Item $dat $backup
			Write-Host "Backed the stock file up to $backup."
		}
		Copy-Item "$work\out.dat" $dat -Force
		Write-Host "Installed into $dat."
	}
}
finally
{
	Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
