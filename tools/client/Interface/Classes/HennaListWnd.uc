class HennaListWnd extends UICommonAPI;

//////////////////////////////////////////////////////////////////////////////
// CONST
//////////////////////////////////////////////////////////////////////////////
const FEE_OFFSET_Y_EQUIP = -13;
const FEE_OFFSET_Y_UNEQUIP = -12;

// 문양 새기기 윈도우의 상태
const HENNA_EQUIP=1;		// 문양새기기
const HENNA_UNEQUIP=2;		// 문양지우기

var int m_iState;
var int m_iRootNameLength;

function OnLoad()
{
	RegisterEvent( EV_HennaListWndShowHideEquip );
	RegisterEvent( EV_HennaListWndAddHennaEquip );

	RegisterEvent( EV_HennaListWndShowHideUnEquip );
	RegisterEvent( EV_HennaListWndAddHennaUnEquip );
}

function OnClickButton( string strID )
{
	local string strHennaID;
	
	switch( strID )
	{
	default:
		strHennaID = Mid(strID, m_iRootNameLength+1);

		if(m_iState==HENNA_EQUIP)
			RequestHennaItemInfo(int(strHennaID));
		else if(m_iState==HENNA_UNEQUIP)
			RequestHennaUnequipInfo(int(strHennaID));
		break;
	}
}

// 트리 비우기
function Clear()
{
	class'UIAPI_TREECTRL'.static.Clear("HennaListWnd.HennaListTree");
}

function OnEvent(int Event_ID, string param)
{
	local int iAdena;
	
	local string strName;
	local string strIconName;
	local string strDescription;
	local int iHennaID;
	local int iClassID;
	local int iNum;
	local int iFee;

	switch(Event_ID)
	{
	case EV_HennaListWndShowHideEquip :
		m_iState=HENNA_EQUIP;
		Clear();
		ParseInt(param, "Adena", iAdena);
		ShowHennaListWnd(iAdena);
		break;

	case EV_HennaListWndAddHennaEquip :
	case EV_HennaListWndAddHennaUnEquip :
		ParseString(param, "Name", strName);				//이름
		ParseString(param, "Description", strDescription);	// 설명은 필요없으니 버린다
		ParseString(param, "IconName", strIconName);		// IconName;
		ParseInt(param, "HennaID", iHennaID);				// 필요없공
		ParseInt(param, "ClassID", iClassID);				// 필요없고
		ParseInt(param, "NumOfItem", iNum);					// 수량 - 필요없음
		ParseInt(param, "Fee", iFee);						// 요금

		AddHennaListItem(strName, strIconName, strDescription, iFee, iHennaID);
		break;

	case EV_HennaListWndShowHideUnEquip :
		m_iState=HENNA_UNEQUIP;
		Clear();
		ParseInt(param, "Adena", iAdena);
		ShowHennaListWnd(iAdena);
		break;
	}
}

// 문양 새기기 윈도우로 초기화 시킴
function ShowHennaListWnd(int iAdena)
{
	local XMLTreeNodeInfo	infNode;
	local string strTmp;

	if(m_iState==HENNA_EQUIP)		// 문양새기기 상태일경우
	{
		// 타이틀 변경
		class'UIAPI_WINDOW'.static.SetWindowTitleByText("HennaListWnd", GetSystemString(651));
		// 타이틀 아래 제목 변경 - 염료목록
		class'UIAPI_TEXTBOX'.static.SetText("HennaListWnd.txtList", GetSystemString(659));
	}
	else if(m_iState==HENNA_UNEQUIP)	// 문양 지우기 상태일 경우
	{
		// 타이틀 - "문양지우기"
		class'UIAPI_WINDOW'.static.SetWindowTitleByText("HennaListWnd", GetSystemString(652));
		// 타이틀 아래 제목 변경 - "문양목록"
		class'UIAPI_TEXTBOX'.static.SetText("HennaListWnd.txtList", GetSystemString(660));
	}

	//소지 아데나 
	class'UIAPI_TEXTBOX'.static.SetText("HennaListWnd.txtAdena", MakeCostString("" $ iAdena));
	class'UIAPI_TEXTBOX'.static.SetTooltipString("HennaListWnd.txtAdena", ConvertNumToText("" $ iAdena));


	//트리에 Root추가
	infNode.strName = "HennaListRoot";
	infNode.nOffSetX = 7;
	infNode.nOffSetY = -3;
	strTmp = class'UIAPI_TREECTRL'.static.InsertNode("HennaListWnd.HennaListTree", "", infNode);
	if (Len(strTmp) < 1)
	{
		debug("ERROR: Can't insert root node. Name: " $ infNode.strName);
		return;
	}

	m_iRootNameLength=Len(infNOde.strName);

	ShowWindow("HennaListWnd");
	class'UIAPI_WINDOW'.static.SetFocus("HennaListWnd");
}

// 염료 추가
function AddHennaListItem(string strName, string strIconName, string strDescription, int iFee, int iHennaID)
{
	local XMLTreeNodeInfo	infNode;
	local XMLTreeNodeItemInfo	infNodeItem;
	local XMLTreeNodeInfo	infNodeClear;
	local XMLTreeNodeItemInfo	infNodeItemClear;

	local string strRetName;
	local string strAdenaComma;


//	debug("AddHennaListItem:"$strName$", "$strIconName$", "$iFee);

	//////////////////////////////////////////////////////////////////////////////////////////////////////
	//Insert Node - with No Button
	infNode = infNodeClear;
	infNode.strName = "" $ iHennaID;
	infNode.bShowButton = 0;
	
	//Tooltip - 일단 없다
//	infNode.Tooltip.infItem.Name = strName;
//	infNode.Tooltip.infItem.Description = strDescription;
//	infNode.Tooltip.infItem.Price = MakingFee;
//	infNode.Tooltip.nStyle1 = 2;	//TTS_INVENTORY
//	infNode.Tooltip.nStyle2 = 4;	//TTES_SHOW_PRICE1
	
	//Expand되었을때의 BackTexture설정
	//스트레치로 그리기 때문에 ExpandedWidth는 없다. 끝에서 -2만큼 배경을 그린다.
	infNode.nTexExpandedOffSetX = -7;		//OffSet
	infNode.nTexExpandedOffSetY = 8;		//OffSet
	infNode.nTexExpandedHeight = 46;		//Height
	infNode.nTexExpandedRightWidth = 0;		//오른쪽 그라데이션부분의 길이
	infNode.nTexExpandedLeftUWidth = 32; 		//스트레치로 그릴 왼쪽 텍스쳐의 UV크기
	infNode.nTexExpandedLeftUHeight = 40;
	infNode.strTexExpandedLeft = "L2UI_CH3.etc.IconSelect2";
	
	strRetName = class'UIAPI_TREECTRL'.static.InsertNode("HennaListWnd.HennaListTree", "HennaListRoot", infNode);
	if (Len(strRetName) < 1)
	{
		debug("ERROR: Can't insert node. Name: " $ infNode.strName);
		return;
	}

	//Insert Node Item - 아이템 아이콘
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXTURE;
	infNodeItem.nOffSetX = 0;
	infNodeItem.nOffSetY = 15;
	infNodeItem.u_nTextureWidth = 32;
	infNodeItem.u_nTextureHeight = 32;
	infNodeItem.u_strTexture = strIconName;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("HennaListWnd.HennaListTree", strRetName, infNodeItem);

	//Insert Node Item - 아이템 이름
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = strName;
	infNodeItem.t_bDrawOneLine = true;
	infNodeItem.nOffSetX = 5;

	if(m_iState==HENNA_EQUIP)
		infNodeItem.nOffSetY = 17;
	else if(m_iState==HENNA_UNEQUIP)
		infNodeItem.nOffSetY = 10;

	class'UIAPI_TREECTRL'.static.InsertNodeItem("HennaListWnd.HennaListTree", strRetName, infNodeItem);


	if(m_iState==HENNA_UNEQUIP)
	{
		//Insert Node Item - 문신 부가정보
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXT;
		infNodeItem.t_strText = strDescription;
		infNodeItem.bLineBreak = true;
		infNodeItem.t_bDrawOneLine = true;
		infNodeItem.nOffSetX = 37;
		infNodeItem.nOffSetY = -24;
		class'UIAPI_TREECTRL'.static.InsertNodeItem("HennaListWnd.HennaListTree", strRetName, infNodeItem);
	}

	//Insert Node Item - "수수료"
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = GetSystemString(637) $ " : ";
	infNodeItem.bLineBreak = true;
	infNodeItem.t_bDrawOneLine = true;
	infNodeItem.nOffSetX = 37;

	if(m_iState==HENNA_EQUIP)
		infNodeItem.nOffSetY = FEE_OFFSET_Y_EQUIP;
	else if(m_iState==HENNA_UNEQUIP)
		infNodeItem.nOffSetY = FEE_OFFSET_Y_UNEQUIP;

	infNodeItem.t_color.R = 168;
	infNodeItem.t_color.G = 168;
	infNodeItem.t_color.B = 168;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("HennaListWnd.HennaListTree", strRetName, infNodeItem);

	//아데나(,)
	strAdenaComma = MakeCostString("" $ iFee);
	
	//Insert Node Item - "제작비(아데나)"
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = strAdenaComma;
	infNodeItem.t_bDrawOneLine = true;
	infNodeItem.nOffSetX = 0;

	if(m_iState==HENNA_EQUIP)
		infNodeItem.nOffSetY = FEE_OFFSET_Y_EQUIP;
	else if(m_iState==HENNA_UNEQUIP)
		infNodeItem.nOffSetY = FEE_OFFSET_Y_UNEQUIP;

	infNodeItem.t_color = GetNumericColor(strAdenaComma);
	class'UIAPI_TREECTRL'.static.InsertNodeItem("HennaListWnd.HennaListTree", strRetName, infNodeItem);

	//Insert Node Item - "아데나"
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = GetSystemString(469);
	infNodeItem.t_bDrawOneLine = true;
	infNodeItem.nOffSetX = 5;

	if(m_iState==HENNA_EQUIP)
		infNodeItem.nOffSetY = FEE_OFFSET_Y_EQUIP;
	else if(m_iState==HENNA_UNEQUIP)
		infNodeItem.nOffSetY = FEE_OFFSET_Y_UNEQUIP;

	infNodeItem.t_color.R = 255;
	infNodeItem.t_color.G = 255;
	infNodeItem.t_color.B = 0;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("HennaListWnd.HennaListTree", strRetName, infNodeItem);
}
