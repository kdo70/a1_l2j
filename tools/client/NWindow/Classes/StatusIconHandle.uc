class StatusIconHandle extends WindowHandle
	native;

native final function AddRow();
native final function AddCol( int a_Row, StatusIconInfo a_Info );
native final function InsertRow( int a_Row );
native final function InsertCol( int a_Row, int a_Col, StatusIconInfo a_Info );

native final function int GetRowCount();
native final function int GetColCount( int a_Row );

native final function GetItem( int a_Row, int a_Col, out StatusIconInfo a_Info );
native final function SetItem( int a_Row, int a_Col, StatusIconInfo a_Info );
native final function DelItem( int a_Row, int a_Col );

native final function SetIconSize( int a_Size );

native final function Clear();
