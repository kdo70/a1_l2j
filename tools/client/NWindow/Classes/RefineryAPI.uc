class RefineryAPI extends UIEventManager
	native;

native static function ConfirmTargetItem( int a_TargetItemServerID );
native static function ConfirmRefinerItem( int a_TargetItemServerID, int a_RefinerItemServerID );
native static function ConfirmGemStone( int a_TargetItemServerID, int a_RefinerItemServerID, int a_GemStoneServerID, int a_GemStoneCount );
native static function RequestRefine( int a_TargetItemServerID, int a_RefinerItemServerID, int a_GemStoneServerID, int a_GemStoneCount );

native static function ConfirmCancelItem( int a_CancelItemServerID );
native static function RequestRefineCancel( int a_CancelItemServerID );
