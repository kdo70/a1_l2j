class EventMatchGMWnd extends UICommonAPI;

const TIMERID_CountDown = 1;

var HtmlHandle m_hCommandHtml;
var WindowHandle m_hEventMatchGMCommandWnd;
var WindowHandle m_hEventMatchGMFenceWnd;
var ButtonHandle m_hCreateEventMatchButton;
var ButtonHandle m_hSetTeam1LeaderButton;
var ButtonHandle m_hLockTeam1Button;
var ButtonHandle m_hSetTeam2LeaderButton;
var ButtonHandle m_hLockTeam2Button;
var ButtonHandle m_hPauseButton;
var ButtonHandle m_hStartButton;
var ButtonHandle m_hSetScoreButton;
var ButtonHandle m_hSendAnnounceButton;
var ButtonHandle m_hShowCommandWndButton;
var ButtonHandle m_hSendGameEndMsgButton;
var ButtonHandle m_hSetFenceButton;
var ButtonHandle m_hTeam1FirecrackerButton;
var ButtonHandle m_hTeam2FirecrackerButton;
var ButtonHandle Summon2Team;
var ButtonHandle SetAllHeal;
var ButtonHandle DelayReset;
var ButtonHandle Summon1Team;
var EditBoxHandle m_hTeam1NameEditBox;
var EditBoxHandle m_hTeam2NameEditBox;
var EditBoxHandle m_hTeam1LeaderNameEditBox;
var EditBoxHandle m_hTeam2LeaderNameEditBox;
var EditBoxHandle m_hOptionFileEditBox;
var EditBoxHandle m_hCommandFileEditBox;
var EditBoxHandle m_hTeam1ScoreEditBox;
var EditBoxHandle m_hTeam2ScoreEditBox;
var EditBoxHandle m_hAnnounceEditBox;
var TextBoxHandle m_hMatchIDTextBox;
var ListCtrlHandle m_hTeam1ListCtrl;
var ListCtrlHandle m_hTeam2ListCtrl;
var int m_CountDown;
var int m_MatchID;
var bool m_Team1Locked;
var bool m_Team2Locked;
var bool m_Paused;

var String m_Team1Name;
var String m_Team2Name;

function OnLoad()
{
	RegisterEvent( EV_ShowEventMatchGMWnd );
	RegisterEvent( EV_EventMatchCreated );
	RegisterEvent( EV_EventMatchUpdateTeamInfo );
	RegisterEvent( EV_EventMatchManage );
	GotoState( 'HidingState' );

	m_hEventMatchGMCommandWnd = GetHandle( "EventMatchGMCommandWnd" );
	m_hCommandHtml = HtmlHandle( GetHandle( "EventMatchGMCommandWnd.HtmlCtrl" ) );
	m_hEventMatchGMFenceWnd = GetHandle( "EventMatchGMFenceWnd" );
	m_hCreateEventMatchButton = ButtonHandle( GetHandle( "CreateEventMatchButton" ) );
	m_hSetTeam1LeaderButton = ButtonHandle( GetHandle( "SetTeam1LeaderButton" ) );
	m_hLockTeam1Button = ButtonHandle( GetHandle( "LockTeam1Button" ) );
	m_hSetTeam2LeaderButton = ButtonHandle( GetHandle( "SetTeam2LeaderButton" ) );
	m_hLockTeam2Button = ButtonHandle( GetHandle( "LockTeam2Button" ) );
	m_hPauseButton = ButtonHandle( GetHandle( "PauseButton" ) );
	m_hStartButton = ButtonHandle( GetHandle( "StartButton" ) );
	Summon2Team = ButtonHandle( GetHandle( "Summon2Team" ) );
	SetAllHeal = ButtonHandle( GetHandle( "SetAllHeal" ) );
	DelayReset = ButtonHandle( GetHandle( "DelayReset" ) );
	Summon1Team = ButtonHandle( GetHandle( "Summon1Team" ) );
	m_hSetScoreButton = ButtonHandle( GetHandle( "SetScoreButton" ) );
	m_hSendAnnounceButton = ButtonHandle( GetHandle( "SendAnnounceButton" ) );
	m_hShowCommandWndButton = ButtonHandle( GetHandle( "ShowCommandWndButton" ) );
	m_hSendGameEndMsgButton = ButtonHandle( GetHandle( "SendGameEndMsgButton" ) );
	m_hSetFenceButton = ButtonHandle( GetHandle( "SetFenceButton" ) );
	m_hTeam1FirecrackerButton = ButtonHandle( GetHandle( "Team1FirecrackerButton" ) );
	m_hTeam2FirecrackerButton = ButtonHandle( GetHandle( "Team2FirecrackerButton" ) );
	m_hTeam1NameEditBox = EditBoxHandle( GetHandle( "Team1NameEditBox" ) );
	m_hTeam2NameEditBox = EditBoxHandle( GetHandle( "Team2NameEditBox" ) );
	m_hTeam1LeaderNameEditBox = EditBoxHandle( GetHandle( "Team1LeaderNameEditBox" ) );
	m_hTeam2LeaderNameEditBox = EditBoxHandle( GetHandle( "Team2LeaderNameEditBox" ) );
	m_hOptionFileEditBox = EditBoxHandle( GetHandle( "OptionFileEditBox" ) );
	m_hCommandFileEditBox = EditBoxHandle( GetHandle( "CommandFileEditBox" ) );
	m_hTeam1ScoreEditBox = EditBoxHandle( GetHandle( "Team1ScoreEditBox" ) );
	m_hTeam2ScoreEditBox = EditBoxHandle( GetHandle( "Team2ScoreEditBox" ) );
	m_hAnnounceEditBox = EditBoxHandle( GetHandle( "AnnounceEditBox" ) );
	m_hMatchIDTextBox = TextBoxHandle( GetHandle( "MatchIDTextBox" ) );
	m_hTeam1ListCtrl = ListCtrlHandle( GetHandle( "Team1ListCtrl" ) );
	m_hTeam2ListCtrl = ListCtrlHandle( GetHandle( "Team2ListCtrl" ) );
}

function OnClickButtonWithHandle( ButtonHandle a_ButtonHandle )
{
	switch( a_ButtonHandle )
	{
	case m_hCreateEventMatchButton:
		OnClickCreateEventMatchButton();
		break;
	case m_hSetTeam1LeaderButton:
		OnClickSetTeam1LeaderButton();
		break;
	case m_hLockTeam1Button:
		OnClickLockTeam1Button();
		break;
	case m_hSetTeam2LeaderButton:
		OnClickSetTeam2LeaderButton();
		break;
	case m_hLockTeam2Button:
		OnClickLockTeam2Button();
		break;
	case m_hPauseButton:
		OnClickPauseButton();
		break;
	case m_hStartButton:
		OnClickStartButton();
		break;
	case m_hSetScoreButton:
		OnClickSetScoreButton();
		break;
	case m_hSendAnnounceButton:
		OnClickSendAnnounceButton();
		break;
	case m_hShowCommandWndButton:
		OnClickShowCommandWndButton();
		break;
	case m_hSendGameEndMsgButton:
		OnClickSendGameEngMsgButton();
		break;
	case m_hSetFenceButton:
		OnClickSetFenceButton();
		break;
	case m_hTeam1FirecrackerButton:
		OnClickTeam1FirecrackerButton();
		break;
	case m_hTeam2FirecrackerButton:
		OnClickTeam2FirecrackerButton();
		break;
	case Summon2Team:
		OnClickSummon2Team();
		break;
	case SetAllHeal:
		OnClickSetAllHeal();
		break;
	case DelayReset:
		OnClickDelayReset();
		break;
	case Summon1Team:
		OnClickSummon1Team();
		break;

	}
}


function OnEvent( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	case EV_ShowEventMatchGMWnd:
		HandleShowEventMatchGMWnd();
		break;
	case EV_EventMatchCreated:
		HandleEventMatchCreated( a_Param );
		break;
	case EV_EventMatchUpdateTeamInfo:
		HandleEventMatchUpdateTeamInfo( a_Param );
		break;
	case EV_EventMatchManage:
		HandleEventMatchManage( a_Param );
		break;
	}
}

function OnHide()
{
	GotoState( 'HidingState' );
}

function OnClickCreateEventMatchButton();
function OnClickSetTeam1LeaderButton();
function OnClickLockTeam1Button();
function OnClickSetTeam2LeaderButton();
function OnClickLockTeam2Button();
function OnClickPauseButton();
function OnClickStartButton();
function OnClickSetScoreButton();
function OnClickSendAnnounceButton();
function OnClickShowCommandWndButton()
{
	local String CommandFileName;
	local int Count;
	local String HtmlString;
	local int i;
	local String CommandString;

	CommandFileName = m_hCommandFileEditBox.GetString();

	if( CommandFileName == "" )
	{
		DialogShow( DIALOG_Notice, GetSystemMessage( 1415 ) );
		return;
	}

	RefreshINI( CommandFileName );

	if( !GetINIInt( "Cmd", "CmdCnt", Count, CommandFileName ) )
		Count = 0;

	HtmlString = "<html><body>";

	for( i = 0; i < Count; ++i )
	{
		if( GetINIString( "Cmd", "Cmd" $ i, CommandString, CommandFileName ) )
			HtmlString = HtmlString $ "<a cmd = \"" $ CommandString $ "\">" $ CommandString $ "</a><br1>";
	}

	HtmlString = HtmlString $ "</body></html>";

	m_hEventMatchGMCommandWnd.ShowWindow();
	m_hEventMatchGMCommandWnd.SetFocus();
	m_hCommandHtml.LoadHtmlFromString( HtmlString );
}

function OnClickSendGameEngMsgButton();
function OnClickSetFenceButton();
function OnClickTeam1FirecrackerButton();
function OnClickTeam2FirecrackerButton();
function NotifyFenceInfo( Vector a_Position, int a_XLength, int a_YLength );
function HandleShowEventMatchGMWnd();
function HandleEventMatchCreated( String a_Param );
function HandleEventMatchUpdateTeamInfo( String a_Param )
{
	local int TeamID;
	local int i;
	local int PartyMemberCount;
	local LVDataRecord Record;
	local EventMatchUserData UserData;
	local ListCtrlHandle hTeamListCtrl;

	if( ParseInt( a_Param, "TeamID", TeamID ) )
	{
		PartyMemberCount = class'EventMatchAPI'.static.GetPartyMemberCount( TeamID );

		switch( TeamID )
		{
		case 0:
			m_hLockTeam1Button.EnableWindow();
			if( 0 != PartyMemberCount )
			{
				m_hLockTeam1Button.SetButtonName( 1072 );
				m_Team1Locked = true;
			}
			hTeamListCtrl = m_hTeam1ListCtrl;
			break;
		case 1:
			m_hLockTeam2Button.EnableWindow();
			if( 0 != PartyMemberCount )
			{
				m_hLockTeam2Button.SetButtonName( 1072 );
				m_Team2Locked = true;
			}
			hTeamListCtrl = m_hTeam2ListCtrl;
			break;
		default:
			break;
		}

		hTeamListCtrl.DeleteAllItem();
		Record.LVDataList.Length = 3;
		for( i = 0; i < PartyMemberCount; ++i )
		{
			if( class'EventMatchAPI'.static.GetUserData( TeamID, i, UserData ) )
			{
				Record.LVDataList[ 0 ].szData = UserData.UserName;
				Record.LVDataList[ 1 ].szData = String( UserData.UserLv );
				Record.LVDataList[ 2 ].szData = GetClassType( UserData.UserClass );
				hTeamListCtrl.InsertRecord( Record );
			}
		}

		RefreshLockStatus();
	}
}
function RefreshLockStatus();
function StartCountDown();

state HidingState
{
	function BeginState()
	{
		m_hOwnerWnd.HideWindow();
	}

	function EndState()
	{
		m_hOwnerWnd.ShowWindow();
	}

	function HandleShowEventMatchGMWnd()
	{
		GotoState( 'WaitingState' );
	}
}

state WaitingState
{
	function BeginState()
	{
		SetMatchID( -1 );
		m_hLockTeam1Button.SetButtonName( 1071 );
		m_hLockTeam2Button.SetButtonName( 1071 );
		m_hTeam1ListCtrl.DeleteAllItem();
		m_hTeam2ListCtrl.DeleteAllItem();
		m_Team1Locked = false;
		m_Team2Locked = false;
		SetPause( false );

		m_hCreateEventMatchButton.SetButtonName( 1068 );
		m_hCreateEventMatchButton.EnableWindow();
		m_hSetTeam1LeaderButton.DisableWindow();
		m_hLockTeam1Button.DisableWindow();
		m_hSetTeam2LeaderButton.DisableWindow();
		m_hLockTeam2Button.DisableWindow();
		m_hPauseButton.DisableWindow();
		m_hStartButton.DisableWindow();
		m_hSetScoreButton.DisableWindow();
		m_hSendAnnounceButton.DisableWindow();
		m_hSendGameEndMsgButton.DisableWindow();
		m_hSetFenceButton.DisableWindow();
		m_hTeam1FirecrackerButton.DisableWindow();
		m_hTeam2FirecrackerButton.DisableWindow();
	}

	function OnClickCreateEventMatchButton()
	{
		local String Team1Name;
		local String Team2Name;

		Team1Name = m_hTeam1NameEditBox.GetString();
		if( Team1Name == "" )
		{
			DialogShow( DIALOG_Notice, GetSystemMessage( 1418 ) );
			return;
		}

		Team2Name = m_hTeam2NameEditBox.GetString();
		if( Team2Name == "" )
		{
			DialogShow( DIALOG_Notice, GetSystemMessage( 1419 ) );
			return;
		}

		if( Team1Name == Team2Name )
		{
			DialogShow( DIALOG_Notice, GetSystemMessage( 1420 ) );
			return;
		}

		m_Team1Name = Team1Name;
		m_Team2Name = Team2Name;

		m_hEventMatchGMFenceWnd.ShowWindow();
		m_hEventMatchGMFenceWnd.SetFocus();
	}

	function NotifyFenceInfo( Vector a_Position, int a_XLength, int a_YLength )
	{
		ExecuteCommand( "//eventmatch create 1" @ m_Team1Name @ m_Team2Name @ int( a_Position.X ) @ int( a_Position.Y ) @ int( a_Position.Z ) @ a_XLength @ a_YLength );
		GotoState( 'CreatingState' );
	}
}

state CreatingState
{
	function BeginState()
	{
		m_hCreateEventMatchButton.SetButtonName( 1099 );
		m_hCreateEventMatchButton.DisableWindow();
	}

	function HandleEventMatchCreated( String a_Param )
	{
		local int MatchID;

		if( ParseInt( a_Param, "MatchID", MatchID ) )
		{
			SetMatchID( MatchID );
			GotoState( 'CreatedState' );
		}
	}
}

state CreatedState
{
	function BeginState()
	{
		m_hCreateEventMatchButton.SetButtonName( 1069 );
		m_hStartButton.SetButtonName( 1075 );

		m_hCreateEventMatchButton.EnableWindow();
		m_hSetTeam1LeaderButton.EnableWindow();
		m_hLockTeam1Button.EnableWindow();
		m_hSetTeam2LeaderButton.EnableWindow();
		m_hLockTeam2Button.EnableWindow();
		m_hPauseButton.DisableWindow();
		RefreshLockStatus();
		m_hSetScoreButton.EnableWindow();
		m_hSendAnnounceButton.EnableWindow();
		m_hSendGameEndMsgButton.EnableWindow();
		m_hSetFenceButton.EnableWindow();
		m_hTeam1FirecrackerButton.EnableWindow();
		m_hTeam2FirecrackerButton.EnableWindow();
		SetPause( false );
	}

	function OnClickCreateEventMatchButton()
	{
		RemoveEventMatch();
	}

	function OnClickSetTeam1LeaderButton()
	{
		local UserInfo TargetInfo;

		if( GetTargetInfo( TargetInfo ) )
			m_hTeam1LeaderNameEditBox.SetString( TargetInfo.Name );
	}

	function OnClickLockTeam1Button()
	{
		if( m_Team1Locked )
		{
			ExecuteCommand( "//eventmatch unlock" @ m_MatchID @ "1" );
			m_hLockTeam1Button.SetButtonName( 1071 );
			m_Team1Locked = false;
			m_hTeam1ListCtrl.DeleteAllItem();
			RefreshLockStatus();
		}
		else
		{
			ExecuteCommand( "//eventmatch leader" @ m_MatchID @ "1" @ m_hTeam1LeaderNameEditBox.GetString() );
			ExecuteCommand( "//eventmatch lock" @ m_MatchID @ "1" );
		}
	}

	function OnClickSetTeam2LeaderButton()
	{
		local UserInfo TargetInfo;

		if( GetTargetInfo( TargetInfo ) )
			m_hTeam2LeaderNameEditBox.SetString( TargetInfo.Name );
	}

	function OnClickLockTeam2Button()
	{
		if( m_Team2Locked )
		{
			ExecuteCommand( "//eventmatch unlock" @ m_MatchID @ "2" );
			m_hLockTeam2Button.SetButtonName( 1071 );
			m_Team2Locked = false;
			m_hTeam2ListCtrl.DeleteAllItem();
			RefreshLockStatus();
		}
		else
		{
			ExecuteCommand( "//eventmatch leader" @ m_MatchID @ "2" @ m_hTeam2LeaderNameEditBox.GetString() );
			ExecuteCommand( "//eventmatch lock" @ m_MatchID @ "2" );
		}
	}

	function RefreshLockStatus()
	{
		if( m_Team1Locked && m_Team2Locked )
			m_hStartButton.EnableWindow();
		else
			m_hStartButton.DisableWindow();
	}

	function OnClickSetFenceButton()
	{
		SetFence();
	}

	function OnClickStartButton()
	{
		local String OptionFile;

		OptionFile = m_hOptionFileEditBox.GetString();

		if( OptionFile == "" )
		{
			DialogShow( DIALOG_Notice, GetSystemMessage( 1421 ) );
			return;
		}

		RefreshINI( OptionFile );
		if( !ApplySkillRule( OptionFile ) )
			return;

		if( !ApplyItemRule( OptionFile ) )
			return;

		if( !CheckBuffRule( OptionFile ) )
			return;

		GotoState( 'CountDownState' );
	}

	function OnClickSetScoreButton()
	{
		SetScore();
	}

	function OnClickSendAnnounceButton()
	{
		SendAnnounce();
	}

	function OnClickSendGameEngMsgButton()
	{
		SendGameEndMsg();
	}

	function OnClickTeam1FirecrackerButton()
	{
		Firecracker( 0 );
	}

	function OnClickTeam2FirecrackerButton()
	{
		Firecracker( 1 );
	}

	function OnCompleteEditBox( String a_EditBoxID )
	{
		if( a_EditBoxID == "AnnounceEditBox" )
		{
			SendAnnounce();
		}
	}
}

state CountDownState
{
	function BeginState()
	{
		m_hStartButton.DisableWindow();
		m_hStartButton.SetButtonName( 1102 );
		m_hOwnerWnd.SetTimer( TIMERID_CountDown, 1000 );
		m_CountDown = 4;
		ExecuteCommand( "//eventmatch msg" @ m_MatchID @ EEventMatchObsMsgType.MESSAGE_5 @ "NULL" );
	}

	function OnClickCreateEventMatchButton()
	{
		RemoveEventMatch();
	}

	function OnClickSetFenceButton()
	{
		SetFence();
	}

	function OnTimer( int a_TimerID )
	{
		switch( a_TimerID )
		{
		case TIMERID_CountDown:
			switch( m_CountDown )
			{
			case 4:
				ExecuteCommand( "//eventmatch msg" @ m_MatchID @ EEventMatchObsMsgType.MESSAGE_4 @ "NULL" );
				m_CountDown = 3;
				break;
			case 3:
				ExecuteCommand( "//eventmatch msg" @ m_MatchID @ EEventMatchObsMsgType.MESSAGE_3 @ "NULL" );
				m_CountDown = 2;
				break;
			case 2:
				ExecuteCommand( "//eventmatch msg" @ m_MatchID @ EEventMatchObsMsgType.MESSAGE_2 @ "NULL" );
				m_CountDown = 1;
				break;
			case 1:
				ExecuteCommand( "//eventmatch msg" @ m_MatchID @ EEventMatchObsMsgType.MESSAGE_1 @ "NULL" );
				m_CountDown = 0;
				break;
			case 0:
				ExecuteCommand( "//eventmatch msg" @ m_MatchID @ EEventMatchObsMsgType.MESSAGE_Start @ "NULL" );
				if( !ApplyBuffRule() )
					return;
				ExecuteCommand( "//eventmatch start" @ m_MatchID );
				GotoState( 'GamingState' );
			default:
				m_hOwnerWnd.KillTimer( TIMERID_CountDown );
				m_CountDown = -1;
				break;
			}
			break;
		}
	}

	function OnClickSetScoreButton()
	{
		SetScore();
	}

	function OnClickSendAnnounceButton()
	{
		SendAnnounce();
	}

	function OnClickSendGameEngMsgButton()
	{
		SendGameEndMsg();
	}

	function OnClickTeam1FirecrackerButton()
	{
		Firecracker( 0 );
	}

	function OnClickTeam2FirecrackerButton()
	{
		Firecracker( 1 );
	}

	function OnCompleteEditBox( String a_EditBoxID )
	{
		if( a_EditBoxID == "AnnounceEditBox" )
		{
			SendAnnounce();
		}
	}
}

state GamingState
{
	function BeginState()
	{
		m_hPauseButton.SetButtonName( 1073 );
		m_hStartButton.SetButtonName( 1076 );

		m_hCreateEventMatchButton.EnableWindow();
		m_hSetTeam1LeaderButton.DisableWindow();
		m_hLockTeam1Button.DisableWindow();
		m_hSetTeam2LeaderButton.DisableWindow();
		m_hLockTeam2Button.DisableWindow();
		m_hPauseButton.EnableWindow();
		m_hStartButton.EnableWindow();
		m_hSetScoreButton.EnableWindow();
		m_hSendAnnounceButton.EnableWindow();
		m_hSendGameEndMsgButton.EnableWindow();
		m_hSetFenceButton.EnableWindow();
		m_hTeam1FirecrackerButton.EnableWindow();
		m_hTeam2FirecrackerButton.EnableWindow();
	}

	function OnClickCreateEventMatchButton()
	{
		RemoveEventMatch();
	}

	function OnClickStartButton()
	{
		ExecuteCommand( "//eventmatch dispelall" @ m_MatchID );
		ExecuteCommand( "//eventmatch end" @ m_MatchID );
		ExecuteCommand( "//eventmatch msg" @ m_MatchID @ EEventMatchObsMsgType.MESSAGE_FINISH @ "NULL" );
		GotoState( 'CreatedState' );
	}

	function OnClickSetFenceButton()
	{
		SetFence();
	}

	function OnClickPauseButton()
	{
		SetPause( !m_Paused, true );
	}

	function OnClickSetScoreButton()
	{
		SetScore();
	}

	function OnClickSendAnnounceButton()
	{
		SendAnnounce();
	}

	function OnClickSendGameEngMsgButton()
	{
		SendGameEndMsg();
	}

	function OnClickTeam1FirecrackerButton()
	{
		Firecracker( 0 );
	}

	function OnClickTeam2FirecrackerButton()
	{
		Firecracker( 1 );
	}

	function OnCompleteEditBox( String a_EditBoxID )
	{
		if( a_EditBoxID == "AnnounceEditBox" )
		{
			SendAnnounce();
		}
	}
}

function bool ApplySkillRule( String a_OptionFile )
{
	local int DefaultAllow;
	local String Command;
	local int i;
	local int Count;
	local int ID;

	if( !GetINIBool( "Skill", "DefaultAllow", DefaultAllow, a_OptionFile ) )
	{
		DialogShow( DIALOG_Notice, GetSystemMessage( 1425 ) );
		return false;
	}

	Command = "//eventmatch skill_rule" @ m_MatchID;
	if( 1 == DefaultAllow )
		Command = Command @ "allow_all";
	else
		Command = Command @ "deny_all";

	if( !GetINIInt( "Skill", "ExpSkillCnt", Count, a_OptionFile ) )
		Count = 0;

	for( i = 0; i < Count; ++i )
	{
		if( !GetINIInt( "Skill", "ExpSkillID" $ i, ID, a_OptionFile ) )
		{
			DialogShow( DIALOG_Notice, MakeFullSystemMsg( GetSystemMessage( 1427 ), String( i ) ) );
			return false;
		}

		if( 1 == DefaultAllow )
			Command = Command @ "D";
		else
			Command = Command @ "A";

		Command = Command $ ID;
	}

	ExecuteCommand( Command );

	return true;
}

function bool ApplyItemRule( String a_OptionFile )
{
	local int DefaultAllow;
	local String Command;
	local int i;
	local int Count;
	local int ID;

	if( !GetINIBool( "Item", "DefaultAllow", DefaultAllow, a_OptionFile ) )
	{
		DialogShow( DIALOG_Notice, GetSystemMessage( 1425 ) );
		return false;
	}

	Command = "//eventmatch item_rule" @ m_MatchID;
	if( 1 == DefaultAllow )
		Command = Command @ "allow_all";
	else
		Command = Command @ "deny_all";

	if( !GetINIInt( "Item", "ExpItemCnt", Count, a_OptionFile ) )
		Count = 0;

	for( i = 0; i < Count; ++i )
	{
		if( !GetINIInt( "Item", "ExpItemID" $ i, ID, a_OptionFile ) )
		{
			DialogShow( DIALOG_Notice, MakeFullSystemMsg( GetSystemMessage( 1427 ), String( i ) ) );
			return false;
		}

		if( 1 == DefaultAllow )
			Command = Command @ "D";
		else
			Command = Command @ "A";

		Command = Command $ ID;
	}

	ExecuteCommand( Command );

	return true;
}

function bool ApplyBuffRule()
{
	local String OptionFile;
	local String Command;
	local int i;
	local int Count;
	local int Level;
	local int ID;

	OptionFile = m_hOptionFileEditBox.GetString();

	if( !GetINIInt( "Buff", "BuffCnt", Count, OptionFile ) )
	{
		DialogShow( DIALOG_Notice, GetSystemMessage( 1422 ) );
		return false;
	}

	if( 0 >= Count )
		return true;

	Command = "//eventmatch useskill" @ m_MatchID;

	for( i = 0; i < Count; ++i )
	{
		if( !GetINIInt( "Buff", "BuffID" $ i, ID, OptionFile ) )
		{
			DialogShow( DIALOG_Notice, MakeFullSystemMsg( GetSystemMessage( 1423 ), String( i ) ) );
			return false;
		}

		if( !GetINIInt( "Buff", "BuffLv" $ i, Level, OptionFile ) )
		{
			DialogShow( DIALOG_Notice, MakeFullSystemMsg( GetSystemMessage( 1424 ), String( i ) ) );
			return false;
		}

		Command = Command @ ID @ Level;
	}

	ExecuteCommand( Command );

	return true;
}

function bool CheckBuffRule( String a_OptionFile )
{
	local int i;
	local int Count;
	local int Level;
	local int ID;

	if( !GetINIInt( "Buff", "BuffCnt", Count, a_OptionFile ) )
	{
		DialogShow( DIALOG_Notice, GetSystemMessage( 1422 ) );
		return false;
	}

	for( i = 0; i < Count; ++i )
	{
		if( !GetINIInt( "Buff", "BuffID" $ i, ID, a_OptionFile ) )
		{
			DialogShow( DIALOG_Notice, MakeFullSystemMsg( GetSystemMessage( 1423 ), String( i ) ) );
			return false;
		}

		if( !GetINIInt( "Buff", "BuffLv" $ i, Level, a_OptionFile ) )
		{
			DialogShow( DIALOG_Notice, MakeFullSystemMsg( GetSystemMessage( 1424 ), String( i ) ) );
			return false;
		}
	}

	return true;
}

function SetFence()
{
	if( m_hSetFenceButton.GetButtonName() == GetSystemString( 1081 ) )
	{
		m_hSetFenceButton.SetButtonName( 1082 );
		ExecuteCommand( "//eventmatch fence" @ m_MatchID @ "2" );
	}
	else if( m_hSetFenceButton.GetButtonName() == GetSystemString( 1082 ) )
	{
		m_hSetFenceButton.SetButtonName( 1081 );
		ExecuteCommand( "//eventmatch fence" @ m_MatchID @ "1" );
	}
}

function RemoveEventMatch()
{
	m_Team1Name = "";
	m_Team2Name = "";

	ExecuteCommand( "//eventmatch remove" @ m_MatchID );

	// TODO: There is no event for removing eventmatch.
	//	Create an eventmatch removing event, and move to WaitingState upon that event - NeverDie
	GotoState( 'WaitingState' );
}

function SetScore()
{
	ExecuteCommand( "//eventmatch score" @ m_MatchID @ m_hTeam1ScoreEditBox.GetString() @ m_hTeam2ScoreEditBox.GetString() );
}

function SendAnnounce()
{
	ExecuteCommand( "//eventmatch msg" @ m_MatchID @ EEventMatchObsMsgType.MESSAGE_GM @ "\"" @ m_hAnnounceEditBox.GetString() @ "\"" );
	m_hAnnounceEditBox.Clear();
}

function SendGameEndMsg()
{
	ExecuteCommand( "//eventmatch msg" @ m_MatchID @ EEventMatchObsMsgType.MESSAGE_GameOver @ "NULL" );
}

function Firecracker( int a_TeamID )
{
	local int PartyMemberCount;
	local int i;
	local EventMatchUserData UserData;

	PartyMemberCount = class'EventMatchAPI'.static.GetPartyMemberCount( a_TeamID );
	for( i = 0; i < PartyMemberCount; ++i )
	{
		if( class'EventMatchAPI'.static.GetUserData( a_TeamID, i, UserData ) )
		{
			ExecuteCommand( "//eventmatch firecracker" @ UserData.UserName );
		}
	}
}

function HandleEventMatchManage( String a_Param )
{
	local int MatchID;
	local int MatchStat;
	local int FenceStat;
	local String Team1Name;
	local String Team2Name;
	local int Team1Stat;
	local int Team2Stat;

	ParseInt( a_Param, "MatchID", MatchID );
	ParseInt( a_Param, "MatchStat", MatchStat );
	ParseInt( a_Param, "FenceStat", FenceStat );
	ParseString( a_Param, "Team1Name", Team1Name );
	ParseString( a_Param, "Team2Name", Team2Name );
	ParseInt( a_Param, "Team1Stat", Team1Stat );
	ParseInt( a_Param, "Team2Stat", Team2Stat );

	SetMatchID( MatchID );

	switch( MatchStat )
	{
	case 1:	// Ready
		GotoState( 'CreatedState' );
		break;
	case 2:	// Playing
		GotoState( 'GamingState' );
		SetPause( false );
		break;
	case 3:	// Pause
		GotoState( 'GamingState' );
		SetPause( true );
		break;
	}

	switch( FenceStat )
	{
	case 0:	// None
	case 1:	// Column
		m_hSetFenceButton.SetButtonName( 1081 );
		break;
	case 2:	// Wall
		m_hSetFenceButton.SetButtonName( 1082 );
		break;
	}

	if( 0 == Team1Stat )
	{
		m_hLockTeam1Button.SetButtonName( 1071 );
		m_Team1Locked = false;
	}
	else
	{
		m_hLockTeam1Button.SetButtonName( 1072 );
		m_Team1Locked = true;
	}

	if( 0 == Team2Stat )
	{
		m_hLockTeam2Button.SetButtonName( 1071 );
		m_Team2Locked = false;
	}
	else
	{
		m_hLockTeam2Button.SetButtonName( 1072 );
		m_Team2Locked = true;
	}

	m_hTeam1NameEditBox.SetString( Team1Name );
	m_hTeam2NameEditBox.SetString( Team2Name );

	m_hTeam1ListCtrl.DeleteAllItem();
	m_hTeam2ListCtrl.DeleteAllItem();
}

function SetPause( bool a_Pause, optional bool a_SendToServer )
{
	Debug( "SetPause" @ a_Pause @ "m_Paused" @ m_Paused );

	if( m_Paused == a_Pause )
		return;

	if( a_Pause )
	{
		m_hPauseButton.SetButtonName( 1074 );
		if( a_SendToServer )
			ExecuteCommand( "//eventmatch pause" @ m_MatchID );		
	}
	else
	{
		m_hPauseButton.SetButtonName( 1073 );
		if( a_SendToServer )
			ExecuteCommand( "//eventmatch start" @ m_MatchID );		
	}

	m_Paused = a_Pause;
}

function SetMatchID( int a_MatchID )
{
	m_MatchID = a_MatchID;

	if( -1 == m_MatchID )
		m_hMatchIDTextBox.SetText( "" );
	else
		m_hMatchIDTextBox.SetText( String( m_MatchID ) );
}


function OnClickSummon2Team()
{
	local int i;
	local int PartyMemberCount;
	local EventMatchUserData UserData;
	
	PartyMemberCount = class'EventMatchAPI'.static.GetPartyMemberCount( 1 );
		
	for( i = 0; i < PartyMemberCount; ++i )
		{
			if( class'EventMatchAPI'.static.GetUserData( 1, i, UserData ) )
			{
				ExecuteCommand("//소환" @ UserData.UserName);
			}
		}
}

function OnClickSetAllHeal()
{
	local int PartyMemberCount0;
	local int PartyMemberCount1;
	local EventMatchUserData UserData;
	local int i;
	
	PartyMemberCount0 = class'EventMatchAPI'.static.GetPartyMemberCount( 0 );
	PartyMemberCount1 = class'EventMatchAPI'.static.GetPartyMemberCount( 1 );
		
	for( i = 0; i < PartyMemberCount0; ++i )
		{
			if( class'EventMatchAPI'.static.GetUserData( 0, i, UserData ) )
			{
				ExecuteCommand("//건강" @ UserData.UserName);
			}
		}
	for( i = 1; i < PartyMemberCount1; ++i )
		{
			if( class'EventMatchAPI'.static.GetUserData( 1, i, UserData ) )
			{
				ExecuteCommand("//건강" @ UserData.UserName);
			}
		}
	
	

}

function OnClickDelayReset()
{
	local int PartyMemberCount0;
	local int PartyMemberCount1;
	local EventMatchUserData UserData;
	local int i;
	
	PartyMemberCount0 = class'EventMatchAPI'.static.GetPartyMemberCount( 0 );
	PartyMemberCount1 = class'EventMatchAPI'.static.GetPartyMemberCount( 1 );
		
	for( i = 0; i < PartyMemberCount0; ++i )
		{
			if( class'EventMatchAPI'.static.GetUserData( 0, i, UserData ) )
			{
				 ExecuteCommand("//타겟" @ UserData.UserName);
				 ExecuteCommand("//remove_skill_delay all");
			}
		}
	for( i = 1; i < PartyMemberCount1; ++i )
		{
			if( class'EventMatchAPI'.static.GetUserData( 1, i, UserData ) )
			{
				 ExecuteCommand("//타겟" @ UserData.UserName);
				 ExecuteCommand("//remove_skill_delay all");
			}
		}

}

function OnClickSummon1Team()
{
	local int PartyMemberCount;
	local int i;
	local EventMatchUserData UserData;
	
	PartyMemberCount = class'EventMatchAPI'.static.GetPartyMemberCount( 0 );
		for( i = 0; i < PartyMemberCount; ++i )
		{
			if( class'EventMatchAPI'.static.GetUserData( 0, i, UserData ) )
			{
				ExecuteCommand("//소환" @ UserData.UserName);
			}
		}

}
