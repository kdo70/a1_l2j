<#
.SYNOPSIS
	Lets every weapon be sold, traded, warehoused and dropped - all but the ones only NPCs carry.

.DESCRIPTION
	Retail locks a good number of weapons down : the newbie gear a quest hands out, the GM toys, the
	Blacksmith's "common" copies. Five flags do it, and this takes all five off :

	    is_tradable  is_sellable  is_depositable  is_dropable  is_destroyable

	A flag that is not written is true, so the lines are removed rather than set to true - the
	datapack stays as short as it was.

	Left alone :

	  * `Monster Only (...)` and `For Monsters Only (...)` - NPC kit, no player is meant to hold it;
	  * the two cursed weapons, Zariche and Akamanah - dropping and trading them is the whole point
	    of the curse and the engine, not the item flags, decides how that works;
	  * the eleven Infinity hero weapons - they are lent for a hero period, not owned. HeroManager
	    takes them back when the period turns, and a tradable one would have been handed to somebody
	    who is not a hero in the meantime.

	The graded copies the ladder mints never carried these flags in the first place - generate.ps1
	drops them, because a quest's lock on a donor says nothing about a copy.

	Idempotent : a rerun finds nothing left to take off.

.PARAMETER Repo
	Repository root. Defaults to the one this script lives in.

.PARAMETER NoSync
	Leave build\gameserver\data alone. Without it the datapack is copied there too, as the CI
	deploys that folder as is.

.PARAMETER DryRun
	Print what would be freed, write nothing.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\weapons\free_weapons.ps1
#>
param(
	[string]$Repo = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
	[switch]$NoSync,
	[switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$dataDir = Join-Path $Repo 'source\aCis_datapack\data'
$xmlDir = Join-Path $dataDir 'xml'
$itemsDir = Join-Path $xmlDir 'items'
if (-not (Test-Path $itemsDir)) { throw "No datapack at $itemsDir." }

$UTF8 = New-Object System.Text.UTF8Encoding $false

$FLAGS = @('is_tradable', 'is_sellable', 'is_depositable', 'is_dropable', 'is_destroyable')

# The curse is a feature of the engine, and it leans on these items being what they are ; the hero
# weapons are on loan from the Olympiad and go back at the end of the period.
$KEEP_LOCKED = New-Object 'System.Collections.Generic.HashSet[int]'
foreach ($id in 6611..6621) { $null = $KEEP_LOCKED.Add($id) }
$cursed = Join-Path $xmlDir 'cursedWeapons.xml'
if (Test-Path $cursed)
{
	foreach ($l in [System.IO.File]::ReadAllLines($cursed))
	{
		if ($l -match '<item\s+id="(\d+)"') { $null = $KEEP_LOCKED.Add([int]$Matches[1]) }
	}
}
Write-Host "left locked : $(($KEEP_LOCKED | Sort-Object) -join ', ')"

function Test-EndsWithNewline([string]$path)
{
	$fs = [System.IO.File]::OpenRead($path)
	try
	{
		if ($fs.Length -eq 0) { return $false }
		$null = $fs.Seek(-1, [System.IO.SeekOrigin]::End)
		return ($fs.ReadByte() -eq 10)
	}
	finally { $fs.Dispose() }
}

$freed = 0
$linesGone = 0
$touchedFiles = 0
$monster = 0

foreach ($f in Get-ChildItem $itemsDir -Filter *.xml)
{
	$src = [System.IO.File]::ReadAllLines($f.FullName)

	# One pass to find every weapon block and decide about it, a second to write the file out.
	$strip = New-Object 'System.Collections.Generic.HashSet[int]'   # line numbers to drop
	$id = 0
	$isWeapon = $false
	$isMonster = $false
	$start = -1
	$mine = New-Object System.Collections.Generic.List[int]

	for ($i = 0; $i -lt $src.Count; $i++)
	{
		if ($src[$i] -match '^\s*<item\s+id="(\d+)"\s+type="([^"]*)"\s+name="([^"]*)"')
		{
			# Close the previous block off before opening a new one.
			if ($isWeapon -and -not $isMonster -and -not $KEEP_LOCKED.Contains($id) -and $mine.Count -gt 0)
			{
				foreach ($n in $mine) { $null = $strip.Add($n) }
				$freed++
			}
			elseif ($isWeapon -and $isMonster) { $monster++ }

			$id = [int]$Matches[1]
			$isWeapon = ($Matches[2] -eq 'Weapon')
			$isMonster = ($Matches[3] -match '(?i)monster')
			$start = $i
			$mine.Clear()
			continue
		}

		if (-not $isWeapon) { continue }
		if ($src[$i] -match '^\s*<set\s+name="([^"]+)"' -and $FLAGS -contains $Matches[1]) { $null = $mine.Add($i) }
	}
	if ($isWeapon -and -not $isMonster -and -not $KEEP_LOCKED.Contains($id) -and $mine.Count -gt 0)
	{
		foreach ($n in $mine) { $null = $strip.Add($n) }
		$freed++
	}
	elseif ($isWeapon -and $isMonster) { $monster++ }

	if ($strip.Count -eq 0) { continue }

	$out = New-Object System.Collections.Generic.List[string]
	for ($i = 0; $i -lt $src.Count; $i++)
	{
		if ($strip.Contains($i)) { continue }
		$null = $out.Add($src[$i])
	}

	$linesGone += $strip.Count
	$touchedFiles++
	if (-not $DryRun)
	{
		$text = ($out -join "`r`n")
		if (Test-EndsWithNewline $f.FullName) { $text += "`r`n" }
		[System.IO.File]::WriteAllText($f.FullName, $text, $UTF8)
	}
	Write-Host "data\xml\items\$($f.Name) : $($strip.Count) flag line(s) removed"
}

Write-Host "$freed weapon(s) freed, $linesGone flag line(s) removed from $touchedFiles file(s) ; $monster monster weapon(s) left as they were"

if ($DryRun) { Write-Host '' ; Write-Host 'dry run, nothing written' ; return }
if ($freed -eq 0) { return }

if (-not $NoSync)
{
	$buildItems = Join-Path $Repo 'build\gameserver\data\xml\items'
	if (-not (Test-Path $buildItems)) { Write-Warning "No $buildItems ; skipping the build\ copy." }
	else
	{
		foreach ($f in Get-ChildItem $itemsDir -Filter *.xml) { Copy-Item $f.FullName (Join-Path $buildItems $f.Name) -Force }
		Write-Host 'synced items into build\gameserver\data\xml\items'
	}
}
