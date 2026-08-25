class ActionWnd extends UICommonAPI;

var bool m_bShow;

function OnLoad()
{
	RegisterEvent(EV_ActionListStart);
	RegisterEvent(EV_ActionList);
	
	RegisterEvent(EV_LanguageChanged);
	
	m_bShow = false;
	
	//ItemWnd의 스크롤바 Hide
	HideScrollBar();
}

function OnShow()
{
	class'ActionAPI'.static.RequestActionList();
	m_bShow = true;
}

function OnHide()
{
	m_bShow = false;
}

function OnEvent(int Event_ID, String param)
{
	if (Event_ID == EV_ActionListStart)
	{
		HandleActionListStart();
	}
	else if (Event_ID == EV_ActionList)
	{
		HandleActionList(param);
	}
	else if (Event_ID == EV_LanguageChanged)
	{
		HandleLanguageChanged();
	}
}

//액션의 클릭
function OnClickItem( string strID, int index )
{
	local ItemInfo 	infItem;
	
	if (strID == "ActionBasicItem" && index>-1)
	{
		if (!class'UIAPI_ITEMWINDOW'.static.GetItem("ActionWnd.ActionBasicItem", index, infItem))
			return;
			
	}
	else if (strID == "ActionPartyItem" && index>-1)
	{
		if (!class'UIAPI_ITEMWINDOW'.static.GetItem("ActionWnd.ActionPartyItem", index, infItem))
			return;
	}
	else if (strID == "ActionSocialItem" && index>-1)
	{
		if (!class'UIAPI_ITEMWINDOW'.static.GetItem("ActionWnd.ActionSocialItem", index, infItem))
			return;
	}
	DoAction(infItem.ClassID);
}

function HideScrollBar()
{
	class'UIAPI_ITEMWINDOW'.static.ShowScrollBar("ActionWnd.ActionBasicItem", false);
	class'UIAPI_ITEMWINDOW'.static.ShowScrollBar("ActionWnd.ActionPartyItem", false);
	class'UIAPI_ITEMWINDOW'.static.ShowScrollBar("ActionWnd.ActionSocialItem", false);
}

function HandleLanguageChanged()
{
	class'ActionAPI'.static.RequestActionList();
}

function HandleActionListStart()
{
	Clear();
}

function Clear()
{
	class'UIAPI_ITEMWINDOW'.static.Clear("ActionWnd.ActionBasicItem");
	class'UIAPI_ITEMWINDOW'.static.Clear("ActionWnd.ActionPartyItem");
	class'UIAPI_ITEMWINDOW'.static.Clear("ActionWnd.ActionSocialItem");
}

function HandleActionList(string param)
{
	local string WndName;
	
	local int Tmp;
	local EActionCategory Type;
	local int ActionID;
	local string strActionName;
	local string strIconName;
	local string strDescription;
	local string strCommand;
	
	local ItemInfo	infItem;
	
	ParseInt(param, "Type", Tmp);
	ParseInt(param, "ActionID", ActionID);
	ParseString(param, "Name", strActionName);
	ParseString(param, "IconName", strIconName);
	ParseString(param, "Description", strDescription);
	ParseString(param, "Command", strCommand);

	infItem.ClassID = ActionID;
	infItem.Name = strActionName;
	infItem.IconName = strIconName;
	infItem.Description = strDescription;
	infItem.ItemSubType = int(EShortCutItemType.SCIT_ACTION);
	infItem.MacroCommand = strCommand;
	
	//ItemWnd에 추가
	Type = EActionCategory(Tmp);
	if (Type==ACTION_BASIC)
	{
		WndName = "ActionBasicItem";
	}
	else if (Type==ACTION_PARTY)
	{
		WndName = "ActionPartyItem";
	}
	else if (Type==ACTION_SOCIAL)
	{
		WndName = "ActionSocialItem";
	}
	else
	{
		return;
	}
	class'UIAPI_ITEMWINDOW'.static.AddItem("ActionWnd." $ WndName, infItem);
}
