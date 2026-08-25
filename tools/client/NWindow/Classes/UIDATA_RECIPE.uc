class UIDATA_RECIPE extends UIDataManager
	native;

native static function int GetRecipeClassID(int id);
native static function string GetRecipeIconName(int id);
native static function int GetRecipeProductID(int id);
native static function int GetRecipeProductNum(int id);
native static function int GetRecipeCrystalType(int id);
native static function int GetRecipeMpConsume(int id);
native static function int GetRecipeLevel(int id);
native static function int GetRecipeIndex(int id);
native static function string GetRecipeDescription(int id);
native static function int GetRecipeSuccessRate(int id);
native static function ParamStack GetRecipeMaterialItem(int id);

native static function string GetRecipeNameBy2Condition(int id, int nSuccessRate);
native static function string GetRecipeIconNameBy2Condition(int id, int nSuccessRate);
native static function string GetRecipeDescriptionBy2Condition(int id, int nSuccessRate);
native static function ParamStack GetRecipeMaterialItemBy2Condition(int id, int nSuccessRate);
