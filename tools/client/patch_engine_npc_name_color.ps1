# Lets an NPC's *name* - the white line the engine draws above its head - take
# the colour that sits next to it in npcname-e.dat, in the Interlude client's
# engine.dll.
#
# The engine already knows how to paint a name any colour. User::GetNameColor
# goes, in order: karma (white -> red), the pvp flag (purple), then
#
#     unique = this->UniqueNameColor        // +0x308
#     if (unique != -1) return unique       // any RGB, straight through
#     ... otherwise a tint by level difference ...
#
# Players carry a colour there, from CharInfo / UserInfo. NPCs never get one, so
# they always fall into the level tint and come out white. This patch adds one
# step in front of that tint: if the NPC's title colour - User+0x190, which the
# client loaded from npcname-e.dat - is not one of the stock ones, the name is
# painted with it too.
#
# That makes npc_title_colors.txt the source of both lines, and leaves every NPC
# it does not mention exactly as it was : the three colours the stock file uses
# (pale green, and the two oranges of "Raid Boss" and "Quest Monster") are in the
# neutral list and fall through to the stock path untouched. So is FFFF77, the
# title colour aCis gives a player, which is what keeps player names out of this
# when their own name colour is the default white.
#
# The patch is one byte in place - the displacement of the "no unique colour"
# branch - plus ~60 bytes of code in the 0xCC padding that follows the function.
# The new code holds no absolute addresses, only ecx-relative loads, immediates
# and relative jumps, so unlike patch_nwindow.ps1 it needs no .reloc entry and no
# section flag: .code is already executable and the padding is inside its
# VirtualSize.
#
# See ../../docs/npc-name-colors.md for how the offsets below were found.
#
#   powershell -ExecutionPolicy Bypass -File patch_engine_npc_name_color.ps1 `
#       -In "<client>\system\engine.dll"

[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)][string] $In,
	[string] $OutFile,
	# Title colours that must NOT bleed into the name, as RRGGBB hex text. The
	# first three are every colour the stock npcname-e.dat uses; the fourth is
	# Appearance._titleColor, the default aCis sends for a player.
	[string[]] $NeutralColors = @('A9E89C', 'FE8B3F', 'FF8000', 'FFFF77'),
	[switch] $Force
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- known file --
# File offsets into the Interlude engine.dll this patch was written against.
# .code is mapped at RVA = fileOffset + 0xC00.
$OFF_UNIQUE = 0x180BCF   # User::GetNameColor, "mov edx,[ecx+308h]"
$OFF_JE     = 0x180BD8   # ... the "je" that means "no unique colour"
$OFF_LEVEL  = 0x180BDE   # ... where it goes today: the tint by level difference
$OFF_TAIL   = 0x180C1C   # ... the shared tail, "cmp esi,2"
$OFF_CAVE   = 0x180C31   # 0xCC padding between this function and the next
$LEN_CAVE   = 63

# The tail of User::GetNameColor, byte for byte, from the "unique" load to the
# closing "ret 4". Anything else and this is not the build the patch was written
# for, so nothing is touched.
$SIG = '8B910803000083FAFF74048BC2EB3E0FB791E20200006685D27E326681FAFF00' +
       '7F2B0FBF89E20200008BC1992BC2D1F8BAFF0000002BD0C1E2088BC2C1E110BA' +
       'FF00FFFF2BD10BC20DFF0000FF83FE02750C807C2408007405B8FF00FFFF5EC2' +
       '0400'

$FLD_NICKCOLOR = 0x190   # User::GetNickColor returns exactly this

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

$found = Get-Hex $bytes $OFF_UNIQUE ($SIG.Length / 2)
if ($found -ne $SIG)
{
	Write-Host "expected : $SIG"
	Write-Host "found    : $found"
	throw "User::GetNameColor does not look like the build this patch was written for. Nothing changed."
}

foreach ($i in 0..($LEN_CAVE - 1))
{
	if ($bytes[$OFF_CAVE + $i] -ne 0xCC)
	{
		throw ("The padding at 0x{0:X} is not free at byte {1} - already patched, or another build. Nothing changed." -f $OFF_CAVE, $i)
	}
}

$neutral = @()
foreach ($c in $NeutralColors)
{
	$t = $c -replace '^0[xX]', ''
	if ($t -notmatch '^[0-9a-fA-F]{6}$') { throw "'$c' is not an RRGGBB colour." }
	$neutral += [Convert]::ToUInt32($t, 16)
}

# --------------------------------------------------------------------- code --
# ecx is the User, and stays untouched : the level path still needs it.
# eax holds the colour karma computed, and is only overwritten on the path that
# actually substitutes, so falling back into the stock code changes nothing.

$OPAQUE = [Convert]::ToUInt32('FF000000', 16)       # 0xFF000000 is a negative Int32 to PowerShell

Emit @(0x8B, 0x91)                                  # mov edx,[ecx+190h]
EmitU32 ([uint32]$FLD_NICKCOLOR)

# A User that never got a title colour holds a plain zero there - a black name,
# and an invisible one. That is not a colour anybody asked for, so it falls
# through like the stock ones. Tested before the alpha is forced on, so it stays
# a two byte test.
Emit @(0x85, 0xD2)                                  # test edx,edx
$jeAt = @()
$jeAt += $code.Count
Emit @(0x74, 0x00)                                  # je L_stock

# Whether the loader left an alpha in there is not something this patch knows,
# so it forces one - both for the comparisons below and for the colour returned.
Emit @(0x81, 0xCA)                                  # or edx,FF000000h
EmitU32 $OPAQUE

foreach ($c in $neutral)
{
	Emit @(0x81, 0xFA)                              # cmp edx,<neutral>
	EmitU32 ($c -bor $OPAQUE)
	$jeAt += $code.Count
	Emit @(0x74, 0x00)                              # je L_stock            (fixed up below)
}

Emit @(0x8B, 0xC2)                                  # mov eax,edx
$jmpTailAt = $code.Count
Emit @(0xE9, 0, 0, 0, 0)                            # jmp <tail>

$labelStock = $code.Count
$jmpLevelAt = $code.Count
Emit @(0xE9, 0, 0, 0, 0)                            # L_stock: jmp <level tint>

if ($code.Count -gt $LEN_CAVE)
{
	throw "The code is $($code.Count) bytes and only $LEN_CAVE are free. Drop a neutral colour."
}

$blob = [byte[]]$code.ToArray()

# short branches to L_stock
foreach ($at in $jeAt)
{
	$d = $labelStock - ($at + 2)
	if ($d -lt 0 -or $d -gt 127) { throw "je out of reach ($d)." }
	$blob[$at + 1] = [byte]$d
}

# near jumps back into the function
$rel = $OFF_TAIL - ($OFF_CAVE + $jmpTailAt + 5)
[Array]::Copy([BitConverter]::GetBytes([int]$rel), 0, $blob, $jmpTailAt + 1, 4)
$rel = $OFF_LEVEL - ($OFF_CAVE + $jmpLevelAt + 5)
[Array]::Copy([BitConverter]::GetBytes([int]$rel), 0, $blob, $jmpLevelAt + 1, 4)

# and the one byte in place: "no unique colour" now goes to the cave
$jeDisp = $OFF_CAVE - ($OFF_JE + 2)
if ($jeDisp -lt 0 -or $jeDisp -gt 127) { throw "the cave is out of reach of the je ($jeDisp)." }

# -------------------------------------------------------------------- write --
[Array]::Copy($blob, 0, $bytes, $OFF_CAVE, $blob.Length)
$bytes[$OFF_JE + 1] = [byte]$jeDisp

if ($OutFile)
{
	[System.IO.File]::WriteAllBytes($OutFile, $bytes)
	Write-Host "Written to $OutFile."
}
else
{
	$backup = "$In.prenpcname.bak"
	if (!(Test-Path $backup))
	{
		Copy-Item $In $backup
		Write-Host "Backed the stock file up to $backup."
	}
	elseif (!$Force)
	{
		Write-Host "$backup is already there - patching the file as it is now."
	}
	[System.IO.File]::WriteAllBytes($In, $bytes)
	Write-Host "Patched $In."
}

Write-Host ("  cave  : 0x{0:X} .. 0x{1:X}, {2} of {3} bytes used" -f $OFF_CAVE, ($OFF_CAVE + $blob.Length - 1), $blob.Length, $LEN_CAVE)
Write-Host ("  je    : 0x{0:X} -> +0x{1:X}" -f $OFF_JE, $jeDisp)
Write-Host ("  keeps : {0}" -f ($NeutralColors -join ', '))
