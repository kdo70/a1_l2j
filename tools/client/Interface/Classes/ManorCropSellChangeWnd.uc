class ManorCropSellChangeWnd extends UICommonAPI;


const MANOR_NAME=0;
const CROP_REMAIN_CNT=1;
const CROP_PRICE=2;
const PROCURE_TYPE=3;

const COLUMN_CNT=4;


function OnLoad()
{
	RegisterEvent( EV_ManorCropSellChangeWndShow );
	RegisterEvent( EV_ManorCropSellChangeWndAddItem );
	RegisterEvent( EV_ManorCropSellChangeWndSetCropNameAndRewardType );
}

function OnEvent( int Event_ID, string a_param )
{
	switch( Event_ID )
	{
	case EV_ManorCropSellChangeWndShow :
		if(IsShowWindow("ManorCropSellChangeWnd"))
		{
			HideWindow("ManorCropSellChangeWnd");
		}
		else
		{
			Clear();
			ShowWindowWithFocus("ManorCropSellChangeWnd");
		}
		break;

	case EV_ManorCropSellChangeWndAddItem :
		HandleAddItem(a_param);
		break;
	case EV_ManorCropSellChangeWndSetCropNameAndRewardType :
		// 작물이름, 보상타입 맨위에 보이는것 설정
		HandleSetCropNameAndRewardType(a_param);
		break;
	}
}

function Clear()
{
	class'UIAPI_LISTCTRL'.static.DeleteAllItem("ManorCropSellChangeWnd.ManorCropSellChangeListCtrl");

	class'UIAPI_COMBOBOX'.static.Clear("ManorCropSellChangeWnd.cbPurchasePlace");
	class'UIAPI_COMBOBOX'.static.SYS_AddStringWithReserved("ManorCropSellChangeWnd.cbPurchasePlace", 1276, -1);
	class'UIAPI_COMBOBOX'.static.SetSelectedNum("ManorCropSellChangeWnd.cbPurchasePlace", 0);	// 수매처 콤보박스에 맨처음꺼 선택

	class'UIAPI_EDITBOX'.static.Clear("ManorCropSellChangeWnd.ebSalesVolume");					// 에디트박스 비움
}


function HandleSetCropNameAndRewardType(string a_param)
{
	local string CropName;
	local string RewardType1;
	local string RewardType2;

	ParseString(a_param, "CropName", CropName);
	ParseString(a_param, "RewardType1", RewardType1);
	ParseString(a_param, "RewardType2", RewardType2);
	
	class'UIAPI_TEXTBOX'.static.SetText("ManorCropSellChangeWnd.txtVarCropName", CropName);
	class'UIAPI_TEXTBOX'.static.SetText("ManorCropSellChangeWnd.txtVarRewardType1", RewardType1);
	class'UIAPI_TEXTBOX'.static.SetText("ManorCropSellChangeWnd.txtVarRewardType2", RewardType2);
}

function HandleAddItem(string a_Param)
{
	local LVDataRecord record;

	local string ManorName;
	local int CropRemainCnt;
	local int CropPrice;
	local int ProcureType;
	local int ManorID;

	record.LVDataList.Length=COLUMN_CNT;

	ParseString(a_Param, "ManorName", ManorName);
	ParseInt(a_Param, "CropRemainCnt", CropRemainCnt);
	ParseInt(a_Param, "CropPrice", CropPrice);
	ParseInt(a_Param, "ProcureType", ProcureType);
	ParseInt(a_Param, "ManorID", ManorID);

//	debug("CropName"$CropName$"ManorName"$ManorName$"CropRemainCnt"$CropRemainCnt$"CropPrice"$CropPrice$"ProcureType"$ProcureType$"MyCropCnt"$MyCropCnt);

	record.LVDataList[MANOR_NAME].szData=ManorName;
	record.LVDataList[CROP_REMAIN_CNT].szData=string(CropRemainCnt);
	record.LVDataList[CROP_PRICE].szData=string(CropPrice);
	record.LVDataList[PROCURE_TYPE].szData=string(ProcureType);
	record.nReserved1=ManorID;

	class'UIAPI_LISTCTRL'.static.InsertRecord("ManorCropSellChangeWnd.ManorCropSellChangeListCtrl", record );

	class'UIAPI_COMBOBOX'.static.AddStringWithReserved("ManorCropSellChangeWnd.cbPurchasePlace", ManorName, ManorID);
}


function OnClickButton(string strID)
{
	//debug(" "$strID);

	switch(strID)
	{
	case "btnMax" :
		HandleMaxButton();
		break;
	case "btnOk" :
		HandleOkBtn();
		break;
	case "btnCancel" :
		HideWindow("ManorCropSellChangeWnd");
		break;
	}
}

function HandleMaxButton()
{
	local LVDataRecord record;
	local int ManorID;
	local int MyCropCnt;
	local int CropRemainCnt;
	local int MinValue;
	local string MinValueString;

	// 콤보박스에서 장원 아이디 가져온다
	record=GetComboBoxSelectedRecord();
		
	CropRemainCnt=int(record.LVDataList[CROP_REMAIN_CNT].szData);
	ManorID=GetComboBoxSelectedManorID();
	if(ManorID ==-1) 
		return;
	MyCropCnt=GetMyCropCnt(ManorID);	

	//debug("남은수량"$record.LVDataList[CROP_REMAIN_CNT].szData$" ManorID:"$ManorID$" MyCropCnt"$MyCropCnt);

	// 둘중에 적은걸로 표시해준다
	MinValue=Min(MyCropCnt, CropRemainCnt);

	if(MinValue==-1)
		MinValueString="0";
	else
		MinValueString=string(MinValue);

	class'UIAPI_EDITBOX'.static.SetString("ManorCropSellChangeWnd.ebSalesVolume", MinValueString);
}


function HandleOkBtn()
{
	local LVDataRecord record;

	local int ManorID;
	local string SellCntString;

	local string param;

	record=GetComboBoxSelectedRecord();

	SellCntString=class'UIAPI_EDITBOX'.static.GetString("ManorCropSellChangeWnd.ebSalesVolume");
	ManorID=record.nReserved1;

	// 작물판매량 변경 정보를 판매 윈도우에 보내준다
	ParamAdd(param, "SellCntString", SellCntString);
	ParamAdd(param, "ManorID", string(ManorID));
	ParamAdd(param, "ManorName", record.LVDataList[MANOR_NAME].szData);
	ParamAdd(param, "CropRemainCntString", record.LVDataList[CROP_REMAIN_CNT].szData);
	ParamAdd(param, "CropPriceString", record.LVDataList[CROP_PRICE].szData);
	ParamAdd(param, "ProcureTypeString", record.LVDataList[PROCURE_TYPE].szData);

	ExecuteEvent(EV_ManorCropSellWndSetCropSell, param);

	HideWindow("ManorCropSellChangeWnd");
}


function int GetComboBoxSelectedManorID()
{
	local int ManorID;
	local int cbSelectedIndex;
	
	//debug("GetComboboxSelectedManorID");
	cbSelectedIndex=class'UIAPI_COMBOBOX'.static.GetSelectedNum("ManorCropSellChangeWnd.cbPurchasePlace");
		
	//debug("selectedindex:" $ cbSelectedIndex);

	ManorID=class'UIAPI_COMBOBOX'.static.GetReserved("ManorCropSellChangeWnd.cbPurchasePlace", cbSelectedIndex);
		
	//debug("ID:"$ManorID);

	return ManorID;
}

function LVDataRecord GetComboBoxSelectedRecord()
{
	local LVDataRecord record;
	local int ManorID;
	local int RecordCount;
	local int i;

	ManorID=GetComboBoxSelectedManorID();

	// 리스트 갯수 얻어온다
	RecordCount=class'UIAPI_LISTCTRL'.static.GetRecordCount("ManorCropSellChangeWnd.ManorCropSellChangeListCtrl");

	for(i=0; i<RecordCount; ++i)
	{
		record=class'UIAPI_LISTCTRL'.static.GetRecord("ManorCropSellChangeWnd.ManorCropSellChangeListCtrl", i);
		
		// 리스트를 돌다가 ID랑 같은게 뱔견되면 찾는 레코드
		if(record.nReserved1==ManorID)
			break;
	}

	return record;
}


function int GetMyCropCnt(int ManorID)
{
	local int MyCropCnt;
	local LVDataRecord record;

	MyCropCnt=-1;

	record=class'UIAPI_LISTCTRL'.static.GetSelectedRecord("ManorCropSellWnd.ManorCropSellListCtrl");
	MyCropCnt=int(record.LVDataList[5].szData);
	
	return MyCropCnt;
}
