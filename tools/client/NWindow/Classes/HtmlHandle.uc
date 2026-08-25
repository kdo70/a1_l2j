class HtmlHandle extends WindowHandle
	native;

native static function LoadHtml( string FileName );
native static function LoadHtmlFromString( string HtmlString );
native static function Clear();
native static function int GetFrameMaxHeight();
native static function EControlReturnType ControllerExecution( string strBypass );

//BBSÀü¿ë
native static function SetHtmlBuffData( string strData);
native static function SetPageLock( bool bLock);
native static function bool IsPageLock();
