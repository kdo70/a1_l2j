# Lets the SERVER colour an NPC's name, per spawned NPC, by putting the colour
# in the NpcInfo packet - a patch of the Interlude client's engine.dll.
#
# It is the second half of the pair. patch_engine_npc_name_color.ps1 makes a
# name take the colour of its title, which lives in npcname-e.dat and is the
# same for every NPC of that id. This one fills User::UniqueNameColor, which
# User::GetNameColor prefers over everything but karma and the pvp flag, so a
# colour from the server wins over the one from the file, and an NPC the server
# says nothing about keeps whatever the other patch gives it. Either patch works
# on its own.
#
# How the colour travels : the server appends one dword, 0xC0RRGGBB, to the very
# end of NpcInfo, and only for the NPCs that have a colour. The client parses a
# packet through format strings ("ddddddddddddddddddffffdddcccccSSddd" and then
# "dddddccffdd" for NpcInfo) and bounds-checks every field against the end of the
# packet, so the four extra bytes are never read by a stock client - it keeps
# working, it just shows white names.
#
# The patched client reads them **from the cursor the parser returns**, which
# points at the first byte it did not parse - that is exactly our dword. Reading
# from the end of the packet instead does not work : whatever [reader+4EF8h]
# counts, it is not the last payload byte, and the tag never matched.
#
# The same colour also paints the TITLE, the line above the name. Its colour is
# User+190h, which the handler fills from npcname-e.dat - per npc id, the same
# for every spawn of it. Overwriting it here is what moves the title's colour to
# the server, so a datapack that says nameColor="FF0000" gets both lines red and
# an NPC the server says nothing about keeps the colour the client has for it.
#
# Cuts, all into the 0xCC padding behind the NpcInfo handler:
#
#   - right after the second parse call, where the cursor is still in eax and the
#     packet reader is still the first argument on the stack. It checks that at
#     least four bytes are left, reads them, and parks the value in the cave.
#   - where the handler starts filling the User, esi being the User. It picks the
#     value back up, checks the tag and writes User::UniqueNameColor.
#   - where it writes User+190h, the title colour, which is a six byte store and
#     so has room for a jump on its own. Same value, same tag check.
#
# The last two come in pairs, one per path the handler takes.
#
# The value is parked in the cave itself, addressed off a call/pop, so the patch
# still holds no absolute address and needs no .reloc entry.
#
# See ../../docs/npc-name-colors.md.
#
#   powershell -ExecutionPolicy Bypass -File patch_engine_npc_packet_color.ps1 `
#       -In "<client>\system\engine.dll"

[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)][string] $In,
	[string] $OutFile,
	# Diagnostics. Normally an NPC the server said nothing about gets -1, "no colour",
	# and falls through to whatever patch_engine_npc_name_color.ps1 gives it. Pass an
	# RRGGBB here and it gets that colour instead, which answers in one relog whether
	# the second cut runs at all and whether User+308h is the right field:
	#
	#   every NPC turns that colour  -> the cut runs, the field is right, the tag never matched
	#   nothing changes              -> the cut never runs, or the field is wrong
	[string] $Diagnose,
	# Second half of the same trick, one level up: this colour is parked when the
	# packet had fewer than four bytes left, i.e. when the server appended nothing.
	# Tagged, so it comes out of the check as a real colour. With both set, one relog
	# separates the three cases that otherwise all look the same:
	#
	#   every NPC in -DiagnoseEmpty  -> nothing was appended : the server side
	#   every NPC in -Diagnose       -> bytes were read, but not ours : the cursor
	#   the coloured NPC is coloured -> it works
	[string] $DiagnoseEmpty,
	# Third and bluntest: drop the tag check and paint the name with whatever dword
	# was read, so the bytes themselves become visible. The colour is the low three
	# bytes of it, so an NPC the server sent 0xC0FF3030 for comes out red.
	#
	#   the coloured NPC is its colour -> the read is right, only the tag check is not
	#   white                          -> fewer than four bytes were there : the server
	#   anything else                  -> the cursor points somewhere else
	[switch] $DiagnoseRaw
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- known file --
# File offsets into the Interlude engine.dll this patch was written against.
# .code is mapped at RVA = fileOffset + 0xC00. The NpcInfo handler of
# UNetworkHandler starts at 0x139870.
$OFF_READ     = 0x139A8F   # "add esp,0D8h", right after the second parse call
$LEN_READ     = 6
$OFF_READ_RET = 0x139A95   # ... and where it falls through to

# The handler fills the User from two places - one per way it got hold of it -
# and both carry the same three instructions. Both have to be cut, or the NPCs
# that come down the other one are missed, which is exactly what happened first.
$OFF_FILL      = 0x139B3E  # mov [esi+8],edi / mov edx,[esp+50h] / mov [esi+0Ch],edx
$LEN_FILL      = 10
$OFF_FILL_RET  = 0x139B48  # ... and where they fall through to

$OFF_FILL2     = 0x13A02F  # the same three instructions on the other path
$LEN_FILL2     = 10
$OFF_FILL2_RET = 0x13A039

# The title colour, at the point both halves of the title have been dealt with.
#
# Not at "mov [esi+190h],edx", the obvious place, because that store is on one
# branch of two and it is the branch nobody takes here. The handler decides:
#
#   cmp [esp+13Ch],bx     ; the title string that came in the packet
#   je  <read npcname-e.dat, and set the colour from it>
#   ...                   ; not empty : take the title from the server
#   jmp <join>            ; and never touch the colour at all
#
# With ServerSideNpcTitle on, every NPC carrying a title in data/xml/npcs goes
# down the upper branch, so hooking the store paints nothing. Hooking where the
# two join catches both. "cmp word [esp+10Ch],bx" is eight bytes and the flags
# it sets are read by the very next instruction, so it is displaced to the END
# of the cave rather than the start.
$OFF_TITLE      = 0x139CD7
$LEN_TITLE      = 8
$OFF_TITLE_RET  = 0x139CDF

$OFF_TITLE2     = 0x13A1CC
$LEN_TITLE2     = 8
$OFF_TITLE2_RET = 0x13A1D4

$OFF_CAVE     = 0x13A710   # 0xCC padding behind the handler (928 bytes of it)
$LEN_CAVE     = 0x180

# Both cut sites, byte for byte. Refuses to touch anything else.
$SIG_READ_AT = 0x139A84
$SIG_READ    = 'E85C8EECFF8B3538F5B11081C4D80000003BF3'      # call / mov esi,[..] / add esp / cmp
$SIG_FILL_AT = 0x139B37
$SIG_FILL    = '8B7004EB0233F6897E088B54245089560C899E94000000'
$SIG_FILL2_AT = 0x13A022
$SIG_FILL2    = '8BF0EB0233F68B4C2418894E18897E088B54245089560C89'

# Both join points carry the same bytes around them.
$SIG_TITLE_AT  = 0x139CD1
$SIG_TITLE2_AT = 0x13A1C6
$SIG_TITLE     = '89991050000066399C240C010000740A'   # mov [ecx+5010h],ebx / the cmp / je

$FLD_TITLECOLOR  = 0x190    # the title's colour, read inline - GetNickColor is never called
$FLD_UNIQUECOLOR = 0x308    # User::GetUniqueNameColor returns exactly this
$FLD_PACKET_END  = 0x4EF8   # what the parser bounds-checks every field against
$TAG             = 0xC0     # top byte of the appended dword

# ------------------------------------------------------------------ helpers --
function Get-Hex([byte[]] $bytes, [int] $at, [int] $len)
{
	($bytes[$at..($at + $len - 1)] | ForEach-Object { '{0:X2}' -f $_ }) -join ''
}

$code = New-Object System.Collections.ArrayList
$shortFixups = @()
function Emit([byte[]] $v) { [void]$code.AddRange($v) }
function EmitU32([uint32] $v) { [void]$code.AddRange([BitConverter]::GetBytes($v)) }
function EmitI32([int] $v) { [void]$code.AddRange([BitConverter]::GetBytes($v)) }

# ------------------------------------------------------------------- checks --
if (!(Test-Path $In)) { throw "No such file: $In" }
$bytes = [System.IO.File]::ReadAllBytes($In)

foreach ($s in @(@($SIG_READ_AT, $SIG_READ, 'the parse tail'), @($SIG_FILL_AT, $SIG_FILL, 'the first User fill'), @($SIG_FILL2_AT, $SIG_FILL2, 'the second User fill'), @($SIG_TITLE_AT, $SIG_TITLE, 'the first title join'), @($SIG_TITLE2_AT, $SIG_TITLE, 'the second title join')))
{
	$found = Get-Hex $bytes $s[0] ($s[1].Length / 2)
	if ($found -ne $s[1])
	{
		Write-Host "expected : $($s[1])"
		Write-Host "found    : $found"
		throw "$($s[2]) of the NpcInfo handler does not look like the build this patch was written for. Nothing changed."
	}
}

foreach ($i in 0..($LEN_CAVE - 1))
{
	if ($bytes[$OFF_CAVE + $i] -ne 0xCC)
	{
		throw ("The padding at 0x{0:X} is not free at byte {1} - already patched, or another build. Nothing changed." -f $OFF_CAVE, $i)
	}
}

# --------------------------------------------------------------------- code --
$OPAQUE = [Convert]::ToUInt32('FF000000', 16)   # 0xFF000000 is a negative Int32 to PowerShell

# What an NPC without a colour from the server gets. -1 hands it back to the stock
# path (and to the other patch) ; a diagnostic colour paints every such NPC instead.
$noColor = [Convert]::ToUInt32('FFFFFFFF', 16)
if ($Diagnose)
{
	$t = $Diagnose -replace '^0[xX]', ''
	if ($t -notmatch '^[0-9a-fA-F]{6}$') { throw "-Diagnose wants RRGGBB, got '$Diagnose'." }
	$noColor = $OPAQUE -bor [Convert]::ToUInt32($t, 16)
	Write-Host "DIAGNOSTIC BUILD : every NPC the server sends no colour for is painted $t."
}

# What gets parked when the packet held nothing extra. -1 means "no colour" and is
# what the tag check turns into the fallback above ; a diagnostic value is tagged,
# so it comes out as a colour of its own and tells the two cases apart.
$emptyValue = [Convert]::ToUInt32('FFFFFFFF', 16)
if ($DiagnoseEmpty)
{
	$t = $DiagnoseEmpty -replace '^0[xX]', ''
	if ($t -notmatch '^[0-9a-fA-F]{6}$') { throw "-DiagnoseEmpty wants RRGGBB, got '$DiagnoseEmpty'." }
	$emptyValue = ([uint32]$TAG -shl 24) -bor [Convert]::ToUInt32($t, 16)
	Write-Host "DIAGNOSTIC BUILD : an NpcInfo with nothing appended is painted $t."
}

# ============================== cave 1 : read ================================
# Entry: eax = the cursor the parser returned, [esp] = its first argument, the
# packet reader, because the arguments of both calls are still on the stack.
# edx is dead here - the stock code reloads it before its next use.
$cave1 = 0

Emit @(0x8B, 0x14, 0x24)                    # mov edx,[esp]            ; the reader
Emit @(0x8B, 0x92)                          # mov edx,[edx+4EF8h]      ; end of packet
EmitU32 ([uint32]$FLD_PACKET_END)
Emit @(0x2B, 0xD0)                          # sub edx,eax              ; bytes left
Emit @(0x83, 0xFA, 0x04)                    # cmp edx,4
$jbAt = $code.Count
Emit @(0x72, 0x00)                          # jb none                  ; nothing appended
Emit @(0x8B, 0x00)                          # mov eax,[eax]            ; the appended dword
$jmpParkAt = $code.Count
Emit @(0xEB, 0x00)                          # jmp park

$labelNone = $code.Count
Emit @(0xB8)                                # mov eax,<nothing appended>
EmitU32 $emptyValue

$labelPark = $code.Count
Emit @(0xE8, 0x00, 0x00, 0x00, 0x00)        # call $+5                 \ position independent
$parkOrigin = $code.Count                   # "call $+5" pushed the address of the pop below,
Emit @(0x5A)                                # pop edx                  / so that is what edx holds
$parkFixup = $code.Count
Emit @(0x89, 0x82)                          # mov [edx+<slot>],eax
EmitU32 0

Emit @(0x81, 0xC4)                          # add esp,0D8h             ; the displaced instruction
EmitU32 ([uint32]0xD8)
$jmpBack1At = $code.Count
Emit @(0xE9, 0, 0, 0, 0)                    # jmp <back>

# ============================ caves 2, 3 : store =============================
# Entry: esi is the User, and the three instructions moved out of the way go
# first so the stock code is unchanged from here on.
#
# There are TWO of these, because the handler has two near identical paths that
# fill the User - one per way it got hold of it - and they carry the very same
# three instructions. Patching only the first one does nothing at all: NPCs in a
# town go down the second.
$stores = @()
$picks = @()
$jmpBacks = @()

foreach ($ret in @($OFF_FILL_RET, $OFF_FILL2_RET))
{
	$stores += $code.Count

	Emit @(0x89, 0x7E, 0x08)                # mov [esi+8],edi
	Emit @(0x8B, 0x54, 0x24, 0x50)          # mov edx,[esp+50h]
	Emit @(0x89, 0x56, 0x0C)                # mov [esi+0Ch],edx

	Emit @(0xE8, 0x00, 0x00, 0x00, 0x00)    # call $+5
	$picks += @{ Origin = $code.Count }
	Emit @(0x58)                            # pop eax
	$picks[-1].Fixup = $code.Count
	Emit @(0x8B, 0x80)                      # mov eax,[eax+<slot>]
	EmitU32 0

	if (!$DiagnoseRaw)
	{
		Emit @(0x8B, 0xD0)                  # mov edx,eax
		Emit @(0xC1, 0xEA, 0x18)            # shr edx,18h
		# imm32, NOT the short "83 /7 ib" form : that one sign-extends, and 0C0h
		# would be compared as 0FFFFFFC0h, which never matches. Cost a full round of
		# diagnostics.
		Emit @(0x81, 0xFA)                  # cmp edx,0C0h
		EmitU32 ([uint32]$TAG)
		$jeAt = $code.Count
		Emit @(0x74, 0x00)                  # je tagged
		Emit @(0xB8)                        # mov eax,<"no colour", or the diagnostic colour>
		EmitU32 $noColor
		$jmpStoreAt = $code.Count
		Emit @(0xEB, 0x00)                  # jmp store

		$labelTagged = $code.Count
		$shortFixups += @{ At = $jeAt; To = $labelTagged }
	}

	Emit @(0x25)                            # and eax,00FFFFFFh
	EmitU32 ([uint32]0x00FFFFFF)
	Emit @(0x0D)                            # or eax,FF000000h         ; opaque
	EmitU32 $OPAQUE

	$labelStore = $code.Count
	if (!$DiagnoseRaw) { $shortFixups += @{ At = $jmpStoreAt; To = $labelStore } }
	Emit @(0x89, 0x86)                      # mov [esi+308h],eax
	EmitU32 ([uint32]$FLD_UNIQUECOLOR)
	$jmpBacks += @{ At = $code.Count; Ret = $ret }
	Emit @(0xE9, 0, 0, 0, 0)                # jmp <back>
}

# =========================== caves 4, 5 : the title ==========================
# Entry: esi is the User, and both branches of the title have already run - the
# one that took the text from the packet and the one that took it, and its
# colour, from npcname-e.dat. So the colour is written here only when the server
# sent one ; otherwise whatever is in the field stays, which is exactly what the
# NPC looks like today.
#
# ebx has to survive - the displaced cmp compares against bx - and eax, ecx and
# edx are all reloaded by both successors before they are read, so edx is ours.
# One register is all there is anyway, hence the tag checked as a range instead
# of shifting a copy out of the way the way the name cave does.
$titles = @()
$titlePicks = @()

foreach ($ret in @($OFF_TITLE_RET, $OFF_TITLE2_RET))
{
	$titles += $code.Count

	Emit @(0xE8, 0x00, 0x00, 0x00, 0x00)    # call $+5
	$titlePicks += @{ Origin = $code.Count }
	Emit @(0x5A)                            # pop edx
	$titlePicks[-1].Fixup = $code.Count
	Emit @(0x8B, 0x92)                      # mov edx,[edx+<slot>]
	EmitU32 0

	# 0xC0RRGGBB is exactly the half-open range below ; "no colour" is 0xFFFFFFFF
	# and falls out of it. imm32 again - the short form would sign-extend.
	Emit @(0x81, 0xFA)                      # cmp edx,0C0000000h
	EmitU32 ([uint32]$TAG -shl 24)
	$jbAt2 = $code.Count
	Emit @(0x72, 0x00)                      # jb keep
	Emit @(0x81, 0xFA)                      # cmp edx,0C1000000h
	EmitU32 (([uint32]$TAG + 1) -shl 24)
	$jaeAt = $code.Count
	Emit @(0x73, 0x00)                      # jae keep

	Emit @(0x81, 0xE2)                      # and edx,00FFFFFFh
	EmitU32 ([uint32]0x00FFFFFF)
	Emit @(0x81, 0xCA)                      # or edx,FF000000h        ; opaque
	EmitU32 $OPAQUE
	Emit @(0x89, 0x96)                      # mov [esi+190h],edx
	EmitU32 ([uint32]$FLD_TITLECOLOR)

	$labelKeep = $code.Count
	$shortFixups += @{ At = $jbAt2; To = $labelKeep }
	$shortFixups += @{ At = $jaeAt; To = $labelKeep }

	# Last, so the flags the next stock instruction branches on are its own.
	Emit @(0x66, 0x39, 0x9C, 0x24, 0x0C, 0x01, 0x00, 0x00)   # cmp word [esp+10Ch],bx

	$jmpBacks += @{ At = $code.Count; Ret = $ret }
	Emit @(0xE9, 0, 0, 0, 0)                # jmp <back>
}

# ============================== the parked value =============================
while ($code.Count % 4 -ne 0) { Emit @(0x90) }
$slot = $code.Count
EmitU32 ([Convert]::ToUInt32('FFFFFFFF', 16))

if ($code.Count -gt $LEN_CAVE) { throw "The code is $($code.Count) bytes, only $LEN_CAVE claimed." }
$blob = [byte[]]$code.ToArray()

# ------------------------------------------------------------------ fixups --
function FixShort([int] $at, [int] $target)
{
	$d = $target - ($at + 2)
	if ($d -lt -128 -or $d -gt 127) { throw "short branch at $at out of reach ($d)." }
	$blob[$at + 1] = [byte]($d -band 0xFF)
}
function FixRel32([int] $at, [int] $targetFileOff)
{
	$rel = $targetFileOff - ($OFF_CAVE + $at + 5)
	[Array]::Copy([BitConverter]::GetBytes([int]$rel), 0, $blob, $at + 1, 4)
}

FixShort $jbAt $labelNone
FixShort $jmpParkAt $labelPark
foreach ($f in $shortFixups) { FixShort $f.At $f.To }
FixRel32 $jmpBack1At $OFF_READ_RET
foreach ($j in $jmpBacks) { FixRel32 $j.At $j.Ret }

# the parked dword, addressed off whatever call/pop left in the register
[Array]::Copy([BitConverter]::GetBytes([int]($slot - $parkOrigin)), 0, $blob, $parkFixup + 2, 4)
foreach ($p in $picks) { [Array]::Copy([BitConverter]::GetBytes([int]($slot - $p.Origin)), 0, $blob, $p.Fixup + 2, 4) }
foreach ($p in $titlePicks) { [Array]::Copy([BitConverter]::GetBytes([int]($slot - $p.Origin)), 0, $blob, $p.Fixup + 2, 4) }

# ------------------------------------------------------------ the two jumps --
function Site([int] $len, [int] $from, [int] $to)
{
	$s = New-Object byte[] $len
	$s[0] = 0xE9
	[Array]::Copy([BitConverter]::GetBytes([int]($to - ($from + 5))), 0, $s, 1, 4)
	for ($i = 5; $i -lt $len; $i++) { $s[$i] = 0x90 }
	return $s
}

$siteRead = Site $LEN_READ $OFF_READ ($OFF_CAVE + $cave1)
$siteFill = Site $LEN_FILL $OFF_FILL ($OFF_CAVE + $stores[0])
$siteFill2 = Site $LEN_FILL2 $OFF_FILL2 ($OFF_CAVE + $stores[1])
$siteTitle = Site $LEN_TITLE $OFF_TITLE ($OFF_CAVE + $titles[0])
$siteTitle2 = Site $LEN_TITLE2 $OFF_TITLE2 ($OFF_CAVE + $titles[1])

# -------------------------------------------------------------------- write --
[Array]::Copy($blob, 0, $bytes, $OFF_CAVE, $blob.Length)
[Array]::Copy($siteRead, 0, $bytes, $OFF_READ, $siteRead.Length)
[Array]::Copy($siteFill, 0, $bytes, $OFF_FILL, $siteFill.Length)
[Array]::Copy($siteFill2, 0, $bytes, $OFF_FILL2, $siteFill2.Length)
[Array]::Copy($siteTitle, 0, $bytes, $OFF_TITLE, $siteTitle.Length)
[Array]::Copy($siteTitle2, 0, $bytes, $OFF_TITLE2, $siteTitle2.Length)

if ($OutFile)
{
	[System.IO.File]::WriteAllBytes($OutFile, $bytes)
	Write-Host "Written to $OutFile."
}
else
{
	$backup = "$In.prepktcolor.bak"
	if (!$NoBackup -and !(Test-Path $backup))
	{
		Copy-Item $In $backup
		Write-Host "Backed the file up to $backup."
	}
	[System.IO.File]::WriteAllBytes($In, $bytes)
	Write-Host "Patched $In."
}

Write-Host ("  read  : 0x{0:X} -> cave+0x{1:X}" -f $OFF_READ, $cave1)
Write-Host ("  fill  : 0x{0:X} -> cave+0x{1:X}" -f $OFF_FILL, $stores[0])
Write-Host ("  fill2 : 0x{0:X} -> cave+0x{1:X}" -f $OFF_FILL2, $stores[1])
Write-Host ("  title : 0x{0:X} -> cave+0x{1:X}" -f $OFF_TITLE, $titles[0])
Write-Host ("  title2: 0x{0:X} -> cave+0x{1:X}" -f $OFF_TITLE2, $titles[1])
Write-Host ("  cave  : 0x{0:X} .. 0x{1:X}, {2} of {3} bytes, parked value at +0x{4:X}" -f $OFF_CAVE, ($OFF_CAVE + $blob.Length - 1), $blob.Length, $LEN_CAVE, $slot)
