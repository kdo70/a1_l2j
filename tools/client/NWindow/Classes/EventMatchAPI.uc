class EventMatchAPI extends UIEventManager
	native;

native static function bool GetEventMatchData( out EventMatchData a_EventMatchData );
native static function int GetScore( int a_TeamID );
native static function String GetTeamName( int a_TeamID );
native static function int GetPartyMemberCount( int a_TeamID );
native static function bool GetUserData( int a_TeamID, int a_UserID, out EventMatchUserData a_UserData );
native static function SetSelectedUser( int a_TeamID, int a_UserID );
