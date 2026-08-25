class RadarWnd extends UIScript;

var bool onshowstat1;
var bool onshowstat2;
var int globalAlphavalue1;
var int globalyloc;
var float numberstrange;
var int global_move_val;

function SetRadarColor( Color a_RadarColor, float a_Seconds )
{
	class'UIAPI_RADAR'.static.SetRadarColor( "RadarContainerWnd.Radar", a_RadarColor, a_Seconds );
}

function OnLoad()
{
	registerEvent(EV_SetRadarZoneCode);
	onshowstat1 = false;
	onshowstat2 = false;
	globalAlphavalue1 = 0;
	globalyloc = 0;
	numberstrange =0;
	global_move_val =0;
	class'UIAPI_WINDOW'.static.HideWindow("movingtext");
	HideAllIcons();
	init_textboxmove();
}

function OnShow()
{
	HideAllIcons();
}

function OnTick()
{
	if (onshowstat2 == true)
	{
		fadeIn();
	}
	if (onshowstat1 == true)
	{
		fadeOut();
	}
	
}

function fadeIn()
{
	globalAlphavalue1 = globalAlphavalue1 + 3;
	if (globalAlphavalue1 < 255)
	{
	class'UIAPI_WINDOW'.static.SetAlpha("movingtext", globalAlphavalue1);
	} else {
	class'UIAPI_WINDOW'.static.SetAlpha("movingtext", 255);
	onshowstat1 = true;
	onshowstat2 = false;
	}
}

function fadeOut()
{
	//global_move_val = move_value();
	globalAlphavalue1 = globalAlphavalue1 - 2;
	globalyloc = globalyloc + 1;
	if (globalAlphavalue1 > 1)
	{
	//debug("OnTick");
	class'UIAPI_WINDOW'.static.SetAlpha("movingtext", globalAlphavalue1);
	//class'UIAPI_WINDOW'.static.Move("movingtext", 0, global_move_val);
	} else {
	class'UIAPI_WINDOW'.static.SetAlpha("movingtext", 0);
	class'UIAPI_WINDOW'.static.HideWindow("movingtext");
	//class'UIAPI_WINDOW'.static.Move("movingtext", 0,globalyloc/2);
	globalyloc = 0;
	global_move_val =0;
	debug("thisisrunningright:" $ globalyloc/2);
	globalAlphavalue1 = 0;
	onshowstat1 = false;
	onshowstat2 = false;
	}
}

function int move_value()
{
	local int movevalue;
	numberstrange = numberstrange + 0.5;
	if (numberstrange < 1)
	{
		movevalue = 0;
		return movevalue;
	} 
	if (numberstrange == 1)
	{
		movevalue = -1;
		numberstrange = 0;
		return movevalue;
	}
}	

function resetanimloc()
{
	//class'UIAPI_WINDOW'.static.Move("movingtext", 0,globalyloc/2);
	onshowstat1 = false;
	onshowstat2 = false;
	globalyloc = 0;
	global_move_val =0;
	globalAlphavalue1 = 0;
}


function HideAllIcons()
{
	class'UIAPI_WINDOW'.static.HideWindow("RadarWnd.icon1");
	class'UIAPI_WINDOW'.static.HideWindow("RadarWnd.icon2");
	class'UIAPI_WINDOW'.static.HideWindow("RadarWnd.icon3");
	class'UIAPI_WINDOW'.static.HideWindow("RadarWnd.icon4");
	class'UIAPI_WINDOW'.static.HideWindow("RadarWnd.icon5");
	class'UIAPI_WINDOW'.static.HideWindow("RadarWnd.icon6");
	class'UIAPI_WINDOW'.static.HideWindow("RadarWnd.icon7");
	class'UIAPI_WINDOW'.static.HideWindow("RadarWnd.icon8");
	class'UIAPI_WINDOW'.static.HideWindow("RadarWnd.icon9");
	class'UIAPI_WINDOW'.static.HideWindow("RadarWnd");
}

function OnEvent( int Event_ID, String a_Param )
{
	local int type;
	local Color Red;
	local Color Blue;
	local Color Grey;
	local Color Orange;
	local Color Green;
	Red.R = 50;
	Red.G = 0;
	Red.B = 0;
	Blue.R = 0;
	Blue.G = 0;
	Blue.B = 50;
	Grey.R = 30;
	Grey.G = 30;
	Grey.B = 30;
	Orange.R = 60;
	Orange.G = 30;
	Orange.B = 0;
	Green.R = 0;
	Green.G = 50;
	Green.B = 0;
	
	if(Event_ID == EV_SetRadarZoneCode)
	{
		ParseInt( a_Param, "ZoneCode", type );
		resetanimloc();
		onshowstat2 = true;
		class'UIAPI_WINDOW'.static.SetAlpha("movingtext", 0);
		class'UIAPI_WINDOW'.static.ShowWindow("movingtext");
		switch (type)
		{
		//Ordinary Field: Grey
		case 15:
		HideAllIcons();
		//class'UIAPI_WINDOW'.static.SetTooltipText("RadarWnd", 1718);
		//class'UIAPI_WINDOW'.static.SetTooltipText("RadarWnd", 1284);
		//class'UIAPI_WINDOW'.static.ShowWindow("RadarWnd.icon1");
		class'UIAPI_TEXTBOX'.static.SetText("movingtext.textboxmove", GetSystemString(1284));
		SetRadarColor(Grey, 2.f);
		break;
		//Peace Zone: Blue
		case 12:
		HideAllIcons();
		//class'UIAPI_WINDOW'.static.SetTooltipText("RadarWnd", 1285);
		//class'UIAPI_WINDOW'.static.SetTooltipText("RadarWnd", 1715);
		//class'UIAPI_WINDOW'.static.ShowWindow("RadarWnd.icon2");
		class'UIAPI_TEXTBOX'.static.SetText("movingtext.textboxmove", GetSystemString(1285));
		SetRadarColor(Blue, 2.f);
		break;
		//Siege Warfare Zone: Orange
		case 11:
		HideAllIcons();
		//class'UIAPI_WINDOW'.static.SetTooltipText("icon6", 1286);
		//class'UIAPI_WINDOW'.static.SetTooltipText("RadarWnd", 1720);
		//class'UIAPI_WINDOW'.static.ShowWindow("RadarWnd.icon3");
		class'UIAPI_TEXTBOX'.static.SetText("movingtext.textboxmove", GetSystemString(1286));
		SetRadarColor(Orange, 2.f);
		break;
		//Buff Zone: Green
		case 9:
		HideAllIcons();
		//class'UIAPI_WINDOW'.static.SetTooltipText("RadarWnd", 1287);
		//class'UIAPI_WINDOW'.static.SetTooltipText("RadarWnd", 1716);
		//class'UIAPI_WINDOW'.static.ShowWindow("RadarWnd.icon4");
		class'UIAPI_TEXTBOX'.static.SetText("movingtext.textboxmove", GetSystemString(1287));
		SetRadarColor(Red, 2.f);
		break;
		//DeBuff Zone: Red
		case 8:
		HideAllIcons();
		//class'UIAPI_WINDOW'.static.SetTooltipText("RadarWnd", 1288);
		//class'UIAPI_WINDOW'.static.SetTooltipText("RadarWnd", 1717);
		//class'UIAPI_WINDOW'.static.ShowWindow("RadarWnd.icon5");
		class'UIAPI_TEXTBOX'.static.SetText("movingtext.textboxmove", GetSystemString(1288));
		SetRadarColor(Red, 2.f);
		break;
		//SSQZone: Grey
		case 13:
		HideAllIcons();
		//class'UIAPI_WINDOW'.static.SetTooltipText("RadarWnd", 1289);
		//class'UIAPI_WINDOW'.static.SetTooltipText("RadarWnd", 1719);
		class'UIAPI_WINDOW'.static.ShowWindow("RadarWnd");
		class'UIAPI_WINDOW'.static.ShowWindow("RadarWnd.icon6");
		class'UIAPI_TEXTBOX'.static.SetText("movingtext.textboxmove", GetSystemString(1289));
		SetRadarColor(Grey, 2.f);
		break;
		//PVPZone: Green
		case 14:
		HideAllIcons();
		//class'UIAPI_WINDOW'.static.SetTooltipText("RadarWnd", 1290);
		//class'UIAPI_WINDOW'.static.SetTooltipText("RadarWnd", 1721);
		//class'UIAPI_WINDOW'.static.ShowWindow("RadarWnd.icon7");
		class'UIAPI_TEXTBOX'.static.SetText("movingtext.textboxmove", GetSystemString(1290));
		SetRadarColor(Green, 2.f);
		break;
		}
	}
}

function init_textboxmove()
{
	class'UIAPI_TEXTBOX'.static.SetText("movingtext.textboxmove", "");
}
