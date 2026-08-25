class GuideWnd extends UIScript;
	
// Sets Max Value for Data Triger Loop 
const MAX_QUEST_NUM=2000; 
const MAX_HUNTINGZONE_NUM=500; 
const MAX_RAID_NUM=2000;
// Sets Timer Value
const TIMER_ID=1; 
const TIMER_DELAY=5000; 
// Sets Domain Validation Number 
const HUNTING_ZONE_TYPE = 0;
// Sets Hunting Zone Validation Number
const HUNTING_ZONE_FIELDHUTINGZONE = 1;
const HUNTING_ZONE_DUNGEON = 2;
// Sets Area Info Validation Number
const HUNTING_ZONE_CASTLEVILLE = 3;
const HUNTING_ZONE_HARBOR = 4;
const HUNTING_ZONE_AZIT = 5;
const HUNTING_ZONE_COLOSSEUM = 6;
const HUNTING_ZONE_ETCERA = 7;
//안타라스 예외처리
const ANTARASMONID1 = 29066;
const ANTARASMONID2 = 29067;
const ANTARASMONID3 = 29068;

// Sets Global Value
var bool bLock; 
struct RAIDRECORD
{
	var int a;
	var int b;
	var int c;
};
var array<RAIDRECORD> RaidRecordList;

var ListCtrlHandle m_hQuestListCtrl;
var ListCtrlHandle m_hHuntingZoneListCtrl;
var ListCtrlHandle m_hRaidListCtrl;
var ListCtrlHandle m_hAreaInfoListCtrl;
var TabHandle m_hTabCtrl;
var ComboBoxHandle m_hQuestComboBox;

function OnLoad()
{
	RegisterEvent(EV_RaidRecord);
	RegisterEvent(EV_ShowGuideWnd);
	//LoadQuestList();

	m_hQuestListCtrl = ListCtrlHandle( GetHandle( "QuestListCtrl" ) );
	m_hHuntingZoneListCtrl = ListCtrlHandle( GetHandle( "HuntingZoneListCtrl" ) );
	m_hRaidListCtrl = ListCtrlHandle( GetHandle( "RaidListCtrl" ) );
	m_hAreaInfoListCtrl = ListCtrlHandle( GetHandle( "AreaInfoListCtrl" ) );
	m_hTabCtrl = TabHandle( GetHandle( "TabCtrl" ) );
	m_hQuestComboBox = ComboBoxHandle( GetHandle( "QuestComboBox" ) );
}

function OnShow()
{
	bLock = false;

	// 2006/12/07 Commended out by NeverDie
	//m_hQuestListCtrl.DeleteAllItem();
	m_hHuntingZoneListCtrl.DeleteAllItem();
	m_hRaidListCtrl.DeleteAllItem();
	m_hAreaInfoListCtrl.DeleteAllItem();
	m_hTabCtrl.InitTabCtrl();

	LoadQuestList();
	m_hOwnerWnd.SetTimer( TIMER_ID, TIMER_DELAY );

	// 2006/12/07 Commended out by NeverDie
	//class'UIAPI_MINIMAPCTRL'.static.InitPosition("GuideWnd.MinimapCtrl");
	
}

function OnHide()
{
	class'UIAPI_WINDOW'.static.KillUITimer("GuideWnd.RaidTab",Timer_ID); 
	bLock = false;
}

function OnTimer(int TimerID)
{
	if(TimerID == TIMER_ID)
	{
		//log("5 Seconds has Passed");
		bLock = false;
	}
}

function OnClickButton(string ID)
{
	local int QuestComboCurrentData;
	local int QuestComboCurrentReservedData;
	local int HuntingZoneComboboxCurrentData;
	local int HuntingZoneComboboxCurrentReservedData;
	//local int RaidCurrentComboboxCurrentData;
	local int RaidCurrentComboboxCurrentReservedData;
	local int AreaInfoComboBoxCurrentData;
	local int AreaInfoComboBoxCurrentReservedData;
	if(ID == "TabCtrl0")
	{
		LoadQuestList();
		m_hQuestComboBox.SetSelectedNum( 0 );

		// 2006/12/07 Commended out by NeverDie
		//class'UIAPI_MINIMAPCTRL'.static.InitPosition("GuideWnd.MinimapCtrl");
	}else
	if(ID == "TabCtrl1")
	{
		LoadHuntingZoneList();
		class'UIAPI_COMBOBOX'.static.SetSelectedNum("GuideWnd.HuntingZoneComboBox",0);

		// 2006/12/07 Commended out by NeverDie
		//class'UIAPI_MINIMAPCTRL'.static.InitPosition("GuideWnd.MinimapCtrl");
	}else
	if(ID == "TabCtrl2")
	{
		if(bLock == false)
		{
			bLock = true;
			RequestRaidRecord();
			//log("requestdddddddd");
			//class'UIAPI_COMBOBOX'.static.SetSelectedNum("GuideWnd.RaidInfoComboBox",0);
		}
	}
	if(ID == "TabCtrl3")
	{
		LoadAreaInfoList();
		class'UIAPI_COMBOBOX'.static.SetSelectedNum("GuideWnd.AreaInfoComboBox",0);

		// 2006/12/07 Commended out by NeverDie
		//class'UIAPI_MINIMAPCTRL'.static.InitPosition("GuideWnd.MinimapCtrl");
	}
	// On Click Search Button on the Quest Data View
	if (ID == "btn_search1")
	{
		//debug(ID);
		QuestComboCurrentData = m_hQuestComboBox.GetSelectedNum();
		QuestComboCurrentReservedData = m_hQuestComboBox.GetReserved( QuestComboCurrentData );
		LoadQuestSearchResult(QuestComboCurrentReservedData);
	}
	
	// On Click Search Button on the Hunting Zone Data View
	if (ID == "btn_search2")
	{
		//debug(ID);
		HuntingZoneComboboxCurrentData = class'UIAPI_COMBOBOX'.static.GetSelectedNum("GuideWnd.HuntingZoneComboBox");
		HuntingZoneComboboxCurrentReservedData = class'UIAPI_COMBOBOX'.static.GetReserved("GuideWnd.HuntingZoneComboBox",HuntingZoneComboboxCurrentData);
		LoadHuntingZoneListSearchResult(HuntingZoneComboboxCurrentReservedData);
	}
	// On Click Search Button on the Raid Data View
	if (ID == "btn_search3")
	{
		//debug(ID);
		//RaidCurrentComboboxCurrentData = class'UIAPI_COMBOBOX'.static.GetSelectedNum("GuideWnd.RaidInfoComboBox");
		//RaidCurrentComboboxCurrentReservedData = class'UIAPI_COMBOBOX'.static.GetReserved("GuideWnd.RaidInfoComboBox",RaidCurrentComboboxCurrentData);
		LoadRaidSearchResult(RaidCurrentComboboxCurrentReservedData);
	}
	// On Click Search Button on the AreaInfo Data View
	if (ID == "btn_search4")
	{
		//debug(ID);
		AreaInfoComboBoxCurrentData = class'UIAPI_COMBOBOX'.static.GetSelectedNum("GuideWnd.AreaInfoComboBox");
		AreaInfoComboBoxCurrentReservedData = class'UIAPI_COMBOBOX'.static.GetReserved("GuideWnd.AreaInfoComboBox",AreaInfoComboBoxCurrentData);
		LoadAreaInfoListSearchResult(AreaInfoComboBoxCurrentReservedData);
	}
	
		// On Click Search Button on the Quest Data View
	if (ID == "QuestComboBox")
	{
		//debug(ID);
		QuestComboCurrentData = m_hQuestComboBox.GetSelectedNum();
		QuestComboCurrentReservedData = m_hQuestComboBox.GetReserved( QuestComboCurrentData );
		LoadQuestSearchResult(QuestComboCurrentReservedData);
	}
	
	// On Click Search Button on the Hunting Zone Data View
	if (ID == "HuntingZoneComboBox")
	{
		//debug(ID);
		HuntingZoneComboboxCurrentData = class'UIAPI_COMBOBOX'.static.GetSelectedNum("GuideWnd.HuntingZoneComboBox");
		HuntingZoneComboboxCurrentReservedData = class'UIAPI_COMBOBOX'.static.GetReserved("GuideWnd.HuntingZoneComboBox",HuntingZoneComboboxCurrentData);
		LoadHuntingZoneListSearchResult(HuntingZoneComboboxCurrentReservedData);
	}
	if (ID == "CloseButton")
	{
		class'UIAPI_WINDOW'.static.HideWindow( "MinimapWnd.GuideWnd" );
	}
	
}

function OnComboBoxItemSelected( string sName, int index )
{
	//local int QuestComboCurrentData;
	local int QuestComboCurrentReservedData;
	//local int HuntingZoneComboboxCurrentData;
	local int HuntingZoneComboboxCurrentReservedData;
	//local int RaidCurrentComboboxCurrentData;
	//local int RaidCurrentComboboxCurrentReservedData;
	//local int AreaInfoComboBoxCurrentData;
	local int AreaInfoComboBoxCurrentReservedData;
	
	if( sName == "QuestComboBox")
	{
		//debug(ID);
		//QuestComboCurrentData = class'UIAPI_COMBOBOX'.static.GetSelectedNum("GuideWnd.QuestComboBox");
		QuestComboCurrentReservedData = m_hQuestComboBox.GetReserved( index );
		LoadQuestSearchResult(QuestComboCurrentReservedData);
	}
	if (sName == "HuntingZoneComboBox")
	{
		//debug(ID);
		//HuntingZoneComboboxCurrentData = class'UIAPI_COMBOBOX'.static.GetSelectedNum("GuideWnd.HuntingZoneComboBox");
		HuntingZoneComboboxCurrentReservedData = class'UIAPI_COMBOBOX'.static.GetReserved("GuideWnd.HuntingZoneComboBox",index);
		LoadHuntingZoneListSearchResult(HuntingZoneComboboxCurrentReservedData);
	}
	//if (sName == "RaidInfoComboBox")
	//{
		//debug(ID);
		//RaidCurrentComboboxCurrentData = class'UIAPI_COMBOBOX'.static.GetSelectedNum("GuideWnd.RaidInfoComboBox");
	//	RaidCurrentComboboxCurrentReservedData = class'UIAPI_COMBOBOX'.static.GetReserved("GuideWnd.RaidInfoComboBox",index);
	//	LoadRaidSearchResult(RaidCurrentComboboxCurrentReservedData);
		
	//}
	if (sName == "AreaInfoComboBox")
	{
		//debug(ID);
		//AreaInfoComboBoxCurrentData = class'UIAPI_COMBOBOX'.static.GetSelectedNum("GuideWnd.AreaInfoComboBox");
		AreaInfoComboBoxCurrentReservedData = class'UIAPI_COMBOBOX'.static.GetReserved("GuideWnd.AreaInfoComboBox",index);
		LoadAreaInfoListSearchResult(AreaInfoComboBoxCurrentReservedData);
	}

	
}

function OnClickListCtrlRecord(string ID)
{

	local LVDataRecord Record;
	local Vector loc;
	
	// On Click Quest List Control.
	if (ID == "QuestListCtrl")
	{
		Record = m_hQuestListCtrl.GetSelectedRecord();
		loc = class'UIDATA_QUEST'.static.GetStartNPCLoc(Record.LVDataList[0].nReserved1,1);

		class'UIAPI_MINIMAPCTRL'.static.AdjustMapView("MinimapWnd.Minimap",loc,false); 
		class'UIAPI_MINIMAPCTRL'.static.DeleteAllTarget("MinimapWnd.Minimap"); 
		class'UIAPI_MINIMAPCTRL'.static.AddTarget("MinimapWnd.Minimap",loc); 

		// 2006/12/07 Commended out by NeverDie
		//SetDetailView(Record.LVDataList[0].nReserved1);
		
	}
	// On Click Hunting Zone List Control.
	if (ID == "HuntingZoneListCtrl")
	{
		Record = m_hHuntingZoneListCtrl.GetSelectedRecord();
		loc = class'UIDATA_HUNTINGZONE'.static.GetHuntingZoneLoc(Record.LVDataList[0].nReserved1);
		class'UIAPI_MINIMAPCTRL'.static.AdjustMapView("MinimapWnd.Minimap",loc,false); 
		class'UIAPI_MINIMAPCTRL'.static.DeleteAllTarget("MinimapWnd.Minimap"); 
		class'UIAPI_MINIMAPCTRL'.static.AddTarget("MinimapWnd.Minimap",loc); 
	
	}
	// On Click Raid Data List Control.
	if (ID == "RaidListCtrl")
	{
		Record = m_hRaidListCtrl.GetSelectedRecord();
		loc = class'UIDATA_RAID'.static.GetRaidLoc(Record.LVDataList[0].nReserved1);
		class'UIAPI_MINIMAPCTRL'.static.AdjustMapView("MinimapWnd.Minimap",loc,false); 
		class'UIAPI_MINIMAPCTRL'.static.DeleteAllTarget("MinimapWnd.Minimap"); 
		class'UIAPI_MINIMAPCTRL'.static.AddTarget("MinimapWnd.Minimap",loc);

		// 2006/12/07 Commended out by NeverDie
		//SetRaidDetailView(Record.LVDataList[0].nReserved1);
	
	}
	// On Click Area Information List Control
	if (ID == "AreaInfoListCtrl")
	{
		//debug("Iaminuse");
		Record = m_hAreaInfoListCtrl.GetSelectedRecord();
		loc = class'UIDATA_HUNTINGZONE'.static.GetHuntingZoneLoc(Record.LVDataList[0].nReserved1);
		//debug("Iaminuse2: " $ loc);
		class'UIAPI_MINIMAPCTRL'.static.AdjustMapView("MinimapWnd.Minimap",loc,false); 
		class'UIAPI_MINIMAPCTRL'.static.DeleteAllTarget("MinimapWnd.Minimap"); 
		class'UIAPI_MINIMAPCTRL'.static.AddTarget("MinimapWnd.Minimap",loc); 
	
	}
}

function OnEvent( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	case EV_ShowGuideWnd:
		m_hOwnerWnd.ShowWindow();
		break;
	case EV_RaidRecord:
		LoadRaidList( a_Param );

		// 2006/12/07 Commended out by NeverDie
		//class'UIAPI_MINIMAPCTRL'.static.InitPosition("GuideWnd.MinimapCtrl");
		break;
	default:
		break;
	}
}

// Load Hunting Zone Data
function LoadHuntingZoneList()
{
	//사냥터 리스트 컨트롤에 사냥터 이름	추천레벨	사냥터유형 설명	소속 영지	위치좌표 가 필요하다
	local string HuntingZoneName; 
	local int MinLevel;   
	local int MaxLevel;  
	local string LevelLimit;	
	local int FieldType; 
	local string FieldType_Name;
	local int Zone; 
	//local string Description;
	local LVDataRecord Record;
	local LVData data1;
	local LVData data2;
	local LVData data3;
	local LVData data4;
	local int i;

	m_hHuntingZoneListCtrl.DeleteAllItem();
	comboxFiller("HuntingZoneComboBox");
	class'UIAPI_COMBOBOX'.static.SetSelectedNum("GuideWnd.HuntingZoneComboBox",0);
	for(i = 0; i < MAX_HUNTINGZONE_NUM ; i++)
	{		
		if(class'UIDATA_HUNTINGZONE'.static.IsValidData(i))
		{
			FieldType = class'UIDATA_HUNTINGZONE'.static.GetHuntingZoneType(i);
			if( FieldType == 1 || FieldType == 2 )
			{
				//사냥터 데이터 얻어오기
				HuntingZoneName = class'UIDATA_HUNTINGZONE'.static.GetHuntingZoneName(i); 
				MinLevel = class'UIDATA_HUNTINGZONE'.static.GetMinLevel(i); 
				MaxLevel = class'UIDATA_HUNTINGZONE'.static.GetMaxLevel(i); 
				Zone = class'UIDATA_HUNTINGZONE'.static.GetHuntingZone(i); 
				//Description = class'UIDATA_HUNTINGZONE'.static.GetHuntingDescription(i); 
					
				//데이터 가공
				if(MinLevel > 0 && MaxLevel > 0)
				{
			 		LevelLimit = MinLevel $ "~" $ MaxLevel;	
				}else if(minlevel > 0)
				{
					LevelLimit = MinLevel $ " " $ GetSystemString(859);
				}else
				{
					LevelLimit = GetSystemString(866);
				}	
				FieldType_Name = conv_zoneType(FieldType);
				
				//얻어온 데이터를 레코드로 만들기
				data1.nReserved1 = i;
				data1.szData = HuntingZoneName;
				Record.LVDataList[0] = data1;
				data2.szData = FieldType_Name;
				Record.LVDataList[1] = data2;
				data3.szData = conv_zoneName(Zone);
				Record.LVDataList[2] = data3;
				data4.szData = LevelLimit;
				Record.LVDataList[3] = data4;
				//툴팁 정보 레코드에 넣기
				//Record.nReserved1 = Zone;
				//Record.szReserved = Description;
				//레코드를 리스트 컨트롤에 인서트 하기
				//debug(HuntingZoneName);
				m_hHuntingZoneListCtrl.InsertRecord( Record );
			}
		}	
	}
	
}

// Load HuntingZone List
function LoadHuntingZoneListSearchResult(int SearchZone)
{
//사냥터 리스트 컨트롤에 사냥터 이름	추천레벨	사냥터유형 설명	소속 영지	위치좌표 가 필요하다
	local string HuntingZoneName; 
	local int MinLevel;   
	local int MaxLevel;  
	local string LevelLimit;	
	local int FieldType; 
	local string FieldType_Name;
	local int Zone; 
	local string Description; 
	local LVDataRecord Record;
	local LVData data1;
	local LVData data2;
	local LVData data3;
	local LVData data4;
	local int i;

	if (SearchZone == 9999)
	{
		LoadHuntingZoneList();
	}
	else
	{	
		m_hHuntingZoneListCtrl.DeleteAllItem();
		for(i = 0; i < MAX_HUNTINGZONE_NUM ; i++)
		{
			if(class'UIDATA_HUNTINGZONE'.static.IsValidData(i))
			{
				if (class'UIDATA_HUNTINGZONE'.static.GetHuntingZone(i) == SearchZone)
				{
					FieldType = class'UIDATA_HUNTINGZONE'.static.GetHuntingZoneType(i);
					if( FieldType == 1 || FieldType == 2 )
					{
						//사냥터 데이터 얻어오기
						HuntingZoneName = class'UIDATA_HUNTINGZONE'.static.GetHuntingZoneName(i); 
						MinLevel = class'UIDATA_HUNTINGZONE'.static.GetMinLevel(i); 
						MaxLevel = class'UIDATA_HUNTINGZONE'.static.GetMaxLevel(i); 
						Zone = class'UIDATA_HUNTINGZONE'.static.GetHuntingZone(i); 
						Description = class'UIDATA_HUNTINGZONE'.static.GetHuntingDescription(i); 
						//데이터 가공
						if(MinLevel > 0 && MaxLevel > 0)
						{
							LevelLimit = MinLevel $ "~" $ MaxLevel;	
						}else if(minlevel > 0)
						{
							LevelLimit = MinLevel $ " " $ GetSystemString(859);
						}else
						{
							LevelLimit = GetSystemString(866);
						}	
						FieldType_Name = conv_zoneType(FieldType);
						//얻어온 데이터를 레코드로 만들기
						data1.nReserved1 = i;
						data1.szData = HuntingZoneName;
						Record.LVDataList[0] = data1;
						data2.szData = FieldType_Name;
						Record.LVDataList[1] = data2;
						data3.szData = conv_zoneName(Zone);
						Record.LVDataList[2] = data3;
						data4.szData = LevelLimit;
						Record.LVDataList[3] = data4;
								
						//레코드를 리스트 컨트롤에 인서트 하기
						//debug(HuntingZoneName);
						m_hHuntingZoneListCtrl.InsertRecord( Record );
					}
				}
			}	
		}
	}
}

// Load Server Raid Data 
function LoadRaidRanking()
{
	
}
// Load Raid Data
function LoadRaidList( String a_Param )
{
	local int i;
	local int j;
	local int RaidMonsterID;
	local int RaidMonsterLevel;
	local int RaidMonsterZone;
	local string RaidPointStr;
	local string RaidMonsterPrefferedLevel;
	local string RaidMonsterName;
	local string RaidDescription;
	local LVDataRecord Record;
	local LVData data1;
	local LVData data2;
	local LVData data3;	
	local LVData data4;

	local int RaidRanking;
	local int RaidSeasonPoint;
	local int RaidNum;
//	local int RaidCount;
	local int ClearRaidMonsterID;
	local int ClearSeasonPoint;
	local int ClearTotalPoint;
	// 안타라스 예외처리 
	local int AntarasPoint;
	local string SeasonTotalString;
	
	m_hRaidListCtrl.DeleteAllItem();
	//안타라스 예외처리
	AntarasPoint = 0;
	//comboxFiller("RaidInfoComboBox");
	//class'UIAPI_COMBOBOX'.static.SetSelectedNum("GuideWnd.RaidInfoComboBox",0);

	ParseInt( a_Param, "RaidRank", RaidRanking );
	ParseInt( a_Param, "SeasonPoint", RaidSeasonPoint );

	// Userbility Coding and Set Raid Point.
	if (RaidRanking == 0)
	{
		class'UIAPI_TEXTBOX'.static.SetText("GuideWnd.Ranking",GetSystemString(1454));
	}
	else 
	{
		class'UIAPI_TEXTBOX'.static.SetInt("GuideWnd.Ranking",RaidRanking);
	}
	SeasonTotalString = "" $ RaidSeasonPoint @ GetSystemString(1442);
	//raid 점수 세팅
	//class'UIAPI_TEXTBOX'.static.SetInt("GuideWnd.Ranking",RaidRanking);
	class'UIAPI_TEXTBOX'.static.SetText("GuideWnd.SeasonTotalPoint",SeasonTotalString);

	/*RaidNum = 3;
//	RaidCount = 0;
	
	RaidRecordList.Remove(0,RaidRecordList.Length);

	RaidRecordList.Insert(0,RaidNum);
	for(i=0;i<RaidNum;i++)
	{
		ClearRaidMonsterID = 10019;
		ClearSeasonPoint = 444;
		ClearTotalPoint = 333;
		RaidRecordList[i].a = ClearRaidMonsterID;
		RaidRecordList[i].b = ClearSeasonPoint;
		RaidRecordList[i].c = ClearTotalPoint;
		log("RaidRecord : " $ RaidRecordList[i].a $ "  " $ RaidRecordList[i].b $ "  " $ RaidRecordList[i].c);
	}*/
	
	ParseInt( a_Param, "Count", RaidNum );
//	RaidCount = 0;
	
	RaidRecordList.Remove(0,RaidRecordList.Length);
	RaidRecordList.Insert(0,RaidNum);
	for(i=0;i<RaidNum;i++)
	{
		ParseInt( a_Param, "MonsterID" $ i, ClearRaidMonsterID );
		ParseInt( a_Param, "CurrentPoint" $ i, ClearSeasonPoint );
		ParseInt( a_Param, "TotalPoint" $ i, ClearTotalPoint );
		RaidRecordList[i].a = ClearRaidMonsterID;
		RaidRecordList[i].b = ClearSeasonPoint;
		RaidRecordList[i].c = ClearTotalPoint;
		//log("RaidRecord : " $ RaidRecordList[i].a $ "  " $ RaidRecordList[i].b $ "  " $ RaidRecordList[i].c);
	}
	
	for(i = 0; i < MAX_RAID_NUM ; i++)
	{
		if(class'UIDATA_RAID'.static.IsValidData(i))
		{
			//Retrieving Raid data record.
			RaidMonsterID = class'UIDATA_RAID'.static.GetRaidMonsterID(i);
			RaidMonsterLevel = class'UIDATA_RAID'.static.GetRaidMonsterLevel(i);
			RaidMonsterZone = class'UIDATA_RAID'.static.GetRaidMonsterZone(i);
			RaidDescription = class'UIDATA_RAID'.static.GetRaidDescription(i);
			RaidMonsterName = class'UIDATA_NPC'.static.GetNPCName(RaidMonsterID);
			//Process 
			
			//안타라스 특별예외처리
			if (RaidMonsterID == ANTARASMONID1)
			{
				debug("안타라스 1");
//				if(RaidMonsterLevel > 0)
//				{
//					RaidMonsterPrefferedLevel = GetSystemString(537) $ " " $ RaidMonsterLevel;
//				}else
//				{
//					RaidMonsterPrefferedLevel = GetSystemString(1415);				
//				}	
//				data1.nReserved1 = i;
//				data1.szData = RaidMonsterName;
//				Record.LVDataList[0] = data1;
//				data2.szData = RaidMonsterPrefferedLevel;
//				Record.LVDataList[1] = data2;
//				data3.szData = conv_zoneName(RaidMonsterZone);
//				Record.LVDataList[2] = data3;
//				//레이드 획득점수 
//				RaidPointStr = "0";
//				for(j=0;j<RaidNum;j++)
//				{
//					if(RaidRecordList[j].a == RaidMonsterID)
//					{
//						RaidPointStr = RaidRecordList[j].b$"";
//						//log("RaidID : " $ RaidMonsterID $ "RaidPoint : " $ RaidPointStr );
//					}
//				}
//				AntarasPoint = int(RaidPointStr) + AntarasPoint;
//				data4.szData = RaidPointStr;
//				Record.LVDataList[3] = data4;
//				
//				Record.szReserved = RaidDescription;
				//Record.nReserved1 = RaidMonsterZone;
				// insertion to the list control.
				//m_hRaidListCtrl.InsertRecord( Record );
			} 
			
			else if (RaidMonsterID == ANTARASMONID2)
			{
				debug("안타라스 2");
//				if(RaidMonsterLevel > 0)
//				{
//					RaidMonsterPrefferedLevel = GetSystemString(537) $ " " $ RaidMonsterLevel;
//				}else
//				{
//					RaidMonsterPrefferedLevel = GetSystemString(1415);				
//				}	
//				data1.nReserved1 = i;
//				data1.szData = RaidMonsterName;
//				Record.LVDataList[0] = data1;
//				data2.szData = RaidMonsterPrefferedLevel;
//				Record.LVDataList[1] = data2;
//				data3.szData = conv_zoneName(RaidMonsterZone);
//				Record.LVDataList[2] = data3;
//				//레이드 획득점수 
//				RaidPointStr = "0";
//				for(j=0;j<RaidNum;j++)
//				{
//					if(RaidRecordList[j].a == RaidMonsterID)
//					{
//						RaidPointStr = RaidRecordList[j].b$"";
						//log("RaidID : " $ RaidMonsterID $ "RaidPoint : " $ RaidPointStr );
//					}
//				}
//				AntarasPoint = int(RaidPointStr) + AntarasPoint;
//				data4.szData = RaidPointStr;
//				Record.LVDataList[3] = data4;
				
//				Record.szReserved = RaidDescription;
				//Record.nReserved1 = RaidMonsterZone;
				// insertion to the list control.
				//m_hRaidListCtrl.InsertRecord( Record );
				
			}
			
			else if (RaidMonsterID == ANTARASMONID3)
			{
				debug("안타라스 3");
				if(RaidMonsterLevel > 0)
				{
					RaidMonsterPrefferedLevel = GetSystemString(537) $ " " $ RaidMonsterLevel;
				}else
				{
					RaidMonsterPrefferedLevel = GetSystemString(1415);				
				}	
				data1.nReserved1 = i;
				data1.szData = RaidMonsterName;
				Record.LVDataList[0] = data1;
				data2.szData = RaidMonsterPrefferedLevel;
				Record.LVDataList[1] = data2;
				data3.szData = conv_zoneName(RaidMonsterZone);
				Record.LVDataList[2] = data3;
				//레이드 획득점수 
				RaidPointStr = "0";
				for(j=0;j<RaidNum;j++)
				{
					if(RaidRecordList[j].a == RaidMonsterID)
					{
						RaidPointStr = RaidRecordList[j].b$"";
						//log("RaidID : " $ RaidMonsterID $ "RaidPoint : " $ RaidPointStr );
					}
				}
				AntarasPoint = int(RaidPointStr) + AntarasPoint;
				data4.szData = String(AntarasPoint);
				Record.LVDataList[3] = data4;
				
				Record.szReserved = RaidDescription;
				//Record.nReserved1 = RaidMonsterZone;
				// insertion to the list control.
				m_hRaidListCtrl.InsertRecord( Record );

				
			}
			
			else
			{
				
				if(RaidMonsterLevel > 0)
				{
					RaidMonsterPrefferedLevel = GetSystemString(537) $ " " $ RaidMonsterLevel;
				}else
				{
					RaidMonsterPrefferedLevel = GetSystemString(1415);				
				}	
				data1.nReserved1 = i;
				data1.szData = RaidMonsterName;
				Record.LVDataList[0] = data1;
				data2.szData = RaidMonsterPrefferedLevel;
				Record.LVDataList[1] = data2;
				data3.szData = conv_zoneName(RaidMonsterZone);
				Record.LVDataList[2] = data3;
				//레이드 획득점수 
				RaidPointStr = "0";
				for(j=0;j<RaidNum;j++)
				{
					if(RaidRecordList[j].a == RaidMonsterID)
					{
						RaidPointStr = RaidRecordList[j].b$"";
						//log("RaidID : " $ RaidMonsterID $ "RaidPoint : " $ RaidPointStr );
					}
				}
				data4.szData = RaidPointStr;
				Record.LVDataList[3] = data4;
				
				Record.szReserved = RaidDescription;
				//Record.nReserved1 = RaidMonsterZone;
				// insertion to the list control.
				m_hRaidListCtrl.InsertRecord( Record );
			}
		}	
	}
	
	
}
function LoadRaidList2()
{
	local int i;
	local int RaidMonsterID;
	local int RaidMonsterLevel;
	local int RaidMonsterZone;
	local string RaidPointStr;
	local string RaidMonsterPrefferedLevel;
	local string RaidMonsterName;
	local string RaidDescription;
	local LVDataRecord Record;
	local LVData data1;
	local LVData data2;
	local LVData data3;	
	local LVData data4;

	//local int RaidRanking;
	//local int RaidSeasonPoint;
	local int RaidNum;
	local int RaidCount;
	//local int ClearRaidMonsterID;
	//local int ClearSeasonPoint;
	//local int ClearTotalPoint;
	
	m_hRaidListCtrl.DeleteAllItem();
	
	//comboxFiller("RaidInfoComboBox");
	//class'UIAPI_COMBOBOX'.static.SetSelectedNum("GuideWnd.RaidInfoComboBox",0);

	
	for(i = 0; i < MAX_RAID_NUM ; i++)
	{
		if(class'UIDATA_RAID'.static.IsValidData(i))
		{
			//Retrieving Raid data record.
			RaidMonsterID = class'UIDATA_RAID'.static.GetRaidMonsterID(i);
			RaidMonsterLevel = class'UIDATA_RAID'.static.GetRaidMonsterLevel(i);
			RaidMonsterZone = class'UIDATA_RAID'.static.GetRaidMonsterZone(i);
			RaidDescription = class'UIDATA_RAID'.static.GetRaidDescription(i);
			RaidMonsterName = class'UIDATA_NPC'.static.GetNPCName(RaidMonsterID);
			//Process 
			if(RaidMonsterLevel > 0)
			{
				RaidMonsterPrefferedLevel = GetSystemString(537) $ " " $ RaidMonsterLevel;
			}else
			{
				RaidMonsterPrefferedLevel = GetSystemString(1415);				
			}	
			data1.nReserved1 = i;
			data1.szData = RaidMonsterName;
			Record.LVDataList[0] = data1;
			data2.szData = RaidMonsterPrefferedLevel;
			Record.LVDataList[1] = data2;
			data3.szData = conv_zoneName(RaidMonsterZone);
			Record.LVDataList[2] = data3;
			//레이드 획득점수 
			RaidPointStr = "0";
			if(RaidCount < RaidNum)
			{
				if(RaidRecordList[RaidCount].a == RaidMonsterID)
				{
					RaidPointStr = RaidRecordList[RaidCount++].b$"";
				}
			}
			data4.szData = RaidPointStr;
			Record.LVDataList[3] = data4;
			
			Record.szReserved = RaidDescription;
			//Record.nReserved1 = RaidMonsterZone;
			// insertion to the list control.
			m_hRaidListCtrl.InsertRecord( Record );
		}	
	}
	
}
// Load Raid Search Result
function LoadRaidSearchResult(int SearchZone)
{
	local int i;
	local int RaidMonsterID;
	local int RaidMonsterLevel;
	local int RaidMonsterZone;
	local string RaidPointStr;
	local string RaidMonsterPrefferedLevel;
	local string RaidMonsterName;
	local string RaidDescription;
	local LVDataRecord Record;
	local LVData data1;
	local LVData data2;
	local LVData data3;	
	local LVData data4;
	local int RaidNum;
	local int RaidCount;
	
if (SearchZone == 9999)
{
LoadRaidList2();
}
else
{

	m_hRaidListCtrl.DeleteAllItem();
	
	RaidNum = RaidRecordList.Length;
	RaidCount = 0;
	for(i = 0; i < MAX_RAID_NUM ; i++)
	{
		if(class'UIDATA_RAID'.static.IsValidData(i))
		{
			RaidMonsterZone = class'UIDATA_RAID'.static.GetRaidMonsterZone(i);

			if( SearchZone == RaidMonsterZone)
			{
				//Retrieving Raid data record.
				RaidMonsterID = class'UIDATA_RAID'.static.GetRaidMonsterID(i);
				RaidMonsterLevel = class'UIDATA_RAID'.static.GetRaidMonsterLevel(i);
				RaidDescription = class'UIDATA_RAID'.static.GetRaidDescription(i);
				RaidMonsterName = class'UIDATA_NPC'.static.GetNPCName(RaidMonsterID);
				//Process 
				if(RaidMonsterLevel > 0)
				{
					RaidMonsterPrefferedLevel = GetSystemString(537) $ " " $ RaidMonsterLevel;
				}else
				{
					RaidMonsterPrefferedLevel = "-";				
				}

				data1.nReserved1 = i;
				data1.szData = RaidMonsterName;
				Record.LVDataList[0] = data1;
				data2.szData = RaidMonsterPrefferedLevel;
				Record.LVDataList[1] = data2;
				data3.szData = conv_zoneName(RaidMonsterZone);
				Record.LVDataList[2] = data3;
				//레이드 획득점수 
				RaidPointStr = "0";
				if(RaidCount < RaidNum)
				{
					if(RaidRecordList[RaidCount].a == RaidMonsterID)
					{
						RaidPointStr = RaidRecordList[RaidCount++].b$"";
					}
				}
				data4.szData = RaidPointStr;
				Record.LVDataList[3] = data4;
				
				Record.szReserved = RaidDescription;
				Record.nReserved1 = RaidMonsterZone;
				// insertion to the list control.
				m_hRaidListCtrl.InsertRecord( Record );
			}
		}	
	}
}
}

// Quest Data
function LoadQuestList()
{
	//퀘스트 리스트 컨트롤에 퀘스트 이름, 수행조건, 추천레벨, 반복성, 소속영지, 의뢰인, 설명이 필요하다
	local string QuestName;
	//local string Condition;
	local int MinLevel;
	local int MaxLevel;
	local int Type;
	//local int Zone;
	local int NPC;
	//local int CountDigit;
	//local string Description;
	local string LevelLimit;
	local string NPCname;
	local int ID;
	local LVDataRecord Record;
	local LVData data1;
	local LVData data2;
	local LVData data3;
	local LVData data4;
	local String TypeText[5];

	m_hQuestListCtrl.DeleteAllItem();
	
	comboxFiller("QuestComboBox");
	m_hQuestComboBox.SetSelectedNum( 0 );

	TypeText[0] = GetSystemString(861);
	TypeText[1] = GetSystemString(862);
	TypeText[2] = GetSystemString(861);
	TypeText[3] = GetSystemString(862);
	TypeText[4] = GetSystemString(861);
	
	for( ID = class'UIDATA_QUEST'.static.GetFirstID(); -1 != ID; iD = class'UIDATA_QUEST'.static.GetNextID() )
	{
		//Retrieving quest data record.
		QuestName = class'UIDATA_QUEST'.static.GetQuestName(ID);
		MinLevel = class'UIDATA_QUEST'.static.GetMinLevel(ID,1);
		MaxLevel = class'UIDATA_QUEST'.static.GetMaxLevel(ID,1);
		Type = class'UIDATA_QUEST'.static.GetQuestType(ID,1);

		// 2006/12/07 Commended out by NeverDie
		//Condition = class'UIDATA_QUEST'.static.GetRequirement(ID,1);
		//Zone = class'UIDATA_QUEST'.static.GetQuestZone(ID,1);
		//Description = class'UIDATA_QUEST'.static.GetIntro(ID,1);
		//CountDigit = Len(Condition);

		NPC = class'UIDATA_QUEST'.static.GetStartNPCID(ID,1);
		NPCname = class'UIDATA_NPC'.static.GetNPCName(NPC);
		if(MinLevel > 0 && MaxLevel > 0)
		{
		 	LevelLimit = MinLevel $ "~" $ MaxLevel;	
		}else if(minlevel > 0)
		{
			LevelLimit = MinLevel $ " " $ GetSystemString(859);
		}else
		{
			LevelLimit = GetSystemString(866);
		}		

		//Process 
		//debug("value: " $ CountDigit);
		data1.nReserved1 = ID;
		data1.szData = QuestName;
		Record.LVDataList[0] = data1;
		//data2.szData = Condition;

		if( 0 <= Type && Type <= 4 )
			data2.szData = TypeText[Type];
		Record.LVDataList[1] = data2;
		data3.szData = NPCname;
		Record.LVDataList[2] = data3;
		data4.szData = LevelLimit;
		Record.LVDataList[3] = data4;
		//Record.szReserved = Description;
		//Record.nReserved1 = Type;
		//Record.nReserved2 = Zone;
		//Record.nReserved3 = NPC;
		//insertion to the list control.
		m_hQuestListCtrl.InsertRecord( Record );
	}
	
}

// 2006/12/07 Commended out by NeverDie
/*
function SetDetailView(int CurrentDataNum)
{
	local string QuestName;
	local int startNPCID;
	local string startNPCName;
	local string Condition;
	local string Description;
	local string firstline;
	local string twoline;
	local string threeline;
	local string QuestArea;
	local int length;
	local int length2;
	local int length3;
	local int lengthoffset;
	local int lengthoffset2;
	local int temp1;
	local string temp2;
	local int temp3;
	local string temp4;
	local int maxlengthline1;

	GetConstantInt( 0, maxlengthline1 );
	
	//SetDetailView(Record.LVDataList[0].nReserved1);

	QuestName = class'UIDATA_QUEST'.static.GetQuestName(CurrentDataNum);
	Condition = class'UIDATA_QUEST'.static.GetRequirement(CurrentDataNum,1);
	Description = class'UIDATA_QUEST'.static.GetIntro(CurrentDataNum,1);
	startNPCID = class'UIDATA_QUEST'.static.GetStartNPCID(CurrentDataNum,1);
	QuestArea = class'UIDATA_HUNTINGZONE'.static.GetHuntingZoneName(class'UIDATA_QUEST'.static.GetQuestZone(CurrentDataNum,1));
	startNPCName = class'UIDATA_NPC'.static.GetNPCName(startNPCID);
	
	
	//Debug("1: " $ QuestName $ Condition $ startNPCName $ Description );

	length = Len(Description);
	lengthoffset = length-maxlengthline1;
	
	if (length > maxlengthline1)
	{
		firstline = Left(Description, maxlengthline1);
		twoline = Right(Description, lengthoffset);
		length2 = Len(twoline);
			if (length2 > maxlengthline1)
			{
				lengthoffset2 = length2-maxlengthline1;
				threeline = Right(twoline, lengthoffset2);
				twoline = Left(twoline, maxlengthline1);
				length3 = Len(threeline);
				if (length3 > (maxlengthline1-1))
				{
				threeline = Left(threeline, (maxlengthline1-2));
				threeline = threeline $ "...";
				}
			}
			else 
			{
				threeline = "";
			}
		
	}
	else 
	{
		firstline = Description;
		twoline = "";
	} 
	temp2 = left(twoline,1);
	temp4 = left(threeline,1);
	if (temp2 == " ")
	{
	temp1 = Len(twoline);
	twoline=right(twoline, temp1-1);
	}
	if (temp2 == ".")
	{
	firstline = firstline$".";
	temp1 = Len(twoline);
	twoline=right(twoline, temp1-2);
	}	
	if (temp2 == "!")
	{
	firstline = firstline$"!";
	temp1 = Len(twoline);
	twoline=right(twoline, temp1-2);
	}
	if (temp2 == "?")
	{
	firstline = firstline$"?";
	temp1 = Len(twoline);
	twoline=right(twoline, temp1-2);
	}
	if (temp4 == " ")
	{
	temp3 = Len(threeline);
	threeline=right(threeline, temp3-1);
	}
	if (temp4 == ".")
	{
	twoline = twoline$".";
	temp3 = Len(threeline);
	threeline=right(threeline, temp3-2);
	}
	if (temp4 == "!")
	{
	twoline = twoline$"!";
	temp3 = Len(threeline);
	threeline=right(threeline, temp3-2);
	}
	if (temp4 == "?")
	{
	twoline = twoline$"?";
	temp3 = Len(threeline);
	threeline=right(threeline, temp3-2);
	}
	
	class'UIAPI_TEXTBOX'.static.SetText("GuideWnd.QuestnameTitle", GetSystemString(1200));
	class'UIAPI_TEXTBOX'.static.SetText("GuideWnd.QuestConditionTitle", GetSystemString(1201));
	class'UIAPI_TEXTBOX'.static.SetText("GuideWnd.QuestnameDetailedView", QuestName);
	class'UIAPI_TEXTBOX'.static.SetText("GuideWnd.QuestArea", QuestArea);
	class'UIAPI_TEXTBOX'.static.SetText("GuideWnd.QuestConditionDetailedView", Condition);
	//class'UIAPI_TEXTBOX'.static.SetText("GuideWnd.StartNPCnameDetailedView", startNPCName);
	class'UIAPI_TEXTBOX'.static.SetText("GuideWnd.QuestComments", firstline);
	class'UIAPI_TEXTBOX'.static.SetText("GuideWnd.QuestComments2", twoline);
	class'UIAPI_TEXTBOX'.static.SetText("GuideWnd.QuestComments3", threeline);
	
}
*/

// Search Quest Data 
function LoadQuestSearchResult(int SearchZone)
{
	//퀘스트 리스트 컨트롤에 퀘스트 이름, 수행조건, 추천레벨, 반복성, 소속영지, 의뢰인, 설명이 필요하다
	local string QuestName;
	local string Condition;
	local int MinLevel;
	local int MaxLevel;
	local int Type;
	local int Zone;
	local int NPC;
	//local int CountDigit;
	local string Description;
	local string LevelLimit;
	local string NPCname;
	local int i;
	local LVDataRecord Record;
	local LVData data1;
	local LVData data2;
	local LVData data3;
	local LVData data4;
	
	local string TypeText;
if (SearchZone == 9999)
{
LoadQuestList();
}
else
{
	m_hQuestListCtrl.DeleteAllItem();
	for(i = 0; i < MAX_QUEST_NUM ; i++)
	{
		if(class'UIDATA_QUEST'.static.IsValidData(i))
		{
			if (class'UIDATA_QUEST'.static.GetQuestZone(i,1) == SearchZone)
			{
				QuestName = class'UIDATA_QUEST'.static.GetQuestName(i);
				Condition = class'UIDATA_QUEST'.static.GetRequirement(i,1);
				MinLevel = class'UIDATA_QUEST'.static.GetMinLevel(i,1);
				MaxLevel = class'UIDATA_QUEST'.static.GetMaxLevel(i,1);
				Type = class'UIDATA_QUEST'.static.GetQuestType(i,1);
				Zone = class'UIDATA_QUEST'.static.GetQuestZone(i,1);
				Description = class'UIDATA_QUEST'.static.GetIntro(i,1);
				NPC = class'UIDATA_QUEST'.static.GetStartNPCID(i,1);
				NPCname = class'UIDATA_NPC'.static.GetNPCName(NPC);
				if(MinLevel > 0 && MaxLevel > 0)
				{
					LevelLimit = MinLevel $ "~" $ MaxLevel;	
				}else if(minlevel > 0)
				{
					LevelLimit = MinLevel $ " " $ GetSystemString(859);
				}else
				{
					LevelLimit = GetSystemString(866);
				}		
				switch(Type)
				{
					case 0:
						TypeText = GetSystemString(861);
					break;
					case 1:
						TypeText = GetSystemString(862);
					break;
					case 2:
						TypeText = GetSystemString(861);
					break;
					case 3:
						TypeText = GetSystemString(862);
					break;
					case 4:
						TypeText = GetSystemString(861);
					break;
				}
				data1.nReserved1 = i;
				data1.szData = QuestName;
				Record.LVDataList[0] = data1;
				//data2.szData = Condition;
				data2.szData = TypeText;
				Record.LVDataList[1] = data2;
				data3.szData = NPCname;
				Record.LVDataList[2] = data3;
				data4.szData = LevelLimit;
				Record.LVDataList[3] = data4;
				//Record.szReserved = Description;
				//Record.nReserved1 = Type;
				//Record.nReserved2 = Zone;
				//Record.nReserved3 = NPC;
				//insertion to the list control.
				m_hQuestListCtrl.InsertRecord( Record );
			}
		}	
	}
}
}

// Area Information data
function LoadAreaInfoList()
{
	//지역정보 리스트 컨트롤에 필요한 변수 정의
	// 지역 이름
	local string AreaName;
	//분류
	local int Type;
	//소속영지
	local int Zone;
	//설명
	local string ZoneName;
	local string ZoneType;
	local string Description;
	//위치좌표
	local int i;
	local LVDataRecord Record;
	local LVData data1;
	local LVData data2;
	local LVData data3;

	m_hAreaInfoListCtrl.DeleteAllItem();
	
	comboxFiller("AreaInfoComboBox");
	class'UIAPI_COMBOBOX'.static.SetSelectedNum("GuideWnd.AreaInfoComboBox",0);

	for(i = 0; i < MAX_HUNTINGZONE_NUM ; i++)
	{
		if(class'UIDATA_HUNTINGZONE'.static.IsValidData(i))
		{
			Type = class'UIDATA_HUNTINGZONE'.static.GetHuntingZoneType(i);
			if(Type > 2)
			{
				//지역정보 데이터 가지고 오?
				// 지역 이름
				AreaName = class'UIDATA_HUNTINGZONE'.static.GetHuntingZoneName(i); 
				//소속영지
				Zone = class'UIDATA_HUNTINGZONE'.static.GetHuntingZone(i); 
				//설명
				Description = class'UIDATA_HUNTINGZONE'.static.GetHuntingDescription(i); 
				//가공
				ZoneName = conv_dom(Zone);
				ZoneType = conv_zoneType(Type);
				//얻어온 데이터를 레코드로 만들기
				data1.nReserved1 = i;
				data1.szData = AreaName;
				Record.LVDataList[0] = data1;
				data2.szData = ZoneType;
				Record.LVDataList[1] = data2;
				data3.szData = ZoneName;
				Record.LVDataList[2] = data3;
				//툴팁 정보 레코드에 넣기
				Record.nReserved1 = Zone;
				Record.szReserved = Description;
				//레코드를 리스트 컨트롤에 인서트 하기
				m_hAreaInfoListCtrl.InsertRecord( Record );
			}
		}	
	}
	
}

// Search Area Information Data
function LoadAreaInfoListSearchResult(int SearchZone)
{
//지역정보 리스트 컨트롤에 필요한 변수 정의
	// 지역 이름
	local string AreaName;
	//분류
	local int Type;
	//소속영지
	local int Zone;
	//설명
	local string ZoneName;
	local string ZoneType;
	local string Description;
	//위치좌표
	local int i;
	local LVDataRecord Record;
	local LVData data1;
	local LVData data2;
	local LVData data3;
	
	if (SearchZone == 9999)
	{
		LoadAreaInfoList();
	}
	else
	{
		m_hAreaInfoListCtrl.DeleteAllItem();

		for(i = 0; i < MAX_QUEST_NUM ; i++)
		{
			if(class'UIDATA_HUNTINGZONE'.static.IsValidData(i))
			{
				//log(SearchZone);
				if (class'UIDATA_HUNTINGZONE'.static.GetHuntingZone(i) == SearchZone)
				{
					//분류
					Type = class'UIDATA_HUNTINGZONE'.static.GetHuntingZoneType(i);
					if(Type > 2)
					{
						//지역정보 데이터 가지고 오?
						// 지역 이름
						AreaName = class'UIDATA_HUNTINGZONE'.static.GetHuntingZoneName(i); 
						//소속영지
						Zone = class'UIDATA_HUNTINGZONE'.static.GetHuntingZone(i); 
						//설명
						Description = class'UIDATA_HUNTINGZONE'.static.GetHuntingDescription(i); 
						//가공
						ZoneName = conv_dom(Zone);
						ZoneType = conv_zoneType(Type);
						//얻어온 데이터를 레코드로 만들기
						data1.nReserved1 = i;
						data1.szData = AreaName;
						Record.LVDataList[0] = data1;
						data2.szData = ZoneType;
						Record.LVDataList[1] = data2;
						data3.szData = ZoneName;
						Record.LVDataList[2] = data3;
						//툴팁 정보 레코드에 넣기
						//Record.m_szReserved = Description;
						//레코드를 리스트 컨트롤에 인서트 하기
						m_hAreaInfoListCtrl.InsertRecord( Record );
					}
				}	
			}
		}
	}
}

// Validate the comboboxes already have any data.
function comboxFiller(string ComboboxName)
{
	switch (comboboxName) 
	{
		case "QuestComboBox":
				proc_combox("QuestComboBox");
		break;
		case "HuntingZoneComboBox":
				proc_combox("HuntingZoneComboBox");
		break;
		//case "RaidInfoComboBox":
		//		proc_combox("RaidInfoComboBox");
		//break;
		case "AreaInfoComboBox":
				proc_combox("AreaInfoComboBox");
		break;
	}
}

// Process combox data filling.
function proc_combox(string ComboboxName)
{
	//local int currentsetnum;
	local string ComboboxNameFull;
	local string ZoneName;
	local int Zone;
	local int i;
	
	//currentsetnum = 0;
	ComboboxNameFull = "GuideWnd." $ ComboboxName;
	class'UIAPI_COMBOBOX'.static.Clear(ComboboxNameFull);
	class'UIAPI_COMBOBOX'.static.AddStringWithReserved(ComboboxNameFull,GetSystemString(144),9999);
	for(i = 0; i < MAX_HUNTINGZONE_NUM ; i++)
	{
		if(class'UIDATA_HUNTINGZONE'.static.IsValidData(i))
		{
			if (class'UIDATA_HUNTINGZONE'.static.GetHuntingZoneType(i) == HUNTING_ZONE_TYPE)
			{
				ZoneName = class'UIDATA_HUNTINGZONE'.static.GetHuntingZoneName(i); 
				Zone = class'UIDATA_HUNTINGZONE'.static.GetHuntingZone(i); 
				class'UIAPI_COMBOBOX'.static.AddStringWithReserved(ComboboxNameFull,ZoneName,Zone);
			}
		}	
	}

	//class'UIAPI_COMBOBOX'.static.SetSelectedNum(ComboboxNameFull, 0);
	//class'UIAPI_COMBOBOX'.static.("GuideWnd.QuestComboBox",0);
}


// Convert Domain Name ID to String Domain Name
function string conv_dom(int ZoneNameNum)
{
	local string ZoneNameStr;
	local int i;
	for(i = 0; i < MAX_HUNTINGZONE_NUM ; i++)
	{
		if(class'UIDATA_HUNTINGZONE'.static.IsValidData(i))
		{
			if (class'UIDATA_HUNTINGZONE'.static.GetHuntingZoneType(i) == HUNTING_ZONE_TYPE)
			{
				if (class'UIDATA_HUNTINGZONE'.static.GetHuntingZone(i) == ZoneNameNum)
				{
					ZoneNameStr = class'UIDATA_HUNTINGZONE'.static.GetHuntingZoneName(i); 
				}
			}
		}	
	}
	return ZoneNameStr;
}

// Convert ZoneType ID to Zone Type String
function string conv_zoneType(int ZoneTypeNum)
{
	local string ZoneTypeStr;
	switch(ZoneTypeNum)
	{
		case HUNTING_ZONE_FIELDHUTINGZONE:
		ZoneTypeStr = GetSystemString(1313);
		break;
		case HUNTING_ZONE_DUNGEON:
		ZoneTypeStr = GetSystemString(1314);	
		break;
		case HUNTING_ZONE_CASTLEVILLE:
		ZoneTypeStr = GetSystemString(1315);	
		break;
		case HUNTING_ZONE_HARBOR:
		ZoneTypeStr = GetSystemString(1316);	
		break;
		case HUNTING_ZONE_AZIT:
		ZoneTypeStr = GetSystemString(1317);	
		break;
		case HUNTING_ZONE_COLOSSEUM:
		ZoneTypeStr = GetSystemString(1318);	
		break;
		case HUNTING_ZONE_ETCERA:
		ZoneTypeStr = GetSystemString(1319);	
		break;		
	}
	return ZoneTypeStr;
}
function string conv_zoneName(int search_zoneid)
{
	local string HuntingZoneName; 
	local int i;
	for(i = 0; i < MAX_HUNTINGZONE_NUM ; i++)
	{
		//debug( "conv_zoneName i=" $ i );
		
		if(class'UIDATA_HUNTINGZONE'.static.IsValidData(i))
		{
			if(class'UIDATA_HUNTINGZONE'.static.GetHuntingZoneType(i) == 0)
			{
				if (class'UIDATA_HUNTINGZONE'.static.GetHuntingZone(i) == search_zoneid)
				{
				HuntingZoneName = class'UIDATA_HUNTINGZONE'.static.GetHuntingZoneName(i); 
				}
			}
		}	
	}
	return HuntingZoneName;
}

// 2006/12/07 Commended out by NeverDie
/*
function SetRaidDetailView(int CurrentDataNum)
{
	local string Description;
	local string firstline;
	local string twoline;
	local string threeline;
	local string fourline;
	local string fiveline;
	local int length;
	local int length2;
	local int length3;
	local int length4;
	local int length5;
	local int lengthoffset;
	local int lengthoffset2;
	local int lengthoffset3;
	local int lengthoffset4;
	local int temp1;
	local string temp2;
	local int temp3;
	local string temp4;
	local int temp5;
	local string temp6;
	local int temp7;
	local string temp8;
	local int maxlengthline1;

	GetConstantInt( 0, maxlengthline1 );
	
	firstline = "";
	twoline = "";
	threeline = "";
	fourline = "";
	fiveline = "";
	
	Description = class'UIDATA_RAID'.static.GetRaidDescription(CurrentDataNum);
	length = Len(Description);
	lengthoffset = length-maxlengthline1;
	if (length > maxlengthline1)
	{
		firstline = Left(Description, maxlengthline1);
		twoline = Right(Description, lengthoffset);
		length2 = Len(twoline);
		if (length2 > maxlengthline1)
		{
			lengthoffset2 = length2-maxlengthline1;
			threeline = Right(twoline, lengthoffset2);
			twoline = Left(twoline, maxlengthline1);
			length3 = Len(threeline);
			if (length3 > maxlengthline1)
			{
				lengthoffset3 = length3-maxlengthline1;
				fourline = Right(threeline,lengthoffset3);
				threeline = Left(threeline, maxlengthline1);
				length4 = Len(fourline);
				if (length4 > maxlengthline1)
				{
					lengthoffset4 = length4-maxlengthline1;
					fiveline = Right(fourline,lengthoffset4);
					fourline = Left(fourline, maxlengthline1);
					length5 = Len(fiveline);
					if (length5 > (maxlengthline1-1))
					{			
						fiveline = Left(fiveline, (maxlengthline1-2));
						fiveline = fiveline $ "...";
					}
				}
			}
		}
		
	}
	else 
	{
		firstline = Description;
	}
	temp2 = left(twoline,1);
	temp4 = left(threeline,1);
	temp6 = left(fourline,1);
	temp8 = left(fiveline,1);
	if (temp2 == " ")
	{
	temp1 = Len(twoline);
	twoline=right(twoline, temp1-1);
	}
	if (temp2 == ".")
	{
	firstline = firstline$".";
	temp1 = Len(twoline);
	twoline=right(twoline, temp1-2);
	}	
	if (temp2 == "!")
	{
	firstline = firstline$"!";
	temp1 = Len(twoline);
	twoline=right(twoline, temp1-2);
	}
	if (temp2 == "?")
	{
	firstline = firstline$"?";
	temp1 = Len(twoline);
	twoline=right(twoline, temp1-2);
	}
	if (temp4 == " ")
	{
	temp3 = Len(threeline);
	threeline=right(threeline, temp3-1);
	}
	if (temp4 == ".")
	{
	twoline = twoline$".";
	temp3 = Len(threeline);
	threeline=right(threeline, temp3-2);
	}
	if (temp4 == "!")
	{
	twoline = twoline$"!";
	temp3 = Len(threeline);
	threeline=right(threeline, temp3-2);
	}
	if (temp4 == "?")
	{
	twoline = twoline$"?";
	temp3 = Len(threeline);
	threeline=right(threeline, temp3-2);
	}
	if (temp6 == " ")
	{
	temp5 = Len(fourline);
	fourline=right(fourline, temp5-1);
	}
	if (temp6 == ".")
	{
	threeline = threeline$".";
	temp5 = Len(fourline);
	fourline=right(fourline, temp5-2);
	}
	if (temp6 == "!")
	{
	threeline = threeline$"!";
	temp5 = Len(fourline);
	fourline=right(fourline, temp5-2);
	}
	if (temp6 == "?")
	{
	threeline = threeline$"?";
	temp5 = Len(fourline);
	fourline=right(fourline, temp5-2);
	}
	if (temp8 == " ")
	{
	temp7 = Len(fiveline);
	fiveline=right(fiveline, temp7-1);
	}
	if (temp8 == ".")
	{
	fourline = fourline$".";
	temp7 = Len(fiveline);
	fiveline=right(fiveline, temp7-2);
	}
	if (temp8 == "!")
	{
	fourline = fourline$"!";
	temp7 = Len(fiveline);
	fiveline=right(fiveline, temp7-2);
	}
	if (temp8 == "?")
	{
	fourline = fourline$"?";
	temp7 = Len(fiveline);
	fiveline=right(fiveline, temp7-2);
	}
	
	class'UIAPI_TEXTBOX'.static.SetText("GuideWnd.RaidComments1", firstline);
	class'UIAPI_TEXTBOX'.static.SetText("GuideWnd.RaidComments2", twoline);
	class'UIAPI_TEXTBOX'.static.SetText("GuideWnd.RaidComments3", threeline);
	class'UIAPI_TEXTBOX'.static.SetText("GuideWnd.RaidComments4", fourline);
	class'UIAPI_TEXTBOX'.static.SetText("GuideWnd.RaidComments5", fiveline);
}
*/
