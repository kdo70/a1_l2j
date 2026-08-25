class CommandChannelAPI extends Object
	native;

native static function RequestCommandChannelInfo();
native static function RequestCommandChannelBanParty(String PartyMasterName);
native static function RequestCommandChannelWithdraw();
native static function RequestCommandChannelPartyMembersInfo(int MasterID);
