class ManorCropInfoChangeWnd extends UICommonAPI;


var int m_MinCropPrice;
var int m_MaxCropPrice;
var int m_TomorrowLimit;

function OnLoad()
{
	RegisterEvent( EV_ManorCropInfoChangeWndShow );
}

function OnEvent( int Event_ID, string a_Param)
{
	debug(""$Event_ID);
	switch( Event_ID )
	{
	case EV_ManorCropInfoChangeWndShow :
		HandleShow(a_Param);
		break;
	}
}

function HandleShow(string a_Param)
{
	local string CropName;
	local int TomorrowVolumeOfBuy;
	local int TomorrowLimit;
	local int TomorrowPrice;
	local int TomorrowProcure;
	local int MinCropPrice;
	local int MaxCropPrice;

	local string TomorrowLimitString;


	ParseString(a_Param, "CropName", CropName);							// 작물이름
	ParseInt(a_Param, "TomorrowVolumeOfBuy", TomorrowVolumeOfBuy);	// 내일 수매량
	ParseInt(a_Param, "TomorrowLimit", TomorrowLimit);					// 내일 수매한도
	ParseInt(a_Param, "TomorrowPrice", TomorrowPrice);					// 내일 수매가
	ParseInt(a_Param, "TomorrowProcure", TomorrowProcure);				// 내일 보상

	ParseInt(a_Param, "MinCropPrice", MinCropPrice);						// 최소작물가격
	ParseInt(a_Param, "MaxCropPrice", MaxCropPrice);						// 최대작물가격

	class'UIAPI_TEXTBOX'.static.SetText("ManorCropInfoChangeWnd.txtCropName", CropName);
	class'UIAPI_EDITBOX'.static.SetString("ManorCropInfoChangeWnd.ebTomorrowAmountOfPurchase", string(TomorrowVolumeOfBuy));

	m_TomorrowLimit=TomorrowLimit;
	TomorrowLimitString=MakeCostString(string(TomorrowLimit));
	class'UIAPI_TEXTBOX'.static.SetText("ManorCropInfoChangeWnd.txtVarTomorrowPurchaseLimit", TomorrowLimitString);
	class'UIAPI_EDITBOX'.static.SetString("ManorCropInfoChangeWnd.ebTomorrowPurchasePrice", string(TomorrowPrice));

	if(TomorrowProcure==0)
		TomorrowProcure=1;

	class'UIAPI_COMBOBOX'.static.SetSelectedNum("ManorCropInfoChangeWnd.cbTomorrowReward", TomorrowProcure-1);

	m_MinCropPrice=MinCropPrice;
	m_MaxCropPrice=MaxCropPrice;

	ShowWindowWithFocus("ManorCropInfoChangeWnd");
	class'UIAPI_WINDOW'.static.SetFocus("ManorCropInfoChangeWnd.ebTomorrowAmountOfPurchase");
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
		HideWindow("ManorCropInfoChangeWnd");
		break;
	}
}

function OnClickBtnOk()
{
	local int InputTomorrowAmountOfPurchase;
	local int InputTomorrowPurchasePrice;
	local int InputTomorrowProcure;
	local string Procure;

	local int SelectedNum;

	local string ParamString;
	
	InputTomorrowAmountOfPurchase=int(class'UIAPI_EDITBOX'.static.GetString("ManorCropInfoChangeWnd.ebTomorrowAmountOfPurchase"));
	InputTomorrowPurchasePrice=int(class'UIAPI_EDITBOX'.static.GetString("ManorCropInfoChangeWnd.ebTomorrowPurchasePrice"));

	if(InputTomorrowAmountOfPurchase < 0 || InputTomorrowAmountOfPurchase > m_TomorrowLimit)
	{	
		ShowErrorDialog(0, m_TomorrowLimit, 1560);	
		return;
	}

	if(InputTomorrowAmountOfPurchase !=0 && (InputTomorrowPurchasePrice < m_MinCropPrice || InputTomorrowPurchasePrice > m_MaxCropPrice))
	{
		ShowErrorDialog(m_MinCropPrice, m_MaxCropPrice, 1559);
		return;
	}

	SelectedNum=class'UIAPI_COMBOBOX'.static.GetSelectedNum("ManorCropInfoChangeWnd.cbTomorrowReward");
	Procure=class'UIAPI_COMBOBOX'.static.GetString("ManorCropInfoChangeWnd.cbTomorrowReward", SelectedNum);
	
	InputTomorrowProcure=int(Procure);


	ParamAdd(ParamString, "TomorrowAmountOfPurchase", string(InputTomorrowAmountOfPurchase));
	ParamAdd(ParamString, "TomorrowPurchasePrice", string(InputTomorrowPurchasePrice));
	ParamAdd(ParamString, "TomorrowProcure", string(InputTomorrowProcure));
	ExecuteEvent(EV_ManorCropInfoSettingWndChangeValue, ParamString);

	HideWindow("ManorCropInfoChangeWnd");
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
