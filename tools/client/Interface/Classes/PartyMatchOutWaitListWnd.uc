class PartyMatchOutWaitListWnd extends PartyMatchWndCommon;
var int entire_page;
var int current_page;
var int minLevel;
var int maxLevel;

function OnLoad()
{
	RegisterEvent( EV_PartyMatchWaitListStart );
	RegisterEvent( EV_PartyMatchWaitList );
	entire_page = 1;
	current_page = 1;
	class'UIAPI_EDITBOX'.static.SetString( "PartyMatchOutWaitListWnd.MinLevel", "1");
	class'UIAPI_EDITBOX'.static.SetString( "PartyMatchOutWaitListWnd.MaxLevel", "80");
}

function OnShow()
{
	current_page = 1;
}

function OnEvent( int a_EventID, String param )
{
	switch( a_EventID )
	{
	case EV_PartyMatchWaitListStart:
		HandlePartyMatchWaitListStart( param );
		break;
	case EV_PartyMatchWaitList:
		HandlePartyMatchWaitList( param );
		break;
	}
}

function HandlePartyMatchWaitListStart( String param )
{
	local int AllCount;
	local int Count;
	local string totalPages;
	local string currentPage;
	local string page_info;
	
	ParseInt(param, "AllCount", AllCount);
	ParseInt(param, "Count", Count);
	
	totalPages = string((AllCount/64)+1);
	entire_page = (AllCount/64)+1;
	currentPage = string(current_page);
	page_info = currentPage $ "/" $ totalPages;
	
	class'UIAPI_TEXTBOX'.static.SetText( "PartyMatchOutWaitListWnd.MemberCount", page_info );	
	class'UIAPI_LISTCTRL'.static.DeleteAllItem( "PartyMatchOutWaitListWnd.WaitListCtrl" );
	CheckButtonAlive();
}

function HandlePartyMatchWaitList( String param )
{
	local String Name;
	local int ClassID;
	local int Level;
	local LVDataRecord Record;
	
	ParseString(param, "Name", Name);
	ParseInt(param, "ClassID", ClassID);
	ParseInt(param, "Level", Level);

	Record.LVDataList.length = 3;
	Record.LVDataList[0].szData = Name;
	Record.LVDataList[1].szTexture = GetClassIconName( ClassID );
	Record.LVDataList[1].nTextureWidth = 11;
	Record.LVDataList[1].nTextureHeight = 11;
	Record.LVDataList[1].szData = String( ClassID );
	Record.LVDataList[2].szData = GetAmbiguousLevelString( Level, false );
	Record.nReserved1 = Level;
	class'UIAPI_LISTCTRL'.static.InsertRecord( "PartyMatchOutWaitListWnd.WaitListCtrl", Record );
}

function OnClickButton( string a_strButtonName )
{
	switch( a_strButtonName )
	{
	case "RefreshButton":
		OnRefreshButtonClick();
		break;
	case "WhisperButton":
		OnWhisperButtonClick();
		break;
	case "PartyInviteButton":
		OnInviteButtonClick();
		break;
	case "CloseButton":
		OnCloseButtonClick();
		break;
	case "btn_Search":
		OnSearchBtnClick();
		break;
	case "prev_btn":
		OnPrevbuttonClick();
		break;
	case "next_btn":
		OnNextbuttonClick();
		break;
	}
}

function OnRefreshButtonClick()
{
	MinLevel = int(class'UIAPI_EDITBOX'.static.GetString( "PartyMatchOutWaitListWnd.MinLevel"));
	MaxLevel = int(class'UIAPI_EDITBOX'.static.GetString( "PartyMatchOutWaitListWnd.MaxLevel"));
	class'PartyMatchAPI'.static.RequestPartyMatchWaitList(current_page, MinLevel, MaxLevel, 1);
}
 
function OnNextbuttonClick()
{
	current_page = current_page +1;
	class'PartyMatchAPI'.static.RequestPartyMatchWaitList(current_page, minLevel, maxLevel, 1);
	
}

function OnPrevbuttonClick()
{
	current_page = current_page -1;
	class'PartyMatchAPI'.static.RequestPartyMatchWaitList(current_page, minLevel, maxLevel, 1);
}

function OnSearchBtnClick()
{
	MinLevel = int(class'UIAPI_EDITBOX'.static.GetString( "PartyMatchOutWaitListWnd.MinLevel"));
	MaxLevel = int(class'UIAPI_EDITBOX'.static.GetString( "PartyMatchOutWaitListWnd.MaxLevel"));
	class'PartyMatchAPI'.static.RequestPartyMatchWaitList(1, MinLevel, MaxLevel, 1);
}

function OnWhisperButtonClick()
{
	local LVDataRecord Record;
	local string szData1;
	
	Record = class'UIAPI_LISTCTRL'.static.GetSelectedRecord( "PartyMatchOutWaitListWnd.WaitListCtrl" );
	szData1 = Record.LVDataList[0].szData;
	if (szData1 != "")
	{
	SetChatMessage( "\"" $ szData1 $ " " );
	}
}

function OnInviteButtonClick()
{
	local LVDataRecord Record;

	Record = class'UIAPI_LISTCTRL'.static.GetSelectedRecord( "PartyMatchOutWaitListWnd.WaitListCtrl" );
	//RequestInviteParty( Record.LVDataList[0].szData );
	MakeRoomFirst( Record.nReserved1, Record.LVDataList[0].szData );
}

function OnCloseButtonClick()
{
	local PartyMatchWnd Script;
	
	Script = PartyMatchWnd( GetScript( "PartyMatchWnd" ) );
	if( Script != None )
	{
		Script.SetWaitListWnd(false);
		Script.ShowHideWaitListWnd();
	}
}

function OnDBClickListCtrlRecord( String a_ListCtrlName )
{
	local LVDataRecord Record;

	if( a_ListCtrlName != "WaitListCtrl" )
		return;

	Record = class'UIAPI_LISTCTRL'.static.GetSelectedRecord( "PartyMatchOutWaitListWnd.WaitListCtrl" );
	SetChatMessage( "\"" $ Record.LVDataList[0].szData $ " " );
}


function MakeRoomFirst(int TargetLevel, string InviteTargetName)
{
	local PartyMatchMakeRoomWnd Script;
	local UserInfo PlayerInfo;
	local int LevelMin;
	local int LevelMax;

	Script = PartyMatchMakeRoomWnd( GetScript( "PartyMatchMakeRoomWnd" ) );
	if( Script != None )
	{
		Script.InviteState = 1;
		Script.InvitedName = InviteTargetName;
		Script.SetRoomNumber( 0 );
		Script.SetTitle( GetSystemMessage( 1398 ) );
		Script.SetMaxPartyMemberCount( 12 );

		if( GetPlayerInfo( PlayerInfo ) )
		{
			if (TargetLevel < PlayerInfo.nLevel)
			{
				LevelMin = TargetLevel;
				LevelMax = PlayerInfo.nLevel;
			}
			else 
			{
				LevelMin = PlayerInfo.nLevel;
				LevelMax = TargetLevel;
			}

			
			if( LevelMin - 5 > 0 )
				Script.SetMinLevel( LevelMin - 5 );
			else
				Script.SetMinLevel( 1 );

			if( LevelMax + 5 <= MAX_Level )
				Script.SetMaxLevel( LevelMax + 5 );
			else
				Script.SetMaxLevel( Max_Level );
		}		
	}

	class'UIAPI_WINDOW'.static.ShowWindow( "PartyMatchMakeRoomWnd" );
	class'UIAPI_WINDOW'.static.SetFocus( "PartyMatchMakeRoomWnd" );
}


function CheckButtonAlive()
{
	class'UIAPI_WINDOW'.static.EnableWindow("PartyMatchOutWaitListWnd.prev_btn");
	class'UIAPI_WINDOW'.static.EnableWindow("PartyMatchOutWaitListWnd.next_btn");
	if (current_page == 1)
	{
	class'UIAPI_WINDOW'.static.DisableWindow("PartyMatchOutWaitListWnd.prev_btn");
	}
	if (current_page == entire_page)
	{
	class'UIAPI_WINDOW'.static.DisableWindow("PartyMatchOutWaitListWnd.next_btn");
	}
}
