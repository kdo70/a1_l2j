class AbnormalStatusWnd extends UIScript;

const NSTATUSICON_FRAMESIZE = 12;
const NSTATUSICON_MAXCOL = 12;

var int m_NormalStatusRow;
var int m_EtcStatusRow;
var int m_ShortStatusRow;

var bool m_bOnCurState;

var WindowHandle		Me;
var StatusIconHandle	StatusIcon;

function OnLoad()
{
	RegisterEvent( EV_AbnormalStatusNormalItem );
	RegisterEvent( EV_AbnormalStatusEtcItem );
	RegisterEvent( EV_AbnormalStatusShortItem );
	
	RegisterEvent( EV_Restart );
	RegisterEvent( EV_Die );
	RegisterEvent( EV_ShowReplayQuitDialogBox );
	RegisterEvent( EV_LanguageChanged );
	
	m_NormalStatusRow = -1;
	m_EtcStatusRow = -1;
	m_ShortStatusRow = -1;
	
	m_bOnCurState = false;
	
	InitHandle();
}

function InitHandle()
{
	Me = GetHandle( "AbnormalStatusWnd" );
	StatusIcon = StatusIconHandle( GetHandle( "AbnormalStatusWnd.StatusIcon" ) );
}

function OnEnterState( name a_PreStateName )
{
	m_bOnCurState = true;
	UpdateWindowSize();
}

function OnExitState( name a_NextStateName )
{
	m_bOnCurState = false;
}

function OnEvent(int Event_ID, string param)
{
	if (Event_ID == EV_AbnormalStatusNormalItem)
	{
		HandleAddNormalStatus(param);
	}
	else if (Event_ID == EV_AbnormalStatusEtcItem)
	{
		HandleAddEtcStatus(param);
	}
	else if (Event_ID == EV_AbnormalStatusShortItem)
	{
		HandleAddShortStatus(param);
	}
	else if (Event_ID == EV_Restart)
	{
		HandleRestart();
	}
	else if (Event_ID == EV_Die)
	{
		HandleDie();
	}
	else if (Event_ID == EV_ShowReplayQuitDialogBox)
	{
		HandleShowReplayQuitDialogBox();
	}
	else if (Event_ID == EV_LanguageChanged)
	{
		HandleLanguageChanged();
	}
}

//리스타트를 하면 올클리어
function HandleRestart()
{
	ClearAll();
}

//죽었으면, Normal/Short를 클리어
function HandleDie()
{
	ClearStatus(false, false);
	ClearStatus(false, true);
}

function HandleShowReplayQuitDialogBox()
{
	Me.HideWindow();
}

//강제로 UI가 보여질 때, 프레임이 보여지는 것을 막는다
function OnShow()
{
	local int RowCount;
	RowCount = StatusIcon.GetRowCount();
	if (RowCount<1)
	{
		Me.HideWindow();
	}
}

//특정한 Status들을 초기화한다.
function ClearStatus(bool bEtcItem, bool bShortItem)
{
	local int i;
	local int j;
	local int RowCount;
	local int RowCountTmp;
	local int ColCount;
	local StatusIconInfo info;
	
	//Normal아이템을 초기화하는 경우라면, Normal아이템의 현재행을 초기화한다.
	if (bEtcItem==false && bShortItem==false)
	{
		m_NormalStatusRow = -1;
	}
	//Etc아이템을 초기화하는 경우라면, Etc아이템의 현재행을 초기화한다.
	if (bEtcItem==true && bShortItem==false)
	{
		m_EtcStatusRow = -1;
	}
	//Short아이템을 초기화하는 경우라면, Short아이템의 현재행을 초기화한다.
	if (bEtcItem==false && bShortItem==true)
	{
		m_ShortStatusRow = -1;
	}
	
	RowCount = StatusIcon.GetRowCount();
	for (i=0; i<RowCount; i++)
	{
		ColCount = StatusIcon.GetColCount(i);
		for (j=0; j<ColCount; j++)
		{
			StatusIcon.GetItem(i, j, info);
			
			//제대로 아이템을 얻어왔다면
			if (info.ClassID>0)
			{
				if (info.bEtcItem==bEtcItem && info.bShortItem==bShortItem)
				{
					StatusIcon.DelItem(i, j);
					j--;
					ColCount--;
					
					RowCountTmp = StatusIcon.GetRowCount();
					if (RowCountTmp != RowCount)
					{
						i--;
						RowCount--;
					}
				}
			}
		}
	}
}

function ClearAll()
{
	ClearStatus(false, false);
	ClearStatus(true, false);
	ClearStatus(false, true);
}

//Normal Status 추가
function HandleAddNormalStatus(string param)
{
	local int i;
	local int Max;
	local int BuffCnt;
	local StatusIconInfo info;
	
	//NormalStatus 초기화
	ClearStatus(false, false);
	
	//info 초기화
	info.Size = 24;
	info.BackTex = "L2UI.EtcWndBack.AbnormalBack";
	info.bShow = true;
	info.bEtcItem = false;
	info.bShortItem = false;

	BuffCnt = 0;
	ParseInt(param, "Max", Max);
	for (i=0; i<Max; i++)
	{
		ParseInt(param, "SkillID_" $ i, info.ClassID);
		ParseInt(param, "SkillLevel_" $ i, info.Level);
		ParseInt(param, "RemainTime_" $ i, info.RemainTime);
		ParseString(param, "Name_" $ i, info.Name);
		ParseString(param, "IconName_" $ i, info.IconName);
		ParseString(param, "Description_" $ i, info.Description);
		
		if (info.ClassID>0)
		{
			//한줄에 NSTATUSICON_MAXCOL만큼 표시한다.
			if (BuffCnt%NSTATUSICON_MAXCOL == 0)
			{
				m_NormalStatusRow++;
				StatusIcon.InsertRow(m_NormalStatusRow);
			}
			
			StatusIcon.AddCol(m_NormalStatusRow, info);	
			
			BuffCnt++;
		}
	}
	
	//현재 Etc, Short아이템이 표시되고 있는 중이라면, 행이 증가/삭제 되었을 경우가 있기 때문에
	if (m_EtcStatusRow>-1)
	{
		m_EtcStatusRow = m_NormalStatusRow + 1;
	}
	if (m_ShortStatusRow>-1)
	{
		m_ShortStatusRow = m_NormalStatusRow + 1;
	}
	
	UpdateWindowSize();
}

//Etc Status 추가
function HandleAddEtcStatus(string param)
{
	local int i;
	local int Max;
	local int BuffCnt;
	local int CurRow;
	local bool bNewRow;
	local StatusIconInfo info;
	
	//EtcStatus 초기화
	ClearStatus(true, false);
	
	//info 초기화
	info.Size = 24;
	info.BackTex = "L2UI.EtcWndBack.AbnormalBack";
	info.bShow = true;
	info.bEtcItem = true;
	info.bShortItem = false;
	
	//추가 시작점(Normal아이템 다음줄, Short아이템 다음 열에 추가한다)
	if (m_ShortStatusRow>-1)
	{
		bNewRow = false;
		CurRow = m_ShortStatusRow;
	}
	else
	{
		bNewRow = true;
		CurRow = m_NormalStatusRow;
	}
	
	BuffCnt = 0;
	ParseInt(param, "Max", Max);
	for (i=0; i<Max; i++)
	{
		ParseInt(param, "SkillID_" $ i, info.ClassID);
		ParseInt(param, "SkillLevel_" $ i, info.Level);
		ParseInt(param, "RemainTime_" $ i, info.RemainTime);
		ParseString(param, "Name_" $ i, info.Name);
		ParseString(param, "IconName_" $ i, info.IconName);
		ParseString(param, "Description_" $ i, info.Description);
		
		if (info.ClassID>0)
		{
			//Etc아이템은 최대 한 행에만 표시한다.(Short아이템 뒤에...)
			if (bNewRow)
			{
				bNewRow = !bNewRow;
				CurRow++;
				StatusIcon.InsertRow(CurRow);
			}
			StatusIcon.AddCol(CurRow, info);
			
			m_EtcStatusRow = CurRow;
			
			BuffCnt++;
		}
	}
	
	UpdateWindowSize();
}

//Short Status 추가
function HandleAddShortStatus(string param)
{
	local int i;
	local int Max;
	local int BuffCnt;
	local int CurRow;
	local int CurCol;
	local bool bNewRow;
	local StatusIconInfo info;
	
	//ShortStatus 초기화
	ClearStatus(false, true);
	
	//info 초기화
	info.Size = 24;
	info.BackTex = "L2UI.EtcWndBack.AbnormalBack";
	info.bShow = true;
	info.bEtcItem = false;
	info.bShortItem = true;
	
	//추가 시작점(Normal아이템 다음줄, Etc아이템 전에 추가한다)
	CurCol = -1;
	if (m_EtcStatusRow>-1)
	{
		bNewRow = false;
		CurRow = m_EtcStatusRow;
	}
	else
	{
		bNewRow = true;
		CurRow = m_NormalStatusRow;
	}
	
	BuffCnt = 0;
	ParseInt(param, "Max", Max);
	for (i=0; i<Max; i++)
	{
		ParseInt(param, "SkillID_" $ i, info.ClassID);
		ParseInt(param, "SkillLevel_" $ i, info.Level);
		ParseInt(param, "RemainTime_" $ i, info.RemainTime);
		ParseString(param, "Name_" $ i, info.Name);
		ParseString(param, "IconName_" $ i, info.IconName);
		ParseString(param, "Description_" $ i, info.Description);
			
		if (info.ClassID>0)
		{
			//Short아이템은 최대 한 행에만 표시한다.(Etc아이템과 함께..)
			if (bNewRow)
			{
				bNewRow = !bNewRow;
				CurRow++;
				StatusIcon.InsertRow(CurRow);
			}
			CurCol++;
			StatusIcon.InsertCol(CurRow, CurCol, info);
			
			m_ShortStatusRow = CurRow;
			
			BuffCnt++;
		}
	}
	
	UpdateWindowSize();
}

//윈도우 사이즈 갱신
function UpdateWindowSize()
{
	local int RowCount;
	local Rect rectWnd;
	
	RowCount = StatusIcon.GetRowCount();
	if (RowCount>0)
	{
		//현재 GameState가 아니면 윈도우를 보이지 않는다.
		if (m_bOnCurState)
		{
			Me.ShowWindow();
		}
		else
		{
			Me.HideWindow();
		}
		
		//윈도우 사이즈 변경
		rectWnd = StatusIcon.GetRect();
		Me.SetWindowSize(rectWnd.nWidth + NSTATUSICON_FRAMESIZE, rectWnd.nHeight);
		
		//세로 프레임 사이즈 변경
		Me.SetFrameSize(NSTATUSICON_FRAMESIZE, rectWnd.nHeight);	
	}
	else
	{
		Me.HideWindow();
	}
}

//언어 변경 처리
function HandleLanguageChanged()
{
	local int i;
	local int j;
	local int RowCount;
	local int ColCount;
	local StatusIconInfo info;
	
	RowCount = StatusIcon.GetRowCount();
	for (i=0; i<RowCount; i++)
	{
		ColCount = StatusIcon.GetColCount(i);
		for (j=0; j<ColCount; j++)
		{
			StatusIcon.GetItem(i, j, info);
			if (info.ClassID>0)
			{
				info.Name = class'UIDATA_SKILL'.static.GetName( info.ClassID, info.Level );
				info.Description = class'UIDATA_SKILL'.static.GetDescription( info.ClassID, info.Level );
				StatusIcon.SetItem(i, j, info);
			}
		}
	}
}
