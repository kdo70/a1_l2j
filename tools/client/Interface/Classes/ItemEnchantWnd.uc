class ItemEnchantWnd extends UICommonAPI;

//Handle List
var WindowHandle		Me;
var ItemWindowHandle	ItemWnd;

// Set as soon as an enchant attempt comes back. While it is set, the next EV_EnchantShow is the server
// carrying the same enchant run on with another scroll, so the item list - and with it whatever the player
// had selected - has to survive. Cleared as soon as that show arrives, or by the timer below when it never
// does, which is how the window closes on its own once the run is over.
var bool				bContinuing;

const TIMER_ENDRUN			= 1;
const TIMER_ENDRUN_DELAY	= 400;

function OnLoad()
{
	RegisterEvent( EV_EnchantShow );
	RegisterEvent( EV_EnchantHide );
	RegisterEvent( EV_EnchantItemList );
	RegisterEvent( EV_EnchantResult );

	//Init Handle
	Me = GetHandle( "ItemEnchantWnd" );
	ItemWnd = ItemWindowHandle( GetHandle( "ItemEnchantWnd.ItemWnd" ) );
}

function OnEvent(int Event_ID, string param)
{
	if (Event_ID == EV_EnchantShow)
	{
		HandleEnchantShow(param);
	}
	else if (Event_ID == EV_EnchantHide)
	{
		HandleEnchantHide();
	}
	else if (Event_ID == EV_EnchantItemList)
	{
		HandleEnchantItemList(param);
	}
	else if (Event_ID == EV_EnchantResult)
	{
		HandleEnchantResult(param);
	}
}

function OnClickButton( string strID )
{
	switch( strID )
	{
	case "btnOK":
		OnOKClick();
		break;
	case "btnCancel":
		OnCancelClick();
		break;
	}
}

function OnOKClick()
{
	local ItemInfo infItem;

	ItemWnd.GetSelectedItem(infItem);
	if (infItem.ServerID>0)
		class'EnchantAPI'.static.RequestEnchantItem(infItem.ServerID);
}

function OnCancelClick()
{
	class'EnchantAPI'.static.RequestEnchantItem(-1);
	EndRun();
}

function Clear()
{
	ItemWnd.Clear();
}

// Closes the window and forgets everything the enchant run was holding on to.
function EndRun()
{
	Me.KillTimer( TIMER_ENDRUN );
	bContinuing = false;
	Me.HideWindow();
	Clear();
}

function HandleEnchantShow(string param)
{
	local int ClassID;

	Me.KillTimer( TIMER_ENDRUN );

	// A scroll used from scratch starts on a clean list. A continuation keeps the list, so that the item
	// the player picked stays selected - the entries are refreshed one by one in HandleEnchantItemList.
	if ( !bContinuing )
		Clear();
	bContinuing = false;

	ParseInt(param, "ClassID", ClassID);
	Me.SetWindowTitle(GetSystemString(1220) $ "(" $ class'UIDATA_ITEM'.static.GetItemName(ClassID) $ ")");
	Me.ShowWindow();
	Me.SetFocus();
}

function HandleEnchantHide()
{
	EndRun();
}

function HandleEnchantItemList(string param)
{
	local ItemInfo infItem;
	local int index;

	ParamToItemInfo(param, infItem);

	// Replace the entry in place when the item is already listed. Rebuilding the list would show the right
	// enchant level too, but it also drops the selection, and there is no way to select an item back.
	index = ItemWnd.FindItemWithServerID( infItem.ServerID );
	if ( index >= 0 )
		ItemWnd.SetItem( index, infItem );
	else
		ItemWnd.AddItem( infItem );
}

function HandleEnchantResult(string param)
{
	// Retail tears the window down right here. Instead we wait: the server states whether the run goes on
	// by sending another "choose item" order, which lands well within the delay below. If none comes - the
	// item broke, the scrolls ran out, the item hit the enchant limit - the timer closes the window.
	bContinuing = true;
	Me.SetTimer( TIMER_ENDRUN, TIMER_ENDRUN_DELAY );
}

function OnTimer(int TimerID)
{
	if ( TimerID == TIMER_ENDRUN )
		EndRun();
}
