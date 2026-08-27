-- Adds the "skills" and "name_color" columns to an items table created before item skills existed.
-- A fresh install gets them from items.sql and doesn't need this file. See docs/item-skills.md.
--
-- Written the long way round because "ADD COLUMN IF NOT EXISTS" is MariaDB only : this runs on MySQL too,
-- and can be run twice without failing on a column which is already there.

SET @sql := IF(
	(SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'items' AND COLUMN_NAME = 'skills') > 0,
	'SELECT ''column skills already there''',
	'ALTER TABLE `items` ADD COLUMN `skills` VARCHAR(255) NOT NULL DEFAULT '''' AFTER `time`');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
	(SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'items' AND COLUMN_NAME = 'name_color') > 0,
	'SELECT ''column name_color already there''',
	'ALTER TABLE `items` ADD COLUMN `name_color` VARCHAR(6) NOT NULL DEFAULT '''' AFTER `skills`');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Example : every Short Sword already in the world grants Ring of Ant Queen (passive) and Wind Walk Lv 2
-- (active) to whoever equips it, and shows a golden name. Items owned by an online character have to be
-- edited while he is offline, otherwise the server writes his inventory back over it on logout.
UPDATE `items` SET `skills` = '3562:1;1204:2', `name_color` = 'FFD700' WHERE `item_id` = 1;
