class GMQuestWnd extends QuestTreeWnd;

var bool bShow;	// GM창에서 버튼을 한번 더 누르면 사라지게 하기 위한 변수

function OnLoad()
{
	RegisterEvent( EV_GMObservingQuestListStart );
	RegisterEvent( EV_GMObservingQuestList );
	RegisterEvent( EV_GMObservingQuestListEnd );
	RegisterEvent( EV_GMObservingQuestItem );
	
	bShow = false;	//초기화
}

function OnShow()
{
	class'UIAPI_WINDOW'.static.HideWindow( "GMQuestWnd.InnerWnd.btnClose" );
	class'UIAPI_WINDOW'.static.HideWindow( "GMQuestWnd.InnerWnd.chkNpcPosBox" );
}	

function ShowQuest( String a_Param )
{
	if( a_Param == "" )
		return;

	if(bShow)	//창이 떠있으면 지워준다.
	{
		m_hOwnerWnd.HideWindow();
		bShow = false;
	}
	else
	{
		class'GMAPI'.static.RequestGMCommand( GMCOMMAND_QuestInfo, a_Param );
		bShow = true;
	}
}

// Nullify Super class implementation
function OnClickButton( string strID )
{
}

function OnEvent( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	case EV_GMObservingQuestListStart:
		HandleGMObservingQuestListStart();
		break;
	case EV_GMObservingQuestList:
		HandleGMObservingQuestList( a_Param );
		break;
	case EV_GMObservingQuestListEnd:
		HandleGMObservingQuestListEnd();
		break;
	case EV_GMObservingQuestItem:
		HandleGMObservingQuestItem( a_Param );
		break;
	}
}

function HandleGMObservingQuestListStart()
{
	m_hOwnerWnd.ShowWindow();
	m_hOwnerWnd.SetFocus();
	HandleQuestListStart();
}

function HandleGMObservingQuestList( String a_Param )
{
	HandleQuestList( a_Param );
}

function HandleGMObservingQuestListEnd()
{
	UpdateQuestCount();
	UpdateItemCount( 0, -1 );
}

function HandleGMObservingQuestItem( String a_Param )
{
	local int ClassID;
	local int ItemCount;

	ParseInt( a_Param, "ClassID", ClassID );
	ParseInt( a_Param, "ItemCount", ItemCount );

	UpdateItemCount( ClassID, ItemCount );
}

defaultproperties
{
     m_WindowName="GMQuestWnd.InnerWnd"
}
