class ComboBoxHandle extends WindowHandle
	native;

native final function AddString(string str);
native final function SYS_AddString(int index);
native final function AddStringWithReserved(string str,int reserved);
native final function SYS_AddStringWithReserved(int index,int reserved);
native final function string GetString(int num);
native final function int GetReserved(int num);
native final function int GetSelectedNum();
native final function SetSelectedNum(int num);
native final function Clear();
