class TutorialViewerWnd extends UICommonAPI;

function OnLoad()
{
	RegisterEvent( EV_TutorialViewerWndShow );
	RegisterEvent( EV_TutorialViewerWndHide );
}

function OnEvent( int Event_ID, string param )
{
	local string HtmlString;
	local Rect rect;

	local int HtmlHeight;

	switch( Event_ID )
	{
	case EV_TutorialViewerWndShow :
		ParseString(param, "HtmlString", HtmlString);

		class'UIAPI_HTMLCTRL'.static.LoadHtmlFromString("TutorialViewerWnd.HtmlTutorialViewer", HtmlString);

		rect=class'UIAPI_WINDOW'.static.GetRect("TutorialViewerWnd");
		HtmlHeight=class'UIAPI_HTMLCTRL'.static.GetFrameMaxHeight("TutorialViewerWnd.HtmlTutorialViewer");

//		debug("rect.nX:"$rect.nX$", rect.nY:"$rect.nY$", rect.nWidth:"$rect.nWidth$", rect.nHeight:"$rect.nHeight$", Height:"$HtmlHeight);

		if(HtmlHeight < 256) 
			HtmlHeight = 256;
		else if(HtmlHeight > 680-8) // 이수치는 원래 소스를 그대로 가져온것 - lancelot 2006. 9. 26
			HtmlHeight = 680-8;

		rect.nHeight=HtmlHeight+32+8;		// +32는 Frame 높이와 상단 텍스쳐 높이를 합한것.  +8은 Html 이 아랫부분이 조금 가리는 경향이 있어서 임의로 보정치를 넣어준것

//		debug("rect.nX:"$rect.nX$", rect.nY:"$rect.nY$", rect.nWidth:"$rect.nWidth$", rect.nHeight:"$rect.nHeight$", Height:"$HtmlHeight);

		class'UIAPI_WINDOW'.static.SetWindowSize("TutorialViewerWnd", rect.nWidth, rect.nHeight);
		class'UIAPI_WINDOW'.static.SetWindowSize("TutorialViewerWnd.texTutorialViewerBack2", rect.nWidth, rect.nHeight-32-9);
		class'UIAPI_WINDOW'.static.MoveTo("TutorialViewerWnd.texTutorialViewerBack3", rect.nX, rect.nY+rect.nHeight-9);

		class'UIAPI_WINDOW'.static.SetWindowSize("TutorialViewerWnd.HtmlTutorialViewer", rect.nWidth-15, rect.nHeight-32-9);
		ShowWindowWithFocus("TutorialViewerWnd");
		break;
	case EV_TutorialViewerWndHide :
		HideWindow("TutorialViewerWnd");
		break;
	}
}
