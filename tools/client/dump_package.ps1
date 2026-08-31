<#
.SYNOPSIS
    Lists what a Lineage 2 client package holds : its exports, their classes and their full paths.

.DESCRIPTION
    Reads a "Lineage2Ver111" package (28 byte UTF-16 header, body XOR'ed with 0xAC, 20 byte plain trailer), the
    same container extract_interface_source.ps1 unwraps, and walks the three tables every Unreal 2 package is
    built around : names, imports and exports.

    Where extract_interface_source.ps1 goes after the UnrealScript sources of a code package, this one answers
    "what is inside" for a content package - which is how LineageEffect.u was surveyed : 864 effect classes,
    each one a set of SpriteEmitter / MeshEmitter / BeamEmitter subobjects. See
    ../../docs/npc-visual-effects.md.

    Nothing is written to the client ; the package is only read.

.PARAMETER Package
    Path to the package, e.g. E:\client\system\LineageEffect.u. Encrypted or already-plain files both work.

.PARAMETER OutCsv
    Optional. Writes every export to a CSV : index, full path, name, class, serial size.

.PARAMETER ClassesOnly
    Only list the exports that are classes - for a content package, that is the list of effects it ships.

.EXAMPLE
    .\dump_package.ps1 -Package 'E:\client\system\LineageEffect.u' -ClassesOnly

.EXAMPLE
    .\dump_package.ps1 -Package 'E:\client\system\LineageEffect.u' -OutCsv .\lineageeffect.csv
#>
param(
    [Parameter(Mandatory = $true)][string]$Package,
    [string]$OutCsv,
    [switch]$ClassesOnly
)

$ErrorActionPreference = 'Stop'

$raw = [System.IO.File]::ReadAllBytes($Package)

# Unwrap the Lineage2Ver111 container if present.
$b = $raw
if ($raw.Length -gt 48 -and [System.Text.Encoding]::Unicode.GetString($raw, 0, 28) -eq 'Lineage2Ver111') {
    $n = $raw.Length - 28 - 20
    $b = New-Object byte[] $n
    for ($i = 0; $i -lt $n; $i++) { $b[$i] = [byte]($raw[$i + 28] -bxor 0xAC) }
    Write-Output "container: Lineage2Ver111 (XOR 0xAC), payload $n bytes"
}

$script:pos = 0
function Read-Byte { $v = $b[$script:pos]; $script:pos++; return $v }
function Read-Int32 { $v = [BitConverter]::ToInt32($b, $script:pos); $script:pos += 4; return $v }
function Read-UInt32 { $v = [BitConverter]::ToUInt32($b, $script:pos); $script:pos += 4; return $v }
function Read-UInt16 { $v = [BitConverter]::ToUInt16($b, $script:pos); $script:pos += 2; return $v }

# Unreal's compact index : first byte carries the sign in bit 7 and 6 value bits, the next ones 7 each.
function Read-Index {
    $b0 = Read-Byte
    $negative = ($b0 -band 0x80) -ne 0
    $value = [int]($b0 -band 0x3F)
    if (($b0 -band 0x40) -ne 0) {
        $shift = 6
        do {
            $c = Read-Byte
            $value = $value -bor ([int]($c -band 0x7F) -shl $shift)
            $shift += 7
        } while ((($c -band 0x80) -ne 0) -and ($shift -lt 32))
    }
    if ($negative) { return - $value }
    return $value
}

# 0x9E2A83C1 is written as a signed literal, PowerShell reads hex as Int32.
if ((Read-UInt32) -ne 2653586369) { throw "$Package is not an Unreal package." }

$version = Read-UInt16
$licensee = Read-UInt16
$null = Read-UInt32 # package flags
$nameCount = Read-Int32
$nameOffset = Read-Int32
$exportCount = Read-Int32
$exportOffset = Read-Int32
$importCount = Read-Int32
$importOffset = Read-Int32

Write-Output "version $version, licensee $licensee : $nameCount names, $importCount imports, $exportCount exports"

# Names.
$script:pos = $nameOffset
$names = New-Object string[] $nameCount
for ($i = 0; $i -lt $nameCount; $i++) {
    $len = Read-Index
    $names[$i] = [System.Text.Encoding]::ASCII.GetString($b, $script:pos, [Math]::Max(0, $len - 1))
    $script:pos += $len
    $null = Read-UInt32 # name flags
}

# Imports - needed to name a class that lives in another package.
$script:pos = $importOffset
$imports = @()
for ($i = 0; $i -lt $importCount; $i++) {
    $classPackage = Read-Index
    $className = Read-Index
    $package = Read-Int32
    $objectName = Read-Index
    $imports += [pscustomobject]@{
        ClassPackage = $names[$classPackage]
        ClassName    = $names[$className]
        Package      = $package
        Name         = $names[$objectName]
    }
}

# Exports.
$script:pos = $exportOffset
$exports = @()
for ($i = 0; $i -lt $exportCount; $i++) {
    $classIndex = Read-Index
    $null = Read-Index # super
    $group = Read-Int32
    $objectName = Read-Index
    $null = Read-UInt32 # object flags
    $size = Read-Index
    $offset = 0
    if ($size -gt 0) { $offset = Read-Index }

    # A null class index means the export is a class itself.
    $className = 'Class'
    if ($classIndex -lt 0) { $className = $imports[(-$classIndex) - 1].Name }
    elseif ($classIndex -gt 0) { $className = $exports[$classIndex - 1].Name }

    $exports += [pscustomobject]@{
        Index  = $i + 1
        Name   = $names[$objectName]
        Class  = $className
        Group  = $group
        Size   = $size
        Offset = $offset
        Full   = $names[$objectName]
    }
}

# Walk the group chain, so a subobject shows up as "class.subobject".
foreach ($export in $exports) {
    $path = $export.Name
    $group = $export.Group
    $guard = 0
    while ($group -ne 0 -and $guard -lt 8) {
        if ($group -gt 0) {
            $parent = $exports[$group - 1]
            $path = "$($parent.Name).$path"
            $group = $parent.Group
        }
        else {
            $parent = $imports[(-$group) - 1]
            $path = "$($parent.Name).$path"
            $group = $parent.Package
        }
        $guard++
    }
    $export.Full = $path
}

if ($OutCsv) {
    $exports | Select-Object Index, Full, Name, Class, Size | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8
    Write-Output "written: $OutCsv"
}

if ($ClassesOnly) {
    $exports | Where-Object { $_.Class -eq 'Class' } | Select-Object -ExpandProperty Name | Sort-Object
}
else {
    Write-Output '--- exports by class:'
    $exports | Group-Object Class | Sort-Object Count -Descending | Select-Object Count, Name | Format-Table -AutoSize
}
