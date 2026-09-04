CREATE TABLE IF NOT EXISTS `raidboss_monthly_wins` (
  `char_id` INT UNSIGNED NOT NULL DEFAULT 0,
  `wins` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`char_id`)
);

-- How many times a character took the first place of the daily ladder since the last monthly reward.
-- It is what the monthly ladder is sorted on, and it is wiped the moment the monthly rewards are
-- handed out - the month starts over from an empty board.
