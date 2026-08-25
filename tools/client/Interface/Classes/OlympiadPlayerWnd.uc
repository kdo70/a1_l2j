class OlympiadPlayerWnd extends UIScript;

const MAX_OLYMPIAD_SKILL_MSG = 5;

var int		m_PlayerNum;
var string		m_WindowName;
var string		m_BuffWindowName;
var bool		m_Expand;

var int		m_ID;
var string		m_Name;
var int		m_ClassID;
var int		m_MaxHP;
var int		m_CurHP;
var int		m_MaxCP;
var int		m_CurCP;

var string		m_Msg[5];
var int		m_MsgStartLine;

function SetPlayerNum(int PlayerNum)
{
	m_PlayerNum = PlayerNum;
	m_WindowName = "OlympiadPlayer" $ PlayerNum $ "Wnd";
	m_BuffWindowName = "OlympiadBuff" $ PlayerNum $ "Wnd";
}

function OnLoad()
{
	RegisterEvent( EV_OlympiadUserInfo );
	RegisterEvent( EV_OlympiadMatchEnd );
	RegisterEvent( EV_ReceiveMagicSkillUse );
	RegisterEvent( EV_ReceiveAttack );
	
	SetExpandMode(false);
}

function OnEnterState( name a_PreStateName )
{
	Clear();
	SetExpandMode(m_Expand);
}

function OnEvent(int Event_ID, string param)
{
	if (Event_ID == EV_OlympiadUserInfo)
	{
		HandleUserInfo(param);
		UpdateStatus();
	}
	else if (Event_ID == EV_ReceiveMagicSkillUse)
	{
		HandleMagicSkillUse(param);
	}
	else if (Event_ID == EV_ReceiveAttack)
	{
		HandleAttack(param);
	}
	else if (Event_ID == EV_OlympiadMatchEnd)
	{
		Clear();
	}	
}

//초기화
function Clear()
{
	local int i;
	
	m_ID = 0;
	m_Name = "";
	m_ClassID = 0;
	m_MaxHP = 0;
	m_CurHP = 0;
	m_MaxCP = 0;
	m_CurCP = 0;
	
	for (i=0; i<MAX_OLYMPIAD_SKILL_MSG; i++)
	{
		m_Msg[i] = "";
	}
	
	UpdateStatus();
	UpdateMsg("");
}

//UserInfo설정
function HandleUserInfo(string param)
{
	local int IsPlayer;
	local int PlayerNum;
	local int PlayerID;
	local string strParam;
	
	//Observer모드에서의 플레이어 정보가 아니면 패스
	ParseInt(param, "IsPlayer", IsPlayer);
	if (IsPlayer != 1)
	{
		return;
	}
	
	//표시하고자 하는 타겟의 PlayerNum이 아니면 패스
	ParseInt(param, "PlayerNum", PlayerNum);
	if (m_PlayerNum != PlayerNum || PlayerNum<1)
	{
		return;
	}
	
	ParseInt(param, "ID", PlayerID);
	ParseString(param, "Name", m_Name);
	ParseInt(param, "ClassID", m_ClassID);
	ParseInt(param, "MaxHP", m_MaxHP);
	ParseInt(param, "CurHP", m_CurHP);
	ParseInt(param, "MaxCP", m_MaxCP);
	ParseInt(param, "CurCP", m_CurCP);
	
	//플레이어ID가 새로운 것이라면 버프윈도우정보를 재셋팅(초기화)한다.
	if (m_ID != PlayerID)
	{
		m_ID = PlayerID;
		
		ParamAdd(strParam, "PlayerNum", string(m_PlayerNum));
		ParamAdd(strParam, "PlayerID", string(PlayerID));
		ExecuteEvent( EV_OlympiadBuffShow, strParam );	
	}
}

//MagicSkill정보 처리
function HandleMagicSkillUse(string param)
{
	local int ID;
	local int SkillID;
	local string paramsend;
	local string strMsg;
	
	ParseInt(param, "AttackerID", ID);
	if (ID<1 || ID!=m_ID)
	{
		return;
	}
	
	ParseInt(param, "SkillID", SkillID);
	if (0 > SkillID || 1999 < SkillID)
	{
		return;
	}
	
	//메세지를 만들어서, 갱신함
	ParamAdd(paramsend, "Type", string(int(ESystemMsgParamType.SMPT_SKILLID)));
	ParamAdd(paramsend, "param1", string(SkillID));
	ParamAdd(paramsend, "param2", "1");
	AddSystemMessageParam(paramsend);
	strMsg = EndSystemMessageParam(46, true);
	
	UpdateMsg(strMsg);
}

//Attackl정보 처리
function HandleAttack(string param)
{
	local int		AttackerID;
	local string	AttackerName;
	local int		DefenderID;
	local int		Critical;
	local int		Miss;
	local int		ShieldDefense;
	local string	paramsend;
	local string	strMsg;
	
	ParseInt(param, "AttackerID", AttackerID);
	ParseString(param, "AttackerName", AttackerName);
	ParseInt(param, "DefenderID", DefenderID);
	ParseInt(param, "Critical", Critical);
	ParseInt(param, "Miss", Miss);
	ParseInt(param, "ShieldDefense", ShieldDefense);
	
	if (AttackerID>0 && AttackerID==m_ID)
	{
		if (Critical>0)
		{
			UpdateMsg(GetSystemMessage(44));
		}
	}
	else if (DefenderID>0 && DefenderID==m_ID)
	{
		if (Miss>0)
		{
			//메세지를 만들어서, 갱신함
			ParamAdd(paramsend, "Type", string(int(ESystemMsgParamType.SMPT_STRING)));
			ParamAdd(paramsend, "param1", AttackerName);
			AddSystemMessageParam(paramsend);
			strMsg = EndSystemMessageParam(42, true);
			
			UpdateMsg(strMsg);
		}
		else if (ShieldDefense>0)
		{
			UpdateMsg(GetSystemMessage(111));
		}
	}
}

//Update Message
function UpdateMsg(string strMsg)
{
	local int i;
	local int CurPos;
	
	m_Msg[m_MsgStartLine] = strMsg;
	m_MsgStartLine = (m_MsgStartLine + 1) % MAX_OLYMPIAD_SKILL_MSG;
	
	for (i=0; i<MAX_OLYMPIAD_SKILL_MSG; i++)
	{
		CurPos = (m_MsgStartLine + i) % MAX_OLYMPIAD_SKILL_MSG;
		class'UIAPI_TEXTBOX'.static.SetText( m_WindowName $ ".txtMsg" $ MAX_OLYMPIAD_SKILL_MSG-1-i, m_Msg[CurPos]);
	}
}

//Update Info
function UpdateStatus()
{
	//이름
	class'UIAPI_TEXTBOX'.static.SetText( m_WindowName $ ".txtName", m_Name);
	
	//CP
	if (m_MaxCP>0)
	{
		class'UIAPI_WINDOW'.static.SetWindowSize( m_WindowName $ ".texCP", 326 * m_CurCP / m_MaxCP, 6);
	}
	else
	{
		class'UIAPI_WINDOW'.static.SetWindowSize( m_WindowName $ ".texCP", 0, 6);
	}
	
	//HP
	if (m_MaxHP>0)
	{
		class'UIAPI_WINDOW'.static.SetWindowSize( m_WindowName $ ".texHP", 326 * m_CurHP / m_MaxHP, 6);
	}
	else
	{
		class'UIAPI_WINDOW'.static.SetWindowSize( m_WindowName $ ".texHP", 0, 6);
	}
}

//Frame Expand버튼 처리
function OnFrameExpandClick( bool bIsExpand )
{
	SetExpandMode(bIsExpand);
	m_Expand = bIsExpand;
}

//Expand상태에 따른 여러가지 처리
function SetExpandMode(bool bExpand)
{
	local Rect 	rectWnd;
	local Rect 	rectBuffWnd;
	
	if (bExpand)
	{
		class'UIAPI_WINDOW'.static.HideWindow(m_WindowName $ ".BackTex");
		class'UIAPI_WINDOW'.static.ShowWindow(m_WindowName $ ".BackExpTex");
	}
	else
	{
		class'UIAPI_WINDOW'.static.ShowWindow(m_WindowName $ ".BackTex");
		class'UIAPI_WINDOW'.static.HideWindow(m_WindowName $ ".BackExpTex");
	}
	
	//Buff윈도우를 이동시켜 준다
	rectWnd = class'UIAPI_WINDOW'.static.GetRect(m_WindowName);
	rectBuffWnd = class'UIAPI_WINDOW'.static.GetRect(m_BuffWindowName);
	
	if (bExpand)
	{	
		//Stuckable속성때문에 이상하게 움직일 수 있으므로 MoveEx를 사용
		if ( rectWnd.nY + 46 == rectBuffWnd.nY || rectWnd.nY + 47 == rectBuffWnd.nY )
		{
			class'UIAPI_WINDOW'.static.MoveEx(m_BuffWindowName, 0, 80);
		}
	}
	else
	{
		//Stuckable속성때문에 이상하게 움직일 수 있으므로 MoveEx를 사용
		if ( rectWnd.nY + 126 == rectBuffWnd.nY || rectWnd.nY + 127 == rectBuffWnd.nY )
		{
			class'UIAPI_WINDOW'.static.MoveEx(m_BuffWindowName, 0, -80);
		}
	}
}
