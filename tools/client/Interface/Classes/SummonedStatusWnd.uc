class SummonedStatusWnd extends UIScript;

const NSTATUSICON_MAXCOL = 10;

var bool	m_bBuff;
var bool	m_bShow;
var int	m_PetID;
var bool	m_bSummonedStarted;

function OnLoad()
{
	RegisterEvent( EV_UpdatePetInfo );
	RegisterEvent( EV_ShowBuffIcon );
	
	RegisterEvent( EV_SummonedStatusShow );
	RegisterEvent( EV_SummonedStatusSpelledList );
	RegisterEvent( EV_SummonedStatusRemainTime );
	
	RegisterEvent( EV_PetSummonedStatusClose );
	
	m_bShow = false;
	m_bBuff = false;
}

function OnShow()
{
	local int PetID;
	local int IsPetOrSummoned;
	
	PetID = class'UIDATA_PET'.static.GetPetID();
	IsPetOrSummoned = class'UIDATA_PET'.static.GetIsPetOrSummoned();
	
	if (PetID<0 || IsPetOrSummoned!=1)
	{
		Debug("Hide " $ IsPetOrSummoned $ " " $ PetID);
		class'UIAPI_WINDOW'.static.HideWindow("SummonedStatusWnd");
	}
	else
	{
		m_bShow = true;
		class'UIAPI_WINDOW'.static.ShowWindow("SummonedStatusWnd");
	}
}

function OnHide()
{
	m_bShow = false;
}

function OnEnterState( name a_PreStateName )
{
	m_bBuff = false;
	
	//if (a_PreStateName == 'GamingState')	//스테이트를 지정하지 않아두 될라나 모르겠네용
	//{
		OnShow();				//소환수가 없으면 어짜피 그려주지 않으니 여기서는 onshow를 부르도록 한다.
	//}
}

function OnEvent(int Event_ID, string param)
{
	if (Event_ID == EV_UpdatePetInfo)
	{
		HandlePetInfoUpdate();
	}
	else if (Event_ID == EV_PetSummonedStatusClose)
	{
		HandlePetSummonedStatusClose();
	}
	else if (Event_ID == EV_SummonedStatusShow)
	{
		HandleSummonedStatusShow();
	}
	else if (Event_ID == EV_ShowBuffIcon)
	{
		HandleShowBuffIcon(param);
	}
	else if (Event_ID == EV_SummonedStatusSpelledList)
	{
		HandleSummonedStatusSpelledList(param);
	}
	else if (Event_ID == EV_SummonedStatusRemainTime)
	{
		HandleSummonedStatusRemainTime(param);
	}
}

//초기화
function Clear()
{
	ClearBuff();
	class'UIAPI_NAMECTRL'.static.SetName("SummonedStatusWnd.PetName", "", NCT_Normal,TA_Center);
	UpdateHPBar(0, 0);
	UpdateMPBar(0, 0);
}

//버프 정보의 초기화
function ClearBuff()
{
	class'UIAPI_STATUSICONCTRL'.static.Clear("SummonedStatusWnd.StatusIcon");
}

//소환 남은 시간의 갱신
function HandleSummonedStatusRemainTime(string param)
{
	local int RemainTime;
	local int MaxTime;
	
	ParseInt(param, "RemainTime", RemainTime);
	ParseInt(param, "MaxTime", MaxTime);
	
	if (m_bSummonedStarted)
	{
		class'UIAPI_PROGRESSCTRL'.static.SetPos("SummonedStatusWnd.progFATIGUE", RemainTime);
	}
	else
	{
		ClearBuff();
		class'UIAPI_PROGRESSCTRL'.static.SetProgressTime("SummonedStatusWnd.progFATIGUE", MaxTime);
		class'UIAPI_PROGRESSCTRL'.static.Start("SummonedStatusWnd.progFATIGUE");
		m_bSummonedStarted = true;
	}
}

//종료처리
function HandlePetSummonedStatusClose()
{
	InitFATIGUEBar();
	class'UIAPI_WINDOW'.static.HideWindow("SummonedStatusWnd");
	PlayConsoleSound(IFST_WINDOW_CLOSE);
}

//펫Info패킷 처리
function HandlePetInfoUpdate()
{
	local string	Name;
	local int		HP;
	local int		MaxHP;
	local int		MP;
	local int		MaxMP;
	local int		Fatigue;
	local int		MaxFatigue;
	local PetInfo	info;
	
	m_PetID = 0;
	if (GetPetInfo(info))
	{
		m_PetID = info.nID;
		Name = info.Name;
		HP = info.nCurHP;
		MP = info.nCurMP;
		Fatigue = info.nFatigue;
		MaxHP = info.nMaxHP;
		MaxMP = info.nMaxMP;
		MaxFatigue = info.nMaxFatigue;
	}

	class'UIAPI_NAMECTRL'.static.SetName("SummonedStatusWnd.PetName", Name, NCT_Normal,TA_Center);
	UpdateHPBar(HP, MaxHP);
	UpdateMPBar(MP, MaxMP);
}

//펫창을 표시
function HandleSummonedStatusShow()
{
	Clear();
	class'UIAPI_WINDOW'.static.ShowWindow("SummonedStatusWnd");
	class'UIAPI_WINDOW'.static.SetFocus("SummonedStatusWnd");
	
	Debug("HandleSummonedStatusShow");
}

//펫의 버프리스트정보
function HandleSummonedStatusSpelledList(string param)
{
	local int i;
	local int Max;
	
	local int BuffCnt;
	local int CurRow;
	local StatusIconInfo info;
	
	CurRow = -1;
	
	//버프 초기화
	class'UIAPI_STATUSICONCTRL'.static.Clear("SummonedStatusWnd.StatusIcon");
	
	//info 초기화
	info.Size = 16;
	info.bShow = true;
	
	ParseInt(param, "Max", Max);
	for (i=0; i<Max; i++)
	{
		ParseInt(param, "SkillID_" $ i, info.ClassID);
		
		if (info.ClassID>0)
		{
			info.IconName = class'UIDATA_SKILL'.static.GetIconName(info.ClassID, 1);
			
			//한줄에 NSTATUSICON_MAXCOL만큼 표시한다.
			if (BuffCnt%NSTATUSICON_MAXCOL == 0)
			{
				CurRow++;
				class'UIAPI_STATUSICONCTRL'.static.AddRow("SummonedStatusWnd.StatusIcon");
			}
			
			class'UIAPI_STATUSICONCTRL'.static.AddCol("SummonedStatusWnd.StatusIcon", CurRow, info);	
			
			BuffCnt++;
		}
	}
	
	UpdateBuff(m_bBuff);
}

//버프아이콘 표시
function HandleShowBuffIcon(string param)
{
	local int nShow;
	ParseInt(param, "Show", nShow);
	if (nShow==1)
	{
		UpdateBuff(true);
	}
	else
	{
		UpdateBuff(false);
	}
}

function OnLButtonDown( WindowHandle a_WindowHandle, int X, int Y )
{
	local Rect rectWnd;
	local UserInfo userinfo;
	
	rectWnd = class'UIAPI_WINDOW'.static.GetRect("SummonedStatusWnd");
	if (X > rectWnd.nX + 13 && X < rectWnd.nX + rectWnd.nWidth -10)
	{
		if (GetPlayerInfo(userinfo))
		{
			RequestAction(m_PetID, userinfo.Loc);
		}
	}
}

function OnClickButton( string strID )
{
	switch( strID )
	{
	case "btnBuff":
		OnBuffButton();
		break;
	}
}

function OnBuffButton()
{
	UpdateBuff(!m_bBuff);
}

function UpdateBuff(bool bShow)
{
	if (bShow)
	{
		class'UIAPI_WINDOW'.static.ShowWindow("SummonedStatusWnd.StatusIcon");
	}
	else
	{
		class'UIAPI_WINDOW'.static.HideWindow("SummonedStatusWnd.StatusIcon");
	}
	m_bBuff = bShow;
}

//HP바 갱신
function UpdateHPBar(int Value, int MaxValue)
{
	class'UIAPI_BARCTRL'.static.SetValue("SummonedStatusWnd.barHP", MaxValue, Value);
}

//MP바 갱신
function UpdateMPBar(int Value, int MaxValue)
{
	class'UIAPI_BARCTRL'.static.SetValue("SummonedStatusWnd.barMP", MaxValue, Value);
}

//FATIGUE바 초기화
function InitFATIGUEBar()
{
	class'UIAPI_PROGRESSCTRL'.static.Stop("SummonedStatusWnd.progFATIGUE");
	class'UIAPI_PROGRESSCTRL'.static.Reset("SummonedStatusWnd.progFATIGUE");
	m_bSummonedStarted = false;
}
