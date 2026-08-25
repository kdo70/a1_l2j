class RecipeBuyListWnd extends UIScript;

//////////////////////////////////////////////////////////////////////////////
// RECIPE CONST
//////////////////////////////////////////////////////////////////////////////
const RECIPEWND_MAX_MP_WIDTH = 165.0f;

var int		m_MerchantID;	//판매자의 ServerID
var int		m_MaxMP;

function OnLoad()
{
	RegisterEvent( EV_RecipeShowBuyListWnd );
	RegisterEvent( EV_RecipeShopSellItem );
	RegisterEvent( EV_UpdateMP );

	//소지 아데나 = 0
	class'UIAPI_TEXTBOX'.static.SetText("RecipeBuyListWnd.txtAdena", "0");
}

function OnEvent(int Event_ID, string param)
{
	local Rect 	rectWnd;
	local int		ServerID;
	local int		MPValue;

	// 2006/07/10 NeverDie
	local int CurrentMP;
	local int MaxMP;
	local int Adena;
	local int RecipeID;
	local int CanbeMade;
	local int MakingFee;

	if (Event_ID == EV_RecipeShowBuyListWnd)
	{
		Clear();
		
		//윈도우의 위치를 RecipeBuyManufactureWnd에 맞춤
		rectWnd = class'UIAPI_WINDOW'.static.GetRect("RecipeBuyManufactureWnd");
		class'UIAPI_WINDOW'.static.MoveTo("RecipeBuyListWnd", rectWnd.nX, rectWnd.nY);
		
		ParseInt( param, "ServerID", ServerID);
		ParseInt( param, "CurrentMP", CurrentMP);
		ParseInt( param, "MaxMP", MaxMP);
		ParseInt( param, "Adena", Adena);
		ReceiveRecipeShopSellList( ServerID, CurrentMP, MaxMP, Adena );
		
		class'UIAPI_WINDOW'.static.ShowWindow("RecipeBuyListWnd");
		class'UIAPI_WINDOW'.static.SetFocus("RecipeBuyListWnd");
	}
	else if (Event_ID == EV_RecipeShopSellItem)
	{
		ParseInt( param, "RecipeID", RecipeID);
		ParseInt( param, "CanbeMade", CanbeMade);
		ParseInt( param, "MakingFee", MakingFee);
		AddRecipeShopSellItem( RecipeID, CanbeMade, MakingFee );
	}
	else if (Event_ID == EV_UpdateMP)
	{
		ParseInt( param, "ServerID", ServerID );
		ParseInt( param, "CurrentMP", MPValue );
		if (m_MerchantID==ServerID && m_MerchantID>0)
			SetMPBar(MPValue);
	}
}

function OnClickButton( string strID )
{
	local string strRecipeID;
	
	switch( strID )
	{
	case "btnClose":
		CloseWindow();
		break;
	default:
		strRecipeID = Mid(strID, 5);
		class'RecipeAPI'.static.RequestRecipeShopMakeInfo(m_MerchantID, int(strRecipeID));
		break;
	}
}

//윈도우 닫기
function CloseWindow()
{
	Clear();
	class'UIAPI_WINDOW'.static.HideWindow("RecipeBuyListWnd");
	PlayConsoleSound(IFST_WINDOW_CLOSE);
}

//초기화
function Clear()
{
	m_MerchantID = 0;
	m_MaxMP = 0;
	class'UIAPI_TREECTRL'.static.Clear("RecipeBuyListWnd.MainTree");
}

//기본정보 셋팅
function ReceiveRecipeShopSellList(int ServerID, int CurrentMP, int MaxMP, int Adena)
{
	local string		strTmp;
	local XMLTreeNodeInfo	infNode;
	
	m_MerchantID = ServerID;
	m_MaxMP = MaxMP;
	
	//윈도우 타이틀 설정
	strTmp = GetSystemString(663) $ " - " $ class'UIDATA_USER'.static.GetUserName(ServerID);
	class'UIAPI_WINDOW'.static.SetWindowTitleByText("RecipeBuyListWnd", strTmp);
	
	//MP바 표시
	SetMPBar(CurrentMP);
	
	//소지 아데나 = 0
	class'UIAPI_TEXTBOX'.static.SetText("RecipeBuyListWnd.txtAdena", MakeCostString("" $ Adena));
	class'UIAPI_TEXTBOX'.static.SetTooltipString("RecipeBuyListWnd.txtAdena", ConvertNumToText("" $ Adena));
	
	//트리에 Root추가
	infNode.strName = "root";
	infNode.nOffSetX = 7;
	infNode.nOffSetY = 7;
	strTmp = class'UIAPI_TREECTRL'.static.InsertNode("RecipeBuyListWnd.MainTree", "", infNode);
	if (Len(strTmp) < 1)
	{
		debug("ERROR: Can't insert root node. Name: " $ infNode.strName);
		return;
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
	class'UIAPI_WINDOW'.static.SetWindowSize("RecipeBuyListWnd.texMPBar", nMPWidth, 12);
}

//레시피 리스트 추가
function AddRecipeShopSellItem(int RecipeID, int CanbeMade, int MakingFee)
{
	local string		strTmp;

	local XMLTreeNodeInfo	infNode;
	local XMLTreeNodeItemInfo	infNodeItem;
	local XMLTreeNodeInfo	infNodeClear;
	local XMLTreeNodeItemInfo	infNodeItemClear;
	local string		strRetName;
	
	//For Recipe
	local int			ProductID;
	local string		AdenaComma;
	local string		strName;
	local string		strDescription;
	
	//레시피 Product ID
	ProductID = class'UIDATA_RECIPE'.static.GetRecipeProductID(RecipeID);
	
	//아이템 이름
	strName = class'UIDATA_ITEM'.static.GetItemName(ProductID);
	
	//아이템 설명
	strDescription = class'UIDATA_ITEM'.static.GetItemDescription(ProductID);
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////
	//Insert Node - with No Button
	infNode = infNodeClear;
	infNode.strName = "" $ RecipeID;
	infNode.bShowButton = 0;
	
	//Tooltip
	infNode.Tooltip = SetTooltip(strName, strDescription, MakingFee);
	infNode.bFollowCursor = true;
	
	//Expand되었을때의 BackTexture설정
	//스트레치로 그리기 때문에 ExpandedWidth는 없다. 끝에서 -2만큼 배경을 그린다.
	infNode.nTexExpandedOffSetX = -7;		//OffSet
	infNode.nTexExpandedOffSetY = -3;		//OffSet
	infNode.nTexExpandedHeight = 46;		//Height
	infNode.nTexExpandedRightWidth = 0;		//오른쪽 그라데이션부분의 길이
	infNode.nTexExpandedLeftUWidth = 32; 		//스트레치로 그릴 왼쪽 텍스쳐의 UV크기
	infNode.nTexExpandedLeftUHeight = 40;
	infNode.strTexExpandedLeft = "L2UI_CH3.etc.IconSelect2";
	
	strRetName = class'UIAPI_TREECTRL'.static.InsertNode("RecipeBuyListWnd.MainTree", "root", infNode);
	if (Len(strRetName) < 1)
	{
		Log("ERROR: Can't insert node. Name: " $ infNode.strName);
		return;
	}
	
	//Node Tooltip Clear
	infNode.ToolTip.DrawList.Remove(0, infNode.ToolTip.DrawList.Length);
	
	//아이콘 이름
	strTmp = class'UIDATA_ITEM'.static.GetItemTextureName(ProductID);
	if (Len(strTmp)<1)
	{
		strTmp = "Default.BlackTexture";
	}
	
	//Insert Node Item - 아이템 아이콘
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXTURE;
	infNodeItem.nOffSetX = 0;
	infNodeItem.nOffSetY = 4;
	infNodeItem.u_nTextureWidth = 32;
	infNodeItem.u_nTextureHeight = 32;
	infNodeItem.u_strTexture = strTmp;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeBuyListWnd.MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - 아이템 이름
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = strName;
	infNodeItem.t_bDrawOneLine = true;
	infNodeItem.nOffSetX = 10;
	infNodeItem.nOffSetY = 0;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeBuyListWnd.MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - "제작비"
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = GetSystemString(641);
	infNodeItem.bLineBreak = true;
	infNodeItem.t_bDrawOneLine = true;
	infNodeItem.nOffSetX = 42;
	infNodeItem.nOffSetY = -22;
	infNodeItem.t_color.R = 168;
	infNodeItem.t_color.G = 168;
	infNodeItem.t_color.B = 168;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeBuyListWnd.MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - " : "
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = " : ";
	infNodeItem.t_bDrawOneLine = true;
	infNodeItem.nOffSetX = 0;
	infNodeItem.nOffSetY = -22;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeBuyListWnd.MainTree", strRetName, infNodeItem);
	
	//아데나(,)
	AdenaComma = MakeCostString("" $ MakingFee);
	
	//Insert Node Item - "제작비(아데나)"
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = AdenaComma;
	infNodeItem.t_bDrawOneLine = true;
	infNodeItem.nOffSetX = 0;
	infNodeItem.nOffSetY = -22;
	infNodeItem.t_color = GetNumericColor(AdenaComma);
	class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeBuyListWnd.MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - "아데나"
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = GetSystemString(469);
	infNodeItem.t_bDrawOneLine = true;
	infNodeItem.nOffSetX = 5;
	infNodeItem.nOffSetY = -22;
	infNodeItem.t_color.R = 255;
	infNodeItem.t_color.G = 255;
	infNodeItem.t_color.B = 0;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeBuyListWnd.MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - "성공확률"
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = GetSystemString(642);
	infNodeItem.bLineBreak = true;
	infNodeItem.t_bDrawOneLine = true;
	infNodeItem.nOffSetX = 42;
	infNodeItem.nOffSetY = -8;
	infNodeItem.t_color.R = 168;
	infNodeItem.t_color.G = 168;
	infNodeItem.t_color.B = 168;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeBuyListWnd.MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - " : "
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = " : ";
	infNodeItem.t_bDrawOneLine = true;
	infNodeItem.nOffSetX = 0;
	infNodeItem.nOffSetY = -8;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeBuyListWnd.MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - "퍼센트"
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = class'UIDATA_RECIPE'.static.GetRecipeSuccessRate(RecipeID) $ "%";
	infNodeItem.t_bDrawOneLine = true;
	infNodeItem.nOffSetX = 0;
	infNodeItem.nOffSetY = -8;
	infNodeItem.t_color.R = 176;
	infNodeItem.t_color.G = 155;
	infNodeItem.t_color.B = 121;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeBuyListWnd.MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - Blank
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_BLANK;
	infNodeItem.bStopMouseFocus = true;
	infNodeItem.b_nHeight = 10;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeBuyListWnd.MainTree", strRetName, infNodeItem);
}

function CustomTooltip SetTooltip(string Name, string Description, int MakingFee)
{
	local CustomTooltip Tooltip;
	local DrawItemInfo info;
	local DrawItemInfo infoClear;
	
	local string AdenaComma;
	
	//아데나(,)
	AdenaComma = MakeCostString("" $ MakingFee);
	
	Tooltip.DrawList.Length = 4;
	
	//이름
	info = infoClear;
	info.eType = DIT_TEXT;
	info.t_bDrawOneLine = true;
	info.t_strText = Name;
	Tooltip.DrawList[0] = info;
	
	//가격	
	info = infoClear;
	info.eType = DIT_TEXT;
	info.nOffSetY = 6;
	info.bLineBreak = true;
	info.t_bDrawOneLine = true;
	info.t_color.R = 163;
	info.t_color.G = 163;
	info.t_color.B = 163;
	info.t_color.A = 255;
	info.t_strText = GetSystemString(322) $ " : ";
	Tooltip.DrawList[1] = info;
	
	//아데나
	info = infoClear;
	info.eType = DIT_TEXT;
	info.nOffSetY = 6;
	info.t_bDrawOneLine = true;
	info.t_color = GetNumericColor(AdenaComma);
	info.t_strText = AdenaComma $ " " $ GetSystemString(469);
	Tooltip.DrawList[2] = info;
	
	//읽어주기 스트링
	info = infoClear;
	info.eType = DIT_TEXT;
	info.nOffSetY = 6;
	info.bLineBreak = true;
	info.t_bDrawOneLine = true;
	info.t_color = GetNumericColor(AdenaComma);
	info.t_strText = "(" $ ConvertNumToText(String(MakingFee)) $ ")";
	Tooltip.DrawList[3] = info;

	return Tooltip;
}
