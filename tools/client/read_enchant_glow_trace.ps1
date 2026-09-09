<#
.SYNOPSIS
	Reads the file a -Trace build of patch_engine_enchant_glow.ps1 leaves behind.

.DESCRIPTION
	The tracing cave appends 48 bytes every time APawn::GetEnchantedWeaponEffect is called :

	  +0  the pawn's enchant level, [pawn+0x1830] - what the caller compares against
	      EnchantEffectShow before it asks for an effect at all
	  +4  the FName index weapongrp handed in, before we touched it. Opaque on its own, but
	      equal indices mean equal names, and 0 means NAME_None
	  +8  what the cave decided :
	        0  the original returned NAME_None - weapongrp has no effect on this weapon
	        1  the name is not one of the eight EnchantGlow shapes - somebody else's effect,
	           handed back untouched
	        2  enchanted below the first rung - NAME_None, no glow on purpose
	        3  a rung was handed back ; the step (0..55) is in the bits above the low byte
	        4  not one rung of the shape would load - NAME_None
	  +12 the UClass StaticLoadClass came back with for that rung, 0 if none
	  +16 GetTickCount at the call - what separates the character screen from the world
	  +20 the pawn
	  +24 the control : the same StaticLoadClass, on the shape's own +4, the rung the walk down
	      ends at. A sane pointer here next to nonsense at +12 means the refusal belongs to that
	      rung ; the same nonsense in both means the call itself is wrong
	  +28 Cast<?>(pawn), the first gate in the routine that spawns the effect actor (0x104B8950)
	  +32 that cast's [+0x134], the second gate
	  +36 the FName the pawn's vtable[+0x21C] hands back - the socket the effect hangs off, and
	      the third gate
	  +40 the level the rung was actually graded by : the pawn's own, or the one a -Live config
	      forced. -1 means grading was never reached
	  +44 the magic of the live block, 'GLOW' when that file was read whole and 0 when it was
	      missing, short or not ours - which is what says whether -Live is doing anything
	  +48 the caller's effect cache, [pawn+0x182C] - the weapon it last built an effect for
	  +52 the weapon in hand, [pawn+0x6A0]. The caller builds once per weapon and then skips this
	      function, so +48 catching up with +52 is what says a build finished. A cache that stays
	      behind call after call means the effect is never actually built

	The last three are evaluated here, from the same pawn, exactly as the spawn routine will do
	it a moment later. Each of them leaves without spawning anything and says nothing, so a NULL
	or a None in any of them is the whole answer to "the name was right and nothing appeared".

	Nothing else in this client reports anything, so this is what tells "the cave never ran"
	from "it ran and the name it handed back would not resolve". See docs/enchant-glow.md.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\client\read_enchant_glow_trace.ps1 `
	    -Path "C:\l2client\system\enchantglow.trace"
#>
param(
	[Parameter(Mandatory = $true)][string]$Path,
	# Must match the build that wrote the file.
	[int[]]$Levels = @(4, 7, 10, 12, 14, 15, 17)
)

$ErrorActionPreference = 'Stop'

$SHAPES = @('001t fist', '002t dagger/pole', '004t sword', '005t staff/2h blunt',
	'006t dual', '007t blunt/mystic', '008t bow', '010t rapier')

$OUTCOMES = @{
	0 = 'weapongrp had no effect (NAME_None came in)'
	1 = 'not an EnchantGlow name, left alone'
	2 = 'below the first rung, NAME_None'
	3 = 'rung handed back'
	4 = 'no rung of the shape would load, NAME_None'
}

if (-not (Test-Path $Path)) { throw "No such file: $Path - the client never wrote one, so the cave never ran." }
$bytes = [System.IO.File]::ReadAllBytes($Path)
if ($bytes.Length -eq 0) { throw "$Path is empty - the cave never ran." }
$REC = 56
if ($bytes.Length % $REC) { Write-Warning "$($bytes.Length) bytes is not a whole number of $REC byte records ; the tail is ignored." }

$rows = @()
$first = $null
for ($at = 0; $at + $REC -le $bytes.Length; $at += $REC)
{
	$enchant = [BitConverter]::ToInt32($bytes, $at)
	$came = [BitConverter]::ToUInt32($bytes, $at + 4)
	$outcome = [BitConverter]::ToInt32($bytes, $at + 8)
	$class = [BitConverter]::ToUInt32($bytes, $at + 12)
	$tick = [BitConverter]::ToUInt32($bytes, $at + 16)
	$pawn = [BitConverter]::ToUInt32($bytes, $at + 20)
	$floor = [BitConverter]::ToUInt32($bytes, $at + 24)
	$cast = [BitConverter]::ToUInt32($bytes, $at + 28)
	$gate = [BitConverter]::ToUInt32($bytes, $at + 32)
	$socket = [BitConverter]::ToUInt32($bytes, $at + 36)
	$graded = [BitConverter]::ToInt32($bytes, $at + 40)
	$live = [BitConverter]::ToUInt32($bytes, $at + 44)
	$cached = [BitConverter]::ToUInt32($bytes, $at + 48)
	$inHand = [BitConverter]::ToUInt32($bytes, $at + 52)
	if ($null -eq $first) { $first = $tick }

	$code = $outcome -band 0xFF
	$step = $outcome -shr 8
	$what = if ($OUTCOMES.ContainsKey($code)) { $OUTCOMES[$code] } else { "unknown outcome $code" }
	$rung = ''
	if ($code -eq 3)
	{
		$shape = [int][math]::Floor($step / $Levels.Count)
		$lvl = $Levels[$step % $Levels.Count]
		$rung = "+$lvl $($SHAPES[$shape])"
	}

	$rows += [pscustomobject]@{
		at      = '{0:N1}s' -f (($tick - $first) / 1000)
		enchant = $enchant
		cameIn  = '0x{0:X}' -f $came
		rung    = $rung
		class   = if ($class) { '0x{0:X}' -f $class } else { '0 (nothing)' }
		floor4  = if ($floor) { '0x{0:X}' -f $floor } else { '0 (nothing)' }
		pawn    = '0x{0:X}' -f $pawn
		cast    = if ($cast) { '0x{0:X} ok' -f $cast } else { 'NULL  <-- kills the effect' }
		gate    = if ($gate) { '0x{0:X} ok' -f $gate } else { 'NULL  <-- kills the effect' }
		socket  = if ($socket) { '0x{0:X} ok' -f $socket } else { 'None  <-- kills the effect' }
		graded  = if ($graded -lt 0) { 'never reached' } else { "$graded" }
		live    = if ($live -eq 0x574F4C47) { "read" } elseif ($live -eq 0) { 'not read (no file, or a plain build)' } else { '0x{0:X} - not ours' -f $live }
		cache   = if ($cached -eq $inHand -and $inHand -ne 0) { "$cached, caught up" } else { "$cached vs $inHand in hand  <-- build never finished" }
		outcome = $what
	}
}

Write-Host "$($rows.Count) call(s) in $Path"
Write-Host ''

# Every call, in order. "at" is seconds since the first one, which is what says whether a call
# happened on the character screen or after the world had loaded.
#
# Written a line at a time rather than through Format-Table : a console narrower than the table
# silently drops the columns on the right, and those are the ones worth reading.
foreach ($r in $rows)
{
	Write-Host ("{0,7}  enchant {1,-3} in {2,-8} {3}" -f $r.at, $r.enchant, $r.cameIn, $r.rung)
	Write-Host ("         graded by {0}, live config {1}" -f $r.graded, $r.live)
	Write-Host ("         effect cache {0}" -f $r.cache)
	Write-Host ("         field written {0}" -f $r.class)
	Write-Host ("         field address {0}" -f $r.floor4)
	Write-Host ("         pawn {0} : {1}" -f $r.pawn, $r.outcome)
	Write-Host ("         spawn gates : cast {0}" -f $r.cast)
	Write-Host ("                       [+134h] {0}" -f $r.gate)
	Write-Host ("                       socket {0}" -f $r.socket)
	Write-Host ''
}

$span = 0
if ($rows.Count -gt 1) { $span = [double]($rows[-1].at -replace 's$', '' -replace ',', '.') }
Write-Host ("$($rows.Count) call(s) spanning {0} s" -f $span)

