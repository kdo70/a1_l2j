class BarHandle extends WindowHandle
	native;

native function SetValue( int a_MaxValue, int a_CurValue );
native function GetValue( out int a_MaxValue, out int a_CurValue );
native function Clear();
