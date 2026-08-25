class CalculatorWnd extends UICommonAPI;

// 계산기의 상태
const STATE_INSERT_OP1=0;
const STATE_OP1=1;
const STATE_OP=2;
const STATE_INSERT_OP2=3;

var int m_iState;

const OP_PLUS=0;
const OP_MINUS=1;
const OP_MULTIPLY=2;
const OP_DIVIDE=3;
const OP_EQUAL=4;


var float m_fOperand1;
var int m_nOperator;


function OnLoad()
{
	RegisterEvent( EV_CalculatorWndShowHide );
}

function OnShow()
{
	InitCalculator();
	class'UIAPI_WINDOW'.static.SetFocus("CalculatorWnd.editBoxCalculate");
}

function Clear()
{
	class'UIAPI_EDITBOX'.static.Clear("CalculatorWnd.editBoxCalculate");
}

function InitCalculator()
{
	m_fOperand1 = 0;
	m_nOperator = -1;
	SetState(STATE_OP1);
	AddNum(0);
}

function CE()
{
	Clear();
	SetString("0");
}

function SetState(int iState)
{
	m_iState=iState;
}

function SetOperand1(string str)
{
	if(Len(str)>0) 
		m_fOperand1 = float(str);
	else 
		m_fOperand1 = 0f;
}

function SetOperator(int op)
{
	m_nOperator = op;
}

function AddString(string str)
{
	local string strTempGet;
	local string strTempResult;

	strTempGet=GetString();
	strTempResult=strTempGet$""$str;

	class'UIAPI_EDITBOX'.static.SetString("CalculatorWnd.editBoxCalculate", strTempResult);
}

function SetString(string str)
{
	class'UIAPI_EDITBOX'.static.SetString("CalculatorWnd.editBoxCalculate", str);
}

function string GetString()
{
	local string strTemp;
	strTemp=class'UIAPI_EDITBOX'.static.GetString("CalculatorWnd.editBoxCalculate");
	return strTemp;
}

function float GetOperand()
{
//	SetCommaStr();
	local string str;
	str=GetString();

	if(Len(str)>0) 
		return float(str);
	else 
		return 0;
}

function AddNum(float num)
{
	local string strTemp;
	Clear();
	AddString(strtemp$""$int(num));
}



function float Calc(float A, float B,int op)
{ 
	switch(op)
	{
		case -1: 
			return B;
		case OP_PLUS : 
			return A+B;
		case OP_MINUS : 
			return A-B;
		case OP_MULTIPLY : 
			return A*B;
		case OP_DIVIDE : 
				if(B == 0 ) 
					return 0;
				return A/B;
	}

	return 0;
}

function bool ExecOverFlow(float a,float b,int op,float result)
{ 
	switch(op)
	{
		case OP_PLUS :
		case OP_MULTIPLY :
			if(a>0 && b>0 && (result<0 || result > 100000000000000000000.f)) 
			{
				InitCalculator();
				return true;
			}
			break;
		case OP_MINUS :
		case OP_DIVIDE :
			break;
	}

	return false;
}

function BackSpace()
{
	local string strTemp;
	local string strResult;
	local int iLength;

	strTemp=GetString();

	iLength=Len(strTemp)-1;

//	debug("BackSpace:"$strTemp$", "$iLength);

	if(iLength>0)
	{
		strResult=Left(strTemp, iLength);
		SetString(strResult);
	}
	else
	{
		CE();
	}
}


function OnEvent( int Event_ID, string param )
{
	switch( Event_ID )
	{
	case EV_CalculatorWndShowHide :
		ShowWindowWithFocus("CalculatorWnd");
		break;
	}
}


function ProcessBtn(int iValue)
{
	local int iTemp;
	local string strTemp;
	local string strTemp2;
	local float result;
	local float fTmp;
	local string strTmp3;
	local string strTempGet;	//길이를 찾기위한 임시 temp

	strTempGet=GetString();
	
	if(Len(strTempGet) > 24)
		return;

	if ( iValue == 0x000d )			// Enter 키는 "=" 으로 해석해준다
	{
		iValue = 0x003d;
	}

	// 숫자키일 경우의 처리
 	if ( iValue >= 0x0030 && iValue <= 0x0039 )
	{
		if(m_iState == STATE_INSERT_OP1 || m_iState == STATE_INSERT_OP2)
		{
			if(GetString()=="0")
			{
				if(iValue != 0x0030) 
				{
					Clear();
				}
			}
		}
		
		if(m_iState == STATE_OP1)
		{
			Clear();
			SetState(STATE_INSERT_OP1);
		}	
		else if(m_iState == STATE_OP)
		{
			SetOperand1(GetString());
			Clear();
			SetState(STATE_INSERT_OP2);
		}
	
		strTemp=GetString();
		iTemp=iValue-48;
		strTemp2=""$iTemp;

		if ( Len(strTemp) > 0 )
		{
			AddString(strTemp2);
		}
		else
		{
			SetString(strTemp2);
		}
		
//		SetCommaStr();
	}
	else
	{

 		if(iValue == 0x002a || iValue == 0x002b || iValue == 0x002d || iValue == 0x002f || iValue == 0x003d )
		{
 			if(m_iState == STATE_OP1)
	 		{
				SetState(STATE_OP);
 			}
			else if(m_iState == STATE_INSERT_OP1)
			{
				SetOperand1(GetString());
//				SetCommaStr();
				SetState(STATE_OP);
			}
			else if(m_iState == STATE_INSERT_OP2)
			{
				result = Calc(m_fOperand1,GetOperand(),m_nOperator);

				if(!ExecOverFlow(m_fOperand1,GetOperand(),m_nOperator,result))
				{
					SetOperand1(GetString());
//					SetCommaStr();
					AddNum(result);
					SetState(STATE_OP);
				}

			}
			else if(m_iState == STATE_OP && iValue == 0x003d)
			{
 				fTmp = GetOperand();
				result = Calc(fTmp,m_fOperand1,m_nOperator);

 				if(!ExecOverFlow(fTmp,m_fOperand1,m_nOperator,result))
				{
					strTmp3=""$int(result);
					Clear();
 					AddString(strTmp3);
				}
			}
		}
		
		if(iValue == 0x002a) // *
		{
            SetOperator(OP_MULTIPLY);
		}
		else if(iValue == 0x002b) //+
		{
			SetOperator(OP_PLUS);
		}
		else if(iValue == 0x002d) //-
		{
			SetOperator(OP_MINUS);
		}
		else if(iValue == 0x002f) ///
		{
			SetOperator(OP_DIVIDE);	
		}
		else if(iValue == 0x003d) //=
		{
		}

	}
}




function OnClickButton(string strID)
{
	switch(strID)
	{
		case "btn7" : 
			ProcessBtn(0x0037); 
			break;
		case "btn8" : 
			ProcessBtn(0x0038); 
			break;
		case "btn9" : 
			ProcessBtn(0x0039);
			break;
		case "btnAdd" : 
			ProcessBtn(0x002b); 
			break;
		case "btnCE" : 
			CE();
			break;
		case "btn4" : 
			ProcessBtn(0x0034); 
			break;
		case "btn5" : 
			ProcessBtn(0x0035); 
			break;
		case "btn6" : 
			ProcessBtn(0x0036); 
			break;
		case "btnSub" : 
			ProcessBtn(0x002d); 
			break;
		case "btnC" : 
			InitCalculator(); 
			break;
		case "btn1" : 
			ProcessBtn(0x0031); 
			break;
		case "btn2" : 
			ProcessBtn(0x0032); 
			break;
		case "btn3" : 
			ProcessBtn(0x0033); 
			break;
		case "btnMul" : 
			ProcessBtn(0x002a); 
			break;
		case "btnBS" : 
			BackSpace();
			break;
		case "btn0" : 
			ProcessBtn(0x0030); 
			break;
		case "btn00" : 
			ProcessBtn(0x0030);
			ProcessBtn(0x0030);
			break;
		case "btnDiv" : 
			ProcessBtn(0x002f); 
			break;
		case "btnEQ" : 
			ProcessBtn(0x003d); 
			break;

		case "btnClose" :
			class'UIAPI_WINDOW'.static.HideWindow("CalculatorWnd");
		break;

	}
}
