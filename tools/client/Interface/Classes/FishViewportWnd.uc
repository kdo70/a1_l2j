class FishViewportWnd extends UICommonAPI;

function OnLoad()
{
	RegisterEvent( EV_FishViewportWndShow );
	RegisterEvent( EV_FishViewportWndHide );
	RegisterEvent( EV_FishRankEventButtonShow );
	RegisterEvent( EV_FishRankEventButtonHide );
}

function OnEvent( int Event_ID, string param )
{
	switch( Event_ID )
	{
	case EV_FishViewportWndShow :
		ShowWindowWithFocus("FishViewportWnd");
		break;
	case EV_FishViewportWndHide :
		HideWindow("FishViewportWnd");
		break;
	// 사용하지 않음 - lancelot 2006. 11. 27.
	//case EV_FishViewportWndInit :
	//	ParseInt(param, "Event", Event);
	//	if(Event==0)
	//		bEvent=false;
	//	else
	//		bEvent=true;
	//	InitFishViewportWnd(bEvent);
	//	break;
	//case EV_FishViewportWndFinalAction :
	//	FishFinalAction();
	//	break;

	case EV_FishRankEventButtonShow :
		ShowWindow("FishViewportWnd.btnRanking");
		break;
	case EV_FishRankEventButtonHide :
		HideWindow("FishViewportWnd.btnRanking");
		break;
	}
}

function OnClickButton(string strID)
{
	switch(strID)
	{
	case "btnRanking" :
		RequestFishRanking();
		break;
	}
}
