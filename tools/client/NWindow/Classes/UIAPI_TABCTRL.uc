class UIAPI_TABCTRL extends UIAPI_WINDOW
	native;
//tab 컨트롤 초기화 onshow에서 호출 해줘야한다.
native static function InitTabCtrl(string ControlName);
native static function SetTopOrder(string ControlName, int index, bool bSendMessage);
native static function int GetTopIndex(string ControlName);
native static function SetDisable( string ControlName, int index, bool bDisable );
