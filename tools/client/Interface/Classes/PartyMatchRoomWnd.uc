class PartyMatchRoomWnd extends PartyMatchWndCommon;

var int RoomNumber;
var int CurPartyMemberCount;
var int MaxPartyMemberCount;
var int MinLevel;
var int MaxLevel;
var int LootingMethodID;
var int RoomZoneID;
var int MyMembershipType;	// 0:Want to be party member, 1:Room Master, 2:Party member

var string RoomTitle;

var bool m_bPartyMatchRoomStart;
var bool m_bRequestExitPartyRoom;

function OnLoad()
{
	RegisterEvent( EV_Restart );
	RegisterEvent( EV_PartyMatchRoomStart );
	RegisterEvent( EV_PartyMatchRoomClose );
	RegisterEvent( EV_PartyMatchRoomMember );
	RegisterEvent( EV_PartyMatchRoomMemberUpdate );
	RegisterEvent( EV_PartyMatchChatMessage );
	RegisterEvent( EV_PartyMatchCommand );
	
	m_bPartyMatchRoomStart = false;
	m_bRequestExitPartyRoom = false;
}

//X버튼을 눌렀을때
function OnSendPacketWhenHiding()
{
	local PartyMatchWnd Script;
	
	Script = PartyMatchWnd( GetScript( "PartyMatchWnd" ) );
	if( Script != None )
	{
		Script.CompletelyQuitPartyMatching = 1;
		Script.SetWaitListWnd(false);
		Script.ShowHideWaitListWnd();
	}
	
	ExitPartyRoom();
}

function OnEnterState( name a_PreStateName )
{
	if (m_bPartyMatchRoomStart)
	{
		class'UIAPI_WINDOW'.static.ShowWindow( "PartyMatchRoomWnd" );
		class'UIAPI_WINDOW'.static.SetFocus( "PartyMatchRoomWnd" );
	}
}

function OnEvent( int a_EventID, String param )
{
	switch( a_EventID )
	{
	case EV_PartyMatchCommand:
	if (class'UIAPI_WINDOW'.static.IsMinimizedWindow("PartyMatchRoomWnd"))
		{
		    class'UIAPI_WINDOW'.static.ShowWindow("PartyMatchRoomWnd");
		}
		class'UIAPI_WINDOW'.static.SetFocus("PartyMatchRoomWnd");
		break;	
	case EV_PartyMatchRoomStart:
		HandlePartyMatchRoomStart( param );
		break;
	case EV_PartyMatchRoomClose:
		HandlePartyMatchRoomClose();
		break;
	case EV_PartyMatchRoomMember:
		HandlePartyMatchRoomMember( param );
		break;
	case EV_PartyMatchRoomMemberUpdate:
		HandlePartyMatchRoomMemberUpdate( param );
		break;
	case EV_PartyMatchChatMessage:
		HandlePartyMatchChatMessage( param );
		break;
	case EV_Restart:
		HandleRestart();
		break;
	}
}

function HandleRestart()
{
	m_bPartyMatchRoomStart = false;
}

function ExitPartyRoom()
{
	m_bRequestExitPartyRoom = true;
	
	switch( MyMembershipType )
	{
	case 0:
	case 2:
		class'PartyMatchAPI'.static.RequestWithdrawPartyRoom( RoomNumber );
		break;
	case 1:
		class'PartyMatchAPI'.static.RequestDismissPartyRoom( RoomNumber );
		break;
	}
}

function HandlePartyMatchRoomStart( String param )
{
	local Rect 	rectWnd;
	
	ParseInt(param, "RoomNum", RoomNumber);
	ParseInt(param, "MaxMember", MaxPartyMemberCount);
	ParseInt(param, "MinLevel", MinLevel);
	ParseInt(param, "MaxLevel", MaxLevel);
	ParseInt(param, "LootingMethodID", LootingMethodID);
	ParseInt(param, "ZoneID", RoomZoneID);
	ParseString(param, "RoomName", RoomTitle);
	
	UpdateData( true );
	
	m_bPartyMatchRoomStart = true;
	
	//채팅창 초기화
	class'UIAPI_TEXTLISTBOX'.static.Clear( "PartyMatchRoomWnd.PartyRoomChatWindow" );
	
	//Minimize된 상태라면, 아이콘만 깜박이게 한다.
	if (class'UIAPI_WINDOW'.static.IsMinimizedWindow( "PartyMatchRoomWnd" ))
	{
		class'UIAPI_WINDOW'.static.NotifyAlarm( "PartyMatchRoomWnd" );
	}
	else
	{
		//윈도우의 위치를 PartyMatchWnd에 맞춤
		rectWnd = class'UIAPI_WINDOW'.static.GetRect("PartyMatchWnd");
		class'UIAPI_WINDOW'.static.MoveTo("PartyMatchRoomWnd", rectWnd.nX, rectWnd.nY);
		
		//대기자리스트 업데이트
		UpdateWaitListWnd();
		
		class'UIAPI_WINDOW'.static.ShowWindow( "PartyMatchRoomWnd" );
		class'UIAPI_WINDOW'.static.SetFocus( "PartyMatchRoomWnd" );
	}
}

//대기자리스트 업데이트
function UpdateWaitListWnd()
{
	local PartyMatchWnd Script;
	
	Script = PartyMatchWnd( GetScript( "PartyMatchWnd" ) );
	if( Script != None )
	{
		if (Script.IsShowWaitListWnd())
		{
			class'PartyMatchAPI'.static.RequestPartyMatchWaitList(1, MinLevel, MaxLevel, 0);
		}
	}
}

function OnHide()
{
	class'UIAPI_WINDOW'.static.HideWindow( "PartyMatchMakeRoomWnd" );
}

function HandlePartyMatchRoomClose()
{
	local PartyMatchWnd Script;
	local PartyMatchMakeRoomWnd Script2;
	
	m_bPartyMatchRoomStart = false;
	
	class'UIAPI_WINDOW'.static.HideWindow( "PartyMatchRoomWnd" );
	
	//버튼을 눌러서 Request를 했을 때만, PartyMatchWnd의 갱신을 해준다.
	//왜냐하면, 파티매칭중에 리스타트를 해서 EV_PartyMatchRoomClose가 날라왔을 때, 서버접속종료가 되기 때문이다.
	if (m_bRequestExitPartyRoom)
	{
		Script = PartyMatchWnd( GetScript( "PartyMatchWnd" ) );
		if( Script != None )
			Script.OnRefreshBtnClick();	
		
		Script2 = PartyMatchMakeRoomWnd( GetScript( "PartyMatchMakeRoomWnd" ) );
		if( Script2 != None )
			Script2.OnCancelButtonClick();
	}
	m_bRequestExitPartyRoom = false;
}

function UpdateMyMembershipType()
{
	switch( MyMembershipType )
	{
	case 0:
	case 2:
		class'UIAPI_BUTTON'.static.DisableWindow( "PartyMatchRoomWnd.RoomSettingButton" );
		class'UIAPI_BUTTON'.static.DisableWindow( "PartyMatchRoomWnd.BanButton" );
		class'UIAPI_BUTTON'.static.DisableWindow( "PartyMatchRoomWnd.InviteButton" );
		class'UIAPI_BUTTON'.static.EnableWindow( "PartyMatchRoomWnd.ExitButton" );
		break;
	case 1:
		class'UIAPI_BUTTON'.static.EnableWindow( "PartyMatchRoomWnd.RoomSettingButton" );
		class'UIAPI_BUTTON'.static.EnableWindow( "PartyMatchRoomWnd.BanButton" );
		class'UIAPI_BUTTON'.static.EnableWindow( "PartyMatchRoomWnd.InviteButton" );
		class'UIAPI_BUTTON'.static.EnableWindow( "PartyMatchRoomWnd.ExitButton" );
		break;
	}
}

function HandlePartyMatchRoomMember( String param )
{
	local int i;
	local int ClassID;
	local int Level;
	local int MemberID;
	local String MemberName;
	local int ZoneID;
	local int MembershipType;
	local PartyMatchWaitListWnd Script;
	
	Script = PartyMatchWaitListWnd( GetScript( "PartyMatchWaitListWnd" ) );
	
	ParseInt(param, "MyMembershipType", MyMembershipType);
	UpdateMyMembershipType();

	class'UIAPI_LISTCTRL'.static.DeleteAllItem( "PartyMatchRoomWnd.PartyMemberListCtrl" );

	ParseInt(param, "MemberCount", CurPartyMemberCount);
	for( i = 0; i < CurPartyMemberCount; ++i )
	{
		ParseInt(param, "MemberID_" $ i, MemberID);
		ParseString(param, "MemberName_" $ i, MemberName);
		ParseInt(param, "ClassID_" $ i, ClassID);
		ParseInt(param, "Level_" $ i, Level);
		ParseInt(param, "ZoneID_" $ i, ZoneID);
		ParseInt(param, "MembershipType_" $ i, MembershipType);
		
		AddMember( MemberID, MemberName, ClassID, Level, ZoneID, MembershipType );
	}
	
	UpdateData( true );
	
	//Minimize된 상태라면, 아이콘을 깜박이게 한다.
	if (class'UIAPI_WINDOW'.static.IsMinimizedWindow( "PartyMatchRoomWnd" ))
	{
		class'UIAPI_WINDOW'.static.NotifyAlarm( "PartyMatchRoomWnd" );
	}
	
	if (class'UIAPI_WINDOW'.static.IsShowWindow( "PartyMatchRoomWnd.PartyMatchWaitListWnd" ) == true)
	{
		Script.OnRefreshButtonClick();
	}
	
}

function AddMember( int a_MemberID, string a_MemberName, int a_ClassID, int a_Level, int a_ZoneID, int a_MembershipType )
{
	local LVDataRecord Record;

	Record.LVDataList.length = 5;
	Record.LVDataList[0].nReserved1 = a_MemberID;
	Record.LVDataList[0].szData = a_MemberName;
	Record.LVDataList[1].szData = String( a_ClassID );
	Record.LVDataList[1].szTexture = GetClassIconName( a_ClassID );
	Record.LVDataList[1].nTextureWidth = 11;
	Record.LVDataList[1].nTextureHeight = 11;
	Record.LVDataList[2].szData = GetAmbiguousLevelString( a_Level, true );
	Record.LVDataList[3].szData = GetZoneNameWithZoneID( a_ZoneID );

	switch( a_MembershipType )
	{
	case 0:
		Record.LVDataList[4].szData = GetSystemString( 1061 );
		break;
	case 1:
		Record.LVDataList[4].szData = GetSystemString( 1062 );
		break;
	case 2:
		Record.LVDataList[4].szData = GetSystemString( 1063 );
		break;
	}	

	class'UIAPI_LISTCTRL'.static.InsertRecord( "PartyMatchRoomWnd.PartyMemberListCtrl", Record );
}

function RemoveMember( int a_MemberID )
{
	local int RecordCount;
	local int i;
	local LVDataRecord Record;

	RecordCount = class'UIAPI_LISTCTRL'.static.GetRecordCount( "PartyMatchRoomWnd.PartyMemberListCtrl" );
	for( i = 0; i < RecordCount; ++i )
	{
		Record = class'UIAPI_LISTCTRL'.static.GetRecord( "PartyMatchRoomWnd.PartyMemberListCtrl", i );
		if( Record.LVDataList[0].nReserved1 == a_MemberID )
		{
			class'UIAPI_LISTCTRL'.static.DeleteRecord( "PartyMatchRoomWnd.PartyMemberListCtrl", i );
			break;
		}
	}
}

function HandlePartyMatchRoomMemberUpdate( String param )
{
	local int UpdateType;	// 0:Add, 1:Modify, 2:Remove
	local int MemberID;
	local String MemberName;
	local int ClassID;
	local int Level;
	local int ZoneID;
	local int MembershipType;
	local UserInfo PlayerInfo;
	local PartyMatchWaitListWnd Script;
	
	Script = PartyMatchWaitListWnd( GetScript( "PartyMatchWaitListWnd" ) );
	
	ParseInt(param, "UpdateType", UpdateType);
	ParseInt(param, "MemberID", MemberID);
	switch( UpdateType )
	{
	case 0:
		ParseString(param, "MemberName", MemberName);
		ParseInt(param, "ClassID", ClassID);
		ParseInt(param, "Level", Level);
		ParseInt(param, "ZoneID", ZoneID);
		ParseInt(param, "MembershipType", MembershipType);
		AddMember( MemberID, MemberName, ClassID, Level, ZoneID, MembershipType );
		
		CurPartyMemberCount = CurPartyMemberCount + 1;
		break;
	case 1:
		ParseString(param, "MemberName", MemberName);
		ParseInt(param, "ClassID", ClassID);
		ParseInt(param, "Level", Level);
		ParseInt(param, "ZoneID", ZoneID);
		ParseInt(param, "MembershipType", MembershipType);
		
		RemoveMember( MemberID );
		CurPartyMemberCount = CurPartyMemberCount - 1;
		AddMember( MemberID, MemberName, ClassID, Level, ZoneID, MembershipType );
		CurPartyMemberCount = CurPartyMemberCount + 1;
		break;
	case 2:
		RemoveMember( MemberID );
		CurPartyMemberCount = CurPartyMemberCount  - 1;
		break;
	}

	if( GetPlayerInfo( PlayerInfo ) )
	{
		if( PlayerInfo.nID == MemberID )
		{
			MyMembershipType = MembershipType;
			UpdateMyMembershipType();
		}
	}
	
	//Minimize된 상태라면, 아이콘을 깜박이게 한다.
	if (class'UIAPI_WINDOW'.static.IsMinimizedWindow( "PartyMatchRoomWnd" ))
	{
		class'UIAPI_WINDOW'.static.NotifyAlarm( "PartyMatchRoomWnd" );
	}
	UpdateData( true );
	
	if (class'UIAPI_WINDOW'.static.IsShowWindow( "PartyMatchRoomWnd.PartyMatchWaitListWnd" ) == true)
	{
		Script.OnRefreshButtonClick();
	}
	
}

function HandlePartyMatchChatMessage( String param )
{
	local int Tmp;
	local Color ChatColor;
	local String ChatMessage;
	
	ParseString(param, "Msg", ChatMessage);
	ParseInt(param, "ColorR", Tmp);
	ChatColor.R = Tmp;
	ParseInt(param, "ColorG", Tmp);
	ChatColor.G = Tmp;
	ParseInt(param, "ColorB", Tmp);
	ChatColor.B = Tmp;
	ParseInt(param, "ColorA", Tmp);
	ChatColor.A = Tmp;

	class'UIAPI_TEXTLISTBOX'.static.AddString( "PartyMatchRoomWnd.PartyRoomChatWindow", ChatMessage, ChatColor );
	
	//Minimize된 상태라면, 아이콘을 깜박이게 한다.
	if (class'UIAPI_WINDOW'.static.IsMinimizedWindow( "PartyMatchRoomWnd" ))
	{
		class'UIAPI_WINDOW'.static.NotifyAlarm( "PartyMatchRoomWnd" );
	}
}

function UpdateData( bool a_ToControl )
{
	if( a_ToControl )
	{
		class'UIAPI_TEXTBOX'.static.SetText( "PartyMatchRoomWnd.RoomNumber", string( RoomNumber ) );
		class'UIAPI_TEXTBOX'.static.SetText( "PartyMatchRoomWnd.RoomTitle", RoomTitle );
		class'UIAPI_TEXTBOX'.static.SetText( "PartyMatchRoomWnd.Location", GetZoneNameWithZoneID( RoomZoneID ) );
		class'UIAPI_TEXTBOX'.static.SetText( "PartyMatchRoomWnd.PartyMemberCount", string( CurPartyMemberCount ) $ "/" $ MaxPartyMemberCount );
		class'UIAPI_TEXTBOX'.static.SetText( "PartyMatchRoomWnd.LootingMethod", GetLootingMethodName( LootingMethodID ) );
		class'UIAPI_TEXTBOX'.static.SetText( "PartyMatchRoomWnd.LevelLimit", string( MinLevel ) $ "-" $ MaxLevel );
	}
}

function OnClickButton( string a_strButtonName )
{
	switch( a_strButtonName )
	{
	case "WaitListButton":
		OnWaitListButtonClick();
		break;
	case "RoomSettingButton":
		OnRoomSettingButtonClick();
		break;
	case "BanButton":
		OnBanButtonClick();
		break;
	case "InviteButton":
		OnInviteButtonClick();
		break;
	case "ExitButton":
		OnExitButtonClick();
		break;
	}
}

function OnWaitListButtonClick()
{
	local PartyMatchWnd Script;
	
	Script = PartyMatchWnd( GetScript( "PartyMatchWnd" ) );
	if( Script != None )
	{
		Script.ToggleWaitListWnd();
		UpdateWaitListWnd();
	}
}

function OnRoomSettingButtonClick()
{
	local PartyMatchMakeRoomWnd Script;

	Script = PartyMatchMakeRoomWnd( GetScript( "PartyMatchMakeRoomWnd" ) );
	if( Script != None )
	{
		Script.InviteState = 2;
		Script.SetRoomNumber( RoomNumber );
		Script.SetTitle( RoomTitle );
		Script.SetMaxPartyMemberCount( MaxPartyMemberCount );
		Script.SetMinLevel( MinLevel );
		Script.SetMaxLevel( MaxLevel );
	}

	class'UIAPI_WINDOW'.static.ShowWindow( "PartyMatchMakeRoomWnd" );
	class'UIAPI_WINDOW'.static.SetFocus( "PartyMatchMakeRoomWnd" );
}

function OnBanButtonClick()
{
	local LVDataRecord Record;

	Record = class'UIAPI_LISTCTRL'.static.GetSelectedRecord( "PartyMatchRoomWnd.PartyMemberListCtrl" );
	class'PartyMatchAPI'.static.RequestBanFromPartyRoom( Record.LVDataList[0].nReserved1 );
}

function OnInviteButtonClick()
{
	local LVDataRecord Record;

	Record = class'UIAPI_LISTCTRL'.static.GetSelectedRecord( "PartyMatchRoomWnd.PartyMemberListCtrl" );
	RequestInviteParty( Record.LVDataList[0].szData );
}

function OnExitButtonClick()
{
	ExitPartyRoom();
	class'UIAPI_WINDOW'.static.HideWindow( "PartyMatchRoomWnd" );
}

function OnCompleteEditBox( String strID )
{
	local String ChatMsg;

	if( strID == "PartyRoomChatEditBox" )
	{
		ChatMsg = class'UIAPI_EDITBOX'.static.GetString( "PartyMatchRoomWnd.PartyRoomChatEditBox" );
		ProcessPartyMatchChatMessage( ChatMsg );
		class'UIAPI_EDITBOX'.static.SetString( "PartyMatchRoomWnd.PartyRoomChatEditBox", "" );
	}
}

function OnChatMarkedEditBox( string strID )
{
	Local Color ChatColor;
	If ( strID == "PartyRoomChatEditBox")
	{
		 ChatColor.R = 176;
		 ChatColor.G= 155;
		 ChatColor.B = 121;
		 ChatColor.A = 255;
		 Class'UIAPI_TEXTLISTBOX'.static.AddString("PartyMatchRoomWnd.PartyRoomChatWindow", GetSystemMessage(966), ChatColor);
	}
}

