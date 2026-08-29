-- Merges the enchant scrolls and the life stones a character already owns into single stacks.
--
-- Making an item stackable only changes what happens to items created from then on : the rows that
-- already exist stay one item each, and the inventory keeps showing them as separate cells until
-- they happen to be re-added (a warehouse round trip, a trade). This script does that merge once.
--
-- RUN IT WITH THE GAME SERVER STOPPED, on a fresh dump : it deletes rows from `items`.
--
-- See docs/stackable-scrolls-and-life-stones.md.

DROP TEMPORARY TABLE IF EXISTS stack_rows;
DROP TEMPORARY TABLE IF EXISTS stack_keep;
DROP TEMPORARY TABLE IF EXISTS stack_drop;

-- Every row that is a candidate, with the key it gets merged on. Freight is the one location where
-- loc_data isn't a display slot but the destination village, so it stays part of the key.
CREATE TEMPORARY TABLE stack_rows AS
SELECT
	object_id,
	owner_id,
	item_id,
	loc,
	CASE WHEN loc = 'FREIGHT' THEN loc_data ELSE 0 END AS gkey,
	enchant_level,
	custom_type1,
	custom_type2,
	mana_left,
	`time`,
	skills,
	name_color,
	`count`
FROM items
WHERE
	item_id IN (
		729, 730, 731, 732,
		947, 948, 949, 950, 951, 952, 953, 954, 955, 956, 957, 958, 959, 960, 961, 962,
		6569, 6570, 6571, 6572, 6573, 6574, 6575, 6576, 6577, 6578,
		8723, 8724, 8725, 8726, 8727, 8728, 8729, 8730, 8731, 8732,
		8733, 8734, 8735, 8736, 8737, 8738, 8739, 8740, 8741, 8742,
		8743, 8744, 8745, 8746, 8747, 8748, 8749, 8750, 8751, 8752,
		8753, 8754, 8755, 8756, 8757, 8758, 8759, 8760, 8761, 8762
	)
	AND owner_id IS NOT NULL AND owner_id > 0
	AND loc IN ('INVENTORY', 'WAREHOUSE', 'CLANWH', 'FREIGHT', 'PET_INVENTORY');

CREATE INDEX ix_stack_rows ON stack_rows (owner_id, item_id, loc, gkey);

-- The row of each group that survives, and the count it ends up with.
CREATE TEMPORARY TABLE stack_keep AS
SELECT
	MIN(object_id) AS keep_id,
	SUM(`count`) AS total,
	owner_id, item_id, loc, gkey, enchant_level, custom_type1, custom_type2, mana_left, `time`, skills, name_color
FROM stack_rows
GROUP BY owner_id, item_id, loc, gkey, enchant_level, custom_type1, custom_type2, mana_left, `time`, skills, name_color
HAVING COUNT(*) > 1;

CREATE TEMPORARY TABLE stack_drop AS
SELECT r.object_id
FROM stack_rows r
JOIN stack_keep k
	ON k.owner_id = r.owner_id AND k.item_id = r.item_id AND k.loc = r.loc AND k.gkey = r.gkey
	AND k.enchant_level = r.enchant_level AND k.custom_type1 = r.custom_type1 AND k.custom_type2 = r.custom_type2
	AND k.mana_left = r.mana_left AND k.`time` = r.`time` AND k.skills = r.skills AND k.name_color = r.name_color
WHERE r.object_id <> k.keep_id;

-- What is about to happen.
SELECT COUNT(*) AS stacks_formed, SUM(total) AS items_involved FROM stack_keep;
SELECT COUNT(*) AS rows_deleted FROM stack_drop;

UPDATE items i JOIN stack_keep k ON i.object_id = k.keep_id SET i.`count` = k.total;

DELETE FROM items WHERE object_id IN (SELECT object_id FROM stack_drop);

-- Shortcuts pointing at a row that just went away. Harmless if left over, but the slot stays dead.
DELETE FROM character_shortcuts
WHERE type = 'ITEM' AND id IN (SELECT object_id FROM stack_drop);

DROP TEMPORARY TABLE stack_rows;
DROP TEMPORARY TABLE stack_keep;
DROP TEMPORARY TABLE stack_drop;
