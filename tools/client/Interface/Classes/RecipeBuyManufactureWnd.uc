class RecipeBuyManufactureWnd extends UIScript;

//////////////////////////////////////////////////////////////////////////////
// RECIPE CONST
//////////////////////////////////////////////////////////////////////////////
const RECIPEWND_MAX_MP_WIDTH = 165.0f;

var int		m_MerchantID;	//판매자의 ServerID
var int		m_RecipeID;	//RecipeID
var int		m_SuccessRate;	//성공률
var int		m_Adena;		//아데나
var int		m_MaxMP;

function OnLoad()
{
	RegisterEvent( EV_RecipeShopItemInfo );
	RegisterEvent( EV_UpdateMP );
	
	RegisterEvent( EV_InventoryAddItem );
	RegisterEvent( EV_InventoryUpdateItem );
}

function OnEvent(int Event_ID, string param)
{
	local Rect 	rectWnd;
	local int		ServerID;
	local int		MPValue;

	// 2006/07/10 NeverDie
	local int		MerchantID;
	local int		RecipeID;
	local int		CurrentMP;
	local int		MaxMP;
	local int		MakingResult;
	local int		Adena;
	
	if (Event_ID == EV_RecipeShopItemInfo)
	{
		class'UIAPI_WINDOW'.static.HideWindow("RecipeBuyListWnd");
		
		Clear();
		
		//윈도우의 위치를 RecipeBuyListWnd에 맞춤
		rectWnd = class'UIAPI_WINDOW'.static.GetRect("RecipeBuyListWnd");
		class'UIAPI_WINDOW'.static.MoveTo("RecipeBuyManufactureWnd", rectWnd.nX, rectWnd.nY);
		
		//show
		class'UIAPI_WINDOW'.static.ShowWindow("RecipeBuyManufactureWnd");
		class'UIAPI_WINDOW'.static.SetFocus("RecipeBuyManufactureWnd");
		
		ParseInt( param, "MerchantID", MerchantID );
		ParseInt( param, "RecipeID", RecipeID );
		ParseInt( param, "CurrentMP", CurrentMP );
		ParseInt( param, "MaxMP", MaxMP );
		ParseInt( param, "MakingResult", MakingResult );
		ParseInt( param, "Adena", Adena );
		ReceiveRecipeShopSellList( MerchantID, RecipeID, CurrentMP, MaxMP, MakingResult, Adena );
	}
	else if (Event_ID == EV_UpdateMP)
	{
		ParseInt(param, "ServerID", ServerID);
		ParseInt(param, "CurrentMP", MPValue );
		if (m_MerchantID==ServerID && m_MerchantID>0)
		{
			SetMPBar(MPValue);
		}
	}
	else if( Event_ID == EV_InventoryAddItem || Event_ID == EV_InventoryUpdateItem )
	{
		HandleInventoryItem(param);
	}
}

function OnClickButton( string strID )
{
	local string param;
	
	switch( strID )
	{
	case "btnClose":
		CloseWindow();
		break;
	case "btnPrev":
		//RecipeBuyListWnd로 돌아감
		class'RecipeAPI'.static.RequestRecipeShopSellList(m_MerchantID);
		
		CloseWindow();
		break;
	case "btnRecipeTree":
		if (class'UIAPI_WINDOW'.static.IsShowWindow("RecipeTreeWnd"))
		{
			class'UIAPI_WINDOW'.static.HideWindow("RecipeTreeWnd");	
		}
		else
		{
			ParamAdd(param, "RecipeID", string(m_RecipeID));
			ParamAdd(param, "SuccessRate", string(m_SuccessRate));
			ExecuteEvent( EV_RecipeShowRecipeTreeWnd, param);
		}
		break;
	case "btnManufacture":
		class'RecipeAPI'.static.RequestRecipeShopMakeDo(m_MerchantID, m_RecipeID, m_Adena);
		break;
	}
}

//윈도우 닫기
function CloseWindow()
{
	Clear();
	class'UIAPI_WINDOW'.static.HideWindow("RecipeBuyManufactureWnd");
	PlayConsoleSound(IFST_WINDOW_CLOSE);
}

//초기화
function Clear()
{
	m_MerchantID = 0;
	m_RecipeID = 0;
	m_SuccessRate = 0;
	m_Adena = 0;
	m_MaxMP = 0;
	class'UIAPI_ITEMWINDOW'.static.Clear("RecipeBuyManufactureWnd.ItemWnd");
}

//기본정보 셋팅
function ReceiveRecipeShopSellList(int MerchantID,int RecipeID,int CurrentMP,int MaxMP,int MakingResult,int Adena)
{
	local int			i;
	
	local string		strTmp;
	local int			nTmp;
	
	local int			ProductID;
	local int			ProductNum;
	local string		ItemName;
	
	local ParamStack		param;
	local ItemInfo		infItem;
	
	//전역변수 설정
	m_MerchantID = MerchantID;
	m_RecipeID = RecipeID;
	m_SuccessRate = class'UIDATA_RECIPE'.static.GetRecipeSuccessRate(RecipeID);
	m_Adena = Adena;
	m_MaxMP = MaxMP;
	
	//윈도우 타이틀 설정
	strTmp = GetSystemString(663) $ " - " $ class'UIDATA_USER'.static.GetUserName(MerchantID);
	class'UIAPI_WINDOW'.static.SetWindowTitleByText("RecipeBuyManufactureWnd", strTmp);
	
	//Product ID
	ProductID = class'UIDATA_RECIPE'.static.GetRecipeProductID(RecipeID);
	
	//(아이템)텍스쳐
	strTmp = class'UIDATA_ITEM'.static.GetItemTextureName(ProductID);
	class'UIAPI_TEXTURECTRL'.static.SetTexture("RecipeBuyManufactureWnd.texItem", strTmp);
	
	//아이템 이름
	ItemName = MakeFullItemName(ProductID);
	
	//Crystal Type(Grade Emoticon출력)
	nTmp = class'UIDATA_RECIPE'.static.GetRecipeCrystalType(RecipeID);
	strTmp = GetItemGradeString(nTmp);
	if (Len(strTmp)>0)
	{
		strTmp = "`" $ strTmp $ "`";
		
	}
	
	class'UIAPI_TEXTBOX'.static.SetText("RecipeBuyManufactureWnd.txtName", ItemName $ " " $ strTmp);
	
	//MP소비량
	nTmp = class'UIDATA_RECIPE'.static.GetRecipeMpConsume(RecipeID);
	class'UIAPI_TEXTBOX'.static.SetText("RecipeBuyManufactureWnd.txtMPConsume", "" $ nTmp);
	
	//성공확률
	class'UIAPI_TEXTBOX'.static.SetText("RecipeBuyManufactureWnd.txtSuccessRate", m_SuccessRate $ "%");
	
	//결과물수
	ProductNum = class'UIDATA_RECIPE'.static.GetRecipeProductNum(RecipeID);
	class'UIAPI_TEXTBOX'.static.SetText("RecipeBuyManufactureWnd.txtResultValue", "" $ ProductNum);
	
	//MP바 표시
	SetMPBar(CurrentMP);
	
	//보유갯수
	class'UIAPI_TEXTBOX'.static.SetText("RecipeBuyManufactureWnd.txtCountValue", "" $ GetInventoryItemCount(ProductID));
	
	//제작결과
	strTmp = "";
	if (MakingResult == 0)
	{
		strTmp = MakeFullSystemMsg(GetSystemMessage(960), ItemName, "");
	}
	else if (MakingResult == 1)
	{
		strTmp = MakeFullSystemMsg(GetSystemMessage(959), ItemName, "" $ ProductNum);
	}
	class'UIAPI_TEXTBOX'.static.SetText("RecipeBuyManufactureWnd.txtMsg", strTmp);
	
	//ItemWnd에 추가
	param = class'UIDATA_RECIPE'.static.GetRecipeMaterialItem(RecipeID);
	nTmp = param.GetInt();
	for (i=0; i<nTmp; i++)
	{
		infItem.ClassID = param.GetInt();	//ID
		infItem.Reserved = param.GetInt();	//NeedNum
		infItem.Name = class'UIDATA_ITEM'.static.GetItemName(infItem.ClassID);
		infItem.AdditionalName = class'UIDATA_ITEM'.static.GetItemAdditionalName(infItem.ClassID);
		infItem.IconName = class'UIDATA_ITEM'.static.GetItemTextureName(infItem.ClassID);
		infItem.Description = class'UIDATA_ITEM'.static.GetItemDescription(infItem.ClassID);
		infItem.ItemNum = GetInventoryItemCount(infItem.ClassID);
		if (infItem.Reserved>infItem.ItemNum)
			infItem.bDisabled = true;
		else
			infItem.bDisabled = false;
		class'UIAPI_ITEMWINDOW'.static.AddItem( "RecipeBuyManufactureWnd.ItemWnd", infItem);
	}
}

//MP Bar
function SetMPBar(int CurrentMP)
{
	local int	nTmp;
	local int	nMPWidth;
	
	nTmp = RECIPEWND_MAX_MP_WIDTH * CurrentMP;
	nMPWidth = nTmp / m_MaxMP;
	if (nMPWidth>RECIPEWND_MAX_MP_WIDTH)
	{
		nMPWidth = RECIPEWND_MAX_MP_WIDTH;
	}
	class'UIAPI_WINDOW'.static.SetWindowSize("RecipeBuyManufactureWnd.texMPBar", nMPWidth, 12);
}

//인벤아이템이 업데이트되면 아이템의 현재보유수를 바꿔준다
function HandleInventoryItem(string param)
{
	local int ClassID;
	local int idx;
	local ItemInfo infItem;
	
	if (ParseInt( param, "classID", ClassID ))
	{
		idx = class'UIAPI_ITEMWINDOW'.static.FindItemWithClassID( "RecipeBuyManufactureWnd.ItemWnd", ClassID);
		if (idx>-1)
		{
			class'UIAPI_ITEMWINDOW'.static.GetItem( "RecipeBuyManufactureWnd.ItemWnd", idx, infItem);
			infItem.ItemNum = GetInventoryItemCount(infItem.ClassID);
			if (infItem.Reserved>infItem.ItemNum)
				infItem.bDisabled = true;
			else
				infItem.bDisabled = false;
			class'UIAPI_ITEMWINDOW'.static.SetItem( "RecipeBuyManufactureWnd.ItemWnd", idx, infItem);
		}
	}
}
