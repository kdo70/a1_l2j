class ButtonHandle extends WindowHandle
	native;

native final function String GetButtonName();
native final function SetButtonName( int a_NameID );
native final function SetTexture( string sForeTexture, string sBackTexture, string sHighlightTexture );
