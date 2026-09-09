# Enchant glow settings of the Interlude client - system\env.int.
#
# The client keeps two thresholds in the [EnchantEffect] section of env.int :
#
#   EnchantMeshShow    from this level the aura MESH is drawn around the weapon
#                      (EnchantedMesh of weapongrp, tinted by the Enchant0..N
#                      colour rows further down the same section)
#   EnchantEffectShow  from this level the EFFECT is spawned (EnchantedEffect of
#                      weapongrp - the column tools\weapons\patch_client.ps1
#                      points at EnchantGlow)
#
# Stock is 4 and 7, so the graded effects would only start at +7 and the +4 rung
# of EnchantGlow would never be seen : pass -EffectShow 4. Neither threshold is
# touched unless it is asked for, so -Ladder can be rerun without moving them.
#
# -Ladder rewrites the Enchant0..N rows themselves so that the aura follows the
# same seven rungs the EnchantGlow ladder uses - see Set-Ladder below.
#
# env.int is a Lineage2Ver111 container : 28 byte UTF-16 header, body XOR'ed with
# 0xAC, 20 byte plain trailer. XOR is its own inverse, so the body is decoded,
# edited as text and encoded back ; the header and the trailer are copied over
# untouched. The trailer is not a checksum over the body - it is carried verbatim
# the same way tools\client\pack_l2_package.ps1 carries it, and the body is free
# to change length.
#
# See ../../docs/enchant-glow.md.
#
#   powershell -ExecutionPolicy Bypass -File patch_env_enchant.ps1 `
#       -In "<client>\system\env.int" -EffectShow 4 -Ladder

[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)][string] $In,
	[string] $OutFile,
	# -1 leaves the key alone, and that is the default for both : -Ladder rewrites rows and has no
	# business moving a threshold nobody asked it to move. Pass -EffectShow 4 to arm the ladder on
	# a live client, or -EffectShow 0 for the dev build, where the pawn's real level is 0.
	[int] $EffectShow = -1,
	[int] $MeshShow = -1,
	# Rewrite the Enchant0..N rows off the rungs below.
	[switch] $Ladder,
	# The rungs of EnchantGlow - keep in step with $GLOW_LEVELS of
	# tools\weapons\patch_client.ps1.
	[int[]] $Rungs = @(4, 7, 10, 12, 14, 15, 17),
	# [Variation] carries an Enchant0..N table of its own, of the same shape, for
	# augmented weapons. Left alone unless asked for.
	[switch] $IncludeVariation
)

$ErrorActionPreference = 'Stop'

$XOR = 0xAC
$HEADER = 28
$TRAILER = 20

if (!(Test-Path $In)) { throw "No such file: $In" }
$bytes = [System.IO.File]::ReadAllBytes($In)
if ($bytes.Length -le $HEADER + $TRAILER) { throw "$In is too short to be a Lineage2Ver111 container." }

$magic = [System.Text.Encoding]::Unicode.GetString($bytes, 0, $HEADER)
if ($magic -ne 'Lineage2Ver111') { throw "$In does not start with Lineage2Ver111 (got '$magic')." }

$bodyLen = $bytes.Length - $HEADER - $TRAILER
$plain = New-Object 'System.Collections.Generic.List[char]'
for ($i = $HEADER; $i -lt $HEADER + $bodyLen; $i++) { $null = $plain.Add([char]([byte]($bytes[$i] -bxor $XOR))) }
$text = -join $plain

# byte <-> char is one to one here, but the body is about to be rebuilt from the
# text rather than patched in place, so prove the round trip before editing it.
for ($i = 0; $i -lt $bodyLen; $i++)
{
	if ([byte]([byte][char]$text[$i] -bxor $XOR) -ne $bytes[$HEADER + $i])
	{
		throw "byte $i of the body does not survive decode/encode ; refusing to rewrite $In."
	}
}

function Set-Key([string] $key, [int] $value)
{
	if ($value -lt 0) { return }
	if ($script:text -notmatch "(?m)^$key=(\d+)[ \t]*\r?$") { throw "env.int has no $key= line." }
	$old = $Matches[1]
	$new = "$value"
	if ($new -eq $old) { Write-Host "$key is already $old" ; return }

	$rx = [regex] "(?m)^($key=)\d+"
	$script:text = $rx.Replace($script:text, "`${1}$new", 1)
	Write-Host "$key : $old -> $new"
}

# Opacity of one enchant level.
#
# Below the first rung the aura is off. Every rung then spans the levels up to the
# next one and shares its brightness out over them, so that the level right before
# the next rung is at full opacity and the step down from there is even : three
# levels give 0.33 / 0.66 / 1, two give 0.5 / 1, one gives 1. The last rung runs to
# the end of the table and is one step wide - everything from it up is full.
function Get-Opacity([int] $level, [int[]] $rungs)
{
	if ($level -lt $rungs[0]) { return 0.0 }

	$i = 0
	while ($i + 1 -lt $rungs.Count -and $level -ge $rungs[$i + 1]) { $i++ }

	$span = $(if ($i + 1 -lt $rungs.Count) { $rungs[$i + 1] - $rungs[$i] } else { 1 })
	$pos = $level - $rungs[$i] + 1
	if ($pos -ge $span) { return 1.0 }
	# The step is rounded first, so a rung of three reads 0.33 / 0.66 / 1 rather
	# than 0.33 / 0.67 / 1 - even helpings of the same share.
	return [Math]::Round([Math]::Round(1.0 / $span, 2) * $pos, 2)
}

function Format-Num([double] $v)
{
	return $v.ToString('0.##', [System.Globalization.CultureInfo]::InvariantCulture)
}

# Colour is not what tells the levels apart any more - EnchantGlow does that - so
# every row goes black and carries nothing but its opacity. Num is the density of
# the aura and stays at full on every row.
function Set-Ladder([string] $section, [int[]] $rungs)
{
	$head = "[$section]"
	$at = $script:text.IndexOf($head)
	if ($at -lt 0) { throw "env.int has no $head section." }

	$from = $at + $head.Length
	$next = [regex]::Match($script:text.Substring($from), '(?m)^\[')
	$len = $(if ($next.Success) { $next.Index } else { $script:text.Length - $from })
	$span = $script:text.Substring($from, $len)

	$script:touched = 0
	$span = [regex]::Replace($span, '(?m)^Enchant(\d+)=\([^\r\n]*\)', {
		param($m)
		$level = [int]$m.Groups[1].Value
		$o = Format-Num (Get-Opacity $level $rungs)
		$script:touched++
		return "Enchant$level=(R1=0,G1=0,B1=0,R2=0,G2=0,B2=0,Opacity=$o,Num=1)"
	})

	if ($script:touched -eq 0) { throw "$head has no Enchant<n>=(...) rows." }
	$script:text = $script:text.Substring(0, $from) + $span + $script:text.Substring($from + $len)
	Write-Host "$head : $($script:touched) Enchant row(s) rewritten off rungs $($rungs -join ', ')"
}

Set-Key 'EnchantEffectShow' $EffectShow
Set-Key 'EnchantMeshShow' $MeshShow

if ($Ladder)
{
	if ($Rungs.Count -lt 1) { throw "-Rungs needs at least one level." }
	$sorted = @($Rungs | Sort-Object -Unique)
	if ($sorted.Count -ne $Rungs.Count) { throw "-Rungs has to be strictly ascending." }

	Set-Ladder 'EnchantEffect' $sorted
	if ($IncludeVariation) { Set-Ladder 'Variation' $sorted }

	# What the ladder came out as, once, rather than 101 rows of it.
	$shown = @()
	foreach ($lvl in 0..($sorted[-1] + 1))
	{
		$shown += "+$lvl=$(Format-Num (Get-Opacity $lvl $sorted))"
	}
	Write-Host "opacity : $($shown -join ' ')  (and 1 from +$($sorted[-1]) up)"
}

$body = New-Object 'byte[]' $text.Length
for ($i = 0; $i -lt $text.Length; $i++) { $body[$i] = [byte]([byte][char]$text[$i] -bxor $XOR) }

$out = New-Object 'byte[]' ($HEADER + $body.Length + $TRAILER)
[Array]::Copy($bytes, 0, $out, 0, $HEADER)
[Array]::Copy($body, 0, $out, $HEADER, $body.Length)
[Array]::Copy($bytes, $bytes.Length - $TRAILER, $out, $HEADER + $body.Length, $TRAILER)

if (-not $OutFile) { $OutFile = $In }
if ($OutFile -eq $In)
{
	$bak = "$In.enchantglow.bak"
	if (-not (Test-Path $bak)) { [System.IO.File]::WriteAllBytes($bak, [System.IO.File]::ReadAllBytes($In)) }
	Write-Host "stock file kept as $bak"
}
[System.IO.File]::WriteAllBytes($OutFile, $out)
Write-Host "wrote $OutFile ($($bytes.Length) -> $($out.Length) bytes)"
