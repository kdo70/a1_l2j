class SystemMsgWnd	extends UIScript;

function OnLoad()
{
	registerEvent( EV_GamingStateEnter );
}

function OnEvent( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	case EV_GamingStateEnter:
		if( GetOptionBool("Game", "SystemMsgWnd") )
		{
			//debug("SystemMsgWndtest Show");
			class'UIAPI_WINDOW'.static.ShowWindow("SystemMsgWnd");
		}
		else
		{
			//debug("SystemMsgWndtest Hide");
			class'UIAPI_WINDOW'.static.HideWindow("SystemMsgWnd");
		}
		break;
	default:
		break;
	}
}

function OnShow()
{
	//debug("SystemMsgWndtest OnShow");
	class'UIAPI_WINDOW'.static.SetAnchor( "ChatFilterWnd", "SystemMsgWnd", "TopLeft", "BottomLeft", 0, -5 );
	ChangeAnchorEffectButton("SystemMsgWnd");	// lancelot 2006. 7. 10.
}

function OnHide()
{
	//debug("SystemMsgWndtest OnHide");
	class'UIAPI_WINDOW'.static.SetAnchor( "ChatFilterWnd", "ChatWnd", "TopLeft", "BottomLeft", 0, -5 );
	ChangeAnchorEffectButton("ChatWnd");		// lancelot 2006. 7. 10.
}

function ChangeAnchorEffectButton(string strID)
{
	class'UIAPI_WINDOW'.static.SetAnchor( "TutorialBtnWnd", strID, "TopLeft", "BottomLeft", 5, -5 );
	class'UIAPI_WINDOW'.static.SetAnchor( "QuestBtnWnd", StrID, "TopLeft", "BottomLeft", 42, -5 );
	class'UIAPI_WINDOW'.static.SetAnchor( "MailBtnWnd", strID, "TopLeft", "BottomLeft", 79, -5 );
}
