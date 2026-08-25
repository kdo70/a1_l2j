class PetStatusWnd extends UIScript;

const NSTATUSICON_MAXCOL = 10;

var bool	m_bBuff;
var bool	m_bShow;
var int	m_PetID;

function OnLoad()
{
	RegisterEvent( EV_UpdatePetInfo );
	RegisterEvent( EV_ShowBuffIcon );
	
	RegisterEvent( EV_PetStatusShow );
	RegisterEvent( EV_PetStatusSpelledList );
	
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
	
	if (PetID<0 || IsPetOrSummoned!=2)
	{
		class'UIAPI_WINDOW'.static.HideWindow("PetStatusWnd");
	}
	else
	{
		m_bShow = true;
	}
}

function OnHide()
{
	m_bShow = false;
}

function OnEnterState( name a_PreStateName )
{
	m_bBuff = false;
}

function OnEvent(int Event_ID, string param)
{
	if (Event_ID == EV_UpdatePetInfo)
	{
		HandlePetInfoUpdate();
	}
	else if (Event_ID == EV_PetSummonedStatusClose)
	{
		HandlePetStatusClose();
	}
	else if (Event_ID == EV_PetStatusShow)
	{
		HandlePetStatusShow();
	}
	else if (Event_ID == EV_ShowBuffIcon)
	{
		HandleShowBuffIcon(param);
	}
	else if (Event_ID == EV_PetStatusSpelledList)
	{
		HandlePetStatusSpelledList(param);
	}
}

//초기화
function Clear()
{
	class'UIAPI_STATUSICONCTRL'.static.Clear("PetStatusWnd.StatusIcon");
	class'UIAPI_NAMECTRL'.static.SetName("PetStatusWnd.PetName", "", NCT_Normal,TA_Center);
	UpdateHPBar(0, 0);
	UpdateMPBar(0, 0);
	UpdateFatigueBar(0, 0);
}

//종료처리
function HandlePetStatusClose()
{
	class'UIAPI_WINDOW'.static.HideWindow("PetStatusWnd");
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

	class'UIAPI_NAMECTRL'.static.SetName("PetStatusWnd.PetName", Name, NCT_Normal,TA_Center);
	UpdateHPBar(HP, MaxHP);
	UpdateMPBar(MP, MaxMP);
	UpdateFatigueBar(Fatigue, MaxFatigue);
}

//펫창을 표시
function HandlePetStatusShow()
{
	Clear();
	class'UIAPI_WINDOW'.static.ShowWindow("PetStatusWnd");
	class'UIAPI_WINDOW'.static.SetFocus("PetStatusWnd");
}

//펫의 버프리스트정보
function HandlePetStatusSpelledList(string param)
{
	local int i;
	local int Max;
	
	local int BuffCnt;
	local int CurRow;
	local StatusIconInfo info;
	
	CurRow = -1;
	
	//버프 초기화
	class'UIAPI_STATUSICONCTRL'.static.Clear("PetStatusWnd.StatusIcon");
	
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
				class'UIAPI_STATUSICONCTRL'.static.AddRow("PetStatusWnd.StatusIcon");
			}
			
			class'UIAPI_STATUSICONCTRL'.static.AddCol("PetStatusWnd.StatusIcon", CurRow, info);	
			
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
	
	rectWnd = class'UIAPI_WINDOW'.static.GetRect("PetStatusWnd");
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
		class'UIAPI_WINDOW'.static.ShowWindow("PetStatusWnd.StatusIcon");
	}
	else
	{
		class'UIAPI_WINDOW'.static.HideWindow("PetStatusWnd.StatusIcon");
	}
	m_bBuff = bShow;
}

//HP바 갱신
function UpdateHPBar(int Value, int MaxValue)
{
	class'UIAPI_BARCTRL'.static.SetValue("PetStatusWnd.barHP", MaxValue, Value);
}

//MP바 갱신
function UpdateMPBar(int Value, int MaxValue)
{
	class'UIAPI_BARCTRL'.static.SetValue("PetStatusWnd.barMP", MaxValue, Value);
}

//Fatigue바 갱신
function UpdateFatigueBar(int Value, int MaxValue)
{
	class'UIAPI_BARCTRL'.static.SetValue("PetStatusWnd.barFatigue", MaxValue, Value);
}
