class TownMapWnd extends UIScript;

function OnLoad()
{
	RegisterEvent( EV_ShowTownMap );
}

function OnEvent( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	case EV_ShowTownMap:
		HandleShowTownMap( a_Param );
		break;
	}
}

function HandleShowTownMap( String a_Param )
{
	local String strTownMapName;
	local int UserPosX;
	local int UserPosY;

	if( ParseString( a_Param, "TownMapName", strTownMapName ) )
	{
		class'UIAPI_TEXTURECTRL'.static.SetTexture( "TownMapWnd.TownMapTex", strTownMapName );
		class'UIAPI_TEXTURECTRL'.static.SetUV( "TownMapWnd.TownMapTex", 0, 0 );
	}

	if( ParseInt( a_Param, "UserPosX", UserPosX ) && ParseInt( a_Param, "UserPosY", UserPosY ) )
		class'UIAPI_WINDOW'.static.SetAnchor( "TownMapWnd.UserTex", "TownMapWnd.TownMapTex", "TopLeft", "TopLeft", UserPosX, UserPosY );

	class'UIAPI_WINDOW'.static.ShowWindow( "TownMapWnd" );
}
