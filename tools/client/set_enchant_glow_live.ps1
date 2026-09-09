<#
.SYNOPSIS
	Drives the enchant glow of a running client - the dev-mode half of patch_engine_enchant_glow.ps1 -Live.

.DESCRIPTION
	A client patched with -Live reads a 32 byte file before it builds an enchant glow, and lets that
	file override four things :

	    the enchant level the rung is picked by  - so any rung can be seen without a server
	    the offset the effect sits at            - three floats, the weapon's own axes
	    its scale
	    the speed of its particles

	This writes that file. Values not given are carried over from what is already there, so one
	number can be nudged at a time. A flag is only set for a value that has ever been given, and
	-Reset takes every flag off again, which hands the weapon back to whatever weapongrp says.

	**When it takes effect.** The client caches the built effect against the id of the weapon in
	hand, not against these numbers, so a change shows up the next time the effect is built : take
	the weapon off and put it back on, or switch weapons. Changing -Enchant is not enough on its own.

	**Below the first rung nothing is asked for at all.** Whether the client asks for an effect is
	settled before the patched function runs, by comparing the pawn's REAL enchant level against
	EnchantEffectShow in env.int. Without a server the level is 0, so dev mode also needs

	    patch_env_enchant.ps1 -In "<client>\system\env.int" -EffectShow 0

	or the cave never runs and none of this is reached.

	The file is written in one go. A client that catches it half written sees a short read, drops
	it, and uses the dat for that one frame.

	See ../../docs/enchant-glow.md.

.PARAMETER SystemDir
	The "system" directory of the client, where the file goes.

.EXAMPLE
	.\set_enchant_glow_live.ps1 -SystemDir "C:\l2client\system" -Enchant 17 -Scale 1.4

.EXAMPLE
	.\set_enchant_glow_live.ps1 -SystemDir "C:\l2client\system" -Offset 0,2,-3

.EXAMPLE
	.\set_enchant_glow_live.ps1 -SystemDir "C:\l2client\system" -Show
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)][string] $SystemDir,
	[string] $FileName = 'enchantglow.live',
	# The level the rung is chosen by. Below the ladder's first rung the weapon goes dark.
	[int] $Enchant,
	# Write that level into the pawn as well, not just grade by it. Without this the forced level
	# only picks the rung, and every other part of the client still sees an unenchanted weapon -
	# which is why nothing is drawn without a server. Takes effect from the next call on.
	[switch] $Poke,
	# Three numbers : along the blade, sideways, up. In Unreal units. Takes both "0,2,-3" and
	# 0,2,-3, because powershell -File hands the list over as one string.
	[object[]] $Offset,
	# 1 is the size the effect was authored at ; over 3 is enormous.
	[double] $Scale,
	# Lower keeps the particles tight to the weapon, higher throws them out.
	[double] $Velocity,
	# Keep what has been dialled in : writes the offset, scale and velocity now in the file into
	# enchant_glow_tuning.tsv under this key - a shape ("004t"), one weapon ("id:266") or "*".
	# From there tune_enchant_glow.ps1 puts it into weapongrp for good.
	[string] $SaveAs,
	# The table -SaveAs writes to. Defaults to enchant_glow_tuning.tsv next to this script.
	[string] $TuningFile,
	# Take every override off, leaving the client on what weapongrp says.
	[switch] $Reset,
	# Delete the file - same effect as -Reset, and the client stops finding anything to read.
	[switch] $Clear,
	# Print what the file holds and change nothing.
	[switch] $Show
)

$ErrorActionPreference = 'Stop'

$LIVE_LEN = 32
$LIVE_MAGIC = 0x574F4C47                  # 'GLOW'
$F_OFFSET = 1
$F_SCALE = 2
$F_VELOCITY = 4
$F_ENCHANT = 8
$F_POKE = 16

if (-not (Test-Path $SystemDir)) { throw "No such directory: $SystemDir" }
$path = Join-Path $SystemDir $FileName

function Show-Live([byte[]] $b)
{
	if ($null -eq $b) { Write-Host "$path : not there - the client uses weapongrp" ; return }
	$flags = [BitConverter]::ToInt32($b, 4)
	$on = @()
	if ($flags -band $F_ENCHANT)
	{
		$on += "enchant=$([BitConverter]::ToInt32($b, 8))" + $(if ($flags -band $F_POKE) { ' (written into the pawn)' } else { '' })
	}
	# Through the invariant culture throughout : these numbers are read back by people who then
	# type them into a table that only takes a dot.
	$inv = [System.Globalization.CultureInfo]::InvariantCulture
	if ($flags -band $F_OFFSET)
	{
		$on += ("offset=({0}, {1}, {2})" -f ([BitConverter]::ToSingle($b, 12)).ToString('0.###', $inv),
			([BitConverter]::ToSingle($b, 16)).ToString('0.###', $inv),
			([BitConverter]::ToSingle($b, 20)).ToString('0.###', $inv))
	}
	if ($flags -band $F_SCALE) { $on += "scale=$(([BitConverter]::ToSingle($b, 24)).ToString('0.###', $inv))" }
	if ($flags -band $F_VELOCITY) { $on += "velocity=$(([BitConverter]::ToSingle($b, 28)).ToString('0.###', $inv))" }
	if ($on.Count -eq 0) { Write-Host "$path : nothing overridden" } else { Write-Host "$path : $($on -join '  ')" }
}

# What is there now, if it is ours and whole - so that one value can be changed without
# restating the rest.
$cur = $null
if (Test-Path $path)
{
	$raw = [System.IO.File]::ReadAllBytes($path)
	if ($raw.Length -eq $LIVE_LEN -and [BitConverter]::ToInt32($raw, 0) -eq $LIVE_MAGIC) { $cur = $raw }
	elseif (-not $Clear) { Write-Warning "$path is not a $LIVE_LEN byte 'GLOW' file ; starting over." }
}

if ($Show) { Show-Live $cur ; return }

if ($Clear)
{
	if (Test-Path $path) { Remove-Item $path -Force ; Write-Host "removed $path" }
	else { Write-Host "$path was not there" }
	return
}

$b = New-Object 'byte[]' $LIVE_LEN
if ($cur) { [Array]::Copy($cur, $b, $LIVE_LEN) }
[Array]::Copy([BitConverter]::GetBytes([int]$LIVE_MAGIC), 0, $b, 0, 4)

$flags = $(if ($cur) { [BitConverter]::ToInt32($cur, 4) } else { 0 })
if ($Reset) { $flags = 0 }

function Set-Float([int] $at, [double] $v)
{
	[Array]::Copy([BitConverter]::GetBytes([single]$v), 0, $script:b, $at, 4)
}

if ($PSBoundParameters.ContainsKey('Enchant'))
{
	[Array]::Copy([BitConverter]::GetBytes([int]$Enchant), 0, $b, 8, 4)
	$flags = $flags -bor $F_ENCHANT
}
if ($PSBoundParameters.ContainsKey('Poke'))
{
	if ($Poke) { $flags = $flags -bor $F_POKE } else { $flags = $flags -band (-bnot $F_POKE) }
}
if ($PSBoundParameters.ContainsKey('Offset'))
{
	$inv = [System.Globalization.CultureInfo]::InvariantCulture
	$xyz = @()
	foreach ($piece in (($Offset -join ',') -split '[,;\s]+' | Where-Object { $_ -ne '' }))
	{
		$parsed = 0.0
		if (-not [double]::TryParse($piece, [Globalization.NumberStyles]::Float, $inv, [ref]$parsed))
		{
			throw "-Offset : '$piece' is not a number."
		}
		$xyz += $parsed
	}
	if ($xyz.Count -ne 3) { throw "-Offset takes three numbers, got $($xyz.Count)." }
	Set-Float 12 $xyz[0]
	Set-Float 16 $xyz[1]
	Set-Float 20 $xyz[2]
	$flags = $flags -bor $F_OFFSET
}
if ($PSBoundParameters.ContainsKey('Scale'))
{
	Set-Float 24 $Scale
	$flags = $flags -bor $F_SCALE
}
if ($PSBoundParameters.ContainsKey('Velocity'))
{
	Set-Float 28 $Velocity
	$flags = $flags -bor $F_VELOCITY
}

[Array]::Copy([BitConverter]::GetBytes([int]$flags), 0, $b, 4, 4)
[System.IO.File]::WriteAllBytes($path, $b)
Show-Live $b

# ---------------------------------------------------------------------------
# Keeping it : the same three numbers, into the table weapongrp is built from.
# ---------------------------------------------------------------------------

function Save-Tuning([string] $key, [byte[]] $blob, [string] $table)
{
	$inv = [System.Globalization.CultureInfo]::InvariantCulture
	if ($key -notmatch '^(\*|[0-9a-z]+t|id:[0-9]+)$')
	{
		throw "-SaveAs takes '*', a shape like 004t, or id:<n> ; got '$key'."
	}

	$f = [BitConverter]::ToInt32($blob, 4)
	# A value that was never dialled in has nothing to keep, so it is saved as the neutral one
	# rather than as whatever zero happens to be sitting in the block.
	$vals = @(0.0, 0.0, 0.0, 1.0, 1.0)
	if ($f -band $F_OFFSET)
	{
		$vals[0] = [BitConverter]::ToSingle($blob, 12)
		$vals[1] = [BitConverter]::ToSingle($blob, 16)
		$vals[2] = [BitConverter]::ToSingle($blob, 20)
	}
	else { Write-Warning "offset was not overridden ; saving 0 0 0." }
	if ($f -band $F_SCALE) { $vals[3] = [BitConverter]::ToSingle($blob, 24) } else { Write-Warning "scale was not overridden ; saving 1." }
	if ($f -band $F_VELOCITY) { $vals[4] = [BitConverter]::ToSingle($blob, 28) } else { Write-Warning "velocity was not overridden ; saving 1." }

	$cells = $vals | ForEach-Object { $_.ToString('0.###', $inv) }
	$row = "{0,-8} {1,-6} {2,-6} {3,-6} {4,-7} {5}" -f $key, $cells[0], $cells[1], $cells[2], $cells[3], $cells[4]

	if (-not (Test-Path $table)) { throw "No such table: $table" }
	$lines = [System.Collections.Generic.List[string]]::new()
	foreach ($l in [System.IO.File]::ReadAllLines($table)) { $null = $lines.Add($l) }

	$at = -1
	for ($i = 0; $i -lt $lines.Count; $i++)
	{
		$s = $lines[$i].Trim()
		if ($s -eq '' -or $s.StartsWith('#')) { continue }
		if (($s -split '[\s]+')[0] -eq $key) { $at = $i ; break }
	}

	if ($at -ge 0)
	{
		Write-Host "$table : $key was '$($lines[$at].Trim())'"
		$lines[$at] = $row
	}
	else
	{
		$lines.Add($row)
	}

	[System.IO.File]::WriteAllLines($table, $lines, (New-Object System.Text.UTF8Encoding $false))
	Write-Host "$table : $key -> $($row.Trim())"
}

if ($SaveAs)
{
	if (-not $TuningFile) { $TuningFile = Join-Path $PSScriptRoot 'enchant_glow_tuning.tsv' }
	Save-Tuning $SaveAs $b $TuningFile
	Write-Host 'run tune_enchant_glow.ps1 to put the table into weapongrp'
}

Write-Host 're-equip the weapon in the client for this to be picked up'
