class GMAPI extends UIEventManager
	native;

native static function BeginGMChangeServer( int a_ServerID, Vector a_PlayerLocation );
native static function RequestGMCommand( EGMCommandType a_GMCommandType, optional String a_Param );
native static function bool GetObservingUserInfo( out UserInfo a_ObservingUserInfo );
native static function RequestSnoopEnd( int a_SnoopID );
