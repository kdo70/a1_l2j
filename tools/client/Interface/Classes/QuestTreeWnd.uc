class QuestTreeWnd extends UICommonAPI;

const QUESTTREEWND_MAX_COUNT = 25;

var String m_WindowName;
var int		m_QuestNum;	//현재 퀘스트 갯수

var int		m_OldQuestID;
var string		m_CurNodeName;

var int		m_DeleteQuestID;
var string		m_DeleteNodeName;

var array<string>	m_arrItemNodeName;
var array<string>	m_arrItemString;
var array<int>		m_arrItemClassID;

//Handle
var TextureHandle	m_QuestTooltip;

function OnLoad()
{
	RegisterEvent( EV_QuestListStart );
	RegisterEvent( EV_QuestList );
	RegisterEvent( EV_QuestListEnd );
	RegisterEvent( EV_QuestSetCurrentID );
	RegisterEvent( EV_DialogOK );
	
	RegisterEvent( EV_InventoryAddItem );
	RegisterEvent( EV_InventoryUpdateItem );
	
	RegisterEvent( EV_LanguageChanged );
	
	//Init Handle
	m_QuestTooltip = TextureHandle( GetHandle( m_WindowName $ ".QuestToolTip" ) );
	InitQuestTooltip();
	
	m_QuestNum = 0;
}

function OnShow()
{
	//퀘스트 리스트 표시
	ShowQuestList();
}

function OnClickButton( string strID )
{	
	switch( strID )
	{
	case "btnClose":
		HandleQuestCancel();
		break;
	}
	
	//TreeNode Click
	if (Left(strID, 4) == "root")
	{
		UpdateTargetInfo();
	}
}

function OnClickCheckBox( String strID )
{
	switch( strID )
	{
	case "chkNpcPosBox":
		UpdateTargetInfo();
		break;
	}
}

//Clear
function Clear()
{
	m_QuestNum = 0;
	UpdateQuestCount();
	m_OldQuestID = -1;
	m_CurNodeName = "";
	
	m_DeleteQuestID = 0;
	m_DeleteNodeName = "";
	
	m_arrItemNodeName.Remove(0, m_arrItemNodeName.Length);
	m_arrItemString.Remove(0, m_arrItemString.Length);
	m_arrItemClassID.Remove(0, m_arrItemClassID.Length);
	class'UIAPI_TREECTRL'.static.Clear(m_WindowName $ ".MainTree");
}

//////////////////////
//Request Quest List
function ShowQuestList()
{
	class'QuestAPI'.static.RequestQuestList();		//EV_QuestListStart -> EV_QuestList -> EV_QuestListEnd
}

function InitTree()
{
	local XMLTreeNodeInfo	infNode;
	local string		strRetName;
	
	// 0. 초기화
	Clear();
	
	// 1. Add Root Item
	infNode.strName = "root";
	infNode.nOffSetX = 3;
	infNode.nOffSetY = 5;
	strRetName = class'UIAPI_TREECTRL'.static.InsertNode(m_WindowName $ ".MainTree", "", infNode);
	if (Len(strRetName) < 1)
	{
		Log("ERROR: Can't insert root node. Name: " $ infNode.strName);
		return;
	}
}

function HandleQuestListStart()
{
	//초기화
	InitTree();
}

function HandleQuestList( String a_Param )
{
	local int QuestID;
	local int Level;
	local int Completed;

	ParseInt( a_Param, "QuestID", QuestID );
	ParseInt( a_Param, "Level", Level );
	ParseInt( a_Param, "Completed", Completed );
	
	if (m_OldQuestID != QuestID)
	{
		m_QuestNum++;	//퀘스트 갯수 증가
		AddQuestInfo( "", QuestID, Level, Completed );
	}
	else
	{
		AddQuestInfo( m_CurNodeName, QuestID, Level, Completed );	
	}
	m_OldQuestID = QuestID;
}

function HandleQuestListEnd()
{
	//아이템&퀘스트 갯수 갱신
	UpdateQuestCount();
	UpdateItemCount(0);
}

function OnEvent(int Event_ID,String param)
{
	local int ClassID;
	
	if( Event_ID == EV_QuestListStart )
		HandleQuestListStart();
	else if( Event_ID == EV_QuestList )
		HandleQuestList( param );
	else if( Event_ID == EV_QuestListEnd )
		HandleQuestListEnd();
	else if( Event_ID == EV_QuestSetCurrentID )
		HandleQuestSetCurrentID(param);
	else if( Event_ID == EV_InventoryAddItem || Event_ID == EV_InventoryUpdateItem )
	{
		ParseInt( param, "classID", ClassID );	
		UpdateItemCount(ClassID);
	}
	else if (Event_ID == EV_DialogOK)
	{
		if (DialogIsMine())
		{
			//Cancel
			if (DialogGetID() == 0 )
			{
				class'QuestAPI'.static.RequestDestroyQuest(m_DeleteQuestID);
				SetQuestOff();
				
				//노드 삭제
				class'UIAPI_TREECTRL'.static.DeleteNode(m_WindowName $ ".MainTree", m_DeleteNodeName);
				
				m_DeleteQuestID = 0;
				m_DeleteNodeName = "";
			}
			//Cannot Cancel
			else
			{
			}
		}
	}
	else if (Event_ID == EV_LanguageChanged)
	{
		HandleLanguageChanged();
	}
}

//퀘스트Effect버튼을 클릭했을 때, 해당 퀘스트를 펼쳐서 보여준다
function HandleQuestSetCurrentID(string param)
{
	local string strNodeName;
	local string strChildList;
	local int RecentlyAddedQuestID;
	local int SplitCount;
	local array<string>	arrSplit;
	
	if (!ParseInt(param, "QuestID", RecentlyAddedQuestID))
		return;
		
	if (RecentlyAddedQuestID>0)
	{
		// 1. QuestNode Expand
		strNodeName = "root." $ RecentlyAddedQuestID;
		class'UIAPI_TREECTRL'.static.SetExpandedNode(m_WindowName $ ".MainTree", strNodeName, true);
		
		// 2. JournalNode Expand
		strChildList = class'UIAPI_TREECTRL'.static.GetChildNode(m_WindowName $ ".MainTree", strNodeName);
		
		// Child중에서 가장 마지막 Child가 Expand할 저널
		if (Len(strChildList)>0)
		{
			SplitCount = Split(strChildList, "|", arrSplit);
			class'UIAPI_TREECTRL'.static.SetExpandedNode(m_WindowName $ ".MainTree", arrSplit[SplitCount-1], true);
		}
		
		//Target정보 갱신
		UpdateTargetInfo();
	}
}

//퀘스트 아이템 갯수 갱신(ClassID=0이면 전체 아이템을 갱신)
function UpdateItemCount( int ClassID, optional int a_ItemCount )
{
	local int i;
	local int nPos;
	local int ItemCount;
	local string strTmp;
	
	//Debug("UpdateItemCount=" $ ClassID);
	
	for (i=0; i<m_arrItemClassID.Length; i++)
	{	
		if (ClassID==0 || ClassID==m_arrItemClassID[i])
		{
			switch( a_ItemCount )
			{
			case -1:
				ItemCount = 0;
				break;
			case 0:
				ItemCount = GetInventoryItemCount(m_arrItemClassID[i]);
				break;
			default:
				ItemCount = a_ItemCount;
				break;

			}

			nPos = InStr(m_arrItemString[i], "%s");
			if (nPos>-1)
			{
				strTmp = Left(m_arrItemString[i], nPos) $ ItemCount $ Mid(m_arrItemString[i], nPos+2);
				class'UIAPI_TREECTRL'.static.SetNodeItemText(m_WindowName $ ".MainTree", m_arrItemNodeName[i], m_arrItemClassID.Length-i, strTmp);
			}
		}
	}	
}

//현재 퀘스트 갯수 갱신
function UpdateQuestCount()
{
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName $ ".txtQuestNum", "(" $ m_QuestNum $ "/" $ QUESTTREEWND_MAX_COUNT $ ")" );
}

//퀘스트 목적지 표시 관련
function UpdateTargetInfo()
{
	local int		i;
	local array<string>	arrSplit;
	local int		SplitCount;
	
	local int QuestID;
	local int Level;
	local int Completed;
	
	local string strChildList;
	local string strTargetNode;
	
	local string strNodeName;
	local string strTargetName;
	local vector vTargetPos;
	local bool bOnlyMinimap;
	
	//위치표시 체크박스
	if (!class'UIAPI_CHECKBOX'.static.IsChecked(m_WindowName $ ".chkNpcPosBox"))
	{
		SetQuestOff();
		return;
	}
	
	strNodeName = GetExpandedNode();
	if (Len(strNodeName)<1)
	{
		SetQuestOff();
		return;
	}	
	
	///////////////////////////////////////////////////////////////////////
	//Expanded된 노드가 가리키는 퀘스트의 Target표시용 저널을 찾아야함
	///////////////////////////////////////////////////////////////////////
	
	// 1. Child노드를 구한다.
	strChildList = class'UIAPI_TREECTRL'.static.GetChildNode(m_WindowName $ ".MainTree", strNodeName);
	
	// 2. Child가 있으면, Child중에서 가장 마지막 Child가 Target표시용 저널
	if (Len(strChildList)>0)
	{
		SplitCount = Split(strChildList, "|", arrSplit);
		strTargetNode = arrSplit[SplitCount-1];
	}
	else
	{
		SetQuestOff();
		return;
	}
	
	// 3. 이름을 분석해서, QuestID와 Level을 취득
	arrSplit.Remove(0,arrSplit.Length);
	SplitCount = Split(strTargetNode, ".", arrSplit);
	for (i=0; i<SplitCount; i++)
	{
		switch(i)
		{
		//"root"
		case 0:
			break;
		//"QuestID"
		case 1:
			QuestID = int(arrSplit[i]);
			break;
		//"QuestLevel"
		case 2:
			Level = int(arrSplit[i]);
			break;
		//"IsCompleted"
		case 2:
			Completed = int(arrSplit[i]);
			break;
		}
	}
	
	if (QuestID>0 && Level>0)
	{
		//Target이름 취득
		strTargetName = class'UIDATA_QUEST'.static.GetTargetName(QuestID, Level);
		vTargetPos = class'UIDATA_QUEST'.static.GetTargetLoc(QuestID, Level);
		
		if (Completed==0 && Len(strTargetName)>0)
		{
			bOnlyMinimap = class'UIDATA_QUEST'.static.IsMinimapOnly(QuestID, Level);
			if (bOnlyMinimap)
			{
				class'QuestAPI'.static.SetQuestTargetInfo( true, false, false, strTargetName, vTargetPos, QuestID);
			}
			else
			{
				class'QuestAPI'.static.SetQuestTargetInfo( true, true, true, strTargetName, vTargetPos, QuestID);
			}
		}
		else
		{
			SetQuestOff();
		}
	}
}

function SetQuestOff()
{
	local vector vVector;
	class'QuestAPI'.static.SetQuestTargetInfo( false, false, false, "", vVector, 0);
}

function string GetExpandedNode()
{
	local array<string>	arrSplit;
	local int		SplitCount;
	local string	strNodeName;
	
	strNodeName = class'UIAPI_TREECTRL'.static.GetExpandedNode(m_WindowName $ ".MainTree", "root");
	SplitCount = Split(strNodeName, "|", arrSplit);
	if (SplitCount>0)
	{
		strNodeName = arrSplit[0];
	}
	return strNodeName;
}

//퀘스트 중단
function HandleQuestCancel()
{
	local array<string>	arrSplit;
	local int		SplitCount;
	
	local string	strNodeName;
	
	m_DeleteQuestID = 0;
	m_DeleteNodeName = "";
	
	//Expanded된 노드를 구한다.
	strNodeName = GetExpandedNode();
	SplitCount = Split(strNodeName, "|", arrSplit);
	if (SplitCount>0)
	{
		strNodeName = arrSplit[0];
		
		arrSplit.Remove(0,arrSplit.Length);
		SplitCount = Split(strNodeName, ".", arrSplit);
		if (SplitCount>1)
		{
			m_DeleteQuestID = int(arrSplit[1]);
			m_DeleteNodeName = strNodeName;
		}
	}
	
	if (Len(m_DeleteNodeName)<1)
	{
		DialogShow(DIALOG_Notice, GetSystemMessage(1201));
		DialogSetID(1);
	}
	else
	{
		
		DialogShow(DIALOG_Warning, GetSystemMessage(182));
		DialogSetID(0);
	}
}

//////////////////////////////
//Add QuestInfo to TreeItem
function AddQuestInfo(string strParentName, int QuestID, int Level, int Completed)
{
	local XMLTreeNodeInfo	infNode;
	local XMLTreeNodeItemInfo	infNodeItem;
	local XMLTreeNodeInfo	infNodeClear;
	local XMLTreeNodeItemInfo	infNodeItemClear;
	local string		strRetName;
	local string		strTmp;
	
	//Quest Info
	local int			QuestMaxLevel;
	local int			QuestMinLevel;
	local int			nQuestType;
	local string		strTexture1;
	local string		strTexture2;
	local int			ItemCount;
	local array<int>		arrItemIDList;
	local array<int>		arrItemNumList;
	
	local int			i;
	local bool			bShowCompletionItem;
	local bool			bShowCompletionJournal;
	
	//Debug("ReceiveQuest ID:" $ QuestID $ " LEVEL:" $ Level $ " COM:" $ Completed);
	
	bShowCompletionItem = class'UIDATA_QUEST'.static.IsShowableItemNumQuest(QuestID, Level);
	bShowCompletionJournal = class'UIDATA_QUEST'.static.IsShowableJournalQuest(QuestID, Level);
	
	if (Level ==1)
	{
		//Get Quest Name
		strTmp = class'UIDATA_QUEST'.static.GetQuestName(QuestID);
		
		//////////////////////////////////////////////////////////////////////////////////////////////////////
		//Insert Node - with Button
		infNode = infNodeClear;
		infNode.strName = "" $ QuestID;
		infNode.Tooltip = MakeTooltipSimpleText(strTmp);
		infNode.bFollowCursor = true;
		infNode.bShowButton = 1;
		infNode.nTexBtnWidth = 14;
		infNode.nTexBtnHeight = 14;
		infNode.strTexBtnExpand = "L2UI_CH3.QUESTWND.QuestWndPlusBtn";
		infNode.strTexBtnCollapse = "L2UI_CH3.QUESTWND.QuestWndMinusBtn";
		infNode.strTexBtnExpand_Over = "L2UI_CH3.QUESTWND.QuestWndPlusBtn_over";
		infNode.strTexBtnCollapse_Over = "L2UI_CH3.QUESTWND.QuestWndMinusBtn_over";
		
		//Expand되었을때의 BackTexture설정
		//스트레치로 그리기 때문에 ExpandedWidth는 없다. 끝에서 -2만큼 배경을 그린다.
		infNode.nTexExpandedOffSetY = 1;		//OffSet
		infNode.nTexExpandedHeight = 13;		//Height
		infNode.nTexExpandedRightWidth = 32;		//오른쪽 그라데이션부분의 길이
		infNode.nTexExpandedLeftUWidth = 16; 		//스트레치로 그릴 왼쪽 텍스쳐의 UV크기
		infNode.nTexExpandedLeftUHeight = 13;
		infNode.nTexExpandedRightUWidth = 32; 	//스트레치로 그릴 오른쪽 텍스쳐의 UV크기
		infNode.nTexExpandedRightUHeight = 13;
		infNode.strTexExpandedLeft = "L2UI_CH3.ListCtrl.TextSelect";
		infNode.strTexExpandedRight = "L2UI_CH3.ListCtrl.TextSelect2";
		
		strRetName = class'UIAPI_TREECTRL'.static.InsertNode(m_WindowName $ ".MainTree", "root", infNode);
		if (Len(strRetName) < 1)
		{
			Log("ERROR: Can't insert node. Name: " $ infNode.strName);
			return;
		}
		
		//Node Tooltip Clear
		infNode.ToolTip.DrawList.Remove(0, infNode.ToolTip.DrawList.Length);
		
		//Insert Node Item - QuestName
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXT;
		infNodeItem.t_strText = strTmp;
		infNodeItem.nOffSetX = 5;
		infNodeItem.nOffSetY = 2;
		class'UIAPI_TREECTRL'.static.InsertNodeItem(m_WindowName $ ".MainTree", strRetName, infNodeItem);
		
		//Insert Node Item - QuestType
		nQuestType = 0;
		nQuestType = class'UIDATA_QUEST'.static.GetQuestType(QuestID, Level);
		if (nQuestType == 0)
		{
			strTexture1 = "L2UI_CH3.QUESTWND.QuestWndInfoIcon_4";
			strTexture2 = "L2UI_CH3.QUESTWND.QuestWndInfoIcon_1";
		}
		else if (nQuestType == 1)
		{
			strTexture1 = "L2UI_CH3.QUESTWND.QuestWndInfoIcon_4";
			strTexture2 = "L2UI_CH3.QUESTWND.QuestWndInfoIcon_2";
		}
		else if (nQuestType == 2)
		{
			strTexture1 = "L2UI_CH3.QUESTWND.QuestWndInfoIcon_3";
			strTexture2 = "L2UI_CH3.QUESTWND.QuestWndInfoIcon_1";
		}
		else if (nQuestType == 3)
		{
			strTexture1 = "L2UI_CH3.QUESTWND.QuestWndInfoIcon_3";
			strTexture2 = "L2UI_CH3.QUESTWND.QuestWndInfoIcon_2";
		}
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXTURE;
		infNodeItem.bStopMouseFocus = true;
		infNodeItem.nOffSetX = 5;
		infNodeItem.nOffSetY = 0;
		infNodeItem.u_nTextureWidth = 11;
		infNodeItem.u_nTextureHeight = 11;
		infNodeItem.u_strTexture = strTexture1;
		if (Len(strTexture1)>0) class'UIAPI_TREECTRL'.static.InsertNodeItem(m_WindowName $ ".MainTree", strRetName, infNodeItem);
		infNodeItem.nOffSetX = 0;
		infNodeItem.u_strTexture = strTexture2;
		if (Len(strTexture2)>0) class'UIAPI_TREECTRL'.static.InsertNodeItem(m_WindowName $ ".MainTree", strRetName, infNodeItem);
		
		//Insert Node Item - QuestLevel
		QuestMaxLevel = class'UIDATA_QUEST'.static.GetMaxLevel(QuestID, Level);
		QuestMinLevel = class'UIDATA_QUEST'.static.GetMinLevel(QuestID, Level);
		if (QuestMaxLevel>0 && QuestMinLevel>0)
		{
			strTmp = "(" $ GetSystemString(922) $ ":" $ QuestMinLevel $ "~" $ QuestMaxLevel $ ")";
		}
		else if (QuestMinLevel>0)
		{
			strTmp = "(" $ GetSystemString(922) $ ":" $ QuestMinLevel $ " " $ GetSystemString(859) $ ")";
		}
		else
		{
			strTmp = "(" $ GetSystemString(922) $ ":" $ GetSystemString(866) $ ")";
		}
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXT;
		infNodeItem.t_strText = strTmp;
		infNodeItem.t_color.R = 176;
		infNodeItem.t_color.G = 155;
		infNodeItem.t_color.B = 121;
		infNodeItem.t_color.A = 255;
		infNodeItem.bLineBreak = true;
		infNodeItem.nOffSetX = 22;
		infNodeItem.nOffSetY = 0;
		class'UIAPI_TREECTRL'.static.InsertNodeItem(m_WindowName $ ".MainTree", strRetName, infNodeItem);
		
		//Insert Node Item - Blank
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_BLANK;
		infNodeItem.b_nHeight = 7;
		class'UIAPI_TREECTRL'.static.InsertNodeItem(m_WindowName $ ".MainTree", strRetName, infNodeItem);
		
		strParentName = strRetName;
		m_CurNodeName = strRetName;
	}
		
	//////////////////////////////////////////////////////////////////////////////////////////////////////
	//Insert Node - JounalName with Button
	
	//Get Quest Jounal Name
	strTmp = class'UIDATA_QUEST'.static.GetQuestJournalName(QuestID, Level);
	
	infNode = infNodeClear;
	infNode.strName = "" $ Level $ "." $ Completed;
	infNode.Tooltip = MakeTooltipSimpleText(strTmp);
	infNode.bFollowCursor = true;
	infNode.nOffSetX = 7;
	infNode.bShowButton = 1;
	infNode.nTexBtnWidth = 14;
	infNode.nTexBtnHeight = 14;
	infNode.strTexBtnExpand = "L2UI_CH3.QUESTWND.QuestWndDownBtn";
	infNode.strTexBtnCollapse = "L2UI_CH3.QUESTWND.QuestWndUpBtn";
	infNode.strTexBtnExpand_Over = "L2UI_CH3.QUESTWND.QuestWndDownBtn_over";
	infNode.strTexBtnCollapse_Over = "L2UI_CH3.QUESTWND.QuestWndUpBtn_over";
	strRetName = class'UIAPI_TREECTRL'.static.InsertNode(m_WindowName $ ".MainTree", strParentName, infNode);
	if (Len(strRetName) < 1)
	{
		Log("ERROR: Can't insert node. Name: " $ infNode.strName);
		return;
	}
	
	//Node Tooltip Clear
	infNode.ToolTip.DrawList.Remove(0, infNode.ToolTip.DrawList.Length);
	
	//Insert Node Item - Jounal Name
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = strTmp;
	infNodeItem.nOffSetX = 5;
	class'UIAPI_TREECTRL'.static.InsertNodeItem(m_WindowName $ ".MainTree", strRetName, infNodeItem);
	
	//Get Quest Target Name
	strTmp = class'UIDATA_QUEST'.static.GetTargetName(QuestID, Level);
	if (Len(strTmp)>0)
	{
		//Insert Node Item - Show Target Icon
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXTURE;
		infNodeItem.bStopMouseFocus = true;
		infNodeItem.nOffSetX = 5;
		infNodeItem.nOffSetY = 0;
		infNodeItem.u_nTextureWidth = 11;
		infNodeItem.u_nTextureHeight = 11;
		infNodeItem.u_strTexture = "L2UI_CH3.QUESTWND.QuestWndInfoIcon_5";
		class'UIAPI_TREECTRL'.static.InsertNodeItem(m_WindowName $ ".MainTree", strRetName, infNodeItem);
	}
	
	//Insert Node Item - Journal 완료
	if (Completed>0 && bShowCompletionJournal)
	{
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXT;
		infNodeItem.t_strText = GetSystemString(898);
		infNodeItem.t_color.R = 176;
		infNodeItem.t_color.G = 155;
		infNodeItem.t_color.B = 121;
		infNodeItem.t_color.A = 255;
		infNodeItem.nOffSetX = 5;
		class'UIAPI_TREECTRL'.static.InsertNodeItem(m_WindowName $ ".MainTree", strRetName, infNodeItem);
	}
	
	//Insert Node Item - Blank
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_BLANK;
	infNodeItem.b_nHeight = 5;
	class'UIAPI_TREECTRL'.static.InsertNodeItem(m_WindowName $ ".MainTree", strRetName, infNodeItem);
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////
	//Insert Node - Jounal Description
	
	//Get Quest Jounal Description
	strTmp = class'UIDATA_QUEST'.static.GetQuestDescription(QuestID, Level);
	
	infNode = infNodeClear;
	infNode.strName = "desc";
	infNode.nOffSetX = 2;
	infNode.bDrawBackground = 1;
	infNode.bTexBackHighlight = 0;
	infNode.nTexBackWidth = 211;
	infNode.nTexBackUWidth = 211;
	infNode.nTexBackOffSetY = -2;
	infNode.nTexBackOffSetBottom = -2;
	strRetName = class'UIAPI_TREECTRL'.static.InsertNode(m_WindowName $ ".MainTree", strRetName, infNode);
	if (Len(strRetName) < 1)
	{
		Log("ERROR: Can't insert node. Name: " $ infNode.strName);
		return;
	}
	
	//Insert Node Item - Jounal Description
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = strTmp;
	infNodeItem.t_color.R = 140;
	infNodeItem.t_color.G = 140;
	infNodeItem.t_color.B = 140;
	infNodeItem.t_color.A = 255;
	infNodeItem.nOffSetX = 5;
	class'UIAPI_TREECTRL'.static.InsertNodeItem(m_WindowName $ ".MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - Item List
	strTmp = class'UIDATA_QUEST'.static.GetQuestItem(QuestID, Level);
	
	ParseInt( strTmp, "Max", ItemCount );
	arrItemIDList.Length = ItemCount;
	arrItemNumList.Length = ItemCount;
	for (i=0; i<ItemCount; i++)
	{
		ParseInt( strTmp, "ItemID_" $ i, arrItemIDList[i] );
		ParseInt( strTmp, "ItemNum_" $ i, arrItemNumList[i] );
	}
	for (i=0; i<ItemCount; i++)
	{
		//Get Item Texture Name
		strTmp = class'UIDATA_ITEM'.static.GetItemTextureName(arrItemIDList[i]);
		
		if (Len(strTmp)>0)
		{
			//Insert Node Item - Blank
			infNodeItem = infNodeItemClear;
			infNodeItem.eType = XTNITEM_BLANK;
			infNodeItem.b_nHeight = 4;
			class'UIAPI_TREECTRL'.static.InsertNodeItem(m_WindowName $ ".MainTree", strRetName, infNodeItem);
			
			//Insert Node Item - Icon BackTexture
			infNodeItem = infNodeItemClear;
			infNodeItem.eType = XTNITEM_TEXTURE;
			infNodeItem.nOffSetX = 4;
			infNodeItem.u_nTextureWidth = 34;
			infNodeItem.u_nTextureHeight = 34;
			infNodeItem.u_strTexture = "L2UI_CH3.Etc.menu_outline";
			class'UIAPI_TREECTRL'.static.InsertNodeItem(m_WindowName $ ".MainTree", strRetName, infNodeItem);
			
			//Insert Node Item - Icon Texture
			infNodeItem = infNodeItemClear;
			infNodeItem.eType = XTNITEM_TEXTURE;
			infNodeItem.nOffSetX = -33;
			infNodeItem.nOffSetY = 1;
			infNodeItem.u_nTextureWidth = 32;
			infNodeItem.u_nTextureHeight = 32;
			infNodeItem.u_strTexture = strTmp;
			class'UIAPI_TREECTRL'.static.InsertNodeItem(m_WindowName $ ".MainTree", strRetName, infNodeItem);
			
			//Get Item Name
			strTmp = class'UIDATA_ITEM'.static.GetItemName(arrItemIDList[i]);
			
			//Insert Node Item - Item Name
			infNodeItem = infNodeItemClear;
			infNodeItem.eType = XTNITEM_TEXT;
			infNodeItem.t_strText = strTmp;
			infNodeItem.t_color.R = 176;
			infNodeItem.t_color.G = 155;
			infNodeItem.t_color.B = 121;
			infNodeItem.t_color.A = 255;
			infNodeItem.nOffSetX = 5;
			infNodeItem.nOffSetY = 1;
			class'UIAPI_TREECTRL'.static.InsertNodeItem(m_WindowName $ ".MainTree", strRetName, infNodeItem);
			
			//Insert Node Item - Item Count
			infNodeItem = infNodeItemClear;
			infNodeItem.eType = XTNITEM_TEXT;
			if (arrItemNumList[i]>0)
			{
				if(Completed>0 && bShowCompletionItem)
				{
					strTmp = "(" $ GetSystemString(898) $ "/" $ arrItemNumList[i] $ ")";
				}
				else
				{
					strTmp = "(%s/" $ arrItemNumList[i] $ ")";
					m_arrItemNodeName.Insert(0, 1);	m_arrItemNodeName[0] = strRetName;
					m_arrItemClassID.Insert(0, 1);		m_arrItemClassID[0] = arrItemIDList[i];
					m_arrItemString.Insert(0, 1);		m_arrItemString[0] = strTmp;
					infNodeItem.t_nTextID = m_arrItemClassID.Length;
				}
			}
			else if (arrItemNumList[i]==0)
			{
				if (Completed>0 && bShowCompletionItem)
				{
					strTmp = "(" $ GetSystemString(898) $ "/" $ GetSystemString(858) $ ")";
				}
				else
				{
					strTmp = "(%s/" $ GetSystemString(858) $ ")";
					m_arrItemNodeName.Insert(0, 1);	m_arrItemNodeName[0] = strRetName;
					m_arrItemClassID.Insert(0, 1);		m_arrItemClassID[0] = arrItemIDList[i];
					m_arrItemString.Insert(0, 1);		m_arrItemString[0] = strTmp;
					infNodeItem.t_nTextID = m_arrItemClassID.Length;
				}
			}
			else
			{
				if (Completed>0 && bShowCompletionItem)
				{
					strTmp = "(" $ GetSystemString(898) $ "/" $ -arrItemNumList[i] $ GetSystemString(859) $ ")";
				}
				else
				{
					strTmp = "(%s/" $ -arrItemNumList[i] $ GetSystemString(859) $ ")";
					m_arrItemNodeName.Insert(0, 1);	m_arrItemNodeName[0] = strRetName;
					m_arrItemClassID.Insert(0, 1);		m_arrItemClassID[0] = arrItemIDList[i];
					m_arrItemString.Insert(0, 1);		m_arrItemString[0] = strTmp;
					infNodeItem.t_nTextID = m_arrItemClassID.Length;
				}
			}
			infNodeItem.t_strText = strTmp;
			infNodeItem.bLineBreak = true;
			infNodeItem.nOffSetX = 42;
			infNodeItem.nOffSetY = -16;
			class'UIAPI_TREECTRL'.static.InsertNodeItem(m_WindowName $ ".MainTree", strRetName, infNodeItem);
		}	
	}
	
	//Insert Node Item - Blank
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_BLANK;
	infNodeItem.b_nHeight = 9;
	class'UIAPI_TREECTRL'.static.InsertNodeItem(m_WindowName $ ".MainTree", strRetName, infNodeItem);
}

function InitQuestTooltip()
{
	//Custom Tooltip
	local CustomTooltip TooltipInfo;
		
	TooltipInfo.DrawList.length = 10;
	
	TooltipInfo.DrawList[0].eType = DIT_TEXTURE;
	TooltipInfo.DrawList[0].u_nTextureWidth = 16;
	TooltipInfo.DrawList[0].u_nTextureHeight = 16;
	TooltipInfo.DrawList[0].u_strTexture = "L2UI_CH3.QuestWnd.QuestWndInfoIcon_1";
	
	TooltipInfo.DrawList[1].eType = DIT_TEXT;
	TooltipInfo.DrawList[1].nOffSetX = 5;
	TooltipInfo.DrawList[1].t_bDrawOneLine = true;
	TooltipInfo.DrawList[1].t_ID = 861;
	
	TooltipInfo.DrawList[2].eType = DIT_TEXTURE;
	TooltipInfo.DrawList[2].nOffSetY = 2;
	TooltipInfo.DrawList[2].u_nTextureWidth = 16;
	TooltipInfo.DrawList[2].u_nTextureHeight = 16;
	TooltipInfo.DrawList[2].u_strTexture = "L2UI_CH3.QuestWnd.QuestWndInfoIcon_2";
	TooltipInfo.DrawList[2].bLineBreak = true;
	
	TooltipInfo.DrawList[3].eType = DIT_TEXT;
	TooltipInfo.DrawList[3].nOffSetY = 2;
	TooltipInfo.DrawList[3].nOffSetX = 5;
	TooltipInfo.DrawList[3].t_bDrawOneLine = true;
	TooltipInfo.DrawList[3].t_ID = 862;
	
	TooltipInfo.DrawList[4].eType = DIT_TEXTURE;
	TooltipInfo.DrawList[4].nOffSetY = 2;
	TooltipInfo.DrawList[4].u_nTextureWidth = 16;
	TooltipInfo.DrawList[4].u_nTextureHeight = 16;
	TooltipInfo.DrawList[4].u_strTexture = "L2UI_CH3.QuestWnd.QuestWndInfoIcon_3";
	TooltipInfo.DrawList[4].bLineBreak = true;
	
	TooltipInfo.DrawList[5].eType = DIT_TEXT;
	TooltipInfo.DrawList[5].nOffSetY = 2;
	TooltipInfo.DrawList[5].nOffSetX = 5;
	TooltipInfo.DrawList[5].t_bDrawOneLine = true;
	TooltipInfo.DrawList[5].t_ID = 863;
	
	TooltipInfo.DrawList[6].eType = DIT_TEXTURE;
	TooltipInfo.DrawList[6].nOffSetY = 2;
	TooltipInfo.DrawList[6].u_nTextureWidth = 16;
	TooltipInfo.DrawList[6].u_nTextureHeight = 16;
	TooltipInfo.DrawList[6].u_strTexture = "L2UI_CH3.QuestWnd.QuestWndInfoIcon_4";
	TooltipInfo.DrawList[6].bLineBreak = true;
	
	TooltipInfo.DrawList[7].eType = DIT_TEXT;
	TooltipInfo.DrawList[7].nOffSetY = 2;
	TooltipInfo.DrawList[7].nOffSetX = 5;
	TooltipInfo.DrawList[7].t_bDrawOneLine = true;
	TooltipInfo.DrawList[7].t_ID = 864;
	
	TooltipInfo.DrawList[8].eType = DIT_TEXTURE;
	TooltipInfo.DrawList[8].nOffSetY = 2;
	TooltipInfo.DrawList[8].u_nTextureWidth = 16;
	TooltipInfo.DrawList[8].u_nTextureHeight = 16;
	TooltipInfo.DrawList[8].u_strTexture = "L2UI_CH3.QuestWnd.QuestWndInfoIcon_5";
	TooltipInfo.DrawList[8].bLineBreak = true;
	
	TooltipInfo.DrawList[9].eType = DIT_TEXT;
	TooltipInfo.DrawList[9].nOffSetY = 2;
	TooltipInfo.DrawList[9].nOffSetX = 5;
	TooltipInfo.DrawList[9].t_bDrawOneLine = true;
	TooltipInfo.DrawList[9].t_ID = 865;

	m_QuestTooltip.SetTooltipCustomType(TooltipInfo);
}

//언어 변경 처리
function HandleLanguageChanged()
{
	if (class'UIAPI_WINDOW'.static.IsShowWindow(m_WindowName))
	{
		ShowQuestList();
	}	
}

defaultproperties
{
     m_WindowName="QuestTreeWnd"
}
