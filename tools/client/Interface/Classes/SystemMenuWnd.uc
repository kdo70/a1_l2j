class SystemMenuWnd extends UICommonAPI;

function OnLoad()
{
	
	RegisterEvent( EV_DialogOK );
	RegisterEvent( EV_LanguageChanged );

	SetMenuString();
}

function OnClickButton( string strID )
{
	switch( strID )
	{
	case "btnBBS":
		HandleShowBoardWnd();
		break;
	case "btnMacro":
		HandleShowMacroListWnd();
		break;
	case "btnHelpHtml":
		HandleShowHelpHtmlWnd();
		break;
	case "btnPetition":
		HandleShowPetitionBegin();
		break;
	case "btnOption":
		HandleShowOptionWnd();
		break;
	case "btnRestart":
		DialogHide();	// 이미 창이 떠있다면 지워준다.
		DialogShow(DIALOG_Warning, GetSystemMessage(126));		
		DialogSetID(0);
		break;
	case "btnQuit":
		DialogHide();	// 이미 창이 떠있다면 지워준다.
		DialogShow(DIALOG_Warning, GetSystemMessage(125));		
		DialogSetID(1);
		break;
	}
}

function OnEvent(int Event_ID, String param)
{
	if (Event_ID == EV_DialogOK)
	{
		if (DialogIsMine())
		{
			//Restart
			if (DialogGetID() == 0 )
			{
				//리스타트시 지워줘야할 윈도우들. 
				class'UIAPI_WINDOW'.static.HideWindow("SystemMenuWnd");
				ExecRestart();
			}
			//Quit
			else
			{
				ExecQuit();
			}
		}
	}
	else if( Event_ID == EV_LanguageChanged )
	{
		SetMenuString();
	}
}

function HandleShowBoardWnd()
{
	local string strParam;
	ParamAdd(strParam, "Init", "1");
	ExecuteEvent(EV_ShowBBS, strParam);
}

function HandleShowHelpHtmlWnd()
{
	local string strParam;
	ParamAdd(strParam, "FilePath", "..\\L2text\\help.htm");
	ExecuteEvent(EV_ShowHelp, strParam);
}

function HandleShowMacroListWnd()
{
	ExecuteEvent(EV_MacroShowListWnd);
}

function HandleShowPetitionBegin()
{
	if (class'UIAPI_WINDOW'.static.IsShowWindow("UserPetitionWnd"))
	{
		PlayConsoleSound(IFST_WINDOW_CLOSE);
		class'UIAPI_WINDOW'.static.HideWindow("UserPetitionWnd");
	}
	else
	{
		PlayConsoleSound(IFST_WINDOW_OPEN);
		class'UIAPI_WINDOW'.static.ShowWindow("UserPetitionWnd");
		class'UIAPI_WINDOW'.static.SetFocus("UserPetitionWnd");
	}
}

function HandleShowOptionWnd()
{
	if (class'UIAPI_WINDOW'.static.IsShowWindow("OptionWnd"))
	{
		PlayConsoleSound(IFST_WINDOW_CLOSE);
		class'UIAPI_WINDOW'.static.HideWindow("OptionWnd");
	}
	else
	{
		PlayConsoleSound(IFST_WINDOW_OPEN);
		class'UIAPI_WINDOW'.static.ShowWindow("OptionWnd");
		class'UIAPI_WINDOW'.static.SetFocus("OptionWnd");
	}
}

function SetMenuString()
{
	//단축키 붙여주기
	class'UIAPI_TEXTBOX'.static.SetText("SystemMenuWnd.txtBBS", GetSystemString(387) $ "(Alt+B)");
	class'UIAPI_TEXTBOX'.static.SetText("SystemMenuWnd.txtMacro", GetSystemString(711) $ "(Alt+R)");
}
