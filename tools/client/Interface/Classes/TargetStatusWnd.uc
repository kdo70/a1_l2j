class TargetStatusWnd extends UIScript;

var bool	m_bExpand;

var int	m_TargetLevel;
var int	m_TargetID;

var bool	m_bShow;

function OnLoad()
{
	RegisterEvent( EV_TargetUpdate );
	RegisterEvent( EV_TargetHideWindow );
	
	RegisterEvent( EV_UpdateHP );
	RegisterEvent( EV_UpdateMP );
	RegisterEvent( EV_UpdateMaxHP );
	RegisterEvent( EV_UpdateMaxMP );
	
	RegisterEvent( EV_ReceiveTargetLevelDiff );
	
	SetExpandMode(false);
	
	m_bShow = false;
	m_TargetID = -1;
}

function OnShow()
{
	m_bShow = true;
}

function OnHide()
{
	m_bShow = false;
}

function OnEnterState( name a_PreStateName )
{
	SetExpandMode(m_bExpand);
}

function OnEvent(int Event_ID, string param)
{
	if (Event_ID == EV_TargetUpdate)
	{
		HandleTargetUpdate();
	}
	else if (Event_ID == EV_TargetHideWindow)
	{
		class'UIAPI_WINDOW'.static.HideWindow("TargetStatusWnd");
	}
	else if (Event_ID == EV_ReceiveTargetLevelDiff)
	{
		HandleReceiveTargetLevelDiff(param);
	}
	else if (Event_ID == EV_UpdateHP)
	{
		HandleUpdateHPMP(param);
	}
	else if (Event_ID == EV_UpdateMP)
	{
		HandleUpdateHPMP(param);
	}
	else if (Event_ID == EV_UpdateMaxHP)
	{
		HandleUpdateHPMP(param);
	}
	else if (Event_ID == EV_UpdateMaxMP)
	{
		HandleUpdateHPMP(param);
	}
}

function OnClickButton( string strID )
{
	switch( strID )
	{
	case "btnClose":
		OnCloseButton();
		break;
	}
}

//종료
function OnCloseButton()
{
	RequestTargetCancel();
	PlayConsoleSound(IFST_WINDOW_CLOSE);
}

//HP,MP 업데이트
function HandleUpdateHPMP(string param)
{
	local int ServerID;
	
	if (m_bShow)
	{
		ParseInt( param, "ServerID", ServerID );
		if (m_TargetID == ServerID)
		{
			HandleTargetUpdate();
		}	
	}
}

//타겟과의 레벨 차이
function HandleReceiveTargetLevelDiff(string param)
{
	ParseInt(param, "LevelDiff", m_TargetLevel);
}

//타겟 정보 업데이트 처리
function HandleTargetUpdate()
{
	local Rect rectWnd;
	local string strTmp;
	
	local int		TargetID;
	local int		PlayerID;
	local int		PetID;
	local int		ClanType;
	local int		ClanNameValue;
	
	//타겟 속성 정보
	local bool		bIsServerObject;
	local bool		bIsHPShowableNPC;	//공성진지
	
	local string	Name;
	local string	RankName;
	local color	TargetNameColor;
	
	//ServerObject
	local int ServerObjectNameID;
	local EServerObjectType ServerObjectType;
	
	//HP,MP
	local bool		bShowHPBar;
	local bool		bShowMPBar;
	
	//혈맹 정보
	local bool		bShowPledgeInfo;
	local bool		bShowPledgeTex;
	local bool		bShowPledgeAllianceTex;
	local string	PledgeName;
	local string	PledgeAllianceName;
	local texture	PledgeCrestTexture;
	local texture	PledgeAllianceCrestTexture;
	local color	PledgeNameColor;
	local color	PledgeAllianceNameColor;
	
	//NPC특성
	local bool		 bShowNpcInfo;
	local Array<int>	 arrNpcInfo;
	
	//새로운Target인가?
	local bool		IsTargetChanged;
	
	local UserInfo	info;
	
	local Color WhiteColor;	//  하얀색을 설정.
	WhiteColor.R = 0;
	WhiteColor.G = 0;
	WhiteColor.B = 0;
	
	//타겟ID 얻어오기
	TargetID = class'UIDATA_TARGET'.static.GetTargetID();
	if (TargetID<1)
	{
		class'UIAPI_WINDOW'.static.HideWindow("TargetStatusWnd");
		return;
	}
	
	//타겟이 바뀌었는가?
	if (m_TargetID!=TargetID)
		IsTargetChanged = true;	
	m_TargetID = TargetID;
	
	GetTargetInfo(info);
	
	//초기화
	rectWnd = class'UIAPI_WINDOW'.static.GetRect("TargetStatusWnd");
	PledgeName = GetSystemString(431);
	PledgeAllianceName = GetSystemString(591);
	PledgeNameColor.R = 128;
	PledgeNameColor.G = 128;
	PledgeNameColor.B = 128;
	PledgeAllianceNameColor.R = 128;
	PledgeAllianceNameColor.G = 128;
	PledgeAllianceNameColor.B = 128;
	
	//타겟 이름 색깔
	TargetNameColor = class'UIDATA_TARGET'.static.GetTargetNameColor(m_TargetLevel);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////
	//StaticObject인가? ( door 등등 )
	bIsServerObject = class'UIDATA_TARGET'.static.IsServerObject();
	if (bIsServerObject)
	{
		ServerObjectNameID = class'UIDATA_STATICOBJECT'.static.GetServerObjectNameID(m_TargetID);
		if (ServerObjectNameID>0)
		{
			Name = class'UIDATA_STATICOBJECT'.static.GetStaticObjectName(ServerObjectNameID);
			RankName = "";	
		}
		class'UIAPI_NAMECTRL'.static.SetName("TargetStatusWnd.UserName", Name, NCT_Normal,TA_Center);
		class'UIAPI_NAMECTRL'.static.SetName("TargetStatusWnd.RankName", RankName, NCT_Normal,TA_Center);
		
		//HP표시
		ServerObjectType = class'UIDATA_STATICOBJECT'.static.GetServerObjectType(m_TargetID);
		if (ServerObjectType == SOT_DOOR)
		{
			if( class'UIDATA_STATICOBJECT'.static.GetStaticObjectShowHP( m_TargetID ) )
			{
				bShowHPBar = true;
				UpdateHPBar(class'UIDATA_STATICOBJECT'.static.GetServerObjectHP(m_TargetID), class'UIDATA_STATICOBJECT'.static.GetServerObjectMaxHP(m_TargetID));
			}
		}
	}
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////
	//타겟ID는 있는데 이름을 알수없다면, 멀리있는 파티멤버로 가정
	else if (Len(info.Name)<1)
	{			
		Name = class'UIDATA_PARTY'.static.GetMemberName(m_TargetID);
		RankName = "";
		debug("m_TargetID" $ m_TargetID $ ", info.Name : " $ info.Name $ ", Name : " $ Name );
		class'UIAPI_NAMECTRL'.static.SetName("TargetStatusWnd.UserName", Name, NCT_Normal,TA_Center);
		class'UIAPI_NAMECTRL'.static.SetName("TargetStatusWnd.RankName", RankName, NCT_Normal,TA_Center);
	}
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////
	//Npc or Pc 의 경우
	else
	{
		PlayerID = class'UIDATA_PLAYER'.static.GetPlayerID();
		PetID = class'UIDATA_PET'.static.GetPetID();
		
		bIsHPShowableNPC = class'UIDATA_TARGET'.static.IsHPShowableNPC();

		if ((info.bNpc && !info.bPet && info.bCanBeAttacked ) ||	//몹의경우
			(PlayerID>0 && m_TargetID == PlayerID) ||		//나의경우
			(info.bNpc && info.bPet && m_TargetID == PetID) ||	//펫의경우
			(info.bNpc && bIsHPShowableNPC)	)		//공성진지
		{
			//일반 몹중에 항상 흰색으로 표시해 줄 필요가 있는 몬스터일 경우
			if(IsAllWhiteID(info.nClassID))
			{
				Name = info.Name;
				RankName = "";
				//debug("m_TargetID" $ m_TargetID $ ", info.Name : " $ info.Name $ ", Name : " $ Name );
				class'UIAPI_NAMECTRL'.static.SetName("TargetStatusWnd.UserName", Name, NCT_Normal,TA_Center);
				class'UIAPI_NAMECTRL'.static.SetName("TargetStatusWnd.RankName", RankName, NCT_Normal,TA_Center);
					
				//HP표시
				if(! (IsNoBarID(info.nClassID)))
				{
					bShowHPBar = true;
					UpdateHPBar(info.nCurHP, info.nMaxHP);
				}
			}
			else
			{
				Name = info.Name;
				RankName = "";	
				class'UIAPI_NAMECTRL'.static.SetNameWithColor("TargetStatusWnd.UserName", Name, NCT_Normal,TA_Center,TargetNameColor);
				class'UIAPI_NAMECTRL'.static.SetName("TargetStatusWnd.RankName", RankName, NCT_Normal,TA_Center);
				
				//HP표시
				bShowHPBar = true;
				UpdateHPBar(info.nCurHP, info.nMaxHP);
				
				//MP표시
				if (!(info.bNpc && !info.bPet && info.bCanBeAttacked))
				{
					bShowMPBar = true;
					UpdateMPBar(info.nCurMP, info.nMaxMP);
				}
			}
		}		
		//Npc or Other Pc
		else
		{
			Name = info.Name;
			if (info.bNpc)
			{
				RankName = "";	
			}
			else
			{
				RankName = GetUserRankString(info.nUserRank);
			}
			class'UIAPI_NAMECTRL'.static.SetName("TargetStatusWnd.UserName", Name, NCT_Normal,TA_Center);;
			class'UIAPI_NAMECTRL'.static.SetName("TargetStatusWnd.RankName", RankName, NCT_Normal,TA_Center);
		}
		
		/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		/// 추가 정보 표시
		/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		if (m_bExpand)
		{
			if (info.bNpc)
			{
				if (class'UIDATA_NPC'.static.GetNpcProperty(info.nClassID, arrNpcInfo))
				{
					bShowNpcInfo = true;
					
					//트리컨트롤에 Npc특성아이콘 추가
					//타겟이 바뀌었을때만 정보를 갱신한다. 안그럼 HP만 갱신될 때 깜박거림
					if (IsTargetChanged)
						UpdateNpcInfoTree(arrNpcInfo);
				}				
			}
			else
			{
				bShowPledgeInfo = true;
				if (info.nClanID>0)
				{
					//혈맹이름
					PledgeName = class'UIDATA_CLAN'.static.GetName(info.nClanID);
					PledgeNameColor.R = 176;
					PledgeNameColor.G = 152;
					PledgeNameColor.B = 121;
					if( PledgeName != "" && class'UIDATA_USER'.static.GetClanType( m_TargetID, ClanType ) && class'UIDATA_CLAN'.static.GetNameValue(info.nClanID, ClanNameValue) )
					{
						if( ClanType == CLAN_ACADEMY )
						{
							PledgeNameColor.R = 209;
							PledgeNameColor.G = 167;
							PledgeNameColor.B = 2;
						}
						else if( ClanNameValue > 0 )
						{
							PledgeNameColor.R = 0;
							PledgeNameColor.G = 130;
							PledgeNameColor.B = 255;
						}
						else if( ClanNameValue < 0 )
						{
							PledgeNameColor.R = 255;
							PledgeNameColor.G = 0;
							PledgeNameColor.B = 0;
						}
					}
					
					//혈맹 텍스쳐 얻어오기
					if (class'UIDATA_CLAN'.static.GetCrestTexture(info.nClanID, PledgeCrestTexture))
					{
						bShowPledgeTex = true;
						class'UIAPI_TEXTURECTRL'.static.SetTextureWithObject("TargetStatusWnd.texPledgeCrest", PledgeCrestTexture);
					}
					else
					{
						bShowPledgeTex = false;
					}
					
					//동맹이름 및 마크
					strTmp = class'UIDATA_CLAN'.static.GetAllianceName(info.nClanID);
					if (Len(strTmp)>0)
					{
						//동맹 이름 색깔
						PledgeAllianceName = strTmp;
						PledgeAllianceNameColor.R = 176;
						PledgeAllianceNameColor.G = 155;
						PledgeAllianceNameColor.B = 121;
						
						//동맹 텍스쳐 얻어오기
						if (class'UIDATA_CLAN'.static.GetAllianceCrestTexture(info.nClanID, PledgeAllianceCrestTexture))
						{
							bShowPledgeAllianceTex = true;
							class'UIAPI_TEXTURECTRL'.static.SetTextureWithObject("TargetStatusWnd.texPledgeAllianceCrest", PledgeAllianceCrestTexture);
						}
						else
						{
							bShowPledgeAllianceTex = false;
						}
					}
				}
			}
		}
	}
	
	if (!class'UIAPI_WINDOW'.static.IsShowWindow("TargetStatusWnd"))
	{
		class'UIAPI_WINDOW'.static.ShowWindow("TargetStatusWnd");
		SetExpandMode(m_bExpand);
	}
	
	//HP,MP표시
	if (bShowHPBar)
	{
		class'UIAPI_WINDOW'.static.ShowWindow("TargetStatusWnd.barHP");
	}
	else
	{
		class'UIAPI_WINDOW'.static.HideWindow("TargetStatusWnd.barHP");
	}
	if (bShowMPBar)
	{
		class'UIAPI_WINDOW'.static.ShowWindow("TargetStatusWnd.barMP");
	}
	else
	{
		class'UIAPI_WINDOW'.static.HIdeWindow("TargetStatusWnd.barMP");
	}
	
	//혈맹정보 표시
	if (bShowPledgeInfo)
	{
		class'UIAPI_WINDOW'.static.ShowWindow("TargetStatusWnd.txtPledge");
		class'UIAPI_WINDOW'.static.ShowWindow("TargetStatusWnd.txtAlliance");
		class'UIAPI_WINDOW'.static.ShowWindow("TargetStatusWnd.txtPledgeName");
		class'UIAPI_WINDOW'.static.ShowWindow("TargetStatusWnd.txtPledgeAllianceName");
		class'UIAPI_TEXTBOX'.static.SetText("TargetStatusWnd.txtPledgeName", PledgeName);
		class'UIAPI_TEXTBOX'.static.SetText("TargetStatusWnd.txtPledgeAllianceName", PledgeAllianceName);
		class'UIAPI_TEXTBOX'.static.SetTextColor("TargetStatusWnd.txtPledgeName", PledgeNameColor);
		class'UIAPI_TEXTBOX'.static.SetTextColor("TargetStatusWnd.txtPledgeAllianceName", PledgeAllianceNameColor);
		
		if (bShowPledgeTex)
		{
			class'UIAPI_WINDOW'.static.ShowWindow("TargetStatusWnd.texPledgeCrest");
			class'UIAPI_WINDOW'.static.MoveTo("TargetStatusWnd.txtPledgeName", rectWnd.nX + 63, rectWnd.nY + 43);
		}
		else
		{
			class'UIAPI_WINDOW'.static.HideWindow("TargetStatusWnd.texPledgeCrest");
			class'UIAPI_WINDOW'.static.MoveTo("TargetStatusWnd.txtPledgeName", rectWnd.nX + 45, rectWnd.nY + 43);
		}
		
		if (bShowPledgeAllianceTex)
		{
			class'UIAPI_WINDOW'.static.ShowWindow("TargetStatusWnd.texPledgeAllianceCrest");
			class'UIAPI_WINDOW'.static.MoveTo("TargetStatusWnd.txtPledgeAllianceName", rectWnd.nX + 63, rectWnd.nY + 59);
		}
		else
		{
			class'UIAPI_WINDOW'.static.HideWindow("TargetStatusWnd.texPledgeAllianceCrest");
			class'UIAPI_WINDOW'.static.MoveTo("TargetStatusWnd.txtPledgeAllianceName", rectWnd.nX + 45, rectWnd.nY + 59);
		}
	}
	else
	{
		class'UIAPI_WINDOW'.static.HideWindow("TargetStatusWnd.txtPledge");
		class'UIAPI_WINDOW'.static.HideWindow("TargetStatusWnd.texPledgeCrest");
		class'UIAPI_WINDOW'.static.HideWindow("TargetStatusWnd.txtPledgeName");
		class'UIAPI_WINDOW'.static.HideWindow("TargetStatusWnd.txtAlliance");
		class'UIAPI_WINDOW'.static.HideWindow("TargetStatusWnd.texPledgeAllianceCrest");
		class'UIAPI_WINDOW'.static.HideWindow("TargetStatusWnd.txtPledgeAllianceName");
	}
	
	//NPC특성 표시
	if (bShowNpcInfo)
	{
		class'UIAPI_WINDOW'.static.ShowWindow("TargetStatusWnd.NpcInfo");
		class'UIAPI_TREECTRL'.static.ShowScrollBar("TargetStatusWnd.NpcInfo", false);
	}
	else
	{
		class'UIAPI_WINDOW'.static.HideWindow("TargetStatusWnd.NpcInfo");
	}
}

//Frame Expand버튼 처리
function OnFrameExpandClick( bool bIsExpand )
{
	SetExpandMode(bIsExpand);
}

//Expand상태에 따른 여러가지 처리
function SetExpandMode(bool bExpand)
{
	m_bExpand = bExpand;
	
	m_TargetID = -1;
	HandleTargetUpdate();
	
	if (bExpand)
	{
		class'UIAPI_WINDOW'.static.HideWindow("TargetStatusWnd.BackTex");
		class'UIAPI_WINDOW'.static.ShowWindow("TargetStatusWnd.BackExpTex");
	}
	else
	{
		class'UIAPI_WINDOW'.static.ShowWindow("TargetStatusWnd.BackTex");
		class'UIAPI_WINDOW'.static.HideWindow("TargetStatusWnd.BackExpTex");
	}
}

//HP바 갱신
function UpdateHPBar(int HP, int MaxHP)
{
	class'UIAPI_BARCTRL'.static.SetValue("TargetStatusWnd.barHP", MaxHP, HP);
}

//MP바 갱신
function UpdateMPBar(int MP, int MaxMP)
{
	class'UIAPI_BARCTRL'.static.SetValue("TargetStatusWnd.barMP", MaxMP, MP);
}

//트리컨트롤에 Npc특성아이콘 추가
function UpdateNpcInfoTree(array<int> arrNpcInfo)
{
	local int i;
	local int SkillID;
	local int SkillLevel;
	
	local string				strNodeName;
	local XMLTreeNodeInfo		infNode;
	local XMLTreeNodeItemInfo	infNodeItem;
	local XMLTreeNodeInfo		infNodeClear;
	local XMLTreeNodeItemInfo	infNodeItemClear;
	
	//초기화
	class'UIAPI_TREECTRL'.static.Clear("TargetStatusWnd.NpcInfo");
	
	//루트 추가
	infNode.strName = "root";
	strNodeName = class'UIAPI_TREECTRL'.static.InsertNode("TargetStatusWnd.NpcInfo", "", infNode);
	if (Len(strNodeName) < 1)
	{
		debug("ERROR: Can't insert root node. Name: " $ infNode.strName);
		return;
	}
	
	for (i=0; i<arrNpcInfo.Length; i+=2)
	{
		SkillID = arrNpcInfo[i];
		SkillLevel = arrNpcInfo[i+1];
		
		//////////////////////////////////////////////////////////////////////////////////////////////////////
		//Insert Node
		infNode = infNodeClear;
		infNode.nOffSetX = ((i/2)%8)*18;
		if ((i/2)%8==0)
		{
			if (i>0)
			{
				infNode.nOffSetY = 3;
			}
			else
			{
				infNode.nOffSetY = 0;
			}
		}
		else
		{
			infNode.nOffSetY = -15;
		}
		
		infNode.strName = "" $ i/2;
		infNode.bShowButton = 0;
		//Tooltip
		infNode.ToolTip = SetNpcInfoTooltip(SkillID, SkillLevel);
		strNodeName = class'UIAPI_TREECTRL'.static.InsertNode("TargetStatusWnd.NpcInfo", "root", infNode);
		if (Len(strNodeName) < 1)
		{
			Log("ERROR: Can't insert node. Name: " $ infNode.strName);
			return;
		}
		//Node Tooltip Clear
		infNode.ToolTip.DrawList.Remove(0, infNode.ToolTip.DrawList.Length);
		
		//////////////////////////////////////////////////////////////////////////////////////////////////////
		//Insert NodeItem
		infNodeItem = infNodeItemClear;
		infNodeItem.eType = XTNITEM_TEXTURE;
		infNodeItem.u_nTextureWidth = 15;
		infNodeItem.u_nTextureHeight = 15;
		infNodeItem.u_nTextureUWidth = 32;
		infNodeItem.u_nTextureUHeight = 32;
		infNodeItem.u_strTexture = class'UIDATA_SKILL'.static.GetIconName(SkillID, SkillLevel);
		class'UIAPI_TREECTRL'.static.InsertNodeItem("TargetStatusWnd.NpcInfo", strNodeName, infNodeItem);
	}
}

function CustomTooltip SetNpcInfoTooltip(int ID, int Level)
{
	local CustomTooltip Tooltip;
	local DrawItemInfo info;
	local DrawItemInfo infoClear;
	local ItemInfo Item;
	
	Item.Name = class'UIDATA_SKILL'.static.GetName(ID, Level);
	Item.Description = class'UIDATA_SKILL'.static.GetDescription(ID, Level);
	
	Tooltip.DrawList.Length = 1;
	
	//이름
	info = infoClear;
	info.eType = DIT_TEXT;
	info.t_bDrawOneLine = true;
	info.t_strText = Item.Name;
	Tooltip.DrawList[0] = info;

	//설명
	if (Len(Item.Description)>0)
	{
		Tooltip.MinimumWidth = 144;
		Tooltip.DrawList.Length = 2;
		
		info = infoClear;
		info.eType = DIT_TEXT;
		info.nOffSetY = 6;
		info.bLineBreak = true;
		info.t_color.R = 178;
		info.t_color.G = 190;
		info.t_color.B = 207;
		info.t_color.A = 255;
		info.t_strText = Item.Description;
		Tooltip.DrawList[1] = info;	
	}
	return Tooltip;
}

//항상 흰색으로 표시해 줄 몬스터를 체크하는 함수
function bool IsAllWhiteID(int m_TargetID)
{
	local bool	bIsAllWhiteName;
	bIsAllWhiteName = false;
	
	switch( m_TargetID )
	{
		case 12778:	//우량대박
		case 13031:	//거대 돼지
		case 13032:	//거대 돼지 리더
		case 13033:	//거대 돼지 부하
		case 13034:	//초거대 돼지
		case 13035:	//황금 돼지
		case 13036:	//연금술사의 보물상자
			bIsAllWhiteName = true;
			break;
	}	
	return bIsAllWhiteName;
}

//HP 바도 표시하면 안되는 몬스터인지 체크하는 함수
function bool IsNoBarID(int m_TargetID)
{
	local bool	bIsNoBarName;
	bIsNoBarName = false;
	
	switch( m_TargetID )
	{
		case 13036:	//연금술사의 보물상자
			bIsNoBarName = true;
			break;
	}	
	return bIsNoBarName;
}
