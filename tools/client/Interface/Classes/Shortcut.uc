class Shortcut extends UIScript;

var bool m_chatstateok;

const CHAT_WINDOW_NORMAL = 0;
const CHAT_WINDOW_TRADE = 1;
const CHAT_WINDOW_PARTY = 2;
const CHAT_WINDOW_CLAN = 3;
const CHAT_WINDOW_ALLY = 4;
const CHAT_WINDOW_COUNT = 5;
const CHAT_WINDOW_SYSTEM = 5;		// 시스템 메시지 창

function OnLoad()
{
	RegisterEvent( EV_ShortcutCommand );
}

function OnEvent( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	case EV_ShortcutCommand:
		HandleShortcutCommand( a_Param );
		break;
	}
}

//어째서인지 이리 들어오지 않습니다.
function OnExitState( name a_NextStateName )
{
	if (a_NextStateName == 'GamingState')
	{
		//debug("what?");
		m_chatstateok = true;
	}
	else
	{
		m_chatstateok = false;
	}
}


function HandleShortcutCommand( String a_Param )
{
	local String Command;
	
	if( ParseString( a_Param, "Command", Command ) )
	{
		switch( Command )
		{
		case "CloseAllWindow":		
			HandleCloseAllWindow();
			break;
		case "ShowChatWindow":		// alt + j
			HandleShowChatWindow();
			//if (m_chatstateok == true)
			//{
			//	HandleShowChatWindow();
			//}
			break;
		case "SetPrevChatType":		// alt + page up	
			HandleSetPrevChatType();
			break;
		case "SetNextChatType":		// alt + page down
			HandleSetNextChatType();
			break;
		}
	}
}

function HandleShowChatWindow()		// alt + j
{
	local WindowHandle handle;
	handle = GetHandle( "ChatWnd" );
	
	if( handle.IsShowWindow() )
	{
		handle.HideWindow();
		if( GetOptionBool("Game", "SystemMsgWnd") )
			class'UIAPI_WINDOW'.static.HideWindow("SystemMsgWnd");
			
	}
	else
	{
		handle.ShowWindow();
		if( GetOptionBool("Game", "SystemMsgWnd") )
			class'UIAPI_WINDOW'.static.ShowWindow("SystemMsgWnd");
	}
}

function HandleSetPrevChatType()		// alt + page up
{
	local ChatWnd chatWndScript;			// 채팅 윈도우 클래스
	
	chatWndScript = ChatWnd( GetScript("ChatWnd") );	// 스크립트를 가져온다.
	
	//debug("chatWndScript.m_chatType" $ chatWndScript.m_chatType);
	switch (chatWndScript.m_chatType)	
	{
		case CHAT_WINDOW_NORMAL:
			//chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_NORMAL);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_TRADE);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_PARTY);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_CLAN);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_ALLY);
			chatWndScript.ChatTabCtrl.SetTopOrder(4, true);
			chatWndScript.HandleTabClick("ChatTabCtrl4");
			break;
		case CHAT_WINDOW_TRADE:
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_NORMAL);
			//chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_TRADE);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_PARTY);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_CLAN);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_ALLY);
			chatWndScript.ChatTabCtrl.SetTopOrder(0, true);
			chatWndScript.HandleTabClick("ChatTabCtrl0");
			break;
		case CHAT_WINDOW_PARTY:
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_NORMAL);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_TRADE);
			//chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_PARTY);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_CLAN);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_ALLY);
			chatWndScript.ChatTabCtrl.SetTopOrder(1, true);
			chatWndScript.HandleTabClick("ChatTabCtrl1");
			break;
		case CHAT_WINDOW_CLAN:
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_NORMAL);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_TRADE);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_PARTY);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_CLAN);
			//chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_ALLY);
			chatWndScript.ChatTabCtrl.SetTopOrder(2, true);
			chatWndScript.HandleTabClick("ChatTabCtrl2");
			break;
		case CHAT_WINDOW_ALLY:
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_NORMAL);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_TRADE);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_PARTY);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_CLAN);
			//chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_ALLY);
			chatWndScript.ChatTabCtrl.SetTopOrder(3, true);
			chatWndScript.HandleTabClick("ChatTabCtrl3");
			break;		
	}

}

function HandleSetNextChatType()		// alt + page down
{
	local ChatWnd chatWndScript;			// 채팅 윈도우 클래스
	
	chatWndScript = ChatWnd( GetScript("ChatWnd") );	// 스크립트를 가져온다.
	
	//debug("chatWndScript.m_chatType" $ chatWndScript.m_chatType);
	switch (chatWndScript.m_chatType)	
	{
		case CHAT_WINDOW_NORMAL:
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_NORMAL);
			//chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_TRADE);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_PARTY);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_CLAN);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_ALLY);
			chatWndScript.ChatTabCtrl.SetTopOrder(1, true);
			chatWndScript.HandleTabClick("ChatTabCtrl1");
			break;
		case CHAT_WINDOW_TRADE:
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_NORMAL);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_TRADE);
			//chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_PARTY);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_CLAN);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_ALLY);
			chatWndScript.ChatTabCtrl.SetTopOrder(2, true);
			chatWndScript.HandleTabClick("ChatTabCtrl2");
			break;
		case CHAT_WINDOW_PARTY:
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_NORMAL);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_TRADE);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_PARTY);
			//chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_CLAN);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_ALLY);
			chatWndScript.ChatTabCtrl.SetTopOrder(3, true);
			chatWndScript.HandleTabClick("ChatTabCtrl3");
			break;
		case CHAT_WINDOW_CLAN:
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_NORMAL);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_TRADE);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_PARTY);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_CLAN);
			//chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_ALLY);
			chatWndScript.ChatTabCtrl.SetTopOrder(4, true);
			chatWndScript.HandleTabClick("ChatTabCtrl4");
			break;
		case CHAT_WINDOW_ALLY:
			//chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_NORMAL);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_TRADE);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_PARTY);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_CLAN);
			chatWndScript.ChatTabCtrl.MergeTab(CHAT_WINDOW_ALLY);
			chatWndScript.ChatTabCtrl.SetTopOrder(0, true);
			chatWndScript.HandleTabClick("ChatTabCtrl0");
			break;		
	}
}


function HandleCloseAllWindow()
{
	class'UIAPI_WINDOW'.static.HideWindow( "SystemMenuWnd" );
}
