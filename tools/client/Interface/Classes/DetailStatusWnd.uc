class DetailStatusWnd extends UIScript;

const NSTATUS_SMALLBARSIZE = 85;
const NSTATUS_BARHEIGHT = 12;

var String m_WindowName;
var int	m_UserID;
var bool	m_bReceivedUserInfo;
var bool	m_bShow;

var HennaInfo	m_HennaInfo;

function OnLoad()
{
	//Level과 Exp는 UserInfo패킷으로 처리한다.
	RegisterEvent( EV_UpdateUserInfo );
	RegisterEvent( EV_UpdateHennaInfo );
	
	RegisterEvent( EV_UpdateHP );
	RegisterEvent( EV_UpdateMaxHP );
	RegisterEvent( EV_UpdateMP );
	RegisterEvent( EV_UpdateMaxMP );
	RegisterEvent( EV_UpdateCP );
	RegisterEvent( EV_UpdateMaxCP );
	
	m_bShow = false;
}

function OnEnterState( name a_PreStateName )
{
	m_bReceivedUserInfo = false;
	HandleUpdateUserInfo();
}

function OnShow()
{
	HandleUpdateUserInfo();
	m_bShow = true;
}

function OnHide()
{
	m_bShow = false;
}

function OnEvent(int Event_ID, string param)
{
	if (Event_ID == EV_UpdateUserInfo)
	{
		HandleUpdateUserInfo();
	}
	else if (Event_ID == EV_UpdateHennaInfo)
	{
		HandleUpdateHennaInfo(param);
	}
	else if (Event_ID == EV_UpdateMaxHP)
	{
		HandleUpdateStatusPacket(param);
	}
	else if (Event_ID == EV_UpdateMP)
	{
		HandleUpdateStatusPacket(param);
	}
	else if (Event_ID == EV_UpdateMaxMP)
	{
		HandleUpdateStatusPacket(param);
	}
	else if (Event_ID == EV_UpdateCP)
	{
		HandleUpdateStatusPacket(param);
	}
	else if (Event_ID == EV_UpdateMaxCP)
	{
		HandleUpdateStatusPacket(param);
	}
}

function HandleUpdateStatusPacket(string param)
{
	local int ServerID;
	ParseInt( param, "ServerID", ServerID );
	
	//아직 User에 대한 정보를 받지못했다면, 무조건 Update를 실시한다.
	if (m_UserID == ServerID || !m_bReceivedUserInfo)
	{
		m_bReceivedUserInfo = true;
		HandleUpdateUserInfo();
	}
}

//플레이어의 문양 정보 처리
function HandleUpdateHennaInfo(string param)
{
	ParseInt(param, "HennaID", m_HennaInfo.HennaID);
	ParseInt(param, "ClassID", m_HennaInfo.ClassID);
	ParseInt(param, "Num", m_HennaInfo.Num);
	ParseInt(param, "Fee", m_HennaInfo.Fee);
	ParseInt(param, "CanUse", m_HennaInfo.CanUse);
	ParseInt(param, "INTnow", m_HennaInfo.INTnow);
	ParseInt(param, "INTchange", m_HennaInfo.INTchange);
	ParseInt(param, "STRnow", m_HennaInfo.STRnow);
	ParseInt(param, "STRchange", m_HennaInfo.STRchange);
	ParseInt(param, "CONnow", m_HennaInfo.CONnow);
	ParseInt(param, "CONchange", m_HennaInfo.CONchange);
	ParseInt(param, "MENnow", m_HennaInfo.MENnow);
	ParseInt(param, "MENchange", m_HennaInfo.MENchange);
	ParseInt(param, "DEXnow", m_HennaInfo.DEXnow);
	ParseInt(param, "DEXchange", m_HennaInfo.DEXchange);
	ParseInt(param, "WITnow", m_HennaInfo.WITnow);
	ParseInt(param, "WITchange", m_HennaInfo.WITchange);
}

function bool GetMyUserInfo( out UserInfo a_MyUserInfo )
{
	return GetPlayerInfo( a_MyUserInfo );
}

function String GetMovingSpeed( UserInfo a_UserInfo )
{
	local int MovingSpeed;
	local EMoveType	MoveType;
	local EEnvType	EnvType;

	// Moving Speed
	MoveType			= class'UIDATA_PLAYER'.static.GetPlayerMoveType();
	EnvType				= class'UIDATA_PLAYER'.static.GetPlayerEnvironment();

	if (MoveType == MVT_FAST)
	{
		MovingSpeed = a_UserInfo.nGroundMaxSpeed * a_UserInfo.fNonAttackSpeedModifier;
		switch (EnvType)
		{
		case ET_UNDERWATER:
			MovingSpeed = a_UserInfo.nWaterMaxSpeed * a_UserInfo.fNonAttackSpeedModifier;
			break;
		case ET_AIR:
			MovingSpeed = a_UserInfo.nAirMaxSpeed * a_UserInfo.fNonAttackSpeedModifier;
			break;
		}
	}
	else if (MoveType == MVT_SLOW)
	{
		MovingSpeed = a_UserInfo.nGroundMinSpeed * a_UserInfo.fNonAttackSpeedModifier;
		switch (EnvType)
		{
		case ET_UNDERWATER:
			MovingSpeed = a_UserInfo.nWaterMinSpeed * a_UserInfo.fNonAttackSpeedModifier;
			break;
		case ET_AIR:
			MovingSpeed = a_UserInfo.nAirMinSpeed * a_UserInfo.fNonAttackSpeedModifier;
			break;
		}
	}

	return String( MovingSpeed );
}

function float GetMyExpRate()
{
	return class'UIDATA_PLAYER'.static.GetPlayerEXPRate() * 100.0f;
}

//플레이어 정보 처리
function HandleUpdateUserInfo()
{
	local Rect rectWnd;
	local int Width1;
	local int Height1;
	local int Width2;
	local int Height2;
	
	local string	Name;
	local string	NickName;
	local color	NameColor;
	local color	NickNameColor;
	local int		SubClassID;
	local string	ClassName;
	local string	UserRank;
	local int		HP;
	local int		MaxHP;
	local int		MP;
	local int		MaxMP;
	local int		CP;
	local int		MaxCP;
	local int		CarryWeight;
	local int		CarringWeight;
	local int		SP;
	local int		Level;
	local float		fExpRate;
	local float		fTmp;
	
	local int		PledgeID;
	local string	PledgeName;
	local texture	PledgeCrestTexture;
	local bool		bPledgeCrestTexture;
	local color	PledgeNameColor;
	
	local string	HeroTexture;
	local bool		bHero;
	local bool		bNobless;
	
	local int		nSTR;
	local int		nDEX;
	local int		nCON;
	local int		nINT;
	local int		nWIT;
	local int		nMEN;
	local string	strTmp;
	
	local int		PhysicalAttack;
	local int		PhysicalDefense;
	local int		HitRate;
	local int		CriticalRate;
	local int		PhysicalAttackSpeed;
	local int		MagicalAttack;
	local int		MagicDefense;
	local int		PhysicalAvoid;
	local String	MovingSpeed;
	local int		MagicCastingSpeed;
	
	local int		CriminalRate;
	local int		CrimRate;
	local string	strCriminalRate;
	local int		DualCount;
	local int		PKCount;
	local int		Sociality;
	local int		RemainSulffrage;
	
	local UserInfo	info;
	
	//초기화
	class'UIAPI_TEXTURECTRL'.static.SetTexture(m_WindowName$".texPledgeCrest", "");
	rectWnd = class'UIAPI_WINDOW'.static.GetRect( m_WindowName );
	
	if (GetMyUserInfo(info))
	{
		m_UserID = info.nID;
		
		Name = info.Name;
		NickName = info.strNickName;
		SubClassID = info.nSubClass;
		ClassName = GetClassType(SubClassID);
		SP = info.nSP;
		Level = info.nLevel;
		UserRank = GetUserRankString(info.nUserRank);
		HP = info.nCurHP;
		MaxHP = info.nMaxHP;
		MP = info.nCurMP;
		MaxMP = info.nMaxMP;
		CarryWeight = info.nCarryWeight;
		CarringWeight = info.nCarringWeight;	
		CP = info.nCurCP;
		MaxCP = info.nMaxCP;
		fExpRate = GetMyExpRate();
		
		PledgeID = info.nClanID;
		bHero = info.bHero;
		bNobless = info.bNobless;
		
		//플레이어 상세 정보
		nSTR	= info.nStr;
		nDEX	= info.nDex;
		nCON	= info.nCon;
		nINT		= info.nInt;
		nWIT		= info.nWit;
		nMEN	= info.nMen;
		
		PhysicalAttack			= info.nPhysicalAttack;
		PhysicalDefense		= info.nPhysicalDefense;
		HitRate				= info.nHitRate;
		CriticalRate			= info.nCriticalRate;
		PhysicalAttackSpeed	= info.nPhysicalAttackSpeed;
		MagicalAttack			= info.nMagicalAttack;
		MagicDefense			= info.nMagicDefense;
		PhysicalAvoid			= info.nPhysicalAvoid;
		MagicCastingSpeed		= info.nMagicCastingSpeed;
		
		MovingSpeed = GetMovingSpeed( info );
		
		CriminalRate		= info.nCriminalRate;
		DualCount		= info.nDualCount;
		PKCount			= info.nPKCount;
		Sociality			= info.nSociality;
		RemainSulffrage	= info.nRemainSulffrage;
		if (CriminalRate>=999999)
		{
			strCriminalRate = CriminalRate $ "+";
		}
		else
		{
			strCriminalRate = CriminalRate $ "";
		}
		
	}
	
	//닉네임,네임 색상 설정
	CrimRate = CriminalRate;
	if (CrimRate > 255)
	{
		CrimRate = 255;
	}
	if (CrimRate > 0)
	{
		CrimRate = Clamp(CrimRate, (100 + (CrimRate/16)), 255);
	}
	NameColor.R = 255;
	NameColor.G = 255 - CrimRate;
	NameColor.B = 255 - CrimRate;
	NameColor.A = 255;
	NickNameColor.R = 162;
	NickNameColor.G = 249;
	NickNameColor.B = 236;
	NickNameColor.A = 255;
	
	if (Len(NickName)>0)
	{
		GetTextSize(Name, Width1, Height1);
		GetTextSize(NickName, Width2, Height2);
		if (Width1 + Width2 > 220)
		{
			if (Width1 > 109)
			{
				Name = Left(Name, 8);
				GetTextSize(Name, Width1, Height1);
			}
			if (Width2 > 109)
			{
				NickName = Left(NickName, 8);
				GetTextSize(NickName, Width2, Height2);
			}
		}
		class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtName1", NickName);
		class'UIAPI_TEXTBOX'.static.SetTextColor(m_WindowName$".txtName1", NickNameColor);
		class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtName2", Name);
		class'UIAPI_TEXTBOX'.static.SetTextColor(m_WindowName$".txtName2", NameColor);
		class'UIAPI_WINDOW'.static.MoveTo(m_WindowName$".txtName2", rectWnd.nX + 15 + Width2 + 6, rectWnd.nY + 9);
	}
	else
	{
		class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtName1", Name);
		class'UIAPI_TEXTBOX'.static.SetTextColor(m_WindowName$".txtName1", NameColor);
		class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtName2", "");
	}
	
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtLvName", Level $ " " $ ClassName);
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtRank", UserRank);
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtHP", HP $ "/" $ MaxHP);
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtMP", MP $ "/" $ MaxMP);
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtExp", fExpRate $ "%");
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtCP", CP $ "/" $ MaxCP);
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtSP", string(SP));
	fTmp = 100.0f * float(CarringWeight) / float(CarryWeight);
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtWeight", fTmp $ "%");
	
	//혈맹
	if (PledgeID>0)
	{
		//텍스쳐
		bPledgeCrestTexture = class'UIDATA_CLAN'.static.GetCrestTexture(PledgeID, PledgeCrestTexture);
		PledgeName = class'UIDATA_CLAN'.static.GetName(PledgeID);
		PledgeNameColor.R = 176;
		PledgeNameColor.G = 155;
		PledgeNameColor.B = 121;
		PledgeNameColor.A = 255;
	}
	else
	{
		PledgeName = GetSystemString(431);
		PledgeNameColor.R = 255;
		PledgeNameColor.G = 255;
		PledgeNameColor.B = 255;
		PledgeNameColor.A = 255;
	}
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtPledge", PledgeName);
	class'UIAPI_TEXTBOX'.static.SetTextColor(m_WindowName$".txtPledge", PledgeNameColor);
	if (bPledgeCrestTexture)
	{
		class'UIAPI_TEXTURECTRL'.static.SetTextureWithObject(m_WindowName$".texPledgeCrest", PledgeCrestTexture);
		class'UIAPI_WINDOW'.static.MoveTo(m_WindowName$".txtPledge", rectWnd.nX + 88, rectWnd.nY + 25);
	}
	else
	{
		class'UIAPI_WINDOW'.static.MoveTo(m_WindowName$".txtPledge", rectWnd.nX + 68, rectWnd.nY + 25);
	}
	
	//영웅,노블레스
	if (bHero)
	{
		HeroTexture = "L2UI_CH3.PlayerStatusWnd.myinfo_heroicon";
	}
	else if (bNobless)
	{
		HeroTexture = "L2UI_CH3.PlayerStatusWnd.myinfo_nobleicon";
	}
	class'UIAPI_TEXTURECTRL'.static.SetTexture(m_WindowName$".texHero", HeroTexture);
	
	//상세 정보
	if (m_HennaInfo.STRchange > 0)
	{
		strTmp = nSTR $ "(+" $ m_HennaInfo.STRchange $ ")";
	}
	else if (m_HennaInfo.STRchange < 0)
	{
		strTmp = nSTR $ "(" $ m_HennaInfo.STRchange $ ")";
	}
	else
	{
		strTmp = string(nSTR);
	}
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtSTR", strTmp);
	
	if (m_HennaInfo.DEXchange > 0)
	{
		strTmp = nDEX $ "(+" $ m_HennaInfo.DEXchange $ ")";
	}
	else if (m_HennaInfo.DEXchange < 0)
	{
		strTmp = nDEX $ "(" $ m_HennaInfo.DEXchange $ ")";
	}
	else
	{
		strTmp = string(nDEX);
	}
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtDEX", strTmp);
	
	if (m_HennaInfo.CONchange > 0)
	{
		strTmp = nCON $ "(+" $ m_HennaInfo.CONchange $ ")";
	}
	else if (m_HennaInfo.CONchange < 0)
	{
		strTmp = nCON $ "(" $ m_HennaInfo.CONchange $ ")";
	}
	else
	{
		strTmp = string(nCON);
	}
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtCON", strTmp);
	
	if (m_HennaInfo.INTchange > 0)
	{
		strTmp = nINT $ "(+" $ m_HennaInfo.INTchange $ ")";
	}
	else if (m_HennaInfo.INTchange < 0)
	{
		strTmp = nINT $ "(" $ m_HennaInfo.INTchange $ ")";
	}
	else
	{
		strTmp = string(nINT);
	}
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtINT", strTmp);
	
	if (m_HennaInfo.WITchange > 0)
	{
		strTmp = nWIT $ "(+" $ m_HennaInfo.WITchange $ ")";
	}
	else if (m_HennaInfo.WITchange < 0)
	{
		strTmp = nWIT $ "(" $ m_HennaInfo.WITchange $ ")";
	}
	else
	{
		strTmp = string(nWIT);
	}
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtWIT", strTmp);
	
	if (m_HennaInfo.MENchange > 0)
	{
		strTmp = nMEN $ "(+" $ m_HennaInfo.MENchange $ ")";
	}
	else if (m_HennaInfo.MENchange < 0)
	{
		strTmp = nMEN $ "(" $ m_HennaInfo.MENchange $ ")";
	}
	else
	{
		strTmp = string(nMEN);
	}
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtMEN", strTmp);
	
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtPhysicalAttack", string(PhysicalAttack));
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtPhysicalDefense", string(PhysicalDefense));
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtHitRate", string(HitRate));
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtCriticalRate", string(CriticalRate));
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtPhysicalAttackSpeed", string(PhysicalAttackSpeed));
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtMagicalAttack", string(MagicalAttack));
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtMagicDefense", string(MagicDefense));
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtPhysicalAvoid", string(PhysicalAvoid));
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtMovingSpeed", MovingSpeed);
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtMagicCastingSpeed", string(MagicCastingSpeed));
	
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtCriminalRate", strCriminalRate);
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtPVP", DualCount $ " / " $ PKCount);
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtSociality", string(Sociality));
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtRemainSulffrage", string(RemainSulffrage));
	
	UpdateHPBar(HP, MaxHP);
	UpdateMPBar(MP, MaxMP);
	UpdateCPBar(CP, MaxCP);
	UpdateEXPBar(int(fExpRate), 100);
	UpdateWeightBar(CarringWeight, CarryWeight);
}

//HP바 갱신
function UpdateHPBar(int Value, int MaxValue)
{
	local int Size;
	Size = 0;
	if (MaxValue>0)
	{
		Size = NSTATUS_SMALLBARSIZE;
		if (Value<MaxValue)
		{
			Size = NSTATUS_SMALLBARSIZE* Value / MaxValue;
		}
		
	}
	class'UIAPI_WINDOW'.static.SetWindowSize(m_WindowName$".texHP", Size, NSTATUS_BARHEIGHT);
}

//MP바 갱신
function UpdateMPBar(int Value, int MaxValue)
{
	local int Size;
	Size = 0;
	if (MaxValue>0)
	{
		Size = NSTATUS_SMALLBARSIZE;
		if (Value<MaxValue)
		{
			Size = NSTATUS_SMALLBARSIZE* Value / MaxValue;
		}
		
	}
	class'UIAPI_WINDOW'.static.SetWindowSize(m_WindowName$".texMP", Size, NSTATUS_BARHEIGHT);
}

//EXP바 갱신
function UpdateEXPBar(int Value, int MaxValue)
{
	local int Size;
	Size = 0;
	if (MaxValue>0)
	{
		Size = NSTATUS_SMALLBARSIZE;
		if (Value<MaxValue)
		{
			Size = NSTATUS_SMALLBARSIZE* Value / MaxValue;
		}
		
	}
	class'UIAPI_WINDOW'.static.SetWindowSize(m_WindowName$".texEXP", Size, NSTATUS_BARHEIGHT);
}

//CP바 갱신
function UpdateCPBar(int Value, int MaxValue)
{
	local int Size;
	Size = 0;
	if (MaxValue>0)
	{
		Size = NSTATUS_SMALLBARSIZE;
		if (Value<MaxValue)
		{
			Size = NSTATUS_SMALLBARSIZE* Value / MaxValue;
		}
	}
	class'UIAPI_WINDOW'.static.SetWindowSize(m_WindowName$".texCP", Size, NSTATUS_BARHEIGHT);
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
		Size = NSTATUS_SMALLBARSIZE;
		if (Value<MaxValue)
		{
			Size = NSTATUS_SMALLBARSIZE* Value / MaxValue;
		}
	}
	class'UIAPI_TEXTURECTRL'.static.SetTexture(m_WindowName$".texWeight", strName);
	class'UIAPI_WINDOW'.static.SetWindowSize(m_WindowName$".texWeight", Size, NSTATUS_BARHEIGHT);
}

