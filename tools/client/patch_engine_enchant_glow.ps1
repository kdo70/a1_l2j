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
# _010t rapier). tools\weapons\patch_client.ps1 writes the +4 name of its shape
# into every weapon of weapongrp ; this patch wraps GetEnchantedWeaponEffect so
# that the name it returns is walked up that ladder from the enchant level the
# pawn carries.
#
#   the weapon's effect is not one of the eight  -> returned untouched
#   enchanted below +4                           -> NAME_None, no glow at all
#   +4..+6 / +7..+9 / +10..+11 / +12..+13
#     / +14 / +15..+16 / +17 and up              -> that step's effect
#
# So a stock weapongrp goes through this patch unchanged, and a patched
# weapongrp works without it - it just shows the +4 effect from +4 up.
#
# How. The five bytes of the function's prologue are replaced with a jump into
# the 0xCC padding that follows engine.dll's incremental-link thunk table. The
# cave re-pushes the five arguments, calls the original through a trampoline
# that carries the displaced prologue, and rewrites the FName the original
# stored before handing the same pointer back. The 56 names are built once, on
# the first call, through core.dll's FName(const TCHAR*, EFindName) - the
# import engine.dll already has - and cached in the cave.
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
	# Below the first of these the weapon does not glow at all.
	[int[]] $Levels = @(4, 7, 10, 12, 14, 15, 17)
)

$ErrorActionPreference = 'Stop'

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
$LEN_CAVE = 0x1100

# core.dll's FName::FName(const TCHAR*, EFindName), through engine.dll's import table.
$IAT_FNAME = 0x11D8D988
$FNAME_ADD = 1

# APawn::AttackItemEnchantedValue - what the caller compares against
# EnchantEffectShow before it asks for an effect at all.
$FLD_ENCHANT = 0x1830

# Layout inside the cave. Fixed rather than packed, so that the disassembly of a
# patched file is readable and a rerun lands on the same bytes.
$AT_HOOK = 0x0000
$AT_TRAMP = 0x0180
$AT_BUILT = 0x0190
$AT_TABLE = 0x01A0                        # 56 FName indices
$AT_NAMES = 0x0300                        # 56 slots of $SLOT bytes, UTF-16, NUL terminated
$SLOT = 64

$COUNT = $SHAPES.Count * $Levels.Count
if ($COUNT -ne 56) { throw "expected 8 shapes x 7 levels, got $COUNT." }

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
function Va([string] $n)
{
	$script:fixups += , @{ pos = $script:code.Count; label = $n; kind = 'va' }
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
					$b = [BitConverter]::GetBytes([int]($caveVa + $target))
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
	L 'hook'
	B @(0x55)                                    # push ebp
	B @(0x8B, 0xEC)                              # mov  ebp,esp
	B @(0x83, 0xEC, 0x08)                        # sub  esp,8          ; [ebp-4] spare, [ebp-8] result
	B @(0x53, 0x56, 0x57)                        # push ebx / esi / edi
	B @(0x8B, 0xF1)                              # mov  esi,ecx        ; the pawn

	# Where are we ? ebx ends up holding the difference between the image's real
	# base and the one every address below was written for.
	B @(0xE8, 0x00, 0x00, 0x00, 0x00)            # call $+5
	L 'here'
	B @(0x5B)                                    # pop  ebx
	B @(0x81, 0xEB) ; Va 'here'                  # sub  ebx,<here>

	# The original, with its own arguments and its own this.
	B @(0xFF, 0x75, 0x18)                        # push [ebp+18h]
	B @(0xFF, 0x75, 0x14)                        # push [ebp+14h]
	B @(0xFF, 0x75, 0x10)                        # push [ebp+10h]
	B @(0xFF, 0x75, 0x0C)                        # push [ebp+0Ch]
	B @(0xFF, 0x75, 0x08)                        # push [ebp+8]
	B @(0x8B, 0xCE)                              # mov  ecx,esi
	B @(0x8D, 0x83) ; Va 'tramp'                 # lea  eax,[ebx+<tramp>]
	B @(0xFF, 0xD0)                              # call eax            ; cleans its own 14h
	B @(0x89, 0x45, 0xF8)                        # mov  [ebp-8],eax    ; the FName it filled
	B @(0x8B, 0x00)                              # mov  eax,[eax]
	B @(0x85, 0xC0)                              # test eax,eax
	B @(0x0F, 0x84) ; Rel32 'done'               # jz   done           ; NAME_None : nothing to grade

	# ---- the 56 names, built once and kept.
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
	B @(0x83, 0xFF, [byte]$COUNT)                # cmp  edi,56
	B @(0x72) ; Rel8 'build'                     # jb   build
	L 'have'

	# ---- which of the eight shapes is this ? The name in weapongrp is the first
	# rung of its own ladder, so it matches one of the eight table entries.
	B @(0x8B, 0x45, 0xF8)                        # mov  eax,[ebp-8]
	B @(0x8B, 0x00)                              # mov  eax,[eax]
	B @(0x33, 0xFF)                              # xor  edi,edi
	L 'find'
	B @(0x8B, 0xCF)                              # mov  ecx,edi
	B @(0x6B, 0xC9, [byte]($Levels.Count * 4))   # imul ecx,ecx,28
	B @(0x03, 0xCB)                              # add  ecx,ebx
	B @(0x3B, 0x81) ; Va 'table'                 # cmp  eax,[ecx+<table>]
	B @(0x74) ; Rel8 'found'                     # je   found
	B @(0x47)                                    # inc  edi
	B @(0x83, 0xFF, [byte]$SHAPES.Count)         # cmp  edi,8
	B @(0x72) ; Rel8 'find'                      # jb   find
	B @(0xEB) ; Rel8 'done'                      # jmp  done           ; somebody else's effect
	L 'found'

	# ---- which rung ? Under the first level there is no glow at all.
	B @(0x8B, 0x86) ; Abs32 $FLD_ENCHANT         # mov  eax,[esi+1830h]
	B @(0x83, 0xF8, [byte]$Levels[0])            # cmp  eax,<first level>
	B @(0x7D) ; Rel8 'grade'                     # jge  grade
	B @(0x8B, 0x4D, 0xF8)                        # mov  ecx,[ebp-8]
	B @(0xC7, 0x01) ; I32 0                      # mov  dword [ecx],0  ; NAME_None
	B @(0xEB) ; Rel8 'done'                      # jmp  done
	L 'grade'
	B @(0x33, 0xC9)                              # xor  ecx,ecx
	for ($i = 1; $i -lt $Levels.Count; $i++)
	{
		B @(0x83, 0xF8, [byte]$Levels[$i])       # cmp  eax,<level>
		B @(0x7C) ; Rel8 'pick'                  # jl   pick
		B @(0x41)                                # inc  ecx
	}
	L 'pick'
	B @(0x6B, 0xFF, [byte]$Levels.Count)         # imul edi,edi,7
	B @(0x03, 0xF9)                              # add  edi,ecx
	B @(0x8D, 0x14, 0xBB)                        # lea  edx,[ebx+edi*4]
	B @(0x8B, 0x82) ; Va 'table'                 # mov  eax,[edx+<table>]
	B @(0x8B, 0x4D, 0xF8)                        # mov  ecx,[ebp-8]
	B @(0x89, 0x01)                              # mov  [ecx],eax
	L 'done'
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
	for ($i = 0; $i -lt $COUNT; $i++) { I32 0 }

	# ---- the names, shape major, so that entry <shape>*7 is the one weapongrp holds.
	while ($script:code.Count -lt $AT_NAMES) { B @(0x00) }
	L 'names'
	foreach ($shape in $SHAPES)
	{
		foreach ($lvl in $Levels)
		{
			$name = "$Package.enchant$lvl`_$shape"
			$raw = [System.Text.Encoding]::Unicode.GetBytes($name)
			if ($raw.Length + 2 -gt $SLOT) { throw "'$name' does not fit in $SLOT bytes." }
			B $raw
			for ($i = $raw.Length; $i -lt $SLOT; $i++) { B @(0x00) }
		}
	}
}

if ($cave.Length -gt $LEN_CAVE) { throw "the cave wants $($cave.Length) bytes, only $LEN_CAVE were checked as free." }
if ($script:labels['hook'] -ne $AT_HOOK) { throw 'the hook did not land at the top of the cave.' }
if ($script:labels['tramp'] -ne $AT_TRAMP -or $script:labels['built'] -ne $AT_BUILT -or
	$script:labels['table'] -ne $AT_TABLE -or $script:labels['names'] -ne $AT_NAMES)
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
Write-Host "wrote $OutFile"
