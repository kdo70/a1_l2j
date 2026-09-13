# tools/weapons

Оружие: удаление SA-копий, лестница грейдов и клиентская половина обеих правок.
Устройство и цифры — [../../docs/weapon-grades.md](../../docs/weapon-grades.md),
свечение при заточке — [../../docs/enchant-glow.md](../../docs/enchant-glow.md).

## Файлы

| файл | что это |
|---|---|
| `retired_sa.csv` | 441 SA-копия на удаление: id, имя, грейд, id базового оружия. **Исходник, правится руками.** |
| `retired_weapons.csv` | 53 оружия, выведенных из игры целиком: 47 дуалов, `7887 Mysterious Sword`, `240 Conjurer's Knife` и четыре книги-заглушки `324 Tears of Fairy`, `335 Soul Crystal`, `341 Forgotten Tome`, `346 Tears of Fallen Angel` — у них в клиенте нет своей модели, все носят `apprentices_spellbook`, как и оставленная `319 Eye of Infinity`. **Исходник, правится руками.** |
| `retired_shadow.csv` | 115 `Shadow Item: ...` — временное оружие, выведенное из игры целиком. **Исходник, правится руками.** |
| `weapons.csv` | 461 оружие, у которого есть лестница: id, имя, класс, стартовый грейд. **Исходник, правится руками**, генератор его не переписывает. |
| `duplicates.csv` | 106 оружий, делящих меш, текстуру, тип и грейд с другим: что удалить, что оставить, и каким квестом занято. **Предложение, правится руками** — `keep` меняется, если догадка мимо. Пишется `find_duplicates.ps1`. |
| `remove_sa.ps1` | удаляет `retired_sa.csv` из датапака и из всего, что на него ссылалось |
| `remove_weapons.ps1` | то же для любого списка ретейльного оружия (`-Retired`), а ниток тут больше: рецепты и предметы-рецепты, магазины, обмены, а руки NPC переставляются на уцелевшее оружие того же класса и грейда |
| `restore_weapons.ps1` | обратная операция: возвращает оружие в датапак из нетронутой копии (`-From`) — предмет, иконку, рецепт, продукты лавок, обмены и руки NPC |
| `remove_sa_client.ps1` | клиентская половина удалений: выкидывает id списка из `weapongrp.dat` и `itemname-e.dat`; список задаётся `-Retired`, имя бэкапа — `-BackupSuffix` |
| `restore_weapons_client.ps1` | клиентская половина возврата: копирует строки id из `*.bak` обратно в `weapongrp.dat` и `itemname-e.dat` |
| `duplicates_texture.csv` | второй проход: 22 оружия, делящих текстуру и тип с другим, с тем, кто остаётся. Пишется `find_duplicates.ps1 -ByTexture` |
| `find_duplicates.ps1` | ищет оружие, неотличимое в мире, и предлагает, кого из группы оставить — пишет `duplicates.csv`; с `-ByTexture` группирует по текстуре и типу и оставляет самый низкий грейд выше NG |
| `dedup_weapons.ps1` | сливает группы в одно оружие по `duplicates.csv` (`-List`), список удалённых — в `generated\` под `-RetiredName`; квестовые строки пропускает, пока не сказано иначе |
| `free_weapons.ps1` | снимает запреты на продажу, обмен, склад и выброс со всего оружия, кроме монстрового и проклятого |
| `monster_only.csv` | ретейльное оружие, сделанное монстровым: NPC его держат, игроку взять негде. **Исходник, правится руками.** |
| `monster_only.ps1` | снимает оружие `monster_only.csv` с игроков: лавки NPC, обмены, рецепты вместе с предметами-рецептами, `droplist.sql`; пишет `generated/monster_only_live.sql` для рабочей БД |
| `monster_icons_client.ps1` | клиентская половина: ставит тому же оружию иконку `weapon_monster_i00` в `weapongrp.dat` (в `itemIcons.xml` она уже стоит) |
| `generate.ps1` | чеканит лестницу, перезаполняет списки GM-магазина, пишет `generated/*.tsv` |
| `patch_client.ps1` | дописывает новые id в `weapongrp.dat` / `itemname-e.dat` и переписывает эффект свечения |
| `generated/client_items.tsv` | что скармливается `patch_client.ps1`: id, донор, грейд, числа, класс, вид свечения, имя |
| `generated/upgrade_chain.tsv` | ряды id по грейдам — заготовка под будущую фичу «прокачать грейд» |

## Порядок

```powershell
# 1. один раз: убрать SA-копии (идемпотентно, повтор ничего не делает)
powershell -ExecutionPolicy Bypass -File tools\weapons\remove_sa.ps1

# 2. лестница; гонять заново после правки weapons.csv
powershell -ExecutionPolicy Bypass -File tools\weapons\generate.ps1

# 2b. вывести из игры оружие из retired_weapons.csv. Строго ПОСЛЕ шага 2 и только когда те же id
#     убраны из weapons.csv, иначе лестница отчеканит копии уже удалённого оружия обратно -
#     скрипт сам откажется работать, пока хоть один id остаётся в weapons.csv
powershell -ExecutionPolicy Bypass -File tools\weapons\remove_weapons.ps1

# 2c. тем же скриптом, другим списком: shadow-оружие
powershell -ExecutionPolicy Bypass -File tools\weapons\remove_weapons.ps1 `
    -Retired tools\weapons\retired_shadow.csv

# 2d. слить оружие, неотличимое в мире. Сначала найти (нужен разобранный weapongrp),
#     прочитать duplicates.csv глазами, поправить колонку keep, и только потом слить.
powershell -ExecutionPolicy Bypass -File tools\weapons\find_duplicates.ps1 `
    -Weapongrp C:\tmp\weapongrp.txt
powershell -ExecutionPolicy Bypass -File tools\weapons\dedup_weapons.ps1
#     ...и снова шаг 2, потому что лестница ужалась

# 2e. снять запреты на продажу/обмен/склад/выброс
powershell -ExecutionPolicy Bypass -File tools\weapons\free_weapons.ps1

# 2f. сделать оружие monster only : id из monster_only.csv убрать из weapons.csv, шаг 2, потом
#     это (скрипт откажется, пока id в weapons.csv). На живой БД ещё generated\monster_only_live.sql
#     и //reload drop
powershell -ExecutionPolicy Bypass -File tools\weapons\monster_only.ps1

# 3. клиент: новые предметы и свечение
powershell -ExecutionPolicy Bypass -File tools\weapons\patch_client.ps1 `
    -SystemDir "C:\Users\KRIVOSHEEC\Desktop\1\system" `
    -ToolsDir  "C:\Users\KRIVOSHEEC\Desktop\L2_File_Editor_2a__C4_to_Freya__by_CriticalError\data"

# 3b. клиент: убрать те же SA-копии из его таблиц (идемпотентно, повтор ничего не делает)
powershell -ExecutionPolicy Bypass -File tools\weapons\remove_sa_client.ps1 `
    -SystemDir "C:\Users\KRIVOSHEEC\Desktop\1\system" `
    -ToolsDir  "C:\Users\KRIVOSHEEC\Desktop\L2_File_Editor_2a__C4_to_Freya__by_CriticalError\data"

# 3c. клиент: и выведенное из игры оружие, тем же скриптом по другому списку
powershell -ExecutionPolicy Bypass -File tools\weapons\remove_sa_client.ps1 `
    -SystemDir "C:\Users\KRIVOSHEEC\Desktop\1\system" `
    -ToolsDir  "C:\Users\KRIVOSHEEC\Desktop\L2_File_Editor_2a__C4_to_Freya__by_CriticalError\data" `
    -Retired tools\weapons\retired_weapons.csv -BackupSuffix ".retired.bak"

# 3d. клиент: и shadow-оружие, тем же скриптом по третьему списку
powershell -ExecutionPolicy Bypass -File tools\weapons\remove_sa_client.ps1 `
    -SystemDir "C:\Users\KRIVOSHEEC\Desktop\1\system" `
    -ToolsDir  "C:\Users\KRIVOSHEEC\Desktop\L2_File_Editor_2a__C4_to_Freya__by_CriticalError\data" `
    -Retired tools\weapons\retired_shadow.csv -BackupSuffix ".shadow.bak"

# 3e. клиент: и слитые дубли, четвёртым списком
powershell -ExecutionPolicy Bypass -File tools\weapons\remove_sa_client.ps1 `
    -SystemDir "C:\Users\KRIVOSHEEC\Desktop\1\system" `
    -ToolsDir  "C:\Users\KRIVOSHEEC\Desktop\L2_File_Editor_2a__C4_to_Freya__by_CriticalError\data" `
    -Retired tools\weapons\generated\dedup_retired.csv -BackupSuffix ".dedup.bak"

# 3f. клиент: дубли по текстуре, пятым списком (серверная половина - find_duplicates.ps1 -ByTexture
#     -Out duplicates_texture.csv, dedup_weapons.ps1 -List duplicates_texture.csv
#     -RetiredName dedup_texture_retired.csv), затем patch_client.ps1, monster_icons_client.ps1 и
#     tools\client\tune_enchant_glow.ps1 -ByTexture
powershell -ExecutionPolicy Bypass -File tools\weapons\remove_sa_client.ps1 `
    -SystemDir "C:\Users\KRIVOSHEEC\Desktop\1\system" `
    -ToolsDir  "C:\Users\KRIVOSHEEC\Desktop\L2_File_Editor_2a__C4_to_Freya__by_CriticalError\data" `
    -Retired tools\weapons\generated\dedup_texture_retired.csv -BackupSuffix ".dedup_texture.bak"

# 4. EnchantGlow.u кладётся в system\ КАК ЕСТЬ - голым, licensee 0.
#    Заворачивать его в контейнер и трогать licensee нельзя, см. docs/enchant-glow.md.

# 5. клиент: свечение по ступеням заточки (один раз на сборку клиента)
powershell -ExecutionPolicy Bypass -File tools\client\patch_engine_enchant_glow.ps1 `
    -In "C:\Users\KRIVOSHEEC\Desktop\1\system\engine.dll"
powershell -ExecutionPolicy Bypass -File tools\client\patch_env_enchant.ps1 `
    -In "C:\Users\KRIVOSHEEC\Desktop\1\system\env.int"
```

Шаг 5 гонять по бэкапу, если движок уже пропатчен:
`-In "...\engine.dll.enchantglow.bak" -OutFile "...\engine.dll"`.

`remove_sa.ps1`, `remove_weapons.ps1`, `restore_weapons.ps1` и `generate.ps1` сами синхронизируют
`build\gameserver\data` — без этого правка не уедет на сервер (см. AGENTS.md). Отключается флагом
`-NoSync`.

### Вернуть удалённое обратно

Обратный ход к шагу 2b, и он тоже двусторонний. Оружию нужна нетронутая копия датапака — проще
всего снять её с коммита, где оно ещё было:

```powershell
git archive --format=tar -o head.tar HEAD source/aCis_datapack/data
mkdir head ; tar -x -f head.tar -C head

# сервер: предмет, иконка, рецепт, продукты лавок, обмены и руки NPC
powershell -ExecutionPolicy Bypass -File tools\weapons\restore_weapons.ps1 `
    -From head\source\aCis_datapack\data -Ids "67,73,74,76,86,96,123,127,153,223,228,298"

# клиент: строки weapongrp и itemname из бэкапа, СТРОГО до patch_client.ps1 -
# тот падает на оружии лестницы, у которого нет строки в weapongrp
powershell -ExecutionPolicy Bypass -File tools\weapons\restore_weapons_client.ps1 `
    -SystemDir "C:\Users\KRIVOSHEEC\Desktop\1\system" `
    -ToolsDir  "C:\Users\KRIVOSHEEC\Desktop\L2_File_Editor_2a__C4_to_Freya__by_CriticalError\data" `
    -FromWeapongrp "...\system\weapongrp.dat.models.bak.retired.bak" `
    -FromItemname  "...\system\itemname-e.dat.retired.bak"
```

Вернув оружие, надо руками убрать его id из `retired_weapons.csv` и, если ему полагается лестница,
дописать в `weapons.csv` — и прогнать шаги 2 и 3 заново.

## Границы

- **`generate.ps1` владеет байлистами GM-магазина `9001..9053`, `9129..9136`** и выметает из всего
  магазина (`npcId="-1"`) продукты `12000..19999`. `9105..9111` — чужие, они у страниц брони.
- **`generate.ps1` владеет id `12000..12988`** и файлами `data/xml/items/12*.xml`, `13*.xml`.
  Броня владеет `10000..11409`; её генератор больше не сносит чужие бакеты выше своего диапазона.
- **`patch_client.ps1` не стартует со стокового `*.presets.bak`** — иначе он бы затёр строки,
  которые положил патчер брони. Вместо этого он выкидывает из таблицы свои id и вставляет их заново,
  так что повторный прогон даёт тот же файл. Копия для отката — `*.weapons.bak`.
- Порядок между патчерами: сначала `tools/armorsets/patch_client.ps1`, потом этот. Если броню
  перепатчивали — этот прогнать заново.
