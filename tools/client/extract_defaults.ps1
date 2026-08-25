<#
.SYNOPSIS
    Recovers the defaultproperties blocks a client package holds and appends them to the extracted sources.

.DESCRIPTION
    The UnrealScript sources embedded in a client package (ScriptText) contain the code only - NCsoft does not
    store the defaultproperties block there. Recompiling from those sources therefore produces classes with all
    their default values blank, which quietly breaks the UI: LoadingWnd loses its textures, every window loses
    its m_WindowName, and so on.

    The values themselves are still in the package: a UClass export ends with the class defaults, serialized as
    Unreal's tagged property list. This walks that list and writes it back out as a defaultproperties block at
    the end of each .uc, so a rebuild reproduces the original class blob.

    Finding where the defaults start inside the UClass blob is done by trying every offset and keeping the first
    that parses cleanly to the end of the export. That can latch onto preceding bytes by accident, so entries are
    then filtered against the variables the class actually declares (its own and its ancestors'), which the
    sources give us. Junk never survives that check.

.PARAMETER Package
    The client package to read the defaults from, e.g. system\interface.u.

.PARAMETER SourceDirs
    Folders holding the extracted Classes ; the first one is written to, the rest only supply var declarations
    for inheritance. Example: .\Interface,.\NWindow

.EXAMPLE
    .\extract_defaults.ps1 -Package 'C:\Lineage2\system\interface.u' -SourceDirs .\Interface,.\NWindow
#>
param(
    [Parameter(Mandatory = $true)][string]$Package,
    [Parameter(Mandatory = $true)][string[]]$SourceDirs,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$latin1 = [System.Text.Encoding]::GetEncoding(28591)

# ---------- sources: class -> parent, class -> declared vars ----------
$parent = @{}
$vars = @{}
$fileOf = @{}
foreach ($dir in $SourceDirs) {
    $cd = Join-Path $dir 'Classes'
    if (-not (Test-Path $cd)) { throw "not found: $cd" }
    foreach ($f in Get-ChildItem $cd -Filter '*.uc') {
        $t = $latin1.GetString([System.IO.File]::ReadAllBytes($f.FullName))
        $cls = $f.BaseName
        if (-not $fileOf.ContainsKey($cls)) { $fileOf[$cls] = $f.FullName }
        $m = [regex]::Match($t, '(?im)^\s*class\s+([A-Za-z_]\w*)\s+extends\s+([A-Za-z_]\w*)')
        if ($m.Success) { $parent[$cls] = $m.Groups[2].Value }
        $set = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($vm in [regex]::Matches($t, '(?im)^\s*var(?:\s*\([^)]*\))?\s+[^;]*?([A-Za-z_]\w*)\s*(?:\[[^\]]*\])?\s*;')) {
            $null = $set.Add($vm.Groups[1].Value)
        }
        # a var line can declare several names at once
        foreach ($vm in [regex]::Matches($t, '(?im)^\s*var(?:\s*\([^)]*\))?\s+([^;]*);')) {
            foreach ($nm in [regex]::Matches($vm.Groups[1].Value, '([A-Za-z_]\w*)\s*(?:\[[^\]]*\])?\s*(?:,|$)')) {
                $null = $set.Add($nm.Groups[1].Value)
            }
        }
        $vars[$cls] = $set
    }
}
function AllowedVars($cls) {
    $acc = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $cur = $cls
    $guard = 0
    while ($cur -and $vars.ContainsKey($cur) -and $guard -lt 50) {
        foreach ($v in $vars[$cur]) { $null = $acc.Add($v) }
        if (-not $parent.ContainsKey($cur)) { break }
        $cur = $parent[$cur]; $guard++
    }
    return $acc
}

# ---------- package ----------
$b = [System.IO.File]::ReadAllBytes($Package)
if ($b.Length -gt 28 -and [System.Text.Encoding]::Unicode.GetString($b, 0, 28) -eq 'Lineage2Ver111') {
    $n = $b.Length - 28 - 20
    $d = New-Object byte[] $n
    for ($i = 0; $i -lt $n; $i++) { $d[$i] = [byte]($b[$i + 28] -bxor 0xAC) }
    $b = $d
}
$script:buf = $b; $script:p = 0
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
            $val = $val -bor ([int]($bx -band 0x7F) -shl $shift); $shift += 7
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
    $script:p += $len; $null = RdU32
}
$imports = New-Object 'System.Collections.Generic.List[string]'
$script:p = [int]$importOffset
for ($i = 0; $i -lt $importCount; $i++) { $null = RdIdx; $null = RdIdx; $null = RdI32; $on = RdIdx; $imports.Add($names[$on]) }
$exports = New-Object 'System.Collections.Generic.List[object]'
$script:p = [int]$exportOffset
for ($i = 0; $i -lt $exportCount; $i++) {
    $cl = RdIdx; $null = RdIdx; $null = RdI32; $on = RdIdx; $null = RdU32
    $sz = RdIdx; $off = 0
    if ($sz -gt 0) { $off = RdIdx }
    $exports.Add([pscustomobject]@{ ClassRef = $cl; Name = $names[$on]; Size = $sz; Offset = $off })
}
function ObjName($r) {
    if ($r -gt 0) { return $exports[$r - 1].Name }
    if ($r -lt 0) { return $imports[(-$r) - 1] }
    return 'None'
}

$TYPES = @{ 1 = 'Byte'; 2 = 'Int'; 3 = 'Bool'; 4 = 'Float'; 5 = 'Object'; 6 = 'Name'; 7 = 'String';
    8 = 'Class'; 9 = 'Array'; 10 = 'Struct'; 11 = 'Vector'; 12 = 'Rotator'; 13 = 'Str'; 14 = 'Map'; 15 = 'FixedArray'
}

function ParseTagged($start, $end) {
    $script:p = $start
    $out = New-Object 'System.Collections.Generic.List[object]'
    while ($true) {
        if ($script:p -ge $end) { return $null }
        $ni = RdIdx
        if ($ni -lt 0 -or $ni -ge $names.Count) { return $null }
        if ($names[$ni] -eq 'None') { if ($script:p -eq $end) { return $out } else { return $null } }
        if ($script:p -ge $end) { return $null }
        $info = $script:buf[$script:p]; $script:p++
        $type = $info -band 0x0F
        $sizeBits = ($info -shr 4) -band 0x07
        $isArray = ($info -band 0x80) -ne 0
        if (-not $TYPES.ContainsKey($type)) { return $null }
        $structName = ''
        if ($type -eq 10) { $si = RdIdx; if ($si -lt 0 -or $si -ge $names.Count) { return $null }; $structName = $names[$si] }
        switch ($sizeBits) {
            0 { $size = 1 } 1 { $size = 2 } 2 { $size = 4 } 3 { $size = 12 } 4 { $size = 16 }
            5 { $size = $script:buf[$script:p]; $script:p++ }
            6 { $size = [BitConverter]::ToUInt16($script:buf, $script:p); $script:p += 2 }
            7 { $size = [BitConverter]::ToInt32($script:buf, $script:p); $script:p += 4 }
        }
        $arrIdx = 0
        if ($isArray -and $type -ne 3) { $arrIdx = $script:buf[$script:p]; $script:p++ }
        if ($type -eq 3) { $size = 0 }
        if ($size -lt 0 -or ($script:p + $size) -gt $end) { return $null }
        $valStart = $script:p
        $val = $null; $ok = $true
        switch ($type) {
            1 { $val = $script:buf[$valStart] }
            2 { $val = [BitConverter]::ToInt32($script:buf, $valStart) }
            3 { $val = $isArray }
            4 { $val = [BitConverter]::ToSingle($script:buf, $valStart) }
            5 { $save = $script:p; $r = RdIdx; $val = (ObjName $r); $script:p = $save }
            6 { $save = $script:p; $r = RdIdx; if ($r -lt 0 -or $r -ge $names.Count) { $ok = $false } else { $val = $names[$r] }; $script:p = $save }
            8 { $save = $script:p; $r = RdIdx; $val = (ObjName $r); $script:p = $save }
            13 { $save = $script:p; $l = RdIdx; if ($l -gt 0 -and ($script:p + $l) -le $end) { $val = [System.Text.Encoding]::GetEncoding(1252).GetString($script:buf, $script:p, $l - 1) } elseif ($l -eq 0) { $val = '' } else { $ok = $false }; $script:p = $save }
            default { $ok = $false }
        }
        $script:p = $valStart + $size
        $out.Add([pscustomobject]@{ Name = $names[$ni]; Type = $TYPES[$type]; Index = $arrIdx; Value = $val; Supported = $ok })
    }
}

function Literal($pr) {
    switch ($pr.Type) {
        'Str' { return '"' + ($pr.Value -replace '\\', '\\\\' -replace '"', '\"') + '"' }
        'Bool' { if ($pr.Value) { return 'True' } else { return 'False' } }
        'Float' { return ([string][single]$pr.Value) }
        'Name' { return '"' + $pr.Value + '"' }
        default { return [string]$pr.Value }
    }
}

$written = 0; $skipped = @()
foreach ($x in $exports) {
    if ($x.ClassRef -ne 0) { continue }
    $cls = $x.Name
    if (-not $fileOf.ContainsKey($cls)) { continue }
    $allowed = AllowedVars $cls
    $s = [int]$x.Offset; $e = $s + [int]$x.Size

    # Every offset that parses cleanly is a candidate ; the right one is whichever yields the most entries
    # naming a variable this class actually has. Taking merely the first parse that works reads a few of the
    # preceding bytes as a property and loses real defaults behind them.
    $props = $null; $best = -1
    for ($try = $s; $try -lt $e; $try++) {
        $r = ParseTagged $try $e
        if ($null -eq $r -or $r.Count -eq 0) { continue }
        $score = @($r | Where-Object { $allowed.Contains($_.Name) }).Count
        if ($score -gt $best) { $best = $score; $props = $r }
    }
    if ($null -eq $props -or $best -le 0) { continue }

    # Drop whatever the offset search picked up from the bytes before the defaults.
    $real = @($props | Where-Object { $allowed.Contains($_.Name) })
    if ($real.Count -eq 0) { continue }
    $bad = @($real | Where-Object { -not $_.Supported })
    if ($bad.Count -gt 0) { $skipped += ("{0}: {1}" -f $cls, (($bad | ForEach-Object { $_.Name + '(' + $_.Type + ')' }) -join ', ')); continue }

    $lines = foreach ($pr in $real) {
        $nm = $pr.Name
        if ($pr.Index -gt 0) { $nm = "$nm($($pr.Index))" }
        "     $nm=" + (Literal $pr)
    }
    $block = "`r`n`r`ndefaultproperties`r`n{`r`n" + ($lines -join "`r`n") + "`r`n}`r`n"

    $path = $fileOf[$cls]
    $text = $latin1.GetString([System.IO.File]::ReadAllBytes($path))
    $text = [regex]::Replace($text, '(?is)\r?\n\r?\ndefaultproperties\r?\n\{.*?\}\r?\n\s*$', '')
    if (-not $WhatIf) { [System.IO.File]::WriteAllBytes($path, $latin1.GetBytes($text.TrimEnd() + $block)) }
    Write-Output ("{0,-28} {1} defaults" -f $cls, $real.Count)
    $written++
}
Write-Output ("`nclasses given a defaultproperties block: {0}" -f $written)
if ($skipped.Count -gt 0) {
    Write-Output "unsupported value types, left alone:"
    $skipped | ForEach-Object { Write-Output "  $_" }
}
