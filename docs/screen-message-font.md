# Кириллица в сообщениях поверх экрана

Почему текст `ExShowScreenMessage` был виден на латинице и пуст на кириллице, и чем это чинится.

Инструмент — [tools/client/patch_screen_message_font.ps1](../tools/client/patch_screen_message_font.ps1)
(и его половина на groovy — [screen_message_font.groovy](../tools/client/screen_message_font.groovy)).
Общий контекст модификации клиента — [enchant-and-client-modding.md](enchant-and-client-modding.md).

---

## 1. Короткий ответ

**Виноват не текст и не пакет, а шрифт одного окна.** Восемь окон `OnScreenMessageWnd1..8`, в которые
попадает `ExShowScreenMessage`, рисуют большую строку шрифтом `LargeFontType_4`. Это не шрифт, а слот:
`LargeFontType_1..4` клиент разрешает в **TrueType**-шрифты, объявленные в `TTFontInfo.ini` под
назначениями `zonetitle` / `benchmark` / `broadcast1` / `broadcast2`. В интернациональном клиенте
`broadcast2` закомментирован, шрифта под него нет, и боксы достаются GDI-умолчанию, которое рисует
латиницу и ничего больше.

Все остальные надписи интерфейса рисуются растровыми шрифтами из `Localization.ini`, а те кириллицу
несут — поэтому тот же самый текст в чате читается нормально.

Правка: перевести большие боксы этих восьми окон на растровый шрифт (`SpecialBigerFont` — это
`Font2` из `Localization.ini`, тот же, что у крупных надписей клиента).

## 2. Как это выглядело

Сервер шлёт сообщение книги рейдбоссов (`RaidBookManager.inform`, ключи `msg*` в
`data/xml/raidbook.xml`) двумя путями: в чат `player.sendMessage(...)` и, если включён
`RaidBookScreenMessages`, ещё и `ExShowScreenMessage` поверх экрана. В чате русский текст виден,
поверх экрана — окно с фоном появляется и гаснет по таймеру, а строка пустая; латинские куски
(имя босса, цифры) при этом рисуются.

Это сразу отсекает половину подозреваемых: пакет доходит, строка не теряется (иначе не было бы и
латиницы), `writeS` шлёт UTF-16LE посимвольно, скрипт `OnScreenMessageWnd.uc` текст не фильтрует
(он вырезает только `` ` `` и `#`, где `#` — перенос на вторую строку). Не рисуются именно глифы.

## 3. Где лежит шрифт окна

`interface.xdat`, схема `ct0` XDAT Editor'а. У каждого `TextBox` есть поле `fontType` — int, значения
которого схема называет так:

| знач. | имя | что это |
|---|---|---|
| 0 | `Normal` | растровый шрифт `Font` из `Localization.ini` (им рисует чат) |
| 1 | `SpecialBigerFont` | растровый `Font2`, крупный |
| 2–4 | `SpecialDigitSmall/Normal/Large` | цифровые шрифты (HP/MP, макросы) |
| 5–8 | `LargeFontType_1..4` | TrueType-шрифты `Font1..Font4` из `TTFontInfo.ini` |

Кто чем пользуется (по всему `interface.xdat`): `Normal` — 577 боксов, `LargeFontType_4` — 39
(восемь `OnScreenMessageWnd` плюс окна олимпийского наблюдателя), `SpecialDigitNormal` — 33,
`LargeFontType_1` — 6 (в том числе `ZoneTitleWnd`, и это сходится с `Font1=zonetitle` в
`TTFontInfo.ini`), `LargeFontType_3` — 5, `SpecialBigerFont` — 2 (часы на миникарте).

В каждом `OnScreenMessageWnd` шесть боксов: `TextBoxN`, `TextBoxN-1` (вторая строка) и их тени
`-0` — все четыре были `LargeFontType_4`; и `TextBoxsmN`, `TextBoxsmN-1` — они и так `Normal`.
Малый размер выбирается сервером (`writeD(_size)`, 1 — маленький), то есть в маленьком варианте
кириллица работала и до правки.

## 4. Почему LargeFontType_4 пустой

Имена назначений лежат прямо в `d3ddrv.dll`, рядом с `FD3DFont::CreateFont`:

```
broadcast2  broadcast1  benchmark  zonetitle  none
FontFile  Italic  FontSize  FontWeight  FontName  FontUsage  TTFontInfo.ini  Font%d
```

То есть драйвер читает `TTFontInfo.ini`, секцию `[FontUsage]` с ключами `Font%d`, и связывает
`FontN` с назначением. В клиенте этой сборки заполнен только `Font1`:

```ini
[FontUsage]
Font1=zonetitle
;Font2=benchmark
;Font3=broadcast1
;Font4=broadcast2

[FontName]
Font1=Tahoma
```

`broadcast2` не объявлен — значит для `LargeFontType_4` настоящего шрифта нет, и остаётся то, что
GDI даёт по умолчанию: латиница есть, кириллицы нет.

(`TTFontInfo.ini` — контейнер `Lineage2Ver111`: 28 байт заголовка в UTF-16 и дальше тело, XOR'ом
одного байта `0xAC`. Тем же способом читается `Localization.ini`.)

## 5. Почему в чате всё видно

`Localization.ini` (там же, `Ver111`) на `Language=1` даёт:

```ini
[English]
English_Font=L2Font-r.SmallFont-r
English_Glyph=SmallFont-e.gly
English_Font2=L2Font-r.LargeFont-r
English_Glyph2=LargeFont-r.gly
```

Оба шрифта — русские, из `systextures\L2Font-r.utx`. Ключи `%s_Font` / `%s_Glyph` / `%s_Font2` /
`%s_Glyph2` видны в `engine.dll` — читает их движок.

`.gly` — таблица прямоугольников глифов в текстуре шрифта, устроена так:

```
dword texWidth, texHeight, rangeCount
для каждого диапазона:  dword firstChar, count,  затем count * (dword u, width, v, height)
20 байт хвоста
```

Отсюда сразу видно, что кириллица есть:

| файл | диапазоны |
|---|---|
| `SmallFont-r.gly` (= `smallfont-e.gly`, файлы побайтово равны) | `0..255`, **`0x401..0x457`** |
| `LargeFont-r.gly` | `0..255`, **`0x401..0x44F`**, ещё один |
| `largefont-e.gly` | только `32..126` — в этой сборке не используется |

Прямоугольники кириллических глифов не пустые (ненулевые ширины, вторая строка текстуры), так что
`Font2` кириллицу действительно рисует.

## 6. Как применить и как откатить

```
powershell -ExecutionPolicy Bypass -File patch_screen_message_font.ps1 `
    -ClientSystemDir "<client>\system"
```

По умолчанию ставится `SpecialBigerFont`. Если и он окажется пустым — тот же скрипт с
`-FontType Normal` даёт шрифт чата, который заведомо рисует кириллицу (мельче). Вернуть сток —
`-FontType LargeFontType_4` либо восстановить `interface.xdat.prefont.bak`, который скрипт кладёт
рядом при первом запуске.

Скрипт правит файл библиотеками самого XDAT Editor'а (`-EditorDir`, по умолчанию папка редактора на
рабочем столе) и проверяет себя трижды: холостая перезапись обязана повторить вход байт в байт,
размер файла не должен измениться, а отличаться должны ровно 32 байта — по одному на бокс. После
записи файл перечитывается целиком.

`interface.xdat` игрокам нужно раздать: проверка `ClientVersion` следит за `interface.u` и про xdat
ничего не знает, так что стоковый клиент останется с пустой строкой, но работать не перестанет.

## 7. Что ещё можно было сделать

Объявить `broadcast2` в `TTFontInfo.ini` (`[FontUsage] Font4=broadcast2`, `[FontName] Font4=Tahoma`
и размер) — родной для NCsoft путь, и надпись осталась бы крупной TrueType'ой. **Не проверено:**
в импортах `d3ddrv.dll` из семейства GGO есть только `GetGlyphOutlineA`, а ANSI-вариант берёт символ
через кодовую страницу набора, которым создан шрифт, — то есть кириллица могла бы остаться пустой и
с настроенным шрифтом. Растровый шрифт эту неопределённость обходит целиком.
