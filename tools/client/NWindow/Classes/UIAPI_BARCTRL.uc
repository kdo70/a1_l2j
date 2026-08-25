class UIAPI_BARCTRL extends UIAPI_WINDOW
	native;
	
native static function SetValue(string ControlName, int MaxValue, int CurValue);
native static function GetValue(string ControlName, out int MaxValue, out int CurValue);
native static function Clear(string ControlName);
