class WarehouseWnd extends UICommonAPI;

const KEEPING_PRICE = 30;			// 한칸 당 보관료

const DEFAULT_MAX_COUNT = 200;		// 개인 창고를 제외한 다른 창고들의 최대 개수

const DIALOG_TOP_TO_BOTTOM = 111;
const DIALOG_BOTTOM_TO_TOP = 222;

enum WarehouseCategory
{
	WC_None,			// dummy
	WC_Private,
	WC_Clan,
	WC_Castle,
	WC_Etc,
};

enum WarehouseType
{
	WT_Deposit,
	WT_Withdraw,
};

var WarehouseCategory	m_category;
var WarehouseType		m_type;
var int					m_maxPrivateCount;
var String				m_WindowName;

var ItemWindowHandle	m_topList;
var ItemWindowHandle	m_bottomList;

function OnLoad()
{
	registerEvent( EV_WarehouseOpenWindow );
	registerEvent( EV_WarehouseAddItem );
	registerEvent( EV_SetMaxCount );
	registerEvent( EV_DialogOK );

	InitHandle();
}

function InitHandle()
{
	m_topList = ItemWindowHandle( GetHandle( "TopList" ) );
	m_bottomList = ItemWindowHandle( GetHandle( "BottomList" ) );
}

function Clear()
{
	m_type = WT_Deposit;
	m_category = WC_None;

	m_topList.Clear();
	m_bottomList.Clear();

	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName $ ".PriceText", "0");
	class'UIAPI_TEXTBOX'.static.SetTooltipString(m_WindowName $ ".PriceText", "");

	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName $ ".AdenaText", "0");
	class'UIAPI_TEXTBOX'.static.SetTooltipString(m_WindowName $ ".AdenaText", "");

	class'UIAPI_INVENWEIGHT'.static.ZeroWeight("WarehouseWnd.InvenWeight");
}

function OnEvent(int Event_ID,string param)
{
	switch( Event_ID )
	{
	case EV_WarehouseOpenWindow:
		HandleOpenWindow(param);
		break;
	case EV_WarehouseAddItem:
		HandleAddItem(param);
		break;
	case EV_SetMaxCount:
		HandleSetMaxCount(param);
		break;
	case EV_DialogOK:
		HandleDialogOK();
		break;
	default:
		break;
	}
}

function OnClickButton( string ControlName )
{
	local int index;
	if( ControlName == "UpButton" )
	{
		index = m_bottomList.GetSelectedNum();
		MoveItemBottomToTop( index, false );
	}
	else if( ControlName == "DownButton" )
	{
		index = m_topList.GetSelectedNum();
		MoveItemTopToBottom( index, false );
	}
	else if( ControlName == "OKButton" )
	{
		HandleOKButton();
	}
	else if( ControlName == "CancelButton" )
	{
		Clear();
		HideWindow(m_WindowName);
	}
}

function OnDBClickItem( string ControlName, int index )
{
	if(ControlName == "TopList")
	{
		MoveItemTopToBottom( index, false );
	}
	else if(ControlName == "BottomList")
	{
		MoveItemBottomToTop( index, false );
	}

}

// 아이템을 클릭하였을 경우 (더블클릭 아님)
function OnClickItem( string ControlName, int index )
{
	local WindowHandle m_dialogWnd;
	m_dialogWnd = GetHandle( "DialogBox" );		
	if(ControlName == "TopList")
	{
		if( DialogIsMine() && m_dialogWnd.IsShowWindow())
		{
			DialogHide();
			m_dialogWnd.HideWindow();
		}		
	}
}

function OnDropItem( string strID, ItemInfo info, int x, int y)
{
	local int index;
	//debug("OnDropItem strID " $ strID $ ", src=" $ info.DragSrcName);
	if( strID == "TopList" && info.DragSrcName == "BottomList" )
	{
		index = m_bottomList.FindItemWithClassID( info.ClassID );
		if( index >= 0 )
			MoveItemBottomToTop( index, info.AllItemCount > 0 );
	}
	else if( strID == "BottomList" && info.DragSrcName == "TopList" )
	{
		index = m_topList.FindItemWithClassID( info.ClassID );
		if( index >= 0 )
			MoveItemTopToBottom( index, info.AllItemCount > 0 );
	}
}

function MoveItemTopToBottom( int index, bool bAllItem )
{
	local ItemInfo topInfo, bottomInfo;
	local int bottomIndex;
	if( m_topList.GetItem( index, topInfo) )
	{
		// 1일경우 수량을 입력하는 다이얼로그는 출력하지 않는다. 
		if( !bAllItem && IsStackableItem( topInfo.ConsumeType ) && (topInfo.ItemNum>1) )		// stackable?
		{
			DialogSetID( DIALOG_TOP_TO_BOTTOM );
			DialogSetReservedInt( topInfo.ClassID );
			DialogSetParamInt( topInfo.ItemNum );
			DialogSetDefaultOK();	
			DialogShow( DIALOG_NumberPad, MakeFullSystemMsg( GetSystemMessage(72), topInfo.Name, "" ) );
		}
		else
		{
			//topInfo.ItemNum k= 1;
			bottomIndex = m_bottomList.FindItemWithClassID( topInfo.ClassID );
			if( bottomIndex != -1 && IsStackableItem( topInfo.ConsumeType ) )				// 숫자만 합치기
			{
				m_bottomList.GetItem( bottomIndex, bottomInfo );
				bottomInfo.ItemNum += topInfo.ItemNum;
				m_bottomList.SetItem( bottomIndex, bottomInfo );
			}
			else
			{
				m_bottomList.AddItem( topInfo );
			}
			m_topList.DeleteItem( index );		// 물건을 팔 경우 자신의 인벤토리 목록에서 아이템을 제거

			if( m_type == WT_Withdraw )
				class'UIAPI_INVENWEIGHT'.static.AddWeight( "WarehouseWnd.InvenWeight", topInfo.ItemNum * topInfo.Weight );		// 무게 바에 더해주기
			AdjustPrice();
			AdjustCount();
		}
	}
}

function MoveItemBottomToTop( int index, bool bAllItem )
{
	local ItemInfo bottomInfo, topInfo;
	local int	topIndex;
	if( m_bottomList.GetItem(index, bottomInfo) )
	{
		if( !bAllItem && IsStackableItem( bottomInfo.ConsumeType ) && (bottomInfo.ItemNum > 1) )		// 개수 물어보기
		{
			DialogSetID( DIALOG_BOTTOM_TO_TOP );
			DialogSetReservedInt( bottomInfo.ClassID );
			DialogSetParamInt( bottomInfo.ItemNum );
			DialogSetDefaultOK();	
			DialogShow( DIALOG_NumberPad, MakeFullSystemMsg( GetSystemMessage(72), bottomInfo.Name, "" ) );
		}
		else
		{
			topIndex = m_topList.FindItemWithClassID( bottomInfo.ClassID );
			if( topIndex != -1 && IsStackableItem( bottomInfo.ConsumeType ) )				// 숫자만 합치기
			{
				m_topList.GetItem( topIndex, topInfo );
				topInfo.ItemNum += bottomInfo.ItemNum;
				m_topList.SetItem( topIndex, topInfo );
			}
			else
			{
				m_topList.AddItem( bottomInfo );
			}
			m_bottomList.DeleteItem( index );

			if( m_type == WT_Withdraw )
				class'UIAPI_INVENWEIGHT'.static.ReduceWeight( "WarehouseWnd.InvenWeight", bottomInfo.ItemNum * bottomInfo.Weight );		// 무게 바에서 빼 주시

			AdjustPrice();
			AdjustCount();
		}
	}
}

function HandleDialogOK()
{
	local int id, num, classID, index, topIndex;
	local ItemInfo info, topInfo;

	if( DialogIsMine() )
	{
		id = DialogGetID();
		num = int( DialogGetString() );
		classID = DialogGetReservedInt();
		if( id == DIALOG_TOP_TO_BOTTOM && num > 0 )
		{
			topIndex = m_topList.FindItemWithClassID( classID );
			if( topIndex >= 0 )
			{
				m_topList.GetItem( topIndex, topInfo );
				index = m_bottomList.FindItemWithClassID( classID );
				if( index >= 0 )
				{
					m_bottomList.GetItem( index, info );
					info.ItemNum += num;
					m_bottomList.SetItem( index, info );
				}
				else
				{
					info = topInfo;
					info.ItemNum = num;
					info.bShowCount = false;
					m_bottomList.AddItem( info );
				}
	
				if( m_type == WT_Withdraw )
					class'UIAPI_INVENWEIGHT'.static.AddWeight( "WarehouseWnd.InvenWeight", info.ItemNum * info.Weight );		// 무게 바에 더해주기

				topInfo.ItemNum -= num;
				if( topInfo.ItemNum <= 0 )
					m_topList.DeleteItem( topIndex );
				else
					m_topList.SetItem( topIndex, topInfo );
			}
		}
		else if( id == DIALOG_BOTTOM_TO_TOP && num > 0 )
		{
			index = m_bottomList.FindItemWithClassID( classID );
			if( index >= 0 )
			{
				m_bottomList.GetItem( index, info );
				info.ItemNum -= num;
				if( info.ItemNum > 0 )
					m_bottomList.SetItem( index, info );
				else 
					m_bottomList.DeleteItem( index );

				topIndex = m_topList.FindItemWithClassID( classID );
				if( topIndex >=0 && IsStackableItem( info.ConsumeType ) )
				{
					m_topList.GetItem( topIndex, topInfo );
					topInfo.ItemNum += num;
					m_topList.SetItem( topIndex, topInfo );
				}
				else
				{
					info.ItemNum = num;
					m_topList.AddItem( info );
				}

				if( m_type == WT_Withdraw )
					class'UIAPI_INVENWEIGHT'.static.ReduceWeight( "WarehouseWnd.InvenWeight", info.ItemNum * info.Weight );		// 무게 바에서 빼 주기
			}
		}
		AdjustPrice();
		AdjustCount();
	}
}

function HandleOpenWindow( string param )
{
	local string type;
	local int adena, tmpInt;
	local string adenaString;
	local WindowHandle m_inventoryWnd;
	
	m_inventoryWnd = GetHandle( "InventoryWnd" );	//인벤토리의 윈도우 핸들을 얻어온다.

	Clear();

	ParseString( param, "type", type );
	ParseInt( param, "category", tmpInt ); 
	m_category = WarehouseCategory( tmpInt );
	ParseInt( param, "adena", adena );

	switch( m_category )
	{
	case WC_Private:
		class'UIAPI_WINDOW'.static.SetWindowTitle(m_WindowName, 1216);
		break;
	case WC_Clan:
		class'UIAPI_WINDOW'.static.SetWindowTitle(m_WindowName, 1217);
		break;
	case WC_Castle:
		class'UIAPI_WINDOW'.static.SetWindowTitle(m_WindowName, 1218);
		break;
	case WC_Etc:
		class'UIAPI_WINDOW'.static.SetWindowTitle(m_WindowName, 131);
		break;
	default:
		break;
	};
	if( type == "deposit" )
		m_type = WT_Deposit;
	else if( type == "withdraw" )
		m_type = WT_Withdraw;;

	adenaString = MakeCostString( string(adena) );
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName $ ".AdenaText", adenaString);
	class'UIAPI_TEXTBOX'.static.SetTooltipString(m_WindowName $ ".AdenaText", ConvertNumToText(string(adena)) );

	if( m_inventoryWnd.IsShowWindow() )			//인벤토리 창이 열려있으면 닫아준다. 
	{
		m_inventoryWnd.HideWindow();
	}
	ShowWindow( m_WindowName );
	class'UIAPI_WINDOW'.static.SetFocus(m_WindowName);

	if( m_type == WT_Deposit )
	{
		class'UIAPI_TEXTBOX'.static.SetText( m_WindowName $ ".TopText", GetSystemString(138) );
		class'UIAPI_TEXTBOX'.static.SetText( m_WindowName $ ".BottomText", GetSystemString(132) );

		ShowWindow( m_WindowName $ ".BottomCountText" );
		HideWindow( m_WindowName $ ".TopCountText" );
	}
	else if( m_type == WT_Withdraw )
	{
		class'UIAPI_TEXTBOX'.static.SetText( m_WindowName $ ".TopText", GetSystemString(132) );
		class'UIAPI_TEXTBOX'.static.SetText( m_WindowName $ ".BottomText", GetSystemString(133) );

		ShowWindow( m_WindowName $ ".TopCountText" );
		HideWindow( m_WindowName $ ".BottomCountText" );
	}
}

function HandleAddItem( string param )
{
	local ItemInfo info;
	
	ParamToItemInfo( param, info );
	m_topList.AddItem( info );
	AdjustCount();
}

// 한 칸당 KEEPING_PRICE 씩 만큼
function AdjustPrice()
{
	local string adena;
	local int count;
	if( m_type == WT_Deposit )
	{
		count = m_bottomList.GetItemNum();
		adena = MakeCostString( string(count*KEEPING_PRICE) );
		class'UIAPI_TEXTBOX'.static.SetText(m_WindowName $ ".PriceText", adena);
		class'UIAPI_TEXTBOX'.static.SetTooltipString(m_WindowName $ ".PriceText", ConvertNumToText(string(count*KEEPING_PRICE)) );
	}
}

function AdjustCount()
{
	local int num, maxNum;
	if( m_category == WC_Private )
		maxNum = m_maxPrivateCount;
	else 
		maxNum = DEFAULT_MAX_COUNT;

	if( m_type == WT_Deposit )
	{
		num = m_bottomList.GetItemNum();
		class'UIAPI_TEXTBOX'.static.SetText(m_WindowName $ ".BottomCountText", "(" $ string(num) $ "/" $ string(maxNum) $ ")");
		//debug("AdjustCount Deposit num " $ num $ ", maxCount " $ maxNum );
	}
	else if( m_type == WT_Withdraw )
	{
		num = m_topList.GetItemNum();
		class'UIAPI_TEXTBOX'.static.SetText(m_WindowName $ ".TopCountText", "(" $ string(num) $ "/" $ string(maxNum) $ ")");
		//debug("AdjustCount Withdraw num " $ num $ ", maxCount " $ maxNum );
	}
}

function HandleOKButton()
{
	local string	param;
	local int		bottomCount, bottomIndex;
	local ItemInfo	bottomInfo;

	bottomCount = m_bottomList.GetItemNum();
	if( m_type == WT_Deposit )
	{
		// pack every item in BottomList
		ParamAdd( param, "num", string(bottomCount) );
		for( bottomIndex=0 ; bottomIndex < bottomCount; ++bottomIndex )
		{
			m_bottomList.GetItem( bottomIndex, bottomInfo );
			ParamAdd( param, "dbID" $ bottomIndex, string(bottomInfo.Reserved) );
			ParamAdd( Param, "count" $ bottomIndex, string(bottomInfo.ItemNum) );
		}
		RequestWarehouseDeposit( param );
	}
	else if( m_type == WT_Withdraw )
	{
		// pack every item in BottomList
		ParamAdd( param, "num", string(bottomCount) );
		for( bottomIndex=0 ; bottomIndex < bottomCount; ++bottomIndex )
		{
			m_bottomList.GetItem( bottomIndex, bottomInfo );
			ParamAdd( param, "dbID" $ bottomIndex, string(bottomInfo.Reserved) );
			ParamAdd( Param, "count" $ bottomIndex, string(bottomInfo.ItemNum) );
		}

		RequestWarehouseWithdraw( param );
	}

	HideWindow(m_WindowName);
}

function HandleSetMaxCount( string param )
{
	ParseInt( param, "warehousePrivate", m_maxPrivateCount );
	//debug("HandleStoreSetMaxCount " $ m_maxCount );
}

defaultproperties
{
     m_WindowName="WarehouseWnd"
}
