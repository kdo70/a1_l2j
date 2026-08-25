class PartyMatchAPI extends Object
	native;

native static function RequestOpenPartyMatch();
native static function RequestPartyRoomList( int a_Page, int a_LocationFilter, int a_LevelFilter );
native static function RequestJoinPartyRoom( int a_RoomNumber );
native static function RequestJoinPartyRoomAuto( int a_Page, int a_LocationFilter, int a_LevelFilter );
native static function RequestManagePartyRoom( int a_RoomNumber, int a_MaxPartyMemberCount, int a_MinLevel, int a_MaxLevel, String a_RoomTitle );
native static function RequestDismissPartyRoom( int a_RoomNumber );
native static function RequestWithdrawPartyRoom( int a_RoomNumber );
native static function RequestBanFromPartyRoom( int a_MemberID );
native static function RequestPartyMatchWaitList( int a_Page, int a_MinLevel, int a_MaxLevel, int RoomType );
native static function RequestExitPartyMatchingWaitingRoom();
native static function RequestAskJoinPartyRoom( string a_Name );
