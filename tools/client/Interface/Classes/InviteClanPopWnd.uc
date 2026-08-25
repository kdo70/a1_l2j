class InviteClanPopWnd extends UIScript;

var string m_userName;
var array<int>	m_knighthoodIndex;

function OnLoad()
{
	m_knighthoodIndex.Length = CLAN_KNIGHTHOOD_COUNT;
	m_knighthoodIndex[0] = 0;
	m_knighthoodIndex[1] = 100;
	m_knighthoodIndex[2] = 200;
	m_knighthoodIndex[3] = 1001;
	m_knighthoodIndex[4] = 1002;
	m_knighthoodIndex[5] = 2001;
	m_knighthoodIndex[6] = 2002;
	m_knighthoodIndex[7] = -1;

	registerEvent( EV_GamingStateExit );
}

function OnShow()
{
	InitializeComboBox();
}

function OnEvent( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	case EV_GamingStateExit:
		class'UIAPI_WINDOW'.static.HideWindow("InviteClanPopWnd");
		break;
	default:
		break;
	}
}

function OnClickButton( string strID )
{
	if( strID == "InviteClandPopOkBtn" )
	{
		AskJoin();
		class'UIAPI_WINDOW'.static.HideWindow("InviteClanPopWnd");
	}
	else if( strID == "InviteClandPopCancelBtn" )
	{
		class'UIAPI_WINDOW'.static.HideWindow("InviteClanPopWnd");
	}
}

function AskJoin()
{
	local UserInfo user;
	local int	index;
	local int	knighthoodID;

	if( GetTargetInfo( user ) )
	{
		if( user.nID > 0 )
		{
			index = class'UIAPI_COMBOBOX'.static.GetSelectedNum("InviteClanPopWnd.ComboboxInviteClandPopWnd");
			if( index >= 0 )
			{
				knighthoodID = class'UIAPI_COMBOBOX'.static.GetReserved("InviteClanPopWnd.ComboboxInviteClandPopWnd", index);

				debug("AskJoin : id " $ user.nID $ " name " $ user.Name $ " clanType " $ knighthoodID );
				RequestClanAskJoin( user.nID, knighthoodID );
			}
		}
	}
}

function InitializeComboBox()
{
	local int i;
	local ClanWnd	script;
	local int addedCount;
	local string countnum;
	local string countnum2;
	local int cnt1;
	local int cnt2;
	script = ClanWnd( GetScript("ClanWnd") );
	class'UIAPI_COMBOBOX'.static.Clear("InviteClanPopWnd.ComboboxInviteClandPopWnd");
	countnum2 = "" $ script.m_myClanType;
	debug(countnum2);
	cnt1 = len(countnum2);
	for( i=0 ; i < CLAN_KNIGHTHOOD_COUNT ; ++i )
	{
		countnum = "" $ m_knighthoodIndex[i];
		debug(countnum);
		cnt2 = len(countnum);
		if( script.m_memberList[i].m_sName != "" )
		{
			if ( m_knighthoodIndex[i] == -1 )
			{
				class'UIAPI_COMBOBOX'.static.AddStringWithReserved("InviteClanPopWnd.ComboboxInviteClandPopWnd", script.m_memberList[i].m_sName, m_knighthoodIndex[i] );
				++addedCount;
			}
			else if (cnt1 <= cnt2)
			{
				class'UIAPI_COMBOBOX'.static.AddStringWithReserved("InviteClanPopWnd.ComboboxInviteClandPopWnd", script.m_memberList[i].m_sName, m_knighthoodIndex[i] );
				++addedCount;
			}
		}
	}
	if( addedCount > 0 )
		class'UIAPI_COMBOBOX'.static.SetSelectedNum("InviteClanPopWnd.ComboboxInviteClandPopWnd", 0);		// 제일 처음 아이템이 보이도록
}
