class MultiSellWnd extends UICommonAPI;

const MULTISELLWND_DIALOG_OK=1122;

struct NeededItem
{
	var int ID;
	var	string Name;
	var int Count;
	var string IconName;
	var int Enchant;
	var int CrystalType;
	var int ItemType;
	var int RefineryOp1;
	var int RefineryOp2;
};

struct ItemList
{
	var int MultiSellType;
	var int NeededItemNum;
	var array< ItemInfo > ItemInfoList;
	var array< NeededItem > NeededItemList;
};

var array< ItemList >	m_itemLIst;
var int					m_shopID;
var int		pre_itemList;

function OnLoad()
{
	registerEvent( EV_MultiSellShopID );
	registerEvent( EV_MultiSellItemList );
	registerEvent( EV_MultiSellNeededItemList );
	registerEvent( EV_MultiSellItemListEnd );
	registerEvent( EV_DialogOK );
	pre_itemList = -1;
}

function OnEvent(int Event_ID, string param)
{
	switch( Event_ID )
	{
	case EV_MultiSellShopID:
		HandleShopID( param );
		break;
	case EV_MultiSellItemList:
		HandleItemList( param );
		break;
	case EV_MultiSellNeededItemList:
		HandleNeededItemList( param );
		break;
	case EV_MultiSellItemListEnd:
		HandleItemListEnd( param );
		break;
	case EV_DialogOK:
		HandleDialogOK();
		break;
	default:
		break;
	};
}

function OnShow()
{
	class'UIAPI_EDITBOX'.static.Clear("MultiSellWnd.ItemCountEdit");
}

function OnHide()
{
}

function OnClickButton( string ControlName )
{
	if( ControlName == "OKButton" )
	{
		HandleOKButton();
	}
	else if( ControlName == "CancelButton" )
	{
		Clear();
		HideWindow("MultiSellWnd");
	}
}

function OnClickItem( String strID, int index )			// ItemWindow
{
	local int i;
	local string param;
	
	class'UIAPI_MULTISELLITEMINFO'.static.Clear("MultiSellWnd.ItemInfo");
	class'UIAPI_MULTISELLNEEDEDITEM'.static.Clear("MultiSellWnd.NeededItem");
	//debug("OnClickItem : " $ strID $ ", index : " $ index );
	if( strID == "ItemList" )
	{
		if( index >= 0 && index < m_itemList.Length )
		{
			for( i=0 ; i < m_itemList[index].NeededItemList.Length ; ++i )
			{
				param = "";
				ParamAdd( param, "Name", m_itemList[index].NeededItemList[i].Name );
				ParamAdd( param, "ID", string(m_itemList[index].NeededItemList[i].ID ));
				ParamAdd( param, "Num", string(m_itemList[index].NeededItemList[i].Count ));
				ParamAdd( param, "Icon", m_itemList[index].NeededItemList[i].IconName );
				ParamAdd( param, "Enchant", string(m_itemList[index].NeededItemList[i].Enchant) );
				ParamAdd( param, "CrystalType", string(m_itemList[index].NeededItemList[i].CrystalType) );
				ParamAdd( param, "ItemType", string(m_itemList[index].NeededItemList[i].ItemType) );

				//debug("AddData " $ param );
				class'UIAPI_MULTISELLNEEDEDITEM'.static.AddData("MultiSellWnd.NeededItem", param);
			}

			for( i=0 ; i < m_itemList[index].NeededItemNum ; ++i )
			{
				class'UIAPI_MULTISELLITEMINFO'.static.SetItemInfo("MultiSellWnd.ItemInfo", i, m_itemList[index].ItemInfoList[i] );
			}

			class'UIAPI_EDITBOX'.static.Clear("MultiSellWnd.ItemCountEdit");
			
			if( m_itemList[index].MultiSellType == 0 )
			{
				class'UIAPI_EDITBOX'.static.SetString("MultiSellWnd.ItemCountEdit", "1");
				class'UIAPI_WINDOW'.static.DisableWindow("MultiSellWnd.ItemCountEdit");
			}
			else if( m_itemList[index].MultiSellType == 1 )
			{
				class'UIAPI_EDITBOX'.static.SetString("MultiSellWnd.ItemCountEdit", "1");
				class'UIAPI_WINDOW'.static.EnableWindow("MultiSellWnd.ItemCountEdit");
			}
			
			if(pre_itemList != index)	//다이얼로그를 없애준다. - innowind
			{
				if( DialogIsMine() )
				{
					DialogHide();
				}
			}
		}
	}

	//Print();
}

function Print()
{
	local int i,j;
	for( i = 0; i<m_ItemList.Length ; ++i)
	{
		for( j =0 ; j < m_ItemList[i].NeededItemList.Length ; ++j )
		{
			debug("Print ("$i$","$j$"), " $ m_ItemList[i].NeededItemList[j].Name);
		}
	}
}

function HandleShopID( string param )
{
	Clear();
	ParseInt( param, "shopID", m_shopID );
}

function Clear()
{
	m_itemList.Length = 0;
	class'UIAPI_MULTISELLITEMINFO'.static.Clear("MultiSellWnd.ItemInfo");
	class'UIAPI_MULTISELLNEEDEDITEM'.static.Clear("MultiSellWnd.NeededItem");
	class'UIAPI_ITEMWINDOW'.static.Clear("MultiSellWnd.ItemList");
}

function HandleItemList( string param )
{
	local ItemInfo info;
	local int index, type, i, classID;
	local bool bMatchFound;

	ParseInt( param, "classID", classID );
	class'UIDATA_ITEM'.static.GetItemInfo( classID, info );

	info.ClassID = classID;
	ParseInt( param, "index", index );
	ParseInt( param, "type", type );
	ParseInt( param, "ID", info.Reserved );
	ParseInt( param, "slotBitType", info.SlotBitType );
	ParseInt( param, "itemType", info.ItemType );
	ParseInt( param, "itemCount", info.ItemNum );
	ParseInt( param, "OutputRefineryOp1", info.RefineryOp1 );
	ParseInt( param, "OutputRefineryOp2", info.RefineryOp2 );

	// 투영병기의 경우 강제로, 100% Durability를 표시하게 합니다 - NeverDie
	if( 0 < info.Durability )
		info.CurrentDurability = info.Durability;

	//debug("HandleItemList classID : " $ classID $ ", index : " $ index $ ", type : " $ type $ ", ID : " $ info.Reserved $ ", m_itemList.Length : " $ m_itemList.Length );
	
	if( index == 0 )			// 새로운 데이터를 추가한다
	{
		i = m_itemList.Length;
		m_itemList.Length = i+1;
		m_itemList[i].MultiSellType = type;
		m_itemList[i].NeededItemNum = 1;
		m_itemList[i].ItemInfoList.Length = index + 1;
		m_itemList[i].ItemInfoList[index] = info;
	}
	else if( index > 0 )			// index가 0보다 크다는 것은 같은 ID를 가진 아이템이 존재 한다는 것.
	{
		bMatchFound = false;
		// Find matching item with ID
		for( i=m_itemList.Length-1; i >= 0 ; --i )
		{
			if( m_itemList[i].ItemInfoList[0].Reserved ==  info.Reserved
				&& m_itemList[i].ItemInfoList[0].RefineryOp1 == info.RefineryOp1
				&& m_itemList[i].ItemInfoList[0].RefineryOp2 == info.RefineryOp2 )
			{
				bMatchFound = true;
				break;
			}
		}

		if( bMatchFound )
		{
			if( m_itemList[i].ItemInfoList.Length <= index )
				m_itemList[i].ItemInfoList.Length = index + 1;

			m_itemList[i].MultiSellType = type;
			m_itemList[i].ItemInfoList[index] = info;
			++m_ItemList[i].NeededItemNum;
		}
		else
		{
			debug("MultiSellWnd Error!!");			// 이건 에러.
		}
	}
}

function HandleNeededItemList( string param )
{
	local NeededItem item;
	local int i, ID, index, RefineryOp1, RefineryOp2 ;
	ParseInt( param, "ID", ID );
	ParseInt( param, "refineryOp1", RefineryOp1 );
	ParseInt( param, "refineryOp2", RefineryOp2 );
	ParseInt( param, "ClassID", item.ID );
	ParseInt( param, "count", item.Count );
	ParseInt( param, "enchant", item.Enchant );
	ParseInt( param, "inputRefineryOp1", item.RefineryOp1 );
	ParseInt( param, "inputRefineryOp2", item.RefineryOp2 );
	
	if( item.ID == -100 )
	{
		item.Name = GetSystemString(1277);
		item.IconName = "icon.etc_i.etc_pccafe_point_i00";
		item.Enchant = 0;
		item.ItemType = -1;
		item.ID = 0;
	}
	else if( item.ID == -200 )
	{
		item.Name = GetSystemString( 1311 );
		item.IconName = "icon.etc_i.etc_bloodpledge_point_i00";
		item.Enchant = 0;
		item.ItemType = -1;
		item.ID = 0;
	}
	else
	{
		item.Name = class'UIDATA_ITEM'.static.GetItemName( item.ID );
		item.IconName = class'UIDATA_ITEM'.static.GetItemTextureName( item.ID );
	}

	//debug("NeededItem param : " $ param $ ", Name : " $ item.Name $ ", IconName : " $ item.IconName );
	// Add Item Info
	for( i=m_itemList.Length-1; i>=0 ; --i )
	{
		if( m_itemList[i].ItemInfoList[0].Reserved == ID
			&& m_itemList[i].ItemInfoList[0].RefineryOp1 == RefineryOp1
			&& m_itemList[i].ItemInfoList[0].RefineryOp2 == RefineryOp2
			)		// match found
		{
			index = m_itemList[i].NeededItemList.Length;
			m_itemList[i].NeededItemList.Length = index + 1;
			item.ItemType = class'UIDATA_ITEM'.static.GetItemDataType( item.ID );
			item.CrystalType = class'UIDATA_ITEM'.static.GetItemCrystalType( item.ID );
			m_itemList[i].NeededItemList[index] = item;
			break;
		}
	}
}

function HandleItemListEnd( string param )
{
	local WindowHandle m_inventoryWnd;
	
	m_inventoryWnd = GetHandle( "InventoryWnd" );	//인벤토리
	
	if( m_inventoryWnd.IsShowWindow() )			//인벤토리 창이 열려있으면 닫아준다. 
	{
		m_inventoryWnd.HideWindow();
	}	
	
	ShowWindow("MultiSellWnd");
	class'UIAPI_WINDOW'.static.SetFocus("MultiSellWnd");
	ShowItemList();
}

function ShowItemList()
{
	local ItemInfo info;
	local int i;

	for( i=0 ; i < m_itemList.Length ; ++i )
	{
		info = m_itemList[i].ItemInfoList[0];
		class'UIAPI_ITEMWINDOW'.static.AddItem( "MultiSellWnd.ItemList", info );
	}
}

function HandleOKButton()
{
	local int selectedIndex, itemNum;

	selectedIndex = class'UIAPI_ITEMWINDOW'.static.GetSelectedNum("MultiSellWnd.ItemList");
	itemNum = int(class'UIAPI_EDITBOX'.static.GetString("MultiSellWnd.ItemCountEdit"));
	//debug("HandleOKButton selectedIndex: " $ selectedIndex $ ", itemNum: " $ itemNum );
	if( selectedIndex >= 0 )
	{
		DialogSetReservedInt( selectedIndex );
		DialogSetReservedInt2( itemNum );
		DialogSetID( MULTISELLWND_DIALOG_OK );
		DialogShow(DIALOG_Warning, GetSystemMessage(1383));
		pre_itemList = selectedIndex;
	}
}

function HandleDialogOK()
{
	local string param;
	local int SelectedIndex;

	if( DialogIsMine() )
	{
		SelectedIndex = DialogGetReservedInt();

		ParamAdd( param, "ShopID", string(m_shopID) );
		ParamAdd( param, "ItemID", string( m_itemList[SelectedIndex].ItemInfoList[0].Reserved ) );
		ParamAdd( param, "RefineryOp1", string( m_itemList[SelectedIndex].ItemInfoList[0].RefineryOp1 ) );
		ParamAdd( param, "RefineryOp2", string( m_itemList[SelectedIndex].ItemInfoList[0].RefineryOp2 ) );
		ParamAdd( param, "ItemCount", string(DialogGetReservedInt2()) );		

		RequestMultiSellChoose( param );
	}
}
