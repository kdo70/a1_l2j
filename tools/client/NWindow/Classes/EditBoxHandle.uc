class EditBoxHandle extends WindowHandle
	native;

native final function string GetString();
native final function SetString( string str );
native final function AddString( string str );
native final function SimulateBackspace();
native final function Clear();
native final function SetEditType( string Type );
native final function SetHighLight( bool bHighlight);
native final function SetMaxLength( int maxLength );
native final function int GetMaxLength();
