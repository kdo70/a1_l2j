class GMWarehouseWnd extends WarehouseWnd;

var bool bShow;	// GM창에서 버튼을 한번 더 누르면 사라지게 하기 위한 변수

function OnLoad()
{
	RegisterEvent( EV_GMObservingWarehouseItemListStart );
	RegisterEvent( EV_GMObservingWarehouseItemList );

	InitHandle();
	
	bShow = false;	//초기화
}

function OnShow()
{
	class'UIAPI_WINDOW'.static.HideWindow( "GMWarehouseWnd.OKButton" );
	class'UIAPI_WINDOW'.static.HideWindow( "GMWarehouseWnd.CancelButton" );
}

function ShowWarehouse( String a_Param )
{
	if( a_Param == "" )
		return;

	if(bShow)	//창이 떠있으면 지워준다.
	{
		Clear();
		m_hOwnerWnd.HideWindow();
		bShow = false;
	}
	else
	{
		debug("GMwareShow param :" $ a_Param);
		class'GMAPI'.static.RequestGMCommand( GMCOMMAND_WarehouseInfo, a_Param );	// 061117 동작하지 않는것같아요 by innowind
		bShow = true;
	}
}

// Nullify Super class implementation
function OnClickButton( string strID )
{
}

function OnEvent( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	case EV_GMObservingWarehouseItemListStart:
		HandleGMObservingWarehouseItemListStart( a_Param );
		break;
	case EV_GMObservingWarehouseItemList:
		HandleGMObservingWarehouseItemList( a_Param );
		break;
	}
}

function HandleGMObservingWarehouseItemListStart( String a_Param )
{
	HandleOpenWindow( a_Param );
}

function HandleGMObservingWarehouseItemList( String a_Param )
{
	HandleAddItem( a_Param );
}

// Disabling inhereted function - NeverDie
function MoveItemTopToBottom( int index, bool bAllItem )
{
}

// Disabling inhereted function - NeverDie
function MoveItemBottomToTop( int index, bool bAllItem )
{
}

