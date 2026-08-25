class OnScreenMessageWnd extends UIScript;
var string currentwnd1;
var bool onshowstat1;
var bool onshowstat2;
var int timerset1;
var int globalAlphavalue1;
var int globalAlphavalue2;
var int globalDuration;
var int droprate;
var int moveval;
var int moveval2;
var string MovedWndName;
var int m_TimerCount;
var bool linedivided;

function OnLoad()
{
	
	RegisterEvent(EV_ShowScreenMessage);
	RegisterEvent(EV_SystemMessage);
	ResetAllMessage();
	timerset1 = 0;
	moveval = 0;
	moveval2 = 0;
	globalAlphavalue1 = 0;
	globalAlphavalue2 = 255;
	m_TimerCount = 0;

	//ShowMsg(2, "Hello World! This is Choonsik Moon", 3000, 11, 0, 1, 255, 255, 255);
	//ShowMsg(8,"Hello World! Hello World! Hello World!#Hello World!", 3000, 11, 0, 0);

}

function OnTick()
{
	if (onshowstat1 == true)
	{
		fadeIn(currentwnd1);
		//debug ("alpha=" $ globalAlphavalue1);
	}
	
	if (onshowstat2 == true)
	{
		fadeOut(currentwnd1);
		//debug ("alpha2=" $ globalAlphavalue2);
	}
	
}

function OnTimer(int TimerID)
{
	if (m_TimerCount>0)
	{
		class'UIAPI_WINDOW'.static.KillUITimer("OnScreenMessageWnd1",m_TimerCount);
		m_TimerCount--;
		if (m_TimerCount<1)
		{
			m_TimerCount = 0;
			onshowstat2 = true;
		}
	}	
}

function OnHide()
{
	
}

function ResetAllMessage()
{
	local int i;
	local Color DefaultColor;
	local string wndname;

	DefaultColor.R = 255;
	DefaultColor.G = 255;
	DefaultColor.B = 255;
	
	globalAlphavalue1 = 0;
	globalAlphavalue2 = 255;
	
	currentwnd1 = "";
	onshowstat1 = false;
	onshowstat2 = false;
	// Set DefaultColor for all the Screen Messages
	class'UIAPI_WINDOW'.static.HideWindow("OnScreenMessageWnd1");
	class'UIAPI_WINDOW'.static.HideWindow("OnScreenMessageWnd2");
	class'UIAPI_WINDOW'.static.HideWindow("OnScreenMessageWnd3");
	class'UIAPI_WINDOW'.static.HideWindow("OnScreenMessageWnd4");
	class'UIAPI_WINDOW'.static.HideWindow("OnScreenMessageWnd5");
	class'UIAPI_WINDOW'.static.HideWindow("OnScreenMessageWnd6");
	class'UIAPI_WINDOW'.static.HideWindow("OnScreenMessageWnd7");
	class'UIAPI_WINDOW'.static.HideWindow("OnScreenMessageWnd8");
		
	for (i = 1; i <= 8; ++i )
	{
		wndname = "OnScreenMessageWnd" $ i;
	
		class'UIAPI_TEXTBOX'.static.SetTextColor( wndname $ ".TextBox" $ i , DefaultColor);
		class'UIAPI_TEXTBOX'.static.SetTextColor( wndname $ ".TextBox" $ i $ "-1" , DefaultColor);
		class'UIAPI_TEXTBOX'.static.SetTextColor( wndname $ ".TextBoxsm" $ i  , DefaultColor);
		class'UIAPI_TEXTBOX'.static.SetTextColor( wndname $ ".TextBoxsm" $ i $ "-1" , DefaultColor);
	}
	//장식 이미지 현재 위치 리셋
	
	//if (linedivided == true)
		//class'UIAPI_WINDOW'.static.Move("OnScreenMessageWnd2.texturetype2", 0, -30, 0);
		
}

function ShowMsg(int WndNum, string TextValue, int Duration, int Animation, int fonttype, int backgroundtype, int ColorR, int ColorG, int ColorB)
{
	local string WndName;
	local string TextBoxName;
	local string ShadowBoxName;
	local string TextBoxName2;
	local string ShadowBoxName2;
	local string TextValue1;
	local string TextValue2;
	local string CurText;
	local string 	SmallBoxName1;
	local string 	SmallBoxName2;
	
	local color FontColor;

	local int i;
	local int j;
	local int LengthTotal;
	//local int LengthSum;
	local int TotalLength;
	local int TextOffsetTotal1;
	
	//local int TextOffsetTotal2;
	
	j = 1;
	TotalLength =  Len(TextValue);
	TextValue1 = "";
	TextValue2 = "";
	linedivided = false; 
	
	FontColor.R = ColorR;
	FontColor.G = ColorG;
	FontColor.B = ColorB;
	
	debug ("totalval" @ TextValue);
	
	//Debug ("CurrentL:"@ Len(TextValue));
	
	for (i=1; i <= TotalLength; ++i)
	{
		LengthTotal = Len(TextValue) - 1;
		CurText = Left(TextValue, 1);
		TextValue = Right(TextValue, LengthTotal);
		
		if(CurText =="`")
		{
			CurText = "";
		}
		
		if(CurText =="#")
		{
			CurText = "";
			j = 2;
			linedivided = true;
		}
		
		 if (j == 1)
		 {
			TextValue1 = TextValue1 $ CurText;
		 }
		else
		{
			TextValue2 = TextValue2 $ CurText;
		}
	}


	debug (TextValue1);
	debug (TextValue2);
		
	WndName = "OnScreenMessageWnd" $ WndNum;
	TextBoxName = WndName $ ".TextBox" $ WndNum;
	ShadowBoxName = WndName $".TextBox" $ WndNum $ "-0";
	TextBoxName2 = WndName $ ".TextBox" $ WndNum $ "-1";
	ShadowBoxName2 = WndName $".TextBox" $ WndNum $ "-1-0";
	SmallBoxName1 = WndName $".TextBoxsm" $ WndNum;
	SmallBoxName2 = WndName $".TextBoxsm" $ WndNum $ "-1";
	
	
	//debug("TBN:" $ TextBoxName $ Duration $ Animation);
	currentwnd1 = WndName;
	

	class'UIAPI_TEXTBOX'.static.SetTextColor( TextBoxName , FontColor);
	class'UIAPI_TEXTBOX'.static.SetTextColor( TextBoxName2 , FontColor);
	class'UIAPI_TEXTBOX'.static.SetTextColor( SmallBoxName1 , FontColor);
	class'UIAPI_TEXTBOX'.static.SetTextColor( SmallBoxName2 , FontColor);

	if (fonttype == 0)
	{
	class'UIAPI_WINDOW'.static.ShowWindow(currentwnd1);
	class'UIAPI_TEXTBOX'.static.SetText(ShadowBoxName,TextValue1);
	class'UIAPI_TEXTBOX'.static.SetText(TextBoxName,TextValue1);
	class'UIAPI_TEXTBOX'.static.SetText(ShadowBoxName2,TextValue2);
	class'UIAPI_TEXTBOX'.static.SetText(TextBoxName2,TextValue2);
	class'UIAPI_TEXTBOX'.static.SetText(SmallBoxName1,"");
	class'UIAPI_TEXTBOX'.static.SetText(SmallBoxName2,"");
	}
	else if (fonttype == 1)
	{
	class'UIAPI_WINDOW'.static.ShowWindow(currentwnd1);
	class'UIAPI_TEXTBOX'.static.SetText(ShadowBoxName,"");
	class'UIAPI_TEXTBOX'.static.SetText(TextBoxName,"");
	class'UIAPI_TEXTBOX'.static.SetText(ShadowBoxName2,"");
	class'UIAPI_TEXTBOX'.static.SetText(TextBoxName2,"");
	class'UIAPI_TEXTBOX'.static.SetText(SmallBoxName1,TextValue1);
	class'UIAPI_TEXTBOX'.static.SetText(SmallBoxName2,TextValue2);
	}	
	
	if (WndNum == 2)
	{
		if (moveval != 0)
		{
		//class'UIAPI_WINDOW'.static.Move(MovedWndName, 1 * moveval, 0);
		//class'UIAPI_WINDOW'.static.Move(MovedWndName$".texturetype1", -1 * moveval2, 0);
		//class'UIAPI_WINDOW'.static.Move(MovedWndName$".texturetype2", -1 * moveval2, 0);
		}
		MovedWndName = WndName;
		//moveval = ((TextOffsetTotal1/2)*25);
		moveval2 = ((TextOffsetTotal1/2)*29);
		//class'UIAPI_WINDOW'.static.Move(MovedWndName, -1 * moveval, 0);
		if (backgroundtype == 1)
		{			
			class'UIAPI_WINDOW'.static.ShowWindow(MovedWndName$".texturetype1");
			//class'UIAPI_WINDOW'.static.ShowWindow(MovedWndName$".texturetype2");
			
			//if (linedivided == true)
				//class'UIAPI_WINDOW'.static.Move(MovedWndName$".texturetype2", 0, 30, 0);
			
			//class'UIAPI_WINDOW'.static.Move(MovedWndName$".texturetype1", -1 * moveval2, 0);
			//class'UIAPI_WINDOW'.static.Move(MovedWndName$".texturetype2",  -1 * moveval2, 0);
		}
		else 
		{
			class'UIAPI_WINDOW'.static.HideWindow(MovedWndName$".texturetype1");
			//class'UIAPI_WINDOW'.static.HideWindow(MovedWndName$".texturetype2");
		}
		
	}
	
	else if (WndNum == 5)
	{
		if (moveval != 0)
		{
		//class'UIAPI_WINDOW'.static.Move(MovedWndName, 1 * moveval, 0);
		}
		MovedWndName = WndName;
		//moveval = ((TextOffsetTotal1/2)*30);
		//class'UIAPI_WINDOW'.static.Move(MovedWndName, -1 * moveval, 0);
	}
	
	else if (WndNum == 7)
	{
		if (moveval != 0)
		{
		//class'UIAPI_WINDOW'.static.Move(MovedWndName, 1 * moveval, 0);
		}
		MovedWndName = WndName;
		//moveval = ((TextOffsetTotal1/2)*30);
		//class'UIAPI_WINDOW'.static.Move(MovedWndName, -1 * moveval, 0);
	} 
	
	else 
	{
		moveval = 0;
	}
	
	
	onshowstat1 = true;
	onshowstat2 = false;
	globalDuration = Duration;
	switch (Animation)
	{
		case 0:
			droprate = 255;
		break;
		case 1:
			droprate = 25;
		break;
		case 11:
			droprate = 15;
		break;
		case 12:
			droprate = 25;
		break;
		case 13:
			droprate = 35;
		break;
	}
}


function fadeIn(string WndName)
{
	globalAlphavalue1 = globalAlphavalue1 + droprate;
	if (globalAlphavalue1 < 255)
	{
		class'UIAPI_WINDOW'.static.SetAlpha(WndName, globalAlphavalue1);
	}
	else
	{
		class'UIAPI_WINDOW'.static.SetAlpha(WndName, 255);
		globalAlphavalue1 = 0;
		onshowstat1 = false;
		m_TimerCount++;
		class'UIAPI_WINDOW'.static.SetUITimer("OnScreenMessageWnd1",m_TimerCount,globalDuration);
	}
}

function fadeOut(string WndName)
{
	globalAlphavalue2 = globalAlphavalue2 - droprate;
	if (globalAlphavalue2 > 1)
	{
		class'UIAPI_WINDOW'.static.SetAlpha(WndName, globalAlphavalue2);
	}
	else
	{
		class'UIAPI_WINDOW'.static.SetAlpha(WndName, 0);
		//debug("thisisrunningright");
		globalAlphavalue2 = 255;
		onshowstat2 = false;
		ResetAllMessage();
		//class'UIAPI_WINDOW'.static.Move(MovedWndName, 1 * moveval, 0);
	
		// 혹시 고치게 되면 이부분을 주의 하시라. 
		//class'UIAPI_WINDOW'.static.Move(MovedWndName$".texturetype1", -1 * moveval2, 0);
		//class'UIAPI_WINDOW'.static.Move(MovedWndName$".texturetype2", -1 * moveval2, 0);
		//
		moveval2 = 0;
		moveval = 0;
	}
}

function OnEvent( int a_EventID, String a_Param )
{
	local int msgtype;
	local int msgno;
	local int windowtype;	
	local int fontsize;
	local int fonttype;
	local int msgcolor;
	local int msgcolorR;
	local int msgcolorG;
	local int msgcolorB;
	local int shadowtype;
	local int backgroundtype;
	local int lifetime;
	local int animationtype;
	local int SystemMsgIndex;
	local string msgtext;
	local string ParamString1;
	local string ParamString2;

	if( a_EventID == EV_ShowScreenMessage )
	{
		ParseInt( a_Param, "MsgType", msgtype );
		ParseInt( a_Param, "MsgNo", msgno );
		ParseInt( a_Param, "WindowType", windowtype );
		ParseInt( a_Param, "FontSize", fontsize );
		ParseInt( a_Param, "FontType", fonttype );
		ParseInt( a_Param, "MsgColor", msgcolor );
		if (!ParseInt( a_Param, "MsgColorR", msgcolorR ))
			msgcolorR = 255;
		if (!ParseInt( a_Param, "MsgColorG", msgcolorG ))
			msgcolorG = 255;
		if (!ParseInt( a_Param, "MsgColorB", msgcolorB ))
			msgcolorB = 255;
		ParseInt( a_Param, "ShadowType", shadowtype );
		ParseInt( a_Param, "BackgroundType", backgroundtype );
		ParseInt( a_Param, "LifeTime", lifetime );
		ParseInt( a_Param, "AnimationType", animationtype );
		ParseString( a_Param, "Msg", msgtext );

		ResetAllMessage();
		switch(msgtype)
		{
			case 1:		
			ShowMsg(windowtype, msgtext, lifetime, animationtype, fonttype, backgroundtype, msgcolorR, msgcolorG, msgcolorB);
			break;
			case 0:	
			msgtext =  GetSystemMessage(msgno);
			ShowMsg(windowtype, msgtext, lifetime, animationtype, fonttype, backgroundtype, msgcolorR, msgcolorG, msgcolorB);
			break;
		}
	}
	
	if( a_EventID == EV_SystemMessage )
	{
		ParseInt ( a_Param, "Index", SystemMsgIndex );
		ParseString ( a_Param, "Param1", ParamString1 );
		ParseString ( a_Param, "Param2", ParamString2 );
		//debug("SystemMsg Param1:" $ ParamString1);
		//debug("SystemMsg Param2:" $ ParamString2);
		ValidateSystemMsg( SystemMsgIndex, ParamString1, ParamString2 );
	}
}

function ValidateSystemMsg(int Index, string StringTxt1, string StringTxt2)
{
	
	local SystemMsgData SystemMsgCurrent;
	local int windowtype;	
	local int fonttype;
	local int backgroundtype;
	local int lifetime;
	local int animationtype;
	local string msgtext;
	local Color TextColor;
	
	GetSystemMsgInfo( Index, SystemMsgCurrent);
	
	
	if ( SystemMsgCurrent.WindowType != 0 )
	{
		windowtype = SystemMsgCurrent.WindowType; 
		msgtext = SystemMsgCurrent.OnScrMsg;
		msgtext = MakeFullSystemMsg( msgtext, StringTxt1, StringTxt2 );
		lifetime = (SystemMsgCurrent.LifeTime * 1000);
		animationtype = SystemMsgCurrent.AnimationType;
		fonttype = SystemMsgCurrent.FontType;
		backgroundtype = SystemMsgCurrent.backgroundtype;
		TextColor = SystemMsgCurrent.Color;
		
		if (TextColor.R == 0 && TextColor.G == 0 && TextColor.B == 0 )
		{
			TextColor.R = 255;
			TextColor.G = 255; 
			TextColor.B = 255; 
		}
		else if (TextColor.R == 176 && TextColor.G == 155 && TextColor.B == 121 )
		{
			TextColor.R = 255;
			TextColor.G = 255; 
			TextColor.B = 255; 
		}
		
		//Debug ("ColorR:" @ TextColor.R );
		//Debug ("ColorG:" @ TextColor.G );
		//Debug ("ColorB:" @ TextColor.B );
		                       
		ShowMsg(windowtype, msgtext, lifetime, animationtype, fonttype, backgroundtype, TextColor.R, TextColor.G, TextColor.B);

	}
}
