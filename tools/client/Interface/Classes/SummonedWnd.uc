class SummonedWnd extends UIScript;

const NPET_SMALLBARSIZE = 125;
const NPET_BARHEIGHT = 12;

var int m_PetID;

function OnLoad()
{
	RegisterEvent( EV_UpdatePetInfo );
	RegisterEvent( EV_SummonedWndShow );
	RegisterEvent( EV_PetSummonedStatusClose );
	
	RegisterEvent( EV_ActionSummonedListStart );
	RegisterEvent( EV_ActionSummonedList );
	
	RegisterEvent( EV_LanguageChanged );
	
	//ItemWnd의 스크롤바 Hide
	HideScrollBar();
}

function OnShow()
{
	class'ActionAPI'.static.RequestSummonedActionList();
}

function HandleLanguageChanged()
{
	class'ActionAPI'.static.RequestSummonedActionList();
}

function OnEvent(int Event_ID, string param)
{
	if (Event_ID == EV_UpdatePetInfo)
	{
		HandlePetInfoUpdate();
	}
	else if (Event_ID == EV_PetSummonedStatusClose)
	{
		HandlePetSummonedStatusClose();
	}
	else if (Event_ID == EV_SummonedWndShow)
	{
		HandlePetShow();
	}
	else if (Event_ID == EV_ActionSummonedListStart)
	{
		HandleActionSummonedListStart();
	}
	else if (Event_ID == EV_ActionSummonedList)
	{
		HandleActionSummonedList(param);
	}
	else if (Event_ID == EV_LanguageChanged)
	{
		HandleLanguageChanged();
	}
}

//액션의 클릭
function OnClickItem( string strID, int index )
{
	local ItemInfo infItem;
	
	if (strID == "SummonedActionWnd" && index>-1)
	{
		if (class'UIAPI_ITEMWINDOW'.static.GetItem("SummonedWnd.SummonedWnd_Action.SummonedActionWnd", index, infItem))
			DoAction(infItem.ClassID);
	}
}

function HideScrollBar()
{
	class'UIAPI_ITEMWINDOW'.static.ShowScrollBar("SummonedWnd.SummonedWnd_Action.SummonedActionWnd", false);
}

function HandleActionSummonedListStart()
{
	ClearActionWnd();
}

//초기화
function Clear()
{
	class'UIAPI_TEXTBOX'.static.SetText("SummonedWnd.txtLvName", "");
	class'UIAPI_TEXTBOX'.static.SetText("SummonedWnd.txtHP", "0/0");
	class'UIAPI_TEXTBOX'.static.SetText("SummonedWnd.txtMP", "0/0");
	UpdateHPBar(0, 0);
	UpdateMPBar(0, 0);
}
function ClearActionWnd()
{
	class'UIAPI_ITEMWINDOW'.static.Clear("SummonedWnd.SummonedWnd_Action.SummonedActionWnd");
}

//종료처리
function HandlePetSummonedStatusClose()
{
	class'UIAPI_WINDOW'.static.HideWindow("SummonedWnd");
	PlayConsoleSound(IFST_WINDOW_CLOSE);
}

//펫Info패킷 처리
function HandlePetInfoUpdate()
{
	local string	Name;
	local int		HP;
	local int		MaxHP;
	local int		MP;
	local int		MaxMP;
	local int		Level;
	local int		PhysicalAttack;
	local int		PhysicalDefense;
	local int		HitRate;
	local int		CriticalRate;
	local int		PhysicalAttackSpeed;
	local int		MagicalAttack;
	local int		MagicDefense;
	local int		PhysicalAvoid;
	local int		MovingSpeed;
	local int		MagicCastingSpeed;
	local int		SoulShotCosume;
	local int		SpiritShotConsume;
	
	local PetInfo	info;
	
	if (GetPetInfo(info))
	{
		m_PetID = info.nID;
		Name = info.Name;
		Level = info.nLevel;
		HP = info.nCurHP;
		MaxHP = info.nMaxHP;
		MP = info.nCurMP;
		MaxMP = info.nMaxMP;
		
		//펫 상세 정보
		PhysicalAttack			= info.nPhysicalAttack;
		PhysicalDefense		= info.nPhysicalDefense;
		HitRate				= info.nHitRate;
		CriticalRate			= info.nCriticalRate;
		PhysicalAttackSpeed	= info.nPhysicalAttackSpeed;
		MagicalAttack			= info.nMagicalAttack;
		MagicDefense			= info.nMagicDefense;
		PhysicalAvoid			= info.nPhysicalAvoid;
		MovingSpeed			= info.nMovingSpeed;
		MagicCastingSpeed		= info.nMagicCastingSpeed;
		SoulShotCosume		= info.nSoulShotCosume;
		SpiritShotConsume		= info.nSpiritShotConsume;
	}
	
	class'UIAPI_TEXTBOX'.static.SetText("SummonedWnd.txtLvName", Level $ " " $ Name);
	class'UIAPI_TEXTBOX'.static.SetText("SummonedWnd.txtHP", HP $ "/" $ MaxHP);
	class'UIAPI_TEXTBOX'.static.SetText("SummonedWnd.txtMP", MP $ "/" $ MaxMP);
	
	//펫 상세 정보 탭
	class'UIAPI_TEXTBOX'.static.SetText("SummonedWnd.txtPhysicalAttack", string(PhysicalAttack));
	class'UIAPI_TEXTBOX'.static.SetText("SummonedWnd.txtPhysicalDefense", string(PhysicalDefense));
	class'UIAPI_TEXTBOX'.static.SetText("SummonedWnd.txtHitRate", string(HitRate));
	class'UIAPI_TEXTBOX'.static.SetText("SummonedWnd.txtCriticalRate", string(CriticalRate));
	class'UIAPI_TEXTBOX'.static.SetText("SummonedWnd.txtPhysicalAttackSpeed", string(PhysicalAttackSpeed));
	class'UIAPI_TEXTBOX'.static.SetText("SummonedWnd.txtMagicalAttack", string(MagicalAttack));
	class'UIAPI_TEXTBOX'.static.SetText("SummonedWnd.txtMagicDefense", string(MagicDefense));
	class'UIAPI_TEXTBOX'.static.SetText("SummonedWnd.txtPhysicalAvoid", string(PhysicalAvoid));
	class'UIAPI_TEXTBOX'.static.SetText("SummonedWnd.txtMovingSpeed", string(MovingSpeed));
	class'UIAPI_TEXTBOX'.static.SetText("SummonedWnd.txtMagicCastingSpeed", string(MagicCastingSpeed));
	class'UIAPI_TEXTBOX'.static.SetText("SummonedWnd.txtSoulShotCosume", string(SoulShotCosume));
	class'UIAPI_TEXTBOX'.static.SetText("SummonedWnd.txtSpiritShotConsume", string(SpiritShotConsume));

	UpdateHPBar(HP, MaxHP);
	UpdateMPBar(MP, MaxMP);
}

//펫창을 표시
function HandlePetShow()
{
	Clear();
	HandlePetInfoUpdate();
	PlayConsoleSound(IFST_WINDOW_OPEN);
	class'UIAPI_WINDOW'.static.ShowWindow("SummonedWnd");
	class'UIAPI_WINDOW'.static.SetFocus("SummonedWnd");
}

//HP바 갱신
function UpdateHPBar(int Value, int MaxValue)
{
	local int Size;
	Size = 0;
	if (MaxValue>0)
	{
		Size = NPET_SMALLBARSIZE;
		if (Value<MaxValue)
		{
			Size = NPET_SMALLBARSIZE* Value / MaxValue;
		}
	}
	class'UIAPI_WINDOW'.static.SetWindowSize("SummonedWnd.texHP", Size, NPET_BARHEIGHT);
}

//MP바 갱신
function UpdateMPBar(int Value, int MaxValue)
{
	local int Size;
	Size = 0;
	if (MaxValue>0)
	{
		Size = NPET_SMALLBARSIZE;
		if (Value<MaxValue)
		{
			Size = NPET_SMALLBARSIZE* Value / MaxValue;
		}
	}
	class'UIAPI_WINDOW'.static.SetWindowSize("SummonedWnd.texMP", Size, NPET_BARHEIGHT);
}

function HandleActionSummonedList(string param)
{
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
	if (Type==ACTION_SUMMON)
	{
		class'UIAPI_ITEMWINDOW'.static.AddItem("SummonedWnd.SummonedWnd_Action.SummonedActionWnd", infItem);
	}
}
