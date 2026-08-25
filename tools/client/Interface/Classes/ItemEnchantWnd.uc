class ItemEnchantWnd extends UICommonAPI;

//Handle List
var WindowHandle		Me;
var ItemWindowHandle	ItemWnd;
var WindowHandle		RepeatBtn;

// Set as soon as an enchant attempt comes back. While it is set, the next EV_EnchantShow is the server
// carrying the same enchant run on with another scroll, so the item list is refreshed in place instead of
// being rebuilt. Cleared by that show, or by the timer below when it never arrives - which is how the
// window closes on its own once the run is over.
var bool				bContinuing;

// The item the last attempt was aimed at. Refreshing a list entry makes the item window forget its
// selection and nothing can put it back, so btnRepeat works from this instead of from the selection.
var int					LastServerID;

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

	// A Button's caption is a system string id, and there is no id for this one, so the button carries a
	// tooltip instead.
	RepeatBtn = GetHandle( "ItemEnchantWnd.btnRepeat" );
	if ( RepeatBtn != None )
		RepeatBtn.SetTooltipText( "Enchant the same item again" );
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
	case "btnRepeat":
		OnRepeatClick();
		break;
	case "btnCancel":
		OnCancelClick();
		break;
	}
}

// Retail behaviour: enchant whatever the player has selected.
function OnOKClick()
{
	local ItemInfo infItem;

	ItemWnd.GetSelectedItem(infItem);
	if (infItem.ServerID>0)
	{
		LastServerID = infItem.ServerID;
		class'EnchantAPI'.static.RequestEnchantItem(infItem.ServerID);
	}
}

// Aim at the same item as last time, no selection needed.
function OnRepeatClick()
{
	if ( LastServerID > 0 )
		class'EnchantAPI'.static.RequestEnchantItem( LastServerID );
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
	LastServerID = 0;
	Me.HideWindow();
	Clear();
}

function HandleEnchantShow(string param)
{
	local int ClassID;

	Me.KillTimer( TIMER_ENDRUN );

	// A scroll used from scratch starts on a clean list and forgets the previous target. A continuation
	// keeps both - the entries are refreshed one by one in HandleEnchantItemList.
	if ( !bContinuing )
	{
		Clear();
		LastServerID = 0;
	}

	ParseInt(param, "ClassID", ClassID);
	Me.SetWindowTitle(GetSystemString(1220) $ "(" $ class'UIDATA_ITEM'.static.GetItemName(ClassID) $ ")");

	// Showing and focusing a window that is already up buys nothing and can reset its controls, so only do
	// it when the window is actually coming into view.
	if ( !bContinuing )
	{
		Me.ShowWindow();
		Me.SetFocus();
	}

	bContinuing = false;
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

	// Refresh in place so enchant levels stay correct. This costs the selection, which is exactly what
	// btnRepeat exists to make unnecessary.
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
