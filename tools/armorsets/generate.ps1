<#
.SYNOPSIS
	Gives every armor set of the datapack a ladder up to S grade, out of tools/armorsets/families.csv.

.DESCRIPTION
	One "family" is one look : a chest (or a fullarmor), the legs that go with it, a helmet, gloves
	and boots. families.csv holds 79 of them, one row per chest item of data/xml/items.

	A set keeps the grade it always had and gains one copy per grade above it, up to S :

	    a No Grade set exists as  NG D C B A S
	    a D grade set as             D C B A S
	    a C grade set as               C B A S
	    ... and an S grade set is left exactly as it is.

	So Zubei's, a B grade set, gains an A and an S version ; Imperial Crusader, already S, gains
	nothing at all.

	Every set owns its pieces. Head, legs, gloves and boots are minted for that one family on every
	rung of its ladder and named after its chest - "Tunic of Zubei Boots" - so no piece is ever worn
	by two sets. The items families.csv names are clone sources : they give their mesh, texture,
	icon, weight and material, and are not touched. The one exception is the chest, which is the
	family's key and unique to it : on the rung of its own grade the original item is used as is.

	What this script writes :

	  * every rung of every family, minted into data/xml/items/10000-*.xml and up ;
	  * the 79 chests keep their id and their grade - only their P. Def. is levelled onto the table
	    below, so that every set of a grade is worth the same ;
	  * data/xml/armorSets.xml is regenerated whole, one <armorset> per family per grade it reaches ;
	  * every family gets one passive skill of six levels - one per grade, level 6 always being S -
	    in data/xml/skills/9500-*.xml, plus three "+6 enchanted" skills, one per armor type.

	The ladder is only the items : upgrading one grade into the next is somebody else's feature, and
	the ids it needs are laid out in generated\upgrade_chain.tsv.

	Nothing is granted to anybody : no drop, no shop and no multisell is touched, the new items only
	exist. They are handed out the same way the old ones are.

	The client knows none of the new ids, so patch_client.ps1 has to be run afterwards against a
	client system directory - it feeds on the two .tsv this script drops in generated\. See
	docs/armor-sets-all-grades.md.

.PARAMETER Repo
	Repository root. Defaults to the one this script lives in.

.PARAMETER NoSync
	Leave build\gameserver\data alone. Without it the generated datapack is copied there too, as
	the CI deploys that folder as is.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\armorsets\generate.ps1
#>
param(
	[string]$Repo = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
	[switch]$NoSync
)

$ErrorActionPreference = 'Stop'

$dataDir = Join-Path $Repo 'source\aCis_datapack\data\xml'
$itemsDir = Join-Path $dataDir 'items'
$skillsDir = Join-Path $dataDir 'skills'
$outDir = Join-Path $PSScriptRoot 'generated'

if (-not (Test-Path $itemsDir)) { throw "No datapack at $itemsDir." }
$null = New-Item -ItemType Directory -Force -Path $outDir

# ---------------------------------------------------------------------------
# Grades. The whole script is driven by these six, in this order.
# ---------------------------------------------------------------------------

$GRADES = @('NG', 'D', 'C', 'B', 'A', 'S')
$GRADE_IDX = @{ NG = 0; D = 1; C = 2; B = 3; A = 4; S = 5 }
$TOP_GRADE = 5
$FIRST_ITEM_ID = 10000
$FIRST_SKILL_ID = 9500
$ENCHANT_SKILL = @{ HEAVY = 9700; LIGHT = 9701; MAGIC = 9702 }
$ITEMS_PER_FILE = 100

# P. Def. of one piece, per grade. Head, gloves and feet carry no armor type in Interlude, so one
# row each ; the chest / legs / fullarmor rows come from the armor type of the piece itself.
#
# The numbers are the retail top of each grade : a fullarmor total split 61.6 / 38.4 between chest
# and legs, which is the ratio every retail set uses (Zubei 157/98, Blue Wolf 166/104...).
$FULL_PDEF = @{
	HEAVY = @{ NG = 111; D = 167; C = 239; B = 270; A = 293; S = 333 }
	LIGHT = @{ NG = 86;  D = 125; C = 179; B = 202; A = 220; S = 249 }
	MAGIC = @{ NG = 56;  D = 85;  C = 120; B = 135; A = 147; S = 166 }
}
$CHEST_SHARE = 0.616
$SLOT_PDEF = @{
	head   = @{ NG = 26; D = 44; C = 58; B = 67; A = 73; S = 83 }
	gloves = @{ NG = 20; D = 29; C = 39; B = 44; A = 49; S = 55 }
	feet   = @{ NG = 20; D = 29; C = 39; B = 45; A = 49; S = 55 }
}

# Crystals given back on crystallization, and shop price. No Grade armor crystallizes into nothing,
# so its count is 0 whatever the piece.
$CRYSTALS = @{
	fullarmor = @{ NG = 0; D = 400; C = 560; B = 700; A = 830; S = 1000 }
	chest     = @{ NG = 0; D = 250; C = 350; B = 440; A = 520; S = 630 }
	legs      = @{ NG = 0; D = 150; C = 210; B = 260; A = 310; S = 370 }
	head      = @{ NG = 0; D = 100; C = 140; B = 175; A = 210; S = 250 }
	gloves    = @{ NG = 0; D = 80;  C = 110; B = 140; A = 165; S = 200 }
	feet      = @{ NG = 0; D = 80;  C = 110; B = 140; A = 165; S = 200 }
}
$PRICES = @{
	fullarmor = @{ NG = 60000; D = 429000; C = 1570000; B = 5080000; A = 7730000; S = 17400000 }
	chest     = @{ NG = 30000; D = 152000; C = 505000;  B = 2410000; A = 4630000; S = 14300000 }
	legs      = @{ NG = 18000; D = 95200;  C = 316000;  B = 1510000; A = 2890000; S = 8960000 }
	head      = @{ NG = 12000; D = 76200;  C = 536000;  B = 1210000; A = 2640000; S = 5370000 }
	gloves    = @{ NG = 8000;  D = 74700;  C = 245000;  B = 804000;  A = 1760000; S = 3580000 }
	feet      = @{ NG = 8000;  D = 74700;  C = 245000;  B = 804000;  A = 1760000; S = 3580000 }
}

# How hard a set bonus hits, per grade. 1.0 is A grade : a retail bonus is read as the value of its
# own original grade and rescaled from there, so Zubei's +5.26% P. Def. (B) becomes +2.2% at No
# Grade and +7.3% at S.
$GRADE_FACTOR = @{ NG = 0.35; D = 0.50; C = 0.68; B = 0.85; A = 1.00; S = 1.18 }
$MAGIC_LVL = @{ NG = 1; D = 20; C = 40; B = 52; A = 61; S = 76 }

# Base attributes are handed out whole or not at all - scaling them gives fractions of a STR point.
$UNSCALED_STATS = @('STR', 'DEX', 'CON', 'INT', 'WIT', 'MEN')

# Clan Oath and Apella. Their pledge rank <cond> and their academy equip_condition are dropped, so
# that they wear like any other set - and so is the "may be worn by a Baron" line the client shows,
# which would be a lie afterwards. Spelled out rather than sniffed off the <cond>, because the first
# run of this script already removed it.
$CLAN_ARMOR = 7850..7879

# ---------------------------------------------------------------------------
# Set bonuses for the families retail never made a set out of. Eight per armor type, handed out
# round robin by families.csv ; their values are read as A grade ones.
# ---------------------------------------------------------------------------

$POOL = @{
	h1 = @( @{f='mul';    s='pDef';          v=1.0524}, @{f='add'; s='maxHp'; v=294} )
	h2 = @( @{f='add';    s='maxHp';         v=320},    @{f='add'; s='breath'; v=200}, @{f='sub'; s='STR'; v=3}, @{f='add'; s='CON'; v=3} )
	h3 = @( @{f='add';    s='runSpd';        v=7},      @{f='mul'; s='regHp'; v=1.0526}, @{f='add'; s='STR'; v=3}, @{f='sub'; s='CON'; v=1}, @{f='sub'; s='DEX'; v=2} )
	h4 = @( @{f='mul';    s='pAtk';          v=1.04},   @{f='add'; s='accCombat'; v=3}, @{f='addMul'; s='stunVuln'; v=50}, @{f='add'; s='STR'; v=2}, @{f='sub'; s='CON'; v=2} )
	h5 = @( @{f='mul';    s='pAtkSpd';       v=1.08},   @{f='add'; s='weightLimit'; v=5759}, @{f='addMul'; s='poisonVuln'; v=80}, @{f='add'; s='STR'; v=2}, @{f='sub'; s='CON'; v=2} )
	h6 = @( @{f='mul';    s='pDef';          v=1.08},   @{f='add'; s='maxHp'; v=445} )
	h7 = @( @{f='add';    s='maxCp';         v=232},    @{f='mul'; s='regCp'; v=1.4} )
	h8 = @( @{f='mul';    s='gainHp';        v=1.04},   @{f='addMul'; s='paralyzeVuln'; v=50}, @{f='sub'; s='STR'; v=2}, @{f='add'; s='CON'; v=2} )
	l1 = @( @{f='add';    s='rEvas';         v=4} )
	l2 = @( @{f='mul';    s='pDef';          v=1.0524}, @{f='mul'; s='mAtkSpd'; v=1.15} )
	l3 = @( @{f='mul';    s='pAtkSpd';       v=1.04},   @{f='mul'; s='pAtk'; v=1.04}, @{f='add'; s='STR'; v=1}, @{f='sub'; s='CON'; v=1} )
	l4 = @( @{f='mul';    s='pAtk';          v=1.08},   @{f='add'; s='maxMp'; v=240}, @{f='add'; s='weightLimit'; v=5759} )
	l5 = @( @{f='mul';    s='mDef';          v=1.0525}, @{f='add'; s='weightLimit'; v=5795} )
	l6 = @( @{f='mul';    s='regMp';         v=1.08},   @{f='add'; s='maxMp'; v=222}, @{f='add'; s='MEN'; v=2}, @{f='sub'; s='WIT'; v=2} )
	l7 = @( @{f='add';    s='maxCp';         v=195},    @{f='mul'; s='regCp'; v=1.4} )
	l8 = @( @{f='mul';    s='mDef';          v=1.04},   @{f='add'; s='absorbDam'; v=3}, @{f='add'; s='DEX'; v=1}, @{f='sub'; s='CON'; v=1} )
	m1 = @( @{f='mul';    s='mAtk';          v=1.10},   @{f='mul'; s='regMp'; v=0.95} )
	m2 = @( @{f='mul';    s='mAtkSpd';       v=1.15},   @{f='mul'; s='mDef'; v=1.08} )
	m3 = @( @{f='add';    s='maxMp';         v=206},    @{f='mul'; s='regMp'; v=1.0526}, @{f='add'; s='WIT'; v=3}, @{f='sub'; s='INT'; v=2} )
	m4 = @( @{f='mul';    s='pDef';          v=1.08},   @{f='mul'; s='mAtkSpd'; v=1.15}, @{f='add'; s='runSpd'; v=7} )
	m5 = @( @{f='mul';    s='mAtk';          v=1.17},   @{f='add'; s='runSpd'; v=7}, @{f='add'; s='weightLimit'; v=5759} )
	m6 = @( @{f='add';    s='maxMp';         v=240},    @{f='mul'; s='mAtkSpd'; v=1.15}, @{f='mul'; s='regMp'; v=1.08} )
	m7 = @( @{f='add';    s='maxCp';         v=177},    @{f='mul'; s='regCp'; v=1.4} )
	m8 = @( @{f='mul';    s='regMp';         v=1.04},   @{f='mul'; s='mAtk'; v=1.08}, @{f='add'; s='INT'; v=2}, @{f='sub'; s='WIT'; v=2} )
}

# The "all parts +6" bonus, straight off the retail ladder 3611..3625, with a No Grade rung added
# under the D one.
$ENCHANT_ROWS = @{
	HEAVY = @{ stats = @('pDef', 'regMp'); rows = @{ NG = @(15, 2); D = @(25, 2); C = @(38, 2); B = @(44, 2); A = @(50, 2); S = @(56, 2) } }
	LIGHT = @{ stats = @('rEvas', 'mDef'); rows = @{ NG = @(1, 7);  D = @(2, 12); C = @(2, 20); B = @(2, 24); A = @(2, 28); S = @(2, 32) } }
	MAGIC = @{ stats = @('pDef', 'mDef');  rows = @{ NG = @(10, 6); D = @(16, 10); C = @(24, 14); B = @(28, 18); A = @(32, 22); S = @(36, 26) } }
}

# ---------------------------------------------------------------------------
# The item files, as lines, plus an index of where each item block sits.
# ---------------------------------------------------------------------------

# Datapack files carry no trailing newline ; adding one would show up as a diff on files whose
# content this script didn't actually change.
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

function Write-Datapack([string]$path, [string[]]$body, [string]$eol, [bool]$endsNl)
{
	$text = ($body -join $eol)
	if ($endsNl) { $text += $eol }
	[System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding $false))
}

# A table that shrank leaves its top buckets behind, and the server would happily go on loading the
# orphans out of them. Every "<from>-<to>.xml" of our own id range that this run didn't write goes.
function Remove-StaleBuckets([string]$dir, [int]$firstId, $written)
{
	$dropped = 0
	foreach ($f in Get-ChildItem $dir -Filter *.xml)
	{
		if ($f.Name -notmatch '^(\d+)-\d+\.xml$') { continue }
		if ([int]$Matches[1] -lt $firstId -or $written.ContainsKey($f.Name)) { continue }
		Remove-Item $f.FullName -Force
		$dropped++
	}
	$dropped
}

$files = @{}
$index = @{}
$endsNl = @{}
foreach ($f in Get-ChildItem $itemsDir -Filter *.xml)
{
	$lines = [System.IO.File]::ReadAllLines($f.FullName)
	$endsNl[$f.Name] = Test-EndsWithNewline $f.FullName
	$files[$f.Name] = [System.Collections.Generic.List[string]]::new()
	foreach ($l in $lines) { $null = $files[$f.Name].Add($l) }

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
	, @($files[$e.file].GetRange($e.start, $e.end - $e.start + 1))
}

function Get-ItemField([string[]]$block, [string]$name)
{
	foreach ($l in $block) { if ($l -match "<set\s+name=`"$name`"\s+val=`"([^`"]*)`"") { return $Matches[1] } }
	return ''
}

function Get-ItemName([string[]]$block)
{
	if ($block[0] -match 'name="([^"]*)"') { return $Matches[1] }
	return ''
}

function ConvertTo-XmlText([string]$s)
{
	$s.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
}

# ---------------------------------------------------------------------------
# Families, and the pieces they are made of.
# ---------------------------------------------------------------------------

$families = @(Import-Csv (Join-Path $PSScriptRoot 'families.csv'))
if ($families.Count -eq 0) { throw 'families.csv is empty.' }

$SLOTS = @('head', 'chest', 'legs', 'gloves', 'feet')

# What a slot is called once the piece is named after its chest : "Tunic of Zubei Helmet". Legs are
# stockings on a robe and gaiters on anything else, the way retail names them.
$SLOT_WORD = @{ head = 'Helmet'; gloves = 'Gloves'; feet = 'Boots' }
function Get-SlotWord([string]$slot, [string]$type)
{
	if ($slot -eq 'legs') { return $(if ($type -eq 'MAGIC') { 'Stockings' } else { 'Gaiters' }) }
	$SLOT_WORD[$slot]
}

# Donors are clone sources and nothing else : nobody wears one as a set piece except a chest, on its
# own rung. What is read off them is the look - mesh, texture, icon, weight, material - plus the
# body part and the grade the item itself carries.
$donors = @{}
foreach ($fam in $families)
{
	foreach ($slot in $SLOTS)
	{
		$donor = [int]$fam.$slot
		if ($donor -eq 0 -or $donors.ContainsKey($donor)) { continue }

		$block = Get-ItemBlock $donor
		$bodypart = Get-ItemField $block 'bodypart'
		if ($bodypart -eq '') { throw "item $donor has no bodypart" }
		$crystal = Get-ItemField $block 'crystal_type'
		$donors[$donor] = @{
			bodypart = $bodypart
			type     = Get-ItemField $block 'armor_type'
			name     = Get-ItemName $block
			block    = $block
			gated    = ($CLAN_ARMOR -contains $donor)
			own      = $(if ($crystal -eq '') { 0 } else { $GRADE_IDX[$crystal] })
		}
	}
}

# Every set owns its pieces. A helmet that says "Tunic of Zubei" on it cannot also be worn by the
# heavy and the light Zubei, so nothing is shared any more : each family gets its own head, legs,
# gloves and boots minted on every rung of its ladder. Only the chest, which is the family's key and
# is unique to it anyway, keeps its original item on the rung of its own grade.
#
# Numbering runs family by family in chest id order and, inside a family, bottom grade up, so a
# rerun gives the very same ids.
$famIds = @{}
$next = $FIRST_ITEM_ID
foreach ($fam in ($families | Sort-Object { [int]$_.chest }))
{
	$lo = $GRADE_IDX[$fam.origGrade]
	$chest = [int]$fam.chest
	if ($donors[$chest].own -ne $lo) { throw "chest $chest is grade $($GRADES[$donors[$chest].own]), families.csv says $($fam.origGrade)" }

	$famIds[$fam.chest] = @{}
	for ($gi = $lo; $gi -le $TOP_GRADE; $gi++)
	{
		$rung = @{}
		foreach ($slot in $SLOTS)
		{
			if ([int]$fam.$slot -eq 0) { $rung[$slot] = 0 ; continue }
			if ($slot -eq 'chest' -and $gi -eq $lo) { $rung[$slot] = $chest ; continue }
			$rung[$slot] = $next
			$next++
		}
		$famIds[$fam.chest][$GRADES[$gi]] = $rung
	}
}
$lastItemId = $next - 1

Write-Host "$($families.Count) families, $($donors.Count) donors, new item ids $FIRST_ITEM_ID..$lastItemId"

# ---------------------------------------------------------------------------
# What a piece is worth at a given grade.
# ---------------------------------------------------------------------------

function Get-PDef($piece, [string]$grade)
{
	switch ($piece.bodypart)
	{
		'fullarmor' { return $FULL_PDEF[$piece.type][$grade] }
		'chest'     { return [int][math]::Round($FULL_PDEF[$piece.type][$grade] * $CHEST_SHARE) }
		'legs'      { return $FULL_PDEF[$piece.type][$grade] - [int][math]::Round($FULL_PDEF[$piece.type][$grade] * $CHEST_SHARE) }
		default     { return $SLOT_PDEF[$piece.bodypart][$grade] }
	}
}

# <set> lines a copy never inherits : the first three are rewritten per grade, and the rest would
# carry a donor's quest strings over to a piece that has no quest behind it - a copy of Dragon Scale
# Mail is an ordinary item, not a bound reward. Clan armor also loses its <cond> (see $CLAN_ARMOR),
# which is handled separately because it is a block, not a line.
$DROPPED_SETS = @('crystal_type', 'crystal_count', 'price', 'equip_condition',
	'is_tradable', 'is_dropable', 'is_sellable', 'is_depositable', 'is_destroyable')

function New-ItemBlock($piece, [string]$grade, [int]$newId, [string]$pieceName)
{
	$src = $piece.block
	$pdef = Get-PDef $piece $grade
	$name = ConvertTo-XmlText $pieceName
	$crystals = $CRYSTALS[$piece.bodypart][$grade]
	$price = $PRICES[$piece.bodypart][$grade]

	# A hole in one of the tables would otherwise ship as val="" and the item would silently fail
	# to load.
	foreach ($v in $pdef, $crystals, $price) { if ($null -eq $v) { throw "no $($piece.bodypart) / $grade row in the stat tables (item $newId, from $($piece.name))" } }

	# No Grade armor has no crystal type at all - CrystalType.NONE is what an absent line means, and
	# there is no "NG" to write.
	$grades = @()
	if ($grade -ne 'NG')
	{
		$grades += "`t`t<set name=`"crystal_type`" val=`"$grade`" />"
		$grades += "`t`t<set name=`"crystal_count`" val=`"$crystals`" />"
	}
	$grades += "`t`t<set name=`"price`" val=`"$price`" />"

	$out = [System.Collections.Generic.List[string]]::new()
	$null = $out.Add("`t<item id=`"$newId`" type=`"Armor`" name=`"$name`">")

	$inCond = $false
	$gradesWritten = $false
	for ($i = 1; $i -lt $src.Count; $i++)
	{
		$l = $src[$i]

		if ($inCond) { if ($l -match '</cond>') { $inCond = $false } ; continue }
		if ($l -match '<cond\b') { if ($l -notmatch '/>\s*$' -and $l -notmatch '</cond>') { $inCond = $true } ; continue }

		$skip = $false
		foreach ($s in $DROPPED_SETS) { if ($l -match "<set\s+name=`"$s`"") { $skip = $true ; break } }
		if ($skip) { continue }

		if (-not $gradesWritten -and ($l -match '<for>' -or $l -match '</item>'))
		{
			foreach ($g in $grades) { $null = $out.Add($g) }
			$gradesWritten = $true
		}

		if ($l -match '<baseadd\s+stat="pDef"') { $l = $l -replace 'val="[^"]*"', "val=`"$pdef`"" }
		$null = $out.Add($l)
	}
	, $out
}

# ---------------------------------------------------------------------------
# The graded copies of every piece.
# ---------------------------------------------------------------------------

$clientItems = [System.Collections.Generic.List[string]]::new()
$null = $clientItems.Add("id`tdonor`tgrade`tgradeIdx`tpdef`tname`taddName`tmode`tclearDesc")

$buckets = @{}
$minted = 0
$pieceName = @{}
foreach ($fam in ($families | Sort-Object { [int]$_.chest }))
{
	$chest = [int]$fam.chest
	$setName = $donors[$chest].name

	foreach ($g in $GRADES)
	{
		if (-not $famIds[$fam.chest].ContainsKey($g)) { continue }
		$gi = $GRADE_IDX[$g]

		foreach ($slot in $SLOTS)
		{
			$id = $famIds[$fam.chest][$g][$slot]
			if ($id -eq 0) { continue }

			$piece = $donors[[int]$fam.$slot]
			$pdef = Get-PDef $piece $g
			$clear = $(if ($piece.gated) { '1' } else { '0' })

			# Every piece of a set is named after its chest, and carries no grade : the client shows
			# the grade on the icon already.
			$name = $(if ($slot -eq 'chest') { $setName } else { "$setName $(Get-SlotWord $slot $fam.type)" })
			$pieceName[$id] = $name

			# The chest on the rung of its own grade : it keeps its id, its name and its grade, and
			# only its P. Def. is levelled onto the table.
			if ($id -eq $chest)
			{
				$null = $clientItems.Add("$id`t$chest`t$g`t$gi`t$pdef`t$name`t`tupdate`t$clear")
				continue
			}

			$bucket = [int][math]::Floor($id / $ITEMS_PER_FILE) * $ITEMS_PER_FILE
			if (-not $buckets.ContainsKey($bucket)) { $buckets[$bucket] = [System.Collections.Generic.List[string]]::new() }
			foreach ($l in (New-ItemBlock $piece $g $id $name)) { $null = $buckets[$bucket].Add($l) }
			$minted++

			$null = $clientItems.Add("$id`t$([int]$fam.$slot)`t$g`t$gi`t$pdef`t$name`t`tadd`t$clear")
		}
	}
}

$mintedFiles = @{}
foreach ($bucket in ($buckets.Keys | Sort-Object))
{
	$name = "{0}-{1}.xml" -f $bucket, ($bucket + $ITEMS_PER_FILE - 1)
	$mintedFiles[$name] = $true
	$body = @('<?xml version="1.0" encoding="UTF-8"?>', '<list>') + $buckets[$bucket] + @('</list>')
	Write-Datapack (Join-Path $itemsDir $name) $body "`r`n" $false
}

$dropped = Remove-StaleBuckets $itemsDir $FIRST_ITEM_ID $mintedFiles
Write-Host "wrote $($buckets.Count) item files$(if ($dropped) { ", removed $dropped stale" })"

# ---------------------------------------------------------------------------
# The chests, on the rung of their own grade, rewritten where they stand. Their grade, their price
# and their crystals are left alone - only P. Def. is levelled, and clan armor is ungated. Bottom
# up, so that removing lines out of one block doesn't move the next one.
#
# Nothing else is touched : head, legs, gloves and boots are clone sources only, never worn as
# themselves, so those originals stay exactly as retail left them.
# ---------------------------------------------------------------------------

$byFile = @{}
foreach ($fam in $families)
{
	$chest = [int]$fam.chest
	$f = $index[$chest].file
	if (-not $byFile.ContainsKey($f)) { $byFile[$f] = @() }
	$byFile[$f] += $chest
}

$rewritten = 0
foreach ($f in $byFile.Keys)
{
	$lines = $files[$f]
	foreach ($donor in ($byFile[$f] | Sort-Object { $index[$_].start } -Descending))
	{
		$e = $index[$donor]
		$piece = $donors[$donor]
		$pdef = Get-PDef $piece $GRADES[$piece.own]
		$keep = [System.Collections.Generic.List[string]]::new()
		$inCond = $false

		for ($i = $e.start; $i -le $e.end; $i++)
		{
			$l = $lines[$i]

			if ($piece.gated)
			{
				if ($inCond) { if ($l -match '</cond>') { $inCond = $false } ; continue }
				if ($l -match '<cond\b') { if ($l -notmatch '/>\s*$' -and $l -notmatch '</cond>') { $inCond = $true } ; continue }
				if ($l -match '<set\s+name="equip_condition"') { continue }
			}

			if ($l -match '<baseadd\s+stat="pDef"') { $l = $l -replace 'val="[^"]*"', "val=`"$pdef`"" }
			$null = $keep.Add($l)
		}

		$lines.RemoveRange($e.start, $e.end - $e.start + 1)
		$lines.InsertRange($e.start, $keep)
		$rewritten++
	}
	Write-Datapack (Join-Path $itemsDir $f) $lines "`r`n" $endsNl[$f]
}
Write-Host "minted $minted items, levelled $rewritten chests in $($byFile.Count) files"

# ---------------------------------------------------------------------------
# Set bonuses. One skill per family, one level per grade.
# ---------------------------------------------------------------------------

$INV = [System.Globalization.CultureInfo]::InvariantCulture
function ConvertTo-Double([string]$s) { [double]::Parse($s, $INV) }
function Format-Double([double]$d, [int]$dec) { $d.ToString("F$dec", $INV).TrimEnd('0').TrimEnd('.') }

# The <for> block of every retail set skill, so that a family retail did make a set out of keeps
# its own bonus - only rescaled onto the six grades.
$retailFor = @{}
foreach ($sf in Get-ChildItem $skillsDir -Filter '3*.xml')
{
	[xml]$doc = Get-Content $sf.FullName
	foreach ($sk in $doc.list.skill)
	{
		if (-not $sk.for) { continue }
		# Skills whose values come out of a <table> ("#pAtk") can't be rescaled ; none of the set
		# bonuses is one, so dropping them costs nothing.
		$fns = @()
		foreach ($n in $sk.for.ChildNodes)
		{
			if ($n.NodeType -ne 'Element') { continue }
			$v = 0.0
			if (-not $n.stat -or -not [double]::TryParse([string]$n.val, [System.Globalization.NumberStyles]::Float, $INV, [ref]$v)) { $fns = @() ; break }
			$fns += @{ f = $n.Name; s = $n.stat; v = $v }
		}
		if ($fns.Count -gt 0) { $retailFor[$sk.id] = $fns }
	}
}

function Get-ScaledValue($fn, [double]$ratio)
{
	if ($UNSCALED_STATS -contains $fn.s) { return Format-Double $fn.v 0 }

	if ($fn.f -eq 'mul' -or $fn.f -eq 'basemul')
	{
		return Format-Double (1 + ($fn.v - 1) * $ratio) 4
	}

	$v = $fn.v * $ratio
	if ([math]::Abs($fn.v - [math]::Round($fn.v)) -lt 0.0001)
	{
		$r = [int][math]::Round($v)
		if ($r -eq 0) { $r = 1 }
		return "$r"
	}
	return Format-Double $v 2
}

$STAT_LABEL = @{
	pDef = 'P. Def.'; mDef = 'M. Def.'; pAtk = 'P. Atk.'; mAtk = 'M. Atk.'
	pAtkSpd = 'Atk. Spd.'; mAtkSpd = 'Casting Spd.'; maxHp = 'Max HP'; maxMp = 'Max MP'; maxCp = 'Max CP'
	regHp = 'HP regeneration'; regMp = 'MP regeneration'; regCp = 'CP regeneration'; gainHp = 'HP recovery'
	rEvas = 'Evasion'; accCombat = 'Accuracy'; runSpd = 'Speed'; weightLimit = 'Weight limit'
	breath = 'Breath'; absorbDam = 'HP drain'; cancel = 'Cancel resistance'
	poisonVuln = 'Poison resistance'; bleedVuln = 'Bleed resistance'; stunVuln = 'Stun resistance'
	sleepVuln = 'Sleep resistance'; rootVuln = 'Root resistance'; paralyzeVuln = 'Paralysis resistance'
	daggerWpnVuln = 'Dagger resistance'
}

function Format-Bonus($fns, [double]$ratio)
{
	$out = @()
	foreach ($fn in $fns)
	{
		$label = $(if ($STAT_LABEL.ContainsKey($fn.s)) { $STAT_LABEL[$fn.s] } else { $fn.s })
		$val = Get-ScaledValue $fn $ratio

		if ($fn.f -eq 'mul' -or $fn.f -eq 'basemul')
		{
			$pct = [math]::Round(((ConvertTo-Double $val) - 1) * 100, 1)
			$out += "$label $(if ($pct -ge 0) { '+' })$($pct.ToString($INV))%"
		}
		elseif ($fn.f -eq 'sub') { $out += "$label -$val" }
		elseif ($fn.f -eq 'addMul') { $out += "$label +$val%" }
		else { $out += "$label +$val" }
	}
	($out -join ', ') + '.'
}

$clientSkills = [System.Collections.Generic.List[string]]::new()
$null = $clientSkills.Add("id`tlevel`tname`tdesc`tkind`ticonFrom")

$skillBuckets = @{}
function Add-Skill([int]$id, [string]$xml)
{
	$bucket = [int][math]::Floor($id / 100) * 100
	if (-not $skillBuckets.ContainsKey($bucket)) { $skillBuckets[$bucket] = [System.Collections.Generic.List[string]]::new() }
	foreach ($l in ($xml -split "`n")) { $null = $skillBuckets[$bucket].Add($l) }
}

function New-SkillXml([int]$id, [string]$name, $fns, [double[]]$ratios)
{
	$tables = @("`t`t<table name=`"#magicLvl`"> " + (($GRADES | ForEach-Object { $MAGIC_LVL[$_] }) -join ' ') + " </table>")
	$body = @()
	$n = 0
	foreach ($fn in $fns)
	{
		$n++
		if ($UNSCALED_STATS -contains $fn.s)
		{
			$body += "`t`t`t<$($fn.f) stat=`"$($fn.s)`" val=`"$(Format-Double $fn.v 0)`" />"
			continue
		}
		$vals = @()
		foreach ($r in $ratios) { $vals += Get-ScaledValue $fn $r }
		$tables += "`t`t<table name=`"#v$n`"> " + ($vals -join ' ') + " </table>"
		$body += "`t`t`t<$($fn.f) stat=`"$($fn.s)`" val=`"#v$n`" />"
	}

	@(
		"`t<skill id=`"$id`" levels=`"6`" name=`"$(ConvertTo-XmlText $name)`" >"
		$tables
		"`t`t<set name=`"target`" val=`"SELF`" />"
		"`t`t<set name=`"skillType`" val=`"BUFF`" />"
		"`t`t<set name=`"operateType`" val=`"PASSIVE`" />"
		"`t`t<set name=`"magicLvl`" val=`"#magicLvl`" />"
		"`t`t<for>"
		$body
		"`t`t</for>"
		"`t</skill>"
	) -join "`n"
}

$famSkill = @{}
$famBonus = @{}
$k = 0
foreach ($fam in $families)
{
	$id = $FIRST_SKILL_ID + $k
	$famSkill[$fam.chest] = $id

	$fns = $(if ($retailFor.ContainsKey($fam.profile)) { $retailFor[$fam.profile] } else { $POOL[$fam.profile] })
	if (-not $fns) { throw "family $($fam.chest) has an unknown profile '$($fam.profile)'" }
	$ref = $(if ($retailFor.ContainsKey($fam.profile)) { $fam.origGrade } else { 'A' })

	$ratios = @($GRADES | ForEach-Object { $GRADE_FACTOR[$_] / $GRADE_FACTOR[$ref] })
	Add-Skill $id (New-SkillXml $id $fam.name $fns $ratios)

	$famBonus[$fam.chest] = @{}
	for ($gi = 0; $gi -lt 6; $gi++)
	{
		$g = $GRADES[$gi]
		$famBonus[$fam.chest][$g] = Format-Bonus $fns $ratios[$gi]
		$null = $clientSkills.Add("$id`t$($gi + 1)`t$($fam.name)`t$($famBonus[$fam.chest][$g])`tset`t$($fam.chest)")
	}
	$k++
}

foreach ($type in @('HEAVY', 'LIGHT', 'MAGIC'))
{
	$id = $ENCHANT_SKILL[$type]
	$def = $ENCHANT_ROWS[$type]
	$name = "Enchant $((Get-Culture).TextInfo.ToTitleCase($type.ToLower())) Armor"
	if ($type -eq 'MAGIC') { $name = 'Enchant Robe' }

	$tables = @("`t`t<table name=`"#magicLvl`"> " + (($GRADES | ForEach-Object { $MAGIC_LVL[$_] }) -join ' ') + " </table>")
	$body = @()
	for ($n = 0; $n -lt $def.stats.Count; $n++)
	{
		$vals = @($GRADES | ForEach-Object { $def.rows[$_][$n] })
		$tables += "`t`t<table name=`"#v$($n + 1)`"> " + ($vals -join ' ') + " </table>"
		$body += "`t`t`t<add stat=`"$($def.stats[$n])`" val=`"#v$($n + 1)`" />"
	}

	Add-Skill $id (@(
		"`t<skill id=`"$id`" levels=`"6`" name=`"$name`" >"
		$tables
		"`t`t<set name=`"target`" val=`"SELF`" />"
		"`t`t<set name=`"skillType`" val=`"BUFF`" />"
		"`t`t<set name=`"operateType`" val=`"PASSIVE`" />"
		"`t`t<set name=`"magicLvl`" val=`"#magicLvl`" />"
		"`t`t<for>"
		$body
		"`t`t</for>"
		"`t</skill>"
	) -join "`n")

	for ($gi = 0; $gi -lt 6; $gi++)
	{
		$d = @()
		for ($n = 0; $n -lt $def.stats.Count; $n++)
		{
			$s = $def.stats[$n]
			$label = $(if ($STAT_LABEL.ContainsKey($s)) { $STAT_LABEL[$s] } else { $s })
			$d += "$label +$($def.rows[$GRADES[$gi]][$n])"
		}
		$null = $clientSkills.Add("$id`t$($gi + 1)`t$name`t$(($d -join ', ')).`tenchant`t0")
	}
}

$writtenSkills = @{}
foreach ($bucket in ($skillBuckets.Keys | Sort-Object))
{
	$name = "{0}-{1}.xml" -f $bucket, ($bucket + 99)
	$writtenSkills[$name] = $true
	$body = @('<?xml version="1.0" encoding="UTF-8"?>', '<list>') + $skillBuckets[$bucket] + @('</list>')
	[System.IO.File]::WriteAllText((Join-Path $skillsDir $name), ($body -join "`n") + "`n", (New-Object System.Text.UTF8Encoding $false))
}
$dropped = Remove-StaleBuckets $skillsDir $FIRST_SKILL_ID $writtenSkills
Write-Host "wrote $($families.Count) set skills + 3 enchant skills in $($skillBuckets.Count) files$(if ($dropped) { ", removed $dropped stale" })"

# ---------------------------------------------------------------------------
# armorSets.xml, one row per family per grade it reaches, and what the client has to say about them.
# ---------------------------------------------------------------------------

$sets = [System.Collections.Generic.List[string]]::new()
$clientSets = [System.Collections.Generic.List[string]]::new()
$null = $clientSets.Add("chest`tmembers`tbonus`textraId`textraDesc")

foreach ($fam in $families)
{
	for ($gi = $GRADE_IDX[$fam.origGrade]; $gi -le $TOP_GRADE; $gi++)
	{
		$g = $GRADES[$gi]
		$slotIds = $famIds[$fam.chest][$g]

		$name = ConvertTo-XmlText ("{0} ({1})" -f $fam.name, $g)
		$null = $sets.Add(("`t<armorset name=`"{0}`" chest=`"{1}`" legs=`"{2}`" head=`"{3}`" gloves=`"{4}`" feet=`"{5}`" skillId=`"{6}`" skillLvl=`"{7}`" shield=`"{8}`" shieldSkillId=`"{9}`" enchant6Skill=`"{10}`"/>" -f `
			$name, $slotIds.chest, $slotIds.legs, $slotIds.head, $slotIds.gloves, $slotIds.feet,
			$famSkill[$fam.chest], ($gi + 1), $fam.shield, $fam.shieldSkill, $ENCHANT_SKILL[$fam.type]))

		$members = @($slotIds.chest, $slotIds.legs, $slotIds.head, $slotIds.gloves, $slotIds.feet) | Where-Object { $_ -ne 0 }
		$extraId = ''
		$extraDesc = ''
		if ([int]$fam.shield -ne 0)
		{
			$extraId = $fam.shield
			$sfns = $retailFor[$fam.shieldSkill]
			$extraDesc = $(if ($sfns) { Format-Bonus $sfns 1.0 } else { 'Shield bonus.' })
		}
		$null = $clientSets.Add("$($slotIds.chest)`t$($members -join ',')`t$($famBonus[$fam.chest][$g])`t$extraId`t$extraDesc")
	}
}

$armorSetsPath = Join-Path $dataDir 'armorSets.xml'
$body = @("<?xml version='1.0' encoding='utf-8'?>", '<list>') + $sets + @('</list>')
Write-Datapack $armorSetsPath $body "`r`n" (Test-EndsWithNewline $armorSetsPath)
Write-Host "wrote $($sets.Count) armor sets"

# One line per slot of every set : the ids that piece wears from the set's own grade up to S, an
# empty cell for the grades it doesn't reach. Whoever builds the "upgrade this set one grade"
# feature reads its ladder out of here rather than guessing at id arithmetic.
$chain = [System.Collections.Generic.List[string]]::new()
$null = $chain.Add("set`tpiece`tslot`tbodypart`tarmorType`tfrom`t" + ($GRADES -join "`t"))
foreach ($fam in ($families | Sort-Object { [int]$_.chest }))
{
	foreach ($slot in $SLOTS)
	{
		if ([int]$fam.$slot -eq 0) { continue }
		$p = $donors[[int]$fam.$slot]
		$rungs = $GRADES | ForEach-Object { $(if ($famIds[$fam.chest].ContainsKey($_)) { $famIds[$fam.chest][$_][$slot] } else { '' }) }
		$first = $famIds[$fam.chest][$fam.origGrade][$slot]
		$null = $chain.Add("$($fam.name)`t$($pieceName[$first])`t$slot`t$($p.bodypart)`t$($p.type)`t$($fam.origGrade)`t" + ($rungs -join "`t"))
	}
}
[System.IO.File]::WriteAllText((Join-Path $outDir 'upgrade_chain.tsv'), (($chain -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding $false))

[System.IO.File]::WriteAllText((Join-Path $outDir 'client_items.tsv'), (($clientItems -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding $false))
[System.IO.File]::WriteAllText((Join-Path $outDir 'client_sets.tsv'), (($clientSets -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding $false))
[System.IO.File]::WriteAllText((Join-Path $outDir 'client_skills.tsv'), (($clientSkills -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding $false))
Write-Host "wrote generated\client_items.tsv ($($clientItems.Count - 1)), client_sets.tsv ($($clientSets.Count - 1)), client_skills.tsv ($($clientSkills.Count - 1)), upgrade_chain.tsv ($($chain.Count - 1))"

# ---------------------------------------------------------------------------
# The GM shop. //gmshop -> Armors -> <grade> reads one buy list per grade and body part
# (data/html/admin/gmshop/*gradea.htm) ; the minted copies have to be filed under the grade they
# carry, next to the original they were cloned from.
#
# Only the ids this script owns are touched : whatever else those lists hold - sealed and shadow
# armor, shields, cloaks, underwear - is left where it is.
# ---------------------------------------------------------------------------

$BUYLISTS = @{
	head      = @{ NG = 9099; D = 9090; C = 9081; B = 9072; A = 9063; S = 9054 }
	chest     = @{ NG = 9100; D = 9091; C = 9082; B = 9073; A = 9064; S = 9055 }
	fullarmor = @{ NG = 9101; D = 9092; C = 9083; B = 9074; A = 9065; S = 9056 }
	legs      = @{ NG = 9102; D = 9093; C = 9084; B = 9075; A = 9066; S = 9057 }
	gloves    = @{ NG = 9103; D = 9094; C = 9085; B = 9076; A = 9067; S = 9058 }
	feet      = @{ NG = 9104; D = 9095; C = 9086; B = 9077; A = 9068; S = 9059 }
}

$owned = New-Object 'System.Collections.Generic.HashSet[int]'

# All 36 lists up front, empty. A grade that ends up with no piece of a body part - No Grade
# fullarmor, once the robes that were the only ones went - still has to be walked, so that whatever
# a previous run left in it is taken back out.
$wanted = @{}
foreach ($perGrade in $BUYLISTS.Values) { foreach ($list in $perGrade.Values) { $wanted[$list] = @() } }

foreach ($fam in $families)
{
	foreach ($g in $GRADES)
	{
		if (-not $famIds[$fam.chest].ContainsKey($g)) { continue }
		foreach ($slot in $SLOTS)
		{
			$id = $famIds[$fam.chest][$g][$slot]
			if ($id -eq 0) { continue }
			$null = $owned.Add($id)
			$wanted[$BUYLISTS[$donors[[int]$fam.$slot].bodypart][$g]] += $id
		}
	}
}

$buyListsPath = Join-Path $dataDir 'buyLists.xml'
$buyListsEndsNl = Test-EndsWithNewline $buyListsPath
$buyLines = [System.Collections.Generic.List[string]]::new()
foreach ($l in [System.IO.File]::ReadAllLines($buyListsPath)) { $null = $buyLines.Add($l) }

$blocks = @()
for ($i = 0; $i -lt $buyLines.Count; $i++)
{
	if ($buyLines[$i] -notmatch '^\s*<buyList\s+id="(\d+)"') { continue }
	$id = [int]$Matches[1]
	if (-not $wanted.ContainsKey($id)) { continue }
	$end = $i
	while ($end -lt $buyLines.Count -and $buyLines[$end] -notmatch '</buyList>') { $end++ }
	$blocks += @{ id = $id; start = $i; end = $end }
}

$touched = 0
foreach ($b in ($blocks | Sort-Object { $_.start } -Descending))
{
	$keep = [System.Collections.Generic.List[string]]::new()
	$null = $keep.Add(($buyLines[$b.start] -replace '></buyList>\s*$', '>'))

	for ($i = $b.start + 1; $i -le $b.end; $i++)
	{
		$l = $buyLines[$i]
		if ($l -match '</buyList>') { continue }
		# Ours, and about to be written back in order - or a minted id this run no longer has,
		# left behind by an earlier one.
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

if ($touched -ne 36) { throw "expected 36 GM shop armor buy lists, refilled $touched" }
Write-Datapack $buyListsPath $buyLines "`r`n" $buyListsEndsNl
Write-Host "refilled $touched GM shop buy lists with $($owned.Count) pieces"

# ---------------------------------------------------------------------------
# The CI ships build\ as it stands, so the datapack has to land there too.
# ---------------------------------------------------------------------------

if (-not $NoSync)
{
	$buildXml = Join-Path $Repo 'build\gameserver\data\xml'
	if (-not (Test-Path $buildXml)) { Write-Warning "No $buildXml ; skipping the build\ copy." }
	else
	{
		Copy-Item $armorSetsPath (Join-Path $buildXml 'armorSets.xml') -Force
		Copy-Item $buyListsPath (Join-Path $buildXml 'buyLists.xml') -Force

		# A mirror, not just a copy : a file the datapack dropped has to go from build\ too, or the
		# server keeps loading it.
		foreach ($sub in 'items', 'skills')
		{
			$from = $(if ($sub -eq 'items') { $itemsDir } else { $skillsDir })
			$to = Join-Path $buildXml $sub

			$have = @{}
			foreach ($f in Get-ChildItem $from -Filter *.xml)
			{
				$have[$f.Name] = $true
				Copy-Item $f.FullName (Join-Path $to $f.Name) -Force
			}
			foreach ($f in Get-ChildItem $to -Filter *.xml) { if (-not $have.ContainsKey($f.Name)) { Remove-Item $f.FullName -Force } }
		}
		Write-Host "synced items, skills, armorSets.xml and buyLists.xml into build\gameserver\data\xml"
	}
}
