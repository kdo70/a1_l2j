class UICommonAPI extends UIScript;

// Dialog API
enum EDialogType
{
	DIALOG_OKCancel,
	DIALOG_OK,
	DIALOG_OKCancelInput,
	DIALOG_OKInput,
	DIALOG_Warning,
	DIALOG_Notice,
	DIALOG_NumberPad,
	DIALOG_Progress,
};

enum DialogDefaultAction
{
	EDefaultNone,
	EDefaultOK,
	EDefaultCancel,
};

// 다이얼로그를 보여준다. strMessage : 함께 보여줄 스트링( 예를들어 "개수를 입력해 주세요" )
// 무척 간단한 다이얼로그가 아닌 이상 DialogSetID() 같이 불러줘야 한다.
function DialogShow( EDialogType dialogType, string strMessage )
{
	local DialogBox	script;
	script = DialogBox(GetScript("DialogBox"));
	script.ShowDialog( dialogType, strMessage, string(Self) );
}

// 다이얼로그를 감춘다. 다이얼로그가 떠 있는 상황에서 다른 다이얼로그를 보여주려면 DialogHide() 를 먼저 호출해야한다.
function DialogHide()
{
	local DialogBox	script;
	script = DialogBox(GetScript("DialogBox"));
	script.HideDialog();
}

// 엔터 키를 눌렀을 경우 다이얼로그가 어떤 동작을 취할지를 세팅하는 함수이다.
// 이 함수를 부르지 않으면 엔터키가 들어오면 Cancel 버튼을 누른 것과 같은 동작을 한다.
// 한번 사용되고나면 초기화 되므로 디폴트 액션을 OK로 하고싶으면 매번 다이얼로그 띄울 때 마다 불러줘야한다.
function DialogSetDefaultOK()
{
	local DialogBox	script;
	script = DialogBox(GetScript("DialogBox"));
	script.SetDefaultAction( EDefaultOK );
}

// EV_DialogOK 등의 다이얼로그 이벤트가 왔을 때, 이 다이얼로그가 자신이 띄운 다이얼로그 인지를 판별할 때 쓰인다. 남이 띄운 다이얼로그라면 신경쓸 필요가 없다~
function bool DialogIsMine()
{
	local DialogBox	script;
	script = DialogBox(GetScript("DialogBox"));
	if( script.GetTarget() == string(Self) )
		return true;
	return false;
}

// 한개의 uc에서 다이얼로그를 한번만 띄운다면 쓸 필요가 없겠지만, 다이얼로그를 여러 상황에서 쓴다면, 예를 들어 혈맹.uc에서  혈원아이디를 묻는데도 쓰고
// 혈원 호칭을 입력 받는 데도 사용한다면, 다이얼로그 이벤트가 왔을때 자신이 어떤 다이얼로그를 띄웠는지를 알 필요가 있다.
// 이럴 경우 다이얼로그를 띄울 때 적절하게 아무 숫자나 DialogSetID() 해 주고 이벤트 처리 부분에서 DialogGetID()를 해서 그에 맞게 코드를 짜면된다.
function DialogSetID( int id )
{
	local DialogBox	script;
	script = DialogBox(GetScript("DialogBox"));
	script.SetID( id );
}

// 다이어로그의 에디트 박스의 입력 타입을 지정해 줄 수 있다. 일반 문자열, 숫자, 패스워드 등, XML 프로토콜 문서 참조.
function DialogSetEditType( string strType )
{
	local DialogBox	script;
	script = DialogBox(GetScript("DialogBox"));
	script.SetEditType( strType );
}

// 다이얼로그의 에디트박스에 입력된 스트링을 받아온다
function string DialogGetString()
{
	local DialogBox	script;
	script = DialogBox(GetScript("DialogBox"));
	return script.GetEditMessage();
}

// 다이얼로그의 에디트박스에 스트링을 입력한다
function DialogSetString(string strInput)
{
	local DialogBox	script;
	script = DialogBox(GetScript("DialogBox"));
	script.SetEditMessage(strInput);
}

function int DialogGetID()
{
	local DialogBox	script;
	script = DialogBox(GetScript("DialogBox"));
	return script.GetID();
}

// ParamInt는 다이얼로그의 동작과 관련된 상수들을 지정해 주는데 쓰인다. Progress의 timeup 시간, NumberPad에서 max값 등.
function DialogSetParamInt( int param )
{
	local DialogBox	script;
	script = DialogBox(GetScript("DialogBox"));
	script.SetParamInt( param );
}

// ReservedXXX 값들은 다이얼로그에 넣어놨다가 다시 꺼내 볼 수 있다는 점에서 ParamXXX와는 다르다.
function DialogSetReservedInt( int value )
{
	local DialogBox	script;
	script = DialogBox(GetScript("DialogBox"));
	script.SetReservedInt( value );
}

function DialogSetReservedInt2( int value )
{
	local DialogBox	script;
	script = DialogBox(GetScript("DialogBox"));
	script.SetReservedInt2( value );
}

function DialogSetReservedInt3( int value )
{
	local DialogBox	script;
	script = DialogBox(GetScript("DialogBox"));
	script.SetReservedInt3( value );
}

function int DialogGetReservedInt()
{
	local DialogBox	script;
	script = DialogBox(GetScript("DialogBox"));
	return script.GetReservedInt();
}

function int DialogGetReservedInt2()
{
	local DialogBox	script;
	script = DialogBox(GetScript("DialogBox"));
	return script.GetReservedInt2();
}

function int DialogGetReservedInt3()
{
	local DialogBox	script;
	script = DialogBox(GetScript("DialogBox"));
	return script.GetReservedInt3();
}

function DialogSetEditBoxMaxLength(int maxLength)
{
	local DialogBox	script;
	script = DialogBox(GetScript("DialogBox"));
	script.SetEditBoxMaxLength(maxLength);
}

function int Split( string strInput, string delim, out array<string> arrToken )
{
	local int arrSize;
	
	while ( InStr(strInput, delim)>0 )
	{
		arrToken.Insert(arrToken.Length, 1);
		arrToken[arrToken.Length-1] = Left(strInput, InStr(strInput, delim));
		strInput = Mid(strInput, InStr(strInput, delim)+1);
		arrSize = arrSize + 1;
	}
	arrToken.Insert(arrToken.Length, 1);
	arrToken[arrToken.Length-1] = strInput;
	arrSize = arrSize + 1;
	
	return arrSize;
}

function ShowWindow( string a_ControlID )
{
	class'UIAPI_WINDOW'.static.ShowWindow( a_ControlID );
}

function ShowWindowWithFocus( string a_ControlID )
{
	class'UIAPI_WINDOW'.static.ShowWindow( a_ControlID );
	class'UIAPI_WINDOW'.static.SetFocus( a_ControlID );
}


function HideWindow( string a_ControlID )
{
	class'UIAPI_WINDOW'.static.HideWindow( a_ControlID );
}

function bool IsShowWindow( string a_ControlID )
{
	return class'UIAPI_WINDOW'.static.IsShowWindow( a_ControlID );
}

function ParamToItemInfo( string param, out ItemInfo info )
{
	local int tmpInt;
	ParseInt( param, "classID", info.ClassID );
	ParseInt( param, "level", info.Level);
	ParseString( param, "name", info.Name);
	ParseString( param, "additionalName", info.AdditionalName);
	ParseString( param, "iconName", info.IconName);
	ParseString( param, "description", info.Description);
	ParseInt( param, "itemType", info.ItemType);
	ParseInt( param, "serverID", info.ServerID );
	ParseInt( param, "itemNum", info.ItemNum);
	ParseInt( param, "slotBitType", info.SlotBitType);
	ParseInt( param, "enchanted", info.Enchanted);
	ParseInt( param, "blessed", info.Blessed);
	ParseInt( param, "damaged", info.Damaged);
	if( ParseInt( param, "equipped", tmpInt ) )
		info.bEquipped = bool(tmpInt);
	ParseInt( param, "price", info.Price );
	ParseInt( param, "reserved", info.Reserved );
	ParseInt( param, "defaultPrice", info.DefaultPrice );
	ParseInt( param, "refineryOp1", info.RefineryOp1 );
	ParseInt( param, "refineryOp2", info.RefineryOp2 );
	ParseInt( param, "currentDurability", info.CurrentDurability );

	ParseInt( param, "weight", info.Weight );
	ParseInt( param, "materialType", info.MaterialType);
	ParseInt( param, "weaponType", info.WeaponType);
	ParseInt( param, "physicalDamage", info.PhysicalDamage);
	ParseInt( param, "magicalDamage", info.MagicalDamage);
	ParseInt( param, "shieldDefense", info.ShieldDefense);
	ParseInt( param, "shieldDefenseRate", info.ShieldDefenseRate);
	ParseInt( param, "durability", info.Durability);
	ParseInt( param, "crystalType", info.CrystalType);
	ParseInt( param, "randomDamage", info.RandomDamage);
	ParseInt( param, "critical", info.Critical);
	ParseInt( param, "hitModify", info.HitModify);
	ParseInt( param, "attackSpeed", info.AttackSpeed);
	ParseInt( param, "mpConsume", info.MpConsume);
	ParseInt( param, "avoidModify", info.AvoidModify);
	ParseInt( param, "soulshotCount", info.SoulshotCount);
	ParseInt( param, "spiritshotCount", info.SpiritshotCount);
		
	ParseInt( param, "armorType", info.ArmorType);
	ParseInt( param, "physicalDefense", info.PhysicalDefense);
	ParseInt( param, "magicalDefense", info.MagicalDefense);
	ParseInt( param, "mpBonus", info.MpBonus);

	ParseInt( param, "consumeType", info.ConsumeType);
	ParseInt( param, "ItemSubType", info.ItemSubType );
	ParseString( param, "iconNameEx1", info.IconNameEx1 );
	ParseString( param, "iconNameEx2", info.IconNameEx2 );
	ParseString( param, "iconNameEx3", info.IconNameEx3 );
	ParseString( param, "iconNameEx4", info.IconNameEx4 );
	if( ParseInt( param, "arrow", tmpInt ) )
		info.bArrow = bool(tmpInt);
	if( ParseInt( param, "recipe", tmpInt ) )
		info.bRecipe = bool(tmpInt);
	//ParseInt( param, "etcItemType", info.EtcItemType);
}

function ParamToRecord( string param, out LVDataRecord record )
{
	local int idx;
	local int MaxColumn;
	
	ParseString( param, "szReserved", record.szReserved );
	ParseInt( param, "nReserved1", record.nReserved1 );
	ParseInt( param, "nReserved2", record.nReserved2 );
	ParseInt( param, "nReserved3", record.nReserved3 );

	ParseInt( param, "MaxColumn", MaxColumn );
	record.LVDataList.Length = MaxColumn;
	for (idx=0; idx<MaxColumn; idx++)
	{
		ParseString( param, "szData_" $ idx, record.LVDataList[idx].szData );
		ParseString( param, "szReserved_" $ idx, record.LVDataList[idx].szReserved );
		ParseInt( param, "nReserved1_" $ idx, record.LVDataList[idx].nReserved1 );
		ParseInt( param, "nReserved2_" $ idx, record.LVDataList[idx].nReserved2 );
		ParseInt( param, "nReserved3_" $ idx, record.LVDataList[idx].nReserved3 );
	}
}

function CustomTooltip MakeTooltipSimpleText(string Text)
{
	local CustomTooltip Tooltip;
	local DrawItemInfo info;
	
	Tooltip.DrawList.Length = 1;
	info.eType = DIT_TEXT;
	info.t_bDrawOneLine = true;
	info.t_strText = Text;
	Tooltip.DrawList[0] = info;

	return Tooltip;
}
