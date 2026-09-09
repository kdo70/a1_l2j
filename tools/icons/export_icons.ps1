<#
.SYNOPSIS
    Exports item icons out of the client texture packages into PNG files.

.DESCRIPTION
    Takes a list of item ids, turns it into texture names with data/xml/itemIcons.xml, finds those textures in
    the client's systextures\*.utx and writes each one as a PNG plus a manifest of "id -> file".

    The packages are read the same way dump_package.ps1 reads a code package : a "Lineage2Ver1xx" container
    (28 byte UTF-16 header, body XOR'ed with a key, 20 byte plain trailer) wrapping an Unreal 2 package. The key
    is 0xAC for Ver111 and the low byte of the sum of the lowercased file name for Ver121.

    Textures are decoded here : DXT1 / DXT3 / DXT5, P8 with its palette, RGBA8 and G16. Nothing is written to
    the client ; the packages are only read.

.PARAMETER Ids
    Item ids to export. Defaults to every "id:<n>" key of tools\client\enchant_glow_tuning.tsv.

.PARAMETER IdFile
    File to read the ids from, instead of the tuning table : any text with "id:<n>" or bare numbers.

.PARAMETER SysTextures
    The client's systextures folder.

.PARAMETER Packages
    Texture packages to look in, in order. The first one holding a name wins.

.PARAMETER Out
    Where the PNGs go. Created if missing.

.PARAMETER ListOnly
    Only report what would be exported - which package holds each icon, its size and format.

.EXAMPLE
    .\export_icons.ps1

.EXAMPLE
    .\export_icons.ps1 -Ids 2,3,4 -Out .\some\folder
#>
param(
    [int[]]$Ids,
    [string]$IdFile,
    [string]$IconsXml,
    [string]$SysTextures = 'C:\Users\KRIVOSHEEC\Desktop\1\systextures',
    [string[]]$Packages = @('Icon.utx', 'ct1Icon.utx', 'c5icon.utx', 'epicicon.utx', 'bwico.utx', 'kswepicons.utx', 'mordoricon.utx', 'dynasty_shield_icon.utx'),
    [string]$Out,
    [switch]$ListOnly
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $IconsXml) { $IconsXml = Join-Path $repo 'build\gameserver\data\xml\itemIcons.xml' }
if (-not $IdFile) { $IdFile = Join-Path $repo 'tools\client\enchant_glow_tuning.tsv' }
if (-not $Out) { $Out = Join-Path $PSScriptRoot 'export' }

# ---------------------------------------------------------------- ids and their texture names

if (-not $Ids) {
    $Ids = @()
    foreach ($line in Get-Content -LiteralPath $IdFile) {
        if ($line -match '^\s*id:(\d+)') { $Ids += [int]$Matches[1] }
        elseif ($line -match '^\s*(\d+)\s*$') { $Ids += [int]$Matches[1] }
    }
    $Ids = $Ids | Sort-Object -Unique
}

$xml = [xml](Get-Content -LiteralPath $IconsXml)
$iconOf = @{}
foreach ($node in $xml.list.item) { $iconOf[[int]$node.id] = $node.icon }

$wanted = @{}      # texture name (lower) -> its real name
$idIcon = @()      # id -> texture name, for the manifest
$noIcon = @()
foreach ($id in $Ids) {
    if (-not $iconOf.ContainsKey($id)) { $noIcon += $id; continue }
    $icon = $iconOf[$id]
    $wanted[$icon.ToLower()] = $icon
    $idIcon += [pscustomobject]@{ Id = $id; Icon = $icon }
}

Write-Output "$($Ids.Count) ids, $($wanted.Count) distinct icons"
if ($noIcon.Count) { Write-Output "no icon in itemIcons.xml : $($noIcon -join ',')" }

# ---------------------------------------------------------------- package reading

$script:b = $null
$script:pos = 0

function Read-Byte { $v = $script:b[$script:pos]; $script:pos++; return $v }
function Read-Int32 { $v = [BitConverter]::ToInt32($script:b, $script:pos); $script:pos += 4; return $v }
function Read-UInt32 { $v = [BitConverter]::ToUInt32($script:b, $script:pos); $script:pos += 4; return $v }
function Read-UInt16 { $v = [BitConverter]::ToUInt16($script:b, $script:pos); $script:pos += 2; return $v }
function Read-Float { $v = [BitConverter]::ToSingle($script:b, $script:pos); $script:pos += 4; return $v }

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

function Open-Package([string]$path) {
    $raw = [System.IO.File]::ReadAllBytes($path)
    $body = $raw

    if ($raw.Length -gt 48) {
        $head = [System.Text.Encoding]::Unicode.GetString($raw, 0, 28)
        if ($head -match '^Lineage2Ver(\d+)') {
            $ver = $Matches[1]
            $key = 0xAC
            if ($ver -ne '111') {
                # Ver121 : the key is the low byte of the sum of the file name, lowercased, extension included.
                $name = [System.IO.Path]::GetFileName($path).ToLower()
                $sum = 0
                foreach ($c in [System.Text.Encoding]::ASCII.GetBytes($name)) { $sum += $c }
                $key = $sum -band 0xFF
            }
            $n = $raw.Length - 28 - 20
            $body = New-Object byte[] $n
            for ($i = 0; $i -lt $n; $i++) { $body[$i] = [byte]($raw[$i + 28] -bxor $key) }
        }
    }

    $script:b = $body
    $script:pos = 0

    if ((Read-UInt32) -ne 2653586369) { throw "$path is not an Unreal package." }

    $version = Read-UInt16
    $null = Read-UInt16 # licensee
    $null = Read-UInt32 # package flags
    $nameCount = Read-Int32
    $nameOffset = Read-Int32
    $exportCount = Read-Int32
    $exportOffset = Read-Int32
    $importCount = Read-Int32
    $importOffset = Read-Int32

    $script:pos = $nameOffset
    $names = New-Object string[] $nameCount
    for ($i = 0; $i -lt $nameCount; $i++) {
        $len = Read-Index
        $names[$i] = [System.Text.Encoding]::ASCII.GetString($script:b, $script:pos, [Math]::Max(0, $len - 1))
        $script:pos += $len
        $null = Read-UInt32 # name flags
    }

    $script:pos = $importOffset
    $imports = New-Object object[] $importCount
    for ($i = 0; $i -lt $importCount; $i++) {
        $null = Read-Index # class package
        $null = Read-Index # class name
        $null = Read-Int32 # package
        $imports[$i] = [pscustomobject]@{ Name = $names[(Read-Index)] }
    }

    $script:pos = $exportOffset
    $exports = New-Object object[] $exportCount
    for ($i = 0; $i -lt $exportCount; $i++) {
        $classIndex = Read-Index
        $null = Read-Index # super
        $null = Read-Int32 # group
        $objectName = Read-Index
        $null = Read-UInt32 # object flags
        $size = Read-Index
        $offset = 0
        if ($size -gt 0) { $offset = Read-Index }

        $className = 'Class'
        if ($classIndex -lt 0) { $className = $imports[(-$classIndex) - 1].Name }
        elseif ($classIndex -gt 0) { $className = $exports[$classIndex - 1].Name }

        $exports[$i] = [pscustomobject]@{
            Name   = $names[$objectName]
            Class  = $className
            Size   = $size
            Offset = $offset
        }
    }

    return [pscustomobject]@{ Body = $body; Version = $version; Names = $names; Exports = $exports }
}

# A UE1 property list : name, an info byte carrying type and size, then the value. Ends on the "None" name.
function Read-Properties {
    $props = @{}
    while ($true) {
        $nameIdx = Read-Index
        $pname = $script:names[$nameIdx]
        if ($pname -eq 'None') { break }

        $info = Read-Byte
        $type = $info -band 0x0F
        $sizeCode = ($info -shr 4) -band 0x07
        $isArray = ($info -band 0x80) -ne 0

        if ($type -eq 10) { $null = Read-Index } # struct name

        $size = switch ($sizeCode) {
            0 { 1 } 1 { 2 } 2 { 4 } 3 { 12 } 4 { 16 }
            5 { [int](Read-Byte) } 6 { [int](Read-UInt16) } 7 { Read-Int32 }
        }

        if ($type -eq 3) {
            # BOOL keeps its value in the array bit and carries no data.
            $props[$pname] = $isArray
            continue
        }

        if ($isArray) { $null = Read-Index }

        $start = $script:pos
        switch ($type) {
            1 { $props[$pname] = [int](Read-Byte) }              # BYTE
            2 { $props[$pname] = Read-Int32 }                    # INT
            4 { $props[$pname] = Read-Float }                    # FLOAT
            5 { $props[$pname] = Read-Index }                    # OBJECT
            6 { $props[$pname] = $script:names[(Read-Index)] }   # NAME
        }
        $script:pos = $start + $size
    }
    return $props
}

# UTexture : the property list, then its mipmaps, biggest first. Between the two Lineage 2 writes four bytes
# of its own - stock Unreal starts the mip array right after the properties.
function Read-Texture([object]$export) {
    $script:pos = $export.Offset
    $props = Read-Properties

    $null = Read-Int32
    $mipCount = Read-Index
    if ($mipCount -lt 1) { return $null }

    if ($script:version -ge 63) { $null = Read-Int32 } # offset past the mip data
    $size = Read-Index
    $data = New-Object byte[] $size
    [Array]::Copy($script:b, $script:pos, $data, 0, $size)
    $script:pos += $size
    $usize = Read-Int32
    $vsize = Read-Int32

    return [pscustomobject]@{
        Format  = [int]$props['Format']
        Palette = $props['Palette']
        USize   = $usize
        VSize   = $vsize
        Data    = $data
    }
}

function Read-Palette([object]$export) {
    $script:pos = $export.Offset
    $null = Read-Properties
    $count = Read-Index
    $pal = New-Object byte[] ($count * 4)
    [Array]::Copy($script:b, $script:pos, $pal, 0, $count * 4)
    return $pal
}

# ---------------------------------------------------------------- decoding, into a BGRA buffer

function Set-Pixel([byte[]]$out, [int]$stride, [int]$x, [int]$y, [int]$r, [int]$g, [int]$bl, [int]$a) {
    $o = $y * $stride + $x * 4
    $out[$o] = [byte]$bl; $out[$o + 1] = [byte]$g; $out[$o + 2] = [byte]$r; $out[$o + 3] = [byte]$a
}

function Decode-Dxt([byte[]]$data, [int]$w, [int]$h, [int]$format) {
    $stride = $w * 4
    $out = New-Object byte[] ($stride * $h)
    $blockSize = if ($format -eq 3) { 8 } else { 16 }
    $p = 0

    for ($by = 0; $by -lt $h; $by += 4) {
        for ($bx = 0; $bx -lt $w; $bx += 4) {
            if ($p + $blockSize -gt $data.Length) { break }

            $alpha = New-Object int[] 16
            for ($i = 0; $i -lt 16; $i++) { $alpha[$i] = 255 }

            if ($format -eq 7) {
                # DXT3 : four explicit bits per pixel.
                for ($i = 0; $i -lt 8; $i++) {
                    $two = $data[$p + $i]
                    $alpha[$i * 2] = ($two -band 0x0F) * 17
                    $alpha[$i * 2 + 1] = (($two -shr 4) -band 0x0F) * 17
                }
                $p += 8
            }
            elseif ($format -eq 8) {
                # DXT5 : two endpoints and three-bit indices into an interpolated ramp.
                $a0 = [int]$data[$p]; $a1 = [int]$data[$p + 1]
                $ramp = New-Object int[] 8
                $ramp[0] = $a0; $ramp[1] = $a1
                if ($a0 -gt $a1) {
                    for ($i = 1; $i -lt 7; $i++) { $ramp[$i + 1] = [int](((7 - $i) * $a0 + $i * $a1) / 7) }
                }
                else {
                    for ($i = 1; $i -lt 5; $i++) { $ramp[$i + 1] = [int](((5 - $i) * $a0 + $i * $a1) / 5) }
                    $ramp[6] = 0; $ramp[7] = 255
                }
                $bits = [uint64]0
                for ($i = 0; $i -lt 6; $i++) { $bits = $bits -bor ([uint64]$data[$p + 2 + $i] -shl (8 * $i)) }
                for ($i = 0; $i -lt 16; $i++) { $alpha[$i] = $ramp[[int](($bits -shr (3 * $i)) -band 7)] }
                $p += 16
            }

            $c0 = [BitConverter]::ToUInt16($data, $p)
            $c1 = [BitConverter]::ToUInt16($data, $p + 2)
            $idx = [BitConverter]::ToUInt32($data, $p + 4)
            $p += 8

            $r = New-Object int[] 4; $g = New-Object int[] 4; $bl = New-Object int[] 4
            $r[0] = ((($c0 -shr 11) -band 0x1F) * 255) / 31; $g[0] = ((($c0 -shr 5) -band 0x3F) * 255) / 63; $bl[0] = (($c0 -band 0x1F) * 255) / 31
            $r[1] = ((($c1 -shr 11) -band 0x1F) * 255) / 31; $g[1] = ((($c1 -shr 5) -band 0x3F) * 255) / 63; $bl[1] = (($c1 -band 0x1F) * 255) / 31

            $punch = ($format -eq 3) -and ($c0 -le $c1)
            if ($punch) {
                $r[2] = ($r[0] + $r[1]) / 2; $g[2] = ($g[0] + $g[1]) / 2; $bl[2] = ($bl[0] + $bl[1]) / 2
                $r[3] = 0; $g[3] = 0; $bl[3] = 0
            }
            else {
                $r[2] = (2 * $r[0] + $r[1]) / 3; $g[2] = (2 * $g[0] + $g[1]) / 3; $bl[2] = (2 * $bl[0] + $bl[1]) / 3
                $r[3] = ($r[0] + 2 * $r[1]) / 3; $g[3] = ($g[0] + 2 * $g[1]) / 3; $bl[3] = ($bl[0] + 2 * $bl[1]) / 3
            }

            for ($i = 0; $i -lt 16; $i++) {
                $x = $bx + ($i % 4)
                $y = $by + [int][Math]::Floor($i / 4)
                if ($x -ge $w -or $y -ge $h) { continue }
                $sel = [int](($idx -shr (2 * $i)) -band 3)
                $a = $alpha[$i]
                if ($punch -and $sel -eq 3) { $a = 0 }
                Set-Pixel $out $stride $x $y ([int]$r[$sel]) ([int]$g[$sel]) ([int]$bl[$sel]) $a
            }
        }
    }
    return $out
}

function Decode-P8([byte[]]$data, [int]$w, [int]$h, [byte[]]$pal) {
    $stride = $w * 4
    $out = New-Object byte[] ($stride * $h)
    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            $c = [int]$data[$y * $w + $x] * 4
            Set-Pixel $out $stride $x $y $pal[$c] $pal[$c + 1] $pal[$c + 2] $pal[$c + 3]
        }
    }
    return $out
}

function Decode-Rgba8([byte[]]$data, [int]$w, [int]$h) {
    $stride = $w * 4
    $out = New-Object byte[] ($stride * $h)
    [Array]::Copy($data, 0, $out, 0, [Math]::Min($data.Length, $out.Length))
    return $out
}

function Save-Png([byte[]]$bgra, [int]$w, [int]$h, [string]$path) {
    $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
    $locked = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    [System.Runtime.InteropServices.Marshal]::Copy($bgra, 0, $locked.Scan0, $bgra.Length)
    $bmp.UnlockBits($locked)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

# ---------------------------------------------------------------- the run

if (-not $ListOnly -and -not (Test-Path -LiteralPath $Out)) { $null = New-Item -ItemType Directory -Path $Out }

$formatName = @{ 0 = 'P8'; 1 = 'RGBA7'; 2 = 'RGB16'; 3 = 'DXT1'; 4 = 'RGB8'; 5 = 'RGBA8'; 6 = 'NODATA'; 7 = 'DXT3'; 8 = 'DXT5'; 9 = 'L8'; 10 = 'G16' }
$done = @{}
$resolved = @{}   # name as itemIcons.xml has it -> the texture actually taken, when the two differ
$report = @()

foreach ($packageName in $Packages) {
    if ($wanted.Count -eq $done.Count) { break }

    $path = Join-Path $SysTextures $packageName
    if (-not (Test-Path -LiteralPath $path)) { continue }

    $pkg = Open-Package $path
    $script:names = $pkg.Names
    $script:version = $pkg.Version

    $textures = $pkg.Exports | Where-Object { $_.Class -eq 'Texture' -and $_.Size -gt 0 }
    $hits = 0

    # itemIcons.xml carries a few names its extractor got wrong - cut short on a "'" or a "-", or carrying one
    # extra hex digit of the next field. Both are recovered here : an exact miss is retried without its last
    # character, then as a prefix of a real texture name, the first one in alphabetical order winning (that is
    # the "_i00" of a pair). Every rescue is reported, so a wrong guess is visible.
    $byName = @{}
    foreach ($t in $textures) { $byName[$t.Name.ToLower()] = $t }
    foreach ($key in @($wanted.Keys)) {
        if ($done.ContainsKey($key) -or $resolved.ContainsKey($key) -or $byName.ContainsKey($key)) { continue }

        $fix = $null
        $trimmed = $key.Substring(0, [Math]::Max(0, $key.Length - 1))
        if ($trimmed -and $byName.ContainsKey($trimmed)) { $fix = $trimmed }
        else {
            $prefixed = $byName.Keys | Where-Object { $_.StartsWith($key) } | Sort-Object
            if ($prefixed) { $fix = @($prefixed)[0] }
        }

        if ($fix) {
            Write-Output "  $($wanted[$key]) -> $($byName[$fix].Name) (name mangled in itemIcons.xml)"
            $resolved[$key] = $byName[$fix].Name
            $wanted[$fix] = $byName[$fix].Name
        }
    }

    foreach ($export in $textures) {
        $key = $export.Name.ToLower()
        if (-not $wanted.ContainsKey($key) -or $done.ContainsKey($key)) { continue }

        $tex = Read-Texture $export
        if (-not $tex) { continue }

        $fmt = $tex.Format
        $bgra = $null
        switch ($fmt) {
            0 {
                $palIndex = [int]$tex.Palette
                if ($palIndex -gt 0) {
                    $bgra = Decode-P8 $tex.Data $tex.USize $tex.VSize (Read-Palette $pkg.Exports[$palIndex - 1])
                }
            }
            3 { $bgra = Decode-Dxt $tex.Data $tex.USize $tex.VSize 3 }
            5 { $bgra = Decode-Rgba8 $tex.Data $tex.USize $tex.VSize }
            7 { $bgra = Decode-Dxt $tex.Data $tex.USize $tex.VSize 7 }
            8 { $bgra = Decode-Dxt $tex.Data $tex.USize $tex.VSize 8 }
        }

        $name = $formatName[$fmt]
        if (-not $name) { $name = "format $fmt" }

        if (-not $bgra) {
            Write-Warning "$($export.Name) : $name is not decoded here, skipped"
            continue
        }

        if (-not $ListOnly) {
            Save-Png $bgra $tex.USize $tex.VSize (Join-Path $Out ($wanted[$key] + '.png'))
        }

        $done[$key] = $packageName
        $hits++
        $report += [pscustomobject]@{ Icon = $wanted[$key]; Package = $packageName; Size = "$($tex.USize)x$($tex.VSize)"; Format = $name }
    }

    Write-Output "$packageName : $($textures.Count) textures, $hits taken"
}

# What each wanted name ended up as : itself, the texture a mangled name was resolved to, or nothing.
function Resolve-Name([string]$icon) {
    $key = $icon.ToLower()
    if ($done.ContainsKey($key)) { return $icon }
    if ($resolved.ContainsKey($key)) { return $resolved[$key] }
    return $null
}

$missing = $wanted.Values | Sort-Object -Unique | Where-Object { -not (Resolve-Name $_) }

if ($ListOnly) {
    $report | Sort-Object Icon | Format-Table -AutoSize
}
else {
    $manifest = Join-Path $Out 'icons.csv'
    $idIcon |
        Select-Object Id, Icon,
            @{n = 'Texture'; e = { $t = Resolve-Name $_.Icon; if ($t) { $t } else { '' } } },
            @{n = 'Package'; e = { $t = Resolve-Name $_.Icon; if ($t) { $done[$t.ToLower()] } else { '' } } },
            @{n = 'File'; e = { $t = Resolve-Name $_.Icon; if ($t) { $t + '.png' } else { '' } } } |
        Export-Csv -LiteralPath $manifest -NoTypeInformation -Encoding UTF8
    Write-Output "written: $($done.Count) PNG + $manifest, in $Out"
}

if ($missing) {
    Write-Output "not found in any package ($($missing.Count)) :"
    $missing | Sort-Object | ForEach-Object { Write-Output "  $_" }
}
