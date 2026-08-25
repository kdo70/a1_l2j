class RecipeShopWnd extends UICommonAPI;

const RECIPESHOP_MAX_ITEM_SELL = 20;

var int		m_BookItemCount;
var int		m_ShopItemCount;
var array<int>	m_arrBookItem;
var array<int>	m_arrShopItem;

var int		m_BookType;
var ItemInfo	m_HandleItem;

function OnLoad()
{
	RegisterEvent( EV_RecipeShopShowWnd );
	RegisterEvent( EV_RecipeShopAddBookItem );
	RegisterEvent( EV_RecipeShopAddShopItem );
	RegisterEvent( EV_DialogOK );
}

function OnClickButton( string strID )
{
	switch( strID )
	{
	case "btnEnd":
		class'RecipeAPI'.static.RequestRecipeShopManageQuit();
		CloseWindow();
		break;
	case "btnMsg":
		DialogSetEditBoxMaxLength(29);
		DialogShow(DIALOG_OKCancelInput, GetSystemMessage(334));
		DialogSetID(0);
		DialogSetString(class'UIDATA_PLAYER'.static.GetRecipeShopMsg());
		break;
	case "btnStart":
		StartRecipeShop();
		CloseWindow();
		break;
	case "btnMoveUp":
		HandleMoveUpItem();
		break;
	case "btnMoveDown":
		HandleMoveDownItem();
		break;
	}
}

function OnEvent(int Event_ID, string param)
{
	local string strPrice;
	
	local int RecipeID;
	local int CanbeMade;
	local int MakingFee;
	local int Price;
	
	local InventoryWnd InventoryWnd;
	InventoryWnd = InventoryWnd( GetScript("InventoryWnd") );
	
	if (Event_ID == EV_RecipeShopShowWnd)
	{
		Clear();
		InventoryWnd.LoadItemOrder();
		//Show
		class'UIAPI_WINDOW'.static.ShowWindow("RecipeShopWnd");
		class'UIAPI_WINDOW'.static.SetFocus("RecipeShopWnd");
		
		//enum RecipeBookClass
		//{
		//	RBC_DWARF  = 0,	//드워프용 레시피샵
		//	RBC_NORMAL		//개인 레시피샵
		//};
		ParseInt(param, "Type", m_BookType);
		if (m_BookType == 1)
		{
			class'UIAPI_WINDOW'.static.SetWindowTitle("RecipeShopWnd", 1212);
		}
		else
		{
			class'UIAPI_WINDOW'.static.SetWindowTitle("RecipeShopWnd", 1213);
		}
	}
	else if (Event_ID == EV_RecipeShopAddBookItem)
	{
		ParseInt( param, "RecipeID", RecipeID );
		AddRecipeBookItem( RecipeID );
	}
	else if (Event_ID == EV_RecipeShopAddShopItem)
	{
		ParseInt( param, "RecipeID", RecipeID );
		ParseInt( param, "CanbeMade", CanbeMade );
		ParseInt( param, "MakingFee", MakingFee );
		AddRecipeShopItem( RecipeID, CanbeMade, MakingFee );
	}
	else if (Event_ID == EV_DialogOK)
	{
		if (DialogIsMine())
		{	
			//메시지 입력
			if (DialogGetID() == 0 )
			{
				class'RecipeAPI'.static.RequestRecipeShopMessageSet(DialogGetString());
			}
			else if (DialogGetID() == 1 )
			{
				//가격이 "0"원이라도, 뭔가 입력한 게 있어야만 아이템을 추가
				strPrice = DialogGetString();
				if (Len(strPrice)>0)
				{
					//입력한 가격이 20억이 넘으면 수량 초과 에러를 뿌려준다.
					Price = int(strPrice);
					if( Price >= 2000000000 )
					{
						DialogSetID(2);
						DialogShow(DIALOG_Warning, GetSystemMessage(1369));
					}
					else
					{
						m_HandleItem.Price = Price;
						UpdateShopItem(m_HandleItem);
					}
				}
				ClearHandleItem();
			}
		}
	}
}

//Frame의 "X"를 눌렀을 때 (따로 사운드를 출력할 필요가 없음)
function OnSendPacketWhenHiding()
{
	class'RecipeAPI'.static.RequestRecipeShopManageQuit();
	Clear();
}

//윈도우 닫기
function CloseWindow()
{
	Clear();
	class'UIAPI_WINDOW'.static.HideWindow("RecipeShopWnd");
	PlayConsoleSound(IFST_WINDOW_CLOSE);
}

//ItemWindow더블 클릭 처리
function OnDBClickItem( string strID, int index )
{
	local int Max;
	local int i;
	local ItemInfo infItem;
	local ItemInfo DeleteItem;
	
	ClearHandleItem();
	
	if (strID == "BookItemWnd" && m_BookItemCount>index)
	{
		class'UIAPI_ITEMWINDOW'.static.GetItem( "RecipeShopWnd.BookItemWnd", index, infItem);
			
		// 이미 아래에 존재하는 아이템이라면 삭제해줘야 한다. 
		Max = class'UIAPI_ITEMWINDOW'.static.GetItemNum( "RecipeShopWnd.ShopItemWnd");
		for (i=0; i<Max; i++)
		{
			if (class'UIAPI_ITEMWINDOW'.static.GetItem( "RecipeShopWnd.ShopItemWnd", i, DeleteItem))
			{
				if (DeleteItem.ClassID == infItem.ClassID)
				{
					DeleteShopItem(infItem);	// 해당아이템을 삭제하고 리턴한다. 
					return;
				}
			}
		}
			
		//위에서 리턴되지 않고 넘어왔다면, 가격을 입력하는 창으로 이동.		
		class'UIAPI_ITEMWINDOW'.static.GetItem( "RecipeShopWnd.BookItemWnd", index, infItem);
		ShowShopItemAddDialog(infItem);
	}
	//Shop에서 더블클릭을 하면 다이얼로그가 나타나고 가격을 입력하지만, 실제로는 아무런 작동을 하지않는다.(원래 이렇삼)
	//원래 이런게 아닌가봅니다. TTP가 날라왔네요. 아래부분에서 더블클릭하면 아이템을 삭제합니다. -innowind
	else if (strID == "ShopItemWnd" && m_ShopItemCount>index)
	{
		class'UIAPI_ITEMWINDOW'.static.GetItem( "RecipeShopWnd.ShopItemWnd", index, infItem);
		DeleteShopItem(infItem);	// 해당아이템을 삭제한다. 
		//ShowShopItemAddDialog(infItem);
	}
}

/*
	Max = class'UIAPI_ITEMWINDOW'.static.GetItemNum( "RecipeShopWnd.ShopItemWnd");
	for (i=0; i<Max; i++)
	{
		if (class'UIAPI_ITEMWINDOW'.static.GetItem( "RecipeShopWnd.ShopItemWnd", i, infItem))
		{
			if (DeleteItem.ClassID == infItem.ClassID)
			{
				class'UIAPI_ITEMWINDOW'.static.DeleteItem( "RecipeShopWnd.ShopItemWnd", i);
				m_ShopItemCount--;
				UpdateShopItemCount(m_ShopItemCount);
				break;
			}
		}
	}
*/


//아이템 드롭 처리
function OnDropItem( string strID, ItemInfo infItem, int x, int y)
{
	if (strID == "BookItemWnd")
	{
		if (infItem.DragSrcName == "ShopItemWnd")
		{
			//Shop에서 Book으로 드랍한 경우, Shop의 아이템을 삭제한다.
			DeleteShopItem(infItem);
		}
	}
	else if (strID == "ShopItemWnd")
	{
		if (infItem.DragSrcName == "BookItemWnd")
		{
			//Book에서 Shop으로 드랍한 경우, Shop에 아이템을 추가한다.
			ShowShopItemAddDialog(infItem);
		}
	}
}

//초기화
function Clear()
{
	ClearHandleItem();	
	m_BookItemCount = 0;
	m_ShopItemCount = 0;
	UpdateShopItemCount(0);
	m_arrBookItem.Remove(0, m_arrBookItem.Length);
	m_arrShopItem.Remove(0, m_arrShopItem.Length);
	
	class'UIAPI_ITEMWINDOW'.static.Clear("RecipeShopWnd.BookItemWnd");
	class'UIAPI_ITEMWINDOW'.static.Clear("RecipeShopWnd.ShopItemWnd");
}

//Handle아이템 클리어
function ClearHandleItem()
{
	local ItemInfo ItemClear;
	m_HandleItem = ItemClear;
}

//레시피샵 아이템 추가
function AddRecipeBookItem(int RecipeID)
{
	local ItemInfo	infItem;
	local int		ProductID;
	local int		Index;
	
	//Product ID
	ProductID = class'UIDATA_RECIPE'.static.GetRecipeProductID(RecipeID);
	
	//Index(ServerID)
	Index = class'UIDATA_RECIPE'.static.GetRecipeIndex(RecipeID);
	
	//레시피정보
	infItem.ClassID = class'UIDATA_RECIPE'.static.GetRecipeClassID(RecipeID);
	infItem.Level = class'UIDATA_RECIPE'.static.GetRecipeLevel(RecipeID);
	infItem.ServerID = class'UIDATA_RECIPE'.static.GetRecipeIndex(RecipeID);
	
	infItem.Name = class'UIDATA_ITEM'.static.GetItemName(infItem.ClassID);
	infItem.Description = class'UIDATA_ITEM'.static.GetItemDescription(infItem.ClassID);
	infItem.Weight = class'UIDATA_ITEM'.static.GetItemWeight(infItem.ClassID);

	//생산물정보
	infItem.IconName = class'UIDATA_ITEM'.static.GetItemTextureName(ProductID);
	infItem.CrystalType = class'UIDATA_RECIPE'.static.GetRecipeCrystalType(RecipeID);
	
	//ItemWnd에 추가
	class'UIAPI_ITEMWINDOW'.static.AddItem( "RecipeShopWnd.BookItemWnd", infItem);
	
	//ItemArray에 추가
	m_arrBookItem.Insert(m_arrBookItem.Length, 1);
	m_arrBookItem[m_arrBookItem.Length-1] = Index;
	
	m_BookItemCount++;
}

//이미 등록한  아이템 추가
function AddRecipeShopItem(int RecipeID, int CanbeMade, int MakingFee)
{
	local ItemInfo	infItem;
	local int		ProductID;
	local int		Index;
	
	//Product ID
	ProductID = class'UIDATA_RECIPE'.static.GetRecipeProductID(RecipeID);
	
	//Index(ServerID)
	Index = class'UIDATA_RECIPE'.static.GetRecipeIndex(RecipeID);
	
	//레시피정보
	infItem.ClassID = class'UIDATA_RECIPE'.static.GetRecipeClassID(RecipeID);
	infItem.Level = class'UIDATA_RECIPE'.static.GetRecipeLevel(RecipeID);
	infItem.ServerID = class'UIDATA_RECIPE'.static.GetRecipeIndex(RecipeID);
	infItem.Price = MakingFee;
	infItem.Reserved = CanbeMade;
	
	infItem.Name = class'UIDATA_ITEM'.static.GetItemName(infItem.ClassID);
	infItem.Description = class'UIDATA_ITEM'.static.GetItemDescription(infItem.ClassID);
	infItem.Weight = class'UIDATA_ITEM'.static.GetItemWeight(infItem.ClassID);

	//생산물정보
	infItem.IconName = class'UIDATA_ITEM'.static.GetItemTextureName(ProductID);
	infItem.CrystalType = class'UIDATA_RECIPE'.static.GetRecipeCrystalType(RecipeID);
	
	//ItemWnd에 추가
	class'UIAPI_ITEMWINDOW'.static.AddItem( "RecipeShopWnd.ShopItemWnd", infItem);
	
	//ItemArray에 추가
	m_arrShopItem.Insert(m_arrShopItem.Length, 1);
	m_arrShopItem[m_arrShopItem.Length-1] = Index;
	
	m_ShopItemCount++;
	UpdateShopItemCount(m_ShopItemCount);
}

//레시피샵에 아이템 추가 다이얼로그 박스 표시
function ShowShopItemAddDialog(ItemInfo AddItem)
{
	m_HandleItem = AddItem;
	DialogSetID(1);
	DialogSetParamInt(-1);
	DialogSetDefaultOK();	
	DialogShow(DIALOG_NumberPad, GetSystemMessage(963));
}

//레시피샵에 아이템 추가
function UpdateShopItem(ItemInfo AddItem)
{
	local int		i;
	local int		Max;
	local ItemInfo	infItem;
	local bool		bDuplicated;
	
	bDuplicated = false;
	
	Max = class'UIAPI_ITEMWINDOW'.static.GetItemNum( "RecipeShopWnd.ShopItemWnd");
	for (i=0; i<Max; i++)
	{
		if (class'UIAPI_ITEMWINDOW'.static.GetItem( "RecipeShopWnd.ShopItemWnd", i, infItem))
		{
			if (AddItem.ClassID == infItem.ClassID)
			{
				bDuplicated = true;
				break;
			}
		}
	}
	if (!bDuplicated)
	{
		class'UIAPI_ITEMWINDOW'.static.AddItem( "RecipeShopWnd.ShopItemWnd", AddItem);
		m_ShopItemCount++;
		UpdateShopItemCount(m_ShopItemCount);
	}
}

//레시피샵의 아이템 삭제
function DeleteShopItem(ItemInfo DeleteItem)
{
	local int		i;
	local int		Max;
	local ItemInfo	infItem;
	
	Max = class'UIAPI_ITEMWINDOW'.static.GetItemNum( "RecipeShopWnd.ShopItemWnd");
	for (i=0; i<Max; i++)
	{
		if (class'UIAPI_ITEMWINDOW'.static.GetItem( "RecipeShopWnd.ShopItemWnd", i, infItem))
		{
			if (DeleteItem.ClassID == infItem.ClassID)
			{
				class'UIAPI_ITEMWINDOW'.static.DeleteItem( "RecipeShopWnd.ShopItemWnd", i);
				m_ShopItemCount--;
				UpdateShopItemCount(m_ShopItemCount);
				break;
			}
		}
	}
}

//등록된 아이템 갯수 갱신
function UpdateShopItemCount(int Count)
{
	class'UIAPI_TEXTBOX'.static.SetText("RecipeShopWnd.txtCount", "(" $ Count $ "/" $ RECIPESHOP_MAX_ITEM_SELL $ ")");	
}

//레시피샵 시작
function StartRecipeShop()
{
	local int		i;
	local int		Max;
	local ItemInfo	infItem;
	
	local string	param;
	local int		ServerID;
	local int		Price;
	
	Max = class'UIAPI_ITEMWINDOW'.static.GetItemNum( "RecipeShopWnd.ShopItemWnd");
	ParamAdd(param, "Max", string(Max));
	
	for (i=0; i<Max; i++)
	{
		ServerID = 0;
		Price = 0;
		if (class'UIAPI_ITEMWINDOW'.static.GetItem( "RecipeShopWnd.ShopItemWnd", i, infItem))
		{
			ServerID = infItem.ServerID;
			Price = infItem.Price;
		}
		ParamAdd(param, "ServerID_" $ i, string(ServerID));
		ParamAdd(param, "Price_" $ i, string(Price));
	}
	class'RecipeAPI'.static.RequestRecipeShopListSet( param );
}

//아이템 업
function HandleMoveUpItem()
{
	local ItemInfo infItem;
	
	if (class'UIAPI_ITEMWINDOW'.static.GetSelectedItem( "RecipeShopWnd.ShopItemWnd", infItem))
	{
		DeleteShopItem(infItem);
	}
}

//아이템 다운
function HandleMoveDownItem()
{
	local ItemInfo infItem;
	
	if (class'UIAPI_ITEMWINDOW'.static.GetSelectedItem( "RecipeShopWnd.BookItemWnd", infItem))
	{
		ShowShopItemAddDialog(infItem);
	}
}
