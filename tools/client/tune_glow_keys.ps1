<#
.SYNOPSIS
	Moves the enchant glow with the keyboard while the client is running, and keeps what you dial in.

.DESCRIPTION
	Three pieces work together :

	  this script      polls the keyboard and rewrites system\enchantglow.live
	  the cave         (patch_engine_enchant_glow.ps1 -Live) reads that file on every call, applies
	                   the numbers, rebuilds the effect each tick and reports back which weapon is
	                   in hand in system\enchantglow.state
	  the tuning table enchant_glow_tuning.tsv, where a weapon's numbers are kept for good, and
	                   from which tune_enchant_glow.ps1 writes them into weapongrp

	Keys are read with GetAsyncKeyState, which is global : the client keeps the focus, this window
	can sit behind it. Everything is held with ALT, which -Modifier can change.

	Bound to LETTERS, not to arrows : arrows and punctuation go through the game's input and the
	shell's, and here they did not come back. The arrows are still bound as a second key for the
	axes that have one, and cost nothing when they do not arrive.

	  ALT + Z / X              along the blade           ALT + shift : five times the step
	  ALT + C / V              sideways
	  ALT + B / N              down / up
	  ALT + G / H              smaller / bigger
	  ALT + J / K              slower / faster particles
	  ALT + 1 .. 7             jump to a rung : 4, 7, 10, 12, 14, 15, 17
	  ALT + S                  save these numbers for this weapon SHAPE
	  ALT + D                  save them against the id of the weapon in hand instead
	  ALT + R                  back to 0 0 0, scale 1, velocity 1
	  ALT + Q                  quit, leaving the client on the last numbers

	RUN THIS WINDOW AS ADMINISTRATOR if the client runs as one. Windows will not let a process see
	input going to a window of higher integrity (UIPI), so an unelevated script reads nothing while
	the game has the focus - and reads the modifier fine while the console has it, which is exactly
	how the symptom looks : "ALT is seen, the letters are not". Elevating this window fixes it.

	If nothing responds, -KeyTest prints every key this script can actually see. That is the one
	way to tell a modifier that never arrives from a script that died on startup.

	-Poke is set for you, so the forced rung works without a server. The other half is engine side :
	while the pawn already holds an effect the client rebuilds nothing, so the engine needs
	-NoEffectCache AND -RebuildAlways, or nothing moves until the weapon is taken off. See
	docs/enchant-glow.md.

	Saving writes a shape row - or "id:<weapon>" with ALT+D - into the tuning table. To put the
	table into weapongrp afterwards :

	    .\tune_enchant_glow.ps1 -SystemDir <...> -ToolsDir <...>

.PARAMETER SystemDir
	The "system" directory of the running client.

.EXAMPLE
	.\tune_glow_keys.ps1 -SystemDir "C:\l2client\system"
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)][string] $SystemDir,
	# The rung to show while tuning. The 1..7 keys switch it.
	[int] $Enchant = 17,
	[double] $OffsetStep = 0.5,
	[double] $ScaleStep = 0.05,
	[double] $VelocityStep = 0.05,
	# The key everything is held with. ALT is the default because it is the one that has been seen
	# working here. NONE binds the keys bare, which collides with the game and is only sane with the
	# client not focused.
	[ValidateSet('ALT', 'CTRL', 'SHIFT', 'NONE')][string] $Modifier = 'ALT',
	# How often the keyboard is polled, and how fast a held key repeats.
	[int] $PollMs = 60,
	# Set the files up, print them and exit - no polling. For checking the plumbing.
	[switch] $Once,
	# Every id in weapongrp with its glow shape, one per line - what ALT+D checks the reported id
	# against before it writes a row for it. Made by dump_weapongrp_ids.ps1.
	[string] $IdsFile,
	# Print which of the watched keys this script can see, for a few seconds, and change nothing.
	# The one honest way to tell "the modifier is not reaching us" from "the modifier is fine and
	# something else is wrong".
	[switch] $KeyTest,
	[int] $KeyTestSeconds = 15
)

$ErrorActionPreference = 'Stop'

$LIVE_LEN = 32
$LIVE_MAGIC = 0x574F4C47                  # 'GLOW'
$STATE_LEN = 16
$STATE_MAGIC = 0x54534C47                 # 'GLST'

$F_OFFSET = 1
$F_SCALE = 2
$F_VELOCITY = 4
$F_ENCHANT = 8
$F_POKE = 16
# 32 is dead : rebuilding every tick is engine-side, patch_engine_enchant_glow.ps1 -NoEffectCache.
$F_STATE = 64

$RUNGS = @(4, 7, 10, 12, 14, 15, 17)
$INV = [System.Globalization.CultureInfo]::InvariantCulture

if (-not (Test-Path $SystemDir)) { throw "No such directory: $SystemDir" }
$livePath = Join-Path $SystemDir 'enchantglow.live'
$statePath = Join-Path $SystemDir 'enchantglow.state'
$setScript = Join-Path $PSScriptRoot 'set_enchant_glow_live.ps1'
if (-not (Test-Path $setScript)) { throw "Missing $setScript" }

# GetAsyncKeyState, bound in memory.
#
# NOT through Add-Type : that one compiles a C# snippet to a DLL under %TEMP% and loads it back,
# and on this machine the file is gone by the time it is loaded -
#
#     Add-Type : Could not find file 'C:\Users\...\Temp\z4nexvib.dll'
#
# which is antivirus eating it, and it kills the whole script on the first line that matters.
# DefinePInvokeMethod builds the same binding in a dynamic assembly, so nothing is written to
# disk and nothing can take it away. Add-Type is kept as a fallback for anywhere this is refused.
function New-KeyReader
{
	try
	{
		$asmName = New-Object System.Reflection.AssemblyName 'L2GlowKeys'
		$asm = [AppDomain]::CurrentDomain.DefineDynamicAssembly($asmName, [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
		$mod = $asm.DefineDynamicModule('Kb', $false)
		$type = $mod.DefineType('L2Glow.Kb', 'Public, Class')
		$m = $type.DefinePInvokeMethod('GetAsyncKeyState', 'user32.dll',
			'Public, Static, PinvokeImpl',
			[System.Reflection.CallingConventions]::Standard,
			[int16], @([int]),
			[System.Runtime.InteropServices.CallingConvention]::Winapi,
			[System.Runtime.InteropServices.CharSet]::Auto)
		$m.SetImplementationFlags([System.Reflection.MethodImplAttributes]::PreserveSig)
		return $type.CreateType()
	}
	catch
	{
		Write-Warning "binding GetAsyncKeyState in memory failed ($($_.Exception.Message)) ; falling back to Add-Type."
		Add-Type -Namespace L2Glow -Name KbCompiled -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern short GetAsyncKeyState(int vKey);
'@
		return [L2Glow.KbCompiled]
	}
}

$KB = New-KeyReader

# The one failure that looks exactly like a wrong key binding. A process cannot see input sent to a
# window running at higher integrity, so an unelevated script reads nothing while the elevated
# client has the focus - and reads the modifier perfectly well while the console has it.
$IS_ADMIN = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
	[Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IS_ADMIN)
{
	Write-Warning 'this window is NOT elevated : if the client runs as administrator, Windows hides its keys from us (UIPI) and nothing here will respond. Run this window as administrator.'
}

# Virtual key codes, only the ones this uses.
# Letters first : arrows and the punctuation keys go through the game's own input and through
# whatever the shell does with them, and on this machine they did not come back. Plain letters do.
# The arrows are kept as a second binding for the two axes that have one - they cost nothing when
# they do not arrive.
$VK = @{
	ALT = 0x12; SHIFT = 0x10; CTRL = 0x11
	LEFT = 0x25; UP = 0x26; RIGHT = 0x27; DOWN = 0x28
	PGUP = 0x21; PGDN = 0x22
	PLUS = 0xBB; MINUS = 0xBD; LBRACKET = 0xDB; RBRACKET = 0xDD
	Z = 0x5A; X = 0x58; C = 0x43; V = 0x56; B = 0x42; N = 0x4E
	G = 0x47; H = 0x48; J = 0x4A; K = 0x4B
	S = 0x53; D = 0x44; R = 0x52; Q = 0x51
}

function Down([int] $vk) { return ($script:KB::GetAsyncKeyState($vk) -band 0x8000) -ne 0 }

# The step multiplier shares SHIFT, so SHIFT cannot also be the modifier without the two meaning
# the same thing ; with SHIFT held down as the modifier every move would be a big one.
$MOD_VK = $(if ($Modifier -eq 'NONE') { 0 } else { $VK[$Modifier] })
$BIG_VK = $(if ($Modifier -eq 'SHIFT') { $VK.CTRL } else { $VK.SHIFT })
$BIG_NAME = $(if ($Modifier -eq 'SHIFT') { 'CTRL' } else { 'SHIFT' })
function ModDown { if ($MOD_VK -eq 0) { return $true } ; return (Down $MOD_VK) }

if ($KeyTest)
{
	Write-Host "modifier $Modifier = vk $MOD_VK, big step $BIG_NAME = vk $BIG_VK"
	Write-Host "elevated : $IS_ADMIN"
	Write-Host "hold keys for $KeyTestSeconds seconds - anything this script can see is printed"
	Write-Host "press them WITH THE CLIENT FOCUSED : keys seen only over this console and not over"
	Write-Host "the game mean the game is elevated and this window is not."
	$until = (Get-Date).AddSeconds($KeyTestSeconds)
	$last = ''
	while ((Get-Date) -lt $until)
	{
		Start-Sleep -Milliseconds 80
		$on = @()
		foreach ($name in ($VK.Keys | Sort-Object)) { if (Down $VK[$name]) { $on += $name } }
		$line = $(if ($on.Count) { $on -join ' + ' } else { '' })
		if ($line -ne $last) { $last = $line ; if ($line) { Write-Host "  $line" } }
	}
	Write-Host 'done'
	return
}

# ---------------------------------------------------------------------------
# The two files.
# ---------------------------------------------------------------------------

$state = @{ ox = 0.0; oy = 0.0; oz = 0.0; scale = 1.0; velocity = 1.0; enchant = $Enchant }

# What is already there is where we pick up, so a session continues the last one.
if (Test-Path $livePath)
{
	$raw = [System.IO.File]::ReadAllBytes($livePath)
	if ($raw.Length -eq $LIVE_LEN -and [BitConverter]::ToInt32($raw, 0) -eq $LIVE_MAGIC)
	{
		$f = [BitConverter]::ToInt32($raw, 4)
		if ($f -band $F_ENCHANT) { $state.enchant = [BitConverter]::ToInt32($raw, 8) }
		if ($f -band $F_OFFSET)
		{
			$state.ox = [double][BitConverter]::ToSingle($raw, 12)
			$state.oy = [double][BitConverter]::ToSingle($raw, 16)
			$state.oz = [double][BitConverter]::ToSingle($raw, 20)
		}
		if ($f -band $F_SCALE) { $state.scale = [double][BitConverter]::ToSingle($raw, 24) }
		if ($f -band $F_VELOCITY) { $state.velocity = [double][BitConverter]::ToSingle($raw, 28) }
	}
}

function Write-Live($s)
{
	$b = New-Object 'byte[]' $LIVE_LEN
	$flags = $F_OFFSET -bor $F_SCALE -bor $F_VELOCITY -bor $F_ENCHANT -bor $F_POKE -bor $F_STATE
	[Array]::Copy([BitConverter]::GetBytes([int]$LIVE_MAGIC), 0, $b, 0, 4)
	[Array]::Copy([BitConverter]::GetBytes([int]$flags), 0, $b, 4, 4)
	[Array]::Copy([BitConverter]::GetBytes([int]$s.enchant), 0, $b, 8, 4)
	[Array]::Copy([BitConverter]::GetBytes([single]$s.ox), 0, $b, 12, 4)
	[Array]::Copy([BitConverter]::GetBytes([single]$s.oy), 0, $b, 16, 4)
	[Array]::Copy([BitConverter]::GetBytes([single]$s.oz), 0, $b, 20, 4)
	[Array]::Copy([BitConverter]::GetBytes([single]$s.scale), 0, $b, 24, 4)
	[Array]::Copy([BitConverter]::GetBytes([single]$s.velocity), 0, $b, 28, 4)
	# Written whole in one call ; a client that catches it torn sees a short read and skips it.
	[System.IO.File]::WriteAllBytes($livePath, $b)
}

# What the cave last reported. Absent until the client has run one call with the state flag on,
# which is why -Once prints "no report yet" on a cold client.
#
#   +0  'GLST'   +4  the weapon's item id   +8  the level it was graded by   +12  the outcome
#
# The shape is worked out from the outcome the same way read_enchant_glow_trace.ps1 does it :
# low byte 3 means a rung was handed back, and the step is in the bits above it.
#
# The id at +4 is [pawn+0x6A0], and it IS the item id : the client hands its item-data manager the
# ADDRESS of that field, and the manager is a TMap keyed by exactly that number - the disassembly
# is in patch_engine_enchant_glow.ps1 next to $FLD_WEAPONID. It used to be read as "not the id"
# because 1, 2, 6 and 75 are real ids of retail weapons and look too small to be ones, and because
# something in hand that is not in weapongrp at all (5646 was one) reports its own id here while
# the lookup comes back empty. weapongrp_ids.txt settles both cases without guessing.
$SHAPES = @('001t', '002t', '004t', '005t', '006t', '007t', '008t', '010t')

if (-not $IdsFile) { $IdsFile = Join-Path $PSScriptRoot 'weapongrp_ids.txt' }
# id -> glow shape, so that a reported id can be checked against the table it will be saved into.
$KNOWN_IDS = $null
if (Test-Path $IdsFile)
{
	$KNOWN_IDS = @{}
	foreach ($line in [System.IO.File]::ReadAllLines($IdsFile))
	{
		$s = $line.Trim()
		if ($s -eq '' -or $s.StartsWith('#')) { continue }
		$f = $s -split "`t"
		$n = 0
		if (-not [int]::TryParse($f[0], [ref]$n)) { continue }
		$KNOWN_IDS[$n] = $(if ($f.Count -gt 1) { $f[1] } else { '' })
	}
	Write-Host "  $($KNOWN_IDS.Count) weapongrp ids loaded from $IdsFile"
}

function Read-Report
{
	if (-not (Test-Path $statePath)) { return $null }
	try { $raw = [System.IO.File]::ReadAllBytes($statePath) } catch { return $null }
	# 16 bytes is the whole report ; a longer one is an older build that also carried the head of
	# the weapongrp row, and those extra fields are read by nothing now.
	if ($raw.Length -lt $STATE_LEN -or [BitConverter]::ToInt32($raw, 0) -ne $STATE_MAGIC) { return $null }

	$outcome = [BitConverter]::ToInt32($raw, 12)
	$shape = $null
	if (($outcome -band 0xFF) -eq 3)
	{
		$step = $outcome -shr 8
		$i = [int][Math]::Floor($step / $RUNGS.Count)
		if ($i -ge 0 -and $i -lt $SHAPES.Count) { $shape = $SHAPES[$i] }
	}
	return @{
		weapon  = [BitConverter]::ToInt32($raw, 4)
		graded  = [BitConverter]::ToInt32($raw, 8)
		outcome = $outcome -band 0xFF
		shape   = $shape
	}
}

function Show-State($s, $r)
{
	# An outcome other than "rung handed back" leaves the shape unknown - say so rather than
	# printing an empty slot that reads like a bug.
	$w = if ($null -eq $r) { 'no report yet' } else { "$(if ($r.shape) { $r.shape } else { "shape ? (outcome $($r.outcome))" }), id $($r.weapon)" }
	'+{0}  off ({1}, {2}, {3})  scale {4}  vel {5}   [{6}]' -f $s.enchant,
		$s.ox.ToString('0.##', $INV), $s.oy.ToString('0.##', $INV), $s.oz.ToString('0.##', $INV),
		$s.scale.ToString('0.##', $INV), $s.velocity.ToString('0.##', $INV), $w
}

# ---------------------------------------------------------------------------
# What the two save keys do. Both take the report as it is right now and either write the row or,
# with -Once, only say which row they would write - so "why does ALT+D do nothing" can be answered
# without the keyboard, and the answer is the same code that runs on the key.
# ---------------------------------------------------------------------------

function Save-ByShape($r, [bool] $really)
{
	if ($null -eq $r)
	{
		Write-Warning 'nothing reported yet - equip a glowing weapon in the client first'
		return
	}
	if ($null -eq $r.shape)
	{
		# The shape is read out of the outcome, and only an outcome of 3 carries one : anything
		# else means no rung was handed out, so there is no shape to file this under.
		Write-Warning "no rung was handed out on the last call (outcome $($r.outcome)) - the weapon in hand is not glowing off this ladder, so there is no shape to save under ; ALT+D saves by its id"
		return
	}
	if (-not $really) { Write-Host "  ALT+S would save the shape row $($r.shape)" ; return }
	& $setScript -SystemDir $SystemDir -SaveAs $r.shape
}

# The id is [pawn+0x6A0] as reported : the number the client itself looks weapongrp up by. The
# checks here only guard against writing a row for the wrong weapon - they are not a hunt for
# which field the id is in.
function Save-ById($r, [bool] $really)
{
	if ($null -eq $r)
	{
		Write-Warning 'nothing reported yet - equip a glowing weapon in the client first'
		return
	}
	$id = [int]$r.weapon
	if ($id -le 0)
	{
		Write-Warning 'the client reports no weapon in hand - equip one and try again'
		return
	}
	if ($KNOWN_IDS -and -not $KNOWN_IDS.ContainsKey($id))
	{
		# Not a weapon of the table : the client's own lookup came back empty too, so there is no
		# weapongrp row to save this against.
		Write-Warning "id $id is not in weapongrp ($IdsFile) - either what is in hand is no weapon of the table, or the list is older than the dat ; re-run dump_weapongrp_ids.ps1, or save by shape with ALT+S"
		return
	}
	# The shape the cave graded and the shape the table has for this id should agree. When they do
	# not, the list is stale or the report is a frame behind a weapon change - say so, and save
	# anyway, because the id is the id.
	if ($KNOWN_IDS -and $r.shape -and $KNOWN_IDS[$id] -and $KNOWN_IDS[$id] -ne $r.shape)
	{
		Write-Warning "the cave graded $($r.shape) but weapongrp has $($KNOWN_IDS[$id]) for id $id - saving anyway ; re-run dump_weapongrp_ids.ps1 if the dat has moved on"
	}
	elseif (-not $r.shape)
	{
		Write-Warning "no rung was handed out on the last call (outcome $($r.outcome)) - saving for id $id anyway, but check that the weapon is really glowing"
	}
	if (-not $really) { Write-Host "  ALT+D would save the row id:$id" ; return }
	& $setScript -SystemDir $SystemDir -SaveAs "id:$id"
}

Write-Live $state

if ($Once)
{
	Write-Host "live  : $livePath"
	Write-Host "state : $statePath"
	$r = Read-Report
	Write-Host (Show-State $state $r)
	if ($null -eq $r)
	{
		Write-Warning "no report from the cave. Either the client has not run since engine.dll was patched, or it was patched without -Live, or it has not asked for an enchant effect yet (EnchantEffectShow=0 in env.int, and a weapon in hand)."
	}
	else
	{
		Save-ByShape $r $false
		Save-ById $r $false
	}
	return
}

$M = $Modifier
Write-Host ''
Write-Host "  modifier $M (vk $MOD_VK) - if nothing responds, run with -KeyTest"
Write-Host "  $M + Z X                    along the blade      $M + $BIG_NAME : x5"
Write-Host "  $M + C V                    sideways"
Write-Host "  $M + B N                    down / up"
Write-Host "  $M + G H                    smaller / bigger"
Write-Host "  $M + J K                    slower / faster particles"
Write-Host "  $M + 1..7                   rung 4 7 10 12 14 15 17"
Write-Host "  (arrows, pgup/pgdn, = - ] [ also work where they arrive)"
Write-Host "  $M + S                      save for this weapon SHAPE   $M + D : by weapon id"
Write-Host "  $M + R                      reset      $M + Q : quit"
Write-Host ''
$lastReport = Read-Report
Write-Host (Show-State $state $lastReport)
if ($null -eq $lastReport)
{
	# Both save keys need this file, so say straight away that it is not there rather than let the
	# first ALT+S look like a key that does not arrive.
	Write-Warning "no report from the cave yet ($statePath). Both save keys need it : the client has to be running, its engine.dll patched with -Live, and it has to have asked for an enchant effect at least once (EnchantEffectShow=0 in env.int, a weapon in hand)."
}

# Discrete actions fire once per press ; movement repeats while held.
$wasDown = @{}
function Pressed([int] $vk, [string] $name)
{
	$now = Down $vk
	$before = $script:wasDown[$name]
	$script:wasDown[$name] = $now
	return ($now -and -not $before)
}

while ($true)
{
	Start-Sleep -Milliseconds $PollMs

	if (-not (ModDown))
	{
		# Nothing is held with the modifier up, so no press carries into the next round.
		$wasDown.Clear()
		$w = Read-Report
		if ($null -ne $w -and ($null -eq $lastReport -or $w.shape -ne $lastReport.shape -or $w.weapon -ne $lastReport.weapon))
		{
			$lastReport = $w
			Write-Host (Show-State $state $w)
		}
		continue
	}

	if (Pressed $VK.Q 'q') { Write-Host 'done - the client keeps the last numbers' ; break }

	$mult = $(if (Down $BIG_VK) { 5 } else { 1 })
	$moved = $false

	if ((Down $VK.Z) -or (Down $VK.LEFT)) { $state.ox -= $OffsetStep * $mult ; $moved = $true }
	if ((Down $VK.X) -or (Down $VK.RIGHT)) { $state.ox += $OffsetStep * $mult ; $moved = $true }
	if ((Down $VK.C) -or (Down $VK.PGDN)) { $state.oy -= $OffsetStep * $mult ; $moved = $true }
	if ((Down $VK.V) -or (Down $VK.PGUP)) { $state.oy += $OffsetStep * $mult ; $moved = $true }
	if ((Down $VK.B) -or (Down $VK.DOWN)) { $state.oz -= $OffsetStep * $mult ; $moved = $true }
	if ((Down $VK.N) -or (Down $VK.UP)) { $state.oz += $OffsetStep * $mult ; $moved = $true }
	if ((Down $VK.G) -or (Down $VK.MINUS)) { $state.scale -= $ScaleStep * $mult ; $moved = $true }
	if ((Down $VK.H) -or (Down $VK.PLUS)) { $state.scale += $ScaleStep * $mult ; $moved = $true }
	if ((Down $VK.J) -or (Down $VK.LBRACKET)) { $state.velocity -= $VelocityStep * $mult ; $moved = $true }
	if ((Down $VK.K) -or (Down $VK.RBRACKET)) { $state.velocity += $VelocityStep * $mult ; $moved = $true }

	# A negative scale turns the effect inside out and a negative speed runs it backwards ; neither
	# is worth reaching for by holding a key a moment too long.
	if ($state.scale -lt 0) { $state.scale = 0.0 }
	if ($state.velocity -lt 0) { $state.velocity = 0.0 }

	for ($i = 0; $i -lt $RUNGS.Count; $i++)
	{
		if (Pressed (0x31 + $i) "rung$i") { $state.enchant = $RUNGS[$i] ; $moved = $true }
	}

	if (Pressed $VK.R 'r')
	{
		$state.ox = 0.0 ; $state.oy = 0.0 ; $state.oz = 0.0 ; $state.scale = 1.0 ; $state.velocity = 1.0
		$moved = $true
	}

	if ($moved)
	{
		$state.ox = [Math]::Round($state.ox, 3)
		$state.oy = [Math]::Round($state.oy, 3)
		$state.oz = [Math]::Round($state.oz, 3)
		$state.scale = [Math]::Round($state.scale, 3)
		$state.velocity = [Math]::Round($state.velocity, 3)
		Write-Live $state
		$lastReport = Read-Report
		Write-Host (Show-State $state $lastReport)
	}

	if (Pressed $VK.S 's') { Save-ByShape (Read-Report) $true }
	if (Pressed $VK.D 'd') { Save-ById (Read-Report) $true }
}
