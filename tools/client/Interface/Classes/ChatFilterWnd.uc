class ChatFilterWnd extends UIScript;

// 채팅 필터 윈도우

function OnClickButton(string strID)
{
	if( strID == "ChatFilterOK" )
	{
		SaveChatFilterOption();
		class'UIAPI_WINDOW'.static.HideWindow( "ChatFilterWnd" );
	}
	else if( strID == "ChatFilterCancel" )
	{
		class'UIAPI_WINDOW'.static.HideWindow( "ChatFilterWnd" );
	}
}

function OnClickCheckBox( String strID )
{
	local ChatWnd	script;
	local int chatType;

	script = ChatWnd( GetScript("ChatWnd") );
	chatType = script.m_chatType;

	if( strID == "CheckBoxSystem" )
	{
		// 큰 카테고리가 체크 되었는지 여부에 따라 작은 카테고리의 checkbox를 활성/비활성 한다.
		if( !class'UIAPI_CHECKBOX'.static.IsChecked( "ChatFilterWnd.CheckBoxSystem" ) )
		{
			class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxDamage", true );
			class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxItem", true );
		}
		else
		{
			class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxDamage", false );
			class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxItem", false );
		}
	}
//	else if( strID == "CheckBoxChat" )
//	{
//		// 큰 카테고리가 체크 되었는지 여부에 따라 작은 카테고리의 checkbox를 활성/비활성 한다.
//		if( !class'UIAPI_CHECKBOX'.static.IsChecked( "ChatFilterWnd.CheckBoxChat" ) )
///		{
	//		class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxNormal", true );
	//		class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxShout", true );
	//		class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxPledge", true );
	//		class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxParty", true );
	//		class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxTrade", true );
	//		class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxWhisper", true );
	//		class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxAlly", true );
	//		class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxHero", true );
	//		class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxUnion", true );
	//	}
	//	else
	//	{
	//		class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxNormal", true );
	//		class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxShout", true );
	//		class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxPledge", true );
	//		class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxParty", true );
	//		class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxTrade", true );
	//		class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxWhisper", true );
	//		class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxAlly", true );
	//		class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxHero", true );
	//		class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxUnion", true );
	//	}
//
//	}
	 else if ( strID == "SystemMsgBox")
	 {
		if( class'UIAPI_CHECKBOX'.static.IsChecked( "ChatFilterWnd.SystemMsgBox" ) )
		{
			class'UIAPI_CHECKBOX'.static.EnableWindow( "ChatFilterWnd.DamageBox" );
			class'UIAPI_CHECKBOX'.static.EnableWindow( "ChatFilterWnd.ItemBox" );
		}
		else
		{
			class'UIAPI_CHECKBOX'.static.DisableWindow( "ChatFilterWnd.DamageBox" );
			class'UIAPI_CHECKBOX'.static.DisableWindow( "ChatFilterWnd.ItemBox" );
		}
	}
	
	class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxNormal", false );
	class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxShout", false );
	class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxPledge", false );
	class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxParty", false );
	class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxTrade", false );
	class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxWhisper", false );
	class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxAlly", false );
	class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxHero", false );
	class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxUnion", false );
	
	switch( chatType )
		{
		case script.CHAT_WINDOW_TRADE:
			class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxTrade", true );
			break;
		case script.CHAT_WINDOW_PARTY:
			class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxParty", true );
			break;
		case script.CHAT_WINDOW_CLAN:
			class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxPledge", true );
			break;
		case script.CHAT_WINDOW_ALLY:
			class'UIAPI_CHECKBOX'.static.SetDisable( "ChatFilterWnd.CheckBoxAlly", true );
			break;
		default:
			break;
		}
}

function SaveChatFilterOption()
{
	local ChatWnd	script;
	local int chatType;
	local bool bChecked;
	
	script = ChatWnd( GetScript("ChatWnd") );
	chatType = script.m_chatType;
	script.m_filterInfo[chatType].bSystem = int( class'UIAPI_CHECKBOX'.static.IsChecked( "ChatFilterWnd.CheckBoxSystem" ) );
	script.m_filterInfo[chatType].bUseitem = int( class'UIAPI_CHECKBOX'.static.IsChecked( "ChatFilterWnd.CheckBoxItem" ) );
	script.m_filterInfo[chatType].bDamage = int( class'UIAPI_CHECKBOX'.static.IsChecked( "ChatFilterWnd.CheckBoxDamage" ) );
	script.m_filterInfo[chatType].bChat = int( class'UIAPI_CHECKBOX'.static.IsChecked( "ChatFilterWnd.CheckBoxChat" ) );
	script.m_filterInfo[chatType].bNormal = int( class'UIAPI_CHECKBOX'.static.IsChecked( "ChatFilterWnd.CheckBoxNormal" ) );
	script.m_filterInfo[chatType].bParty = int( class'UIAPI_CHECKBOX'.static.IsChecked( "ChatFilterWnd.CheckBoxParty" ) );
	script.m_filterInfo[chatType].bShout = int( class'UIAPI_CHECKBOX'.static.IsChecked( "ChatFilterWnd.CheckBoxShout" ) );
	script.m_filterInfo[chatType].bTrade = int( class'UIAPI_CHECKBOX'.static.IsChecked( "ChatFilterWnd.CheckBoxTrade" ) );
	script.m_filterInfo[chatType].bClan = int( class'UIAPI_CHECKBOX'.static.IsChecked( "ChatFilterWnd.CheckBoxPledge" ) );
	script.m_filterInfo[chatType].bWhisper = int( class'UIAPI_CHECKBOX'.static.IsChecked( "ChatFilterWnd.CheckBoxWhisper" ) );
	script.m_filterInfo[chatType].bAlly = int( class'UIAPI_CHECKBOX'.static.IsChecked( "ChatFilterWnd.CheckBoxAlly" ) );
	script.m_filterInfo[chatType].bHero = int( class'UIAPI_CHECKBOX'.static.IsChecked( "ChatFilterWnd.CheckBoxHero" ) );
	script.m_filterInfo[chatType].bUnion = int( class'UIAPI_CHECKBOX'.static.IsChecked( "ChatFilterWnd.CheckBoxUnion" ) );
	script.m_NoUnionCommanderMessage = int( class'UIAPI_CHECKBOX'.static.IsChecked( "ChatFilterWnd.CheckBoxCommand" ) );

	// 시스템메시지전용창 - SystemMsgBox
	bChecked = class'UIAPI_CHECKBOX'.static.IsChecked( "ChatFilterWnd.SystemMsgBox" );
	SetOptionBool( "Game", "SystemMsgWnd", bChecked );

	// 데미지 - DamageBox
	bChecked = class'UIAPI_CHECKBOX'.static.IsChecked( "ChatFilterWnd.DamageBox" );
	SetOptionBool( "Game", "SystemMsgWndDamage", bChecked );

	// 소모성아이템사용 - ItemBox
	bChecked = class'UIAPI_CHECKBOX'.static.IsChecked( "ChatFilterWnd.ItemBox" );
	SetOptionBool( "Game", "SystemMsgWndExpendableItem", bChecked );
	
	if (GetOptionBool( "Game", "SystemMsgWnd" ) )
	{
		 class'UIAPI_WINDOW'.static.ShowWindow("SystemMsgWnd");
	} 
	else 
	{
		class'UIAPI_WINDOW'.static.HideWindow("SystemMsgWnd");
	}
	
	
	SetINIBool(script.m_sectionName[chatType],"system", bool(script.m_filterInfo[chatType].bSystem), "chatfilter.ini");
	SetINIBool(script.m_sectionName[chatType],"damage", bool(script.m_filterInfo[chatType].bDamage), "chatfilter.ini");
	SetINIBool(script.m_sectionName[chatType],"useitems", bool(script.m_filterInfo[chatType].bUseItem), "chatfilter.ini");
	SetINIBool(script.m_sectionName[chatType],"chat", bool(script.m_filterInfo[chatType].bChat), "chatfilter.ini");
	SetINIBool(script.m_sectionName[chatType],"normal", bool(script.m_filterInfo[chatType].bNormal), "chatfilter.ini");
	SetINIBool(script.m_sectionName[chatType],"party", bool(script.m_filterInfo[chatType].bParty), "chatfilter.ini");
	SetINIBool(script.m_sectionName[chatType],"shout", bool(script.m_filterInfo[chatType].bShout), "chatfilter.ini");
	SetINIBool(script.m_sectionName[chatType],"market", bool(script.m_filterInfo[chatType].bTrade), "chatfilter.ini");
	SetINIBool(script.m_sectionName[chatType],"pledge", bool(script.m_filterInfo[chatType].bClan), "chatfilter.ini");
	SetINIBool(script.m_sectionName[chatType],"tell", bool(script.m_filterInfo[chatType].bWhisper), "chatfilter.ini");
	SetINIBool(script.m_sectionName[chatType],"ally", bool(script.m_filterInfo[chatType].bAlly), "chatfilter.ini");	
	SetINIBool(script.m_sectionName[chatType],"hero", bool(script.m_filterInfo[chatType].bHero), "chatfilter.ini");
	SetINIBool(script.m_sectionName[chatType],"union", bool(script.m_filterInfo[chatType].bUnion), "chatfilter.ini");
	
	//Global Setting
	SetINIBool("global","command", bool(script.m_NoUnionCommanderMessage), "chatfilter.ini");
	
	
	
}

