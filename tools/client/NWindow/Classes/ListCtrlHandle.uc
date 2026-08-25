class ListCtrlHandle extends WindowHandle
	native;

native final function InsertRecord(LVDataRecord Record);
native final function LVDataRecord GetSelectedRecord();
native final function DeleteAllItem();
native final function DeleteRecord(int index);
native final function int GetRecordCount();
native final function LVDataRecord GetRecord( int index);
native final function int GetSelectedIndex();
native final function SetSelectedIndex( int index, bool bMoveToRow);
native final function ShowScrollBar( bool bShow);
native final function bool ModifyRecord(int index, LVDataRecord Record);
