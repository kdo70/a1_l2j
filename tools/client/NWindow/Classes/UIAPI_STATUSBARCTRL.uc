class UIAPI_STATUSBARCTRL extends UIAPI_WINDOW
	native;
native static function SetPoint(string ControlName,int CurrentValue,int MaxValue);
native static function SetPointPercent(string ControlName,INT64 CurrentValue,INT64 MinValue,INT64 MaxValue);
native static function SetPointExp(string ControlName,INT64 CurrentValue,int Level); 
native static function SetRegenInfo(string ControlName,int duration,int ticks,float amount);
