class TutorialBtnWnd extends UICommonAPI;

function OnLoad()
{
	RegisterEvent( EV_ArriveNewTutorialQuestion );
}

function OnEvent( int Event_ID, string param )
{
	local int iEffectNumber;

	ParseInt(param, "QuestionID", iEffectNumber);

	switch( Event_ID )
	{
	case EV_ArriveNewTutorialQuestion :
		ShowWindowWithFocus("TutorialBtnWnd");
		class'UIAPI_EFFECTBUTTON'.static.BeginEffect("TutorialBtnWnd.btnTutorial", iEffectNumber);
		break;
	}
}

function OnClickButton(string strID)
{
	switch(strID)
	{
	case "btnTutorial" :
		HideWindow("TutorialBtnWnd");
		break;
	}
}
