class CouponEventWnd extends UIScript;

// Declare Global Variables;
var string CurrentInput;
var bool completeEditbox;
var array<int> completebox;

function OnLoad()
{
	registerEvent(EV_ShowPCCafeCouponUI);
	class'UIAPI_WINDOW'.static.HideWindow("CouponEventWnd");
	completebox.length = 5;
	initValue();
}      

// Initialize Global Variables on Load 
function initValue()
{
	CurrentInput = "";
	completeEditbox = false;
	completebox[1] = 0;
	completebox[2] = 0;
	completebox[3] = 0;
	completebox[4] = 0;
	completebox[5] = 0;
}

function resetEditBox()
{
	local int i;
	for (i=1; i<=5;++i)
	{
		class'UIAPI_EDITBOX'.static.SetString("CouponEventWnd.input" $ i,"");
	}
}

function OnShow()
{
	initValue();
	resetEditBox();
	// default value is to set disable input button until the edit box completed. 
	class'UIAPI_WINDOW'.static.DisableWindow("CouponEventWnd.inputnumber");
	class'UIAPI_WINDOW'.static.SetFocus("CouponEventWnd.input1");
}

//Server Event Handler
function OnEvent( int Event_ID, string param )
{

	if(Event_ID == EV_ShowPCCafeCouponUI)
	{
		class'UIAPI_WINDOW'.static.ShowWindow("CouponEventWnd");
	}
}

//Send back current input value to the server
function OnClickButton( string strID )
{
	if( strID == "inputnumber" )
	{
		Proc_Delivery();
		//debug (CurrentInput);
		resetEditBox();
		initValue();
		class'UIAPI_WINDOW'.static.HideWindow("CouponEventWnd");
	}
	if( strID == "resetbtn" )
	{
		resetEditBox();
		initValue();
		class'UIAPI_WINDOW'.static.SetFocus("CouponEventWnd.input1");
	}
}

function Proc_Delivery()
{
	RequestPCCafeCouponUse(CurrentInput);
	//debug ("finalinput:" @ CurrentInput);
}

function OnChangeEditBox( string EditBoxID )
{
	if (EditBoxID == "input1")
	{
		count_editBox(EditBoxID);
		//debug("CurrentEditBox:"@ EditBoxID);
	}
	if (EditBoxID == "input2")
	{
		count_editBox(EditBoxID);
		//debug("CurrentEditBox:"@ EditBoxID);
	}
	if (EditBoxID == "input3")
	{
		count_editBox(EditBoxID);
		//debug("CurrentEditBox:"@ EditBoxID);
	}
	if (EditBoxID == "input4")
	{
		count_editBox(EditBoxID);
		//debug("CurrentEditBox:"@ EditBoxID);
	}
	if (EditBoxID == "input5")
	{
		count_editBox(EditBoxID);
		//debug("CurrentEditBox:"@ EditBoxID);
	}
}

function count_editBox(string currentboxnum)
{
	local array<string> inputtxt;
	local int currentboxNumint;
	local int i;
	inputtxt.length = 5;
	currentboxNumint = Int(Right(currentboxnum,1));
	//debug(""$currentboxNumint);
	inputtxt[currentboxNumint] = "" $ class'UIAPI_EDITBOX'.static.GetString("CouponEventWnd.input" $ currentboxNumint);
	//debug(inputtxt[currentboxNumint]);
	if (len(inputtxt[currentboxNumint]) == 4)
	{
		completebox[currentboxNumint] = 1;
		if (currentboxNumint != 5)
		{
			class'UIAPI_WINDOW'.static.SetFocus("CouponEventWnd.input" $ currentboxNumint +1);
		}
		//debug("currentvalue" $ currentboxNumint $ ":" $ completebox[currentboxNumint]);
	}
	else
	{
		completebox[currentboxNumint] = 0;
	}

	for (i=1; i<=5;++i)
	{
	}
	
	if (completebox[1] == 1 && completebox[2] == 1 && completebox[3] == 1 && completebox[4] == 1 && completebox[5] == 1)
	{
		completeEditbox = true;
		CurrentInput = "" $ class'UIAPI_EDITBOX'.static.GetString("CouponEventWnd.input1") $ class'UIAPI_EDITBOX'.static.GetString("CouponEventWnd.input2") $ class'UIAPI_EDITBOX'.static.GetString("CouponEventWnd.input3") $ class'UIAPI_EDITBOX'.static.GetString("CouponEventWnd.input4") $ class'UIAPI_EDITBOX'.static.GetString("CouponEventWnd.input5");
		class'UIAPI_WINDOW'.static.EnableWindow("CouponEventWnd.inputnumber");
		//debug("CurrntSum:"$ CurrentInput);
	}
	else
	{
		completeEditbox = false;
		class'UIAPI_WINDOW'.static.DisableWindow("CouponEventWnd.inputnumber");
	}	
	
}
