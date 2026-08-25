class QuestListWnd extends UIScript;

//Handle List
var WindowHandle	Me;
var ListCtrlHandle	lstQuest;
var TextureHandle	QuestTooltip;

function OnLoad()
{
	RegisterEvent( EV_QuestInfoStart );
	RegisterEvent( EV_QuestInfo );
	
	//Init Handle
	Me = GetHandle( "QuestListWnd" );
	QuestTooltip = TextureHandle( GetHandle( "QuestListWnd.QuestTooltip" ) );
	lstQuest = ListCtrlHandle( GetHandle( "QuestListWnd.lstQuest" ) );
	
	//Init Tooltip
	InitQuestTooltip();
}

function OnEvent(int Event_ID, string param)
{
	switch( Event_ID )
	{
	case EV_QuestInfoStart:
		HandleQuestInfoStart();
		break;
	case EV_QuestInfo:
		HandleQuestInfo(param);
		break;
	}
}

function OnClickButton( string strID )
{	
	switch( strID )
	{
	case "btnLoc":
		ShowQuestTarget();
		break;
	}
}

//퀘스트 리스트 시작
function HandleQuestInfoStart()
{
	lstQuest.DeleteAllItem();
	Me.ShowWindow();
	Me.SetFocus();
}

//퀘스트 리스트를 추가
function HandleQuestInfo(string param)
{
	local int		QuestID;
	local string	QuestName;
	local string	QuestRequirement;
	local string	QuestLevel;
	local int		QuestType;
	local string	QuestNpcName;
	local string	QuestDecription;
	
	local LVDataRecord	record;
	
	ParseInt(param, "QuestID", QuestID);
	ParseString(param, "QuestName", QuestName);
	ParseString(param, "QuestRequirement", QuestRequirement);
	ParseString(param, "QuestLevel", QuestLevel);
	ParseInt(param, "QuestType", QuestType);
	ParseString(param, "QuestNpcName", QuestNpcName);
	ParseString(param, "QuestDecription", QuestDecription);
	
	record.LVDataList.Length = 5;
	
	record.LVDataList[0].szData = QuestName;			//퀘스트 이름
	record.LVDataList[1].szData = QuestRequirement;		//수행조건
	record.LVDataList[2].szData = QuestLevel;			//레벨대
	record.LVDataList[3].nTextureWidth = 16;
	record.LVDataList[3].nTextureHeight = 16;
	switch( QuestType )
	{
	case 0:
	case 2:
		record.LVDataList[3].szTexture = "L2UI_CH3.QUESTWND.QuestWndInfoIcon_1";
		break;
	case 1:
	case 3:
		record.LVDataList[3].szTexture = "L2UI_CH3.QUESTWND.QuestWndInfoIcon_2";
		break;
	}
	record.LVDataList[3].szData = String(QuestType);	//반복성
	record.LVDataList[4].szData = QuestNpcName;			//의뢰자
	record.szReserved = QuestDecription;				//설명
	record.nReserved1 = QuestID;
	
	lstQuest.InsertRecord(record);	
}

function ShowQuestTarget()
{
	local int		idx;
	local int		QuestID;
	local int		NpcID;
	local string	strTargetName;
	local vector	vTargetPos;
	
	local LVDataRecord record;
	
	idx = lstQuest.GetSelectedIndex();
	if (idx>-1)
	{
		record = lstQuest.GetRecord(idx);
		QuestID = record.nReserved1;
	}
	if (QuestID>0)
	{
		NpcID = class'UIDATA_QUEST'.static.GetStartNPCID(QuestID, 1);
		strTargetName = class'UIDATA_NPC'.static.GetNPCName(NpcID);
		vTargetPos = class'UIDATA_QUEST'.static.GetStartNPCLoc(QuestID, 1);
		Debug("QuestID=" $ QuestID);
		Debug("strTargetName=" $ strTargetName);
		Debug("vTargetPos.x=" $ vTargetPos.x);
		Debug("vTargetPos.y=" $ vTargetPos.y);
		Debug("vTargetPos.z=" $ vTargetPos.z);
		
		if (Len(strTargetName)>0)
			class'QuestAPI'.static.SetQuestTargetInfo(true, true, true, strTargetName, vTargetPos, QuestID);
	}
}

function InitQuestTooltip()
{
	//Custom Tooltip
	local CustomTooltip TooltipInfo;
		
	TooltipInfo.DrawList.length = 4;
	
	TooltipInfo.DrawList[0].eType = DIT_TEXTURE;
	TooltipInfo.DrawList[0].u_nTextureWidth = 16;
	TooltipInfo.DrawList[0].u_nTextureHeight = 16;
	TooltipInfo.DrawList[0].u_strTexture = "L2UI_CH3.QuestWnd.QuestWndInfoIcon_1";
	
	TooltipInfo.DrawList[1].eType = DIT_TEXT;
	TooltipInfo.DrawList[1].nOffSetX = 5;
	TooltipInfo.DrawList[1].t_bDrawOneLine = true;
	TooltipInfo.DrawList[1].t_strText = GetSystemString( 861 );
	
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
	TooltipInfo.DrawList[3].t_strText = GetSystemString( 862 );
	
	QuestTooltip.SetTooltipCustomType(TooltipInfo);
}
