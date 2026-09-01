# A ladder up to S grade for every armor set

`generate.ps1` gives each of the 122 armor looks of the datapack a ladder from the grade it already has up
to S — **438 sets, 1924 minted items** — and `patch_client.ps1` teaches the client those new ids.

Every set owns its pieces : head, legs, gloves and boots are minted for that one set on every rung, named
after its chest (`Tunic of Zubei Boots`) and shared with nobody. Retail items are clone sources only.

```
a No Grade set exists as  NG D C B A S
a D grade set as             D C B A S
...
an S grade set as                    S   - Imperial Crusader gains nothing at all
```

Design, numbers and consequences: [../../docs/armor-sets-all-grades.md](../../docs/armor-sets-all-grades.md).
Read it before touching anything here.

## The two runs

Always in this order — the second one feeds on what the first one writes into `generated/`.

```powershell
powershell -ExecutionPolicy Bypass -File tools\armorsets\generate.ps1
```

```powershell
powershell -ExecutionPolicy Bypass -File tools\armorsets\patch_client.ps1 -SystemDir "C:\l2client\system" -ToolsDir "C:\tools\L2 File Editor\data"
```

`-ToolsDir` is the `data` directory of L2 File Editor, the one holding `l2encdec\` and `l2asm-disasm\`.

Both are **idempotent**: `generate.ps1` rewrites what it owns from scratch, and `patch_client.ps1` always
starts from the `*.presets.bak` it left next to each patched `.dat`. Running them twice equals running them
once, so a change to `families.csv` is applied by simply running both again.

## Files

| file | what |
|---|---|
| `families.csv` | the table everything is generated from — one row per chest item, the pieces that go with it, and which set bonus it carries. Hand curated ; see below. |
| `retired.csv` | the chests that used to be a set and are not one any more. `patch_client.ps1` wipes the stock set tooltip off them ; without it a removed retail set goes on promising its bonus in game. Explicit on purpose — the client also carries set tooltips this datapack never modelled (Dynasty, DragonFire) and those must stay. |
| `generate.ps1` | datapack side : items, `armorSets.xml`, set skills, GM shop buy lists, and a copy into `build\`. |
| `patch_client.ps1` | client side : `armorgrp.dat`, `itemname-e.dat`, `skillgrp.dat`, `skillname-e.dat`. |
| `generated/client_items.tsv` | every piece, its name, its grade, its P. Def. and the item it was cloned from. |
| `generated/client_sets.tsv` | the set tooltip of every chest — members, bonus text, shield. |
| `generated/client_skills.tsv` | every set skill level, its name, its bonus text and whose icon it wears. |
| `generated/upgrade_chain.tsv` | one line per slot of every set : the grade it starts at and the id it wears on every rung, blank where it has none. |

`generated/` is committed on purpose — `patch_client.ps1` is meant to run on a machine that has the client
but not necessarily a working `generate.ps1`.

## families.csv

One row per chest (or fullarmor) item of `data/xml/items`. Columns:

| column | what |
|---|---|
| `chest` | the chest item id. It is the key of the whole thing : `ArmorSetData` files sets by chest id. |
| `name` | the set name, shown in `//item set` and in the skill window. |
| `base` | the chest's own item name, for reading the table. |
| `style` | `chestlegs` or `full` — a fullarmor set has no legs slot. |
| `type` | `HEAVY`, `LIGHT` or `MAGIC`. Picks the P. Def. row and the "+6 enchanted" skill. |
| `origGrade` | the grade the set starts at — the bottom rung of its ladder, and the grade its retail bonus is read as. |
| `head` | fixed by `type` : `41` for MAGIC, `2416` for LIGHT, `7860` for HEAVY. Interlude does not draw helmets on the character, so all a donor gives is its icon — cloth, leather or plate. |
| `legs`, `gloves`, `feet` | the item each slot is **cloned from** — its mesh, texture, icon, weight and material. Two sets may name the same donor ; they still get their own minted pieces out of it. |
| `shield`, `shieldSkill` | kept from `armorSets.xml` where retail had one ; shields are not regraded. |
| `profile` | the set bonus. A retail skill id (`3518`) reuses that skill's own `<for>` block ; `h1`..`h8`, `l1`..`l8`, `m1`..`m8` pick one out of the pools at the top of `generate.ps1`. |

The table was seeded by matching piece names against each other (idf weighted token overlap), then overlaid
with the retail composition out of `armorSets.xml`, then hand fixed. It is **data, not output** — edit it and
rerun, don't regenerate it.

Removing a row means adding its chest to `retired.csv`, or the client keeps whatever set tooltip the stock
game shipped for it.

Adding, removing or reordering a row renumbers every id minted after it. That is fine as long as both
scripts are rerun, but it does invalidate items already in players' inventories, so treat the table as
append-only once the server is live. Swapping one donor for another inside a row does not move any id.
