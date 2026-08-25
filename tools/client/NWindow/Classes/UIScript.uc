class UIScript extends UIEventManager
	dynamicrecompile
	native;

var WindowHandle m_hOwnerWnd;
	
// Test
native function RequestTest( String param );

// Console State
native function bool IsPKMode();

// Client To Server API
native function RequestExit();
native function RequestAuthCardKeyLogin( int uid, string value);
native function RequestSelfTarget();
native function RequestTargetCancel();
native function RequestSkillList();
native function RequestRaidRecord();
native function RequestTradeDone( bool bDone );
native function RequestStartTrade( int targetID );
native function RequestAddTradeItem( int serverID, int num );
native function AnswerTradeRequest( bool bOK );
native function RequestSellItem( string param );
native function RequestBuyItem( string param );

native function RequestBuySeed( string param );
native function RequestProcureCrop( string param );
native function RequestSetSeed( string param );
native function RequestSetCrop( string param );

native function RequestAttack( int ServerID, vector Loc );
native function RequestAction( int ServerID, vector Loc );
native function RequestAssist( int ServerID, vector Loc );
native function RequestTargetUser( int ServerID );
native function RequestWarehouseDeposit( string param );
native function RequestWarehouseWithdraw( string param );
native function RequestChangePetName( string Name );
native function RequestPackageSendableItemList( int targetID );
native function RequestPackageSend( string param );
native function RequestPreviewItem( string param );
native function RequestBBSBoard();
native function RequestMultiSellChoose( string param );
native function RequestRestartPoint( ERestartPointType Type );
native function RequestUseItem( int serverID );
native function RequestDestroyItem( int serverID, int num );
native function RequestDropItem( int serverID, int num, Vector location );
native function RequestUnequipItem( int serverID, int slotBitType );
native function RequestCrystallizeItem( int serverID, int number );
native function RequestItemList();		// Ivnetory Item request
native function RequestDuelStart( string sTargetName, int duelType );				// 결투 신청
native function RequestDuelAnswerStart( int duelType, int option, int answer );		// 결투 신청에 대한 응답. option은 결투 수락 가능 옵션의 값. 0 이면 answer는 더미.
native function RequestDuelSurrender();												// 현재 진행 중인 결투에서 항복(패배 인정).

// PrivateShop
native function RequestQuitPrivateShop(string type);			// type : "sell", "buy", "sellList", "buyList"	 PrivateShopWnd.uc 참조
native function SendPrivateShopList(string type, string param);

// Party
native function int GetPartyMemberCount();
native function bool GetPartyMemberLocation( int a_PartyMemberIndex, out Vector a_Location );

// clan
native function RequestClanMemberInfo( int type, string name );
native function RequestClanGradeList();
native function RequestClanChangeGrade( string sName, int grade );
native function RequestClanAssignPupil( string sMaster, string sPupil );
native function RequestClanDeletePupil( string sMaster, string sPupil );
native function RequestClanLeave(string ClanName, int clanType);
native function RequestClanExpelMember( int clanType, string sName );
native function RequestClanAskJoin( int ID, int clanType );
native function RequestClanDeclareWar();								// 혈맹 이름 입력창이 뜨고 거기서 이름을 넣는다
native function RequestClanDeclareWarWithUserID( int ID );				// 유저의 ID로 그 유저의 혈맹에 전쟁 선포
native function RequestClanDeclareWarWidhClanName( string sName );		// 혈맹 이름으로 전쟁 선포
native function RequestClanWithdrawWar();								// 혈맹 이름 입력창이 뜨고 거기서 이름을 넣는다
native function RequestClanWithdrawWarWithClanName( string sClanName );
native function RequestClanReorganizeMember( int type, string memberName, int clanType, string targetMemberName );

native function RequestClanRegisterCrest();
native function RequestClanUnregisterCrest();
native function RequestClanRegisterEmblem();
native function RequestClanUnregisterEmblem();

native function RequestClanChangeNickName( string sName, string sNickName );
native function RequestClanWarList( int page, int state );						// state 0:선포 1: 피선포
native function RequestClanAuth( int gradeID );
native function RequestEditClanAuth( int gradeID, array<int> powers );
native function RequestClanMemberAuth( int clanType, string sName );

native function RequestPCCafeCouponUse( string a_CouponKey );

native function string GetCastleName( int castleID );

native function bool	HasClanCrest();			// 혈맹 문장을 가지고 있는지를 리턴
native function bool	HasClanEmblem();		// 혈맹 휘장을 가지고 있는지를 리턴

native function RequestInviteParty( string sName );
//native function OpenBBS( int index );			//사용안함 2006.9.11 ttmayrin

// ClassInfo
native final function string GetClassType( int ClassID ); 
native final function string GetClassStr( int ClassID ); 
native function string GetClassIconName( int classID );

// UserInfo
native function bool GetPlayerInfo( out UserInfo a_UserInfo );
native function bool GetTargetInfo( out UserInfo a_UserInfo );
native function bool GetUserInfo( int userID, out UserInfo a_UserInfo );
native function bool GetPetInfo( out PetInfo a_PetInfo );
native function bool GetSkillInfo( int a_SkillID, int a_SkillLevel, out SkillInfo a_SkillInfo );
native function INT64 GetExpByPlayerLevel( int iLevel );
native function bool GetAccessoryServerID( out int a_LEar, out int a_REar, out int a_LFinger, out int a_RFinger );
native function int GetClassStep( int a_ClassID );

native function string GetClanName( int clanID );
native final function int GetClanNameValue(int iClanID);			// 혈맹 명성치 얻어온다

native final function int GetAdena();								// 현재 인벤토리에 갖고 있는 아데나 카운트를 리턴
// Util API
native final function string MakeBuffTimeStr( int Time );
native final function string GetTimeString();
native final function string ConvertTimetoStr( int Time );
native final function Debug( string strMsg );
native final function bool IsKeyDown( EInputKey Key );
native final function string GetSystemString(int id);
native final function string GetSystemMessage(int id);
native final function GetSystemMsgInfo(int id, out SystemMsgData SysMsgData);		// lancelot 2006. 10. 11.

native final function UIScript GetScript( string window );
native final function string MakeFullSystemMsg( string sMsg, string sArg1, optional string sArg2 );

native final function GetTextSize( string strInput, out int nWidth, out int nHeight);
native final function GetZoneNameTextSize( string strInput, out int nWidth, out int nHeight);

native final function string MakeFullItemName(int id);
native final function string GetItemGradeString(int nCrystalType);
native final function string MakeCostStringInt64( INT64 a_Input );
native final function string MakeCostString( string strInput );
native final function string ConvertNumToText( string strInput );
native final function string ConvertNumToTextNoAdena( string strInput );
native final function color GetNumericColor( string strCommaAdena );
native final function int GetInventoryItemCount( int nID );
native final function PlayConsoleSound(EInterfaceSoundType eType);
native final function EIMEType GetCurrentIMELang();
native final function texture GetPledgeCrestTexFromPledgeCrestID( int PledgeCrestID );
native final function texture GetAllianceCrestTexFromAllianceCrestID( int AllianceCrestID );
native final function RequestBypassToServer( string strPass );
native final function String GetUserRankString( int Rank );
native final function String GetRoutingString( int RoutingType );
native final function bool IsDebuff( int SkillID, int SkillLevel );
native final function bool CheckItemLimit( int ClassID, int Count );

native final function String Int64ToString( INT64 i64 );
native final function INT64 Int64SubtractBfromA(INT64 A, INT64 B);
native final function INT64 Int64Add( INT64 A, INT64 B );
native final function INT64 Int64Mul( int A, int B );
native final function INT64	Int2Int64( int value );

native final function float GetExpRate( INT64 a_Exp, optional int a_Level );

native function Vector GetClickLocation();

native final function GetCurrentResolution(out int ScreenWidth, out int ScreenHeight);

//Chat Prefix
native function string GetChatPrefix(EChatType type);
native function bool IsSameChatPrefix(EChatType type, string InputPrefix);

// PrivateStore
native function SetPrivateShopMessage( string type, string message );		// type : "buy" or "sell"
native function string GetPrivateShopMessage( string type );				// type : "buy" or "sell"

//System Message
native final function AddSystemMessage( String a_Message, Color a_Color );
native final function AddSystemMessageParam( string strParam );
native final function string EndSystemMessageParam( int MsgNum, bool bGetMsg );

//Restart & Quit
native final function ExecRestart();
native final function ExecQuit();

//About Server
native final function EServerAgeLimit GetServerAgeLimit();
native final function int GetServerNo();
native final function int GetServerType();

// Option API
native final function bool CanUseAudio();
native final function bool CanUseJoystick();
native final function bool CanUseHDR();
native final function bool IsEnableEngSelection();
native final function bool IsUseKeyCrypt();
native final function bool IsCheckKeyCrypt();
native final function bool IsEnableKeyCrypt();
native final function ELanguageType GetLanguage();
native final function GetResolutionList( out Array<ResolutionInfo> a_ResolutionList );
native final function GetRefreshRateList( out Array<int> a_RefreshRateList, optional int a_nWidth, optional int a_nHeight );
native final function SetResolution( int a_nResolutionIndex, int a_nRefreshRateIndex );
native final function int GetMultiSample();
native final function int GetResolutionIndex();
native final function GetShaderVersion( out int a_nPixelShaderVersion, out int a_nVertexShaderVersion );
native final function SetDefaultPosition();
native final function SetKeyCrypt( bool a_bOnOff );
native final function SetTextureDetail( int a_nTextureDetail );
native final function SetModelingDetail( int a_nModelingDetail );
native final function SetMotionDetail( int a_nMotionDetail );
native final function SetShadow( bool a_bShadow );
native final function SetBackgroundEffect( bool a_bBackgroundEffect );
native final function SetTerrainClippingRange( int a_nTerrainClippingRange );
native final function SetPawnClippingRange( int a_nPawnClippingRange );
native final function SetReflectionEffect( int a_nReflectionEffect );
native final function SetHDR( int a_nHDR );
native final function SetWeatherEffect( int a_nWeatherEffect );

// Common API
native final function ExecuteCommand( String a_strCmd );
native final function ExecuteCommandFromAction( String strCmd );
native final function DoAction( INT ActionID );
native final function UseSkill( INT SkillID );
native final function bool IsStackableItem( int consumeType );

// Option API
native final function SetOptionBool( string a_strSection, string a_strName, bool a_bValue );
native final function SetOptionInt( string a_strSection, string a_strName, int a_nValue );
native final function SetOptionFloat( string a_strSection, string a_strName, float a_fValue );
native final function SetOptionString( string a_strSection, string a_strName, string a_strValue );
native final function bool GetOptionBool( string a_strSection, string a_strName );
native final function int GetOptionInt( string a_strSection, string a_strName );
native final function float GetOptionFloat( string a_strSection, string a_strName );
native final function string GetOptionString( string a_strSection, string a_strName );

// Inventory Item API
native final function string GetSlotTypeString( int ItemType, int SlotBitType, int ArmorType );
native final function string GetWeaponTypeString( int WeaponType );
native final function int GetPhysicalDamage( int WeaponType, int SlotBitType, int CrystalType, int Enchanted, int PhysicalDamage );
native final function int GetMagicalDamage( int WeaponType, int SlotBitType, int CrystalType, int Enchanted, int MagicalDamage );
native final function string GetAttackSpeedString( int AttackSpeed );
native final function int GetShieldDefense( int CrystalType, int Enchanted, int ShieldDefense );
native final function int GetPhysicalDefense( int CrystalType, int Enchanted, int PhysicalDefense );
native final function int GetMagicalDefense( int CrystalType, int Enchanted, int MagicalDefense );
native final function bool IsMagicalArmor( int ClassID );
native final function string GetLottoString( int Enchanted, int Damaged);
native final function string GetRaceTicketString( int Blessed );

// INI file option
native final function RefreshINI( String a_INIFileName );
native final function bool GetINIBool( string section, string key, out int value, string file );
native final function bool GetINIInt( string section, string key, out int value, string file );
native final function bool GetINIFloat( string section, string key, out float value, string file );
native final function bool GetINIString( string section, string key, out string value, string file );

native final function SetINIBool( string section, string key, bool value, string file );
native final function SetINIInt( string section, string key, int value, string file );
native final function SetINIFloat( string section, string key, float value, string file );
native final function SetINIString( string section, string key, string value, string file );

// Constant API
native final function bool GetConstantInt( int a_nID, out int a_nValue );
native final function bool GetConstantString( int a_nID, out String a_strValue );
native final function bool GetConstantBool( int a_nID, out int a_bValue );
native final function bool GetConstantFloat( int a_nID, out float a_fValue );

// Audio API
native final function SetSoundVolume( float a_fVolume );
native final function SetMusicVolume( float a_fVolume );
native final function SetWavVoiceVolume( float a_fVolume );
native final function SetOggVoiceVolume( float a_fVolume );

// Tooltip API
native final function ReturnTooltipInfo( CustomTooltip Info );

// Default Events
event OnLoad();
event OnTick();
event OnShow();
event OnHide();
event OnEvent( int a_EventID, String a_Param );
event OnTimer( int TimerID );
event OnMinimize();
event OnEnterState( name a_PreStateName );
event OnExitState( name a_NextStateName );
event OnSendPacketWhenHiding();
event OnFrameExpandClick( bool bIsExpand );
event OnDefaultPosition();

// Keyboard events
event OnKeyDown( EInputKey Key );
event OnKeyUp( EInputKey Key );

// Mouse events
event OnLButtonDown( WindowHandle a_WindowHandle, int X, int Y );
event OnLButtonUp( WindowHandle a_WindowHandle, int X, int Y );
event OnLButtonDblClick( int X, int Y );
event OnRButtonDown( int X, int Y );
event OnRButtonUp( int X, int Y );
event OnRButtonDblClick( int X, int Y );

// Drag&Drop event
event OnDropItem( String strID, ItemInfo infItem, int x, int y );
event OnDragItemStart( String strID, ItemInfo infItem );
event OnDragItemEnd( String strID );
event OnDropItemSource( String strTarget, ItemInfo infItem );				// 아이템을 드랍했을 경우 드래그를 시작한 윈도우에 불린다.

// Button,Tab events
event OnClickButton( String strID );
event OnClickButtonWithHandle( ButtonHandle a_ButtonHandle );
event OnButtonTimer( bool bExpired );
event OnTabSplit( string sName );										// 탭윈도우에서 윈도우가 분리될때 보내진다.
event OnTabMerge( string sName );										// 탭윈도우에서 윈도우가 분리되었다가 합쳐질 때 보내진다.

// Editbox events
event OnCompleteEditBox( String strID );
event OnChangeEditBox( String strID );
event OnChatMarkedEditBox( String strID );

// ListCtrl events
event OnClickListCtrlRecord( String strID );
event OnDBClickListCtrlRecord( String strID );

// check box events
event OnClickCheckBox( String strID );

// ItemWnd event
event OnClickItem( String strID, int index );
event OnDBClickItem( String strID, int index );
event OnRClickItem( String strID, int index );
event OnRDBClickItem( String strID, int index );
event OnRClickItemWithHandle( ItemWindowHandle a_hItemWindow, int a_Index );
event OnDBClickItemWithHandle( ItemWindowHandle a_hItemWindow, int a_Index );
event OnSelectItemWithHandle( ItemWindowHandle a_hItemWindow, int a_Index );

// ProgressCtrl
event OnProgressTimeUp( String strID );

// combobox event
event OnComboBoxItemSelected( String strID, int index );

// AnimTexture event
event OnTextureAnimEnd( AnimTextureHandle a_AnimTextureHandle );

// API for MainWnd. This is temporary measure
//native final function SetTabStatusWnd(int x, int y);	2006.8 ttmayrin
//native final function SetTabSkillWnd(int x, int y);	2006.9.27 ttmayrin
//native final function SetTabActionWnd(int x, int y);	2006.9.27 ttmayrin
//native final function SetTabQuestWnd(int x, int y);	2006.7 ttmayrin

native final function ProcessChatMessage( string chatMessage, int type );

// Petition Chat - NeverDie 2006/07/18
native final function ProcessPetitionChatMessage( string a_strChatMsg );

// PartyMatch Chat - NeverDie 2006/07/04
native final function ProcessPartyMatchChatMessage( string a_strChatMsg );

// CommandChannel Chat - ttmayrin 2006/10/10
native final function ProcessCommandChatMessage( string a_strChatMsg );
native final function ProcessCommandInterPartyChatMessage( string a_strChatMsg );

// Sound API for MenuWnd - lancelot 2006. 5. 10.
native final function PlaySound( String strSoundName);
native final function StopSound( String a_SoundName );

// MenuWnd API - lancelot 2006. 5. 11.
native final function RequestOpenMinimap();

// Slider control - lancelot 2006. 6. 13.
event OnModifyCurrentTickSliderCtrl(String strID, int iCurrentTick);

// Returns zone name with given zone ID - NeverDie 2006/06/26
native final function string GetZoneNameWithZoneID( int a_ZoneID );
native final function string GetCurrentZoneName();

// Returns looting method name with given looting method ID - NeverDie 2006/06/26
native final function string GetLootingMethodName( int a_LootingMethodID );
 
// Henna - lancelot 2006 .6. 29.
native final function RequestHennaItemInfo(int iHennaID);	// 문양새기기 윈도에서 염료 클릭했을때 염료정보 요청
native final function RequestHennaItemList();				// 문양새기기 - 염료정보 윈도에서 "<이전" 버튼 클릭시 이전화면으로
native final function RequestHennaEquip(int iHennaID);				// 문양새기기 - 염료정보 윈도에서 "확인" 버튼 클릭시 문신요청

native final function RequestHennaUnEquipInfo(int iHennaID);	// 문양지우기 윈도에서 문신 클릭했을때 문신정보 요청
native final function RequestHennaUnEquipList();				// 문양 지우기 윈도에서 "<이전"버튼 눌렀을때
native final function RequestHennaUnEquip(int iHennaID);		// 문양 지우기 윈도에서 "확인"버튼 눌렀을때

native final function SetChatMessage( String a_Message );

native function Vector GetPlayerPosition();

// Replay - lancelot 2006. 7. 10.
native final function GetFileList(out Array<string> FileList, string strDir, string strExtention);
native final function BeginReplay(string strFileName, bool bLoadCameraInst, bool bLoadChatData);
native final function EraseReplayFile(string strFileName);
// BenchMark- lancelot 2006. 7. 18.
native final function BeginPlay();
native final function BeginBenchMark();

// Skill Train - lancelot 2006. 8. 1.
// 스킬 목록창에서 스킬 정보요청
native final function RequestAcquireSkillInfo(int iID, int iLevel, int iType);
native final function RequestExEnchantSkillInfo(int iID, int iLevel);
// 스킬정보 창에서 스킬 배우기 요청
native final function RequestAcquireSkill(int iID, int iLevel, int iType);
native final function RequestExEnchantSkill(int iID, int iLevel);

// ObserverMode
native final function RequestObserverModeEnd();

native final function WindowHandle GetHandle( String a_ControlID );

// (cpptext)
// (cpptext)
// (cpptext)
// (cpptext)

// FishViewport
native final function RequestFishRanking();
native final function InitFishViewportWnd(bool Event);
native final function FishFinalAction();

native final function SaveInventoryOrder( array<int> order );
native final function bool LoadInventoryOrder( out array<int> order );

//manor
native final function RequestProcureCropList(string param);
native final function int GetManorCount();
native final function int GetManorIDInManorList(int index);
native final function string GetManorNameInManorList(int index);

native final function ToggleMsnWindow();

// minimap
native final function bool GetQuestLocation(Vector Location);

// PawnViewer
native final function RequestLoadAllItem();
native final function float GetPawnFrameCount();
native final function float GetPawnCurrentFrame();
