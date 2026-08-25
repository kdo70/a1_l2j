class PetitionWnd extends UICommonAPI;

function OnLoad()
{
	RegisterEvent( EV_ShowPetitionWnd );
	RegisterEvent( EV_PetitionChatMessage );
	RegisterEvent( EV_EnablePetitionFeedback );
	SetFeedBackEnable( false );
}

function OnHide()
{
	SetFeedBackEnable( false );
}

function SetFeedBackEnable( bool a_IsEnabled )
{
	if( a_IsEnabled )
		class'UIAPI_BUTTON'.static.EnableWindow( "PetitionWnd.FeedBackButton" );
	else
		class'UIAPI_BUTTON'.static.DisableWindow( "PetitionWnd.FeedBackButton" );
}

function OnEvent( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	case EV_ShowPetitionWnd:
		HandleShowPetitionWnd();
		break;
	case EV_PetitionChatMessage:
		HandlePetitionChatMessage( a_Param );
		break;
	case EV_EnablePetitionFeedback:
		HandleEnablePetitionFeedback( a_Param );
		break;
	}
}

function OnCompleteEditBox( String strID )
{
	local String Message;

	switch( strID )
	{
	case "PetitionChatEditBox":
		Message = class'UIAPI_EDITBOX'.static.GetString( "PetitionWnd.PetitionChatEditBox" );
		ProcessPetitionChatMessage( Message );
		break;
	}
	
	class'UIAPI_EDITBOX'.static.Clear( "PetitionWnd.PetitionChatEditBox" );
}

function HandleShowPetitionWnd()
{
	if( m_hOwnerWnd.IsMinimizedWindow() )
		m_hOwnerWnd.NotifyAlarm();
	else
	{
		ShowWindow( "PetitionWnd" );
		m_hOwnerWnd.SetFocus();
	}
}

function HandlePetitionChatMessage( String a_Param )
{
	local String ChatMessage;
	local Color ChatColor;
	local int ColorR, ColorG, ColorB, ColorA;

	if( ParseString( a_Param, "Message", ChatMessage )
		&& ParseInt( a_Param, "ColorR", ColorR )
		&& ParseInt( a_Param, "ColorG", ColorG )
		&& ParseInt( a_Param, "ColorB", ColorB )
		&& ParseInt( a_Param, "ColorA", ColorA )
		)
	{
		ChatColor.R = ColorR;
		ChatColor.G = ColorG;
		ChatColor.B = ColorB;
		ChatColor.A = ColorA;
		class'UIAPI_TEXTLISTBOX'.static.AddString( "PetitionWnd.PetitionChatWindow", ChatMessage, ChatColor );
	}

}

function HandleEnablePetitionFeedback( String a_Param )
{
	local int Enable;

	if( ParseInt( a_Param, "Enable", Enable ) )
	{
		if( 1 == Enable )
			SetFeedBackEnable( true );
		else
			SetFeedBackEnable( false );
	}
}

function OnClickButton( String a_ControlID )
{
	switch( a_ControlID )
	{
	case "FeedBackButton":
		OnClickFeedBackButton();
		break;
	case "CancelButton":
		OnClickCancelButton();
		break;
	}
}

function OnClickFeedBackButton()
{
	class'UIAPI_WINDOW'.static.ShowWindow( "PetitionFeedBackWnd" );
}

function OnClickCancelButton()
{
	SetFeedBackEnable( false );
	class'PetitionAPI'.static.RequestPetitionCancel();
}

function Clear()
{
	class'UIAPI_TEXTLISTBOX'.static.Clear( "PetitionWnd.PetitionChatWindow" );
}

