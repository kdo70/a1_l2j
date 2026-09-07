# Sets the enchant level a weapon starts glowing at - system\env.int of the
# Interlude client.
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
# of EnchantGlow would never be seen. This sets EnchantEffectShow to 4.
#
# env.int is a Lineage2Ver111 container : 28 byte UTF-16 header, body XOR'ed with
# 0xAC, 20 byte plain trailer. XOR is its own inverse and this script only ever
# swaps one digit for another of the same width, so the file is edited in place -
# nothing is re-encoded, no length moves and the trailer is never touched.
#
# See ../../docs/enchant-glow.md.
#
#   powershell -ExecutionPolicy Bypass -File patch_env_enchant.ps1 `
#       -In "<client>\system\env.int"

[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)][string] $In,
	[string] $OutFile,
	# -1 leaves the key alone.
	[int] $EffectShow = 4,
	[int] $MeshShow = -1
)

$ErrorActionPreference = 'Stop'

$XOR = 0xAC
$HEADER = 28

if (!(Test-Path $In)) { throw "No such file: $In" }
$bytes = [System.IO.File]::ReadAllBytes($In)
if ($bytes.Length -le $HEADER + 20) { throw "$In is too short to be a Lineage2Ver111 container." }

$magic = [System.Text.Encoding]::Unicode.GetString($bytes, 0, $HEADER)
if ($magic -ne 'Lineage2Ver111') { throw "$In does not start with Lineage2Ver111 (got '$magic')." }

# The whole body, decoded, only so that a key can be found in it by offset.
$plain = New-Object 'System.Collections.Generic.List[char]'
for ($i = $HEADER; $i -lt $bytes.Length - 20; $i++) { $null = $plain.Add([char]([byte]($bytes[$i] -bxor $XOR))) }
$text = -join $plain

function Set-Key([string] $key, [int] $value)
{
	if ($value -lt 0) { return }
	if ($text -notmatch "(?m)^$key=(\d+)\s*$") { throw "env.int has no $key= line." }
	$old = $Matches[1]
	$new = "$value"
	if ($new.Length -ne $old.Length) { throw "$key is '$old' and would become '$new' ; only a same width value can be swapped in place." }
	if ($new -eq $old) { Write-Host "$key is already $old" ; return }

	$at = $text.IndexOf("$key=$old")
	if ($at -lt 0) { throw "$key= vanished between the match and the edit." }
	$at += $key.Length + 1
	for ($i = 0; $i -lt $new.Length; $i++)
	{
		$script:bytes[$HEADER + $at + $i] = [byte]([byte][char]$new[$i] -bxor $XOR)
	}
	Write-Host "$key : $old -> $new"
}

Set-Key 'EnchantEffectShow' $EffectShow
Set-Key 'EnchantMeshShow' $MeshShow

if (-not $OutFile) { $OutFile = $In }
if ($OutFile -eq $In)
{
	$bak = "$In.enchantglow.bak"
	if (-not (Test-Path $bak)) { [System.IO.File]::WriteAllBytes($bak, [System.IO.File]::ReadAllBytes($In)) }
	Write-Host "stock file kept as $bak"
}
[System.IO.File]::WriteAllBytes($OutFile, $bytes)
Write-Host "wrote $OutFile"
