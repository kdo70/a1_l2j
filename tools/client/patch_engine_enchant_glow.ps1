# Makes the enchant glow of a weapon climb with its enchant level - a patch of
# the Interlude client's engine.dll.
#
# Stock behaviour. weapongrp.dat carries ONE effect name per weapon
# (EnchantedEffect, the "effA" column of the Interlude ddf), and
# APawn::GetEnchantedWeaponEffect hands it back untouched. The caller spawns it
# once the weapon is enchanted to at least EnchantEffectShow, out of the
# [EnchantEffect] section of system\env.int. One weapon, one effect, whatever
# the level : +4 and +17 look the same.
#
# What this does. EnchantGlow.u ships 56 effects - seven enchant steps
# (4, 7, 10, 12, 14, 15, 17) for each of eight weapon shapes
# (_001t fist, _002t dagger and polearm, _004t sword, _005t staff and two handed
# blunt, _006t dual sword, _007t one handed blunt and mystic, _008t bow,
# _010t rapier). tools\weapons\patch_client.ps1 gives every weapon of the ladder
# an effect of its own shape in weapongrp ; this patch wraps
# GetEnchantedWeaponEffect so that the rung is chosen from the enchant level the
# pawn carries.
#
#   the weapon's effect is not on our ladder     -> left alone
#   enchanted below +4                           -> NAME_None, no glow at all
#   +4..+6 / +7..+9 / +10..+11 / +12..+13
#     / +14 / +15..+16 / +17 and up              -> that step's effect
#
# A stock weapongrp goes through this patch unchanged. The other way round it is
# NOT symmetric : this patch needs a weapongrp that carries every name of the
# ladder, for the reason under THE ONE THING TO KNOW below.
#
# How. The five bytes of the function's prologue are replaced with a jump into
# the 0xCC padding that follows engine.dll's incremental-link thunk table. The
# cave calls the original through a trampoline that carries the displaced
# prologue. The names are built once, on the first call, through core.dll's
# FName(const TCHAR*, EFindName) - the import engine.dll already has.
#
# WHAT IS SWAPPED, AND WHY IT MATTERS. Not the FName the original hands back :
# the cave writes the rung into the weapon's own row of weapongrp, the same field
# a hand edited dat carries, BEFORE the original reads it -
#
#   lea  eax,[ecx+6A0h]        the id of the weapon in hand
#   mov  ecx,[10B3E0A4h]       the item data manager
#   call 1030C04Ah             -> the weapon's row, or NULL
#   [row + meshIndex*4 + 1DCh] effA / effB, as an FName
#
# and leaves it there. Putting the old name back is what a hand edited dat never
# does, and the client is free to read that field again later.
#
# So the shape is recognised among ALL the ladder's names, not just the first
# rung's : after one call the field holds whatever rung was handed out last. And
# below the first rung the field is left alone - NAME_None would stick there, the
# name would stop being one of ours, and the weapon could never be graded again -
# so the silence goes into the returned value instead.
#
# THE ONE THING TO KNOW. The client only ever draws an effect whose name was in a
# dat when it loaded. A name this patch invents at run time is ignored, however
# correct : StaticLoadClass resolves it and returns a live class, and nothing is
# drawn. Which is why tools\weapons\patch_client.ps1 deals the rungs round robin
# through weapongrp - every name of the ladder has to be in there at least once.
# Proved by putting rung 17 into the dat : +17 then drew in the world while +15,
# still invented here, stayed invisible. See ../../docs/enchant-glow.md.
#
# EnchantGlow.u itself goes into system\ exactly as it comes : plain, licensee 0,
# the only unwrapped package in the folder. The client reads it that way ; giving
# it the licensee 30 the others carry breaks the format its textures are stored
# in and takes the client down with it. See ../../docs/enchant-glow.md.
#
# The cave holds no absolute address of its own : it learns where it is from a
# call/pop and reaches its table, its strings and the import through that, so
# the patch needs no .reloc entry, the same way patch_engine_npc_packet_color.ps1
# does it.
#
# Set EnchantEffectShow to 4 in system\env.int (patch_env_enchant.ps1) or the
# client will not ask for an effect below the level that file names.
#
# See ../../docs/enchant-glow.md.
#
#   powershell -ExecutionPolicy Bypass -File patch_engine_enchant_glow.ps1 `
#       -In "<client>\system\engine.dll"

[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)][string] $In,
	[string] $OutFile,
	# The package the 56 effects live in. Only the name changes, the layout does not.
	[string] $Package = 'EnchantGlow',
	# The rungs of the ladder, climbing. Below the first one the weapon does not glow at all.
	# Leave a level out to keep that rung out of the ladder entirely - see below. Takes both
	# "4,7,10" and 4,7,10, because powershell -File hands the list over as one string.
	[object[]] $Levels = @(4, 7, 10, 12, 14, 15, 17),
	# Diagnostics. Every step becomes THIS effect, while the names the shapes are recognised
	# by stay what they are. Point it at a stock effect - LineageEffect.c_u007, the aura of
	# an S grade blunt - and one relog says whether the cave runs at all:
	#
	#   every enchanted weapon glows, in game too  -> the cave and the swap are fine
	#   nothing glows                              -> the cave never runs, or runs wrong
	#
	# Mind what it does NOT prove : a stock effect's name came out of a dat, so this glowing
	# says nothing about a rung whose name did not.
	[string] $DiagnoseEffect,
	# Diagnostics of the other kind : append a 16 byte record to a file on EVERY call, saying what
	# the cave saw and what it decided. Nothing else in this client reports anything - l2.log is
	# dead and a failed StaticLoadClass is silent - so this is the only way to tell "the cave never
	# ran" from "it ran and handed back a name the client could not resolve". Read it back with
	# read_enchant_glow_trace.ps1. Off unless asked for : it opens and closes a file per call.
	[switch] $Trace,
	# Where that file goes. Defaults to enchantglow.trace next to the patched engine.dll, which is
	# the client's own system\ - an absolute path, so it does not depend on the working directory.
	[string] $TraceTo,
	# Dev mode. The cave reads a 32 byte file before it does anything else and lets that file
	# override the enchant level it grades by and the offset, scale and velocity the client builds
	# the effect with. Written by set_enchant_glow_live.ps1 ; absent or malformed, nothing is
	# overridden and the build behaves exactly as without this switch.
	#
	# The forced level only decides which RUNG the cave hands out. Whether the client asks for an
	# effect at all is still settled before the call, by comparing the pawn's real level against
	# EnchantEffectShow - so a weapon that is not enchanted needs
	# patch_env_enchant.ps1 -EffectShow 0 as well, or the cave never runs.
	[switch] $Live,
	# Where that file is read from. Defaults to enchantglow.live next to the patched engine.dll.
	[string] $LiveFrom,
	# Where the cave reports back to. Defaults to enchantglow.state next to the patched engine.dll.
	[string] $StateTo,
	# Dev mode, second half. The caller builds the enchant effect once per weapon and then skips
	# the whole thing, so a change to the live config is not seen until the weapon is taken off.
	# This nops out that one comparison, and the effect is rebuilt every tick instead - which is
	# what makes tune_glow_keys.ps1 feel live. Costs an effect actor per frame ; dev builds only.
	[switch] $NoEffectCache,
	# Dev mode, the blunt half. -NoEffectCache alone is not enough : an earlier gate skips the whole
	# routine while the pawn already holds an effect, so nothing is rebuilt until the weapon comes
	# off. This nops that gate too.
	#
	# EXPERIMENTAL, and the reason it is a separate switch : the routine does not tear the old
	# effect down before building the new one, so effects may pile up - watch for the glow getting
	# brighter by itself or the frame rate sagging, and drop this switch if it does.
	[switch] $RebuildAlways
)

$ErrorActionPreference = 'Stop'

$Levels = @(($Levels -join ',') -split '[,;\s]+' | Where-Object { $_ -ne '' } | ForEach-Object { [int]$_ })

# The trace file's path is baked into the cave, so it has to be settled before anything is built.
if ($Trace -and -not $TraceTo)
{
	$near = if ($OutFile) { $OutFile } else { $In }
	$TraceTo = Join-Path ([System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($near))) 'enchantglow.trace'
}
if ($Live -and -not $LiveFrom)
{
	$near = if ($OutFile) { $OutFile } else { $In }
	$LiveFrom = Join-Path ([System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($near))) 'enchantglow.live'
}
if ($Live -and -not $StateTo)
{
	$near = if ($OutFile) { $OutFile } else { $In }
	$StateTo = Join-Path ([System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($near))) 'enchantglow.state'
}

# The eight weapon shapes of EnchantGlow.u, in the order the table is indexed.
$SHAPES = @('001t', '002t', '004t', '005t', '006t', '007t', '008t', '010t')

# ---------------------------------------------------------------- the build --
# .code is mapped at RVA = fileOffset + 0xC00, and the image base is 0x10300000.
$IMAGE_BASE = 0x10300000
$CODE_DELTA = 0xC00

# APawn::GetEnchantedWeaponEffect(FName&, FVector&, float&, float&, int), the body
# behind the incremental-link thunk at RVA 0x69AB.
$OFF_FUNC = 0x32B770                      # RVA 0x32C370
$SIG_FUNC = '558BEC6AFF68B0328210'        # push ebp / mov ebp,esp / push -1 / push 108232B0h
$LEN_HOOK = 5                             # the first three instructions, exactly five bytes

# 0xCC padding behind the thunk table : 65543 bytes of it, nothing jumps in.
$OFF_CAVE = 0x14A00                       # RVA 0x15600
$LEN_CAVE = 0x1F00

# core.dll, through engine.dll's import table.
$IAT_FNAME = 0x11D8D988                   # FName::FName(const TCHAR*, EFindName)
$IAT_LOADCLASS = 0x11D8DAFC               # UObject::StaticLoadClass(...) - what the caller uses too
$IAT_ADDTOROOT = 0x11D8DB3C               # UObject::AddToRoot()
$FNAME_ADD = 1
$LOAD_FLAGS = 0x2000                      # the flags the stock call passes
$EFFECT_CLASS = 0x10C1C4D8                # the UClass StaticLoadClass is asked for, read off the stock call

# kernel32, same table - only the trace and the live config use these.
$IAT_CREATEFILEW = 0x11D8E948
$IAT_SETFILEPOINTER = 0x11D8E974
$IAT_WRITEFILE = 0x11D8EA00
$IAT_READFILE = 0x11D8E944
$IAT_CLOSEHANDLE = 0x11D8E924
$IAT_GETTICKCOUNT = 0x11D8E95C

# -Live : the block the config file is read into, once per call.
#
#   +0  magic     'GLOW', little endian. Anything else and the whole block is ignored.
#   +4  flags     1 offset, 2 scale, 4 velocity, 8 enchant level - each applied only if set
#   +8  enchant   the level the rung is picked by, as an int
#   +12 offX      the three floats the client positions the effect with
#   +16 offY
#   +20 offZ
#   +24 scale
#   +28 velocity
#
# Read whole or not at all : a short read drops the magic, so half a file being written while
# the client reads it can never be applied.
$LIVE_LEN = 32
$LIVE_MAGIC = 0x574F4C47                  # 'GLOW'
$LIVE_F_OFFSET = 1
$LIVE_F_SCALE = 2
$LIVE_F_VELOCITY = 4
$LIVE_F_ENCHANT = 8
# 16 : write that level into the pawn's own field instead of only grading by it. Forcing the level
# inside this function moves the CHOICE of rung and nothing else - every other piece of the client
# still reads [pawn+0x1830] and still sees a weapon that is not enchanted. Writing it makes the
# whole client agree, from the next call on.
$LIVE_F_POKE = 16
# 32 : unused. It used to clear the caller's effect cache on the way out, which never worked : the
# caller writes that field itself the moment this function returns, so the zero was gone before the
# next tick could see it. Rebuilding every tick is -NoEffectCache below, a patch of the comparison
# rather than of the field. Kept out of the flag list so nothing reuses the bit by accident.
# 64 : report back. 16 bytes - magic, the weapon in hand, the level it was graded by, the outcome -
# rewritten on every call, so an editor outside the client knows which weapon it is tuning.
$LIVE_F_STATE = 64

# The report, whole :
#
#   +0  'GLST'
#   +4  [pawn+0x6A0] - the ITEM ID of the weapon in hand, see $FLD_WEAPONID below
#   +8  the level the rung was graded by (the pawn's own, or the one -Live forced)
#   +12 the outcome, the same byte the trace carries, with the step in the bits above it
$STATE_LEN = 16
$STATE_MAGIC = 0x54534C47                 # 'GLST'

# The gates inside the routine that actually builds the effect actor, APawn's
# 0x104B8950, reached from the effect object's constructor. Every one of them
# leaves without spawning anything, and none of them says a word. The trace
# evaluates the same three from the pawn we already hold.
$FN_CAST = 0x10310C1C                     # Cast<?>(pawn) - NULL and the routine returns
$FLD_GATE = 0x134                         # ...and NULL here too
$VF_SOCKET = 0x21C                        # pawn vtable : the FName the effect hangs off

$TRACE_REC = 56                           # bytes per trace record

# The caller's own cache : it builds the effect once per weapon and remembers which weapon it
# built it for. Traced next to the id in hand, because the two being equal on the NEXT call is
# what says the build actually finished - and 4216 calls in one session say it never does.
$FLD_EFFECT_CACHE = 0x182C

# ...and the comparison that reads it, in the routine that calls this function (two call sites,
# 0x104B9B8F and 0x104B9CDA, both behind this one gate) :
#
#   mov ecx,[edi+182Ch]        the weapon an effect was already built for
#   cmp ecx,[edi+6A0h]         against the weapon in hand
#   je  <out>                  equal - build nothing
#
# -NoEffectCache turns that je into six nops. Clearing the field from inside the hook does NOT
# work : the caller writes it again the moment the hook returns.
$OFF_CACHE_JE = 0x1B8ED0                  # file ; the mov is at 0x1B8EC4, the cmp at 0x1B8ECA
$SIG_CACHE_JE = '0F84D9020000'

# ...and the gate BEFORE it, which is the one that really stops a rebuild :
#
#   1B8E83  cmp dword [edi+16A4h],0    how many effects this pawn already holds
#   1B8E8A  jne <out>                  it holds one - do nothing at all
#
# [edi+16A0] is the array and [edi+16A4] its count : the code above walks it as
# [[edi+16A0] + (count-1)*4]. So while an effect exists, the routine never reaches the cache
# check, never reaches this function, and nothing new is built - which is exactly the
# "I have to re-equip after every change" symptom. Nopping this makes the effect be rebuilt
# every tick, and the old one is NOT torn down first : see -RebuildAlways.
$OFF_HELD_JNE = 0x1B8E8A
$SIG_HELD_JNE = '0F851F030000'

# APawn::AttackItemEnchantedValue - what the caller compares against
# EnchantEffectShow before it asks for an effect at all.
$FLD_ENCHANT = 0x1830

# How the original reaches the weapon's row of weapongrp. Read straight off its body :
#
#   lea  eax,[ecx+6A0h]           the id of the weapon in hand
#   mov  ecx,[10B3E0A4h]          the item data manager
#   call 1030C04Ah                -> the weapon's data, or NULL
#   mov  eax,[esi+edi*4+1DCh]     effA / effB, by mesh index, as an FName
#
# That FName is what the rung is written over : the same field the dat carries, changed
# just before the original reads it and put back the moment it has.
#
# [pawn+0x6A0] IS the item id, and this is where that is settled rather than guessed.
# FindWeapon (the thunk at 0x1030C04A, body at 0x10422EE0) is a TMap<INT,...>::Find :
#
#   mov edx,[eax]                  eax = the ADDRESS handed in, so edx = [pawn+6A0] - the KEY
#   mov eax,[ecx+10h] ; sub eax,1  the hash mask
#   mov esi,[ecx+0Ch] ; and eax,edx ; mov eax,[esi+eax*4]     the bucket
#   cmp [esi+ecx*4+4],edx          each element is 3 dwords : next, KEY, value
#   mov eax,[esi+edx*4+8]          the row - the VALUE, keyed by that number
#
# So the number at +0x6A0 is the key weapongrp is indexed by, which is its id column, and the
# row that comes back carries no id of its own. A value that is not in weapongrp (5646 was one)
# just means the thing in hand is not a weapon of the table : Find returns NULL and the original
# gives up, exactly as it does for us.
$FLD_WEAPONID = 0x6A0
$VAR_ITEMDATA = 0x10B3E0A4                # the manager, a global
$FN_FINDWEAPON = 0x1030C04A               # thiscall(manager, &itemId) -> weapon data
$FLD_WD_BUSY = 0x04                       # non zero and the original gives up
$FLD_WD_EFFECT = 0x1DC                    # + meshIndex*4

# Layout inside the cave. Fixed rather than packed, so that the disassembly of a
# patched file is readable and a rerun lands on the same bytes. The room for the
# trace is reserved whether or not -Trace is on, so that both builds put every
# other piece at the same offset and two disassemblies line up.
$AT_HOOK = 0x0000
$AT_TRAMP = 0x0500
$AT_BUILT = 0x0510
$AT_TABLE = 0x0520                        # 64 FName indices : 56 steps, then the 8 keys
$AT_PINNED = 0x0620                       # 64 slots : the UClass rooted for this step, -1 if it will not load
$AT_REC = 0x0720                          # the trace record, then the DWORD WriteFile fills in
$AT_PATH = 0x0780                         # where the trace goes, UTF-16, NUL terminated
$AT_NAMES = 0x0A00                        # 64 slots of $SLOT bytes, UTF-16, NUL terminated
$AT_LIVE = 0x1A00                         # the 32 bytes of the live config, as read
$AT_LIVEREAD = 0x1A20                     # the DWORD ReadFile fills in
$AT_LIVEPATH = 0x1A40                     # where that file is, UTF-16, NUL terminated
$AT_STATE = 0x1C80                        # what the cave reports back : 16 bytes
$AT_STATEWROTE = 0x1CC0                   # the DWORD WriteFile fills in
$AT_STATEPATH = 0x1CE0                    # where that report goes, UTF-16, NUL terminated
$SLOT = 64
$PATH_SLOT = 520                          # 260 wchar, MAX_PATH

# One step per shape per level, and then eight more names - one per shape - that are
# only ever compared against, never returned. They are what weapongrp holds, so they
# must stay themselves even when -DiagnoseEffect rewrites every step.
#
# -Levels does not have to be the full seven. A rung whose class loads but will not
# DRAW is invisible to the walk down the ladder - that only catches a class that will
# not load - so the way to keep such a rung out is to leave its level out of this list.
# Drop 15 and 17 and the ladder becomes 4/7/10/12/14, with +14 covering everything
# above it. The table has room for 64 names, which is what caps the list.
$COUNT = $SHAPES.Count * $Levels.Count
$KEYS = $SHAPES.Count
$SLOTS = $COUNT + $KEYS
if ($Levels.Count -lt 1) { throw 'at least one level is needed.' }
if ($Levels.Count -gt 1)
{
	foreach ($i in 1..($Levels.Count - 1)) { if ($Levels[$i] -le $Levels[$i - 1]) { throw '-Levels has to climb.' } }
}
if ($SLOTS -gt 64) { throw "$($SHAPES.Count) shapes x $($Levels.Count) levels plus $KEYS keys is $SLOTS names, and the table holds 64." }

# ------------------------------------------------------------------ helpers --
function Get-Hex([byte[]] $bytes, [int] $at, [int] $len)
{
	($bytes[$at..($at + $len - 1)] | ForEach-Object { '{0:X2}' -f $_ }) -join ''
}

# A two pass assembler over the handful of instructions this cave needs. Labels
# are offsets inside the cave ; every instruction has a fixed length whatever the
# label resolves to, so the second pass only fills displacements in.
$script:code = $null
$script:labels = $null
$script:fixups = $null

function B([byte[]] $v) { $script:code.AddRange($v) }
function I32([int] $v) { $script:code.AddRange([BitConverter]::GetBytes($v)) }
function L([string] $n) { $script:labels[$n] = $script:code.Count }
function Rel8([string] $n)
{
	$script:fixups += , @{ pos = $script:code.Count; label = $n; kind = 'rel8' }
	$script:code.Add(0)
}
function Rel32([string] $n)
{
	$script:fixups += , @{ pos = $script:code.Count; label = $n; kind = 'rel32' }
	$script:code.AddRange([byte[]]@(0, 0, 0, 0))
}
# The virtual address a cave label will have once the image is at its preferred
# base. Everything the cave touches is reached as [ebx + <that>], ebx being the
# difference between where the image really landed and that base.
function Va([string] $n, [int] $add = 0)
{
	$script:fixups += , @{ pos = $script:code.Count; label = $n; kind = 'va'; add = $add }
	$script:code.AddRange([byte[]]@(0, 0, 0, 0))
}
function Abs32([int] $v) { I32 $v }

function Assemble([scriptblock] $body)
{
	$caveVa = $IMAGE_BASE + $OFF_CAVE + $CODE_DELTA
	for ($pass = 0; $pass -lt 2; $pass++)
	{
		$script:code = New-Object 'System.Collections.Generic.List[byte]'
		$script:labels = @{}
		$script:fixups = @()
		& $body
		if ($pass -eq 0) { continue }

		foreach ($f in $script:fixups)
		{
			if (-not $script:labels.ContainsKey($f.label)) { throw "unknown label $($f.label)." }
			$target = $script:labels[$f.label]
			switch ($f.kind)
			{
				'rel8'
				{
					$d = $target - ($f.pos + 1)
					if ($d -lt -128 -or $d -gt 127) { throw "$($f.label) is $d bytes away, too far for a short jump." }
					$script:code[$f.pos] = [byte]([sbyte]$d -band 0xFF)
				}
				'rel32'
				{
					$d = $target - ($f.pos + 4)
					$b = [BitConverter]::GetBytes([int]$d)
					for ($i = 0; $i -lt 4; $i++) { $script:code[$f.pos + $i] = $b[$i] }
				}
				'va'
				{
					$b = [BitConverter]::GetBytes([int]($caveVa + $target + $f.add))
					for ($i = 0; $i -lt 4; $i++) { $script:code[$f.pos + $i] = $b[$i] }
				}
			}
		}
	}
	, $script:code.ToArray()
}

# -------------------------------------------------------------------- input --
if (!(Test-Path $In)) { throw "No such file: $In" }
$bytes = [System.IO.File]::ReadAllBytes($In)

$found = Get-Hex $bytes $OFF_FUNC ($SIG_FUNC.Length / 2)
if ($found -ne $SIG_FUNC)
{
	Write-Host "expected : $SIG_FUNC"
	Write-Host "found    : $found"
	throw 'GetEnchantedWeaponEffect does not look like the build this patch was written for. Nothing changed.'
}
foreach ($i in 0..($LEN_CAVE - 1))
{
	if ($bytes[$OFF_CAVE + $i] -ne 0xCC)
	{
		throw ("The padding at 0x{0:X} is not free at byte {1} - already patched, or another build. Nothing changed." -f $OFF_CAVE, $i)
	}
}

# --------------------------------------------------------------------- code --
$funcVa = $IMAGE_BASE + $OFF_FUNC + $CODE_DELTA
$caveVa = $IMAGE_BASE + $OFF_CAVE + $CODE_DELTA

$cave = Assemble {

	# ---- hook : the wrapper the function's prologue now jumps to.
	# On entry ecx = the APawn, and the five arguments are where the caller left
	# them : [esp+4] the FName to fill, then the offset, the scale, the velocity
	# and the weapon mesh index.
	# [ebp-04] unused
	# [ebp-08] what the original returned, and what we hand back
	# [ebp-0C] what happened, for the trace
	# [ebp-10] the effA/effB field we overwrote, NULL if we left it alone
	# [ebp-14] the trace file's handle
	# [ebp-18] the FName that field held, to be put back
	# [ebp-1C] scratch
	# [ebp-20] the live config's file handle
	# [ebp-24] the level the rung was actually graded by, -1 if it never got that far
	# [ebp-28] spare
	L 'hook'
	B @(0x55)                                    # push ebp
	B @(0x8B, 0xEC)                              # mov  ebp,esp
	B @(0x83, 0xEC, 0x28)                        # sub  esp,28h
	B @(0x53, 0x56, 0x57)                        # push ebx / esi / edi
	B @(0x8B, 0xF1)                              # mov  esi,ecx        ; the pawn

	# Where are we ? ebx ends up holding the difference between the image's real
	# base and the one every address below was written for.
	B @(0xE8, 0x00, 0x00, 0x00, 0x00)            # call $+5
	L 'here'
	B @(0x5B)                                    # pop  ebx
	B @(0x81, 0xEB) ; Va 'here'                  # sub  ebx,<here>

	B @(0xC7, 0x45, 0xF0) ; I32 0                # mov  dword [ebp-10h],0  ; nothing overwritten
	B @(0xC7, 0x45, 0xF4) ; I32 0                # mov  dword [ebp-0Ch],0  ; outcome
	B @(0xC7, 0x45, 0xE8) ; I32 0                # mov  dword [ebp-18h],0
	B @(0xC7, 0x45, 0xFC) ; I32 -1               # mov  dword [ebp-4],-1   ; no rung picked yet
	B @(0xC7, 0x45, 0xDC) ; I32 -1               # mov  dword [ebp-24h],-1 ; nor a level to grade by

	# ---- the names, built once and kept.
	B @(0x83, 0xBB) ; Va 'built' ; B @(0x00)     # cmp  dword [ebx+<built>],0
	B @(0x75) ; Rel8 'have'                      # jnz  have
	B @(0xC7, 0x83) ; Va 'built' ; I32 1         # mov  dword [ebx+<built>],1
	B @(0x33, 0xFF)                              # xor  edi,edi
	L 'build'
	B @(0x6A, [byte]$FNAME_ADD)                  # push FNAME_Add
	B @(0x8B, 0xC7)                              # mov  eax,edi
	B @(0x6B, 0xC0, [byte]$SLOT)                 # imul eax,eax,<slot>
	B @(0x03, 0xC3)                              # add  eax,ebx
	B @(0x05) ; Va 'names'                       # add  eax,<names>
	B @(0x50)                                    # push eax
	B @(0x8B, 0xCF)                              # mov  ecx,edi
	B @(0xC1, 0xE1, 0x02)                        # shl  ecx,2
	B @(0x03, 0xCB)                              # add  ecx,ebx
	B @(0x81, 0xC1) ; Va 'table'                 # add  ecx,<table>
	B @(0xFF, 0x93) ; Abs32 $IAT_FNAME           # call [ebx+<FName ctor>]
	B @(0x47)                                    # inc  edi
	B @(0x83, 0xFF, [byte]$SLOTS)                # cmp  edi,64
	B @(0x72) ; Rel8 'build'                     # jb   build
	L 'have'

	# ---- the live config, re-read on every call so that editing the file shows up in the
	# game without a relog. The magic is cleared first : a torn or short read then leaves
	# the block invalid rather than half of last frame's numbers.
	if ($Live)
	{
		B @(0xC7, 0x83) ; Va 'live' 0 ; I32 0        # mov  dword [ebx+<live>],0
		B @(0xC7, 0x83) ; Va 'liveread' 0 ; I32 0    # mov  dword [ebx+<liveread>],0

		B @(0x6A, 0x00)                              # push 0            ; hTemplateFile
		B @(0x68) ; I32 0x80                         # push 80h          ; FILE_ATTRIBUTE_NORMAL
		B @(0x6A, 0x03)                              # push 3            ; OPEN_EXISTING
		B @(0x6A, 0x00)                              # push 0            ; lpSecurityAttributes
		B @(0x6A, 0x03)                              # push 3            ; FILE_SHARE_READ|WRITE
		B @(0x68) ; I32 ([int]::MinValue)            # push 80000000h    ; GENERIC_READ
		B @(0x8D, 0x83) ; Va 'livepath'              # lea  eax,[ebx+<livepath>]
		B @(0x50)                                    # push eax
		B @(0xFF, 0x93) ; Abs32 $IAT_CREATEFILEW     # call [ebx+<CreateFileW>]
		B @(0x83, 0xF8, 0xFF)                        # cmp  eax,-1       ; no file, nothing to apply
		B @(0x74) ; Rel8 'live_done'                 # je   live_done
		B @(0x89, 0x45, 0xE0)                        # mov  [ebp-20h],eax

		B @(0x6A, 0x00)                              # push 0            ; lpOverlapped
		B @(0x8D, 0x8B) ; Va 'liveread'              # lea  ecx,[ebx+<liveread>]
		B @(0x51)                                    # push ecx
		B @(0x6A, [byte]$LIVE_LEN)                   # push <32>
		B @(0x8D, 0x93) ; Va 'live'                  # lea  edx,[ebx+<live>]
		B @(0x52)                                    # push edx
		B @(0xFF, 0x75, 0xE0)                        # push [ebp-20h]
		B @(0xFF, 0x93) ; Abs32 $IAT_READFILE        # call [ebx+<ReadFile>]

		B @(0xFF, 0x75, 0xE0)                        # push [ebp-20h]
		B @(0xFF, 0x93) ; Abs32 $IAT_CLOSEHANDLE     # call [ebx+<CloseHandle>]

		B @(0x81, 0xBB) ; Va 'liveread' ; I32 $LIVE_LEN  # cmp dword [ebx+<liveread>],<32>
		B @(0x74) ; Rel8 'live_done'                 # je   live_done
		B @(0xC7, 0x83) ; Va 'live' 0 ; I32 0        # mov  dword [ebx+<live>],0
		L 'live_done'
	}

	# ---- reach the weapon's own row of weapongrp, the way the original does it.
	B @(0x8D, 0x86) ; Abs32 $FLD_WEAPONID        # lea  eax,[esi+6A0h] ; &id of the weapon in hand
	B @(0x83, 0x38, 0x00)                        # cmp  dword [eax],0
	B @(0x0F, 0x84) ; Rel32 'call_orig'          # je   call_orig      ; nothing equipped
	B @(0x50)                                    # push eax
	B @(0x8B, 0x8B) ; Abs32 $VAR_ITEMDATA        # mov  ecx,[ebx+<item data>]
	B @(0x8D, 0x93) ; Abs32 $FN_FINDWEAPON       # lea  edx,[ebx+<FindWeapon>]
	B @(0xFF, 0xD2)                              # call edx            ; thiscall, cleans its own
	B @(0x85, 0xC0)                              # test eax,eax
	B @(0x0F, 0x84) ; Rel32 'call_orig'          # je   call_orig
	B @(0x83, 0x78, [byte]$FLD_WD_BUSY, 0x00)    # cmp  dword [eax+4],0
	B @(0x0F, 0x85) ; Rel32 'call_orig'          # jne  call_orig      ; the original would give up too
	B @(0x8B, 0x4D, 0x18)                        # mov  ecx,[ebp+18h]  ; the mesh index
	B @(0x8D, 0x04, 0x88)                        # lea  eax,[eax+ecx*4]
	B @(0x05) ; I32 $FLD_WD_EFFECT               # add  eax,1DCh       ; &effA / &effB
	B @(0x89, 0x45, 0xE4)                        # mov  [ebp-1Ch],eax  ; the field itself
	B @(0x8B, 0x08)                              # mov  ecx,[eax]      ; what the dat put there
	B @(0x89, 0x4D, 0xE8)                        # mov  [ebp-18h],ecx  ; to be put back after

	# ---- which of the eight shapes is this ?
	#
	# The rung stays in the field once written - that is the whole point, it is what the dat
	# would hold - so on the second call the field no longer carries the shape's first rung
	# but whatever rung we last put there. So the name is looked up among ALL of them, the
	# steps as well as the eight keys, and the shape is worked out from where it was found.
	B @(0x8B, 0xC1)                              # mov  eax,ecx
	B @(0x33, 0xFF)                              # xor  edi,edi
	L 'find'
	B @(0x8B, 0xCF)                              # mov  ecx,edi
	B @(0xC1, 0xE1, 0x02)                        # shl  ecx,2
	B @(0x03, 0xCB)                              # add  ecx,ebx
	B @(0x3B, 0x81) ; Va 'table'                 # cmp  eax,[ecx+<table>]
	B @(0x74) ; Rel8 'found'                     # je   found
	B @(0x47)                                    # inc  edi
	B @(0x83, 0xFF, [byte]$SLOTS)                # cmp  edi,<steps + keys>
	B @(0x72) ; Rel8 'find'                      # jb   find
	B @(0xC7, 0x45, 0xF4) ; I32 1                # mov  dword [ebp-0Ch],1  ; not one of ours
	B @(0xE9) ; Rel32 'call_orig'                # jmp  call_orig      ; somebody else's effect
	L 'found'
	# edi is the slot it matched. Past the steps it is one of the keys, and the shape is the
	# offset into them ; inside the steps the shape is the slot divided by the rung count.
	B @(0x83, 0xFF, [byte]$COUNT)                # cmp  edi,<steps>
	B @(0x7C) ; Rel8 'from_step'                 # jl   from_step
	B @(0x83, 0xEF, [byte]$COUNT)                # sub  edi,<steps>
	B @(0xEB) ; Rel8 'have_shape'                # jmp  have_shape
	L 'from_step'
	B @(0x8B, 0xC7)                              # mov  eax,edi
	B @(0x33, 0xD2)                              # xor  edx,edx
	B @(0xB9) ; I32 $Levels.Count                # mov  ecx,<rungs>
	B @(0xF7, 0xF1)                              # div  ecx
	B @(0x8B, 0xF8)                              # mov  edi,eax        ; the shape
	L 'have_shape'

	# ---- which rung ? Under the first level there is no glow at all, and NAME_None in
	# the field is what the original turns into "no effect" all by itself.
	B @(0x8B, 0x86) ; Abs32 $FLD_ENCHANT         # mov  eax,[esi+1830h]
	# Dev mode : grade by the level the config names instead of the one the pawn carries. Only
	# the CHOICE of rung moves - whether the client asked for an effect at all was settled
	# against the real level before this function was ever called.
	if ($Live)
	{
		B @(0x81, 0xBB) ; Va 'live' ; I32 $LIVE_MAGIC        # cmp  dword [ebx+<live>],'GLOW'
		B @(0x75) ; Rel8 'have_level'                        # jne  have_level
		B @(0xF7, 0x83) ; Va 'live' 4 ; I32 $LIVE_F_ENCHANT  # test dword [ebx+<live>+4],8
		B @(0x74) ; Rel8 'have_level'                        # jz   have_level
		B @(0x8B, 0x83) ; Va 'live' 8                        # mov  eax,[ebx+<live>+8]
		B @(0xF7, 0x83) ; Va 'live' 4 ; I32 $LIVE_F_POKE     # test dword [ebx+<live>+4],16
		B @(0x74) ; Rel8 'have_level'                        # jz   have_level
		B @(0x89, 0x86) ; Abs32 $FLD_ENCHANT                 # mov  [esi+1830h],eax
		L 'have_level'
	}
	B @(0x89, 0x45, 0xDC)                        # mov  [ebp-24h],eax  ; what the grading saw
	B @(0x83, 0xF8, [byte]$Levels[0])            # cmp  eax,<first level>
	B @(0x7D) ; Rel8 'grade'                     # jge  grade
	# Under the first rung there is no glow - but the FIELD is left alone. Writing NAME_None
	# into it would stick, the name would stop being one of ours, and the weapon could never
	# be graded again. So the silence goes into the returned value instead, after the call.
	B @(0xC7, 0x45, 0xFC) ; I32 1                # mov  dword [ebp-4],1    ; hush it afterwards
	B @(0xC7, 0x45, 0xF4) ; I32 2                # mov  dword [ebp-0Ch],2
	B @(0xE9) ; Rel32 'call_orig'                # jmp  call_orig
	L 'grade'
	B @(0x33, 0xC9)                              # xor  ecx,ecx
	for ($i = 1; $i -lt $Levels.Count; $i++)
	{
		B @(0x83, 0xF8, [byte]$Levels[$i])       # cmp  eax,<level>
		B @(0x7C) ; Rel8 'pick'                  # jl   pick
		B @(0x41)                                # inc  ecx
	}
	L 'pick'
	# edi = the shape, ecx = the rung within it.
	B @(0x8B, 0xC7)                              # mov  eax,edi
	B @(0x6B, 0xC0, [byte]$Levels.Count)         # imul eax,eax,<levels>
	B @(0x03, 0xC1)                              # add  eax,ecx
	B @(0x8B, 0xF8)                              # mov  edi,eax        ; the step
	B @(0x8D, 0x14, 0xBB)                        # lea  edx,[ebx+edi*4]
	B @(0x8B, 0x82) ; Va 'table'                 # mov  eax,[edx+<table>]
	B @(0x8B, 0x4D, 0xE4)                        # mov  ecx,[ebp-1Ch]
	B @(0x89, 0x4D, 0xF0)                        # mov  [ebp-10h],ecx  ; remember to restore it
	B @(0x89, 0x01)                              # mov  [ecx],eax      ; the rung, in the dat's own field
	B @(0x8B, 0xC7)                              # mov  eax,edi
	B @(0xC1, 0xE0, 0x08)                        # shl  eax,8
	B @(0x83, 0xC8, 0x03)                        # or   eax,3
	B @(0x89, 0x45, 0xF4)                        # mov  [ebp-0Ch],eax

	# ---- the original, with its own arguments and its own this. It now reads the rung
	# out of the weapon's row and does everything else exactly as it would for a dat that
	# had been edited by hand.
	L 'call_orig'
	B @(0xFF, 0x75, 0x18)                        # push [ebp+18h]
	B @(0xFF, 0x75, 0x14)                        # push [ebp+14h]
	B @(0xFF, 0x75, 0x10)                        # push [ebp+10h]
	B @(0xFF, 0x75, 0x0C)                        # push [ebp+0Ch]
	B @(0xFF, 0x75, 0x08)                        # push [ebp+8]
	B @(0x8B, 0xCE)                              # mov  ecx,esi
	B @(0x8D, 0x83) ; Va 'tramp'                 # lea  eax,[ebx+<tramp>]
	B @(0xFF, 0xD0)                              # call eax            ; cleans its own 14h
	B @(0x89, 0x45, 0xF8)                        # mov  [ebp-8],eax

	# The rung STAYS in the row. Putting the old name back is what a hand edited dat never
	# does, and the client is free to read that field again later ; leaving it alone is the
	# whole point of writing it there rather than into the value the original returns.
	#
	# The one thing that does go into the returned value is silence below the first rung.
	B @(0x83, 0x7D, 0xFC, 0x01)                  # cmp  dword [ebp-4],1
	B @(0x75, 0x09)                              # jne  +9 : past both instructions below
	B @(0x8B, 0x4D, 0xF8)                        # mov  ecx,[ebp-8]
	B @(0xC7, 0x01) ; I32 0                      # mov  dword [ecx],0  ; NAME_None
	L 'done'

	# ---- dev mode : the three out-parameters the caller builds the effect with.
	#
	# [ebp+0Ch] the FVector it is offset by, [ebp+10h] its scale, [ebp+14h] the speed of its
	# particles - the same numbers weapongrp carries per weapon, which the original has just
	# filled in from the row. Overwriting them here is what lets a value be tried without
	# rebuilding the dat. Each is guarded twice : by its flag, and by the pointer being real.
	if ($Live)
	{
		B @(0x81, 0xBB) ; Va 'live' ; I32 $LIVE_MAGIC         # cmp  dword [ebx+<live>],'GLOW'
		B @(0x0F, 0x85) ; Rel32 'live_off'                    # jne  live_off

		B @(0xF7, 0x83) ; Va 'live' 4 ; I32 $LIVE_F_OFFSET    # test dword [ebx+<live>+4],1
		B @(0x74) ; Rel8 'no_off'                             # jz   no_off
		B @(0x8B, 0x45, 0x0C)                                 # mov  eax,[ebp+0Ch]
		B @(0x85, 0xC0)                                       # test eax,eax
		B @(0x74) ; Rel8 'no_off'                             # jz   no_off
		B @(0x8B, 0x8B) ; Va 'live' 12                        # mov  ecx,[ebx+<live>+12]
		B @(0x89, 0x08)                                       # mov  [eax],ecx
		B @(0x8B, 0x8B) ; Va 'live' 16                        # mov  ecx,[ebx+<live>+16]
		B @(0x89, 0x48, 0x04)                                 # mov  [eax+4],ecx
		B @(0x8B, 0x8B) ; Va 'live' 20                        # mov  ecx,[ebx+<live>+20]
		B @(0x89, 0x48, 0x08)                                 # mov  [eax+8],ecx
		L 'no_off'

		B @(0xF7, 0x83) ; Va 'live' 4 ; I32 $LIVE_F_SCALE     # test dword [ebx+<live>+4],2
		B @(0x74) ; Rel8 'no_scale'                           # jz   no_scale
		B @(0x8B, 0x45, 0x10)                                 # mov  eax,[ebp+10h]
		B @(0x85, 0xC0)                                       # test eax,eax
		B @(0x74) ; Rel8 'no_scale'                           # jz   no_scale
		B @(0x8B, 0x8B) ; Va 'live' 24                        # mov  ecx,[ebx+<live>+24]
		B @(0x89, 0x08)                                       # mov  [eax],ecx
		L 'no_scale'

		B @(0xF7, 0x83) ; Va 'live' 4 ; I32 $LIVE_F_VELOCITY  # test dword [ebx+<live>+4],4
		B @(0x74) ; Rel8 'no_vel'                             # jz   no_vel
		B @(0x8B, 0x45, 0x14)                                 # mov  eax,[ebp+14h]
		B @(0x85, 0xC0)                                       # test eax,eax
		B @(0x74) ; Rel8 'no_vel'                             # jz   no_vel
		B @(0x8B, 0x8B) ; Va 'live' 28                        # mov  ecx,[ebx+<live>+28]
		B @(0x89, 0x08)                                       # mov  [eax],ecx
		L 'no_vel'
		L 'live_off'

		# ---- report back : which weapon this call was for, so that an editor outside the client
		# can save what was dialled in against that weapon rather than against a guess. Rewritten
		# whole every time (CREATE_ALWAYS), so a reader never sees a mix of two calls.
		B @(0x81, 0xBB) ; Va 'live' ; I32 $LIVE_MAGIC        # cmp  dword [ebx+<live>],'GLOW'
		B @(0x0F, 0x85) ; Rel32 'no_state'                   # jne  no_state
		B @(0xF7, 0x83) ; Va 'live' 4 ; I32 $LIVE_F_STATE    # test dword [ebx+<live>+4],64
		B @(0x0F, 0x84) ; Rel32 'no_state'                   # jz   no_state

		B @(0xC7, 0x83) ; Va 'state' 0 ; I32 $STATE_MAGIC    # mov  dword [ebx+<state>],'GLST'
		B @(0x8B, 0x86) ; Abs32 $FLD_WEAPONID                # mov  eax,[esi+6A0h]
		B @(0x89, 0x83) ; Va 'state' 4                       # mov  [ebx+<state>+4],eax
		B @(0x8B, 0x45, 0xDC)                                # mov  eax,[ebp-24h]  ; level graded by
		B @(0x89, 0x83) ; Va 'state' 8                       # mov  [ebx+<state>+8],eax
		B @(0x8B, 0x45, 0xF4)                                # mov  eax,[ebp-0Ch]  ; outcome and step
		B @(0x89, 0x83) ; Va 'state' 12                      # mov  [ebx+<state>+12],eax

		# Nothing else is reported : the id is at +4, and the row FindWeapon hands back carries no
		# id of its own - it is the map's VALUE, the id is its KEY. See $FLD_WEAPONID.
		B @(0x6A, 0x00)                                      # push 0            ; hTemplateFile
		B @(0x68) ; I32 0x80                                 # push 80h
		B @(0x6A, 0x02)                                      # push 2            ; CREATE_ALWAYS
		B @(0x6A, 0x00)                                      # push 0
		B @(0x6A, 0x03)                                      # push 3            ; FILE_SHARE_READ|WRITE
		B @(0x68) ; I32 0x40000000                           # push 40000000h    ; GENERIC_WRITE
		B @(0x8D, 0x83) ; Va 'statepath'                     # lea  eax,[ebx+<statepath>]
		B @(0x50)                                            # push eax
		B @(0xFF, 0x93) ; Abs32 $IAT_CREATEFILEW             # call [ebx+<CreateFileW>]
		B @(0x83, 0xF8, 0xFF)                                # cmp  eax,-1
		B @(0x74) ; Rel8 'no_state'                          # je   no_state
		B @(0x89, 0x45, 0xE0)                                # mov  [ebp-20h],eax

		B @(0x6A, 0x00)                                      # push 0            ; lpOverlapped
		B @(0x8D, 0x8B) ; Va 'statewrote'                    # lea  ecx,[ebx+<statewrote>]
		B @(0x51)                                            # push ecx
		B @(0x6A, [byte]$STATE_LEN)                          # push <the report's size>
		B @(0x8D, 0x93) ; Va 'state'                         # lea  edx,[ebx+<state>]
		B @(0x52)                                            # push edx
		B @(0xFF, 0x75, 0xE0)                                # push [ebp-20h]
		B @(0xFF, 0x93) ; Abs32 $IAT_WRITEFILE               # call [ebx+<WriteFile>]

		B @(0xFF, 0x75, 0xE0)                                # push [ebp-20h]
		B @(0xFF, 0x93) ; Abs32 $IAT_CLOSEHANDLE             # call [ebx+<CloseHandle>]
		L 'no_state'

	}

	# ---- the trace : one 16 byte record per call, appended.
	#
	# enchant level | the FName that came in | what happened | the class, if any
	#
	# Nothing else in this client says a word - l2.log is dead and a StaticLoadClass that comes
	# back empty is silent - so this is what separates "the cave never ran" from "it ran and the
	# name it handed back would not resolve". stdcall throughout, so nothing to clean up.
	if ($Trace)
	{
		B @(0x8B, 0x86) ; Abs32 $FLD_ENCHANT     # mov  eax,[esi+1830h]
		B @(0x89, 0x83) ; Va 'rec' 0             # mov  [ebx+<rec>+0],eax
		B @(0x8B, 0x45, 0xE8)                    # mov  eax,[ebp-18h]
		B @(0x89, 0x83) ; Va 'rec' 4             # mov  [ebx+<rec>+4],eax
		B @(0x8B, 0x45, 0xF4)                    # mov  eax,[ebp-0Ch]
		B @(0x89, 0x83) ; Va 'rec' 8             # mov  [ebx+<rec>+8],eax
		B @(0x8B, 0x45, 0xF0)                    # mov  eax,[ebp-10h]
		B @(0x89, 0x83) ; Va 'rec' 12            # mov  [ebx+<rec>+12],eax
		B @(0xFF, 0x93) ; Abs32 $IAT_GETTICKCOUNT # call [ebx+<GetTickCount>]
		B @(0x89, 0x83) ; Va 'rec' 16            # mov  [ebx+<rec>+16],eax
		B @(0x89, 0xB3) ; Va 'rec' 20            # mov  [ebx+<rec>+20],esi ; which pawn

		B @(0x8B, 0x45, 0xE4)                    # mov  eax,[ebp-1Ch]
		B @(0x89, 0x83) ; Va 'rec' 24            # mov  [ebx+<rec>+24],eax ; the field we wrote

		# The three gates the spawn routine will hit after us, evaluated here from the same pawn.
		B @(0x56)                                # push esi          ; the pawn
		B @(0x8D, 0x83) ; Abs32 $FN_CAST         # lea  eax,[ebx+<Cast>]
		B @(0xFF, 0xD0)                          # call eax
		B @(0x83, 0xC4, 0x04)                    # add  esp,4        ; cdecl
		B @(0x89, 0x83) ; Va 'rec' 28            # mov  [ebx+<rec>+28],eax
		B @(0x33, 0xC9)                          # xor  ecx,ecx
		B @(0x85, 0xC0)                          # test eax,eax
		B @(0x74, 0x06)                          # jz   +6
		B @(0x8B, 0x88) ; Abs32 $FLD_GATE        # mov  ecx,[eax+134h]
		B @(0x89, 0x8B) ; Va 'rec' 32            # mov  [ebx+<rec>+32],ecx

		B @(0xC7, 0x45, 0xE4) ; I32 0            # mov  dword [ebp-1Ch],0
		B @(0x8B, 0x16)                          # mov  edx,[esi]    ; the pawn's vtable
		B @(0x8B, 0x92) ; Abs32 $VF_SOCKET       # mov  edx,[edx+21Ch]
		B @(0x8D, 0x45, 0xE4)                    # lea  eax,[ebp-1Ch]
		B @(0x50)                                # push eax          ; where it puts the FName
		B @(0x8B, 0xCE)                          # mov  ecx,esi
		B @(0xFF, 0xD2)                          # call edx
		B @(0x8B, 0x00)                          # mov  eax,[eax]
		B @(0x89, 0x83) ; Va 'rec' 36            # mov  [ebx+<rec>+36],eax
		# The level the rung was graded by - the pawn's own unless -Live overrode it - and the
		# magic of the live block, which is 0 whenever that file was missing or unreadable.
		B @(0x8B, 0x45, 0xDC)                    # mov  eax,[ebp-24h]
		B @(0x89, 0x83) ; Va 'rec' 40            # mov  [ebx+<rec>+40],eax
		B @(0x8B, 0x83) ; Va 'live' 0            # mov  eax,[ebx+<live>]
		B @(0x89, 0x83) ; Va 'rec' 44            # mov  [ebx+<rec>+44],eax

		# The caller's cache against the weapon in hand : equal on the next call means the build
		# finished, and a cache that never catches up means it never does.
		B @(0x8B, 0x86) ; Abs32 $FLD_EFFECT_CACHE # mov eax,[esi+182Ch]
		B @(0x89, 0x83) ; Va 'rec' 48            # mov  [ebx+<rec>+48],eax
		B @(0x8B, 0x86) ; Abs32 $FLD_WEAPONID    # mov  eax,[esi+6A0h]
		B @(0x89, 0x83) ; Va 'rec' 52            # mov  [ebx+<rec>+52],eax

		B @(0x6A, 0x00)                          # push 0            ; hTemplateFile
		B @(0x68) ; I32 0x80                     # push 80h          ; FILE_ATTRIBUTE_NORMAL
		B @(0x6A, 0x04)                          # push 4            ; OPEN_ALWAYS
		B @(0x6A, 0x00)                          # push 0            ; lpSecurityAttributes
		B @(0x6A, 0x01)                          # push 1            ; FILE_SHARE_READ
		B @(0x68) ; I32 0x40000000               # push 40000000h    ; GENERIC_WRITE
		B @(0x8D, 0x83) ; Va 'path'              # lea  eax,[ebx+<path>]
		B @(0x50)                                # push eax
		B @(0xFF, 0x93) ; Abs32 $IAT_CREATEFILEW # call [ebx+<CreateFileW>]
		B @(0x83, 0xF8, 0xFF)                    # cmp  eax,-1       ; INVALID_HANDLE_VALUE
		B @(0x74) ; Rel8 'no_trace'              # je   no_trace
		B @(0x89, 0x45, 0xEC)                    # mov  [ebp-14h],eax

		B @(0x6A, 0x02)                          # push 2            ; FILE_END
		B @(0x6A, 0x00)                          # push 0            ; lpDistanceToMoveHigh
		B @(0x6A, 0x00)                          # push 0            ; lDistanceToMove
		B @(0x50)                                # push eax
		B @(0xFF, 0x93) ; Abs32 $IAT_SETFILEPOINTER

		B @(0x6A, 0x00)                          # push 0            ; lpOverlapped
		B @(0x8D, 0x8B) ; Va 'written'           # lea  ecx,[ebx+<written>]
		B @(0x51)                                # push ecx
		B @(0x6A, [byte]$TRACE_REC)              # push <record size>
		B @(0x8D, 0x93) ; Va 'rec'               # lea  edx,[ebx+<rec>]
		B @(0x52)                                # push edx
		B @(0xFF, 0x75, 0xEC)                    # push [ebp-14h]
		B @(0xFF, 0x93) ; Abs32 $IAT_WRITEFILE   # call [ebx+<WriteFile>]

		B @(0xFF, 0x75, 0xEC)                    # push [ebp-14h]
		B @(0xFF, 0x93) ; Abs32 $IAT_CLOSEHANDLE # call [ebx+<CloseHandle>]
		L 'no_trace'
	}

	B @(0x8B, 0x45, 0xF8)                        # mov  eax,[ebp-8]    ; the function returns it
	B @(0x5F, 0x5E, 0x5B)                        # pop  edi / esi / ebx
	B @(0x8B, 0xE5)                              # mov  esp,ebp
	B @(0x5D)                                    # pop  ebp
	B @(0xC2, 0x14, 0x00)                        # ret  14h

	# ---- trampoline : the prologue the hook displaced, then back into the body.
	while ($script:code.Count -lt $AT_TRAMP) { B @(0xCC) }
	L 'tramp'
	B @(0x55)                                    # push ebp
	B @(0x8B, 0xEC)                              # mov  ebp,esp
	B @(0x6A, 0xFF)                              # push -1
	B @(0xE9)                                    # jmp  <func+5>
	I32 ($funcVa + $LEN_HOOK - ($caveVa + $script:code.Count + 4))

	# ---- the cache.
	while ($script:code.Count -lt $AT_BUILT) { B @(0xCC) }
	L 'built'
	I32 0
	while ($script:code.Count -lt $AT_TABLE) { B @(0x00) }
	L 'table'
	for ($i = 0; $i -lt $SLOTS; $i++) { I32 0 }
	while ($script:code.Count -lt $AT_PINNED) { B @(0x00) }
	L 'pinned'
	for ($i = 0; $i -lt $SLOTS; $i++) { I32 0 }

	# ---- the trace's scratch : the record, the DWORD WriteFile fills in, and the path.
	while ($script:code.Count -lt $AT_REC) { B @(0x00) }
	L 'rec'
	for ($i = 0; $i -lt ($TRACE_REC / 4); $i++) { I32 0 }
	L 'written'
	I32 0
	while ($script:code.Count -lt $AT_PATH) { B @(0x00) }
	L 'path'
	# Assigned rather than taken from an if : an empty [byte[]] out of one collapses to $null.
	$rawPath = [byte[]]@()
	if ($Trace) { $rawPath = [System.Text.Encoding]::Unicode.GetBytes($TraceTo) }
	if ($rawPath.Length + 2 -gt $PATH_SLOT) { throw "the trace path does not fit in $PATH_SLOT bytes." }
	if ($rawPath.Length) { B $rawPath }
	for ($i = $rawPath.Length; $i -lt $PATH_SLOT; $i++) { B @(0x00) }

	# ---- the names : 56 steps shape major, then the eight the shapes are recognised by.
	while ($script:code.Count -lt $AT_NAMES) { B @(0x00) }
	L 'names'
	$names = @()
	foreach ($shape in $SHAPES)
	{
		foreach ($lvl in $Levels)
		{
			$names += $(if ($DiagnoseEffect) { $DiagnoseEffect } else { "$Package.enchant$lvl`_$shape" })
		}
	}
	foreach ($shape in $SHAPES) { $names += "$Package.enchant$($Levels[0])`_$shape" }

	foreach ($name in $names)
	{
		$raw = [System.Text.Encoding]::Unicode.GetBytes($name)
		if ($raw.Length + 2 -gt $SLOT) { throw "'$name' does not fit in $SLOT bytes." }
		B $raw
		for ($i = $raw.Length; $i -lt $SLOT; $i++) { B @(0x00) }
	}

	# ---- the live config : the block it is read into, what ReadFile reports, and its path.
	# Reserved whether or not -Live is on, so that both builds put everything at one offset.
	while ($script:code.Count -lt $AT_LIVE) { B @(0x00) }
	L 'live'
	for ($i = 0; $i -lt ($LIVE_LEN / 4); $i++) { I32 0 }
	while ($script:code.Count -lt $AT_LIVEREAD) { B @(0x00) }
	L 'liveread'
	I32 0
	while ($script:code.Count -lt $AT_LIVEPATH) { B @(0x00) }
	L 'livepath'
	$rawLive = [byte[]]@()
	if ($Live) { $rawLive = [System.Text.Encoding]::Unicode.GetBytes($LiveFrom) }
	if ($rawLive.Length + 2 -gt $PATH_SLOT) { throw "the live config path does not fit in $PATH_SLOT bytes." }
	if ($rawLive.Length) { B $rawLive }
	for ($i = $rawLive.Length; $i -lt $PATH_SLOT; $i++) { B @(0x00) }

	# ---- and what the cave reports back, with its own path.
	while ($script:code.Count -lt $AT_STATE) { B @(0x00) }
	L 'state'
	for ($i = 0; $i -lt ($STATE_LEN / 4); $i++) { I32 0 }
	while ($script:code.Count -lt $AT_STATEWROTE) { B @(0x00) }
	L 'statewrote'
	I32 0
	while ($script:code.Count -lt $AT_STATEPATH) { B @(0x00) }
	L 'statepath'
	$rawState = [byte[]]@()
	if ($Live) { $rawState = [System.Text.Encoding]::Unicode.GetBytes($StateTo) }
	if ($rawState.Length + 2 -gt $PATH_SLOT) { throw "the state path does not fit in $PATH_SLOT bytes." }
	if ($rawState.Length) { B $rawState }
	for ($i = $rawState.Length; $i -lt $PATH_SLOT; $i++) { B @(0x00) }
}

if ($cave.Length -gt $LEN_CAVE) { throw "the cave wants $($cave.Length) bytes, only $LEN_CAVE were checked as free." }
if ($script:labels['hook'] -ne $AT_HOOK) { throw 'the hook did not land at the top of the cave.' }
if ($script:labels['tramp'] -ne $AT_TRAMP -or $script:labels['built'] -ne $AT_BUILT -or
	$script:labels['table'] -ne $AT_TABLE -or $script:labels['pinned'] -ne $AT_PINNED -or
	$script:labels['rec'] -ne $AT_REC -or $script:labels['path'] -ne $AT_PATH -or
	$script:labels['names'] -ne $AT_NAMES -or $script:labels['live'] -ne $AT_LIVE -or
	$script:labels['liveread'] -ne $AT_LIVEREAD -or $script:labels['livepath'] -ne $AT_LIVEPATH -or
	$script:labels['state'] -ne $AT_STATE -or $script:labels['statewrote'] -ne $AT_STATEWROTE -or
	$script:labels['statepath'] -ne $AT_STATEPATH)
{
	throw 'the cave layout drifted ; the code outgrew one of its fixed offsets.'
}

# --------------------------------------------------------------------- write --
for ($i = 0; $i -lt $cave.Length; $i++) { $bytes[$OFF_CAVE + $i] = $cave[$i] }

$jump = New-Object 'System.Collections.Generic.List[byte]'
$jump.Add(0xE9)
$jump.AddRange([BitConverter]::GetBytes([int]($caveVa - ($funcVa + 5))))
if ($jump.Count -ne $LEN_HOOK) { throw 'the entry jump is not five bytes.' }
for ($i = 0; $i -lt $LEN_HOOK; $i++) { $bytes[$OFF_FUNC + $i] = $jump[$i] }

if ($NoEffectCache)
{
	$was = Get-Hex $bytes $OFF_CACHE_JE ($SIG_CACHE_JE.Length / 2)
	if ($was -ne $SIG_CACHE_JE)
	{
		throw ("the effect cache check at 0x{0:X} is {1}, expected {2} - wrong build, or already patched. Nothing changed." -f $OFF_CACHE_JE, $was, $SIG_CACHE_JE)
	}
	for ($i = 0; $i -lt ($SIG_CACHE_JE.Length / 2); $i++) { $bytes[$OFF_CACHE_JE + $i] = 0x90 }
}

if ($RebuildAlways)
{
	$was = Get-Hex $bytes $OFF_HELD_JNE ($SIG_HELD_JNE.Length / 2)
	if ($was -ne $SIG_HELD_JNE)
	{
		throw ("the held-effect gate at 0x{0:X} is {1}, expected {2} - wrong build, or already patched. Nothing changed." -f $OFF_HELD_JNE, $was, $SIG_HELD_JNE)
	}
	for ($i = 0; $i -lt ($SIG_HELD_JNE.Length / 2); $i++) { $bytes[$OFF_HELD_JNE + $i] = 0x90 }
}

if (-not $OutFile) { $OutFile = $In }
if ($OutFile -eq $In)
{
	$bak = "$In.enchantglow.bak"
	if (-not (Test-Path $bak)) { [System.IO.File]::WriteAllBytes($bak, [System.IO.File]::ReadAllBytes($In)) }
	Write-Host "stock file kept as $bak"
}
[System.IO.File]::WriteAllBytes($OutFile, $bytes)

Write-Host ("cave at 0x{0:X} ({1} bytes), entry jump at 0x{2:X}" -f $OFF_CAVE, $cave.Length, $OFF_FUNC)
Write-Host ("{0} effects : {1}.enchant{2}_{3} .. {4}.enchant{5}_{6}" -f $COUNT, $Package, $Levels[0], $SHAPES[0], $Package, $Levels[-1], $SHAPES[-1])
if ($DiagnoseEffect) { Write-Host "DIAGNOSTIC BUILD : every step returns '$DiagnoseEffect'." }
if ($Trace) { Write-Host "TRACING BUILD : a $TRACE_REC byte record per call goes to $TraceTo" }
if ($Live)
{
	Write-Host "DEV BUILD : $LIVE_LEN bytes are read from $LiveFrom on every call"
	Write-Host "            write it with set_enchant_glow_live.ps1 ; set EnchantEffectShow=0 to reach unenchanted weapons"
	Write-Host "DEV BUILD : a $STATE_LEN byte report goes to $StateTo, whenever that file asks for it (flag 64)"
}
if ($NoEffectCache) { Write-Host ("DEV BUILD : the effect cache check at 0x{0:X} is nopped" -f $OFF_CACHE_JE) }
if ($RebuildAlways) { Write-Host ("DEV BUILD : the held-effect gate at 0x{0:X} is nopped - effects may pile up, see -RebuildAlways" -f $OFF_HELD_JNE) }
Write-Host "wrote $OutFile"


