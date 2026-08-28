<#
.SYNOPSIS
	Переносит дроп монстров из data/xml/npcs/*.xml в SQL-таблицу droplist.

.DESCRIPTION
	Читает блоки <drops> из NPC-XML датапака и генерирует sql/droplist.sql
	(схема таблицы + INSERT со всеми строками дропа). С ключом -StripXml
	дополнительно вырезает <drops> из XML — после этого единственным
	источником дропа становится БД, а сервер читает её через DropTable.

	Скрипт идемпотентен: повторный запуск без -StripXml просто перегенерирует
	SQL из того, что осталось в XML (после вырезки — из пустого, поэтому
	порядок такой: сначала прогон без -StripXml, проверка SQL, затем -StripXml).

.PARAMETER Root
	Корень репозитория. По умолчанию вычисляется от расположения скрипта.

.PARAMETER XmlDir
	Каталог с NPC-XML, из которого берётся дроп (канонический — датапак).

.PARAMETER OutSql
	Список файлов, в которые пишется результат.

.PARAMETER StripXml
	Вырезать блоки <drops> из XML в датапаке и в build/.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\droplist\xml_drops_to_sql.ps1
	powershell -ExecutionPolicy Bypass -File tools\droplist\xml_drops_to_sql.ps1 -StripXml
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

if (-not $XmlDir) { $XmlDir = Join-Path $Root 'source\aCis_datapack\data\xml\npcs' }
if (-not $OutSql) {
	$OutSql = @(
		(Join-Path $Root 'source\aCis_datapack\sql\droplist.sql'),
		(Join-Path $Root 'build\sql\droplist.sql')
	)
}

$stripDirs = @(
	(Join-Path $Root 'source\aCis_datapack\data\xml\npcs'),
	(Join-Path $Root 'build\gameserver\data\xml\npcs')
)

$inv = [System.Globalization.CultureInfo]::InvariantCulture
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Format-Double([string] $raw) {
	# 'R' даёт кратчайшую запись, которая читается обратно в тот же double : 25.0 -> 25, 0.0649 -> 0.0649.
	return ([double]::Parse($raw, $inv)).ToString('R', $inv)
}

# ---------------------------------------------------------------- сбор данных

$rows = New-Object System.Collections.Generic.List[string]
$npcWithDrops = 0
$categories = 0
$warnings = New-Object System.Collections.Generic.List[string]

foreach ($file in (Get-ChildItem $XmlDir -Filter *.xml | Sort-Object Name)) {
	$doc = New-Object System.Xml.XmlDocument
	$doc.PreserveWhitespace = $false
	$doc.Load($file.FullName)

	foreach ($npc in $doc.SelectNodes('/list/npc')) {
		$dropsNode = $npc.SelectSingleNode('drops')
		if ($null -eq $dropsNode) { continue }

		$npcId = [int] $npc.GetAttribute('id')
		$catIndex = 0
		$emitted = 0

		foreach ($cat in $dropsNode.SelectNodes('category')) {
			$type = $cat.GetAttribute('type')
			if (-not $type) { $type = 'DROP' }
			if ($type -notin @('DROP', 'SPOIL', 'CURRENCY', 'HERB')) {
				$warnings.Add("npc ${npcId}: неизвестный type='$type', строка пропущена")
				continue
			}

			$rawCatChance = $cat.GetAttribute('chance')
			if (-not $rawCatChance) { $rawCatChance = '100' }
			$catChance = Format-Double $rawCatChance

			$orderId = 0
			foreach ($drop in $cat.SelectNodes('drop')) {
				$itemId = [int] $drop.GetAttribute('itemid')
				$minRaw = $drop.GetAttribute('min')
				$maxRaw = $drop.GetAttribute('max')
				$min = if ($minRaw) { [int] $minRaw } else { 1 }
				$max = if ($maxRaw) { [int] $maxRaw } else { $min }
				$chance = Format-Double $drop.GetAttribute('chance')

				$rows.Add("($npcId,$catIndex,$orderId,'$type',$catChance,$itemId,$min,$max,$chance,1)")
				$orderId++
				$emitted++
			}

			if ($orderId -eq 0) {
				$warnings.Add("npc ${npcId}: категория $catIndex ($type) пуста, пропущена")
				continue
			}

			$categories++
			$catIndex++
		}

		if ($emitted -gt 0) { $npcWithDrops++ }
	}
}

Write-Host "NPC с дропом : $npcWithDrops"
Write-Host "категорий    : $categories"
Write-Host "строк дропа  : $($rows.Count)"
foreach ($w in $warnings) { Write-Warning $w }

if ($rows.Count -eq 0) {
	Write-Warning 'В XML не найдено ни одного <drops> — SQL не перезаписан.'
	if (-not $StripXml) { return }
}

# ------------------------------------------------------------------ вывод SQL

if ($rows.Count -gt 0) {
	$sb = New-Object System.Text.StringBuilder

	$header = @(
		'-- Дроп всех NPC. Сгенерировано tools/droplist/xml_drops_to_sql.ps1 из data/xml/npcs — руками файл не правят,',
		'-- правят таблицу в БД (см. docs/droplist-in-db.md).',
		'--',
		'-- Одна строка = один предмет в одной категории дропа одного NPC. Категория — это группа предметов,',
		'-- которая сначала разыгрывается целиком по category_chance, и только потом внутри неё выбирается предмет',
		'-- по chance : для SPOIL проверяется каждый предмет отдельно, для остальных типов выпадает ровно один.',
		'--',
		'--   npc_id          id NPC из data/xml/npcs',
		'--   category        номер категории внутри NPC ; строки с одинаковым (npc_id, category) — одна категория',
		'--   order_id        порядок предмета внутри категории ; важен только когда сумма chance в категории > 100',
		'--   drop_type       SPOIL | CURRENCY | DROP | HERB — от него зависит, какой Rate* из rates.properties применится',
		'--   category_chance шанс срабатывания всей категории, % ; свойство категории, поэтому одинаков во всех её строках',
		'--                   (сервер берёт значение из строки с наименьшим order_id)',
		'--   item_id         id предмета из data/xml/items',
		'--   min_count       минимальное количество',
		'--   max_count       максимальное количество',
		'--   chance          вес предмета внутри категории, %',
		'--   enabled         0 выключает строку, не удаляя её',
		'--',
		'-- ВНИМАНИЕ: файл сносит таблицу целиком, то есть откатывает любую ручную правку дропа. Он для установки',
		'-- и для отката к ретейлу, а не для регулярного прогона.',
		''
	) -join "`n"

	[void] $sb.Append($header).Append("`n")
	[void] $sb.Append(@'
DROP TABLE IF EXISTS `droplist`;
CREATE TABLE IF NOT EXISTS `droplist` (
	`npc_id` INT UNSIGNED NOT NULL,
	`category` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
	`order_id` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
	`drop_type` ENUM('SPOIL','CURRENCY','DROP','HERB') NOT NULL DEFAULT 'DROP',
	`category_chance` DOUBLE NOT NULL DEFAULT 100,
	`item_id` INT UNSIGNED NOT NULL,
	`min_count` INT UNSIGNED NOT NULL DEFAULT 1,
	`max_count` INT UNSIGNED NOT NULL DEFAULT 1,
	`chance` DOUBLE NOT NULL DEFAULT 0,
	`enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1,
	PRIMARY KEY (`npc_id`,`category`,`order_id`),
	KEY `item_id` (`item_id`)
);
'@.Replace("`r`n", "`n")).Append("`n")

	$columns = 'INSERT INTO `droplist` (`npc_id`,`category`,`order_id`,`drop_type`,`category_chance`,`item_id`,`min_count`,`max_count`,`chance`,`enabled`) VALUES'
	$batch = 500

	for ($i = 0; $i -lt $rows.Count; $i += $batch) {
		$last = [Math]::Min($i + $batch, $rows.Count) - 1
		[void] $sb.Append($columns).Append("`n")
		for ($j = $i; $j -le $last; $j++) {
			[void] $sb.Append($rows[$j]).Append($(if ($j -eq $last) { ";`n" } else { ",`n" }))
		}
	}

	foreach ($out in $OutSql) {
		$dir = Split-Path $out -Parent
		if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
		[System.IO.File]::WriteAllText($out, $sb.ToString(), $utf8NoBom)
		Write-Host "записан $out"
	}
}

# --------------------------------------------------------------- вырезка <drops>

if ($StripXml) {
	$rx = New-Object System.Text.RegularExpressions.Regex('[\t ]*<drops(?:\s*/>|>.*?</drops>)[\t ]*\r?\n', 'Singleline')

	foreach ($dir in $stripDirs) {
		if (-not (Test-Path $dir)) { continue }

		foreach ($file in (Get-ChildItem $dir -Filter *.xml | Sort-Object Name)) {
			$text = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
			$stripped = $rx.Replace($text, '')
			if ($stripped -ne $text) {
				[System.IO.File]::WriteAllText($file.FullName, $stripped, $utf8NoBom)
				Write-Host "очищен $($file.FullName)"
			}
		}
	}
}
