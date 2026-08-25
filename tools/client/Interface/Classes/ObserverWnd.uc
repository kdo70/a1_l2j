class ObserverWnd extends UICommonAPI;

var bool m_bObserverMode;

function OnLoad()
{
	m_bObserverMode=FALSE;

	RegisterEvent( EV_ObserverWndShow );
	RegisterEvent( EV_ObserverWndHide );
	RegisterEvent( EV_GamingStateEnter );
}

function OnEvent( int Event_ID, string param )
{
	switch( Event_ID )
	{
	case EV_ObserverWndShow :
		m_bObserverMode=TRUE;
		ShowWindow("ObserverWnd");
		break;
	case EV_ObserverWndHide :
		m_bObserverMode=FALSE;
		HideWindow("ObserverWnd");
		break;
	case EV_GamingStateEnter :
		if(m_bObserverMode)
			ShowWindow("ObserverWnd");
		break;
	}
}


function OnClickButton(string strID)
{
	switch(strID)
	{
	case "BtnEnd" :
		RequestObserverModeEnd();
		break;
	}
}
