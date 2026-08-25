class UIAPI_PROGRESSCTRL extends UIAPI_WINDOW 
	native;
native static function SetProgressTime(string ControlName,int Millitime);
native static function SetPos(string ControlName,int Millitime);
native static function Reset(string ControlName);
native static function Stop(string ControlName);
native static function Resume(string ControlName);
native static function Start(string ControlName);
