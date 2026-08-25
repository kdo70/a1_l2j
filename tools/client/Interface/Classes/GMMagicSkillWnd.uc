class GMMagicSkillWnd extends MagicSkillWnd;

var bool bShow;	// GM창에서 버튼을 한번 더 누르면 사라지게 하기 위한 변수

function OnLoad()
{
	RegisterEvent( EV_GMObservingSkillListStart );
	RegisterEvent( EV_GMObservingSkillList );
	
	bShow = false;	//초기화
}

function OnShow()
{
}

function OnHide()
{
}

function ShowMagicSkill( String a_Param )
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
		class'GMAPI'.static.RequestGMCommand( GMCOMMAND_SkillInfo, a_Param );
		bShow = true;
	}
}

function OnEvent( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	case EV_GMObservingSkillListStart:
		HadleGMObservingSkillListStart();
		break;
	case EV_GMObservingSkillList:
		HadleGMObservingSkillList( a_Param );
		break;
	}
}

function HadleGMObservingSkillListStart()
{
	Clear();
	m_hOwnerWnd.ShowWindow();
	m_hOwnerWnd.SetFocus();
}

function HadleGMObservingSkillList( String a_Param )
{
	HandleSkillList( a_Param );
}

function OnClickItem( string strID, int index )
{
}

defaultproperties
{
     m_WindowName="GMMagicSkillWnd.InnerWnd"
}
