CREATE TABLE IF NOT EXISTS `gatekeeper_stats` (
  `loc_id` INT UNSIGNED NOT NULL DEFAULT 0,
  `teleport_count` INT UNSIGNED NOT NULL DEFAULT 0,
  `last_used` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`loc_id`),
  KEY `teleport_count` (`teleport_count`)
);
