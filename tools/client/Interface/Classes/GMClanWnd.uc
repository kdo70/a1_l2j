class GMClanWnd extends ClanWnd;

var bool bShow;	// GM창에서 버튼을 한번 더 누르면 사라지게 하기 위한 변수

function RegisterEvents()
{
	local  GMClanWnd script1;
	
	script1 = GMClanWnd( GetScript("GMClanWnd") );
	
	RegisterEvent( EV_GMObservingClan );
	RegisterEvent( EV_GMObservingClanMemberStart );
	RegisterEvent( EV_GMObservingClanMember );
	
	bShow = false;	//초기화
	
	// 디스에이블로 해준다. 
	class'UIAPI_WINDOW'.static.DisableWindow("GMClanWnd.ClanMemInfoBtn");
	class'UIAPI_WINDOW'.static.DisableWindow("GMClanWnd.ClanMemAuthBtn");
	class'UIAPI_WINDOW'.static.DisableWindow("GMClanWnd.ClanBoardBtn");
	class'UIAPI_WINDOW'.static.DisableWindow("GMClanWnd.ClanInfoBtn");
	class'UIAPI_WINDOW'.static.DisableWindow("GMClanWnd.ClanPenaltyBtn");
	class'UIAPI_WINDOW'.static.DisableWindow("GMClanWnd.ClanQuitBtn");
	class'UIAPI_WINDOW'.static.DisableWindow("GMClanWnd.ClanWarInfoBtn");
	class'UIAPI_WINDOW'.static.DisableWindow("GMClanWnd.ClanWarDeclareBtn");
	class'UIAPI_WINDOW'.static.DisableWindow("GMClanWnd.ClanWarCancleBtn");
	class'UIAPI_WINDOW'.static.DisableWindow("GMClanWnd.ClanAskJoinBtn");
	class'UIAPI_WINDOW'.static.DisableWindow("GMClanWnd.ClanAuthEditBtn");
	class'UIAPI_WINDOW'.static.DisableWindow("GMClanWnd.ClanTitleManageBtn");
	
}

function OnShow()
{
}

function OnHide()
{
}

function ShowClan( String a_Param )
{
	if( a_Param == "" )
		return;

	if(bShow)	//창이 떠있으면 지워준다.
	{
		Clear();
		m_hOwnerWnd.HideWindow();
		bShow = false;
	}
	else
	{
		HandleGMObservingClan("");	//기본적으로 빈창을 띄우도록
		class'GMAPI'.static.RequestGMCommand( GMCOMMAND_ClanInfo, a_Param );
		bShow = true;
	}
}

function OnEvent( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	case EV_GMObservingClan:
		HandleGMObservingClan( a_Param );
		break;
	case EV_GMObservingClanMemberStart:
		HandleGMObservingClanMemberStart();
		break;
	case EV_GMObservingClanMember:
		HandleGMObservingClanMember( a_Param );
		break;
	}
}

function HandleGMObservingClan( String a_Param )
{
	m_hOwnerWnd.ShowWindow();
	m_hOwnerWnd.SetFocus();
	Clear();
	HandleClanInfo( a_Param );
}

function HandleGMObservingClanMemberStart()
{	
}

function HandleGMObservingClanMember( String a_Param )
{
	HandleAddClanMember( a_Param );
}

defaultproperties
{
     m_WindowName="GMClanWnd.InnerWnd"
}
