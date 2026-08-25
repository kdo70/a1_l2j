class TextBoxHandle extends WindowHandle
	native;

native final function String GetText();
native final function SetText( String a_Text );
native final function SetTextColor( Color a_Color );
native final function Color GetTextColor();
native final function SetAlign(ETextAlign align);
native final function SetInt(int Number);
native final function SetTooltipString(string Text);
