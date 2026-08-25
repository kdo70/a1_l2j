class SelectDeliverWnd extends UICommonAPI;

function OnLoad()
{
	registerEvent( EV_SelectDeliverClear );
	registerEvent( EV_SelectDeliverAddName );
}

function OnEvent( int Event_ID, string param )
{
	switch( Event_ID )
	{
	case EV_SelectDeliverClear:
		class'UIAPI_COMBOBOX'.static.Clear( "SelectDeliverWnd.SelectDeliverCombo" );
		ShowWindow( "SelectDeliverWnd" );
		class'UIAPI_WINDOW'.static.SetFocus("SelectDeliverWnd");
		break;
	case EV_SelectDeliverAddName:
		HandleAddName( param );
		break;
	default:
		break;
	}
}

function HandleAddName( string param )
{
	local string name;
	local int id;

	ParseString(param, "name", name);
	ParseInt(param,"id", id);

	class'UIAPI_COMBOBOX'.static.AddStringWithReserved( "SelectDeliverWnd.SelectDeliverCombo", name, id );
}

function OnClickButton( string ControlName )
{
	if( ControlName == "OKButton" )
	{
		HandleOKButtonClick();
	}
	else if( ControlName == "CancelButton" )
	{
		HideWindow("SelectDeliverWnd");
	}
}

function HandleOKButtonClick()
{
	local int selected;
	local int reservedID;
	selected = class'UIAPI_COMBOBOX'.static.GetSelectedNum( "SelectDeliverWnd.SelectDeliverCombo" );
	if( selected >= 0 )
	{
		reservedID = class'UIAPI_COMBOBOX'.static.GetReserved( "SelectDeliverWnd.SelectDeliverCombo", selected );
		RequestPackageSendableItemList( reservedID );
	}
	HideWindow("SelectDeliverWnd");
}
