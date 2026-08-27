-- Adds the "skills" and "name_color" columns to an items table created before item skills existed.
-- A fresh install gets them from items.sql and doesn't need this file. See docs/item-skills.md.
ALTER TABLE `items` ADD COLUMN IF NOT EXISTS `skills` VARCHAR(255) NOT NULL DEFAULT '' AFTER `time`;
ALTER TABLE `items` ADD COLUMN IF NOT EXISTS `name_color` VARCHAR(6) NOT NULL DEFAULT '' AFTER `skills`;

-- Example : every Short Sword already in the world grants Ring of Ant Queen (passive) and Wind Walk Lv 2
-- (active) to whoever equips it, and shows a golden name. Items owned by an online character have to be
-- edited while he is offline, otherwise the server writes his inventory back over it on logout.
UPDATE `items` SET `skills` = '3562:1;1204:2', `name_color` = 'FFD700' WHERE `item_id` = 1;
