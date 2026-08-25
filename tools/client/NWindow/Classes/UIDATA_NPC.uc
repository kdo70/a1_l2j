class UIDATA_NPC extends UIDataManager
	native;

native static function int GetFirstID();
native static function int GetNextID();
native static function bool IsValidData(int id);
native static function string GetNPCName(int id);
native static function bool GetNpcProperty(int id, out Array<int> arrProperty);
