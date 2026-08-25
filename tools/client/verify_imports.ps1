<#
.SYNOPSIS
    Checks that every import of a freshly built package resolves against the real client packages.

.DESCRIPTION
    A package compiled against stand-in dependencies can build cleanly and still fail to load, because an
    import ended up pointing at a package the client doesn't have that name in. This walks the import table,
    resolves each entry to "Package.Object", and looks the object up in the client's own .u files.

    Anything reported here would be a load failure in the client, so the list must come back empty.

.EXAMPLE
    .\verify_imports.ps1 -Package .\_build\System\Interface.u -ClientSystemDir 'C:\Lineage2\system'
#>
param(
    [Parameter(Mandatory = $true)][string]$Package,
    [Parameter(Mandatory = $true)][string]$ClientSystemDir
)

$ErrorActionPreference = 'Stop'

function Read-Package([string]$path) {
    $raw = [System.IO.File]::ReadAllBytes($path)
    $b = $raw
    if ($raw.Length -gt 28 -and [System.Text.Encoding]::Unicode.GetString($raw, 0, 28) -eq 'Lineage2Ver111') {
        $n = $raw.Length - 28 - 20
        $b = New-Object byte[] $n
        for ($i = 0; $i -lt $n; $i++) { $b[$i] = [byte]($raw[$i + 28] -bxor 0xAC) }
    }

    $script:buf = $b
    $script:p = 0
    function RdU32 { $v = [BitConverter]::ToUInt32($script:buf, $script:p); $script:p += 4; return $v }
    function RdI32 { $v = [BitConverter]::ToInt32($script:buf, $script:p); $script:p += 4; return $v }
    function RdU16 { $v = [BitConverter]::ToUInt16($script:buf, $script:p); $script:p += 2; return $v }
    function RdIdx {
        $b0 = $script:buf[$script:p]; $script:p++
        $neg = ($b0 -band 0x80) -ne 0
        $val = [int]($b0 -band 0x3F)
        if (($b0 -band 0x40) -ne 0) {
            $shift = 6
            for ($i = 0; $i -lt 4; $i++) {
                $bx = $script:buf[$script:p]; $script:p++
                $val = $val -bor ([int]($bx -band 0x7F) -shl $shift)
                $shift += 7
                if (($bx -band 0x80) -eq 0) { break }
            }
        }
        if ($neg) { return - $val }
        return $val
    }

    $null = RdU32; $null = RdU16; $null = RdU16; $null = RdU32
    $nameCount = RdU32; $nameOffset = RdU32
    $exportCount = RdU32; $exportOffset = RdU32
    $importCount = RdU32; $importOffset = RdU32

    $names = New-Object 'System.Collections.Generic.List[string]'
    $script:p = [int]$nameOffset
    for ($i = 0; $i -lt $nameCount; $i++) {
        $len = $script:buf[$script:p]; $script:p++
        $names.Add([System.Text.Encoding]::ASCII.GetString($script:buf, $script:p, [Math]::Max(0, $len - 1)))
        $script:p += $len
        $null = RdU32
    }

    $imports = New-Object 'System.Collections.Generic.List[object]'
    $script:p = [int]$importOffset
    for ($i = 0; $i -lt $importCount; $i++) {
        $null = RdIdx
        $cn = RdIdx
        $pk = RdI32
        $on = RdIdx
        $imports.Add([pscustomobject]@{ Class = $names[$cn]; Outer = $pk; Name = $names[$on] })
    }

    $exports = New-Object 'System.Collections.Generic.List[object]'
    $script:p = [int]$exportOffset
    for ($i = 0; $i -lt $exportCount; $i++) {
        $null = RdIdx; $null = RdIdx
        $pk = RdI32
        $on = RdIdx; $null = RdU32
        $sz = RdIdx
        if ($sz -gt 0) { $null = RdIdx }
        $exports.Add([pscustomobject]@{ Outer = $pk; Name = $names[$on] })
    }

    return [pscustomobject]@{ Imports = $imports; Exports = $exports }
}

$pkg = Read-Package $Package
Write-Output ("{0}: {1} imports, {2} exports" -f (Split-Path $Package -Leaf), $pkg.Imports.Count, $pkg.Exports.Count)

# Resolve each import to its root package plus the chain of names below it.
function Resolve-Import($imports, $idx) {
    $chain = @()
    $cur = $idx
    while ($cur -lt 0) {
        $imp = $imports[(-$cur) - 1]
        $chain = , $imp.Name + $chain
        $cur = $imp.Outer
    }
    return $chain
}

$needed = @{}
for ($i = 0; $i -lt $pkg.Imports.Count; $i++) {
    $imp = $pkg.Imports[$i]
    if ($imp.Class -eq 'Package' -and $imp.Outer -eq 0) { continue }   # the package itself
    $chain = Resolve-Import $pkg.Imports (-($i + 1))
    if ($chain.Count -lt 2) { continue }
    $root = $chain[0]
    $leaf = $chain[$chain.Count - 1]
    if (-not $needed.ContainsKey($root)) { $needed[$root] = New-Object 'System.Collections.Generic.HashSet[string]' }
    $null = $needed[$root].Add($leaf)
}

# Registered in C++ at startup instead of being serialized into Core.u, so they never show up as exports.
# Both a stock package and a freshly built one import them ; they are not a problem.
$intrinsic = @(
    'Class', 'Package', 'Field', 'Struct', 'State', 'Enum', 'Const', 'Function', 'TextBuffer', 'Property',
    'ByteProperty', 'IntProperty', 'BoolProperty', 'FloatProperty', 'ObjectProperty', 'NameProperty',
    'StrProperty', 'StringProperty', 'ArrayProperty', 'StructProperty', 'ClassProperty', 'FixedArrayProperty',
    'MapProperty', 'DelegateProperty', 'PointerProperty'
)

$problems = @()
foreach ($root in ($needed.Keys | Sort-Object)) {
    $candidate = Join-Path $ClientSystemDir "$root.u"
    if (-not (Test-Path $candidate)) {
        $problems += "package '$root' has no $root.u in the client"
        continue
    }
    $client = Read-Package $candidate
    # Unreal names are case insensitive, and the casing stored in a package is just whichever spelling got
    # registered first - so compare without case, or every differently-cased name reads as a false alarm.
    $have = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($x in $client.Exports) { $null = $have.Add($x.Name) }

    $missing = @($needed[$root] | Where-Object { -not $have.Contains($_) -and $intrinsic -notcontains $_ })
    $skipped = @($needed[$root] | Where-Object { -not $have.Contains($_) -and $intrinsic -contains $_ })
    Write-Output ("{0,-12} {1,4} names needed, {2} missing, {3} intrinsic" -f $root, $needed[$root].Count, $missing.Count, $skipped.Count)
    foreach ($m in $missing) { $problems += "$root.$m" }
}

Write-Output ''
if ($problems.Count -eq 0) {
    Write-Output 'OK - every import resolves against the client packages'
}
else {
    Write-Output ("UNRESOLVED ({0}):" -f $problems.Count)
    $problems | ForEach-Object { Write-Output "  $_" }
}
