<#
.SYNOPSIS
    Writes the level, the kind of monster and the matching name color into every
    monster's title in data/xml/npcs.

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

    The three named kinds also get a "nameColor", which a patched client paints
    both lines with : orange for quests and raids, red for epics. See
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

    Levels and aggression are read from the same XML the titles are written to,
    so re-running this after a stat change refreshes the titles. The script is
    idempotent : it rewrites the title attribute and the nameColor property
    outright rather than prepending to them.

.PARAMETER NpcDirs
    The data/xml/npcs folders to rewrite. Both copies of the datapack by default
    - the deployed one and the one under source/.

.PARAMETER SpawnlistSql
    sql/spawnlist.sql, read for the minion table.

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
	[string[]] $BossFiles = @('25000-25999.xml', '29000-29999.xml'),
	[switch] $WhatIf
)

$ErrorActionPreference = 'Stop'

# The kinds, in the order they win when an npc could be several of them.
$KINDS = [ordered]@{
	epic         = @{ Prefix = 'Epic Boss';     Color = 'FF0000' }
	epicMinion   = @{ Prefix = 'Epic Fighter';  Color = 'FF0000' }
	raid         = @{ Prefix = 'Raid Boss';     Color = 'FE8B3F' }
	raidMinion   = @{ Prefix = 'Raid Fighter';  Color = 'FE8B3F' }
	quest        = @{ Prefix = 'Quest Monster'; Color = 'FF8000' }
	plain        = @{ Prefix = '';              Color = $null }
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
		$prefix = ($npc.Title -replace '\s*Lvl \d+\*?$', '').Trim()

		$kind[$npc.Id] =
			if ($npc.Type -eq 'GrandBoss') { 'epic' }
			elseif ($npc.Type -eq 'RaidBoss') { 'raid' }
			elseif ($prefix -eq 'Epic Fighter') { 'epicMinion' }
			elseif ($prefix -eq 'Raid Fighter') { 'raidMinion' }
			elseif ($prefix -eq 'Quest Monster') { 'quest' }
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
	$prefix = $KINDS[$kind].Prefix
	$star = if ($npc.AggroRange -gt 0) { '*' } else { '' }

	return ("$prefix Lvl $($npc.Level)$star").Trim()
}

# --------------------------------------------------------------------------
# Rewrite one file : the title attribute, and the nameColor property, which is
# kept right under "type" the way the hand-written ones are.
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

	# What each npc in this file carries today, so a rewrite that changes
	# nothing is not reported as one.
	$has = @{}
	$id = 0
	foreach ($line in $lines)
	{
		if ($line -match $NPC_LINE) { $id = [int]$Matches['id'] }
		elseif ($line -match $SET_LINE -and $Matches['key'] -eq 'nameColor') { $has[$id] = $Matches['val'] }
	}

	$id = 0
	$wanted = $null

	foreach ($line in $lines)
	{
		if ($line -match $NPC_LINE)
		{
			$id = [int]$Matches['id']
			$wanted = if ($kind.ContainsKey($id)) { $KINDS[$kind[$id]].Color } else { $null }

			if ($kind.ContainsKey($id))
			{
				$title = Get-Title $npcs[$id] $kind[$id]

				if ($Matches['title'] -ne $title)
				{
					$line = $Matches['head'] + $title + $Matches['tail']
					$stats.Titles++
				}

				$had = if ($has.ContainsKey($id)) { $has[$id] } else { $null }
				if ($had -ne $wanted)
				{
					$stats.Colors++
				}
			}

			$out.Add($line)
			continue
		}

		if ($line -match $SET_LINE)
		{
			$key = $Matches['key']

			# Ours to own only on the npcs this script names ; a nameColor set
			# by hand on anything else stays where it is. The wanted one goes
			# back right under "type", where the hand-written ones sit.
			if ($key -eq 'nameColor' -and $kind.ContainsKey($id))
			{
				continue
			}

			$out.Add($line)

			if ($key -eq 'type' -and $null -ne $wanted)
			{
				$out.Add($Matches['indent'] + '<set name="nameColor" val="' + $wanted + '"/>')
				$wanted = $null
			}

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
			"  {0,-20} titles {1,5}   colors {2,5}" -f $file.Name, $s.Titles, $s.Colors
		}
	}

	"  ---"
	"  {0,-20} titles {1,5}   colors {2,5}{3}" -f 'total', $titles, $colors, $(if ($WhatIf) { '   (nothing written)' } else { '' })
}
