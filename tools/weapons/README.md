# tools/weapons

Оружие: удаление SA-копий, лестница грейдов и клиентская половина обеих правок.
Устройство и цифры — [../../docs/weapon-grades.md](../../docs/weapon-grades.md),
свечение при заточке — [../../docs/enchant-glow.md](../../docs/enchant-glow.md).

## Файлы

| файл | что это |
|---|---|
| `retired_sa.csv` | 434 SA-копии на удаление: id, имя, грейд, id базового оружия. **Исходник, правится руками.** |
| `weapons.csv` | 566 оружий, у которых есть лестница: id, имя, класс, стартовый грейд. **Исходник, правится руками**, генератор его не переписывает. |
| `remove_sa.ps1` | удаляет `retired_sa.csv` из датапака и из всего, что на него ссылалось |
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

# 3. клиент: новые предметы и свечение
powershell -ExecutionPolicy Bypass -File tools\weapons\patch_client.ps1 `
    -SystemDir "C:\Users\KRIVOSHEEC\Desktop\1\system" `
    -ToolsDir  "C:\Users\KRIVOSHEEC\Desktop\L2_File_Editor_2a__C4_to_Freya__by_CriticalError\data"

# 4. клиент: свечение по ступеням заточки (один раз на сборку клиента)
powershell -ExecutionPolicy Bypass -File tools\client\patch_engine_enchant_glow.ps1 `
    -In "C:\Users\KRIVOSHEEC\Desktop\1\system\engine.dll"
powershell -ExecutionPolicy Bypass -File tools\client\patch_env_enchant.ps1 `
    -In "C:\Users\KRIVOSHEEC\Desktop\1\system\env.int"
```

`remove_sa.ps1` и `generate.ps1` сами синхронизируют `build\gameserver\data` — без этого правка не
уедет на сервер (см. AGENTS.md). Отключается флагом `-NoSync`.

## Границы

- **`generate.ps1` владеет id `12000..13771`** и файлами `data/xml/items/12*.xml`, `13*.xml`.
  Броня владеет `10000..11409`; её генератор больше не сносит чужие бакеты выше своего диапазона.
- **`patch_client.ps1` не стартует со стокового `*.presets.bak`** — иначе он бы затёр строки,
  которые положил патчер брони. Вместо этого он выкидывает из таблицы свои id и вставляет их заново,
  так что повторный прогон даёт тот же файл. Копия для отката — `*.weapons.bak`.
- Порядок между патчерами: сначала `tools/armorsets/patch_client.ps1`, потом этот. Если броню
  перепатчивали — этот прогнать заново.
