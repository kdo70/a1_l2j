class ClanDrawerWnd extends UIScript;

const c_maxranklimit = 100;
const changelineval1 = 23;
var	string	m_state;
var int		m_clanType;
var int		m_clanWarListPage;			// 선포
var int		m_currentEditGradeID;
var string	m_currentName;
var string 	m_myName;
var int	m_currentMaster;
//var bool	m_currentmemberselectoffset;
//var int	m_clanType;
var string 	currentMasterName;

//Handle
var WindowHandle Clan3_OrgIcon[CLAN_KNIGHTHOOD_COUNT];

function OnLoad()
{

	registerEvent( EV_ClanAuthGradeList );
	registerEvent( EV_ClanCrestChange );
	registerEvent( EV_ClanAuth );
	registerEvent( EV_ClanAuthMember );
	registerEvent( EV_ClanMemberInfo );
	registerEvent( EV_ClanWarList );
	registerEvent( EV_ClanSkillList );
	registerEvent( EV_ClanSkillListAdd );
	registerEvent( EV_GamingStateExit );
	registerEvent( EV_ClanClearWarList );
	
	InitHandle();
	InitializeGradeComboBox();
	HideAll();
	
	m_clanWarListPage = -1;
}

function InitHandle()
{
	local int i;
	for( i=0 ; i < CLAN_KNIGHTHOOD_COUNT ; ++i )
	{
		Clan3_OrgIcon[i] = GetHandle("ClanDrawerWnd.Clan3_OrgIcon" $ (i + 1));
	}
}

function OnShow()
{
	local ClanWnd script;
	script = ClanWnd( GetScript("ClanWnd") );

	// 권한에 따라 버튼 Enable/Diable
	class'UIAPI_WINDOW'.static.EnableWindow("ClanDrawerWnd.Clan1_ChangeMemberNameBtn");			// nickname
	class'UIAPI_WINDOW'.static.EnableWindow("ClanDrawerWnd.Clan1_ChangeMemberGradeBtn");
	class'UIAPI_WINDOW'.static.EnableWindow("ClanDrawerWnd.Clan1_AssignApprenticeBtn");
	class'UIAPI_WINDOW'.static.EnableWindow("ClanDrawerWnd.Clan1_DeleteApprenticeBtn");
	class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeBanishBtn");


	if( script.m_bClanMaster == 0 )
	{
		if(script.m_bNickName == 0)
		{
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeMemberNameBtn");	
		}				// nickname
		if(script.m_bGrade==0)
		{
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeMemberGradeBtn");
		}
		if(script.m_bManageMaster == 0)
		{
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_AssignApprenticeBtn");
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_DeleteApprenticeBtn");
		}
		if(script.m_bOustMember == 0)
		{
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeBanishBtn");
		}
	}
}

function Clear()
{
	m_state = "";
	m_clanType = -1;
	m_clanWarListPage = -1;
	m_currentEditGradeID = -1;
	m_currentName = "";
}

function SetStateAndShow( string state )
{
	local ClanWnd	script;
	local int i;
	local string string1;
	local string string2;
	local string string3;
	local string string4;
	//debug( "SetState " $ state );
	m_state = state;
	if( !class'UIAPI_WINDOW'.static.IsShowWindow("ClanDrawerWnd") )
	{
		class'UIAPI_WINDOW'.static.ShowWindow("ClanDrawerWnd");
	}
	HideAll();
	if( m_state == "ClanMemberInfoState" )
	{
		//RecallCurrentMemberInfo();
		class'UIAPI_WINDOW'.static.ShowWindow("ClanDrawerWnd.ClanMemberInfoWnd");
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_ChangeMemberNameWnd");
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_ChangeMemberGradeNameWnd");
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_AssignApprenticeWnd");
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_ChangeMemberKnightHoodWnd");
	}
	else if( m_state == "ClanMemberAuthState" )			// 혈원의 권한 보기. 보기만 되므로 모든 체크 박스는 Diable
	{
		class'UIAPI_WINDOW'.static.ShowWindow("ClanDrawerWnd.ClanMemberAuthWnd");
		for( i=0 ; i <= 9 ; ++i )
			class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan2_Check10" $ i, true );

		for( i=0; i <= 5 ; ++i )
			class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan2_Check20" $ i, true );

		for( i=0; i <= 8 ; ++i )
			class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan2_Check30" $ i, true );

		//class'UIAPI_WINDOW'.static.ShowWindow("ClanDrawerWnd.ClanMemberAuthWnd");

	}
	else if( m_state == "ClanInfoState" )		// 혈맹 정보
	{
		//InitializeClanInfoWnd();
		class'UIAPI_WINDOW'.static.ShowWindow("ClanDrawerWnd.ClanInfoWnd");
		InitializeClanInfoWnd();
	}
	else if( m_state == "ClanAuthManageWndState" )	// 권한 목록
	{
		class'UIAPI_WINDOW'.static.ShowWindow("ClanDrawerWnd.ClanAuthManageWnd");
	}
	else if( m_state == "ClanEmblemManageWndState" )	//문장 관리
	{
		class'UIAPI_WINDOW'.static.ShowWindow("ClanDrawerWnd.ClanEmblemManageWnd");
		
		string1 = Left(GetSystemMessage(211), changelineval1);
		string2 = Right(GetSystemMessage(211), Len(GetSystemMessage(211))-changelineval1);
		string3 = Left(GetSystemMessage(1478), changelineval1);
		string4 = Right(GetSystemMessage(1478), Len(GetSystemMessage(1478))-changelineval1);
		class'UIAPI_TEXTBOX'.static.SetText("ClanDrawerWnd.Clan7_ManageEmb1Text1", string1);
		class'UIAPI_TEXTBOX'.static.SetText("ClanDrawerWnd.Clan7_ManageEmb1Text2", string2);
		class'UIAPI_TEXTBOX'.static.SetText("ClanDrawerWnd.Clan7_ManageEmb2Text1", string3);
		class'UIAPI_TEXTBOX'.static.SetText("ClanDrawerWnd.Clan7_ManageEmb2Text2", string4);

		script = ClanWnd( GetScript("ClanWnd"));
		//class'UIAPI_TEXTURECTRL'.static.SetTextureWithClanCrest( "ClanDrawerWnd.ClanCrestTextureCtrl", script.m_clanID );
	}
	else if( m_state == "ClanWarManagementWndState" )	// 전쟁 정보
	{
		class'UIAPI_TABCTRL'.static.SetTopOrder("ClanDrawerWnd.ClanWarTabCtrl", 0, true);
		class'UIAPI_WINDOW'.static.ShowWindow("ClanDrawerWnd.ClanWarManagementWnd");
	}
	else if( m_state == "ClanAuthEditWndState" )	// 권한 편집
	{
		class'UIAPI_WINDOW'.static.ShowWindow("ClanDrawerWnd.ClanAuthEditWnd");
	}
	else if( m_state == "ClanHeroWndState" )		//영웅 전용 메뉴 보기
	{
		class'UIAPI_WINDOW'.static.ShowWindow("ClanDrawerWnd.ClanHeroWnd");
	}
}

function HideAll()
{
	class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.ClanMemberInfoWnd");
	class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.ClanMemberAuthWnd");
	class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.ClanInfoWnd");
	class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.ClanPenaltyWnd");
	class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.ClanWarManagementWnd");
	class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.ClanAuthManageWnd");
	class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.ClanAuthEditWnd");
	class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.ClanEmblemManageWnd");
	class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.ClanHeroWnd");
	
}

function OnClickButton( string strID )
{
	local LVDataRecord record;
	local int i;
	local ClanWnd script;
	script = ClanWnd( GetScript("ClanWnd") );

	//debug("ClanDrawerWnd::OnClickButton " $ strID );
	if( strID == "Clan1_AskJoinPartyBtn" )				// 혈원 정보. 파티 초대
	{
		RequestInviteParty( class'UIAPI_TEXTBOX'.static.GetText("ClanDrawerWnd.Clan1_CurrentSelectedMemberName" ) );
	}
	else if( strID == "Clan1_ChangeMemberNameBtn" )		// 혈원 정보. 호칭 변경
	{
		class'UIAPI_WINDOW'.static.ShowWindow("ClanDrawerWnd.Clan1_ChangeMemberNameWnd");
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_ChangeMemberGradeNameWnd");
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_AssignApprenticeWnd");
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_ChangeMemberKnightHoodWnd");
		class'UIAPI_EDITBOX'.static.SetString("ClanDrawerWnd.Clan1_ChangeNameTextEditbox","");
		
	}
	else if( strID == "Clan1_ChangeMemberGradeBtn" )	// 혈원 정보. 등급 변경
	{
		class'UIAPI_WINDOW'.static.ShowWindow("ClanDrawerWnd.Clan1_ChangeMemberGradeNameWnd");
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_ChangeMemberNameWnd");
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_ChangeMemberKnightHoodWnd");
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_AssignApprenticeWnd");
	}
	else if ( strID == "Clan1_ChangeBanishBtn")			// 혈원 정보. 혈원 제명
	{
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_ChangeMemberNameWnd");
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_ChangeMemberGradeNameWnd");
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_AssignApprenticeWnd");
		HideWindow();
		RequestClanExpelMember( m_clanType, class'UIAPI_TEXTBOX'.static.GetText("ClanDrawerWnd.Clan1_CurrentSelectedMemberName" ));
	}
	else if( strID == "Clan1_AssignApprenticeBtn" )		// 혈원 정보. 제자 할당.
	{
		class'UIAPI_WINDOW'.static.ShowWindow("ClanDrawerWnd.Clan1_AssignApprenticeWnd");
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_ChangeMemberNameWnd");
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_ChangeMemberKnightHoodWnd");
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_ChangeMemberGradeNameWnd");
		InitializeAcademyList();
	}
	// 신규추가 중간 업데이트 
	else if( strID == "Clan1_ChangeMemberKHOpen" )		// 혈원 소속 변경
	{
		class'UIAPI_WINDOW'.static.ShowWindow("ClanDrawerWnd.Clan1_ChangeMemberKnightHoodWnd");
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_AssignApprenticeWnd");
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_ChangeMemberNameWnd");
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_ChangeMemberGradeNameWnd");
		KnighthoodCombobox();
	}
	
	else if( strID == "Clan1_DeleteApprenticeBtn" )		// 혈원 정보. 제자 없애기
	{
		RequestClanDeletePupil( class'UIAPI_TEXTBOX'.static.GetText("ClanDrawerWnd.Clan1_CurrentSelectedMemberName" ), class'UIAPI_TEXTBOX'.static.GetText("ClanDrawerWnd.Clan1_CurrentSelectedApprentice" ));
		RecallCurrentMemberInfo();
		//ResetdeleteApprenticeonMainWnd(class'UIAPI_TEXTBOX'.static.GetText("ClanDrawerWnd.Clan1_CurrentSelectedMemberName" ), class'UIAPI_TEXTBOX'.static.GetText("ClanDrawerWnd.Clan1_CurrentSelectedApprentice" ));
	}
	else if( strID == "Clan1_OKBtn" )
	{
		HideWindow();
	}
	else if( strID == "Clan1_ChangeNameAssignBtn" )		// [호칭 변경] 버튼을 눌렀을 때 호칭 입력창과 함께 나오는 [적용] 버튼
	{
		//debug("Clan1_ChangeNameAssignBtn");
		RequestClanChangeNickName( class'UIAPI_TEXTBOX'.static.GetText("ClanDrawerWnd.Clan1_CurrentSelectedMemberName" ), 
		class'UIAPI_EDITBOX'.static.GetString("ClanDrawerWnd.Clan1_ChangeNameTextEditbox") ) ;
		class'UIAPI_EDITBOX'.static.SetString("ClanDrawerWnd.Clan1_ChangeNameTextEditbox","");
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_ChangeMemberNameWnd");	
		//유저 정보 리셋 함수 
		RecallCurrentMemberInfo();
	}
	else if( strID == "Clan1_ChangeNameDeleteBtn" )		// [호칭 삭제] 버튼을 눌렀을 때
	{
		//debug("Clan1_ChangeNameDeleteBtn");
		RequestClanChangeNickName( class'UIAPI_TEXTBOX'.static.GetText("ClanDrawerWnd.Clan1_CurrentSelectedMemberName" ), 
			"" );
		class'UIAPI_EDITBOX'.static.SetString("ClanDrawerWnd.Clan1_ChangeNameTextEditbox", "");
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_ChangeMemberNameWnd");	
		//유저 정보 리셋 함수 
		RecallCurrentMemberInfo();
	}
	
	else if( strId == "Clan1_ChangeMemberGradeAssignBtn" ) // [등급 변경] 버튼을 눌렀을 때 나오는 [적용] 버튼
	{
		debug("Clan1_ChangeMemberGradeAssignBtn");
		//if (class'UIAPI_COMBOBOX'.static.GetSelectedNum("ClanDrawerWnd.Clan1_MemberGradeList") <= 5) 
		if (class'UIAPI_COMBOBOX'.static.GetSelectedNum("ClanDrawerWnd.Clan1_MemberGradeList") < 5) 
		{
			debug("지정된 그레이드를 세팅함");
			RequestClanChangeGrade( class'UIAPI_TEXTBOX'.static.GetText("ClanDrawerWnd.Clan1_CurrentSelectedMemberName" ), 
			class'UIAPI_COMBOBOX'.static.GetSelectedNum("ClanDrawerWnd.Clan1_MemberGradeList") + 1);	// grade 는 1부터 9까지
		} 
		else 
		{
			debug("현재 등급을 찾아서 세팅하도록");
			debug("현재 설정된 클랜 고유번호:" @ m_clanType);
			RequestClanChangeGrade( class'UIAPI_TEXTBOX'.static.GetText("ClanDrawerWnd.Clan1_CurrentSelectedMemberName" ), 
			getCurrentGradebyClanType());		// 원래 소속등급을 찾아서 세팅 한다.
		}
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_ChangeMemberGradeNameWnd");	
		//유저 정보 리셋 함수 
		RecallCurrentMemberInfo();
	}
	else if( strID == "Clan1_ApprenticeAssignBtn" )		// [제자선임] 버튼 눌렀을 때 나오는 [적용] 버튼
	{
		//debug("Clan1_ApprenticeAssignBtn");
		i = class'UIAPI_LISTCTRL'.static.GetSelectedIndex("ClanDrawerWnd.Clan1_AssignApprenticeList");
		if( i >= 0 && m_currentName != "" )
		{
			record = class'UIAPI_LISTCTRL'.static.GetRecord("ClanDrawerWnd.Clan1_AssignApprenticeList", i);
			RequestClanAssignPupil( m_currentName, record.LVDataList[0].szData );
		}
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_AssignApprenticeWnd");	
		//유저 정보 리셋 함수 
		//RecallCurrentMemberInfo();
		//ResetAssignApprenticeonMainWnd(m_currentName, record.LVDataList[0].szData);
	}
	
	else if( strID == "Clan1_ChangeMemberKnightHoodBtn" )		//혈원소속변경 변경 버튼
	{
		proc_swapmember();
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_ChangeMemberKnightHoodWnd");	
	}
	
	
	else if( strID == "Clan1_Cancel1" )		//호칭변경창 [취소] 버튼
	{
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_ChangeMemberNameWnd");	
	}
	else if( strID == "Clan1_Cancel2" )		//혈원등급창 [취소] 버튼
	{
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_ChangeMemberGradeNameWnd");	
	}
	else if( strID == "Clan1_Cancel3" )		//후견인 [취소] 버튼
	{
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_AssignApprenticeWnd");	
	}
	else if( strID == "Clan1_Cancel4" )		//혈원소속변경 [취소] 버튼
	{
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_ChangeMemberKnightHoodWnd");	
	}
	
	else if( strID == "Clan7_RegEmbBtn" )		// 혈맹 문장 등록
	{
		RequestClanRegisterCrest();
	}
	else if( strID == "Clan7_RmEmbBtn" )		// 혈맹 문장 삭제
	{
		RequestClanUnregisterCrest();
	}
	else if( strID == "Clan7_RegEmb2Btn" )		// 휘장 등록
	{
		RequestClanRegisterEmblem();
	}
	else if( strID == "Clan7_RmEmb2Btn" )		// 휘장 삭제
	{
		RequestClanUnregisterEmblem();
	}
	else if( strID == "Clan8_CancelWar1Btn" )		// 선포중 창일때
	{
		HandleCancelWar1();
	}
	else if( strID == "Clan8_DeclareWar1Btn" )		// 여기서부터 피선포 창일때
	{
		HandleDeclareWar();
	}
	else if( strID == "Clan8_CancelWar2Btn" )
	{
		HandleCancelWar2();
	}
	else if( strID == "Clan8_ViewMoreBtn" )			// 피선포 창 END
	{
		RequestClanWarList( ++m_clanWarListPage, 1 );
	}
	else if( strID == "Clan2_OKBtn" )
	{
		HideWindow();
	}
	else if( strID == "Clan3_OKBtn" )
	{
		HideWindow();
	}
	else if( strID == "Clan4_OKBtn" )
	{
		HideWindow();
	}
	else if( strID == "Clan5_OKBtn" )		// 등급 리스트
	{
		HideWindow();
	}
	else if( strID == "Clan7_OKBtn" )
	{
		//debug("xxx");
		HideWindow();
	}
	else if( strID == "ClanWar_OKBtn" )
	{
		HideWindow();
	}
	else if( strID == "Clan5_ManageBtn")
	{
		EditAuthGrade();
	}
	else if( strID == "Clan5_ManageBtn2")
	{
		EditAuthGrade2();
	}
	else if( strID == "Clan6_ApplyBtn" )		// 권한 편집 적용
	{
		//debug("ApplyEditGrade");
		ApplyEditGrade();
		SetStateAndShow("ClanAuthManageWndState");
	}
	else if( strID == "Clan6_CancelBtn" )
	{
		SetStateAndShow("ClanAuthManageWndState");
	}
	else if( strID == "ClanWarTabCtrl0" )
	{
		RequestClanWarList( 0, 0 );
	}
	else if( strID == "ClanWarTabCtrl1" )
	{
		RequestClanWarList( m_clanWarListPage, 1 );
	}
	else if( strID == "Clan1_ChangeNameAssignNobBtn" )
	{
		//ExecuteCommandFromAction("selfnickname");
		//ExecuteCommand("/selfnickname " $ class'UIAPI_EDITBOX'.static.GetString("ClanDrawerWnd.Clan1_ChangeNobNameTextEditbox"));
		//debug("nicknamechanged?");
		//debug("Clan1_ChangeNameAssignBtn");
		//debug(script.m_myName);
		RequestClanChangeNickName( script.m_myName, 
		class'UIAPI_EDITBOX'.static.GetString("ClanDrawerWnd.Clan1_ChangeNobNameTextEditbox") ) ;
		class'UIAPI_EDITBOX'.static.SetString("ClanDrawerWnd.Clan1_ChangeNobNameTextEditbox","");
		
	}	
	else if( strID == "Clan1_NobCancel1" )
	{
		HideWindow();
	}	
	else if( strID == "Clan1_ChangeNameDeleteNobBtn" )
	{
		RequestClanChangeNickName( script.m_myName, "" );
	}	
}

//function ResetAssignApprenticeonMainWnd(string C_NAME, string C_APP)
//{
//	local MainWnd script;
//	script = MainWnd( GetScript("MainWnd") );
//	script.assignClanMasterAssign(C_NAME, script.m_memberList[ script.GetIndexFromType( m_clanType ) ]);
//	debug("changed:" $ C_NAME);
//	script.assignClanMasterAssign(C_APP, script.m_memberList[ script.GetIndexFromType( CLAN_ACADEMY ) ]);
//	debug("changed:" $ C_APP);
//	script.ClearList();
//	script.AddToList( script.m_memberList[ script.GetIndexFromType( m_clanType ) ] );
//	script.m_currentShowIndex = script.GetIndexFromType( m_clanType );
//}


//function ResetdeleteApprenticeonMainWnd(string C_NAME, string C_APP)
//{
//	local MainWnd script;
//	script = MainWnd( GetScript("MainWnd") );
//	script.deleteClanMasterAssign(C_NAME, script.m_memberList[ script.GetIndexFromType( m_clanType ) ]);
//	debug("changed:" $ C_NAME);
//	script.deleteClanMasterAssign(C_APP, script.m_memberList[ script.GetIndexFromType( CLAN_ACADEMY ) ]);
//	debug("changed:" $ C_APP);
//	script.ClearList();
//	script.AddToList( script.m_memberList[ script.GetIndexFromType( m_clanType ) ] );
//	script.m_currentShowIndex = script.GetIndexFromType( m_clanType );
//}


//레코드를 더블클릭하면....
function OnDBClickListCtrlRecord( string ListCtrlID)
{
	local int i;
	local LVDataRecord	record;	
	
	if (ListCtrlID == "Clan5_AuthListCtrl")
	{
		EditAuthGrade();
	}
	if (ListCtrlID == "Clan5_AuthListCtrl2")
	{
		EditAuthGrade2();
	}
	
	if (ListCtrlID == "Clan1_AssignApprenticeList")
	{
		//debug("Clan1_ApprenticeAssignBtn");
		i = class'UIAPI_LISTCTRL'.static.GetSelectedIndex("ClanDrawerWnd.Clan1_AssignApprenticeList");
		if( i >= 0 && m_currentName != "" )
		{
			record = class'UIAPI_LISTCTRL'.static.GetRecord("ClanDrawerWnd.Clan1_AssignApprenticeList", i);
			RequestClanAssignPupil( m_currentName, record.LVDataList[0].szData );
		}
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd.Clan1_AssignApprenticeWnd");	
		//유저 정보 리셋 함수 
		//RecallCurrentMemberInfo();
		//ResetAssignApprenticeonMainWnd(m_currentName, record.LVDataList[0].szData);
	}
	
}

// 현재 유저 정보창의 데이터를 리셋
function RecallCurrentMemberInfo()
{
	local ClanWnd script;
	script = ClanWnd( GetScript("ClanWnd") );
	RequestClanMemberInfo(script.G_CurrentRecord, script.G_CurrentSzData);
	SetStateAndShow("ClanMemberInfoState");
}

// selectall_checkbox_coded by Choonsik 
function OnClickCheckBox(string CheckBoxID)
{
	local string CheckboxNum;
	local string CheckboxName;
	local bool CheckedStat;
	local int i;
	
	CheckboxName = Left(CheckBoxID,12);

	if (CheckboxName == "Clan6_Check1")
	{
		CheckboxNum = Right(CheckBoxID,2);
		if (CheckboxNum == "00")
		{
			CheckedStat = class'UIAPI_CHECKBOX'.static.IsChecked("ClanDrawerWnd.Clan6_Check100");
			
			switch (CheckedStat)
			{
				case true:
				//!전체 체크박스를 체크하는 함수
				for( i=0 ; i <= 9 ; ++i )
					{
						class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan6_Check10" $ i, true );
					}
				break;
				case false:
				for( i=0 ; i <= 9 ; ++i )
					{
						class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan6_Check10" $ i, false );
					}
				break;
			}
		} 
		else
		{
			if (count_all_check("10",9) == true) 
			{
				class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan6_Check100", true);
			}
			else
			{
				class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan6_Check100", false);
			}
		}
	}
	if (CheckboxName == "Clan6_Check2")
	{
		CheckboxNum = Right(CheckBoxID,2);
		if (CheckboxNum == "00")
		{
			CheckedStat = class'UIAPI_CHECKBOX'.static.IsChecked("ClanDrawerWnd.Clan6_Check200");
			
			switch (CheckedStat)
			{
				case true:
				//!전체 체크박스를 체크하는 함수
				for( i=0 ; i <= 5 ; ++i )
					{
						class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan6_Check20" $ i, true );
					}
				break;
				case false:
				for( i=0 ; i <= 5 ; ++i )
					{
						class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan6_Check20" $ i, false );
					}
				break;
			}
		} 
		else
		{
			if (count_all_check("20",8) == true) 
			{
				class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan6_Check200", true);
			}
			else
			{
				class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan6_Check200", false);
			}
		}
	}
	if (CheckboxName == "Clan6_Check3")
	{
		CheckboxNum = Right(CheckBoxID,2);
		if (CheckboxNum == "00")
		{
			CheckedStat = class'UIAPI_CHECKBOX'.static.IsChecked("ClanDrawerWnd.Clan6_Check300");
			
			switch (CheckedStat)
			{
				case true:
				//!전체 체크박스를 체크하는 함수
				for( i=0 ; i <= 9 ; ++i )
					{
						class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan6_Check30" $ i, true );
					}
				break;
				case false:
				for( i=0 ; i <= 9 ; ++i )
					{
						class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan6_Check30" $ i, false );
					}
				break;
			}
		} 
		else
		{
			if (count_all_check("30",9) == true) 
			{
				class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan6_Check300", true);
			}
			else
			{
				class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan6_Check300", false);
			}
		}
	}
}

// check all the checkboxes are turned off coded by oxyzen
function bool count_all_check(string numString, int TotalNum)
{
	local bool checkall;
	local bool currentcheck;
	local int i;
	checkall = false;
	for (i=1; i<=TotalNum; ++i)
	{
		currentcheck = class'UIAPI_CHECKBOX'.static.IsChecked("ClanDrawerWnd.Clan6_Check" $ numString  $ i);
		if (currentcheck == true)
		{
			checkall = true;
		}
	}
		
	return checkall;
}

//check all the checkboxes are turned off coded by oxyzen
function bool count_all_check2(string numString, int TotalNum)
{
	local bool checkall;
	local bool currentcheck;
	local int i;
	checkall = false;
	for (i=1; i<=TotalNum; ++i)
	{
		currentcheck = class'UIAPI_CHECKBOX'.static.IsChecked("ClanDrawerWnd.Clan2_Check" $ numString  $ i);
		if (currentcheck == true)
		{
			checkall = true;
		}
	}
	return checkall;
}

function OnEvent( int a_EventID, String a_Param )
{
	debug ("Igotthisevent:" @ a_EventID);
	switch( a_EventID )
	{
	case EV_ClanAuthGradeList:
		HandleClanAuthGradeList( a_Param );
		break;
	case EV_ClanWarList:
		HandleClanWarList( a_Param );
		break;
	case EV_ClanCrestChange:
		HandleCrestChange( a_Param );
	case EV_ClanMemberInfo:
		HandleClanMemberInfo( a_Param );
		break;
	case EV_ClanSkillList:
		HandleSkillList( a_Param );
		break;
	case EV_ClanSkillListAdd:
		HandleSkillListAdd( a_Param );
		break;
	case EV_ClanAuth:	// 등급에 대한 권한 정보
		HandleClanAuth( a_Param );
		break;
	case EV_ClanAuthMember:	// 혈원애 대한 권한 정보
		HandleClanAuthMember( a_Param );
		break;
	case EV_GamingStateExit:
		class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd");
		break;
	case EV_ClanClearWarList:
		HandleClearWarList( a_Param );
		break;
	default:
		break;
	}
}

//	이벤트 핸들러
//	개별적인 이벤트를 처리하는 함수들은 Handle....() 형식의 이름을 가짐
function HandleClanAuthGradeList( String a_Param )
{
	local int count;
	local int id;
	local int members;
	local int i;
	local LVDataRecord	record;
	local LVData		data;
	
	record.LVDataList.Length = 2;
	class'UIAPI_LISTCTRL'.static.DeleteAllItem("ClanDrawerWnd.Clan5_AuthListCtrl");
	class'UIAPI_LISTCTRL'.static.DeleteAllItem("ClanDrawerWnd.Clan5_AuthListCtrl2");

	ParseInt( a_Param, "Count", count );
	for(i=0; i<5; ++i)
	{
		ParseInt( a_Param, "GradeID" $ i, id );
		ParseInt( a_Param, "GradeMemberCount" $ i, members );
		data.szData = GetStringByGradeID( id );
		record.LVDataList[0] = data;
		data.szData = string(members);
		record.LVDataList[1] = data;
		record.nReserved1 = id;
		class'UIAPI_LISTCTRL'.static.InsertRecord("ClanDrawerWnd.Clan5_AuthListCtrl", record );
	}
	for(i=5; i<9; ++i)
	{
		ParseInt( a_Param, "GradeID" $ i, id );
		ParseInt( a_Param, "GradeMemberCount" $ i, members );
		data.szData = GetStringByGradeID( id );
		record.LVDataList[0] = data;
		data.szData = string(members);
		record.LVDataList[1] = data;
		record.nReserved1 = id;
		class'UIAPI_LISTCTRL'.static.InsertRecord("ClanDrawerWnd.Clan5_AuthListCtrl2", record );
	}
	class'UIAPI_LISTCTRL'.static.SetSelectedIndex( "ClanDrawerWnd.Clan5_AuthListCtrl", 0 ,true);
	class'UIAPI_LISTCTRL'.static.SetSelectedIndex( "ClanDrawerWnd.Clan5_AuthListCtrl2", 0 ,true);
}


function HandleClanWarList( String a_Param )
{
	local string sClanName;
	local int type;			// 0 : 선포, 1: 피선포, 2:쌍방선포
	local int period;
	local LVDataRecord	record;
	local int page;

	ParseInt( a_Param, "Page", page );
	ParseString( a_Param, "ClanName", sClanName );
	ParseInt( a_Param, "Type", type );
	ParseInt( a_Param, "Period", period );
	
	//debug("HandleClanWarList page: " $ page $ " clanName: " $ sClanName $ " type: " $ type $ " period: " $ period );
	record.LVDataList.Length = 3;
	record.LVDataList[0].szData = sClanName;
	record.LVDataList[1].szData = GetWarStateString( type );
	record.LVDataList[2].szData = string(period);

	if( type == 0 || type == 2 )
	{
		class'UIAPI_TABCTRL'.static.SetTopOrder("ClanDrawerWnd.ClanWarTabCtrl", 0, true);
		class'UIAPI_LISTCTRL'.static.InsertRecord("ClanDrawerWnd.Clan8_DeclaredListCtrl", record);
	}
	else
	{
		class'UIAPI_TABCTRL'.static.SetTopOrder("ClanDrawerWnd.ClanWarTabCtrl", 1, true);
		m_clanWarListPage = page;
		class'UIAPI_LISTCTRL'.static.InsertRecord("ClanDrawerWnd.Clan8_GotDeclaredListCtrl", record);
	}
	

	
}


function HandleClanMemberInfo( String a_Param )
{
	local string nickName;
	local int gradeID;
	local string organization;
	local string masterName;		// empty if not exists
	local ClanWnd script;
	local string organizationtext;

	script = ClanWnd( GetScript("ClanWnd") );

	ParseInt( a_Param, "ClanType", m_clanType );
	ParseString( a_Param, "Name", m_currentName );
	ParseString( a_Param, "NickName", nickName );
	ParseInt( a_Param, "GradeID", gradeID );
	ParseString( a_Param, "OrderName", organization );
	ParseString( a_Param, "MasterName", MasterName );

	currentMasterName = masterName;
	//debug("d:"$currentMasterName);
	if (masterName == "")
	{
		masterName = GetSystemString(27);
	}
	//oxyzen
	organizationtext = getClanOrderString( m_clanType )@"-"@organization;
	
	class'UIAPI_TEXTBOX'.static.SetText("ClanDrawerWnd.Clan1_CurrentSelectedMemberName", m_currentName );
	class'UIAPI_TEXTBOX'.static.SetText("ClanDrawerWnd.Clan1_CurrentSelectedMemberSName", nickName);
	class'UIAPI_TEXTBOX'.static.SetText("ClanDrawerWnd.Clan1_CurrentSelectedMemberGrade", GetStringByGradeID(gradeID));
	class'UIAPI_TEXTBOX'.static.SetText("ClanDrawerWnd.Clan1_CurrentSelectedMemberOrderName", organizationtext);
	class'UIAPI_TEXTBOX'.static.SetText("ClanDrawerWnd.Clan1_CurrentSelectedApprentice", masterName);
		
	if (script.m_CurrentclanMasterReal == m_currentName)
	{
		if (script.m_currentShowIndex == 0)
		{
			class'UIAPI_TEXTBOX'.static.SetText("ClanDrawerWnd.Clan1_CurrentSelectedMemberGrade",GetSystemString(342));
		} 
	}
	

	
	// pledgeType에 따라 "후견인", "제자"로 텍스트를 바꿔 줘야함
	if ( m_clanType == CLAN_ACADEMY )
	{
		class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_AssignApprenticeBtn");
		class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_DeleteApprenticeBtn");
		class'UIAPI_TEXTBOX'.static.SetText("ClanDrawerWnd.Clan1_CurrentSelectedApprenticeTitle", GetSystemString( 1332 ) );
	}
	else
	{
		class'UIAPI_WINDOW'.static.EnableWindow("ClanDrawerWnd.Clan1_AssignApprenticeBtn");
		class'UIAPI_WINDOW'.static.EnableWindow("ClanDrawerWnd.Clan1_DeleteApprenticeBtn");
			
					if (currentMasterName != "")
			{
				//Debug("PressDel");
				class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_AssignApprenticeBtn");
				class'UIAPI_WINDOW'.static.EnableWindow("ClanDrawerWnd.Clan1_DeleteApprenticeBtn");
			}
			else
			{
				//Debug("PressName");
				class'UIAPI_WINDOW'.static.EnableWindow("ClanDrawerWnd.Clan1_AssignApprenticeBtn");
				class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_DeleteApprenticeBtn");
			}

		class'UIAPI_TEXTBOX'.static.SetText("ClanDrawerWnd.Clan1_CurrentSelectedApprenticeTitle", GetSystemString( 1431 ) );

	}
	
	
	script.resetBtnShowHide();
	CheckandCompareMyNameandDisableThings();
}

//권환 봐서 창 디스에이블 시키기 oxyzen
function CheckandCompareMyNameandDisableThings()
{
	local ClanWnd script;
	local UserInfo userinfo;
	//userinfo = GetUser();
	GetPlayerInfo( userinfo );
	m_myName = userinfo.Name;
	script = ClanWnd( GetScript("ClanWnd") );
	//debug("informme:" $ script.m_bOustMember);
	//혈맹주일경우 등급설정버튼 비활성화/혈원제명버튼 활성화
	if (script.m_bClanMaster > 0)
	{
		class'UIAPI_WINDOW'.static.EnableWindow("ClanDrawerWnd.Clan1_ChangeBanishBtn");
		class'UIAPI_WINDOW'.static.EnableWindow("ClanDrawerWnd.Clan1_ChangeMemberKHOpen");
			
		if (currentMasterName != "")
		{
			//Debug("PressDel");
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_AssignApprenticeBtn");
			class'UIAPI_WINDOW'.static.EnableWindow("ClanDrawerWnd.Clan1_DeleteApprenticeBtn");
			if (script.G_CurrentAlias == true)
			{
				class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_DeleteApprenticeBtn");
			}
		}
		else
		{
			//Debug("PressName");
			class'UIAPI_WINDOW'.static.EnableWindow("ClanDrawerWnd.Clan1_AssignApprenticeBtn");
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_DeleteApprenticeBtn");
		}
	} 
	// 여기서부터는 혈맹주가 아닐경우
	else 
	{
		// 우선 등급설정부터 하고...
		class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeMemberGradeBtn");
		class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeBanishBtn");
		class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeMemberKHOpen");
		Proc_AuthValidation();
		// 자기보다 기사단 번호가 상위(실제숫자는 거꾸로...) 
		if (script.GetClanTypeFromIndex( script.m_currentShowIndex) < script.m_myClanType)
		{
			//Debug("EditAuth"@ script.GetClanTypeFromIndex( script.m_currentShowIndex) @ script.m_myClanType);
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeBanishBtn");
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeMemberGradeBtn");
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_AssignApprenticeBtn");
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_DeleteApprenticeBtn");
			if (m_clanType == CLAN_ACADEMY)
			{
			}
			else
			{
				class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeMemberNameBtn");
			}
		} 
		if (script.m_myClanType > 1)
		{
			if (script.GetClanTypeFromIndex(script.m_currentShowIndex) != 0)
			{
				if (script.m_myClanType - script.GetClanTypeFromIndex( script.m_currentShowIndex) == 1)
				{
					Proc_AuthValidation();
				}                                       
				if (script.m_myClanType - script.GetClanTypeFromIndex( script.m_currentShowIndex) == 1000)
				{
					Proc_AuthValidation();
				}
				if (script.m_myClanType - script.GetClanTypeFromIndex( script.m_currentShowIndex) == 100)
				{
					Proc_AuthValidation();
				}
				if (script.m_myClanType - script.GetClanTypeFromIndex( script.m_currentShowIndex) == 999)
				{
					Proc_AuthValidation();
				} 
				if (script.m_myClanType - script.GetClanTypeFromIndex( script.m_currentShowIndex) == 1001)
				{
					Proc_AuthValidation();
				} 
			}
		}
		if (script.G_CurrentAlias == true)
		{
			//Debug("EditAuth"@ script.GetClanTypeFromIndex( script.m_currentShowIndex) @ script.m_myClanType);
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeBanishBtn");
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeMemberNameBtn");
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeMemberGradeBtn");
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_AssignApprenticeBtn");
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_DeleteApprenticeBtn");
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeMemberKHOpen");
		} 
		// 각 혈맹주의 권한은 편집 할 수 없음. - 다른 무엇보다 우선함.
		if (script.m_CurrentclanMasterReal == m_currentName)
		{
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeMemberGradeBtn");
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeBanishBtn");
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_AssignApprenticeBtn");
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_DeleteApprenticeBtn");
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeMemberNameBtn");
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeMemberKHOpen");
			
		}
	}
	// 자기 정보는 자기가 수정 할 수 없음.	
	if (m_currentName == m_myName)
	{
		class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeMemberGradeBtn");
		class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeBanishBtn");
		class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeMemberKHOpen");
	}
	//아카데미혈맹원에게는 그 누구도 권한을 지정할 수 없음. 
	if (m_clanType == CLAN_ACADEMY)
	{
		//debug("Academy");
		class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeMemberGradeBtn");
		class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_AssignApprenticeBtn");
		class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_DeleteApprenticeBtn");
	}
}
//실제 프로세스 부분
function Proc_AuthValidation()
{
	local ClanWnd script;
	script = ClanWnd( GetScript("ClanWnd") );
	
	if(script.m_bNickName == 0)
	{
		
		if (script.G_IamHero == true || script.G_IamNobless == true) 
		{
			class'UIAPI_WINDOW'.static.EnableWindow("ClanDrawerWnd.Clan1_ChangeMemberNameBtn");	
		}
		else 
		{
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeMemberNameBtn");	
		}
	}
	else
	{
		class'UIAPI_WINDOW'.static.EnableWindow("ClanDrawerWnd.Clan1_ChangeMemberNameBtn");	
	}
	if(script.m_bGrade==0)
	{
		class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeMemberGradeBtn");
	}
	else
	{
		class'UIAPI_WINDOW'.static.EnableWindow("ClanDrawerWnd.Clan1_ChangeMemberGradeBtn");

	}
	if(script.m_bManageMaster == 0)
	{
		class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_AssignApprenticeBtn");
		class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_DeleteApprenticeBtn");
	}
	else
	{
		if (currentMasterName != "")
		{
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_AssignApprenticeBtn");
			class'UIAPI_WINDOW'.static.EnableWindow("ClanDrawerWnd.Clan1_DeleteApprenticeBtn");
		}
		else
		{
			class'UIAPI_WINDOW'.static.EnableWindow("ClanDrawerWnd.Clan1_AssignApprenticeBtn");
			class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_DeleteApprenticeBtn");
		}

	}
	if(script.m_bOustMember == 0)
	{
		class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeBanishBtn");
	}
	else
	{
		class'UIAPI_WINDOW'.static.EnableWindow("ClanDrawerWnd.Clan1_ChangeBanishBtn");			
	}
}

function HandleCrestChange( String param )
{
	local ClanWnd script;
	if( m_state == "ClanEmblemManageWndState" )
	{
		script = ClanWnd( GetScript("ClanWnd"));
		class'UIAPI_TEXTURECTRL'.static.SetTextureWithClanCrest( "ClanDrawerWnd.ClanCrestTextureCtrl", script.m_clanID );
	}
}

function HandleSkillList( String a_Param )
{
	local int count;
	local int i;
	local int id;
	local int level;

	ParseInt( a_Param, "Count", count );
	class'UIAPI_ITEMWINDOW'.static.Clear( "ClanDrawerWnd.ClanSkillWnd" );
	for(i=0; i<count ; ++i)
	{
		ParseInt( a_Param, "SkillID" $ i, id );
		ParseInt( a_Param, "SkillLevel" $ i, level );
		AddSkill( id, level );
	}
}

function HandleSkillListAdd( String a_Param )
{
	local int id;
	local int level;
	local int i;
	local int count;
	local ItemInfo info;

	ParseInt( a_Param, "SkillID", id );
	ParseInt( a_Param, "SkillLevel", level );

	count = class'UIAPI_ITEMWINDOW'.static.GetItemNum("ClanDrawerWnd.ClanSkillWnd");
	for( i=0 ; i < count ; ++i )
	{
		class'UIAPI_ITEMWINDOW'.static.GetItem("ClanDrawerWnd.ClanSkillWnd", i, info);
		if( info.ClassID == id )			/// match found
			break;
	}
	
	if( i < count )	// match found
	{
		ReplaceSkill( i, id, level );
		//debug("ReplaceSkill id:" $ id $ ", level:" $ level $ ", index:" $ i);
	}
	else
	{
		//debug("AddSkill id:" $ id $ ", level:" $ level );
		AddSkill( id, level );
	}
}

function HandleCancelWar1()			// 선포 창일때
{
	local LVDataRecord record;
	local int index;
	index = class'UIAPI_LISTCTRL'.static.GetSelectedIndex("ClanDrawerWnd.Clan8_DeclaredListCtrl");

	if( index >= 0 )
	{
		record = class'UIAPI_LISTCTRL'.static.GetRecord("ClanDrawerWnd.Clan8_DeclaredListCtrl", index);
		RequestClanWithdrawWarWithClanName( record.LVDataList[0].szData );
		//debug("HandleCancelWar1 " $ record.LVDataList[0].szData );
		RequestClanWarList(0, 0);			// 0 page
		SetStateAndShow("ClanWarManagementWndState");
	}
}

function HandleDeclareWar()	
{
	local LVDataRecord record;
	local int index;
	index = class'UIAPI_LISTCTRL'.static.GetSelectedIndex("ClanDrawerWnd.Clan8_GotDeclaredListCtrl");

	if( index >= 0 )
	{
		record = class'UIAPI_LISTCTRL'.static.GetRecord("ClanDrawerWnd.Clan8_GotDeclaredListCtrl", index);
		RequestClanDeclareWarWidhClanName( record.LVDataList[0].szData );
		RequestClanWarList( m_clanWarListPage, 1 );
		
	}
}

function HandleCancelWar2()		// 피선포 창일 때
{
	local LVDataRecord record;
	local int index;
	index = class'UIAPI_LISTCTRL'.static.GetSelectedIndex("ClanDrawerWnd.Clan8_GotDeclaredListCtrl");

	if( index >= 0 )
	{
		record = class'UIAPI_LISTCTRL'.static.GetRecord("ClanDrawerWnd.Clan8_GotDeclaredListCtrl", index);
		RequestClanWithdrawWarWithClanName( record.LVDataList[0].szData );
		RequestClanWarList( m_clanWarListPage, 1 );
		class'UIAPI_TABCTRL'.static.SetTopOrder("ClanDrawerWnd.ClanWarTabCtrl", 1, true);
		class'UIAPI_WINDOW'.static.ShowWindow("ClanDrawerWnd.ClanWarManagementWnd");
		
	}
}

function HandleClanAuth( String a_Param )		// 권한 등급 처리
{
	local int gradeID;
	local int command;
	local array<int> powers;
	local int i;
	local int index;

	ParseInt( a_Param, "GradeID", gradeID );
	ParseInt( a_Param, "Command", command );

	powers.Length = 32;
	for( i = 0; i < 32 ; ++i )
	{
		ParseInt( a_Param, "PowerValue" $ i, powers[ i ] );
	}

	class'UIAPI_TEXTBOX'.static.SetText("ClanDrawerWnd.Clan6_CurrentSelectedRankName", GetStringByGradeID( gradeID ) $ GetSystemString(1376) );

	index = 1;
	for( i=1 ; i <= 9 ; ++i )
	{
		class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan6_Check10" $ i, bool( powers[index++] ) );
	}

	for( i=1; i <= 5 ; ++i )
	{
		class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan6_Check20" $ i, bool( powers[index++] ) );
	}

	for( i=1; i <= 8 ; ++i )
	{
		class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan6_Check30" $ i, bool( powers[index++] ) );
	}
	
	if (count_all_check("10", 9) == true)
	{
		class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan6_Check100", true);
	} else {
		class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan6_Check100", false);
	}
	if (count_all_check("20", 5) == true)
	{
		class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan6_Check200", true);
	} else {
		class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan6_Check200", false);
	}
	if (count_all_check("30", 8) == true)
	{
		class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan6_Check300", true);
	} else {
		class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan6_Check300", false);
	}

	if ( gradeID == CLAN_AUTH_GRADE9)
	{
		//debug("I have done1");
		disableAcademyAuth();
	} 
	else
	{
		resetAcademyAuth();
	}
	
}

function HandleClanAuthMember( String a_Param )	// 혈원 권한
{
	local ClanWnd script;
	
	local int gradeID;
	local string sName;
	local array<int> powers;
	local int i;
	local int index;
	script = ClanWnd( GetScript("ClanWnd") );

	ParseInt( a_Param, "Grade", gradeID );
	ParseString( a_Param, "Name", sName );

	powers.Length = 32;
	for( i = 0; i < 32 ; ++i )
	{
		ParseInt( a_Param, "PowerValue" $ i, powers[ i ] );
	}

	class'UIAPI_TEXTBOX'.static.SetText("ClanDrawerWnd.Clan2_CurrentSelectedMemberName", sName @ "-" @ GetStringByGradeID( gradeID ));
	
	index = 1;
	for( i=1 ; i <= 9 ; ++i )
	{
		class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan2_Check10" $ i, bool( powers[index++] ) );
	}

	for( i=1; i <= 5 ; ++i )
	{
		class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan2_Check20" $ i, bool( powers[index++] ) );
	}

	for( i=1; i <= 8 ; ++i )
	{
		class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan2_Check30" $ i, bool( powers[index++] ) );
	}
	
	if (count_all_check2("10", 9) == true)
	{
		class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan2_Check100", true);
	} else {
		class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan2_Check100", false);
	}
	if (count_all_check2("20", 5) == true)
	{
		class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan2_Check200", true);
	} else {
		class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan2_Check200", false);
	}
	if (count_all_check2("30", 8) == true)
	{
		class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan2_Check300", true);
	} else {
		class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan2_Check300", false);
	}

	//서버에서 온데이터가 자신의 정보일 경우 자신의 혈맹 본창을 리프레시
	if (script.m_myName == sName)
	{
		//가입권유
		if (class'UIAPI_CHECKBOX'.static.IsChecked("ClanDrawerWnd.Clan2_Check101") == true)
		{
			script.m_bJoin = 1;
		}
		else
		{
			script.m_bJoin = 0;
		}
		if (class'UIAPI_CHECKBOX'.static.IsChecked("ClanDrawerWnd.Clan2_Check107") == true)
		{
			script.m_bCrest = 1;
		}	
		else
		{
			script.m_bCrest = 0;
		}
		if (class'UIAPI_CHECKBOX'.static.IsChecked("ClanDrawerWnd.Clan2_Check105") == true)
		{
			script.m_bWar = 1;
		}	
		else
		{
			script.m_bWar = 0;
		}
	script.resetBtnShowHide();
	//script.m_bCrest = 1;
	//script.m_bWar = 1;
	//script.m_bGrade = 1;
	//script.m_bManageMaster = 1;
	//script.m_bOustMember =1;
	}
		// 혈맹주 예외 처리 혈맹주만 모두 트루를 집어 넣어 줌.
	if (script.m_CurrentclanMasterReal == sName)
	{
		//문춘식
		//debug("iamRunning:" @  script.m_CurrentclanMasterName @ sName);
		class'UIAPI_TEXTBOX'.static.SetText("ClanDrawerWnd.Clan2_CurrentSelectedMemberName", sName @ "-" @ GetSystemString(342));
		for( i=0 ; i <= 9 ; ++i )
		{
			class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan2_Check10" $ i, true );
		}
	
		for( i=0; i <= 5 ; ++i )
		{
			class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan2_Check20" $ i, true );
		}
	
		for( i=0; i <= 8 ; ++i )
		{
			class'UIAPI_CHECKBOX'.static.SetCheck("ClanDrawerWnd.Clan2_Check30" $ i, true );
		}
	}
	
}

function HandleClearWarList( String a_Param )
{
	local int condition;

	if( ParseInt( a_Param, "Condition", condition ) )
	{
		if( condition == 0 )
			class'UIAPI_LISTCTRL'.static.DeleteAllItem("ClanDrawerWnd.Clan8_DeclaredListCtrl");
		else
			class'UIAPI_LISTCTRL'.static.DeleteAllItem("ClanDrawerWnd.Clan8_GotDeclaredListCtrl");
	}
}

//
//	이벤트 핸들러 - END
//


// 등급을 넣으면 그에 맞는 시스템 스트링을 돌려준다
function string GetStringByGradeID( int gradeID )
{
	local int stringIndex;
	stringIndex = -1;
	
	debug("gradeID" @ gradeID);
	
	if( gradeID == CLAN_AUTH_GRADE1 )
		stringIndex = 1406;
	else if( gradeID == CLAN_AUTH_GRADE2 )
		stringIndex = 1407;
	else if( gradeID == CLAN_AUTH_GRADE3 )
		stringIndex = 1408;
	else if( gradeID == CLAN_AUTH_GRADE4 )
		stringIndex = 1409;
	else if( gradeID == CLAN_AUTH_GRADE5 )
		stringIndex = 1410;
	else if( gradeID == CLAN_AUTH_GRADE6 )
		stringIndex = 1411;
	else if( gradeID == CLAN_AUTH_GRADE7 )
		stringIndex = 1412;
	else if( gradeID == CLAN_AUTH_GRADE8 )
		stringIndex = 1413;
	else if( gradeID == CLAN_AUTH_GRADE9 )
		stringIndex = 1414;

	if( stringIndex != -1 )
		return GetSystemString( stringIndex );
	else 
		return "";

}

// 제자 선임을 위해서 아카데미 혈맹원만을 가져와 리스트 컨트롤에 추가한다
function InitializeAcademyList()
{
	local ClanWnd script;
	local int i;
	local LVDataRecord record;
	record.LVDataList.Length = 3;
	script = ClanWnd( GetScript("ClanWnd") );
	InitializeClan1_AssignApprenticeList();
	for( i=0 ; i < script.m_memberList[ script.GetIndexFromType( CLAN_ACADEMY ) ].m_array.Length ; ++i )
	{
		//후견인이 있는 아카데미원은 삽입하지 않는다.
		if (  script.m_memberList[ script.GetIndexFromType( CLAN_ACADEMY ) ].m_array[i].bHaveMaster == 0 )	
		{
			record.LVDataList[0].szData = script.m_memberList[ script.GetIndexFromType( CLAN_ACADEMY ) ].m_array[i].sName;
			record.LVDataList[1].szData = string(script.m_memberList[ script.GetIndexFromType( CLAN_ACADEMY ) ].m_array[i].level);
			record.nReserved1 = script.m_memberList[ script.GetIndexFromType( CLAN_ACADEMY ) ].m_array[i].clanType;		// for additional information
			record.LVDataList[2].szData = string( script.m_memberList[ script.GetIndexFromType( CLAN_ACADEMY ) ].m_array[i].classID );
			record.LVDataList[2].szTexture = GetClassIconName(script.m_memberList[ script.GetIndexFromType( CLAN_ACADEMY ) ].m_array[i].classID);
			record.LVDataList[2].nTextureWidth = 11;
			record.LVDataList[2].nTextureHeight = 11;
			class'UIAPI_LISTCTRL'.static.InsertRecord( "ClanDrawerWnd.Clan1_AssignApprenticeList", record );
		}
	}
}

function InitializeClan1_AssignApprenticeList()
{
	class'UIAPI_LISTCTRL'.static.DeleteAllItem( "ClanDrawerWnd.Clan1_AssignApprenticeList" );
}

// 혈맹 정보창 초기화
function InitializeClanInfoWnd()
{
	local Color Blue;
	local Color Red;
	local Color DarkYellow;
	local ClanWnd script;
	local int i;
	local string ClanNameVal;
	local string ClanRankStr;
	local string tooltip;
	local int	clanType;
	
	Blue.R = 126;
	Blue.G = 158;
	Blue.B = 245;
	Red.R = 200;
	Red.G = 50;
	Red.B = 80;
	DarkYellow.R =175;
	DarkYellow.G =152;
	DarkYellow.B =120;
	
	script = ClanWnd( GetScript("ClanWnd") );
	ClanNameVal = script.m_clanNameValue @ GetSystemString(1442);
	
	// reset all 
	reset_clan_org();
	
	if (script.m_clanRank == 0)
	{
		ClanRankStr = GetSystemString(1374);
	}
	else if (script.m_clanRank <= c_maxranklimit)
	{
		ClanRankStr = GetSystemString(1375)@ script.m_clanRank;
	}
	else 
	{
		ClanRankStr = GetSystemString(1374);
	}
	class'UIAPI_TEXTBOX'.static.SetText("ClanDrawerWnd.Clan3_ClanName", script.m_clanName );
	class'UIAPI_TEXTBOX'.static.SetText("ClanDrawerWnd.Clan3_ClanPoint", ClanNameVal );
	
	if (script.m_clanNameValue == 0)
	{
		class'UIAPI_TEXTBOX'.static.SetTextColor("ClanDrawerWnd.Clan3_ClanPoint", DarkYellow );
	}
	else if (script.m_clanNameValue < 0)
	{
		class'UIAPI_TEXTBOX'.static.SetTextColor("ClanDrawerWnd.Clan3_ClanPoint", Red );
	}
	else if (script.m_clanNameValue > 0)
	{
		class'UIAPI_TEXTBOX'.static.SetTextColor("ClanDrawerWnd.Clan3_ClanPoint", Blue );
	}
	
	class'UIAPI_TEXTBOX'.static.SetText("ClanDrawerWnd.Clan3_ClanRanking", ClanRankStr );

	for( i=0 ; i < CLAN_KNIGHTHOOD_COUNT ; ++i )
	{
		if( script.m_memberList[i].m_sName != "" )
		{
			clanType = script.GetClanTypeFromIndex(i);
			if( clanType == CLAN_MAIN )
			{
				tooltip = script.m_memberList[i].m_sName $ "\\n" $ GetSystemString(342) $ " : " $ script.m_memberList[i].m_sMasterName;
			}
			if( clanType == CLAN_ACADEMY )
			{
				tooltip = script.m_memberList[i].m_sName;
			}
			if( clanType == CLAN_KNIGHT1 || clanType == CLAN_KNIGHT2 )		// 근위대
			{
				tooltip = script.m_memberList[i].m_sName $ "\\n" $ GetSystemString(1438) $ " : " $ script.m_memberList[i].m_sMasterName;
			}
			if( clanType == CLAN_KNIGHT3 || clanType == CLAN_KNIGHT4 || clanType == CLAN_KNIGHT5 || clanType == CLAN_KNIGHT6 )
			{
				tooltip = script.m_memberList[i].m_sName $ "\\n" $ GetSystemString(1433) $ " : " $ script.m_memberList[i].m_sMasterName;
			}
			if (tooltip != "")
			{
				Clan3_OrgIcon[i].ShowWindow();
				Clan3_OrgIcon[i].EnableWindow();
				Clan3_OrgIcon[i].SetTooltipCustomType(SetTooltip(tooltip));
			}
		}
	}
}


function InitializeGradeComboBox()
{
	local int i;
	class'UIAPI_COMBOBOX'.static.Clear("ClanDrawerWnd.Clan1_MemberGradeList");
	
	for( i = CLAN_AUTH_GRADE1 ; i < CLAN_AUTH_GRADE6; ++i )
	{
		class'UIAPI_COMBOBOX'.static.AddString("ClanDrawerWnd.Clan1_MemberGradeList", GetStringByGradeID( i ) );
	}
	
	class'UIAPI_COMBOBOX'.static.AddString("ClanDrawerWnd.Clan1_MemberGradeList", GetSystemString(1451) );
}

function KnighthoodCombobox()
{
	local ClanWnd script;
	local int i;
	script = ClanWnd( GetScript("ClanWnd") );

	class'UIAPI_COMBOBOX'.static.Clear("ClanDrawerWnd.Clan1_targetknighthoodcombobox");
	class'UIAPI_COMBOBOX'.static.Clear("ClanDrawerWnd.Clan1_targetknighthoodmember");
		
	class'UIAPI_COMBOBOX'.static.AddStringWithReserved("ClanDrawerWnd.Clan1_targetknighthoodcombobox", GetSystemString(1465), 0);
	class'UIAPI_COMBOBOX'.static.AddStringWithReserved("ClanDrawerWnd.Clan1_targetknighthoodmember", GetSystemString(1466), 0);

	class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_targetknighthoodmember");
	class'UIAPI_WINDOW'.static.DisableWindow("ClanDrawerWnd.Clan1_ChangeMemberKnightHoodBtn");

	class'UIAPI_TEXTBOX'.static.SetText( "ClanDrawerWnd.Clan1_ChangeMemberKnightHoodTXT1", MakeFullSystemMsg(GetSystemMessage(1906), m_currentName, ""));
	
	for( i=0 ; i < script.CLAN_KNIGHTHOOD_COUNT ; ++i )
	{
		if( script.m_memberList[i].m_sName != "" )
		{
			if (script.GetClanTypeFromIndex(i) != CLAN_ACADEMY)
			{
				class'UIAPI_COMBOBOX'.static.AddStringWithReserved("ClanDrawerWnd.Clan1_targetknighthoodcombobox", script.m_memberList[i].m_sName, i);
			}
		}
	}
	
	class'UIAPI_COMBOBOX'.static.SetSelectedNum("ClanDrawerWnd.Clan1_targetknighthoodcombobox",0);
	
}


function swapTargetSelect(int clanNo)
{
	local ClanWnd script;
	local int i;
	script = ClanWnd( GetScript("ClanWnd") );

	class'UIAPI_COMBOBOX'.static.Clear("ClanDrawerWnd.Clan1_targetknighthoodmember");
	class'UIAPI_COMBOBOX'.static.AddStringWithReserved("ClanDrawerWnd.Clan1_targetknighthoodmember", GetSystemString(1466), 0);
	class'UIAPI_TEXTBOX'.static.SetText( "ClanDrawerWnd.Clan1_ChangeMemberKnightHoodTXT1", MakeFullSystemMsg(GetSystemMessage(1907), m_currentName, ""));
	
	for( i=0 ; i <= script.m_memberList[ clanNo ].m_array.Length ; ++i )
	{
		if ( script.m_memberList[ clanNo ].m_array[i].sName != script.m_CurrentclanMasterReal)
		class'UIAPI_COMBOBOX'.static.AddStringWithReserved("ClanDrawerWnd.Clan1_targetknighthoodmember", script.m_memberList[ clanNo ].m_array[i].sName, script.m_memberList[ clanNo ].m_array[i].clanType);
	}
	class'UIAPI_COMBOBOX'.static.SetSelectedNum("ClanDrawerWnd.Clan1_targetknighthoodmember",0);
	
}

function proc_swapmember()
{
	
	local int currentindexnew1;
	local int currentindexnew2;
	local string currentstring1; 
	local string currentstring2; 
	local int type;
	local int clantype1;
	//local int clantype2;
	local ClanWnd script;
	script = ClanWnd( GetScript("ClanWnd") );
	
	currentindexnew1 = class'UIAPI_COMBOBOX'.static.GetSelectedNum("ClanDrawerWnd.Clan1_targetknighthoodcombobox");
	currentstring1 = class'UIAPI_COMBOBOX'.static.GetString("ClanDrawerWnd.Clan1_targetknighthoodcombobox", currentindexnew1);
	clantype1 = script.GetClanTypeFromIndex(class'UIAPI_COMBOBOX'.static.GetReserved("ClanDrawerWnd.Clan1_targetknighthoodcombobox", currentindexnew1));
	
	currentindexnew2 = class'UIAPI_COMBOBOX'.static.GetSelectedNum("ClanDrawerWnd.Clan1_targetknighthoodmember");
	currentstring2 = class'UIAPI_COMBOBOX'.static.GetString("ClanDrawerWnd.Clan1_targetknighthoodmember", currentindexnew2);

		
	//debug(currentstring1 @ currentstring2);
	
	if (currentindexnew2 == 0)
	{
		type = 0;
	}
	else 
	{
		type = 1;
	}
	
	if (type == 1)
	{
		//debug("멤버교체");
		RequestClanReorganizeMember( 1, m_currentName, clantype1, currentstring2);
	}
	else if (type == 0)
	{
		//debug("멤버이동이얌");
		RequestClanReorganizeMember( 0, m_currentName, clantype1, "");
	}
	
	class'UIAPI_TEXTBOX'.static.SetText("ClanDrawerWnd.Clan1_CurrentSelectedMemberOrderName", getClanOrderString( clantype1 ) @ "-" @ currentstring1);
}


function OnComboBoxItemSelected(string strID, int index)
{
	local int selectval;
	if (strID == "Clan1_targetknighthoodcombobox")
	{
		class'UIAPI_WINDOW'.static.EnableWindow("ClanDrawerWnd.Clan1_targetknighthoodmember");
		class'UIAPI_WINDOW'.static.EnableWindow("ClanDrawerWnd.Clan1_ChangeMemberKnightHoodBtn");
		selectval = class'UIAPI_COMBOBOX'.static.GetReserved("ClanDrawerWnd.Clan1_targetknighthoodcombobox", index);
		swapTargetSelect(selectval);
	}
}

function HideWindow()
{
	local ClanWnd script;
	script = ClanWnd( GetScript("ClanWnd") );
	
	//debug ("HideWindow is in Run");
	class'UIAPI_WINDOW'.static.HideWindow("ClanDrawerWnd");
	script.ResetOpeningVariables();
}

function ApplyEditGrade()
{
	local array<int> powers;
	local int i;
	local int index;
	powers.Length = 32;
	powers[0]=0;			// first power bit is dummy
	index = 1;
	for( i=1 ; i <= 9 ; ++i )
	{
		if( class'UIAPI_CHECKBOX'.static.IsChecked("ClanDrawerWnd.Clan6_Check10" $ i ) )
			powers[index] = 1;
		++index;
	}

	for( i=1; i <= 5 ; ++i )
	{
		if( class'UIAPI_CHECKBOX'.static.IsChecked("ClanDrawerWnd.Clan6_Check20" $ i ) )
			powers[index] = 1;
		++index;
	}

	for( i=1; i <= 8 ; ++i )
	{
		if( class'UIAPI_CHECKBOX'.static.IsChecked("ClanDrawerWnd.Clan6_Check30" $ i ) )
			powers[index] = 1;
		++index;
	}

		
	RequestEditClanAuth( m_currentEditGradeID, powers );
}

function EditAuthGrade()
{
	local int index;
	local LVDataRecord record;
	index = class'UIAPI_LISTCTRL'.static.GetSelectedIndex("ClanDrawerWnd.Clan5_AuthListCtrl");
	if( index >= 0 )
	{
		record = class'UIAPI_LISTCTRL'.static.GetRecord("ClanDrawerWnd.Clan5_AuthListCtrl", index);
		RequestClanAuth( record.nReserved1 );
		//debug("RequestClanAuth " $ ( record.nReserved1 ) );
		m_currentEditGradeID = record.nReserved1;
		SetStateAndShow("ClanAuthEditWndState");
	
	}
	else
	{
		SetStateAndShow("ClanAuthManageWndState");
	}
}

function EditAuthGrade2()
{
	local int index;
	local LVDataRecord record;
	index = class'UIAPI_LISTCTRL'.static.GetSelectedIndex("ClanDrawerWnd.Clan5_AuthListCtrl2");
	if( index >= 0 )
	{
		record = class'UIAPI_LISTCTRL'.static.GetRecord("ClanDrawerWnd.Clan5_AuthListCtrl2", index);
		RequestClanAuth( record.nReserved1 );
		//debug("RequestClanAuth " $ ( record.nReserved1 ) );
		m_currentEditGradeID = record.nReserved1;
		SetStateAndShow("ClanAuthEditWndState");
	
	}
	else
	{
		SetStateAndShow("ClanAuthManageWndState");
	}
}

function string GetWarStateString( int state )
{
	if( state == 0 )
		return GetSystemString( 1429 );	// 선포중
	else if( state == 1 ) 
		return GetSystemString( 1430 ); // 피선포중
	else if( state == 2 )
		return GetSystemString( 1367 ); //쌍방선포

	return "Error";
}

function AddSkill( int id, int level )
{
	local ItemInfo info;

	info.ClassID = id;
	info.Level = level;
	info.Name = class'UIDATA_SKILL'.static.GetName( info.ClassID, info.Level );
	info.IconName = class'UIDATA_SKILL'.static.GetIconName( info.ClassID, info.Level );
	info.Description = class'UIDATA_SKILL'.static.GetDescription( info.ClassID, info.Level );
	info.AdditionalName = class'UIDATA_SKILL'.static.GetEnchantName( info.ClassID, info.Level );

	//debug("AddSkill ID: " $ info.ClassID $ " level: " $ info.Level $ " name: " $ info.Name $ " iconName: " $ info.IconName );
	class'UIAPI_ITEMWINDOW'.static.AddItem( "ClanDrawerWnd.ClanSkillWnd", info );
}

function ReplaceSkill( int index, int id, int level )
{
	local ItemInfo info;

	info.ClassID = id;
	info.Level = level;
	info.Name = class'UIDATA_SKILL'.static.GetName( info.ClassID, info.Level );
	info.IconName = class'UIDATA_SKILL'.static.GetIconName( info.ClassID, info.Level );
	info.Description = class'UIDATA_SKILL'.static.GetDescription( info.ClassID, info.Level );
	info.AdditionalName = class'UIDATA_SKILL'.static.GetEnchantName( info.ClassID, info.Level );

	//debug("ReplaceSkill ID: " $ info.ClassID $ " level: " $ info.Level $ " name: " $ info.Name $ " iconName: " $ info.IconName );
	class'UIAPI_ITEMWINDOW'.static.SetItem( "ClanDrawerWnd.ClanSkillWnd", index, info );
}

// oxyzen added 혈맹기사단 이름 가져오기
function string getClanOrderString(int gradeID)
{
	local int stringIndex;
	stringIndex = -1;
	if( gradeID == CLAN_MAIN )
		stringIndex = 1399;
	else if( gradeID == CLAN_KNIGHT1 )
		stringIndex = 1400;
	else if( gradeID == CLAN_KNIGHT2 )
		stringIndex = 1401;
	else if( gradeID == CLAN_KNIGHT3 )
		stringIndex = 1402;
	else if( gradeID == CLAN_KNIGHT4 )
		stringIndex = 1403;
	else if( gradeID == CLAN_KNIGHT5 )
		stringIndex = 1404;
	else if( gradeID == CLAN_KNIGHT6 )
		stringIndex = 1405;
	else if( gradeID == CLAN_ACADEMY )
		stringIndex = 1419;

	if( stringIndex != -1 )
		return GetSystemString( stringIndex );
	else 
		return "";

}


// function reset 혈맹 정보 by oxyzen
function reset_clan_org()
{
	local int i;
	for ( i=0; i < CLAN_KNIGHTHOOD_COUNT; ++i)
	{
		Clan3_OrgIcon[i].HideWindow();
		Clan3_OrgIcon[i].DisableWindow();
		Clan3_OrgIcon[i].SetTooltipCustomType(SetTooltip(""));
	}
}


// 아카데미혈맹원등급의 권한 편집시 디스에이블
function disableAcademyAuth()
{
	//debug("I have done2");
	//혈맹권한: 혈맹가입, 호칭관리, 문장관리, 혈맹전쟁, 혈원제명, 성장괸리, 등급관리, 마스터관리
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check100", true );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check101", true );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check102", true );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check106", true );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check104", true );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check105", true );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check107", true );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check108", true );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check109", true );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check110", true );

	//아지트권한: 추방권한, 기능설정, 입찰매각
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check200", true );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check203", true );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check204", true );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check205", true );

	//성권한: 추방권한, 장원관리, 세금관리, 공수성등록, 용병관리, 기능설정
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check300", true );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check303", true );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check302", true );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check305", true );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check306", true );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check307", true );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check308", true );
}

// 아캄데미 혈맹원의 등급이 아닐 경우 다시 이네이블 혹은 리셋;
function resetAcademyAuth()
{
	//혈맹권한: 혈맹가입, 호칭관리, 문장관리, 혈맹전쟁, 혈원제명, 성장괸리, 등급관리, 마스터관리
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check100", false );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check101", false );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check102", false );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check106", false );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check104", false );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check105", false );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check107", false );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check108", false );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check109", false );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check109", false );
	//아지트권한: 추방권한, 기능설정, 입찰매각
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check200", false );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check203", false );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check204", false );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check205", false );

	//성권한: 추방권한, 장원관리, 세금관리, 공수성등록, 용병관리, 기능설?
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check300", false );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check303", false );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check302", false );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check305", false );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check306", false );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check307", false );
	class'UIAPI_CHECKBOX'.static.SetDisable("ClanDrawerWnd.Clan6_Check308", false );
}

function int getCurrentGradebyClanType()
{
	local int GradeNum;
	debug("현재 그레이드를 클랜에서 가져옴:"@ m_clanType);
	switch(m_clanType)
	{
		case CLAN_MAIN:
		GradeNum = 6;
		break;
		case CLAN_KNIGHT1:
		GradeNum = 7;
		break;
		case CLAN_KNIGHT2:
		GradeNum = 7;
		break;
		case CLAN_KNIGHT3:
		GradeNum = 8;
		break;
		case CLAN_KNIGHT4:
		GradeNum = 8;
		break;
		case CLAN_KNIGHT5:
		GradeNum = 8;
		break;
		case CLAN_KNIGHT6:
		GradeNum = 8;
		break;
		case CLAN_ACADEMY:
		GradeNum = 9;
		break;
	}
	debug ("현재 그레이드 번호는?" @ GradeNum);
	return GradeNum;
}

function CustomTooltip SetTooltip(string Text)
{
	local CustomTooltip Tooltip;
	local DrawItemInfo info;
	
	Tooltip.MinimumWidth = 144;
	Tooltip.DrawList.Length = 1;
	
	info.eType = DIT_TEXT;
	info.t_color.R = 178;
	info.t_color.G = 190;
	info.t_color.B = 207;
	info.t_color.A = 255;
	info.t_strText = Text;
	Tooltip.DrawList[0] = info;

	return Tooltip;
}
