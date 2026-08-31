# Client-side interface rebuilds

Three server features have a client half, and all of them live here — one rebuild of `interface.u` carries
them together:

| classes | goes with | why |
|---|---|---|
| `ItemEnchantWnd` | `EnchantKeepWindowOpened` | keeps the enchant list and its selection alive between attempts (below) |
| `ToolTip`, `ChatWnd` | `SendItemNameColors` | paints item names with the color the server sends, and keeps the feed out of the chat — see [../../docs/item-name-colors.md](../../docs/item-name-colors.md) |
| `ToolTip`, `ChatWnd` | `SendItemStats` | asks the server for the item numbers the client would read from its own `weapongrp.dat` and friends, and keeps that feed out of the chat too — see [../../docs/item-stats-from-server.md](../../docs/item-stats-from-server.md) |
| `ToolTip`, `ChatWnd` | `SendItemSkills` | shows the skills an item grants once equipped and paints its name with the color that very item carries — see [../../docs/item-skills.md](../../docs/item-skills.md) |
| `ToolTip` | `ClientVersion` | reports which build this is, so the server can turn away the clients that did not pick it up — see [../../docs/client-version-check.md](../../docs/client-version-check.md) |

## The enchant window

Goes with `EnchantKeepWindowOpened` in `config/players/enchant.properties`.

With that setting on, the server hands the enchant window the next scroll of the same type instead of closing
it. A **stock client** handles that correctly but rebuilds its item list every time, so the player has to pick
the item again. This folder rebuilds `ItemEnchantWnd` so the list is refreshed in place and the selection
survives — then pressing **Enchant** again is all it takes.

Everything here is optional. Without it the server feature still works, it just costs one extra click per
scroll, and nothing in this folder affects the server build.

## What the stock client does

`interface.u` still carries its UnrealScript sources, so this is the real thing, not a guess:

```unrealscript
function HandleEnchantShow(string param)   { Clear(); ... Me.ShowWindow(); }
function HandleEnchantItemList(string param){ ParamToItemInfo(param, infItem); ItemWnd.AddItem(infItem); }
function HandleEnchantResult(string param) { Me.HideWindow(); Clear(); }
```

`Clear()` empties the list, and `ItemWindowHandle` has **no way to select an item programmatically** — only
`ClearSelect()`, `GetSelectedNum()`, `GetSelectedItem()`. So "rebuild the list, then reselect" is impossible
by construction, and a bytecode-level hack that merely removes `HideWindow(); Clear();` trades the problem for
three worse ones: the window never closes, a broken item stays listed, and enchant levels go stale.

## What the rebuilt class does

`Interface/Classes/ItemEnchantWnd.uc` changes three things and leaves the rest byte-identical to stock:

| | stock | rebuilt |
|---|---|---|
| `HandleEnchantItemList` | always `AddItem` | `FindItemWithServerID` + `SetItem` when the item is already listed — the entry is replaced, so the enchant level refreshes **without** rebuilding the list |
| `HandleEnchantResult` | `HideWindow(); Clear();` | sets `bContinuing` and arms a 400 ms timer instead of tearing the window down |
| `HandleEnchantShow` | always `Clear()` | skips `Clear()` when `bContinuing` is set, i.e. when the server is carrying the same run on |

The server states "the run goes on" simply by sending another *choose item* order, which lands in the same
packet batch as the result. If none comes — item broke, scrolls ran out, enchant limit reached — the timer
fires and `EndRun()` closes the window and empties the list. That is what keeps the three failure cases
behaving like retail while the happy path stays one click.

## Item name colors

`ToolTip.uc` keeps a table of "item class id → color" and paints the item name in every tooltip it builds
with it ; items the server said nothing about keep the color the client gives them. `ChatWnd.uc` drops the
messages that table arrives in, so nothing of it shows up in chat.

The table itself is a server side XML property fed through a chat channel — the whole design, and what it
can and cannot color, is in [../../docs/item-name-colors.md](../../docs/item-name-colors.md).

## Item statistics

`ToolTip` also replaces the numbers it read from `weapongrp.dat` / `armorgrp.dat` / `etcitemgrp.dat` -
P.Atk, M.Atk, defenses, attack speed, weight and the rest of the tooltip block - with the ones the server
keeps in its item XMLs, so those files no longer have to be kept in sync with the datapack.

This one is a pull, not a push : the client asks with `RequestBypassToServer("_itemstats ...")` - once for
everything in its inventory, then item by item for whatever else it is about to draw - and the answers come
back on the same tagged chat channel the colors use. Nothing reaches a client that did not ask, which is why
`SendItemStats` is harmless to a stock one. The whole design is in
[../../docs/item-stats-from-server.md](../../docs/item-stats-from-server.md).

## Item skills

`ToolTip` also asks the server what the items it draws carry on top of their class — the skills they grant to
whoever equips them, and the color of their name — and draws both. Those live on the item itself, so the feed
is keyed by server id: two Short Swords can carry different ones, and a color carried by the item wins over the
one its class carries.

It is a pull like the statistics, on a bypass and a tag of its own, and the answers come back on the same
tagged chat channel. The whole design is in [../../docs/item-skills.md](../../docs/item-skills.md).

## The client version

`ToolTip.uc` also carries a `CLIENTVER_VALUE` constant and reports it to the server with
`RequestBypassToServer("_ver ...")` on entering the world. The server compares it against its `ClientVersion`
setting and disconnects whoever does not match — a stock client reports nothing at all and is disconnected on
a timeout, which is the point: it is how an `interface.u` update is made mandatory.

**Bump `CLIENTVER_VALUE` and the server's `ClientVersion` together**, in the same commit, whenever you rebuild
a package players have to pick up. Bump only the constant and everyone is turned away; bump only the setting
and nobody is. The whole design is in [../../docs/client-version-check.md](../../docs/client-version-check.md).

## Enchant level and stack count on the icon

This one is not part of the `interface.u` rebuild at all — it is a binary patch of `nwindow.dll`, applied by
`patch_nwindow.ps1`. It has to be, because the native `NCItemWnd::OnPaint` draws exactly one piece of text in
the corner of an item icon, the stack count, and UnrealScript cannot change its format, colour or position:

```
powershell -ExecutionPolicy Bypass -File patch_nwindow.ps1 -In "<client>\system\nwindow.dll"
```

The patch adds a branch — `"+N"` for enchanted items, `"99+"` for counts past a cap, the stock `"%d"`
otherwise — and takes `-EnchantColor`, `-CountColor`, `-EnchantOffsetX/Y`, `-CountOffsetX/Y` and `-CountCap`.
It verifies the block it replaces byte for byte first, so it is a no-op on any other build, and it leaves
`nwindow.dll.preench.bak` behind. To change the colours or the position, restore that backup and run it again.
The whole disassembly, and the structure offsets it rests on, are in
[../../docs/enchant-on-icon.md](../../docs/enchant-on-icon.md).

## Colored titles above NPCs

Also not part of the `interface.u` rebuild — `npc_title_colors.ps1` rewrites the client's
`npcname-e.dat`, whose per-npc `FColor` is the one arbitrary color an NPC owns:

```
powershell -ExecutionPolicy Bypass -File npc_title_colors.ps1 -ClientSystemDir "<client>\system"
```

The **name** of an NPC carries no color anywhere — not in the packet, not in the client's data —
and it is the engine that draws it. The colored slot is the title, the line above the name, and
that one takes any RGB. Which colors go on which npc id is `npc_title_colors.txt`; the text itself
can still come from the server through `usingServerSideTitle`. The whole reasoning, the file
format and the checks the script runs on itself are in
[../../docs/npc-title-colors.md](../../docs/npc-title-colors.md).

`patch_engine_npc_name_color.ps1` then makes the **name** take that same color, by patching
`engine.dll`:

```
powershell -ExecutionPolicy Bypass -File patch_engine_npc_name_color.ps1 -In "<client>\system\engine.dll"
```

`User::GetNameColor` already returns any RGB an object carries in `UniqueNameColor` — players get
one from `CharInfo`, NPCs never do. The patch adds one step in front of the level tint that stands
in for it: an NPC whose title color is not one of the stock ones wears it on its name too. One byte
in place plus 60 bytes in the padding behind the function, no absolute addresses, no `.reloc`. See
[../../docs/npc-name-colors.md](../../docs/npc-name-colors.md).

`patch_engine_npc_packet_color.ps1` goes one further and lets the **server** pick the color, per
spawned NPC:

```
powershell -ExecutionPolicy Bypass -File patch_engine_npc_packet_color.ps1 -In "<client>\system\engine.dll"
```

The server appends one tagged dword to `NpcInfo` for the NPCs whose XML carries `nameColor`, and the
patch drops it straight into `UniqueNameColor` — which wins over the color the other patch takes
from `npcname-e.dat`. The client checks every packet field against the packet's end, so a stock
client never reads those four bytes and keeps working; the tag byte covers the other direction, a
patched client against a server that sends nothing. Both patches are independent, and both are in
[../../docs/npc-name-colors.md](../../docs/npc-name-colors.md).

## Rebuilding it

You need an **L2-capable** `ucc`. A stock UT2003 one won't do: it has to read the `Lineage2Ver111` container
and it has to be built against L2's engine. Check any kit you're handed the same way this one was checked —
`UCC.exe` must contain the strings `Lineage2111WindowsFileReader` / `Lineage2Ver111`, and `Engine.dll` must
contain L2 class names such as `LineagePlayerController`:

```powershell
$b=[IO.File]::ReadAllBytes('<kit>\UCC.exe'); [Text.Encoding]::Unicode.GetString($b) -match 'Lineage2Ver111'
```

Such kits are 32 bit and link against the **Visual C++ 2013 x86 runtime** (`msvcr120.dll`). Without it `ucc`
dies with exit code `0xC0000135` and prints nothing at all, which looks like a broken kit but isn't — install
`vcredist_x86.exe` for Visual Studio 2013 first.

The scripts here are unsigned, so PowerShell's execution policy blocks them by default with
`UnauthorizedAccess`. Pass `-ExecutionPolicy Bypass` on the command line — it applies to that one process
only, needs no admin rights, and leaves the machine-wide policy alone.

Then one command does everything — it builds in a throwaway tree and touches neither the client nor the kit:

```
powershell -ExecutionPolicy Bypass -File build_interface.ps1 -KitDir "<kit>" -ClientSystemDir "<client>\system"
```

### The defaultproperties trap — read this first

`ScriptText` holds the class **code only**. NCsoft does not store the `defaultproperties` block there, and
none of the 142 extracted sources has one. Recompile straight from them and every class comes out with its
defaults blank: `LoadingWnd` loses its textures, every window loses its `m_WindowName`, and the client comes
up with no loading screen, an empty inventory, a dead status window and a stutter every few seconds. It looks
like the compiler produced garbage; it did not, the code is byte-for-byte right and only the values are gone.

The values are still in the package, at the tail of each `UClass` export as a tagged property list.
`extract_defaults.ps1` reads them back and appends a real `defaultproperties` block to each source:

```
powershell -ExecutionPolicy Bypass -File extract_defaults.ps1 -Package "<client>\system\interface.u" -SourceDirs .\Interface,.\NWindow
```

Run it once after extracting the sources, before building. The sources in this folder already have it applied
— 36 classes carry a recovered block.

### What the build has to work around

The kit is a genuine L2 set but from a different chronicle than the client, so the two cannot simply be
mixed — the script handles all of this, it is written down here so the next person knows why:

- **Packages come from the kit, not the client.** The kit's `Core.dll` binds only against the kit's own
  packages; feeding it the client's `core.u` fails with `Can't find 'intUObjectexecRotator2Vector'`.
- **`Core` is rebuilt** from the kit's class sources plus `ParamStack`, which Interlude's `Core` has and the
  kit's lacks. Rebuilding it there is what makes the output import `Core.ParamStack` — the name the real
  client resolves. `Split` is dropped from the stand-in `Object`, because the client's `Object` has none and
  `UICommonAPI` declares its own, which ucc otherwise rejects as "specifiers differ from original".
- **`NWindow` is rebuilt too, with `native` stripped.** The kit's engine crashes on the client's binary
  `nwindow.u`, and the client's `nwindow.dll` cannot load in the kit's process. Its functions are unnumbered
  natives, so calls to them compile to the same opcodes either way, and only its names and signatures matter.
- **`dynamicrecompile` and `constructive`** postdate this ucc and are stripped from the sources.

`ucc` stamps licensee 0 while every client package is licensee 30, so `pack_l2_package.ps1` rewrites that
field by default.

### Verifying

Getting a build is not the same as getting one that loads. Compare the result against the client's real
packages — every import has to resolve, or the client drops the package:

```
powershell -ExecutionPolicy Bypass -File verify_imports.ps1 -Package .\_build\System\Interface.u -ClientSystemDir "<client>\system"
```

Run it against the stock `interface.u.orig.bak` too and compare: the import counts should be all but equal.
The stock package reports 726 imports needing 29 Core / 1 Engine / 635 NWindow names ; the current build
reports 727 / 29 / 1 / 636, all resolved — new code referencing one more NWindow name is expected, missing
names are not.

The sharpest offline check, and the one that catches missing defaults, is comparing the size of every
`UClass` export — the blob those defaults live in — against a package known to be good. It does not move when
you only change code: the `ToolTip`/`ChatWnd` rebuild that carries `SendItemStats` leaves all 142 sizes
identical to the build before it, which is exactly the result to want. Against **stock**, four differ:
`ItemEnchantWnd` (rebuilt on purpose) and `GuideWnd`, `MinimapWnd`, `MinimapWnd_Expand` — +12, +19 and +18
bytes, never touched, their recovered `defaultproperties` simply re-serialize a little longer. Those three
differ in the build already running in the client as well ; a class showing up beyond them is the one that
lost its defaults:

```powershell
# class blobs, one package against the other
$s = .\dump_class_sizes.ps1 -Package '<client>\system\interface.u.orig.bak'
$b = .\dump_class_sizes.ps1 -Package .\_build\System\Interface.u
Compare-Object $s $b
```

A cheaper stand-in, when the stock package isn't at hand: run `extract_interface_source.ps1` on both the
previous build and the new one and diff the two `Classes` folders. Only the classes you edited may come out
different — it won't catch lost defaults, but it does catch a class you changed without meaning to.

Function bytecode sizes will differ by a byte here and there across unrelated classes. That is harmless:
object and name references are stored as compact indices, and a rebuilt package orders its name table
differently, so some references encode in one byte instead of two.

Then install it. Try the plain package first, some clients read unwrapped ones; if the client refuses it,
wrap it back into the container:

```
powershell -ExecutionPolicy Bypass -File pack_l2_package.ps1 -In .\_build\System\Interface.u ^
    -Out "<client>\system\interface.u" ^
    -TrailerFrom "<client>\system\interface.u.orig.bak"
```

The 20 byte trailer is undocumented, so it is copied verbatim from a stock file rather than invented. The
kit's own `_MXC EncDec.exe` does the same job if you'd rather use it.

**Back up `interface.u` before replacing it.** A copy of the untouched original is at
`<client>\system\interface.u.orig.bak`.

## Files here

- `add_repeat_button.groovy` — adds the Repeat button to `interface.xdat`, or updates its caption id. Runs on
  the XDAT Editor's own jars (`java -cp <editor jars> groovy.ui.GroovyMain add_repeat_button.groovy <in> <out>
  [captionId]`). The schema that reads an Interlude xdat is `ct0`, not `ct1`. A Button caption is a system
  string id, so the id has to exist in the client's `sysstring` dat first — this server uses **1501**.
- `build_interface.ps1` — sets up a throwaway build tree and runs `ucc make`.
- `extract_interface_source.ps1` — pulls the `.uc` sources out of any `Lineage2Ver111` package.
- `extract_defaults.ps1` — recovers the `defaultproperties` the sources don't carry. **Mandatory.**
- `pack_l2_package.ps1` — wraps a plain `ucc` package back into that container and stamps the licensee.
- `verify_imports.ps1` — checks a built package's imports against the client's real packages.
- `dump_class_sizes.ps1` — lists the size of every `UClass` export, for the comparison above.
- `dump_package.ps1` — lists what any `Lineage2Ver111` package holds (names, imports, exports and their full
  paths). Written to survey the client's effects — `LineageEffect.u` ships 864 of them — see
  [../../docs/npc-visual-effects.md](../../docs/npc-visual-effects.md). Nothing to do with the `interface.u`
  build either.
- `patch_nwindow.ps1` — the `nwindow.dll` patch that puts the enchant level on item icons and caps the stack
  count. Nothing to do with the `interface.u` build.
- `npc_title_colors.ps1` / `npc_title_colors.txt` — the `npcname-e.dat` rewrite that colors the title an NPC
  carries above its head. Also nothing to do with the `interface.u` build.
- `patch_engine_npc_name_color.ps1` — the `engine.dll` patch that makes an NPC's name take that color too.
- `patch_engine_npc_packet_color.ps1` — the `engine.dll` patch that reads an NPC's name color out of the
  `NpcInfo` packet, so the server owns it per spawned NPC.
- `Interface/Classes/` — 142 classes extracted from `interface.u`, with `ItemEnchantWnd.uc`, `ToolTip.uc`
  and `ChatWnd.uc` rebuilt. They are stored in the encoding they came out of the package with, Korean
  comments and all: edit them with a tool that leaves the bytes it does not touch alone.
- `NWindow/Classes/` — 87 classes from `nwindow.u`, compiled as a stand-in for the client's binary package.
  Also the place to read the native API from (`ItemWindowHandle`, `WindowHandle`, `EnchantAPI`, …).
- `Core/Classes/` — the kit's four Core classes plus `ParamStack` from the client, with `Split` removed.

The extracted sources are NCsoft client code that came out of your own client files. Drop them from version
control if you'd rather not carry them.
