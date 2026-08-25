class UIAPI_HTMLCTRL extends UIAPI_WINDOW
	native;
	
native static function LoadHtml(string ControlName, string FileName);
native static function LoadHtmlFromString(string ControlName, string HtmlString);
native static function Clear(string ControlName);
native static function int GetFrameMaxHeight(string ControlName);
native static function EControlReturnType ControllerExecution( string ControlName, string strBypass );

//BBSÀü¿ë
native static function SetHtmlBuffData(string ControlName, string strData);
native static function SetPageLock(string ControlName, bool bLock);
native static function bool IsPageLock(string ControlName);
