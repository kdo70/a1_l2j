<#
.SYNOPSIS
    Writes the level and the kind of monster into every monster's title in
    data/xml/npcs, out of the texts config/npcs/nameplates.properties holds.

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

    Every word of that - the name of each kind, the "Lvl" and the "*" - is read
    from config/npcs/nameplates.properties, not written here.

    The three named kinds are also painted, orange for quests and raids, red for
    epics, with a color per line - the name and the title carry one each. Those
    colors are NOT written into the datapack : the very same config file holds
    them, and the server reads them back off the title this script writes. A
    "nameColor" or a "titleColor" left in data/xml/npcs therefore means "this one
    NPC, whatever the config says" - so this script clears the colors it owns and
    leaves anything else alone. See docs/npc-name-colors.md.

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

    Levels and aggression are read from the same XML the titles are written to,
    so re-running this after a stat change refreshes the titles. The script is
    idempotent : it rewrites the title attribute outright rather than prepending
    to it. Renaming a kind in the config needs a re-run too, or the datapack
    keeps the old wording and the server stops recognizing it.

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
					Type = ''; Level = 0; AggroRange = 0
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

		# The title is read back the same way it is written, so a second run
		# sees what the first one decided and does not lose the stock marking
		# it replaced.
		$text = ($npc.Title -replace $TITLE_TAIL, '').Trim()

		$kind[$npc.Id] =
			if ($npc.Type -eq 'GrandBoss') { 'epic' }
			elseif ($npc.Type -eq 'RaidBoss') { 'raid' }
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

# --------------------------------------------------------------------------
# Rewrite one file : the title attribute, and away with the nameColor property
# this script used to write there before the color moved to the config.
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
	$stats = @{ Titles = 0; Colors = 0 }

	$id = 0

	foreach ($line in $lines)
	{
		if ($line -match $NPC_LINE)
		{
			$id = [int]$Matches['id']

			if ($kind.ContainsKey($id))
			{
				$title = Get-Title $npcs[$id] $kind[$id]

				if ($Matches['title'] -ne $title)
				{
					$line = $Matches['head'] + $title + $Matches['tail']
					$stats.Titles++
				}
			}

			$out.Add($line)
			continue
		}

		# The colors of a monster live in config/npcs/nameplates.properties and
		# are looked up by the title written just above, so the datapack carries
		# none - but a color this script never chose is somebody's decision
		# about that one NPC, and the server lets it win, so it stays.
		if ($line -match $SET_LINE -and $COLOR_KEYS -contains $Matches['key'] -and $kind.ContainsKey($id) -and $OWNED_COLORS.ContainsKey($Matches['val'].ToUpperInvariant()))
		{
			$stats.Colors++
			continue
		}

		$out.Add($line)
	}

	if ($stats.Titles -gt 0 -or $stats.Colors -gt 0)
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

	$titles = 0
	$colors = 0

	foreach ($file in Get-ChildItem $dir -Filter *.xml)
	{
		$s = Update-File $file.FullName $npcs $kind
		$titles += $s.Titles
		$colors += $s.Colors

		if ($s.Titles -gt 0 -or $s.Colors -gt 0)
		{
			"  {0,-20} titles {1,5}   colors dropped {2,5}" -f $file.Name, $s.Titles, $s.Colors
		}
	}

	"  ---"
	"  {0,-20} titles {1,5}   colors dropped {2,5}{3}" -f 'total', $titles, $colors, $(if ($WhatIf) { '   (nothing written)' } else { '' })
}
