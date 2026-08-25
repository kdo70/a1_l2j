class UIDATA_QUEST extends UIDataManager
	native;

native static function int GetFirstID();
native static function int GetNextID();
native static function bool IsValidData(int id);
native static function bool IsMinimapOnly(int id,int level);
native static function string GetQuestName(int id);
native static function string GetQuestJournalName(int id,int level);
native static function string GetQuestDescription(int id,int level);
native static function string GetQuestItem(int id,int level);
native static function Vector GetTargetLoc(int id,int level);
native static function string GetTargetName(int id,int level);
native static function Vector GetStartNPCLoc(int id, int level);
native static function int GetStartNPCID(int id,int level);
native static function string GetRequirement(int id,int level);
native static function string GetIntro(int id,int level);
native static function int GetMinLevel(int id,int level);
native static function int GetMaxLevel(int id,int level);
native static function int GetQuestType(int id,int level);
native static function int GetClearedQuest(int id,int level);
native static function int GetQuestZone(int id,int level);
native static function bool IsShowableJournalQuest(int id,int level);
native static function bool IsShowableItemNumQuest(int id,int level);

//货肺款 ParamStack栏肺 老窜 林籍贸府
//2006.7 ttmayrin
//native static function ParamStack GetClassRequirement(int id);
//native static function ParamStack GetItemRequirement(int id,int level);
