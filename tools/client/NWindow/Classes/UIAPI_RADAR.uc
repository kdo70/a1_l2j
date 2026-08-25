class UIAPI_RADAR extends UIScript
	native;

native static function AddTarget( String a_ControlID, int a_X, int a_Y, int a_Z );
native static function DeleteTarget( String a_ControlID, int a_X, int a_Y, int a_Z );
native static function DeleteAllTarget( String a_ControlID );
native static function SetRadarColor( String a_ControlID, Color a_RadarColor, float a_Seconds );
