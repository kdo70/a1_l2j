class PetWnd extends UICommonAPI;

const PET_EQUIPPEDTEXTURE_NAME = "l2ui_ch3.PetWnd.petitem_click";

const DIALOG_PETNAME		= 1111;				// 펫이름적기
const DIALOG_GIVEITEMTOPET	= 2222;				// 인벤에서 펫인벤으로 아이템 옮기기

const NPET_SMALLBARSIZE = 85;
const NPET_LARGEBARSIZE = 206;
const NPET_BARHEIGHT = 12;

var int			m_PetID;
var bool		m_bShowNameBtn;
var string		m_LastInputPetName;

function OnLoad()
{
	RegisterEvent( EV_DialogOK );
	RegisterEvent( EV_UpdatePetInfo );
	RegisterEvent( EV_PetWndShow );
	RegisterEvent( EV_PetWndShowNameBtn );
	RegisterEvent( EV_PetWndRegPetNameFailed );
	RegisterEvent( EV_PetSummonedStatusClose );
	
	RegisterEvent( EV_ActionPetListStart );
	RegisterEvent( EV_ActionPetList );
	
	RegisterEvent( EV_PetInventoryItemStart );
	RegisterEvent( EV_PetInventoryItemList );
	RegisterEvent( EV_PetInventoryItemUpdate );
	
	RegisterEvent( EV_LanguageChanged );
	
	m_bShowNameBtn = true;
	
	//ItemWnd의 스크롤바 Hide
	HideScrollBar();
}

function OnShow()
{
	class'PetAPI'.static.RequestPetInventoryItemList();
	class'ActionAPI'.static.RequestPetActionList();
}

function OnDropItem( String strTarget, ItemInfo info, int x, int y )
{
	if( strTarget == "PetInvenWnd" && info.DragSrcName == "InventoryItem" )
	{
		if( IsStackableItem(info.ConsumeType) && info.ItemNum > 1 )			// Multiple item?
		{
			if( info.AllItemCount > 0 )				// 전부 이동?
			{
				class'PetAPI'.static.RequestGiveItemToPet(info.ServerID, info.AllItemCount);
			}
			else
			{
				DialogSetID(DIALOG_GIVEITEMTOPET);
				DialogSetReservedInt(info.ServerID);
				DialogSetParamInt(info.ItemNum);
				DialogShow( DIALOG_NumberPad, MakeFullSystemMsg( GetSystemMessage(72), info.Name ) );
			}
		}
		else																// Single item?
		{
			class'PetAPI'.static.RequestGiveItemToPet(info.ServerID, 1);
		}
	}
}

function HandleLanguageChanged()
{
	class'PetAPI'.static.RequestPetInventoryItemList();
	class'ActionAPI'.static.RequestPetActionList();
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
	else if (Event_ID == EV_PetWndShow)
	{
		HandlePetShow();
	}
	else if (Event_ID == EV_PetWndShowNameBtn)
	{
		HandlePetShowNameBtn(param);
	}
	else if (Event_ID == EV_PetWndRegPetNameFailed)
	{
		HandleRegPetName(param);
	}
	else if (Event_ID == EV_DialogOK)
	{
		HandleDialogOK();
	}
	else if (Event_ID == EV_ActionPetListStart)
	{
		HandleActionPetListStart();
	}
	else if (Event_ID == EV_ActionPetList)
	{
		HandleActionPetList(param);
	}
	else if (Event_ID == EV_PetInventoryItemStart)
	{
		HandlePetInventoryItemStart();
	}
	else if (Event_ID == EV_PetInventoryItemList)
	{
		HandlePetInventoryItemList(param);
	}
	else if (Event_ID == EV_PetInventoryItemUpdate)
	{
		HandlePetInventoryItemUpdate(param);
	}
	else if (Event_ID == EV_LanguageChanged)
	{
		HandleLanguageChanged();
	}
}

function HandleDialogOK()
{
	local int ID;
	local int ServerID;
	local int Number;
	
	if( DialogIsMine() )
	{
		ID = DialogGetID();
		ServerID = DialogGetReservedInt();
		Number = int(DialogGetString());
		
		if( id == DIALOG_PETNAME )
		{
			m_LastInputPetName = DialogGetString();
			RequestChangePetName(m_LastInputPetName);	//등록 결과가 EV_PetWndRegNameXXX로 날라온다.
		}
		else if( id == DIALOG_GIVEITEMTOPET )
		{
			class'PetAPI'.static.RequestGiveItemToPet(ServerID, Number);
		}
	}
}

function OnClickButton( string strID )
{
	switch( strID )
	{
	case "btnName":
		OnNameClick();
		break;
	}
}

function OnNameClick()
{
	DialogSetID(DIALOG_PETNAME);
	DialogShow(DIALOG_OKCancelInput, GetSystemMessage(535));
}

//액션의 클릭
function OnClickItem( string strID, int index )
{
	local ItemInfo infItem;
	
	if (strID == "PetActionWnd" && index>-1)
	{
		if (class'UIAPI_ITEMWINDOW'.static.GetItem("PetWnd.PetWnd_Action.PetActionWnd", index, infItem))
			DoAction(infItem.ClassID);
	}
}

//인벤 아이템의 사용
function OnDBClickItem( String strID, int index )
{
	local ItemInfo infItem;
	
	if (strID == "PetInvenWnd" && index>-1)
	{
		if (class'UIAPI_ITEMWINDOW'.static.GetItem("PetWnd.PetWnd_Inventory.PetInvenWnd", index, infItem))
			class'PetAPI'.static.RequestPetUseItem(infItem.ServerID);
	}
}
function OnRClickItem( String strID, int index )
{
	local ItemInfo infItem;
	
	if (strID == "PetInvenWnd" && index>-1)
	{
		if (class'UIAPI_ITEMWINDOW'.static.GetItem("PetWnd.PetWnd_Inventory.PetInvenWnd", index, infItem))
			class'PetAPI'.static.RequestPetUseItem(infItem.ServerID);
	}
}

function HideScrollBar()
{
	class'UIAPI_ITEMWINDOW'.static.ShowScrollBar("PetWnd.PetWnd_Action.PetActionWnd", false);
}

//초기화
function Clear()
{
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtLvName", "");
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtHP", "0/0");
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtMP", "0/0");
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtSP", "0");
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtExp", "0%");
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtFatigue", "0%");
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtWeight", "0%");
	UpdateHPBar(0, 0);
	UpdateMPBar(0, 0);
	UpdateFatigueBar(0, 0);
	UpdateEXPBar(0, 0);
	UpdateWeightBar(0, 0);
}
function ClearActionWnd()
{
	class'UIAPI_ITEMWINDOW'.static.Clear("PetWnd.PetWnd_Action.PetActionWnd");
}
function ClearInvenWnd()
{
	class'UIAPI_ITEMWINDOW'.static.Clear("PetWnd.PetWnd_Inventory.PetInvenWnd");
}

//펫이름 등록 결과 처리
function HandleRegPetName(string param)
{
	local int MsgNo;
	local color MsgColor;
	
	ParseInt(param, "ErrMsgNo", MsgNo);
		
	MsgColor.R = 176;
	MsgColor.G = 155;
	MsgColor.B = 121;
	MsgColor.A = 255;
	AddSystemMessage(GetSystemMessage(MsgNo), MsgColor);
	DialogShow(DIALOG_OKCancelInput, GetSystemMessage(535));
	
	//펫이름이 제한글자수를 초과하였을 때는, 전에 입력한 이름을 다시 출력한다.
	if (MsgNo==80)
	{
		DialogSetString(m_LastInputPetName);
	}
}

//펫이름 버튼 처리
function HandlePetShowNameBtn(string param)
{
	local int ShowFlag;
	ParseInt(param, "Show", ShowFlag);
	
	if (ShowFlag==1)
	{
		SetVisibleNameBtn(true);
	}
	else
	{
		SetVisibleNameBtn(false);
	}
}

function SetVisibleNameBtn(bool bShow)
{
	if (bShow)
	{
		class'UIAPI_WINDOW'.static.ShowWindow("PetWnd.btnName");
	}
	else
	{
		class'UIAPI_WINDOW'.static.HideWindow("PetWnd.btnName");
	}
	m_bShowNameBtn = bShow;
}

//종료처리
function HandlePetSummonedStatusClose()
{
	class'UIAPI_WINDOW'.static.HideWindow("PetWnd");
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
	local int		Fatigue;
	local int		MaxFatigue;
	local int		CarryWeight;
	local int		CarringWeight;
	local int		SP;
	local int		Level;
	local float		fExpRate;
	local float		fTmp;
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
		SP = info.nSP;
		Level = info.nLevel;
		HP = info.nCurHP;
		MaxHP = info.nMaxHP;
		MP = info.nCurMP;
		MaxMP = info.nMaxMP;
		CarryWeight = info.nCarryWeight;
		CarringWeight = info.nCarringWeight;	
		Fatigue = info.nFatigue;
		MaxFatigue = info.nMaxFatigue;
		fExpRate = class'UIDATA_PET'.static.GetPetEXPRate();
		
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
	
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtLvName", Level $ " " $ Name);
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtHP", HP $ "/" $ MaxHP);
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtMP", MP $ "/" $ MaxMP);
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtSP", string(SP));
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtExp", fExpRate $ "%");
	
	//펫 상세 정보 탭
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtPhysicalAttack", string(PhysicalAttack));
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtPhysicalDefense", string(PhysicalDefense));
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtHitRate", string(HitRate));
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtCriticalRate", string(CriticalRate));
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtPhysicalAttackSpeed", string(PhysicalAttackSpeed));
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtMagicalAttack", string(MagicalAttack));
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtMagicDefense", string(MagicDefense));
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtPhysicalAvoid", string(PhysicalAvoid));
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtMovingSpeed", string(MovingSpeed));
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtMagicCastingSpeed", string(MagicCastingSpeed));
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtSoulShotCosume", string(SoulShotCosume));
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtSpiritShotConsume", string(SpiritShotConsume));
	
	fTmp = 100.0f * float(Fatigue) / float(MaxFatigue);
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtFatigue", fTmp $ "%");
	
	fTmp = 100.0f * float(CarringWeight) / float(CarryWeight);
	class'UIAPI_TEXTBOX'.static.SetText("PetWnd.txtWeight", fTmp $ "%");

	UpdateHPBar(HP, MaxHP);
	UpdateMPBar(MP, MaxMP);
	UpdateEXPBar(int(fExpRate), 100);
	UpdateFatigueBar(Fatigue, MaxFatigue);
	UpdateWeightBar(CarringWeight, CarryWeight);
}

//펫창을 표시
function HandlePetShow()
{
	Clear();
	HandlePetInfoUpdate();
	PlayConsoleSound(IFST_WINDOW_OPEN);
	class'UIAPI_WINDOW'.static.ShowWindow("PetWnd");
	class'UIAPI_WINDOW'.static.SetFocus("PetWnd");
	
	//이름버튼
	SetVisibleNameBtn(m_bShowNameBtn);
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
	class'UIAPI_WINDOW'.static.SetWindowSize("PetWnd.texHP", Size, NPET_BARHEIGHT);
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
	class'UIAPI_WINDOW'.static.SetWindowSize("PetWnd.texMP", Size, NPET_BARHEIGHT);
}

//EXP바 갱신
function UpdateEXPBar(int Value, int MaxValue)
{
	local int Size;
	Size = 0;
	if (MaxValue>0)
	{
		Size = NPET_LARGEBARSIZE;
		if (Value<MaxValue)
		{
			Size = NPET_LARGEBARSIZE* Value / MaxValue;
		}
	}
	class'UIAPI_WINDOW'.static.SetWindowSize("PetWnd.texEXP", Size, NPET_BARHEIGHT);
}

//Fatigue바 갱신
function UpdateFatigueBar(int Value, int MaxValue)
{
	local int Size;
	Size = 0;
	if (MaxValue>0)
	{
		Size = NPET_LARGEBARSIZE;
		if (Value<MaxValue)
		{
			Size = NPET_LARGEBARSIZE* Value / MaxValue;
		}
	}
	class'UIAPI_WINDOW'.static.SetWindowSize("PetWnd.texFatigue", Size, NPET_BARHEIGHT);
}

//Weight바 갱신
function UpdateWeightBar(int Value, int MaxValue)
{
	local int Size;
	local float fTmp;
	local string strName;
	
	Size = 0;
	if (MaxValue>0)
	{
		fTmp = 100.0f * float(Value) / float(MaxValue);
		
		if ( fTmp <= 50.0f )
		{
			strName = "L2UI_CH3.PlayerStatusWnd.ps_weightbar1";
		}
		else if ( fTmp > 50.0f && fTmp <= 66.66f)
		{
			strName = "L2UI_CH3.PlayerStatusWnd.ps_weightbar2";
		}
		else if ( fTmp > 66.66f && fTmp <= 80.0f)
		{
			strName = "L2UI_CH3.PlayerStatusWnd.ps_weightbar3";
		}
		else if ( fTmp > 80.0f )
		{
			strName = "L2UI_CH3.PlayerStatusWnd.ps_weightbar4";
		}
		Size = NPET_SMALLBARSIZE;
		if (Value<MaxValue)
		{
			Size = NPET_SMALLBARSIZE* Value / MaxValue;
		}
	}
	class'UIAPI_TEXTURECTRL'.static.SetTexture("PetWnd.texWeight", strName);
	class'UIAPI_WINDOW'.static.SetWindowSize("PetWnd.texWeight", Size, NPET_BARHEIGHT);
}

///////////////////////////////////////////////////////////////////////////////////////
// 액션 아이템 처리
///////////////////////////////////////////////////////////////////////////////////////
function HandleActionPetListStart()
{
	ClearActionWnd();
}

function HandleActionPetList(string param)
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
	if (Type==ACTION_PET)
	{
		class'UIAPI_ITEMWINDOW'.static.AddItem("PetWnd.PetWnd_Action.PetActionWnd", infItem);
	}
}

///////////////////////////////////////////////////////////////////////////////////////
// 인벤 아이템 처리
///////////////////////////////////////////////////////////////////////////////////////
function HandlePetInventoryItemStart()
{
	ClearInvenWnd();
}

function HandlePetInventoryItemList(string param)
{
	local ItemInfo	infItem;
	
	ParamToItemInfo(param, infItem);
	
	if (infItem.bEquipped)
		infItem.ForeTexture = PET_EQUIPPEDTEXTURE_NAME;
	
	class'UIAPI_ITEMWINDOW'.static.AddItem("PetWnd.PetWnd_Inventory.PetInvenWnd", infItem);
}

function HandlePetInventoryItemUpdate(string param)
{
	local ItemInfo	infItem;
	local int		Tmp;
	local int		Index;
	local EInventoryUpdateType WorkType;
	
	ParamToItemInfo(param, infItem);
	ParseInt(param, "WorkType", Tmp);
	WorkType = EInventoryUpdateType(Tmp);
	
	//Check ClassID
	if (infItem.ClassID<1)
		return;
		
	if (infItem.bEquipped)
		infItem.ForeTexture = PET_EQUIPPEDTEXTURE_NAME;
		
	switch( WorkType )
	{
	case IVUT_ADD:
		class'UIAPI_ITEMWINDOW'.static.AddItem("PetWnd.PetWnd_Inventory.PetInvenWnd", infItem);
		break;
	case IVUT_UPDATE:
		//Find Item
		Index = class'UIAPI_ITEMWINDOW'.static.FindItemWithClassID("PetWnd.PetWnd_Inventory.PetInvenWnd", infItem.ClassID);
		if (Index<0)
			return;
		class'UIAPI_ITEMWINDOW'.static.SetItem("PetWnd.PetWnd_Inventory.PetInvenWnd", Index, infItem);
		break;
	case IVUT_DELETE:
		//Find Item
		Index = class'UIAPI_ITEMWINDOW'.static.FindItemWithClassID("PetWnd.PetWnd_Inventory.PetInvenWnd", infItem.ClassID);
		if (Index<0)
			return;
		class'UIAPI_ITEMWINDOW'.static.DeleteItem("PetWnd.PetWnd_Inventory.PetInvenWnd", Index);
		break;
	}
}
