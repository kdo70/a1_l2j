<#
.SYNOPSIS
	Переносит спавн-лист из data/xml/spawnlist/*.xml в SQL-таблицы spawnlist_*.

.DESCRIPTION
	Читает территории и npcmaker'ы из XML датапака и генерирует sql/spawnlist.sql
	(схемы шести таблиц + INSERT со всеми строками). С ключом -StripXml
	дополнительно удаляет каталог data/xml/spawnlist — после этого единственным
	источником спавна становится БД, а сервер читает её через SpawnManager.

	Скрипт идемпотентен: повторный запуск без -StripXml просто перегенерирует
	SQL из того, что осталось в XML (после удаления — из пустого, поэтому
	порядок такой: сначала прогон без -StripXml, проверка SQL, затем -StripXml).

.PARAMETER Root
	Корень репозитория. По умолчанию вычисляется от расположения скрипта.

.PARAMETER XmlDir
	Каталог со спавн-XML, из которого берутся данные (канонический — датапак).

.PARAMETER OutSql
	Список файлов, в которые пишется результат.

.PARAMETER StripXml
	Удалить каталог spawnlist в датапаке и в build/.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\spawnlist\xml_spawns_to_sql.ps1
	powershell -ExecutionPolicy Bypass -File tools\spawnlist\xml_spawns_to_sql.ps1 -StripXml
#>
[CmdletBinding()]
param(
	[string] $Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
	[string] $XmlDir,
	[string[]] $OutSql,
	[switch] $StripXml
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $XmlDir) { $XmlDir = Join-Path $Root 'source\aCis_datapack\data\xml\spawnlist' }
if (-not $OutSql) {
	$OutSql = @(
		(Join-Path $Root 'source\aCis_datapack\sql\spawnlist.sql'),
		(Join-Path $Root 'build\sql\spawnlist.sql')
	)
}

$stripDirs = @(
	(Join-Path $Root 'source\aCis_datapack\data\xml\spawnlist'),
	(Join-Path $Root 'build\gameserver\data\xml\spawnlist')
)

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Get-SqlString([string] $value) {
	if ([string]::IsNullOrEmpty($value)) { return 'NULL' }
	return "'" + $value.Replace('\', '\\').Replace("'", "''") + "'"
}

# Тот же разбор, что и StringUtil.getTimeStamp : 'no' -> -1, отсутствие -> 0.
function Get-Seconds([string] $value) {
	if ([string]::IsNullOrEmpty($value)) { return 0 }
	if ($value -eq 'no') { return -1 }
	if ($value.EndsWith('hour')) { return [int] $value.Substring(0, $value.Length - 4) * 3600 }
	if ($value.EndsWith('min')) { return [int] $value.Substring(0, $value.Length - 3) * 60 }
	if ($value.EndsWith('sec')) { return [int] $value.Substring(0, $value.Length - 3) }
	return 0
}

function Get-Attr($node, [string] $name) {
	$value = $node.GetAttribute($name)
	if ($null -eq $value) { return '' }
	return $value
}

# ---------------------------------------------------------------- сбор данных

$territoryRows = New-Object System.Collections.Generic.List[string]
$nodeRows = New-Object System.Collections.Generic.List[string]
$makerRows = New-Object System.Collections.Generic.List[string]
$makerParamRows = New-Object System.Collections.Generic.List[string]
$npcRows = New-Object System.Collections.Generic.List[string]
$npcParamRows = New-Object System.Collections.Generic.List[string]
$privateRows = New-Object System.Collections.Generic.List[string]

$knownTerritories = New-Object 'System.Collections.Generic.HashSet[string]'
$knownMakers = New-Object 'System.Collections.Generic.HashSet[string]'
$warnings = New-Object System.Collections.Generic.List[string]

$files = @()
if (Test-Path $XmlDir) { $files = @(Get-ChildItem $XmlDir -Filter *.xml | Sort-Object Name) }

foreach ($file in $files) {
	$doc = New-Object System.Xml.XmlDocument
	$doc.PreserveWhitespace = $false
	$doc.Load($file.FullName)

	foreach ($territory in $doc.SelectNodes('/list/territory')) {
		$name = Get-Attr $territory 'name'

		# Дубли территорий в ретейле встречаются (Zaken) и всегда побайтово равны:
		# в БД имя это первичный ключ, поэтому вторую копию просто отбрасываем.
		if (-not $knownTerritories.Add($name)) {
			$warnings.Add("территория '$name' объявлена повторно ($($file.Name)), дубль пропущен")
			continue
		}

		$territoryRows.Add("($(Get-SqlString $name),$([int](Get-Attr $territory 'minZ')),$([int](Get-Attr $territory 'maxZ')))")

		$order = 0
		foreach ($point in $territory.SelectNodes('node')) {
			$nodeRows.Add("($(Get-SqlString $name),$order,$([int](Get-Attr $point 'x')),$([int](Get-Attr $point 'y')))")
			$order++
		}

		if ($order -lt 3) { $warnings.Add("территория '$name' описана $order точками, триангуляция не выйдет") }
	}

	foreach ($maker in $doc.SelectNodes('/list/npcmaker')) {
		$makerName = Get-Attr $maker 'name'

		if (-not $knownMakers.Add($makerName)) {
			$warnings.Add("npcmaker '$makerName' объявлен повторно ($($file.Name)), дубль пропущен")
			continue
		}

		$makerAi = $maker.SelectSingleNode('ai')
		$makerType = if ($null -ne $makerAi) { Get-Attr $makerAi 'type' } else { '' }
		if ([string]::IsNullOrEmpty($makerType)) { $makerType = 'default_maker' }

		$makerRows.Add(('({0},{1},{2},{3},{4},{5},{6},1)' -f
			(Get-SqlString $makerName),
			(Get-SqlString (Get-Attr $maker 'territory')),
			(Get-SqlString (Get-Attr $maker 'ban')),
			[int](Get-Attr $maker 'maximumNpcs'),
			(Get-SqlString $makerType),
			(Get-SqlString (Get-Attr $maker 'event')),
			(Get-SqlString (Get-Attr $maker 'spawnTime'))))

		if ($null -ne $makerAi) {
			foreach ($param in $makerAi.SelectNodes('set')) {
				$makerParamRows.Add("($(Get-SqlString $makerName),$(Get-SqlString (Get-Attr $param 'name')),$(Get-SqlString (Get-Attr $param 'val')))")
			}
		}

		$npcOrder = 0
		foreach ($npc in $maker.SelectNodes('npc')) {
			$npcRows.Add(('({0},{1},{2},{3},{4},{5},{6},{7},{8},1)' -f
				(Get-SqlString $makerName),
				$npcOrder,
				[int](Get-Attr $npc 'id'),
				[int](Get-Attr $npc 'total'),
				(Get-Seconds (Get-Attr $npc 'respawn')),
				(Get-Seconds (Get-Attr $npc 'respawnRand')),
				(Get-SqlString (Get-Attr $npc 'pos')),
				(Get-SqlString (Get-Attr $npc 'dbName')),
				(Get-SqlString (Get-Attr $npc 'dbSaving'))))

			foreach ($ai in $npc.SelectNodes('ai')) {
				foreach ($param in $ai.SelectNodes('set')) {
					$npcParamRows.Add("($(Get-SqlString $makerName),$npcOrder,$(Get-SqlString (Get-Attr $param 'name')),$(Get-SqlString (Get-Attr $param 'val')))")
				}
			}

			$privateOrder = 0
			foreach ($privates in $npc.SelectNodes('privates')) {
				foreach ($private in $privates.SelectNodes('private')) {
					$privateRows.Add(('({0},{1},{2},{3},{4},{5})' -f
						(Get-SqlString $makerName),
						$npcOrder,
						$privateOrder,
						[int](Get-Attr $private 'id'),
						[int](Get-Attr $private 'weight'),
						(Get-Seconds (Get-Attr $private 'respawn'))))
					$privateOrder++
				}
			}

			$npcOrder++
		}

		if ($npcOrder -eq 0) { $warnings.Add("npcmaker '$makerName' не содержит ни одного <npc>") }
	}
}

Write-Host "файлов       : $($files.Count)"
Write-Host "территорий   : $($territoryRows.Count) ($($nodeRows.Count) точек)"
Write-Host "npcmaker'ов  : $($makerRows.Count) ($($makerParamRows.Count) AI-параметров)"
Write-Host "строк спавна : $($npcRows.Count) ($($npcParamRows.Count) AI-параметров, $($privateRows.Count) привэйтов)"
foreach ($w in $warnings) { Write-Warning $w }

if ($makerRows.Count -eq 0) {
	Write-Warning 'В XML не найдено ни одного <npcmaker> — SQL не перезаписан.'
	if (-not $StripXml) { return }
}

# ------------------------------------------------------------------ вывод SQL

if ($makerRows.Count -gt 0) {
	$sb = New-Object System.Text.StringBuilder

	$header = @(
		'-- Спавн-лист сервера. Сгенерировано tools/spawnlist/xml_spawns_to_sql.ps1 из data/xml/spawnlist — руками файл',
		'-- не правят, правят таблицы в БД (см. docs/spawnlist-in-db.md).',
		'--',
		'-- Шесть таблиц описывают то же, что описывал XML :',
		'--',
		'--   spawnlist_territories      многоугольник-территория (имя + пределы по Z)',
		'--   spawnlist_territory_nodes  вершины этого многоугольника по порядку обхода',
		'--   spawnlist_makers           группа спавна : территория, лимит NPC, тип maker-скрипта, событие',
		'--   spawnlist_maker_params     AI-параметры maker-скрипта',
		'--   spawnlist_npcs             строка спавна : какой NPC, сколько, где, с каким респауном',
		'--   spawnlist_npc_params       AI-параметры конкретной строки спавна (flee_x, MoveAroundDistance, ...)',
		'--   spawnlist_npc_privates     минионы строки спавна',
		'--',
		'-- Респаун везде хранится в СЕКУНДАХ : -1 это ретейльное respawn="no" (не возрождается),',
		'-- 0 — респаун не задан. Обе величины сервер приводит к «без респауна».',
		'--',
		'-- ВНИМАНИЕ: файл сносит таблицы целиком, то есть откатывает любую ручную правку спавна. Он для установки',
		'-- и для отката к ретейлу, а не для регулярного прогона. Ручной спавн GM-а живёт в отдельной таблице',
		'-- spawnlist_custom (sql/spawnlist_custom.sql) и этим файлом не затрагивается.',
		''
	) -join "`n"

	[void] $sb.Append($header).Append("`n")
	[void] $sb.Append(@'
DROP TABLE IF EXISTS `spawnlist_npc_privates`;
DROP TABLE IF EXISTS `spawnlist_npc_params`;
DROP TABLE IF EXISTS `spawnlist_npcs`;
DROP TABLE IF EXISTS `spawnlist_maker_params`;
DROP TABLE IF EXISTS `spawnlist_makers`;
DROP TABLE IF EXISTS `spawnlist_territory_nodes`;
DROP TABLE IF EXISTS `spawnlist_territories`;

CREATE TABLE IF NOT EXISTS `spawnlist_territories` (
	`name` VARCHAR(64) NOT NULL,
	`min_z` INT NOT NULL DEFAULT 0,
	`max_z` INT NOT NULL DEFAULT 0,
	PRIMARY KEY (`name`)
);

CREATE TABLE IF NOT EXISTS `spawnlist_territory_nodes` (
	`territory` VARCHAR(64) NOT NULL,
	`order_id` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
	`x` INT NOT NULL,
	`y` INT NOT NULL,
	PRIMARY KEY (`territory`,`order_id`)
);

CREATE TABLE IF NOT EXISTS `spawnlist_makers` (
	`name` VARCHAR(64) NOT NULL,
	`territory` TEXT NOT NULL,
	`ban_territory` TEXT,
	`maximum_npcs` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
	`maker_type` VARCHAR(64) NOT NULL DEFAULT 'default_maker',
	`event` VARCHAR(64) DEFAULT NULL,
	`spawn_time` VARCHAR(64) DEFAULT NULL,
	`enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1,
	PRIMARY KEY (`name`)
);

CREATE TABLE IF NOT EXISTS `spawnlist_maker_params` (
	`maker` VARCHAR(64) NOT NULL,
	`name` VARCHAR(64) NOT NULL,
	`val` VARCHAR(255) NOT NULL DEFAULT '',
	PRIMARY KEY (`maker`,`name`)
);

CREATE TABLE IF NOT EXISTS `spawnlist_npcs` (
	`maker` VARCHAR(64) NOT NULL,
	`order_id` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
	`npc_id` INT UNSIGNED NOT NULL,
	`total` SMALLINT UNSIGNED NOT NULL DEFAULT 1,
	`respawn` INT NOT NULL DEFAULT 0,
	`respawn_rand` INT NOT NULL DEFAULT 0,
	`pos` VARCHAR(255) DEFAULT NULL,
	`db_name` VARCHAR(80) DEFAULT NULL,
	`db_saving` VARCHAR(64) DEFAULT NULL,
	`enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1,
	PRIMARY KEY (`maker`,`order_id`),
	KEY `npc_id` (`npc_id`),
	KEY `db_name` (`db_name`)
);

CREATE TABLE IF NOT EXISTS `spawnlist_npc_params` (
	`maker` VARCHAR(64) NOT NULL,
	`npc_order` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
	`name` VARCHAR(64) NOT NULL,
	`val` VARCHAR(255) NOT NULL DEFAULT '',
	PRIMARY KEY (`maker`,`npc_order`,`name`)
);

CREATE TABLE IF NOT EXISTS `spawnlist_npc_privates` (
	`maker` VARCHAR(64) NOT NULL,
	`npc_order` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
	`order_id` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
	`npc_id` INT UNSIGNED NOT NULL,
	`weight` SMALLINT NOT NULL DEFAULT 0,
	`respawn` INT NOT NULL DEFAULT 0,
	PRIMARY KEY (`maker`,`npc_order`,`order_id`)
);
'@.Replace("`r`n", "`n")).Append("`n")

	$batch = 500

	function Add-Insert($builder, [string] $columns, $rows) {
		if ($rows.Count -eq 0) { return }

		for ($i = 0; $i -lt $rows.Count; $i += $batch) {
			$last = [Math]::Min($i + $batch, $rows.Count) - 1
			[void] $builder.Append($columns).Append("`n")
			for ($j = $i; $j -le $last; $j++) {
				[void] $builder.Append($rows[$j]).Append($(if ($j -eq $last) { ";`n" } else { ",`n" }))
			}
		}
	}

	Add-Insert $sb 'INSERT INTO `spawnlist_territories` (`name`,`min_z`,`max_z`) VALUES' $territoryRows
	Add-Insert $sb 'INSERT INTO `spawnlist_territory_nodes` (`territory`,`order_id`,`x`,`y`) VALUES' $nodeRows
	Add-Insert $sb 'INSERT INTO `spawnlist_makers` (`name`,`territory`,`ban_territory`,`maximum_npcs`,`maker_type`,`event`,`spawn_time`,`enabled`) VALUES' $makerRows
	Add-Insert $sb 'INSERT INTO `spawnlist_maker_params` (`maker`,`name`,`val`) VALUES' $makerParamRows
	Add-Insert $sb 'INSERT INTO `spawnlist_npcs` (`maker`,`order_id`,`npc_id`,`total`,`respawn`,`respawn_rand`,`pos`,`db_name`,`db_saving`,`enabled`) VALUES' $npcRows
	Add-Insert $sb 'INSERT INTO `spawnlist_npc_params` (`maker`,`npc_order`,`name`,`val`) VALUES' $npcParamRows
	Add-Insert $sb 'INSERT INTO `spawnlist_npc_privates` (`maker`,`npc_order`,`order_id`,`npc_id`,`weight`,`respawn`) VALUES' $privateRows

	foreach ($out in $OutSql) {
		$dir = Split-Path $out -Parent
		if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
		[System.IO.File]::WriteAllText($out, $sb.ToString(), $utf8NoBom)
		Write-Host "записан $out"
	}
}

# ------------------------------------------------------------ удаление XML

if ($StripXml) {
	foreach ($dir in $stripDirs) {
		if (-not (Test-Path $dir)) { continue }

		Remove-Item -Recurse -Force $dir
		Write-Host "удалён $dir"
	}
}
