class UIAPI_NAMECTRL extends UIAPI_WINDOW
	native;
native static function SetName(string ControlName,string Name,ENameCtrlType Type,ETextAlign Align);
native static function SetNameWithColor(string ControlName,string Name,ENameCtrlType Type,ETextAlign Align,Color NameColor);
native static function string GetName(string ControlName);
