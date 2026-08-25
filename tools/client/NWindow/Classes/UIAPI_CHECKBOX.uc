class UIAPI_CHECKBOX extends UIAPI_WINDOW 
	native;
native static function SetTitle(string ControlName,string Title);
native static function SetCheck(string ControlName,bool bCheck);
native static function bool IsChecked(string ControlName);
native static function bool IsDisable(string ControlName);
native static function SetDisable(string ControlName,bool bDisable);
native static function ToggleDisable(string ControlName);
