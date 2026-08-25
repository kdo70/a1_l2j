class UIAPI_STATUSICONCTRL extends UIAPI_WINDOW
	native;
	
native static function AddRow(string ControlName);
native static function AddCol(string ControlName, int row, StatusIconInfo info);
native static function InsertRow(string ControlName, int row);
native static function InsertCol(string ControlName, int row, int col, StatusIconInfo info);

native static function int GetRowCount(string ControlName);
native static function int GetColCount(string ControlName, int row);

native static function GetItem(string ControlName, int row, int col, out StatusIconInfo info);
native static function DelItem(string ControlName, int row, int col);

native static function Clear(string ControlName); 
