class GMDetailStatusWnd extends DetailStatusWnd;

var String temp1;
var bool bShow;	// GM창에서 버튼을 한번 더 누르면 사라지게 하기 위한 변수
var UserInfo m_ObservingUserInfo;

function OnLoad()
{
	temp1= "Water/Air/Ground";
	
	RegisterEvent( EV_GMObservingUserInfoUpdate );
	RegisterEvent( EV_GMUpdateHennaInfo );
		
	class'UIAPI_WINDOW'.static.SetAnchor( m_WindowName $ ".txtMovingSpeed", m_WindowName, "TopLeft", "TopLeft", 139, 208 );
	class'UIAPI_WINDOW'.static.SetAnchor( m_WindowName $ ".txtMagicCastingSpeed", m_WindowName, "TopLeft", "TopLeft", 186, 177 );
	class'UIAPI_WINDOW'.static.SetAnchor( m_WindowName $ ".txtHeadMovingSpeed", m_WindowName, "TopLeft", "TopLeft", 137, 192 );
	class'UIAPI_WINDOW'.static.SetAnchor( m_WindowName $ ".txtHeadMagicCastingSpeed", m_WindowName, "TopLeft", "TopLeft", 137, 177 );
	
	class'UIAPI_WINDOW'.static.SetAnchor( m_WindowName $".txtGmMoving", m_WindowName, "TopLeft", "TopLeft", 139, 220 );
	class'UIAPI_TEXTBOX'.static.SetText(m_WindowName$".txtGmMoving", temp1);
	
	bShow = false;	//초기화	
}

function OnShow()
{
}

function OnHide()
{
}

function ShowStatus( String a_Param )
{
	if( a_Param == "" )
		return;

	if(bShow)	//창이 떠있으면 지워준다.
	{
		m_hOwnerWnd.HideWindow();
		bShow = false;
	}
	else	
	{
		class'GMAPI'.static.RequestGMCommand( GMCOMMAND_StatusInfo, a_Param );
		bShow = true;
	}
}

function OnEvent( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	case EV_GMObservingUserInfoUpdate:
		if( HandleGMObservingUserInfoUpdate() )
		{
			m_hOwnerWnd.ShowWindow();
			m_hOwnerWnd.SetFocus();
		}
		break;
	case EV_GMUpdateHennaInfo:
		HandleGMUpdateHennaInfo( a_Param );
		break;
	}
}

function bool HandleGMObservingUserInfoUpdate()
{
	local UserInfo ObservingUserInfo;

	if( class'GMAPI'.static.GetObservingUserInfo( ObservingUserInfo ) )
	{
		HandleUpdateUserInfo();
		return true;
	}
	else
		return false;
}

function HandleGMUpdateHennaInfo( String a_Param )
{
	HandleUpdateHennaInfo( a_Param );
	HandleGMObservingUserInfoUpdate();
}

function bool GetMyUserInfo( out UserInfo a_MyUserInfo )
{
	local bool Result;

	Result = class'GMAPI'.static.GetObservingUserInfo( m_ObservingUserInfo );

	if( Result )
	{
		a_MyUserInfo = m_ObservingUserInfo;
		return true;
	}
	else
		return false;
}

function String GetMovingSpeed( UserInfo a_UserInfo )
{
	local int WaterMaxSpeed;
	local int WaterMinSpeed;
	local int AirMaxSpeed;
	local int AirMinSpeed;
	local int GroundMaxSpeed;
	local int GroundMinSpeed;
	local String MovingSpeed;

	WaterMaxSpeed = a_UserInfo.nWaterMaxSpeed * a_UserInfo.fNonAttackSpeedModifier;
	WaterMinSpeed = a_UserInfo.nWaterMinSpeed * a_UserInfo.fNonAttackSpeedModifier;
	AirMaxSpeed = a_UserInfo.nAirMaxSpeed * a_UserInfo.fNonAttackSpeedModifier;
	AirMinSpeed = a_UserInfo.nAirMinSpeed * a_UserInfo.fNonAttackSpeedModifier;
	GroundMaxSpeed = a_UserInfo.nGroundMaxSpeed * a_UserInfo.fNonAttackSpeedModifier;
	GroundMinSpeed = a_UserInfo.nGroundMinSpeed * a_UserInfo.fNonAttackSpeedModifier;

	MovingSpeed = String( WaterMaxSpeed ) $ "," $ String( WaterMinSpeed );
	MovingSpeed = MovingSpeed $ "/" $ String( AirMaxSpeed ) $ "," $ String( AirMinSpeed );
	MovingSpeed = MovingSpeed $ "/" $ String( GroundMaxSpeed ) $ "," $ String( GroundMinSpeed );
	//MovingSpeed = MovingSpeed $ "||Water/Air/Ground" ;

	return MovingSpeed;
}

function float GetMyExpRate()
{
	return GetExpRate( m_ObservingUserInfo.nCurExp, m_ObservingUserInfo.nLevel ) * 100.f;
}

defaultproperties
{
     m_WindowName="GMDetailStatusWnd.InnerWnd"
}
