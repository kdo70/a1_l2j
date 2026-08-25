class UnionDetailWnd extends UICommonAPI;

var int m_MasterID;

//Handle List
var WindowHandle	Me;
var TextBoxHandle	txtMasterName;
var ListCtrlHandle	lstPartyMember;

function OnLoad()
{
	RegisterEvent( EV_CommandChannelPartyMember );
	
	Me = GetHandle( "UnionDetailWnd" );
	txtMasterName = TextBoxHandle( GetHandle( "UnionDetailWnd.txtMasterName" ) );
	lstPartyMember = ListCtrlHandle( GetHandle( "UnionDetailWnd.lstPartyMember" ) );
}

function OnEvent(int Event_ID, string param)
{
	if (Event_ID == EV_CommandChannelPartyMember)
	{
		HandleCommandChannelPartyMember(param);
	}
}

function SetMasterInfo(string MasterName, int MasterID)
{
	txtMasterName.SetText(MasterName);
	m_MasterID = MasterID;
}

function int GetMasterID()
{
	return m_MasterID;
}

//초기화
function Clear()
{
	lstPartyMember.DeleteAllItem();
	txtMasterName.SetText("");
}

function OnClickButton( string strID )
{
	switch( strID )
	{
	case "btnClose":
		OnCloseClick();
		break;
	}
}

//[닫기]
function OnCloseClick()
{
	Me.HideWindow();
}

//파티원 클릭
function OnDBClickListCtrlRecord( String strID )
{
	local UserInfo userinfo;
	local LVDataRecord Record;
	local int ServerID;
	
	if (strID == "lstPartyMember")
	{
		Record = lstPartyMember.GetSelectedRecord();
		ServerID = Record.nReserved1;
		
		if (ServerID>0)
		{
			if (GetPlayerInfo(userinfo))
			{
				if (IsPKMode())
				{
					RequestAttack(ServerID, userinfo.Loc);
				}
				else
				{
					RequestAction(ServerID, userinfo.Loc);
				}
			}
		}
	}
}

//파티구성원들의 리스트
function HandleCommandChannelPartyMember(string param)
{
	local LVDataRecord	record;
	
	local int idx;
	local int MemberCount;
	
	local string Name;
	local int ClassID;
	local int ServerID;
	
	local UnionWnd Script;
	
	lstPartyMember.DeleteAllItem();
	
	ParseInt(param, "MemberCount", MemberCount);
	for (idx=0; idx<MemberCount; idx++)
	{
		ParseString(param, "Name_" $ idx, Name);
		ParseInt(param, "ClassID_" $ idx, ClassID);
		ParseInt(param, "ServerID_" $ idx, ServerID);
		
		if (Len(Name)>0)
		{
			record.LVDataList.length = 2;
			record.nReserved1 = ServerID;
			record.LVDataList[0].szData = Name;
			record.LVDataList[1].nTextureWidth = 11;
			record.LVDataList[1].nTextureHeight = 11;
			record.LVDataList[1].szData = String(ClassID);
			record.LVDataList[1].szTexture = GetClassIconName(ClassID);
			lstPartyMember.InsertRecord(record);	
		}
	}
	
	//메인창의 파티원수 갱신
	Script = UnionWnd(GetScript("UnionWnd"));
	Script.UpdatePartyMemberCount(m_MasterID, MemberCount);
}
