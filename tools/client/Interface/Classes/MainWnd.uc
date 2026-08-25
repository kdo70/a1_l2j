class MainWnd extends UIScript;

var ClanWnd ClanWndScript;

function OnLoad()
{
	class'UIAPI_WINDOW'.static.SetWindowTitle( "MainWnd", 433 );
	ClanWndScript = ClanWnd( GetScript( "ClanWnd" ) );
}

function OnHide()
{
	// 2006/04/03 - Removed by NeverDie
	//	Drawer child window now automatically hides upon hiding Drawer parent window
	//class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd");
}

function OnMinimize()
{
	local int index;
	index = class'UIAPI_TABCTRL'.static.GetTopIndex("MainWnd.MainTabCtrl");
	if( index == 0 )
		class'UIAPI_WINDOW'.static.Iconize("MainWnd","L2UI_CH3.TABBUTTON.MainWndTabIcon1",194);
	else if( index == 1 )
		class'UIAPI_WINDOW'.static.Iconize("MainWnd","L2UI_CH3.TABBUTTON.MainWndTabIcon2",196);
	else if( index == 2 )
		class'UIAPI_WINDOW'.static.Iconize("MainWnd","L2UI_CH3.TABBUTTON.MainWndTabIcon3",197);
	else if( index == 3 )
		class'UIAPI_WINDOW'.static.Iconize("MainWnd","L2UI_CH3.TABBUTTON.MainWndTabIcon4",895);
	else if( index == 4 )
		class'UIAPI_WINDOW'.static.Iconize("MainWnd","L2UI_CH3.TABBUTTON.MainWndTabIcon5",198);

	ClanWndScript.ResetOpeningVariables();
}

function OnClickButton( string strID )
{
	if( strID == "MainTabCtrl0" )
	{
		class'UIAPI_WINDOW'.static.SetWindowTitle("MainWnd", 433);
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd");
		ClanWndScript.ResetOpeningVariables();
	}
	else if( strID == "MainTabCtrl1" )
	{
		class'UIAPI_WINDOW'.static.SetWindowTitle("MainWnd", 119);
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd");
		ClanWndScript.ResetOpeningVariables();
	}
	else if( strID == "MainTabCtrl2" )
	{
		class'UIAPI_WINDOW'.static.SetWindowTitle("MainWnd", 127);
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd");
		ClanWndScript.ResetOpeningVariables();
	}
	else if( strID == "MainTabCtrl3" )
	{
		class'UIAPI_WINDOW'.static.SetWindowTitle("MainWnd", 439);
		ClanWndScript.getmyClanInfo();
		ClanWndScript.NoblessMenuValidate();
		ClanWndScript.ResetOpeningVariables();
	}
	else if( strID == "MainTabCtrl4" )
	{
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd");
		class'UIAPI_WINDOW'.static.SetWindowTitle("MainWnd", 118);
		ClanWndScript.ResetOpeningVariables();
	}	
}
