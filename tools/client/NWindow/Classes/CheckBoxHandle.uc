class CheckBoxHandle extends WindowHandle
	native;

native final function SetTitle(string Title);
native final function SetCheck(bool bCheck);
native final function bool IsChecked();
native final function bool IsDisable();
native final function SetDisable(bool bDisable);
native final function ToggleDisable();
