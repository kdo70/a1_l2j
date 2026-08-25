class ManorSeedInfoChangeWnd extends UICommonAPI;


var int m_MinCropPrice;
var int m_MaxCropPrice;
var int m_TomorrowLimit;

function OnLoad()
{
	RegisterEvent( EV_ManorSeedInfoChangeWndShow );
}

function OnEvent( int Event_ID, string a_Param)
{
	switch( Event_ID )
	{
	case EV_ManorSeedInfoChangeWndShow :
		HandleShow(a_Param);
		break;
	}
}

function HandleShow(string a_Param)
{
	local string SeedName;
	local int TomorrowVolumeOfSales;
	local int TomorrowLimit;
	local int TomorrowPrice;
	local int MinCropPrice;
	local int MaxCropPrice;

	local string TomorrowLimitString;


	ParseString(a_Param, "SeedName", SeedName);							// 씨앗이름
	ParseInt(a_Param, "TomorrowVolumeOfSales", TomorrowVolumeOfSales);	// 내일 판매량
	ParseInt(a_Param, "TomorrowLimit", TomorrowLimit);					// 내일 발매한도
	ParseInt(a_Param, "TomorrowPrice", TomorrowPrice);					// 내일 가격

	ParseInt(a_Param, "MinCropPrice", MinCropPrice);						// 최소작물가격
	ParseInt(a_Param, "MaxCropPrice", MaxCropPrice);						// 최대작물가격

	class'UIAPI_TEXTBOX'.static.SetText("ManorSeedInfoChangeWnd.txtSeedName", SeedName);
	class'UIAPI_EDITBOX'.static.SetString("ManorSeedInfoChangeWnd.ebTomorrowSalesVolume", string(TomorrowVolumeOfSales));

	m_TomorrowLimit=TomorrowLimit;
	TomorrowLimitString=MakeCostString(string(TomorrowLimit));
	class'UIAPI_TEXTBOX'.static.SetText("ManorSeedInfoChangeWnd.txtVarTomorrowLimit", TomorrowLimitString);
	class'UIAPI_EDITBOX'.static.SetString("ManorSeedInfoChangeWnd.ebTomorrowPrice", string(TomorrowPrice));

	m_MinCropPrice=MinCropPrice;
	m_MaxCropPrice=MaxCropPrice;

	ShowWindowWithFocus("ManorSeedInfoChangeWnd");
	class'UIAPI_WINDOW'.static.SetFocus("ManorSeedInfoChangeWnd.ebTomorrowSalesVolume");
}

function OnClickButton(string strID)
{
	debug(" "$strID);

	switch(strID)
	{
	case "btnOk" :
		OnClickBtnOk();
		break;
	case "btnCancel" :
		HideWindow("ManorSeedInfoChangeWnd");
		break;
	}
}

function OnClickBtnOk()
{
	local int InputTomorrowSalesVolume;
	local int InputTomorrowPrice;

	local string ParamString;
	
	InputTomorrowSalesVolume=int(class'UIAPI_EDITBOX'.static.GetString("ManorSeedInfoChangeWnd.ebTomorrowSalesVolume"));
	InputTomorrowPrice=int(class'UIAPI_EDITBOX'.static.GetString("ManorSeedInfoChangeWnd.ebTomorrowPrice"));

	if(InputTomorrowSalesVolume < 0 || InputTomorrowSalesVolume > m_TomorrowLimit)
	{	
		ShowErrorDialog(0, m_TomorrowLimit, 1558);	
		return;
	}

	if(InputTomorrowSalesVolume !=0 && (InputTomorrowPrice < m_MinCropPrice || InputTomorrowPrice > m_MaxCropPrice))
	{
		ShowErrorDialog(m_MinCropPrice, m_MaxCropPrice, 1557);
		return;
	}

	ParamAdd(ParamString, "TomorrowSalesVolume", string(InputTomorrowSalesVolume));
	ParamAdd(ParamString, "TomorrowPrice", string(InputTomorrowPrice));
	ExecuteEvent(EV_ManorSeedInfoSettingWndChangeValue, ParamString);

	HideWindow("ManorSeedInfoChangeWnd");
}


function ShowErrorDialog(int MinValue, int MaxValue, int SystemStringIdx)
{
	local string ParamString;
	local string Message;

	ParamAdd(ParamString, "Type", string(int(ESystemMsgParamType.SMPT_NUMBER)));
	ParamAdd(ParamString, "param1", string(MinValue));
	AddSystemMessageParam(ParamString);
	ParamString="";
	ParamAdd(ParamString, "Type", string(int(ESystemMsgParamType.SMPT_NUMBER)));
	ParamAdd(ParamString, "param1", string(MaxValue));
	AddSystemMessageParam(ParamString);
	Message = EndSystemMessageParam(SystemStringIdx, true);

	DialogShow( DIALOG_Notice, Message );
}
