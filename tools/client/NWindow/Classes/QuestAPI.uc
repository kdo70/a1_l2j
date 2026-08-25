class QuestAPI extends Object
	native;
	
native static function RequestQuestList();
native static function RequestDestroyQuest( int QuestID );
native static function SetQuestTargetInfo( bool QuestOn, bool ShowTargetInRadar, bool ShowArrow, string TargetName, vector TargetPos, int QuestID);
