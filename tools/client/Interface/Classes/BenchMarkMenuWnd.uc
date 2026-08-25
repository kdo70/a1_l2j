class BenchMarkMenuWnd extends UIScript;

function OnLoad()
{
	class'UIAPI_WINDOW'.static.SetFocus("BenchMarkMenuWnd.BenchMarkFunctionWnd");
}

function OnClickButton(string strID)
{
	switch(strID)
	{
	case "btnPlay" :
		BeginPlay();
		break;
	case "btnBenchMark" :
		BeginBenchMark();
		break;
	case "btnOption" :
		ShowOptionWnd();
		break;
	case "btnExit" :
		ExecQuit();
		break;
	}
}

function ShowOptionWnd()
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
