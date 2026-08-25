<#
.SYNOPSIS
    Extracts the original UnrealScript sources out of a Lineage 2 client package (system\interface.u).

.DESCRIPTION
    The Interlude client ships interface.u with its UnrealScript sources still embedded: every compiled class
    carries a UTextBuffer export named "ScriptText" holding the .uc text it was built from. This script decrypts
    the "Lineage2Ver111" container (28 byte UTF-16 header, body XOR'ed with 0xAC, 20 byte plain trailer), walks
    the package and writes one .uc file per class.

    The result is a complete "Classes" folder, which is what ucc needs to rebuild the package - no need to hunt
    for a leaked Interface source pack.

.PARAMETER Package
    Path to the client package, e.g. C:\Lineage2\system\interface.u. Encrypted or already-plain files both work.

.PARAMETER OutDir
    Where to write the sources. A "Classes" subfolder is created, matching the layout ucc expects.

.EXAMPLE
    .\extract_interface_source.ps1 -Package 'C:\Lineage2\system\interface.u' -OutDir 'C:\l2mod\Interface'
#>
param(
    [Parameter(Mandatory = $true)][string]$Package,
    [Parameter(Mandatory = $true)][string]$OutDir
)

$ErrorActionPreference = 'Stop'

$raw = [System.IO.File]::ReadAllBytes($Package)

# Unwrap the Lineage2Ver111 container if present.
$script:b = $null
if ($raw.Length -gt 28) {
    $magic = [System.Text.Encoding]::Unicode.GetString($raw, 0, 28)
    if ($magic -eq 'Lineage2Ver111') {
        $n = $raw.Length - 28 - 20
        $script:b = New-Object byte[] $n
        for ($i = 0; $i -lt $n; $i++) { $script:b[$i] = [byte]($raw[$i + 28] -bxor 0xAC) }
        Write-Output "container: Lineage2Ver111 (XOR 0xAC), payload $n bytes"
    }
}
if ($null -eq $script:b) {
    $script:b = $raw
    Write-Output "container: none, treating the file as a plain package"
}

$script:pos = 0
function RdU32 { $v = [BitConverter]::ToUInt32($script:b, $script:pos); $script:pos += 4; return $v }
function RdI32 { $v = [BitConverter]::ToInt32($script:b, $script:pos); $script:pos += 4; return $v }
function RdU16 { $v = [BitConverter]::ToUInt16($script:b, $script:pos); $script:pos += 2; return $v }
function RdByte { $v = $script:b[$script:pos]; $script:pos += 1; return $v }
function RdIdx {
    $b0 = $script:b[$script:pos]; $script:pos++
    $neg = ($b0 -band 0x80) -ne 0
    $val = [int]($b0 -band 0x3F)
    if (($b0 -band 0x40) -ne 0) {
        $shift = 6
        for ($i = 0; $i -lt 4; $i++) {
            $bx = $script:b[$script:pos]; $script:pos++
            $val = $val -bor ([int]($bx -band 0x7F) -shl $shift)
            $shift += 7
            if (($bx -band 0x80) -eq 0) { break }
        }
    }
    if ($neg) { return - $val }
    return $val
}

$tag = RdU32
if (("{0:X8}" -f $tag) -ne '9E2A83C1') { throw ("not an Unreal package, signature 0x{0:X8}" -f $tag) }
$ver = RdU16; $lic = RdU16; $null = RdU32
$nameCount = RdU32; $nameOffset = RdU32
$exportCount = RdU32; $exportOffset = RdU32
$importCount = RdU32; $importOffset = RdU32
Write-Output ("package version {0}, licensee {1}, {2} exports" -f $ver, $lic, $exportCount)

$names = New-Object 'System.Collections.Generic.List[string]'
$script:pos = [int]$nameOffset
for ($i = 0; $i -lt $nameCount; $i++) {
    $len = RdByte
    $names.Add([System.Text.Encoding]::ASCII.GetString($script:b, $script:pos, [Math]::Max(0, $len - 1)))
    $script:pos += $len
    $null = RdU32
}

$exps = New-Object 'System.Collections.Generic.List[object]'
$script:pos = [int]$exportOffset
for ($i = 0; $i -lt $exportCount; $i++) {
    $null = RdIdx; $null = RdIdx
    $pk = RdI32
    $on = RdIdx; $null = RdU32
    $sz = RdIdx
    $off = 0
    if ($sz -gt 0) { $off = RdIdx }
    $exps.Add([pscustomobject]@{ PkgRef = $pk; Name = $names[$on]; Size = $sz; Offset = $off })
}

$classesDir = Join-Path $OutDir 'Classes'
if (-not (Test-Path $classesDir)) { New-Item -ItemType Directory -Force $classesDir | Out-Null }

$written = 0
foreach ($x in $exps) {
    if ($x.Name -ne 'ScriptText' -or $x.Size -le 0) { continue }
    if ($x.PkgRef -le 0) { continue }
    $owner = $exps[$x.PkgRef - 1].Name

    # UTextBuffer: empty property list, then Pos (int32), Top (int32), then the text as an FString.
    $script:pos = [int]$x.Offset
    $terminator = RdIdx
    if ($terminator -ne 0) { Write-Warning "$owner : unexpected property list, skipped"; continue }
    $null = RdI32   # Pos
    $null = RdI32   # Top
    $len = RdIdx
    if ($len -eq 0) { continue }

    $file = Join-Path $classesDir ($owner + '.uc')
    if ($len -gt 0) {
        # Single byte text. Written back byte for byte - the sources carry Korean comments in the
        # client's own codepage, and decoding them would lose bytes ucc still has to see.
        $bytes = New-Object byte[] ($len - 1)
        [Array]::Copy($script:b, $script:pos, $bytes, 0, $len - 1)
        [System.IO.File]::WriteAllBytes($file, $bytes)
    }
    else {
        $text = [System.Text.Encoding]::Unicode.GetString($script:b, $script:pos, ((-$len) - 1) * 2)
        [System.IO.File]::WriteAllText($file, $text, [System.Text.Encoding]::Unicode)
    }
    $written++
}

Write-Output ("extracted {0} classes to {1}" -f $written, $classesDir)
