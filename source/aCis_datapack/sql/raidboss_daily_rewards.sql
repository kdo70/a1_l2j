CREATE TABLE IF NOT EXISTS `raidboss_daily_rewards` (
  `char_id` INT UNSIGNED NOT NULL DEFAULT 0,
  `place` INT UNSIGNED NOT NULL DEFAULT 0,
  `item_id` INT UNSIGNED NOT NULL DEFAULT 0,
  `count` INT UNSIGNED NOT NULL DEFAULT 0,
  KEY `char_id` (`char_id`)
);
