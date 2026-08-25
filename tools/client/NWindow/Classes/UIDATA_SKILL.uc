class UIDATA_SKILL extends UIDataManager
	native;

native static function int GetFirstID();
native static function int GetNextID();
native static function int GetDataCount();
native static function string GetIconName( int classID, int level );
native static function string GetName( int classID, int level );
native static function string GetDescription( int classID, int level );
native static function string GetEnchantName( int classID, int level );
native static function int GetEnchantSkillLevel( int classID, int level );
native static function string GetOperateType( int classID, int level );
native static function int GetHpConsume( int classID, int level );
native static function int GetMpConsume( int classID, int level );
native static function int GetCastRange( int classID, int level );
