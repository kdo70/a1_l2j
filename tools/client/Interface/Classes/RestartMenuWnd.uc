class RestartMenuWnd extends UICommonAPI;

var bool m_bShow;
var bool m_bRestartON;

var bool m_bVillage;
var bool m_bAgit;
var bool m_bCastle;
var bool m_bBattleCamp;
var bool m_bOriginal;

//Handle List
var WindowHandle	m_wndTop;
var ButtonHandle	m_btnVillage;
var ButtonHandle	m_btnAgit;
var ButtonHandle	m_btnCastle;
var ButtonHandle	m_btnBattleCamp;
var ButtonHandle	m_btnOriginal;

function OnLoad()
{
	RegisterEvent( EV_Die );
	RegisterEvent( EV_Restart );
	RegisterEvent( EV_RestartMenuShow );
	RegisterEvent( EV_RestartMenuHide );
	
	m_bShow = false;
	m_bRestartON = false;
	
	//Init Handle
	m_wndTop = GetHandle( "RestartMenuWnd" );
	m_btnVillage = ButtonHandle ( GetHandle( "RestartMenuWnd.btnVillage" ) );
	m_btnAgit = ButtonHandle ( GetHandle( "RestartMenuWnd.btnAgit" ) );
	m_btnCastle = ButtonHandle ( GetHandle( "RestartMenuWnd.btnCastle" ) );
	m_btnBattleCamp = ButtonHandle ( GetHandle( "RestartMenuWnd.btnBattleCamp" ) );
	m_btnOriginal = ButtonHandle ( GetHandle( "RestartMenuWnd.btnOriginal" ) );
}

function OnShow()
{
	m_bShow = true;
}

function OnHide()
{
	m_bShow = false;
}

function OnEnterState( name a_PreStateName )
{
	if (m_bRestartON)
	{
		ShowMe();
	}
	else
	{
		HideMe();
	}
}

function OnEvent(int Event_ID, string param)
{
	if (Event_ID == EV_Die)
	{
		HandleDie(param);
	}
	else if (Event_ID == EV_Restart)
	{
		HandleRestart();
	}
	else if (Event_ID == EV_RestartMenuShow)
	{
		HandleRestartMenuShow();
	}
	else if (Event_ID == EV_RestartMenuHide)
	{
		HandleRestartMenuHide();
	}
}

function OnClickButton( string strID )
{
	switch( strID )
	{
	case "btnVillage":
		OnVillageClick();
		break;
	case "btnAgit":
		OnAgitClick();
		break;
	case "btnCastle":
		OnCastleClick();
		break;
	case "btnBattleCamp":
		OnBattleCampClick();
		break;
	case "btnOriginal":
		OnOriginalClick();
		break;
	}
}

//버튼 클릭 처리
function OnVillageClick()
{
	RequestRestartPoint(RPT_VILLAGE);
	HideMe();
	
}
function OnAgitClick()
{
	RequestRestartPoint(RPT_AGIT);
	HideMe();
}
function OnCastleClick()
{
	RequestRestartPoint(RPT_CASTLE);
	HideMe();
}
function OnBattleCampClick()
{
	RequestRestartPoint(RPT_BATTLE_CAMP);
	HideMe();
}
function OnOriginalClick()
{
	RequestRestartPoint(RPT_ORIGINAL_PLACE);
	HideMe();
}

//리스타트 포인트를 받았을때
function HandleDie(string param)
{	
	local int Village;
	local int Agit;
	local int Castle;
	local int BattleCamp;
	local int Original;
	
	ParseInt(param, "Village" ,Village);
	ParseInt(param, "Agit" ,Agit);
	ParseInt(param, "Castle" ,Castle);
	ParseInt(param, "BattleCamp" ,BattleCamp);
	ParseInt(param, "Original" ,Original);
	
	m_bVillage = false;
	m_bAgit = false;
	m_bCastle = false;
	m_bBattleCamp = false;
	m_bOriginal = false;
	
	if (Village>0)
		m_bVillage = true;
	if (Agit>0)
		m_bAgit = true;
	if (Castle>0)
		m_bCastle = true;
	if (BattleCamp>0)
		m_bBattleCamp = true;
	if (Original>0)
		m_bOriginal = true;
}

function HandleRestartMenuShow()
{
	ShowMe();
}

function HandleRestartMenuHide()
{
	HideMe();
}

function HandleRestart()
{
	HideMe();
}

function ShowMe()
{
	m_bRestartON = true;
	m_wndTop.ShowWindow();
	
	if (m_bVillage)
		m_btnVillage.ShowWindow();
	else
		m_btnVillage.HideWindow();
	
	if (m_bAgit)
		m_btnAgit.ShowWindow();
	else
		m_btnAgit.HideWindow();
		
	if (m_bCastle)
		m_btnCastle.ShowWindow();
	else
		m_btnCastle.HideWindow();
		
	if (m_bBattleCamp)
		m_btnBattleCamp.ShowWindow();
	else
		m_btnBattleCamp.HideWindow();
		
	if (m_bOriginal)
		m_btnOriginal.ShowWindow();
	else
		m_btnOriginal.HideWindow();
}

function HideMe()
{
	m_bRestartON = false;
	m_wndTop.HideWindow();
}
