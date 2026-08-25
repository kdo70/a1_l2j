/******************************************************************************
//                                                파티창  옵션 관련 UI 스크립트                                                                    //
******************************************************************************/
class PartyWndOption extends UIScript;

// 전역변수 선언
var bool	m_OptionShow;	// 현재 옵션창이 보여지고 있는지 체크하는 함수.
					// true이면 보임. false  이면 보이지 않음.

// 이벤트 핸들 선언
var WindowHandle	m_PartyOption;
var WindowHandle 	m_PartyWndBig;
var WindowHandle	m_PartyWndSmall;

// 윈도우 생성시 로드되는 함수
function OnLoad()
{
	m_OptionShow = false;	// 디폴트는 false 
	m_PartyOption = GetHandle("PartyWndOption");
	m_PartyWndBig = GetHandle("PartyWnd");;
	m_PartyWndSmall = GetHandle("PartyWndCompact");;
}
       
// 윈도우가 보여질때마다 호출되는 함수
function OnShow()
{	
	class'UIAPI_CHECKBOX'.static.SetCheck("ShowSmallPartyWndCheck", GetOptionBool( "Game", "SmallPartyWnd" ));
	class'UIAPI_WINDOW'.static.SetFocus("PartyWndOption");
	m_OptionShow = true;
}

// 체크박스를 클릭하였을 경우 이벤트
function OnClickCheckBox( string CheckBoxID)
{
	switch( CheckBoxID )
	{
	case "ShowSmallPartyWndCheck":
		//debug("Clicked  2");

		break;
	}
}

// 확장된 파티창과 축소된 파티창을 교환
function SwapBigandSmall()
{
	local  PartyWnd script1;			// 확장된 파티창의 클래스
	local PartyWndCompact script2;	// 축소된 파티창의 클래스
	
	script1 = PartyWnd( GetScript("PartyWnd") );
	script2 = PartyWndCompact( GetScript("PartyWndCompact") );
	
	class'UIAPI_WINDOW'.static.SetAnchor("PartyWndCompact", "PartyWnd", "TopLeft", "TopLeft", 0, 0 );	// 이거하나면 양쪽 창이 링크됨. 굿!
	
	// 각 스크립트의 ResizeWnd()는 옵션의 활성화에 따라 자신의 윈도우를 HIDE할지 활성화할지 결정한다. 
	script1.ResizeWnd();
	script2.ResizeWnd();
}

// 버튼이 눌렸을 경우 실행
function OnClickButton( string strID )
{
	//local PartyWnd script1;
	//local PartyWndCompact script2;
	//script1 = PartyWnd( GetScript("PartyWnd") );
	//script2 = PartyWndCompact( GetScript("PartyWndCompact") );
	
	switch( strID )
	{
	case "okbtn":	// OK 버튼을 누르면
		
		switch (class'UIAPI_CHECKBOX'.static.IsChecked("ShowSmallPartyWndCheck"))
		{ 
		case true:
			//SetOptionBool("Game", ... ) 은 게임의 Option ->게임항목에서 사용할수 있는 bool 변수를 사용할 수 있다.	
			//기존에 등록되지 않은 변수를 사용하면 자동으로 클라이언트에서 알아서 저장함.
			// 추후 사용된 변수에 대한 Documentation 이 필요!
			// GetOptionBool과 페어.
			SetOptionBool( "Game", "SmallPartyWnd", true );											
			break;
		case false:
			SetOptionBool( "Game", "SmallPartyWnd", false);
			break;
		}
		SwapBigandSmall();		// 상황에 따라 파티창의 크기를 스왑해준다.
		m_PartyOption.HideWindow();	// 현재의 윈도우를 숨기고
		//script1.m_OptionShow = false;
		//script2.m_OptionShow = false;
		m_OptionShow = false;
		break;
	}
}

// PartyWnd나 PartyWndCompact 에서 호출하는 함수.
function ShowPartyWndOption()
{
	// 닫혀있으면 열고
	if (m_OptionShow == false)
	{ 
		m_PartyOption.ShowWindow();
		m_OptionShow = true;
	}
	else	// 열려있으면 닫는다. 
	{
		m_PartyOption.HideWindow();
		m_OptionShow = false;
	}
}
