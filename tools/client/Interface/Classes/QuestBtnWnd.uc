class QuestBtnWnd extends UICommonAPI;

function OnLoad()
{
	RegisterEvent( EV_ArriveShowQuest );
}

function OnEvent( int Event_ID, string param )
{
	local int iEffectNumber;

	ParseInt(param, "QuestID", iEffectNumber);

	switch( Event_ID )
	{
	case EV_ArriveShowQuest :
		ShowWindowWithFocus("QuestBtnWnd");
		class'UIAPI_WINDOW'.static.ShowWindow("QuestBtnWnd.btnQuest");
		class'UIAPI_EFFECTBUTTON'.static.BeginEffect("QuestBtnWnd.btnQuest", iEffectNumber);
		break;
	}
}

function OnClickButton(string strID)
{
	switch(strID)
	{
	case "btnQuest" :
		HideWindow("QuestBtnWnd");
		break;
	}
}
