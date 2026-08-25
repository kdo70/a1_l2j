class HennaInfoWnd extends UIScript;

// 문양 정보 윈도우의 상태
const HENNA_EQUIP=1;		// 문양새기기
const HENNA_UNEQUIP=2;		// 문양지우기

var int m_iState;
var int m_iHennaID;

function OnLoad()
{
	RegisterEvent( EV_HennaInfoWndShowHideEquip);
	RegisterEvent( EV_HennaInfoWndShowHideUnEquip);
}

function OnClickButton( string strID )
{
	class'UIAPI_WINDOW'.static.HideWindow("HennaInfoWnd");

	switch( strID )
	{
	case "btnPrev" :
		if(m_iState==HENNA_EQUIP)
			RequestHennaItemList();
		else if(m_iState==HENNA_UNEQUIP)
			RequestHennaUnEquipList();
		break;
	case "btnOK" :
		if(m_iState==HENNA_EQUIP)
			RequestHennaEquip(m_iHennaID);
		else if(m_iState==HENNA_UNEQUIP)
			RequestHennaUnEquip(m_iHennaID);
		break;
	}
}

function OnShow()
{
	// 상태에 따라 윈도를 보여주고 숨겨줍니다
	if(m_iState==HENNA_EQUIP)
	{
		// 타이틀 - 문양새기기
		class'UIAPI_WINDOW'.static.SetWindowTitleByText("HennaInfoWnd", GetSystemString(651));
		class'UIAPI_WINDOW'.static.HideWindow("HennaInfoWnd.HennaInfoWndUnEquip");
		class'UIAPI_WINDOW'.static.ShowWindow("HennaInfoWnd.HennaInfoWndEquip");
	}
	else if(m_iState==HENNA_UNEQUIP)
	{
		// 타이틀 - 문양지우기
		class'UIAPI_WINDOW'.static.SetWindowTitleByText("HennaInfoWnd", GetSystemString(652));
		class'UIAPI_WINDOW'.static.HideWindow("HennaInfoWnd.HennaInfoWndEquip");
		class'UIAPI_WINDOW'.static.ShowWindow("HennaInfoWnd.HennaInfoWndUnEquip");
	}
	else
	{
		debug("에러에러 이상이상~~");
	}
}


function OnEvent(int Event_ID, string param)
{

	switch(Event_ID)
	{
	case EV_HennaInfoWndShowHideEquip :
		m_iState=HENNA_EQUIP;		// 상태를 "문양새기기"로 바꿉니다.
		ShowHennaInfoWnd(param);
		break;
	case EV_HennaInfoWndShowHideUnEquip :
		m_iState=HENNA_UNEQUIP;		// 상태를 "문양지우기"로 바꿉니다.
		ShowHennaInfoWnd(param);
		break;
	}
}

function ShowHennaInfoWnd(string param)
{
	local string strAdenaComma;

	local int iAdena;
	local string strDyeName;			// 염료
	local string strDyeIconName;
	local int iHennaID;
	local int iClassID;
	local int iNum;
	local int iFee;

	local string strTattooName;			// 문양
	local string strTattooAddName;		// 문양
	local string strTattooIconName;

	local int iINTnow;
	local int iINTchange;
	local int iSTRnow;
	local int iSTRchange;
	local int iCONnow;
	local int iCONchange;
	local int iMENnow;
	local int iMENchange;
	local int iDEXnow;
	local int iDEXchange;
	local int iWITnow;
	local int iWITchange;

	local color col;

	ParseInt(param, "Adena", iAdena);						// 아데나
	ParseString(param, "DyeIconName", strDyeIconName);		// 염료 Icon 이름
	ParseString(param, "DyeName", strDyeName);				// 염료이름
	ParseInt(param, "HennaID", iHennaID);				 
	ParseInt(param, "ClassID", iClassID);
	ParseInt(param, "NumOfItem", iNum);
	ParseInt(param, "Fee", iFee);

	ParseString(param, "TattooIconName", strTattooIconName);	// 문양아이콘이름
	ParseString(param, "TattooName", strTattooName);		// 문양이름
	ParseString(param, "TattooAddName", strTattooAddName);	// 문양정보 - 수치변동텍스트 

	ParseInt(param, "INTnow", iINTnow);
	ParseInt(param, "INTchange", iINTchange);
	ParseInt(param, "STRnow", iSTRnow);
	ParseInt(param, "STRchange", iSTRchange);
	ParseInt(param, "CONnow", iCONnow);
	ParseInt(param, "CONchange", iCONchange);
	ParseInt(param, "MENnow", iMENnow);
	ParseInt(param, "MENchange", iMENchange);
	ParseInt(param, "DEXnow", iDEXnow);
	ParseInt(param, "DEXchange", iDEXchange);
	ParseInt(param, "WITnow", iWITnow);
	ParseInt(param, "WITchange", iWITchange);


	m_iHennaID=iHennaID;		// 문양을 새기거나 제거할때 필요하므로 ID를 저장해둡니다

	if(m_iState==HENNA_EQUIP)
	{
		// 염료
		class'UIAPI_TEXTBOX'.static.SetText("HennaInfoWnd.txtDyeInfo", GetSystemString(638));			// "염료정보"
		class'UIAPI_TEXTURECTRL'.static.SetTexture("HennaInfoWnd.textureDyeIconName", strDyeIconName);	// 염료 Icon
		class'UIAPI_TEXTBOX'.static.SetText("HennaInfoWnd.txtDyeName", strDyeName);						// 염료이름

		col.R=168;
		col.G=168;
		col.B=168;
		class'UIAPI_TEXTBOX'.static.SetText("HennaInfoWnd.txtFee", GetSystemString(637) $ " : ");		// "수수료 : "
		class'UIAPI_TEXTBOX'.static.SetTextColor("HennaInfoWnd.txtFee", col);		

		strAdenaComma = MakeCostString("" $ iFee);
		col= GetNumericColor(strAdenaComma);
		class'UIAPI_TEXTBOX'.static.SetText("HennaInfoWnd.txtAdena", strAdenaComma);		// 수수료 아데나 숫자
		class'UIAPI_TEXTBOX'.static.SetTextColor("HennaInfoWnd.txtAdena", col);

		col.R=255;
		col.G=255;
		col.B=0;
		class'UIAPI_TEXTBOX'.static.SetText("HennaInfoWnd.txtAdenaString", GetSystemString(469));		// "아데나"
		class'UIAPI_TEXTBOX'.static.SetTextColor("HennaInfoWnd.txtAdenaString", col);		


		// 문양
		class'UIAPI_TEXTBOX'.static.SetText("HennaInfoWnd.txtTattooInfo", GetSystemString(639));		// "문양정보"
		class'UIAPI_TEXTURECTRL'.static.SetTexture("HennaInfoWnd.textureTattooIconName", strTattooIconName);	// 문양 Icon
		class'UIAPI_TEXTBOX'.static.SetText("HennaInfoWnd.txtTattooName", strTattooName);		// 문양이름
		class'UIAPI_TEXTBOX'.static.SetText("HennaInfoWnd.txtTattooAddName", strTattooAddName);		// 문양부가정보
	}
	else if(m_iState==HENNA_UNEQUIP)
	{
		// 문양
		class'UIAPI_TEXTBOX'.static.SetText("HennaInfoWnd.txtTattooInfoUnEquip", GetSystemString(639));		// "문양정보"
		class'UIAPI_TEXTURECTRL'.static.SetTexture("HennaInfoWnd.textureTattooIconNameUnEquip", strTattooIconName);	// 문양 Icon
		class'UIAPI_TEXTBOX'.static.SetText("HennaInfoWnd.txtTattooNameUnEquip", GetSystemString(652)$":"$strTattooName);		// 문양이름
		class'UIAPI_TEXTBOX'.static.SetText("HennaInfoWnd.txtTattooAddNameUnEquip", strTattooAddName);		// 문양부가정보

		// 염료
		class'UIAPI_TEXTBOX'.static.SetText("HennaInfoWnd.txtDyeInfoUnEquip", GetSystemString(638));			// "염료정보"
		class'UIAPI_TEXTURECTRL'.static.SetTexture("HennaInfoWnd.textureDyeIconNameUnEquip", strDyeIconName);	// 염료 Icon
		class'UIAPI_TEXTBOX'.static.SetText("HennaInfoWnd.txtDyeNameUnEquip", strDyeName);						// 염료이름

		col.R=168;
		col.G=168;
		col.B=168;
		class'UIAPI_TEXTBOX'.static.SetText("HennaInfoWnd.txtFeeUnEquip", GetSystemString(637) $ " : ");		// "수수료 : "
		class'UIAPI_TEXTBOX'.static.SetTextColor("HennaInfoWnd.txtFeeUnEquip", col);		

		strAdenaComma = MakeCostString("" $ iFee);
		col= GetNumericColor(strAdenaComma);
		class'UIAPI_TEXTBOX'.static.SetText("HennaInfoWnd.txtAdenaUnEquip", strAdenaComma);		// 수수료 아데나 숫자
		class'UIAPI_TEXTBOX'.static.SetTextColor("HennaInfoWnd.txtAdenaUnEquip", col);

		col.R=255;
		col.G=255;
		col.B=0;
		class'UIAPI_TEXTBOX'.static.SetText("HennaInfoWnd.txtAdenaStringUnEquip", GetSystemString(469));		// "아데나"
		class'UIAPI_TEXTBOX'.static.SetTextColor("HennaInfoWnd.txtAdenaStringUnEquip", col);		
	}

	


	// 수치변화
	class'UIAPI_TEXTBOX'.static.SetInt("HennaInfoWnd.txtSTRBefore", iSTRnow);		// STR 현재
	class'UIAPI_TEXTBOX'.static.SetInt("HennaInfoWnd.txtSTRAfter", iSTRchange);		// STR 변화후
	class'UIAPI_TEXTBOX'.static.SetInt("HennaInfoWnd.txtDEXBefore", iDEXnow);		// DEX 현재
	class'UIAPI_TEXTBOX'.static.SetInt("HennaInfoWnd.txtDEXAfter", iDEXchange);		// DEX 변화후
	class'UIAPI_TEXTBOX'.static.SetInt("HennaInfoWnd.txtCONBefore", iCONnow);		// CON 현재
	class'UIAPI_TEXTBOX'.static.SetInt("HennaInfoWnd.txtCONAfter", iCONchange);		// CON 변화후
	class'UIAPI_TEXTBOX'.static.SetInt("HennaInfoWnd.txtINTBefore", iINTnow);		// INT 현재
	class'UIAPI_TEXTBOX'.static.SetInt("HennaInfoWnd.txtINTAfter", iINTchange);		// INT 변화후
	class'UIAPI_TEXTBOX'.static.SetInt("HennaInfoWnd.txtWITBefore", iWITnow);		// WIT 현재
	class'UIAPI_TEXTBOX'.static.SetInt("HennaInfoWnd.txtWITAfter", iWITchange);		// WIT 변화후
	class'UIAPI_TEXTBOX'.static.SetInt("HennaInfoWnd.txtMENBefore", iMENnow);		// MEN 현재
	class'UIAPI_TEXTBOX'.static.SetInt("HennaInfoWnd.txtMENAfter", iMENchange);		// MEN 변화후

	//아데나(,)
	strAdenaComma = MakeCostString("" $ iAdena);
	col = GetNumericColor(strAdenaComma);
	class'UIAPI_TEXTBOX'.static.SetText("HennaInfoWnd.txtHaveAdena", strAdenaComma);		// 아데나 숫자
	class'UIAPI_TEXTBOX'.static.SetTooltipString("HennaInfoWnd.txtHaveAdena", ConvertNumToText(""$iAdena));

	class'UIAPI_WINDOW'.static.HideWindow("HennaListWnd");

	class'UIAPI_WINDOW'.static.ShowWindow("HennaInfoWnd");
	class'UIAPI_WINDOW'.static.SetFocus("HennaInfoWnd");
}
