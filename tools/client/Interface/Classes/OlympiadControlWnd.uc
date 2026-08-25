class OlympiadControlWnd extends UIScript;

function OnLoad()
{
}

function OnClickButton(string strID)
{
	switch (strID)
	{
		case "btnStop":
			class'OlympiadAPI'.static.RequestOlympiadObserverEnd();
			break;
		case "btnOtherGame":
			class'OlympiadAPI'.static.RequestOlympiadMatchList();
			break;
	}
}
