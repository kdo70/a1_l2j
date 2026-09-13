-- monster only weapons : tools/weapons/monster_only.ps1, see tools/weapons/monster_only.csv
DELETE FROM droplist WHERE item_id IN (67,73,74,76,86,87,96,123,127,147,152,153,156,160,223,228,298,1299,2252,2255,2300,2301,2313,2315,2316,2328,2357);
DELETE FROM character_recipebook WHERE recipeId IN (145,148,193,194,206,208,209,221,250);
-- then in game : //reload drop
