package net.sf.l2j;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.math.BigInteger;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.StringTokenizer;

import net.sf.l2j.commons.config.ExProperties;
import net.sf.l2j.commons.logging.CLogger;

import net.sf.l2j.gameserver.enums.ChampionType;
import net.sf.l2j.gameserver.enums.GeoType;
import net.sf.l2j.gameserver.enums.MonsterKind;
import net.sf.l2j.gameserver.model.ChampionSettings;
import net.sf.l2j.gameserver.model.actor.template.NpcTemplate;
import net.sf.l2j.gameserver.model.holder.IntIntHolder;
import net.sf.l2j.gameserver.model.records.MonsterNameplate;

/**
 * This class contains global server configuration.<br>
 * It has static final fields initialized from configuration files.
 */
public final class Config
{
	private Config()
	{
		throw new IllegalStateException("Utility class");
	}
	
	private static final CLogger LOGGER = new CLogger(Config.class.getName());
	
	private static final String CLANS_FILE = "./config/clans.properties";
	private static final String DEVELOPMENT_FILE = "./config/development.properties";
	private static final String FEATURES_FILE = "./config/features.properties";
	public static final String GEOENGINE_FILE = "./config/geoengine.properties";
	private static final String HEXID_FILE = "./config/hexid.txt";
	private static final String ITEMS_FILE = "./config/items.properties";
	private static final String LOGINSERVER_FILE = "./config/loginserver.properties";
	private static final String NETWORK_FILE = "./config/network.properties";
	private static final String PROTECTION_FILE = "./config/protection.properties";
	private static final String RATES_FILE = "./config/rates.properties";
	private static final String SERVER_FILE = "./config/server.properties";
	private static final String SIEGE_FILE = "./config/siege.properties";
	
	private static final String EVENTS_INSTANCES_FILE = "./config/events/instances.properties";
	private static final String EVENTS_MINIGAMES_FILE = "./config/events/minigames.properties";
	private static final String EVENTS_OLYMPIAD_FILE = "./config/events/olympiad.properties";
	private static final String EVENTS_SEVEN_SIGNS_FILE = "./config/events/sevensigns.properties";
	
	private static final String MODS_CHAMPION_MOBS_FILE = "./config/mods/championmobs.properties";
	private static final String MODS_CLIENT_FILE = "./config/mods/client.properties";
	private static final String MODS_DROPLIST_FILE = "./config/mods/droplist.properties";
	private static final String MODS_GATEKEEPER_FILE = "./config/mods/gatekeeper.properties";
	private static final String MODS_OFFLINE_SHOP_FILE = "./config/mods/offlineshop.properties";
	private static final String MODS_RAIDBOOK_FILE = "./config/mods/raidbook.properties";
	
	private static final String NPCS_BOSSES_FILE = "./config/npcs/bosses.properties";
	private static final String NPCS_MANAGERS_FILE = "./config/npcs/managers.properties";
	private static final String NPCS_FILE = "./config/npcs/npcs.properties";
	private static final String NPCS_NAMEPLATES_FILE = "./config/npcs/nameplates.properties";
	
	private static final String PLAYERS_ADMIN_FILE = "./config/players/admin.properties";
	private static final String PLAYERS_AUGMENTATION_FILE = "./config/players/augmentation.properties";
	private static final String PLAYERS_CHARACTER_FILE = "./config/players/character.properties";
	private static final String PLAYERS_ENCHANT_FILE = "./config/players/enchant.properties";
	private static final String PLAYERS_INVENTORY_FILE = "./config/players/inventory.properties";
	private static final String PLAYERS_KARMA_FILE = "./config/players/karma.properties";
	private static final String PLAYERS_SKILLS_FILE = "./config/players/skills.properties";
	
	// --------------------------------------------------
	// Mods - champion mobs
	// --------------------------------------------------
	
	/** Settings of every flavor of champion monster - red and blue - each one holding its own frequency, multipliers, extra drops and schedule. */
	public static final Map<ChampionType, ChampionSettings> CHAMPION_MOBS = new EnumMap<>(ChampionType.class);
	
	// --------------------------------------------------
	// Clans
	// --------------------------------------------------
	
	/** Clans */
	public static int CLAN_JOIN_DAYS;
	public static int CLAN_CREATE_DAYS;
	public static int CLAN_DISSOLVE_DAYS;
	public static int ALLY_JOIN_DAYS_WHEN_LEAVED;
	public static int ALLY_JOIN_DAYS_WHEN_DISMISSED;
	public static int ACCEPT_CLAN_DAYS_WHEN_DISMISSED;
	public static int CREATE_ALLY_DAYS_WHEN_DISSOLVED;
	public static int MAX_NUM_OF_CLANS_IN_ALLY;
	public static int CLAN_MEMBERS_FOR_WAR;
	public static int CLAN_WAR_PENALTY_WHEN_ENDED;
	public static boolean MEMBERS_CAN_WITHDRAW_FROM_CLANWH;
	
	/** Manor */
	public static boolean ALLOW_MANOR;
	public static int MANOR_REFRESH_TIME;
	public static int MANOR_REFRESH_MIN;
	public static int MANOR_APPROVE_TIME;
	public static int MANOR_APPROVE_MIN;
	public static int MANOR_MAINTENANCE_MIN;
	public static int MANOR_SAVE_PERIOD_RATE;
	
	// --------------------------------------------------
	// Events - olympiad
	// --------------------------------------------------
	
	public static int OLY_START_TIME;
	public static int OLY_MIN;
	public static long OLY_CPERIOD;
	public static long OLY_BATTLE;
	public static int OLY_WAIT_TIME;
	public static int OLY_WAIT_BATTLE;
	public static int OLY_WAIT_END;
	public static int OLY_START_POINTS;
	public static int OLY_WEEKLY_POINTS;
	public static int OLY_MIN_MATCHES;
	public static int OLY_CLASSED;
	public static int OLY_NONCLASSED;
	public static IntIntHolder[] OLY_CLASSED_REWARD;
	public static IntIntHolder[] OLY_NONCLASSED_REWARD;
	public static int OLY_GP_PER_POINT;
	public static int OLY_HERO_POINTS;
	public static int OLY_MAX_POINTS;
	public static int OLY_DIVIDER_CLASSED;
	public static int OLY_DIVIDER_NON_CLASSED;
	public static boolean OLY_ANNOUNCE_GAMES;
	
	// --------------------------------------------------
	// Events - seven signs
	// --------------------------------------------------
	
	public static boolean SEVEN_SIGNS_BYPASS_PREREQUISITES;
	public static int FESTIVAL_MIN_PLAYER;
	public static int MAXIMUM_PLAYER_CONTRIB;
	public static long FESTIVAL_MANAGER_START;
	public static long FESTIVAL_LENGTH;
	public static long FESTIVAL_CYCLE_LENGTH;
	public static long FESTIVAL_FIRST_SPAWN;
	public static long FESTIVAL_FIRST_SWARM;
	public static long FESTIVAL_SECOND_SPAWN;
	public static long FESTIVAL_SECOND_SWARM;
	public static long FESTIVAL_CHEST_SPAWN;
	
	// --------------------------------------------------
	// Events - instances
	// --------------------------------------------------
	
	/** Four Sepulchers */
	public static int FS_PARTY_MEMBER_COUNT;
	
	/** Dimensional Rift */
	public static int RIFT_MIN_PARTY_SIZE;
	public static int RIFT_AUTO_JUMPS_TIME_MIN;
	public static int RIFT_AUTO_JUMPS_TIME_RND;
	public static int RIFT_ENTER_COST_RECRUIT;
	public static int RIFT_ENTER_COST_SOLDIER;
	public static int RIFT_ENTER_COST_OFFICER;
	public static int RIFT_ENTER_COST_CAPTAIN;
	public static int RIFT_ENTER_COST_COMMANDER;
	public static int RIFT_ENTER_COST_HERO;
	public static int RIFT_ANAKAZEL_PORT_CHANCE;
	
	// --------------------------------------------------
	// Events - minigames
	// --------------------------------------------------
	
	/** Lottery */
	public static boolean ALLOW_LOTTERY;
	public static int LOTTERY_PRIZE;
	public static int LOTTERY_TICKET_PRICE;
	public static double LOTTERY_5_NUMBER_RATE;
	public static double LOTTERY_4_NUMBER_RATE;
	public static double LOTTERY_3_NUMBER_RATE;
	public static int LOTTERY_2_AND_1_NUMBER_PRIZE;
	
	/** Fishing tournament */
	public static boolean ALLOW_FISH_CHAMPIONSHIP;
	public static int FISH_CHAMPIONSHIP_REWARD_ITEM;
	public static int FISH_CHAMPIONSHIP_REWARD_1;
	public static int FISH_CHAMPIONSHIP_REWARD_2;
	public static int FISH_CHAMPIONSHIP_REWARD_3;
	public static int FISH_CHAMPIONSHIP_REWARD_4;
	public static int FISH_CHAMPIONSHIP_REWARD_5;
	
	// --------------------------------------------------
	// Mods - droplist window
	// --------------------------------------------------

	public static boolean DROPLIST_ENABLED;
	public static int DROPLIST_SKILL_ID;
	public static int DROPLIST_ROWS_PER_PAGE;
	public static boolean DROPLIST_SHOW_SPOIL;
	public static boolean DROPLIST_SHOW_HEADER;
	public static boolean DROPLIST_APPLY_RATES;
	public static boolean DROPLIST_APPLY_LEVEL_PENALTY;

	// --------------------------------------------------
	// Mods - raid boss book
	// --------------------------------------------------

	public static boolean RAIDBOOK_ENABLED;
	public static int RAIDBOOK_ITEM_ID;
	public static int RAIDBOOK_ROWS_PER_PAGE;
	public static int RAIDBOOK_TAB_ROWS_PER_PAGE;
	public static int RAIDBOOK_KILLS_PER_LEVEL;
	public static int RAIDBOOK_MAX_LEVEL;
	public static double RAIDBOOK_DAMAGE_PER_LEVEL;
	public static double RAIDBOOK_MAX_DAMAGE_BONUS;
	public static int RAIDBOOK_POINTS_PER_KILL;
	public static double RAIDBOOK_POINTS_PER_BOSS_LEVEL;
	public static boolean RAIDBOOK_SCREEN_MESSAGES;
	public static boolean RAIDBOOK_DAILY_ENABLED;
	public static Map<Integer, List<IntIntHolder>> RAIDBOOK_DAILY_REWARDS;
	public static int RAIDBOOK_HISTORY_SIZE;
	public static int RAIDBOOK_RANKING_SIZE;
	public static int RAIDBOOK_SHOWN_REWARDS;
	public static boolean RAIDBOOK_APPLY_RATES;
	public static boolean RAIDBOOK_APPLY_LEVEL_PENALTY;
	public static Map<Integer, List<IntIntHolder>> RAIDBOOK_LEVEL_REWARDS;
	public static List<IntIntHolder> RAIDBOOK_DEFAULT_REWARD;

	// --------------------------------------------------
	// Mods - gatekeeper
	// --------------------------------------------------
	
	/** General */
	public static int GATEKEEPER_ROWS_PER_PAGE;
	public static int GATEKEEPER_POPULAR_LIMIT;
	public static int GATEKEEPER_POPULAR_MIN_COUNT;
	public static int GATEKEEPER_TELEPORT_DELAY;
	
	/** Default prices */
	public static int GATEKEEPER_DEFAULT_PRICE_ID;
	public static int GATEKEEPER_DEFAULT_PRICE;
	public static int GATEKEEPER_DEFAULT_NOBLE_PRICE;
	
	/** Dynamic pricing */
	public static boolean GATEKEEPER_PRICING_ENABLED;
	public static int GATEKEEPER_PRICE_ROUNDING;
	public static boolean GATEKEEPER_DISTANCE_PRICE_ENABLED;
	public static int GATEKEEPER_NEAR_PRICE;
	public static int GATEKEEPER_FAR_PRICE;
	public static int GATEKEEPER_CAP_PRICE;
	public static double GATEKEEPER_REF_DISTANCE;
	public static double GATEKEEPER_DISTANCE_CURVE;
	public static boolean GATEKEEPER_LEVEL_PRICE_ENABLED;
	public static int GATEKEEPER_LEVEL_PRICE_FROM;
	public static int GATEKEEPER_LEVEL_PRICE_TO;
	public static double GATEKEEPER_LEVEL_PRICE_MIN_RATE;
	public static boolean GATEKEEPER_KARMA_PRICE_ENABLED;
	public static int GATEKEEPER_KARMA_PRICE_CAP;
	public static double GATEKEEPER_KARMA_PRICE_RATE;
	public static boolean GATEKEEPER_NIGHT_PRICE_ENABLED;
	public static double GATEKEEPER_NIGHT_PRICE_RATE;
	
	// --------------------------------------------------
	// GeoEngine
	// --------------------------------------------------
	
	/** Geodata */
	public static String GEODATA_PATH;
	public static GeoType GEODATA_TYPE;
	
	/** Movement */
	public static int MAX_GEOPATH_FAIL_COUNT;
	
	/** Path checking */
	public static int PART_OF_CHARACTER_HEIGHT;
	public static int MAX_OBSTACLE_HEIGHT;
	
	/** Path finding */
	public static int MOVE_WEIGHT;
	public static int MOVE_WEIGHT_DIAG;
	public static int OBSTACLE_WEIGHT;
	public static int OBSTACLE_WEIGHT_DIAG;
	public static int HEURISTIC_WEIGHT;
	public static int MAX_ITERATIONS;
	
	// --------------------------------------------------
	// HexID
	// --------------------------------------------------
	
	public static int SERVER_ID;
	public static byte[] HEX_ID;
	
	// --------------------------------------------------
	// Loginserver
	// --------------------------------------------------
	
	public static String LOGINSERVER_HOSTNAME;
	public static int LOGINSERVER_PORT;
	
	public static int LOGIN_TRY_BEFORE_BAN;
	public static int LOGIN_BLOCK_AFTER_BAN;
	public static boolean ACCEPT_NEW_GAMESERVER;
	
	public static boolean SHOW_LICENCE;
	
	public static boolean AUTO_CREATE_ACCOUNTS;
	
	public static boolean FLOOD_PROTECTION;
	public static int FAST_CONNECTION_LIMIT;
	public static int NORMAL_CONNECTION_TIME;
	public static int FAST_CONNECTION_TIME;
	public static int MAX_CONNECTION_PER_IP;
	
	// --------------------------------------------------
	// NPCs
	// --------------------------------------------------
	
	/** Spawn */
	public static double SPAWN_MULTIPLIER;
	public static String[] SPAWN_EVENTS;
	
	/** Display */
	public static boolean SHOW_NPC_LVL;
	public static boolean SHOW_NPC_CREST;
	public static boolean SHOW_SUMMON_CREST;
	public static boolean SERVER_SIDE_NPC_NAME;
	public static boolean SERVER_SIDE_NPC_TITLE;
	
	/** AI */
	public static boolean GUARD_ATTACK_AGGRO_MOB;
	public static boolean MOB_AGGRO_IN_PEACEZONE;
	public static int RANDOM_WALK_RATE;
	public static int MAX_DRIFT_RANGE;
	public static int DEFAULT_SEE_RANGE;
	
	/** Misc */
	public static boolean FREE_TELEPORT;

	// --------------------------------------------------
	// NPCs - monster nameplates
	// --------------------------------------------------

	/** The two line plate every kind of monster wears above its head - the words its title is made of, the colors both lines are painted with, and the way the level and the aggression are written. */
	public static final Map<MonsterKind, MonsterNameplate> MONSTER_NAMEPLATES = new EnumMap<>(MonsterKind.class);

	// --------------------------------------------------
	// NPCs - bosses
	// --------------------------------------------------
	
	/** Raid Boss */
	public static double RAID_HP_REGEN_MULTIPLIER;
	public static double RAID_MP_REGEN_MULTIPLIER;
	public static double RAID_DEFENCE_MULTIPLIER;
	public static boolean RAID_DISABLE_CURSE;
	
	/** Grand Boss */
	public static int WAIT_TIME_ANTHARAS;
	public static int WAIT_TIME_VALAKAS;
	public static int WAIT_TIME_FRINTEZZA;
	
	// --------------------------------------------------
	// NPCs - managers
	// --------------------------------------------------
	
	/** Class Master */
	public static boolean ALLOW_ENTIRE_TREE;
	public static ClassMasterSettings CLASS_MASTER_SETTINGS;
	
	/** Wedding Manager */
	public static int WEDDING_PRICE;
	public static boolean WEDDING_SAMESEX;
	public static boolean WEDDING_FORMALWEAR;
	
	/** Scheme Buffer */
	public static int BUFFER_MAX_SCHEMES;
	public static int BUFFER_STATIC_BUFF_COST;
	
	/** Wyvern Manager */
	public static int WYVERN_REQUIRED_LEVEL;
	public static int WYVERN_REQUIRED_CRYSTALS;
	
	// --------------------------------------------------
	// Players - character
	// --------------------------------------------------
	
	/** Stats */
	public static boolean EFFECT_CANCELING;
	public static double HP_REGEN_MULTIPLIER;
	public static double MP_REGEN_MULTIPLIER;
	public static double CP_REGEN_MULTIPLIER;
	public static int PLAYER_SPAWN_PROTECTION;
	public static int PLAYER_FAKEDEATH_UP_PROTECTION;
	public static double RESPAWN_RESTORE_HP;
	
	/** Death */
	public static boolean ALLOW_DELEVEL;
	public static int DEATH_PENALTY_CHANCE;
	
	/** Private stores */
	public static int MAX_PVTSTORE_SLOTS_DWARF;
	public static int MAX_PVTSTORE_SLOTS_OTHER;
	
	/** Deep blue drop rules */
	public static boolean DEEPBLUE_DROP_RULES;
	
	/** Party */
	public static String PARTY_XP_CUTOFF_METHOD;
	public static int PARTY_XP_CUTOFF_LEVEL;
	public static double PARTY_XP_CUTOFF_PERCENT;
	public static int PARTY_RANGE;
	
	// --------------------------------------------------
	// Players - inventory
	// --------------------------------------------------
	
	/** Inventory */
	public static int INVENTORY_MAXIMUM_NO_DWARF;
	public static int INVENTORY_MAXIMUM_DWARF;
	public static int INVENTORY_MAXIMUM_PET;
	public static int MAX_ITEM_IN_PACKET;
	public static double WEIGHT_LIMIT;
	
	/** Warehouse */
	public static boolean ALLOW_WAREHOUSE;
	public static int WAREHOUSE_SLOTS_NO_DWARF;
	public static int WAREHOUSE_SLOTS_DWARF;
	public static int WAREHOUSE_SLOTS_CLAN;
	
	/** Freight */
	public static boolean ALLOW_FREIGHT;
	public static int FREIGHT_SLOTS;
	public static boolean REGION_BASED_FREIGHT;
	public static int FREIGHT_PRICE;
	
	// --------------------------------------------------
	// Players - enchant
	// --------------------------------------------------
	
	public static double ENCHANT_CHANCE_WEAPON_MAGIC;
	public static double ENCHANT_CHANCE_WEAPON_MAGIC_15PLUS;
	public static double ENCHANT_CHANCE_WEAPON_NONMAGIC;
	public static double ENCHANT_CHANCE_WEAPON_NONMAGIC_15PLUS;
	public static double ENCHANT_CHANCE_ARMOR;
	public static int ENCHANT_MAX_WEAPON;
	public static int ENCHANT_MAX_ARMOR;
	public static int ENCHANT_SAFE_MAX;
	public static int ENCHANT_SAFE_MAX_FULL;
	public static boolean ENCHANT_KEEP_WINDOW_OPENED;
	
	// --------------------------------------------------
	// Players - augmentation
	// --------------------------------------------------
	
	public static int AUGMENTATION_NG_SKILL_CHANCE;
	public static int AUGMENTATION_NG_GLOW_CHANCE;
	public static int AUGMENTATION_MID_SKILL_CHANCE;
	public static int AUGMENTATION_MID_GLOW_CHANCE;
	public static int AUGMENTATION_HIGH_SKILL_CHANCE;
	public static int AUGMENTATION_HIGH_GLOW_CHANCE;
	public static int AUGMENTATION_TOP_SKILL_CHANCE;
	public static int AUGMENTATION_TOP_GLOW_CHANCE;
	public static int AUGMENTATION_BASESTAT_CHANCE;
	public static boolean AUGMENTATION_VIA_LIFE_STONE;
	public static int[] AUGMENTATION_VIA_LIFE_STONE_COST_NO_GRADE;
	public static int[] AUGMENTATION_VIA_LIFE_STONE_COST_MID_GRADE;
	public static int[] AUGMENTATION_VIA_LIFE_STONE_COST_HIGH_GRADE;
	public static int[] AUGMENTATION_VIA_LIFE_STONE_COST_TOP_GRADE;
	
	// --------------------------------------------------
	// Players - karma
	// --------------------------------------------------
	
	/** Karma restrictions */
	public static boolean KARMA_PLAYER_CAN_SHOP;
	public static boolean KARMA_PLAYER_CAN_USE_GK;
	public static boolean KARMA_PLAYER_CAN_TELEPORT;
	public static boolean KARMA_PLAYER_CAN_TRADE;
	public static boolean KARMA_PLAYER_CAN_USE_WH;
	
	/** Death drops */
	public static boolean KARMA_DROP_GM;
	public static int KARMA_PK_LIMIT;
	public static int[] KARMA_NONDROPPABLE_PET_ITEMS;
	public static int[] KARMA_NONDROPPABLE_ITEMS;
	
	/** PvP flag */
	public static boolean KARMA_AWARD_PK_KILL;
	public static int PVP_NORMAL_TIME;
	public static int PVP_PVP_TIME;
	
	// --------------------------------------------------
	// Players - admin
	// --------------------------------------------------
	
	/** Access */
	public static int DEFAULT_ACCESS_LEVEL;
	
	/** GM login */
	public static boolean GM_HERO_AURA;
	public static boolean GM_STARTUP_INVULNERABLE;
	public static boolean GM_STARTUP_INVISIBLE;
	public static boolean GM_STARTUP_BLOCK_ALL;
	public static boolean GM_STARTUP_AUTO_LIST;
	
	/** Petitions */
	public static boolean PETITIONING_ALLOWED;
	public static int MAX_PETITIONS_PER_PLAYER;
	public static int MAX_PETITIONS_PENDING;
	
	// --------------------------------------------------
	// Players - skills
	// --------------------------------------------------
	
	/** Learning */
	public static boolean AUTO_LEARN_SKILLS;
	public static boolean SP_BOOK_NEEDED;
	public static boolean ES_SP_BOOK_NEEDED;
	public static boolean DIVINE_SP_BOOK_NEEDED;
	public static boolean LIFE_CRYSTAL_NEEDED;
	
	/** Casting */
	public static boolean MAGIC_FAILURES;
	public static int PERFECT_SHIELD_BLOCK_RATE;
	
	/** Subclasses */
	public static boolean SUBCLASS_WITHOUT_QUESTS;
	
	/** Crafting */
	public static boolean IS_CRAFTING_ENABLED;
	public static int DWARF_RECIPE_LIMIT;
	public static int COMMON_RECIPE_LIMIT;
	public static boolean BLACKSMITH_USE_RECIPES;
	
	/** Buffs */
	public static boolean STORE_SKILL_COOLTIME;
	public static int MAX_BUFFS_AMOUNT;
	
	// --------------------------------------------------
	// Sieges
	// --------------------------------------------------
	
	public static int SIEGE_LENGTH;
	public static int MINIMUM_CLAN_LEVEL;
	public static int MAX_ATTACKERS_NUMBER;
	public static int MAX_DEFENDERS_NUMBER;
	public static int ATTACKERS_RESPAWN_DELAY;
	
	public static int CH_MINIMUM_CLAN_LEVEL;
	public static int CH_MAX_ATTACKERS_NUMBER;
	
	// --------------------------------------------------
	// Server
	// --------------------------------------------------
	
	/** Network */
	public static String HOSTNAME;
	public static String GAMESERVER_HOSTNAME;
	public static int GAMESERVER_PORT;
	public static String GAMESERVER_LOGIN_HOSTNAME;
	public static int GAMESERVER_LOGIN_PORT;
	public static int REQUEST_ID;
	public static boolean ACCEPT_ALTERNATE_ID;
	public static boolean USE_BLOWFISH_CIPHER;
	
	/** Database */
	public static String DATABASE_URL;
	public static String DATABASE_LOGIN;
	public static String DATABASE_PASSWORD;
	
	/** Server list */
	public static boolean SERVER_LIST_BRACKET;
	public static boolean SERVER_LIST_CLOCK;
	public static int SERVER_LIST_AGE;
	public static boolean SERVER_LIST_TESTSERVER;
	public static boolean SERVER_LIST_PVPSERVER;
	public static boolean SERVER_GMONLY;
	
	/** Characters */
	public static int DELETE_DAYS;
	public static int MAXIMUM_ONLINE_USERS;
	
	// --------------------------------------------------
	// Rates
	// --------------------------------------------------
	
	/** Experience and skill points */
	public static double RATE_XP;
	public static double RATE_SP;
	public static double RATE_PARTY_XP;
	public static double RATE_PARTY_SP;
	
	/** Monster drops */
	public static double RATE_DROP_CURRENCY;
	public static double RATE_DROP_ITEMS;
	public static double RATE_DROP_ITEMS_BY_RAID;
	public static double RATE_DROP_SPOIL;
	public static double RATE_DROP_HERBS;
	public static int RATE_DROP_MANOR;
	
	/** Quests */
	public static double RATE_QUEST_DROP;
	public static double RATE_QUEST_REWARD;
	public static double RATE_QUEST_REWARD_XP;
	public static double RATE_QUEST_REWARD_SP;
	public static double RATE_QUEST_REWARD_ADENA;
	
	/** Misc */
	public static double RATE_KARMA_EXP_LOST;
	public static double RATE_SIEGE_GUARDS_PRICE;
	
	/** Player death drops */
	public static int PLAYER_DROP_LIMIT;
	public static int PLAYER_RATE_DROP;
	public static int PLAYER_RATE_DROP_ITEM;
	public static int PLAYER_RATE_DROP_EQUIP;
	public static int PLAYER_RATE_DROP_EQUIP_WEAPON;
	
	public static int KARMA_DROP_LIMIT;
	public static int KARMA_RATE_DROP;
	public static int KARMA_RATE_DROP_ITEM;
	public static int KARMA_RATE_DROP_EQUIP;
	public static int KARMA_RATE_DROP_EQUIP_WEAPON;
	
	/** Pets */
	public static double PET_XP_RATE;
	public static int PET_FOOD_RATE;
	public static double SINEATER_XP_RATE;
	
	// --------------------------------------------------
	// Items
	// --------------------------------------------------
	
	/** Auto-loot */
	public static boolean AUTO_LOOT;
	public static boolean AUTO_LOOT_HERBS;
	public static boolean AUTO_LOOT_RAID;
	
	/** Ground items */
	public static boolean ALLOW_DISCARDITEM;
	public static boolean MULTIPLE_ITEM_DROP;
	public static int HERB_AUTO_DESTROY_TIME;
	public static int ITEM_AUTO_DESTROY_TIME;
	public static int EQUIPABLE_ITEM_AUTO_DESTROY_TIME;
	public static Map<Integer, Integer> SPECIAL_ITEM_DESTROY_TIME;
	public static int PLAYER_DROPPED_ITEM_MULTIPLIER;
	
	/** Try on */
	public static boolean ALLOW_WEAR;
	public static int WEAR_DELAY;
	public static int WEAR_PRICE;
	
	// --------------------------------------------------
	// Features
	// --------------------------------------------------
	
	/** World */
	public static boolean ALLOW_WATER;
	public static boolean ALLOW_BOAT;
	public static boolean ALLOW_CURSED_WEAPONS;
	public static boolean ENABLE_FALLING_DAMAGE;
	public static int ZONE_TOWN;
	
	/** Community board */
	public static boolean ENABLE_COMMUNITY_BOARD;
	public static String BBS_DEFAULT;
	
	/** Misc */
	public static boolean SERVER_NEWS;
	
	// --------------------------------------------------
	// Development
	// --------------------------------------------------
	
	/** Debug */
	public static boolean NO_SPAWNS;
	public static boolean DEVELOPER;
	public static boolean PACKET_HANDLER_DEBUG;
	
	/** Logs */
	public static boolean LOG_CHAT;
	public static boolean LOG_ITEMS;
	public static boolean GMAUDIT;
	
	// --------------------------------------------------
	// Protection
	// --------------------------------------------------
	
	/** Third party clients */
	public static boolean L2WALKER_PROTECTION;
	
	/** Flood protectors */
	public static int ROLL_DICE_TIME;
	public static int HERO_VOICE_TIME;
	public static int SUBCLASS_TIME;
	public static int DROP_ITEM_TIME;
	public static int SERVER_BYPASS_TIME;
	public static int MULTISELL_TIME;
	public static int MANUFACTURE_TIME;
	public static int MANOR_TIME;
	public static int SENDMAIL_TIME;
	public static int CHARACTER_SELECT_TIME;
	public static int GLOBAL_CHAT_TIME;
	public static int TRADE_CHAT_TIME;
	public static int SOCIAL_TIME;
	
	// --------------------------------------------------
	// Mods - offline shop
	// --------------------------------------------------
	
	/** General */
	public static boolean OFFLINE_TRADE_ENABLE;
	public static boolean OFFLINE_CRAFT_ENABLE;
	public static boolean OFFLINE_MODE_IN_PEACE_ZONE;
	public static boolean OFFLINE_MODE_NO_DAMAGE;
	
	/** Display */
	public static boolean OFFLINE_SET_NAME_COLOR;
	public static int OFFLINE_NAME_COLOR;
	
	/** Restore */
	public static boolean RESTORE_OFFLINERS;
	public static int OFFLINE_MAX_DAYS;
	public static boolean OFFLINE_DISCONNECT_FINISHED;
	
	// --------------------------------------------------
	// Mods - custom client
	// --------------------------------------------------
	
	/** Version check */
	public static String CLIENT_VERSION;
	public static int CLIENT_VERSION_TIMEOUT;
	public static String CLIENT_VERSION_MESSAGE;
	
	/** Item name colors */
	public static boolean SEND_ITEM_NAME_COLORS;
	
	/** Item statistics */
	public static boolean SEND_ITEM_STATS;

	/** Item skills */
	public static boolean SEND_ITEM_SKILLS;
	
	// --------------------------------------------------
	// Network
	// --------------------------------------------------
	
	/** Reserve Host on LoginServerThread */
	public static boolean RESERVE_HOST_ON_LOGIN;
	
	/** MMO settings */
	public static int MMO_SELECTOR_SLEEP_TIME;
	public static int MMO_MAX_SEND_PER_PASS;
	public static int MMO_MAX_READ_PER_PASS;
	public static int MMO_HELPER_BUFFER_COUNT;
	
	/** Client Packets Queue settings */
	public static int CLIENT_PACKET_QUEUE_SIZE;
	public static int CLIENT_PACKET_QUEUE_MAX_BURST_SIZE;
	public static int CLIENT_PACKET_QUEUE_MAX_PACKETS_PER_SECOND;
	public static int CLIENT_PACKET_QUEUE_MEASURE_INTERVAL;
	public static int CLIENT_PACKET_QUEUE_MAX_AVERAGE_PACKETS_PER_SECOND;
	public static int CLIENT_PACKET_QUEUE_MAX_FLOODS_PER_MIN;
	public static int CLIENT_PACKET_QUEUE_MAX_OVERFLOWS_PER_MIN;
	public static int CLIENT_PACKET_QUEUE_MAX_UNDERFLOWS_PER_MIN;
	public static int CLIENT_PACKET_QUEUE_MAX_UNKNOWN_PER_MIN;
	
	// --------------------------------------------------
	
	/**
	 * Initialize {@link ExProperties} from specified configuration file.
	 * @param filename : File name to be loaded.
	 * @return ExProperties : Initialized {@link ExProperties}.
	 */
	public static final ExProperties initProperties(String filename)
	{
		final ExProperties result = new ExProperties();
		
		try
		{
			result.load(new File(filename));
		}
		catch (Exception e)
		{
			LOGGER.error("An error occured loading '{}' config.", e, filename);
		}
		
		return result;
	}
	
	/**
	 * Loads champion mobs settings.
	 */
	private static final void loadChampionMobs()
	{
		final ExProperties championMobs = initProperties(MODS_CHAMPION_MOBS_FILE);

		CHAMPION_MOBS.clear();

		// Both flavors are read out of the very same keys, only prefixed by their own name.
		for (ChampionType type : ChampionType.values())
		{
			final String prefix = "ChampionMobs" + type.getPrefix();

			final ChampionSettings settings = new ChampionSettings(type);

			settings.setEnabled(championMobs.getProperty(prefix + "Enable", false));
			settings.setPassive(championMobs.getProperty(prefix + "Passive", false));
			settings.setFrequency(championMobs.getProperty(prefix + "Frequency", 0));
			settings.setTitle(championMobs.getProperty(prefix + "Title", "Champion"));
			// The title takes the name's color when the config names none of its own, which is what one single color used to mean.
			final String nameColor = championMobs.getProperty(prefix + "NameColor", String.format("%06X", type.getDefaultNameColor()));
			settings.setNameColor(NpcTemplate.parseNameColor(nameColor));
			settings.setTitleColor(NpcTemplate.parseNameColor(championMobs.getProperty(prefix + "TitleColor", nameColor)));

			settings.setLevelRange(championMobs.getProperty(prefix + "MinLevel", 1), championMobs.getProperty(prefix + "MaxLevel", 85));

			settings.setStatMultipliers(championMobs.getProperty(prefix + "HpMultiplier", 1), championMobs.getProperty(prefix + "PAtkMultiplier", 1.), championMobs.getProperty(prefix + "PDefMultiplier", 1.), championMobs.getProperty(prefix + "MAtkMultiplier", 1.), championMobs.getProperty(prefix + "MDefMultiplier", 1.));
			settings.setRewardMultipliers(championMobs.getProperty(prefix + "XpMultiplier", 1.), championMobs.getProperty(prefix + "SpMultiplier", 1.), championMobs.getProperty(prefix + "AdenaMultiplier", 1.), Math.max(0., championMobs.getProperty(prefix + "DropMultiplier", 2.)), Math.max(0., championMobs.getProperty(prefix + "SpoilMultiplier", 2.)));

			settings.setDrops(ChampionSettings.parseDrops(prefix + "Drop", championMobs.getProperty(prefix + "Drop", "")));
			settings.setSchedule(championMobs.getProperty(prefix + "Schedule", ""));

			CHAMPION_MOBS.put(type, settings);
		}
	}
	
	/**
	 * Loads clan and clan hall settings.
	 */
	private static final void loadClans()
	{
		final ExProperties clans = initProperties(CLANS_FILE);
		
		CLAN_JOIN_DAYS = clans.getProperty("DaysBeforeJoinAClan", 5);
		CLAN_CREATE_DAYS = clans.getProperty("DaysBeforeCreateAClan", 10);
		MAX_NUM_OF_CLANS_IN_ALLY = clans.getProperty("MaxNumOfClansInAlly", 3);
		CLAN_MEMBERS_FOR_WAR = clans.getProperty("ClanMembersForWar", 15);
		CLAN_WAR_PENALTY_WHEN_ENDED = clans.getProperty("ClanWarPenaltyWhenEnded", 5);
		CLAN_DISSOLVE_DAYS = clans.getProperty("DaysToPassToDissolveAClan", 7);
		ALLY_JOIN_DAYS_WHEN_LEAVED = clans.getProperty("DaysBeforeJoinAllyWhenLeaved", 1);
		ALLY_JOIN_DAYS_WHEN_DISMISSED = clans.getProperty("DaysBeforeJoinAllyWhenDismissed", 1);
		ACCEPT_CLAN_DAYS_WHEN_DISMISSED = clans.getProperty("DaysBeforeAcceptNewClanWhenDismissed", 1);
		CREATE_ALLY_DAYS_WHEN_DISSOLVED = clans.getProperty("DaysBeforeCreateNewAllyWhenDissolved", 10);
		MEMBERS_CAN_WITHDRAW_FROM_CLANWH = clans.getProperty("MembersCanWithdrawFromClanWH", false);
		
		ALLOW_MANOR = clans.getProperty("AllowManor", true);
		MANOR_REFRESH_TIME = clans.getProperty("ManorRefreshTime", 20);
		MANOR_REFRESH_MIN = clans.getProperty("ManorRefreshMin", 0);
		MANOR_APPROVE_TIME = clans.getProperty("ManorApproveTime", 6);
		MANOR_APPROVE_MIN = clans.getProperty("ManorApproveMin", 0);
		MANOR_MAINTENANCE_MIN = clans.getProperty("ManorMaintenanceMin", 6);
		MANOR_SAVE_PERIOD_RATE = clans.getProperty("ManorSavePeriodRate", 2) * 3600000;
	}
	
	/**
	 * Loads olympiad settings.
	 */
	private static final void loadOlympiad()
	{
		final ExProperties olympiad = initProperties(EVENTS_OLYMPIAD_FILE);
		
		OLY_START_TIME = olympiad.getProperty("OlyStartTime", 18);
		OLY_MIN = olympiad.getProperty("OlyMin", 0);
		OLY_CPERIOD = olympiad.getProperty("OlyCPeriod", 21600000L);
		OLY_BATTLE = olympiad.getProperty("OlyBattle", 180000L);
		OLY_WAIT_TIME = olympiad.getProperty("OlyWaitTime", 30);
		OLY_WAIT_BATTLE = olympiad.getProperty("OlyWaitBattle", 60);
		OLY_WAIT_END = olympiad.getProperty("OlyWaitEnd", 40);
		OLY_START_POINTS = olympiad.getProperty("OlyStartPoints", 18);
		OLY_WEEKLY_POINTS = olympiad.getProperty("OlyWeeklyPoints", 3);
		OLY_MIN_MATCHES = olympiad.getProperty("OlyMinMatchesToBeClassed", 5);
		OLY_CLASSED = olympiad.getProperty("OlyClassedParticipants", 5);
		OLY_NONCLASSED = olympiad.getProperty("OlyNonClassedParticipants", 9);
		OLY_CLASSED_REWARD = olympiad.parseIntIntList("OlyClassedReward", "6651-50");
		OLY_NONCLASSED_REWARD = olympiad.parseIntIntList("OlyNonClassedReward", "6651-30");
		OLY_GP_PER_POINT = olympiad.getProperty("OlyGPPerPoint", 1000);
		OLY_HERO_POINTS = olympiad.getProperty("OlyHeroPoints", 300);
		OLY_MAX_POINTS = olympiad.getProperty("OlyMaxPoints", 10);
		OLY_DIVIDER_CLASSED = olympiad.getProperty("OlyDividerClassed", 3);
		OLY_DIVIDER_NON_CLASSED = olympiad.getProperty("OlyDividerNonClassed", 5);
		OLY_ANNOUNCE_GAMES = olympiad.getProperty("OlyAnnounceGames", true);
	}
	
	/**
	 * Loads seven signs and festival settings.
	 */
	private static final void loadSevenSigns()
	{
		final ExProperties sevenSigns = initProperties(EVENTS_SEVEN_SIGNS_FILE);
		
		SEVEN_SIGNS_BYPASS_PREREQUISITES = sevenSigns.getProperty("SevenSignsBypassPrerequisites", false);
		FESTIVAL_MIN_PLAYER = Math.clamp(sevenSigns.getProperty("FestivalMinPlayer", 5), 2, 9);
		MAXIMUM_PLAYER_CONTRIB = sevenSigns.getProperty("MaxPlayerContrib", 1000000);
		FESTIVAL_MANAGER_START = sevenSigns.getProperty("FestivalManagerStart", 120000L);
		FESTIVAL_LENGTH = sevenSigns.getProperty("FestivalLength", 1080000L);
		FESTIVAL_CYCLE_LENGTH = sevenSigns.getProperty("FestivalCycleLength", 2280000L);
		FESTIVAL_FIRST_SPAWN = sevenSigns.getProperty("FestivalFirstSpawn", 120000L);
		FESTIVAL_FIRST_SWARM = sevenSigns.getProperty("FestivalFirstSwarm", 300000L);
		FESTIVAL_SECOND_SPAWN = sevenSigns.getProperty("FestivalSecondSpawn", 540000L);
		FESTIVAL_SECOND_SWARM = sevenSigns.getProperty("FestivalSecondSwarm", 720000L);
		FESTIVAL_CHEST_SPAWN = sevenSigns.getProperty("FestivalChestSpawn", 900000L);
	}
	
	/**
	 * Loads instances settings.<br>
	 * Such as four sepulchers and dimensional rift.
	 */
	private static final void loadInstances()
	{
		final ExProperties instances = initProperties(EVENTS_INSTANCES_FILE);
		
		FS_PARTY_MEMBER_COUNT = Math.clamp(instances.getProperty("NeededPartyMembers", 4), 2, 9);
		
		RIFT_MIN_PARTY_SIZE = instances.getProperty("RiftMinPartySize", 2);
		RIFT_AUTO_JUMPS_TIME_MIN = instances.getProperty("AutoJumpsDelayMin", 8);
		RIFT_AUTO_JUMPS_TIME_RND = instances.getProperty("AutoJumpsDelayRnd", 5);
		RIFT_ENTER_COST_RECRUIT = instances.getProperty("RecruitCost", 21);
		RIFT_ENTER_COST_SOLDIER = instances.getProperty("SoldierCost", 24);
		RIFT_ENTER_COST_OFFICER = instances.getProperty("OfficerCost", 27);
		RIFT_ENTER_COST_CAPTAIN = instances.getProperty("CaptainCost", 30);
		RIFT_ENTER_COST_COMMANDER = instances.getProperty("CommanderCost", 33);
		RIFT_ENTER_COST_HERO = instances.getProperty("HeroCost", 36);
		RIFT_ANAKAZEL_PORT_CHANCE = instances.getProperty("AnakazelPortChance", 15);
	}
	
	/**
	 * Loads minigames settings.<br>
	 * Such as lottery and fishing championship.
	 */
	private static final void loadMinigames()
	{
		final ExProperties minigames = initProperties(EVENTS_MINIGAMES_FILE);
		
		ALLOW_LOTTERY = minigames.getProperty("AllowLottery", true);
		LOTTERY_PRIZE = minigames.getProperty("LotteryPrize", 50000);
		LOTTERY_TICKET_PRICE = minigames.getProperty("LotteryTicketPrice", 2000);
		LOTTERY_5_NUMBER_RATE = minigames.getProperty("Lottery5NumberRate", 0.6);
		LOTTERY_4_NUMBER_RATE = minigames.getProperty("Lottery4NumberRate", 0.2);
		LOTTERY_3_NUMBER_RATE = minigames.getProperty("Lottery3NumberRate", 0.2);
		LOTTERY_2_AND_1_NUMBER_PRIZE = minigames.getProperty("Lottery2and1NumberPrize", 200);
		
		ALLOW_FISH_CHAMPIONSHIP = minigames.getProperty("AllowFishChampionship", true);
		FISH_CHAMPIONSHIP_REWARD_ITEM = minigames.getProperty("FishChampionshipRewardItemId", 57);
		FISH_CHAMPIONSHIP_REWARD_1 = minigames.getProperty("FishChampionshipReward1", 800000);
		FISH_CHAMPIONSHIP_REWARD_2 = minigames.getProperty("FishChampionshipReward2", 500000);
		FISH_CHAMPIONSHIP_REWARD_3 = minigames.getProperty("FishChampionshipReward3", 300000);
		FISH_CHAMPIONSHIP_REWARD_4 = minigames.getProperty("FishChampionshipReward4", 200000);
		FISH_CHAMPIONSHIP_REWARD_5 = minigames.getProperty("FishChampionshipReward5", 100000);
	}
	
	/**
	 * Loads the drop list window settings.<br>
	 * <br>
	 * Only the behavior lives here ; the whole appearance is datapack driven, on data/xml/droplist.xml.
	 */
	private static final void loadDropList()
	{
		final ExProperties droplist = initProperties(MODS_DROPLIST_FILE);

		DROPLIST_ENABLED = droplist.getProperty("DropListEnabled", true);
		DROPLIST_SKILL_ID = Math.max(0, droplist.getProperty("DropListSkillId", 0));
		DROPLIST_ROWS_PER_PAGE = Math.max(1, droplist.getProperty("DropListRowsPerPage", 9));
		DROPLIST_SHOW_SPOIL = droplist.getProperty("DropListShowSpoil", true);
		DROPLIST_SHOW_HEADER = droplist.getProperty("DropListShowHeader", true);
		DROPLIST_APPLY_RATES = droplist.getProperty("DropListApplyRates", true);
		DROPLIST_APPLY_LEVEL_PENALTY = droplist.getProperty("DropListApplyLevelPenalty", true);
	}

	/**
	 * Loads the raid boss book settings.<br>
	 * <br>
	 * Only the behavior lives here ; the whole appearance, the level ranges of the filter menu included, is datapack driven, on data/xml/raidbook.xml.
	 */
	private static final void loadRaidBook()
	{
		final ExProperties raidbook = initProperties(MODS_RAIDBOOK_FILE);

		RAIDBOOK_ENABLED = raidbook.getProperty("RaidBookEnabled", true);
		RAIDBOOK_ITEM_ID = Math.max(0, raidbook.getProperty("RaidBookItemId", 9300));
		RAIDBOOK_ROWS_PER_PAGE = Math.max(1, raidbook.getProperty("RaidBookRowsPerPage", 8));
		RAIDBOOK_TAB_ROWS_PER_PAGE = Math.max(1, raidbook.getProperty("RaidBookTabRowsPerPage", 4));

		// A single kill per level would make the very first level - which is reached on the first kill - as long as any other one, and leave the progress bar of a fresh level already full.
		RAIDBOOK_KILLS_PER_LEVEL = Math.max(2, raidbook.getProperty("RaidBookKillsPerLevel", 5));
		RAIDBOOK_MAX_LEVEL = Math.max(0, raidbook.getProperty("RaidBookMaxLevel", 0));

		RAIDBOOK_DAMAGE_PER_LEVEL = Math.max(0, raidbook.getProperty("RaidBookDamagePerLevel", 1.));
		RAIDBOOK_MAX_DAMAGE_BONUS = Math.max(0, raidbook.getProperty("RaidBookMaxDamageBonus", 0.));

		RAIDBOOK_POINTS_PER_KILL = Math.max(0, raidbook.getProperty("RaidBookPointsPerKill", 10));
		RAIDBOOK_POINTS_PER_BOSS_LEVEL = Math.max(0, raidbook.getProperty("RaidBookPointsPerBossLevel", 1.));

		RAIDBOOK_SCREEN_MESSAGES = raidbook.getProperty("RaidBookScreenMessages", true);
		RAIDBOOK_HISTORY_SIZE = Math.max(1, raidbook.getProperty("RaidBookHistorySize", 20));
		RAIDBOOK_RANKING_SIZE = Math.max(1, raidbook.getProperty("RaidBookRankingSize", 100));
		RAIDBOOK_SHOWN_REWARDS = Math.max(1, raidbook.getProperty("RaidBookShownRewards", 5));

		RAIDBOOK_APPLY_RATES = raidbook.getProperty("RaidBookApplyRates", true);
		RAIDBOOK_APPLY_LEVEL_PENALTY = raidbook.getProperty("RaidBookApplyLevelPenalty", true);

		RAIDBOOK_DEFAULT_REWARD = parseRewardItems(raidbook.getProperty("RaidBookDefaultReward", ""));
		RAIDBOOK_LEVEL_REWARDS = parseRewardMap(raidbook.getProperty("RaidBookLevelRewards", ""));

		RAIDBOOK_DAILY_ENABLED = raidbook.getProperty("RaidBookDailyRewardEnabled", true);
		RAIDBOOK_DAILY_REWARDS = parseRewardMap(raidbook.getProperty("RaidBookDailyRewards", ""));
	}

	/**
	 * @param value : A "key:itemId,count[,itemId,count...];key:..." list, the key being a hunting level or a ranking position.
	 * @return The parsed entries, an empty {@link Map} when the value is blank.
	 */
	private static final Map<Integer, List<IntIntHolder>> parseRewardMap(String value)
	{
		final Map<Integer, List<IntIntHolder>> entries = new HashMap<>();

		if (value == null)
			return entries;

		for (String entry : value.split(";"))
		{
			if (entry.isBlank())
				continue;

			final String[] parts = entry.split(":", 2);
			if (parts.length != 2)
			{
				LOGGER.warn("The raid book reward '{}' isn't written as 'key:itemId,count' ; it is dropped.", entry);
				continue;
			}

			try
			{
				final int key = Integer.parseInt(parts[0].trim());
				final List<IntIntHolder> items = parseRewardItems(parts[1]);

				if (key > 0 && !items.isEmpty())
					entries.put(key, items);
			}
			catch (NumberFormatException e)
			{
				LOGGER.warn("The raid book reward '{}' holds a key which isn't a number ; it is dropped.", entry);
			}
		}

		return entries;
	}

	/**
	 * @param value : A flat "itemId,count[,itemId,count...]" list.
	 * @return The parsed items, an empty {@link List} when the value is blank or malformed.
	 */
	private static final List<IntIntHolder> parseRewardItems(String value)
	{
		final List<IntIntHolder> items = new ArrayList<>();

		if (value == null || value.isBlank())
			return items;

		final String[] tokens = value.trim().split(",");
		if (tokens.length % 2 != 0)
		{
			LOGGER.warn("The raid book reward '{}' doesn't hold a count for every item ; it is dropped.", value);
			return items;
		}

		try
		{
			for (int i = 0; i < tokens.length; i += 2)
			{
				final int itemId = Integer.parseInt(tokens[i].trim());
				final int count = Integer.parseInt(tokens[i + 1].trim());

				if (itemId > 0 && count > 0)
					items.add(new IntIntHolder(itemId, count));
			}
		}
		catch (NumberFormatException e)
		{
			LOGGER.warn("The raid book reward '{}' holds something which isn't a number ; it is dropped.", value);
			items.clear();
		}

		return items;
	}

	/**
	 * Loads global gatekeeper settings.<br>
	 * <br>
	 * Only the behavior and the economy live here ; the content and the whole appearance are datapack driven, on data/xml/gatekeeper.xml.
	 */
	private static final void loadGatekeeper()
	{
		final ExProperties gatekeeper = initProperties(MODS_GATEKEEPER_FILE);
		
		GATEKEEPER_ROWS_PER_PAGE = Math.max(1, gatekeeper.getProperty("RowsPerPage", 12));
		GATEKEEPER_POPULAR_LIMIT = Math.max(1, gatekeeper.getProperty("PopularLimit", 20));
		GATEKEEPER_POPULAR_MIN_COUNT = Math.max(1, gatekeeper.getProperty("PopularMinCount", 1));
		GATEKEEPER_TELEPORT_DELAY = Math.min(60000, Math.max(0, gatekeeper.getProperty("TeleportDelay", 5000)));
		
		GATEKEEPER_DEFAULT_PRICE_ID = gatekeeper.getProperty("DefaultPriceId", 57);
		GATEKEEPER_DEFAULT_PRICE = Math.max(-1, gatekeeper.getProperty("DefaultPrice", -1));
		GATEKEEPER_DEFAULT_NOBLE_PRICE = Math.max(-1, gatekeeper.getProperty("DefaultNoblePrice", -1));
		
		GATEKEEPER_PRICING_ENABLED = gatekeeper.getProperty("PricingEnabled", true);
		GATEKEEPER_PRICE_ROUNDING = Math.max(1, gatekeeper.getProperty("PriceRounding", 100));
		
		GATEKEEPER_DISTANCE_PRICE_ENABLED = gatekeeper.getProperty("DistancePriceEnabled", true);
		GATEKEEPER_NEAR_PRICE = Math.max(0, gatekeeper.getProperty("NearPrice", 15000));
		GATEKEEPER_FAR_PRICE = Math.max(GATEKEEPER_NEAR_PRICE, gatekeeper.getProperty("FarPrice", 100000));
		GATEKEEPER_REF_DISTANCE = Math.max(1, gatekeeper.getProperty("RefDistance", 240000.));
		GATEKEEPER_DISTANCE_CURVE = Math.max(0.1, gatekeeper.getProperty("DistanceCurve", 1.35));
		GATEKEEPER_CAP_PRICE = Math.max(0, gatekeeper.getProperty("CapPrice", 200000));
		
		GATEKEEPER_LEVEL_PRICE_ENABLED = gatekeeper.getProperty("LevelPriceEnabled", true);
		GATEKEEPER_LEVEL_PRICE_FROM = Math.max(1, gatekeeper.getProperty("LevelPriceFrom", 1));
		GATEKEEPER_LEVEL_PRICE_TO = Math.max(GATEKEEPER_LEVEL_PRICE_FROM, gatekeeper.getProperty("LevelPriceTo", 80));
		GATEKEEPER_LEVEL_PRICE_MIN_RATE = Math.min(1, Math.max(0, gatekeeper.getProperty("LevelPriceMinRate", 0.4)));
		
		GATEKEEPER_KARMA_PRICE_ENABLED = gatekeeper.getProperty("KarmaPriceEnabled", true);
		GATEKEEPER_KARMA_PRICE_CAP = Math.max(1, gatekeeper.getProperty("KarmaPriceCap", 10000));
		GATEKEEPER_KARMA_PRICE_RATE = Math.max(0, gatekeeper.getProperty("KarmaPriceRate", 1.));
		
		GATEKEEPER_NIGHT_PRICE_ENABLED = gatekeeper.getProperty("NightPriceEnabled", true);
		GATEKEEPER_NIGHT_PRICE_RATE = Math.max(0, gatekeeper.getProperty("NightPriceRate", 1.25));
	}
	
	/**
	 * Loads geoengine settings.
	 */
	private static final void loadGeoengine()
	{
		final ExProperties geoengine = initProperties(GEOENGINE_FILE);
		
		GEODATA_PATH = geoengine.getProperty("GeoDataPath", "./data/geodata/");
		GEODATA_TYPE = Enum.valueOf(GeoType.class, geoengine.getProperty("GeoDataType", "L2OFF"));
		
		MAX_GEOPATH_FAIL_COUNT = Math.max(15, geoengine.getProperty("MaxGeopathFailCount", 50));
		
		PART_OF_CHARACTER_HEIGHT = geoengine.getProperty("PartOfCharacterHeight", 75);
		MAX_OBSTACLE_HEIGHT = geoengine.getProperty("MaxObstacleHeight", 32);
		
		MOVE_WEIGHT = geoengine.getProperty("MoveWeight", 10);
		MOVE_WEIGHT_DIAG = geoengine.getProperty("MoveWeightDiag", 14);
		OBSTACLE_WEIGHT = geoengine.getProperty("ObstacleWeight", 30);
		OBSTACLE_WEIGHT_DIAG = (int) (OBSTACLE_WEIGHT * Math.sqrt(2));
		HEURISTIC_WEIGHT = geoengine.getProperty("HeuristicWeight", 12);
		MAX_ITERATIONS = geoengine.getProperty("MaxIterations", 10000);
	}
	
	/**
	 * Loads hex ID settings.
	 */
	private static final void loadHexID()
	{
		final ExProperties hexid = initProperties(HEXID_FILE);
		
		SERVER_ID = Integer.parseInt(hexid.getProperty("ServerID"));
		HEX_ID = new BigInteger(hexid.getProperty("HexID"), 16).toByteArray();
	}
	
	/**
	 * Saves hex ID file.
	 * @param serverId : The ID of server.
	 * @param hexId : The hex ID of server.
	 */
	public static final void saveHexid(int serverId, String hexId)
	{
		saveHexid(serverId, hexId, HEXID_FILE);
	}
	
	/**
	 * Saves hexID file.
	 * @param serverId : The ID of server.
	 * @param hexId : The hexID of server.
	 * @param filename : The file name.
	 */
	public static final void saveHexid(int serverId, String hexId, String filename)
	{
		try
		{
			final File file = new File(filename);
			file.createNewFile();
			
			final Properties hexSetting = new Properties();
			hexSetting.setProperty("ServerID", String.valueOf(serverId));
			hexSetting.setProperty("HexID", hexId);
			
			try (OutputStream out = new FileOutputStream(file))
			{
				hexSetting.store(out, "the hexID to auth into login");
			}
		}
		catch (Exception e)
		{
			LOGGER.error("Failed to save hex ID to '{}' file.", e, filename);
		}
	}
	
	/**
	 * Loads NPC settings.<br>
	 * Such as spawn manager, NPC display and monsters AI.
	 */
	private static final void loadNpcs()
	{
		final ExProperties npcs = initProperties(NPCS_FILE);
		
		SPAWN_MULTIPLIER = npcs.getProperty("SpawnMultiplier", 1.);
		SPAWN_EVENTS = npcs.getProperty("SpawnEvents", new String[]
		{
			"extra_mob",
			"18age",
			"start_weapon",
		});
		
		SHOW_NPC_LVL = npcs.getProperty("ShowNpcLevel", false);
		SHOW_NPC_CREST = npcs.getProperty("ShowNpcCrest", false);
		SHOW_SUMMON_CREST = npcs.getProperty("ShowSummonCrest", false);
		SERVER_SIDE_NPC_NAME = npcs.getProperty("ServerSideNpcName", false);
		SERVER_SIDE_NPC_TITLE = npcs.getProperty("ServerSideNpcTitle", false);
		
		GUARD_ATTACK_AGGRO_MOB = npcs.getProperty("GuardAttackAggroMob", false);
		MOB_AGGRO_IN_PEACEZONE = npcs.getProperty("MobAggroInPeaceZone", true);
		RANDOM_WALK_RATE = npcs.getProperty("RandomWalkRate", 30);
		MAX_DRIFT_RANGE = npcs.getProperty("MaxDriftRange", 200);
		DEFAULT_SEE_RANGE = npcs.getProperty("DefaultSeeRange", 450);
		
		FREE_TELEPORT = npcs.getProperty("FreeTeleport", false);
	}

	/**
	 * Loads the plates monsters wear above their head.<br>
	 * The words naming every kind of monster, and the colors that kind's two lines are painted with.
	 */
	private static final void loadNameplates()
	{
		final ExProperties nameplates = initProperties(NPCS_NAMEPLATES_FILE);

		// Both are shared by every kind : a title is "<text> <level label> <level><aggressive mark>".
		final String levelLabel = nameplates.getProperty("MonsterLevelLabel", "Lvl");
		final String aggressiveMark = nameplates.getProperty("MonsterAggressiveMark", "*");

		MONSTER_NAMEPLATES.clear();

		for (MonsterKind kind : MonsterKind.values())
		{
			final String prefix = "Monster" + kind.getPrefix();

			final String text = nameplates.getProperty(prefix + "Text", kind.getDefaultText());

			// The title takes the name's color when the config names none of its own, so a kind written the way the one color of the older protocol was still paints both lines alike.
			final String nameColor = nameplates.getProperty(prefix + "NameColor", (kind.getDefaultNameColor() == NpcTemplate.NO_NAME_COLOR) ? "" : String.format("%06X", kind.getDefaultNameColor()));
			final String titleColor = nameplates.getProperty(prefix + "TitleColor", nameColor);

			MONSTER_NAMEPLATES.put(kind, new MonsterNameplate(text, NpcTemplate.parseNameColor(nameColor), NpcTemplate.parseNameColor(titleColor), levelLabel, aggressiveMark));
		}
	}

	/**
	 * Loads raid bosses and grand bosses settings.
	 */
	private static final void loadBosses()
	{
		final ExProperties bosses = initProperties(NPCS_BOSSES_FILE);
		
		RAID_HP_REGEN_MULTIPLIER = bosses.getProperty("RaidHpRegenMultiplier", 1.);
		RAID_MP_REGEN_MULTIPLIER = bosses.getProperty("RaidMpRegenMultiplier", 1.);
		RAID_DEFENCE_MULTIPLIER = bosses.getProperty("RaidDefenceMultiplier", 1.);
		RAID_DISABLE_CURSE = bosses.getProperty("DisableRaidCurse", false);
		
		WAIT_TIME_ANTHARAS = bosses.getProperty("AntharasWaitTime", 30) * 60000;
		WAIT_TIME_VALAKAS = bosses.getProperty("ValakasWaitTime", 20) * 60000;
		WAIT_TIME_FRINTEZZA = bosses.getProperty("FrintezzaWaitTime", 10) * 60000;
	}
	
	/**
	 * Loads NPC managers settings.<br>
	 * Such as class master, wedding manager, scheme buffer and wyvern manager.
	 */
	private static final void loadNpcManagers()
	{
		final ExProperties managers = initProperties(NPCS_MANAGERS_FILE);
		
		ALLOW_ENTIRE_TREE = managers.getProperty("AllowEntireTree", false);
		CLASS_MASTER_SETTINGS = new ClassMasterSettings(managers.getProperty("ConfigClassMaster"));
		
		WEDDING_PRICE = managers.getProperty("WeddingPrice", 1000000);
		WEDDING_SAMESEX = managers.getProperty("WeddingAllowSameSex", false);
		WEDDING_FORMALWEAR = managers.getProperty("WeddingFormalWear", true);
		
		BUFFER_MAX_SCHEMES = managers.getProperty("BufferMaxSchemesPerChar", 4);
		BUFFER_STATIC_BUFF_COST = managers.getProperty("BufferStaticCostPerBuff", -1);
		
		WYVERN_REQUIRED_LEVEL = managers.getProperty("RequiredStriderLevel", 55);
		WYVERN_REQUIRED_CRYSTALS = managers.getProperty("RequiredCrystalsNumber", 10);
	}
	
	/**
	 * Loads character settings.<br>
	 * Such as stats, protections, death penalties, private stores and party.
	 */
	private static final void loadCharacter()
	{
		final ExProperties character = initProperties(PLAYERS_CHARACTER_FILE);
		
		EFFECT_CANCELING = character.getProperty("CancelLesserEffect", true);
		HP_REGEN_MULTIPLIER = character.getProperty("HpRegenMultiplier", 1.);
		MP_REGEN_MULTIPLIER = character.getProperty("MpRegenMultiplier", 1.);
		CP_REGEN_MULTIPLIER = character.getProperty("CpRegenMultiplier", 1.);
		RESPAWN_RESTORE_HP = character.getProperty("RespawnRestoreHP", 0.7);
		
		PLAYER_SPAWN_PROTECTION = character.getProperty("PlayerSpawnProtection", 0);
		PLAYER_FAKEDEATH_UP_PROTECTION = character.getProperty("PlayerFakeDeathUpProtection", 5);
		
		ALLOW_DELEVEL = character.getProperty("AllowDelevel", true);
		DEATH_PENALTY_CHANCE = character.getProperty("DeathPenaltyChance", 20);
		
		MAX_PVTSTORE_SLOTS_DWARF = character.getProperty("MaxPvtStoreSlotsDwarf", 5);
		MAX_PVTSTORE_SLOTS_OTHER = character.getProperty("MaxPvtStoreSlotsOther", 4);
		
		DEEPBLUE_DROP_RULES = character.getProperty("UseDeepBlueDropRules", true);
		
		PARTY_XP_CUTOFF_METHOD = character.getProperty("PartyXpCutoffMethod", "level");
		PARTY_XP_CUTOFF_PERCENT = character.getProperty("PartyXpCutoffPercent", 3.);
		PARTY_XP_CUTOFF_LEVEL = character.getProperty("PartyXpCutoffLevel", 20);
		PARTY_RANGE = character.getProperty("PartyRange", 1500);
	}
	
	/**
	 * Loads inventory, warehouse and freight settings.
	 */
	private static final void loadInventory()
	{
		final ExProperties inventory = initProperties(PLAYERS_INVENTORY_FILE);
		
		INVENTORY_MAXIMUM_NO_DWARF = inventory.getProperty("MaximumSlotsForNoDwarf", 80);
		INVENTORY_MAXIMUM_DWARF = inventory.getProperty("MaximumSlotsForDwarf", 100);
		INVENTORY_MAXIMUM_PET = inventory.getProperty("MaximumSlotsForPet", 12);
		MAX_ITEM_IN_PACKET = Math.max(INVENTORY_MAXIMUM_NO_DWARF, INVENTORY_MAXIMUM_DWARF);
		WEIGHT_LIMIT = inventory.getProperty("WeightLimit", 1.);
		
		ALLOW_WAREHOUSE = inventory.getProperty("AllowWarehouse", true);
		WAREHOUSE_SLOTS_NO_DWARF = inventory.getProperty("MaximumWarehouseSlotsForNoDwarf", 100);
		WAREHOUSE_SLOTS_DWARF = inventory.getProperty("MaximumWarehouseSlotsForDwarf", 120);
		WAREHOUSE_SLOTS_CLAN = inventory.getProperty("MaximumWarehouseSlotsForClan", 150);
		
		ALLOW_FREIGHT = inventory.getProperty("AllowFreight", true);
		FREIGHT_SLOTS = inventory.getProperty("MaximumFreightSlots", 20);
		REGION_BASED_FREIGHT = inventory.getProperty("RegionBasedFreight", true);
		FREIGHT_PRICE = inventory.getProperty("FreightPrice", 1000);
	}
	
	/**
	 * Loads enchant settings.
	 */
	private static final void loadEnchant()
	{
		final ExProperties enchant = initProperties(PLAYERS_ENCHANT_FILE);
		
		ENCHANT_CHANCE_WEAPON_MAGIC = enchant.getProperty("EnchantChanceMagicWeapon", 0.4);
		ENCHANT_CHANCE_WEAPON_MAGIC_15PLUS = enchant.getProperty("EnchantChanceMagicWeapon15Plus", 0.2);
		ENCHANT_CHANCE_WEAPON_NONMAGIC = enchant.getProperty("EnchantChanceNonMagicWeapon", 0.7);
		ENCHANT_CHANCE_WEAPON_NONMAGIC_15PLUS = enchant.getProperty("EnchantChanceNonMagicWeapon15Plus", 0.35);
		ENCHANT_CHANCE_ARMOR = enchant.getProperty("EnchantChanceArmor", 0.66);
		ENCHANT_MAX_WEAPON = enchant.getProperty("EnchantMaxWeapon", 0);
		ENCHANT_MAX_ARMOR = enchant.getProperty("EnchantMaxArmor", 0);
		ENCHANT_SAFE_MAX = enchant.getProperty("EnchantSafeMax", 3);
		ENCHANT_SAFE_MAX_FULL = enchant.getProperty("EnchantSafeMaxFull", 4);
		ENCHANT_KEEP_WINDOW_OPENED = enchant.getProperty("EnchantKeepWindowOpened", false);
	}
	
	/**
	 * Loads augmentation settings.
	 */
	private static final void loadAugmentation()
	{
		final ExProperties augmentation = initProperties(PLAYERS_AUGMENTATION_FILE);
		
		AUGMENTATION_NG_SKILL_CHANCE = augmentation.getProperty("AugmentationNGSkillChance", 15);
		AUGMENTATION_NG_GLOW_CHANCE = augmentation.getProperty("AugmentationNGGlowChance", 0);
		AUGMENTATION_MID_SKILL_CHANCE = augmentation.getProperty("AugmentationMidSkillChance", 30);
		AUGMENTATION_MID_GLOW_CHANCE = augmentation.getProperty("AugmentationMidGlowChance", 40);
		AUGMENTATION_HIGH_SKILL_CHANCE = augmentation.getProperty("AugmentationHighSkillChance", 45);
		AUGMENTATION_HIGH_GLOW_CHANCE = augmentation.getProperty("AugmentationHighGlowChance", 70);
		AUGMENTATION_TOP_SKILL_CHANCE = augmentation.getProperty("AugmentationTopSkillChance", 60);
		AUGMENTATION_TOP_GLOW_CHANCE = augmentation.getProperty("AugmentationTopGlowChance", 100);
		AUGMENTATION_BASESTAT_CHANCE = augmentation.getProperty("AugmentationBaseStatChance", 1);
		AUGMENTATION_VIA_LIFE_STONE = augmentation.getProperty("AugmentationViaLifeStone", true);
		AUGMENTATION_VIA_LIFE_STONE_COST_NO_GRADE = augmentation.getProperty("AugmentationViaLifeStoneCostNoGrade", new int[]
		{
			2130,
			20
		});
		AUGMENTATION_VIA_LIFE_STONE_COST_MID_GRADE = augmentation.getProperty("AugmentationViaLifeStoneCostMidGrade", new int[]
		{
			2130,
			30
		});
		AUGMENTATION_VIA_LIFE_STONE_COST_HIGH_GRADE = augmentation.getProperty("AugmentationViaLifeStoneCostHighGrade", new int[]
		{
			2131,
			20
		});
		AUGMENTATION_VIA_LIFE_STONE_COST_TOP_GRADE = augmentation.getProperty("AugmentationViaLifeStoneCostTopGrade", new int[]
		{
			2131,
			25
		});
	}
	
	/**
	 * Loads karma and PvP settings.
	 */
	private static final void loadKarma()
	{
		final ExProperties karma = initProperties(PLAYERS_KARMA_FILE);
		
		KARMA_PLAYER_CAN_SHOP = karma.getProperty("KarmaPlayerCanShop", false);
		KARMA_PLAYER_CAN_USE_GK = karma.getProperty("KarmaPlayerCanUseGK", false);
		KARMA_PLAYER_CAN_TELEPORT = karma.getProperty("KarmaPlayerCanTeleport", true);
		KARMA_PLAYER_CAN_TRADE = karma.getProperty("KarmaPlayerCanTrade", true);
		KARMA_PLAYER_CAN_USE_WH = karma.getProperty("KarmaPlayerCanUseWareHouse", true);
		KARMA_DROP_GM = karma.getProperty("CanGMDropEquipment", false);
		KARMA_AWARD_PK_KILL = karma.getProperty("AwardPKKillPVPPoint", true);
		KARMA_PK_LIMIT = karma.getProperty("MinimumPKRequiredToDrop", 5);
		KARMA_NONDROPPABLE_PET_ITEMS = karma.getProperty("ListOfPetItems", new int[]
		{
			2375,
			3500,
			3501,
			3502,
			4422,
			4423,
			4424,
			4425,
			6648,
			6649,
			6650
		});
		KARMA_NONDROPPABLE_ITEMS = karma.getProperty("ListOfNonDroppableItemsForPK", new int[]
		{
			1147,
			425,
			1146,
			461,
			10,
			2368,
			7,
			6,
			2370,
			2369
		});
		
		PVP_NORMAL_TIME = karma.getProperty("PvPVsNormalTime", 40000);
		PVP_PVP_TIME = karma.getProperty("PvPVsPvPTime", 20000);
	}
	
	/**
	 * Loads skills settings.<br>
	 * Such as skill learning, casting, subclasses, crafting and buffs.
	 */
	private static final void loadSkills()
	{
		final ExProperties skills = initProperties(PLAYERS_SKILLS_FILE);
		
		AUTO_LEARN_SKILLS = skills.getProperty("AutoLearnSkills", false);
		SP_BOOK_NEEDED = skills.getProperty("SpBookNeeded", true);
		ES_SP_BOOK_NEEDED = skills.getProperty("EnchantSkillSpBookNeeded", true);
		DIVINE_SP_BOOK_NEEDED = skills.getProperty("DivineInspirationSpBookNeeded", true);
		LIFE_CRYSTAL_NEEDED = skills.getProperty("LifeCrystalNeeded", true);
		
		MAGIC_FAILURES = skills.getProperty("MagicFailures", true);
		PERFECT_SHIELD_BLOCK_RATE = skills.getProperty("PerfectShieldBlockRate", 5);
		
		SUBCLASS_WITHOUT_QUESTS = skills.getProperty("SubClassWithoutQuests", false);
		
		IS_CRAFTING_ENABLED = skills.getProperty("CraftingEnabled", true);
		DWARF_RECIPE_LIMIT = skills.getProperty("DwarfRecipeLimit", 50);
		COMMON_RECIPE_LIMIT = skills.getProperty("CommonRecipeLimit", 50);
		BLACKSMITH_USE_RECIPES = skills.getProperty("BlacksmithUseRecipes", true);
		
		MAX_BUFFS_AMOUNT = skills.getProperty("MaxBuffsAmount", 20);
		STORE_SKILL_COOLTIME = skills.getProperty("StoreSkillCooltime", true);
	}
	
	/**
	 * Loads admin settings.<br>
	 * Such as access level, GM login behavior and petitions.
	 */
	private static final void loadAdmin()
	{
		final ExProperties admin = initProperties(PLAYERS_ADMIN_FILE);
		
		DEFAULT_ACCESS_LEVEL = admin.getProperty("DefaultAccessLevel", 0);
		
		GM_HERO_AURA = admin.getProperty("GMHeroAura", false);
		GM_STARTUP_INVULNERABLE = admin.getProperty("GMStartupInvulnerable", false);
		GM_STARTUP_INVISIBLE = admin.getProperty("GMStartupInvisible", false);
		GM_STARTUP_BLOCK_ALL = admin.getProperty("GMStartupBlockAll", false);
		GM_STARTUP_AUTO_LIST = admin.getProperty("GMStartupAutoList", true);
		
		PETITIONING_ALLOWED = admin.getProperty("PetitioningAllowed", true);
		MAX_PETITIONS_PER_PLAYER = admin.getProperty("MaxPetitionsPerPlayer", 5);
		MAX_PETITIONS_PENDING = admin.getProperty("MaxPetitionsPending", 25);
	}
	
	/**
	 * Loads siege settings.
	 */
	private static final void loadSieges()
	{
		final ExProperties sieges = initProperties(SIEGE_FILE);
		
		SIEGE_LENGTH = sieges.getProperty("SiegeLength", 120);
		MINIMUM_CLAN_LEVEL = sieges.getProperty("SiegeClanMinLevel", 4);
		MAX_ATTACKERS_NUMBER = sieges.getProperty("AttackerMaxClans", 10);
		MAX_DEFENDERS_NUMBER = sieges.getProperty("DefenderMaxClans", 10);
		ATTACKERS_RESPAWN_DELAY = sieges.getProperty("AttackerRespawn", 10000);
		
		CH_MINIMUM_CLAN_LEVEL = sieges.getProperty("ChSiegeClanMinLevel", 4);
		CH_MAX_ATTACKERS_NUMBER = sieges.getProperty("ChAttackerMaxClans", 10);
	}
	
	/**
	 * Loads gameserver settings.<br>
	 * IP addresses, database, server list and characters.
	 */
	private static final void loadServer()
	{
		final ExProperties server = initProperties(SERVER_FILE);
		
		HOSTNAME = server.getProperty("Hostname", "*");
		GAMESERVER_HOSTNAME = server.getProperty("GameserverHostname");
		GAMESERVER_PORT = server.getProperty("GameserverPort", 7777);
		GAMESERVER_LOGIN_HOSTNAME = server.getProperty("LoginHost", "127.0.0.1");
		GAMESERVER_LOGIN_PORT = server.getProperty("LoginPort", 9014);
		REQUEST_ID = server.getProperty("RequestServerID", 0);
		ACCEPT_ALTERNATE_ID = server.getProperty("AcceptAlternateID", true);
		USE_BLOWFISH_CIPHER = server.getProperty("UseBlowfishCipher", true);
		
		DATABASE_URL = server.getProperty("URL", "jdbc:mariadb://localhost/acis");
		DATABASE_LOGIN = server.getProperty("Login", "root");
		DATABASE_PASSWORD = server.getProperty("Password", "");
		
		SERVER_LIST_BRACKET = server.getProperty("ServerListBrackets", false);
		SERVER_LIST_CLOCK = server.getProperty("ServerListClock", false);
		SERVER_GMONLY = server.getProperty("ServerGMOnly", false);
		SERVER_LIST_AGE = server.getProperty("ServerListAgeLimit", 0);
		SERVER_LIST_TESTSERVER = server.getProperty("TestServer", false);
		SERVER_LIST_PVPSERVER = server.getProperty("PvpServer", true);
		
		DELETE_DAYS = server.getProperty("DeleteCharAfterDays", 7);
		MAXIMUM_ONLINE_USERS = server.getProperty("MaximumOnlineUsers", 100);
	}
	
	/**
	 * Loads rates settings.<br>
	 * Experience, drops, quest rewards, player death drops and pets.
	 */
	private static final void loadRates()
	{
		final ExProperties rates = initProperties(RATES_FILE);
		
		RATE_XP = rates.getProperty("RateXp", 1.);
		RATE_SP = rates.getProperty("RateSp", 1.);
		RATE_PARTY_XP = rates.getProperty("RatePartyXp", 1.);
		RATE_PARTY_SP = rates.getProperty("RatePartySp", 1.);
		
		RATE_DROP_CURRENCY = rates.getProperty("RateDropCurrency", 1.);
		RATE_DROP_ITEMS = rates.getProperty("RateDropItems", 1.);
		RATE_DROP_ITEMS_BY_RAID = rates.getProperty("RateRaidDropItems", 1.);
		RATE_DROP_SPOIL = rates.getProperty("RateDropSpoil", 1.);
		RATE_DROP_HERBS = rates.getProperty("RateDropHerbs", 1.);
		RATE_DROP_MANOR = rates.getProperty("RateDropManor", 1);
		
		RATE_QUEST_DROP = rates.getProperty("RateQuestDrop", 1.);
		RATE_QUEST_REWARD = rates.getProperty("RateQuestReward", 1.);
		RATE_QUEST_REWARD_XP = rates.getProperty("RateQuestRewardXP", 1.);
		RATE_QUEST_REWARD_SP = rates.getProperty("RateQuestRewardSP", 1.);
		RATE_QUEST_REWARD_ADENA = rates.getProperty("RateQuestRewardAdena", 1.);
		
		RATE_KARMA_EXP_LOST = rates.getProperty("RateKarmaExpLost", 1.);
		RATE_SIEGE_GUARDS_PRICE = rates.getProperty("RateSiegeGuardsPrice", 1.);
		
		PLAYER_DROP_LIMIT = rates.getProperty("PlayerDropLimit", 3);
		PLAYER_RATE_DROP = rates.getProperty("PlayerRateDrop", 5);
		PLAYER_RATE_DROP_ITEM = rates.getProperty("PlayerRateDropItem", 70);
		PLAYER_RATE_DROP_EQUIP = rates.getProperty("PlayerRateDropEquip", 25);
		PLAYER_RATE_DROP_EQUIP_WEAPON = rates.getProperty("PlayerRateDropEquipWeapon", 5);
		
		KARMA_DROP_LIMIT = rates.getProperty("KarmaDropLimit", 10);
		KARMA_RATE_DROP = rates.getProperty("KarmaRateDrop", 70);
		KARMA_RATE_DROP_ITEM = rates.getProperty("KarmaRateDropItem", 50);
		KARMA_RATE_DROP_EQUIP = rates.getProperty("KarmaRateDropEquip", 40);
		KARMA_RATE_DROP_EQUIP_WEAPON = rates.getProperty("KarmaRateDropEquipWeapon", 10);
		
		PET_XP_RATE = rates.getProperty("PetXpRate", 1.);
		PET_FOOD_RATE = rates.getProperty("PetFoodRate", 1);
		SINEATER_XP_RATE = rates.getProperty("SinEaterXpRate", 1.);
	}
	
	/**
	 * Loads items settings.<br>
	 * Auto-loot, ground items lifetime and try on.
	 */
	private static final void loadItems()
	{
		final ExProperties items = initProperties(ITEMS_FILE);
		
		AUTO_LOOT = items.getProperty("AutoLoot", false);
		AUTO_LOOT_HERBS = items.getProperty("AutoLootHerbs", false);
		AUTO_LOOT_RAID = items.getProperty("AutoLootRaid", false);
		
		ALLOW_DISCARDITEM = items.getProperty("AllowDiscardItem", true);
		MULTIPLE_ITEM_DROP = items.getProperty("MultipleItemDrop", true);
		HERB_AUTO_DESTROY_TIME = items.getProperty("AutoDestroyHerbTime", 15) * 1000;
		ITEM_AUTO_DESTROY_TIME = items.getProperty("AutoDestroyItemTime", 600) * 1000;
		EQUIPABLE_ITEM_AUTO_DESTROY_TIME = items.getProperty("AutoDestroyEquipableItemTime", 0) * 1000;
		SPECIAL_ITEM_DESTROY_TIME = new HashMap<>();
		String[] data = items.getProperty("AutoDestroySpecialItemTime", (String[]) null, ",");
		if (data != null)
		{
			for (String itemData : data)
			{
				String[] item = itemData.split("-");
				SPECIAL_ITEM_DESTROY_TIME.put(Integer.parseInt(item[0]), Integer.parseInt(item[1]) * 1000);
			}
		}
		PLAYER_DROPPED_ITEM_MULTIPLIER = items.getProperty("PlayerDroppedItemMultiplier", 1);
		
		ALLOW_WEAR = items.getProperty("AllowWear", true);
		WEAR_DELAY = items.getProperty("WearDelay", 5);
		WEAR_PRICE = items.getProperty("WearPrice", 10);
	}
	
	/**
	 * Loads features settings.<br>
	 * World wide switches and community board.
	 */
	private static final void loadFeatures()
	{
		final ExProperties features = initProperties(FEATURES_FILE);
		
		ALLOW_WATER = features.getProperty("AllowWater", true);
		ALLOW_BOAT = features.getProperty("AllowBoat", true);
		ALLOW_CURSED_WEAPONS = features.getProperty("AllowCursedWeapons", true);
		ENABLE_FALLING_DAMAGE = features.getProperty("EnableFallingDamage", true);
		ZONE_TOWN = features.getProperty("ZoneTown", 0);
		
		ENABLE_COMMUNITY_BOARD = features.getProperty("EnableCommunityBoard", false);
		BBS_DEFAULT = features.getProperty("BBSDefault", "_bbshome");
		
		SERVER_NEWS = features.getProperty("ShowServerNews", false);
	}
	
	/**
	 * Loads protection settings.<br>
	 * Third party clients and flood protectors.
	 */
	private static final void loadProtection()
	{
		final ExProperties protection = initProperties(PROTECTION_FILE);
		
		L2WALKER_PROTECTION = protection.getProperty("L2WalkerProtection", false);
		
		ROLL_DICE_TIME = protection.getProperty("RollDiceTime", 4200);
		HERO_VOICE_TIME = protection.getProperty("HeroVoiceTime", 10000);
		SUBCLASS_TIME = protection.getProperty("SubclassTime", 2000);
		DROP_ITEM_TIME = protection.getProperty("DropItemTime", 1000);
		SERVER_BYPASS_TIME = protection.getProperty("ServerBypassTime", 100);
		MULTISELL_TIME = protection.getProperty("MultisellTime", 100);
		MANUFACTURE_TIME = protection.getProperty("ManufactureTime", 300);
		MANOR_TIME = protection.getProperty("ManorTime", 3000);
		SENDMAIL_TIME = protection.getProperty("SendMailTime", 10000);
		CHARACTER_SELECT_TIME = protection.getProperty("CharacterSelectTime", 3000);
		GLOBAL_CHAT_TIME = protection.getProperty("GlobalChatTime", 0);
		TRADE_CHAT_TIME = protection.getProperty("TradeChatTime", 0);
		SOCIAL_TIME = protection.getProperty("SocialTime", 2000);
	}
	
	/**
	 * Loads development settings.<br>
	 * Debug switches and audit logs.
	 */
	private static final void loadDevelopment()
	{
		final ExProperties development = initProperties(DEVELOPMENT_FILE);
		
		NO_SPAWNS = development.getProperty("NoSpawns", false);
		DEVELOPER = development.getProperty("Developer", false);
		PACKET_HANDLER_DEBUG = development.getProperty("PacketHandlerDebug", false);
		
		LOG_CHAT = development.getProperty("LogChat", false);
		LOG_ITEMS = development.getProperty("LogItems", false);
		GMAUDIT = development.getProperty("GMAudit", false);
	}
	
	/**
	 * Loads offline shop settings.
	 */
	private static final void loadOfflineShop()
	{
		final ExProperties offlineShop = initProperties(MODS_OFFLINE_SHOP_FILE);
		
		OFFLINE_TRADE_ENABLE = offlineShop.getProperty("OfflineTradeEnable", false);
		OFFLINE_CRAFT_ENABLE = offlineShop.getProperty("OfflineCraftEnable", false);
		OFFLINE_MODE_IN_PEACE_ZONE = offlineShop.getProperty("OfflineModeInPeaceZone", false);
		OFFLINE_MODE_NO_DAMAGE = offlineShop.getProperty("OfflineModeNoDamage", false);
		
		OFFLINE_SET_NAME_COLOR = offlineShop.getProperty("OfflineSetNameColor", false);
		OFFLINE_NAME_COLOR = Integer.decode("0x" + offlineShop.getProperty("OfflineNameColor", "808080"));
		
		RESTORE_OFFLINERS = offlineShop.getProperty("RestoreOffliners", false);
		OFFLINE_MAX_DAYS = offlineShop.getProperty("OfflineMaxDays", 10);
		OFFLINE_DISCONNECT_FINISHED = offlineShop.getProperty("OfflineDisconnectFinished", true);
	}
	
	/**
	 * Loads custom client settings.<br>
	 * Only meaningful for the client rebuilt from tools/client : version check, item name colors and item statistics.
	 */
	private static final void loadClient()
	{
		final ExProperties client = initProperties(MODS_CLIENT_FILE);
		
		CLIENT_VERSION = client.getProperty("ClientVersion", "").trim();
		CLIENT_VERSION_TIMEOUT = client.getProperty("ClientVersionTimeout", 10) * 1000;
		CLIENT_VERSION_MESSAGE = client.getProperty("ClientVersionMessage", "Your game client is out of date. Please update it to play on this server.").trim();
		
		SEND_ITEM_NAME_COLORS = client.getProperty("SendItemNameColors", false);
		SEND_ITEM_STATS = client.getProperty("SendItemStats", false);
		SEND_ITEM_SKILLS = client.getProperty("SendItemSkills", false);
	}
	
	/**
	 * Loads network settings.<br>
	 * MMO selector, client packets queue.
	 */
	private static final void loadNetwork()
	{
		final ExProperties network = initProperties(NETWORK_FILE);

		RESERVE_HOST_ON_LOGIN = network.getProperty("ReserveHostOnLogin", false);

		MMO_SELECTOR_SLEEP_TIME = network.getProperty("SelectorSleepTime", 20);
		MMO_MAX_SEND_PER_PASS = network.getProperty("MaxSendPerPass", 80);
		MMO_MAX_READ_PER_PASS = network.getProperty("MaxReadPerPass", 80);
		MMO_HELPER_BUFFER_COUNT = network.getProperty("HelperBufferCount", 20);

		CLIENT_PACKET_QUEUE_SIZE = network.getProperty("PacketQueueSize", 0);
		if (CLIENT_PACKET_QUEUE_SIZE <= 0)
			CLIENT_PACKET_QUEUE_SIZE = MMO_MAX_READ_PER_PASS + 2;

		CLIENT_PACKET_QUEUE_MAX_BURST_SIZE = network.getProperty("PacketQueueMaxBurstSize", 0);
		if (CLIENT_PACKET_QUEUE_MAX_BURST_SIZE <= 0)
			CLIENT_PACKET_QUEUE_MAX_BURST_SIZE = MMO_MAX_READ_PER_PASS + 1;

		CLIENT_PACKET_QUEUE_MAX_PACKETS_PER_SECOND = network.getProperty("PacketQueueMaxPacketsPerSecond", 160);
		CLIENT_PACKET_QUEUE_MEASURE_INTERVAL = network.getProperty("PacketQueueMeasureInterval", 5);
		CLIENT_PACKET_QUEUE_MAX_AVERAGE_PACKETS_PER_SECOND = network.getProperty("PacketQueueMaxAveragePacketsPerSecond", 80);
		CLIENT_PACKET_QUEUE_MAX_FLOODS_PER_MIN = network.getProperty("PacketQueueMaxFloodsPerMin", 2);
		CLIENT_PACKET_QUEUE_MAX_OVERFLOWS_PER_MIN = network.getProperty("PacketQueueMaxOverflowsPerMin", 1);
		CLIENT_PACKET_QUEUE_MAX_UNDERFLOWS_PER_MIN = network.getProperty("PacketQueueMaxUnderflowsPerMin", 1);
		CLIENT_PACKET_QUEUE_MAX_UNKNOWN_PER_MIN = network.getProperty("PacketQueueMaxUnknownPerMin", 5);
	}

	/**
	 * Loads loginserver settings.<br>
	 * IP addresses, database, account, misc.
	 */
	private static final void loadLogin()
	{
		final ExProperties server = initProperties(LOGINSERVER_FILE);
		
		HOSTNAME = server.getProperty("Hostname", "localhost");
		LOGINSERVER_HOSTNAME = server.getProperty("LoginserverHostname", "*");
		LOGINSERVER_PORT = server.getProperty("LoginserverPort", 2106);
		GAMESERVER_LOGIN_HOSTNAME = server.getProperty("LoginHostname", "*");
		GAMESERVER_LOGIN_PORT = server.getProperty("LoginPort", 9014);
		LOGIN_TRY_BEFORE_BAN = server.getProperty("LoginTryBeforeBan", 3);
		LOGIN_BLOCK_AFTER_BAN = server.getProperty("LoginBlockAfterBan", 600);
		ACCEPT_NEW_GAMESERVER = server.getProperty("AcceptNewGameServer", false);
		SHOW_LICENCE = server.getProperty("ShowLicence", true);
		
		DATABASE_URL = server.getProperty("URL", "jdbc:mariadb://localhost/acis");
		DATABASE_LOGIN = server.getProperty("Login", "root");
		DATABASE_PASSWORD = server.getProperty("Password", "");
		
		AUTO_CREATE_ACCOUNTS = server.getProperty("AutoCreateAccounts", true);
		
		FLOOD_PROTECTION = server.getProperty("EnableFloodProtection", true);
		FAST_CONNECTION_LIMIT = server.getProperty("FastConnectionLimit", 15);
		NORMAL_CONNECTION_TIME = server.getProperty("NormalConnectionTime", 700);
		FAST_CONNECTION_TIME = server.getProperty("FastConnectionTime", 350);
		MAX_CONNECTION_PER_IP = server.getProperty("MaxConnectionPerIP", 50);
	}
	
	public static final void loadGameServer()
	{
		LOGGER.info("Loading gameserver configuration files.");
		
		// server settings
		loadServer();
		loadNetwork();
		loadRates();
		loadItems();
		loadFeatures();
		loadProtection();
		loadDevelopment();
		
		// world settings
		loadClans();
		loadSieges();
		loadGeoengine();
		
		// events settings
		loadOlympiad();
		loadSevenSigns();
		loadInstances();
		loadMinigames();
		
		// NPCs settings
		loadNpcs();
		loadNameplates();
		loadBosses();
		loadNpcManagers();
		
		// players settings
		loadCharacter();
		loadInventory();
		loadEnchant();
		loadAugmentation();
		loadKarma();
		loadSkills();
		loadAdmin();
		
		// mods settings
		loadChampionMobs();
		loadClient();
		loadDropList();
		loadGatekeeper();
		loadOfflineShop();
		loadRaidBook();
		
		// hexID
		loadHexID();
	}
	
	public static final void loadLoginServer()
	{
		LOGGER.info("Loading loginserver configuration files.");

		// login settings
		loadLogin();
		loadNetwork();
	}

	public static final void loadAccountManager()
	{
		LOGGER.info("Loading account manager configuration files.");
		
		// login settings
		loadLogin();
	}
	
	public static final void loadGameServerRegistration()
	{
		LOGGER.info("Loading gameserver registration configuration files.");
		
		// login settings
		loadLogin();
	}
	
	public static final class ClassMasterSettings
	{
		private final Map<Integer, Boolean> _allowedClassChange;
		private final Map<Integer, List<IntIntHolder>> _claimItems;
		private final Map<Integer, List<IntIntHolder>> _rewardItems;
		
		private ClassMasterSettings(String configLine)
		{
			_allowedClassChange = HashMap.newHashMap(3);
			_claimItems = HashMap.newHashMap(3);
			_rewardItems = HashMap.newHashMap(3);
			
			if (configLine != null)
				parseConfigLine(configLine.trim());
		}
		
		private void parseConfigLine(String configLine)
		{
			StringTokenizer st = new StringTokenizer(configLine, ";");
			while (st.hasMoreTokens())
			{
				// Get allowed class change.
				int job = Integer.parseInt(st.nextToken());
				
				_allowedClassChange.put(job, true);
				
				List<IntIntHolder> items = new ArrayList<>();
				
				// Parse items needed for class change.
				if (st.hasMoreTokens())
				{
					StringTokenizer st2 = new StringTokenizer(st.nextToken(), "[],");
					while (st2.hasMoreTokens())
					{
						StringTokenizer st3 = new StringTokenizer(st2.nextToken(), "()");
						items.add(new IntIntHolder(Integer.parseInt(st3.nextToken()), Integer.parseInt(st3.nextToken())));
					}
				}
				
				// Feed the map, and clean the list.
				_claimItems.put(job, items);
				items = new ArrayList<>();
				
				// Parse gifts after class change.
				if (st.hasMoreTokens())
				{
					StringTokenizer st2 = new StringTokenizer(st.nextToken(), "[],");
					while (st2.hasMoreTokens())
					{
						StringTokenizer st3 = new StringTokenizer(st2.nextToken(), "()");
						items.add(new IntIntHolder(Integer.parseInt(st3.nextToken()), Integer.parseInt(st3.nextToken())));
					}
				}
				
				_rewardItems.put(job, items);
			}
		}
		
		public boolean isAllowed(int job)
		{
			if (_allowedClassChange == null)
				return false;
			
			if (_allowedClassChange.containsKey(job))
				return _allowedClassChange.get(job);
			
			return false;
		}
		
		public List<IntIntHolder> getRewardItems(int job)
		{
			return _rewardItems.get(job);
		}
		
		public List<IntIntHolder> getRequiredItems(int job)
		{
			return _claimItems.get(job);
		}
	}
}
