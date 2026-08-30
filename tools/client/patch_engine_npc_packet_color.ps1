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
# end of NpcInfo, and only for the NPCs that have a colour. The client's parser
# reads a packet through a format string ("ddddddddddddddddddffffdddcccccSSddd"
# and then "dddddccffdd" for NpcInfo) and bounds-checks every field against the
# end of the packet, so the four extra bytes are simply never read by a stock
# client - it keeps working, it just shows white names.
#
# The patched client reads them where the packet ends. The tag byte 0xC0 is what
# tells a colour from the last dword of an untouched packet, which is isFlying,
# 0 or 1 - so a patched client talking to a server that sends nothing also keeps
# working.
#
# The patch is 10 bytes in place - three instructions of the NpcInfo handler
# moved into a cave - plus ~50 bytes in the 0xCC padding behind that handler.
# Like the other one it holds no absolute addresses, so it needs no .reloc entry
# and no section flag.
#
# See ../../docs/npc-name-colors.md.
#
#   powershell -ExecutionPolicy Bypass -File patch_engine_npc_packet_color.ps1 `
#       -In "<client>\system\engine.dll"

[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)][string] $In,
	[string] $OutFile,
	[switch] $NoBackup
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- known file --
# File offsets into the Interlude engine.dll this patch was written against.
# .code is mapped at RVA = fileOffset + 0xC00.
#
# The NpcInfo handler of UNetworkHandler starts at 0x139870. It parses the
# packet with two calls to the format parser, looks the User up by object id,
# and from 0x139B3E on copies the parsed fields into it. That is where this
# patch cuts in: esi is the User, ebp still the frame pointer.
$OFF_SITE  = 0x139B3E   # mov [esi+8],edi / mov edx,[esp+50h] / mov [esi+0Ch],edx
$LEN_SITE  = 10
$OFF_CONT  = 0x139B48   # ... and where they fall through to
$OFF_CAVE  = 0x13A710   # 0xCC padding behind the handler (934 bytes of it)
$LEN_CAVE  = 0x80       # only this much is claimed

# From "mov esi,[eax+4]" - where the User lands - through the three instructions
# being moved and the one after them. Refuses to touch anything else.
$SIG_AT   = 0x139B37
$SIG      = '8B7004EB0233F6897E088B54245089560C899E94000000'

$FLD_UNIQUECOLOR = 0x308    # User::GetUniqueNameColor returns exactly this
$OFF_HANDLER_ARG = 0x08     # [ebp+8], the object whose +0x48 is the packet reader
$FLD_READER      = 0x48
$FLD_PACKET_END  = 0x4EF8   # the parser bounds-checks every field against this
$TAG             = 0xC0     # top byte of the appended dword

# ------------------------------------------------------------------ helpers --
function Get-Hex([byte[]] $bytes, [int] $at, [int] $len)
{
	($bytes[$at..($at + $len - 1)] | ForEach-Object { '{0:X2}' -f $_ }) -join ''
}

$code = New-Object System.Collections.ArrayList
function Emit([byte[]] $v) { [void]$code.AddRange($v) }
function EmitU32([uint32] $v) { [void]$code.AddRange([BitConverter]::GetBytes($v)) }

# ------------------------------------------------------------------- checks --
if (!(Test-Path $In)) { throw "No such file: $In" }
$bytes = [System.IO.File]::ReadAllBytes($In)

$found = Get-Hex $bytes $SIG_AT ($SIG.Length / 2)
if ($found -ne $SIG)
{
	Write-Host "expected : $SIG"
	Write-Host "found    : $found"
	throw "The NpcInfo handler does not look like the build this patch was written for. Nothing changed."
}

foreach ($i in 0..($LEN_CAVE - 1))
{
	if ($bytes[$OFF_CAVE + $i] -ne 0xCC)
	{
		throw ("The padding at 0x{0:X} is not free at byte {1} - already patched, or another build. Nothing changed." -f $OFF_CAVE, $i)
	}
}

# --------------------------------------------------------------------- code --
# On entry esi is the User and ebp the frame pointer, both of which the moved
# instructions already rely on. eax and edx are scratch here: the stock code
# reloads edx right away and eax is dead until the next call.

# --- the three instructions being moved out of the way -----------------------
Emit @(0x89, 0x7E, 0x08)                    # mov [esi+8],edi
Emit @(0x8B, 0x54, 0x24, 0x50)              # mov edx,[esp+50h]
Emit @(0x89, 0x56, 0x0C)                    # mov [esi+0Ch],edx

# --- the last dword of the packet --------------------------------------------
Emit @(0x8B, 0x45, [byte]$OFF_HANDLER_ARG)  # mov eax,[ebp+8]
Emit @(0x8B, 0x40, [byte]$FLD_READER)       # mov eax,[eax+48h]        ; the reader
Emit @(0x8B, 0x80)                          # mov eax,[eax+4EF8h]      ; end of packet
EmitU32 ([uint32]$FLD_PACKET_END)
Emit @(0x8B, 0x40, 0xFC)                    # mov eax,[eax-4]

# --- tagged ? -----------------------------------------------------------------
Emit @(0x8B, 0xD0)                          # mov edx,eax
Emit @(0xC1, 0xEA, 0x18)                    # shr edx,18h
Emit @(0x83, 0xFA, [byte]$TAG)              # cmp edx,0C0h
$jeAt = $code.Count
Emit @(0x74, 0x00)                          # je tagged
Emit @(0xB8, 0xFF, 0xFF, 0xFF, 0xFF)        # mov eax,-1               ; "no colour"
$jmpStoreAt = $code.Count
Emit @(0xEB, 0x00)                          # jmp store

$labelTagged = $code.Count
Emit @(0x25)                                # and eax,00FFFFFFh
EmitU32 ([uint32]0x00FFFFFF)
Emit @(0x0D)                                # or eax,FF000000h         ; opaque
EmitU32 ([Convert]::ToUInt32('FF000000', 16))

$labelStore = $code.Count
Emit @(0x89, 0x86)                          # mov [esi+308h],eax
EmitU32 ([uint32]$FLD_UNIQUECOLOR)

$jmpBackAt = $code.Count
Emit @(0xE9, 0, 0, 0, 0)                    # jmp <back>

if ($code.Count -gt $LEN_CAVE) { throw "The code is $($code.Count) bytes, only $LEN_CAVE claimed." }

$blob = [byte[]]$code.ToArray()

$d = $labelTagged - ($jeAt + 2)
if ($d -lt 0 -or $d -gt 127) { throw "je out of reach ($d)." }
$blob[$jeAt + 1] = [byte]$d

$d = $labelStore - ($jmpStoreAt + 2)
if ($d -lt 0 -or $d -gt 127) { throw "jmp out of reach ($d)." }
$blob[$jmpStoreAt + 1] = [byte]$d

$rel = $OFF_CONT - ($OFF_CAVE + $jmpBackAt + 5)
[Array]::Copy([BitConverter]::GetBytes([int]$rel), 0, $blob, $jmpBackAt + 1, 4)

# --- and the jump out to it ---------------------------------------------------
$site = New-Object byte[] $LEN_SITE
$site[0] = 0xE9
[Array]::Copy([BitConverter]::GetBytes([int]($OFF_CAVE - ($OFF_SITE + 5))), 0, $site, 1, 4)
for ($i = 5; $i -lt $LEN_SITE; $i++) { $site[$i] = 0x90 }

# -------------------------------------------------------------------- write --
[Array]::Copy($blob, 0, $bytes, $OFF_CAVE, $blob.Length)
[Array]::Copy($site, 0, $bytes, $OFF_SITE, $site.Length)

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

Write-Host ("  site : 0x{0:X} .. 0x{1:X} -> jmp 0x{2:X}" -f $OFF_SITE, ($OFF_SITE + $LEN_SITE - 1), $OFF_CAVE)
Write-Host ("  cave : 0x{0:X} .. 0x{1:X}, {2} bytes" -f $OFF_CAVE, ($OFF_CAVE + $blob.Length - 1), $blob.Length)
