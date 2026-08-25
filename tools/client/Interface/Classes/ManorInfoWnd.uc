class ManorInfoWnd extends UICommonAPI;

const SEED_NAME=0;
const SEED_REMAIN_CNT=1;
const SEED_TOTLAL_CNT=2;
const SEED_PRICE=3;
const SEED_LEVEL=4;
const SEED_REWARD_TYPE_1=5;
const SEED_REWARD_TYPE_2=6;
const SEED_MAX_COLUMN=7;


const CROP_NAME=0;
const CROP_REMAIN_CNT=1;
const CROP_TOTLAL_CNT=2;
const CROP_PRICE=3;
const CROP_PROCURE_TYPE=4;
const CROP_LEVEL=5;
const CROP_REWARD_TYPE_1=6;
const CROP_REWARD_TYPE_2=7;
const CROP_MAX_COLUMN=8;

const DEFAULT_CROP_NAME=0;
const DEFAULT_CROP_LEVEL=1;
const DEFAULT_SEED_PRICE=2;
const DEFAULT_CROP_PRICE=3;
const DEFAULT_REWARD_TYPE_1=4;
const DEFAULT_REWARD_TYPE_2=5;
const DEFAULT_MAX_COLUMN=6;



var bool m_bTime;



var int m_MerchantOrChamberlain;
var int m_ManorID;
var int m_MyManorID;

function OnLoad()
{
	RegisterEvent( EV_ManorInfoWndSeedShow );
	RegisterEvent( EV_ManorInfoWndCropShow );
	RegisterEvent( EV_ManorInfoWndDefaultShow );

	RegisterEvent( EV_ManorInfoWndSeedAdd );
	RegisterEvent( EV_ManorInfoWndCropAdd );
	RegisterEvent( EV_ManorInfoWndDefaultAdd );

	m_MerchantOrChamberlain=0;
	m_ManorID=-1;
	m_MyManorID=-1;
	m_bTime = false;
}

function OnEvent( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	case EV_ManorInfoWndSeedShow :
		HandleSeedInfoShow(a_Param);
		break;
	case EV_ManorInfoWndSeedAdd :
		HandleSeedAdd(a_Param);
		break;

	case EV_ManorInfoWndCropShow :
		HandleCropInfoShow(a_Param);
		break;
	case EV_ManorInfoWndCropAdd :
		HandleCropAdd(a_Param);
		break;

	case EV_ManorInfoWndDefaultShow :
		HandleDefaultInfoShow(a_Param);
		break;
	case EV_ManorInfoWndDefaultAdd :
		HandleDefaultAdd(a_Param);
		break;

	}
}

// ------------------------------- 씨앗현황 --------------------------------------
function HandleSeedInfoShow(string a_Param)
{
	local int MerchantOrChamberlain;
	local int NumOfManor;
	local int i;
	local int ManorID;
	local string ManorName;

	local string ParamString;
	local string Message;
	
	local int ManorCnt;
	local string MyManorName;


	ParseInt(a_Param, "MerchantOrChamberlain", MerchantOrChamberlain);
	ParseInt(a_Param, "ManorID", ManorID);
	ParseString(a_Param, "ManorName", ManorName);

	m_MerchantOrChamberlain=MerchantOrChamberlain;
	m_ManorID=ManorID;

	debug("HandleSeedInfoShow - m_ManorID:"$m_ManorID);


	class'UIAPI_LISTCTRL'.static.DeleteAllItem("ManorInfoWnd.SeedInfoWnd.SeedInfoListCtrl");
	class'UIAPI_COMBOBOX'.static.Clear("ManorInfoWnd.SeedInfoWnd.cbManorSelectInSeedInfo");


	// 콤보박스에 장원리스트 더해주고
	for(i=0; i<GetManorCount(); ++i)
	{
		ManorID = GetManorIDInManorList(i);
		class'UIAPI_COMBOBOX'.static.AddStringWithReserved("ManorInfoWnd.SeedInfoWnd.cbManorSelectInSeedInfo", GetManorNameInManorList(i), ManorID);
	}

	// 더해준거가지고 돌면서 비교해서 콤보박스 선택해준다
	NumOfManor=class'UIAPI_COMBOBOX'.static.GetNumOfItems("ManorInfoWnd.SeedInfoWnd.cbManorSelectInSeedInfo");

	for(i=0; i<NumOfManor; ++i)
	{
		if(m_ManorID==class'UIAPI_COMBOBOX'.static.GetReserved("ManorInfoWnd.SeedInfoWnd.cbManorSelectInSeedInfo", i))
		{
			class'UIAPI_COMBOBOX'.static.SetSelectedNum("ManorInfoWnd.SeedInfoWnd.cbManorSelectInSeedInfo", i);
			break;
		}
	}
	
	if(!IsShowWindow("ManorInfoWnd"))
		m_MyManorID=m_ManorID;

	
	
	
	if(MerchantOrChamberlain==1)
	{
		HideWindow("ManorInfoWnd.SeedInfoWnd.btnBuySeed");
	}
	else
	{
		ShowWindow("ManorInfoWnd.SeedInfoWnd.btnBuySeed");
		
		
		ManorCnt=GetManorCount();
		
		for(i=0; i<ManorCnt; ++i)
		{
			if(m_MyManorID==GetManorIDInManorList(i))
			{
				MyManorName=GetManorNameInManorList(i);
				break;
			}
		}

		ParamAdd(ParamString, "Type", string(int(ESystemMsgParamType.SMPT_STRING)));
		ParamAdd(ParamString, "param1", MyManorName);
		AddSystemMessageParam(ParamString);
		Message = EndSystemMessageParam(1605, true);
		class'UIAPI_TEXTBOX'.static.SetText("ManorInfoWnd.SeedInfoWnd.txtNotice", Message);
	}
	
	
	ShowWindowWithFocus("ManorInfoWnd");

	HideWindow("ManorInfoWnd.CropInfoWnd");
	HideWindow("ManorInfoWnd.DefaultInfoWnd");
	
	
	class'UIAPI_TABCTRL'.static.SetTopOrder("ManorInfoWnd.ManorInfoTabCtrl", 0, false);

	if(!IsShowWindow("ManorInfoWnd.SeedInfoWnd"))
	{
		class'UIAPI_COMBOBOX'.static.SetSelectedNum("ManorInfoWnd.CropInfoWnd.cbManorSelectInCropInfo", -1);
		ShowWindowWithFocus("ManorInfoWnd.SeedInfoWnd");

		debug("HandleSeedInfoShow  !IsShowWindow 안 - m_ManorID:"$m_ManorID$"m_MyManorID:"$m_MyManorID);
	}
}

function HandleSeedAdd(string a_Param)
{
	local int SeedID;
	local string SeedName;
	local int SeedRemainCnt;
	local int SeedTotalCnt;
	local int SeedPrice;
	local int SeedLevel;
	local string RewardType1;
	local string RewardType2;

	local LVDataRecord record;

	ParseInt(a_Param, "SeedID", SeedID);
	ParseString(a_Param, "SeedName", SeedName);
	ParseInt(a_Param, "SeedRemainCnt", SeedRemainCnt);
	ParseInt(a_Param, "SeedTotalCnt", SeedTotalCnt);
	ParseInt(a_Param, "SeedPrice", SeedPrice);
	ParseInt(a_Param, "SeedLevel", SeedLevel);
	ParseString(a_Param, "RewardType1", RewardType1);
	ParseString(a_Param, "RewardType2", RewardType2);

	record.LVDataList.Length=SEED_MAX_COLUMN;

	record.LVDataList[SEED_NAME].szData=SeedName;
	record.LVDataList[SEED_REMAIN_CNT].szData=string(SeedRemainCnt);
	record.LVDataList[SEED_TOTLAL_CNT].szData=string(SeedTotalCnt);
	record.LVDataList[SEED_PRICE].szData=string(SeedPrice);
	record.LVDataList[SEED_LEVEL].szData=string(SeedLevel);
	record.LVDataList[SEED_REWARD_TYPE_1].szData=RewardType1;
	record.LVDataList[SEED_REWARD_TYPE_2].szData=RewardType2;

	class'UIAPI_LISTCTRL'.static.InsertRecord("ManorInfoWnd.SeedInfoWnd.SeedInfoListCtrl", record);
}


// ------------------------------- 작물현황 --------------------------------------
function HandleCropInfoShow(string a_Param)
{
	local int MerchantOrChamberlain;
	local int NumOfManor;
	local int i;
	local int ManorID;

	ParseInt(a_Param, "MerchantOrChamberlain", MerchantOrChamberlain);
	ParseInt(a_Param, "ManorID", ManorID);

	m_MerchantOrChamberlain=MerchantOrChamberlain;
	m_ManorID=ManorID;


	class'UIAPI_LISTCTRL'.static.DeleteAllItem("ManorInfoWnd.CropInfoWnd.CropInfoListCtrl");
	class'UIAPI_COMBOBOX'.static.Clear("ManorInfoWnd.CropInfoWnd.cbManorSelectInCropInfo");


	// 콤보박스에 장원리스트 더해주고
	for(i=0; i<GetManorCount(); ++i)
	{
		ManorID = GetManorIDInManorList(i);
		class'UIAPI_COMBOBOX'.static.AddStringWithReserved("ManorInfoWnd.CropInfoWnd.cbManorSelectInCropInfo", GetManorNameInManorList(i), ManorID);
	}

	// 더해준거가지고 돌면서 비교해서 콤보박스 선택해준다
	NumOfManor=class'UIAPI_COMBOBOX'.static.GetNumOfItems("ManorInfoWnd.CropInfoWnd.cbManorSelectInCropInfo");

	for(i=0; i<NumOfManor; ++i)
	{
		if(m_ManorID==class'UIAPI_COMBOBOX'.static.GetReserved("ManorInfoWnd.CropInfoWnd.cbManorSelectInCropInfo", i))
		{
			class'UIAPI_COMBOBOX'.static.SetSelectedNum("ManorInfoWnd.CropInfoWnd.cbManorSelectInCropInfo", i);
			break;
		}
	}

	// 일반 유저(농부)가 아니고장원 셋팅하는사람일 경우
	if(MerchantOrChamberlain==1)
		HideWindow("ManorInfoWnd.CropInfoWnd.btnSellCrop");
	else
		ShowWindow("ManorInfoWnd.CropInfoWnd.btnSellCrop");

	if(!IsShowWindow("ManorInfoWnd.CropInfoWnd"))
	{
		ShowWindowWithFocus("ManorInfoWnd.CropInfoWnd");

		if(!IsShowWindow("ManorInfoWnd"))
			ShowWindow("ManorInfoWnd");

		HideWindow("ManorInfoWnd.SeedInfoWnd");
		HideWindow("ManorInfoWnd.DefaultInfoWnd");
	}
}

function HandleCropAdd(string a_Param)
{
	local int CropID;
	local string CropName;
	local int CropRemainCnt;
	local int CropTotalCnt;
	local int CropPrice;
	local int ProcureType;
	local int CropLevel;
	local string RewardType1;
	local string RewardType2;

	local LVDataRecord record;

	ParseInt(a_Param, "CropID", CropID);
	ParseString(a_Param, "CropName", CropName);
	ParseInt(a_Param, "CropRemainCnt", CropRemainCnt);
	ParseInt(a_Param, "CropTotalCnt", CropTotalCnt);
	ParseInt(a_Param, "CropPrice", CropPrice);
	ParseInt(a_Param, "ProcureType", ProcureType);
	ParseInt(a_Param, "CropLevel", CropLevel);
	ParseString(a_Param, "RewardType1", RewardType1);
	ParseString(a_Param, "RewardType2", RewardType2);

	record.LVDataList.Length=CROP_MAX_COLUMN;

	record.LVDataList[CROP_NAME].szData=CROPName;
	record.LVDataList[CROP_REMAIN_CNT].szData=string(CROPRemainCnt);
	record.LVDataList[CROP_TOTLAL_CNT].szData=string(CROPTotalCnt);
	record.LVDataList[CROP_PRICE].szData=string(CROPPrice);
	record.LVDataList[CROP_PROCURE_TYPE].szData=string(ProcureType);
	record.LVDataList[CROP_LEVEL].szData=string(CROPLevel);
	record.LVDataList[CROP_REWARD_TYPE_1].szData=RewardType1;
	record.LVDataList[CROP_REWARD_TYPE_2].szData=RewardType2;

	class'UIAPI_LISTCTRL'.static.InsertRecord("ManorInfoWnd.CropInfoWnd.CropInfoListCtrl", record);
}


// ------------------------------- 기본정보 --------------------------------------
function HandleDefaultInfoShow(string a_Param)
{
	local int MerchantOrChamberlain;

	ParseInt(a_Param, "MerchantOrChamberlain", MerchantOrChamberlain);

	m_MerchantOrChamberlain=MerchantOrChamberlain;


	class'UIAPI_LISTCTRL'.static.DeleteAllItem("ManorInfoWnd.DefaultInfoWnd.DefaultInfoListCtrl");

	// 일반 유저(농부)가 아니고 장원 셋팅하는사람일 경우
	if(MerchantOrChamberlain==1)
	{
		HideWindow("ManorInfoWnd.DefaultInfoWnd.btnSellCrop");
		HideWindow("ManorInfoWnd.DefaultInfoWnd.btnBuySeed");
	}
	else
	{
		ShowWindow("ManorInfoWnd.DefaultInfoWnd.btnSellCrop");
		ShowWindow("ManorInfoWnd.DefaultInfoWnd.btnBuySeed");
	}

	ShowWindowWithFocus("ManorInfoWnd");
	ShowWindowWithFocus("ManorInfoWnd.DefaultInfoWnd");
	
	class'UIAPI_TABCTRL'.static.SetTopOrder("ManorInfoWnd.ManorInfoTabCtrl", 2, false);

	HideWindow("ManorInfoWnd.SeedInfoWnd");
	HideWindow("ManorInfoWnd.CropInfoWnd");
}

function HandleDefaultAdd(string a_Param)
{
	local int CropID;
	local string CropName;
	local int CropLevel;
	local int SeedPrice;
	local int CropPrice;
	local string RewardType1;
	local string RewardType2;

	local LVDataRecord record;

	ParseInt(a_Param, "CropID", CropID);
	ParseString(a_Param, "CropName", CropName);
	ParseInt(a_Param, "CropLevel", CropLevel);
	ParseInt(a_Param, "SeedPrice", SeedPrice);
	ParseInt(a_Param, "CropPrice", CropPrice);
	ParseString(a_Param, "RewardType1", RewardType1);
	ParseString(a_Param, "RewardType2", RewardType2);


	record.LVDataList.Length=DEFAULT_MAX_COLUMN;

	record.LVDataList[DEFAULT_CROP_NAME].szData=CropName;
	record.LVDataList[DEFAULT_CROP_LEVEL].szData=string(CropLevel);
	record.LVDataList[DEFAULT_SEED_PRICE].szData=string(SeedPrice);
	record.LVDataList[DEFAULT_CROP_PRICE].szData=string(CropPrice);
	record.LVDataList[DEFAULT_REWARD_TYPE_1].szData=RewardType1;
	record.LVDataList[DEFAULT_REWARD_TYPE_2].szData=RewardType2;

	class'UIAPI_LISTCTRL'.static.InsertRecord("ManorInfoWnd.DefaultInfoWnd.DefaultInfoListCtrl", record);
}


function OnClickButton( string strID )
{
	Debug( strID );

	switch( strID )
	{
	case "btnBuySeed" :
		RequestBypassToServer("manor_menu_select?ask=1&state=-1&time=0");
		break;
	case "btnSellCrop" :
		RequestBypassToServer("manor_menu_select?ask=2&state=-1&time=0");
		break;
	case "ManorInfoTabCtrl0" :
		OnClickInfoTab("SeedInfo");
		break;
	case "ManorInfoTabCtrl1" :
		OnClickInfoTab("CropInfo");
		break;
	case "ManorInfoTabCtrl2" :
		RequestBypassToServer("manor_menu_select?ask=5&state=-1&time=0");
		break;
	}
}

function OnClickInfoTab(string TabName)
{
	local int SelectedManorID;
	local int SelectedTime;
	local string RequestString;
	local string PreString;

	local int Index;

	local string ManorComboBoxName;
	local string TimeComboBoxName;

	switch(TabName)
	{
	case "SeedInfo" :
		PreString="manor_menu_select?ask=3&state=";
		ManorComboBoxName="ManorInfoWnd.SeedInfoWnd.cbManorSelectInSeedInfo";
		TimeComboBoxName="ManorInfoWnd.SeedInfoWnd.cbTimeInSeedInfo";
		break;
	case "CropInfo" :
		PreString="manor_menu_select?ask=4&state="; 
		ManorComboBoxName="ManorInfoWnd.CropInfoWnd.cbManorSelectInCropInfo";
		TimeComboBoxName="ManorInfoWnd.CropInfoWnd.cbTimeInCropInfo";
		break;
	}

	Index=class'UIAPI_COMBOBOX'.static.GetSelectedNum(ManorComboBoxName);
	SelectedManorID=class'UIAPI_COMBOBOX'.static.GetReserved(ManorComboBoxName, index);

	SelectedTime=class'UIAPI_COMBOBOX'.static.GetSelectedNum(TimeComboBoxName);

	debug("ID:"$SelectedManorID);
	if(TabName=="CropInfo" && SelectedManorID == -1)
		SelectedManorID=m_MyManorID;

	if(SelectedManorID!=0)
	{
		debug("장원ID - ID:"$SelectedManorID);
		RequestString=PreString $ string(SelectedManorID) $"&time="$ string(SelectedTime);
		RequestBypassToServer(RequestString);
	}
	else
	{
		debug("장원ID 오류 - ID:"$SelectedManorID);
	}

}

function OnComboBoxItemSelected( string sName, int index )
{
	debug( sName$", index:"$index);
	switch( sName )
	{
	case "cbManorSelectInSeedInfo":
		m_bTime = false;
		RequestSelectedData("SeedInfo", index);
		break;
	case "cbTimeInSeedInfo":
		m_bTime = true;
		RequestSelectedData("SeedInfo", index);
		break;
	case "cbManorSelectInCropInfo":
		m_bTime = false;
		RequestSelectedData("CropInfo", index);
		break;
	case "cbTimeInCropInfo" :
		m_bTime = true;
		RequestSelectedData("CropInfo", index);
		break;
	}
}

function RequestSelectedData(string WindowName, int Index)
{
	local int ManorID;
	local string RequestString;
	local string PreString;
	local int Time;
	local string ManorComboboxName;
	local string TimeComboboxName;

	if(WindowName=="SeedInfo")
	{
		PreString="manor_menu_select?ask=3&state=";
		ManorComboboxName="ManorInfoWnd.SeedInfoWnd.cbManorSelectInSeedInfo";
		TimeComboboxName="ManorInfoWnd.SeedInfoWnd.cbTimeInSeedInfo";
	}
	else
	{
		PreString="manor_menu_select?ask=4&state=";
		ManorComboboxName="ManorInfoWnd.CropInfoWnd.cbManorSelectInCropInfo";
		TimeComboboxName="ManorInfoWnd.CropInfoWnd.cbTimeInCropInfo";
	}

	//--------- 수정한 코드 //시간관련 데이터를 수정하였습니다.
	if(m_bTime)	
	{
		ManorID = m_ManorID;
		Time=class'UIAPI_COMBOBOX'.static.GetSelectedNum(TimeComboboxName);
	}
	else
	{
		ManorID=class'UIAPI_COMBOBOX'.static.GetReserved(ManorComboboxName, index);
		Time=class'UIAPI_COMBOBOX'.static.GetSelectedNum(TimeComboboxName);
	}
	//--------- 수정한 코드
	
	//--------- 원래 코드
	//ManorID=class'UIAPI_COMBOBOX'.static.GetReserved(ManorComboboxName, index);
	//Time=class'UIAPI_COMBOBOX'.static.GetSelectedNum(TimeComboboxName);
	//--------- 원래 코드

	if(ManorID>0)
	{
		debug("장원ID"$ManorID);
		RequestString=PreString $string(ManorID)$"&time="$string(Time);
	}
	else
		debug("장원ID오류 : "$ManorID);
	RequestBypassToServer( RequestString );
}
