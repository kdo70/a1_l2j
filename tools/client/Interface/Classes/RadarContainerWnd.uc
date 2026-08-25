class RadarContainerWnd extends UIScript;

function OnLoad()
{
	RegisterEvent( EV_RadarAddTarget );
	RegisterEvent( EV_RadarDeleteTarget );
	RegisterEvent( EV_RadarDeleteAllTarget );
}

function OnEvent( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	case EV_RadarAddTarget:
		HandleRadarAddTarget( a_Param );
		break;
	case EV_RadarDeleteTarget:
		HandleRadarDeleteTarget( a_Param );
		break;
	case EV_RadarDeleteAllTarget:
		HandleRadarDeleteAllTarget();
		break;
	}
}

function HandleRadarAddTarget( String a_Param )
{
	local int X, Y, Z;

	if( ParseInt( a_Param, "X", X )
		&& ParseInt( a_Param, "Y", Y )
		&& ParseInt( a_Param, "Z", Z ) )
	{
		class'UIAPI_RADAR'.static.AddTarget( "RadarContainterWnd.Radar", X, Y, Z );
	}
}

function HandleRadarDeleteTarget( String a_Param )
{
	local int X, Y, Z;

	if( ParseInt( a_Param, "X", X )
		&& ParseInt( a_Param, "Y", Y )
		&& ParseInt( a_Param, "Z", Z ) )
	{
		class'UIAPI_RADAR'.static.DeleteTarget( "RadarContainterWnd.Radar", X, Y, Z );
	}
}

function HandleRadarDeleteAllTarget()
{
	class'UIAPI_RADAR'.static.DeleteAllTarget( "RadarContainterWnd.Radar" );
}
