class UIAPI_ITEMWINDOW extends UIAPI_WINDOW
	native;
	
native static function int GetSelectedNum(string ControlName);
native static function int GetItemNum(string ControlName);
native static function ClearSelect(string ControlName);
native static function AddItem(string ControlName, ItemInfo info);
native static function SetItem(string ControlName, int index, ItemInfo info);
native static function DeleteItem(string ControlName, int index);
native static function bool GetSelectedItem(string ControlName, out ItemInfo info);
native static function bool GetItem(string ControlName, int index, out ItemInfo info);
native static function INT	GetSelectedItemID(string ControlName);
native static function Clear(string ControlName);
native static function int FindItemWithServerID( string ControlName, int serverID );
native static function int FindItemWithClassID( string ControlName, int classID );
native static function SetFaded( string ControlName, bool bOn );
native static function ShowScrollBar(string ControlName, bool bShow);
