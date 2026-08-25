class UIDATA_USER extends UIDataManager
	native;

native static function string GetUserName(int ServerID);
native static function bool GetClanType( int ID, out int type );
