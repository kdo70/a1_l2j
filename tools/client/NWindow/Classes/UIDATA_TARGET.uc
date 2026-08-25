class UIDATA_TARGET extends UIDataManager
	native;

native static function int GetTargetID();
native static function int GetTargetUserRank();
native static function int GetTargetMaxHP();
native static function int GetTargetHP();
native static function int GetTargetMaxMP();
native static function int GetTargetMP();
native static function string GetTargetName();
native static function color GetTargetNameColor(int Level);
native static function int GetTargetPledgeID();
native static function int GetTargetClassID();
native static function bool IsServerObject();
native static function bool IsNpc();
native static function bool IsPet();
native static function bool IsCanBeAttacked();
native static function bool IsHPShowableNPC();
