CREATE TABLE IF NOT EXISTS `character_offline_trade_items` (
  `charId` INT UNSIGNED NOT NULL DEFAULT '0',
  `item` INT UNSIGNED NOT NULL DEFAULT '0',
  `count` INT UNSIGNED NOT NULL DEFAULT '0',
  `price` INT UNSIGNED NOT NULL DEFAULT '0',
  KEY `charId` (`charId`)
);
