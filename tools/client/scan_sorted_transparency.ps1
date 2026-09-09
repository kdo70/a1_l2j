<#
.SYNOPSIS
    Finds the client materials that pay for sorted transparency without needing it - the ones that make a
    weapon glow (or any other effect) flicker in front of and behind them from one camera angle to the next.

.DESCRIPTION
    A Lineage 2 frame draws opaque geometry first, writing depth, and then everything transparent, sorted
    per object and with no depth write of its own. Two transparent things that overlap on screen therefore
    have no per pixel answer to "which is in front" : the engine picks an order from the objects' positions
    and draws them whole. That is why a particle effect can vanish behind a bush and reappear when the
    camera turns - both are in that second pass.

    A material only has to be in that pass if its alpha really is a gradient - smoke, glass, a light haze.
    A cut out - leaves, grass, a grating, a bone - is alpha 0 or alpha 255 almost everywhere, and belongs in
    the opaque pass with an alpha test, where it writes depth and sorts per pixel like everything else. The
    client ships both kinds side by side :

        Shader  AlphaTest=True  ZWrite=True   -> alpha tested, in the opaque pass  (what grass uses)
        Shader  Opacity set, neither flag     -> blended, sorted, no depth written

    This script reads every material in a package, and for each blended one measures the alpha channel of
    the texture it takes its opacity from. A blended material whose alpha turns out to be a cut out is a
    hit : it is in the sorted pass for nothing, and moving it to an alpha test costs it nothing visually.

    Read only. Nothing is written to the client.

.PARAMETER Package
    A .utx / .usx / .u package, or a directory of them (searched recursively).

.PARAMETER PartialMax
    How much genuinely see-through alpha a material may carry and still count as a cut out, in percent of
    the texture's pixels. Default 8. Grass in field_deco_T sits at 3-19%, a decal at 40-50%.

.PARAMETER OutCsv
    Optional. Writes every material of every package scanned, hit or not, with its alpha measurements.

.EXAMPLE
    .\scan_sorted_transparency.ps1 -Package 'C:\Lineage2\textures\field_deco_T.utx'

.EXAMPLE
    .\scan_sorted_transparency.ps1 -Package 'C:\Lineage2\textures' -OutCsv .\transparency.csv
#>
param(
    [Parameter(Mandatory = $true)][string]$Package,
    [double]$PartialMax = 8,
    [string]$OutCsv
)
$ErrorActionPreference = 'Stop'

if (-not ('L2Pkg' -as [type])) {
    Add-Type -TypeDefinition @'
public static class L2Pkg {
    public static byte[] Decode(byte[] src, int start, int tail, byte key) {
        int n = src.Length - start - tail;
        byte[] d = new byte[n];
        for (int i = 0; i < n; i++) d[i] = (byte)(src[i + start] ^ key);
        return d;
    }
    // { clear, partial, opaque } pixel counts of a compressed texture's alpha channel
    public static long[] Alpha(byte[] d, int off, int len, int format) {
        long clear = 0, partial = 0, opaque = 0;
        if (format == 3) {            // DXT1 : one bit, and only in blocks that opt in (color0 <= color1)
            for (int p = off; p + 8 <= off + len; p += 8) {
                int c0 = d[p] | (d[p+1] << 8), c1 = d[p+2] | (d[p+3] << 8);
                if (c0 > c1) { opaque += 16; continue; }
                uint bits = (uint)(d[p+4] | (d[p+5] << 8) | (d[p+6] << 16) | (d[p+7] << 24));
                for (int i = 0; i < 16; i++) { if (((bits >> (i*2)) & 3) == 3) clear++; else opaque++; }
            }
        } else if (format == 7) {     // DXT3 : four bits per pixel, stored straight
            for (int p = off; p + 16 <= off + len; p += 16)
                for (int i = 0; i < 8; i++) {
                    int lo = d[p+i] & 0x0F, hi = (d[p+i] >> 4) & 0x0F;
                    if (lo == 0) clear++; else if (lo == 15) opaque++; else partial++;
                    if (hi == 0) clear++; else if (hi == 15) opaque++; else partial++;
                }
        } else if (format == 8) {     // DXT5 : two endpoints and three bit indices
            for (int p = off; p + 16 <= off + len; p += 16) {
                int a0 = d[p], a1 = d[p+1];
                ulong bits = 0;
                for (int i = 0; i < 6; i++) bits |= (ulong)d[p+2+i] << (8*i);
                for (int i = 0; i < 16; i++) {
                    int idx = (int)((bits >> (i*3)) & 7); int a;
                    if (idx == 0) a = a0;
                    else if (idx == 1) a = a1;
                    else if (a0 > a1) a = ((8-idx)*a0 + (idx-1)*a1) / 7;
                    else if (idx == 6) a = 0;
                    else if (idx == 7) a = 255;
                    else a = ((6-idx)*a0 + (idx-1)*a1) / 5;
                    if (a <= 8) clear++; else if (a >= 247) opaque++; else partial++;
                }
            }
        } else return null;
        return new long[] { clear, partial, opaque };
    }
}
'@
}

function Read-Pkg([string]$path) {
    $raw = [System.IO.File]::ReadAllBytes($path)
    $b = $raw
    if ($raw.Length -gt 48 -and [System.Text.Encoding]::Unicode.GetString($raw, 0, 28) -match '^Lineage2Ver\d+') {
        # Ver111 keys on a fixed 0xAC, Ver121 on the file name - but the plain body always opens with the
        # Unreal signature, so the key is the first byte XOR 0xC1, checked against the other three.
        $key = [byte]($raw[28] -bxor 0xC1)
        $sig = 0xC1, 0x83, 0x2A, 0x9E
        for ($i = 0; $i -lt 4; $i++) { if (($raw[28 + $i] -bxor $key) -ne $sig[$i]) { throw "not a package under one XOR byte" } }
        $b = [L2Pkg]::Decode($raw, 28, 20, $key)
    }
    return $b
}

function Scan-Package([string]$path) {
    $script:buf = Read-Pkg $path
    $script:p = 0
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
    $script:names = $names; $script:imports = $imports; $script:exports = $exports

    # every Texture of this package, by name, with its alpha measured lazily
    $texOf = @{}
    foreach ($x in $exports) {
        if ($x.ClassRef -eq 0) { continue }
        if ((ObjName $x.ClassRef) -ne 'Texture') { continue }
        if (-not $texOf.ContainsKey($x.Name)) { $texOf[$x.Name] = $x }
    }

    $rows = New-Object 'System.Collections.Generic.List[object]'
    foreach ($x in $exports) {
        if ($x.ClassRef -eq 0 -or $x.Size -le 0) { continue }
        $cn = ObjName $x.ClassRef
        if ($cn -ne 'Shader' -and $cn -ne 'FinalBlend') { continue }
        $pr = GetProps ([int]$x.Offset) ([int]$x.Offset + [int]$x.Size)

        $blended = $false; $why = ''
        if ($cn -eq 'Shader') {
            $ob = $pr['OutputBlending']
            # OB_Masked (1) is an alpha test already ; the blending modes and the plain default with an
            # opacity map are not, unless the material asks for the test itself.
            if ($null -ne $ob -and [int]$ob -eq 1) { continue }
            if ($null -eq $pr['Opacity']) { continue }
            if ($pr['AlphaTest'] -eq $true) { continue }
            $blended = $true; $why = 'Opacity without AlphaTest'
            $srcTex = $pr['Opacity']
        }
        else {
            $fb = $pr['FrameBufferBlending']
            if ($null -eq $fb -or [int]$fb -notin 2, 4) { continue }   # FB_AlphaBlend, FB_Translucent
            if ($pr['AlphaTest'] -eq $true) { continue }
            $blended = $true; $why = 'FrameBufferBlending without AlphaTest'
            $srcTex = $pr['Material']
        }
        if (-not $blended) { continue }

        $row = [ordered]@{
            Package = [IO.Path]::GetFileName($path); Material = $x.Name; Class = $cn; Why = $why
            Texture = $srcTex; Format = ''; Size = ''; Clear = $null; Partial = $null; Opaque = $null; Verdict = ''
        }
        $tx = if ($srcTex -and $texOf.ContainsKey($srcTex)) { $texOf[$srcTex] } else { $null }
        if ($null -eq $tx) { $row.Verdict = 'texture not in this package'; $rows.Add([pscustomobject]$row); continue }

        $st = Measure-Alpha $tx
        if ($null -eq $st) { $row.Verdict = 'alpha unreadable'; $rows.Add([pscustomobject]$row); continue }
        $row.Format = $st.Format; $row.Size = $st.Size
        $row.Clear = [math]::Round($st.Clear * 100, 1)
        $row.Partial = [math]::Round($st.Partial * 100, 1)
        $row.Opaque = [math]::Round($st.Opaque * 100, 1)
        $row.Verdict = if ($st.Partial * 100 -le $PartialMax) { 'CUT-OUT : sorted for nothing' } else { 'really translucent' }
        $rows.Add([pscustomobject]$row)
    }
    return $rows
}

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
function ObjName($r) {
    if ($r -gt 0) { return $script:exports[$r - 1].Name }
    if ($r -lt 0) { return $script:imports[(-$r) - 1] }
    return 'None'
}

# Walks a tagged property list, returning the values this script cares about and, in .End, where the list's
# None terminator left off - which is where a Texture's mip data follows.
function GetProps($start, $end) {
    $script:p = $start
    $out = @{}
    while ($true) {
        if ($script:p -ge $end) { $out['End'] = -1; return $out }
        $ni = RdIdx
        if ($ni -lt 0 -or $ni -ge $script:names.Count) { $out['End'] = -1; return $out }
        if ($script:names[$ni] -eq 'None') { $out['End'] = $script:p; return $out }
        if ($script:p -ge $end) { $out['End'] = -1; return $out }
        $info = $script:buf[$script:p]; $script:p++
        $type = $info -band 0x0F
        $sizeBits = ($info -shr 4) -band 0x07
        $isArray = ($info -band 0x80) -ne 0
        if ($type -eq 10) { $null = RdIdx }
        switch ($sizeBits) {
            0 { $size = 1 } 1 { $size = 2 } 2 { $size = 4 } 3 { $size = 12 } 4 { $size = 16 }
            5 { $size = $script:buf[$script:p]; $script:p++ }
            6 { $size = [BitConverter]::ToUInt16($script:buf, $script:p); $script:p += 2 }
            7 { $size = [BitConverter]::ToInt32($script:buf, $script:p); $script:p += 4 }
        }
        if ($isArray -and $type -ne 3) { $script:p++ }
        if ($type -eq 3) { $size = 0 }
        if ($size -lt 0 -or ($script:p + $size) -gt $end) { $out['End'] = -1; return $out }
        $valStart = $script:p
        $nm = $script:names[$ni]
        switch ($type) {
            1 { $out[$nm] = $script:buf[$valStart] }
            2 { $out[$nm] = [BitConverter]::ToInt32($script:buf, $valStart) }
            3 { $out[$nm] = $isArray }
            5 { $save = $script:p; $r = RdIdx; $out[$nm] = (ObjName $r); $script:p = $save }
            default { }
        }
        $script:p = $valStart + $size
    }
}

$FMT = @{ 3 = 'DXT1'; 7 = 'DXT3'; 8 = 'DXT5' }
function Measure-Alpha($tx) {
    $s = [int]$tx.Offset; $e = $s + [int]$tx.Size
    $pr = GetProps $s $e
    $after = [int]$pr['End']
    if ($after -lt 0) { return $null }
    $fmt = [int]$pr['Format']
    if (-not $FMT.ContainsKey($fmt)) { return $null }
    $u = [int]$pr['USize']; $v = [int]$pr['VSize']
    if ($u -le 0 -or $v -le 0) { return $null }
    # The mip array's own header is not worth guessing at ; the top mip's byte count follows from the format
    # and the dimensions, so the compact index carrying exactly that value is where its data starts.
    $expect = if ($fmt -eq 3) { [Math]::Max(8, $u * $v / 2) } else { [Math]::Max(16, $u * $v) }
    $dataAt = -1
    for ($try = $after; $try -lt [Math]::Min($after + 48, $e); $try++) {
        $script:p = $try
        if ((RdIdx) -eq $expect) { $dataAt = $script:p; break }
    }
    if ($dataAt -lt 0 -or ($dataAt + $expect) -gt $e) { return $null }
    $st = [L2Pkg]::Alpha($script:buf, $dataAt, $expect, $fmt)
    if ($null -eq $st) { return $null }
    $tot = $st[0] + $st[1] + $st[2]
    if ($tot -eq 0) { return $null }
    return [pscustomobject]@{ Format = $FMT[$fmt]; Size = "${u}x${v}"; Clear = $st[0] / $tot; Partial = $st[1] / $tot; Opaque = $st[2] / $tot }
}

$targets = if (Test-Path $Package -PathType Container) {
    Get-ChildItem $Package -Include '*.utx', '*.usx', '*.u' -File -Recurse
}
else { Get-Item $Package }

$all = New-Object 'System.Collections.Generic.List[object]'
$n = 0
foreach ($f in $targets) {
    $n++
    if ($targets.Count -gt 1) { Write-Progress -Activity 'scanning' -Status $f.Name -PercentComplete ([int](100 * $n / $targets.Count)) }
    try { foreach ($r in (Scan-Package $f.FullName)) { $all.Add($r) } }
    catch { Write-Output ("SKIP {0} : {1}" -f $f.Name, $_.Exception.Message) }
}

$hits = @($all | Where-Object { $_.Verdict -like 'CUT-OUT*' })
Write-Output ("packages {0}   blended materials {1}   of them cut-outs {2}" -f $targets.Count, $all.Count, $hits.Count)
if ($OutCsv) { $all | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8; Write-Output "written: $OutCsv" }
else { $hits | Select-Object Package, Material, Texture, Format, Size, Clear, Partial, Opaque }
