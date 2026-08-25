class TabHandle extends WindowHandle
	native;

native final function InitTabCtrl();
native final function SetTopOrder(int index, bool bSendMessage);
native final function int GetTopIndex();
native final function SetDisable(int index, bool bDisable);
native final function MergeTab(int index);
