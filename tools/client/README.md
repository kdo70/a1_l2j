# Client-side enchant window rebuild

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

## Rebuilding it

You need `ucc.exe` **and** `editor.dll` for this engine build. The client ships `core.dll`, `engine.dll`,
`window.dll`, `nwindow.dll` and friends, but not those two — they only come with L2 developer/tool kits, which
you have to source yourself. Verify you got a matching pair by running `extract_interface_source.ps1` against
whatever `ucc` produces: it must print **package version 123, licensee 30**. Anything else will not load.

1. Extract the stock sources (already done for `Interface` and `NWindow` in this folder, redo it if your
   client differs):

   ```
   powershell -File extract_interface_source.ps1 -Package "<client>\system\interface.u" -OutDir .\Interface
   ```

2. Put `ucc.exe` and `editor.dll` next to a copy of the client's `system` folder, and point an ini at the
   packages, `Interface` last:

   ```
   [Editor.EditorEngine]
   EditPackages=Core
   EditPackages=Engine
   EditPackages=Fire
   EditPackages=IpDrv
   EditPackages=UWindow
   EditPackages=NWindow
   EditPackages=Interface
   ```

3. Delete the old `Interface.u` from that folder (`ucc` refuses to overwrite), then:

   ```
   ucc make -ini=<your ini>
   ```

4. `ucc` writes a plain package. Try dropping it into the client's `system` as `interface.u` first — some
   clients read unwrapped packages. If the client refuses it, wrap it back into the `Lineage2Ver111`
   container:

   ```
   powershell -File pack_l2_package.ps1 -In .\Interface.u ^
       -Out "<client>\system\interface.u" ^
       -TrailerFrom "<client>\system\interface.u.orig.bak"
   ```

   The 20 byte trailer is undocumented, so it is copied verbatim from a stock file rather than invented.

**Back up `interface.u` before replacing it.** A copy of the untouched original is at
`<client>\system\interface.u.orig.bak`.

## Files here

- `extract_interface_source.ps1` — pulls the `.uc` sources out of any `Lineage2Ver111` package.
- `pack_l2_package.ps1` — wraps a plain `ucc` package back into that container.
- `Interface/Classes/` — 142 classes extracted from `interface.u`, with `ItemEnchantWnd.uc` rebuilt.
- `NWindow/Classes/` — 87 classes from `nwindow.u`, kept for the native API declarations
  (`ItemWindowHandle`, `WindowHandle`, `EnchantAPI`, …). Not needed to build, handy to read.

The extracted sources are NCsoft client code that came out of your own client files. Drop them from version
control if you'd rather not carry them.
