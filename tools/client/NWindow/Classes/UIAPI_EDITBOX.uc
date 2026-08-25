class UIAPI_EDITBOX extends UIAPI_WINDOW 
	native;
native static function string GetString(string ControlName);
native static function SetString(string ControlName, string str);
native static function AddString( string ControlName, string str );
native static function SimulateBackspace( string ControlName );
native static function Clear(string ControlName);			// lancelot 2006. 7. 6.
native static function SetEditType( string CotrolName, string Type );
native static function SetHighLight( string CotrolName, bool bHighlight);
