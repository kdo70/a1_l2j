<#
.SYNOPSIS
	Gives every weapon of the datapack a ladder up to S grade, out of tools/weapons/weapons.csv.

.DESCRIPTION
	A weapon keeps the grade it always had and gains one copy per grade above it, up to S - the same
	ladder the armor sets got (see docs/armor-sets-all-grades.md) :

	    a No Grade weapon exists as  NG D C B A S
	    a D grade weapon as             D C B A S
	    a C grade weapon as               C B A S
	    ... and an S grade weapon is left exactly as it is.

	So Katana, a C grade sword, gains a B, an A and an S version ; Arcana Mace, already S, gains nothing.

	**No existing item is touched.** The rung of a weapon's own grade is the retail item itself, with the
	numbers it always had ; only the rungs above it are minted. That is the one place this differs from
	the armor generator, which levelled the P. Def. of the 79 chests it owned : a weapon carries far more
	of its identity in its numbers, and every weapon of the datapack would have had to be rewritten.

	A minted copy carries the top of its grade for its weapon class, so that upgrading is worth it whatever
	the weapon started as - a Short Sword taken to S hits like any other S grade sword, exactly the way a
	No Grade armor set taken to S defends like any other S grade set.

	The ladder is only the items : upgrading one grade into the next is somebody else's feature, and the
	ids it needs are laid out in generated\upgrade_chain.tsv.

	Nothing is granted to anybody : no drop, no shop and no multisell is touched, the new items only exist.
	The one exception is the admin shop (//gmshop -> Weapons -> <grade>), which is refilled, because that
	is where the armor ladder is handed out too.

	The client knows none of the new ids, so patch_client.ps1 has to be run afterwards against a client
	system directory - it feeds on generated\client_items.tsv. See docs/weapon-grades.md.

.PARAMETER Repo
	Repository root. Defaults to the one this script lives in.

.PARAMETER NoSync
	Leave build\gameserver\data alone. Without it the generated datapack is copied there too, as the CI
	deploys that folder as is.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\weapons\generate.ps1
#>
param(
	[string]$Repo = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
	[switch]$NoSync
)

$ErrorActionPreference = 'Stop'

$dataDir = Join-Path $Repo 'source\aCis_datapack\data\xml'
$itemsDir = Join-Path $dataDir 'items'
$outDir = Join-Path $PSScriptRoot 'generated'

if (-not (Test-Path $itemsDir)) { throw "No datapack at $itemsDir." }
$null = New-Item -ItemType Directory -Force -Path $outDir

# ---------------------------------------------------------------------------
# Grades, and where the minted ids start. The armor ladder owns 10000..11409, so weapons start well
# clear of it and of any room armor may still grow into.
# ---------------------------------------------------------------------------

$GRADES = @('NG', 'D', 'C', 'B', 'A', 'S')
$GRADE_IDX = @{ NG = 0; D = 1; C = 2; B = 3; A = 4; S = 5 }
$TOP_GRADE = 5
$FIRST_ITEM_ID = 12000
$ITEMS_PER_FILE = 100

# P. Atk. and M. Atk. of the best retail weapon of each class at each grade. A minted copy gets these
# whatever it was cloned from - that is what makes the ladder worth walking.
#
# The rows are the retail tiers : one handed melee and polearms share one, two handed melee another,
# daggers sit under both, bows have their own, and the mystic weapons (magic swords, maces, mystic
# daggers, spellbooks and dolls) split into one handed and staves.
$MELEE_1H = @{ pAtk = @{ NG = 31; D = 92; C = 156; B = 194; A = 258; S = 297 }; mAtk = @{ NG = 21; D = 54; C = 83; B = 99; A = 121; S = 137 } }
$MELEE_2H = @{ pAtk = @{ NG = 38; D = 112; C = 190; B = 236; A = 305; S = 361 }; mAtk = @{ NG = 21; D = 54; C = 83; B = 99; A = 121; S = 137 } }
$DAGGER   = @{ pAtk = @{ NG = 27; D = 80; C = 136; B = 170; A = 220; S = 260 }; mAtk = @{ NG = 21; D = 54; C = 83; B = 99; A = 121; S = 137 } }
$BOW      = @{ pAtk = @{ NG = 120; D = 191; C = 323; B = 400; A = 570; S = 614 }; mAtk = @{ NG = 21; D = 54; C = 84; B = 100; A = 133; S = 137 } }
$MYSTIC_1H = @{ pAtk = @{ NG = 25; D = 74; C = 125; B = 155; A = 202; S = 238 }; mAtk = @{ NG = 28; D = 72; C = 111; B = 132; A = 161; S = 182 } }
$MYSTIC_2H = @{ pAtk = @{ NG = 30; D = 90; C = 152; B = 189; A = 245; S = 290 }; mAtk = @{ NG = 28; D = 72; C = 111; B = 132; A = 161; S = 182 } }

$STATS = @{
	SWORD_P    = $MELEE_1H
	BLUNT_P    = $MELEE_1H
	POLE       = $MELEE_1H
	BIGSWORD   = $MELEE_2H
	BIGBLUNT_P = $MELEE_2H
	DUAL       = $MELEE_2H
	DUALFIST   = $MELEE_2H
	DAGGER_P   = $DAGGER
	BOW        = $BOW
	SWORD_M    = $MYSTIC_1H
	BLUNT_M    = $MYSTIC_1H
	DAGGER_M   = $MYSTIC_1H
	ETC_M      = $MYSTIC_1H
	BIGBLUNT_M = $MYSTIC_2H
}

# Crystals given back on crystallization and shop price - the top of each grade, one row for every
# weapon. No Grade weapons crystallize into nothing.
$CRYSTALS = @{ NG = 0; D = 3272; C = 2452; B = 1746; A = 2824; S = 2440 }
$PRICES = @{ NG = 244000; D = 1800000; C = 6130000; B = 13100000; A = 35300000; S = 48800000 }

# Shots. Interlude changes the system at B grade : below it a weapon eats several shots of its own
# grade, from B up exactly one. Bows eat more, and carry an MP cost on top.
$SHOTS = @{ NG = 2; D = 2; C = 3; B = 1; A = 1; S = 1 }
$BOW_SHOTS = @{ NG = 6; D = 6; C = 8; B = 3; A = 2; S = 1 }
$BOW_SPIRITSHOTS = @{ NG = 2; D = 2; C = 2; B = 1; A = 1; S = 1 }
$BOW_MP = @{ NG = 2; D = 4; C = 7; B = 8; A = 10; S = 11 }

# Where a class is handed out in //gmshop -> Weapons -> <grade>.
$CATEGORY = @{
	SWORD_P = 'sword1h'; SWORD_M = 'sword1h'
	BIGSWORD = 'sword2h'
	DUAL = 'dual'
	DAGGER_P = 'dagger'; DAGGER_M = 'dagger'
	BOW = 'bow'
	DUALFIST = 'fist'
	POLE = 'pole'
	BLUNT_P = 'blunt1h'; BLUNT_M = 'blunt1h'
	BIGBLUNT_P = 'blunt2h'; BIGBLUNT_M = 'blunt2h'
	ETC_M = 'mystic'
}

# One buy list per category and grade. 9001..9053 are the stock admin shop lists ; No Grade had no
# dual list and mystic weapons had no list at all, so those seven are ours (9105..9111) and are
# created on the first run.
$BUYLISTS = @{
	sword1h = @{ NG = 9001; D = 9009; C = 9018; B = 9027; A = 9036; S = 9045 }
	sword2h = @{ NG = 9002; D = 9010; C = 9019; B = 9028; A = 9037; S = 9046 }
	dual    = @{ NG = 9105; D = 9011; C = 9020; B = 9029; A = 9038; S = 9047 }
	dagger  = @{ NG = 9003; D = 9012; C = 9021; B = 9030; A = 9039; S = 9048 }
	bow     = @{ NG = 9004; D = 9013; C = 9022; B = 9031; A = 9040; S = 9049 }
	fist    = @{ NG = 9005; D = 9014; C = 9023; B = 9032; A = 9041; S = 9050 }
	pole    = @{ NG = 9006; D = 9015; C = 9024; B = 9033; A = 9042; S = 9051 }
	blunt1h = @{ NG = 9007; D = 9016; C = 9025; B = 9034; A = 9043; S = 9052 }
	blunt2h = @{ NG = 9008; D = 9017; C = 9026; B = 9035; A = 9044; S = 9053 }
	mystic  = @{ NG = 9106; D = 9107; C = 9108; B = 9109; A = 9110; S = 9111 }
}

# The enchant glow package groups weapons by shape, not by class - see docs/enchant-glow.md. The
# suffix travels to the client in client_items.tsv, so patch_client.ps1 can write it into weapongrp.
$GLOW_TYPE = @{
	DUALFIST = '001t'
	DAGGER_P = '002t'; DAGGER_M = '002t'; POLE = '002t'
	SWORD_P = '004t'; BIGSWORD = '004t'
	BIGBLUNT_P = '005t'; BIGBLUNT_M = '005t'
	DUAL = '006t'
	BLUNT_P = '007t'; BLUNT_M = '007t'; SWORD_M = '007t'; ETC_M = '007t'
	BOW = '008t'
}

# <set> lines a copy never inherits : the first six are rewritten per grade, and the rest would carry a
# donor's quest strings over to a copy that has no quest behind it.
$DROPPED_SETS = @('crystal_type', 'crystal_count', 'price', 'soulshots', 'spiritshots', 'mp_consume',
	'equip_condition', 'is_tradable', 'is_dropable', 'is_sellable', 'is_depositable', 'is_destroyable')

# ---------------------------------------------------------------------------
# The item files, as lines, plus an index of where each item block sits.
# ---------------------------------------------------------------------------

function Test-EndsWithNewline([string]$path)
{
	if (-not (Test-Path $path)) { return $false }
	$fs = [System.IO.File]::OpenRead($path)
	try
	{
		if ($fs.Length -eq 0) { return $false }
		$null = $fs.Seek(-1, [System.IO.SeekOrigin]::End)
		return ($fs.ReadByte() -eq 10)
	}
	finally { $fs.Dispose() }
}

function Write-Datapack([string]$path, [string[]]$body, [bool]$endsNl)
{
	$text = ($body -join "`r`n")
	if ($endsNl) { $text += "`r`n" }
	[System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding $false))
}

# A table that shrank leaves its top buckets behind, and the server would happily go on loading the
# orphans out of them. Every "<from>-<to>.xml" of our own id range that this run didn't write goes.
function Remove-StaleBuckets([string]$dir, [int]$firstId, [int]$lastId, $written)
{
	$dropped = 0
	foreach ($f in Get-ChildItem $dir -Filter *.xml)
	{
		if ($f.Name -notmatch '^(\d+)-(\d+)\.xml$') { continue }
		if ([int]$Matches[1] -lt $firstId -or [int]$Matches[2] -gt $lastId -or $written.ContainsKey($f.Name)) { continue }
		Remove-Item $f.FullName -Force
		$dropped++
	}
	$dropped
}

$files = @{}
$index = @{}
foreach ($f in Get-ChildItem $itemsDir -Filter *.xml)
{
	$lines = [System.IO.File]::ReadAllLines($f.FullName)
	$files[$f.Name] = $lines

	for ($i = 0; $i -lt $lines.Count; $i++)
	{
		if ($lines[$i] -match '^\s*<item\s+id="(\d+)"')
		{
			$id = [int]$Matches[1]
			$end = $i
			while ($end -lt $lines.Count -and $lines[$end] -notmatch '</item>') { $end++ }
			$index[$id] = @{ file = $f.Name; start = $i; end = $end }
		}
	}
}

function Get-ItemBlock([int]$id)
{
	if (-not $index.ContainsKey($id)) { throw "item $id is not in the datapack" }
	$e = $index[$id]
	, @($files[$e.file][$e.start..$e.end])
}

# ---------------------------------------------------------------------------
# The weapons, and the rungs each of them reaches.
# ---------------------------------------------------------------------------

$weapons = @(Import-Csv (Join-Path $PSScriptRoot 'weapons.csv') | Sort-Object { [int]$_.id })
if ($weapons.Count -eq 0) { throw 'weapons.csv is empty.' }

$blocks = @{}
foreach ($w in $weapons)
{
	$id = [int]$w.id
	if (-not $STATS.ContainsKey($w.class)) { throw "weapon $id : unknown class $($w.class)" }
	if (-not $GRADE_IDX.ContainsKey($w.origGrade)) { throw "weapon $id : unknown grade $($w.origGrade)" }
	$blocks[$id] = Get-ItemBlock $id
	if ($blocks[$id][0] -notmatch 'type="Weapon"') { throw "item $id is not a weapon any more" }
}

# Numbering runs weapon by weapon in id order and, inside a weapon, bottom grade up, so a rerun gives
# the very same ids.
$ladder = @{}
$next = $FIRST_ITEM_ID
foreach ($w in $weapons)
{
	$id = [int]$w.id
	$rungs = @{}
	$rungs[$w.origGrade] = $id
	for ($gi = $GRADE_IDX[$w.origGrade] + 1; $gi -le $TOP_GRADE; $gi++)
	{
		$rungs[$GRADES[$gi]] = $next
		$next++
	}
	$ladder[$id] = $rungs
}
$lastItemId = $next - 1
Write-Host "$($weapons.Count) weapons, new item ids $FIRST_ITEM_ID..$lastItemId"

# ---------------------------------------------------------------------------
# The graded copies.
# ---------------------------------------------------------------------------

function New-ItemBlock($w, [string]$grade, [int]$newId)
{
	$src = $blocks[[int]$w.id]
	$tbl = $STATS[$w.class]
	$isBow = ($w.class -eq 'BOW')

	$head = @()
	if ($grade -ne 'NG')
	{
		$head += "`t`t<set name=`"crystal_type`" val=`"$grade`" />"
		$head += "`t`t<set name=`"crystal_count`" val=`"$($CRYSTALS[$grade])`" />"
	}
	$head += "`t`t<set name=`"price`" val=`"$($PRICES[$grade])`" />"
	$head += "`t`t<set name=`"soulshots`" val=`"$($(if ($isBow) { $BOW_SHOTS[$grade] } else { $SHOTS[$grade] }))`" />"
	$head += "`t`t<set name=`"spiritshots`" val=`"$($(if ($isBow) { $BOW_SPIRITSHOTS[$grade] } else { $SHOTS[$grade] }))`" />"
	if ($isBow) { $head += "`t`t<set name=`"mp_consume`" val=`"$($BOW_MP[$grade])`" />" }

	$out = [System.Collections.Generic.List[string]]::new()
	$null = $out.Add(($src[0] -replace '^\s*<item\s+id="\d+"', "`t<item id=`"$newId`""))

	$inCond = $false
	$written = $false
	for ($i = 1; $i -lt $src.Count; $i++)
	{
		$l = $src[$i]

		if ($inCond) { if ($l -match '</cond>') { $inCond = $false } ; continue }
		if ($l -match '<cond\b') { if ($l -notmatch '/>\s*$' -and $l -notmatch '</cond>') { $inCond = $true } ; continue }

		$skip = $false
		foreach ($s in $DROPPED_SETS) { if ($l -match "<set\s+name=`"$s`"") { $skip = $true ; break } }
		if ($skip) { continue }

		if (-not $written -and ($l -match '<for>' -or $l -match '</item>'))
		{
			foreach ($h in $head) { $null = $out.Add($h) }
			$written = $true
		}

		if ($l -match '<set\s+stat="pAtk"') { $l = $l -replace 'val="[^"]*"', "val=`"$($tbl.pAtk[$grade])`"" }
		elseif ($l -match '<set\s+stat="mAtk"') { $l = $l -replace 'val="[^"]*"', "val=`"$($tbl.mAtk[$grade])`"" }
		$null = $out.Add($l)
	}
	, $out
}

$clientItems = [System.Collections.Generic.List[string]]::new()
$null = $clientItems.Add("id`tdonor`tgrade`tgradeIdx`tpAtk`tmAtk`tclass`tglow`tname")

$buckets = @{}
$minted = 0
foreach ($w in $weapons)
{
	$id = [int]$w.id
	$tbl = $STATS[$w.class]
	$glow = $GLOW_TYPE[$w.class]

	foreach ($g in $GRADES)
	{
		if (-not $ladder[$id].ContainsKey($g)) { continue }
		$newId = $ladder[$id][$g]
		$gi = $GRADE_IDX[$g]

		# The rung of the weapon's own grade is the retail item, untouched. It still goes to the client
		# table, because its enchant glow is rewritten like everybody else's.
		if ($newId -eq $id)
		{
			$null = $clientItems.Add("$id`t$id`t$g`t$gi`t`t`t$($w.class)`t$glow`t$($w.name)")
			continue
		}

		$bucket = [int][math]::Floor($newId / $ITEMS_PER_FILE) * $ITEMS_PER_FILE
		if (-not $buckets.ContainsKey($bucket)) { $buckets[$bucket] = [System.Collections.Generic.List[string]]::new() }
		foreach ($l in (New-ItemBlock $w $g $newId)) { $null = $buckets[$bucket].Add($l) }
		$minted++

		$null = $clientItems.Add("$newId`t$id`t$g`t$gi`t$($tbl.pAtk[$g])`t$($tbl.mAtk[$g])`t$($w.class)`t$glow`t$($w.name)")
	}
}

$mintedFiles = @{}
foreach ($bucket in ($buckets.Keys | Sort-Object))
{
	$name = "{0}-{1}.xml" -f $bucket, ($bucket + $ITEMS_PER_FILE - 1)
	$mintedFiles[$name] = $true
	$body = @('<?xml version="1.0" encoding="UTF-8"?>', '<list>') + $buckets[$bucket] + @('</list>')
	Write-Datapack (Join-Path $itemsDir $name) $body $false
}

$dropped = Remove-StaleBuckets $itemsDir $FIRST_ITEM_ID ($FIRST_ITEM_ID + 100000) $mintedFiles
Write-Host "minted $minted copies into $($buckets.Count) item files$(if ($dropped) { ", removed $dropped stale" })"

# ---------------------------------------------------------------------------
# What the client has to be told, and the ladder itself.
# ---------------------------------------------------------------------------

$chain = [System.Collections.Generic.List[string]]::new()
$null = $chain.Add("weapon`tclass`tfrom`t" + ($GRADES -join "`t"))
foreach ($w in $weapons)
{
	$id = [int]$w.id
	$rungs = $GRADES | ForEach-Object { $(if ($ladder[$id].ContainsKey($_)) { $ladder[$id][$_] } else { '' }) }
	$null = $chain.Add("$($w.name)`t$($w.class)`t$($w.origGrade)`t" + ($rungs -join "`t"))
}

$UTF8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path $outDir 'upgrade_chain.tsv'), (($chain -join "`n") + "`n"), $UTF8)
[System.IO.File]::WriteAllText((Join-Path $outDir 'client_items.tsv'), (($clientItems -join "`n") + "`n"), $UTF8)
Write-Host "wrote generated\client_items.tsv ($($clientItems.Count - 1)), upgrade_chain.tsv ($($chain.Count - 1))"

# ---------------------------------------------------------------------------
# The GM shop. //gmshop -> Weapons -> <grade> reads one buy list per grade and weapon category
# (data/html/admin/gmshop/*gradew.htm) ; the minted copies have to be filed under the grade they carry,
# next to the original they were cloned from.
#
# Only the ids this script owns are touched : whatever else those lists hold is left where it is.
# ---------------------------------------------------------------------------

$wanted = @{}
foreach ($perGrade in $BUYLISTS.Values) { foreach ($list in $perGrade.Values) { $wanted[$list] = @() } }

$owned = New-Object 'System.Collections.Generic.HashSet[int]'
foreach ($w in $weapons)
{
	$id = [int]$w.id
	foreach ($g in $GRADES)
	{
		if (-not $ladder[$id].ContainsKey($g)) { continue }
		$newId = $ladder[$id][$g]
		if ($newId -eq $id) { continue }
		$null = $owned.Add($newId)
		$wanted[$BUYLISTS[$CATEGORY[$w.class]][$g]] += $newId
	}
}

$buyListsPath = Join-Path $dataDir 'buyLists.xml'
$buyListsEndsNl = Test-EndsWithNewline $buyListsPath
$buyLines = [System.Collections.Generic.List[string]]::new()
foreach ($l in [System.IO.File]::ReadAllLines($buyListsPath)) { $null = $buyLines.Add($l) }

# The seven lists that don't exist in the stock datapack, appended once, in id order.
$present = @{}
foreach ($l in $buyLines) { if ($l -match '^\s*<buyList\s+id="(\d+)"') { $present[[int]$Matches[1]] = $true } }
$new = @($wanted.Keys | Where-Object { -not $present.ContainsKey($_) } | Sort-Object)
if ($new.Count -gt 0)
{
	$at = -1
	for ($i = $buyLines.Count - 1; $i -ge 0; $i--) { if ($buyLines[$i] -match '</list>') { $at = $i ; break } }
	if ($at -lt 0) { throw 'buyLists.xml has no </list>.' }
	$add = @()
	foreach ($id in $new) { $add += "`t<buyList id=`"$id`" npcId=`"-1`"></buyList>" }
	$buyLines.InsertRange($at, $add)
	Write-Host "buyLists.xml : created $($new.Count) list(s) - $($new -join ', ')"
}

$found = @()
for ($i = 0; $i -lt $buyLines.Count; $i++)
{
	if ($buyLines[$i] -notmatch '^\s*<buyList\s+id="(\d+)"') { continue }
	$id = [int]$Matches[1]
	if (-not $wanted.ContainsKey($id)) { continue }
	$end = $i
	while ($end -lt $buyLines.Count -and $buyLines[$end] -notmatch '</buyList>') { $end++ }
	$found += @{ id = $id; start = $i; end = $end }
}

$touched = 0
foreach ($b in ($found | Sort-Object { $_.start } -Descending))
{
	$keep = [System.Collections.Generic.List[string]]::new()
	$null = $keep.Add(($buyLines[$b.start] -replace '></buyList>\s*$', '>'))

	for ($i = $b.start + 1; $i -le $b.end; $i++)
	{
		$l = $buyLines[$i]
		if ($l -match '</buyList>') { continue }
		# Ours, and about to be written back in order - or a minted id this run no longer has, left
		# behind by an earlier one.
		if ($l -match '<product\s+id="(\d+)"')
		{
			$product = [int]$Matches[1]
			if ($owned.Contains($product) -or $product -ge $FIRST_ITEM_ID) { continue }
		}
		$null = $keep.Add($l)
	}
	foreach ($id in ($wanted[$b.id] | Sort-Object)) { $null = $keep.Add("`t`t<product id=`"$id`"/>") }
	$null = $keep.Add("`t</buyList>")

	$buyLines.RemoveRange($b.start, $b.end - $b.start + 1)
	$buyLines.InsertRange($b.start, $keep)
	$touched++
}

if ($touched -ne 60) { throw "expected 60 GM shop weapon buy lists, refilled $touched" }
Write-Datapack $buyListsPath $buyLines $buyListsEndsNl
Write-Host "refilled $touched GM shop buy lists with $($owned.Count) weapons"

# ---------------------------------------------------------------------------
# The CI ships build\ as it stands, so the datapack has to land there too.
# ---------------------------------------------------------------------------

if (-not $NoSync)
{
	$buildXml = Join-Path $Repo 'build\gameserver\data\xml'
	if (-not (Test-Path $buildXml)) { Write-Warning "No $buildXml ; skipping the build\ copy." }
	else
	{
		Copy-Item $buyListsPath (Join-Path $buildXml 'buyLists.xml') -Force

		# A mirror, not just a copy : a file the datapack dropped has to go from build\ too, or the
		# server keeps loading it.
		$to = Join-Path $buildXml 'items'
		$have = @{}
		foreach ($f in Get-ChildItem $itemsDir -Filter *.xml)
		{
			$have[$f.Name] = $true
			Copy-Item $f.FullName (Join-Path $to $f.Name) -Force
		}
		foreach ($f in Get-ChildItem $to -Filter *.xml) { if (-not $have.ContainsKey($f.Name)) { Remove-Item $f.FullName -Force } }
		Write-Host 'synced items and buyLists.xml into build\gameserver\data\xml'
	}
}
