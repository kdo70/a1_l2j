class LoadingWnd extends UIScript;

var string LoadingTexture15;
var string LoadingTexture18;
var string LoadingTextureFree;

function OnLoad()
{
	RegisterEvent( EV_ServerAgeLimitChange );
	class'UIAPI_TEXTURECTRL'.static.SetTexture( "LoadingWnd.BackTex", LoadingTextureFree );
}

function OnEvent( int a_EventID, String a_Param )
{
	local int ServerAgeLimitInt;
	local EServerAgeLimit ServerAgeLimit;

	if( a_EventID == EV_ServerAgeLimitChange )
	{
		if( ParseInt( a_Param, "ServerAgeLimit", ServerAgeLimitInt ) )
		{
			ServerAgeLimit = EServerAgeLimit( ServerAgeLimitInt );
			switch( ServerAgeLimit )
			{
			case SERVER_AGE_LIMIT_15:
				debug( "LoadingTexture15=" $ LoadingTexture15 );
				class'UIAPI_TEXTURECTRL'.static.SetTexture( "LoadingWnd.BackTex", LoadingTexture15 );
				break;
			case SERVER_AGE_LIMIT_18:
				debug( "LoadingTexture18=" $ LoadingTexture18 );
				class'UIAPI_TEXTURECTRL'.static.SetTexture( "LoadingWnd.BackTex", LoadingTexture18 );
				break;
			case SERVER_AGE_LIMIT_Free:
				debug( "LoadingTextureFree=" $ LoadingTextureFree );
			default:
				class'UIAPI_TEXTURECTRL'.static.SetTexture( "LoadingWnd.BackTex", LoadingTextureFree );
				break;
			}
		}
	}
}

