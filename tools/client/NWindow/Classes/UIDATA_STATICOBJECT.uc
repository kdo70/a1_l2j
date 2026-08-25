class UIDATA_STATICOBJECT extends UIDataManager
	native;

native static function int GetServerObjectNameID(int ID);
native static function EServerObjectType GetServerObjectType(int ID);
native static function int GetServerObjectMaxHP(int ID);
native static function int GetServerObjectHP(int ID);
native static function string GetStaticObjectName(int NameID);
native static function bool GetStaticObjectShowHP( int a_ID );
