<#
.SYNOPSIS
	Takes the special ability copies of weapons out of the datapack, out of tools\weapons\retired_sa.csv.

.DESCRIPTION
	Retail ships every weapon that can carry a special ability three or four times : the plain item, and
	one copy per SA - "Arcana Mace" and "Arcana Mace - Acumen", "- MP Regeneration", "- Mana Up". This
	script keeps the plain one and drops the copies.

	What is dropped is the explicit list in retired_sa.csv, not a name pattern, so a rerun is a no-op and
	nothing new can wander into it by accident. Two kinds of weapon named the same way are NOT in it :

	  * polearms and other weapons whose <item_skill> is their own behaviour (3599 Pole Attack), not an SA ;
	  * "Falchion - for Beginners", "Mage Staff - for Beginners" and "Redemption Bow - Event Use", which are
	    items in their own right rather than a copy of another one.

	**This script cannot take an SA copy off an NPC.** 4700 "Sword of Delusion - Health" and 4900 "Staff
	of Evil Spirits - Magic Focus" are in the list but two NPCs hold them, and an emptied hand is worse
	than an SA copy - so those two go through remove_weapons.ps1 instead, which repoints the hand at the
	base weapon out of its $NPC_SWAP table :

	    powershell -File tools\weapons\remove_weapons.ps1 -Retired tools\weapons\retired_sa.csv

	Everything that points at a dropped id goes with it :

	  data/xml/items       the <item> block itself
	  data/xml/buyLists    the <product> lines of the GM shop
	  data/xml/itemIcons   the icon row the drop list window reads
	  data/xml/multisell   the whole <item> of any SA add / SA removal exchange that mentions one, and the
	                       file itself once it holds nothing else - with the html link that opened it

	Drops, recipes, quests and the soul crystal tables never mention an SA weapon, so there is nothing to
	do there.

.PARAMETER Repo
	Repository root. Defaults to the one this script lives in.

.PARAMETER NoSync
	Leave build\gameserver\data alone. Without it the pruned datapack is copied there too, as the CI
	deploys that folder as is.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\weapons\remove_sa.ps1
#>
param(
	[string]$Repo = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
	[switch]$NoSync
)

$ErrorActionPreference = 'Stop'

$dataDir = Join-Path $Repo 'source\aCis_datapack\data'
$xmlDir = Join-Path $dataDir 'xml'
$itemsDir = Join-Path $xmlDir 'items'
$multisellDir = Join-Path $xmlDir 'multisell'
$htmlDir = Join-Path $dataDir 'html'

if (-not (Test-Path $itemsDir)) { throw "No datapack at $itemsDir." }

$UTF8 = New-Object System.Text.UTF8Encoding $false

$retired = @(Import-Csv (Join-Path $PSScriptRoot 'retired_sa.csv'))
if ($retired.Count -eq 0) { throw 'retired_sa.csv is empty.' }

$ids = New-Object 'System.Collections.Generic.HashSet[int]'
foreach ($r in $retired) { $null = $ids.Add([int]$r.id) }
Write-Host "$($ids.Count) SA copies to remove"

# Datapack files carry no trailing newline ; adding one would show up as a diff on files this script
# didn't actually change.
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

function Save-Lines([string]$path, $lines, [bool]$endsNl)
{
	$text = ($lines -join "`r`n")
	if ($endsNl) { $text += "`r`n" }
	[System.IO.File]::WriteAllText($path, $text, $UTF8)
}

# ---------------------------------------------------------------------------
# The items themselves.
# ---------------------------------------------------------------------------

$goneItems = 0
foreach ($f in Get-ChildItem $itemsDir -Filter *.xml)
{
	$src = [System.IO.File]::ReadAllLines($f.FullName)
	$out = [System.Collections.Generic.List[string]]::new()
	$dropped = 0

	for ($i = 0; $i -lt $src.Count; $i++)
	{
		if ($src[$i] -match '^\s*<item\s+id="(\d+)"' -and $ids.Contains([int]$Matches[1]))
		{
			# A block ends on its own </item>, or on the same line when the item is a one liner.
			if ($src[$i] -notmatch '</item>')
			{
				while ($i -lt $src.Count -and $src[$i] -notmatch '</item>') { $i++ }
			}
			$dropped++
			continue
		}
		$null = $out.Add($src[$i])
	}

	if ($dropped -eq 0) { continue }
	Save-Lines $f.FullName $out (Test-EndsWithNewline $f.FullName)
	$goneItems += $dropped
}
Write-Host "data\xml\items : $goneItems item blocks removed"

# ---------------------------------------------------------------------------
# One line each : the GM shop products and the icon table.
# ---------------------------------------------------------------------------

function Remove-Lines([string]$path, [string]$pattern)
{
	$src = [System.IO.File]::ReadAllLines($path)
	$out = [System.Collections.Generic.List[string]]::new()
	$dropped = 0
	foreach ($l in $src)
	{
		if ($l -match $pattern -and $ids.Contains([int]$Matches[1])) { $dropped++ ; continue }
		$null = $out.Add($l)
	}
	if ($dropped -gt 0) { Save-Lines $path $out (Test-EndsWithNewline $path) }
	$dropped
}

$n = Remove-Lines (Join-Path $xmlDir 'buyLists.xml') '^\s*<product\s+id="(\d+)"'
Write-Host "data\xml\buyLists.xml : $n products removed"

$n = Remove-Lines (Join-Path $xmlDir 'itemIcons.xml') '^\s*<item\s+id="(\d+)"'
Write-Host "data\xml\itemIcons.xml : $n icons removed"

# ---------------------------------------------------------------------------
# The exchanges. An <item> that produces or eats an SA weapon goes whole ; a list left with nothing to
# trade goes with its html link, because an empty multisell window is worse than no link at all.
# ---------------------------------------------------------------------------

$emptied = @()
foreach ($f in Get-ChildItem $multisellDir -Filter *.xml)
{
	$src = [System.IO.File]::ReadAllLines($f.FullName)
	$out = [System.Collections.Generic.List[string]]::new()
	$dropped = 0
	$left = 0

	for ($i = 0; $i -lt $src.Count; $i++)
	{
		if ($src[$i] -notmatch '^\s*<item>\s*$') { $null = $out.Add($src[$i]) ; continue }

		$end = $i
		while ($end -lt $src.Count -and $src[$end] -notmatch '^\s*</item>\s*$') { $end++ }

		$hit = $false
		for ($j = $i; $j -le $end; $j++)
		{
			if ($src[$j] -match '<(?:production|ingredient)\s+id="(\d+)"' -and $ids.Contains([int]$Matches[1])) { $hit = $true ; break }
		}

		if ($hit) { $dropped++ }
		else
		{
			$left++
			for ($j = $i; $j -le $end; $j++) { $null = $out.Add($src[$j]) }
		}
		$i = $end
	}

	if ($dropped -eq 0) { continue }

	if ($left -eq 0)
	{
		Remove-Item $f.FullName -Force
		$emptied += [int]($f.BaseName)
		Write-Host "data\xml\multisell\$($f.Name) : $dropped entries removed, nothing left - file dropped"
		continue
	}

	Save-Lines $f.FullName $out (Test-EndsWithNewline $f.FullName)
	Write-Host "data\xml\multisell\$($f.Name) : $dropped entries removed, $left left"
}

foreach ($id in $emptied)
{
	foreach ($h in Get-ChildItem $htmlDir -Recurse -File)
	{
		$src = [System.IO.File]::ReadAllLines($h.FullName)
		$out = [System.Collections.Generic.List[string]]::new()
		$dropped = 0
		foreach ($l in $src)
		{
			if ($l -match "multisell\s+$id`"") { $dropped++ ; continue }
			$null = $out.Add($l)
		}
		if ($dropped -eq 0) { continue }
		Save-Lines $h.FullName $out (Test-EndsWithNewline $h.FullName)
		Write-Host "$($h.FullName.Substring($Repo.Length + 1)) : $dropped link(s) to multisell $id removed"
	}
}

# ---------------------------------------------------------------------------
# The CI ships build\ as it stands, so the pruned datapack has to land there too. A mirror, not a copy :
# a file the datapack dropped has to go from build\ as well, or the server keeps loading it.
# ---------------------------------------------------------------------------

if (-not $NoSync)
{
	$buildData = Join-Path $Repo 'build\gameserver\data'
	if (-not (Test-Path $buildData)) { Write-Warning "No $buildData ; skipping the build\ copy." }
	else
	{
		foreach ($rel in 'xml\buyLists.xml', 'xml\itemIcons.xml')
		{
			Copy-Item (Join-Path $dataDir $rel) (Join-Path $buildData $rel) -Force
		}
		foreach ($rel in 'xml\items', 'xml\multisell', 'html')
		{
			$from = Join-Path $dataDir $rel
			$to = Join-Path $buildData $rel
			$have = @{}
			foreach ($f in Get-ChildItem $from -Recurse -File)
			{
				$sub = $f.FullName.Substring($from.Length + 1)
				$have[$sub] = $true
				$dst = Join-Path $to $sub
				$null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst)
				Copy-Item $f.FullName $dst -Force
			}
			foreach ($f in Get-ChildItem $to -Recurse -File)
			{
				if (-not $have.ContainsKey($f.FullName.Substring($to.Length + 1))) { Remove-Item $f.FullName -Force }
			}
		}
		Write-Host 'synced items, multisell, html, buyLists.xml and itemIcons.xml into build\gameserver\data'
	}
}
