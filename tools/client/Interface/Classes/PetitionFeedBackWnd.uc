class PetitionFeedBackWnd extends UICommonAPI;

const MAX_FEEDBACK_STRING_LENGTH = 512;

const FEEBACKRATE_VeryGood = 0;
const FEEBACKRATE_Good = 1;
const FEEBACKRATE_Normal = 2;
const FEEBACKRATE_Bad = 3;
const FEEBACKRATE_VeryBad = 4;

function OnLoad()
{
}

function OnEvent( int a_EventID, String a_Param )
{
}

function OnHide()
{
	ExecuteEvent( EV_EnablePetitionFeedback, "Enable=0" );
}

function OnClickButton( String a_ControlID )
{
	switch( a_ControlID )
	{
	case "OKButton":
		OnClickOKButton();
		break;
	}
}

function OnClickOKButton()
{
	local String SelectedRadioButtonName;
	local int FeedbackRate;
	local String FeedbackMessage;
	local Color TextColor;

	SelectedRadioButtonName = class'UIAPI_WINDOW'.static.GetSelectedRadioButtonName( "PetitionFeedBackWnd", 1 );
	switch( SelectedRadioButtonName )
	{
	case "VeryGood":
		FeedbackRate = FEEBACKRATE_VeryGood;
		break;
	case "Good":
		FeedbackRate = FEEBACKRATE_Good;
		break;
	case "Normal":
		FeedbackRate = FEEBACKRATE_Normal;
		break;
	case "Bad":
		FeedbackRate = FEEBACKRATE_Bad;
		break;
	case "VeryBad":
		FeedbackRate = FEEBACKRATE_VeryBad;
		break;
	}

	TextColor.R = 176;
	TextColor.G = 155;
	TextColor.B = 121;
	TextColor.A = 255;
	FeedbackMessage = class'UIAPI_MULTIEDITBOX'.static.GetString( "PetitionFeedBackWnd.MultiEdit" );

	if( Len( FeedbackMessage ) > MAX_FEEDBACK_STRING_LENGTH )
		AddSystemMessage( FeedbackMessage, TextColor );

	class'PetitionAPI'.static.RequestPetitionFeedBack( FeedbackRate, FeedbackMessage );
	HideWindow( "PetitionFeedBackWnd" );
}
