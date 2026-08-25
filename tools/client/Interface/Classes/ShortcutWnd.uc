class ShortcutWnd extends UICommonAPI;

const MAX_Page = 10;
const MAX_ShortcutPerPage = 12;

enum EJoyShortcut
{
	JOYSHORTCUT_Left,
	JOYSHORTCUT_Center,
	JOYSHORTCUT_Right,
};
var int CurrentShortcutPage;
var int CurrentShortcutPage2;
var int CurrentShortcutPage3;
var bool m_IsLocked;
var bool m_IsVertical;
var bool m_IsJoypad;
var bool m_IsJoypadExpand;
var bool m_IsJoypadOn;
var bool m_IsExpand1;
var bool m_IsExpand2;
var bool m_IsShortcutExpand;
var String m_ShortcutWndName;

function OnLoad()
{
	RegisterEvent( EV_ShortcutUpdate );
	RegisterEvent( EV_ShortcutPageUpdate );
	RegisterEvent( EV_ShortcutJoypad );
	RegisterEvent( EV_ShortcutClear );
	RegisterEvent( EV_JoypadLButtonDown );
	RegisterEvent( EV_JoypadLButtonUp );
	RegisterEvent( EV_JoypadRButtonDown );
	RegisterEvent( EV_JoypadRButtonUp );
	
	//Load Ini
	m_IsLocked = GetOptionBool( "Game", "IsLockShortcutWnd" );
	m_IsExpand1 = GetOptionBool( "Game", "Is1ExpandShortcutWnd" );
	m_IsExpand2 = GetOptionBool( "Game", "Is2ExpandShortcutWnd" );
	m_IsVertical = GetOptionBool( "Game", "IsShortcutWndVertical" );
	
	InitShortPageNum();
}

function OnDefaultPosition()
{
	m_IsExpand1 = false;
	m_IsExpand2 = false;
	SetVertical(true);
	
	InitShortPageNum();
	ArrangeWnd();
	ExpandWnd();
}

function OnEnterState( name a_PreStateName )
{
	ArrangeWnd();
	ExpandWnd();
	
	if( a_PreStateName == 'LoadingState' )
	InitShortPageNum();
}

function OnEvent( int a_EventID, String a_Param )
{	
	switch( a_EventID )
	{
	case EV_ShortcutPageUpdate:					//첫번째숏컷창의 페이지가 새로 설정되었을 때 날라오는 이벤트
		HandleShortcutPageUpdate( a_Param );
		break;
	case EV_ShortcutJoypad:
		HandleShortcutJoypad( a_Param );
		break;
	case EV_JoypadLButtonDown:
		HandleJoypadLButtonDown( a_Param );
		break;
	case EV_JoypadLButtonUp:
		HandleJoypadLButtonUp( a_Param );
		break;
	case EV_JoypadRButtonDown:
		HandleJoypadRButtonDown( a_Param );
		break;
	case EV_JoypadRButtonUp:
		HandleJoypadRButtonUp( a_Param );
		break;
	case EV_ShortcutUpdate:
		HandleShortcutUpdate( a_Param );
		break;
	case EV_ShortcutClear:
		HandleShortcutClear();
		//InitShortPageNum();
		ArrangeWnd();
		ExpandWnd();
		break;
	}
}


function InitShortPageNum()
{
	CurrentShortcutPage = 0;
	CurrentShortcutPage2 = 1;
	CurrentShortcutPage3 = 2;
}

function HandleShortcutPageUpdate(string param)
{
	local int i;
	local int nShortcutID;
	local int ShortcutPage;
	
	if( ParseInt(param, "ShortcutPage", ShortcutPage) )
	{
		if( 0 > ShortcutPage || MAX_Page <= ShortcutPage )
			return;
			
		CurrentShortcutPage = ShortcutPage;
		class'UIAPI_TEXTBOX'.static.SetText( "ShortcutWnd." $ m_ShortcutWndName $ ".PageNumTextBox", string( CurrentShortcutPage + 1 ) );
		nShortcutID = CurrentShortcutPage * MAX_ShortcutPerPage;
		for( i = 0; i < MAX_ShortcutPerPage; ++i )
		{
			class'UIAPI_SHORTCUTITEMWINDOW'.static.UpdateShortcut( "ShortcutWnd." $ m_ShortcutWndName $ ".Shortcut" $ ( i + 1 ), nShortcutID );
			nShortcutID++;
		}
	}
}

function HandleShortcutUpdate(string param)
{
	local int nShortcutID;
	local int nShortcutNum;
	
	ParseInt(param, "ShortcutID", nShortcutID);
	nShortcutNum = ( nShortcutID % MAX_ShortcutPerPage ) + 1;
	
	if( IsShortcutIDInCurPage( CurrentShortcutPage, nShortcutID ) )
	{
		class'UIAPI_SHORTCUTITEMWINDOW'.static.UpdateShortcut( "ShortcutWnd." $ m_ShortcutWndName $ ".Shortcut" $ nShortcutNum, nShortcutID );
	}
	if( IsShortcutIDInCurPage( CurrentShortcutPage2, nShortcutID ) )
	{
		class'UIAPI_SHORTCUTITEMWINDOW'.static.UpdateShortcut( "ShortcutWnd." $ m_ShortcutWndName $ "_1.Shortcut" $ nShortcutNum, nShortcutID );
	}
	if( IsShortcutIDInCurPage( CurrentShortcutPage3, nShortcutID ) )
	{
		class'UIAPI_SHORTCUTITEMWINDOW'.static.UpdateShortcut( "ShortcutWnd." $ m_ShortcutWndName $ "_2.Shortcut" $ nShortcutNum, nShortcutID );
	}
}

function HandleShortcutClear()
{
	local int i;
	
	for( i=0 ; i < MAX_ShortcutPerPage ; ++i )
	{
		class'UIAPI_SHORTCUTITEMWINDOW'.static.Clear( "ShortcutWnd.ShortcutWndVertical.Shortcut" $ (i+1) );
		class'UIAPI_SHORTCUTITEMWINDOW'.static.Clear( "ShortcutWnd.ShortcutWndVertical_1.Shortcut" $ (i+1) );
		class'UIAPI_SHORTCUTITEMWINDOW'.static.Clear( "ShortcutWnd.ShortcutWndVertical_2.Shortcut" $ (i+1) );
		class'UIAPI_SHORTCUTITEMWINDOW'.static.Clear( "ShortcutWnd.ShortcutWndHorizontal.Shortcut" $ (i+1) );
		class'UIAPI_SHORTCUTITEMWINDOW'.static.Clear( "ShortcutWnd.ShortcutWndHorizontal_1.Shortcut" $ (i+1) );
		class'UIAPI_SHORTCUTITEMWINDOW'.static.Clear( "ShortcutWnd.ShortcutWndHorizontal_2.Shortcut" $ (i+1) );

		class'UIAPI_SHORTCUTITEMWINDOW'.static.Clear( "ShortcutWnd.ShortcutWndJoypadExpand.Shortcut" $ (i+1) );
	}
	for( i=0; i< 4 ; ++i )
	{
		class'UIAPI_SHORTCUTITEMWINDOW'.static.Clear( "ShortcutWnd.ShortcutWndJoypad.Shortcut" $ (i+1) );
	}
}

function HandleShortcutJoypad( String a_Param )
{
	local int OnOff;

	if( ParseInt( a_Param, "OnOff", OnOff ) )
	{
		if( 1 == OnOff )
		{
			m_IsJoypadOn = true;
			ShowWindow( "ShortcutWnd." $ m_ShortcutWndName $ ".JoypadBtn" );
		}
		else if( 0 == OnOff )
		{
			m_IsJoypadOn = false;
			HideWindow( "ShortcutWnd." $ m_ShortcutWndName $ ".JoypadBtn" );
		}
	}
}

function HandleJoypadLButtonUp( String a_Param )
{
	SetJoypadShortcut( JOYSHORTCUT_Center );
}

function HandleJoypadLButtonDown( String a_Param )
{
	SetJoypadShortcut( JOYSHORTCUT_Left );
}

function HandleJoypadRButtonUp( String a_Param )
{
	SetJoypadShortcut( JOYSHORTCUT_Center );
}

function HandleJoypadRButtonDown( String a_Param )
{
	SetJoypadShortcut( JOYSHORTCUT_Right );
}

function SetJoypadShortcut( EJoyShortcut a_JoyShortcut )
{
	local int i;
	local int nShortcutID;

	switch( a_JoyShortcut )
	{
	case JOYSHORTCUT_Left:
		class'UIAPI_TEXTURECTRL'.static.SetTexture( "ShortcutWnd.ShortcutWndJoypadExpand.JoypadButtonBackTex", "L2UI_CH3.ShortcutWnd.joypad2_back_over1" );
		class'UIAPI_TEXTURECTRL'.static.SetAnchor( "ShortcutWnd.ShortcutWndJoypadExpand.JoypadButtonBackTex", "ShortcutWnd.ShortcutWndJoypadExpand", "TopLeft", "TopLeft", 28, 0 );
		class'UIAPI_TEXTURECTRL'.static.SetTexture( "ShortcutWnd.ShortcutWndJoypad.JoypadLButtonTex", "L2UI_ch3.Joypad.joypad_L_HOLD" );
		class'UIAPI_TEXTURECTRL'.static.SetTexture( "ShortcutWnd.ShortcutWndJoypad.JoypadRButtonTex", "L2UI_ch3.Joypad.joypad_R" );
		nShortcutID = CurrentShortcutPage * MAX_ShortcutPerPage + 4;
		for( i = 0; i < 4; ++i )
		{
			class'UIAPI_SHORTCUTITEMWINDOW'.static.UpdateShortcut( "ShortcutWnd.ShortcutWndJoypad.Shortcut" $ ( i + 1 ), nShortcutID );
			nShortcutID++;
		}
		break;
	case JOYSHORTCUT_Center:
		class'UIAPI_TEXTURECTRL'.static.SetTexture( "ShortcutWnd.ShortcutWndJoypadExpand.JoypadButtonBackTex", "L2UI_CH3.ShortcutWnd.joypad2_back_over2" );
		class'UIAPI_TEXTURECTRL'.static.SetAnchor( "ShortcutWnd.ShortcutWndJoypadExpand.JoypadButtonBackTex", "ShortcutWnd.ShortcutWndJoypadExpand", "TopLeft", "TopLeft", 158, 0 );
		class'UIAPI_TEXTURECTRL'.static.SetTexture( "ShortcutWnd.ShortcutWndJoypad.JoypadLButtonTex", "L2UI_ch3.Joypad.joypad_L" );
		class'UIAPI_TEXTURECTRL'.static.SetTexture( "ShortcutWnd.ShortcutWndJoypad.JoypadRButtonTex", "L2UI_ch3.Joypad.joypad_R" );
		nShortcutID = CurrentShortcutPage * MAX_ShortcutPerPage;
		for( i = 0; i < 4; ++i )
		{
			class'UIAPI_SHORTCUTITEMWINDOW'.static.UpdateShortcut( "ShortcutWnd.ShortcutWndJoypad.Shortcut" $ ( i + 1 ), nShortcutID );
			nShortcutID++;
		}
		break;
	case JOYSHORTCUT_Right:
		class'UIAPI_TEXTURECTRL'.static.SetTexture( "ShortcutWnd.ShortcutWndJoypadExpand.JoypadButtonBackTex", "L2UI_CH3.ShortcutWnd.joypad2_back_over3" );
		class'UIAPI_TEXTURECTRL'.static.SetAnchor( "ShortcutWnd.ShortcutWndJoypadExpand.JoypadButtonBackTex", "ShortcutWnd.ShortcutWndJoypadExpand", "TopLeft", "TopLeft", 288, 0 );
		class'UIAPI_TEXTURECTRL'.static.SetTexture( "ShortcutWnd.ShortcutWndJoypad.JoypadLButtonTex", "L2UI_ch3.Joypad.joypad_L" );
		class'UIAPI_TEXTURECTRL'.static.SetTexture( "ShortcutWnd.ShortcutWndJoypad.JoypadRButtonTex", "L2UI_ch3.Joypad.joypad_R_HOLD" );
		nShortcutID = CurrentShortcutPage * MAX_ShortcutPerPage + 8;
		for( i = 0; i < 4; ++i )
		{
			class'UIAPI_SHORTCUTITEMWINDOW'.static.UpdateShortcut( "ShortcutWnd.ShortcutWndJoypad.Shortcut" $ ( i + 1 ), nShortcutID );
			nShortcutID++;
		}
		break;
	}
}

function OnClickButton( string a_strID )
{
	switch( a_strID )
	{
	case "PrevBtn":
		OnPrevBtn();
		break;
	case "NextBtn":
		OnNextBtn();
		break;
	case "PrevBtn2":
		OnPrevBtn2();
		break;
	case "NextBtn2":
		OnNextBtn2();
		break;
	case "PrevBtn3":
		OnPrevBtn3();
		break;
	case "NextBtn3":
		OnNextBtn3();
		break;
	case "LockBtn":
		OnClickLockBtn();
		break;
	case "UnlockBtn":
		OnClickUnlockBtn();
		break;
	case "RotateBtn":
		OnRotateBtn();
		break;
	case "JoypadBtn":
		OnJoypadBtn();
		break;
	case "ExpandBtn":
		OnExpandBtn();
		break;
	case "ExpandButton":
		OnClickExpandShortcutButton();
		break;
	case "ReduceButton":
		OnClickExpandShortcutButton();
		break;
	}
}

function OnPrevBtn()
{
	local int nNewPage;

	nNewPage = CurrentShortcutPage - 1;
	if( 0 > nNewPage )
		nNewPage = MAX_Page - 1;

	SetCurPage( nNewPage );
}

function OnPrevBtn2()
{
	local int nNewPage;

	nNewPage = CurrentShortcutPage2 - 1;
	if( 0 > nNewPage )
		nNewPage = MAX_Page - 1;

	SetCurPage2( nNewPage );
}

function OnPrevBtn3()
{
	local int nNewPage;

	nNewPage = CurrentShortcutPage3 - 1;
	if( 0 > nNewPage )
		nNewPage = MAX_Page - 1;

	SetCurPage3( nNewPage );
}

function OnNextBtn()
{
	local int nNewPage;

	nNewPage = CurrentShortcutPage + 1;
	if( MAX_Page <= nNewPage )
		nNewPage = 0;

	SetCurPage( nNewPage );
}

function OnNextBtn2()
{
	local int nNewPage;

	nNewPage = CurrentShortcutPage2 + 1;
	if( MAX_Page <= nNewPage )
		nNewPage = 0;

	SetCurPage2( nNewPage );
}

function OnNextBtn3()
{
	local int nNewPage;

	nNewPage = CurrentShortcutPage3 + 1;
	if( MAX_Page <= nNewPage )
		nNewPage = 0;

	SetCurPage3( nNewPage );
}

function OnClickLockBtn()
{
	UnLock();
}

function OnClickUnlockBtn()
{
	Lock();
}

function OnRotateBtn()
{
	SetVertical( !m_IsVertical );
	
	if( m_IsVertical )
	{
		class'UIAPI_WINDOW'.static.SetAnchor( "ShortcutWnd.ShortcutWndVertical", "ShortcutWnd.ShortcutWndHorizontal", "BottomRight", "BottomRight", 0, 0 );
		class'UIAPI_WINDOW'.static.ClearAnchor( "ShortcutWnd.ShortcutWndVertical" );
		class'UIAPI_WINDOW'.static.SetAnchor( "ShortcutWnd.ShortcutWndHorizontal", "ShortcutWnd.ShortcutWndVertical", "BottomRight", "BottomRight", 0, 0 );
	}
	else 
	{
		class'UIAPI_WINDOW'.static.SetAnchor( "ShortcutWnd.ShortcutWndHorizontal", "ShortcutWnd.ShortcutWndVertical", "BottomRight", "BottomRight", 0, 0 );                                
		class'UIAPI_WINDOW'.static.ClearAnchor( "ShortcutWnd.ShortcutWndHorizontal" );                                                                                                     
		class'UIAPI_WINDOW'.static.SetAnchor( "ShortcutWnd.ShortcutWndVertical", "ShortcutWnd.ShortcutWndHorizontal", "BottomRight", "BottomRight", 0, 0 );                                
	}
	
	if(m_IsExpand2 == true)
	{
		Expand1();
		Expand2();
	}
	else if(m_IsExpand1 == true)
	{
		Expand1();
	}
	
	class'UIAPI_WINDOW'.static.SetFocus( "ShortcutWnd." $ m_ShortcutWndName );
}

function OnJoypadBtn()
{
	SetJoypad( !m_IsJoypad );
	class'UIAPI_WINDOW'.static.SetFocus( "ShortcutWnd." $ m_ShortcutWndName );
}

function OnExpandBtn()
{
	SetJoypadExpand( !m_IsJoypadExpand );
	class'UIAPI_WINDOW'.static.SetFocus( "ShortcutWnd." $ m_ShortcutWndName );
}

function SetCurPage( int a_nCurPage )
{
	if( 0 > a_nCurPage || MAX_Page <= a_nCurPage )
		return;
		
	//Set Current ShortcutKey(F1,F2,F3...) ShortcutWnd Num
	//단축키는 첫번째숏컷창만 참조하므로..
	class'ShortcutAPI'.static.SetShortcutPage( a_nCurPage );
	
	//->EV_ShortcutPageUpdate 가 날라온다.
}

function SetCurPage2( int a_nCurPage )
{
	local int i;
	local int nShortcutID;
	
	if( 0 > a_nCurPage || MAX_Page <= a_nCurPage )
		return;
		
	CurrentShortcutPage2 = a_nCurPage;
	class'UIAPI_TEXTBOX'.static.SetText( "ShortcutWnd." $ m_ShortcutWndName $ "." $ m_ShortcutWndName $ "_1" $ ".PageNumTextBox", string( CurrentShortcutPage2 + 1 ) );
	nShortcutID = CurrentShortcutPage2 * MAX_ShortcutPerPage;
	for( i = 0; i < MAX_ShortcutPerPage; ++i )
	{
		class'UIAPI_SHORTCUTITEMWINDOW'.static.UpdateShortcut( "ShortcutWnd." $ m_ShortcutWndName $ "." $ m_ShortcutWndName $ "_1" $".Shortcut" $ ( i + 1 ), nShortcutID );
		nShortcutID++;
	}
}

function SetCurPage3( int a_nCurPage )
{
	local int i;
	local int nShortcutID;
	
	if( 0 > a_nCurPage || MAX_Page <= a_nCurPage )
		return;
		
	CurrentShortcutPage3 = a_nCurPage;
	class'UIAPI_TEXTBOX'.static.SetText( "ShortcutWnd." $ m_ShortcutWndName $ "." $ m_ShortcutWndName $ "_1." $ m_ShortcutWndName $"_2" $ ".PageNumTextBox", string( CurrentShortcutPage3 + 1 ) );	
	nShortcutID = CurrentShortcutPage3 * MAX_ShortcutPerPage;
	for( i = 0; i < MAX_ShortcutPerPage; ++i )
	{
		class'UIAPI_SHORTCUTITEMWINDOW'.static.UpdateShortcut( "ShortcutWnd." $ m_ShortcutWndName $ "." $ m_ShortcutWndName $ "_1." $ m_ShortcutWndName $"_2" $ ".Shortcut" $ ( i + 1 ), nShortcutID );
		nShortcutID++;
	}
}

function bool IsShortcutIDInCurPage( int PageNum, int a_nShortcutID )
{
	if( PageNum * MAX_ShortcutPerPage > a_nShortcutID )
		return false;
	if( ( PageNum + 1 ) * MAX_ShortcutPerPage <= a_nShortcutID )
		return false;
	return true;
}

function Lock()
{
	m_IsLocked = true;
	SetOptionBool( "Game", "IsLockShortcutWnd", true );

	if( IsShowWindow( "ShortcutWnd" ) )
	{
		ShowWindow( "ShortcutWnd." $ m_ShortcutWndName $ ".LockBtn" );
		HideWindow( "ShortcutWnd." $ m_ShortcutWndName $ ".UnlockBtn" );
	}
}

function UnLock()
{
	m_IsLocked = false;
	SetOptionBool( "Game", "IsLockShortcutWnd", false );

	if( IsShowWindow( "ShortcutWnd" ) )
	{
		ShowWindow( "ShortcutWnd." $ m_ShortcutWndName $ ".UnlockBtn" );
		HideWindow( "ShortcutWnd." $ m_ShortcutWndName $ ".LockBtn" );
	}
}

function SetVertical( bool a_IsVertical )
{
	m_IsVertical = a_IsVertical;
	SetOptionBool( "Game", "IsShortcutWndVertical", m_IsVertical );

	ArrangeWnd();
	ExpandWnd();
}

function SetJoypad( bool a_IsJoypad )
{
	m_IsJoypad = a_IsJoypad;

	ArrangeWnd();
}

function SetJoypadExpand( bool a_IsJoypadExpand )
{
	m_IsJoypadExpand = a_IsJoypadExpand;

	if( m_IsJoypadExpand )
	{
		class'UIAPI_WINDOW'.static.SetAnchor( "ShortcutWnd.ShortcutWndJoypadExpand", "ShortcutWnd.ShortcutWndJoypad", "TopLeft", "TopLeft", 0, 0 );
		class'UIAPI_WINDOW'.static.ClearAnchor( "ShortcutWnd.ShortcutWndJoypadExpand" );
	}
	else
	{
		class'UIAPI_WINDOW'.static.SetAnchor( "ShortcutWnd.ShortcutWndJoypad", "ShortcutWnd.ShortcutWndJoypadExpand", "TopLeft", "TopLeft", 0, 0 );
		class'UIAPI_WINDOW'.static.ClearAnchor( "ShortcutWnd.ShortcutWndJoypad" );
	}

	ArrangeWnd();
}

function ArrangeWnd()
{
	local Rect WindowRect;

	if( m_IsJoypad )
	{
		HideWindow( "ShortcutWnd.ShortcutWndVertical" );
		HideWindow( "ShortcutWnd.ShortcutWndHorizontal" );
		if( m_IsJoypadExpand )
		{
			HideWindow( "ShortcutWnd.ShortcutWndJoypad" );
			ShowWindow( "ShortcutWnd.ShortcutWndJoypadExpand" );

			m_ShortcutWndName = "ShortcutWndJoypadExpand";
		}
		else
		{
			HideWindow( "ShortcutWnd.ShortcutWndJoypadExpand" );
			ShowWindow( "ShortcutWnd.ShortcutWndJoypad" );

			m_ShortcutWndName = "ShortcutWndJoypad";
		}
	}
	else
	{
		HideWindow( "ShortcutWnd.ShortcutWndJoypadExpand" );
		HideWindow( "ShortcutWnd.ShortcutWndJoypad" );
		if( m_IsVertical )
		{
			m_ShortcutWndName = "ShortcutWndVertical";
			WindowRect = class'UIAPI_WINDOW'.static.GetRect( "ShortcutWnd.ShortcutWndVertical" );
			if( WindowRect.nY < 0 )
				class'UIAPI_WINDOW'.static.MoveTo( "ShortcutWnd.ShortcutWndVertical", WindowRect.nX, 0 );
			HideWindow( "ShortcutWnd.ShortcutWndHorizontal" );
			ShowWindow( "ShortcutWnd.ShortcutWndVertical" );
		}
		else
		{
			m_ShortcutWndName = "ShortcutWndHorizontal";
			WindowRect = class'UIAPI_WINDOW'.static.GetRect( "ShortcutWnd.ShortcutWndHorizontal" );
			if( WindowRect.nX < 0 )
				class'UIAPI_WINDOW'.static.MoveTo( "ShortcutWnd.ShortcutWndHorizontal", 0, WindowRect.nY );
			HideWindow( "ShortcutWnd.ShortcutWndVertical" );
			ShowWindow( "ShortcutWnd.ShortcutWndHorizontal" );
		}

		if( m_IsJoypadOn )
			ShowWindow( "ShortcutWnd." $ m_ShortcutWndName $ ".JoypadBtn" );
		else
			HideWindow( "ShortcutWnd." $ m_ShortcutWndName $ ".JoypadBtn" );
	}

	if( m_IsLocked )
		Lock();
	else
		UnLock();

	SetCurPage( CurrentShortcutPage );
	SetCurPage2( CurrentShortcutPage2 );
	SetCurPage3( CurrentShortcutPage3 );
	
	if(m_IsExpand1 == true)
	{
		m_IsShortcutExpand = true;
		HandleExpandButton();
	}
	else if(m_IsExpand2 == true)
	{
		m_IsShortcutExpand = false;
		HandleExpandButton();
	}
	else
	{
		m_IsShortcutExpand = true;
		HandleExpandButton();
	}
}

function ExpandWnd()
{
	if(m_IsExpand1 == true || m_IsExpand2 == true)
	{
		if(m_IsExpand2 == true)
		{
			m_IsShortcutExpand = false;
			Expand2();
		}
		if(m_IsExpand1 == true)
		{
			m_IsShortcutExpand = false;
			Expand1();
		}
	}
	else
	{
		m_IsShortcutExpand = true;
		Reduce();
	}
}

function Expand1()
{
	m_IsShortcutExpand = true;
	m_IsExpand1 = true;
	SetOptionBool( "Game", "Is1ExpandShortcutWnd", m_IsExpand1 );
	
	class'UIAPI_WINDOW'.static.ShowWindow("ShortcutWnd.ShortcutWndVertical_1");
	class'UIAPI_WINDOW'.static.ShowWindow("ShortcutWnd.ShortcutWndHorizontal_1");
	
	HandleExpandButton();
}

function Expand2()
{
	m_IsShortcutExpand = false;	
	m_IsExpand2 = true;
	SetOptionBool( "Game", "Is2ExpandShortcutWnd", m_IsExpand2 );
	
	class'UIAPI_WINDOW'.static.ShowWindow("ShortcutWnd.ShortcutWndVertical_2");
	class'UIAPI_WINDOW'.static.ShowWindow("ShortcutWnd.ShortcutWndHorizontal_2");
	
	HandleExpandButton();
}

function Reduce()
{
	m_IsShortcutExpand = true;
	m_IsExpand1 = false;
	m_IsExpand2 = false;
	SetOptionBool( "Game", "Is1ExpandShortcutWnd", m_IsExpand1 );
	SetOptionBool( "Game", "Is2ExpandShortcutWnd", m_IsExpand2 );

	class'UIAPI_WINDOW'.static.HideWindow("ShortcutWnd.ShortcutWndVertical_1");
	class'UIAPI_WINDOW'.static.HideWindow("ShortcutWnd.ShortcutWndVertical_2");
	class'UIAPI_WINDOW'.static.HideWindow("ShortcutWnd.ShortcutWndHorizontal_1");
	class'UIAPI_WINDOW'.static.HideWindow("ShortcutWnd.ShortcutWndHorizontal_2");
	
	HandleExpandButton();
}

function OnClickExpandShortcutButton()
{
	if (m_IsExpand2)
	{
		Reduce();
	}
	else if (m_IsExpand1)
	{
		Expand2();
	}
	else 
	{
		Expand1();
	}
}

function HandleExpandButton()
{
	if( m_IsShortcutExpand )
	{
		ShowWindow( "ShortcutWnd." $ m_ShortcutWndName $ ".ExpandButton" );
		HideWindow( "ShortcutWnd." $ m_ShortcutWndName $ ".ReduceButton" );
	}
	else
	{
		HideWindow( "ShortcutWnd." $ m_ShortcutWndName $ ".ExpandButton" );
		ShowWindow( "ShortcutWnd." $ m_ShortcutWndName $ ".ReduceButton" );
	}
}

