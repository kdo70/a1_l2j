class TextureHandle extends WindowHandle
	native;

native final function SetTexture( String a_TextureName );
native final function SetUV( int a_U, int a_V );
native final function SetTextureSize( int a_UL, int a_VL );
native final function SetTextureCtrlType(ETextureCtrlType type);
native final function SetTextureWithClanCrest(int clanID);
native final function SetTextureWithObject(texture objTexture);
native final function string GetTextureName();
