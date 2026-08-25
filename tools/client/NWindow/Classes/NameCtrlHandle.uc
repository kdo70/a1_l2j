class NameCtrlHandle extends WindowHandle
	native;
	
native final function SetName(string Name,ENameCtrlType Type,ETextAlign Align);
native final function SetNameWithColor(string Name,ENameCtrlType Type,ETextAlign Align,Color NameColor);
native final function string GetName();
