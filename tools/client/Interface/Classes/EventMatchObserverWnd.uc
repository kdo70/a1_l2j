class EventMatchObserverWnd extends UICommonAPI;

const TIMERID_Show = 1;
const TIMERID_Msg = 2;

enum EMessageMode
{
	MESSAGEMODE_Normal,
	MESSAGEMODE_LeftRight,
	MESSAGEMODE_Off,
};

struct SkillMsgInfo
{
	var int AttackerTeamID;
	var int AttackerUserID;
	var String AttackerName;
	var int DefenderTeamID;
	var int DefenderUserID;
	var String DefenderName;
	var String SkillName;
};

var int m_Score1;
var int m_Score2;
var String m_TeamName1;
var String m_TeamName2;
var int m_SelectedUserID[ 2 ];
var bool m_ClassOrName;

var WindowHandle m_hTopWnd;

var WindowHandle m_hPlayerWnd[ 2 ];
var BarHandle m_hPlayerCPBar[ 2 ];
var BarHandle m_hPlayerHPBar[ 2 ];
var BarHandle m_hPlayerMPBar[ 2 ];

var TextureHandle m_hplayerback1_[ 2 ];
var TextureHandle m_hplayerback2_[ 2 ];
var TextureHandle m_hplayerback3_[ 2 ];

var TextBoxHandle m_hPlayerLvClassTextBox[ 2 ];
var TextBoxHandle m_hPlayerNameTextBox[ 2 ];
var WindowHandle m_hPlayerBuffCoverWnd[ 2 ];
var StatusIconHandle m_hPlayerBuffWnd[ 2 ];

var WindowHandle m_hParty1Wnd;
var WindowHandle m_hParty1MemberWnd[ MAX_PartyMemberCount ];
var TextBoxHandle m_hParty1MemberNameTextBox[ MAX_PartyMemberCount ];
var TextBoxHandle m_hParty1MemberClassTextBox[ MAX_PartyMemberCount ];
var BarHandle m_hParty1MemberHPBar[ MAX_PartyMemberCount ];
var BarHandle m_hParty1MemberCPBar[ MAX_PartyMemberCount ];
var BarHandle m_hParty1MemberMPBar[ MAX_PartyMemberCount ];
var WindowHandle m_hParty1MemberSelectedTex[ MAX_PartyMemberCount ];
var TextureHandle m_hParty1NumberTex[ MAX_PartyMemberCount ];
var TextureHandle m_hparty1back1_[ MAX_PartyMemberCount ];
var TextureHandle m_hparty1back2_[ MAX_PartyMemberCount ];
var TextureHandle m_hparty1back3_[ MAX_PartyMemberCount ];



var WindowHandle m_hParty2Wnd;
var WindowHandle m_hParty2MemberWnd[ MAX_PartyMemberCount ];
var TextBoxHandle m_hParty2MemberNameTextBox[ MAX_PartyMemberCount ];
var TextBoxHandle m_hParty2MemberClassTextBox[ MAX_PartyMemberCount ];
var BarHandle m_hParty2MemberHPBar[ MAX_PartyMemberCount ];
var BarHandle m_hParty2MemberCPBar[ MAX_PartyMemberCount ];
var BarHandle m_hParty2MemberMPBar[ MAX_PartyMemberCount ];
var WindowHandle m_hParty2MemberSelectedTex[ MAX_PartyMemberCount ];
var TextureHandle m_hParty2NumberTex[ MAX_PartyMemberCount ];
var TextureHandle m_hparty2back1_[ MAX_PartyMemberCount ];
var TextureHandle m_hparty2back2_[ MAX_PartyMemberCount ];
var TextureHandle m_hparty2back3_[ MAX_PartyMemberCount ];

var TextBoxHandle m_hTeamName1TextBox;
var TextBoxHandle m_hTeamName2TextBox;
var TextureHandle m_hScore1Tex;
var TextureHandle m_hScore2Tex;

var WindowHandle m_hMsgLeftWnd[ 6 ];
var TextBoxHandle m_hMsgLeftAttackerTextBox[ 6 ];
var TextBoxHandle m_hMsgLeftDefenderTextBox[ 6 ];
var TextBoxHandle m_hMsgLeftSkillTextBox[ 6 ];
var WindowHandle m_hMsgRightWnd[ 6 ];
var TextBoxHandle m_hMsgRightAttackerTextBox[ 6 ];
var TextBoxHandle m_hMsgRightDefenderTextBox[ 6 ];
var TextBoxHandle m_hMsgRightSkillTextBox[ 6 ];

var int m_Party1UserIDList[ MAX_PartyMemberCount ];
var int m_Party2UserIDList[ MAX_PartyMemberCount ];

var int m_MsgStartIndex;
var int m_Team1MsgStartIndex;
var int m_Team2MsgStartIndex;
var SkillMsgInfo m_MsgList[ 6 ];
var SkillMsgInfo m_Team1MsgList[ 6 ];
var SkillMsgInfo m_Team2MsgList[ 6 ];

var EMessageMode m_MsgMode;

function OnLoad()
{
	local int i;

	m_hTopWnd = GetHandle( "TopWnd" );

	m_hTeamName1TextBox = TextBoxHandle( GetHandle( "TopWnd.TeamName1" ) );
	m_hTeamName2TextBox = TextBoxHandle( GetHandle( "TopWnd.TeamName2" ) );

	m_hScore1Tex = TextureHandle( GetHandle( "TopWnd.Score1Tex" ) );
	m_hScore2Tex = TextureHandle( GetHandle( "TopWnd.Score2Tex" ) );

	for( i = 0; i < 2; ++i )
	{
		m_hPlayerWnd[ i ] = GetHandle( "Player" $ i + 1 $ "Wnd" );
		m_hPlayerCPBar[ i ] = BarHandle( GetHandle( "Player" $ i + 1 $ "Wnd.CPBar" ) );
		m_hPlayerHPBar[ i ] = BarHandle( GetHandle( "Player" $ i + 1 $ "Wnd.HPBar" ) );
		m_hPlayerMPBar[ i ] = BarHandle( GetHandle( "Player" $ i + 1 $ "Wnd.MPBar" ) );
		m_hPlayerLvClassTextBox[ i ] = TextBoxHandle( GetHandle( "Player" $ i + 1 $ "Wnd.LvClassTextBox" ) );
		m_hPlayerNameTextBox[ i ] = TextBoxHandle( GetHandle( "Player" $ i + 1 $ "Wnd.NameTextBox" ) );
		m_hPlayerBuffCoverWnd[ i ] = GetHandle( "Player" $ i + 1 $ "BuffWnd" );
		m_hPlayerBuffWnd[ i ] = StatusIconHandle( GetHandle( "Player" $ i + 1 $ "BuffWnd.StatusIconCtrl" ) );
		m_hplayerback1_[ i ] = TextureHandle(GetHandle("Player" $ i + 1 $ "Wnd.BackTex1") );
		m_hplayerback2_[ i ] = TextureHandle(GetHandle("Player" $ i + 1 $ "Wnd.BackTex2") );
		m_hplayerback3_[ i ] = TextureHandle(GetHandle("Player" $ i + 1 $ "Wnd.BackTex3") );
		
	}

	m_hParty1Wnd = GetHandle( "Party1Wnd" );

	for( i = 0; i < MAX_PartyMemberCount; ++i )
	{
		m_hParty1MemberWnd[ i ] = GetHandle( "Party1Wnd.PartyMember" $ i + 1 $ "Wnd" );
		m_hParty1MemberNameTextBox[ i ] = TextBoxHandle( GetHandle( "Party1Wnd.PartyMember" $ i + 1 $ "Wnd.Name" ) );
		m_hParty1MemberClassTextBox[ i ] = TextBoxHandle( GetHandle( "Party1Wnd.PartyMember" $ i + 1 $ "Wnd.Class" ) );
		m_hParty1MemberHPBar[ i ] = BarHandle( GetHandle( "Party1Wnd.PartyMember" $ i + 1 $ "Wnd.HPBar" ) );
		m_hParty1MemberCPBar[ i ] = BarHandle( GetHandle( "Party1Wnd.PartyMember" $ i + 1 $ "Wnd.CPBar" ) );
		m_hParty1MemberMPBar[ i ] = BarHandle( GetHandle( "Party1Wnd.PartyMember" $ i + 1 $ "Wnd.MPBar" ) );
		m_hParty1MemberSelectedTex[ i ] = GetHandle( "Party1Wnd.PartyMember" $ i + 1 $ "Wnd.SelectedTex" );
		m_hParty1NumberTex[ i ] = TextureHandle(GetHandle("Party1Wnd.PartyMember" $ i + 1 $ "Wnd.NumberTex") );
		m_hparty1back1_[ i ] = TextureHandle(GetHandle("Party1Wnd.PartyMember" $ i + 1 $ "Wnd.BackTex1") );
		m_hparty1back2_[ i ] = TextureHandle(GetHandle("Party1Wnd.PartyMember" $ i + 1 $ "Wnd.BackTex2") );
		m_hparty1back3_[ i ] = TextureHandle(GetHandle("Party1Wnd.PartyMember" $ i + 1 $ "Wnd.BackTex3") );
	}

	m_hParty2Wnd = GetHandle( "Party2Wnd" );

	for( i = 0; i < MAX_PartyMemberCount; ++i )
	{
		m_hParty2MemberWnd[ i ] = GetHandle( "Party2Wnd.PartyMember" $ i + 1 $ "Wnd" );
		m_hParty2MemberNameTextBox[ i ] = TextBoxHandle( GetHandle( "Party2Wnd.PartyMember" $ i + 1 $ "Wnd.Name" ) );
		m_hParty2MemberClassTextBox[ i ] = TextBoxHandle( GetHandle( "Party2Wnd.PartyMember" $ i + 1 $ "Wnd.Class" ) );
		m_hParty2MemberHPBar[ i ] = BarHandle( GetHandle( "Party2Wnd.PartyMember" $ i + 1 $ "Wnd.HPBar" ) );
		m_hParty2MemberCPBar[ i ] = BarHandle( GetHandle( "Party2Wnd.PartyMember" $ i + 1 $ "Wnd.CPBar" ) );
		m_hParty2MemberMPBar[ i ] = BarHandle( GetHandle( "Party2Wnd.PartyMember" $ i + 1 $ "Wnd.MPBar" ) );
		m_hParty2MemberSelectedTex[ i ] = GetHandle( "Party2Wnd.PartyMember" $ i + 1 $ "Wnd.SelectedTex" );
		m_hParty2NumberTex[ i ] = TextureHandle(GetHandle("Party2Wnd.PartyMember" $ i + 1 $ "Wnd.NumberTex") );
		m_hparty2back1_[ i ] = TextureHandle(GetHandle("Party2Wnd.PartyMember" $ i + 1 $ "Wnd.BackTex1") );
		m_hparty2back2_[ i ] = TextureHandle(GetHandle("Party2Wnd.PartyMember" $ i + 1 $ "Wnd.BackTex2") );
		m_hparty2back3_[ i ] = TextureHandle(GetHandle("Party2Wnd.PartyMember" $ i + 1 $ "Wnd.BackTex3") );
		
	}

	for( i = 0; i < 6; ++i )
	{
		m_hMsgLeftWnd[ i ] = GetHandle( "MsgWnd.MsgLeft.Msg" $ i + 1 );
		m_hMsgRightWnd[ i ] = GetHandle( "MsgWnd.MsgRight.Msg" $ i + 1 );
		m_hMsgLeftAttackerTextBox[ i ] = TextBoxHandle( GetHandle( "MsgWnd.MsgLeft.Msg" $ i + 1 $ ".Attacker" ) );
		m_hMsgLeftDefenderTextBox[ i ] = TextBoxHandle( GetHandle( "MsgWnd.MsgLeft.Msg" $ i + 1 $ ".Defender" ) );
		m_hMsgLeftSkillTextBox[ i ] = TextBoxHandle( GetHandle( "MsgWnd.MsgLeft.Msg" $ i + 1 $ ".Skill" ) );
		m_hMsgRightAttackerTextBox[ i ] = TextBoxHandle( GetHandle( "MsgWnd.MsgRight.Msg" $ i + 1 $ ".Attacker" ) );
		m_hMsgRightDefenderTextBox[ i ] = TextBoxHandle( GetHandle( "MsgWnd.MsgRight.Msg" $ i + 1 $ ".Defender" ) );
		m_hMsgRightSkillTextBox[ i ] = TextBoxHandle( GetHandle( "MsgWnd.MsgRight.Msg" $ i + 1 $ ".Skill" ) );
	}

	RegisterEvent( EV_StartEventMatchObserver );
	RegisterEvent( EV_EventMatchUpdateScore );
	RegisterEvent( EV_EventMatchUpdateTeamName );
	RegisterEvent( EV_EventMatchUpdateTeamInfo );
	RegisterEvent( EV_EventMatchUpdateUserInfo );
	RegisterEvent( EV_ReceiveMagicSkillUse );
	RegisterEvent( EV_ShortcutCommand );
}

function OnEnterState( name a_PreStateName )
{
	UpdateScore();
	UpdateTeamName();
	UpdateTeamInfo( 0 );
	UpdateTeamInfo( 1 );
	ClearMsg();
}

function OnEvent( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	case EV_StartEventMatchObserver:
		HandleStartEventMatchObserver( a_Param );
		break;
	case EV_EventMatchUpdateScore:
		UpdateScore();
		break;
	case EV_EventMatchUpdateTeamName:
		UpdateTeamName();
		break;
	case EV_EventMatchUpdateTeamInfo:
		HandleEventMatchUpdateTeamInfo( a_Param );
		break;
	case EV_EventMatchUpdateUserInfo:
		HandleEventMatchUpdateUserInfo( a_Param );
		break;
	case EV_ReceiveMagicSkillUse:
		HandleReceiveMagicSkillUse( a_Param );
		break;
	case EV_ShortcutCommand:
		HandleShortcutCommand( a_Param );
		break;
	default:
		break;
	}
}

function OnTimer( int a_TimerID )
{
	local int i;

	switch( a_TimerID )
	{
	case TIMERID_Show:
		m_hOwnerWnd.KillTimer( TIMERID_Show );
		m_hTopWnd.HideWindow();
		break;
	case TIMERID_Msg:
		for( i = 0; i < 6; ++i )
		{
			if( m_hMsgLeftWnd[ i ].IsShowWindow()
				&& 0 != m_hMsgLeftWnd[ i ].GetAlpha() )
			{
				m_hMsgLeftWnd[ i ].SetAlpha( 255 );
				m_hMsgLeftWnd[ i ].SetAlpha( 0, 2.f );
				break;
			}

			if( m_hMsgRightWnd[ i ].IsShowWindow()
				&& 0 != m_hMsgRightWnd[ i ].GetAlpha() )
			{
				m_hMsgRightWnd[ i ].SetAlpha( 255 );
				m_hMsgRightWnd[ i ].SetAlpha( 0, 2.f );
				break;
			}
		}
		break;
	}
}

function OnLButtonDown( WindowHandle a_WindowHandle, int X, int Y )
{
	local int i;

	for( i = 0; i < MAX_PartyMemberCount; ++i )
	{
		if( a_WindowHandle.IsChildOf( m_hParty1MemberWnd[ i ] ) )
		{
			SetSelectedUser( 0, i );
			return;
		}
	}

	for( i = 0; i < MAX_PartyMemberCount; ++i )
	{
		if( a_WindowHandle.IsChildOf( m_hParty2MemberWnd[ i ] ) )
		{
			SetSelectedUser( 1, i );
			return;
		}
	}
}

function HandleStartEventMatchObserver( String a_Param )
{
}

function HandleEventMatchUpdateTeamInfo( String a_Param )
{
	local int TeamID;

	if( ParseInt( a_Param, "TeamID", TeamID ) )
		UpdateTeamInfo( TeamID );
}

function HandleEventMatchUpdateUserInfo( String a_Param )
{
	local int UserID;
	local int TeamID;

	ParseInt( a_Param, "UserID", UserID );
	ParseInt( a_Param, "TeamID", TeamID );

	UpdateUserInfo( TeamID, UserID );
}

function HandleReceiveMagicSkillUse( String a_Param )
{
	local int AttackerID;
	local int DefenderID;
	local int SkillID;
	local UserInfo AttackerInfo;
	local UserInfo DefenderInfo;
	local SkillInfo UsedSkillInfo;
	local int AttackerTeamID;
	local int AttackerUserID;
	local int DefenderTeamID;
	local int DefenderUserID;

	if( !ParseInt( a_Param, "AttackerID", AttackerID ) )
		return;

	if( !ParseInt( a_Param, "DefenderID", DefenderID ) )
		return;

	if( !ParseInt( a_Param, "SkillID", SkillID ) )
		return;

	if( !GetTeamUserID( AttackerID, AttackerTeamID, AttackerUserID ) )
		return;

	if( !GetTeamUserID( DefenderID, DefenderTeamID, DefenderUserID ) )
		return;

	if( !GetUserInfo( AttackerID, AttackerInfo ) )
		return;

	if( !GetUserInfo( DefenderID, DefenderInfo ) )
		return;

	if( !GetSkillInfo( SkillID, 1, UsedSkillInfo ) )
		return;

	AddSkillMsg( AttackerTeamID, AttackerUserID, AttackerInfo.Name, DefenderTeamID, DefenderUserID, DefenderInfo.Name, UsedSkillInfo.SkillName );
}

function HandleShortcutCommand( String a_Param )
{
	local String Command;
	local bool Draggable;

	if( ParseString( a_Param, "Command", Command ) )
	{
		switch( Command )
		{
		case "EventMatchShowPartyWindow":
			if( m_hParty1Wnd.IsShowWindow() )
			{
				m_hParty1Wnd.HideWindow();
				m_hParty2Wnd.HideWindow();
			}
			else
			{
				m_hParty1Wnd.ShowWindow();
				m_hParty2Wnd.ShowWindow();
				UpdateTeamInfo( 0 );
				UpdateTeamInfo( 1 );
			}
			break;
		case "EventMatchLockPosition":
			Draggable = m_hPlayerWnd[ 0 ].IsDraggable();
			m_hPlayerWnd[ 0 ].SetDraggable( !Draggable );
			m_hPlayerWnd[ 1 ].SetDraggable( !Draggable );
			m_hPlayerBuffCoverWnd[ 0 ].SetDraggable( !Draggable );
			m_hPlayerBuffCoverWnd[ 1 ].SetDraggable( !Draggable );
			m_hParty1Wnd.SetDraggable( !Draggable );
			m_hParty2Wnd.SetDraggable( !Draggable );
			break;
		case "EventMatchInitPosition":
			m_hPlayerWnd[ 0 ].SetAnchor( "", "TopLeft", "TopLeft", 0, 98 );
			m_hPlayerWnd[ 0 ].ClearAnchor();
			m_hPlayerWnd[ 1 ].SetAnchor( "", "TopRight", "TopRight", 0, 98 );
			m_hPlayerWnd[ 1 ].ClearAnchor();
			m_hPlayerBuffCoverWnd[ 0 ].SetAnchor( "Player1Wnd", "BottomLeft", "TopLeft", 0, 0 );
			m_hPlayerBuffCoverWnd[ 0 ].ClearAnchor();
			m_hPlayerBuffCoverWnd[ 1 ].SetAnchor( "Player2Wnd", "BottomLeft", "TopLeft", 0, 0 );
			m_hPlayerBuffCoverWnd[ 1 ].ClearAnchor();
			m_hParty1Wnd.SetAnchor( "", "TopLeft", "TopLeft", 0, 340 );
			m_hParty1Wnd.ClearAnchor();
			m_hParty2Wnd.SetAnchor( "", "TopRight", "TopRight", 0, 340 );
			m_hParty2Wnd.ClearAnchor();
			break;
		case "EventMatchToggleShowClassOrName":
			m_ClassOrName = !m_ClassOrName;
			RefreshClassOrName();
			break;
		case "EventMatchSwitchMessageMode":
			switch( m_MsgMode )
			{
			case MESSAGEMODE_Normal:
				m_MsgMode = MESSAGEMODE_LeftRight;
				break;
			case MESSAGEMODE_LeftRight:
				m_MsgMode = MESSAGEMODE_Off;
				break;
			case MESSAGEMODE_Off:
				m_MsgMode = MESSAGEMODE_Normal;
				break;
			default:
				m_MsgMode = MESSAGEMODE_Normal;
				break;
			}
			UpdateSkillMsg();
			break;
		}
	}
}

function RefreshClassOrName()
{
	local int i;

	if( m_ClassOrName )
	{
		for( i = 0; i < MAX_PartyMemberCount; ++i )
		{
			m_hParty1MemberNameTextBox[ i ].HideWindow();
			m_hParty2MemberNameTextBox[ i ].HideWindow();
			m_hParty1MemberClassTextBox[ i ].ShowWindow();
			m_hParty2MemberClassTextBox[ i ].ShowWindow();
		}
	}
	else
	{
		for( i = 0; i < MAX_PartyMemberCount; ++i )
		{
			m_hParty1MemberNameTextBox[ i ].ShowWindow();
			m_hParty2MemberNameTextBox[ i ].ShowWindow();
			m_hParty1MemberClassTextBox[ i ].HideWindow();
			m_hParty2MemberClassTextBox[ i ].HideWindow();
		}
	}
}

function UpdateTeamName()
{
	m_TeamName1 = class'EventMatchAPI'.static.GetTeamName( 0 );
	m_TeamName2 = class'EventMatchAPI'.static.GetTeamName( 1 );

	m_hTeamName1TextBox.SetText( m_TeamName1 );
	m_hTeamName2TextBox.SetText( m_TeamName2 );
}

function UpdateTeamInfo( int a_TeamID )
{
	local int i;
	local int PartyMemberCount;

	if( 0 != a_TeamID && 1 != a_TeamID )
		return;

	PartyMemberCount = class'EventMatchAPI'.static.GetPartyMemberCount( a_TeamID );

	debug("PartyMemberCount" @ PartyMemberCount);
	
	switch( a_TeamID )
	{
	case 0:
		m_hParty1Wnd.SetWindowSize( 280, 70 * PartyMemberCount );
		for( i = 0; i < MAX_PartyMemberCount; ++i )
		{
			if( i < PartyMemberCount )
			{
				m_hParty1MemberWnd[ i ].ShowWindow();
				debug("현재 번호:" @ i);
				UpdateUserInfo( 0, i );
			}
			else
			{
				m_hParty1MemberWnd[ i ].HideWindow();
				debug("현재 숨김번호:" @ i);
				m_Party1UserIDList[ i ] = 0;
			}
		}
		break;
	case 1:
		m_hParty2Wnd.SetWindowSize( 280, 70 * PartyMemberCount );
		for( i = 0; i < MAX_PartyMemberCount; ++i )
		{
			if( i < PartyMemberCount )
			{
				m_hParty2MemberWnd[ i ].ShowWindow();
				debug("현재 번호:" @ i);
				UpdateUserInfo( 1, i );
			}
			else
			{
				m_hParty2MemberWnd[ i ].HideWindow();
				debug("현재 숨김번호:" @ i);
				m_Party2UserIDList[ i ] = 0;
			}
		}
		break;
	}

	SetSelectedUser( a_TeamID, -1 );
	RefreshClassOrName();
}

function UpdateScore()
{
	m_Score1 = class'EventMatchAPI'.static.GetScore( 0 );
	m_Score2 = class'EventMatchAPI'.static.GetScore( 1 );

	m_hScore1Tex.SetTexture( "L2UI_CH3.BroadcastObs.br_score" $ m_Score1 );
	m_hScore2Tex.SetTexture( "L2UI_CH3.BroadcastObs.br_score" $ m_Score2 );

	m_hTopWnd.ShowWindow();

	m_hOwnerWnd.SetTimer( TIMERID_Show, 7000 );
}

function UpdateUserInfo( int a_TeamID, int a_UserID )
{
	local int i;
	local int CurRow;
	local EventMatchUserData UserData;
	local StatusIconInfo Info;
	local SkillInfo TheSkillInfo;
	local int width;
	local int height;

	debug ( "유저인포업데이트: a_UserID:" @ a_UserID );
	
	if( class'EventMatchAPI'.static.GetUserData( a_TeamID, a_UserID, UserData ) )
	{
		switch( a_TeamID )
		{
		case 0:
			if (UserData.HPNow == 0)
			{
				m_hParty1MemberHPBar[ a_UserID ].SetValue( UserData.HPMax, UserData.HPNow );
				m_hParty1MemberCPBar[ a_UserID ].SetValue( UserData.CPMax, UserData.CPNow );
				m_hParty1MemberMPBar[ a_UserID ].SetValue( UserData.MPMax, UserData.MPNow );
				
				m_hParty1NumberTex[ a_UserID ].SetTexture("L2UI_CH3.BroadcastObs.br_party_x");
				m_hparty1back1_[ a_UserID ].SetTexture("L2UI_CH3.BroadcastObs.br_dead2_back1");
				m_hparty1back2_[ a_UserID ].SetTexture("L2UI_CH3.BroadcastObs.br_dead2_back2");
				m_hparty1back3_[ a_UserID ].SetTexture("L2UI_CH3.BroadcastObs.br_dead2_back3");
			}
			else 
			{
				m_Party1UserIDList[ a_UserID ] = UserData.UserID;
				m_hParty1MemberNameTextBox[ a_UserID ].SetText( UserData.UserName );
				debug("유저이름:" @ UserData.UserName);
				m_hParty1MemberClassTextBox[ a_UserID ].SetText( GetClassType( UserData.UserClass ) );
				m_hParty1MemberHPBar[ a_UserID ].SetValue( UserData.HPMax, UserData.HPNow );
				m_hParty1MemberCPBar[ a_UserID ].SetValue( UserData.CPMax, UserData.CPNow );
				m_hParty1MemberMPBar[ a_UserID ].SetValue( UserData.MPMax, UserData.MPNow );
				m_hParty1NumberTex[ a_UserID ].SetTexture("L2UI_CH3.BroadcastObs.br_party2_" $ a_UserID+1);
				m_hparty1back1_[ a_UserID ].SetTexture("L2UI_CH3.BroadcastObs.br_party2_back1");
				m_hparty1back2_[ a_UserID ].SetTexture("L2UI_CH3.BroadcastObs.br_party2_back2");
				m_hparty1back3_[ a_UserID ].SetTexture("L2UI_CH3.BroadcastObs.br_party2_back3");
			}
			break;
		case 1:
			if (UserData.HPNow == 0)
			{
				m_hParty2MemberHPBar[ a_UserID ].SetValue( UserData.HPMax, UserData.HPNow );
				m_hParty2MemberCPBar[ a_UserID ].SetValue( UserData.CPMax, UserData.CPNow );
				m_hParty2MemberMPBar[ a_UserID ].SetValue( UserData.MPMax, UserData.MPNow );
				
				m_hParty2NumberTex[ a_UserID ].SetTexture("L2UI_CH3.BroadcastObs.br_party_x");
				m_hparty2back1_[ a_UserID ].SetTexture("L2UI_CH3.BroadcastObs.br_dead2_back1");
				m_hparty2back2_[ a_UserID ].SetTexture("L2UI_CH3.BroadcastObs.br_dead2_back2");
				m_hparty2back3_[ a_UserID ].SetTexture("L2UI_CH3.BroadcastObs.br_dead2_back3");
			}
			else
			{
				m_Party2UserIDList[ a_UserID ] = UserData.UserID;
				m_hParty2MemberNameTextBox[ a_UserID ].SetText( UserData.UserName );
				debug("유저이름:" @ UserData.UserName);
				m_hParty2MemberClassTextBox[ a_UserID ].SetText( GetClassType( UserData.UserClass ) );
				m_hParty2MemberHPBar[ a_UserID ].SetValue( UserData.HPMax, UserData.HPNow );
				m_hParty2MemberCPBar[ a_UserID ].SetValue( UserData.CPMax, UserData.CPNow );
				m_hParty2MemberMPBar[ a_UserID ].SetValue( UserData.MPMax, UserData.MPNow );
				m_hParty2NumberTex[ a_UserID ].SetTexture("L2UI_CH3.BroadcastObs.br_party1_" $ a_UserID+1);
				m_hparty2back1_[ a_UserID ].SetTexture("L2UI_CH3.BroadcastObs.br_party2_back1");
				m_hparty2back2_[ a_UserID ].SetTexture("L2UI_CH3.BroadcastObs.br_party2_back2");
				m_hparty2back3_[ a_UserID ].SetTexture("L2UI_CH3.BroadcastObs.br_party2_back3");
			}
			break;
		}

		if( IsSelectedUser( a_TeamID, a_UserID ) )
		{
			m_hPlayerNameTextBox[ a_TeamID ].SetText( UserData.UserName );
			m_hPlayerLvClassTextBox[ a_TeamID ].SetText( "Lv" $ UserData.UserLv $ " " $ GetClassType( UserData.UserClass ) );
			m_hPlayerHPBar[ a_TeamID ].SetValue( UserData.HPMax, UserData.HPNow );
			m_hPlayerCPBar[ a_TeamID ].SetValue( UserData.CPMax, UserData.CPNow );
			m_hPlayerMPBar[ a_TeamID ].SetValue( UserData.MPMax, UserData.MPNow );
			
			if (UserData.HPNow == 0)
			{
				m_hplayerback1_[ a_TeamID ].SetTexture("L2UI_CH3.BroadcastObs.br_dead1_back1");
				m_hplayerback2_[ a_TeamID ].SetTexture("L2UI_CH3.BroadcastObs.br_dead1_back2");
				m_hplayerback3_[ a_TeamID ].SetTexture("L2UI_CH3.BroadcastObs.br_dead1_back3");
			}
			else
			{
				m_hplayerback1_[ a_TeamID ].SetTexture("L2UI_CH3.BroadcastObs.br_party1_back1");
				m_hplayerback2_[ a_TeamID ].SetTexture("L2UI_CH3.BroadcastObs.br_party1_back2");
				m_hplayerback3_[ a_TeamID ].SetTexture("L2UI_CH3.BroadcastObs.br_party1_back3");
			}

			
			
			
			m_hPlayerBuffWnd[ a_TeamID ].Clear();
			CurRow = -1;
			Debug( "Length=" $ UserData.BuffIDList.Length );
			for( i = 0; i < UserData.BuffIDList.Length; ++i )
			{
				if( 0 == i % 12 )
				{
					m_hPlayerBuffWnd[ a_TeamID ].InsertRow( CurRow );
					CurRow++;
				}

				if( GetSkillInfo( UserData.BuffIDList[ i ], 1, TheSkillInfo ) )
				{
					Info.size = 10;
					Info.ClassID = UserData.BuffIDList[ i ];
					Info.Level = 1;
					Info.RemainTime = UserData.BuffRemainList[ i ];
					Info.IconName = TheSkillInfo.TexName;
					Info.Name = TheSkillInfo.SkillName;
					Info.Description = TheSkillInfo.SkillDesc;
					Info.bShow = true;
					Info.Size = 40;
					m_hPlayerBuffWnd[ a_TeamID ].AddCol( CurRow, Info );
				}
			}

			m_hPlayerBuffWnd[ a_TeamID ].GetWindowSize( width, height );
			m_hPlayerBuffCoverWnd[ a_TeamID ].SetWindowSize( width, height );
		}
	}
	else 
	{
		debug("유저인포 정보 가져오기 실패");
	}
}

function SetSelectedUser( int a_TeamID, int a_UserID )
{
	local int i;

	switch( a_TeamID )
	{
	case 0:
		for( i = 0; i < MAX_PartyMemberCount; ++i )
		{
			if( i == a_UserID )
				m_hParty1MemberSelectedTex[ i ].ShowWindow();
			else
				m_hParty1MemberSelectedTex[ i ].HideWindow();
		}
		break;
	case 1:
		for( i = 0; i < MAX_PartyMemberCount; ++i )
		{
			if( i == a_UserID )
				m_hParty2MemberSelectedTex[ i ].ShowWindow();
			else
				m_hParty2MemberSelectedTex[ i ].HideWindow();
		}
		break;
	}

	m_SelectedUserID[ a_TeamID ] = a_UserID;

	if( -1 == a_UserID )
	{
		m_hPlayerNameTextBox[ a_TeamID ].SetText( "" );
		m_hPlayerLvClassTextBox[ a_TeamID ].SetText( "" );
		m_hPlayerHPBar[ a_TeamID ].SetValue( 0, 0 );
		m_hPlayerCPBar[ a_TeamID ].SetValue( 0, 0 );
		m_hPlayerMPBar[ a_TeamID ].SetValue( 0, 0 );
		m_hPlayerBuffCoverWnd[ a_TeamID ].HideWindow();
	}
	else
	{
		class'EventMatchAPI'.static.SetSelectedUser( a_TeamID, a_UserID );
		m_hPlayerBuffCoverWnd[ a_TeamID ].ShowWindow();
		UpdateUserInfo( a_TeamID, a_UserID );
	}
}

function bool IsSelectedUser( int a_TeamID, int a_UserID )
{
	if( 0 != a_TeamID && 1 != a_TeamID )
		return false;

	if( m_SelectedUserID[ a_TeamID ] != a_UserID )
		return false;

	return true;
}

function ClearMsg()
{
	local int i;

	for( i = 0; i < 6; ++i )
	{
		m_hMsgLeftWnd[ i ].HideWindow();
		m_hMsgRightWnd[ i ].HideWindow();
	}
}

function bool GetTeamUserID( int a_UserClassID, out int a_TeamID, out int a_UserID )
{
	local int i;

	if( 0 == a_UserClassID )
		return false;

	for( i = 0; i < MAX_PartyMemberCount; ++i )
	{
		if( m_Party1UserIDList[ i ] == a_UserClassID )
		{
			a_TeamID = 0;
			a_UserID = i;
			return true;
		}
	}

	for( i = 0; i < MAX_PartyMemberCount; ++i )
	{
		if( m_Party2UserIDList[ i ] == a_UserClassID )
		{
			a_TeamID = 1;
			a_UserID = i;
			return true;
		}
	}
}

function AddSkillMsg( int a_AttackerTeamID, int a_AttackerUserID, String a_AttackerName, int a_DefenderTeamID, int a_DefenderUserID, String a_DefenderName, String a_SkillName )
{
	m_MsgList[ m_MsgStartIndex ].AttackerTeamID = a_AttackerTeamID;
	m_MsgList[ m_MsgStartIndex ].AttackerUserID = a_AttackerUserID;
	m_MsgList[ m_MsgStartIndex ].AttackerName = a_AttackerName;
	m_MsgList[ m_MsgStartIndex ].DefenderTeamID = a_DefenderTeamID;
	m_MsgList[ m_MsgStartIndex ].DefenderUserID = a_DefenderUserID;
	m_MsgList[ m_MsgStartIndex ].DefenderName = a_DefenderName;
	m_MsgList[ m_MsgStartIndex ].SkillName = a_SkillName;
	m_MsgStartIndex = ( m_MsgStartIndex + 1 ) % 6;

	if( 0 == a_AttackerTeamID )
	{
		m_Team1MsgList[ m_Team1MsgStartIndex ].AttackerTeamID = a_AttackerTeamID;
		m_Team1MsgList[ m_Team1MsgStartIndex ].AttackerUserID = a_AttackerUserID;
		m_Team1MsgList[ m_Team1MsgStartIndex ].AttackerName = a_AttackerName;
		m_Team1MsgList[ m_Team1MsgStartIndex ].DefenderTeamID = a_DefenderTeamID;
		m_Team1MsgList[ m_Team1MsgStartIndex ].DefenderUserID = a_DefenderUserID;
		m_Team1MsgList[ m_Team1MsgStartIndex ].DefenderName = a_DefenderName;
		m_Team1MsgList[ m_Team1MsgStartIndex ].SkillName = a_SkillName;
		m_Team1MsgStartIndex = ( m_Team1MsgStartIndex + 1 ) % 6;
	}
	else
	{
		m_Team2MsgList[ m_Team2MsgStartIndex ].AttackerTeamID = a_AttackerTeamID;
		m_Team2MsgList[ m_Team2MsgStartIndex ].AttackerUserID = a_AttackerUserID;
		m_Team2MsgList[ m_Team2MsgStartIndex ].AttackerName = a_AttackerName;
		m_Team2MsgList[ m_Team2MsgStartIndex ].DefenderTeamID = a_DefenderTeamID;
		m_Team2MsgList[ m_Team2MsgStartIndex ].DefenderUserID = a_DefenderUserID;
		m_Team2MsgList[ m_Team2MsgStartIndex ].DefenderName = a_DefenderName;
		m_Team2MsgList[ m_Team2MsgStartIndex ].SkillName = a_SkillName;
		m_Team2MsgStartIndex = ( m_Team2MsgStartIndex + 1 ) % 6;
	}

	UpdateSkillMsg();
}

function UpdateSkillMsg()
{
	local int i;
	local int SkillMsgIndex;
	local Color Team1Color;
	local Color Team2Color;

	Team1Color.R = 220;
	Team1Color.G = 220;
	Team1Color.B = 220;

	Team2Color.R = 255;
	Team2Color.G = 55;
	Team2Color.B = 55;

	switch( m_MsgMode )
	{
	case MESSAGEMODE_Normal:
		for( i = 0; i < 6; ++i )
		{
			m_hMsgRightWnd[ i ].HideWindow();
		}

		for( i = 0; i < 6; ++i )
		{
			SkillMsgIndex = ( m_MsgStartIndex + i ) % 6;

			if( m_MsgList[ SkillMsgIndex ].AttackerName == "" )
				m_hMsgLeftWnd[ i ].HideWindow();
			else
			{
				m_hMsgLeftAttackerTextBox[ i ].SetText( String( m_MsgList[ SkillMsgIndex ].AttackerUserID + 1 ) $ m_MsgList[ SkillMsgIndex ].AttackerName );
				m_hMsgLeftDefenderTextBox[ i ].SetText( String( m_MsgList[ SkillMsgIndex ].DefenderUserID + 1 ) $ m_MsgList[ SkillMsgIndex ].DefenderName );
				m_hMsgLeftSkillTextBox[ i ].SetText( m_MsgList[ SkillMsgIndex ].SkillName );

				if( 0 == m_MsgList[ SkillMsgIndex ].AttackerTeamID )
					m_hMsgLeftAttackerTextBox[ i ].SetTextColor( Team1Color );
				else
					m_hMsgLeftAttackerTextBox[ i ].SetTextColor( Team2Color );

				if( 0 == m_MsgList[ SkillMsgIndex ].DefenderTeamID )
					m_hMsgLeftDefenderTextBox[ i ].SetTextColor( Team1Color );
				else
					m_hMsgLeftDefenderTextBox[ i ].SetTextColor( Team2Color );

				m_hMsgLeftWnd[ i ].ShowWindow();
				m_hMsgLeftWnd[ i ].SetAlpha( 255 );
			}
		}
		break;
	case MESSAGEMODE_LeftRight:
		for( i = 0; i < 6; ++i )
		{
			SkillMsgIndex = ( m_Team1MsgStartIndex + i ) % 6;

			if( m_Team1MsgList[ SkillMsgIndex ].AttackerName == "" )
				m_hMsgLeftWnd[ i ].HideWindow();
			else
			{
				m_hMsgLeftAttackerTextBox[ i ].SetText( String( m_Team1MsgList[ SkillMsgIndex ].AttackerUserID + 1 ) );
				m_hMsgLeftDefenderTextBox[ i ].SetText( String( m_Team1MsgList[ SkillMsgIndex ].DefenderUserID + 1 ) );
				m_hMsgLeftSkillTextBox[ i ].SetText( m_Team1MsgList[ SkillMsgIndex ].SkillName );

				m_hMsgLeftAttackerTextBox[ i ].SetTextColor( Team1Color );

				if( 0 == m_Team1MsgList[ SkillMsgIndex ].DefenderTeamID )
					m_hMsgLeftDefenderTextBox[ i ].SetTextColor( Team1Color );
				else
					m_hMsgLeftDefenderTextBox[ i ].SetTextColor( Team2Color );

				m_hMsgLeftWnd[ i ].ShowWindow();
				m_hMsgLeftWnd[ i ].SetAlpha( 255 );
			}
		}

		for( i = 0; i < 6; ++i )
		{
			SkillMsgIndex = ( m_MsgStartIndex + i ) % 6;

			if( m_Team2MsgList[ SkillMsgIndex ].AttackerName == "" )
				m_hMsgRightWnd[ i ].HideWindow();
			else
			{
				m_hMsgRightAttackerTextBox[ i ].SetText( String( m_Team2MsgList[ SkillMsgIndex ].AttackerUserID + 1 ) );
				m_hMsgRightDefenderTextBox[ i ].SetText( String( m_Team2MsgList[ SkillMsgIndex ].DefenderUserID + 1 ) );
				m_hMsgRightSkillTextBox[ i ].SetText( m_Team2MsgList[ SkillMsgIndex ].SkillName );

				m_hMsgRightAttackerTextBox[ i ].SetTextColor( Team2Color );

				if( 0 == m_Team2MsgList[ SkillMsgIndex ].DefenderTeamID )
					m_hMsgRightDefenderTextBox[ i ].SetTextColor( Team1Color );
				else
					m_hMsgRightDefenderTextBox[ i ].SetTextColor( Team2Color );

				m_hMsgRightWnd[ i ].ShowWindow();
				m_hMsgRightWnd[ i ].SetAlpha( 255 );
			}
		}
		break;
	case MESSAGEMODE_Off:
		for( i = 0; i < 6; ++i )
		{
			m_hMsgLeftWnd[ i ].HideWindow();
			m_hMsgRightWnd[ i ].HideWindow();
		}
		break;
	}

	m_hOwnerWnd.KillTimer( TIMERID_Msg );
	m_hOwnerWnd.SetTimer( TIMERID_Msg, 14000 );
}

