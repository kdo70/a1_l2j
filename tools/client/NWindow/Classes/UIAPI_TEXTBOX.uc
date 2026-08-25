class UIAPI_TEXTBOX extends UIAPI_WINDOW
	native;

native static function SetTextColor( string ControlName, color a_Color );
native static function SetText(string ControlName,string Text);
native static function SetAlign(string ControlName,ETextAlign align);
native static function SetInt(string ControlName,int Number);
native static function string GetText(string ControlName);
native static function SetTooltipString(string ControlName,string Text);
