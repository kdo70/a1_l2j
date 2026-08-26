# AGENTS.md

## Обзор проекта

Сервер Lineage2 (Interlude) на базе aCis (L2J). Два серверных процесса:
Login Server (порт 2106) и Game Server (порт 7777). Стек: Java 21,
Apache Ant, MariaDB/MySQL, Eclipse-проекты (без Maven/Gradle).

## Структура репозитория

```
source/aCis_gameserver/      Java-код серверов (основной проект)
  java/net/sf/l2j/           пакеты: gameserver, loginserver, commons,
                             accountmanager, gsregistering, Config.java
  config/                    *.properties (server, loginserver, players,
                             npcs, clans, siege, events, geoengine, ...)
  lib/                       зависимости (mariadb-java-client-3.1.4.jar)
  dist/                      скрипты запуска (.sh/.bat), копируются в сборку
  build.xml                  Ant-сборка (цель по умолчанию: dist)
source/aCis_datapack/        датапак (контент)
  data/                      xml, html, geodata
  sql/                       SQL-схемы таблиц
  tools/                     database_installer и служебные скрипты
  build.xml                  Ant-синхронизация датапака в build/
build/                       ГОТОВАЯ ДИСТРИБУТИВНАЯ СБОРКА (в git, ~16k файлов)
  login/, gameserver/        jars, libs, конфиги, скрипты запуска
  sql/                       SQL-схемы (из датапака)
  tools/                     database_installer.bat/.sh, full_install.sql
.github/workflows/release.yml  CI/CD на push в main
.github/actions/             composite actions: build-and-deploy,
                             configure-server, start-servers
build.bat                    локальная сборка (Windows)
```

## Сборка и проверка

Требования: **JDK 21**, **Apache Ant**, `java` и `ant` в PATH.

```powershell
# Быстрая проверка компиляции Java-кода (предпочтительно):
ant -f source\aCis_gameserver\build.xml

# Полная сборка (полный пересбор: ant gameserver + ant datapack + сборка build/):
.\build.bat
```

ВАЖНО: `build.bat` содержит `pause` в конце — при запуске из
неинтерактивного окружения может зависнуть. Для проверки компиляции
использовать `ant` напрямую (см. выше).

Режимы `build.bat`:
- `build/` отсутствует -> полный режим: компиляция обоих проектов и
  пересборка папки `build/`.
- `build/` существует -> инкрементальный: только ant gameserver + копирование
  `l2jserver.jar` в `build/login/libs` и `build/gameserver/libs`.

Тестов и линтеров в проекте нет. Единственный способ верификации изменений —
успешная компиляция через ant. При изменениях в датапаке (xml/html/sql)
проверить валидность синтаксиса (для xml) вручную.

## Особенности, которые нужно знать

- **Ядро пересобирается само при деплое — коммитить `l2jserver.jar` не нужно.**
  `build-and-deploy` запускает ant по `source/aCis_gameserver/build.xml` и сам
  подкладывает свежий `l2jserver.jar` в `build/login/libs` и
  `build/gameserver/libs`. Локальный `build.bat` нужен только если хочется
  проверить сборку целиком; для проверки правок достаточно
  `ant -f source\aCis_gameserver\build.xml`.
- **А вот датапак и конфиги CI не пересобирает** — они уезжают на VPS ровно
  такими, какими лежат в закоммиченной папке `build/`. Любая правка в
  `source/aCis_datapack/data/**` или `source/aCis_gameserver/config/**`
  должна быть скопирована в `build/gameserver/data/**` /
  `build/gameserver/config/**` в том же коммите, иначе на сервер она
  не попадёт.
- Папка `build/` закоммичена в git — это релизный артефакт. Не удалять её
  и не пересобирать полностью без необходимости; при изменении только
  Java-кода достаточно инкрементального режима (обновляется только
  `l2jserver.jar` в `build/login/libs` и `build/gameserver/libs`).
- При изменении контента датапака (`source/aCis_datapack/data`) содержимое
  должно быть синхронизировано в `build/gameserver/data` (ant в
  `source/aCis_datapack`, цель `build`, использует `<sync>`).
- JAR собирается как `source/aCis_gameserver/build/l2jserver.jar`
  (Main-Class: `net.sf.l2j.Server`).
- `.gitignore` в `source/aCis_gameserver` игнорирует локальные `/build/`,
  `/bin/`, `/log/`, `/data/` внутри этого проекта — это нормально,
  речь про локальные артефакты ant, а не про корневой `build/`.
- БД: MariaDB. Установка схемы — `build/tools/database_installer.bat/.sh`
  (параметры БД задаются в начале скрипта; по умолчанию БД `acis`,
  пользователь `root`).

## CI/CD (.github)

Файлы workflow и composite actions написаны на английском.

При пуше в `main` (кроме `*.md`, `.gitignore`, `.idea/`) workflow
`release.yml` последовательно:
0. `preflight`: проверка наличия обязательных секретов до того, как
   что-либо будет сделано с работающим сервером.
1. `build-and-deploy`: ant-компиляция gameserver, инъекция `l2jserver.jar`
   в `build/`, tar-архив + sha256, загрузка на VPS. На VPS: сверка
   контрольной суммы, распаковка в `/root/l2server.new`, проверка структуры,
   перенос `hexid.txt` и `geodata` из текущей установки, только затем
   остановка процессов и атомарная подмена каталога. Предыдущий релиз
   остаётся в `/root/l2server.old` для отката.
2. `configure-server`: подстановка секретов в `loginserver.properties` и
   `server.properties` на VPS, включая JDBC `URL`
   (`jdbc:mariadb://DB_HOST:DB_PORT/DB_NAME_*`). Все адреса
   (`Hostname`, `LoginserverHostname`, `LoginHostname`,
   `GameserverHostname`, `LoginHost`) выставляются в `EXTERNAL_HOSTNAME` —
   то есть он используется и как анонсируемый клиентам, и как bind-адрес,
   поэтому VPS должен владеть этим IP напрямую (за NAT не заработает).
3. `start-servers`: идемпотентный рестарт login и game серверов с ожиданием
   портов 2106, 9014 и 7777. Если порт не поднялся — шаг падает и выводит
   хвост соответствующего `stdout.log`.
4. `summary`: таблица результатов в GitHub Step Summary.

Ручной запуск: `workflow_dispatch` с флагом `restart_only` — пропускает
сборку и деплой, только применяет конфиги и перезапускает серверы.

Секреты (VPS_*, DB_*, EXTERNAL_HOSTNAME) хранятся в GitHub; в коде и
конфигах их не дублировать. Необязательные: `VPS_PORT` (по умолчанию 22) и
`VPS_SSH_FINGERPRINT` (если не задан — host key VPS не проверяется).
Логи на VPS: `/root/l2server/*/log/stdout.log`.

Остановка серверов идёт по точному совпадению (`l2jserver.jar`,
`*_loop.sh`), а не `killall java` — посторонние Java-процессы на VPS
не затрагиваются.

## Модификация клиента

Клиент Interlude (`interface.u`, `interface.xdat`) правится из этого же
репозитория: инструменты в `tools/client`, пошаговая инструкция —
`tools/client/README.md`.

Накопленные знания по форматам клиента, пересборке `interface.u` и найденным
ловушкам (главная: `defaultproperties` не хранятся в `ScriptText`, и
пересборка «как есть» ломает весь интерфейс) — в
`docs/enchant-and-client-modding.md`. Читать **до** любых правок клиента.

Цвет названий предметов задаётся в датапаке (`name_color` в
`data/xml/items`) и уезжает на клиент отдельным каналом — устройство и
ограничения в `docs/item-name-colors.md`.

Числа, которые клиент показывает в подсказке предмета (п. атака, м. атака,
защита, вес и прочее), лежат в клиентских `weapongrp.dat`/`armorgrp.dat`, но
могут приезжать с сервера из `data/xml/items` — клиент спрашивает их сам,
устройство и ограничения в `docs/item-stats-from-server.md`.

Пересобранный клиент сообщает серверу свою версию, и сервер отключает тех, у
кого она не совпала с `ClientVersion` в `config/server.properties`, — так
раздаётся обязательное обновление `interface.u`. Устройство и ограничения в
`docs/client-version-check.md`. При каждой пересборке `interface.u`, которую
игроки обязаны забрать, поднимать `CLIENTVER_VALUE` в `ToolTip.uc` и
`ClientVersion` **вместе**.

## Стиль кода и коммиты

- Стиль: Eclipse-настройки в `source/aCis_gameserver/.settings`
  (Java 21, табы). Следовать конвенциям aCis, существующим в кодовой базе;
  комментарии без необходимости не добавлять.
- Коммиты: короткие сообщения (часто на русском), ветка `main`.
