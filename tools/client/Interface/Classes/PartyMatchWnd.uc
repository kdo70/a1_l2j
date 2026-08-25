class PartyMatchWnd extends UIScript;

var int m_CurrentPageNum;
var int CompletelyQuitPartyMatching;
var bool bOpenStateLobby;

function OnLoad()
{
	RegisterEvent( EV_PartyMatchStart );
	RegisterEvent( EV_PartyMatchList );
	RegisterEvent( EV_PartyMatchRoomStart );
	m_CurrentPageNum = 0;
	CompletelyQuitPartyMatching = 0;
	bOpenStateLobby = false;
	
	//검색조건의 초기치 설정
	class'UIAPI_COMBOBOX'.static.SetSelectedNum( "PartyMatchWnd.LocationFilterComboBox", 1 );
	class'UIAPI_COMBOBOX'.static.SetSelectedNum( "PartyMatchWnd.LevelFilterComboBox", 1 );
}

function OnShow()
{
	class'UIAPI_LISTCTRL'.static.ShowScrollBar( "PartyMatchWnd.PartyMatchListCtrl", false );
}

//x버튼을 눌러서 윈도우를 닫으면, 대기자목록에서 빠진다.
function OnSendPacketWhenHiding()
{
	class'PartyMatchAPI'.static.RequestExitPartyMatchingWaitingRoom();
}

function OnHide()
{
	class'UIAPI_WINDOW'.static.HideWindow( "PartyMatchMakeRoomWnd" );
}

function OnEvent(int a_EventID, String param)
{
	local PartyMatchMakeRoomWnd Script;
	
	Script = PartyMatchMakeRoomWnd( GetScript( "PartyMatchMakeRoomWnd" ) );
	
	switch( a_EventID )
	{
	case EV_PartyMatchStart:
		if (CompletelyQuitPartyMatching == 1)
		{
			class'PartyMatchAPI'.static.RequestExitPartyMatchingWaitingRoom();
			class'UIAPI_WINDOW'.static.HideWindow( "PartyMatchWnd" );
			Script.OnCancelButtonClick();
			
			CompletelyQuitPartyMatching = 0;
			SetWaitListWnd(false);
		}
		else 
		{
			//대기자리스트 업데이트
			UpdateWaitListWnd();
			
			if (class'UIAPI_WINDOW'.static.IsShowWindow( "PartyMatchWnd" ) == false)
			{	
				class'UIAPI_WINDOW'.static.ShowWindow( "PartyMatchWnd" );
				class'UIAPI_LISTCTRL'.static.ShowScrollBar( "PartyMatchWnd.PartyMatchListCtrl", false );
			}		
			class'UIAPI_WINDOW'.static.SetFocus( "PartyMatchWnd" );
		}
		break;
	case EV_PartyMatchList:
		HandlePartyMatchList(param);
		break;
	case EV_PartyMatchRoomStart:
		class'UIAPI_WINDOW'.static.HideWindow( "PartyMatchWnd" );
		break;
	}
}

//5초가 지나면 버튼들의 Disable상태가 풀린다
function OnButtonTimer( bool bExpired )
{
	if (bExpired)
	{
		class'UIAPI_BUTTON'.static.EnableWindow( "PartyMatchWnd.PrevBtn" );
		class'UIAPI_BUTTON'.static.EnableWindow( "PartyMatchWnd.NextBtn" );
		class'UIAPI_BUTTON'.static.EnableWindow( "PartyMatchWnd.AutoJoinBtn" );
		class'UIAPI_BUTTON'.static.EnableWindow( "PartyMatchWnd.RefreshBtn" );
	}
	else
	{
		class'UIAPI_BUTTON'.static.DisableWindow( "PartyMatchWnd.PrevBtn" );
		class'UIAPI_BUTTON'.static.DisableWindow( "PartyMatchWnd.NextBtn" );
		class'UIAPI_BUTTON'.static.DisableWindow( "PartyMatchWnd.AutoJoinBtn" );
		class'UIAPI_BUTTON'.static.DisableWindow( "PartyMatchWnd.RefreshBtn" );
	}
}

function HandlePartyMatchList(string param)
{
	local int Count;
	local int i;
	local LVDataRecord Record;
	local int Number;
	local String PartyRoomName;
	local String PartyLeader;
	local int ZoneID;
	local int MinLevel;
	local int MaxLevel;
	local int MinMemberCnt;
	local int MaxMemberCnt;
	
	class'UIAPI_LISTCTRL'.static.DeleteAllItem( "PartyMatchWnd.PartyMatchListCtrl" );
	Record.LVDataList.length = 6;

	ParseInt(param, "PageNum", m_CurrentPageNum);
	ParseInt(param, "RoomCount", Count);
	for( i = 0; i < Count; ++i )
	{
		ParseInt(param, "RoomNum_" $ i, Number);
		ParseString(param, "Leader_" $ i, PartyLeader);
		ParseInt(param, "ZoneID_" $ i, ZoneID);	
		ParseInt(param, "MinLevel_" $ i, MinLevel);
		ParseInt(param, "MaxLevel_" $ i, MaxLevel);
		ParseInt(param, "CurMember_" $ i, MinMemberCnt);
		ParseInt(param, "MaxMember_" $ i, MaxMemberCnt);
		ParseString(param, "RoomName_" $ i, PartyRoomName);
	
		Record.LVDataList[0].szData = String( Number );
		Record.LVDataList[1].szData = PartyLeader;
		Record.LVDataList[2].szData = PartyRoomName;
		Record.LVDataList[3].szData = GetZoneNameWithZoneID( ZoneID );
		Record.LVDataList[4].szData = MinLevel $ "-" $ MaxLevel;
		Record.LVDataList[5].szData = MinMemberCnt $ "/" $ MaxMemberCnt;

		class'UIAPI_LISTCTRL'.static.InsertRecord( "PartyMatchWnd.PartyMatchListCtrl", Record );
	}
}

function OnClickButton( string a_strButtonName )
{
	switch( a_strButtonName )
	{
	case "RefreshBtn":
		OnRefreshBtnClick();
		break;
	case "PrevBtn":
		OnPrevBtnClick();
		break;
	case "NextBtn":
		OnNextBtnClick();
		break;
	case "MakeRoomBtn":
		OnMakeRoomBtnClick();
		break;
	case "AutoJoinBtn":
		OnAutoJoinBtnClick();
		break;
	case "WaitListButton":
		OnWaitListButton();
		break;
	}
}

function OnWaitListButton()
{
	ToggleWaitListWnd();
	UpdateWaitListWnd();
}

function OnRefreshBtnClick()
{
	RequestPartyRoomListLocal( 1 );
}
 
function OnPrevBtnClick()
{
	local int WantedPageNum;

	if( 1 >= m_CurrentPageNum )
		WantedPageNum = 1;
	else
		WantedPageNum = m_CurrentPageNum - 1;

	RequestPartyRoomListLocal( WantedPageNum );
}

function OnNextBtnClick()
{
	RequestPartyRoomListLocal( m_CurrentPageNum + 1 );	
}

function RequestPartyRoomListLocal( int a_Page )
{
	class'PartyMatchAPI'.static.RequestPartyRoomList( a_Page, GetLocationFilter(), GetLevelFilter() );
}

function OnMakeRoomBtnClick()
{
	local PartyMatchMakeRoomWnd Script;
	local UserInfo PlayerInfo;

	Script = PartyMatchMakeRoomWnd( GetScript( "PartyMatchMakeRoomWnd" ) );
	if( Script != None )
	{
		Script.SetRoomNumber( 0 );
		Script.SetTitle( GetSystemMessage( 1398 ) );
		Script.SetMaxPartyMemberCount( 12 );
		if( GetPlayerInfo( PlayerInfo ) )
		{
			if( PlayerInfo.nLevel - 5 > 0 )
				Script.SetMinLevel( PlayerInfo.nLevel - 5 );
			else
				Script.SetMinLevel( 1 );

			if( PlayerInfo.nLevel + 5 <= MAX_Level )
				Script.SetMaxLevel( PlayerInfo.nLevel + 5 );
			else
				Script.SetMaxLevel( Max_Level );
		}		
	}
	script.InviteState = 0;
	class'UIAPI_WINDOW'.static.ShowWindow( "PartyMatchMakeRoomWnd" );
	class'UIAPI_WINDOW'.static.SetFocus( "PartyMatchMakeRoomWnd" );
}

function OnDBClickListCtrlRecord( String a_ListCtrlName )
{
	local int SelectedRecordIndex;
	local LVDataRecord Record;	

	if( a_ListCtrlName != "PartyMatchListCtrl" )
		return;

	SelectedRecordIndex = class'UIAPI_LISTCTRL'.static.GetSelectedIndex( "PartyMatchWnd.PartyMatchListCtrl" );
	Record = class'UIAPI_LISTCTRL'.static.GetRecord( "PartyMatchWnd.PartyMatchListCtrl", SelectedRecordIndex );
	class'PartyMatchAPI'.static.RequestJoinPartyRoom( int( Record.LVDataList[0].szData ) );	
}

function OnAutoJoinBtnClick()
{
	class'PartyMatchAPI'.static.RequestJoinPartyRoomAuto( m_CurrentPageNum, GetLocationFilter(), GetLevelFilter() );
}

function int GetLocationFilter()
{
	return class'UIAPI_COMBOBOX'.static.GetReserved( "PartyMatchWnd.LocationFilterComboBox", class'UIAPI_COMBOBOX'.static.GetSelectedNum( "PartyMatchWnd.LocationFilterComboBox" ) );
}

function int GetLevelFilter()
{
	return class'UIAPI_COMBOBOX'.static.GetSelectedNum( "PartyMatchWnd.LevelFilterComboBox" );
}

/////////////////////////////////////////////////////////////////////////////////
////// 대기자 리스트 관련 공통 함수
////// WaitListWnd는 2개가 있는데, Show/Hide의 설정을 한곳에서 관리하기 위함
/////////////////////////////////////////////////////////////////////////////////

//대기자리스트 Flag설정
function SetWaitListWnd(bool bShow)
{
	bOpenStateLobby = bShow;
}

//대기자리스트 표시
function ShowHideWaitListWnd()
{
	if (bOpenStateLobby)
	{
		class'UIAPI_WINDOW'.static.ShowWindow( "PartyMatchWnd.PartyMatchOutWaitListWnd" );
		class'UIAPI_WINDOW'.static.ShowWindow( "PartyMatchWnd.PartyMatchWaitListWnd" );
	}
	else 
	{
		class'UIAPI_WINDOW'.static.HideWindow( "PartyMatchWnd.PartyMatchOutWaitListWnd" );
		class'UIAPI_WINDOW'.static.HideWindow( "PartyMatchWnd.PartyMatchWaitListWnd" );
	}
}

//대기자리스트 업데이트
function UpdateWaitListWnd()
{
	local int MinLevel;
	local int MaxLevel;
	
	if (IsShowWaitListWnd())
	{
		MinLevel = int(class'UIAPI_EDITBOX'.static.GetString( "PartyMatchOutWaitListWnd.MinLevel"));
		MaxLevel = int(class'UIAPI_EDITBOX'.static.GetString( "PartyMatchOutWaitListWnd.MaxLevel"));
		
		class'PartyMatchAPI'.static.RequestPartyMatchWaitList(1, MinLevel, MaxLevel, 1);
	}	
}

//대기자리스트 토글
function ToggleWaitListWnd()
{
	bOpenStateLobby = !bOpenStateLobby;	
	ShowHideWaitListWnd();
}

function bool IsShowWaitListWnd()
{
	return bOpenStateLobby;
}
