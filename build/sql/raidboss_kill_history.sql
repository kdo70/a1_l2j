CREATE TABLE IF NOT EXISTS `raidboss_kill_history` (
  `boss_id` INT UNSIGNED NOT NULL DEFAULT 0,
  `char_name` VARCHAR(35) NOT NULL DEFAULT '',
  `clan_name` VARCHAR(45) NOT NULL DEFAULT '',
  `kill_time` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  KEY `boss_time` (`boss_id`,`kill_time`)
);
