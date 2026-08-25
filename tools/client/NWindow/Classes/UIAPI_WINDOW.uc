class UIAPI_WINDOW extends UIEventManager
	native;

native static function bool IsShowWindow( string ControlName );
native static function bool IsMinimizedWindow( string ControlName );
native static function ShowWindow( string ControlName );
native static function HideWindow( string ControlName );
native static function Clear( string ControlName );
native static function Rect GetRect( string ControlName );
native static function SetUITimer(string ControlName, int TimerID,int Delayms);
native static function KillUITimer(string ControlName, int TimerID); 
native static function SetWindowTitle(string ControlName, int Index );
native static function SetWindowTitleByText( string ControlName, string strText );

native static function EnableWindow( string ControlName );
native static function DisableWindow( string ControlName );
native static function bool IsEnableWindow( string ControlName );

native static function SetAlwaysOnTop( string ControlName, bool a_bAlwaysOnTop );

native static function SetAlpha( string ControlName, int a_nAlpha, optional float a_Seconds );
native static function Move( string ControlName, int a_nDeltaX, int a_nDeltaY, optional float a_Seconds );
native static function MoveTo( string ControlName, int a_nX, int a_nY );
native static function MoveEx( string ControlName, int a_nX, int a_nY );
native static function MoveShake( string ContorlName, int a_nRange, int a_nSet, optional float a_Seconds );	//solasys
native static function Iconize( string ControlName, string Texture, int tooltip );
native static function NotifyAlarm( string ControlName );

native static function SetFocus( string ControlName );
native static function bool IsFocused( string ControlName );
native static function SetWindowSize( string ControlName, int nWidth, int nHeight);
native static function SetWindowSizeRel( string ControlName, float fWidthRate, float fHeightRate, int nOffsetWidth, int nOffsetHeight);
native static function SetWindowSizeRel43( string ControlName, float fWidthRate, float fHeightRate, int nOffsetWidth, int nOffsetHeight);	//solasys
native static function SetFrameSize( string ControlName, int nWidth, int nHeight);
native static function SetResizeFrameSize( string ControlName, int nWidth, int nHeight);
native static function SetTabOrder( string ControlName, string NextName, string PreName );
native static function SetTooltipType( string ControlName, string TooltipType );
native static function SetTooltipText( string ControlName, string Text );
native static function string GetTooltipText( string ControlName );

native static function SetAnchor( string ControlName, string AnchorWindowName, string RelativePoint, string AnchorPoint, int offsetX, int offsetY );
native static function ClearAnchor( string ControlName );

native static function String GetSelectedRadioButtonName( string a_ControlID, int a_RadioGroupID );
