<#
.SYNOPSIS
	Takes whole weapons out of the datapack, out of tools\weapons\retired_weapons.csv.

.DESCRIPTION
	remove_sa.ps1 drops SA COPIES - items nothing else in the game refers to. This one drops weapons
	that were part of retail, so it has to follow every thread they hang on :

	  data/xml/items       the <item> block itself
	  data/xml/itemIcons   the icon row the drop list window reads
	  data/xml/buyLists    the <product> lines of every shop, the GM shop included
	  data/xml/multisell   the whole <item> of any exchange that mentions one - the dual sword
	                       blacksmiths and the Blacksmith of Mammon - and the file itself once it
	                       holds nothing else, with the html link that opened it
	  data/xml/recipes     the <recipe> that produces one, AND the recipe item it is written on,
	                       which is then dropped as an item and out of the shops like any other
	  data/xml/npcs        NPCs holding one in a hand : the hand is REPOINTED at a surviving weapon
	                       of the same class and grade (see $NPC_SWAP), not emptied

	What it does NOT chase, on purpose : the blades and edges those weapons were crafted from
	(2017 Saber Edge, 2077 Shamshir Blade, 2078 Katana Blade, 2090 Sword of Delusion Blade, 8334)
	stay. They still drop and still sell ; they simply no longer lead anywhere, the way plenty of
	Interlude materials already do. Chasing them would pull in their own recipes, their own recipe
	items and the drop lists of everything that carries them.

	**Run generate.ps1 first.** A retired weapon has to be out of weapons.csv before the ladder is
	minted again, or the graded copies of a weapon that no longer exists are minted right back. This
	script refuses to run while any retired id is still in weapons.csv.

	The client half is remove_sa_client.ps1 with -Retired pointing at the same list : the two tables
	that still describe these ids to the client are weapongrp.dat and itemname-e.dat.

.PARAMETER Repo
	Repository root. Defaults to the one this script lives in.

.PARAMETER Retired
	The list to drop. Defaults to retired_weapons.csv next to this script.

.PARAMETER NoSync
	Leave build\gameserver\data alone. Without it the pruned datapack is copied there too, as the CI
	deploys that folder as is.

.PARAMETER DryRun
	Work out every removal and print the tally, but write nothing.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\weapons\remove_weapons.ps1 -DryRun
#>
param(
	[string]$Repo = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
	[string]$Retired = '',
	[switch]$NoSync,
	[switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if ($Retired -eq '') { $Retired = Join-Path $PSScriptRoot 'retired_weapons.csv' }

$dataDir = Join-Path $Repo 'source\aCis_datapack\data'
$xmlDir = Join-Path $dataDir 'xml'
$itemsDir = Join-Path $xmlDir 'items'
$multisellDir = Join-Path $xmlDir 'multisell'
$npcsDir = Join-Path $xmlDir 'npcs'
$htmlDir = Join-Path $dataDir 'html'

if (-not (Test-Path $itemsDir)) { throw "No datapack at $itemsDir." }

$UTF8 = New-Object System.Text.UTF8Encoding $false

# What an NPC's hand gets instead. Same class and grade, closest thing left standing - an NPC that
# used to hold a sword goes on holding a sword. Emptying the hand instead would restyle 103 NPCs.
$NPC_SWAP = @{
	67   = 68     # Orcish Sword       NG -> Falchion
	73   = 131    # Shamshir           C  -> Spirit Sword
	74   = 135    # Katana             C  -> Samurai Longsword
	76   = 134    # Sword of Delusion  C  -> Sword of Nightmare
	123  = 129    # Saber              D  -> Sword of Revolution
	127  = 128    # Crimson Sword      D  -> Knight's Sword
	7887 = 0      # Mysterious Sword   - no NPC carries one
	86   = 156    # Tomahawk           D  -> Hand Axe
	96   = 95     # Scythe             C  -> Poleaxe
	153  = 4      # Sickle             NG -> Club
	223  = 222    # Kukuri             D  -> Poniard Dagger
	228  = 227    # Crystal Dagger     C  -> Stiletto
	240  = 239    # Conjurer's Knife   D  -> Mystic Knife
	298  = 299    # Orcish Glaive      C  -> Orcish Poleaxe

	# The two SA copies NPCs carry. Their base weapon has the same mesh and the same texture - only
	# the inventory icon differs, and nobody sees an NPC's inventory - so the swap is invisible in
	# the world. This is the one place where an NPC hand moves off the weapon retail gave it, and it
	# buys the datapack a game with no SA copy left in it at all.
	4700 = 76     # Sword of Delusion - Health      -> Sword of Delusion
	4900 = 210    # Staff of Evil Spirits - M.Focus -> Staff of Evil Spirits
}

# ---------------------------------------------------------------------------
# The list, and what hangs off it.
# ---------------------------------------------------------------------------

if (-not (Test-Path $Retired)) { throw "Missing $Retired." }
# Not $retired : PowerShell tells no variable from another by case, and -Retired is a [string].
$list = @(Import-Csv $Retired)
if ($list.Count -eq 0) { throw "$Retired is empty." }

$ids = New-Object 'System.Collections.Generic.HashSet[int]'
$nameOf = @{}
# A list may carry its own answer for the hand of an NPC, in a "swap" column - that is how
# dedup_weapons.ps1 says "this weapon is being merged into that one". Without it the hardcoded
# $NPC_SWAP above is the only source, and an id missing from both is refused.
$swapOf = @{}
foreach ($r in $list)
{
	$null = $ids.Add([int]$r.id)
	$nameOf[[int]$r.id] = $r.name
	if (($r.PSObject.Properties.Name -contains 'swap') -and $r.swap -ne '') { $swapOf[[int]$r.id] = [int]$r.swap }
}
foreach ($k in $NPC_SWAP.Keys) { if (-not $swapOf.ContainsKey($k)) { $swapOf[$k] = $NPC_SWAP[$k] } }
Write-Host "$($ids.Count) weapon(s) to remove$(if ($swapOf.Count -ne $NPC_SWAP.Count) { " ($($swapOf.Count - $NPC_SWAP.Count) of them with a swap of their own)" })"

# The ladder has to be regenerated without them first, or generate.ps1 mints their graded copies
# again on its next run and this script's work is undone by the very next command.
$weaponsCsv = Join-Path $PSScriptRoot 'weapons.csv'
if (Test-Path $weaponsCsv)
{
	$still = @(Import-Csv $weaponsCsv | Where-Object { $ids.Contains([int]$_.id) })
	if ($still.Count)
	{
		throw "$($still.Count) retired id(s) are still in weapons.csv ($(($still | Select-Object -First 3 | ForEach-Object { $_.id }) -join ', ')...) - take them out and rerun generate.ps1 first."
	}
}

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
	if ($script:DryRun) { return }
	$text = ($lines -join "`r`n")
	if ($endsNl) { $text += "`r`n" }
	[System.IO.File]::WriteAllText($path, $text, $UTF8)
}

# ---------------------------------------------------------------------------
# The recipes go first : each one adds its recipe item to the list, and that item is then removed
# everywhere an item can be - which is why this cannot wait until after the item pass.
# ---------------------------------------------------------------------------

$recipesPath = Join-Path $xmlDir 'recipes.xml'
$src = [System.IO.File]::ReadAllLines($recipesPath)
$out = [System.Collections.Generic.List[string]]::new()
$goneRecipes = 0
$recipeItems = @()
foreach ($l in $src)
{
	$drop = $false
	if ($l -match '<recipe\b')
	{
		if ($l -match 'product="(\d+)-' -and $ids.Contains([int]$Matches[1])) { $drop = $true }
		# A recipe that eats a weapon nobody can own any more can never be crafted either.
		if (-not $drop -and $l -match 'material="([^"]+)"')
		{
			foreach ($p in ($Matches[1] -split ';'))
			{
				$v = 0
				if ([int]::TryParse(($p -split '-')[0], [ref]$v) -and $ids.Contains($v)) { $drop = $true ; break }
			}
		}
	}
	if (-not $drop) { $null = $out.Add($l) ; continue }
	if ($l -match 'itemId="(\d+)"') { $recipeItems += [int]$Matches[1] }
	$goneRecipes++
}
if ($goneRecipes) { Save-Lines $recipesPath $out (Test-EndsWithNewline $recipesPath) }
Write-Host "data\xml\recipes.xml : $goneRecipes recipe(s) removed, recipe items $($recipeItems -join ', ') go with them"
foreach ($id in $recipeItems) { $null = $ids.Add($id) }

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
# One line each : shop products and the icon table.
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
# The exchanges. An <item> that produces or eats a retired weapon goes whole ; a list left with
# nothing to trade goes with its html link, because an empty multisell window is worse than none.
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
		if (-not $DryRun) { Remove-Item $f.FullName -Force }
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
# NPC hands. An id that is gone would leave the NPC holding nothing the client can draw, so each
# one is repointed at the survivor named in $NPC_SWAP - and an id with no swap is refused rather
# than silently emptied.
# ---------------------------------------------------------------------------

$swapped = @{}
foreach ($f in Get-ChildItem $npcsDir -Filter *.xml)
{
	$src = [System.IO.File]::ReadAllLines($f.FullName)
	$out = [System.Collections.Generic.List[string]]::new()
	$hit = 0
	foreach ($l in $src)
	{
		if ($l -match '<set\s+name="([rl])Hand"\s+val="(\d+)"' -and $ids.Contains([int]$Matches[2]))
		{
			$was = [int]$Matches[2]
			if (-not $swapOf.ContainsKey($was) -or $swapOf[$was] -eq 0)
			{
				throw "an NPC in $($f.Name) holds $was ($($nameOf[$was])) and neither the list nor \$NPC_SWAP says what to put there."
			}
			$null = $out.Add(($l -replace 'val="\d+"', "val=`"$($swapOf[$was])`""))
			$swapped[$was] = 1 + $(if ($swapped.ContainsKey($was)) { $swapped[$was] } else { 0 })
			$hit++
			continue
		}
		$null = $out.Add($l)
	}
	if ($hit) { Save-Lines $f.FullName $out (Test-EndsWithNewline $f.FullName) }
}
foreach ($k in ($swapped.Keys | Sort-Object))
{
	Write-Host ("data\xml\npcs : {0,3} NPC hand(s) {1} ({2}) -> {3}" -f $swapped[$k], $k, $nameOf[$k], $swapOf[$k])
}

if ($DryRun) { Write-Host '' ; Write-Host 'dry run, nothing written' ; return }

# ---------------------------------------------------------------------------
# The CI ships build\ as it stands, so the pruned datapack has to land there too. A mirror, not a
# copy : a file the datapack dropped has to go from build\ as well, or the server keeps loading it.
# ---------------------------------------------------------------------------

if (-not $NoSync)
{
	$buildData = Join-Path $Repo 'build\gameserver\data'
	if (-not (Test-Path $buildData)) { Write-Warning "No $buildData ; skipping the build\ copy." }
	else
	{
		foreach ($rel in 'xml\buyLists.xml', 'xml\itemIcons.xml', 'xml\recipes.xml')
		{
			Copy-Item (Join-Path $dataDir $rel) (Join-Path $buildData $rel) -Force
		}
		foreach ($rel in 'xml\items', 'xml\multisell', 'xml\npcs', 'html')
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
		Write-Host 'synced items, multisell, npcs, html, buyLists.xml, itemIcons.xml and recipes.xml into build\gameserver\data'
	}
}
