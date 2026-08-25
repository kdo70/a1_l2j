class EventMatchSpecialMsgWnd extends UICommonAPI;

const TIMERID_Hide = 1;

var TextureHandle MessageTex;

function OnLoad()
{
	MessageTex = TextureHandle( GetHandle( "MsgTex" ) );

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
	local String TextureName;
	local int TextureWidth;
	local int TextureHeight;

	ParseInt( a_Param, "Type", Type );
	ParseString( a_Param, "Message", Message );

	switch( EEventMatchObsMsgType( Type ) )
	{
	case MESSAGE_Finish:
		TextureName = "L2UI_CH3.BroadcastObs.br_msg1_finish";
		TextureWidth = 512;
		TextureHeight = 256;
		break;
	case MESSAGE_Start:
		TextureName = "L2UI_CH3.BroadcastObs.br_msg1_start";
		TextureWidth = 512;
		TextureHeight = 512;
		break;
	case MESSAGE_GameOver:
		TextureName = "L2UI_CH3.BroadcastObs.br_msg1_gameover";
		TextureWidth = 512;
		TextureHeight = 256;
		break;
	case MESSAGE_1:
		TextureName = "L2UI_CH3.BroadcastObs.br_msg1_count1";
		TextureWidth = 256;
		TextureHeight = 256;
		break;
	case MESSAGE_2:
		TextureName = "L2UI_CH3.BroadcastObs.br_msg1_count2";
		TextureWidth = 256;
		TextureHeight = 256;
		break;
	case MESSAGE_3:
		TextureName = "L2UI_CH3.BroadcastObs.br_msg1_count3";
		TextureWidth = 256;
		TextureHeight = 256;
		break;
	case MESSAGE_4:
		TextureName = "L2UI_CH3.BroadcastObs.br_msg1_count4";
		TextureWidth = 256;
		TextureHeight = 256;
		break;
	case MESSAGE_5:
		TextureName = "L2UI_CH3.BroadcastObs.br_msg1_count5";
		TextureWidth = 256;
		TextureHeight = 256;
		break;
	default:
		return;
	}

	MessageTex.SetWindowSize( TextureWidth, TextureHeight );
	MessageTex.SetTextureSize( TextureWidth, TextureHeight );
	MessageTex.SetTexture( TextureName );
	m_hOwnerWnd.ShowWindow();
	m_hOwnerWnd.KillTimer( TIMERID_Hide );
	m_hOwnerWnd.SetTimer( TIMERID_Hide, 5000 );
}
