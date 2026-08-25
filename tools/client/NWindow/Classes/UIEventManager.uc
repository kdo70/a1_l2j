class UIEventManager extends Interactions
	dynamicrecompile
	native;	

const MAX_PartyMemberCount = 9;

enum EGMCommandType
{
	GMCOMMAND_None,
	GMCOMMAND_StatusInfo,
	GMCOMMAND_ClanInfo,
	GMCOMMAND_SkillInfo,
	GMCOMMAND_QuestInfo,
	GMCOMMAND_InventoryInfo,
	GMCOMMAND_WarehouseInfo,
};

enum ELanguageType
{
	LANG_None,
	LANG_Korean,
	LANG_English,
	LANG_Japanese,
	LANG_Taiwan,
	LANG_Chinese,
	LANG_Thai,
	LANG_Philippine,
};

enum EIMEType
{
	IME_NONE,
	IME_KOR,
	IME_ENG,
	IME_JPN,
	IME_CHN,
	IME_TAIWAN_CHANGJIE,
	IME_TAIWAN_DAYI,
	IME_TAIWAN_NEWPHONETIC,
	IME_TAIWAN_BOSHAMY,
	IME_CHN_MS,
	IME_CHN_JB,
	IME_CHN_ABC,
	IME_CHN_WUBI,
	IME_CHN_WUBI2,
	IME_THAI
};
	

const EV_Test	= 10;
const EV_LoginOK	= 20;
const EV_LoginFail	= 30;
const EV_Restart	= 40;
const EV_Die	= 50;
const EV_CardKeyLogin	= 60;
const EV_RegenStatus	= 70;
const EV_RadarTransitionFinished	= 80;
const EV_ShortcutCommand	= 90;
const EV_MagicSkillList	= 100;
const EV_SetRadarZoneCode	= 110;
const EV_RaidRecord	= 120;
const EV_ShowGuideWnd	= 130;
const EV_ShowScreenMessage	= 140;
const EV_GamingStateEnter	= 150;
const EV_GamingStateExit	= 160;
const EV_ServerAgeLimitChange	= 170;
const EV_UpdateUserInfo	= 180;
const EV_UpdateHP	= 190;
const EV_UpdateMaxHP	= 200;
const EV_UpdateMP	= 210;
const EV_UpdateMaxMP	= 220;
const EV_UpdateCP	= 230;
const EV_UpdateMaxCP	= 240;
const EV_UpdatePetInfo	= 250;
const EV_UpdateHennaInfo	= 260;
//const EV_InventoryItem	= 270;		//사용안함 2006.11.6 ttmayrin
const EV_ReceiveAttack	= 280;
const EV_ReceiveMagicSkillUse	= 290;
const EV_ReceiveTargetLevelDiff	= 300;
const EV_ShowReplayQuitDialogBox	= 310;
const EV_ClanInfo	= 320;
const EV_ClanInfoUpdate	= 330;
const EV_ClanMyAuth	= 340;
const EV_ClanAuthGradeList	= 350;
const EV_ClanCrestChange	= 360;
const EV_ClanAuth	= 370;
const EV_ClanAuthMember	= 380;
const EV_ClanSetAcademyMaster	= 390;
const EV_ClanAddMember	= 400;
const EV_ClanAddMemberMultiple	= 410;
const EV_ClanDeleteAllMember	= 420;
const EV_ClanMemberInfo	= 430;
const EV_ClanMemberInfoUpdate	= 440;
const EV_ClanDeleteMember	= 450;
const EV_ClanWarList	= 460;
const EV_ClanClearWarList	= 470;
const EV_ClanSubClanUpdated	= 480;
const EV_ClanSkillList	= 490;
const EV_ClanSkillListAdd	= 500;
const EV_MinFrameRateChanged	= 510;
const EV_PartyMemberChanged	= 520;
const EV_ShowPCCafeCouponUI	= 530;
const EV_ChatMessage	= 540;
const EV_ChatWndStatusChange	= 550;
const EV_ChatWndSetString	= 560;
const EV_ChatWndSetFocus	= 570;
const EV_ChatWndMsnStatus	= 571;
const EV_ChatWndMacroCommand = 572;
const EV_SystemMessage	= 580;
const EV_JoypadLButtonDown	= 590;
const EV_JoypadLButtonUp	= 600;
const EV_JoypadRButtonDown	= 610;
const EV_JoypadRButtonUp	= 620;
const EV_ShortcutUpdate	= 630;
const EV_ShortcutPageUpdate	= 640;
const EV_ShortcutClear	= 650;
const EV_ShortcutJoypad	= 660;
const EV_ShortcutPageDown	= 670;
const EV_ShortcutPageUp	= 680;
const EV_ShowShortcutWnd	= 690;
const EV_QuestListStart	= 700;
const EV_QuestList	= 710;
const EV_QuestListEnd	= 720;
const EV_QuestSetCurrentID	= 730;
const EV_SSQStatus	= 740;
const EV_SSQMainEvent	= 750;
const EV_SSQSealStatus	= 760;
const EV_SSQPreInfo	= 770;
const EV_RecipeShowBuyListWnd	= 780;
const EV_RecipeShopSellItem	= 790;
const EV_RecipeShopItemInfo	= 800;
const EV_RecipeShowRecipeTreeWnd	= 810;
const EV_RecipeShowBookWnd	= 820;
const EV_RecipeAddBookItem	= 830;
const EV_RecipeItemMakeInfo	= 840;
const EV_RecipeShopShowWnd	= 850;
const EV_RecipeShopAddBookItem	= 860;
const EV_RecipeShopAddShopItem	= 870;
const EV_HeroShowList	= 880;
const EV_HeroRecord	= 890;
const EV_OlympiadTargetShow	= 900;
const EV_OlympiadMatchEnd	= 910;
const EV_OlympiadUserInfo	= 920;
const EV_OlympiadBuffShow	= 930;
const EV_OlympiadBuffInfo	= 940;
const EV_AbnormalStatusNormalItem	= 950;
const EV_AbnormalStatusEtcItem	= 960;
const EV_AbnormalStatusShortItem	= 970;
const EV_TargetUpdate	= 980;
const EV_TargetHideWindow	= 990;
const EV_ShowBuffIcon	= 1000;
const EV_PetWndShow	= 1010;
const EV_PetWndShowNameBtn	= 1020;
const EV_PetWndRegPetNameFailed	= 1030;
const EV_PetStatusShow	= 1040;
const EV_PetStatusSpelledList	= 1050;
const EV_PetInventoryItemStart	= 1060;
const EV_PetInventoryItemList	= 1070;
const EV_PetInventoryItemUpdate	= 1080;
const EV_SummonedWndShow	= 1090;
const EV_SummonedStatusShow	= 1100;
const EV_SummonedStatusSpelledList	= 1110;
const EV_SummonedStatusRemainTime	= 1120;
const EV_PetSummonedStatusClose	= 1130;
const EV_PartyAddParty	= 1140;
const EV_PartyUpdateParty	= 1150;
const EV_PartyDeleteParty	= 1160;
const EV_PartyDeleteAllParty	= 1170;
const EV_PartySpelledList	= 1180;
const EV_ShowBBS	= 1190;
const EV_ShowBoardPacket	= 1200;
const EV_ShowHelp	= 1210;
const EV_LoadHelpHtml	= 1220;
const EV_LoadPetitionHtml	= 1221;
const EV_MacroShowListWnd	= 1230;
const EV_MacroUpdate	= 1240;
const EV_MacroList	= 1250;
const EV_MacroShowEditWnd	= 1260;
const EV_MacroDeleted	= 1270;
const EV_SkillListStart	= 1280;
const EV_SkillList	= 1290;
const EV_ActionListStart	= 1300;
const EV_ActionList	= 1310;
const EV_ActionPetListStart	= 1320;
const EV_ActionPetList	= 1330;
const EV_ActionSummonedListStart	= 1340;
const EV_ActionSummonedList	= 1350;
const EV_CommandChannelStart	= 1360;
const EV_CommandChannelEnd	= 1370;
const EV_CommandChannelInfo	= 1380;
const EV_CommandChannelPartyList	= 1390;
const EV_CommandChannelPartyUpdate = 1395;
const EV_CommandChannelRoutingType	= 1400;
const EV_CommandChannelPartyMember	= 1420;
const EV_RestartMenuShow	= 1430;
const EV_RestartMenuHide	= 1440;
const EV_SiegeInfo	= 1450;
const EV_SiegeInfoClanListStart	= 1460;
const EV_SiegeInfoClanList	= 1470;
const EV_SiegeInfoClanListEnd	= 1480;
const EV_SiegeInfoSelectableTime	= 1490;
const EV_IMEStatusChange	= 1500;
const EV_ArriveNewTutorialQuestion	= 1510;
const EV_ArriveShowQuest	= 1520;
const EV_ArriveNewMail	= 1530;
const EV_PartyMatchStart	= 1540;
const EV_PartyMatchRoomStart	= 1550;
const EV_PartyMatchRoomClose	= 1560;
const EV_PartyMatchList	= 1570;
const EV_PartyMatchRoomMember	= 1580;
const EV_PartyMatchRoomMemberUpdate	= 1590;
const EV_PartyMatchChatMessage	= 1600;
const EV_PartyMatchWaitListStart	= 1610;
const EV_PartyMatchWaitList	= 1620;
const EV_PartyMatchCommand	= 1630;
const EV_HennaListWndShowHideEquip	= 1640;
const EV_HennaListWndAddHennaEquip	= 1650;
const EV_HennaInfoWndShowHideEquip	= 1660;
const EV_HennaListWndShowHideUnEquip	= 1670;
const EV_HennaListWndAddHennaUnEquip	= 1680;
const EV_HennaInfoWndShowHideUnEquip	= 1690;
const EV_CalculatorWndShowHide	= 1700;
const EV_DialogOK	= 1710;
const EV_DialogCancel	= 1720;

const EV_RadarAddTarget	= 1730;
const EV_RadarDeleteTarget	= 1740;
const EV_RadarDeleteAllTarget	= 1750;
const EV_RadarColor	= 1760;
const EV_ShowTownMap	= 1770;

const EV_ShowMinimap	= 1780;
const EV_MinimapAddTarget	= 1790;
const EV_MinimapDeleteTarget	= 1800;
const EV_MinimapDeleteAllTarget	= 1810;
const EV_MinimapShowQuest	= 1820;
const EV_MinimapHideQuest	= 1830;
const EV_MinimapChangeOnTick	= 1840;
const EV_MinimapCursedWeaponList	= 1850;
const EV_MinimapCursedWeaponLocation	= 1860;
//const EV_MinimapCursedWeaponTooltipShow = 1861;
//const EV_MinimapCursedWeaponTooltipHide = 1862;
const EV_MinimapShowReduceBtn	= 1870;
const EV_MinimapHideReduceBtn	= 1880;
const EV_MinimapUpdateGameTime	= 1890;

const EV_LanguageChanged	= 1900;
const EV_PCCafePointInfo	= 1910;
const EV_ShowPetitionWnd	= 1920;
const EV_ShowUserPetitionWnd	= 1921;
const EV_PetitionChatMessage	= 1930;
const EV_EnablePetitionFeedback	= 1940;
const EV_TradeStart	= 1950;
const EV_TradeAddItem	= 1960;
const EV_TradeDone	= 1970;
const EV_TradeOtherOK	= 1980;
const EV_TradeUpdateInventoryItem	= 1990;
const EV_TradeRequestStartExchange	= 2000;
const EV_SkillTrainListWndShow	= 2010;
const EV_SkillTrainListWndHide	= 2020;
const EV_SkillTrainListWndAddSkill	= 2030;
const EV_SkillTrainInfoWndShow	= 2040;
const EV_SkillTrainInfoWndHide	= 2050;
const EV_SkillTrainInfoWndAddExtendInfo	= 2060;
const EV_SetMaxCount	= 2070;
const EV_ShopOpenWindow	= 2080;
const EV_ShopAddItem	= 2090;
const EV_WarehouseOpenWindow	= 2100;
const EV_WarehouseAddItem	= 2110;
const EV_PrivateShopOpenWindow	= 2120;
const EV_PrivateShopAddItem	= 2130;
const EV_SelectDeliverClear	= 2140;
const EV_SelectDeliverAddName	= 2150;
const EV_DeliverOpenWindow	= 2160;
const EV_DeliverAddItem	= 2170;
const EV_ShowEventMatchGMWnd	= 2180;
const EV_EventMatchCreated	= 2190;
const EV_EventMatchDestroyed	= 2200;
const EV_EventMatchManage	= 2210;
const EV_StartEventMatchObserver	= 2220;
const EV_EventMatchUpdateTeamName	= 2230;
const EV_EventMatchUpdateScore	= 2240;
const EV_EventMatchUpdateTeamInfo	= 2250;
const EV_EventMatchUpdateUserInfo	= 2260;
const EV_EventMatchGMMessage	= 2270;
const EV_ShowGMWnd	= 2280;
const EV_GMObservingUserInfoUpdate	= 2290;
const EV_GMObservingSkillListStart	= 2300;
const EV_GMObservingSkillList	= 2310;
const EV_GMObservingQuestListStart	= 2320;
const EV_GMObservingQuestList	= 2330;
const EV_GMObservingQuestListEnd	= 2340;
const EV_GMObservingQuestItem	= 2350;
const EV_GMObservingWarehouseItemListStart	= 2360;
const EV_GMObservingWarehouseItemList	= 2370;
const EV_GMObservingClan	= 2380;
const EV_GMObservingClanMemberStart	= 2390;
const EV_GMObservingClanMember	= 2400;
const EV_GMObservingInventoryAddItem = 2401;
const EV_GMObservingInventoryClear = 2402;
const EV_GMAddHennaInfo = 2403;
const EV_GMUpdateHennaInfo = 2404;
const EV_GMSnoop	= 2410;
const EV_BeginShowZoneTitleWnd	= 2420;
const EV_TutorialViewerWndShow	= 2430;
const EV_TutorialViewerWndHide	= 2440;
const EV_ObserverWndShow	= 2450;
const EV_ObserverWndHide	= 2460;

// fishviewport
const EV_FishViewportWndShow	= 2470;
const EV_FishViewportWndHide	= 2480;
const EV_FishViewportWndInit	= 2490;
const EV_FishViewportWndFinalAction	= 2500;
const EV_FishRankEventButtonShow	= 2510;
const EV_FishRankEventButtonHide	= 2520;
const EV_MultiSellShopID	= 2530;
const EV_MultiSellItemList	= 2540;
const EV_MultiSellNeededItemList	= 2550;
const EV_MultiSellItemListEnd	= 2560;
const EV_InventoryClear	= 2570;
const EV_InventoryOpenWindow	= 2580;
const EV_InventoryHideWindow	= 2590;
const EV_InventoryAddItem	= 2600;
const EV_InventoryUpdateItem	= 2610;
const EV_InventoryItemListEnd	= 2620;
const EV_InventoryAddHennaInfo	= 2630;
const EV_InventoryToggleWindow = 2631;

// manor
const EV_ManorCropSellWndShow	= 2640;
const EV_ManorCropSellWndAddItem	= 2645;
const EV_ManorCropSellWndSetCropSell	= 2646;
const EV_ManorCropSellChangeWndShow	= 2647;
const EV_ManorCropSellChangeWndAddItem	= 2648;
const EV_ManorCropSellChangeWndSetCropNameAndRewardType	= 2649;

const EV_ManorInfoWndSeedShow		= 2650;
const EV_ManorInfoWndSeedAdd		= 2651;
const EV_ManorInfoWndCropShow		= 2652;
const EV_ManorInfoWndCropAdd		= 2653;
const EV_ManorInfoWndDefaultShow	= 2654;
const EV_ManorInfoWndDefaultAdd		= 2655;

const EV_ManorSeedInfoSettingWndShow		= 2656;
const EV_ManorSeedInfoSettingWndAddItem		= 2657;
const EV_ManorSeedInfoSettingWndAddItemEnd	= 2658;
const EV_ManorSeedInfoSettingWndChangeValue	= 2659;
const EV_ManorSeedInfoChangeWndShow			= 2660;
const EV_ManorCropInfoSettingWndShow		= 2665;
const EV_ManorCropInfoSettingWndAddItem		= 2666;
const EV_ManorCropInfoSettingWndAddItemEnd	= 2667;
const EV_ManorCropInfoSettingWndChangeValue	= 2668;
const EV_ManorCropInfoChangeWndShow			= 2670;

const EV_ManorShopWndOpen					= 2680;
const EV_ManorShopWndAddItem				= 2690;

const EV_ShowPlaySceneInterface=3000;	//solasys
const EV_DuelAskStart = 2700;
const EV_DuelReady = 2710;
const EV_DuelStart = 2720;
const EV_DuelEnd = 2730;
const EV_DuelUpdateUserInfo = 2740;
const EV_DuelEnemyRelation = 2750;
const EV_ShowRefineryInteface = 2760;
const EV_RefineryConfirmTargetItemResult = 2770;
const EV_RefineryConfirmRefinerItemResult = 2780;
const EV_RefineryConfirmGemStoneResult = 2790;
const EV_RefineryRefineResult = 2800;
const EV_ShowRefineryCancelInteface = 2810;
const EV_RefineryConfirmCancelItemResult = 2820;
const EV_RefineryRefineCancelResult = 2830;

//QuestListWnd
const EV_QuestInfoStart	= 2840;
const EV_QuestInfo = 2850;

//ItemEnchantWnd
const EV_EnchantShow = 2860;
const EV_EnchantHide = 2870;
const EV_EnchantItemList = 2880;
const EV_EnchantResult = 2890;

const EV_ResolutionChanged = 2900;

// PawnViewer
const EV_PawnViewerWndAddItem	= 2910;

//Tooltip
const EV_RequestTooltipInfo	= 2920;

enum EEventMatchObsMsgType
{
	MESSAGE_GM,
	MESSAGE_Finish,
	MESSAGE_Start,
	MESSAGE_GameOver,
	MESSAGE_1,
	MESSAGE_2,
	MESSAGE_3,
	MESSAGE_4,
	MESSAGE_5,
};

enum ETextAlign
{
	TA_Undefined,
	TA_Left, 
	TA_Center,
	TA_Right,
	TA_MacroIcon,
}; 
  
enum ETextureCtrlType
{
	TCT_Stretch,
	TCT_Normal,
	TCT_Tile,
	TCT_Draggable,
	TCT_Control,	//툴팁을 표시할 수 있다
};
 
enum ETextureLayer
{
	TL_None,
	TL_Normal,
	TL_Background,	
};

enum ENameCtrlType
{
	NCT_Normal,
	NCT_Item
};

enum EItemType
{
	ITEM_WEAPON, 
	ITEM_ARMOR, 
	ITEM_ACCESSARY, 	
	ITEM_QUESTITEM, 
	ITEM_ASSET, 
	ITEM_ETCITEM
};

enum EItemParamType
{
	ITEMP_WEAPON,
	ITEMP_ARMOR,
	ITEMP_SHIELD,
	ITEMP_ACCESSARY, 
	ITEMP_ETC,
};

enum EEtcItemType
{
	ITEME_NONE,
	ITEME_SCROLL,
	ITEME_ARROW,
	ITEME_POTION,
	ITEME_SPELLBOOK,
	ITEME_RECIPE,
	ITEME_MATERIAL,
	ITEME_PET_COLLAR,
	ITEME_CASTLE_GUARD,
	ITEME_DYE,
	ITEME_SEED,
	ITEME_SEED2,
	ITEME_HARVEST,
	ITEME_LOTTO,
	ITEME_RACE_TICKET,
	ITEME_TICKET_OF_LORD,
	ITEME_LURE,
	ITEME_CROP,
	ITEME_MATURECROP,
	ITEME_ENCHT_WP,
	ITEME_ENCHT_AM,
	ITEME_BLESS_ENCHT_WP,
	ITEME_BLESS_ENCHT_AM,
	ITEME_COUPON,
	ITEME_ELIXIR,
};

enum ESkillCategory
{
	SKILL_Active,
	SKILL_Passive,
};

enum EActionCategory
{
	ACTION_NONE,
	ACTION_BASIC,
	ACTION_PARTY,
	ACTION_SOCIAL,
	ACTION_PET,
	ACTION_SUMMON,
};

enum EXMLTreeNodeItemType
{
	XTNITEM_BLANK,
	XTNITEM_TEXT,
	XTNITEM_TEXTURE,
};

enum EServerAgeLimit
{
	SERVER_AGE_LIMIT_15,
	SERVER_AGE_LIMIT_18,
	SERVER_AGE_LIMIT_Free,
};

enum EInterfaceSoundType
{
	IFST_CLICK1,
	IFST_CLICK2,
	IFST_CLICK_FAILED,
	IFST_PICKUP,
	IFST_TRASH_BASKET,
	IFST_WINDOW_OPEN,
	IFST_WINDOW_CLOSE,
	IFST_QUEST_TUTORIAL,
	IFST_MINIMAP_OPEN_CLOSE,
	IFST_COOLTIME_END,
	IFST_PETITION,
	IFST_STATUSWND_OPEN,
	IFST_STATUSWND_CLOSE,
	IFST_INVENWND_OPEN,
	IFST_INVENWND_CLOSE,
	IFST_MAPWND_OPEN,
	IFST_MAPWND_CLOSE,
	IFST_SYSTEMWND_OPEN,
	IFST_SYSTEMWND_CLOSE,
};

enum EChatType
{
	CHAT_NORMAL,
	CHAT_SHOUT,		// '!'
	CHAT_TELL,		// '\'
	CHAT_PARTY,		// '#'
	CHAT_CLAN,		// '@'
	CHAT_SYSTEM,		// ''
	CHAT_USER_PET,	// '^'
	CHAT_GM_PET,		// '&'
	CHAT_MARKET,		// '+'
	CHAT_ALLIANCE,	// '%'	
	CHAT_ANNOUNCE,	// ''
	CHAT_CUSTOM,		// ''
	CHAT_L2_FRIEND,	// ''
	CHAT_MSN_CHAT,	// ''
	CHAT_PARTY_ROOM_CHAT,	// ''
	CHAT_COMMANDER_CHAT,
	CHAT_INTER_PARTYMASTER_CHAT,
	CHAT_HERO,
	CHAT_CRITICAL_ANNOUNCE,
};

enum ESystemMsgType
{
	SYSTEM_NONE,
	SYSTEM_BATTLE,
	SYSTEM_SERVER,
	SYSTEM_DAMAGE,
	SYSTEM_POPUP,
	SYSTEM_ERROR,
	SYSTEM_PETITION,
	SYSTEM_USEITEMS,
};

enum ESystemMsgParamType
{
	SMPT_STRING,
	SMPT_NUMBER,
	SMPT_NPCID,
	SMPT_ITEMID,
	SMPT_SKILLID,
	SMPT_CASTLEID,
	SMPT_BIGNUMBER,
	SMPT_ZONENAME,
};

enum EServerObjectType
{
	SOT_NONE,
	SOT_STATIC,
	SOT_DOOR,
};

enum EMoveType
{
	MVT_NONE,
    MVT_SLOW,
    MVT_FAST,
};

enum EEnvType
{
	ET_NONE,
	ET_GROUND,
	ET_UNDERWATER,
	ET_AIR,
	ET_HOVER,
};

enum EControlReturnType
{
	CRTT_NO_CONTROL_USE,
	CRTT_CONTROL_USE,
	CRTT_USE_AND_HIDE,
};

enum EShortCutItemType
{
	SCIT_NONE,
	SCIT_ITEM,
	SCIT_SKILL,
	SCIT_ACTION,
	SCIT_MACRO,
	SCIT_RECIPE,
};

enum EInventoryUpdateType
{
	IVUT_NONE,
	IVUT_ADD,
	IVUT_UPDATE,
	IVUT_DELETE,
};

enum ERestartPointType
{
	RPT_VILLAGE,
	RPT_AGIT,
	RPT_CASTLE,
	RPT_BATTLE_CAMP,
	RPT_ORIGINAL_PLACE,
};

enum ECastleSiegeDefenderType
{
	CSDT_NOT_DEFENDER,
	CSDT_CASTLE_OWNER,
	CSDT_WAITING_CONFIRM,
	CSDT_APPROVED,
	CSDT_REJECTED,
};

enum ETooltipSourceType
{
	NTST_TEXT,
	NTST_ITEM,
	NTST_LIST,
};

const	MAX_Level = 80;

const	CLAN_AUTH_VIEW = 1;
const	CLAN_AUTH_EDIT = 2;

const	CLAN_MAIN = 0;
const	CLAN_KNIGHT1 = 100;
const	CLAN_KNIGHT2 = 200;
const	CLAN_KNIGHT3 = 1001;
const	CLAN_KNIGHT4 = 1002;
const	CLAN_KNIGHT5 = 2001;
const	CLAN_KNIGHT6 = 2002;
const	CLAN_ACADEMY = -1;

const	CLAN_KNIGHTHOOD_COUNT = 8;

const	CLAN_AUTH_GRADE1 = 1;
const	CLAN_AUTH_GRADE2 = 2;
const	CLAN_AUTH_GRADE3 = 3;
const	CLAN_AUTH_GRADE4 = 4;
const	CLAN_AUTH_GRADE5=5;
const	CLAN_AUTH_GRADE6=6;
const	CLAN_AUTH_GRADE7=7;
const	CLAN_AUTH_GRADE8=8;
const	CLAN_AUTH_GRADE9=9;

struct native constructive ItemInfo
{
	var string Name;
	var string AdditionalName;
	var string IconName;
	var string IconNameEx1;
	var string IconNameEx2;
	var string IconNameEx3;
	var string IconNameEx4;
	var string ForeTexture;
	var string Description;
	var string DragSrcName;
	var int DragSrcReserved;
	var string MacroCommand;
	var int ItemType;
	var int ItemSubType;
	var int ServerID;
	var int ClassID;
	var int ItemNum;
	var int Price;
	var int Level;
	var int SlotBitType;
	var int Weight;
	var int MaterialType;
	var int WeaponType;
	var int PhysicalDamage;
	var int MagicalDamage;
	var int PhysicalDefense;
	var int MagicalDefense;
	var int ShieldDefense;
	var int ShieldDefenseRate;
	var int Durability; 
	var int CrystalType;
	var int RandomDamage;
	var int Critical;
	var int HitModify;
	var int AttackSpeed;
	var int MpConsume;
	var int ArmorType;
	var int AvoidModify;
	var int Damaged;
	var int Enchanted;
	var int MpBonus;
	var int SoulshotCount;
	var int SpiritshotCount;
	var int PopMsgNum;
	var int BodyPart;
	var int RefineryOp1;
	var int RefineryOp2;
	var int CurrentDurability;
	var int Reserved;
	var int DefaultPrice;
	var int ConsumeType;
	var int Blessed;
	var int AllItemCount;
	var int IconIndex;
	var bool bEquipped;
	var bool bRecipe;  
	var bool bArrow; 
	var bool bShowCount;
	var bool bDisabled;
	var bool bIsLock;
};

struct native constructive LVTexture
{
	var texture objTex;
	var int		X;
	var int		Y;
	var int		Width;
	var int		Height;
	var int		U;
	var int		V;
	var int		UL;
	var int		VL;
};

struct native constructive LVData
{
	var string szData;
	var string szReserved;

	var bool bUseTextColor;
	var Color TextColor;


	var int nReserved1;
	var int nReserved2;
	var int nReserved3;
	
	//Main Texture(텍스쳐 하나만 설정할때, Centeralign된다)
	var string szTexture;
	var int nTextureWidth;
	var int nTextureHeight;
	
	//Texture Array
	var array<LVTexture> arrTexture;
};

struct native constructive LVDataRecord
{	
	var array<LVData> LVDataList;
	var string szReserved;
	var int nReserved1;
	var int nReserved2;
	var int nReserved3;
};

struct native INT64
{
	var int nLeft;
	var int nRight;
};

struct native constructive UserInfo
{
	var int nID;
	var string Name;
	var string strNickName;
	var int nLevel;
	var int nClassID;
	var int nSubClass;
	var int nSP;
	var int nCurHP;
	var int nMaxHP;
	var int nCurMP;
	var int nMaxMP;
	var int nCurCP;
	var int nMaxCP;
	var INT64 nCurExp;
	
	var int nUserRank;
	var int nClanID;
	var int nAllianceID;
	var int nCarryWeight;
	var int nCarringWeight;
	
	var int nPhysicalAttack;
	var int nPhysicalDefense;
	var int nHitRate;
	var int nCriticalRate;
	var int nPhysicalAttackSpeed;
	var int nMagicalAttack;
	var int nMagicDefense;
	var int nPhysicalAvoid;
	var int nWaterMaxSpeed;
	var int nWaterMinSpeed;
	var int nAirMaxSpeed;
	var int nAirMinSpeed;
	var int nGroundMaxSpeed;
	var int nGroundMinSpeed;
	var float fNonAttackSpeedModifier;
	var int nMagicCastingSpeed;
	
	var int nStr;
	var int nDex;
	var int nCon;
	var int nInt;
	var int nWit;
	var int nMen;
	
	var int nCriminalRate;
	var int nDualCount;
	var int nPKCount;
	var int nSociality;
	var int nRemainSulffrage;
	
	var bool bHero;
	var bool bNobless;
	var bool bNpc;
	var bool bPet;
	var bool bCanBeAttacked;
	
	var vector Loc;
};

struct native constructive SkillInfo
{
	var String SkillName;
	var String SkillDesc;
	var int SkillID;
	var int SkillLevel;
	var int OperateType;	// 0 - A1 이상상태를 걸지 않는 액티브 스킬, 1 - A2 이상상태를 거는 액티브 스킬, 2 - P 패시브 스킬, 3 - T 토글 스킬 
	var int MpConsume;
	var int HpConsume;
	var int CastRange;
	var int CastStyle;
	var float HitTime;
	var bool IsUsed;
	var int IsMagic;
	var String AnimName;
	var String SkillPresetName;
	var String TexName;
	var bool IsDebuff;
	var String EnchantName;
	var String EnchantDesc;
	var int Enchanted;
	var int EnchantSkillLevel;
	var int RumbleSelf;
	var int RumbleTarget;
};

struct native constructive PetInfo
{
	var int nID;
	var string Name;
	var int nLevel;
	var int nSP;
	var int nCurHP;
	var int nMaxHP;
	var int nCurMP;
	var int nMaxMP;
	var INT64 nCurExp;
	var INT64 nMaxExp;
	var INT64 nMinExp;
	
	var int nCarryWeight;
	var int nCarringWeight;
	
	var int nPhysicalAttack;
	var int nPhysicalDefense;
	var int nHitRate;
	var int nCriticalRate;
	var int nPhysicalAttackSpeed;
	var int nMagicalAttack;
	var int nMagicDefense;
	var int nPhysicalAvoid;
	var int nMovingSpeed;
	var int nMagicCastingSpeed;
	var int nSoulShotCosume;
	var int nSpiritShotConsume;
	
	var int nFatigue;
	var int nMaxFatigue;
	var bool bIsPetOrSummoned;
};

struct native constructive MacroInfo
{
	var int		ID;
	var string	Name;
	var string	IconName;
	var string	IconTextureName;
	var string	Description;
	var string	CommandList[12];
};

struct native Rect
{
	var int nX;
	var int nY;
	var int nWidth;
	var int nHeight;
};

struct native constructive ClanMemberInfo
{
	var	int	clanType;
	var	string	sName;
	var	int	level;
	var	int	classID;
	var	int	gender;
	var	int	race;
	var	int	id;
	var	int	bHaveMaster;
};

struct native constructive ClanInfo
{
	var array<ClanMemberInfo>	m_array;
	var string					m_sName;
	var string					m_sMasterName;
};

struct native ResolutionInfo
{
	var int nWidth;
	var int nHeight;
	var int nColorBit;
};

enum EDrawItemType
{
	DIT_BLANK,
	DIT_TEXT,
	DIT_TEXTURE,
};

struct native constructive DrawItemInfo
{
	var EDrawItemType eType;
	
	var int		nOffSetX;
	var int		nOffSetY;
	var bool	bLineBreak;
	
	//For BLANK
	var int		b_nHeight;
	
	//For TEXT
	var int		t_ID;
	var string	t_strText;
	var color	t_color;
	var bool	t_bDrawOneLine;
	
	//For TEXTURE
	var int		u_nTextureWidth;
	var int		u_nTextureHeight;
	var int		u_nTextureUWidth;
	var int		u_nTextureUHeight;
	var string	u_strTexture;
	
	//For Dynamic Text
	var string Condition;
};

struct native constructive CustomTooltip
{
	var int MinimumWidth;
	var int SimpleLineCount;
	var Array<DrawItemInfo> DrawList;
};

struct native constructive XMLTreeNodeItemInfo
{
	var EXMLTreeNodeItemType eType;
	
	var int		nOffSetX;
	var int		nOffSetY;
	var bool	bLineBreak;
	var bool	bStopMouseFocus;
	
	//For E_XMLTREE_NODEITEM_BLANK
	var int		b_nHeight;
	
	//For E_XMLTREE_NODEITEM_TEXT
	var int		t_nTextID;
	var string	t_strText;
	var color	t_color;
	var bool	t_bDrawOneLine;
	
	//For E_XMLTREE_NODEITEM_TEXTURE
	var int		u_nTextureWidth;
	var int		u_nTextureHeight;
	var int		u_nTextureUWidth;
	var int		u_nTextureUHeight;
	var string	u_strTexture;
	var string	u_strTextureMouseOn;
	var string	u_strTextureExpanded;
};

struct native constructive XMLTreeNodeInfo
{
	var string	strName;
	
	var int		nOffSetX;
	var int		nOffSetY;
	
	var int		bDrawBackground;
	
	//For Back Texture
	var int		bTexBackHighlight;
	var int		nTexBackHighlightHeight;
	var int		nTexBackWidth;
	var int		nTexBackUWidth;
	var int		nTexBackOffSetX;
	var int		nTexBackOffSetY;
	var int		nTexBackOffSetBottom;
	
	//Expanded Texture
	var string	strTexExpandedLeft;
	var string	strTexExpandedRight;
	var int		nTexExpandedOffSetX;
	var int		nTexExpandedOffSetY;
	var int		nTexExpandedHeight;
	var int		nTexExpandedRightWidth;
	var int		nTexExpandedLeftUWidth;
	var int		nTexExpandedLeftUHeight;
	var int		nTexExpandedRightUWidth;
	var int		nTexExpandedRightUHeight;
	
	//For Tree Expand Button
	var int		bShowButton;
	var int		nTexBtnWidth;
	var int		nTexBtnHeight;
	var int		nTexBtnOffSetX;
	var int		nTexBtnOffSetY;
	var string	strTexBtnExpand;
	var string	strTexBtnCollapse;
	var string	strTexBtnExpand_Over;
	var string	strTexBtnCollapse_Over;
	
	//For Tooltip
	var CustomTooltip ToolTip;
	var bool bFollowCursor;
};

struct native constructive StatusIconInfo
{
	var string	Name;
	var string	IconName;
	var int		Size;
	var string	Description;
	var string  BackTex;

	var int		RemainTime;
	var int		ClassID;
	var int		Level;
	
	var bool	bShow;
	var bool	bShortItem;
	var bool	bEtcItem;
	var bool	bDeBuff;
};

struct native constructive GameTipData
{
	var int ID;
	var int Priority;
	var int TargetLevel;
	var bool Validity;
	var String TipMsg;
};

struct native constructive HennaInfo
{
	var int HennaID;
	var int ClassID; 
	var int Num;
	var int Fee;
	var int CanUse;
	var int INTnow;
	var int INTchange;
	var int STRnow;
	var int STRchange;
	var int CONnow;
	var int CONchange;
	var int MENnow;
	var int MENchange;
	var int DEXnow;
	var int DEXchange;
	var int WITnow;
	var int WITchange;
};

struct native constructive EventMatchUserData
{
	var int UserID;
	var String UserName;
	var int HPNow;
	var int HPMax;
	var int MPNow;
	var int MPMax;
	var int CPNow;
	var int CPMax;
	var int UserLv;
	var int UserClass;
	var int UserGender;
	var int UserRace;
	var Array<int> BuffIDList;
	var Array<int> BuffRemainList;
};

// lancelot 2006. 10. 11.
struct native constructive SystemMsgData
{
	var String Group;
	var Color color;
	var String Sound;
	var String Voice;
	var int WindowType;
	var int FontType;
	var int LifeTime;
	var int AnimationType;
	var int BackgroundType;
	var String SysMsg;
	var String OnScrMsg;
};


struct native constructive EventMatchTeamData
{
	var int Score;
	var String TeamName;
	var int PartyMemberCount;
	var EventMatchUserData User[ MAX_PartyMemberCount ];
};

struct native EventMatchData
{
	var EventMatchTeamData Team[ 2 ];
};

native function ExecuteEvent( int a_EventID, optional string a_Param );

//Param
native function ParamAdd( out string strParam, string strName, string strValue );
native function ParamAddInt64( out string strParam, string strName, INT64 sValue );
native function bool ParseString( string a_strCmd, string a_strMatch, out string a_strResult );
native function bool ParseInt( string a_strCmd, string a_strMatch, out int a_Result );
native function bool ParseInt64( string a_strCmd, string a_strMatch, out INT64 a_Result );
native function bool ParseFloat( string a_strCmd, string a_strMatch, out float a_Result );

native function RegisterEvent( int ev);
native function RegisterState(string WindowName, string state);
native function SetUIState(string State);
native function MessageBox(string Msg);
native function SMessageBox(int SystemMsgNum);
native function string GetUIState();
