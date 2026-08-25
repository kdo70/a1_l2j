class EventMatchGMMsgWnd extends UICommonAPI;

const TIMERID_Hide = 1;

var TextBoxHandle MessageTextBox;

function OnLoad()
{
	MessageTextBox = TextBoxHandle( GetHandle( "MsgTextBox" ) );

	RegisterEvent( EV_EventMatchGMMessage );
}

function OnEvent( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	case EV_EventMatchGMMessage:
		HandleEventMatchGMMessage( a_Param );
		break;
	default:
		break;
	}
}

function OnTimer( int a_TimerID )
{
	switch( a_TimerID )
	{
	case TIMERID_Hide:
		m_hOwnerWnd.HideWindow();
		MessageTextBox.SetText( "" );
		m_hOwnerWnd.KillTimer( TIMERID_Hide );
		break;
	default:
		break;
	}
}

function HandleEventMatchGMMessage( String a_Param )
{
	local int Type;
	local String Message;

	ParseInt( a_Param, "Type", Type );
	ParseString( a_Param, "Message", Message );

	switch( EEventMatchObsMsgType( Type ) )
	{
	case MESSAGE_GM:
		m_hOwnerWnd.ShowWindow();
		MessageTextBox.SetText( Message );
		m_hOwnerWnd.KillTimer( TIMERID_Hide );
		m_hOwnerWnd.SetTimer( TIMERID_Hide, 5000 );
		break;
	default:
		break;
	}
}
