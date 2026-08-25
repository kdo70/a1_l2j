class MailBtnWnd extends UICommonAPI;

function OnLoad()
{
	RegisterEvent( EV_ArriveNewMail );
}

function OnEvent( int Event_ID, string param )
{
	local int iEffectNumber;

	ParseInt(param, "IdxMail", iEffectNumber);

	switch( Event_ID )
	{
	case EV_ArriveNewMail :
		ShowWindowWithFocus("MailBtnWnd");
		class'UIAPI_EFFECTBUTTON'.static.BeginEffect("MailBtnWnd.btnMail", iEffectNumber);
		break;
	}
}

function OnClickButton(string strID)
{
	switch(strID)
	{
	case "btnMail" :
		HideWindow("MailBtnWnd");
		break;
	}
}
