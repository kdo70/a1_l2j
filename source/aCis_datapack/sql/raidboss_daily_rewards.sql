CREATE TABLE IF NOT EXISTS `raidboss_daily_rewards` (
  `char_id` INT UNSIGNED NOT NULL DEFAULT 0,
  `place` INT UNSIGNED NOT NULL DEFAULT 0,
  `item_id` INT UNSIGNED NOT NULL DEFAULT 0,
  `count` INT UNSIGNED NOT NULL DEFAULT 0,
  `kind` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  KEY `char_id` (`char_id`)
);

-- "kind" tells the daily ladder rewards (0) from the monthly ones (1) : the only thing which differs
-- once the reward is stored is the message its winner is told about it.
-- On a server which already holds this table, add it with :
-- ALTER TABLE `raidboss_daily_rewards` ADD COLUMN `kind` TINYINT UNSIGNED NOT NULL DEFAULT 0;
