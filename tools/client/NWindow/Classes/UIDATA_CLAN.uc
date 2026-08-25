class UIDATA_CLAN extends UIDataManager
	native;

native static function string GetName(int ID);
native static function string GetAllianceName(int ID);
native static function bool GetCrestTexture(int ID, out texture texCrest);
native static function bool GetEmblemTexture(int ID, out texture emblemTexture);
native static function bool GetAllianceCrestTexture(int ID, out texture texCrest);
native static function bool	GetNameValue( int ID, out int namevalue );
