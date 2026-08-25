class PartyMatchWaitListWnd extends PartyMatchWndCommon;
var int entire_page;
var int current_page;
var int RoomNumber;
var int MaxPartyMemberCount;
var int MinLevel;
var int MaxLevel;
var int LootingMethodID;
var int RoomZoneID;

function OnLoad()
{
	RegisterEvent( EV_PartyMatchRoomStart );
	RegisterEvent( EV_PartyMatchWaitListStart );
	RegisterEvent( EV_PartyMatchWaitList );
	entire_page = 1;
	current_page = 1;
}

function OnShow()
{
	current_page = 1;
}

function OnEvent( int a_EventID, String param )
{
	switch( a_EventID )
	{
	case EV_PartyMatchRoomStart:
		HandlePartyMatchRoomStart( param );
		break;
	case EV_PartyMatchWaitListStart:
		HandlePartyMatchWaitListStart( param );
		break;
	case EV_PartyMatchWaitList:
		HandlePartyMatchWaitList( param );
		break;
	}
}

function HandlePartyMatchRoomStart( String param )
{
	ParseInt(param, "RoomNum", RoomNumber);
	ParseInt(param, "MaxMember", MaxPartyMemberCount);
	ParseInt(param, "MinLevel", MinLevel);
	ParseInt(param, "MaxLevel", MaxLevel);
	ParseInt(param, "LootingMethodID", LootingMethodID);
	ParseInt(param, "ZoneID", RoomZoneID);
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

	class'UIAPI_TEXTBOX'.static.SetText( "PartyMatchWaitListWnd.MemberCount", page_info );	
	class'UIAPI_LISTCTRL'.static.DeleteAllItem( "PartyMatchWaitListWnd.WaitListCtrl" );
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

	class'UIAPI_LISTCTRL'.static.InsertRecord( "PartyMatchWaitListWnd.WaitListCtrl", Record );
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
	class'PartyMatchAPI'.static.RequestPartyMatchWaitList(current_page, MinLevel, MaxLevel, 0);
}

function OnNextbuttonClick()
{
	current_page = current_page +1;
	class'PartyMatchAPI'.static.RequestPartyMatchWaitList(current_page, MinLevel, MaxLevel, 0);
	
}

function OnPrevbuttonClick()
{
	current_page = current_page -1;
	class'PartyMatchAPI'.static.RequestPartyMatchWaitList(current_page, MinLevel, MaxLevel, 0);
}

function OnWhisperButtonClick()
{
	local LVDataRecord Record;
	local string szData1;
	
	Record = class'UIAPI_LISTCTRL'.static.GetSelectedRecord( "PartyMatchWaitListWnd.WaitListCtrl" );
	szData1 = Record.LVDataList[0].szData;
	if (szData1 != "")
	{
		SetChatMessage( "\"" $ szData1 $ " " );
	}
}


function OnInviteButtonClick()
{
	local LVDataRecord Record;

	Record = class'UIAPI_LISTCTRL'.static.GetSelectedRecord( "PartyMatchWaitListWnd.WaitListCtrl" );
	class'PartyMatchAPI'.static.RequestAskJoinPartyRoom( Record.LVDataList[0].szData );
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

	Record = class'UIAPI_LISTCTRL'.static.GetSelectedRecord( "PartyMatchWaitListWnd.WaitListCtrl" );
	SetChatMessage( "\"" $ Record.LVDataList[0].szData $ " " );
}

function CheckButtonAlive()
{
	class'UIAPI_WINDOW'.static.EnableWindow("PartyMatchWaitListWnd.prev_btn");
	class'UIAPI_WINDOW'.static.EnableWindow("PartyMatchWaitListWnd.next_btn");
	if (current_page == 1)
	{
		class'UIAPI_WINDOW'.static.DisableWindow("PartyMatchWaitListWnd.prev_btn");
	}
	if (current_page == entire_page)
	{
		class'UIAPI_WINDOW'.static.DisableWindow("PartyMatchWaitListWnd.next_btn");
	}
}
