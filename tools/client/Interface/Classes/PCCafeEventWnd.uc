class PCCafeEventWnd extends UICommonAPI;

var int m_TotalPoint;
var int m_AddPoint;
var int m_PeriodType;
var int m_RemainTime;
var int m_PointType;

//Handle
var WindowHandle HelpButton;

function OnLoad()
{
	RegisterEvent( EV_PCCafePointInfo );
	
	HelpButton = GetHandle("PCCafeEventWnd.HelpButton");
	//HideWindow( "PCCafeEventWnd.PointAddTextBox" );
}

function OnClickButton( String a_ButtonID )
{
	switch( a_ButtonID )
	{
	case "HelpButton":
		OnClickHelpButton();
		break;
	}
}

function OnEvent( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	case EV_PCCafePointInfo:
		HandlePCCafePointInfo( a_Param );
		break;
	}
}

function OnClickHelpButton()
{
	// TODO: When TTMayrin implements HTML Control, load proper HTML... - NeverDie
}

function HandlePCCafePointInfo( String a_Param )
{
	ParseInt( a_Param, "TotalPoint", m_TotalPoint );
	ParseInt( a_Param, "AddPoint", m_AddPoint );
	ParseInt( a_Param, "PeriodType", m_PeriodType );
	ParseInt( a_Param, "RemainTime", m_RemainTime );
	ParseInt( a_Param, "PointType", m_PointType );
	
	//debug("m_TotalPoint : " $  m_TotalPoint $ "m_AddPoint : " $ m_AddPoint $ "m_PeriodType : " $ m_PeriodType $ "m_RemainTime : " $ m_RemainTime $ "m_PointType : " $ m_PointType );

	Refresh();
}

function bool IsPCCafeEventOpened()
{
	if( 0 < m_PeriodType )
		return true;

	return false;
}

function OnEnterState( name a_PreStateName )
{
	Refresh();
}

function Refresh()
{
	local Color TextColor;
	local String AddPointText;

	if( IsPCCafeEventOpened())
	{
		ShowWindow( "PCCafeEventWnd" );
		
		HelpButton.SetTooltipCustomType(SetTooltip(GetHelpButtonTooltipText()));
		class'UIAPI_TEXTBOX'.static.SetText( "PCCafeEventWnd.PointTextBox", MakeCostString( String( m_TotalPoint ) ) );
		class'UIAPI_WINDOW'.static.SetAlpha( "PCCafeEventWnd.PointAddTextBox", 0 );
		if( 0 != m_AddPoint )
		{
			if( 0 < m_AddPoint )
				AddPointText = "+" $ MakeCostString( String( m_AddPoint ) );
			else
				AddPointText = MakeCostString( String( m_AddPoint ) );

			class'UIAPI_TEXTBOX'.static.SetText( "PCCafeEventWnd.PointAddTextBox", AddPointText );
			switch( m_PointType )
			{
			case 0:	// Normal
				TextColor.R = 255;
				TextColor.G = 255;
				TextColor.B = 0;
				break;
			case 1:	// Bonus
				//TextColor.R = 255;
				//TextColor.G = 0;
				//TextColor.B = 0;
				TextColor.R = 0;
				TextColor.G = 255;
				TextColor.B = 255;
				break;
			case 2:	// Decrease
				//TextColor.R = 0;
				//TextColor.G = 255;
				//TextColor.B = 255;
				TextColor.R = 255;
				TextColor.G = 0;
				TextColor.B = 0;
				break;
			}
			class'UIAPI_TEXTBOX'.static.SetTextColor( "PCCafeEventWnd.PointAddTextBox", TextColor );
			class'UIAPI_WINDOW'.static.SetAnchor( "PCCafeEventWnd.PointAddTextBox", "PCCafeEventWnd", "TopRight", "TopRight", -5, 41 );
			class'UIAPI_WINDOW'.static.ClearAnchor( "PCCafeEventWnd.PointAddTextBox" );
			class'UIAPI_WINDOW'.static.Move( "PCCafeEventWnd.PointAddTextBox", 0, -18, 1.f );
			class'UIAPI_WINDOW'.static.SetAlpha( "PCCafeEventWnd.PointAddTextBox", 255 );
			class'UIAPI_WINDOW'.static.SetAlpha( "PCCafeEventWnd.PointAddTextBox", 0, 0.8f );
			m_AddPoint = 0;
		}
	}
	else
		HideWindow( "PCCafeEventWnd" );
}

function String GetHelpButtonTooltipText()
{
	local String TooltipSystemMsg;

	if( 1 == m_PeriodType )
		TooltipSystemMsg = GetSystemMessage( 1705 );
	else if( 2 == m_PeriodType )
		TooltipSystemMsg = GetSystemMessage( 1706 );
	else
		return "";

	return MakeFullSystemMsg( TooltipSystemMsg, string( m_RemainTime ), "" );
}

function CustomTooltip SetTooltip(string Text)
{
	local CustomTooltip Tooltip;
	local DrawItemInfo info;
	
	Tooltip.MinimumWidth = 144;
	
	Tooltip.DrawList.Length = 1;
	info.eType = DIT_TEXT;
	info.t_bDrawOneLine = true;
	info.t_color.R = 178;
	info.t_color.G = 190;
	info.t_color.B = 207;
	info.t_color.A = 255;
	info.t_strText = Text;
	Tooltip.DrawList[0] = info;

	return Tooltip;
}
