class GMWnd extends UICommonAPI;

const DIALOGID_Recall = 0;
const DIALOGID_SendHome = 1;
const DIALOGID_NPCList = 2;
const DIALOGID_ItemList = 3;
const DIALOGID_SkillList = 4;

var Color m_WhiteColor;
var EditBoxHandle m_hEditBox;
var WindowHandle m_hGMwnd;
var WindowHandle m_hGMDetailStatusWnd;
var WindowHandle m_hGMInventoryWnd;
var WindowHandle m_hGMMagicSkillWnd;
var WindowHandle m_hGMQuestWnd;
var WindowHandle m_hGMWarehouseWnd;
var WindowHandle m_hGMClanWnd;

var int m_TargetID;

function OnLoad()
{
	RegisterEvent( EV_ShowGMWnd );
	RegisterEvent( EV_DialogOK );
	RegisterEvent( EV_DialogCancel );
	RegisterEvent( EV_TargetUpdate );

	m_hGMwnd = GetHandle( "GMWnd" );
	m_hEditBox = EditBoxHandle( GetHandle( "EditBox" ) );
	m_hGMDetailStatusWnd = GetHandle( "GMDetailStatusWnd" );
	m_hGMInventoryWnd = GetHandle( "GMInventoryWnd" );
	m_hGMMagicSkillWnd = GetHandle( "GMMagicSkillWnd" );
	m_hGMQuestWnd = GetHandle( "GMQuestWnd" );
	m_hGMWarehouseWnd = GetHandle( "GMWarehouseWnd" );
	m_hGMClanWnd = GetHandle( "GMClanWnd" );

	m_WhiteColor.R = 220;
	m_WhiteColor.G = 220;
	m_WhiteColor.B = 220;
	m_WhiteColor.A = 255;
	
	m_TargetID = 0;
}

function OnEvent( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	case EV_ShowGMWnd:
		HandleShowGMWnd();
		break;
	case EV_DialogOK:
		HandleDialogOK();
		break;
	case EV_DialogCancel:
		HandleDialogCancel();
		break;
	case EV_TargetUpdate:
		HandleTargetUpdate();
		break;
	}
}

function HandleShowGMWnd()
{
	if( m_hOwnerWnd.IsShowWindow() )
		m_hOwnerWnd.HideWindow();
	else
	{
		m_hOwnerWnd.ShowWindow();
		m_hGMwnd.SetFocus();	// 보일때 포커스를 GM창에 맞춥니다.
		//class'UIAPI_WINDOW'.static.SetFocus(m_hGMwnd);
	}
}

function HandleDialogOK()
{
	if( !DialogIsMine() )
		return;

	switch( DialogGetID() )
	{
	case DIALOGID_Recall:
		Recall();
		break;
	case DIALOGID_SendHome:
		SendHome();
		break;
	}
}

//타겟 정보 업데이트 처리	-- 입력창에 이름을 넣어주기
function HandleTargetUpdate()
{
	local int m_nowTargetID;
	local UserInfo	info;
			
	//타겟ID 얻어오기
	m_nowTargetID = class'UIDATA_TARGET'.static.GetTargetID();
			
	if(m_nowTargetID == m_TargetID) 	// 한번 스트링을 얻어온 적이 있으면 리턴.
	{
		//m_TargetID = 0;	// 이전의 타겟아이디를 초기화
		return;
	}
	
	if (m_nowTargetID<1)	// 아이디가 없으면 그냥 리턴.
	{
		m_TargetID = 0;	// 이전의 타겟아이디를 초기화
		m_hEditBox.SetString("");
		return;
	}
	GetTargetInfo(info);	// 아이디가 있을 경우에는 정보를 얻어온다. 

	if((m_nowTargetID>0 ) && (info.bNpc == false))	//NPC일경우에는 셋팅해주지 않는다. 
	{		
		m_hEditBox.SetString(info.Name);
	}
	
	m_TargetID = m_nowTargetID;	// 이전의 타겟아이디를 저장해둔다. 
}

function HandleDialogCancel()
{
	if( !DialogIsMine() )
		return;
}

function OnClickButton( String a_ButtonID )
{
	switch( a_ButtonID )
	{
	case "TeleButton":
		OnClickTeleButton();
		break;
	case "MoveButton":
		OnClickMoveButton();
		break;
	case "RecallButton":
		OnClickRecallButton();
		break;
	case "DetailStatusButton":
		OnClickDetailStatusButton();
		break;
	case "InventoryButton":
		OnClickInventoryButton();
		break;
	case "MagicSkillButton":
		OnClickMagicSkillButton();
		break;
	case "QuestButton":
		OnClickQuestButton();
		break;
	case "InfoButton":
		OnClickInfoButton();
		break;
	case "StoreButton":
		OnClickStoreButton();
		break;
	case "ClanButton":
		OnClickClanButton();
		break;
	case "PetitionButton":
		OnClickPetitionButton();
		break;
	case "SendHomeButton":
		OnClickSendHomeButton();
		break;
	case "NPCListButton":
		OnClickNPCListButton();
		break;
	case "ItemListButton":
		OnClickItemListButton();
		break;
	case "SkillListButton":
		OnClickSkillListButton();
		break;
	case "ForcePetitionButton":
		OnClickForcePetitionButton();
		break;
	case "ChangeServerButton":
		OnClickChangeServerButton();
		break;
	}
}

function OnClickTeleButton()
{
	local String EditBoxString;

	EditBoxString = m_hEditBox.GetString();
	if( EditBoxString != "" )
		ExecuteCommand( "//teleportto" @ EditBoxString );
}

function OnClickMoveButton()
{
	ExecuteCommand( "//instant_move" );
}

function OnClickRecallButton()
{
	DialogSetID( DIALOGID_Recall );
	DialogShow( DIALOG_OKCancel, GetSystemMessage( 1220 ) );
}

function Recall()
{
	local String EditBoxString;

	EditBoxString = m_hEditBox.GetString();
	if( EditBoxString != "" )
		ExecuteCommand( "//recall" @ EditBoxString );
}

function OnClickDetailStatusButton()
{
	local String EditBoxString;
	local GMDetailStatusWnd GMDetailStatusWndScript;

	EditBoxString = m_hEditBox.GetString();
	if( EditBoxString != "" )
	{
		GMDetailStatusWndScript = GMDetailStatusWnd( m_hGMDetailStatusWnd.GetScript() );
		GMDetailStatusWndScript.ShowStatus( EditBoxString );
	}
	else
		AddSystemMessage( GetSystemMessage( 364 ), m_WhiteColor );
}

function OnClickInventoryButton()
{
	local String EditBoxString;
	local GMInventoryWnd GMInventoryWndScript;

	EditBoxString = m_hEditBox.GetString();
	if( EditBoxString != "" )
	{
		GMInventoryWndScript = GMInventoryWnd( m_hGMInventoryWnd.GetScript() );
		GMInventoryWndScript.ShowInventory( EditBoxString );
	}
	else
		AddSystemMessage( GetSystemMessage( 364 ), m_WhiteColor );
}

function OnClickMagicSkillButton()
{
	local String EditBoxString;
	local GMMagicSkillWnd GMMagicSkillWndScript;

	EditBoxString = m_hEditBox.GetString();
	if( EditBoxString != "" )
	{
		GMMagicSkillWndScript = GMMagicSkillWnd( m_hGMMagicSkillWnd.GetScript() );
		GMMagicSkillWndScript.ShowMagicSkill( EditBoxString );
	}
	else
		AddSystemMessage( GetSystemMessage( 364 ), m_WhiteColor );
}

function OnClickQuestButton()
{
	local String EditBoxString;
	local GMQuestWnd GMQuestWndScript;

	EditBoxString = m_hEditBox.GetString();
	if( EditBoxString != "" )
	{
		GMQuestWndScript = GMQuestWnd( m_hGMQuestWnd.GetScript() );
		GMQuestWndScript.ShowQuest( EditBoxString );
	}
	else
		AddSystemMessage( GetSystemMessage( 364 ), m_WhiteColor );
}

function OnClickInfoButton()
{
	local String EditBoxString;

	EditBoxString = m_hEditBox.GetString();
	if( EditBoxString != "" )
		ExecuteCommand( "//debug" @ EditBoxString );
}

function OnClickStoreButton()
{
	local String EditBoxString;
	local GMWarehouseWnd GMWarehouseWndScript;

	debug("GMstore");
	EditBoxString = m_hEditBox.GetString();
	if( EditBoxString != "" )
	{
		GMWarehouseWndScript = GMWarehouseWnd( m_hGMWarehouseWnd.GetScript() );
		GMWarehouseWndScript.ShowWarehouse( EditBoxString );
	}
	else
		AddSystemMessage( GetSystemMessage( 364 ), m_WhiteColor );
}

function OnClickClanButton()
{
	local String EditBoxString;
	local GMClanWnd GMClanWndScript;

	EditBoxString = m_hEditBox.GetString();
	if( EditBoxString != "" )
	{
		GMClanWndScript = GMClanWnd( m_hGMClanWnd.GetScript() );
		GMClanWndScript.ShowClan( EditBoxString );
	}
	else
		AddSystemMessage( GetSystemMessage( 364 ), m_WhiteColor );
}

function OnClickPetitionButton()
{
	local String EditBoxString;

	EditBoxString = m_hEditBox.GetString();
	if( EditBoxString != "" )
		ExecuteCommand( "//add_peti_chat" @ EditBoxString );
}

function OnClickSendHomeButton()
{
	DialogSetID( DIALOGID_SendHome );
	DialogShow( DIALOG_OKCancel, GetSystemMessage( 1221 ) );
}

function SendHome()
{
	local String EditBoxString;

	EditBoxString = m_hEditBox.GetString();
	if( EditBoxString != "" )
		ExecuteCommand( "//sendhome" @ EditBoxString );
}

function OnClickNPCListButton()
{
	local int ID;
	local String EditBoxString;
	local WindowHandle m_dialogWnd;
	
	m_dialogWnd = GetHandle( "DialogBox" );	//다이얼로그 핸들 받아오기
	EditBoxString = m_hEditBox.GetString();
	if( EditBoxString == "" )
		return;

	for( ID = class'UIDATA_NPC'.static.GetFirstID(); -1 != ID ; ID = class'UIDATA_NPC'.static.GetNextID() )
	{
		if( class'UIDATA_NPC'.static.IsValidData( ID )
			&& class'UIDATA_NPC'.static.GetNPCName( ID ) == EditBoxString )
		{
			if( DialogIsMine() && m_dialogWnd.IsShowWindow())	//이미 다이얼로그가 떠있다면 지워준다.
			{
				DialogHide();
				m_dialogWnd.HideWindow();
			}
			DialogSetID( DIALOGID_NPCList );
			DialogShow( DIALOG_OK, "ClassID:" $ ID + 1000000 @ "Name:" $ EditBoxString );
			break;
		}
	}
}

function OnClickItemListButton()
{
	local int ID;
	local String EditBoxString;
	local WindowHandle m_dialogWnd;
	
	m_dialogWnd = GetHandle( "DialogBox" );	//다이얼로그 핸들 받아오기
	EditBoxString = m_hEditBox.GetString();
	if( EditBoxString == "" )
		return;

	for( ID = class'UIDATA_ITEM'.static.GetFirstID(); -1 != ID ; ID = class'UIDATA_ITEM'.static.GetNextID() )
	{
		if( class'UIDATA_ITEM'.static.GetItemName( ID ) == EditBoxString )
		{
			if( DialogIsMine() && m_dialogWnd.IsShowWindow())	//이미 다이얼로그가 떠있다면 지워준다.
			{
				DialogHide();
				m_dialogWnd.HideWindow();
			}
			DialogSetID( DIALOGID_ItemList );
			DialogShow( DIALOG_OK, "ClassID:" $ ID @ "Name:" $ EditBoxString );
			break;
		}
	}
}

function OnClickSkillListButton()
{
	local int ID;
	local String EditBoxString;
	local WindowHandle m_dialogWnd;
	
	m_dialogWnd = GetHandle( "DialogBox" );	//다이얼로그 핸들 받아오기
	EditBoxString = m_hEditBox.GetString();
	if( EditBoxString == "" )
		return;

	for( ID = class'UIDATA_SKILL'.static.GetFirstID(); -1 != ID ; ID = class'UIDATA_SKILL'.static.GetNextID() )
	{
		if( class'UIDATA_SKILL'.static.GetName( ID, 1 ) == EditBoxString )
		{
			if( DialogIsMine() && m_dialogWnd.IsShowWindow())	//이미 다이얼로그가 떠있다면 지워준다.
			{
				DialogHide();
				m_dialogWnd.HideWindow();
			}
			DialogSetID( DIALOGID_SkillList );
			DialogShow( DIALOG_OK, "ClassID:" $ ID @ "Name:" $ EditBoxString );
			break;
		}
	}
}

function OnClickForcePetitionButton()
{
	local String EditBoxString;

	EditBoxString = m_hEditBox.GetString();
	if( EditBoxString != "" )
		ExecuteCommand( "//force_peti" @ EditBoxString @ GetSystemMessage( 1528 ) );
}

function OnClickChangeServerButton()
{
	local String EditBoxString;
	local UserInfo PlayerInfo;

	EditBoxString = m_hEditBox.GetString();

	if( EditBoxString == "" )
		return;

	if( !GetPlayerInfo( PlayerInfo ) )
		return;

	class'GMAPI'.static.BeginGMChangeServer( int( EditBoxString ), PlayerInfo.Loc );
}
