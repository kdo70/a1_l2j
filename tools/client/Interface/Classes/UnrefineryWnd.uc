class UnrefineryWnd extends UICommonAPI;

var WindowHandle m_UnRefineryWnd_Main;
var WindowHandle m_ItemtoUnRefineWnd;
var WindowHandle m_ItemtoUnRefineAnim;
var WindowHandle m_hSelectedItemHighlight;
var WindowHandle m_ResultAnimation1;
var AnimTextureHandle m_ResultAnim1;

var TextBoxHandle m_InstructionText;
var TextBoxHandle m_AdenaText;

var ButtonHandle m_hUnrefineButton;
var ButtonHandle m_OkBtn;

var ItemWindowHandle m_ItemDragBox;

var ItemInfo CurrentItem;
var bool procedure1stat;
var bool procedureopenstat;
var int64 m_Adena;

function OnLoad()
{
	RegisterEvent(EV_ShowRefineryCancelInteface );
	RegisterEvent(EV_RefineryConfirmCancelItemResult );
	RegisterEvent(EV_RefineryRefineCancelResult );
	
	procedure1stat = false;
	procedureopenstat = false;
	m_ResultAnimation1 = GetHandle( "UnrefineryWnd.RefineResultAnimation01");
	m_ResultAnim1 = AnimTextureHandle ( GetHandle( "UnrefineryWnd.RefineResultAnimation01.RefineResult1") );
	m_UnRefineryWnd_Main = GetHandle ("UnrefineryWnd");
	m_ItemtoUnRefineWnd = GetHandle ("Itemtounrefine");
	m_ItemtoUnRefineAnim = GetHandle ("ItemtounrefineAnim");
	m_hSelectedItemHighlight = GetHandle( "SelectedItemHighlight" );
	m_ItemDragBox = ItemWindowHandle (GetHandle ("UnRefineryWnd.Itemtounrefine.ItemUnrefine"));
	m_InstructionText = TextBoxHandle ( GetHandle ("UnrefineryWnd.txtInstruction") );
	m_AdenaText = TextBoxHandle ( GetHandle ("UnrefineryWnd.txtAdenaInstruction") );
	m_hUnrefineButton = ButtonHandle( GetHandle( "btnUnRefine" ) );	
	m_OkBtn= ButtonHandle(GetHandle( "btnClose" ) );
	class'UIAPI_PROGRESSCTRL'.static.SetProgressTime( "UnrefineryWnd.UnRefineryProgress", 2000);

}

function OnShow()
{
	ResetReady();
}

// 초기화 
function ResetReady()
{
	procedure1stat = false;
	procedureopenstat = false;
	m_UnRefineryWnd_Main.ShowWindow();
	m_ItemtoUnRefineWnd.ShowWindow();
	m_ItemtoUnRefineAnim.ShowWindow();
	m_hSelectedItemHighlight.HideWindow();
	m_ResultAnimation1.HideWindow();
	m_ResultAnim1.Stop();
	m_hUnrefineButton.DisableWindow();
	m_ItemDragBox.Clear();
	m_InstructionText.SetText( GetSystemMessage( 1963 ) );
	SetAdenaText( "0" );
	m_AdenaText.SetTooltipString( "" );
	// ResetProgressBar
	class'UIAPI_PROGRESSCTRL'.static.SetProgressTime( "UnrefineryWnd.UnRefineryProgress", 2000);
	class'UIAPI_PROGRESSCTRL'.static.Reset( "UnrefineryWnd.UnRefineryProgress" );
	Playsound("ItemSound2.smelting.Smelting_dragin");
	m_OkBtn.EnableWindow();
}      


//function DoneUnRefine()
//{
//	procedure1stat = true;
//	m_UnRefineryWnd_Main.ShowWindow();
//	m_ItemtoUnRefineWnd.ShowWindow();
//	m_ItemtoUnRefineAnim.HideWindow();
//}

//Event
function OnEvent( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	// UnRefinery Window Open
	case EV_ShowRefineryCancelInteface:
		if (procedureopenstat == false)
		{
			Playsound("ItemSound2.smelting.Smelting_dragin");
			ResetReady();
		}
		break;
	// Target Item Validation Result
	case EV_RefineryConfirmCancelItemResult:
		Playsound("ItemSound2.smelting.Smelting_dragin");
		OnTargetItemValidationResult( a_Param );
		break;
	// Final Refine Result
	case EV_RefineryRefineCancelResult:
		Playsound("ItemSound2.smelting.smelting_finalA");
		OnUnRefineDoneResult( a_Param );
		break;
	default:
		break;
	}	
}

// 아이템을 올려 놓을 경우 분기
function OnDropItem( String a_WindowID, ItemInfo a_ItemInfo, int X, int Y)
{
	switch (a_WindowID)
	{
		case "ItemUnrefine":
			if (procedure1stat == false)
				ValidateItem( a_ItemInfo );
		break;
	}
}

// 아이템의 검증요청
function ValidateItem(ItemInfo a_ItemInfo)
{
	local int TargetItemServerID;
	
	CurrentItem = a_ItemInfo;
	TargetItemServerID = a_ItemInfo.ServerID;
	class'RefineryAPI'.static.ConfirmCancelItem( TargetItemServerID );
}

//아이템을 수락받을지 결정
function OnTargetItemValidationResult(string a_Param)
{
	local int ItemServerID;
	local int ItemClassID;
	local int Option1;
	local int Option2;
	local int ItemValidationResult;
	local String AdenaText;
	//local String AdenaNum;
	
	debug ("아이템 수락 결정");
	
	ParseInt(a_Param, "CancelItemServerID", ItemServerID);
	ParseInt(a_Param, "CancelItemClassID", ItemClassID);
	ParseInt(a_Param, "Option1", Option1);
	ParseInt(a_Param, "Option2", Option2);
	ParseInt64(a_Param, "Adena", m_Adena);
	ParseInt(a_Param, "Result", ItemValidationResult);

	//ParseString(a_Param, "Adena", AdenaNum);
	
	switch (ItemValidationResult)
	{
	//Case Granted
	case 1:
		m_hUnrefineButton.EnableWindow();
		if( !m_ItemDragBox.SetItem( 0, CurrentItem ) )
			m_ItemDragBox.AddItem( CurrentItem );
		AdenaText = MakeCostStringInt64( m_Adena );
		SetAdenaText( AdenaText );
		
		m_ItemtoUnRefineAnim.HideWindow();
		m_hSelectedItemHighlight.ShowWindow();
		
		m_InstructionText.SetText( "" );
		
		procedureopenstat = true;
			if (CheckAdena() == false)
			{
				m_hUnrefineButton.DisableWindow();
				m_InstructionText.SetText( GetSystemMessage(279) );
			}
		break;
	//Case Declined
	case 0:
		break;
	}
	
	// 적절한 스테이트로 UI를 변경 할 것.?	
}

function SetAdenaText( String a_AdenaText )
{
	local string adenatext;
	adenatext = ConvertNumToText(a_AdenaText);
	m_AdenaText.SetText( a_AdenaText @ GetSystemString(469));
	m_AdenaText.SetTextColor( GetNumericColor( a_AdenaText ) );
	if (int(a_AdenaText) == 0)
	m_AdenaText.SetTooltipString( "" );	
	else 
	m_AdenaText.SetTooltipString( adenatext );
}

// 버튼을 눌렀을때
function OnClickButton( string strID )
{
	switch (strID)
	{
	case "btnUnRefine":
		//Playsound("Itemsound2.smelting.smelting_loding");
		
		OnClickUnRefineButton();
		break;
	case "btnClose":
		procedure1stat = false;
		procedureopenstat = false;
		Playsound("Itemsound2.smelting.smelting_dragout");
		m_UnRefineryWnd_Main.HideWindow();
		break;
	}
}

function OnClickUnRefineButton()
{
	local INT64 Diff;
	local INT64 CurAdena;

	CurAdena.nLeft = 0;
	CurAdena.nRight = GetAdena();

	
	Diff = Int64SubtractBfromA( CurAdena, m_Adena );
	if( Diff.nLeft >= 0 || Diff.nRight >= 0 )
	{
		// 돈 있음
		m_hUnrefineButton.DisableWindow();
		m_ResultAnim1.SetLoopCount( 1 );
		
		m_ResultAnimation1.ShowWindow();
		Playsound("ItemSound2.smelting.smelting_loding");
		
		m_ResultAnim1.Play();
		PlayProgressiveBar();
		m_OkBtn.DisableWindow();
	}
	else
	{
		// 돈 없음
		DialogShow( DIALOG_OK, GetSystemMessage( 279 ) );
	}	
}

function bool CheckAdena()
{
	local INT64 Diff;
	local INT64 CurAdena;

	CurAdena.nLeft = 0;
	CurAdena.nRight = GetAdena();

	Diff = Int64SubtractBfromA( CurAdena, m_Adena );
	if( Diff.nLeft >= 0 || Diff.nRight >= 0 )
	{
		return true;
	}
	else
	{
		return false;
	}	
}

function PlayProgressiveBar()
{
	class'UIAPI_PROGRESSCTRL'.static.Start( "UnrefineryWnd.UnRefineryProgress");
}

//연출 이펙트 애니메이션의 종료 확인 및 제련 요청
function OnProgressTimeUp( String aWindowID )
{
	switch ( aWindowID )
	{
		case "UnRefineryProgress":
			OnUnRefineRequest();
		break;
	}
}

function OnTextureAnimEnd( AnimTextureHandle a_WindowHandle )
{
	switch ( a_WindowHandle )
	{
	case m_ResultAnim1:
		m_ResultAnimation1.HideWindow();
		break;
	}
}

// 서버에 제련해제 요청하는 함수 
function OnUnRefineRequest()
{
	class'RefineryAPI'.static.RequestRefineCancel( CurrentItem.ServerID );

}

//제련 완료에 따른 결과 확인 
function OnUnRefineDoneResult(string a_Param)
{
	local int UnRefineResult;
	
	ParseInt(a_Param, "Result", UnRefineResult);

	m_OkBtn.EnableWindow();
	debug ("아이템 제련 해제 완료");
	switch (UnRefineResult)
	{
	case 1:
		CurrentItem.RefineryOp1 = 0;
		CurrentItem.RefineryOp2 = 0;
		if( !m_ItemDragBox.SetItem( 0, CurrentItem ) )
			m_ItemDragBox.AddItem( CurrentItem );
		m_InstructionText.SetText( MakeFullSystemMsg( GetSystemMessage( 1965 ), CurrentItem.Name, "" ) );
		m_hUnrefineButton.DisableWindow();
		procedure1stat = true;
		break;
	case 0:
		m_hUnrefineButton.EnableWindow();
		procedure1stat = false;
		m_UnRefineryWnd_Main.HideWindow();
		break;
	}

	// 버튼을 활성화 시키는 코딩
	// 적절한 스테이트로 UI를 변경 할 것.?
}

