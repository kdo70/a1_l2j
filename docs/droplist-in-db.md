# Дроп в базе данных

Весь дроп монстров и РБ переехал из `data/xml/npcs/*.xml` в таблицу `droplist`. XML больше не содержит
блоков `<drops>` — их там просто нет, и парсер NPC про них не знает. Править дроп теперь можно на живом
сервере одним `UPDATE` плюс `//reload drop`, без пересборки датапака и без рестарта.

Соседние фичи того же рода: навыки и цвет названия предмета — [item-skills.md](item-skills.md),
характеристики с сервера — [item-stats-from-server.md](item-stats-from-server.md).

Показ этого дропа игроку (shift+click по монстру) — [droplist-window.md](droplist-window.md).

---

## 1. Таблица

Схема лежит в `sql/droplist.sql` (там же и все ~46 500 строк ретейльного дропа).

| колонка | тип | что |
|---|---|---|
| `npc_id` | INT | id NPC, тот же, что в `data/xml/npcs` |
| `category` | SMALLINT | номер категории внутри NPC; строки с одинаковым `(npc_id, category)` — одна категория |
| `order_id` | SMALLINT | порядок предмета внутри категории |
| `drop_type` | ENUM | `SPOIL` \| `CURRENCY` \| `DROP` \| `HERB` |
| `category_chance` | DOUBLE | шанс срабатывания всей категории, % |
| `item_id` | INT | id предмета из `data/xml/items` |
| `min_count` / `max_count` | INT | количество, разыгрывается равномерно |
| `chance` | DOUBLE | вес предмета внутри категории, % |
| `enabled` | TINYINT | `0` выключает строку, не удаляя её |

Первичный ключ — `(npc_id, category, order_id)`.

**Категория — это не предмет, а лотерея.** Сначала по `category_chance` решается, сработала ли категория
вообще; только потом внутри неё выбирается предмет по `chance`. Для `SPOIL` проверяется каждый предмет
отдельно (спойлится сразу несколько вещей), для остальных типов за одно срабатывание выпадает **ровно один**
предмет — `chance` внутри такой категории это доли от 100 %, а не независимые шансы.

`category_chance` — свойство всей категории, поэтому во всех её строках оно одинаковое. Сервер читает его
из строки с наименьшим `order_id` и игнорирует в остальных: если поменять его в одной строке из пяти,
ничего не произойдёт (или произойдёт не то). Меняйте всю категорию сразу.

`order_id` влияет на результат только когда сумма `chance` в категории больше 100 — тогда предметы в
хвосте не выпадают никогда. В ретейльных данных таких категорий две (18003 и 25512).

`drop_type` определяет, какой рейт из `config/rates.properties` умножит категорию:
`RateDropSpoil`, `RateDropCurrency`, `RateDropItems` (для РБ — `RateDropItemsByRaid`), `RateDropHerbs`.
Рейт работает как число прогонов лотереи, поэтому `RateDropItems = 3` это три независимых броска
категории, а не тройной шанс.

## 2. Как это читает сервер

`DropTable` (`net.sf.l2j.gameserver.data.sql`) один раз выбирает всю таблицу
`ORDER BY npc_id, category, order_id`, склеивает строки в `DropCategory` и складывает в
`Map<npcId, List<DropCategory>>`. `NpcTemplate.getDropData()` только заглядывает в эту карту, своей копии
дропа у шаблона нет.

Загрузка идёт в `GameServer` сразу после `NpcData` — то есть после `ItemData`, потому что строки с
несуществующим `item_id` отбрасываются с предупреждением в лог (ровно как это делал XML-парсер).

Перезагрузка на живом сервере:

```
//reload drop
```

Карта подменяется целиком, поэтому монстр, умирающий в момент перезагрузки, увидит либо старый дроп, либо
новый, но не половину. `//reload npc` перечитывает только XML-шаблоны и дропа не касается.

## 3. Как править дроп

```sql
-- поднять шанс Adena у Grim Wolf (22001)
UPDATE droplist SET category_chance = 100 WHERE npc_id = 22001 AND drop_type = 'CURRENCY';

-- выключить весь HERB у всех NPC, не теряя данные
UPDATE droplist SET enabled = 0 WHERE drop_type = 'HERB';

-- добавить предмет в отдельную новую категорию: 1 % на то, что категория сработает,
-- и внутри неё единственный предмет с весом 100 %
INSERT INTO droplist (npc_id, category, order_id, drop_type, category_chance, item_id, min_count, max_count, chance)
SELECT 22001, MAX(category) + 1, 0, 'DROP', 1, 6673, 1, 1, 100 FROM droplist WHERE npc_id = 22001;

-- посмотреть, что вообще падает с NPC
SELECT * FROM droplist WHERE npc_id = 22001 ORDER BY category, order_id;
```

После правок — `//reload drop`.

Чего делать не надо: менять `category_chance` только в части строк категории (см. выше) и вешать в одну
не-`SPOIL` категорию предметы с суммой `chance` заметно меньше 100 — недобор просто уходит в «ничего не
выпало», и это почти всегда не то, что имелось в виду.

## 4. Установка

Свежая БД: `droplist.sql` подхватывается `tools/database_installer.bat` / `.sh` наравне с остальными
таблицами, отдельных действий не нужно.

Уже работающая БД, в которой таблицы ещё нет:

```bash
mysql -u root -p acis < build/sql/droplist.sql
```

`droplist.sql` начинается с `DROP TABLE IF EXISTS droplist` — он ставит ретейльный дроп с нуля и стирает
любые ручные правки. Это файл установки и отката к ретейлу, а не то, что гоняют регулярно. Свои правки
храните отдельным SQL-скриптом поверх него.

Если запустить сервер, не залив таблицу, дропа не будет ни у кого: `DropTable` напишет в лог
`Couldn't load droplist` и отдаст пустую карту.

## 5. Инструмент

`tools/droplist/xml_drops_to_sql.ps1` — тот самый конвертер, которым делали перенос. Он читает
`<drops>` из `source/aCis_datapack/data/xml/npcs`, пишет `sql/droplist.sql` (в датапак и в `build/`), а с
ключом `-StripXml` вырезает `<drops>` из XML в обоих деревьях.

```powershell
powershell -ExecutionPolicy Bypass -File tools\droplist\xml_drops_to_sql.ps1
powershell -ExecutionPolicy Bypass -File tools\droplist\xml_drops_to_sql.ps1 -StripXml
```

Перенос уже сделан, так что при обычном прогоне скрипт ничего не найдёт и честно об этом скажет, не
затирая SQL. Он нужен, если понадобится повторить перенос из другого набора XML — тогда
`-XmlDir <путь>` укажет, откуда брать.
