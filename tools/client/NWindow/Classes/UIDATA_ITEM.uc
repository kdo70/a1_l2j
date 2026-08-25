class UIDATA_ITEM extends UIDataManager
	native;

native static function int GetFirstID();
native static function int GetNextID();
native static function int GetDataCount();
native static function string GetItemName(int id);
native static function string GetItemAdditionalName(int id);
native static function string GetItemTextureName(int id);
native static function string GetItemDescription(int id);
native static function int GetItemClassID(int id);
native static function int GetItemWeight(int id);
native static function int GetItemDataType( int classID );
native static function int GetItemCrystalType( int classID );
native static function bool GetItemInfo( int classID, out ItemInfo info );
native static function bool IsCrystallizable( int classID );
native static function string GetRefineryItemName( string strItemName, int RefineryOp1, int RefineryOp2 );
native static function GetSetItemIDList( int ClassID, int EffectID, out array<int> arrID );
native static function int GetSetItemEnchantValue( int ClassID );
native static function string GetSetItemEffectDescription( int ClassID, int EffectID );
native static function string GetSetItemEnchantEffectDescription( int ClassID );
