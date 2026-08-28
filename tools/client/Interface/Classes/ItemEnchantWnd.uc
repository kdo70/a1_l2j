class ItemEnchantWnd extends UICommonAPI;

//Handle List
var WindowHandle		Me;
var ItemWindowHandle	ItemWnd;
var WindowHandle		RepeatBtn;

// Which button started the attempt that is now in flight. "Enchant" is a one shot and closes the window,
// "Repeat" keeps it up for the next scroll.
var bool				bCloseOnResult;

// Set while the server's follow-up item list is still on its way after a one shot attempt: that list must
// not reopen the window we have just closed. Dropped by the show it swallows, or by the timer if none comes.
var bool				bIgnoreNextShow;

// Set as soon as an attempt comes back during a repeat run, so the next EV_EnchantShow refreshes the list
// in place instead of rebuilding it. Cleared by that show, or by the timer when the run is over.
var bool				bContinuing;

// The item the last attempt was aimed at. Refreshing a list entry makes the item window forget its
// selection and nothing can put it back, so "Repeat" works from this instead of from the selection.
var int					LastServerID;

// Window title without the level suffix, so the target's real level can be appended to it.
var string				TitleBase;

const TIMER_ENDRUN			= 1;
const TIMER_ENDRUN_DELAY	= 400;

// Overlay drawn on the item being enchanted. Refreshing an entry makes the item window drop its selection
// and nothing can select one back, so the target is marked with a texture of our own instead - the same
// trick stock PetWnd uses to flag equipped pet items.
const TARGET_MARK_TEXTURE	= "l2ui_ch3.PetWnd.petitem_click";

function OnLoad()
{
	RegisterEvent( EV_EnchantShow );
	RegisterEvent( EV_EnchantHide );
	RegisterEvent( EV_EnchantItemList );
	RegisterEvent( EV_EnchantResult );

	//Init Handle
	Me = GetHandle( "ItemEnchantWnd" );
	ItemWnd = ItemWindowHandle( GetHandle( "ItemEnchantWnd.ItemWnd" ) );

	// A Button's caption is a system string id and there is no id for this one, so the button carries a
	// tooltip instead.
	RepeatBtn = GetHandle( "ItemEnchantWnd.btnRepeat" );
	if ( RepeatBtn != None )
		RepeatBtn.SetTooltipText( "Enchant the same item again, keeping this window open" );
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

// Retail behaviour: enchant the selected item once, then the window goes away.
function OnOKClick()
{
	local ItemInfo infItem;

	ItemWnd.GetSelectedItem(infItem);
	if (infItem.ServerID>0)
	{
		LastServerID = infItem.ServerID;
		bCloseOnResult = true;
		class'EnchantAPI'.static.RequestEnchantItem(infItem.ServerID);
	}
}

// Aim at the same item as last time and stay open. The first press has nothing remembered yet, so it takes
// the selection - after that the selection is free to disappear.
function OnRepeatClick()
{
	local ItemInfo infItem;
	local int ServerID;

	// A fresh selection wins, so the player can retarget by clicking another item. There is none after a
	// refresh, and then the marked target carries over.
	ItemWnd.GetSelectedItem(infItem);
	ServerID = infItem.ServerID;
	if ( ServerID <= 0 )
		ServerID = LastServerID;

	if ( ServerID > 0 )
	{
		LastServerID = ServerID;
		bCloseOnResult = false;
		class'EnchantAPI'.static.RequestEnchantItem( ServerID );
	}
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
	bCloseOnResult = false;
	LastServerID = 0;
	Me.HideWindow();
	Clear();
}

function HandleEnchantShow(string param)
{
	local int ClassID;

	Me.KillTimer( TIMER_ENDRUN );

	// The follow-up list of a one shot attempt: the window is closed and stays closed.
	if ( bIgnoreNextShow )
	{
		bIgnoreNextShow = false;
		return;
	}

	// A scroll used from scratch starts on a clean list and forgets the previous target. A continuation
	// keeps both - the entries are refreshed one by one in HandleEnchantItemList.
	if ( !bContinuing )
	{
		Clear();
		LastServerID = 0;
	}

	ParseInt(param, "ClassID", ClassID);
	TitleBase = GetSystemString(1220) $ "(" $ class'UIDATA_ITEM'.static.GetItemName(ClassID) $ ")";
	Me.SetWindowTitle(TitleBase);

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

	// Mark the item being enchanted, and put its level in the title as well. The mark is what keeps the
	// target visible: every entry is refreshed below so the levels stay right, and refreshing is exactly
	// what wipes the window's own selection.
	if ( LastServerID > 0 && infItem.ServerID == LastServerID )
	{
		infItem.ForeTexture = TARGET_MARK_TEXTURE;

		if ( infItem.Enchanted > 0 )
			Me.SetWindowTitle( TitleBase $ " " $ infItem.Name $ " +" $ string(infItem.Enchanted) );
		else
			Me.SetWindowTitle( TitleBase $ " " $ infItem.Name );
	}

	index = ItemWnd.FindItemWithServerID( infItem.ServerID );
	if ( index >= 0 )
		ItemWnd.SetItem( index, infItem );
	else
		ItemWnd.AddItem( infItem );
}

function HandleEnchantResult(string param)
{
	if ( bCloseOnResult )
	{
		// One shot. Hand the scroll the server lined up for a follow-up back to it, ignore the item list
		// that is already on its way, and close. The timer is the fallback for when no list arrives at all -
		// the item broke, or the scrolls ran out - so the ignore flag never survives into the next window.
		bIgnoreNextShow = true;
		class'EnchantAPI'.static.RequestEnchantItem(-1);
		EndRun();
		Me.SetTimer( TIMER_ENDRUN, TIMER_ENDRUN_DELAY );
		return;
	}

	// Retail tears the window down right here. Instead we wait: the server states whether the run goes on
	// by sending another "choose item" order, which lands well within the delay below. If none comes - the
	// item broke, the scrolls ran out, the item hit the enchant limit - the timer closes the window.
	bContinuing = true;
	Me.SetTimer( TIMER_ENDRUN, TIMER_ENDRUN_DELAY );
}

function OnTimer(int TimerID)
{
	if ( TimerID == TIMER_ENDRUN )
	{
		bIgnoreNextShow = false;
		EndRun();
	}
}
