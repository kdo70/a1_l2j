class WindowHandle extends UIEventManager
	native;

var Object m_pTargetWnd;

native final function SetWindowTitle( String a_Title );
native final function ShowWindow();
native final function HideWindow();
native final function bool IsShowWindow();
native final function bool IsMinimizedWindow();
native final function SetTimer( int a_TimerID, int a_DelayMiliseconds );
native final function KillTimer( int a_TimerID );
native final function String GetWindowName();
native final function String GetParentWindowName();
native final function WindowHandle GetParentWindowHandle();
native final function bool IsChildOf( WindowHandle a_hParentWnd );
native final function int GetAlpha();
native final function Rect GetRect();
native final function SetAlpha( int a_Alpha, optional float a_Seconds );
native final function SetWindowSize( int a_Width, int a_Height );
native final function GetWindowSize( out int a_Width, out int a_Height );
native final function SetWindowSizeRel( float fWidthRate, float fHeightRate, int nOffsetWidth, int nOffsetHeight );
native final function SetWindowSizeRel43( float fWidthRate, float fHeightRate, int nOffsetWidth, int nOffsetHeight);	//solasys

native final function SetAnchor( string AnchorWindowName, string RelativePoint, string AnchorPoint, int offsetX, int offsetY );
native final function ClearAnchor();
native final function bool IsAnchored();
native final function bool IsDraggable();
native final function SetDraggable( bool a_Draggable );
native final function EnableWindow();
native final function DisableWindow();
native final function bool IsEnableWindow();
native final function SetFocus();
native final function bool IsFocused();
native final function ReleaseFocus();
native final function UIScript GetScript();

native final function SetTooltipText( string Text );
native final function string GetTooltipText();
native final function SetTooltipType( string TooltipType );
native final function SetTooltipCustomType( CustomTooltip Info );
native final function GetTooltipCustomType( out CustomTooltip Info );

native final function SetFrameSize(int nWidth, int nHeight);
native final function SetResizeFrameSize(int nWidth, int nHeight);

native final function Move( int a_nDeltaX, int a_nDeltaY, optional float a_Seconds );
native final function MoveTo( int a_nX, int a_nY );
native final function MoveEx( int a_nX, int a_nY );
native final function MoveShake( int a_nRange, int a_nSet, optional float a_Seconds );	//solasys

native final function NotifyAlarm();

native final function SetScrollPosition(int pos);

native final function SetSettledWnd( bool bFlag );

// (cpptext)
// (cpptext)
// (cpptext)
// (cpptext)
