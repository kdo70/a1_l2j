class PartyMatchMakeRoomWnd extends UIScript;

var int InviteState;
var int RoomNumber;
var string InvitedName;

function OnLoad()
{
}

function OnShow()
{
	if (InviteState == 1)
	{
		class'UIAPI_TEXTBOX'.static.SetText( "PartyMatchMakeRoomWnd.TitletoDo",  GetSystemString(1458));
	} 
	else if (InviteState == 2)
	{
		class'UIAPI_TEXTBOX'.static.SetText( "PartyMatchMakeRoomWnd.TitletoDo",  GetSystemString(1460));
	} 
	else
	{
		class'UIAPI_TEXTBOX'.static.SetText( "PartyMatchMakeRoomWnd.TitletoDo",  GetSystemString(1457));
	}
}

function OnClickButton( string a_strButtonName )
{
	switch( a_strButtonName )
	{
	case "OKButton":
		OnOKButtonClick();
		break;
	case "CancelButton":
		OnCancelButtonClick();
		break;
	}
}

function OnOKButtonClick()
{
	local int MaxPartyMemberCount;
	local int MinLevel;
	local int MaxLevel;
	local String RoomTitle;

	MaxPartyMemberCount = class'UIAPI_COMBOBOX'.static.GetSelectedNum( "PartyMatchMakeRoomWnd.MaxPartyMemberCountComboBox" ) + 2;
	MinLevel = Clamp( int( class'UIAPI_EDITBOX'.static.GetString( "PartyMatchMakeRoomWnd.MinLevelEditBox" ) ), 1, MAX_Level );
	MaxLevel = Clamp( int( class'UIAPI_EDITBOX'.static.GetString( "PartyMatchMakeRoomWnd.MaxLevelEditBox" ) ), 1, MAX_Level );
	RoomTitle = class'UIAPI_EDITBOX'.static.GetString( "PartyMatchMakeRoomWnd.TitleEditBox" );

	class'PartyMatchAPI'.static.RequestManagePartyRoom( RoomNumber, MaxPartyMemberCount, MinLevel, MaxLevel, RoomTitle );
	class'UIAPI_WINDOW'.static.HideWindow( "PartyMatchMakeRoomWnd" );
	if (InviteState == 1)
	{
		class'PartyMatchAPI'.static.RequestAskJoinPartyRoom( InvitedName );
		InviteState = 0;
	} 

	

}

function OnCancelButtonClick()
{
	class'UIAPI_WINDOW'.static.HideWindow( "PartyMatchMakeRoomWnd" );
	if (InviteState == 1)
	{
		InviteState = 0;
	} 

}

function SetRoomNumber( int a_RoomNumber )
{
	debug( "PartyMatchMakeRoomWnd.SetRoomNumber " $ a_RoomNumber );
	RoomNumber = a_RoomNumber;
}	

function SetTitle( String a_Title )
{
	debug( "PartyMatchMakeRoomWnd.SetTitle " $ a_Title );
	class'UIAPI_EDITBOX'.static.SetString( "PartyMatchMakeRoomWnd.TitleEditBox", a_Title );
}

function SetMinLevel( int a_MinLevel )
{
	debug( "PartyMatchMakeRoomWnd.SetMinLevel " $ a_MinLevel );
	class'UIAPI_EDITBOX'.static.SetString( "PartyMatchMakeRoomWnd.MinLevelEditBox", string( a_MinLevel ) );
}

function SetMaxLevel( int a_MaxLevel )
{
	debug( "PartyMatchMakeRoomWnd.SetMaxLevel " $ a_MaxLevel );
	class'UIAPI_EDITBOX'.static.SetString( "PartyMatchMakeRoomWnd.MaxLevelEditBox", string( a_MaxLevel ) );
}

function SetMaxPartyMemberCount( int a_MaxPartyMemberCount )
{
	debug( "PartyMatchMakeRoomWnd.SetMaxPartyMemberCount " $ a_MaxPartyMemberCount );
	class'UIAPI_COMBOBOX'.static.SetSelectedNum( "PartyMatchMakeRoomWnd.MaxPartyMemberCountComboBox", a_MaxPartyMemberCount - 2 );
}

