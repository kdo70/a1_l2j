class MinimapWnd extends UICommonAPI;

var int m_PartyMemberCount;
var int m_PartyLocIndex;
var int b_IsShowGuideWnd;
var bool m_AdjustCursedLoc;

var int m_SSQStatus;				// 세븐사인상태가지고 있는 변수
var bool m_bShowSSQType;			// 세븐사인 상태 보여줄것인가를 기억하는 변수
var bool m_bShowCurrentLocation;	// 현재위치 보여줄것인가를 기억하는 변수
var bool m_bShowGameTime;			// 현재시간 보여줄것인가를 기억하는 변수

var WindowHandle m_hExpandWnd;
var WindowHandle m_hGuideWnd;

var bool m_bExpandState;



function OnLoad()
{
	//debug("미니맵 로드 됨");
	m_PartyLocIndex = -1;
	m_PartyMemberCount = GetPartyMemberCount();
	RegisterEvent( EV_ShowMinimap );
	RegisterEvent( EV_PartyMemberChanged );
	RegisterEvent( EV_MinimapAddTarget );
	RegisterEvent( EV_MinimapDeleteTarget );
	RegisterEvent( EV_MinimapDeleteAllTarget );
	RegisterEvent( EV_MinimapShowQuest );
	RegisterEvent( EV_MinimapHideQuest );
	RegisterEvent( EV_MinimapChangeOnTick );
	RegisterEvent( EV_MinimapCursedWeaponList );
	RegisterEvent( EV_MinimapCursedWeaponLocation );

	RegisterEvent( EV_BeginShowZoneTitleWnd );		// ZoneName 이 바뀌면 현재위치 업데이트 해야하므로

	RegisterEvent( EV_MinimapShowReduceBtn );
	RegisterEvent( EV_MinimapHideReduceBtn );
	RegisterEvent( EV_MinimapUpdateGameTime );

	m_AdjustCursedLoc = false;
	m_bShowSSQType=true;
	m_bShowCurrentLocation=true;
	m_bShowGameTime=true;

	m_bExpandState=false;

	m_hExpandWnd = GetHandle( "MinimapWnd_Expand" );
	m_hGuideWnd = GetHandle( "GuideWnd" );
}

function OnEvent( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	case EV_ShowMinimap:
		HandleShowMinimap( a_Param );
		break;
	case EV_PartyMemberChanged:
		HandlePartyMemberChanged( a_Param );
		break;
	case EV_MinimapAddTarget:
		HandleMinimapAddTarget( a_Param );
		break;
	case EV_MinimapDeleteTarget:
		HandleMinimapDeleteTarget( a_Param );
		break;
	case EV_MinimapDeleteAllTarget:
		HandleMinimapDeleteAllTarget();
		break;
	case EV_MinimapShowQuest:
		HandleMinimapShowQuest();
		break;
	case EV_MinimapHideQuest:
		HandleMinimapHideQuest();
		break;
	case EV_MinimapChangeOnTick :
		AdjustMapToPlayerPosition( true );
		break;
	case EV_MinimapCursedweaponList :
		HandleCursedWeaponList(a_Param);
		break;
	case EV_MinimapCursedweaponLocation :
		//Debug("기롱");
		HandleCursedWeaponLoctaion(a_Param);
		break;
	case EV_BeginShowZoneTitleWnd :
		SetCurrentLocation();
		break;
	case EV_MinimapShowReduceBtn :
		ShowWindow("MinimapWnd.btnReduce");
		break;
	case EV_MinimapHideReduceBtn :
		HideWindow("MinimapWnd.btnReduce");
		break;
	case EV_MinimapUpdateGameTime :
		if(m_bShowGameTime)
			HandleUpdateGameTime(a_Param);
		break;
	}
}

function OnShow()
{
	debug("MinimapWnd - OnShow");
	AdjustMapToPlayerPosition( true );
	class'AudioAPI'.static.PlaySound( "interfacesound.Interface.map_open_01" );
	if(b_IsShowGuideWnd == 1)
		m_hGuideWnd.ShowWindow();
	b_IsShowGuideWnd = 0;

		
	SetSSQTypeText();	// 세븐사인종류에따라 텍스트셋팅
	SetCurrentLocation();

}


function SetSSQTypeText()
{
	local string SSQText;

	switch(m_SSQStatus)
	{
	case 0 :
		SSQText=GetSystemString(973);
		break;
	case 1 :
		SSQText=GetSystemString(974);
		break;
	case 2 :
		SSQText=GetSystemString(975);
		break;
	case 3 :
		SSQText=GetSystemString(976);
		break;
	}
	class'UIAPI_TEXTBOX'.static.SetText("Minimapwnd.txtVarSSQType", SSQText);
}

function SetCurrentLocation()
{
	local string ZoneName;

	ZoneName=GetCurrentZoneName();
	class'UIAPI_TEXTBOX'.static.SetText("Minimapwnd.txtVarCurLoc", ZoneName);
}

function OnHide()
{
	if( m_hGuideWnd.IsShowWindow() )
	{
		b_IsShowGuideWnd = 1;
	}
	class'AudioAPI'.static.PlaySound( "interfacesound.Interface.map_close_01" );
}

function HandlePartyMemberChanged( String a_Param )
{
	ParseInt( a_Param, "PartyMemberCount", m_PartyMemberCount );
}

function SetExpandState(bool bExpandState)
{
	m_bExpandState=bExpandstate;
}

function bool IsExpandState()
{
	return m_bExpandState;
}



function HandleShowMinimap( String a_Param )
{
	local int SSQStatus;

	debug("HandleShowMiniap");

	// SSQState의 등록
	if( ParseInt( a_Param, "SSQStatus", SSQStatus ) )
	{
//			Debug( "SSQStatus=" $ SSQStatus );
		class'UIAPI_MINIMAPCTRL'.static.SetSSQStatus( "MinimapWnd.Minimap", SSQStatus );

		m_SSQStatus=SSQStatus;
	}

	if(IsExpandState())
	{
		// 큰윈도우 상태
		if(IsShowWindow("MinimapWnd_Expand"))
		{
			HideWindow("MinimapWnd_Expand");
		}
		else
		{
			// 작은 윈도우 닫고
			// 큰윈도우 오픈
			HideWindow("MinimapWnd");
			ShowWindowWithFocus("MinimapWnd_Expand");
		}
	}
	else
	{
		// 작은 윈도우 상태
		if(IsShowWindow("MinimapWnd"))
		{
			HideWindow("MinimapWnd");
		}
		else
		{
			HideWindow("MinimapWnd_Expand");
			ShowWindowWithFocus("MinimapWnd");
		}
	}

	if(IsShowWindow("MinimapWnd") || IsShowWindow("MinimapWnd_Expand"))
	{
		class'MiniMapAPI'.static.RequestCursedWeaponList();
		class'MiniMapAPI'.static.RequestCursedWeaponLocation();
	}
}

function HandleMinimapAddTarget( String a_Param )
{
	local Vector Loc;
	
	debug("~~~MinimapWnd - HandleMiniampAddTarget~~~~~~"$a_Param);
	if( ParseFloat( a_Param, "X", Loc.x )
		&& ParseFloat( a_Param, "Y", Loc.y )
		&& ParseFloat( a_Param, "Z", Loc.z ) )
	{
		
		//debug (" 나 작동중1 :" @ Loc.x @ Loc.y @ Loc.z);
		class'UIAPI_MINIMAPCTRL'.static.AddTarget( "MinimapWnd.Minimap", Loc );
		class'UIAPI_MINIMAPCTRL'.static.AdjustMapView( "MinimapWnd.Minimap", Loc, false, false);
	}
		//debug (" 나 작동중2 :" @ Loc.x @ Loc.y @ Loc.z);
}

function HandleMinimapDeleteTarget( String a_Param )
{
	local Vector Loc;
	local int LocX;
	local int LocY;
	local int LocZ;

	if( ParseInt( a_Param, "X", LocX )
		&& ParseInt( a_Param, "Y", LocY )
		&& ParseInt( a_Param, "Z", LocZ ) )
	{
		Loc.x = float(LocX);
		Loc.y = float(LocY);
		Loc.z = float(LocZ);
		class'UIAPI_MINIMAPCTRL'.static.DeleteTarget( "MinimapWnd.Minimap", Loc );
	}
}

function HandleMinimapDeleteAllTarget()
{
	class'UIAPI_MINIMAPCTRL'.static.DeleteAllTarget( "MinimapWnd.Minimap" );
}

function HandleMinimapShowQuest()
{
	Debug( "MinimapWnd.HandleMinimapShowQuest" );

	class'UIAPI_MINIMAPCTRL'.static.SetShowQuest( "MinimapWnd.Minimap", true );
}

function HandleMinimapHideQuest()
{
	Debug( "MinimapWnd.HandleMinimapHideQuest" );

	class'UIAPI_MINIMAPCTRL'.static.SetShowQuest( "MinimapWnd.Minimap", false );
}

function OnComboBoxItemSelected( string sName, int index )
{
	local int CursedweaponComboBoxCurrentReservedData;

	if( sName == "CursedComboBox")
	{
		//QuestComboCurrentData = class'UIAPI_COMBOBOX'.static.GetSelectedNum("GuideWnd.QuestComboBox");
		CursedweaponComboBoxCurrentReservedData = class'UIAPI_COMBOBOX'.static.GetReserved("MinimapWnd.CursedComboBox",index);
		//LoadQuestSearchResult(CursedweaponComboBoxCurrentReservedData);
	}
	
}
function OnClickButton( String a_ButtonID )
{

	debug(a_ButtonID);

	switch( a_ButtonID )
	{
	case "TargetButton":
		OnClickTargetButton();
		break;
	case "MyLocButton":
		OnClickMyLocButton();
		break;
	case "PartyLocButton":
		OnClickPartyLocButton();
		break;
	case "OpenGuideWnd":
		if( m_hGuideWnd.IsShowWindow() )
			m_hGuideWnd.HideWindow();
		else
			m_hGuideWnd.ShowWindow();
		break;
	case "Pursuit":
//		class'UIAPI_MINIMAPCTRL'.static.RequestReduceBtn("MinimapWnd.Minimap");
		m_AdjustCursedLoc = true;
		class'MiniMapAPI'.static.RequestCursedWeaponLocation();
		break;
	case "ExpandButton":
		SetExpandState(true);
		ShowWindowWithFocus( "MinimapWnd_Expand" );
		HideWindow("MinimapWnd");
		break;
	case "btnReduce" :
		class'UIAPI_MINIMAPCTRL'.static.RequestReduceBtn("MinimapWnd.Minimap");
		HideWindow("MinimapWnd.btnReduce");
		break;

	}
}

function OnClickTargetButton()
{
	local Vector QuestLocation;

	if( GetQuestLocation(QuestLocation ) )
		class'UIAPI_MINIMAPCTRL'.static.AdjustMapView( "MinimapWnd.Minimap", QuestLocation );
}

function OnClickMyLocButton()
{
//	AdjustMapToPlayerPosition( false );
	AdjustMapToPlayerPosition( true );
}

function AdjustMapToPlayerPosition( bool a_ZoomToTownMap )
{
	local Vector PlayerPosition;

	PlayerPosition = GetPlayerPosition();
	class'UIAPI_MINIMAPCTRL'.static.AdjustMapView( "MinimapWnd.Minimap", PlayerPosition, a_ZoomToTownMap );
}

function OnClickPartyLocButton()
{
	local Vector PartyMemberLocation;

	m_PartyMemberCount = GetPartyMemberCount();
	//Debug( "m_PartyLocIndex=" $ m_PartyLocIndex $ " m_PartyMemberCount=" $ m_PartyMemberCount );

	
	
	if( 0 == m_PartyMemberCount )
		return;

	m_PartyLocIndex = ( m_PartyLocIndex + 1 ) % m_PartyMemberCount;
	if( GetPartyMemberLocation( m_PartyLocIndex, PartyMemberLocation ) )
	{
		class'UIAPI_MINIMAPCTRL'.static.AdjustMapView( "MinimapWnd.Minimap", PartyMemberLocation, false );
	}
}

function HandleCursedWeaponList( string param )
{

local int num;  
local int itemID;
local int i;
local string cursedName;
	
	ParseInt( param, "NUM", num );
//	debug ("numafdasf:"@ num);
	class'UIAPI_COMBOBOX'.static.Clear("MinimapWnd.CursedComboBox");
	
	for(i=0;i<num+1;++i)
	{
		if (i==0)
		{
			class'UIAPI_COMBOBOX'.static.AddStringWithReserved("MinimapWnd.CursedComboBox", GetSystemString(1463) , 0);
		}
		else
		{
			ParseInt( param, "ID" $ i-1, itemID );
			ParseString( param, "NAME" $ i-1, cursedName );
			
			//debug ("chooonsik:"@ cursedName @ itemID );
			class'UIAPI_COMBOBOX'.static.AddStringWithReserved("MinimapWnd.CursedComboBox", cursedName , itemID);
			class'UIAPI_COMBOBOX'.static.SetSelectedNum("MinimapWnd.CursedComboBox",0);
		}
	}
	class'UIAPI_MINIMAPCTRL'.static.DeleteAllTarget("MinimapWnd.Minimap"); 
}

function HandleCursedWeaponLoctaion( string param )
{
	local int num;  
	local int itemID;
	local int itemID1;
	local int itemID2;
	local int isowndedo;
	local int isownded1;
	local int isownded2;

	local int x;
	local int y;
	local int z;
	local int i;
	local Vector CursedWeaponLoc1;
	local Vector CursedWeaponLoc2;
	local int CursedWeaponComboCurrentData;
	local string combocursedName;
	local string cursedName;
	local string cursedName1;
	local string cursedName2;
	local Vector cursedWeaponLocation;
	local bool combined;
	
	ParseInt( param, "NUM", num );



//	debug ("handleCursedWeaponLocation - 갯수:"@num);

	if(num==0)
	{
		if(m_AdjustCursedLoc)
			class'UIAPI_MINIMAPCTRL'.static.AdjustMapView( "MinimapWnd.Minimap", GetPlayerPosition());  
		class'UIAPI_MINIMAPCTRL'.static.DeleteAllCursedWeaponIcon( "MinimapWnd.Minimap");	
		return;
	}
	else
	{
		for(i=0; i<num; ++i)
		{
			ParseInt( param, "ID" $ i, itemID );
			ParseString( param, "NAME" $ i, cursedName );

//			CursedWeaponComboCurrentData = class'UIAPI_COMBOBOX'.static.GetSelectedNum("MinimapWnd.CursedComboBox");
//			combocursedName = class'UIAPI_COMBOBOX'.static.GetString("MinimapWnd.CursedComboBox", CursedWeaponComboCurrentData);

			ParseInt( param, "ISOWNED" $ i, isowndedo );
			ParseInt( param, "X" $ i, x );
			ParseInt( param, "Y" $ i, y );
			ParseInt( param, "Z" $ i, z );
				
			cursedWeaponLocation.x = x;
			cursedWeaponLocation.y = y;
			cursedWeaponLocation.z = z;
			
			Normal(cursedWeaponLocation);
			
			switch (i)
			{
			case 0:
				itemID1=itemID;
				cursedName1=cursedName;
				isownded1=isowndedo;
				CursedWeaponLoc1.x = cursedWeaponLocation.x;
				CursedWeaponLoc1.y = cursedWeaponLocation.y;
				CursedWeaponLoc1.z = cursedWeaponLocation.z;
				Normal(CursedWeaponLoc1);
				debug ("무기1:"$cursedName1$", 위치:"@ CursedWeaponLoc1);
				break;
			case 1:
				itemID2=itemID;
				cursedName2=cursedName;
				isownded2=isowndedo;
				CursedWeaponLoc2.x = cursedWeaponLocation.x;
				CursedWeaponLoc2.y = cursedWeaponLocation.y;
				CursedWeaponLoc2.z = cursedWeaponLocation.z;
				Normal(CursedWeaponLoc2);
				debug ("무기2:"$cursedName2$", 위치:"@ CursedWeaponLoc2);
				break;
			}	
		}
	}

	// 추적 눌렀을때
	if(m_AdjustCursedLoc)
	{
		m_AdjustCursedLoc=false;

		CursedWeaponComboCurrentData = class'UIAPI_COMBOBOX'.static.GetSelectedNum("MinimapWnd.CursedComboBox");
		combocursedName = class'UIAPI_COMBOBOX'.static.GetString("MinimapWnd.CursedComboBox", CursedWeaponComboCurrentData);

		if(combocursedName==cursedName1)
		{
			class'UIAPI_MINIMAPCTRL'.static.AdjustMapView( "MinimapWnd.Minimap", cursedWeaponLoc1, false);			
		}
		else if(combocursedName==cursedName2)
		{
			class'UIAPI_MINIMAPCTRL'.static.AdjustMapView( "MinimapWnd.Minimap", cursedWeaponLoc2, false);			
		}
		else
			AdjustMapToPlayerPosition(true);
	}
	else
	{
		if(num==1)
		{
			DrawCursedWeapon("MinimapWnd.Minimap", itemID1, cursedName1, CursedWeaponLoc1, isownded1==0 , true);
		}
		else if(num==2)
		{
			combined = class'UIAPI_MINIMAPCTRL'.static.IsOverlapped("MinimapWnd.Minimap", CursedWeaponLoc1.x, CursedWeaponLoc1.y, CursedWeaponLoc2.x, CursedWeaponLoc2.y);
			debug ("컴바인" @ combined); 

			//if (combined == false)
			//{
			//	tooltiptext1 = MakeFullSystemMsg( GetSystemMessage(1985), GetSystemString(1464),  "1") $"\\n" $MakeFullSystemMsg( GetSystemMessage(1986), GetSystemString(1499), "1");
			//	tooltiptext2 = MakeFullSystemMsg( GetSystemMessage(1985), GetSystemString(1464),  "1") $"\\n" $MakeFullSystemMsg( GetSystemMessage(1986), GetSystemString(1499), "1");
			//}

			if(combined)
			{
				class'UIAPI_MINIMAPCTRL'.static.DrawGridIcon( "MinimapWnd.Minimap","L2UI_CH3.MiniMap.cursedmapicon00","L2UI_CH3.MiniMap.cursedmapicon00", cursedWeaponLoc1,true, 0, -12, cursedName1$"\\n"$cursedName2);			
			}	
			else
			{
				debug("ownded:"@isownded1@isownded2);
				
				DrawCursedWeapon("MinimapWnd.Minimap", itemID1, cursedName1, CursedWeaponLoc1, isownded1==0 , true);
				DrawCursedWeapon("MinimapWnd.Minimap", itemID2, cursedName2, CursedWeaponLoc2, isownded2==0 , false);

	//			class'UIAPI_MINIMAPCTRL'.static.DrawGridIcon( "MinimapWnd.Minimap","L2UI_CH3.MiniMap.cursedmapicon00","L2UI_CH3.MiniMap.cursedmapicon01_drop", cursedWeaponLoc1,true, 0, -12, cursedName1);
	//			class'UIAPI_MINIMAPCTRL'.static.DrawGridIcon( "MinimapWnd.Minimap","L2UI_CH3.MiniMap.cursedmapicon00","L2UI_CH3.MiniMap.cursedmapicon01_drop", cursedWeaponLoc2,false, 0, -12, cursedName2);
			}
		}
	}

/*		
			if(isowndedo == 0)
			{
				// 마검자리체 드롭
				if (itemID == 8190)
				{
					if (combined == true)
						tooltiptext1 = MakeFullSystemMsg( GetSystemMessage(1985), GetSystemString(1464), "1" );
					class'UIAPI_MINIMAPCTRL'.static.DrawGridIcon( "MinimapWnd.Minimap","L2UI_CH3.MiniMap.cursedmapicon00","L2UI_CH3.MiniMap.cursedmapicon01_drop", cursedWeaponLocation,i==0, 0, -12, "");			
						//debug("짜리체:" @ itemID);
				}
				//혈검아카마나흐 드롭
				else if (itemID == 8689)
				{
					if (combined == true)
						tooltiptext2 = MakeFullSystemMsg( GetSystemMessage(1985), GetSystemString(1499), "1" );
					class'UIAPI_MINIMAPCTRL'.static.DrawGridIcon( "MinimapWnd.Minimap","L2UI_CH3.MiniMap.cursedmapicon00","L2UI_CH3.MiniMap.cursedmapicon02_drop", cursedWeaponLocation,i==0, 0, -12, "");
				//debug("마나" @ itemID);
				}
			}
			else
			{
				if (itemID == 8689)
				{
					if (combined == true)
						tooltiptext2 = MakeFullSystemMsg( GetSystemMessage(1986), GetSystemString(1499), "1");
					class'UIAPI_MINIMAPCTRL'.static.DrawGridIcon( "MinimapWnd.Minimap","L2UI_CH3.MiniMap.cursedmapicon00","L2UI_CH3.MiniMap.cursedmapicon02", cursedWeaponLocation,i==0, 0, -12, "");
				}
				//마검자리체소유자
				else if (itemID == 8190)
				{
					if (combined == true)
						tooltiptext1 = MakeFullSystemMsg( GetSystemMessage(1986), GetSystemString(1464), "1");
					class'UIAPI_MINIMAPCTRL'.static.DrawGridIcon( "MinimapWnd.Minimap","L2UI_CH3.MiniMap.cursedmapicon00","L2UI_CH3.MiniMap.cursedmapicon01", cursedWeaponLocation,i==0, 0, -12, "");
				}
			}
			
		}
*/

}

function DrawCursedWeapon(string WindowName, int itemID, string cursedName, Vector vecLoc, bool bDropped, bool bRefresh)
{
	local string itemIconName;

	if(itemID==8190)
	{
		ItemIconName="L2UI_CH3.MiniMap.cursedmapicon01";
	}
	else if(itemID==8689)
	{
		ItemIconName="L2UI_CH3.MiniMap.cursedmapicon02";
	}

	if(bDropped)
		ItemIconName=ItemIconName$"_drop";

	class'UIAPI_MINIMAPCTRL'.static.DrawGridIcon(WindowName,ItemIconName,"L2UI_CH3.MiniMap.cursedmapicon00", vecLoc, bRefresh, 0, -12, cursedName);
}

//
//function ResetCursedWeapon()
//{
//
//
//	class'UIAPI_MINIMAPCTRL'.static.DrawGridIcon("MinimapWnd.Minimap","","", vecLoc, false, 0, -12, "");
//}



function HandleUpdateGameTime(string a_Param)
{
	local int GameHour;
	local int GameMinute;

	local string GameTimeString;

	ParseInt(a_Param, "GameHour", GameHour);
	ParseInt(a_Param, "GameMinute", GameMinute);

	

	SelectSunOrMoon(GameHour);

	
	if ( GameHour >= 12 )
	{
		GameTimeString="PM ";
		GameHour -= 12;
	}
	else
	{
		GameTimeString="AM ";
	}

	if ( GameHour == 0 )
		GameHour = 12;

	if(GameHour<10)
		GameTimeString=GameTimeString$"0"$string(GameHour)$" : ";
	else
		GameTimeString=GameTimeString$string(GameHour)$" : ";

	if(GameMinute<10)
		GameTimeString=GameTimeString$"0"$string(GameMinute);
	else
		GameTimeString=GameTimeString$string(GameMinute);


//	CDC->DrawText(29,19,NWhiteColor, *strTime,0,0,FALSE,L2FT_BIG);	

	class'UIAPI_TEXTBOX'.static.SetText("MinimapWnd.txtGameTime", GameTimeString);
}

function SelectSunOrMoon(int GameHour)
{
	if ( GameHour >= 6 && GameHour <= 24 )
	{
		ShowWindow("MinimapWnd.texSun");
		HideWindow("MinimapWnd.texMoon");
	}
	else
	{
		ShowWindow("MinimapWnd.texMoon");
		HideWindow("MinimapWnd.texSun");
	}
}
