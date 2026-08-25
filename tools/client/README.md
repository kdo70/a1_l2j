# Client-side interface rebuilds

Two server features have a client half, and both live here — one rebuild of `interface.u` carries them
together:

| classes | goes with | why |
|---|---|---|
| `ItemEnchantWnd` | `EnchantKeepWindowOpened` | keeps the enchant list and its selection alive between attempts (below) |
| `ToolTip`, `ChatWnd` | `SendItemNameColors` | paints item names with the color the server sends, and keeps the feed out of the chat — see [../../docs/item-name-colors.md](../../docs/item-name-colors.md) |

## The enchant window

Goes with `EnchantKeepWindowOpened` in `config/players.properties`.

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
`UClass` export against the stock package. A faithful rebuild differs only in the classes you changed —
three of them today: `ItemEnchantWnd`, `ToolTip`, `ChatWnd`. Anything else means a class lost its defaults:

```powershell
# class blobs, stock vs built - only the classes rebuilt on purpose may differ
$s = upkg -Mode exports stock   | ? { $_ -match 'class=None' }
$b = upkg -Mode exports built   | ? { $_ -match 'class=None' }
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
- `Interface/Classes/` — 142 classes extracted from `interface.u`, with `ItemEnchantWnd.uc`, `ToolTip.uc`
  and `ChatWnd.uc` rebuilt.
- `NWindow/Classes/` — 87 classes from `nwindow.u`, compiled as a stand-in for the client's binary package.
  Also the place to read the native API from (`ItemWindowHandle`, `WindowHandle`, `EnchantAPI`, …).
- `Core/Classes/` — the kit's four Core classes plus `ParamStack` from the client, with `Split` removed.

The extracted sources are NCsoft client code that came out of your own client files. Drop them from version
control if you'd rather not carry them.
