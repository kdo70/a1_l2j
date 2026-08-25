class UIDATA_HENNA extends UIDataManager
	native;

native static function bool GetItemName( int a_ID, out String a_ItemName );
native static function bool GetDescription( int a_ID, out String a_Description );
native static function bool GetIconTex( int a_ID, out String a_IconTex );
