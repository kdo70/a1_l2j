class DialogBox	extends UICommonAPI;

var string		m_strTargetScript;
var string		m_strEditMessage;
var EDialogType	m_type;
var int			m_id;
var bool		m_bInUse;
var int			m_paramInt;
var int			m_reservedInt;
var int			m_reservedInt2;
var int			m_reservedInt3;
var int			m_dialogEditMaxLength;					// editbox의 maxLength를 지정해 준다(일회용). 새 다이얼로그를 띄우면 xml에서 지정한 기본으로 돌아감. -1이 아니라면 값이 세팅된 것이다.
var int			m_dialogEditMaxLength_prev;				// 이전 길이를 기억해 주기 위한 변수.

var DialogDefaultAction		m_defaultAction;			// Which action to take, when "Enter" key is pressed.

var TextBoxHandle DialogReadingText;
var EditBoxHandle m_dialogEdit;
// public
//		only public functions should be exposed to other scripts.
//		Functions in DialogBox.uc should not be used directly by other scripts. They should use them through UICommonAPI.
//
function ShowDialog( EDialogType style, string message, string target )
{
	if( m_bInUse )
	{
		debug("Error!! DialogBox in Use");
		return;
	}

	class'UIAPI_WINDOW'.static.ShowWindow( "DialogBox" );
	SetWindowStyle( style );
	SetMessage( message );
	
	
	class'UIAPI_WINDOW'.static.SetFocus( "DialogBox" );
	if( m_dialogEdit.IsShowWindow() )
	{
		m_dialogEdit.SetFocus();
		if( m_dialogEditMaxLength != -1 )
		{
			m_dialogEditMaxLength_prev = m_dialogEdit.GetMaxLength();
			m_dialogEdit.SetMaxLength(m_dialogEditMaxLength);
		}
	}
	m_strTargetScript = target;
	m_bInUse = true;
}

function HideDialog()
{
	HideWindow( "DialogBox" );
	Initialize();
}

//function OnKeyUp( EInputKey nKey )
//{
//	if (nKey == IK_Enter )
//	{
//		DoDefaultAction();
//	}
//}

function SetDefaultAction( DialogDefaultAction defaultAction )
{
	debug("DialogBox SetDefaultAction " $ defaultAction );
	m_defaultAction = defaultAction;
}

function string GetTarget()
{
	//debug("Dialog::GetTarget() returns: " $ m_strTargetScript );
	return m_strTargetScript;
}

function string GetEditMessage()
{
	//debug("Dialog::GetEditMessage() returns: " $ m_strEditMessage );
	return m_strEditMessage;
}

function SetEditMessage(string strMsg)
{
	m_dialogEdit.SetString( strMsg );
}

function int GetID()
{
	return m_id;
}

function SetID( int id )
{
	//debug("DialogBox SetID " $ id );
	m_id = id;
}

function SetEditType( string strType )
{
	m_dialogEdit.SetEditType( strType );
}

function SetParamInt( int param )
{
	m_paramInt = param;
}

function SetReservedInt( int value )
{
	m_reservedInt = value;
	//debug("DialogBox SetReservedInt to " $ value);
}

function SetReservedInt2( int value )
{
	m_reservedInt2 = value;
	//debug("DialogBox SetReservedInt2 to " $ value);
}

function SetReservedInt3( int value )
{
	m_reservedInt3 = value;
	//debug("DialogBox SetReservedInt to " $ value);
}

function int GetReservedInt()
{
	return m_reservedInt;
}

function int GetReservedInt2()
{
	return m_reservedInt2;
}

function int GetReservedInt3()
{
	return m_reservedInt3;
}

function SetEditBoxMaxLength(int maxLength)
{
	if( maxLength >= 0 )
		m_dialogEditMaxLength = maxLength;
}

//
//
//
function OnLoad()
{
	DialogReadingText = TextBoxHandle ( GetHandle ( "DialogBox.DialogReadingText" ) );
	m_dialogEdit = EditBoxHandle( GetHandle("DialogBox.DialogBoxEdit") );
	Initialize();
	SetButtonName( 1337, 1342 );
	SetMessage("Message uninitialized");
}

function OnClickButton( string strID )
{
	switch( strID )
	{
	case "OKButton":
	case "CenterOKButton":
		HandleOK();
		break;
	case "CancelButton":
		HandleCancel();
		break;
	case "num0":
	case "num1":
	case "num2":
	case "num3":
	case "num4":
	case "num5":
	case "num6":
	case "num7":
	case "num8":
	case "num9":
	case "numAll":
	case "numBS":
	case "numC":
		HandleNumberClick( strID );
		break;
	default:
		break;
	}
}

function OnHide()
{
	if( m_type == DIALOG_Progress )
		class'UIAPI_PROGRESSCTRL'.static.Stop("DialogBox.DialogProgress");

	SetEditType( "normal" );
	//debug("에디트메시지 삭제 " @ class'UIAPI_EDITBOX'.static.GetString( "DialogBox.DialogBoxEdit" ));
	SetEditMessage("");
	//debug("에디트메시지 삭제 " @ class'UIAPI_EDITBOX'.static.GetString( "DialogBox.DialogBoxEdit" ));

	// EditBox의 maxLength를 원래 대로 돌려주자.
	if( m_dialogEditMaxLength != -1 )
	{
		m_dialogEditMaxLength = -1;
		m_dialogEdit.SetMaxLength(m_dialogEditMaxLength_prev);
	}
	m_dialogEdit.Clear();
}

//function OnCompleteEditBox( String strID )
//{
//	if( strID == "DialogBoxEdit" )
//	{
//		debug("DialogBox OnCompleteEditBox");
//		HandleOK();
//	}
//}

function OnChangeEditBox( String strID )
{
	local string strInput;
	
	if( strID == "DialogBoxEdit" )
	{
		if( m_type == DIALOG_NumberPad )
		{
			DialogReadingText.SetText("");
			strInput = m_dialogEdit.GetString();
			if(Len(strInput)>0)
			{
				DialogReadingText.SetText(ConvertNumToTextNoAdena(strInput));
			}
		}
	}
}

function Initialize()
{
	m_strTargetScript = "";
	m_bInUse = false;
	SetEditType( "normal" );
	m_paramInt = 0;
	m_reservedInt = 0;
	m_reservedInt2 = 0;
	m_dialogEditMaxLength = -1;

	SetDefaultAction( EDefaultNone );
}

function HideAll()
{
	//debug("HideAll");
	m_dialogEdit.HideWindow();
	class'UIAPI_WINDOW'.static.HideWindow("DialogBox.OKButton");
	class'UIAPI_WINDOW'.static.HideWindow("DialogBox.CancelButton");
	class'UIAPI_WINDOW'.static.HideWindow("DialogBox.CenterOKButton");
	class'UIAPI_WINDOW'.static.HideWindow("DialogBox.NumberPad");
	class'UIAPI_WINDOW'.static.HideWindow("DialogBox.DialogProgress");
}

function SetWindowStyle( EDialogType style )
{
	local Rect bodyRect, numpadRect;
	HideAll();
	bodyRect = class'UIAPI_WINDOW'.static.GetRect( "DialogBox.DialogBody" );
	numpadRect = class'UIAPI_WINDOW'.static.GetRect( "DialogBox.NumberPad" );
	m_type = style;

	switch( style )
	{
	case DIALOG_OKCancel:
		class'UIAPI_WINDOW'.static.ShowWindow("DialogBox.OKButton");
		class'UIAPI_WINDOW'.static.ShowWindow("DialogBox.CancelButton");
		class'UIAPI_WINDOW'.static.SetWindowSize( "DialogBox", bodyRect.nWidth, bodyRect.nHeight );
		break;
	case DIALOG_OK:
		class'UIAPI_WINDOW'.static.ShowWindow("DialogBox.CenterOKButton");
		class'UIAPI_WINDOW'.static.SetWindowSize( "DialogBox", bodyRect.nWidth, bodyRect.nHeight );
		break;
	case DIALOG_OKCancelInput:		// two Button(ok, cancel), and a EditBox
		m_dialogEdit.ShowWindow();
		class'UIAPI_TEXTBOX'.static.SetText( "DialogBox.DialogReadingText", "" );
		debug("what the hell");
		class'UIAPI_WINDOW'.static.ShowWindow("DialogBox.OKButton");
		class'UIAPI_WINDOW'.static.ShowWindow("DialogBox.CancelButton");
		class'UIAPI_WINDOW'.static.SetWindowSize( "DialogBox", bodyRect.nWidth, bodyRect.nHeight );
		break;
	case DIALOG_OKInput:			// one Button(ok), and a EditBox
		m_dialogEdit.ShowWindow();
		class'UIAPI_TEXTBOX'.static.SetText( "DialogBox.DialogReadingText", "" );
		class'UIAPI_WINDOW'.static.ShowWindow("DialogBox.CenterOKButton");
		class'UIAPI_WINDOW'.static.SetWindowSize( "DialogBox", bodyRect.nWidth, bodyRect.nHeight );
		break;
	case DIALOG_Warning:
		class'UIAPI_WINDOW'.static.ShowWindow("DialogBox.OKButton");
		class'UIAPI_WINDOW'.static.ShowWindow("DialogBox.CancelButton");
		class'UIAPI_WINDOW'.static.SetWindowSize( "DialogBox", bodyRect.nWidth, bodyRect.nHeight );
		break;
	case DIALOG_Notice:
		class'UIAPI_WINDOW'.static.ShowWindow("DialogBox.CenterOKButton");
		class'UIAPI_WINDOW'.static.SetWindowSize( "DialogBox", bodyRect.nWidth, bodyRect.nHeight );
		break;
	case DIALOG_NumberPad:
		m_dialogEdit.ShowWindow();
		class'UIAPI_TEXTBOX'.static.SetText( "DialogBox.DialogReadingText", "" );
		class'UIAPI_WINDOW'.static.ShowWindow("DialogBox.OKButton");
		class'UIAPI_WINDOW'.static.ShowWindow("DialogBox.CancelButton");
		class'UIAPI_WINDOW'.static.ShowWindow("DialogBox.NumberPad");
		class'UIAPI_WINDOW'.static.SetWindowSize( "DialogBox", bodyRect.nWidth + numpadRect.nWidth, bodyRect.nHeight );

		SetEditType("number");
		break;
	case DIALOG_Progress:
		class'UIAPI_WINDOW'.static.ShowWindow("DialogBox.OKButton");
		class'UIAPI_WINDOW'.static.ShowWindow("DialogBox.CancelButton");
		class'UIAPI_WINDOW'.static.ShowWindow("DialogBox.DialogProgress");
		class'UIAPI_WINDOW'.static.SetWindowSize( "DialogBox", bodyRect.nWidth, bodyRect.nHeight );
		if( m_paramInt == 0 )
		{
			debug("DialogBox Error!! DIALOG_Progress needs parameter");
		}
		else
		{
			class'UIAPI_PROGRESSCTRL'.static.SetProgressTime("DialogBox.DialogProgress", m_paramInt );
			class'UIAPI_PROGRESSCTRL'.static.Reset("DialogBox.DialogProgress");
			class'UIAPI_PROGRESSCTRL'.static.Start("DialogBox.DialogProgress");
		}
		break;
	}

	if( style == DIALOG_Progress )
	{
		class'UIAPI_WINDOW'.static.SetAnchor("DialogBox", "", "BottomCenter", "BottomCenter", 0, 0 );
	}
	else
	{
		class'UIAPI_WINDOW'.static.SetAnchor("DialogBox", "", "CenterCenter", "CenterCenter", 0, 0 );
	}
}

function SetMessage( string strMessage )
{
	class'UIAPI_TEXTBOX'.static.SetText( "DialogBox.DialogText", strMessage );
}

function SetButtonName( int indexOK, int indexCancel )
{
	class'UIAPI_BUTTON'.static.SetButtonName( "DialogBox.OKButton", indexOK );
	class'UIAPI_BUTTON'.static.SetButtonName( "DialogBox.CenterOKButton", indexOK );
	class'UIAPI_BUTTON'.static.SetButtonName( "DialogBox.CancelButton", indexCancel );
}

function HandleOK()
{
	if( m_dialogEdit.IsShowWindow() )
		m_strEditMessage = m_dialogEdit.GetString();
	else
		m_strEditMessage = "";

	//다이얼로그를 연속으로 띄우기 위해서는 Clear를 하지말고 이벤트를 젤 마지막에 보낸다.
	class'UIAPI_WINDOW'.static.HideWindow("DialogBox");
	m_bInUse = false;
	ExecuteEvent( EV_DialogOK );
}

function HandleCancel()
{
	class'UIAPI_WINDOW'.static.HideWindow("DialogBox");
	m_bInUse = false;
	ExecuteEvent( EV_DialogCancel );
}

function HandleNumberClick( string strID )
{
	switch( strID )
	{
	case "num0":
		m_dialogEdit.AddString( "0" );
		break;
	case "num1":
		m_dialogEdit.AddString( "1" );
		break;
	case "num2":
		m_dialogEdit.AddString( "2" );
		break;
	case "num3":
		m_dialogEdit.AddString( "3" );
		break;
	case "num4":
		m_dialogEdit.AddString( "4" );
		break;
	case "num5":
		m_dialogEdit.AddString( "5" );
		break;
	case "num6":
		m_dialogEdit.AddString( "6" );
		break;
	case "num7":
		m_dialogEdit.AddString( "7" );
		break;
	case "num8":
		m_dialogEdit.AddString( "8" );
		break;
	case "num9":
		m_dialogEdit.AddString( "9" );
		break;
	case "numAll":
		if( m_paramInt >= 0 )
			m_dialogEdit.SetString( string(m_paramInt) );
		break;
	case "numBS":
		m_dialogEdit.SimulateBackspace();
		break;
	case "numC":
		m_dialogEdit.SetString( "0" );
		break;
	default:
		break;
	}
}

// 다이얼로그의 시간이 다했음
function OnProgressTimeUp( string strID )
{
	debug("OnProgressTimeUp");
	if( strID == "DialogProgress" )
		HandleCancel();
}

function DoDefaultAction()
{
	debug("DialogBox DoDefaultAction");
	switch( m_defaultAction )
	{
	case EDefaultOK:
		HandleOK();
		break;
	case EDefaultCancel:
		HandleCancel();
		break;
	case EDefaultNone:
		HandleCancel();
		break;
	default:
		break;
	};

	SetDefaultAction( EDefaultNone );			// 다이얼로그를 띄울 때 이전 다이얼로그의 디폴트 액션의 영향을 받지 않아야 하므로 한번 하고나면 초기화 해 준다.
}
