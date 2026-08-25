class EventMatchGMFenceWnd extends UICommonAPI;

var ButtonHandle m_hOKButton;
var ButtonHandle m_hCancelButton;
var ButtonHandle m_hMyLocationButton;
var EditBoxHandle m_hXEditBox;
var EditBoxHandle m_hYEditBox;
var EditBoxHandle m_hZEditBox;
var EditBoxHandle m_hXLengthEditBox;
var EditBoxHandle m_hYLengthEditBox;

function OnLoad()
{
	RegisterEvent( EV_ShowEventMatchGMWnd );
	m_hOKButton = ButtonHandle( GetHandle( "OKButton" ) );
	m_hCancelButton = ButtonHandle( GetHandle( "CancelButton" ) );
	m_hMyLocationButton = ButtonHandle( GetHandle( "MyLocationButton" ) );
	m_hXEditBox = EditBoxHandle( GetHandle( "XEditBox" ) );
	m_hYEditBox = EditBoxHandle( GetHandle( "YEditBox" ) );
	m_hZEditBox = EditBoxHandle( GetHandle( "ZEditBox" ) );
	m_hXLengthEditBox = EditBoxHandle( GetHandle( "XLengthEditBox" ) );
	m_hYLengthEditBox = EditBoxHandle( GetHandle( "YLengthEditBox" ) );
}

function OnClickButtonWithHandle( ButtonHandle a_ButtonHandle )
{
	switch( a_ButtonHandle )
	{
	case m_hOKButton:
		OnClickOKButton();
		break;
	case m_hCancelButton:
		OnClickCancelButton();
		break;
	case m_hMyLocationButton:
		OnClickMyLocationButton();
		break;
	}
}

function OnClickOKButton()
{
	local int XLength;
	local int YLength;
	local Vector Position;
	local EventMatchGMWnd GMWndScript;

	XLength = int( m_hXLengthEditBox.GetString() );
	if( !( 100 <= XLength && 5000 > XLength ) )
	{
		DialogShow( DIALOG_Notice, GetSystemMessage( 1414 ) );
		return;
	}

	YLength = int( m_hYLengthEditBox.GetString() );
	if( !( 100 <= YLength && 5000 > YLength ) )
	{
		DialogShow( DIALOG_Notice, GetSystemMessage( 1414 ) );
		return;
	}

	Position.X = int( m_hXEditBox.GetString() );
	Position.Y = int( m_hYEditBox.GetString() );
	Position.Z = int( m_hZEditBox.GetString() );

	m_hOwnerWnd.HideWindow();
	GMWndScript = EventMatchGMWnd( GetScript( "EventMatchGMWnd" ) );
	if( GMWndScript != None )
		GMWndScript.NotifyFenceInfo( Position, XLength, YLength );
}

function OnClickCancelButton()
{
	m_hOwnerWnd.HideWindow();
}

function OnClickMyLocationButton()
{
	local Vector PlayerPosition;

	PlayerPosition = GetPlayerPosition();
	m_hXEditBox.SetString( String( int( PlayerPosition.x ) ) );
	m_hYEditBox.SetString( String( int( PlayerPosition.y ) ) );
	m_hZEditBox.SetString( String( int( PlayerPosition.z ) ) );
}
