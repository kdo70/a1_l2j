-- Ручной спавн GM-а : всё, что заспавнено командой //spawn, живёт здесь и переживает рестарт.
-- Таблицу наполняет и чистит сам сервер (//spawn добавляет строку, //delete по этому NPC её убирает),
-- но править её руками тоже можно — сервер перечитывает таблицу на //reload spawn.
--
-- Файл НЕ сносит таблицу : в отличие от sql/spawnlist.sql это не ретейльные данные, а нажитое на сервере.
--
--   npc_id          id NPC из data/xml/npcs
--   loc_x/y/z       координаты спавна ; Z сервер уточняет по геодате при спавне
--   heading         поворот, 0..65535 ; -1 — случайный при каждом спавне
--   respawn_delay   секунды до возрождения после смерти ; 0 — не возрождается до рестарта
--   respawn_random  случайный разброс респауна в секундах, +/- к respawn_delay
--   enabled         0 выключает строку, не удаляя её
--   created_by      имя GM-а, поставившего спавн
--   created_at      unix-время в миллисекундах

CREATE TABLE IF NOT EXISTS `spawnlist_custom` (
	`id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
	`npc_id` INT UNSIGNED NOT NULL,
	`loc_x` INT NOT NULL DEFAULT 0,
	`loc_y` INT NOT NULL DEFAULT 0,
	`loc_z` INT NOT NULL DEFAULT 0,
	`heading` MEDIUMINT NOT NULL DEFAULT 0,
	`respawn_delay` INT UNSIGNED NOT NULL DEFAULT 60,
	`respawn_random` INT UNSIGNED NOT NULL DEFAULT 0,
	`enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1,
	`created_by` VARCHAR(35) DEFAULT NULL,
	`created_at` BIGINT UNSIGNED NOT NULL DEFAULT 0,
	PRIMARY KEY (`id`),
	KEY `npc_id` (`npc_id`)
);
