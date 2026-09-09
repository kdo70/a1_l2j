<#
.SYNOPSIS
	Puts weapons that remove_weapons.ps1 took out back into the datapack, out of a pristine copy of it.

.DESCRIPTION
	remove_weapons.ps1 is one way : it deletes item blocks, icon rows, shop products, recipes and
	multisell entries, and repoints the hands of every NPC that held one. This is the way back for a
	subset of that list - the twelve weapons NPCs actually carry, whose hands had to hold the retail
	item again :

	    67  Orcish Sword      86  Tomahawk        153 Sickle
	    73  Shamshir          96  Scythe          223 Kukuri
	    74  Katana            123 Saber           228 Crystal Dagger
	    76  Sword of Delusion 127 Crimson Sword   298 Orcish Glaive

	Nothing is invented : every line comes from -From, a copy of the datapack taken before the removal
	(`git archive HEAD` into a scratch directory does nicely). What comes back :

	  data/xml/items       the <item> block, slotted back in id order
	  data/xml/recipes     the <recipe> that produces one - and its recipe item, which is restored as
	                       an item too. A recipe whose materials are not all back is left out.
	  data/xml/itemIcons   the icon row the drop list window reads
	  data/xml/buyLists    the <product> lines, back into the very lists they came from
	  data/xml/multisell   an <item> exchange comes back only if EVERY id it names exists again, so a
	                       dual sword craft whose dual is still retired stays out
	  data/xml/npcs        every hand that used to hold one of these ids holds it again

	The client half is restore_weapons_client.ps1.

	Idempotent : anything already present is skipped, so a second run writes nothing.

.PARAMETER Repo
	Repository root. Defaults to the one this script lives in.

.PARAMETER From
	A copy of `source\aCis_datapack\data` taken before the removal - the source of every restored line.

.PARAMETER Ids
	Comma separated item ids to restore. Defaults to the twelve NPC weapons above.

.PARAMETER NoSync
	Leave build\gameserver\data alone. Without it the datapack is copied there too, as the CI deploys
	that folder as is.

.PARAMETER DryRun
	Work out every restore and print the tally, but write nothing.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\weapons\restore_weapons.ps1 -From C:\tmp\head\source\aCis_datapack\data
#>
param(
	[string]$Repo = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
	[string]$From = '',
	[string]$Ids = '67,73,74,76,86,96,123,127,153,223,228,298',
	[switch]$NoSync,
	[switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# Not [Parameter(Mandatory)] : one attribute anywhere in param() makes this an advanced script, and
# then the defaults are bound before $PSScriptRoot exists, which takes -Repo's default down with it.
if ($From -eq '') { throw 'Give -From : a copy of source\aCis_datapack\data taken before the removal.' }

$dataDir = Join-Path $Repo 'source\aCis_datapack\data'
$xmlDir = Join-Path $dataDir 'xml'
$itemsDir = Join-Path $xmlDir 'items'
$multisellDir = Join-Path $xmlDir 'multisell'
$npcsDir = Join-Path $xmlDir 'npcs'

$fromXml = Join-Path $From 'xml'
$fromItems = Join-Path $fromXml 'items'
$fromNpcs = Join-Path $fromXml 'npcs'
$fromMultisell = Join-Path $fromXml 'multisell'

if (-not (Test-Path $itemsDir)) { throw "No datapack at $itemsDir." }
if (-not (Test-Path $fromItems)) { throw "No pristine datapack at $fromItems." }

$UTF8 = New-Object System.Text.UTF8Encoding $false

$idSet = New-Object 'System.Collections.Generic.HashSet[int]'
foreach ($p in ($Ids -split ',')) { if ($p.Trim() -ne '') { $null = $idSet.Add([int]$p.Trim()) } }
if ($idSet.Count -eq 0) { throw 'No ids given.' }
Write-Host "$($idSet.Count) weapon(s) to restore"

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
	if ($DryRun) { return }
	$text = ($lines -join "`r`n")
	if ($endsNl) { $text += "`r`n" }
	[System.IO.File]::WriteAllText($path, $text, $UTF8)
}

# Every <item id="..."> ... </item> of a directory, keyed by id.
function Read-ItemBlocks([string]$dir)
{
	$blocks = @{}
	foreach ($f in Get-ChildItem $dir -Filter *.xml)
	{
		$src = [System.IO.File]::ReadAllLines($f.FullName)
		for ($i = 0; $i -lt $src.Count; $i++)
		{
			if ($src[$i] -notmatch '^\s*<item\s+id="(\d+)"') { continue }
			$id = [int]$Matches[1]
			$end = $i
			while ($end -lt $src.Count -and $src[$end] -notmatch '</item>') { $end++ }
			$blocks[$id] = @{ file = $f.Name; lines = @($src[$i..$end]) }
			$i = $end
		}
	}
	$blocks
}

$fromBlocks = Read-ItemBlocks $fromItems
$haveBlocks = Read-ItemBlocks $itemsDir

# ---------------------------------------------------------------------------
# The recipes first, the way remove_weapons.ps1 removed them first : a restored recipe drags its
# recipe item back with it, and that item then has to travel through the item pass like any other.
# ---------------------------------------------------------------------------

$recipesPath = Join-Path $xmlDir 'recipes.xml'
$fromRecipes = Join-Path $fromXml 'recipes.xml'
$restoredRecipes = 0
$recipeItems = @()

if (Test-Path $fromRecipes)
{
	$cur = [System.Collections.Generic.List[string]]::new()
	foreach ($l in [System.IO.File]::ReadAllLines($recipesPath)) { $null = $cur.Add($l) }

	$present = @{}
	foreach ($l in $cur) { if ($l -match 'product="(\d+)-') { $present[[int]$Matches[1]] = $true } }

	$wanted = @()
	foreach ($l in [System.IO.File]::ReadAllLines($fromRecipes))
	{
		if ($l -notmatch '<recipe\b') { continue }
		if ($l -notmatch 'product="(\d+)-') { continue }
		$product = [int]$Matches[1]
		if (-not $idSet.Contains($product) -or $present.ContainsKey($product)) { continue }

		# A recipe is only worth restoring if everything it eats is still in the game.
		$ok = $true
		if ($l -match 'material="([^"]+)"')
		{
			foreach ($m in ($Matches[1] -split ';'))
			{
				$v = 0
				if (-not [int]::TryParse(($m -split '-')[0], [ref]$v)) { continue }
				if (-not $haveBlocks.ContainsKey($v) -and -not $idSet.Contains($v)) { $ok = $false ; break }
			}
		}
		if (-not $ok) { Write-Host "  recipe of $product left out : a material of it is still gone" ; continue }

		$wanted += $l
		if ($l -match 'itemId="(\d+)"') { $recipeItems += [int]$Matches[1] }
	}

	if ($wanted.Count -gt 0)
	{
		$at = -1
		for ($i = $cur.Count - 1; $i -ge 0; $i--) { if ($cur[$i] -match '</list>') { $at = $i ; break } }
		if ($at -lt 0) { throw 'recipes.xml has no </list>.' }
		$cur.InsertRange($at, [string[]]$wanted)
		Save-Lines $recipesPath $cur (Test-EndsWithNewline $recipesPath)
		$restoredRecipes = $wanted.Count
	}
}
foreach ($id in $recipeItems) { $null = $idSet.Add($id) }
Write-Host "data\xml\recipes.xml : $restoredRecipes recipe(s) restored$(if ($recipeItems.Count) { ", recipe items $($recipeItems -join ', ') come back with them" })"

# ---------------------------------------------------------------------------
# The items themselves, slotted back into the bucket they came from, in id order.
# ---------------------------------------------------------------------------

$perFile = @{}
foreach ($id in ($idSet | Sort-Object))
{
	if ($haveBlocks.ContainsKey($id)) { continue }
	if (-not $fromBlocks.ContainsKey($id)) { throw "item $id is not in $fromItems either." }
	$b = $fromBlocks[$id]
	if (-not $perFile.ContainsKey($b.file)) { $perFile[$b.file] = @() }
	$perFile[$b.file] += $id
}

$restoredItems = 0
foreach ($name in ($perFile.Keys | Sort-Object))
{
	$path = Join-Path $itemsDir $name
	if (-not (Test-Path $path)) { throw "$path is gone ; the bucket has to exist to slot an item back into it." }
	$cur = [System.Collections.Generic.List[string]]::new()
	foreach ($l in [System.IO.File]::ReadAllLines($path)) { $null = $cur.Add($l) }

	foreach ($id in ($perFile[$name] | Sort-Object -Descending))
	{
		# Before the first item of a higher id, or before </list> when it is the highest.
		$at = -1
		for ($i = 0; $i -lt $cur.Count; $i++)
		{
			if ($cur[$i] -match '^\s*<item\s+id="(\d+)"' -and [int]$Matches[1] -gt $id) { $at = $i ; break }
		}
		if ($at -lt 0) { for ($i = $cur.Count - 1; $i -ge 0; $i--) { if ($cur[$i] -match '</list>') { $at = $i ; break } } }
		if ($at -lt 0) { throw "$name has neither a later item nor a </list>." }
		$cur.InsertRange($at, [string[]]$fromBlocks[$id].lines)
		$restoredItems++
	}
	Save-Lines $path $cur (Test-EndsWithNewline $path)
	Write-Host "data\xml\items\$name : $($perFile[$name].Count) item block(s) restored"
}
Write-Host "data\xml\items : $restoredItems item block(s) restored"

# What exists once the items are back - the multisell pass needs it.
$exists = New-Object 'System.Collections.Generic.HashSet[int]'
foreach ($k in $haveBlocks.Keys) { $null = $exists.Add([int]$k) }
foreach ($id in $idSet) { $null = $exists.Add([int]$id) }

# ---------------------------------------------------------------------------
# One line each : the icon table and the shop products.
# ---------------------------------------------------------------------------

# Lines of $fromPath matching $pattern whose id is ours and which the current file has not got,
# put back in id order.
function Restore-Lines([string]$path, [string]$fromPath, [string]$pattern)
{
	if (-not (Test-Path $fromPath)) { return 0 }
	$cur = [System.Collections.Generic.List[string]]::new()
	foreach ($l in [System.IO.File]::ReadAllLines($path)) { $null = $cur.Add($l) }

	$present = @{}
	foreach ($l in $cur) { if ($l -match $pattern) { $present[[int]$Matches[1]] = $true } }

	$want = @()
	foreach ($l in [System.IO.File]::ReadAllLines($fromPath))
	{
		if ($l -notmatch $pattern) { continue }
		$id = [int]$Matches[1]
		if (-not $idSet.Contains($id) -or $present.ContainsKey($id)) { continue }
		$want += @{ id = $id; line = $l }
	}
	if ($want.Count -eq 0) { return 0 }

	foreach ($w in ($want | Sort-Object { -$_.id }))
	{
		$at = -1
		for ($i = 0; $i -lt $cur.Count; $i++)
		{
			if ($cur[$i] -match $pattern -and [int]$Matches[1] -gt $w.id) { $at = $i ; break }
		}
		if ($at -lt 0) { for ($i = $cur.Count - 1; $i -ge 0; $i--) { if ($cur[$i] -match '</list>') { $at = $i ; break } } }
		if ($at -lt 0) { $at = $cur.Count }
		$cur.Insert($at, $w.line)
	}
	Save-Lines $path $cur (Test-EndsWithNewline $path)
	$want.Count
}

$n = Restore-Lines (Join-Path $xmlDir 'itemIcons.xml') (Join-Path $fromXml 'itemIcons.xml') '^\s*<item\s+id="(\d+)"'
Write-Host "data\xml\itemIcons.xml : $n icon(s) restored"

# buyLists is not a flat list : a product belongs to the <buyList> it was written in, so each one
# goes back into that very list rather than wherever the id order would put it.
$buyPath = Join-Path $xmlDir 'buyLists.xml'
$fromBuy = Join-Path $fromXml 'buyLists.xml'
$restoredProducts = 0
if (Test-Path $fromBuy)
{
	$cur = [System.Collections.Generic.List[string]]::new()
	foreach ($l in [System.IO.File]::ReadAllLines($buyPath)) { $null = $cur.Add($l) }

	# list id -> products it wants back, in the order the pristine file had them
	$wantPerList = @{}
	$list = 0
	foreach ($l in [System.IO.File]::ReadAllLines($fromBuy))
	{
		if ($l -match '^\s*<buyList\s+id="(\d+)"') { $list = [int]$Matches[1] ; continue }
		if ($l -match '^\s*<product\s+id="(\d+)"' -and $idSet.Contains([int]$Matches[1]))
		{
			if (-not $wantPerList.ContainsKey($list)) { $wantPerList[$list] = @() }
			$wantPerList[$list] += @{ id = [int]$Matches[1]; line = $l }
		}
	}

	# Walk the current file once, dropping each list's wanted products in just before its close.
	$out = [System.Collections.Generic.List[string]]::new()
	$list = 0
	foreach ($l in $cur)
	{
		if ($l -match '^\s*<buyList\s+id="(\d+)"')
		{
			$list = [int]$Matches[1]
			# A one liner <buyList ...></buyList> has to be opened up before anything fits inside.
			if ($l -match '></buyList>\s*$' -and $wantPerList.ContainsKey($list))
			{
				$null = $out.Add(($l -replace '></buyList>\s*$', '>'))
				foreach ($w in $wantPerList[$list]) { $null = $out.Add($w.line) ; $restoredProducts++ }
				$null = $out.Add("`t</buyList>")
				$wantPerList.Remove($list)
				continue
			}
		}
		if ($l -match '</buyList>' -and $wantPerList.ContainsKey($list))
		{
			$have = @{}
			for ($i = $out.Count - 1; $i -ge 0; $i--)
			{
				if ($out[$i] -match '^\s*<buyList\b') { break }
				if ($out[$i] -match '^\s*<product\s+id="(\d+)"') { $have[[int]$Matches[1]] = $true }
			}
			foreach ($w in $wantPerList[$list])
			{
				if ($have.ContainsKey($w.id)) { continue }
				$null = $out.Add($w.line)
				$restoredProducts++
			}
			$wantPerList.Remove($list)
		}
		$null = $out.Add($l)
	}
	if ($restoredProducts -gt 0) { Save-Lines $buyPath $out (Test-EndsWithNewline $buyPath) }
	if ($wantPerList.Count -gt 0) { Write-Warning "buyLists.xml has no list $(($wantPerList.Keys | Sort-Object) -join ', ') any more ; $((($wantPerList.Values | ForEach-Object { $_.Count }) | Measure-Object -Sum).Sum) product(s) not restored" }
}
Write-Host "data\xml\buyLists.xml : $restoredProducts product(s) restored"

# ---------------------------------------------------------------------------
# The exchanges. An entry comes back whole or not at all, and only when every id it names is in the
# game again - a dual sword craft whose dual is still retired would be a trade to nowhere.
# ---------------------------------------------------------------------------

$restoredEntries = 0
foreach ($f in Get-ChildItem $fromMultisell -Filter *.xml)
{
	$path = Join-Path $multisellDir $f.Name
	if (-not (Test-Path $path)) { continue }   # the whole list was dropped ; not ours to bring back

	$src = [System.IO.File]::ReadAllLines($f.FullName)
	$cur = [System.Collections.Generic.List[string]]::new()
	foreach ($l in [System.IO.File]::ReadAllLines($path)) { $null = $cur.Add($l) }

	# Signature of every entry the current file already holds, so a rerun adds nothing.
	$have = @{}
	for ($i = 0; $i -lt $cur.Count; $i++)
	{
		if ($cur[$i] -notmatch '^\s*<item>\s*$') { continue }
		$end = $i
		while ($end -lt $cur.Count -and $cur[$end] -notmatch '^\s*</item>\s*$') { $end++ }
		$have[(($cur[$i..$end] | ForEach-Object { $_.Trim() }) -join '|')] = $true
		$i = $end
	}

	$want = @()
	for ($i = 0; $i -lt $src.Count; $i++)
	{
		if ($src[$i] -notmatch '^\s*<item>\s*$') { continue }
		$end = $i
		while ($end -lt $src.Count -and $src[$end] -notmatch '^\s*</item>\s*$') { $end++ }
		$block = @($src[$i..$end])
		$i = $end

		$sig = (($block | ForEach-Object { $_.Trim() }) -join '|')
		if ($have.ContainsKey($sig)) { continue }

		$mine = $false
		$whole = $true
		foreach ($l in $block)
		{
			if ($l -notmatch '<(?:production|ingredient)\s+id="(\d+)"') { continue }
			$id = [int]$Matches[1]
			if ($idSet.Contains($id)) { $mine = $true }
			# Adena and the like are not items of data\xml\items ; only ids that USED to be there and
			# are not any more may block a restore, and those are exactly the ones we know about.
			elseif ($fromBlocks.ContainsKey($id) -and -not $exists.Contains($id)) { $whole = $false }
		}
		if ($mine -and $whole) { $want += , $block }
	}

	if ($want.Count -eq 0) { continue }

	$at = -1
	for ($i = $cur.Count - 1; $i -ge 0; $i--) { if ($cur[$i] -match '</list>') { $at = $i ; break } }
	if ($at -lt 0) { throw "$($f.Name) has no </list>." }
	$flat = @()
	foreach ($b in $want) { $flat += $b }
	$cur.InsertRange($at, [string[]]$flat)
	Save-Lines $path $cur (Test-EndsWithNewline $path)
	$restoredEntries += $want.Count
	Write-Host "data\xml\multisell\$($f.Name) : $($want.Count) entr(y/ies) restored"
}
Write-Host "data\xml\multisell : $restoredEntries entr(y/ies) restored"

# ---------------------------------------------------------------------------
# NPC hands. The pristine datapack says what each NPC held ; wherever that was one of our ids, it
# holds it again. Every other hand is left exactly as it is.
# ---------------------------------------------------------------------------

$back = @{}
foreach ($f in Get-ChildItem $npcsDir -Filter *.xml)
{
	$fromPath = Join-Path $fromNpcs $f.Name
	if (-not (Test-Path $fromPath)) { continue }

	# npc id -> what its two hands used to hold
	$was = @{}
	$npc = 0
	foreach ($l in [System.IO.File]::ReadAllLines($fromPath))
	{
		if ($l -match '<npc\s+id="(\d+)"') { $npc = [int]$Matches[1] ; continue }
		if ($l -match '<set\s+name="([rl])Hand"\s+val="(\d+)"')
		{
			if (-not $was.ContainsKey($npc)) { $was[$npc] = @{} }
			$was[$npc][$Matches[1]] = [int]$Matches[2]
		}
	}

	$src = [System.IO.File]::ReadAllLines($f.FullName)
	$out = [System.Collections.Generic.List[string]]::new()
	$hit = 0
	$npc = 0
	foreach ($l in $src)
	{
		if ($l -match '<npc\s+id="(\d+)"') { $npc = [int]$Matches[1] }
		if ($l -match '<set\s+name="([rl])Hand"\s+val="(\d+)"')
		{
			$hand = $Matches[1]
			$now = [int]$Matches[2]
			if ($was.ContainsKey($npc) -and $was[$npc].ContainsKey($hand))
			{
				$orig = $was[$npc][$hand]
				if ($idSet.Contains($orig) -and $now -ne $orig)
				{
					$null = $out.Add(($l -replace 'val="\d+"', "val=`"$orig`""))
					$back[$orig] = 1 + $(if ($back.ContainsKey($orig)) { $back[$orig] } else { 0 })
					$hit++
					continue
				}
			}
		}
		$null = $out.Add($l)
	}
	if ($hit) { Save-Lines $f.FullName $out (Test-EndsWithNewline $f.FullName) }
}
foreach ($k in ($back.Keys | Sort-Object))
{
	Write-Host ("data\xml\npcs : {0,3} NPC hand(s) back to {1}" -f $back[$k], $k)
}
Write-Host ("data\xml\npcs : {0} hand(s) restored in total" -f (($back.Values | Measure-Object -Sum).Sum))

if ($DryRun) { Write-Host '' ; Write-Host 'dry run, nothing written' ; return }

# ---------------------------------------------------------------------------
# The CI ships build\ as it stands, so the datapack has to land there too.
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
		foreach ($rel in 'xml\items', 'xml\multisell', 'xml\npcs')
		{
			$from2 = Join-Path $dataDir $rel
			$to = Join-Path $buildData $rel
			$have = @{}
			foreach ($f in Get-ChildItem $from2 -Recurse -File)
			{
				$sub = $f.FullName.Substring($from2.Length + 1)
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
		Write-Host 'synced items, multisell, npcs, buyLists.xml, itemIcons.xml and recipes.xml into build\gameserver\data'
	}
}
