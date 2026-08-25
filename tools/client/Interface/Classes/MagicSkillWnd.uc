class MagicSkillWnd extends UICommonAPI;

const Skill_MAX_COUNT = 24;

var bool m_bShow;
var String m_WindowName;

function OnLoad()
{
	RegisterEvent(EV_SkillListStart);
	RegisterEvent(EV_SkillList);
	RegisterEvent(EV_LanguageChanged);
	
	m_bShow = false;
}

function OnShow()
{
	RequestSkillList();
	m_bShow = true;
}

function OnHide()
{
	m_bShow = false;
}

function OnEvent(int Event_ID, String param)
{
	if (Event_ID == EV_SkillListStart)
	{
		HandleSkillListStart();
	}
	else if (Event_ID == EV_SkillList)
	{
		HandleSkillList(param);
	}
	else if (Event_ID == EV_LanguageChanged)
	{
		HandleLanguageChanged();
	}
}

//스킬의 클릭
function OnClickItem( string strID, int index )
{
	local ItemInfo 	infItem;
	
	if (strID == "SkillItem" && index>-1)
	{
		if (class'UIAPI_ITEMWINDOW'.static.GetItem(m_WindowName $ ".ASkill.SkillItem", index, infItem))
			UseSkill(infItem.ClassID);
	}
}

function HandleLanguageChanged()
{
	RequestSkillList();
}

function HandleSkillListStart()
{
	Clear();
}

function Clear()
{
	class'UIAPI_ITEMWINDOW'.static.Clear(m_WindowName $ ".ASkill.SkillItem");
	class'UIAPI_ITEMWINDOW'.static.Clear(m_WindowName $ ".PSkill.PItemWnd");
}

function HandleSkillList(string param)
{
	local string WndName;
	
	local int Tmp;
	local ESkillCategory Type;
	local int SkillID;
	local int SkillLevel;
	local int Lock;
	local string strIconName;
	local string strSkillName;
	local string strDescription;
	local string strEnchantName;
	local string strCommand;
	
	local ItemInfo	infItem;
	
	ParseInt(param, "Type", Tmp);
	ParseInt(param, "ClassID", SkillID);
	ParseInt(param, "Level", SkillLevel);
	ParseInt(param, "Lock", Lock);
	ParseString(param, "Name", strSkillName);
	ParseString(param, "IconName", strIconName);
	ParseString(param, "Description", strDescription);
	ParseString(param, "EnchantName", strEnchantName);
	ParseString(param, "Command", strCommand);

	infItem.ClassID = SkillID;
	infItem.Level = SkillLevel;
	infItem.Name = strSkillName;
	infItem.AdditionalName = strEnchantName;
	infItem.IconName = strIconName;
	infItem.Description = strDescription;
	infItem.ItemSubType = int(EShortCutItemType.SCIT_SKILL);
	infItem.MacroCommand = strCommand;
	if (Lock>0)
	{
		infItem.bIsLock = true;
	}
	else
	{
		infItem.bIsLock = false;
	}
	
	//ItemWnd에 추가
	Type = ESkillCategory(Tmp);
	if (Type==SKILL_Passive)
	{
		WndName = "PSkill.PItemWnd";
	}
	else
	{
		WndName = "ASkill.SkillItem";
	}
	class'UIAPI_ITEMWINDOW'.static.AddItem(m_WindowName $ "." $ WndName, infItem);
	
	
}

defaultproperties
{
     m_WindowName="MagicSkillWnd"
}
