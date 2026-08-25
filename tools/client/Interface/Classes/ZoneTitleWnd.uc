class ZoneTitleWnd extends UICommonAPI;

const StartZoneNameX=100;
const StartZoneNameY=80;

const TIMER_ID=0;
const TIMER_DELAY=4000;

var int a;

function OnLoad()
{
	RegisterEvent( EV_BeginShowZoneTitleWnd );
}

function OnEvent( int Event_ID, string param )
{
	local string ZoneName;
	local string SubZoneName1;
	local string SubZoneName2;

	switch( Event_ID )
	{
	case EV_BeginShowZoneTitleWnd :
		ParseString(param, "ZoneName", ZoneName);
		ParseString(param, "SubZoneName1", SubZoneName1);
		ParseString(param, "SubZoneName2", SubZoneName2);
		BeginShowZoneName(ZoneName, SubZoneName1, SubZoneName2);
		break;
	}
}

function BeginShowZoneName(string ZoneName, string SubZoneName1, string SubZoneName2)
{
	local int TextWidth;
	local int TextHeight;
	local int ScreenWidth;
	local int ScreenHeight;

	// 지금은 ZoneName 만 사용하고 있는데 클라이언트 원래 코드가 확장성을 위해 SubZoneName1, SubZoneName2 도 보낼 수 있게 되어있음
	// 필요하다면 XML에서 컨트롤을 삽입하고 사용가능
	// lancelot 2006. 8. 29.

	class'UIAPI_TEXTBOX'.static.SetText("textZoneNameBack", ZoneName);
	class'UIAPI_TEXTBOX'.static.SetText("textZoneNameFront", ZoneName);

	GetZoneNameTextSize(ZoneName, TextWidth, TextHeight);
	GetCurrentResolution(ScreenWidth, ScreenHeight);

	class'UIAPI_WINDOW'.static.SetWindowSize("ZoneTitleWnd", TextWidth+StartZoneNameX, 200);
	class'UIAPI_WINDOW'.static.MoveTo("ZoneTitleWnd", ScreenWidth/2-TextWidth/2-StartZoneNameX, ScreenHeight/5-StartZoneNameY);

	ShowWindow("ZoneTitleWnd");

	class'UIAPI_WINDOW'.static.SetUITimer("ZoneTitleWnd",TIMER_ID,TIMER_DELAY);
}

function OnTimer(int TimerID)
{
	class'UIAPI_WINDOW'.static.KillUITimer("ZoneTitleWnd",TimerID);
	HideWindow("ZoneTitleWnd");
}
