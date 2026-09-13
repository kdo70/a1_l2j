<#
.SYNOPSIS
	Turns the weapons of tools\weapons\monster_only.csv into monster only kit : NPCs keep holding them,
	players have no way left to get one.

.DESCRIPTION
	remove_weapons.ps1 takes a weapon out of the game. This one keeps the item - 103 NPC hands hold
	these nine, and NPC weapons are not touched (see AGENTS.md) - and cuts every thread a PLAYER
	could reach one by :

	  data/xml/buyLists    <product> lines of every NPC shop. The GM shop (npcId="-1") is left to
	                       generate.ps1, which files these ids into the monster tab 9136.
	  data/xml/multisell   the whole <item> of any exchange that produces or eats one, and the file
	                       with its html link once nothing is left in it
	  data/xml/recipes     the <recipe> that crafts one, AND its recipe item : the item block, its
	                       icon, its shop lines (GM shop included), its exchanges and its drops
	  sql/droplist.sql     every drop and spoil row of these weapons and of those recipe items

	What stays : the <item> blocks of the weapons, their icons and every NPC hand. No quest hands
	them out - checked, the SecondClassQuest maps that mention 96 and 123 carry diamond counts.

	**droplist.sql is only the install file.** The running server reads the droplist TABLE, so the
	same rows have to go from the live database too - generated\monster_only_live.sql does that, then
	//reload drop. It also clears the learned recipes out of character_recipebook.

	Run order : take the ids out of weapons.csv, generate.ps1, then this. Refuses while any id is still
	in weapons.csv.

.PARAMETER Repo
	Repository root. Defaults to the one this script lives in.

.PARAMETER NoSync
	Leave build\ alone.

.PARAMETER DryRun
	Work out every removal and print the tally, but write nothing.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\weapons\monster_only.ps1 -DryRun
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
$multisellDir = Join-Path $xmlDir 'multisell'
$htmlDir = Join-Path $dataDir 'html'
$sqlPath = Join-Path $Repo 'source\aCis_datapack\sql\droplist.sql'
$outDir = Join-Path $PSScriptRoot 'generated'

if (-not (Test-Path $itemsDir)) { throw "No datapack at $itemsDir." }
$UTF8 = New-Object System.Text.UTF8Encoding $false

$list = @(Import-Csv (Join-Path $PSScriptRoot 'monster_only.csv'))
if ($list.Count -eq 0) { throw 'monster_only.csv is empty.' }

$weaponIds = New-Object 'System.Collections.Generic.HashSet[int]'
foreach ($r in $list) { $null = $weaponIds.Add([int]$r.id) }
Write-Host "$($weaponIds.Count) weapon(s) to make monster only"

$still = @(Import-Csv (Join-Path $PSScriptRoot 'weapons.csv') | Where-Object { $weaponIds.Contains([int]$_.id) })
if ($still.Count)
{
	throw "$($still.Count) id(s) are still in weapons.csv ($(($still | ForEach-Object { $_.id }) -join ', ')) - take them out and rerun generate.ps1 first."
}

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
# Recipes first : each one names a recipe item, and that item goes everywhere an item can.
# ---------------------------------------------------------------------------

$recipesPath = Join-Path $xmlDir 'recipes.xml'
$src = [System.IO.File]::ReadAllLines($recipesPath)
$out = [System.Collections.Generic.List[string]]::new()
$recipeIds = @()
$recipeItems = New-Object 'System.Collections.Generic.HashSet[int]'
foreach ($l in $src)
{
	if ($l -match '<recipe\b' -and $l -match 'product="(\d+)-' -and $weaponIds.Contains([int]$Matches[1]))
	{
		if ($l -match '\bitemId="(\d+)"') { $null = $recipeItems.Add([int]$Matches[1]) }
		if ($l -match '\bid="(\d+)"') { $recipeIds += [int]$Matches[1] }
		continue
	}
	$null = $out.Add($l)
}
if ($recipeIds.Count) { Save-Lines $recipesPath $out (Test-EndsWithNewline $recipesPath) }
Write-Host "data\xml\recipes.xml : $($recipeIds.Count) recipe(s) removed ($($recipeIds -join ', ')), recipe items $(@($recipeItems) -join ', ') go with them"

# Everything a player must not get : the weapons and the recipe items alike.
$gone = New-Object 'System.Collections.Generic.HashSet[int]'
foreach ($id in $weaponIds) { $null = $gone.Add($id) }
foreach ($id in $recipeItems) { $null = $gone.Add($id) }

# ---------------------------------------------------------------------------
# The recipe items themselves : the item block and the icon. The weapons keep both.
# ---------------------------------------------------------------------------

$goneItems = 0
foreach ($f in Get-ChildItem $itemsDir -Filter *.xml)
{
	$src = [System.IO.File]::ReadAllLines($f.FullName)
	$out = [System.Collections.Generic.List[string]]::new()
	$dropped = 0
	for ($i = 0; $i -lt $src.Count; $i++)
	{
		if ($src[$i] -match '^\s*<item\s+id="(\d+)"' -and $recipeItems.Contains([int]$Matches[1]))
		{
			if ($src[$i] -notmatch '</item>') { while ($i -lt $src.Count -and $src[$i] -notmatch '</item>') { $i++ } }
			$dropped++
			continue
		}
		$null = $out.Add($src[$i])
	}
	if ($dropped -eq 0) { continue }
	Save-Lines $f.FullName $out (Test-EndsWithNewline $f.FullName)
	$goneItems += $dropped
}
Write-Host "data\xml\items : $goneItems recipe item block(s) removed"

# The weapons themselves wear the monster icon from now on - that is also what generate.ps1 and the
# drop list window recognise monster kit by. The client half is monster_icons_client.ps1.
$MONSTER_ICON = 'weapon_monster_i00'
$iconsPath = Join-Path $xmlDir 'itemIcons.xml'
$src = [System.IO.File]::ReadAllLines($iconsPath)
$out = [System.Collections.Generic.List[string]]::new()
$n = 0
$relabelled = 0
foreach ($l in $src)
{
	if ($l -match '^\s*<item\s+id="(\d+)"')
	{
		$id = [int]$Matches[1]
		if ($recipeItems.Contains($id)) { $n++ ; continue }
		if ($weaponIds.Contains($id) -and $l -notmatch "icon=`"$MONSTER_ICON`"")
		{
			$l = $l -replace 'icon="[^"]*"', "icon=`"$MONSTER_ICON`""
			$relabelled++
		}
	}
	$null = $out.Add($l)
}
if ($n + $relabelled) { Save-Lines $iconsPath $out (Test-EndsWithNewline $iconsPath) }
Write-Host "data\xml\itemIcons.xml : $n recipe item icon(s) removed, $relabelled weapon(s) given $MONSTER_ICON"

# ---------------------------------------------------------------------------
# Shops. A weapon leaves every NPC shop but stays in the GM shop - generate.ps1 owns where it sits
# there. A recipe item leaves the GM shop as well : it no longer exists.
# ---------------------------------------------------------------------------

$buyPath = Join-Path $xmlDir 'buyLists.xml'
$src = [System.IO.File]::ReadAllLines($buyPath)
$out = [System.Collections.Generic.List[string]]::new()
$gm = $false
$nWeapon = 0 ; $nRecipe = 0
foreach ($l in $src)
{
	if ($l -match '^\s*<buyList\s') { $gm = ($l -match 'npcId="-1"') }
	if ($l -match '^\s*<product\s+id="(\d+)"')
	{
		$p = [int]$Matches[1]
		if ($recipeItems.Contains($p)) { $nRecipe++ ; continue }
		if ($weaponIds.Contains($p) -and -not $gm) { $nWeapon++ ; continue }
	}
	$null = $out.Add($l)
}
if ($nWeapon + $nRecipe) { Save-Lines $buyPath $out (Test-EndsWithNewline $buyPath) }
Write-Host "data\xml\buyLists.xml : $nWeapon weapon product(s) out of NPC shops, $nRecipe recipe item product(s) out of all shops"

# ---------------------------------------------------------------------------
# Exchanges.
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
			if ($src[$j] -match '<(?:production|ingredient)\s+id="(\d+)"' -and $gone.Contains([int]$Matches[1])) { $hit = $true ; break }
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
		$emptied += $f.BaseName
		Write-Host "data\xml\multisell\$($f.Name) : $dropped entries removed, nothing left - file dropped"
		continue
	}
	Save-Lines $f.FullName $out (Test-EndsWithNewline $f.FullName)
	Write-Host "data\xml\multisell\$($f.Name) : $dropped entries removed, $left left"
}

foreach ($ms in $emptied)
{
	foreach ($h in Get-ChildItem $htmlDir -Recurse -File)
	{
		$src = [System.IO.File]::ReadAllLines($h.FullName)
		$out = [System.Collections.Generic.List[string]]::new()
		$dropped = 0
		foreach ($l in $src) { if ($l -match "multisell\s+0*$([int]$ms)`"") { $dropped++ ; continue } ; $null = $out.Add($l) }
		if ($dropped -eq 0) { continue }
		Save-Lines $h.FullName $out (Test-EndsWithNewline $h.FullName)
		Write-Host "$($h.FullName.Substring($Repo.Length + 1)) : $dropped link(s) to multisell $ms removed"
	}
}

# ---------------------------------------------------------------------------
# The drop list. One row per line, inside multi-row INSERTs : a statement's last row ends in ");".
# When that row goes, the row kept before it takes the ";" ; when a whole statement empties, its
# INSERT header goes too.
# ---------------------------------------------------------------------------

$src = [System.IO.File]::ReadAllLines($sqlPath)
$out = [System.Collections.Generic.List[string]]::new()
$goneRows = 0
$insertAt = -1        # index in $out of the current INSERT line, -1 outside a statement
$kept = 0             # rows kept under it
for ($i = 0; $i -lt $src.Count; $i++)
{
	$l = $src[$i]
	if ($l -match '^INSERT\b')
	{
		$insertAt = $out.Count
		$null = $out.Add($l)
		# The column list runs onto a second line ; everything up to VALUES is the header.
		while ($src[$i] -notmatch '\bVALUES\s*$') { $i++ ; $null = $out.Add($src[$i]) }
		$kept = 0
		continue
	}
	if ($insertAt -ge 0 -and $l -match '^\((\d+),\s*(\d+),\s*(\d+),\s*''(\w+)'',\s*([\d.]+),\s*(\d+),')
	{
		# Read before the next -match : it would overwrite $Matches.
		$item = [int]$Matches[6]
		$last = ($l -match '\);\s*$')
		if ($gone.Contains($item))
		{
			$goneRows++
			if ($last)
			{
				if ($kept -gt 0) { $out[$out.Count - 1] = ($out[$out.Count - 1] -replace '\),\s*$', ');') }
				else { $out.RemoveRange($insertAt, $out.Count - $insertAt) }
				$insertAt = -1
			}
			continue
		}
		$null = $out.Add($l)
		$kept++
		if ($last) { $insertAt = -1 }
		continue
	}
	$null = $out.Add($l)
}
if ($goneRows) { Save-Lines $sqlPath $out (Test-EndsWithNewline $sqlPath) }
Write-Host "sql\droplist.sql : $goneRows drop/spoil row(s) removed"

# The live database is what the server reads ; this is the same removal for it. Cumulative : a
# recipe this run no longer finds was removed by an earlier one, and the database may not have been
# told yet, so whatever the file already names stays in it.
$livePath = Join-Path $outDir 'monster_only_live.sql'
$allItems = New-Object 'System.Collections.Generic.HashSet[int]'
$allRecipes = New-Object 'System.Collections.Generic.HashSet[int]'
foreach ($id in $gone) { $null = $allItems.Add($id) }
foreach ($id in $recipeIds) { $null = $allRecipes.Add($id) }
if (Test-Path $livePath)
{
	foreach ($l in [System.IO.File]::ReadAllLines($livePath))
	{
		$into = $null
		if ($l -match '^DELETE FROM droplist WHERE item_id IN \(([\d,]*)\)') { $into = $allItems }
		elseif ($l -match '^DELETE FROM character_recipebook WHERE recipeId IN \(([\d,]*)\)') { $into = $allRecipes }
		if ($null -eq $into) { continue }
		foreach ($v in ($Matches[1] -split ',')) { if ($v -ne '') { $null = $into.Add([int]$v) } }
	}
}
$live = @(
	'-- monster only weapons : tools/weapons/monster_only.ps1, see tools/weapons/monster_only.csv'
	"DELETE FROM droplist WHERE item_id IN ($((@($allItems) | Sort-Object) -join ','));"
	"DELETE FROM character_recipebook WHERE recipeId IN ($((@($allRecipes) | Sort-Object) -join ','));"
	'-- then in game : //reload drop'
)
if (-not $DryRun)
{
	$null = New-Item -ItemType Directory -Force -Path $outDir
	[System.IO.File]::WriteAllText((Join-Path $outDir 'monster_only_live.sql'), (($live -join "`n") + "`n"), $UTF8)
	Write-Host "wrote generated\monster_only_live.sql"
}

if ($DryRun) { Write-Host '' ; Write-Host 'dry run, nothing written' ; return }

# ---------------------------------------------------------------------------
# build\ is what the CI ships.
# ---------------------------------------------------------------------------

if (-not $NoSync)
{
	$buildData = Join-Path $Repo 'build\gameserver\data'
	foreach ($rel in 'xml\buyLists.xml', 'xml\itemIcons.xml', 'xml\recipes.xml')
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
	Copy-Item $sqlPath (Join-Path $Repo 'build\sql\droplist.sql') -Force
	Write-Host 'synced items, multisell, html, buyLists.xml, itemIcons.xml, recipes.xml and sql\droplist.sql into build\'
}
