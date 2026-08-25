class UIDATA_HUNTINGZONE extends UIDataManager
	native;

native static function bool IsValidData(int id);
native static function string GetHuntingZoneName(int id);
native static function int GetHuntingZoneType(int id);
native static function int GetMinLevel(int id);
native static function int GetMaxLevel(int id);
native static function Vector GetHuntingZoneLoc(int id);
native static function int GetHuntingZone(int id);
native static function string GetHuntingDescription(int id);
