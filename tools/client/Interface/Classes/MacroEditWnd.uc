class MacroEditWnd extends UICommonAPI;

const MACRO_MAX_COUNT = 24;
const MACROCOMMAND_MAX_COUNT = 12;
const MACROICON_MAX_COUNT = 7;
const MACRO_ICONANME = "L2UI.MacroWnd.Macro_Icon";

var bool	m_bShow;
var int		m_CurIconNum;
var int		m_CurMacroID;

function OnLoad()
{
	RegisterEvent( EV_DialogOK );
	
	RegisterEvent( EV_MacroShowEditWnd );
	RegisterEvent( EV_MacroDeleted );
	
	m_bShow = false;
	m_CurIconNum = 1;
	m_CurMacroID = 0;
	
	InitTabOrder();
}

function OnShow()
{
	m_bShow = true;
}

function OnHide()
{
	m_bShow = false;
}

function OnClickButton( string strID )
{	
	switch( strID )
	{
	case "btnInfo":
		OnClickInfo();
		break;
	case "btnHelp":
		OnClickHelp();
		break;
	case "btnCancel":
		OnClickCancel();
		break;
	case "btnLeft":
		OnClickLeft();
		break;
	case "btnRight":
		OnClickRight();
		break;
	case "btnSave":
		OnClickSave();
		break;
	}
}

function OnEvent(int Event_ID, String param)
{
	if (Event_ID == EV_MacroShowEditWnd)
	{
		HandleMacroShowEditWnd(param);
	}
	else if (Event_ID == EV_MacroDeleted)
	{
		HandleMacroDeleted(param);
	}
	else if (Event_ID == EV_DialogOK)
	{
		if (DialogIsMine())
		{
		}
	}
}

function InitTabOrder()
{
	local int idx;
	
	class'UIAPI_WINDOW'.static.SetTabOrder("MacroEditWnd", "MacroEditWnd.txtName", "MacroEditWnd.txtShortName");
	class'UIAPI_WINDOW'.static.SetTabOrder("MacroEditWnd.txtName", "MacroEditWnd.txtShortName", "MacroEditWnd");
	class'UIAPI_WINDOW'.static.SetTabOrder("MacroEditWnd.txtShortName", "MacroEditWnd.txtEdit0", "MacroEditWnd.txtName");
	for (idx=0; idx<MACROCOMMAND_MAX_COUNT; idx++)
	{
		if (idx==0)
			class'UIAPI_WINDOW'.static.SetTabOrder("MacroEditWnd.txtEdit0", "MacroEditWnd.txtEdit1", "MacroEditWnd.txtShortName");
		else if (idx==MACROCOMMAND_MAX_COUNT-1)
			class'UIAPI_WINDOW'.static.SetTabOrder("MacroEditWnd.txtEdit11", "MacroEditWnd.txtName", "MacroEditWnd.txtEdit10");
		else
			class'UIAPI_WINDOW'.static.SetTabOrder("MacroEditWnd.txtEdit" $ idx, "MacroEditWnd.txtEdit" $ idx+1, "MacroEditWnd.txtEdit" $ idx-1);
	}
}

//////////////////////////////////////////////////////////////////////////////////
//추가 정보
function OnClickInfo()
{
	if (class'UIAPI_WINDOW'.static.IsShowWindow("MacroInfoWnd"))
	{
		PlayConsoleSound(IFST_WINDOW_CLOSE);
		class'UIAPI_WINDOW'.static.HideWindow("MacroInfoWnd");
	}
	else
	{
		PlayConsoleSound(IFST_WINDOW_OPEN);	
		class'UIAPI_WINDOW'.static.ShowWindow("MacroInfoWnd");
		class'UIAPI_WINDOW'.static.SetFocus("MacroInfoWnd");
	}
}

//////////////////////////////////////////////////////////////////////////////////
//도움말 버튼
function OnClickHelp()
{
	local string strParam;
	ParamAdd(strParam, "FilePath", "..\\L2text\\help_macro.htm");
	ExecuteEvent(EV_ShowHelp, strParam);
}

//////////////////////////////////////////////////////////////////////////////////
//취소 버튼
function OnClickCancel()
{
	class'UIAPI_WINDOW'.static.HideWindow("MacroEditWnd");
}

//////////////////////////////////////////////////////////////////////////////////
//저장 버튼
function OnClickSave()
{
	SaveMacro();
}

//////////////////////////////////////////////////////////////////////////////////
// Drag & Drop
function OnDropItem( String strID, ItemInfo infItem, int x, int y )
{
	if (Len(strID)<1)
		return;
		
	if (Left(strID, 7) != "txtEdit")
		return;
		
	class'UIAPI_EDITBOX'.static.SetString( "MacroEditWnd." $ strID, infItem.MacroCommand);
	class'UIAPI_EDITBOX'.static.SetHighLight( "MacroEditWnd." $ strID, FALSE);
}

function OnDragItemStart( String strID, ItemInfo infItem )
{
	if (Len(strID)<1)
		return;
		
	if (Left(strID, 7) != "txtEdit")
		return;
		
	class'UIAPI_EDITBOX'.static.SetHighLight( "MacroEditWnd." $ strID, TRUE);
}

function OnDragItemEnd( String strID )
{
	if (Len(strID)<1)
		return;
		
	if (Left(strID, 7) != "txtEdit")
		return;
		
	class'UIAPI_EDITBOX'.static.SetHighLight( "MacroEditWnd." $ strID, FALSE);
}

//////////////////////////////////////////////////////////////////////////////////
// Macro Icon
function OnChangeEditBox( String strID )
{
	switch( strID )
	{
	case "txtShortName":
		UpdateIconName();
		break;
	}
}

function OnClickLeft()
{
	m_CurIconNum--;
	if (m_CurIconNum<1)
		m_CurIconNum = MACROICON_MAX_COUNT;
	UpdateIcon();
}

function OnClickRight()
{
	m_CurIconNum++;
	if (m_CurIconNum>MACROICON_MAX_COUNT)
		m_CurIconNum = 1;
	UpdateIcon();
}

function UpdateIcon()
{
	class'UIAPI_TEXTURECTRL'.static.SetTexture( "MacroEditWnd.texMacro", MACRO_ICONANME $ m_CurIconNum);
}

function UpdateIconName()
{
	local string strShortName;
	
	strShortName = class'UIAPI_EDITBOX'.static.GetString( "MacroEditWnd.txtShortName");
	class'UIAPI_TEXTBOX'.static.SetText( "MacroEditWnd.txtMacroName", strShortName);
}

//////////////////////////////////////////////////////////////////////////////////
// Clear
function Clear()
{
	local int idx;
	local WindowHandle	m_MacroEditWnd;
	
	m_CurIconNum = 1;
	m_MacroEditWnd= GetHandle("MacroEditWnd.areaEdit");
	
	class'UIAPI_EDITBOX'.static.SetString( "MacroEditWnd.txtName", "");
	class'UIAPI_EDITBOX'.static.SetString( "MacroEditWnd.txtShortName", "");
	for (idx=0; idx<MACROCOMMAND_MAX_COUNT; idx++)
	{
		class'UIAPI_EDITBOX'.static.SetString( "MacroEditWnd.txtEdit" $ idx, "");
	}
	UpdateIcon();
	UpdateIconName();
	m_MacroEditWnd.SetScrollPosition(0); // 스크롤바 초기화
}

//현재 보여지고 있는 매크로가 삭제되었다면 Hide시킨다.
function HandleMacroDeleted(string param)
{
	local int MacroID;
	ParseInt(param, "MacroID", MacroID);
	if (m_bShow && m_CurMacroID==MacroID)
	{
		PlayConsoleSound(IFST_WINDOW_CLOSE);
		class'UIAPI_WINDOW'.static.HideWindow("MacroEditWnd");
	}
}

function HandleMacroShowEditWnd(string param)
{
	local int MacroCount;
	local color TextColor;
	
	Clear();
	m_CurMacroID = 0;
	
	//편집모드
	if (ParseInt(param, "MacroID", m_CurMacroID))
	{
		SetMacroID(m_CurMacroID);
		if (!m_bShow)
		{
			PlayConsoleSound(IFST_WINDOW_OPEN);
			class'UIAPI_WINDOW'.static.ShowWindow("MacroEditWnd");
		}
		class'UIAPI_WINDOW'.static.SetFocus("MacroEditWnd.txtName");
	}
	//추가모드
	else
	{
		if (m_bShow)
		{
			PlayConsoleSound(IFST_WINDOW_CLOSE);
			class'UIAPI_WINDOW'.static.HideWindow("MacroEditWnd");
		}
		else
		{
			//Check Macro Count
			MacroCount = class'UIDATA_MACRO'.static.GetMacroCount();
			if (MacroCount>=MACRO_MAX_COUNT)
			{
				TextColor.R = 176;
				TextColor.G = 155;
				TextColor.B = 121;
				TextColor.A = 255;
				DialogShow(DIALOG_Notice, GetSystemMessage(797));
				DialogSetID(0);	
				//AddSystemMessage(GetSystemMessage(797), TextColor);
				return;
			}
			
			PlayConsoleSound(IFST_WINDOW_OPEN);
			class'UIAPI_WINDOW'.static.ShowWindow("MacroEditWnd");
			class'UIAPI_WINDOW'.static.SetFocus("MacroEditWnd.txtName");
		}
	}
}

//////////////////////////////////////////////////////////////////////////////////
// 해당 MacroID로 화면 표시
function SetMacroID(int MacroID)
{
	local int idx;
	local MacroInfo info;
	local MacroInfoWnd Script;
	
	if (MacroID<1)
		return;
		
	if (class'UIDATA_MACRO'.static.GetMacroInfo(MacroID, info))
	{
		//이름
		class'UIAPI_EDITBOX'.static.SetString( "MacroEditWnd.txtName", info.Name);
		//단축이름
		class'UIAPI_EDITBOX'.static.SetString( "MacroEditWnd.txtShortName", info.IconName);
		//아이콘
		m_CurIconNum = int(Right(info.IconTextureName, 1));
		if (m_CurIconNum<1)
			m_CurIconNum = 1;
		UpdateIcon();
		//설명
		Script = MacroInfoWnd(GetScript("MacroInfoWnd"));
		Script.SetInfoText(info.Description);
		//커맨드12개
		for (idx=0; idx<MACROCOMMAND_MAX_COUNT; idx++)
		{
			class'UIAPI_EDITBOX'.static.SetString( "MacroEditWnd.txtEdit" $ idx, info.CommandList[idx]);
		}
	}
}

//////////////////////////////////////////////////////////////////////////////////
// 매크로 저장
function SaveMacro()
{
	local int idx;
	local MacroInfoWnd Script;
	
	local string		Name;
	local string		IconName;
	local string		Description;
	local string		Command;
	local array<string> CommandList;
	
	
	Script = MacroInfoWnd(GetScript("MacroInfoWnd"));
	Name = class'UIAPI_EDITBOX'.static.GetString( "MacroEditWnd.txtName");
	IconName = class'UIAPI_EDITBOX'.static.GetString( "MacroEditWnd.txtShortName");
	Description = Script.GetInfoText();
	for (idx=0; idx<MACROCOMMAND_MAX_COUNT; idx++)
	{
		Command = class'UIAPI_EDITBOX'.static.GetString( "MacroEditWnd.txtEdit" $ idx);
		CommandList.Insert(CommandList.Length, 1);
		CommandList[CommandList.Length-1] = Command;
	}
	
	if (class'MacroAPI'.static.RequestMakeMacro(m_CurMacroID, Name, IconName, m_CurIconNum-1, Description, CommandList))
	{
		class'UIAPI_WINDOW'.static.HideWindow("MacroEditWnd");		
	}
}
