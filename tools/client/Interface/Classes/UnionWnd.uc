class UnionWnd extends UICommonAPI;

var bool m_bChOpened;

//Handle List
var WindowHandle	Me;
var WindowHandle	PartyMemberWnd;

var TextBoxHandle	txtOwner;
var TextBoxHandle	txtRoutingType;
var TextBoxHandle	txtCountInfo;
var ButtonHandle 	banBtn;
var ButtonHandle		quitBtn;
var ListCtrlHandle	lstParty;

var string	m_UserName;
var int		m_PartyNum;
var int		m_PartyMemberNum;
var int		m_SearchedMasterID;

function OnLoad()
{
	RegisterEvent( EV_CommandChannelStart );
	RegisterEvent( EV_CommandChannelEnd );
	RegisterEvent( EV_CommandChannelInfo );
	RegisterEvent( EV_CommandChannelPartyList );
	RegisterEvent( EV_CommandChannelPartyUpdate );
	RegisterEvent( EV_CommandChannelRoutingType );
	
	m_bChOpened = false;
	m_PartyNum = 0;
	m_PartyMemberNum = 0;
	m_SearchedMasterID = 0;
	
	Me = GetHandle( "UnionWnd" );
	PartyMemberWnd = GetHandle( "UnionDetailWnd" );
	
	txtOwner = TextBoxHandle( GetHandle( "UnionWnd.txtOwner" ) );
	txtRoutingType = TextBoxHandle( GetHandle( "UnionWnd.txtRoutingType" ) );
	txtCountInfo = TextBoxHandle( GetHandle( "UnionWnd.txtCountInfo" ) );
	lstParty = ListCtrlHandle( GetHandle( "UnionWnd.lstParty" ) );
	banBtn = ButtonHandle( GetHandle("UnionWnd.btnBan"));
	quitBtn = ButtonHandle( GetHandle("UnionWnd.btnOut"));
}

function OnShow()
{
	local UserInfo a_UserInfo;
	GetPlayerInfo( a_UserInfo );
	m_UserName = a_UserInfo.Name;
	PartyMemberWnd.HideWindow();
}
	
function OnEnterState( name a_PreStateName )
{
	if (m_bChOpened)
	{
		Me.ShowWindow();
	}
	else
	{
		Me.HideWindow();
	}
}

function OnEvent(int Event_ID, string param)
{
	if (Event_ID == EV_CommandChannelStart)
	{
		HandleCommandChannelStart();
	}
	else if (Event_ID == EV_CommandChannelEnd)
	{
		HandleCommandChannelEnd();
	}
	else if (Event_ID == EV_CommandChannelInfo)
	{
		HandleCommandChannelInfo(param);
	}
	else if (Event_ID == EV_CommandChannelPartyList)
	{
		HandleCommandChannelPartyList(param);
	}
	else if (Event_ID == EV_CommandChannelPartyUpdate)
	{
		HandleCommandChannelPartyUpdate(param);
	}
	else if (Event_ID == EV_CommandChannelRoutingType)
	{
		HandleCommandChannelRoutingType(param);
	}
}

//파티장 더블클릭
function OnDBClickListCtrlRecord( String strID )
{
	if (strID == "lstParty")
		RequestPartyMember(true);
}

//초기화
function Clear()
{
	MemberClear();
	txtOwner.SetText("");
	txtRoutingType.SetText(GetSystemString(1383));
	txtCountInfo.SetText("");
}

//파티멤버 초기화
function MemberClear()
{
	lstParty.DeleteAllItem();
}

function OnClickButton( string strID )
{
	switch( strID )
	{
	case "btnRefresh":
		OnRefreshClick();
		break;
	case "btnBan":
		OnBanClick();
		break;
	case "btnOut":
		OnOutClick();
		break;
	case "btnMemberInfo":
		OnMemberInfoClick();
		break;
	}
}

//[새로고침]
function OnRefreshClick()
{
	RequestNewInfo();
}

function RequestNewInfo()
{
	class'CommandChannelAPI'.static.RequestCommandChannelInfo();
}

//[추방]
function OnBanClick()
{
	local int idx;
	local LVDataRecord record;
	local string PartyMasterName;
	
	idx = lstParty.GetSelectedIndex();
	if (idx>-1)
	{
		record = lstParty.GetRecord(idx);
		PartyMasterName = record.LVDataList[0].szData;
		if (Len(PartyMasterName)>0)
		{
			class'CommandChannelAPI'.static.RequestCommandChannelBanParty(PartyMasterName);
		}
	}
}

//[탈퇴]
function OnOutClick()
{
	class'CommandChannelAPI'.static.RequestCommandChannelWithdraw();
}

//[파티정보]
function OnMemberInfoClick()
{
	if (PartyMemberWnd.IsShowWindow())
		PartyMemberWnd.HideWindow();
	else
		RequestPartyMember(true);
}

function RequestPartyMember(bool bShowWindow)
{
	
	local LVDataRecord Record;
	local string PartyMasterName;
	local int MasterID;
	
	local UnionDetailWnd Script;
	Script = UnionDetailWnd(GetScript("UnionDetailWnd"));
	
	m_SearchedMasterID = 0;
	Record = lstParty.GetSelectedRecord();
	PartyMasterName = Record.LVDataList[0].szData;
	MasterID = Record.nReserved1;
	
	if (Len(PartyMasterName)>0 && MasterID>0)
	{
		if (bShowWindow)
		{
			if (!PartyMemberWnd.IsShowWindow())
				PartyMemberWnd.ShowWindow();
		}
		
		m_SearchedMasterID = MasterID;
		Script.SetMasterInfo(PartyMasterName, MasterID);
		class'CommandChannelAPI'.static.RequestCommandChannelPartyMembersInfo(MasterID);
	}
}

//지휘채널 시작
function HandleCommandChannelStart()
{
	Me.ShowWindow();
	Me.SetFocus();
	m_bChOpened = true;
	
	RequestNewInfo();
	class'UIAPI_WINDOW'.static.DisableWindow("UnionWnd.btnBan");
	class'UIAPI_WINDOW'.static.DisableWindow("UnionWnd.btnOut");
}

//지휘채널 종료
function HandleCommandChannelEnd()
{
	Me.HideWindow();
	Clear();
	m_bChOpened = false;
}

//지휘채널 정보
function HandleCommandChannelInfo(string param)
{
	local string	OwnerName;
	local int		RoutingType;
	local int		PartyNum;
	local int		PartyMemberNum;
	
	MemberClear();
	
	ParseString(param, "OwnerName" ,OwnerName);
	ParseInt(param, "RoutingType" ,RoutingType);
	ParseInt(param, "PartyNum" ,PartyNum);
	ParseInt(param, "PartyMemberNum" ,PartyMemberNum);
	
	m_PartyNum = PartyNum;
	m_PartyMemberNum = PartyMemberNum;
	
	txtOwner.SetText(OwnerName);
	UpdateRoutingType(RoutingType);
	UpdateCountInfo();
	
	if (OwnerName == m_UserName)
	{
		class'UIAPI_WINDOW'.static.EnableWindow("UnionWnd.btnBan");
	}
	
}

//파티멤버 리스트
function HandleCommandChannelPartyList(string param)
{
	local LVDataRecord	record;
	
	local string MasterName;
	local int MasterID;
	local int PartyNum;
	local int TotalCount;
	
	ParseString(param, "MasterName", MasterName);
	ParseInt(param, "MasterID", MasterID);
	ParseInt(param, "PartyNum", PartyNum);
	
	record.LVDataList.length = 2;
	record.nReserved1 = MasterID;
	record.LVDataList[0].szData = MasterName;
	record.LVDataList[1].szData = string(PartyNum);
	lstParty.InsertRecord(record);
	
	//최근 검색한 파티장ID와 일치하고 파티원정보창이 보여지고 있으면
	//추가한 레코드를 선택시키고, 목록을 갱신해준다.
	if (m_SearchedMasterID>0 && m_SearchedMasterID==MasterID)
	{
		if (PartyMemberWnd.IsShowWindow())
		{
			TotalCount = lstParty.GetRecordCount();
			if (TotalCount>0)
				lstParty.SetSelectedIndex(TotalCount-1, false);	
			RequestPartyMember(false);
		}
	}
	
	if (MasterName == m_UserName)
		class'UIAPI_WINDOW'.static.EnableWindow("UnionWnd.btnOut");
}

//파티정보 갱신
function HandleCommandChannelPartyUpdate(string param)
{
	local LVDataRecord	record;
	local int SearchIdx;
	
	local string MasterName;
	local int MasterID;
	local int MemberCount;
	local int Type;
	
	local UnionDetailWnd Script;
	
	ParseString(param, "MasterName", MasterName);
	ParseInt(param, "MasterID", MasterID);
	ParseInt(param, "MemberCount", MemberCount);
	ParseInt(param, "Type", Type);
	
	if (MasterID<1)
		return;
	
	switch (Type)
	{
	case 0:	//leave
		SearchIdx = FindMasterID(MasterID);
		if (SearchIdx>-1)
		{
			record = lstParty.GetRecord(SearchIdx);
			MemberCount = int(record.LVDataList[1].szData);
			lstParty.DeleteRecord(SearchIdx);
			
			m_PartyNum--;
			m_PartyMemberNum = m_PartyMemberNum - MemberCount;
			
			if (PartyMemberWnd.IsShowWindow())
			{
				Script = UnionDetailWnd(GetScript("UnionDetailWnd"));
				if (MasterID == Script.GetMasterID())
				{
					Script.Clear();
					PartyMemberWnd.HideWindow();
				}
			}	
		}
		break;
	case 1: //join
		record.LVDataList.length = 2;
		record.nReserved1 = MasterID;
		record.LVDataList[0].szData = MasterName;
		record.LVDataList[1].szData = string(MemberCount);
		lstParty.InsertRecord(record);
		m_PartyNum++;
		m_PartyMemberNum = m_PartyMemberNum + MemberCount;
		break;
	}
	
	UpdateCountInfo();

	if (MasterName == m_UserName)
		class'UIAPI_WINDOW'.static.EnableWindow("UnionWnd.btnOut");
}

function HandleCommandChannelRoutingType(string param)
{
	local int RoutingType;
	
	ParseInt(param, "RoutingType" ,RoutingType);
	UpdateRoutingType(RoutingType);
}

//루팅타입 설정
function UpdateRoutingType(int Type)
{
	if (Type==0)
	{
		txtRoutingType.SetText(GetSystemString(1383));
	}
	else if (Type==1)
	{
		txtRoutingType.SetText(GetSystemString(1384));
	}
}

function int FindMasterID(int MasterID)
{
	local int idx;
	local LVDataRecord	record;
	local int SearchIdx;
	
	SearchIdx = -1;
	for (idx=0; idx<lstParty.GetRecordCount(); idx++)
	{
		record = lstParty.GetRecord(idx);
		if (record.nReserved1 == MasterID)
		{
			SearchIdx = idx;
			break;
		}
	}
	return SearchIdx;
}

//파티인원 정보
function UpdateCountInfo()
{
	txtCountInfo.SetText(String(m_PartyNum) $ GetSystemString(440) $ " / " $ m_PartyMemberNum $ GetSystemString(1013));
}

//파티원 수 갱신
function UpdatePartyMemberCount(int MasterID, int MemberCount)
{
	local int idx;
	local LVDataRecord record;
	
	idx = FindMasterID(MasterID);
	if (idx>-1)
	{
		record = lstParty.GetRecord(idx);
		m_PartyMemberNum = m_PartyMemberNum - int(record.LVDataList[1].szData);
		m_PartyMemberNum = m_PartyMemberNum + MemberCount;
		record.LVDataList[1].szData = string(MemberCount);
		lstParty.ModifyRecord(idx, record);
	}
	UpdateCountInfo();
}

//스테이트 전환 처리
function OnExitState( name a_NextStateName )
{
	if( a_NextStateName == 'LoadingState' )
		HandleCommandChannelEnd();
}
