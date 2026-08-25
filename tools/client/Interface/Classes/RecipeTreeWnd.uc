class RecipeTreeWnd extends UICommonAPI;

function OnLoad()
{
	RegisterEvent( EV_RecipeShowRecipeTreeWnd );
}

function OnEvent(int Event_ID, String param)
{
	local int RecipeID;
	local int SuccessRate;

	if (Event_ID == EV_RecipeShowRecipeTreeWnd)
	{
		ParseInt( param, "RecipeID", RecipeID );
		ParseInt( param, "SuccessRate", SuccessRate );
		StartRecipeTreeWnd( RecipeID, SuccessRate );
	}
}

function OnClickButton( string strID )
{
	switch( strID )
	{
	case "btnClose":
		CloseWindow();
		break;
	}
}

//윈도우 닫기
function CloseWindow()
{
	Clear();
	class'UIAPI_WINDOW'.static.HideWindow("RecipeTreeWnd");
	PlayConsoleSound(IFST_WINDOW_CLOSE);
}

//초기화
function Clear()
{
	class'UIAPI_TREECTRL'.static.Clear("RecipeTreeWnd.MainTree");
}

//Start Function
function StartRecipeTreeWnd(int RecipeID, int SuccessRate)
{
	//Show
	class'UIAPI_WINDOW'.static.ShowWindow("RecipeTreeWnd");
	class'UIAPI_WINDOW'.static.SetFocus("RecipeTreeWnd");
	
	Clear();
	SetRecipeInfo(RecipeID, SuccessRate);
}

//레시피 정보 셋팅
function SetRecipeInfo(int RecipeID, int SuccessRate)
{
	local string		strTmp;
	local string		strTmp2;
	local int			nTmp;
	local XMLTreeNodeInfo	infNode;
	
	local int			ProductID;
	
	//레시피 아이콘 텍스쳐
	strTmp = class'UIDATA_RECIPE'.static.GetRecipeIconName(RecipeID);
	if (Len(strTmp)>0)
	{
		class'UIAPI_TEXTURECTRL'.static.SetTexture("RecipeTreeWnd.texIcon", strTmp);
	}
	else
	{
		class'UIAPI_TEXTURECTRL'.static.SetTexture("RecipeTreeWnd.texIcon", "Default.BlackTexture");
	}
	
	//레시피 이름
	ProductID = class'UIDATA_RECIPE'.static.GetRecipeProductID(RecipeID);
	strTmp = MakeFullItemName(ProductID);
	
	//Crystal Type(Grade Emoticon출력)
	nTmp = class'UIDATA_RECIPE'.static.GetRecipeCrystalType(RecipeID);
	strTmp2 = GetItemGradeString(nTmp);
	if (Len(strTmp2)>0)
	{
		strTmp2 = "`" $ strTmp2 $ "`";
		
	}
	
	class'UIAPI_TEXTBOX'.static.SetText("RecipeTreeWnd.txtName", strTmp $ " " $ strTmp2);
	
	//MP소비량
	nTmp = class'UIDATA_RECIPE'.static.GetRecipeMpConsume(RecipeID);
	class'UIAPI_TEXTBOX'.static.SetText("RecipeTreeWnd.txtMPConsume", "" $ nTmp);
	
	//성공확률
	class'UIAPI_TEXTBOX'.static.SetText("RecipeTreeWnd.txtSuccessRate", SuccessRate $ "%");
	
	//레시피 레벨
	nTmp = class'UIDATA_RECIPE'.static.GetRecipeLevel(RecipeID);
	class'UIAPI_TEXTBOX'.static.SetText("RecipeTreeWnd.txtLevel", "Lv." $ nTmp);
	
	//트리에 Root추가
	infNode.strName = "root";
	infNode.nOffSetX = 1;
	infNode.nOffSetY = 5;
	strTmp = class'UIAPI_TREECTRL'.static.InsertNode("RecipeTreeWnd.MainTree", "", infNode);
	if (Len(strTmp) < 1)
	{
		debug("ERROR: Can't insert root node. Name: " $ infNode.strName);
		return;
	}
	
	//트리 작성
	AddRecipeItem(ProductID, SuccessRate, 0, "root");
}

function AddRecipeItem(int ProductID, int SuccessRate, int NeedCount, string NodeName)
{
	local int		i;
	local ParamStack	param;
	local int		nTmp;
	local string	strTmp;
	local string	strTmp2;
	local int		nMax;
	local bool		bIamRoot;
	
	local array<int>	arrMatID;
	local array<int>	arrMatRate;
	local array<int>	arrMatNeedCount;
	
	local XMLTreeNodeInfo	infNode;
	local XMLTreeNodeItemInfo	infNodeItem;
	local XMLTreeNodeInfo	infNodeClear;
	local XMLTreeNodeItemInfo	infNodeItemClear;
	local string		strRetName;
	
	//레시피 이름
	strTmp = class'UIDATA_RECIPE'.static.GetRecipeNameBy2Condition(ProductID, SuccessRate);
	
	//Child가 있는 레시피
	if (Len(strTmp)>0)
	{
		if (NodeName == "root")
		{
			bIamRoot = true;
		}
		else
		{
			bIamRoot = false;
		}
		
		//////////////////////////////////////////////////////////////////////////////////////////////////////
		//Insert Node - with Button
		infNode = infNodeClear;
		infNode.strName = "" $ ProductID $ "_" $ SuccessRate;
		infNode.Tooltip = MakeTooltipSimpleText(strTmp);
		infNode.bFollowCursor = true;
		if (!bIamRoot)
		{
			infNode.nOffSetX = 16;
		}
		infNode.bShowButton = 1;
		infNode.nTexBtnWidth = 12;
		infNode.nTexBtnHeight = 12;
		infNode.nTexBtnOffSetY = 10;
		infNode.strTexBtnExpand = "L2UI.RecipeWnd.TreePlus";
		infNode.strTexBtnCollapse = "L2UI.RecipeWnd.TreeMinus";
		
		strRetName = class'UIAPI_TREECTRL'.static.InsertNode("RecipeTreeWnd.MainTree", NodeName, infNode);
		if (Len(strRetName) < 1)
		{
			Log("ERROR: Can't insert node. Name: " $ infNode.strName);
			return;
		}
		
		//레시피 아이콘 이름
		strTmp2 = class'UIDATA_RECIPE'.static.GetRecipeIconNameBy2Condition(ProductID, SuccessRate);
		if (Len(strTmp2)<1)
		{
			strTmp2 = "Default.BlackTexture";
		}
		
		//Insert Node Item - 레시피 아이콘
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXTURE;
		infNodeItem.nOffSetX = 2;
		infNodeItem.nOffSetY = 0;
		infNodeItem.u_nTextureWidth = 32;
		infNodeItem.u_nTextureHeight = 32;
		infNodeItem.u_strTexture = strTmp2;
		class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeTreeWnd.MainTree", strRetName, infNodeItem);
		
		//Insert Node Item - 레시피 아이콘(테두리)
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXTURE;
		infNodeItem.nOffSetX = -32;
		infNodeItem.nOffSetY = 0;
		infNodeItem.u_nTextureWidth = 32;
		infNodeItem.u_nTextureHeight = 32;
		infNodeItem.u_strTexture = "L2UI.RecipeWnd.RecipeTreeIconBack";
		infNodeItem.u_strTextureExpanded = "L2UI.RecipeWnd.RecipeTreeIconBack_click";
		class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeTreeWnd.MainTree", strRetName, infNodeItem);
		
		if (!bIamRoot)
		{
			//인벤토리의 해당 아이템의 갯수
			nTmp = GetInventoryItemCount(ProductID);
			
			//재료가 다 안모아진 경우라면 흐릿하게 표시
			if (nTmp < NeedCount)
			{
				//Insert Node Item - 흐릿 텍스쳐
				infNodeItem = infNodeItemClear;
				infNodeItem.eType = XTNITEM_TEXTURE;
				infNodeItem.nOffSetX = -32;
				infNodeItem.nOffSetY = 0;
				infNodeItem.u_nTextureWidth = 32;
				infNodeItem.u_nTextureHeight = 32;
				infNodeItem.u_strTexture = "Default.ChatBack";
				class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeTreeWnd.MainTree", strRetName, infNodeItem);
			}	
		}
		
		//Insert Node Item - 레시피 이름
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXT;
		infNodeItem.t_strText = strTmp;
		infNodeItem.t_bDrawOneLine = true;
		infNodeItem.nOffSetX = 5;
		infNodeItem.nOffSetY = 4;
		class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeTreeWnd.MainTree", strRetName, infNodeItem);
		
		if (!bIamRoot)
		{
			//Insert Node Item - 재료 갯수
			infNodeItem = infNodeItemClear;
			infNodeItem.eType = XTNITEM_TEXT;
			infNodeItem.t_strText = "(" $ nTmp $ "/" $ NeedCount $ ")";
			infNodeItem.bLineBreak = true;
			infNodeItem.nOffSetX = 51;
			infNodeItem.nOffSetY = -14;
			class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeTreeWnd.MainTree", strRetName, infNodeItem);
		}
		
		//Insert Node Item - Blank
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_BLANK;
		infNodeItem.bStopMouseFocus = true;
		infNodeItem.b_nHeight = 6;
		class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeTreeWnd.MainTree", strRetName, infNodeItem);
		
		//Child 레시피들의 추가
		param = class'UIDATA_RECIPE'.static.GetRecipeMaterialItemBy2Condition(ProductID, SuccessRate);
		nMax = param.GetInt();
		
		//나중에 Recursive호출하는 부분이 있으므로, Static인 Param을 일단 완전히 뽑아야(?)한다.
		arrMatID.Length = nMax;
		arrMatRate.Length = nMax;
		arrMatNeedCount.Length = nMax;
		for (i=0; i<nMax; i++)
		{
			arrMatID[i] = param.GetInt();
			arrMatRate[i] = param.GetInt();
			arrMatNeedCount[i] = param.GetInt();
		}
		for (i=0; i<nMax; i++)
		{
			//Recursive
			AddRecipeItem(arrMatID[i], arrMatRate[i], arrMatNeedCount[i], strRetName);
		}
	}
	
	//Child가 없는 넘
	else
	{
		//레시피 이름
		strTmp = class'UIDATA_ITEM'.static.GetItemName(ProductID);
		
		//////////////////////////////////////////////////////////////////////////////////////////////////////
		//Insert Node - with No Button
		infNode = infNodeClear;
		infNode.strName = "" $ ProductID $ "_" $ SuccessRate;
		infNode.nOffSetX = 30;
		infNode.Tooltip = MakeTooltipSimpleText(strTmp);
		infNode.bFollowCursor = true;
		infNode.bShowButton = 0;
		strRetName = class'UIAPI_TREECTRL'.static.InsertNode("RecipeTreeWnd.MainTree", NodeName, infNode);
		if (Len(strRetName) < 1)
		{
			Log("ERROR: Can't insert node. Name: " $ infNode.strName);
			return;
		}
		
		//레시피 아이콘 이름
		strTmp2 = class'UIDATA_ITEM'.static.GetItemTextureName(ProductID);
		if (Len(strTmp2)<1)
		{
			strTmp2 = "Default.BlackTexture";
		}
		
		//Insert Node Item - 레시피 아이콘
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXTURE;
		infNodeItem.nOffSetX = 0;
		infNodeItem.nOffSetY = 0;
		infNodeItem.u_nTextureWidth = 32;
		infNodeItem.u_nTextureHeight = 32;
		infNodeItem.u_strTexture = strTmp2;
		class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeTreeWnd.MainTree", strRetName, infNodeItem);
		
		//Insert Node Item - 레시피 아이콘(Disable)
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXTURE;
		infNodeItem.nOffSetX = -32;
		infNodeItem.nOffSetY = 0;
		infNodeItem.u_nTextureWidth = 32;
		infNodeItem.u_nTextureHeight = 32;
		infNodeItem.u_strTexture = "L2UI.RecipeWnd.RecipeTreeIconDisableBack";
		class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeTreeWnd.MainTree", strRetName, infNodeItem);
		
		//인벤토리의 해당 아이템의 갯수
		nTmp = GetInventoryItemCount(ProductID);
		
		//재료가 다 안모아진 경우라면 흐릿하게 표시
		if (nTmp < NeedCount)
		{
			//Insert Node Item - 흐릿 텍스쳐
			infNodeItem = infNodeItemClear;
			infNodeItem.eType = XTNITEM_TEXTURE;
			infNodeItem.nOffSetX = -32;
			infNodeItem.nOffSetY = 0;
			infNodeItem.u_nTextureWidth = 32;
			infNodeItem.u_nTextureHeight = 32;
			infNodeItem.u_strTexture = "Default.ChatBack";
			class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeTreeWnd.MainTree", strRetName, infNodeItem);
		}
		
		//Insert Node Item - 레시피 이름
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXT;
		infNodeItem.t_strText = strTmp;
		infNodeItem.t_bDrawOneLine = true;
		infNodeItem.nOffSetX = 5;
		infNodeItem.nOffSetY = 3;
		class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeTreeWnd.MainTree", strRetName, infNodeItem);
		
		//Insert Node Item - 재료 갯수
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXT;
		infNodeItem.t_strText = "(" $ nTmp $ "/" $ NeedCount $ ")";
		infNodeItem.bLineBreak = true;
		infNodeItem.nOffSetX = 37;
		infNodeItem.nOffSetY = -14;
		class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeTreeWnd.MainTree", strRetName, infNodeItem);
		
		//Insert Node Item - Blank
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_BLANK;
		infNodeItem.bStopMouseFocus = true;
		infNodeItem.b_nHeight = 4;
		class'UIAPI_TREECTRL'.static.InsertNodeItem("RecipeTreeWnd.MainTree", strRetName, infNodeItem);
	}
}
