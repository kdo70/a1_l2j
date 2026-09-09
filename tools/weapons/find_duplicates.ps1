<#
.SYNOPSIS
	Finds weapons that share a look - same mesh, same texture, same type, same grade - and proposes
	which one of each group to keep.

.DESCRIPTION
	Interlude reuses a mesh across a whole family of weapons : `Long Sword`, `Sword of Solidarity`,
	`Old Knight Sword` and `Apprentice Adventurer's Long Sword` are one and the same object in the
	world, four times over in the shop. This script groups them and writes a proposal to
	duplicates.csv - one row per weapon that would go, with the id that stays next to it.

	**Grouped by mesh + texture + weapon_type + crystal_type.** Two weapons that look alike but sit
	at different grades are two different weapons as far as a player is concerned, so they stay.

	Left out of the hunt entirely :

	  * `PET`, `FISHINGROD`, `NONE`, `FIST` - the 33 pet fangs share one placeholder mesh, and the
	    nine racial fists have no mesh at all ; neither is a weapon anybody picks;
	  * `Monster Only (...)` and `For Monsters Only (...)` - NPC kit, and it has its own shop tab.

	**Which one stays** is a guess, and it is meant to be overruled : the file is a proposal, and
	`dedup_weapons.ps1` reads whatever is in it. The guess scores each name against the mesh it
	wears - `long_sword_m00_wp` wants to be called `Long Sword` - then prefers the one NPCs already
	carry, then the lower id. Names that are plainly derivative lose points : `(Event)`,
	`Traveler's`, `Apprentice Adventurer's`, `- for Beginners`, `- Event Use`.

.PARAMETER Repo
	Repository root. Defaults to the one this script lives in.

.PARAMETER Weapongrp
	weapongrp.dat already disassembled to text - the table that says what each weapon looks like.
	Produced by l2disasm ; see tools\weapons\README.md.

.PARAMETER Out
	Where to write the proposal. Defaults to tools\weapons\duplicates.csv.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\weapons\find_duplicates.ps1 -Weapongrp C:\tmp\weapongrp.txt
#>
param(
	[string]$Repo = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
	[string]$Weapongrp = '',
	[string]$Out = ''
)

$ErrorActionPreference = 'Stop'

if ($Weapongrp -eq '') { throw 'Give -Weapongrp : weapongrp.dat disassembled to text.' }
if ($Out -eq '') { $Out = Join-Path $PSScriptRoot 'duplicates.csv' }

$xmlDir = Join-Path $Repo 'source\aCis_datapack\data\xml'
$itemsDir = Join-Path $xmlDir 'items'
$npcsDir = Join-Path $xmlDir 'npcs'
if (-not (Test-Path $itemsDir)) { throw "No datapack at $itemsDir." }

$UTF8 = New-Object System.Text.UTF8Encoding $false

# The minted ladder shares its donor's look on purpose - it is not a duplicate, it is the same
# weapon one grade up.
$LADDER_FIRST = 12000
$LADDER_LAST = 19999
$SKIP_TYPE = @('PET', 'FISHINGROD', 'NONE', 'FIST')

# ---------------------------------------------------------------------------
# What the datapack has.
# ---------------------------------------------------------------------------

$weapon = @{}
foreach ($f in Get-ChildItem $itemsDir -Filter *.xml)
{
	$id = $null ; $type = $null ; $name = $null ; $wt = '' ; $ct = 'NG'
	foreach ($l in [System.IO.File]::ReadLines($f.FullName))
	{
		if ($l -match '<item\s+id="(\d+)"\s+type="([^"]*)"\s+name="([^"]*)"')
		{
			if ($id -and $type -eq 'Weapon') { $weapon[$id] = @{ name = $name; wtype = $wt; grade = $ct } }
			$id = $Matches[1] ; $type = $Matches[2] ; $name = $Matches[3] ; $wt = '' ; $ct = 'NG'
		}
		elseif ($l -match '<set\s+name="weapon_type"\s+val="([^"]*)"') { $wt = $Matches[1] }
		elseif ($l -match '<set\s+name="crystal_type"\s+val="([^"]*)"') { $ct = $Matches[1] }
	}
	if ($id -and $type -eq 'Weapon') { $weapon[$id] = @{ name = $name; wtype = $wt; grade = $ct } }
}

$grp = @{}
$lines = [System.IO.File]::ReadAllLines($Weapongrp)
$cols = @{}
$header = $lines[0].Split("`t")
for ($i = 0; $i -lt $header.Count; $i++) { $cols[$header[$i]] = $i }
foreach ($need in 'id', 'wpn_mesh[0]', 'wpn_mesh[1]', 'wpn_tex[0]', 'wpn_tex[1]', 'wpn_tex[2]')
{
	if (-not $cols.ContainsKey($need)) { throw "$Weapongrp has no column '$need' ; is it weapongrp ?" }
}
for ($i = 1; $i -lt $lines.Count; $i++)
{
	if ([string]::IsNullOrWhiteSpace($lines[$i])) { continue }
	$f = $lines[$i].Split("`t")
	$grp[$f[$cols['id']]] = $f
}

$npcUse = @{}
foreach ($f in Get-ChildItem $npcsDir -Filter *.xml)
{
	foreach ($l in [System.IO.File]::ReadLines($f.FullName))
	{
		if ($l -match '<set\s+name="[rl]Hand"\s+val="(\d+)"')
		{
			$v = $Matches[1]
			if ($v -eq '0') { continue }
			$npcUse[$v] = 1 + $(if ($npcUse.ContainsKey($v)) { $npcUse[$v] } else { 0 })
		}
	}
}

# ---------------------------------------------------------------------------
# The groups.
# ---------------------------------------------------------------------------

$groups = @{}
foreach ($id in $weapon.Keys)
{
	if ([int]$id -ge $LADDER_FIRST -and [int]$id -le $LADDER_LAST) { continue }
	if ($SKIP_TYPE -contains $weapon[$id].wtype) { continue }
	if ($weapon[$id].name -match '(?i)monster') { continue }
	if (-not $grp.ContainsKey($id)) { continue }
	$r = $grp[$id]
	$mesh = $r[$cols['wpn_mesh[0]']]
	if ($mesh -eq '') { continue }
	$key = @($mesh, $r[$cols['wpn_mesh[1]']], $r[$cols['wpn_tex[0]']], $r[$cols['wpn_tex[1]']],
		$r[$cols['wpn_tex[2]']], $weapon[$id].wtype, $weapon[$id].grade) -join "`t"
	if (-not $groups.ContainsKey($key)) { $groups[$key] = New-Object System.Collections.Generic.List[string] }
	$groups[$key].Add($id)
}

# How much of the mesh name the item name carries. Tokens are matched against the name with its
# spaces and apostrophes taken out, so "Broadsword" still answers to broad_sword.
function Get-NameScore([string]$name, [string]$mesh)
{
	$m = ($mesh -replace '^.*\.', '') -replace '_m\d+_wp$', ''
	$tokens = @($m -split '_' | Where-Object { $_ -ne '' -and $_ -notmatch '^\d+$' -and $_ -ne 'wp' })
	if ($tokens.Count -eq 0) { return 0 }
	$flat = ($name.ToLower() -replace "[^a-z0-9]", '')
	$hit = 0
	foreach ($t in $tokens) { if ($flat.Contains($t)) { $hit++ } }
	[int][math]::Round(100.0 * $hit / $tokens.Count)
}

# A name that only exists because it is a copy of another weapon never wins its group : an event
# duplicate scores 100 against the mesh it was cloned from, and would otherwise beat the retail
# weapon it is a copy of. Only if a group is nothing but copies does the least bad one survive.
function Get-Penalty([string]$name)
{
	$p = 0
	if ($name -match '\(Event\)') { $p -= 1000 }
	if ($name -match "^(Traveler's|Apprentice Adventurer's)") { $p -= 1000 }
	if ($name -match ' - for Beginners| - Event Use') { $p -= 1000 }
	if ($name -eq '0' -or $name -eq '_' -or $name -eq '') { $p -= 5000 }
	$p
}

# A weapon a quest hands out, asks for or checks cannot simply vanish : the quest would go on
# naming an id the datapack no longer has. Those rows are marked rather than left out, so the file
# says what it knows and dedup_weapons.ps1 can be told what to do about them.
$questSrc = Join-Path $Repo 'source\aCis_gameserver\java\net\sf\l2j\gameserver\scripting'
$questText = @()
if (Test-Path $questSrc)
{
	foreach ($f in Get-ChildItem $questSrc -Recurse -File -Filter *.java)
	{
		$questText += , @{ name = $f.BaseName; text = [System.IO.File]::ReadAllText($f.FullName) }
	}
}
$questHtm = @()
$htmSrc = Join-Path $Repo 'source\aCis_datapack\data\html\script'
if (Test-Path $htmSrc)
{
	foreach ($f in Get-ChildItem $htmSrc -Recurse -File)
	{
		$questHtm += , @{ name = $f.Name; text = [System.IO.File]::ReadAllText($f.FullName) }
	}
}

function Get-QuestUse([string]$id)
{
	$re = '(?<![\w.])' + $id + '(?![\w])'
	$out = @()
	foreach ($q in $questText) { if ($q.name -match '^Q\d' -and $q.text -match $re) { $out += $q.name } }
	if ($out.Count -eq 0) { foreach ($q in $questHtm) { if ($q.text -match $re) { $out += 'htm:' + $q.name ; break } } }
	($out | Sort-Object -Unique) -join ' '
}

$rows = New-Object System.Collections.Generic.List[string]
$rows.Add('"drop","dropName","keep","keepName","type","grade","npcHands","questUse","mesh"')

$groupCount = 0
$dropCount = 0
$questBound = 0
foreach ($key in ($groups.Keys | Sort-Object))
{
	$ids = $groups[$key]
	if ($ids.Count -lt 2) { continue }
	$groupCount++

	$parts = $key.Split("`t")
	$mesh = $parts[0]

	$keep = $null ; $best = $null
	foreach ($id in ($ids | Sort-Object { [int]$_ }))
	{
		$score = (Get-NameScore $weapon[$id].name $mesh) + (Get-Penalty $weapon[$id].name)
		$hands = $(if ($npcUse.ContainsKey($id)) { $npcUse[$id] } else { 0 })
		if ($null -eq $keep -or $score -gt $best[0] -or ($score -eq $best[0] -and $hands -gt $best[1]))
		{
			$keep = $id ; $best = @($score, $hands)
		}
	}

	foreach ($id in ($ids | Sort-Object { [int]$_ }))
	{
		if ($id -eq $keep) { continue }
		$hands = $(if ($npcUse.ContainsKey($id)) { $npcUse[$id] } else { 0 })
		$quest = Get-QuestUse $id
		if ($quest -ne '') { $questBound++ }
		$rows.Add(('"{0}","{1}","{2}","{3}","{4}","{5}","{6}","{7}","{8}"' -f $id, $weapon[$id].name.Replace('"', ''),
				$keep, $weapon[$keep].name.Replace('"', ''), $parts[5], $parts[6], $hands, $quest, $mesh))
		$dropCount++
	}
}

[System.IO.File]::WriteAllText($Out, (($rows -join "`r`n") + "`r`n"), $UTF8)
Write-Host "$groupCount group(s) of look alike weapons, $dropCount would go - $questBound of them are named by a quest"
Write-Host "wrote $Out - read it, fix the 'keep' column where the guess is wrong, then run dedup_weapons.ps1"
