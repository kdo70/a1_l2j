<#
.SYNOPSIS
	Builds data/xml/itemIcons.xml out of the *grp.dat tables of an Interlude client.

.DESCRIPTION
	Interlude keeps the icon of an item on the client only, so the server can't guess it. This
	script reads the three tables holding one (weapongrp.dat, armorgrp.dat, etcitemgrp.dat) and
	writes the "item id -> icon" pairs into the datapack, where ItemIconData picks them up.

	The .dat files must already be DECRYPTED (a client ships them as "Lineage2Ver41x", which any
	l2encdec build turns into a plain file). See docs/item-icons.md.

	The record layout of those tables isn't parsed field by field - it holds variable arrays this
	script has no schema for. Instead, it looks for the two things it can recognize on its own :
	the "tag + item id" header a record opens with, and the length prefixed "icon.<name>" string a
	record carries. Stray byte sequences look like a header too, so the real ones are told apart by
	three facts - an item id the datapack knows, five small counters right behind it, and ids that
	only ever grow through the file (records are sorted). The longest such chain is the record
	list ; every record then owns the first icon written after it.

	Shields live on weapongrp.dat while the datapack calls them armors, so they are read in their
	own pass.

.PARAMETER GrpDir
	Directory holding the decrypted weapongrp.dat, armorgrp.dat and etcitemgrp.dat.

.PARAMETER ItemsDir
	The data/xml/items directory of the datapack. Defaults to the one of this repository.

.PARAMETER Out
	The XML to write. Defaults to both datapack trees (source and build).

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\icons\grp_to_icons.ps1 -GrpDir C:\decrypted
#>
param(
	[Parameter(Mandatory = $true)][string]$GrpDir,
	[string]$ItemsDir,
	[string[]]$Out
)

$ErrorActionPreference = 'Stop'

$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not $ItemsDir) { $ItemsDir = Join-Path $root 'source\aCis_datapack\data\xml\items' }
if (-not $Out)
{
	$Out = @(
		(Join-Path $root 'source\aCis_datapack\data\xml\itemIcons.xml'),
		(Join-Path $root 'build\gameserver\data\xml\itemIcons.xml')
	)
}

# ---------------------------------------------------------------------------
# Item ids of the datapack, split the way the client tables are
# ---------------------------------------------------------------------------

$weaponIds = New-Object 'System.Collections.Generic.HashSet[int]'
$shieldIds = New-Object 'System.Collections.Generic.HashSet[int]'
$armorIds = New-Object 'System.Collections.Generic.HashSet[int]'
$etcIds = New-Object 'System.Collections.Generic.HashSet[int]'

$itemRx = [regex]'(?s)<item\s+id="(\d+)"\s+type="(\w+)"(.*?)(?=<item\s|</list>)'

foreach ($file in Get-ChildItem $ItemsDir -Filter *.xml)
{
	foreach ($m in $itemRx.Matches([System.IO.File]::ReadAllText($file.FullName)))
	{
		$id = [int]$m.Groups[1].Value

		switch ($m.Groups[2].Value)
		{
			'Weapon' { $null = $weaponIds.Add($id) }
			'EtcItem' { $null = $etcIds.Add($id) }
			'Armor'
			{
				if ($m.Value -match 'name="bodypart"\s+val="lhand"') { $null = $shieldIds.Add($id) }
				else { $null = $armorIds.Add($id) }
			}
		}
	}
}

"datapack: $($weaponIds.Count) weapons, $($shieldIds.Count) shields, $($armorIds.Count) armors, $($etcIds.Count) etcitems"

# ---------------------------------------------------------------------------
# One pass over one table
# ---------------------------------------------------------------------------

function Read-Grp([string] $Path, [int] $Tag, [System.Collections.Generic.HashSet[int]] $Ids)
{
	$bytes = [System.IO.File]::ReadAllBytes($Path)
	$count = [BitConverter]::ToInt32($bytes, 0)

	# Latin-1 maps every byte on the char of the same value, which lets a regex walk the raw file.
	$raw = [System.Text.Encoding]::GetEncoding(28591).GetString($bytes)

	# Length prefixed UTF-16 "icon.<name>" strings.
	$iconPos = New-Object System.Collections.Generic.List[int]
	$iconName = New-Object System.Collections.Generic.List[string]

	foreach ($m in [regex]::Matches($raw, "i\x00c\x00o\x00n\x00\.\x00((?:[0-9A-Za-z_]\x00)+)"))
	{
		$iconPos.Add($m.Index)
		$iconName.Add((($m.Groups[1].Value.ToCharArray() | Where-Object { $_ -ne [char]0 }) -join ''))
	}

	# Record header candidates : the tag, then an item id the datapack knows. The lookahead keeps
	# the matches overlapping, which matters for the weapon tag - it is a run of zeroes.
	$tagStr = ([BitConverter]::GetBytes([int]$Tag) | ForEach-Object { '\x{0:x2}' -f $_ }) -join ''

	$candPos = New-Object System.Collections.Generic.List[int]
	$candId = New-Object System.Collections.Generic.List[int]

	foreach ($m in [regex]::Matches($raw, "(?=$tagStr([\s\S])([\s\S])\x00\x00)"))
	{
		# Every field of the tables is an int32 or an even sized string, so a record never starts odd.
		if (($m.Index % 2) -ne 0) { continue }

		$id = [int][char]$m.Groups[1].Value + 256 * [int][char]$m.Groups[2].Value
		if (-not $Ids.Contains($id)) { continue }

		# The five fields following the id are small counters ; inside a string they would read as huge numbers.
		$ok = $true
		for ($k = 8; $k -le 24; $k += 4)
		{
			if ($m.Index + $k + 4 -gt $bytes.Length) { $ok = $false; break }

			$v = [BitConverter]::ToInt32($bytes, $m.Index + $k)
			if ($v -lt -1 -or $v -gt 100000) { $ok = $false; break }
		}
		if (-not $ok) { continue }

		$candPos.Add($m.Index)
		$candId.Add($id)
	}

	# Longest strictly increasing run of ids, in file order. Ties keep the earliest candidate, so a
	# later copy of an id can't steal the icon of its own record.
	$n = $candPos.Count
	$tailId = New-Object System.Collections.Generic.List[int]
	$tailIdx = New-Object System.Collections.Generic.List[int]
	$prev = New-Object int[] $n

	for ($i = 0; $i -lt $n; $i++)
	{
		$id = $candId[$i]

		$lo = 0
		$hi = $tailId.Count
		while ($lo -lt $hi)
		{
			$mid = [int][Math]::Floor(($lo + $hi) / 2)
			if ($tailId[$mid] -lt $id) { $lo = $mid + 1 } else { $hi = $mid }
		}

		$prev[$i] = if ($lo -gt 0) { $tailIdx[$lo - 1] } else { -1 }

		if ($lo -eq $tailId.Count) { $tailId.Add($id); $tailIdx.Add($i) }
		elseif ($tailId[$lo] -gt $id) { $tailId[$lo] = $id; $tailIdx[$lo] = $i }
	}

	$chain = New-Object System.Collections.Generic.List[int]
	$k = if ($tailIdx.Count -gt 0) { $tailIdx[$tailIdx.Count - 1] } else { -1 }
	while ($k -ge 0) { $chain.Add($k); $k = $prev[$k] }
	$chain.Reverse()

	$result = @{}
	$iconIdx = 0

	foreach ($c in $chain)
	{
		while ($iconIdx -lt $iconPos.Count -and $iconPos[$iconIdx] -lt $candPos[$c]) { $iconIdx++ }
		if ($iconIdx -ge $iconPos.Count) { break }

		$result[$candId[$c]] = $iconName[$iconIdx]
	}

	Write-Host "$(Split-Path $Path -Leaf): $count records, $($iconPos.Count) icons, $($result.Count) of $($Ids.Count) items matched"

	return $result
}

$weaponGrp = Join-Path $GrpDir 'weapongrp.dat'
$armorGrp = Join-Path $GrpDir 'armorgrp.dat'
$etcGrp = Join-Path $GrpDir 'etcitemgrp.dat'

foreach ($file in $weaponGrp, $armorGrp, $etcGrp)
{
	if (-not (Test-Path $file)) { throw "Missing $file." }

	$header = [System.Text.Encoding]::Unicode.GetString([System.IO.File]::ReadAllBytes($file)[0..27])
	if ($header -like 'Lineage2Ver*') { throw "$file is still encrypted ($header) ; decrypt it first." }
}

$icons = @{}
foreach ($pass in (Read-Grp $etcGrp 2 $etcIds), (Read-Grp $weaponGrp 0 $weaponIds), (Read-Grp $weaponGrp 0 $shieldIds), (Read-Grp $armorGrp 1 $armorIds))
{
	foreach ($entry in $pass.GetEnumerator()) { $icons[$entry.Key] = $entry.Value }
}

# ---------------------------------------------------------------------------
# The datapack file
# ---------------------------------------------------------------------------

$sb = New-Object System.Text.StringBuilder
$null = $sb.AppendLine("<?xml version='1.0' encoding='utf-8'?>")
$null = $sb.AppendLine('<!--')
$null = $sb.AppendLine('	Client side icon of every item, used by the generated HTMs - the drop list window for now.')
$null = $sb.AppendLine('')
$null = $sb.AppendLine('	Interlude keeps that table on the client only (weapongrp.dat, armorgrp.dat, etcitemgrp.dat), so')
$null = $sb.AppendLine('	this file is a copy of it, extracted by tools/icons/grp_to_icons.ps1. Regenerate it whenever the')
$null = $sb.AppendLine('	client gains items ; see docs/item-icons.md.')
$null = $sb.AppendLine('')
$null = $sb.AppendLine('	"icon" holds the bare texture name - the server prepends the "icon." package itself. An item')
$null = $sb.AppendLine('	missing from this list falls back on the "default" icon below.')
$null = $sb.AppendLine('-->')
$null = $sb.AppendLine('<list default="noimage">')

foreach ($id in ($icons.Keys | Sort-Object))
{
	$null = $sb.AppendLine("`t<item id=`"$id`" icon=`"$($icons[$id])`" />")
}

$null = $sb.AppendLine('</list>')

foreach ($path in $Out)
{
	[System.IO.File]::WriteAllText($path, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))
	"wrote $($icons.Count) icons to $path"
}
