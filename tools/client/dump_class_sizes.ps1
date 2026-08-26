<#
.SYNOPSIS
    Lists the size of every UClass export of a Lineage 2 client package.

.DESCRIPTION
    A class export is the blob holding the class metadata and its defaultproperties - the values NCsoft does
    not store in ScriptText and extract_defaults.ps1 has to recover. Comparing these sizes against a package
    known to be good is the offline check that catches a class which came out of the compiler with its
    defaults blank : the client then loads, but comes up with no loading screen, an empty inventory and a
    stutter every few seconds.

    The size does not move when only code changes, so a class you edited without touching its defaults is
    expected to come out identical. See README.md, "Verifying".

.PARAMETER Package
    Path to the package, encrypted (Lineage2Ver111) or already plain.

.EXAMPLE
    # every class that changed between the stock package and a fresh build
    $s = .\dump_class_sizes.ps1 -Package '<client>\system\interface.u.orig.bak'
    $b = .\dump_class_sizes.ps1 -Package .\_build\System\Interface.u
    Compare-Object $s $b
#>
param([Parameter(Mandatory = $true)][string]$Package)

$ErrorActionPreference = 'Stop'

$raw = [System.IO.File]::ReadAllBytes($Package)

# Unwrap the Lineage2Ver111 container if present : 28 byte UTF-16 header, body XOR'ed with 0xAC, 20 byte trailer.
$script:b = $null
if ($raw.Length -gt 28) {
    $magic = [System.Text.Encoding]::Unicode.GetString($raw, 0, 28)
    if ($magic -eq 'Lineage2Ver111') {
        $n = $raw.Length - 28 - 20
        $script:b = New-Object byte[] $n
        for ($i = 0; $i -lt $n; $i++) { $script:b[$i] = [byte]($raw[$i + 28] -bxor 0xAC) }
    }
}
if ($null -eq $script:b) { $script:b = $raw }

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
$null = RdU16; $null = RdU16; $null = RdU32
$nameCount = RdU32; $nameOffset = RdU32
$exportCount = RdU32; $exportOffset = RdU32
$null = RdU32; $null = RdU32

$names = New-Object 'System.Collections.Generic.List[string]'
$script:pos = [int]$nameOffset
for ($i = 0; $i -lt $nameCount; $i++) {
    $len = RdByte
    $names.Add([System.Text.Encoding]::ASCII.GetString($script:b, $script:pos, [Math]::Max(0, $len - 1)))
    $script:pos += $len
    $null = RdU32
}

# An export whose class reference is 0 (None) is a UClass ; anything else is a function, a property, a buffer.
$script:pos = [int]$exportOffset
for ($i = 0; $i -lt $exportCount; $i++) {
    $cls = RdIdx; $null = RdIdx
    $null = RdI32
    $on = RdIdx; $null = RdU32
    $sz = RdIdx
    if ($sz -gt 0) { $null = RdIdx }
    if ($cls -eq 0) { Write-Output ("{0} {1}" -f $names[$on], $sz) }
}
