class SSQMainBoard extends UIScript;

//////////////////////////////////////////////////////////////////////////////
// SSQ CONST
//////////////////////////////////////////////////////////////////////////////
const NC_PARTYMEMBER_MAX = 9;

//Server Request Type
const SSQR_STATUS = 1;
const SSQR_MAINEVENT = 2;
const SSQR_SEALSTATUS = 3;
const SSQR_PREINFO = 4;

//Team Name
const SSQT_NONE = 0;
const SSQT_DUSK = 1;	//황혼팀
const SSQT_DAWN = 2;	//새벽팀

//Main Event ID
const SSQE_TIMEATTACK = 0;	//타임어택이벤트(어둠의제전)

//Seal Name List
const SSQS_NONE = 0;	
const SSQS_GREED = 1;	//탐욕의 봉인
const SSQS_REVEAL = 2;	//계시의 봉인
const SSQS_STRIFE = 3;	//전란의 봉인

//////////////////////////////////////////////////////////////////////////////
// SSQ Structure
//////////////////////////////////////////////////////////////////////////////
//SSQ Status
struct SSQStatusInfo
{
	var int m_nSSQStatus;
	var int m_nSSQTeam;
	var int m_nSelectedSeal;
	var int m_nContribution;
    
	var int m_nTeam1HuntingMark;
	var int m_nTeam2HuntingMark;
	var int m_nTeam1MainEventMark;
	var int m_nTeam2MainEventMark;

	var int m_nTeam1Per;
	var int m_nTeam2Per;

	var int m_nTeam1TotalMark;
	var int m_nTeam2TotalMark;

	var int m_nPeriod;
	var int m_nMsgNum1;
	var int m_nMsgNum2;
	var int m_nSealStoneAdena;
};
var SSQStatusInfo g_sinfo;

//SSQ Status
struct SSQPreStatusInfo
{
	var int		m_nWinner;
	var int		m_nRoomNum;
	var array<int>	m_nSealNumArray;
	var array<int>	m_nWinnerArray;
	var array<int>	m_nMsgArray;
};
var SSQPreStatusInfo g_sinfopre;

//SSQ Main Event
struct SSQMainEventInfo
{
	var int m_nSSQStatus;
	var int m_nEventType;
	var int m_nEventNo;
	var int m_nWinPoint;
	var int m_nTeam1Score;
	var int m_nTeam2Score;
	var string m_Team1MemberName[NC_PARTYMEMBER_MAX];
	var string m_Team2MemberName[NC_PARTYMEMBER_MAX];
};

//////////////////////////////////////////////////////////////////////////////
// SSQ 각종 Flag
//////////////////////////////////////////////////////////////////////////////

//Status Preview
var bool		m_bShowPreInfo;		//결과예상

//처음 한번만 화면을 표시하기 위한 Flag
var bool		m_bRequest_SealStatus;	//봉인상태
var bool		m_bRequest_MainEvent;	//어둠의제전

function OnLoad()
{
	RegisterEvent( EV_SSQStatus );
	RegisterEvent( EV_SSQPreInfo);
	RegisterEvent( EV_SSQMainEvent);
	RegisterEvent( EV_SSQSealStatus );
	
	m_bRequest_SealStatus = false;
	m_bRequest_MainEvent = false;
	
	//텍스트박스 수정
	class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtSS", GetSystemString(833) $ " - ");
	
	//전체상황을 보여줌
	m_bShowPreInfo = false;
	SetSSQStatus();
}

function OnShow()
{
	//0번 Tab을 보여줌
	class'UIAPI_TABCTRL'.static.SetTopOrder("SSQMainBoard.TabCtrl", 0, true);
	
	//소리
	PlayConsoleSound(IFST_WINDOW_OPEN);
	
	//탭을 클릭하면 Child가 전부 Show되버리니, 다시 한번!
	SetSSQStatus();
}

function OnHide()
{
	m_bRequest_SealStatus = false;
	m_bRequest_MainEvent = false;
	
	m_bShowPreInfo = false;	// 결과예상에서 창을 닫아도 다시 열때는 상황창을 보여준다.
	
	//각 Tab의 초기화
	class'UIAPI_TREECTRL'.static.Clear("SSQMainBoard.me_MainTree");
	class'UIAPI_TREECTRL'.static.Clear("SSQMainBoard.ss_MainTree");
}

function OnEvent(int Event_ID, string param)
{
	local int i;
	local int j;
	local int k;
	local int l;
	
	local string strTmp;
	local int m_nSSQStatus;
	
	//SSQ Seal Status
	local int m_nNeedPoint1;
	local int m_nNeedPoint2;
	local int sealnum;
	local int m_nSealID;
	local int m_nOwnerTeamID;
	local int m_nTeam1Mark;
	local int m_nTeam2Mark;
	
	//SSQ Main Event
	local SSQMainEventInfo info;
	local int eventnum;
	local int nEventType;
	local int roomnum;
	local int team1num;
	local int team2num;
	
	//전체상황
	if (Event_ID == EV_SSQStatus)
	{
		ParseInt( param, "SuccessRate", g_sinfo.m_nSSQStatus );
		ParseInt( param, "Period", g_sinfo.m_nPeriod );	
		ParseInt( param, "MsgNum1", g_sinfo.m_nMsgNum1 );	
		ParseInt( param, "MsgNum2", g_sinfo.m_nMsgNum2 );	
		ParseInt( param, "SSQTeam", g_sinfo.m_nSSQTeam );
		ParseInt( param, "SelectedSeal", g_sinfo.m_nSelectedSeal);
		ParseInt( param, "Contribution", g_sinfo.m_nContribution);
		ParseInt( param, "SealStoneAdena", g_sinfo.m_nSealStoneAdena);	
		ParseInt( param, "Team1HuntingMark", g_sinfo.m_nTeam1HuntingMark);	//황혼
		ParseInt( param, "Team1MainEventMark", g_sinfo.m_nTeam1MainEventMark );
		ParseInt( param, "Team2HuntingMark", g_sinfo.m_nTeam2HuntingMark);	//새벽
		ParseInt( param, "Team2MainEventMark", g_sinfo.m_nTeam2MainEventMark);
		ParseInt( param, "Team1Per", g_sinfo.m_nTeam1Per);			//황혼 점유율
		ParseInt( param, "Team2Per", g_sinfo.m_nTeam2Per);			//새벽 점유율
		ParseInt( param, "Team1TotalMark", g_sinfo.m_nTeam1TotalMark);	//황혼 총점수
		ParseInt( param, "Team2TotalMark", g_sinfo.m_nTeam2TotalMark);	//새벽 총점수
		
		SetSSQStatusInfo();
		
		//전체상황 패킷이면, 결과예상의 윗부분(?)도 갱신해줘야한다.
		SetSSQPreInfo();
		
		//Show Window
		class'UIAPI_WINDOW'.static.ShowWindow("SSQMainBoard");
		class'UIAPI_WINDOW'.static.SetFocus("SSQMainBoard");
	}
	//결과예상
	else if (Event_ID == EV_SSQPreInfo)
	{
		//일단 클리어
		ClearSSQPreInfo();
		
		ParseInt(param, "Winner", g_sinfopre.m_nWinner);
		ParseInt(param, "RoomNum", g_sinfopre.m_nRoomNum);
		for (i=0; i<g_sinfopre.m_nRoomNum; i++)
		{
			g_sinfopre.m_nSealNumArray.Insert(g_sinfopre.m_nSealNumArray.Length, 1);
			ParseInt( param, "SealNum_" $ i, g_sinfopre.m_nSealNumArray[g_sinfopre.m_nSealNumArray.Length-1] );
			g_sinfopre.m_nWinnerArray.Insert(g_sinfopre.m_nWinnerArray.Length, 1);
			ParseInt( param, "Winner_" $ i, g_sinfopre.m_nWinnerArray[g_sinfopre.m_nWinnerArray.Length-1] );
			g_sinfopre.m_nMsgArray.Insert(g_sinfopre.m_nMsgArray.Length, 1);
			ParseInt( param, "Msg_" $ i, g_sinfopre.m_nMsgArray[g_sinfopre.m_nMsgArray.Length-1] );
		}
		
		SetSSQPreInfo();
	}
	//어둠의 제전
	else if (Event_ID == EV_SSQMainEvent)
	{
		ParseInt( param, "SSQStatus", m_nSSQStatus);
		info.m_nSSQStatus = m_nSSQStatus;
		ParseInt(param, "EventNum", eventnum);
		for (i=0; i<eventnum; i++)
		{
			ParseInt( param, "EventType_" $ i, nEventType);
			info.m_nEventType = nEventType;
			ParseInt( param, "RoomNum_" $ i, roomnum );
			for (j=0; j<roomnum; j++)
			{
				ParseInt( param, "EventNo_" $ i $ "_" $ j, info.m_nEventNo );
				ParseInt( param, "WinPoint_" $ i $ "_" $ j, info.m_nWinPoint );
				ParseInt( param, "Team2Score_" $ i $ "_" $ j, info.m_nTeam2Score );
				ParseInt( param, "Team2Num_" $ i $ "_" $ j, team2num);
				for (k=0; k<team2num; k++)
				{
					ParseString(param, "Team2MemberName_" $ i $ "_" $ j $ "_" $ k, strTmp);
					if (Len(strTmp)>0) info.m_Team2MemberName[k] = strTmp;
				}
				
				ParseInt( param, "Team1Score_" $ i $ "_" $ j, info.m_nTeam1Score);
				ParseInt( param, "Team1Num_" $ i $ "_" $ j, team1num );
		 		for (l=0; l<team1num; l++)
				{
					ParseString(param, "Team1MemberName_" $ i $ "_" $ j $ "_" $ l, strTmp);
					if (Len(strTmp)>0) info.m_Team1MemberName[l] = strTmp;
				}
				
				AddSSQMainEvent(info);
				
				//Clear
				ClearSSQMainEventInfo(info);
				info.m_nSSQStatus = m_nSSQStatus;
				info.m_nEventType = nEventType;
			}
		}
	}
	//봉인상황
	else if (Event_ID == EV_SSQSealStatus)
	{	
		ParseInt( param, "SSQStatus", m_nSSQStatus);
		ParseInt( param, "NeedPoint1", m_nNeedPoint1);
		ParseInt( param, "NeedPoint2", m_nNeedPoint2);
		ParseInt( param, "SealNum", sealnum);
		for(i=0; i<sealnum; i++)
		{
		 	 ParseInt( param, "SealID_" $ i, m_nSealID);
			 ParseInt( param, "OwnerTeamID_" $ i, m_nOwnerTeamID);
			 ParseInt( param, "Team2Mark_" $ i, m_nTeam2Mark);
			 ParseInt( param, "Team1Mark_" $ i, m_nTeam1Mark);
			
			AddSSQSealStatus(m_nSSQStatus, m_nNeedPoint1, m_nNeedPoint2, m_nSealID,  m_nOwnerTeamID, m_nTeam1Mark, m_nTeam2Mark);
			//debug (" aha / " $ m_nSSQStatus $" aha / " $ m_nNeedPoint1 $" aha / " $ m_nNeedPoint2 $" aha / " $ m_nSealID $" aha / " $ m_nOwnerTeamID $" aha / " $ m_nTeam1Mark $ "aha / " $ m_nTeam2Mark );
		}
	}
}

function OnClickButton( string strID )
{
	switch( strID )
	{
	case "s_btnRenew":
		if (m_bShowPreInfo)
		{
			class'SSQAPI'.static.RequestSSQStatus(SSQR_PREINFO);	//EV_SSQPreInfo 가 이벤트가 날라옴
		}
		else
		{
			class'SSQAPI'.static.RequestSSQStatus(SSQR_STATUS);	//EV_SSQStatus 가 이벤트가 날라옴
		}
		break;
	case "s_btnPreview":
		m_bShowPreInfo = !m_bShowPreInfo;
		if (m_bShowPreInfo)
		{
			class'SSQAPI'.static.RequestSSQStatus(SSQR_PREINFO);	//EV_SSQPreInfo 가 이벤트가 날라옴
		}
		SetSSQStatus();
		break;
	case "ss_btnRenew":
		ShowSSQSealStatus();
		break;
	case "me_btnRenew":
		ShowSSQMainEvent();
		break;
	case "TabCtrl0":
		SetSSQStatus();	//탭을 클릭하면 Child가 모두 Show가 되어버려서 다시 해줘야한다.
		break;
	case "TabCtrl1":
		//어둠의 제전 상태 표시 - 처음 한번만 표시한다
		if (!m_bRequest_MainEvent)
		{
			ShowSSQMainEvent();
			m_bRequest_MainEvent = true;
		}
		break;
	case "TabCtrl2":
		//봉인 상태 표시 - 처음 한번만 표시한다
		if (!m_bRequest_SealStatus)
		{
			ShowSSQSealStatus();
			m_bRequest_SealStatus = true;
		}
		break;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	SSQ Status
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////
//현재 버튼 상태에 맞게 화면 표시
function SetSSQStatus()
{
	if(m_bShowPreInfo)
	{
		class'UIAPI_BUTTON'.static.SetButtonName("SSQMainBoard.s_btnPreview", 939);
		class'UIAPI_WINDOW'.static.ShowWindow("SSQMainBoard.SSQStatusWnd_Preview");
		class'UIAPI_WINDOW'.static.HideWindow("SSQMainBoard.SSQStatusWnd_Status");
	}
	else
	{
		class'UIAPI_BUTTON'.static.SetButtonName("SSQMainBoard.s_btnPreview", 937);
		class'UIAPI_WINDOW'.static.ShowWindow("SSQMainBoard.SSQStatusWnd_Status");
		class'UIAPI_WINDOW'.static.HideWindow("SSQMainBoard.SSQStatusWnd_Preview");
	}
}

//////////////////////
//Set SSQ Status Info
function SetSSQStatusInfo()
{
	//주기
	class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtTime", g_sinfo.m_nPeriod $ " " $ GetSystemString(934));
	//경쟁기간입니다
	//(다음주 월요일 6시까지)
	if (g_sinfo.m_nMsgNum1>0)
	{
		//debug("sidhd : " $ g_sinfo.m_nMsgNum1);
		class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtSta1", GetSystemMessage(g_sinfo.m_nMsgNum1));
	}
	else
	{
		class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtSta1", "");
	}
	if (g_sinfo.m_nMsgNum2 >0)
	{
		class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtSta2", GetSystemMessage(g_sinfo.m_nMsgNum2));
	}
	else
	{
		class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtSta2", "");
	}
	//소속 결사단 이름
	class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtMyTeamName", GetSSQTeamName(g_sinfo.m_nSSQTeam));
	//선택 봉인 이름
	class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtMySealName", GetSSQSealName(g_sinfo.m_nSelectedSeal));
	//바쳐진 봉인석 갯수
	class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtMySealStoneCount", g_sinfo.m_nContribution $ GetSystemString(932));
	//바쳐진 봉인석 갯수(to 고아데나)
	class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtMySealStoneCountAdena", "(" $ g_sinfo.m_nSealStoneAdena $ GetSystemString(933) $ ")");
	//현재집계?
	if (g_sinfo.m_nSSQStatus==3)
	{
		class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtAllStaCur", " - " $ GetSystemString(838));
	}
	else
	{
		class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtAllStaCur", " - " $ GetSystemString(837));
	}
	//여명의 군주들/황혼의 혁명군
	class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtAllDawn", GetSSQTeamName(SSQT_DAWN));
	class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtAllDusk", GetSSQTeamName(SSQT_DUSK));
	//여명의 군주들/황혼의 혁명군(퍼센트)
	class'UIAPI_WINDOW'.static.SetWindowSize("SSQMainBoard.texDawnValue", int(g_sinfo.m_nTeam2Per * 150.0f / 100.0f), 11);
	class'UIAPI_WINDOW'.static.SetWindowSize("SSQMainBoard.texDuskValue", int(g_sinfo.m_nTeam1Per * 150.0f / 100.0f), 11);
	
	//전체점수
	
	//여명의 군주들/황혼의 혁명군
	class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtPointDawn", GetSSQTeamName(SSQT_DAWN));
	class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtPointDusk", GetSSQTeamName(SSQT_DUSK));
	//여명 점수
	class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtPointDawn1", "" $ g_sinfo.m_nTeam2HuntingMark);
	class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtPointDawn2", "" $ g_sinfo.m_nTeam2MainEventMark);
	class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtPointDawn3", "" $ g_sinfo.m_nTeam2TotalMark);
	//황혼 점수
	class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtPointDusk1", "" $ g_sinfo.m_nTeam1HuntingMark);
	class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtPointDusk2", "" $ g_sinfo.m_nTeam1MainEventMark);
	class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.txtPointDusk3", "" $ g_sinfo.m_nTeam1TotalMark);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	SSQ PreInfo
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////
//Clear SSQ Pre Info
function ClearSSQPreInfo()
{
	g_sinfopre.m_nWinner = 0;
	g_sinfopre.m_nRoomNum = 0;
	g_sinfopre.m_nSealNumArray.Remove(0, g_sinfopre.m_nSealNumArray.Length);
	g_sinfopre.m_nWinnerArray.Remove(0, g_sinfopre.m_nWinnerArray.Length);
	g_sinfopre.m_nMsgArray.Remove(0, g_sinfopre.m_nMsgArray.Length);
}

////////////////////
//Set SSQ Pre Info
function SetSSQPreInfo()
{
	local string strTmp;
	
	//ex) 황혼의 혁명군 승리
	if (g_sinfopre.m_nWinner == 1)
	{
		strTmp = GetSSQTeamName(SSQT_DUSK);
		class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.pre_txtWinTeam", strTmp $ " " $ GetSystemString(828));
	}
	else if (g_sinfopre.m_nWinner == 2)
	{
		strTmp = GetSSQTeamName(SSQT_DAWN);
		class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.pre_txtWinTeam", strTmp $ " " $ GetSystemString(828));
	}
	else
	{
		class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.pre_txtWinTeam", "");
	}
	//설명
	if (g_sinfopre.m_nWinner != 0)
	{
		strTmp = MakeFullSystemMsg(GetSystemMessage(1288), strTmp, "");
	}
	else
	{
		strTmp = GetSystemMessage(1293);
	}
	class'UIAPI_TEXTBOX'.static.SetText("SSQMainBoard.pre_txtWinText", strTmp);
	//봉인 상태 결과 예상
	AddSSQPreInfoSealStatus();
}

//////////////////////////////////////
//Add SSQ Pre Seal Status TreeItem
function AddSSQPreInfoSealStatus()
{
	local int			i;
	
	local int			nSealNum;
	local int			nWinner;
	local int			nMsgNum;
	
	local XMLTreeNodeInfo	infNode;
	local XMLTreeNodeItemInfo	infNodeItem;
	local XMLTreeNodeInfo	infNodeClear;
	local XMLTreeNodeItemInfo	infNodeItemClear;
	local string		strRetName;
	
	// 0. 초기화
	class'UIAPI_TREECTRL'.static.Clear("SSQMainBoard.pre_MainTree");
	
	// 1. 데이타가 없으면 Hide시키고 종료
	if (g_sinfopre.m_nSealNumArray.Length<1)
	{
		class'UIAPI_WINDOW'.static.HideWindow("SSQMainBoard.pre_MainTree");
		return;
	}
	else
	{
		class'UIAPI_WINDOW'.static.ShowWindow("SSQMainBoard.pre_MainTree");
	}
	
	// 2. Add Root Item
	infNode.strName = "root";
	strRetName = class'UIAPI_TREECTRL'.static.InsertNode("SSQMainBoard.pre_MainTree", "", infNode);
	if (Len(strRetName) < 1)
	{
		debug("ERROR: Can't insert root node. Name: " $ infNode.strName);
		return;
	}
	
	// 3 . Insert Root Node - with no Button
	infNode = infNodeClear;
	infNode.strName = "node";
	infNode.nOffSetX = 2;
	infNode.nOffSetY = 3;
	infNode.bShowButton = 0;
	infNode.bDrawBackground = 1;
	infNode.bTexBackHighlight = 1;
	infNode.nTexBackHighlightHeight = 17;
	infNode.nTexBackWidth = 240;
	infNode.nTexBackUWidth = 211;
	infNode.nTexBackOffSetX = -3;
	infNode.nTexBackOffSetY = -4;
	infNode.nTexBackOffSetBottom = 2;
	strRetName = class'UIAPI_TREECTRL'.static.InsertNode("SSQMainBoard.pre_MainTree", "root", infNode);
	if (Len(strRetName) < 1)
	{
		debug("ERROR: Can't insert node. Name: " $ infNode.strName);
		return;
	}
	
	for(i=0; i<g_sinfopre.m_nSealNumArray.Length; i++)
	{
		nSealNum = g_sinfopre.m_nSealNumArray[i];
		nWinner = g_sinfopre.m_nWinnerArray[i];
		nMsgNum = g_sinfopre.m_nMsgArray[i];
		
		//Insert Node Item - Seal Name	
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXT;
		infNodeItem.t_strText = GetSSQSealName(nSealNum) $ " : ";
		infNodeItem.nOffSetX = 4;
		infNodeItem.nOffSetY = 0;
		infNodeItem.t_color.R = 128;
		infNodeItem.t_color.G = 128;
		infNodeItem.t_color.B = 128;
		infNodeItem.t_color.A = 255;
		class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.pre_MainTree", strRetName, infNodeItem);
		
		//Insert Node Item - 소유팀
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXT;
		if (nWinner == 1)
		{
			infNodeItem.t_strText = GetSSQTeamName(SSQT_DUSK);
		}
		else if (nWinner == 2)
		{
			infNodeItem.t_strText = GetSSQTeamName(SSQT_DAWN);
		}
		else
		{
			infNodeItem.t_strText = GetSystemString(936);
		}
		infNodeItem.nOffSetX = 0;
		infNodeItem.nOffSetY = 0;
		infNodeItem.t_color.R = 176;
		infNodeItem.t_color.G = 155;
		infNodeItem.t_color.B = 121;
		infNodeItem.t_color.A = 255;
		class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.pre_MainTree", strRetName, infNodeItem);
		
		//Insert Node Item - 설명
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXT;
		infNodeItem.t_strText = GetSystemMessage(nMsgNum);
		infNodeItem.bLineBreak = true;
		infNodeItem.nOffSetX = 8;
		infNodeItem.nOffSetY = 6;
		infNodeItem.t_color.R = 128;
		infNodeItem.t_color.G = 128;
		infNodeItem.t_color.B = 128;
		infNodeItem.t_color.A = 255;
		class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.pre_MainTree", strRetName, infNodeItem);
		
		if (i != g_sinfopre.m_nSealNumArray.Length-1)
		{
			//Insert Node Item - Blank
			infNodeItem = infNodeItemClear;
			infNodeItem.eType = XTNITEM_BLANK;
			infNodeItem.b_nHeight = 20;
			class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.pre_MainTree", strRetName, infNodeItem);
		}
	}
}
	

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	SSQ Main Event
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////
//Clear SSQ Main Event Info
function ClearSSQMainEventInfo(out SSQMainEventInfo info)
{
	local int i;
	for (i=0; i<NC_PARTYMEMBER_MAX; i++)
	{
		info.m_Team1MemberName[i] = "";
		info.m_Team2MemberName[i] = "";
	}
}

/////////////////////////////
//Request SSQ Main Event
function ShowSSQMainEvent()
{
	local XMLTreeNodeInfo	infNode;
	local string		strRetName;
	
	// 0. 초기화
	class'UIAPI_TREECTRL'.static.Clear("SSQMainBoard.me_MainTree");
		
	// 1. Add Root Item
	infNode.strName = "root";
	infNode.nOffSetX = 3;
	infNode.nOffSetY = 5;
	strRetName = class'UIAPI_TREECTRL'.static.InsertNode("SSQMainBoard.me_MainTree", "", infNode);
	
	if (Len(strRetName) < 1)
	{
		debug("ERROR: Can't insert root node. Name: " $ infNode.strName);
		return;
	}
	
	// 2. Request SSQ Main Event
	class'SSQAPI'.static.RequestSSQStatus(SSQR_MAINEVENT);		//EV_SSQMainEvent 이벤트가 날라옴
}

//////////////////////////////
//Add MainEvent to TreeItem
function AddSSQMainEvent(SSQMainEventInfo info)
{
	local int			i;
	
	local XMLTreeNodeInfo	infNode;
	local XMLTreeNodeItemInfo	infNodeItem;
	local XMLTreeNodeInfo	infNodeClear;
	local XMLTreeNodeItemInfo	infNodeItemClear;
	local string		strRetName;
	local string		strNodeName;
	local string		strTmp;
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////
	//Event Type Node
	
	//* 일단 이미 추가되어 있는 Event Type인지 체크한다.
	// (현재는 "어둠의제전"밖에 없다)
	strNodeName = "root." $ info.m_nEventType;
	if (class'UIAPI_TREECTRL'.static.IsNodeNameExist("SSQMainBoard.me_MainTree", strNodeName))
	{
		strRetName = strNodeName;
	}
	else
	{
		//////////////////////////////////////////////////////////////////////////////////////////////////////
		//Insert Node - with Button
		infNode = infNodeClear;
		infNode.strName = "" $ info.m_nEventType;
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
		
		strRetName = class'UIAPI_TREECTRL'.static.InsertNode("SSQMainBoard.me_MainTree", "root", infNode);
		if (Len(strRetName) < 1)
		{
			debug("ERROR: Can't insert node. Name: " $ infNode.strName);
			return;
		}
		
		//Insert Node Item - Event Name
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXT;
		if (info.m_nEventType == SSQE_TIMEATTACK)
		{
			infNodeItem.t_strText = GetSystemString(845);
		}
		else
		{
			infNodeItem.t_strText = GetSystemString(27);	//없음
		}
		infNodeItem.nOffSetX = 4;
		infNodeItem.nOffSetY = 2;
		class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.me_MainTree", strRetName, infNodeItem);
		
		//Insert Node Item - Blank
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_BLANK;
		infNodeItem.b_nHeight = 8;
		class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.me_MainTree", strRetName, infNodeItem);
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////
	//Event Room Node
	infNode = infNodeClear;
	infNode.strName = "" $ info.m_nEventNo;
	infNode.nOffSetX = 7;
	infNode.nOffSetY = 0;
	infNode.bShowButton = 1;
	infNode.nTexBtnWidth = 14;
	infNode.nTexBtnHeight = 14;
	infNode.strTexBtnExpand = "L2UI_CH3.QUESTWND.QuestWndDownBtn";
	infNode.strTexBtnCollapse = "L2UI_CH3.QUESTWND.QuestWndUpBtn";
	infNode.strTexBtnExpand_Over = "L2UI_CH3.QUESTWND.QuestWndDownBtn_over";
	infNode.strTexBtnCollapse_Over = "L2UI_CH3.QUESTWND.QuestWndUpBtn_over";
	strRetName = class'UIAPI_TREECTRL'.static.InsertNode("SSQMainBoard.me_MainTree", strRetName, infNode);
	if (Len(strRetName) < 1)
	{
		Log("ERROR: Can't insert node. Name: " $ infNode.strName);
		return;
	}
	
	//Insert Node Item - Room Name
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = GetSSQTimeAttackEventRoomName(info.m_nEventNo);
	infNodeItem.nOffSetX = 5;
	infNodeItem.nOffSetY = 2;
	infNodeItem.t_color.R = 128;
	infNodeItem.t_color.G = 128;
	infNodeItem.t_color.B = 128;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.me_MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - "진행중"
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	if (info.m_nSSQStatus == 1)
	{
		//진행중
		infNodeItem.t_strText = GetSystemString(829);
	}
	else
	{
		//완료
		if (info.m_nTeam1Score > info.m_nTeam2Score)
		{
			infNodeItem.t_strText = "(" $ GetSystemString(923) $ " " $ GetSystemString(828) $ ")";
		}
		else if (info.m_nTeam1Score < info.m_nTeam2Score)
		{
			infNodeItem.t_strText = "(" $ GetSystemString(924) $ " " $ GetSystemString(828) $ ")";
		}
		else
		{
			infNodeItem.t_strText = "(" $ GetSystemString(846) $ ")";
		}
	}
	infNodeItem.nOffSetX = 5;
	infNodeItem.nOffSetY = 2;
	infNodeItem.t_color.R = 176;
	infNodeItem.t_color.G = 155;
	infNodeItem.t_color.B = 121;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.me_MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - "점수: "
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = GetSystemString(831) $ " : ";
	infNodeItem.bLineBreak = true;
	infNodeItem.nOffSetX = 19;
	infNodeItem.nOffSetY = 4;
	infNodeItem.t_color.R = 128;
	infNodeItem.t_color.G = 128;
	infNodeItem.t_color.B = 128;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.me_MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - xx
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = "" $ info.m_nWinPoint;
	infNodeItem.nOffSetX = 0;
	infNodeItem.nOffSetY = 4;
	infNodeItem.t_color.R = 176;
	infNodeItem.t_color.G = 155;
	infNodeItem.t_color.B = 121;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.me_MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - Blank
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_BLANK;
	infNodeItem.b_nHeight = 8;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.me_MainTree", strRetName, infNodeItem);
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////
	//Member Name List Node
	infNode = infNodeClear;
	infNode.strName = "member";
	infNode.nOffSetX = 2;
	infNode.nOffSetY = 0;
	infNode.bShowButton = 0;
	infNode.bDrawBackground = 1;
	infNode.bTexBackHighlight = 1;
	infNode.nTexBackHighlightHeight = 16;
	infNode.nTexBackWidth = 218;
	infNode.nTexBackUWidth = 211;
	infNode.nTexBackOffSetX = 0;
	infNode.nTexBackOffSetY = -3;
	infNode.nTexBackOffSetBottom = -2;
	strRetName = class'UIAPI_TREECTRL'.static.InsertNode("SSQMainBoard.me_MainTree", strRetName, infNode);
	if (Len(strRetName) < 1)
	{
		debug("ERROR: Can't insert node. Name: " $ infNode.strName);
		return;
	}
	
	//Insert Node Item - Team1 Name
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = GetSSQTeamName(SSQT_DAWN);
	infNodeItem.nOffSetX = 5;
	infNodeItem.nOffSetY = 0;
	infNodeItem.t_color.R = 128;
	infNodeItem.t_color.G = 128;
	infNodeItem.t_color.B = 128;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.me_MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - "최고 기록"
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = GetSystemString(830);
	infNodeItem.bLineBreak = true;
	infNodeItem.nOffSetX = 5;
	infNodeItem.nOffSetY = 4;
	infNodeItem.t_color.R = 128;
	infNodeItem.t_color.G = 128;
	infNodeItem.t_color.B = 128;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.me_MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - Team1 점수
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = "" $ info.m_nTeam1Score;
	infNodeItem.nOffSetX = 5;
	infNodeItem.nOffSetY = 4;
	infNodeItem.t_color.R = 176;
	infNodeItem.t_color.G = 155;
	infNodeItem.t_color.B = 121;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.me_MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - "참가자"
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = GetSystemString(832);
	infNodeItem.bLineBreak = true;
	infNodeItem.nOffSetX = 5;
	infNodeItem.nOffSetY = 4;
	infNodeItem.t_color.R = 128;
	infNodeItem.t_color.G = 128;
	infNodeItem.t_color.B = 128;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.me_MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - 참가자 리스트
	for (i=0; i<NC_PARTYMEMBER_MAX; i++)
	{
		strTmp = info.m_Team1MemberName[i];
		if (Len(strTmp)>0)
		{
			infNodeItem = infNodeItemClear;
			infNodeItem.eType = XTNITEM_TEXT;
			infNodeItem.t_strText = strTmp;
			infNodeItem.bLineBreak = true;
			infNodeItem.nOffSetX = 5;
			infNodeItem.nOffSetY = 4;
			infNodeItem.t_color.R = 176;
			infNodeItem.t_color.G = 155;
			infNodeItem.t_color.B = 121;
			infNodeItem.t_color.A = 255;
			class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.me_MainTree", strRetName, infNodeItem);		
		}
	}
	
	//Insert Node Item - Blank
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_BLANK;
	infNodeItem.b_nHeight = 20;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.me_MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - Team2 Name
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = GetSSQTeamName(SSQT_DUSK);
	infNodeItem.nOffSetX = 5;
	infNodeItem.nOffSetY = 0;
	infNodeItem.t_color.R = 128;
	infNodeItem.t_color.G = 128;
	infNodeItem.t_color.B = 128;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.me_MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - "최고 기록"
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = GetSystemString(830);
	infNodeItem.bLineBreak = true;
	infNodeItem.nOffSetX = 5;
	infNodeItem.nOffSetY = 4;
	infNodeItem.t_color.R = 128;
	infNodeItem.t_color.G = 128;
	infNodeItem.t_color.B = 128;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.me_MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - Team2 점수
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = "" $ info.m_nTeam2Score;
	infNodeItem.nOffSetX = 5;
	infNodeItem.nOffSetY = 4;
	infNodeItem.t_color.R = 176;
	infNodeItem.t_color.G = 155;
	infNodeItem.t_color.B = 121;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.me_MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - "참가자"
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = GetSystemString(832);
	infNodeItem.bLineBreak = true;
	infNodeItem.nOffSetX = 5;
	infNodeItem.nOffSetY = 4;
	infNodeItem.t_color.R = 128;
	infNodeItem.t_color.G = 128;
	infNodeItem.t_color.B = 128;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.me_MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - 참가자 리스트
	for (i=0; i<NC_PARTYMEMBER_MAX; i++)
	{
		strTmp = info.m_Team2MemberName[i];
		if (Len(strTmp)>0)
		{
			infNodeItem = infNodeItemClear;
			infNodeItem.eType = XTNITEM_TEXT;
			infNodeItem.t_strText = strTmp;
			infNodeItem.bLineBreak = true;
			infNodeItem.nOffSetX = 5;
			infNodeItem.nOffSetY = 4;
			infNodeItem.t_color.R = 176;
			infNodeItem.t_color.G = 155;
			infNodeItem.t_color.B = 121;
			infNodeItem.t_color.A = 255;
			class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.me_MainTree", strRetName, infNodeItem);		
		}
	}
	
	//Insert Node Item - Blank
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_BLANK;
	infNodeItem.b_nHeight = 4;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.me_MainTree", strRetName, infNodeItem);
}



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	SSQ Seal Status Wnd 
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////
//Request Seal Status
function ShowSSQSealStatus()
{
	local XMLTreeNodeInfo	infNode;
	local string		strRetName;
	
	// 0. 초기화
	class'UIAPI_TREECTRL'.static.Clear("SSQMainBoard.ss_MainTree");
		
	// 1. Add Root Item
	infNode.strName = "root";
	infNode.nOffSetX = 3;
	infNode.nOffSetY = 5;
	strRetName = class'UIAPI_TREECTRL'.static.InsertNode("SSQMainBoard.ss_MainTree", "", infNode);
	if (Len(strRetName) < 1)
	{
		debug("ERROR: Can't insert root node. Name: " $ infNode.strName);
		return;
	}
	
	// 2. Request Seal Status
	if (g_sinfo.m_nMsgNum1 == 1183)	// 다음경쟁을 준비중인 상태일때는 초기화해버린다. (임시방편)
	{
		AddSSQSealStatus(1,10,35,1,0,0,0);
		AddSSQSealStatus(1,10,35,2,0,0,0);
		AddSSQSealStatus(1,10,35,3,0,0,0);
	}
	else
	{	
		class'SSQAPI'.static.RequestSSQStatus(SSQR_SEALSTATUS);		//EV_SSQSealStatus가 이벤트가 날라옴
	}
}

////////////////////////////////////
//Add SSQ SealStatus to TreeItem
function AddSSQSealStatus(int m_nSSQStatus, int m_nNeedPoint1, int m_nNeedPoint2, int m_nSealID,  int m_nOwnerTeamID, int m_nTeam1Mark, int m_nTeam2Mark)
{
	local int			i;
	local int			nMax;
	local int			nStrID;
	local int			nNeedPoint;
	local int			nTmp;
	
	local float			fBarX;
	local float			fBarWidth;
	local int			nWidth;
	local int			nHeight;
	
	local XMLTreeNodeInfo	infNode;
	local XMLTreeNodeItemInfo	infNodeItem;
	local XMLTreeNodeInfo	infNodeClear;
	local XMLTreeNodeItemInfo	infNodeItemClear;
	local string		strRetName;
	local string		strTmp;
	
	//Get Seal Name
	strTmp = GetSSQSealName(m_nSealID);
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////
	//Insert Node - with Button
	infNode = infNodeClear;
	infNode.strName = "" $ m_nSealID;
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
	
	strRetName = class'UIAPI_TREECTRL'.static.InsertNode("SSQMainBoard.ss_MainTree", "root", infNode);
	if (Len(strRetName) < 1)
	{
		debug("ERROR: Can't insert node. Name: " $ infNode.strName);
		return;
	}
	
	//Insert Node Item - Seal Name
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = strTmp;
	infNodeItem.nOffSetX = 4;
	infNodeItem.nOffSetY = 2;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - "현재 소유"
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = GetSystemString(823);
	infNodeItem.nOffSetX = 0;
	infNodeItem.nOffSetY = 5;
	infNodeItem.bLineBreak = true;
	infNodeItem.bStopMouseFocus = true;	//제목 한줄만 마우스오버되게 한다.
	infNodeItem.t_color.R = 128;
	infNodeItem.t_color.G = 128;
	infNodeItem.t_color.B = 128;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - Team Name
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = GetSSQTeamName(m_nOwnerTeamID);
	infNodeItem.nOffSetX = 4;
	infNodeItem.nOffSetY = 5;
	infNodeItem.t_color.R = 176;
	infNodeItem.t_color.G = 155;
	infNodeItem.t_color.B = 121;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - "여명의 군주들"
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = GetSSQTeamName(2);
	infNodeItem.nOffSetX = 0;
	infNodeItem.nOffSetY = 7;
	infNodeItem.bLineBreak = true;
	infNodeItem.t_color.R = 128;
	infNodeItem.t_color.G = 128;
	infNodeItem.t_color.B = 128;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////
	//여명 퍼센트
	
	fBarX = 80.0f;
	fBarWidth = 140.0f;
	
	//Insert Node Item - 배경BAR
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXTURE;
	infNodeItem.nOffSetX = 2;
	infNodeItem.nOffSetY = 7;
	infNodeItem.u_nTextureWidth = fBarWidth;
	infNodeItem.u_nTextureHeight = 11;
	infNodeItem.u_nTextureUWidth = 8;
	infNodeItem.u_nTextureUHeight = 11;
	infNodeItem.u_strTexture = "L2UI_CH3.SSQWnd.ssq_bar2back";
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
	
	if (m_nOwnerTeamID == SSQT_DAWN)
	{
		nNeedPoint = m_nNeedPoint1;
	}
	else
	{
		nNeedPoint = m_nNeedPoint2;
	}
	
	if (m_nTeam1Mark > nNeedPoint)
	{
		//Insert Node Item - 배경BAR
		//CDC->DrawTexture(BarX,iOffsetY,BarW*(float)(NeedPoint/100.f),11,0,0,8,11,m_pBar11);
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXTURE;
		infNodeItem.nOffSetX = -fBarWidth;
		infNodeItem.nOffSetY = 7;
		infNodeItem.u_nTextureWidth = fBarWidth * (nNeedPoint/100.0f);
		nTmp = infNodeItem.u_nTextureWidth;
		infNodeItem.u_nTextureHeight = 11;
		infNodeItem.u_nTextureUWidth = 8;
		infNodeItem.u_nTextureUHeight = 11;
		infNodeItem.u_strTexture = "L2UI_CH3.SSQWnd.ssq_bar21";
		class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
		
		//Insert Node Item - 배경BAR(진한부분)
		//CDC->DrawTexture(BarX+BarW*(float)(NeedPoint/100.f),iOffsetY,BarW*(float)((Team1Mark-NeedPoint)/100.f),11,0,0,8,11,m_pBar12);
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXTURE;
		infNodeItem.nOffSetX = 0;
		infNodeItem.nOffSetY = 7;
		infNodeItem.u_nTextureWidth = fBarWidth * ((m_nTeam1Mark-nNeedPoint)/100.0f);
		nTmp = nTmp + infNodeItem.u_nTextureWidth;
		infNodeItem.u_nTextureHeight = 11;
		infNodeItem.u_nTextureUWidth = 8;
		infNodeItem.u_nTextureUHeight = 11;
		infNodeItem.u_strTexture = "L2UI_CH3.SSQWnd.ssq_bar22";
		class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
	}
	else
	{
		//Insert Node Item - 배경BAR
		//CDC->DrawTexture(BarX,iOffsetY,BarW*(float)(Team1Mark/100.f),11,0,0,8,11,m_pBar11);
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXTURE;
		infNodeItem.nOffSetX = -fBarWidth;
		infNodeItem.nOffSetY = 7;
		infNodeItem.u_nTextureWidth = fBarWidth * (m_nTeam1Mark/100.0f);
		nTmp = infNodeItem.u_nTextureWidth;
		infNodeItem.u_nTextureHeight = 11;
		infNodeItem.u_nTextureUWidth = 8;
		infNodeItem.u_nTextureUHeight = 11;
		infNodeItem.u_strTexture = "L2UI_CH3.SSQWnd.ssq_bar21";
		class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
	}
	
	//Insert Node Item - 배경BARLINE
	//CDC->DrawTexture(BarX+BarW*(float)(NeedPoint/100.f),iOffsetY,1,11,0,0,1,11,m_pBarLine);
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXTURE;
	infNodeItem.nOffSetX = -nTmp + fBarWidth * (nNeedPoint/100.0f);
	infNodeItem.nOffSetY = 7;
	infNodeItem.u_nTextureWidth = 1;
	nTmp = fBarWidth * (nNeedPoint/100.0f) + 1;
	infNodeItem.u_nTextureHeight = 11;
	infNodeItem.u_nTextureUWidth = 1;
	infNodeItem.u_nTextureUHeight = 11;
	infNodeItem.u_strTexture = "L2UI_CH3.SSQWnd.ssq_barline";
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - ??%
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = m_nTeam1Mark $ "%";
	
	GetTextSize(infNodeItem.t_strText, nWidth, nHeight);
	
	infNodeItem.nOffSetX = -nTmp + (fBarWidth/2) - (nWidth/2);	
	infNodeItem.nOffSetY = 8;
	infNodeItem.t_color.R = 255;
	infNodeItem.t_color.G = 255;
	infNodeItem.t_color.B = 255;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - "황혼의 혁명군"
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = GetSSQTeamName(1);
	infNodeItem.nOffSetX = 0;
	infNodeItem.nOffSetY = 6;
	infNodeItem.bLineBreak = true;
	infNodeItem.t_color.R = 128;
	infNodeItem.t_color.G = 128;
	infNodeItem.t_color.B = 128;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////
	//황혼 퍼센트
	
	//Insert Node Item - 배경BAR
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXTURE;
	infNodeItem.nOffSetX = 2;
	infNodeItem.nOffSetY = 6;
	infNodeItem.u_nTextureWidth = fBarWidth;
	infNodeItem.u_nTextureHeight = 11;
	infNodeItem.u_nTextureUWidth = 8;
	infNodeItem.u_nTextureUHeight = 11;
	infNodeItem.u_strTexture = "L2UI_CH3.SSQWnd.ssq_bar1back";
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
	
	if (m_nOwnerTeamID == SSQT_DUSK)
	{
		nNeedPoint = m_nNeedPoint1;
	}
	else
	{
		nNeedPoint = m_nNeedPoint2;
	}
	
	if (m_nTeam2Mark > nNeedPoint)
	{
		//Insert Node Item - 배경BAR
		//CDC->DrawTexture(BarX,iOffsetY,BarW*(float)(NeedPoint/100.f),11,0,0,8,11,m_pBar11);
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXTURE;
		infNodeItem.nOffSetX = -fBarWidth;
		infNodeItem.nOffSetY = 6;
		infNodeItem.u_nTextureWidth = fBarWidth * (nNeedPoint/100.0f);
		nTmp = infNodeItem.u_nTextureWidth;
		infNodeItem.u_nTextureHeight = 11;
		infNodeItem.u_nTextureUWidth = 8;
		infNodeItem.u_nTextureUHeight = 11;
		infNodeItem.u_strTexture = "L2UI_CH3.SSQWnd.ssq_bar11";
		class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
		
		//Insert Node Item - 배경BAR(진한부분)
		//CDC->DrawTexture(BarX+BarW*(float)(NeedPoint/100.f),iOffsetY,BarW*(float)((Team1Mark-NeedPoint)/100.f),11,0,0,8,11,m_pBar12);
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXTURE;
		infNodeItem.nOffSetX = 0;
		infNodeItem.nOffSetY = 6;
		infNodeItem.u_nTextureWidth = fBarWidth * ((m_nTeam2Mark-nNeedPoint)/100.0f);
		nTmp = nTmp + infNodeItem.u_nTextureWidth;
		infNodeItem.u_nTextureHeight = 11;
		infNodeItem.u_nTextureUWidth = 8;
		infNodeItem.u_nTextureUHeight = 11;
		infNodeItem.u_strTexture = "L2UI_CH3.SSQWnd.ssq_bar12";
		class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
	}
	else
	{
		//Insert Node Item - 배경BAR
		//CDC->DrawTexture(BarX,iOffsetY,BarW*(float)(Team1Mark/100.f),11,0,0,8,11,m_pBar11);
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXTURE;
		infNodeItem.nOffSetX = -fBarWidth;
		infNodeItem.nOffSetY = 6;
		infNodeItem.u_nTextureWidth = fBarWidth * (m_nTeam2Mark/100.0f);
		nTmp = infNodeItem.u_nTextureWidth;
		infNodeItem.u_nTextureHeight = 11;
		infNodeItem.u_nTextureUWidth = 8;
		infNodeItem.u_nTextureUHeight = 11;
		infNodeItem.u_strTexture = "L2UI_CH3.SSQWnd.ssq_bar11";
		class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
	}
	
	//Insert Node Item - 배경BARLINE
	//CDC->DrawTexture(BarX+BarW*(float)(NeedPoint/100.f),iOffsetY,1,11,0,0,1,11,m_pBarLine);
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXTURE;
	infNodeItem.nOffSetX = -nTmp + fBarWidth * (nNeedPoint/100.0f);
	infNodeItem.nOffSetY = 6;
	infNodeItem.u_nTextureWidth = 1;
	nTmp = fBarWidth * (nNeedPoint/100.0f) + 1;
	infNodeItem.u_nTextureHeight = 11;
	infNodeItem.u_nTextureUWidth = 1;
	infNodeItem.u_nTextureUHeight = 11;
	infNodeItem.u_strTexture = "L2UI_CH3.SSQWnd.ssq_barline";
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - ??%
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = m_nTeam2Mark $ "%";
	
	GetTextSize(infNodeItem.t_strText, nWidth, nHeight);
	
	infNodeItem.nOffSetX = -nTmp + (fBarWidth/2) - (nWidth/2);
	infNodeItem.nOffSetY = 6;
	infNodeItem.t_color.R = 255;
	infNodeItem.t_color.G = 255;
	infNodeItem.t_color.B = 255;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - Blank
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_BLANK;
	infNodeItem.b_nHeight = 12;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////
	//Insert Node - Seal Description	
	infNode = infNodeClear;
	infNode.strName = "desc";
	infNode.bShowButton = 0;
	infNode.bDrawBackground = 1;
	infNode.bTexBackHighlight = 1;
	infNode.nTexBackHighlightHeight = 18;
	infNode.nTexBackWidth = 218;
	infNode.nTexBackUWidth = 211;
	infNode.nTexBackOffSetX = -4;
	infNode.nTexBackOffSetY = -3;
	infNode.nTexBackOffSetBottom = -3;
	strRetName = class'UIAPI_TREECTRL'.static.InsertNode("SSQMainBoard.ss_MainTree", strRetName, infNode);
	if (Len(strRetName) < 1)
	{
		debug("ERROR: Can't insert node. Name: " $ infNode.strName);
		return;
	}
	
	//Insert Node Item - 설명
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_TEXT;
	infNodeItem.t_strText = GetSSQSealDesc(m_nSealID);
	infNodeItem.t_color.R = 128;
	infNodeItem.t_color.G = 128;
	infNodeItem.t_color.B = 128;
	infNodeItem.t_color.A = 255;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
	
	//Insert Node Item - Blank
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_BLANK;
	infNodeItem.b_nHeight = 18;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
	
	if(m_nSealID == SSQS_GREED)
	{
		nMax = 16;
		nStrID = 941;
	}
	else if (m_nSealID == SSQS_REVEAL)
	{
		nMax = 12;
		nStrID = 957;
	}
	else
	{
		nMax = 0;
	}
	
	for(i=0; i<nMax; i+=2)
	{
		//Insert Node Item - 사냥터
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXT;
		infNodeItem.t_strText = GetSystemString(nStrID+i);
		infNodeItem.bLineBreak = true;
		infNodeItem.nOffSetY = 6;
		infNodeItem.t_color.R = 128;
		infNodeItem.t_color.G = 128;
		infNodeItem.t_color.B = 128;
		infNodeItem.t_color.A = 255;
		class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
		
		//Insert Node Item - ":"
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXT;
		infNodeItem.t_strText = ":";
		infNodeItem.bLineBreak = true;
		infNodeItem.nOffSetY = 6;
		infNodeItem.t_color.R = 128;
		infNodeItem.t_color.G = 128;
		infNodeItem.t_color.B = 128;
		infNodeItem.t_color.A = 255;
		class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
		
		//Insert Node Item - ":"
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXT;
		infNodeItem.t_strText = GetSystemString(nStrID+i+1);
		infNodeItem.nOffSetY = 6;
		infNodeItem.t_color.R = 176;
		infNodeItem.t_color.G = 155;
		infNodeItem.t_color.B = 121;
		infNodeItem.t_color.A = 255;
		class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
	}
	
	//Insert Node Item - Blank
	infNodeItem = infNodeItemClear;
	infNodeItem.eType = XTNITEM_BLANK;
	infNodeItem.b_nHeight = 6;
	class'UIAPI_TREECTRL'.static.InsertNodeItem("SSQMainBoard.ss_MainTree", strRetName, infNodeItem);
}

function string GetSSQSealName(int nID)
{
	local int nStrID;

	if(nID == SSQS_GREED)
	{
		nStrID = 816;	//탐욕의 봉인
	}
	else if (nID == SSQS_REVEAL)
	{
		nStrID = 817;	//계시의 봉인
	}
	else if (nID == SSQS_STRIFE)
	{
		nStrID = 818;	//전란의 봉인
	}
	else
	{
		nStrID = 27;	//없음
	}
	return GetSystemString(nStrID);
}

function string GetSSQTeamName(int nID)
{
	local int nStrID;

	if(nID == SSQT_DUSK)
	{
		nStrID = 815;	//황혼
	}
	else if (nID == SSQT_DAWN)
	{
		nStrID = 814;	//새벽
	}
	else
	{
		nStrID = 27;	//없음
	}
	return GetSystemString(nStrID);
}

function string GetSSQSealDesc(int nID)
{
	local int nStrID;

	if(nID == SSQS_GREED)
	{
		nStrID = 1178;	//탐욕
	}
	else if (nID == SSQS_REVEAL)
	{
		nStrID = 1179;	//계시
	}
	else if (nID == SSQS_STRIFE)
	{
		nStrID = 1180;	//전란
	}
	else
	{
		nStrID = 27;	//없음
	}
	return GetSystemMessage(nStrID);
}

function string GetSSQTimeAttackEventRoomName(int nID)
{
	local int nStrID;

	if(nID == 1)
	{
		nStrID = 819;	//레벨 무제한 이벤트
	}
	else if (nID == 2)
	{
		nStrID = 820;	//64레벨 이하 이벤트
	}
	else if (nID == 3)
	{
		nStrID = 821;	//53레벨 이하 이벤트
	}
	else if (nID == 4)
	{
		nStrID = 844;	//43레벨 이하 이벤트
	}
	else if (nID == 5)
	{
		nStrID = 822;	//31레벨 이하 이벤트
	}
	else
	{
		nStrID = 27;	//없음
	}
	return GetSystemString(nStrID);
}
