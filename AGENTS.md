# AGENTS.md

## Обзор проекта

Сервер Lineage 2 (Interlude) на базе aCis (L2J). Два серверных процесса:
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

При пуше в `main` workflow `release.yml` последовательно:
1. `build-and-deploy`: ant-компиляция gameserver, инъекция `l2jserver.jar`
   в `build/`, tar-архив, деплой на VPS в `/root/l2server`
   (с бэкапом/восстановлением `hexid.txt` и `geodata`,
   предварительно `killall java`).
2. `configure-server`: sed-подстановка секретов (БД, внешний hostname) в
   `loginserver.properties` и `server.properties` на VPS.
3. `start-servers`: запуск login и game серверов, проверка портов
   2106 и 7777.

Секреты (VPS_*, DB_*, EXTERNAL_HOSTNAME) хранятся в GitHub; в коде и
конфигах их не дублировать. Логи на VPS: `/root/l2server/*/log/stdout.log`.

## Стиль кода и коммиты

- Стиль: Eclipse-настройки в `source/aCis_gameserver/.settings`
  (Java 21, табы). Следовать конвенциям aCis, существующим в кодовой базе;
  комментарии без необходимости не добавлять.
- Коммиты: короткие сообщения (часто на русском), ветка `main`.
