<#
.SYNOPSIS
	Merges look alike weapons into one, out of tools\weapons\duplicates.csv.

.DESCRIPTION
	find_duplicates.ps1 groups the weapons that share a mesh, a texture, a type and a grade, and
	proposes one keeper per group. This applies that file : every weapon in the "drop" column leaves
	the datapack and the ladder, and anything that pointed at it points at the keeper instead.

	Since the two share their mesh and texture, **nothing changes in the world** - an NPC that held
	`Traveler's Pike` now holds `Pike` and looks exactly the same.

	What happens to each row :

	  weapons.csv          the dropped id leaves, so the ladder stops minting copies of it
	  data/xml/**          remove_weapons.ps1 does the rest - item, icon, shop, exchange, recipe -
	                       and repoints NPC hands at the keeper, taken from the "keep" column
	  system\*.dat         remove_sa_client.ps1 takes the same ids out of the client tables

	**Quest bound rows are skipped by default.** A weapon a quest hands out, asks for or checks
	cannot merely vanish : the quest would go on naming an id that is not there any more. Those rows
	carry the quest names in the `questUse` column and are left alone unless -IncludeQuestBound is
	given, and that flag is not enough on its own - the quests have to be repointed by hand first.

	Run generate.ps1 and patch_client.ps1 afterwards : the ladder is a copy of what remains, and the
	client has to be told about the ids that moved.

.PARAMETER Repo
	Repository root. Defaults to the one this script lives in.

.PARAMETER List
	The proposal to apply. Defaults to duplicates.csv next to this script.

.PARAMETER IncludeQuestBound
	Also merge the rows a quest names. Only with the quests already repointed at the keeper.

.PARAMETER DryRun
	Work out every merge and print the tally, but write nothing.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\weapons\dedup_weapons.ps1 -DryRun
#>
param(
	[string]$Repo = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
	[string]$List = '',
	[switch]$IncludeQuestBound,
	[switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if ($List -eq '') { $List = Join-Path $PSScriptRoot 'duplicates.csv' }
if (-not (Test-Path $List)) { throw "Missing $List - run find_duplicates.ps1 first." }

$UTF8 = New-Object System.Text.UTF8Encoding $false
$outDir = Join-Path $PSScriptRoot 'generated'
$null = New-Item -ItemType Directory -Force -Path $outDir

$rows = @(Import-Csv $List)
if ($rows.Count -eq 0) { throw "$List is empty." }

$bound = @($rows | Where-Object { $_.questUse -ne '' })
$take = @($rows | Where-Object { $IncludeQuestBound -or $_.questUse -eq '' })

Write-Host "$($rows.Count) look alike weapon(s) in the list, $($bound.Count) of them named by a quest"
if (-not $IncludeQuestBound -and $bound.Count -gt 0)
{
	Write-Host "  skipping the quest bound ones ; pass -IncludeQuestBound once the quests point at the keeper"
}
if ($take.Count -eq 0) { Write-Host 'nothing to do' ; return }

# A keeper that is itself dropped somewhere else would merge a weapon into a weapon that is going
# away. Follow the chain to whatever actually survives, and refuse a loop.
$keepOf = @{}
foreach ($r in $take) { $keepOf[$r.drop] = $r.keep }
foreach ($r in $take)
{
	$seen = @{}
	$to = $r.keep
	while ($keepOf.ContainsKey($to))
	{
		if ($seen.ContainsKey($to)) { throw "the keep column loops around $($r.drop)." }
		$seen[$to] = $true
		$to = $keepOf[$to]
	}
	if ($to -ne $r.keep) { Write-Host "  $($r.drop) -> $($r.keep) -> $to (the keeper was dropped too)" }
	$r.keep = $to
}

# ---------------------------------------------------------------------------
# weapons.csv first : remove_weapons.ps1 refuses to run while a retired id is still on the ladder.
# ---------------------------------------------------------------------------

$weaponsCsv = Join-Path $PSScriptRoot 'weapons.csv'
$gone = @()
if (Test-Path $weaponsCsv)
{
	$drop = @{}
	foreach ($r in $take) { $drop[$r.drop] = $true }
	$lines = [System.IO.File]::ReadAllLines($weaponsCsv)
	$keep = New-Object System.Collections.Generic.List[string]
	foreach ($l in $lines)
	{
		if ([string]::IsNullOrWhiteSpace($l)) { continue }
		if ($l -match '^"(\d+)"' -and $drop.ContainsKey($Matches[1])) { $gone += $Matches[1] ; continue }
		$null = $keep.Add($l)
	}
	if ($gone.Count -gt 0 -and -not $DryRun)
	{
		[System.IO.File]::WriteAllText($weaponsCsv, (($keep -join "`r`n") + "`r`n"), $UTF8)
	}
	Write-Host "weapons.csv : $($keep.Count - 1) rows, $($gone.Count) taken off the ladder"
}

# ---------------------------------------------------------------------------
# The list remove_weapons.ps1 eats : id, name, and the swap it has to put in an NPC's hand.
# ---------------------------------------------------------------------------

$retired = New-Object System.Collections.Generic.List[string]
$retired.Add('"id","name","swap","keepName"')
foreach ($r in ($take | Sort-Object { [int]$_.drop }))
{
	$retired.Add(('"{0}","{1}","{2}","{3}"' -f $r.drop, $r.dropName.Replace('"', ''), $r.keep, $r.keepName.Replace('"', '')))
}
$retiredPath = Join-Path $outDir 'dedup_retired.csv'
[System.IO.File]::WriteAllText($retiredPath, (($retired -join "`r`n") + "`r`n"), $UTF8)
Write-Host "wrote $retiredPath ($($take.Count) weapon(s))"

if ($DryRun) { Write-Host '' ; Write-Host 'dry run, nothing else written' ; return }

# ---------------------------------------------------------------------------
# And the removal itself.
# ---------------------------------------------------------------------------

& (Join-Path $PSScriptRoot 'remove_weapons.ps1') -Repo $Repo -Retired $retiredPath
Write-Host ''
Write-Host 'now rerun generate.ps1, then remove_sa_client.ps1 with generated\dedup_retired.csv, then patch_client.ps1'
