class GametipWnd extends UIScript;

var Array<GameTipData> TipData;
var int CountRecord;
var Userinfo userinfofortip;
var string CurrentTip;
var int numb;

function OnLoad()
{
	LoadGameTipData();	
	RegisterEvent( EV_LanguageChanged );
}

function OnEventWithStr( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	case EV_LanguageChanged:
		LoadGameTipData();
		break;
	}
}

function LoadGameTipData()
{
	local int i;
	local bool gamedataloaded;
	local GameTipData TipData1;
	
	CountRecord = class'UIDATA_GAMETIP'.static.GetDataCount();
	for (i=0; i<CountRecord; ++i)
	{
		gamedataloaded = class'UIDATA_GAMETIP'.static.GetDataByIndex(i, TipData1);
		TipData[ i ] = TipData1;		
	}
}

function OnShow()
{
	local int RandomVal;
	local int PrioritySelect;
	local int UserLevelData;
	local bool userinfoloaded;
	local Array<String> SelectedCondition;	
	local int i;
	local int j;
	local int UserLevel;
	local int UserArrange;
	local int NumberSelect;

	j = 0;
	
	userinfoloaded = GetPlayerInfo(userinfofortip);
	if (userinfoloaded == false)
	{
		//debug("유저인포 로드 실패");
	}
	else 
	{
		//debug("유저인포 로드 성공:" @ userinfofortip.nLevel);
	}
	UserLevelData = userinfofortip.nLevel;
	if (UserLevelData >= 1 && UserLevelData <= 20)
	{
		UserLevel = 1;
	}
	else if (UserLevelData >= 21 && UserLevelData <= 40)
	{
		UserLevel = 20;
	}	
	else if (UserLevelData >= 41 && UserLevelData <= 60)
	{
		UserLevel = 40;
	}
	else if (UserLevelData >= 61 && UserLevelData <= 74)
	{
		UserLevel = 60;
	}
	else if (UserLevelData >= 75 && UserLevelData <= 80)
	{
		UserLevel = 80;
	}
	
	if (UserLevelData < 40)
	{
		UserArrange = 101;
	}
	else
	{
		UserArrange = 102;
	}
	
	
	RandomVal = Rand(99) + 1;
	if (RandomVal >=1 && RandomVal <= 50 )
	{
		PrioritySelect = 1;
	}
	else 	if (RandomVal >=51 && RandomVal <= 75)
	{
		PrioritySelect = 2;
	}
	else 	if (RandomVal >=76 && RandomVal <= 90)
	{
		PrioritySelect = 3;
	}
	else 	if (RandomVal >=91 && RandomVal <= 100)
	{
		PrioritySelect = 4;
	}
	
	//debug("priority:" @ PrioritySelect);

	for (i=0; i<TipData.length; ++i)
	{
		if (TipData[ i ].TipMsg != "") 
		{
			if (TipData[ i ].Priority == PrioritySelect && TipData[ i ].Validity == true )
			{
				if ( TipData[ i ].TargetLevel == UserLevel || TipData[ i ].TargetLevel == 0 || TipData[ i ].TargetLevel  == UserArrange)
				{
				//SelectedCondition[ j ].ID = TipData[ i ].ID;
				//SelectedCondition[ j ].Priority = TipData[ i ].Priority;
				//SelectedCondition[ j ].TargetLevel = TipData[ i ].TargetLevel;
				//SelectedCondition[ j ].Validity = TipData[ i ].Validity;
				SelectedCondition[ j ] = TipData[ i ].TipMsg;
				//debug (SelectedCondition[ j ]);
				++j;
				}
			}
		}
	}
	
	//debug("결과물:" @ SelectedCondition.length @ "개");

	NumberSelect = Rand(SelectedCondition.length);
	
	//debug("추첨번호:" @ NumberSelect);
	
	if (SelectedCondition.length == 0)
	{
		CurrentTip = "";
	}
	else
	{ 
		//Debug("결과:"@ SelectedCondition[NumberSelect]);
		CurrentTip = SelectedCondition[NumberSelect];
	}
	
	
	if (GetOptionBool( "Game", "ShowGameTipMsg" ) == false)
	{		
	class'UIAPI_TEXTBOX'.static.SetText("GametipWnd.GameTipText1", GetSystemString(1455));
	class'UIAPI_TEXTBOX'.static.SetText("GametipWnd.GameTipText1-1", GetSystemString(1455));
	class'UIAPI_TEXTBOX'.static.SetText("GametipWnd.GameTipText1-2", GetSystemString(1455));
	class'UIAPI_TEXTBOX'.static.SetText("GametipWnd.GameTipText", CurrentTip );
	class'UIAPI_TEXTBOX'.static.SetText("GametipWnd.GameTipText-1", CurrentTip );
	class'UIAPI_TEXTBOX'.static.SetText("GametipWnd.GameTipText-2", CurrentTip );
	}
	else
	{
	class'UIAPI_TEXTBOX'.static.SetText("GametipWnd.GameTipText1", "" );
	class'UIAPI_TEXTBOX'.static.SetText("GametipWnd.GameTipText1-1", "");
	class'UIAPI_TEXTBOX'.static.SetText("GametipWnd.GameTipText1-2", "");
	class'UIAPI_TEXTBOX'.static.SetText("GametipWnd.GameTipText", "" );
	class'UIAPI_TEXTBOX'.static.SetText("GametipWnd.GameTipText-1", "" );
	class'UIAPI_TEXTBOX'.static.SetText("GametipWnd.GameTipText-2", "" );
	}

	 //numb = numb+1;


}
