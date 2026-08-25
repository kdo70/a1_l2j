class ReplayLogoWnd extends UIScript;

var string m_strLineage2LogoTexture;
var string m_strMiniLogoTexture;


function OnLoad()
{
	class'UIAPI_TEXTURECTRL'.static.SetTexture("ReplayLogoWnd.textureLogoTitle", m_strLineage2LogoTexture);
	class'UIAPI_TEXTURECTRL'.static.SetTexture("ReplayLogoWnd.textureLogoSubtitle", m_strMiniLogoTexture);
}

