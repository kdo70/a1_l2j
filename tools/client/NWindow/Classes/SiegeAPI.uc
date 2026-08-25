class SiegeAPI extends Object
	native;

native static function RequestCastleSiegeAttackerList(int CastleID);
native static function RequestCastleSiegeDefenderList(int CastleID);
native static function RequestJoinCastleSiege(int CastleID, int IsAttacker, int IsRegister);
native static function RequestConfirmCastleSiegeWaitingList(int CastleID, int ClanID, int IsRegister);
native static function RequestSetCastleSiegeTime(int CastleID, int TimeID);
