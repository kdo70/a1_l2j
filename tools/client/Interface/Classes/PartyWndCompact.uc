/******************************************************************************
//                                             축소된 파티창 UI 관련 스크립트                                                                    //
******************************************************************************/
class PartyWndCompact extends UICommonAPI;

// 상수 설정.
const NSTATUSICON_MAXCOL = 12;		//status icon의 최대 가로.
const NPARTYSTATUS_HEIGHT = 26;		//status 상태창의 세로길이.	// 확장창은 46
const NPARTYSTATUS_MAXCOUNT = 8;		//한 파티창에 들어갈수 있는 최대 파티원의 수.

var bool	m_bCompact;
var bool	m_bBuff;
var bool	m_partyleader;
var int	m_arrID[NPARTYSTATUS_MAXCOUNT];	// 인덱스에 해당하는 파티원의 서버 ID.
var int	m_CurCount;
var int 	m_CurBf;
var int m_MasterID;

//Handle	선언
var WindowHandle	m_wndTop;			// 현재 윈도우
var WindowHandle	m_PartyOption;		// 옵션 윈도우
var WindowHandle	m_PartyStatus[NPARTYSTATUS_MAXCOUNT];	// 캐릭터별 윈도우 (캐릭터 수만큼 생성해준다)
var TextureHandle	m_ClassIcon[NPARTYSTATUS_MAXCOUNT];		//클래스 아이콘 텍스쳐.
var StatusIconHandle	m_StatusIconBuff[NPARTYSTATUS_MAXCOUNT];	//버프아이콘 핸들
var StatusIconHandle	m_StatusIconDeBuff[NPARTYSTATUS_MAXCOUNT];	//디버프아이콘 핸들
var BarHandle		m_BarCP[NPARTYSTATUS_MAXCOUNT];
var BarHandle		m_BarHP[NPARTYSTATUS_MAXCOUNT];
var BarHandle		m_BarMP[NPARTYSTATUS_MAXCOUNT];
var ButtonHandle	btnBuff;

// 윈도우가 생성될때 불리는 함수.
function OnLoad()
{
	local int idx;
	
	// 이벤트 (서버 혹은 클라이언트에서 오는) 핸들 등록.
	RegisterEvent( EV_ShowBuffIcon );
	
	RegisterEvent( EV_PartyAddParty);
	RegisterEvent( EV_PartyUpdateParty );
	RegisterEvent( EV_PartyDeleteParty );
	RegisterEvent( EV_PartyDeleteAllParty );
	RegisterEvent( EV_PartySpelledList );
	
	RegisterEvent( EV_Restart );
	
	m_bCompact = false;
	m_bBuff = false;
	m_CurBf = 0;
	m_MasterID = 0;
	
	//Init Handle
	m_wndTop = GetHandle( "PartyWndCompact" );
	m_PartyOption = GetHandle("PartyWndOption");		// 옵션창의 핸들 초기화.
	for (idx=0; idx<NPARTYSTATUS_MAXCOUNT; idx++)		// 최대파티원 수 만큼 각 데이터를 초기화해줌.
	{
		m_PartyStatus[idx] = GetHandle( "PartyWndCompact.PartyStatusWnd" $ idx );
		m_ClassIcon[idx] = TextureHandle( GetHandle( "PartyWndCompact.PartyStatusWnd" $ idx $ ".ClassIcon" ) );
		m_StatusIconBuff[idx] = StatusIconHandle( GetHandle( "PartyWndCompact.PartyStatusWnd" $ idx $ ".StatusIconBuff" ) );
		m_StatusIconDeBuff[idx] = StatusIconHandle( GetHandle( "PartyWndCompact.PartyStatusWnd" $ idx $ ".StatusIconDebuff" ) );
		m_BarCP[idx] = BarHandle( GetHandle( "PartyWndCompact.PartyStatusWnd" $ idx $ ".barCP" ) );
		m_BarHP[idx] = BarHandle( GetHandle( "PartyWndCompact.PartyStatusWnd" $ idx $ ".barHP" ) );
		m_BarMP[idx] = BarHandle( GetHandle( "PartyWndCompact.PartyStatusWnd" $ idx $ ".barMP" ) );
	}
	btnBuff = ButtonHandle( GetHandle( "PartyWndCompact.btnBuff" ) );
	
	//Reset Anchor	// 버프와 디버프는 PartyWndCompact의 anchor point를 참조한다.
	for (idx=0; idx<NPARTYSTATUS_MAXCOUNT; idx++)
	{
		m_StatusIconBuff[idx].SetAnchor("PartyWndCompact.PartyStatusWnd" $ idx, "TopRight", "TopLeft", 1, 3);
		m_StatusIconDeBuff[idx].SetAnchor("PartyWndCompact.PartyStatusWnd" $ idx, "TopRight", "TopLeft", 1, 3);
	}
	
	//Set ClassIcon0 Position
	m_ClassIcon[0].Move(0, 7);
	
	
	m_PartyOption.HideWindow();
}

function OnShow()
{
	SetBuffButtonTooltip();
}

function OnEnterState( name a_PreStateName )
{
	m_bCompact = false;
	m_bBuff = false;
	m_CurBf = 0;
	ResizeWnd();
}

// 이벤트 핸들 처리.
function OnEvent(int Event_ID, string param)
{
	if (Event_ID == EV_PartyAddParty)	//파티원을 추가하는 이벤트.
	{
		HandlePartyAddParty(param);
	}
	else if (Event_ID == EV_PartyUpdateParty)	//파티 업데이트. 각종 HP 및 상태를 처리하기 위함.
	{
		HandlePartyUpdateParty(param);
	}
	else if (Event_ID == EV_PartyDeleteParty)	//파티원 삭제.
	{
		HandlePartyDeleteParty(param);
	}
	else if (Event_ID == EV_PartyDeleteAllParty)	//모든 파티원 삭제. 파티를 떠나거나 뽀갤때.
	{
		HandlePartyDeleteAllParty();
	}
	else if (Event_ID == EV_PartySpelledList)	// 버프 혹은 디버프 처리.
	{
		HandlePartySpelledList(param);
	}
	else if (Event_ID == EV_ShowBuffIcon)		// 버프, 디버프, 버프/디버프 보이기 모드를 전환.
	{
		HandleShowBuffIcon(param);
	}
	else if (Event_ID == EV_Restart)
	{
		HandleRestart();
	}
}

//리스타트를 하면 올클리어
function HandleRestart()
{
	Clear();
}

//초기화
function Clear()
{
	local int idx;
	for (idx=0; idx<NPARTYSTATUS_MAXCOUNT; idx++)
	{
		ClearStatus(idx);
	}
	m_CurCount = 0;
	ResizeWnd();
}

//상태창의 초기화
function ClearStatus(int idx)
{
	m_StatusIconBuff[idx].Clear();
	m_StatusIconDeBuff[idx].Clear();
	m_ClassIcon[idx].SetTexture("");
	UpdateCPBar(idx, 0, 0);
	UpdateHPBar(idx, 0, 0);
	UpdateMPBar(idx, 0, 0);
	m_arrID[idx] = 0;
}

//파티창의 복사 (목적이 되는 파티창의 인덱스, 복사할 파티창의 인덱스)
function CopyStatus(int DesIndex, int SrcIndex)
{
	local int		MaxValue;
	local int		CurValue;
	
	local int		Row;
	local int		Col;
	local int		MaxRow;
	local int		MaxCol;
	
	local StatusIconInfo info;
	
	//Custom Tooltip
	local CustomTooltip TooltipInfo;
	local CustomTooltip TooltipInfo2;
	
	//ServerID
	m_arrID[DesIndex] = m_arrID[SrcIndex];
	
	//Window Tooltip
	m_PartyStatus[SrcIndex].GetTooltipCustomType(TooltipInfo);
	m_PartyStatus[DesIndex].SetTooltipCustomType(TooltipInfo);
	
	//Class Texture
	m_ClassIcon[DesIndex].SetTexture(m_ClassIcon[SrcIndex].GetTextureName());
	//Class Tooltip
	m_ClassIcon[SrcIndex].GetTooltipCustomType(TooltipInfo2);	
	m_ClassIcon[DesIndex].SetTooltipCustomType(TooltipInfo2);
	
	//CP,HP,MP
	m_BarCP[SrcIndex].GetValue(MaxValue, CurValue);
	m_BarCP[DesIndex].SetValue(MaxValue, CurValue);
	m_BarHP[SrcIndex].GetValue(MaxValue, CurValue);
	m_BarHP[DesIndex].SetValue(MaxValue, CurValue);
	m_BarMP[SrcIndex].GetValue(MaxValue, CurValue);
	m_BarMP[DesIndex].SetValue(MaxValue, CurValue);
	
	//BuffStatus
	m_StatusIconBuff[DesIndex].Clear();
	MaxRow = m_StatusIconBuff[SrcIndex].GetRowCount();
	for (Row=0; Row<MaxRow; Row++)
	{
		m_StatusIconBuff[DesIndex].AddRow();
		MaxCol = m_StatusIconBuff[SrcIndex].GetColCount(Row);
		for (Col=0; Col<MaxCol; Col++)
		{
			m_StatusIconBuff[SrcIndex].GetItem(Row, Col, info);
			m_StatusIconBuff[DesIndex].AddCol(Row, info);
		}
	}
	
	//DeBuffStatus
	m_StatusIconDeBuff[DesIndex].Clear();
	MaxRow = m_StatusIconDeBuff[SrcIndex].GetRowCount();
	for (Row=0; Row<MaxRow; Row++)
	{
		m_StatusIconDeBuff[DesIndex].AddRow();
		MaxCol = m_StatusIconDeBuff[SrcIndex].GetColCount(Row);
		for (Col=0; Col<MaxCol; Col++)
		{
			m_StatusIconDeBuff[SrcIndex].GetItem(Row, Col, info);
			m_StatusIconDeBuff[DesIndex].AddCol(Row, info);
		}
	}
}

//윈도우의 사이즈 조정
function ResizeWnd()
{
	local int idx;
	local Rect rectWnd;
	local bool bOption;
	
	// SetOptionBool과 페어. 이 변수는 PartyWndOption 에서 변경됨
	bOption = GetOptionBool( "Game", "SmallPartyWnd" );
	
	if (m_CurCount>0)
	{
		//윈도우 사이즈 변경
		rectWnd = m_wndTop.GetRect();
		
		m_wndTop.SetWindowSize(rectWnd.nWidth, NPARTYSTATUS_HEIGHT*m_CurCount);
		m_wndTop.SetResizeFrameSize(10, NPARTYSTATUS_HEIGHT*m_CurCount);
		if (bOption)	// 옵션창에 체크가 되어있으면 현재 (Compact) 윈도우를 활성화
			m_wndTop.ShowWindow();
		else
			m_wndTop.HideWindow();
		
		for (idx=0; idx<NPARTYSTATUS_MAXCOUNT; idx++)
		{
			if (idx<=m_CurCount-1)
			{
				m_PartyStatus[idx].ShowWindow();
			}
			else
			{
				m_PartyStatus[idx].HideWindow();
			}
		}
	}
	else	// 파티원이 존재하지 않으면 이 윈도우는 보이지 않는다.
	{
		m_wndTop.HideWindow();
	}
}

//ID로 몇번째 표시되는 파티원인지 구한다
function int FindPartyID(int ID)
{
	local int idx;
	for (idx=0; idx<NPARTYSTATUS_MAXCOUNT; idx++)
	{
		if (m_arrID[idx] == ID)
		{
			return idx;
		}
	}
	return -1;
}

//ADD	파티원 추가
function HandlePartyAddParty(string param)
{
	local int		ID;
	
	ParseInt(param, "ID", ID);
	if (ID>0)
	{
		m_CurCount++;
		ResizeWnd();
		
		m_arrID[m_CurCount-1] = ID;
		UpdateStatus(m_CurCount-1, param);
	}
}

//UPDATE	특정 파티원 업데이트.
function HandlePartyUpdateParty(string param)
{
	local int	ID;
	local int	idx;
	
	ParseInt(param, "ID", ID);
	if (ID>0)
	{
		idx = FindPartyID(ID);
		UpdateStatus(idx, param);	// 해당 인덱스의 파티원 정보를 갱신
	}
}

//DELETE	특정 파티원을 삭제.
function HandlePartyDeleteParty(string param)
{
	local int	ID;
	local int	idx;
	local int	i;
	
	ParseInt(param, "ID", ID);
	if (ID>0)
	{
		idx = FindPartyID(ID);
		if (idx>-1)
		{	
			for (i=idx; i<m_CurCount-1; i++)	// 삭제하려는 파티원 아래의 파티원들을 땡겨준다. 
			{
				CopyStatus(i, i+1);
			}
			ClearStatus(m_CurCount);
			m_CurCount--;
			ResizeWnd();	// 만약 파티원이 자신밖에 없다면 알아서 파티윈도우는 사라짐.
		}
	}
}

//DELETE ALL	그저 모두 지울뿐..
function HandlePartyDeleteAllParty()
{
	Clear();
}

//Set Info	특정 인덱스의 파티원의 정보 갱신. 서버 아이디 정보는 확인을 위해 필요하다.
function UpdateStatus(int idx, string param)
{
	local string	Name;
	local int		ID;
	local int		CP;
	local int		MaxCP;
	local int		HP;
	local int		MaxHP;
	local int		MP;
	local int		MaxMP;
	local int		ClassID;
	local int		MasterID;
	
	//Custom Tooltip
	local CustomTooltip TooltipInfo;
	local CustomTooltip TooltipInfo2;
		
	if (idx<0 || idx>=NPARTYSTATUS_MAXCOUNT)
		return;
	
	ParseString(param, "Name", Name);
	ParseInt(param, "ID", ID);
	ParseInt(param, "CurCP", CP);
	ParseInt(param, "MaxCP", MaxCP);
	ParseInt(param, "CurHP", HP);
	ParseInt(param, "MaxHP", MaxHP);
	ParseInt(param, "CurMP", MP);
	ParseInt(param, "MaxMP", MaxMP);
	ParseInt(param, "ClassID", ClassID);
	
	//업데이트일경우에는 파티장 정보가 안날라온다.
	if (ParseInt(param, "MasterID", MasterID))
		m_MasterID = MasterID;
	
	//Window Tooltip
	TooltipInfo.DrawList.length = 1;
	TooltipInfo.DrawList[0].eType = DIT_TEXT;
	TooltipInfo.DrawList[0].t_bDrawOneLine = true;
	if (m_MasterID >0 && m_MasterID==ID)
	{	
		TooltipInfo.DrawList[0].t_strText =  Name $ "(" $ GetSystemString(408) $ ")";
	}
	else
	{
		TooltipInfo.DrawList[0].t_strText = Name;
	}
	m_PartyStatus[idx].SetTooltipCustomType(TooltipInfo);
	
	//직업 아이콘
	m_ClassIcon[idx].SetTexture(GetClassIconName(ClassID));
	
	//Custom Tooltip
	TooltipInfo2.DrawList.length = 2;
	TooltipInfo2.DrawList[0].eType = DIT_TEXT;
	TooltipInfo2.DrawList[0].t_bDrawOneLine = true;
	if (m_MasterID >0 && m_MasterID==ID)
	{	
		TooltipInfo2.DrawList[0].t_strText =  Name $ "(" $ GetSystemString(408) $ ")";
	}
	else
	{
		TooltipInfo2.DrawList[0].t_strText = Name;
	}
	
	TooltipInfo2.DrawList[1].eType = DIT_TEXT;
	TooltipInfo2.DrawList[1].nOffSetY = 2;
	TooltipInfo2.DrawList[1].t_bDrawOneLine = true;
	TooltipInfo2.DrawList[1].bLineBreak = true;
	
	TooltipInfo2.DrawList[1].t_strText = GetClassStr(ClassID) $ " - " $ GetClassType(ClassID);
	TooltipInfo2.DrawList[1].t_color.R = 128;
	TooltipInfo2.DrawList[1].t_color.G = 128;
	TooltipInfo2.DrawList[1].t_color.B = 128;
	TooltipInfo2.DrawList[1].t_color.A = 255;
	m_ClassIcon[idx].SetTooltipCustomType(TooltipInfo2);
	
	//각종 게이지
	UpdateCPBar(idx, CP, MaxCP);
	UpdateHPBar(idx, HP, MaxHP);
	UpdateMPBar(idx, MP, MaxMP);
}

//버프리스트정보
function HandlePartySpelledList(string param)
{
	local int i;
	local int idx;
	local int ID;
	local int Max;
	
	local int BuffCnt;
	local int BuffCurRow;
	
	local int DeBuffCnt;
	local int DeBuffCurRow;
	
	local StatusIconInfo info;
	
	DeBuffCurRow = -1;
	BuffCurRow = -1;
	
	ParseInt(param, "ID", ID);
	if (ID<1)
	{
		return;
	}
	
	idx = FindPartyID(ID);
	if (idx<0)
	{
		return;
	}
	
	//버프 초기화
	m_StatusIconBuff[idx].Clear();
	m_StatusIconDeBuff[idx].Clear();
	
	//info 초기화
	info.Size = 10;
	info.bShow = true;
		
	ParseInt(param, "Max", Max);
	
	for (i=0; i<Max; i++)
	{
		ParseInt(param, "SkillID_" $ i, info.ClassID);
		ParseInt(param, "Level_" $ i, info.Level);
		
		if (info.ClassID>0)
		{
			info.IconName = class'UIDATA_SKILL'.static.GetIconName(info.ClassID, info.Level);
			
			if (IsDeBuff( info.ClassID, info.Level) == true )
			{
				if (DeBuffCnt%NSTATUSICON_MAXCOL == 0)
				{
					DeBuffCurRow++;
					m_StatusIconDeBuff[idx].AddRow();
				}
				m_StatusIconDeBuff[idx].AddCol(DeBuffCurRow, info);	
				DeBuffCnt++;
			}
			else
			{
				if (BuffCnt%NSTATUSICON_MAXCOL == 0)
				{
					BuffCurRow++;
					m_StatusIconBuff[idx].AddRow();
				}
				m_StatusIconBuff[idx].AddCol(BuffCurRow, info);	
				BuffCnt++;
			}
		}
	}
	UpdateBuff();
}

//버프아이콘 표시
function HandleShowBuffIcon(string param)
{
	local int nShow;
	ParseInt(param, "Show", nShow);
	
	m_CurBf = m_CurBf + 1;
	
	
	if (m_CurBf > 2)
	{
		m_CurBf = 0;
	}
	
	SetBuffButtonTooltip();
	
	switch (m_CurBf)
	{
		case 1:
		UpdateBuff();
		break;
		case 2:
		UpdateBuff();
		break;
		case 0:
		m_CurBf = 0;
		UpdateBuff();
	}
}

// 버튼클릭 이벤트
function OnClickButton( string strID )
{
	local PartyWnd script;
	script = PartyWnd( GetScript("PartyWnd") );
	switch( strID )
	{
	case "btnBuff":		//버프버튼 클릭시 
		OnBuffButton();
		script.OnBuffButton();
		break;
	case "btnOption":	// 옵션 버튼 클릭시
		OnOpenPartyWndOption();
	}
}

// 옵션버튼 클릭시 불리는 함수
function OnOpenPartyWndOption()
{
	local PartyWndOption script;
	script = PartyWndOption( GetScript("PartyWndOption") );
	script.ShowPartyWndOption();
	m_PartyOption.SetAnchor("PartyWndCompact.PartyStatusWnd0", "TopRight", "TopLeft", 5, 5);
}

// 사용되지 않는 함수인듯.  PartyWnd, PartyWndCompact, PartyWndOption 에서 사용하지 않음
//		function OnCompactButton()
//		{
//			local int idx;
//			local int Size;
//			
//			if (m_bCompact)
//			{
//				Size = 16;
//			}
//			else
//			{
//				Size = 10;
//			}
//			m_bCompact = !m_bCompact;
//			
//			for (idx=0; idx<NPARTYSTATUS_MAXCOUNT; idx++)
//			{
//				m_StatusIconBuff[idx].SetIconSize(Size);	
//				m_StatusIconDeBuff[idx].SetIconSize(Size);	
//			}
//		}

// 버프버튼을 눌렀을 경우 실행되는 함수
function OnBuffButton()
{
	m_CurBf = m_CurBf + 1;
	
	//3가지 모드가 전환된다.
	if (m_CurBf > 2)
	{
		m_CurBf = 0;
	}
	
	// 툴팁표시
	SetBuffButtonTooltip();
	
	UpdateBuff();
}

// 버프표시, 디버프 표시,  끄기 3가지모드를 전환한다.
function UpdateBuff()
{
	local int idx;
	if (m_CurBf == 1)
	{
		for (idx=0; idx<NPARTYSTATUS_MAXCOUNT; idx++)
		{
			m_StatusIconBuff[idx].ShowWindow();	
			m_StatusIconDeBuff[idx].HideWindow();	
			
		}
	}
	else if (m_CurBf == 2)
	{
		for (idx=0; idx<NPARTYSTATUS_MAXCOUNT; idx++)
		{
			m_StatusIconBuff[idx].HideWindow();	
			m_StatusIconDeBuff[idx].ShowWindow();	
			
		}
	}
	else 
	{
		for (idx=0; idx<NPARTYSTATUS_MAXCOUNT; idx++)
		{
			m_StatusIconBuff[idx].HideWindow();	
			m_StatusIconDeBuff[idx].HideWindow();	
		}
	}
}

//CP바 갱신
function UpdateCPBar(int idx, int Value, int MaxValue)
{
	m_BarCP[idx].SetValue(MaxValue, Value);
}

//HP바 갱신
function UpdateHPBar(int idx, int Value, int MaxValue)
{
	m_BarHP[idx].SetValue(MaxValue, Value);
}

//MP바 갱신
function UpdateMPBar(int idx, int Value, int MaxValue)
{
	m_BarMP[idx].SetValue(MaxValue, Value);
}

//파티원 클릭 했을시..
function OnLButtonDown( WindowHandle a_WindowHandle, int X, int Y )
{
	local Rect rectWnd;
	local int idx;
	
	rectWnd = m_wndTop.GetRect();
	if (X > rectWnd.nX + 30)
	{
		idx = (Y-rectWnd.nY) / NPARTYSTATUS_HEIGHT;
		RequestTargetUser(m_arrID[idx]);
	}
}

//파티원의 어시스트
function OnRButtonUp( int X, int Y )
{
	local Rect rectWnd;
	local UserInfo userinfo;
	local int idx;
	
	rectWnd = m_wndTop.GetRect();
	if (X > rectWnd.nX + 30)
	{
		if (GetPlayerInfo(userinfo))
		{
			idx = (Y-rectWnd.nY) / NPARTYSTATUS_HEIGHT;
			RequestAssist(m_arrID[idx], userinfo.Loc);
		}
	}
}

// 버프 툴팁을 설정한다.
function SetBuffButtonTooltip()
{
	local int idx;
	switch (m_CurBf)
	{
		case 0:	idx = 1496;
		break;
		case 1:	idx = 1497;
		break;
		case 2:	idx = 1498;
		break;
	}
	btnBuff.SetTooltipCustomType(MakeTooltipSimpleText(GetSystemString(idx)));
}
