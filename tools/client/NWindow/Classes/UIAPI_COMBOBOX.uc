class UIAPI_COMBOBOX extends UIAPI_WINDOW
	native;

native static function AddString(string ControlName,string str);
native static function SYS_AddString(string ControlName,int index);
native static function AddStringWithReserved(string ControlName,string str,int reserved);
native static function SYS_AddStringWithReserved(string ControlName,int index,int reserved);
native static function string GetString(string ControlName,int num);
native static function int GetReserved(string ControlName,int num);
native static function int GetSelectedNum(string ControlName);
native static function SetSelectedNum(string ControlName,int num);
native static function Clear(string ControlName);
native static function int GetNumOfItems(string ControlName);
