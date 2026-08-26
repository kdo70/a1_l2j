# Draws the enchant level on the item icon, and caps the stack count, in the
# Interlude client's nwindow.dll.
#
# The item cell is painted by the native NCItemWnd::OnPaint, which knows how to
# put exactly one piece of text in the corner of an icon: the stack count.
# UnrealScript cannot reach that - a script only decides *whether* the count is
# shown and *what number* it is, never the format, the colour or the spot. So
# the branch is added here instead:
#
#   enchanted, and an item type that can be enchanted  ->  "+%d"
#   a stack, above the cap                             ->  "%d+" of the cap
#   a stack                                            ->  "%d"
#
# Enchantable items are never stackable, so the two never compete for the spot.
# Each string is drawn twice, shadow first, so the digits keep their edges.
#
# The new code goes into the zero padding at the tail of .rdata, which is mapped
# but unused; .rdata is marked executable and its VirtualSize grown to cover it,
# and the absolute addresses in the new code get their own .reloc block, because
# nwindow.dll never loads at its own ImageBase. Everything else is a jump.
#
# See ../../docs/enchant-on-icon.md for how the offsets below were found.
#
#   powershell -ExecutionPolicy Bypass -File patch_nwindow.ps1 `
#       -In "<client>\system\nwindow.dll"

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string] $In,
    [string] $Out,
    # AARRGGBB, the format NCWnd's text draw takes (stock UI grey is FFDCDCDC).
    # Hex text, because PowerShell reads 0xFF...... as a negative Int32.
    [string] $EnchantColor = 'FFCC66FF',
    [string] $CountColor   = 'FFFFFFFF',
    # The engine draws flat text, so an outline is just more passes in another
    # colour: "bold" surrounds the text on all eight sides, "outline" on four,
    # "drop" is a single pass down-right.
    [string] $ShadowColor = 'FF000000',
    [ValidateSet('bold','outline','drop','none')]
    [string] $ShadowStyle = 'bold',
    [int] $ShadowSpread = 1,
    # Pixels from the top left corner of the cell, which is where the draw would
    # otherwise land. The icon is 34x34, so ~21 down puts text on its bottom edge.
    [int] $EnchantOffsetX = 1,
    [int] $EnchantOffsetY = 21,
    [int] $CountOffsetX   = 1,
    [int] $CountOffsetY   = 21,
    # Counts above this are drawn as "<cap>+". 0 keeps the stock full number.
    [int] $CountCap = 99,
    [switch] $Force
)

$ErrorActionPreference = 'Stop'

$enchArgb   = [Convert]::ToUInt32(($EnchantColor -replace '^0[xX]', ''), 16)
$countArgb  = [Convert]::ToUInt32(($CountColor   -replace '^0[xX]', ''), 16)
$shadowArgb = [Convert]::ToUInt32(($ShadowColor  -replace '^0[xX]', ''), 16)

# ---------------------------------------------------------------- known file --
# File offsets into the Interlude nwindow.dll this patch was written against.
# .text and .rdata are mapped at VA = fileOffset + 0x10000000, so the two are
# interchangeable and the base is only added where an absolute is needed.
$IMAGE_BASE   = 0x10000000

$OFF_PAINT    = 0x311F0     # NCItemWnd::OnPaint, the count-drawing block
$LEN_PAINT    = 0x6B        # ... up to but not including OFF_CONT
$OFF_CONT     = 0x3125B     # where that block falls through to
$OFF_JMP1     = 0x311B8     # operand of a short jump that lands mid-block
$OFF_JMP2     = 0x311C1     # ... and another
$OFF_CAVE     = 0x34BE00    # zero padding past .rdata's VirtualSize
$LEN_CAVE     = 0x200

$STR_ENCH     = 0x1023AFCC  # L"+%d"
$STR_COUNT    = 0x10233718  # L"%d"
$STR_CAPPED   = 0x1028B878  # L"%d+"
$IAT_PRINTF   = 0x1022C404  # FString::Printf
$IAT_GETDATA  = 0x1022C3E4  # FString::operator const TCHAR*
$IAT_DTOR     = 0x1022C3C4  # FString::~FString
$FN_DRAWSTR   = 0x100217A0  # NCWnd::DrawString(y, x, colour, text, 0 x11, -1)

# NCItem fields, mapped from NCItem::Init copying an NCItemInfo in.
$FLD_ENCHANT  = 0x1E80
$FLD_ITEMTYPE = 0x1E50
$FLD_SHOWCNT  = 0x1F14
$FLD_ITEMNUM  = 0x1E64

# ItemType is an EItemType - InventoryWnd.uc compares it against ITEM_QUESTITEM,
# so it is that enum and not EItemParamType: 0 WEAPON, 1 ARMOR, 2 ACCESSARY,
# 3 QUESTITEM, 4 ASSET, 5 ETCITEM. Only the first three take an enchant; arrows
# and shots are ETCITEM and must not get a "+N" even when Enchanted says 1.
$ITEMTYPE_MAX_ENCHANTABLE = 2

# The block being replaced, byte for byte. Refuses to touch anything else.
$SIG_PAINT = '8B4DE883B9141F000000745F8B89641E00005168183723108D55A052FF1504C4221083C40C' +
             'C645FC016AFF6A006A006A006A006A006A006A006A006A006A006A008BC8FF15E4C32210' +
             '50680000FFFF8B45EC50538BCFE85505FFFFC645FC008D4DA0FF15C4C322108B4DE8'

# ------------------------------------------------------------------ helpers --
function Get-Hex([byte[]] $bytes, [int] $at, [int] $len) {
    ($bytes[$at..($at + $len - 1)] | ForEach-Object { '{0:X2}' -f $_ }) -join ''
}

$code = New-Object System.Collections.ArrayList
function Emit([byte[]] $v)   { [void]$code.AddRange($v) }
function EmitU32([uint32] $v){ [void]$code.AddRange([BitConverter]::GetBytes($v)) }
function EmitI32([int] $v)   { [void]$code.AddRange([BitConverter]::GetBytes($v)) }

# Every branch is emitted with a zero displacement and fixed up once the labels
# are known.
$fixShort = @()   # @{ At = <offset of the opcode>; To = <label name> }
$fixRel32 = @()
$fixAbs   = @()   # offsets of absolute addresses, which need .reloc entries
$labels   = @{}
# Absolute VA baked into the code. nwindow.dll never loads at its own ImageBase,
# so every one of these has to be described in .reloc or it points at nothing
# after the module is moved.
function EmitAbs32([uint32] $va) {
    $script:fixAbs += $code.Count
    [void]$code.AddRange([BitConverter]::GetBytes($va))
}
function Label([string] $name) { $labels[$name] = $code.Count }
# Always the near form: the draw tail is well past a short jump's reach, and
# guessing per jump is how you get an "out of range" halfway through a rewrite.
function JmpShort([byte] $op, [string] $to) {
    if ($op -eq 0xEB) {
        $script:fixShort += @{ At = $code.Count + 1; End = $code.Count + 5; To = $to }
        Emit @(0xE9); EmitI32 0
    } else {
        $script:fixShort += @{ At = $code.Count + 2; End = $code.Count + 6; To = $to }
        Emit @(0x0F, [byte]($op + 0x10)); EmitI32 0
    }
}
function CallAbs([int] $va) {
    $script:fixRel32 += @{ At = $code.Count + 1; Target = $va }
    Emit @(0xE8); EmitI32 0
}
function CallLabel([string] $to) {
    $script:fixShort += @{ At = $code.Count + 1; End = $code.Count + 5; To = $to }
    Emit @(0xE8); EmitI32 0
}
function JmpAbs([int] $va) {
    $script:fixRel32 += @{ At = $code.Count + 1; Target = $va }
    Emit @(0xE9); EmitI32 0
}

# Where the outline passes go, relative to the text, all drawn before it.
$spread = $ShadowSpread
$shadowPasses = switch ($ShadowStyle) {
    'bold'    { @(@(-$spread,-$spread), @(0,-$spread), @($spread,-$spread), @(-$spread,0), @($spread,0), @(-$spread,$spread), @(0,$spread), @($spread,$spread)) }
    'outline' { @(@(-$spread,0), @($spread,0), @(0,-$spread), @(0,$spread)) }
    'drop'    { @(@($spread,$spread)) }
    default   { @() }
}

function EmitAddReg([byte] $reg, [int] $v) {       # reg: C1 = ecx, C2 = edx
    if ($v -eq 0) { return }
    if ($v -ge -128 -and $v -le 127) { Emit @(0x83, $reg, [byte]($v -band 0xFF)) }
    else { Emit @(0x81, $reg); EmitI32 $v }
}

# Call the draw_all helper for one string: colour in eax, y in ecx, x in edx.
function EmitDrawCall([uint32] $colour, [int] $dx, [int] $dy) {
    Emit @(0xB8); EmitU32 $colour                   # mov  eax,colour
    # ebx is the cell's x and [ebp-14h] its y, not the other way round: the icon
    # draw above centres them against [esi+26Ch] and [esi+270h] respectively.
    Emit @(0x8B,0x4D,0xEC)                          # mov  ecx,[ebp-14h]  ; cell y
    EmitAddReg 0xC1 $dy
    Emit @(0x8B,0xD3)                               # mov  edx,ebx        ; cell x
    EmitAddReg 0xC2 $dx
    CallLabel 'draw_all'
}

# Build the FString from the two pushed printf arguments, keep its text pointer
# in esi for the whole run, draw it, destroy the temporary. esi is saved and
# restored around the cave.
function EmitDraw([uint32] $colour, [int] $dx, [int] $dy) {
    Emit @(0x8D,0x55,0xA0)                          # lea  edx,[ebp-60h]  ; FString slot
    Emit @(0x52)                                    # push edx
    Emit @(0xFF,0x15); EmitAbs32 $IAT_PRINTF        # call FString::Printf
    Emit @(0x83,0xC4,0x0C)                          # add  esp,0Ch
    Emit @(0xC6,0x45,0xFC,0x01)                     # mov  byte [ebp-4],1 ; EH state
    Emit @(0x8D,0x4D,0xA0)                          # lea  ecx,[ebp-60h]
    Emit @(0xFF,0x15); EmitAbs32 $IAT_GETDATA       # call FString::operator*
    Emit @(0x8B,0xF0)                               # mov  esi,eax        ; the text
    EmitDrawCall $colour $dx $dy
    Emit @(0xC6,0x45,0xFC,0x00)                     # mov  byte [ebp-4],0
    Emit @(0x8D,0x4D,0xA0)                          # lea  ecx,[ebp-60h]
    Emit @(0xFF,0x15); EmitAbs32 $IAT_DTOR          # call FString::~FString
}

# Every outline pass and then the text itself. Emitted once and shared by both
# strings - nine passes written out twice do not fit in the cave. The base x/y
# and the colour live on the stack because a draw is free to clobber eax/ecx/edx.
function EmitDrawAll() {
    Label 'draw_all'
    Emit @(0x52)                                    # push edx            ; x  -> [esp+8]
    Emit @(0x51)                                    # push ecx            ; y  -> [esp+4]
    Emit @(0x50)                                    # push eax            ; colour -> [esp]
    foreach ($p in $shadowPasses) {
        Emit @(0xB8); EmitU32 $shadowArgb           # mov  eax,shadow
        Emit @(0x8B,0x4C,0x24,0x04)                 # mov  ecx,[esp+4]
        EmitAddReg 0xC1 $p[1]
        Emit @(0x8B,0x54,0x24,0x08)                 # mov  edx,[esp+8]
        EmitAddReg 0xC2 $p[0]
        CallLabel 'draw_str'
    }
    Emit @(0x8B,0x04,0x24)                          # mov  eax,[esp]
    Emit @(0x8B,0x4C,0x24,0x04)                     # mov  ecx,[esp+4]
    Emit @(0x8B,0x54,0x24,0x08)                     # mov  edx,[esp+8]
    CallLabel 'draw_str'
    Emit @(0x83,0xC4,0x0C)                          # add  esp,0Ch
    Emit @(0xC3)                                    # ret
}

# The helper itself. It calls DrawString rather than tail jumping into it: the
# arguments are pushed after this routine's own return address, so a jump would
# leave DrawString reading argument one where it expects a return address.
function EmitDrawStr() {
    Label 'draw_str'
    Emit @(0x6A,0xFF)                               # push -1
    for ($i = 0; $i -lt 11; $i++) { Emit @(0x6A,0x00) }  # push 0 x11
    Emit @(0x56)                                    # push esi            ; text
    Emit @(0x50)                                    # push eax            ; colour
    Emit @(0x51)                                    # push ecx            ; y
    Emit @(0x52)                                    # push edx            ; x
    Emit @(0x8B,0xCF)                               # mov  ecx,edi        ; NCWnd*
    CallAbs $FN_DRAWSTR                             # call NCWnd::DrawString
    Emit @(0xC3)                                    # ret
}

# --------------------------------------------------------------- read/verify --
$In = (Resolve-Path -LiteralPath $In).Path
if (-not $Out) { $Out = $In }
$img = [IO.File]::ReadAllBytes($In)

if ([BitConverter]::ToUInt16($img, 0) -ne 0x5A4D) { throw "$In is not a PE image." }
$peOff = [BitConverter]::ToInt32($img, 0x3C)
if ([BitConverter]::ToUInt32($img, $peOff) -ne 0x00004550) { throw "$In has no PE header." }
$base = [BitConverter]::ToUInt32($img, $peOff + 24 + 28)
if ($base -ne $IMAGE_BASE) {
    throw ("ImageBase is 0x{0:X8}, this patch assumes 0x{1:X8}." -f $base, $IMAGE_BASE)
}

$have = Get-Hex $img $OFF_PAINT $LEN_PAINT
if ($have -ne $SIG_PAINT) {
    if ($img[$OFF_PAINT] -eq 0xE9) {
        throw ("Already patched (jump at 0x{0:X}). Start from the untouched dll." -f $OFF_PAINT)
    }
    Write-Host "expected: $SIG_PAINT"
    Write-Host "found   : $have"
    throw "NCItemWnd::OnPaint is not the Interlude build this patch knows."
}
if ($img[$OFF_JMP1] -ne 0x3A -or $img[$OFF_JMP2] -ne 0x31) {
    throw "The two short jumps into the block are not where they are expected."
}
foreach ($i in $OFF_CAVE..($OFF_CAVE + $LEN_CAVE - 1)) {
    if ($img[$i] -ne 0) { throw ("The .rdata padding at 0x{0:X} is not free." -f $i) }
}

$secStart = $peOff + 24 + [BitConverter]::ToUInt16($img, $peOff + 20)
$numSec   = [BitConverter]::ToUInt16($img, $peOff + 6)
$secAlign = [BitConverter]::ToUInt32($img, $peOff + 24 + 32)
$rdataHdr = -1
$nextVA   = [uint32]::MaxValue
for ($i = 0; $i -lt $numSec; $i++) {
    $o = $secStart + $i * 40
    if ([Text.Encoding]::ASCII.GetString($img, $o, 8).Trim([char]0) -eq '.rdata') {
        $rdataHdr = $o
        if ($i + 1 -lt $numSec) { $nextVA = [BitConverter]::ToUInt32($img, $secStart + ($i + 1) * 40 + 12) }
    }
}
if ($rdataHdr -lt 0) { throw "No .rdata section header." }

# ------------------------------------------------------------------ assemble --
$caveVA = $IMAGE_BASE + $OFF_CAVE

Emit @(0x56)                                            # push esi            ; borrowed below
Emit @(0x8B,0x4D,0xE8)                                  # mov  ecx,[ebp-18h]  ; NCItem*
Emit @(0x8B,0x81); EmitI32 $FLD_ENCHANT                 # mov  eax,[ecx+Enchanted]
Emit @(0x85,0xC0)                                       # test eax,eax
JmpShort 0x7E 'count'                                   # jle  count
Emit @(0x8B,0x91); EmitI32 $FLD_ITEMTYPE                # mov  edx,[ecx+ItemType]
Emit @(0x83,0xFA,[byte]$ITEMTYPE_MAX_ENCHANTABLE)       # cmp  edx,ITEM_ACCESSARY
JmpShort 0x7F 'count'                                   # jg   count
Emit @(0x50)                                            # push eax            ; the level
Emit @(0x68); EmitAbs32 $STR_ENCH                       # push L"+%d"
EmitDraw $enchArgb $EnchantOffsetX $EnchantOffsetY
JmpShort 0xEB 'done'

# bShowCount is what stock goes by, but UICommonAPI.ParamToItemInfo never sets
# it, so on this client it is always false and no count was ever drawn. Anything
# holding more than one is a stack and gets its number regardless.
Label 'count'
Emit @(0x83,0xB9); EmitI32 $FLD_SHOWCNT; Emit @(0x00)   # cmp  [ecx+bShowCount],0
JmpShort 0x75 'counted'                                 # jne  counted
Emit @(0x83,0xB9); EmitI32 $FLD_ITEMNUM; Emit @(0x01)   # cmp  [ecx+ItemNum],1
JmpShort 0x7E 'done'                                    # jle  done
Label 'counted'
Emit @(0x8B,0x81); EmitI32 $FLD_ITEMNUM                 # mov  eax,[ecx+ItemNum]
if ($CountCap -gt 0) {
    Emit @(0x3D); EmitI32 $CountCap                     # cmp  eax,cap
    JmpShort 0x7E 'plain'                               # jle  plain
    Emit @(0x68); EmitI32 $CountCap                     # push cap
    Emit @(0x68); EmitAbs32 $STR_CAPPED                   # push L"%d+"
    JmpShort 0xEB 'draw'                                # jmp  draw
}
Label 'plain'
Emit @(0x50)                                            # push eax
Emit @(0x68); EmitAbs32 $STR_COUNT                        # push L"%d"
Label 'draw'
EmitDraw $countArgb $CountOffsetX $CountOffsetY

Label 'done'
Emit @(0x5E)                                            # pop  esi
# The last instruction of the replaced block was this reload, and the code after
# it dereferences ecx straight away. Both draw paths clobber ecx, so it has to be
# put back before jumping home.
Emit @(0x8B,0x4D,0xE8)                                  # mov  ecx,[ebp-18h]
JmpAbs ($IMAGE_BASE + $OFF_CONT)

EmitDrawAll                                             # never fallen into
EmitDrawStr

$blob = [byte[]]$code.ToArray()
foreach ($f in $fixShort) {
    if (-not $labels.ContainsKey($f.To)) { throw "no label $($f.To)" }
    [Array]::Copy([BitConverter]::GetBytes([int]($labels[$f.To] - $f.End)), 0, $blob, $f.At, 4)
}
foreach ($f in $fixRel32) {
    $rel = [int]($f.Target - ($caveVA + $f.At + 4))
    [Array]::Copy([BitConverter]::GetBytes($rel), 0, $blob, $f.At, 4)
}
if ($blob.Length -gt $LEN_CAVE) {
    throw "cave code is $($blob.Length) bytes, the padding holds $LEN_CAVE."
}

# --------------------------------------------------------------------- apply --
[Array]::Copy($blob, 0, $img, $OFF_CAVE, $blob.Length)

# .rdata gets MEM_EXECUTE so the cave can run
$chars = [BitConverter]::ToUInt32($img, $rdataHdr + 36)
[Array]::Copy([BitConverter]::GetBytes([uint32]($chars -bor 0x20000000)), 0, $img, $rdataHdr + 36, 4)

# ... and its VirtualSize has to cover the cave. The padding is inside the raw
# section but past VirtualSize, and the loader zero fills a section's tail beyond
# that - the cave would be a page of zeroes at run time, which is what executing
# it looks like: a GPF inside NCItemWnd::OnPaint.
$rdataVSize = [BitConverter]::ToUInt32($img, $rdataHdr + 8)
$rdataRaw   = [BitConverter]::ToUInt32($img, $rdataHdr + 20)
$rdataRSize = [BitConverter]::ToUInt32($img, $rdataHdr + 16)
$needVSize  = $OFF_CAVE - $rdataRaw + $blob.Length
if ($needVSize -gt $rdataRSize) { throw "the cave does not fit inside .rdata's raw data." }
if ($rdataVSize -lt $needVSize) {
    $newVSize = [int](($needVSize + $secAlign - 1) - (($needVSize + $secAlign - 1) % $secAlign))
    if ($newVSize -gt $rdataRSize) { $newVSize = [int]$rdataRSize }
    if ($newVSize -lt $needVSize)  { $newVSize = [int]$needVSize }
    $rdataVA = [BitConverter]::ToUInt32($img, $rdataHdr + 12)
    if (($rdataVA + $newVSize) -gt $nextVA) {
        throw ("growing .rdata to 0x{0:X} would run into the next section." -f $newVSize)
    }
    [Array]::Copy([BitConverter]::GetBytes([uint32]$newVSize), 0, $img, $rdataHdr + 8, 4)
    Write-Host ("rdata   : VirtualSize 0x{0:X} -> 0x{1:X}" -f $rdataVSize, $newVSize)
}

# .reloc: nwindow.dll can never load at its own ImageBase - its 0x40B000 image
# would swallow core.dll (0x10100000) and engine.dll (0x10300000) - so it is
# always moved, and every absolute address in the cave has to be relocated with
# it. Without this the string pointers and IAT slots point at another module's
# memory and the first call out of the cave is a GPF inside NCItemWnd::OnPaint.
$relocDirVA   = [BitConverter]::ToUInt32($img, $peOff + 24 + 136)
$relocDirSize = [BitConverter]::ToUInt32($img, $peOff + 24 + 140)
$relocHdr = -1
for ($i = 0; $i -lt $numSec; $i++) {
    $o = $secStart + $i * 40
    if ([BitConverter]::ToUInt32($img, $o + 12) -eq $relocDirVA) { $relocHdr = $o }
}
if ($relocHdr -lt 0) { throw "No section holds the relocation directory." }
$relocRaw   = [BitConverter]::ToUInt32($img, $relocHdr + 20)
$relocRSize = [BitConverter]::ToUInt32($img, $relocHdr + 16)
$relocVSize = [BitConverter]::ToUInt32($img, $relocHdr + 8)

$caveRVA = $OFF_CAVE - $rdataRaw + [BitConverter]::ToUInt32($img, $rdataHdr + 12)
$sites = @($fixAbs | ForEach-Object { $caveRVA + $_ })
if ($sites.Count -eq 0) { throw "no absolute addresses recorded - the emitter changed." }
$page = $sites[0] -band 0xFFFFF000
foreach ($s in $sites) {
    if (($s -band 0xFFFFF000) -ne $page) { throw "the cave straddles a page, one block is not enough." }
}
$blockLen = 8 + 2 * $sites.Count
if ($blockLen % 4 -ne 0) { $blockLen += 2 }     # relocation blocks are 4 byte aligned
$at = $relocRaw + $relocDirSize
if (($relocDirSize + $blockLen) -gt [Math]::Min($relocVSize, $relocRSize)) {
    throw "no room to append a relocation block."
}
foreach ($i in $at..($at + $blockLen - 1)) {
    if ($img[$i] -ne 0) { throw "the space after the relocation blocks is not free." }
}
[Array]::Copy([BitConverter]::GetBytes([uint32]$page), 0, $img, $at, 4)
[Array]::Copy([BitConverter]::GetBytes([uint32]$blockLen), 0, $img, $at + 4, 4)
$w = $at + 8
foreach ($s in $sites) {
    [Array]::Copy([BitConverter]::GetBytes([uint16](0x3000 -bor ($s - $page))), 0, $img, $w, 2)
    $w += 2
}
[Array]::Copy([BitConverter]::GetBytes([uint32]($relocDirSize + $blockLen)), 0, $img, $peOff + 24 + 140, 4)
Write-Host ("reloc   : {0} entries for page 0x{1:X}, directory 0x{2:X} -> 0x{3:X}" -f `
    $sites.Count, $page, $relocDirSize, ($relocDirSize + $blockLen))

# OnPaint jumps into the cave; the rest of the old block becomes int3
$img[$OFF_PAINT] = 0xE9
[Array]::Copy([BitConverter]::GetBytes([int]($caveVA - ($IMAGE_BASE + $OFF_PAINT + 5))), 0, $img, $OFF_PAINT + 1, 4)
for ($i = $OFF_PAINT + 5; $i -lt $OFF_PAINT + $LEN_PAINT; $i++) { $img[$i] = 0xCC }

# the two short jumps aimed into the old block now land on that jump
$img[$OFF_JMP1] = [byte]($OFF_PAINT - ($OFF_JMP1 + 1))
$img[$OFF_JMP2] = [byte]($OFF_PAINT - ($OFF_JMP2 + 1))

if ($Out -eq $In) {
    $bak = "$In.preench.bak"
    if ((Test-Path -LiteralPath $bak) -and -not $Force) {
        throw "$bak already exists - pass -Force to overwrite it."
    }
    Copy-Item -LiteralPath $In -Destination $bak -Force
    Write-Host "backup  : $bak"
}
[IO.File]::WriteAllBytes($Out, $img)

Write-Host ("patched : {0}" -f $Out)
Write-Host ("cave    : 0x{0:X}, {1} of {2} bytes used" -f $OFF_CAVE, $blob.Length, $LEN_CAVE)
Write-Host ("enchant : +N in {0}, offset {1},{2}" -f $EnchantColor, $EnchantOffsetX, $EnchantOffsetY)
Write-Host ("shadow  : {0}, {1}, spread {2} ({3} passes)" -f $ShadowColor, $ShadowStyle, $ShadowSpread, $shadowPasses.Count)
if ($CountCap -gt 0) {
    Write-Host ("count   : {0}, offset {1},{2}, above {3} drawn as `"{3}+`"" -f $CountColor, $CountOffsetX, $CountOffsetY, $CountCap)
} else {
    Write-Host ("count   : {0}, offset {1},{2}, uncapped" -f $CountColor, $CountOffsetX, $CountOffsetY)
}
