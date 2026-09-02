<#
.SYNOPSIS
    Sorts every monster in data/xml/npcs into its kind and writes that, and only
    that, into its "monsterKind" property.

.DESCRIPTION
    The title an NPC carries above its head is the only line a server can write
    freely (ServerSideNpcTitle is on), so it is where the level goes :

        Lvl 80                 an ordinary monster
        Lvl 80*                ... that is aggressive - aggroRange > 0, which is
                               exactly what Monster.isAggressive() reads
        Quest Monster Lvl 80*  a monster a quest needs
        Raid Boss Lvl 80*      a raid boss
        Raid Fighter Lvl 80*   its minion
        Epic Boss Lvl 80*      a grand boss
        Epic Fighter Lvl 80*   its minion

    None of that is written here. The SERVER builds those titles, out of
    config/npcs/nameplates.properties and the kind this script leaves behind, for
    every monster whose own title in the datapack is empty - so this script
    clears the ones it used to write and puts the kind in their place. A monster
    carrying a title of its own keeps it, words for words.

    The three named kinds are also painted, orange for quests and raids, red for
    epics, with a color per line - the name and the title carry one each. Those
    colors come from the very same config file, by the very same kind, and are
    not written into the datapack either. A "nameColor" or a "titleColor" left in
    data/xml/npcs therefore means "this one NPC, whatever the config says" - so
    this script clears the colors it owns and leaves anything else alone. See
    docs/npc-name-colors.md.

    Who is what :

      - epic          type GrandBoss
      - raid          type RaidBoss
      - minion        the npc is spawned as a "private" of another one - the
                      table is sql/spawnlist.sql, spawnlist_npc_privates joined
                      to spawnlist_npcs - and its master is an epic or a raid.
                      The stock title "Raid Fighter" counts too : it is how the
                      client itself marks them.
                      Neither catches a minion that only an AI script spawns
                      (Baium's archangels, Antharas' dragon bombers), so inside
                      the two files that hold nothing but bosses and their
                      escorts - 25000-25999 and 29000-29999 - a monster left
                      over takes the kind of the last boss declared above it.
                      Checked entry by entry: every leftover in those two files
                      is an escort of exactly that boss.
      - quest         the stock title is "Quest Monster", again the client's own
                      marking, or the npc is a private of one such monster.

    The script is idempotent : a second run in a row changes nothing, because the
    kind it settled on is read straight back out of the property it wrote. Levels
    and aggression are the server's to read now, so a stat change needs no run at
    all, and neither does a change of wording in the config.

    Re-run it when the spawn list changes, or when a monster is added : those are
    what decide the kinds.

.PARAMETER NpcDirs
    The data/xml/npcs folders to rewrite. Both copies of the datapack by default
    - the deployed one and the one under source/.

.PARAMETER SpawnlistSql
    sql/spawnlist.sql, read for the minion table.

.PARAMETER NameplatesConfig
    config/npcs/nameplates.properties, holding the words every kind is written
    with and the colors its two lines are painted with.

.PARAMETER WhatIf
    Report what would change and write nothing.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\datapack\npc_level_titles.ps1
#>
param(
	[string[]] $NpcDirs = @(
		"$PSScriptRoot\..\..\build\gameserver\data\xml\npcs",
		"$PSScriptRoot\..\..\source\aCis_datapack\data\xml\npcs"
	),
	[string] $SpawnlistSql = "$PSScriptRoot\..\..\source\aCis_datapack\sql\spawnlist.sql",
	[string] $NameplatesConfig = "$PSScriptRoot\..\..\source\aCis_gameserver\config\npcs\nameplates.properties",
	[string[]] $BossFiles = @('25000-25999.xml', '29000-29999.xml'),
	[switch] $WhatIf
)

$ErrorActionPreference = 'Stop'

# The kinds, in the order they win when an npc could be several of them. Each
# one carries the name it goes by in the config file, the words and the color it
# falls back to when the config says nothing, and whether its own words are read
# back out of a title - which is how the client's own markings, and this
# script's previous run, are recognized.
$KIND_DEFAULTS = [ordered]@{
	epic       = @{ Key = 'Epic';       Text = 'Epic Boss';     Color = 'FF0000'; FromTitle = $false }
	epicMinion = @{ Key = 'EpicMinion'; Text = 'Epic Fighter';  Color = 'FF0000'; FromTitle = $true }
	raid       = @{ Key = 'Raid';       Text = 'Raid Boss';     Color = 'FE8B3F'; FromTitle = $false }
	raidMinion = @{ Key = 'RaidMinion'; Text = 'Raid Fighter';  Color = 'FE8B3F'; FromTitle = $true }
	quest      = @{ Key = 'Quest';      Text = 'Quest Monster'; Color = 'FF8000'; FromTitle = $true }
	plain      = @{ Key = 'Plain';      Text = '';              Color = '';       FromTitle = $false }
}

# The two properties the color of a monster used to be written into. Both are
# the server's business now, so both are cleared from the datapack.
$COLOR_KEYS = @('nameColor', 'titleColor')

# What the stock client calls these two kinds, in the titles data/xml/npcs came
# to hold from npcname-e.dat. They are read on top of the configured words, so
# renaming a kind in the config does not throw away the very marking the whole
# sorting rests on.
$STOCK_TEXTS = [ordered]@{
	'Quest Monster' = 'quest'
	'Raid Fighter'  = 'raidMinion'
}

# Everything deriving from Monster, plus FriendlyMonster, which derives from
# Attackable but is a monster all the same.
$MONSTER_TYPES = @(
	'Monster', 'RaidBoss', 'GrandBoss', 'FestivalMonster', 'FeedableBeast',
	'Chest', 'HalishaChest', 'FriendlyMonster'
)

$NPC_LINE = '^(?<head>\s*<npc\s+id="(?<id>\d+)".*?title=")(?<title>[^"]*)(?<tail>".*)$'
$SET_LINE = '^(?<indent>\s*)<set\s+name="(?<key>[^"]+)"\s+val="(?<val>[^"]*)"\s*/>\s*$'

# --------------------------------------------------------------------------
# The config file : every word a title is made of, and every color.
# --------------------------------------------------------------------------
function Read-Properties([string] $path)
{
	$props = @{}

	foreach ($line in [System.IO.File]::ReadLines($path))
	{
		$entry = $line.Trim()

		if ($entry -eq '' -or $entry.StartsWith('#') -or $entry.StartsWith('!'))
		{
			continue
		}

		$eq = $entry.IndexOf('=')
		if ($eq -lt 1)
		{
			continue
		}

		$props[$entry.Substring(0, $eq).Trim()] = $entry.Substring($eq + 1).Trim()
	}

	return $props
}

$props = Read-Properties (Resolve-Path $NameplatesConfig)

function Get-Prop([string] $key, [string] $fallback)
{
	if ($props.ContainsKey($key))
	{
		return $props[$key]
	}

	return $fallback
}

$LEVEL_LABEL = Get-Prop 'MonsterLevelLabel' 'Lvl'
$AGGRESSIVE_MARK = Get-Prop 'MonsterAggressiveMark' '*'

if ($LEVEL_LABEL -eq '')
{
	throw "MonsterLevelLabel is empty in $NameplatesConfig ; the level needs a word to be announced with."
}

$KINDS = [ordered]@{}

foreach ($name in $KIND_DEFAULTS.Keys)
{
	$default = $KIND_DEFAULTS[$name]
	$color = (Get-Prop ('Monster' + $default.Key + 'NameColor') $default.Color).ToUpperInvariant()

	$KINDS[$name] = @{
		Text       = Get-Prop ('Monster' + $default.Key + 'Text') $default.Text
		Color      = $color
		# Left out of the config, the title takes the name's color, the way the server reads it.
		TitleColor = (Get-Prop ('Monster' + $default.Key + 'TitleColor') $color).ToUpperInvariant()
	}
}

# The words a title is recognized by : what the config calls each kind, plus the
# client's own markings for the two kinds it marks itself.
$TEXT_TO_KIND = @{}

foreach ($name in $KIND_DEFAULTS.Keys)
{
	$text = $KINDS[$name].Text

	if ($KIND_DEFAULTS[$name].FromTitle -and $text -ne '' -and -not $TEXT_TO_KIND.ContainsKey($text))
	{
		$TEXT_TO_KIND[$text] = $name
	}
}

foreach ($text in $STOCK_TEXTS.Keys)
{
	if (-not $TEXT_TO_KIND.ContainsKey($text))
	{
		$TEXT_TO_KIND[$text] = $STOCK_TEXTS[$text]
	}
}

# The other way round : what a "monsterKind" property holds -> the kind itself.
$KEY_TO_KIND = @{}

foreach ($name in $KIND_DEFAULTS.Keys)
{
	$KEY_TO_KIND[$KIND_DEFAULTS[$name].Key] = $name
}

# The colors this script owns : the ones the config gives a kind, and the ones
# it used to write before they moved to the config. A "nameColor" holding one of
# them is this script's own leftover and goes ; anything else is a hand made
# override of one NPC and stays.
$OWNED_COLORS = @{}

foreach ($name in $KIND_DEFAULTS.Keys)
{
	foreach ($color in @($KIND_DEFAULTS[$name].Color, $KINDS[$name].Color, $KINDS[$name].TitleColor))
	{
		if ($color -ne '')
		{
			$OWNED_COLORS[$color.ToUpperInvariant()] = $true
		}
	}
}

# "<words> <label> <level><mark>", read from the back : this is what tells a
# title this script wrote from the bare marking the client left behind.
$MARK_PATTERN = if ($AGGRESSIVE_MARK -eq '') { '' } else { '(?:' + [regex]::Escape($AGGRESSIVE_MARK) + ')?' }
$TITLE_TAIL = '\s*' + [regex]::Escape($LEVEL_LABEL) + ' \d+' + $MARK_PATTERN + '$'

# --------------------------------------------------------------------------
# Read every npc : id, kind-deciding stock title, type, level, aggro range.
# --------------------------------------------------------------------------
function Read-Npcs([string] $dir)
{
	$npcs = @{}

	foreach ($file in Get-ChildItem $dir -Filter *.xml)
	{
		$cur = $null
		$order = 0

		foreach ($line in [System.IO.File]::ReadLines($file.FullName))
		{
			if ($line -match $NPC_LINE)
			{
				$cur = [pscustomobject]@{
					Id = [int]$Matches['id']; Title = $Matches['title']
					Type = ''; Level = 0; AggroRange = 0; Kind = ''
					File = $file.Name; Order = $order++
				}
				$npcs[$cur.Id] = $cur
			}
			elseif ($null -ne $cur -and $line -match $SET_LINE)
			{
				switch ($Matches['key'])
				{
					'type' { $cur.Type = $Matches['val'] }
					'level' { $cur.Level = [int]$Matches['val'] }
					'aggroRange' { $cur.AggroRange = [int]$Matches['val'] }
					'monsterKind' { $cur.Kind = $Matches['val'] }
				}
			}
		}
	}

	return $npcs
}

# --------------------------------------------------------------------------
# minion id -> ids of the npcs it is spawned under. spawnlist_npc_privates
# points at a spawn line by (maker, npc_order), and that line names the master.
# --------------------------------------------------------------------------
function Read-Minions([string] $sql)
{
	$masterOf = @{}
	$privates = New-Object System.Collections.ArrayList
	$table = ''

	foreach ($line in [System.IO.File]::ReadLines($sql))
	{
		if ($line -match '^INSERT INTO `(?<t>[a-z_]+)`')
		{
			$table = $Matches['t']
		}
		elseif ($table -eq 'spawnlist_npcs' -and $line -match "^\('(?<maker>(?:[^']|'')*)',(?<order>\d+),(?<npc>\d+),")
		{
			$masterOf[$Matches['maker'] + '|' + $Matches['order']] = [int]$Matches['npc']
		}
		elseif ($table -eq 'spawnlist_npc_privates' -and $line -match "^\('(?<maker>(?:[^']|'')*)',(?<order>\d+),\d+,(?<npc>\d+),")
		{
			[void]$privates.Add(@{ Key = $Matches['maker'] + '|' + $Matches['order']; Npc = [int]$Matches['npc'] })
		}
	}

	$minions = @{}
	foreach ($p in $privates)
	{
		if (-not $masterOf.ContainsKey($p.Key))
		{
			continue
		}

		if (-not $minions.ContainsKey($p.Npc))
		{
			$minions[$p.Npc] = @{}
		}
		$minions[$p.Npc][$masterOf[$p.Key]] = $true
	}

	return $minions
}

# --------------------------------------------------------------------------
# id -> kind. Minions inherit from their master, so masters are settled first.
# --------------------------------------------------------------------------
function Get-Kinds($npcs, $minions)
{
	$kind = @{}

	foreach ($npc in $npcs.Values)
	{
		if ($MONSTER_TYPES -notcontains $npc.Type)
		{
			continue
		}

		# What a previous run settled on, and - for the very first one, before the
		# kind had a property of its own - the marking left in the title, either
		# the client's own or the one this script wrote over it.
		$marked = $KEY_TO_KIND[$npc.Kind]
		$text = ($npc.Title -replace $TITLE_TAIL, '').Trim()

		$kind[$npc.Id] =
			if ($npc.Type -eq 'GrandBoss') { 'epic' }
			elseif ($npc.Type -eq 'RaidBoss') { 'raid' }
			elseif ($null -ne $marked) { $marked }
			elseif ($text -ne '' -and $TEXT_TO_KIND.ContainsKey($text)) { $TEXT_TO_KIND[$text] }
			else { 'plain' }
	}

	# A minion the stock client does not mark takes its master's kind. Masters
	# can themselves be minions (an epic's minion spawning its own), so this
	# settles down over a few passes rather than one.
	for ($pass = 0; $pass -lt 8; $pass++)
	{
		$changed = $false

		foreach ($id in @($minions.Keys))
		{
			if (-not $kind.ContainsKey($id) -or $kind[$id] -ne 'plain')
			{
				continue
			}

			foreach ($master in $minions[$id].Keys)
			{
				if (-not $kind.ContainsKey($master))
				{
					continue
				}

				$inherited = switch ($kind[$master])
				{
					'epic' { 'epicMinion' }
					'epicMinion' { 'epicMinion' }
					'raid' { 'raidMinion' }
					'raidMinion' { 'raidMinion' }
					'quest' { 'quest' }
					default { $null }
				}

				if ($null -ne $inherited)
				{
					$kind[$id] = $inherited
					$changed = $true
					break
				}
			}
		}

		if (-not $changed)
		{
			break
		}
	}

	# The boss blocks : whatever is still plain there escorts the boss above it.
	foreach ($file in $BossFiles)
	{
		$boss = $null

		foreach ($npc in ($npcs.Values | Where-Object { $_.File -eq $file } | Sort-Object Order))
		{
			if (-not $kind.ContainsKey($npc.Id))
			{
				continue
			}

			switch ($kind[$npc.Id])
			{
				'epic' { $boss = 'epicMinion' }
				'raid' { $boss = 'raidMinion' }
				'plain' { if ($null -ne $boss) { $kind[$npc.Id] = $boss } }
			}
		}
	}

	return $kind
}

function Get-Title($npc, [string] $kind)
{
	$text = $KINDS[$kind].Text
	$mark = if ($npc.AggroRange -gt 0) { $AGGRESSIVE_MARK } else { '' }

	return ("$text $LEVEL_LABEL $($npc.Level)$mark").Trim()
}

# True when the given title is one nobody typed by hand : either the shape this
# script used to write into the datapack before the server started building it -
# "<words> <label> <level><mark>" and nothing else - or one of the two bare
# markings the stock client left behind, whose meaning now lives in the
# "monsterKind" property instead. Anything else is somebody's own words.
function Test-GeneratedTitle([string] $title)
{
	if ($STOCK_TEXTS.Contains($title))
	{
		return $true
	}

	foreach ($name in $KINDS.Keys)
	{
		$text = $KINDS[$name].Text
		$head = if ($text -eq '') { '' } else { [regex]::Escape($text) + ' ' }

		if ($title -match ('^' + $head + [regex]::Escape($LEVEL_LABEL) + ' \d+' + $MARK_PATTERN + '$'))
		{
			return $true
		}
	}

	return $false
}

# --------------------------------------------------------------------------
# Rewrite one file : in with the "monsterKind" property, out with the generated
# title and the colors that both moved to the server.
# --------------------------------------------------------------------------
function Update-File([string] $path, $npcs, $kind)
{
	# Line endings and the missing newline at the end of the datapack's files
	# are kept as they are, so the diff is only the lines this script means.
	$raw = [System.IO.File]::ReadAllText($path)
	$newline = if ($raw -match "\r\n") { "`r`n" } else { "`n" }
	$endsWithNewline = $raw.EndsWith("`n")

	$lines = [System.IO.File]::ReadAllLines($path)
	$out = New-Object System.Collections.Generic.List[string]
	$stats = @{ Titles = 0; Kinds = 0; Colors = 0 }

	$id = 0
	$wanted = $null

	foreach ($line in $lines)
	{
		if ($line -match $NPC_LINE)
		{
			$id = [int]$Matches['id']
			$wanted = $null

			if ($kind.ContainsKey($id))
			{
				$wanted = if ($kind[$id] -eq 'plain') { $null } else { $KIND_DEFAULTS[$kind[$id]].Key }

				# The title is the server's to build, out of the kind written
				# just below and the config - so the datapack carries none. Only
				# a title this script wrote is cleared : a hand written one is
				# somebody's decision about that one monster, and the server
				# lets it win, so it stays.
				if ($Matches['title'] -ne '' -and (Test-GeneratedTitle $Matches['title']))
				{
					$line = $Matches['head'] + $Matches['tail']
					$stats.Titles++
				}

				if ($npcs[$id].Kind -ne [string]$wanted)
				{
					$stats.Kinds++
				}
			}

			$out.Add($line)
			continue
		}

		if ($line -match $SET_LINE)
		{
			$key = $Matches['key']

			# Ours to own, and rewritten from scratch rather than edited.
			if ($key -eq 'monsterKind' -and $kind.ContainsKey($id))
			{
				continue
			}

			# The colors of a monster live in config/npcs/nameplates.properties
			# and are looked up by the kind, so the datapack carries none - but a
			# color this script never chose is, again, somebody's decision, and
			# it stays.
			if ($COLOR_KEYS -contains $key -and $kind.ContainsKey($id) -and $OWNED_COLORS.ContainsKey($Matches['val'].ToUpperInvariant()))
			{
				$stats.Colors++
				continue
			}

			$out.Add($line)

			# The kind goes right under "type", where a reader looks for what an
			# NPC is.
			if ($key -eq 'type' -and $null -ne $wanted)
			{
				$out.Add($Matches['indent'] + '<set name="monsterKind" val="' + $wanted + '"/>')
				$wanted = $null
			}

			continue
		}

		$out.Add($line)
	}

	if ($stats.Titles -gt 0 -or $stats.Kinds -gt 0 -or $stats.Colors -gt 0)
	{
		if (-not $WhatIf)
		{
			# The datapack is UTF-8 without a BOM, and stays that way.
			$text = [string]::Join($newline, $out) + $(if ($endsWithNewline) { $newline } else { '' })
			[System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding $false))
		}
	}

	return $stats
}

# --------------------------------------------------------------------------

"Titles read from $((Resolve-Path $NameplatesConfig).Path)."

foreach ($name in $KINDS.Keys)
{
	"  {0,-12} {1,-22} name {2,-8} title {3}" -f $name, (Get-Title ([pscustomobject]@{ Level = 80; AggroRange = 1 }) $name), $(if ($KINDS[$name].Color -eq '') { '-' } else { $KINDS[$name].Color }), $(if ($KINDS[$name].TitleColor -eq '') { '-' } else { $KINDS[$name].TitleColor })
}

""

$minions = Read-Minions (Resolve-Path $SpawnlistSql)
"$($minions.Count) npc ids are spawned as minions."

foreach ($dir in $NpcDirs)
{
	$dir = (Resolve-Path $dir).Path
	""
	"=== $dir ==="

	$npcs = Read-Npcs $dir
	$kind = Get-Kinds $npcs $minions

	foreach ($k in $KINDS.Keys)
	{
		$n = ($kind.Values | Where-Object { $_ -eq $k }).Count
		"  {0,-12} {1,5}" -f $k, $n
	}

	# Not "$kinds" : PowerShell tells no variable apart by case, and that one
	# would be the $KINDS table read by every function below.
	$titlesCleared = 0
	$kindsWritten = 0
	$colorsDropped = 0

	foreach ($file in Get-ChildItem $dir -Filter *.xml)
	{
		$s = Update-File $file.FullName $npcs $kind
		$titlesCleared += $s.Titles
		$kindsWritten += $s.Kinds
		$colorsDropped += $s.Colors

		if ($s.Titles -gt 0 -or $s.Kinds -gt 0 -or $s.Colors -gt 0)
		{
			"  {0,-20} kinds {1,5}   titles cleared {2,5}   colors dropped {3,5}" -f $file.Name, $s.Kinds, $s.Titles, $s.Colors
		}
	}

	"  ---"
	"  {0,-20} kinds {1,5}   titles cleared {2,5}   colors dropped {3,5}{4}" -f 'total', $kindsWritten, $titlesCleared, $colorsDropped, $(if ($WhatIf) { '   (nothing written)' } else { '' })
}
