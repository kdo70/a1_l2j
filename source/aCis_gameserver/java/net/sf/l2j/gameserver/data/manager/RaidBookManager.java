package net.sf.l2j.gameserver.data.manager;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.text.SimpleDateFormat;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.Date;
import java.util.Deque;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Set;
import java.util.StringTokenizer;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.IntFunction;

import net.sf.l2j.commons.lang.StringUtil;
import net.sf.l2j.commons.logging.CLogger;
import net.sf.l2j.commons.math.MathUtil;
import net.sf.l2j.commons.pool.ConnectionPool;

import net.sf.l2j.Config;
import net.sf.l2j.gameserver.data.cache.HtmCache;
import net.sf.l2j.gameserver.data.sql.ClanTable;
import net.sf.l2j.gameserver.data.sql.PlayerInfoTable;
import net.sf.l2j.gameserver.data.xml.ItemData;
import net.sf.l2j.gameserver.data.xml.ItemIconData;
import net.sf.l2j.gameserver.data.xml.NpcData;
import net.sf.l2j.gameserver.data.xml.RaidBookData;
import net.sf.l2j.gameserver.data.xml.RaidBookData.LevelFilter;
import net.sf.l2j.gameserver.data.xml.ScriptData;
import net.sf.l2j.gameserver.enums.DropType;
import net.sf.l2j.gameserver.model.World;
import net.sf.l2j.gameserver.model.actor.Creature;
import net.sf.l2j.gameserver.model.actor.Npc;
import net.sf.l2j.gameserver.model.actor.Playable;
import net.sf.l2j.gameserver.model.actor.Player;
import net.sf.l2j.gameserver.model.actor.container.npc.AggroInfo;
import net.sf.l2j.gameserver.model.actor.instance.RaidBoss;
import net.sf.l2j.gameserver.model.actor.template.NpcTemplate;
import net.sf.l2j.gameserver.model.holder.IntIntHolder;
import net.sf.l2j.gameserver.model.item.DropCategory;
import net.sf.l2j.gameserver.model.item.DropData;
import net.sf.l2j.gameserver.model.item.kind.Item;
import net.sf.l2j.gameserver.model.location.Location;
import net.sf.l2j.gameserver.model.pledge.Clan;
import net.sf.l2j.gameserver.model.pledge.ClanMember;
import net.sf.l2j.gameserver.model.spawn.ASpawn;
import net.sf.l2j.gameserver.scripting.Quest;
import net.sf.l2j.gameserver.scripting.ScheduledQuest;

import net.sf.l2j.gameserver.network.serverpackets.ActionFailed;
import net.sf.l2j.gameserver.network.serverpackets.ExShowScreenMessage;
import net.sf.l2j.gameserver.network.serverpackets.NpcHtmlMessage;

/**
 * Generates the raid boss book a {@link Player} opens by using the book item, and holds the hunting record which feeds it.<br>
 * <br>
 * The book lists every raid boss of the server, filtered by level ranges, each row telling the hunting level of that very {@link Player} on that boss and how far he stands from the next one - a bar
 * drawn the way the experience bar of a character is. A row leads to a detail page holding the statistics of the boss, a button dropping a radar marker on its spawn point, and four tabs : the rewards
 * the coming hunting levels give, the drop list of the boss, the last kills it suffered and the players who killed it the most.<br>
 * <br>
 * A hunting level is worth {@link Config#RAIDBOOK_KILLS_PER_LEVEL} kills, the very first one being reached on the first kill, and each of them adds
 * {@link Config#RAIDBOOK_DAMAGE_PER_LEVEL} percent to the damage that {@link Player} deals to that boss - and to that boss only. Every kill is also worth ranking points, which are summed over every
 * boss into one single server wide ladder - the one the daily rewards are handed out of.<br>
 * <br>
 * A kill is credited to every {@link Player} who dealt damage and stood close enough when the boss went down, which is the very rule the experience rewards run on. The history names the one who dealt
 * the most damage.<br>
 * <br>
 * The behavior lives on config/mods/raidbook.properties, the whole appearance on data/xml/raidbook.xml.
 */
public class RaidBookManager
{
	private static final CLogger LOGGER = new CLogger(RaidBookManager.class.getName());

	/** The bypass fired by the generated links, followed by a one letter action and its parameters. */
	public static final String BYPASS = "_rbook ";

	private static final String LIST_HTM = "./data/html/mods/raidbook/list.htm";
	private static final String DETAIL_HTM = "./data/html/mods/raidbook/detail.htm";
	private static final String RANK_HTM = "./data/html/mods/raidbook/rank.htm";
	private static final String DAILY_HTM = "./data/html/mods/raidbook/daily.htm";

	private static final String LOAD_HUNTS = "SELECT char_id, boss_id, kills, points FROM character_raidboss_kills";
	private static final String SAVE_HUNT = "REPLACE INTO character_raidboss_kills (char_id, boss_id, kills, points) VALUES (?,?,?,?)";
	private static final String LOAD_HISTORY = "SELECT boss_id, char_name, clan_name, kill_time FROM raidboss_kill_history ORDER BY kill_time DESC";
	private static final String SAVE_HISTORY = "INSERT INTO raidboss_kill_history (boss_id, char_name, clan_name, kill_time) VALUES (?,?,?,?)";
	private static final String TRIM_HISTORY = "DELETE FROM raidboss_kill_history WHERE boss_id = ? AND kill_time < ?";
	private static final String LOAD_PENDING = "SELECT char_id, place, item_id, count FROM raidboss_daily_rewards";
	private static final String SAVE_PENDING = "INSERT INTO raidboss_daily_rewards (char_id, place, item_id, count, kind) VALUES (?,?,?,?,?)";
	private static final String READ_PENDING = "SELECT place, item_id, count, kind FROM raidboss_daily_rewards WHERE char_id = ?";
	private static final String CLEAR_PENDING = "DELETE FROM raidboss_daily_rewards WHERE char_id = ?";

	private static final String LOAD_WINS = "SELECT char_id, wins FROM raidboss_monthly_wins";
	private static final String SAVE_WIN = "REPLACE INTO raidboss_monthly_wins (char_id, wins) VALUES (?,?)";
	private static final String CLEAR_WINS = "DELETE FROM raidboss_monthly_wins";

	private static final String ROW_END = "</tr></table>";

	/**
	 * The placeholder standing where the background color of a row goes. A row is rendered once, then striped when it lands on a page : a stripe which follows the absolute index of a row would flip
	 * from one page to the next, and the first row of a page would sometimes repeat the color of the menu sitting right above it.
	 */
	private static final String BAND = "%band%";

	/** Height, in pixels, of the rule cutting the blocks of a page apart. The separator textures are hairlines, and the filler math relies on that height being fixed. */
	private static final int SEPARATOR_HEIGHT = 1;

	/** Slack, in pixels, left inside the cell holding the progress bar. A cell holding something of its very width leaves the client no room, and it wraps that content onto the next line. */
	private static final int BAR_SLACK = 2;

	/**
	 * Amount of lines the statistics block of a detail page holds : two for the pools and the rewards, one for the respawn window, three for the combat stats. Both blocks are two columns wide, so a
	 * line carries two stats - the respawn one being the exception, it owns its whole line.
	 */
	private static final int STATS_ROWS = 6;

	/** Amount of lines the hunting block of a detail page holds : the hunting level and the amount of kills, then the damage bonus and what the next level takes. */
	private static final int HUNT_ROWS = 2;

	/** {@link DecimalFormat} isn't thread safe and several {@link Player}s can browse the book at once, so a formatter is built per cell ; only its symbols are shared. */
	private static final DecimalFormatSymbols NUMBER_SYMBOLS = DecimalFormatSymbols.getInstance(Locale.ENGLISH);

	/** The memo telling a character has already been handed the book. It is stored on character_memo, so it outlives whatever happens to the item itself. */
	private static final String GIVEN_MEMO = "raidbook_given";

	/** The two ladders of the book, and the two reward pages which go with them : the daily one, ranked on hunting points, and the monthly one, ranked on daily wins. */
	private static final int MODE_DAILY = 0;
	private static final int MODE_MONTHLY = 1;

	/** The name of the scheduled scripts handing out both rewards, which is what the book reads the date of the next handout off. */
	private static final String DAILY_SCRIPT = "RaidBookDailyReward";
	private static final String MONTHLY_SCRIPT = "RaidBookMonthlyReward";

	/** The characters a search query is allowed to hold. Anything else is dropped : a query travels back to the server inside a bypass, and it is written back into the page afterwards. */
	private static final String QUERY_EXTRAS = " '-.";

	/** The tabs of a detail page, in the very order they are shown. */
	private static final int TAB_REWARDS = 0;
	private static final int TAB_DROP = 1;
	private static final int TAB_HISTORY = 2;
	private static final int TAB_RANK = 3;
	private static final int TAB_COUNT = 4;

	/** What one {@link Player} did to one raid boss : the amount of kills, which drives his hunting level, and the ranking points those kills were worth. */
	private record HuntData(int kills, int points)
	{
	}

	/** One line of the kill history of a raid boss. The clan is the one the killer wore at that very moment, so a later clan change doesn't rewrite the past. */
	private record KillRecord(String playerName, String clanName, long time)
	{
	}

	/** One line of a ladder : the objectId of a {@link Player} and whatever it is ranked on - the points he cumulated over every raid boss, or his kills on one single boss. */
	private record RankRow(int objectId, int score)
	{
	}

	/** One rendered drop : the whole draw chance of a {@link DropData}, and the amount it gives. */
	private record DropRow(int itemId, double chance, int min, int max)
	{
	}

	/** The statistics of a raid boss, computed out of its template rather than out of a live instance - a boss which isn't spawned has to be readable too. */
	private record BossStats(long hp, long mp, long exp, long sp, int pAtk, int pDef, int atkSpd, int mAtk, int mDef, int castSpd)
	{
	}

	/** One already rendered row of a tab, and the index of the group it belongs to - -1 on the tabs which hold no group. */
	private record TabRow(String html, int group)
	{
	}

	/**
	 * The whole content of a tab : its column header - empty on the tabs whose columns speak for themselves - its rows, the header of each of its groups, and whether it is paged at all. The reward
	 * tab isn't, since a player reads the coming levels as one single block.
	 */
	private record TabContent(String columns, List<TabRow> rows, List<String> headers, boolean paged)
	{
	}

	/** One ladder reward waiting for its winner to log in, the kind telling a daily one from a monthly one - which is the only thing which still differs once it is stored. */
	private record PendingReward(int place, int itemId, int count, int kind)
	{
	}

	private final Map<Integer, Map<Integer, HuntData>> _hunts = new ConcurrentHashMap<>();
	private final Map<Integer, Deque<KillRecord>> _history = new ConcurrentHashMap<>();

	/** How many times each character took the first place of the daily ladder since the last monthly handout. It is what the monthly ladder is ranked on, and it is wiped by that handout. */
	private final Map<Integer, Integer> _wins = new ConcurrentHashMap<>();

	/** The objectIds owning a daily reward they haven't been handed yet, which is what spares a database read on every single login. */
	private final Set<Integer> _pending = ConcurrentHashMap.newKeySet();

	/** The sorted list of the raid bosses of the server, built once and dropped by {@link #reload()} - the templates don't move on their own. */
	private volatile List<NpcTemplate> _bosses;

	protected RaidBookManager()
	{
		loadHunts();
		loadHistory();
		loadPending();
		loadWins();

		LOGGER.info("Loaded {} raid boss hunting records.", _hunts.size());
	}

	private void loadHunts()
	{
		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement ps = con.prepareStatement(LOAD_HUNTS);
			ResultSet rs = ps.executeQuery())
		{
			while (rs.next())
				_hunts.computeIfAbsent(rs.getInt("char_id"), k -> new ConcurrentHashMap<>()).put(rs.getInt("boss_id"), new HuntData(rs.getInt("kills"), rs.getInt("points")));
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't load the raid boss hunting records.", e);
		}
	}

	/**
	 * The rows arrive newest first, so a boss simply stops taking them once it holds what the config shows ; whatever is left in the table is trimmed on the next kill of that boss.
	 */
	private void loadHistory()
	{
		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement ps = con.prepareStatement(LOAD_HISTORY);
			ResultSet rs = ps.executeQuery())
		{
			while (rs.next())
			{
				final Deque<KillRecord> records = _history.computeIfAbsent(rs.getInt("boss_id"), k -> new ArrayDeque<>());
				if (records.size() >= Config.RAIDBOOK_HISTORY_SIZE)
					continue;

				records.addLast(new KillRecord(rs.getString("char_name"), rs.getString("clan_name"), rs.getLong("kill_time")));
			}
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't load the raid boss kill history.", e);
		}
	}

	private void loadPending()
	{
		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement ps = con.prepareStatement(LOAD_PENDING);
			ResultSet rs = ps.executeQuery())
		{
			while (rs.next())
				_pending.add(rs.getInt("char_id"));
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't load the pending raid book daily rewards.", e);
		}
	}

	private void loadWins()
	{
		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement ps = con.prepareStatement(LOAD_WINS);
			ResultSet rs = ps.executeQuery())
		{
			while (rs.next())
				_wins.put(rs.getInt("char_id"), rs.getInt("wins"));
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't load the raid book monthly wins.", e);
		}
	}

	/**
	 * Answer the very first hit a {@link Player} lands on a raid boss : the boss enters his own book, and the book itself is handed over when he owns none yet.
	 * @param attacker : The {@link Creature} which just hit the boss, its owner being the one credited.
	 * @param bossId : The npcId of the hit raid boss.
	 */
	public void onRaidBossAttacked(Creature attacker, int bossId)
	{
		if (!Config.RAIDBOOK_ENABLED || attacker == null)
			return;

		final Player player = attacker.getActingPlayer();
		if (player == null)
			return;

		discover(player, bossId);
		giveBook(player);
	}

	/**
	 * Write a raid boss into the book of a {@link Player}. A book opens empty and fills up as its owner meets the bosses : a list of the 213 raid bosses of the server tells nothing, a list of the ones
	 * he actually fought is his own hunting record.<br>
	 * <br>
	 * The boss is remembered as a hunting record holding no kill yet, which is the very row a kill then bumps - so a discovery costs one single insert, and only the first hit ever pays it.
	 * @param player : The {@link Player} which just hit the boss.
	 * @param bossId : The npcId of the hit raid boss.
	 */
	private void discover(Player player, int bossId)
	{
		final Map<Integer, HuntData> playerData = _hunts.computeIfAbsent(player.getObjectId(), k -> new ConcurrentHashMap<>());

		// A hit lands on this path from several threads at once - the character, his servitor, a damage over time - so the row is claimed atomically rather than tested and then written.
		if (playerData.putIfAbsent(bossId, new HuntData(0, 0)) != null)
			return;

		saveHunt(player, bossId, 0, 0);
	}

	/**
	 * Hand the book over the first time a {@link Player} lays a hand on a raid boss - the moment the feature starts being worth anything to him, and the one moment he is bound to notice it.<br>
	 * <br>
	 * It is handed once and only once, whatever happens to the item afterwards : the marker lives on the character rather than on his inventory, so a book which somehow got destroyed isn't handed
	 * again. The one case which does hand it again is a full inventory - nothing was given, so nothing is remembered.
	 * @param player : The {@link Player} to hand the book to.
	 */
	private static void giveBook(Player player)
	{
		if (Config.RAIDBOOK_ITEM_ID <= 0)
			return;

		// The marker is claimed atomically too, and for the very same reason.
		if (player.getMemos().putIfAbsent(GIVEN_MEMO, Boolean.TRUE.toString()) != null)
			return;

		if (player.addItem(Config.RAIDBOOK_ITEM_ID, 1, true) == null)
		{
			// The inventory was full. Nothing has been written to the database yet, so dropping the marker from memory is enough to try again on the next hit.
			player.getMemos().remove(GIVEN_MEMO);
			return;
		}

		player.getMemos().set(GIVEN_MEMO, true);

		inform(player, RaidBookData.getInstance().getBookGivenMessage(), true);
	}

	/**
	 * Register the kill of a raid boss, which is what feeds the whole book.<br>
	 * <br>
	 * The kill is credited to every {@link Player} who dealt damage to the boss and stood close enough when it went down - the very rule {@link net.sf.l2j.gameserver.model.actor.instance.Monster}
	 * shares its experience by, so whoever earned experience for the kill earned the hunting kill too. The damage of a servitor counts for its owner. The history names the one who dealt the most
	 * damage, since a raid boss is brought down by a crowd and the last blow says little about who killed it.
	 * @param boss : The {@link RaidBoss} which has been killed.
	 */
	public void onRaidBossKill(RaidBoss boss)
	{
		if (!Config.RAIDBOOK_ENABLED)
			return;

		final Map<Player, Double> damages = new HashMap<>();

		for (AggroInfo info : boss.getAI().getAggroList().values())
		{
			if (!(info.getAttacker() instanceof Playable attacker))
				continue;

			// The very thresholds of the reward path : a scratch doesn't count, and neither does an attacker who left the place.
			final double damage = info.getDamage();
			if (damage <= 1 || !MathUtil.checkIfInRange(Config.PARTY_RANGE, boss, attacker, true))
				continue;

			final Player player = attacker.getActingPlayer();
			if (player == null)
				continue;

			damages.merge(player, damage, Double::sum);
		}

		if (damages.isEmpty())
			return;

		final int points = getKillPoints(boss.getStatus().getLevel());

		Player topDealer = null;
		double topDamage = 0;

		for (Entry<Player, Double> entry : damages.entrySet())
		{
			addKill(entry.getKey(), boss, points);

			if (entry.getValue() > topDamage)
			{
				topDamage = entry.getValue();
				topDealer = entry.getKey();
			}
		}

		addHistory(boss.getNpcId(), topDealer);
	}

	/**
	 * @param bossLevel : The level of the killed raid boss.
	 * @return The amount of ranking points one kill of such a boss is worth.
	 */
	private static int getKillPoints(int bossLevel)
	{
		return Math.max(0, (int) (Config.RAIDBOOK_POINTS_PER_KILL + bossLevel * Config.RAIDBOOK_POINTS_PER_BOSS_LEVEL));
	}

	private void addKill(Player player, RaidBoss boss, int points)
	{
		final RaidBookData data = RaidBookData.getInstance();
		final int bossId = boss.getNpcId();

		final Map<Integer, HuntData> playerData = _hunts.computeIfAbsent(player.getObjectId(), k -> new ConcurrentHashMap<>());

		// Two kills of the same boss can be credited to the same character within the same breath, so the record is bumped atomically.
		final HuntData current = playerData.compute(bossId, (k, previous) -> new HuntData(((previous == null) ? 0 : previous.kills()) + 1, ((previous == null) ? 0 : previous.points()) + points));

		final int kills = current.kills();

		saveHunt(player, bossId, kills, current.points());

		inform(player, data.getKillMessage().replace("%boss%", boss.getName()).replace("%points%", String.valueOf(points)), false);

		// A level is crossed by the very kill which reaches its own amount, so the reward is only ever given once.
		final int level = getHuntLevel(kills);
		if (level > getHuntLevel(kills - 1))
		{
			inform(player, data.getLevelUpMessage().replace("%boss%", boss.getName()).replace("%level%", String.valueOf(level)), true);

			for (IntIntHolder item : getLevelReward(level))
			{
				player.addItem(item.getId(), item.getValue(), true);

				inform(player, data.getRewardMessage().replace("%level%", String.valueOf(level)).replace("%item%", getItemName(item.getId())).replace("%count%", StringUtil.formatNumber(item.getValue())), true);
			}
		}
	}

	/**
	 * Write the hunting record of one {@link Player} on one raid boss, be it a fresh discovery holding no kill yet or a bumped one.
	 * @param player : The {@link Player} owning the record.
	 * @param bossId : The npcId of the raid boss the record belongs to.
	 * @param kills : The amount of kills to write.
	 * @param points : The amount of ranking points to write.
	 */
	private static void saveHunt(Player player, int bossId, int kills, int points)
	{
		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement ps = con.prepareStatement(SAVE_HUNT))
		{
			ps.setInt(1, player.getObjectId());
			ps.setInt(2, bossId);
			ps.setInt(3, kills);
			ps.setInt(4, points);
			ps.executeUpdate();
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't save the raid boss hunting record of {}.", e, player.getName());
		}
	}

	private void addHistory(int bossId, Player killer)
	{
		if (killer == null)
			return;

		final KillRecord record = new KillRecord(killer.getName(), (killer.getClan() == null) ? "" : killer.getClan().getName(), System.currentTimeMillis());

		final Deque<KillRecord> records = _history.computeIfAbsent(bossId, k -> new ArrayDeque<>());

		long oldest;

		synchronized (records)
		{
			records.addFirst(record);

			while (records.size() > Config.RAIDBOOK_HISTORY_SIZE)
				records.removeLast();

			oldest = records.getLast().time();
		}

		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement insert = con.prepareStatement(SAVE_HISTORY);
			PreparedStatement trim = con.prepareStatement(TRIM_HISTORY))
		{
			insert.setInt(1, bossId);
			insert.setString(2, record.playerName());
			insert.setString(3, record.clanName());
			insert.setLong(4, record.time());
			insert.executeUpdate();

			// Whatever fell out of the shown window is dropped from the table too, which is what keeps it bounded without any scheduled cleanup.
			trim.setInt(1, bossId);
			trim.setLong(2, oldest);
			trim.executeUpdate();
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't save the raid boss kill history of boss {}.", e, bossId);
		}
	}

	/**
	 * Hand out the daily rewards of the server wide ladder, called once a day by the scheduled task.<br>
	 * <br>
	 * A reward is always stored first and handed out afterwards : a winner who happens to be offline would lose it otherwise, and there is no telling when the task runs.
	 */
	public void runDailyRewards()
	{
		if (!Config.RAIDBOOK_ENABLED)
			return;

		final List<RankRow> ranking = getRanking();

		// Whoever tops the daily ladder wins the day, and the month is won by whoever won the most days. That is counted whatever the daily ladder itself hands out - the win is the ranking, not
		// the reward.
		if (!ranking.isEmpty())
			addWin(ranking.get(0).objectId());

		if (!Config.RAIDBOOK_DAILY_ENABLED || Config.RAIDBOOK_DAILY_REWARDS.isEmpty())
			return;

		LOGGER.info("Handed out the raid book daily rewards to {} player(s).", hand(ranking, Config.RAIDBOOK_DAILY_REWARDS, MODE_DAILY));
	}

	/**
	 * Hand out the monthly rewards of the daily win ladder, called on the first day of every month by the scheduled task, and wipe that ladder afterwards - the month starts over from an empty board.
	 * <br>
	 * <br>
	 * It runs after the daily task of the very same night on purpose (see data/xml/scripts.xml) : the day which just ended belongs to the month which is being closed, so its win has to be counted
	 * before the board is read.
	 */
	public void runMonthlyRewards()
	{
		if (!Config.RAIDBOOK_ENABLED || !Config.RAIDBOOK_MONTHLY_ENABLED || Config.RAIDBOOK_MONTHLY_REWARDS.isEmpty())
			return;

		final int rewarded = hand(getWinRanking(), Config.RAIDBOOK_MONTHLY_REWARDS, MODE_MONTHLY);

		clearWins();

		LOGGER.info("Handed out the raid book monthly rewards to {} player(s).", rewarded);
	}

	/**
	 * Hand out the rewards of one ladder.
	 * @param ranking : The already sorted ladder to read the winners off.
	 * @param rewards : What each rewarded position is given.
	 * @param kind : Which of the two rewards this is, which is what its winner is told about it.
	 * @return The amount of players which have been rewarded.
	 */
	private int hand(List<RankRow> ranking, Map<Integer, List<IntIntHolder>> rewards, int kind)
	{
		int rewarded = 0;

		for (Entry<Integer, List<IntIntHolder>> entry : rewards.entrySet())
		{
			final int place = entry.getKey();
			if (place > ranking.size())
				continue;

			final int objectId = ranking.get(place - 1).objectId();

			store(objectId, place, entry.getValue(), kind);
			rewarded++;

			// The winner may very well be online, and waiting for his next login to be told would read as a missing reward.
			final Player player = World.getInstance().getPlayer(objectId);
			if (player != null)
				deliver(player);
		}

		return rewarded;
	}

	/**
	 * Credit one more daily win to the {@link Player} which just topped the daily ladder.
	 * @param objectId : The objectId of that {@link Player}.
	 */
	private void addWin(int objectId)
	{
		final int wins = _wins.merge(objectId, 1, Integer::sum);

		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement ps = con.prepareStatement(SAVE_WIN))
		{
			ps.setInt(1, objectId);
			ps.setInt(2, wins);
			ps.executeUpdate();
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't save the raid book monthly win of the objectId {}.", e, objectId);
		}
	}

	/**
	 * Wipe the daily win ladder, which is what closes a month. The memory is only cleared once the table is, so a failed wipe leaves the board standing rather than losing it silently.
	 */
	private void clearWins()
	{
		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement ps = con.prepareStatement(CLEAR_WINS))
		{
			ps.executeUpdate();
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't wipe the raid book monthly wins ; they are kept, so the next month starts on the same board.", e);
			return;
		}

		_wins.clear();
	}

	private void store(int objectId, int place, List<IntIntHolder> items, int kind)
	{
		_pending.add(objectId);

		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement ps = con.prepareStatement(SAVE_PENDING))
		{
			for (IntIntHolder item : items)
			{
				ps.setInt(1, objectId);
				ps.setInt(2, place);
				ps.setInt(3, item.getId());
				ps.setInt(4, item.getValue());
				ps.setInt(5, kind);
				ps.addBatch();
			}
			ps.executeBatch();
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't store the raid book ladder reward of the objectId {}.", e, objectId);
		}
	}

	/**
	 * Hand a {@link Player} whatever daily reward has been waiting for him.
	 * @param player : The {@link Player} which just entered the world.
	 */
	public void onEnterWorld(Player player)
	{
		// Whoever owns nothing never touches the database, which is what keeps this off the login path.
		if (Config.RAIDBOOK_ENABLED && _pending.remove(player.getObjectId()))
			deliver(player);
	}

	private void deliver(Player player)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final List<PendingReward> rewards = new ArrayList<>();

		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement read = con.prepareStatement(READ_PENDING))
		{
			read.setInt(1, player.getObjectId());

			try (ResultSet rs = read.executeQuery())
			{
				while (rs.next())
					rewards.add(new PendingReward(rs.getInt("place"), rs.getInt("item_id"), rs.getInt("count"), rs.getInt("kind")));
			}
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't read the pending raid book daily reward of {}.", e, player.getName());

			// The rows are still there, so the reward isn't lost - it is simply handed out on the next login.
			_pending.add(player.getObjectId());
			return;
		}

		if (rewards.isEmpty())
			return;

		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement clear = con.prepareStatement(CLEAR_PENDING))
		{
			clear.setInt(1, player.getObjectId());
			clear.executeUpdate();
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't clear the pending raid book daily reward of {} ; it isn't handed out, to avoid handing it twice.", e, player.getName());

			_pending.add(player.getObjectId());
			return;
		}

		for (PendingReward reward : rewards)
		{
			player.addItem(reward.itemId(), reward.count(), true);

			final String message = (reward.kind() == MODE_MONTHLY) ? data.getMonthlyMessage() : data.getDailyMessage();

			inform(player, message.replace("%place%", String.valueOf(reward.place())).replace("%item%", getItemName(reward.itemId())).replace("%count%", StringUtil.formatNumber(reward.count())), true);
		}
	}

	/**
	 * Tell a {@link Player} about something the book just did for him. The chat always gets it ; the screen only gets what is worth interrupting him for, and only when the config allows it.
	 * @param player : The {@link Player} to tell.
	 * @param text : The already built message, an empty one being dropped - which is how a datapack silences a single message.
	 * @param onScreen : Whether the message is worth showing on the screen as well.
	 */
	private static void inform(Player player, String text, boolean onScreen)
	{
		if (text.isEmpty())
			return;

		player.sendMessage(text);

		if (onScreen && Config.RAIDBOOK_SCREEN_MESSAGES)
			player.sendPacket(new ExShowScreenMessage(text, RaidBookData.getInstance().getScreenTime()));
	}

	/**
	 * The damage bonus a {@link Player} earned by hunting one given raid boss. It is applied on the damage the boss takes rather than on the damage the attacker rolls, so it rides on top of every
	 * single damage source - hits, skills and damage over time alike.
	 * @param attacker : The {@link Creature} dealing the damage, its owner being the one holding the hunting levels.
	 * @param bossId : The npcId of the attacked raid boss.
	 * @return The multiplier the dealt damage is scaled by, 1 when the attacker owns no hunting level on that boss.
	 */
	public double getDamageMultiplier(Creature attacker, int bossId)
	{
		if (!Config.RAIDBOOK_ENABLED || Config.RAIDBOOK_DAMAGE_PER_LEVEL <= 0 || attacker == null)
			return 1.;

		final Player player = attacker.getActingPlayer();
		if (player == null)
			return 1.;

		final int level = getHuntLevel(getKills(player.getObjectId(), bossId));
		if (level <= 0)
			return 1.;

		return 1. + getDamageBonus(level) / 100.;
	}

	/**
	 * @param level : The hunting level to evaluate.
	 * @return The damage bonus, in percent, the given hunting level grants.
	 */
	private static double getDamageBonus(int level)
	{
		final double bonus = level * Config.RAIDBOOK_DAMAGE_PER_LEVEL;

		return (Config.RAIDBOOK_MAX_DAMAGE_BONUS > 0) ? Math.min(bonus, Config.RAIDBOOK_MAX_DAMAGE_BONUS) : bonus;
	}

	/**
	 * The hunting levels are endless out of the box : the first one is reached on the very first kill, and every {@link Config#RAIDBOOK_KILLS_PER_LEVEL} kills add one more.
	 * @param kills : The amount of kills of one {@link Player} on one raid boss.
	 * @return The hunting level such an amount of kills stands for, 0 meaning the boss has never been killed.
	 */
	public static int getHuntLevel(int kills)
	{
		if (kills <= 0)
			return 0;

		final int level = 1 + kills / Config.RAIDBOOK_KILLS_PER_LEVEL;

		return (Config.RAIDBOOK_MAX_LEVEL > 0) ? Math.min(level, Config.RAIDBOOK_MAX_LEVEL) : level;
	}

	/**
	 * @param level : The hunting level to evaluate.
	 * @return The amount of kills the given hunting level takes, 0 for the level 0.
	 */
	public static int getKillsForLevel(int level)
	{
		if (level <= 0)
			return 0;

		return (level == 1) ? 1 : (level - 1) * Config.RAIDBOOK_KILLS_PER_LEVEL;
	}

	/**
	 * Where the progress bar of a hunting level starts counting from.<br>
	 * <br>
	 * It is the amount of kills the level takes, with one exception : the level 1 counts from zero rather than from the very kill which granted it. That kill is worth a level <b>and</b> a step
	 * towards the next one - a bar reading 0/5 right after a raid boss went down reads as a kill which wasn't counted at all.
	 * @param level : The hunting level to evaluate.
	 * @return The amount of kills the bar of that level is counted from.
	 */
	private static int getLevelStart(int level)
	{
		return (level <= 1) ? 0 : getKillsForLevel(level);
	}

	/**
	 * @param level : The hunting level to evaluate.
	 * @return The items the given hunting level rewards - the ones listed for that very level, or the default reward when it holds none.
	 */
	public static List<IntIntHolder> getLevelReward(int level)
	{
		final List<IntIntHolder> items = Config.RAIDBOOK_LEVEL_REWARDS.get(level);

		return (items == null) ? Config.RAIDBOOK_DEFAULT_REWARD : items;
	}

	private int getKills(int objectId, int bossId)
	{
		final Map<Integer, HuntData> playerData = _hunts.get(objectId);
		if (playerData == null)
			return 0;

		final HuntData data = playerData.get(bossId);

		return (data == null) ? 0 : data.kills();
	}

	/**
	 * @param objectId : The objectId of the {@link Player} to check.
	 * @return The amount of ranking points that {@link Player} cumulated over every raid boss.
	 */
	private int getPoints(int objectId)
	{
		final Map<Integer, HuntData> playerData = _hunts.get(objectId);
		if (playerData == null)
			return 0;

		return playerData.values().stream().mapToInt(HuntData::points).sum();
	}

	/**
	 * @return The whole ladder, sorted by decreasing points, holding every {@link Player} owning at least one point.
	 */
	private List<RankRow> getRanking()
	{
		final List<RankRow> rows = new ArrayList<>();

		for (int objectId : _hunts.keySet())
		{
			final int points = getPoints(objectId);
			if (points > 0)
				rows.add(new RankRow(objectId, points));
		}

		rows.sort(Comparator.comparingInt(RankRow::score).reversed());

		return rows;
	}

	/**
	 * @return The monthly ladder, sorted by decreasing amount of daily wins, holding every {@link Player} owning at least one.
	 */
	private List<RankRow> getWinRanking()
	{
		final List<RankRow> rows = new ArrayList<>();

		for (Entry<Integer, Integer> entry : _wins.entrySet())
		{
			if (entry.getValue() > 0)
				rows.add(new RankRow(entry.getKey(), entry.getValue()));
		}

		rows.sort(Comparator.comparingInt(RankRow::score).reversed());

		return rows;
	}

	/**
	 * @param mode : Which of the two ladders to read.
	 * @return That ladder, already sorted.
	 */
	private List<RankRow> getRanking(int mode)
	{
		return (mode == MODE_MONTHLY) ? getWinRanking() : getRanking();
	}

	/**
	 * @param ranking : The already sorted ladder to walk.
	 * @param objectId : The objectId of the {@link Player} to look for.
	 * @return The position of that {@link Player} on the given ladder, 0 when he doesn't stand on it at all.
	 */
	private static int getRank(List<RankRow> ranking, int objectId)
	{
		for (int i = 0; i < ranking.size(); i++)
		{
			if (ranking.get(i).objectId() == objectId)
				return i + 1;
		}

		return 0;
	}

	/**
	 * @param objectId : The objectId of the {@link Player} to check.
	 * @return The score that {@link Player} holds on the monthly ladder, being the amount of days he topped the daily one.
	 */
	private int getWins(int objectId)
	{
		return _wins.getOrDefault(objectId, 0);
	}

	/**
	 * The date the next handout of a ladder reward is due, read off the very schedule the task runs on (data/xml/scripts.xml) rather than off a setting of its own - two places to write one date
	 * apart is one place too many.
	 * @param mode : Which of the two rewards to look at.
	 * @return That date, in milliseconds, 0 when the related script isn't scheduled at all.
	 */
	private static long getNextRewardTime(int mode)
	{
		final Quest quest = ScriptData.getInstance().getQuest((mode == MODE_MONTHLY) ? MONTHLY_SCRIPT : DAILY_SCRIPT);

		return (quest instanceof ScheduledQuest scheduled) ? scheduled.getTimeNext() : 0;
	}

	/**
	 * The clan of a ranked {@link Player} can't be read off his hunting record - he doesn't have to be online to be ranked - so it is looked up on the clan roster, which is fully held in memory.
	 * @return The clan name of every character belonging to one, keyed by objectId.
	 */
	private static Map<Integer, String> getClanNames()
	{
		final Map<Integer, String> names = new HashMap<>();

		for (Clan clan : ClanTable.getInstance().getClans())
		{
			for (ClanMember member : clan.getMembers())
				names.put(member.getObjectId(), clan.getName());
		}

		return names;
	}

	/**
	 * @param bossId : The npcId to look for.
	 * @return The kills of one raid boss, newest first, as a {@link List} safe to iterate.
	 */
	private List<KillRecord> getHistory(int bossId)
	{
		final Deque<KillRecord> records = _history.get(bossId);
		if (records == null)
			return List.of();

		synchronized (records)
		{
			return new ArrayList<>(records);
		}
	}

	/**
	 * @return Every raid boss template of the server, sorted by level and then by name - which is the order the book lists them in.
	 */
	private List<NpcTemplate> getBosses()
	{
		List<NpcTemplate> bosses = _bosses;
		if (bosses == null)
		{
			bosses = NpcData.getInstance().getTemplates().stream().filter(t -> t.isType("RaidBoss")).sorted(Comparator.comparingInt((NpcTemplate t) -> t.getLevel()).thenComparing(NpcTemplate::getName)).toList();

			_bosses = bosses;
		}

		return bosses;
	}

	/**
	 * A book opens empty and fills up as its owner meets the bosses : the very first hit on a raid boss writes it in, and it stays there afterwards. A list of every raid boss of the server tells a
	 * player nothing ; the list of the ones he actually fought is his own hunting record.
	 * @param player : The {@link Player} reading his book.
	 * @return The raid bosses that {@link Player} already laid a hand on, in the very order {@link #getBosses()} holds them.
	 */
	private List<NpcTemplate> getDiscovered(Player player)
	{
		final Map<Integer, HuntData> playerData = _hunts.get(player.getObjectId());
		if (playerData == null || playerData.isEmpty())
			return List.of();

		return getBosses().stream().filter(t -> playerData.containsKey(t.getNpcId())).toList();
	}

	public void reload()
	{
		_bosses = null;
	}

	/**
	 * Open the book on its first page.
	 * @param player : The {@link Player} to send the dialog to.
	 */
	public void show(Player player)
	{
		if (!Config.RAIDBOOK_ENABLED)
			return;

		showList(player, 0, 0, "");
	}

	/**
	 * Answer a link of an already shown page of the book.
	 * @param player : The {@link Player} which clicked.
	 * @param command : The bypass parameters, being a one letter action followed by its own arguments.
	 */
	public void handleBypass(Player player, String command)
	{
		if (!Config.RAIDBOOK_ENABLED)
			return;

		try
		{
			final StringTokenizer st = new StringTokenizer(command, " ");
			final String action = st.nextToken();

			// The search query is written last on every single bypass, and it is the only parameter which may hold spaces - so whatever is left once the numbers have been read is the query.
			switch (action)
			{
				case "l":
					showList(player, Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), getQuery(st));
					break;

				case "i":
					showDetail(player, Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), getQuery(st));
					break;

				case "f":
					final int searched = Integer.parseInt(st.nextToken());

					search(player, searched);
					showDetail(player, searched, Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), getQuery(st));
					break;

				case "x":
					final int cleared = Integer.parseInt(st.nextToken());

					clear(player);
					showDetail(player, cleared, Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), getQuery(st));
					break;

				case "r":
					showRanking(player, Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), getQuery(st));
					break;

				case "d":
					showRewards(player, Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), getQuery(st));
					break;
			}
		}
		catch (Exception e)
		{
			LOGGER.warn("Couldn't handle the raid book bypass '{}'.", e, command);
		}
	}

	/**
	 * Read the search query off the tail of a bypass. It is the one parameter a player writes himself - it travels back inside the bypass and it is written into the page afterwards - so it is
	 * stripped down to letters, digits and a handful of harmless characters rather than trusted : a quote or an angle bracket would break the page it lands on.
	 * @param st : The already walked bypass, standing on its last number.
	 * @return Whatever is left of the bypass, cleaned up and shortened to {@link Config#RAIDBOOK_SEARCH_CHARS}, an empty {@link String} meaning no search at all.
	 */
	private static String getQuery(StringTokenizer st)
	{
		final StringBuilder sb = new StringBuilder(32);

		while (st.hasMoreTokens())
		{
			if (sb.length() > 0)
				sb.append(' ');

			sb.append(st.nextToken());
		}

		final StringBuilder query = new StringBuilder(32);

		for (int i = 0; i < sb.length() && query.length() < Config.RAIDBOOK_SEARCH_CHARS; i++)
		{
			final char c = sb.charAt(i);

			if (Character.isLetterOrDigit(c) || QUERY_EXTRAS.indexOf(c) >= 0)
				query.append(c);
		}

		return query.toString().trim();
	}

	/**
	 * @param query : The already cleaned up search query.
	 * @return That query, as the tail every bypass of the book carries - an empty one costing nothing but a trailing space.
	 */
	private static String getContext(String query)
	{
		return (query.isEmpty()) ? "" : " " + query;
	}

	/**
	 * Drop a radar marker on the spawn point of a raid boss, which is what the arrow circling the character then points at. A boss standing in the world is marked where it actually stands ; any other
	 * one is marked on the spot it spawns at.
	 * @param player : The {@link Player} to mark the map of.
	 * @param bossId : The npcId of the raid boss to look for.
	 */
	private static void search(Player player, int bossId)
	{
		final RaidBookData data = RaidBookData.getInstance();

		Location loc = null;

		final Npc npc = SpawnManager.getInstance().getNpc(bossId);
		if (npc != null && !npc.isDead())
			loc = npc.getPosition();
		else
		{
			final ASpawn spawn = SpawnManager.getInstance().getSpawn(bossId);
			if (spawn != null)
				loc = spawn.getSpawnLocation();
		}

		if (loc == null)
		{
			inform(player, data.getNoLocationLabel(), true);
			return;
		}

		player.getRadarList().addMarker(loc.getX(), loc.getY(), loc.getZ());

		inform(player, data.getSearchDoneLabel(), true);
	}

	/**
	 * Take the radar marker back off the map, which is what the "clear" link sitting next to the search one does : a marker outlives the page it was dropped from, and the arrow circling the character
	 * keeps pointing at a boss he stopped caring about otherwise.<br>
	 * <br>
	 * Every marker goes, not only the one of the shown boss : {@link net.sf.l2j.gameserver.model.actor.container.player.RadarList#addMarker(int, int, int)} wipes the map before dropping its own, so
	 * the marker of the book is the only one standing anyway.
	 * @param player : The {@link Player} to clear the map of.
	 */
	private static void clear(Player player)
	{
		player.getRadarList().removeAllMarkers();

		inform(player, RaidBookData.getInstance().getClearDoneLabel(), true);
	}

	/**
	 * Generate and send the main page of the book : the ranking position of the {@link Player} on its head, the search box and the level filter menu right under it, then one row per raid boss.
	 * @param player : The {@link Player} to send the dialog to.
	 * @param filter : The index of the shown level filter.
	 * @param page : The page index to show.
	 * @param query : The search query, an empty one listing everything the level filter allows.
	 */
	private void showList(Player player, int filter, int page, String query)
	{
		final RaidBookData data = RaidBookData.getInstance();

		filter = Math.min(Math.max(filter, 0), data.getFilters().size() - 1);

		final LevelFilter levelFilter = data.getFilter(filter);

		// The search runs over the bosses this very player already met - a handful of templates already sitting in memory, sorted once at startup - so it costs one walk of that list and nothing
		// else : no database, no world lookup, no index to keep.
		final String needle = query.toLowerCase();
		final List<NpcTemplate> bosses = getDiscovered(player).stream().filter(t -> levelFilter.matches(t.getLevel()) && (needle.isEmpty() || t.getName().toLowerCase().contains(needle))).toList();

		final int perPage = data.getRowsPerPage();
		final int pages = Math.max(1, (bosses.size() + perPage - 1) / perPage);

		page = Math.min(Math.max(page, 0), pages - 1);

		final int first = page * perPage;
		final int last = Math.min(bosses.size(), first + perPage);

		final StringBuilder sb = new StringBuilder(4096);

		if (bosses.isEmpty())
			sb.append(getEmptyRow(data.getRowHeight()));

		// The filter menu right above is drawn on the plain band color, so the list starts on the other one rather than stacking two identical blocks.
		int band = 1;

		for (int i = first; i < last; i++)
			sb.append(getBossRow(player, bosses.get(i), filter, page, query).replace(BAND, getBandAttribute(band++)));

		final int shown = Math.max(1, last - first);

		// The page selector is built by a lambda, so the browsed range has to be handed to it as a final.
		final int index = filter;
		final String tail = getContext(query);

		String content = HtmCache.getInstance().getHtmForce(LIST_HTM);
		content = content.replace("%title%", escape(data.getBookTitle()));
		content = content.replace("%header%", getListHeader(player, filter, page, query));
		content = content.replace("%search%", getSearchRow(index, query));
		content = content.replace("%filters%", getFilters(index, query));
		content = content.replace("%list%", sb.toString());
		content = content.replace("%footer%", getFooter(page, pages, p -> getBypass("l " + index + " " + p + tail)));
		content = content.replace("%filler%", getFiller(getBlockHeight() + getBlockHeight() + getSearchHeight() + shown * data.getRowHeight()));
		content = content.replace("%width%", String.valueOf(data.getWidth()));

		send(player, content);
	}

	/**
	 * The search box sitting between the head of the main list and the level filter menu : a field to write a name in, the button firing the search, and - once a search is running - what is being
	 * searched for, along with the link dropping it.<br>
	 * <br>
	 * The typed text reaches the server as the tail of the bypass of the button, which is what the "$" of an "edit" variable does. The client only ever sends the prefix standing in front of that
	 * "$" as the bypass to validate, so such a bypass passes {@link Player#validateBypass(String)} on its prefix - see {@link net.sf.l2j.gameserver.network.serverpackets.NpcHtmlMessage}.
	 * @param filter : The index of the shown level filter, which a search doesn't change.
	 * @param query : The running search query, an empty one meaning none.
	 * @return The search row.
	 */
	private static String getSearchRow(int filter, String query)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final int width = data.getWidth();
		final int inputWidth = Math.max(1, Math.min(width - 3, data.getSearchInputWidth()));
		final int buttonWidth = Math.max(1, Math.min(width - inputWidth - 2, data.getSearchButtonWidth()));

		// The link dropping the search owns a cell of its own, the way the one of a detail page does : written right after the query, it would read as the last letter of what is being searched for.
		final int clearWidth = Math.max(1, Math.min(width - inputWidth - buttonWidth - 1, data.getPageWidth()));
		final int queryWidth = Math.max(1, width - inputWidth - buttonWidth - clearWidth);

		// The field owns a variable of its own, and the button hands its content over as the tail of the bypass.
		final String field = "<edit var=\"q\" width=" + Math.max(1, inputWidth - 4) + " height=" + data.getSearchHeight() + ">";
		final String button = "<button value=\"" + escape(data.getSearchNameLabel()) + "\" action=\"bypass -h " + getBypass("l " + filter + " 0 $q") + "\" width=" + Math.max(1, buttonWidth - 4) + " height=" + data.getSearchHeight() + " back=\"" + data.getButtonBack() + "\" fore=\"" + data.getButtonFore() + "\">";

		// Whatever is being searched for is written next to the box, since the client can't be asked to keep it inside the field itself. It is cut down to what its cell holds - the query is allowed
		// to be far longer than that, and a wrapped line would make the whole row taller.
		final String running = (query.isEmpty()) ? "" : colorize(data.getValueColor(), escape(truncate(query, Math.max(1, queryWidth / 6))));
		final String clear = (query.isEmpty()) ? "" : getLink(getBypass("l " + filter + " 0"), data.getClearLabel(), data.getTabColor());

		final StringBuilder sb = new StringBuilder(512);

		StringUtil.append(sb, getRowStart(data.getRowColor()));
		StringUtil.append(sb, getCell(inputWidth, data.getSearchRowHeight(), data.getSearchFieldAlign(), field));
		StringUtil.append(sb, getCell(buttonWidth, 0, data.getMenuAlign(), button));
		StringUtil.append(sb, getCell(queryWidth, 0, data.getSearchQueryAlign(), running));
		StringUtil.append(sb, getCell(clearWidth, 0, data.getMenuAlign(), clear));
		StringUtil.append(sb, ROW_END);
		sb.append(getSeparator());

		return sb.toString();
	}

	/**
	 * @return The height, in pixels, the search row takes, the rule closing it included.
	 */
	private static int getSearchHeight()
	{
		final RaidBookData data = RaidBookData.getInstance();

		return data.getSearchRowHeight() + ((data.getSeparator().isEmpty()) ? 0 : SEPARATOR_HEIGHT);
	}

	/**
	 * The head of the main page, telling the very {@link Player} where he stands on the server wide ladder and linking to it.
	 * @param player : The {@link Player} the position is computed for.
	 * @param filter : The index of the shown level filter, so the ladder knows where to come back to.
	 * @param page : The shown page index, for the same reason.
	 * @return The header block, closed by the rule cutting the page into blocks.
	 */
	private String getListHeader(Player player, int filter, int page, String query)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final int rank = getRank(getRanking(), player.getObjectId());
		final int points = getPoints(player.getObjectId());

		final int width = data.getWidth();
		final int linkWidth = Math.max(1, Math.min(width - 2, data.getListButtonWidth()));
		final int pointsWidth = Math.max(1, (width - linkWidth) / 2);

		final StringBuilder sb = new StringBuilder(512);

		StringUtil.append(sb, getRowStart(data.getRowColor()));
		StringUtil.append(sb, getCell(Math.max(1, width - linkWidth - pointsWidth), data.getGroupHeight(), data.getHeaderRankAlign(), colorize(data.getLabelColor(), escape(data.getRankPrefix())) + colorize(data.getValueColor(), (rank > 0) ? String.valueOf(rank) : escape(data.getUnrankedLabel()))));
		StringUtil.append(sb, getCell(pointsWidth, 0, data.getHeaderPointsAlign(), colorize(data.getCountColor(), StringUtil.formatNumber(points) + escape(data.getPointsLabel()))));
		StringUtil.append(sb, getCell(linkWidth, 0, data.getHeaderLinkAlign(), getLink(getBypass("r " + filter + " " + page + " 0 " + MODE_DAILY + getContext(query)), data.getRankLabel(), data.getTabColor())));
		StringUtil.append(sb, ROW_END);
		sb.append(getSeparator());

		return sb.toString();
	}

	/**
	 * @return The height, in pixels, of one single line block - a header, a menu or a button row - the rule closing it included.
	 */
	private static int getBlockHeight()
	{
		final RaidBookData data = RaidBookData.getInstance();

		return data.getGroupHeight() + ((data.getSeparator().isEmpty()) ? 0 : SEPARATOR_HEIGHT);
	}

	/**
	 * The level filter menu, drawn as one cell per range. The shown range is written with the active color instead of being a link, so a player always reads which one he browses.<br>
	 * <br>
	 * Picking a range always lands on its first page : the boss which sat on the browsed page isn't in the new range.
	 * @param filter : The index of the shown level filter.
	 * @return The filter row, closed by the rule cutting the page into blocks.
	 */
	private static String getFilters(int filter, String query)
	{
		final RaidBookData data = RaidBookData.getInstance();
		final List<LevelFilter> filters = data.getFilters();

		// A range is picked while a search is running, so the search rides along rather than being dropped under the player.
		final String tail = getContext(query);

		final int cellWidth = Math.max(1, data.getWidth() / filters.size());

		final StringBuilder sb = new StringBuilder(512);

		StringUtil.append(sb, getRowStart(data.getRowColor()));

		for (int i = 0; i < filters.size(); i++)
		{
			// The last cell takes whatever is left of the layout width, which absorbs the rounding of an uneven division.
			final int width = (i == filters.size() - 1) ? Math.max(1, data.getWidth() - i * cellWidth) : cellWidth;
			final String label = escape(filters.get(i).label());

			StringUtil.append(sb, getCell(width, data.getGroupHeight(), data.getMenuAlign(), (i == filter) ? colorize(data.getActiveFilterColor(), label) : getLink(getBypass("l " + i + " 0" + tail), filters.get(i).label(), data.getFilterColor())));
		}

		StringUtil.append(sb, ROW_END);
		sb.append(getSeparator());

		return sb.toString();
	}

	/**
	 * One row of the main page, rendered as two stacked tables sharing one background color, which is what makes them read as a single striped row.<br>
	 * <br>
	 * The first one holds the name and the level of the raid boss, the hunting level and the link to the detail page. The second one is the progress bar and its counter : a bar is built out of cells
	 * (see {@link #getBarCells(int, int)}), so it can't share a table with text sitting in columns of its own.
	 * @param player : The {@link Player} the hunting record is read for.
	 * @param template : The raid boss to render.
	 * @param filter : The index of the shown level filter, carried over to the detail page.
	 * @param page : The shown page index, carried over for the same reason.
	 * @return The whole row, its background color left as the {@link #BAND} placeholder - on both of its tables.
	 */
	private String getBossRow(Player player, NpcTemplate template, int filter, int page, String query)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final int kills = getKills(player.getObjectId(), template.getNpcId());
		final int level = getHuntLevel(kills);

		// The two lines share the row height ; the bar takes whatever the text line leaves.
		final int nameHeight = Math.max(1, Math.min(data.getGroupHeight(), data.getRowHeight() - 1));
		final int barHeight = Math.max(1, data.getRowHeight() - nameHeight);

		// The name shares its line with the level of the boss, so it gets a tighter limit than the item and character names, which own their column whole.
		final String name = colorize(data.getNameColor(), escape(truncate(template.getName(), data.getBossNameChars()))) + " " + colorize(data.getBossLevelColor(), escape(data.getLevelPrefix()) + template.getLevel());

		final StringBuilder sb = new StringBuilder(1024);

		StringUtil.append(sb, getRowStart());
		StringUtil.append(sb, getCell(data.getListNameWidth(), nameHeight, data.getListNameAlign(), name));
		StringUtil.append(sb, getCell(data.getListLevelWidth(), 0, data.getListLevelAlign(), colorize(data.getHuntLevelColor(), escape(data.getHuntLevelPrefix()) + level)));
		StringUtil.append(sb, getCell(data.getListButtonWidth(), 0, data.getListButtonAlign(), getLink(getBypass("i " + template.getNpcId() + " " + TAB_REWARDS + " 0 " + filter + " " + page + getContext(query)), data.getDetailsLabel(), data.getTabColor())));
		StringUtil.append(sb, ROW_END);

		StringUtil.append(sb, getRowStart());
		StringUtil.append(sb, getBarCells(kills, barHeight, false));
		StringUtil.append(sb, ROW_END);

		return sb.toString();
	}

	/**
	 * Generate and send the detail page of one raid boss.
	 * @param player : The {@link Player} to send the dialog to.
	 * @param bossId : The npcId of the shown raid boss.
	 * @param tab : The index of the shown tab.
	 * @param page : The page index of the shown tab.
	 * @param filter : The index of the level filter the list was showing.
	 * @param listPage : The page index the list was showing.
	 * @param query : The search query the list was showing.
	 */
	private void showDetail(Player player, int bossId, int tab, int page, int filter, int listPage, String query)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final NpcTemplate template = NpcData.getInstance().getTemplate(bossId);
		if (template == null || !template.isType("RaidBoss"))
		{
			inform(player, data.getNotFoundLabel(), true);
			return;
		}

		tab = Math.min(Math.max(tab, 0), TAB_COUNT - 1);

		final TabContent content = getTabContent(player, template, tab);
		final List<TabRow> rows = content.rows();

		// The reward tab shows the coming levels as one single block, so it holds every row it owns whatever their amount.
		final int perPage = (content.paged()) ? Config.RAIDBOOK_TAB_ROWS_PER_PAGE : Math.max(1, rows.size());
		final int pages = Math.max(1, (rows.size() + perPage - 1) / perPage);

		page = Math.min(Math.max(page, 0), pages - 1);

		final int first = page * perPage;
		final int last = Math.min(rows.size(), first + perPage);

		final StringBuilder sb = new StringBuilder(4096);

		// The column header is drawn once on top of the list rather than sliced along with it, so it stays readable whatever page is browsed.
		sb.append(content.columns());

		if (rows.isEmpty())
			sb.append(getEmptyRow(data.getGroupHeight()));

		// The tab menu - and the column header when there is one - is drawn on the plain band color, so the content starts on the other one.
		int band = 1;
		int shownGroups = 0;
		int shownGroup = -2;

		for (int i = first; i < last; i++)
		{
			final TabRow row = rows.get(i);

			// A group spanning several pages gets its header again on each of them, so a page never opens on an orphan row.
			if (row.group() >= 0 && row.group() != shownGroup)
			{
				sb.append(getSeparator());
				sb.append(content.headers().get(row.group()).replace(BAND, getBandAttribute(band++)));
				sb.append(getSeparator());

				shownGroups++;
				shownGroup = row.group();
			}

			sb.append(row.html().replace(BAND, getBandAttribute(band++)));
		}

		final int shown = Math.max(1, last - first);
		final int shownTab = tab;

		final int groupHeight = data.getGroupHeight() + ((data.getSeparator().isEmpty()) ? 0 : 2 * SEPARATOR_HEIGHT);
		final String tail = getContext(query);
		final String context = " " + shownTab + " " + page + " " + filter + " " + listPage + tail;

		String html = HtmCache.getInstance().getHtmForce(DETAIL_HTM);
		html = html.replace("%title%", escape(template.getName()) + escape(data.getTitleSeparator()) + escape(data.getLevelPrefix()) + template.getLevel());
		html = html.replace("%stats%", getStats(player, template));
		html = html.replace("%hunt%", getHunt(player, bossId));
		html = html.replace("%buttons%", getDetailButtons(bossId, context, filter, listPage, tail));
		html = html.replace("%tabs%", getTabs(bossId, shownTab, filter, listPage, tail));
		html = html.replace("%content%", sb.toString());
		html = html.replace("%footer%", getFooter(page, pages, p -> getBypass("i " + bossId + " " + shownTab + " " + p + " " + filter + " " + listPage + tail)));
		html = html.replace("%filler%", getFiller(getStatsHeight() + getHuntHeight() + data.getGroupHeight() + getBlockHeight() + getColumnsHeight(content.columns()) + shownGroups * groupHeight + shown * data.getGroupHeight()));
		html = html.replace("%width%", String.valueOf(data.getWidth()));

		send(player, html);
	}

	/**
	 * The statistics block of a detail page, laid out the way the status window of a {@link Player} is - two blocks of two columns - so a player reads a raid boss the same way he reads himself.<br>
	 * <br>
	 * Every number is computed out of the template rather than out of a live instance : a boss which is dead, or simply not spawned yet, has to be readable too. That is the very formula
	 * {@link net.sf.l2j.gameserver.model.actor.status.CreatureStatus} runs, minus the temporary buffs a spawned boss could be carrying.
	 * @param player : The {@link Player} the rewards are computed for - the level gap penalty is his own.
	 * @param template : The raid boss to describe.
	 * @return The statistics block, closed by the rule cutting the page into blocks.
	 */
	private String getStats(Player player, NpcTemplate template)
	{
		final RaidBookData data = RaidBookData.getInstance();
		final BossStats stats = getBossStats(template, player.getStatus().getLevel());

		final StringBuilder sb = new StringBuilder(1536);

		// The block opens on a caption band of its own, the way the shift click window names the very same statistics.
		if (!data.getStatsTitle().isEmpty())
		{
			sb.append(getBand(data.getStatsTitle()));
			sb.append(getSeparator());
		}

		sb.append(getBlockStart());
		sb.append(getStatRow(data.getHpLabel(), stats.hp(), data.getExpLabel(), stats.exp()));
		sb.append(getStatRow(data.getMpLabel(), stats.mp(), data.getSpLabel(), stats.sp()));

		// The two halves of one question - when the boss can be hunted again : the window it comes back in, and when it went down for the last time. The date is the longest value of the whole block
		// - a day and an hour - so its caption is given a cell of its own rather than the wide one every other caption sits in.
		sb.append(getStatRow(data.getRespawnLabel(), getRespawnText(template.getNpcId()), data.getLastKillLabel(), getLastKillText(template.getNpcId()), data.getLastKillWidth()));
		sb.append("</table>");
		sb.append(getSeparator());

		sb.append(getBlockStart());
		sb.append(getStatRow(data.getPAtkLabel(), stats.pAtk(), data.getMAtkLabel(), stats.mAtk()));
		sb.append(getStatRow(data.getPDefLabel(), stats.pDef(), data.getMDefLabel(), stats.mDef()));
		sb.append(getStatRow(data.getAtkSpdLabel(), stats.atkSpd(), data.getCastSpdLabel(), stats.castSpd()));
		sb.append("</table>");
		sb.append(getSeparator());

		return sb.toString();
	}

	/**
	 * The window a raid boss respawns in, written in hours : a hunter reads a raid boss for when it comes back, and the spawn holds a fixed delay plus a random spread on both of its sides.
	 * @param bossId : The npcId of the raid boss to read.
	 * @return The respawn window, as a single value when the spawn holds no random spread at all, and the "respawnUnknown" label for a boss owning no spawn point.
	 */
	private static String getRespawnText(int bossId)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final ASpawn spawn = SpawnManager.getInstance().getSpawn(bossId);
		if (spawn == null || spawn.getRespawnDelay() <= 0)
			return escape(data.getRespawnUnknown());

		final int random = Math.min(spawn.getRespawnRandom(), spawn.getRespawnDelay());

		final DecimalFormat format = new DecimalFormat(data.getRespawnPattern(), NUMBER_SYMBOLS);

		final String window = (random <= 0) ? format.format((spawn.getRespawnDelay()) / 3600.) : format.format((spawn.getRespawnDelay() - random) / 3600.) + escape(data.getRespawnRange()) + format.format((spawn.getRespawnDelay() + random) / 3600.);

		return window + escape(data.getRespawnSuffix());
	}

	/**
	 * When a raid boss went down for the last time, which is the other half of the respawn question : a window means nothing without the moment it is counted from.<br>
	 * <br>
	 * It is read off the kill history of the boss, which is already held in memory, newest first - so it is the last kill of the server rather than the last kill of the reader.
	 * @param bossId : The npcId of the raid boss to read.
	 * @return That date, and the "lastKillNever" label for a boss nobody ever killed.
	 */
	private String getLastKillText(int bossId)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final List<KillRecord> history = getHistory(bossId);
		if (history.isEmpty())
			return escape(data.getLastKillNever());

		return escape(new SimpleDateFormat(data.getTimePattern()).format(new Date(history.get(0).time())));
	}

	/**
	 * @param template : The raid boss to read.
	 * @param playerLevel : The level the experience and the SP are computed for.
	 * @return The statistics of the given raid boss. The defences carry {@link Config#RAID_DEFENCE_MULTIPLIER}, the rewards carry the server rates and the level gap penalty of a solo kill dealing the
	 *         whole damage - the very reward path of a real kill, minus the over-hit and the party sharing, which are circumstances rather than properties of the boss.
	 */
	private static BossStats getBossStats(NpcTemplate template, int playerLevel)
	{
		final int level = template.getLevel();

		double exp = template.getRewardExp() * Config.RATE_XP;
		double sp = template.getRewardSp() * Config.RATE_SP;

		final int diff = playerLevel - level;
		if (diff > 5)
		{
			final double pow = Math.pow(5 / 6., diff - 5);

			exp *= pow;
			sp *= pow;
		}

		if (exp <= 0)
		{
			exp = 0;
			sp = 0;
		}
		else if (sp <= 0)
			sp = 0;

		return new BossStats((long) template.getBaseHpMax(level), (long) template.getBaseMpMax(level), (long) exp, (long) sp, (int) template.getBasePAtk(), (int) (template.getBasePDef() * Config.RAID_DEFENCE_MULTIPLIER), (int) template.getBasePAtkSpd(), (int) template.getBaseMAtk(), (int) (template.getBaseMDef() * Config.RAID_DEFENCE_MULTIPLIER), 333);
	}

	/**
	 * The hunting block of a detail page : the hunting level and the amount of kills on the first line, the damage bonus and what the next level takes on the second one, then the progress bar and its
	 * counter on a row of their own - a bar is built out of cells, so it can't share a table with the two columns block sitting above it.
	 * @param player : The {@link Player} the hunting record is read for.
	 * @param bossId : The npcId of the shown raid boss.
	 * @return The hunting block, closed by the rule cutting the page into blocks.
	 */
	private String getHunt(Player player, int bossId)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final int kills = getKills(player.getObjectId(), bossId);
		final int level = getHuntLevel(kills);
		final int next = getKillsForLevel(level + 1) - kills;

		final boolean capped = Config.RAIDBOOK_MAX_LEVEL > 0 && level >= Config.RAIDBOOK_MAX_LEVEL;

		final StringBuilder sb = new StringBuilder(1024);

		// The hunting block is a section of its own, so it opens on its own caption band - the way the statistics sitting right above it do.
		if (!data.getHuntTitle().isEmpty())
		{
			sb.append(getBand(data.getHuntTitle()));
			sb.append(getSeparator());
		}

		sb.append(getBlockStart());
		sb.append(getStatRow(data.getHuntLabel(), String.valueOf(level), data.getKillsLabel(), String.valueOf(kills)));
		// The damage bonus is a percentage too, so it is written with the very pattern and suffix a drop chance is.
		sb.append(getStatRow(data.getBonusLabel(), format(getDamageBonus(level)) + escape(data.getChanceSuffix()), data.getNextLevelLabel(), (capped) ? escape(data.getMaxLevelLabel()) : String.valueOf(Math.max(0, next))));
		sb.append("</table>");

		// A detail page shows one single boss, so its bar owns the middle of the row rather than starting on the left edge the way a list row does.
		StringUtil.append(sb, getRowStart(data.getRowColor()));
		StringUtil.append(sb, getBarCells(kills, data.getGroupHeight(), true));
		StringUtil.append(sb, ROW_END);

		sb.append(getSeparator());

		return sb.toString();
	}

	/**
	 * @return The height, in pixels, the statistics block of a detail page takes - its caption band, its rows and the rules cutting it apart and closing it.
	 */
	private static int getStatsHeight()
	{
		final RaidBookData data = RaidBookData.getInstance();

		return STATS_ROWS * data.getHeaderHeight() + getBandHeight(data.getStatsTitle()) + ((data.getSeparator().isEmpty()) ? 0 : 2 * SEPARATOR_HEIGHT);
	}

	/**
	 * @return The height, in pixels, the hunting block of a detail page takes - its caption band, its rows, the progress bar row and the closing rule.
	 */
	private static int getHuntHeight()
	{
		final RaidBookData data = RaidBookData.getInstance();

		return HUNT_ROWS * data.getHeaderHeight() + data.getGroupHeight() + getBandHeight(data.getHuntTitle()) + ((data.getSeparator().isEmpty()) ? 0 : SEPARATOR_HEIGHT);
	}

	/**
	 * A band the datapack silenced doesn't take any room at all, and neither does the rule closing it - a height read out of a band which isn't drawn would throw the bottom padding of the page off.
	 * @param caption : The caption of the band, an empty one meaning no band at all.
	 * @return The height, in pixels, the given caption band takes, the rule closing it included.
	 */
	private static int getBandHeight(String caption)
	{
		final RaidBookData data = RaidBookData.getInstance();

		return (caption.isEmpty()) ? 0 : data.getTitleHeight() + ((data.getSeparator().isEmpty()) ? 0 : SEPARATOR_HEIGHT);
	}

	/**
	 * One full width band naming the section opening under it, drawn on the plain band color the blocks of a page use - the very way the shift click window opens its own statistics.
	 * @param caption : The datapack caption to write.
	 * @return The band, rendered as its own table.
	 */
	private static String getBand(String caption)
	{
		return getBandContent(escape(caption), RaidBookData.getInstance().getTitleAlign());
	}

	/**
	 * @param content : The already escaped content of the band, which lets a band hold something built out of several labels.
	 * @param align : The alignment of that content. A band naming a section lines up with the captions of the group headers, where the one dating the next reward stands on its own.
	 * @return The band, rendered as its own table.
	 */
	private static String getBandContent(String content, String align)
	{
		final RaidBookData data = RaidBookData.getInstance();

		return getBlockStart() + "<tr>" + getCell(data.getWidth(), data.getTitleHeight(), align, colorize(data.getTitleColor(), content)) + ROW_END;
	}

	/**
	 * The button row of a detail page : the way back to the list on the left, the radar marker on the right, and the link taking that marker back off the map right next to it - a marker outlives the
	 * page it was dropped from, so dropping one has to be as reachable as undoing it.
	 * @param bossId : The npcId of the shown raid boss.
	 * @param context : The tab, page, filter and list page both marker links have to come back to.
	 * @param filter : The index of the level filter the list was showing.
	 * @param listPage : The page index the list was showing.
	 * @return The button row.
	 */
	private static String getDetailButtons(int bossId, String context, int filter, int listPage, String tail)
	{
		final RaidBookData data = RaidBookData.getInstance();

		// The "clear" link is a single character sitting next to the search one, so it takes a cell of the width of a page selector one rather than a third of the row.
		final int clearWidth = Math.max(1, Math.min(data.getWidth() - 2, data.getPageWidth()));
		final int half = Math.max(1, (data.getWidth() - clearWidth) / 2);

		final StringBuilder sb = new StringBuilder(512);

		StringUtil.append(sb, getRowStart(data.getRowColor()));
		StringUtil.append(sb, getCell(half, data.getGroupHeight(), data.getMenuAlign(), getLink(getBypass("l " + filter + " " + listPage + tail), data.getBackLabel(), data.getTabColor())));
		StringUtil.append(sb, getCell(Math.max(1, data.getWidth() - half - clearWidth), 0, data.getMenuAlign(), getLink(getBypass("f " + bossId + context), data.getSearchLabel(), data.getActiveTabColor())));
		StringUtil.append(sb, getCell(clearWidth, 0, data.getMenuAlign(), getLink(getBypass("x " + bossId + context), data.getClearLabel(), data.getTabColor())));
		StringUtil.append(sb, ROW_END);

		return sb.toString();
	}

	/**
	 * The tab menu of a detail page. The shown tab is written with the active color instead of being a link, so a player always reads which one he browses.
	 * @param bossId : The npcId of the shown raid boss.
	 * @param tab : The index of the shown tab.
	 * @param filter : The index of the level filter the list was showing.
	 * @param listPage : The page index the list was showing.
	 * @return The tab row, closed by the rule cutting the page into blocks.
	 */
	private static String getTabs(int bossId, int tab, int filter, int listPage, String tail)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final String[] labels =
		{
			data.getTabRewardsLabel(),
			data.getTabDropLabel(),
			data.getTabHistoryLabel(),
			data.getTabRankLabel()
		};

		final int cellWidth = Math.max(1, data.getWidth() / TAB_COUNT);

		final StringBuilder sb = new StringBuilder(512);

		StringUtil.append(sb, getRowStart(data.getRowColor()));

		for (int i = 0; i < TAB_COUNT; i++)
		{
			// The last cell takes whatever is left of the layout width, which absorbs the rounding of an uneven division.
			final int width = (i == TAB_COUNT - 1) ? Math.max(1, data.getWidth() - i * cellWidth) : cellWidth;

			StringUtil.append(sb, getCell(width, data.getGroupHeight(), data.getMenuAlign(), (i == tab) ? colorize(data.getActiveTabColor(), escape(labels[i])) : getLink(getBypass("i " + bossId + " " + i + " 0 " + filter + " " + listPage + tail), labels[i], data.getTabColor())));
		}

		StringUtil.append(sb, ROW_END);
		sb.append(getSeparator());

		return sb.toString();
	}

	/**
	 * @param player : The {@link Player} the rows are rendered for.
	 * @param template : The shown raid boss.
	 * @param tab : The index of the shown tab.
	 * @return The already rendered content of the given tab, which is what the paging then slices.
	 */
	private TabContent getTabContent(Player player, NpcTemplate template, int tab)
	{
		switch (tab)
		{
			case TAB_DROP:
				return getDropContent(player, template);

			case TAB_HISTORY:
				return getHistoryContent(template.getNpcId());

			case TAB_RANK:
				return getBossRankContent(player, template.getNpcId());

			default:
				return getRewardContent(player, template.getNpcId());
		}
	}

	/**
	 * The rewards tab : the coming hunting levels and what each of them gives. It opens on the very next level rather than on the first one - what a player reads a reward list for is what he is about
	 * to earn - and it isn't paged, so the whole outlook is read in one go.
	 * @param player : The {@link Player} the hunting record is read for.
	 * @param bossId : The npcId of the shown raid boss.
	 * @return One row per rewarded item, an item of a level owning a row of its own.
	 */
	private TabContent getRewardContent(Player player, int bossId)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final int level = getHuntLevel(getKills(player.getObjectId(), bossId));

		final List<TabRow> rows = new ArrayList<>();

		for (int i = 1; i <= Config.RAIDBOOK_SHOWN_REWARDS; i++)
		{
			final int shown = level + i;
			if (Config.RAIDBOOK_MAX_LEVEL > 0 && shown > Config.RAIDBOOK_MAX_LEVEL)
				break;

			for (IntIntHolder item : getLevelReward(shown))
			{
				final StringBuilder sb = new StringBuilder(512);

				StringUtil.append(sb, getRowStart());
				StringUtil.append(sb, getCell(data.getRewardIconWidth(), data.getGroupHeight(), data.getRewardIconAlign(), getIcon(item.getId())));
				StringUtil.append(sb, getCell(data.getRewardNameWidth(), 0, data.getRewardNameAlign(), colorize(data.getNameColor(), escape(truncate(getItemName(item.getId()), data.getNameChars()))) + " " + colorize(data.getCountColor(), escape(data.getCountPrefix()) + StringUtil.formatNumber(item.getValue()))));
				StringUtil.append(sb, getCell(data.getRewardLevelWidth(), 0, data.getRewardLevelAlign(), colorize(data.getHuntLevelColor(), escape(data.getLevelPrefix()) + shown)));
				StringUtil.append(sb, ROW_END);

				rows.add(new TabRow(sb.toString(), -1));
			}
		}

		return new TabContent("", rows, List.of(), false);
	}

	/**
	 * The drop tab : the drop list of the raid boss, cut into groups the way the shift click window is - one header per drop category, holding its caption and the chance the whole group rolls,
	 * followed by its items sorted by decreasing chance. The groups themselves are sorted by decreasing chance.<br>
	 * <br>
	 * The shown chance is the chance of the whole draw : the category rolls first, the item is then picked inside of it. The server rates are folded in when "RaidBookApplyRates" is set - they multiply
	 * the amount of rolls of a category, so the result is capped at 100% - and the deep blue penalty of the very {@link Player} reading the book when "RaidBookApplyLevelPenalty" is. The spoil
	 * categories are left out : a raid boss isn't spoiled.
	 * @param player : The {@link Player} the chances are computed for.
	 * @param template : The shown raid boss.
	 * @return One row per dropped item, each pointing at the group it belongs to.
	 */
	private static TabContent getDropContent(Player player, NpcTemplate template)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final double levelMultiplier = (Config.RAIDBOOK_APPLY_LEVEL_PENALTY) ? getLevelMultiplier(player.getStatus().getLevel(), template.getLevel()) : 1;

		// The chance of a group, and the rows it holds ; both are needed before anything is rendered, since the groups are sorted by their own chance.
		final List<Double> chances = new ArrayList<>();
		final List<List<DropRow>> groups = new ArrayList<>();

		for (DropCategory category : template.getDropData())
		{
			if (category.isEmpty() || category.getDropType() == DropType.SPOIL)
				continue;

			final double rate = (Config.RAIDBOOK_APPLY_RATES) ? category.getDropType().getDropRate(true) : 1;

			// A rate is an amount of rolls of the category, not a multiplier of its chance ; a category rolled more than once is simply shown as a certain one.
			final double chance = Math.min(100, category.getChance() * levelMultiplier * rate);

			final List<DropRow> rows = new ArrayList<>(category.size());

			for (DropData drop : category)
				rows.add(new DropRow(drop.itemId(), Math.min(100, chance * drop.chance() / 100), drop.minDrop(), drop.maxDrop()));

			rows.sort(Comparator.<DropRow> comparingDouble(DropRow::chance).reversed());

			chances.add(chance);
			groups.add(rows);
		}

		// Sort the groups by decreasing chance, keeping every group next to its own chance.
		final List<Integer> order = new ArrayList<>();
		for (int i = 0; i < groups.size(); i++)
			order.add(i);

		order.sort(Comparator.<Integer> comparingDouble(i -> chances.get(i)).reversed());

		final List<String> headers = new ArrayList<>();
		final List<TabRow> rows = new ArrayList<>();

		for (int index : order)
		{
			final int group = headers.size();

			headers.add(getGroupHeader(data.getDropGroupLabel(group + 1), chances.get(index)));

			for (DropRow drop : groups.get(index))
				rows.add(new TabRow(getDropRow(drop), group));
		}

		// The group headers already name what the columns hold, so the drop tab needs no column header of its own.
		return new TabContent("", rows, headers, true);
	}

	/**
	 * The header of a drop group, generated out of the very same width as its rows and framed by the separator of the datapack - a background color would fight the alternating rows sitting right under
	 * it, a pair of rules simply cuts the list into groups.
	 * @param caption : The caption of the group.
	 * @param chance : The chance the whole group rolls.
	 * @return The header row, its background color left as the {@link #BAND} placeholder.
	 */
	private static String getGroupHeader(String caption, double chance)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final StringBuilder sb = new StringBuilder(384);

		StringUtil.append(sb, getRowStart());
		StringUtil.append(sb, getCell(Math.max(1, data.getWidth() - data.getDropChanceWidth()), data.getGroupHeight(), data.getGroupAlign(), colorize(data.getGroupTextColor(), escape(caption))));
		StringUtil.append(sb, getCell(data.getDropChanceWidth(), 0, data.getGroupChanceAlign(), colorize(data.getChanceColor(chance), getChanceText(chance))));
		StringUtil.append(sb, ROW_END);

		return sb.toString();
	}

	private static String getDropRow(DropRow drop)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final String amount = (drop.min() == drop.max()) ? StringUtil.formatNumber(drop.min()) : StringUtil.formatNumber(drop.min()) + data.getCountRange() + StringUtil.formatNumber(drop.max());

		final StringBuilder sb = new StringBuilder(512);

		StringUtil.append(sb, getRowStart());
		StringUtil.append(sb, getCell(data.getDropIconWidth(), data.getGroupHeight(), data.getDropIconAlign(), getIcon(drop.itemId())));
		StringUtil.append(sb, getCell(data.getDropNameWidth(), 0, data.getDropNameAlign(), colorize(data.getNameColor(), escape(truncate(getItemName(drop.itemId()), data.getNameChars()))) + " " + colorize(data.getCountColor(), escape(data.getCountPrefix() + amount))));
		StringUtil.append(sb, getCell(data.getDropChanceWidth(), 0, data.getDropChanceAlign(), colorize(data.getChanceColor(drop.chance()), getChanceText(drop.chance()))));
		StringUtil.append(sb, ROW_END);

		return sb.toString();
	}

	/**
	 * The very formula {@link net.sf.l2j.gameserver.model.actor.instance.Monster#getLevelMultiplier(int)} runs, fed with the two levels rather than with a live instance - the book has to preview the
	 * drop of a boss which isn't spawned.
	 * @param playerLevel : The level of the {@link Player} reading the book.
	 * @param bossLevel : The level of the shown raid boss.
	 * @return The multiplier every drop chance is scaled by, 1 meaning no penalty at all.
	 */
	private static double getLevelMultiplier(int playerLevel, int bossLevel)
	{
		if (!Config.DEEPBLUE_DROP_RULES)
			return 1.;

		// A raid boss forgives 2 levels, where a regular monster forgives 5.
		final int levelDiff = playerLevel - bossLevel - 2;

		return (levelDiff <= 0) ? 1. : Math.max(0.1, 1 - 0.18 * levelDiff);
	}

	/**
	 * The history tab : the last kills the raid boss suffered, newest first.
	 * @param bossId : The npcId of the shown raid boss.
	 * @return One row per kill, holding the killer, the clan he wore at that very moment and when it happened.
	 */
	private TabContent getHistoryContent(int bossId)
	{
		final RaidBookData data = RaidBookData.getInstance();
		final SimpleDateFormat format = new SimpleDateFormat(data.getTimePattern());

		final List<TabRow> rows = new ArrayList<>();

		for (KillRecord record : getHistory(bossId))
		{
			final String clan = (record.clanName() == null || record.clanName().isEmpty()) ? data.getNoClanLabel() : record.clanName();

			final StringBuilder sb = new StringBuilder(512);

			StringUtil.append(sb, getRowStart());
			StringUtil.append(sb, getCell(data.getHistoryNameWidth(), data.getGroupHeight(), data.getHistoryNameAlign(), colorize(data.getValueColor(), escape(truncate(record.playerName(), data.getNameChars())))));
			StringUtil.append(sb, getCell(data.getHistoryClanWidth(), 0, data.getHistoryClanAlign(), colorize(data.getCountColor(), escape(truncate(clan, data.getNameChars())))));
			StringUtil.append(sb, getCell(data.getHistoryTimeWidth(), 0, data.getHistoryTimeAlign(), colorize(data.getLabelColor(), escape(format.format(new Date(record.time()))))));
			StringUtil.append(sb, ROW_END);

			rows.add(new TabRow(sb.toString(), -1));
		}

		return new TabContent(getColumns(new int[]
		{
			data.getHistoryNameWidth(),
			data.getHistoryClanWidth(),
			data.getHistoryTimeWidth()
		}, new String[]
		{
			data.getColNameLabel(),
			data.getColClanLabel(),
			data.getColTimeLabel()
		}, new String[]
		{
			data.getHistoryNameAlign(),
			data.getHistoryClanAlign(),
			data.getHistoryTimeAlign()
		}), rows, List.of(), true);
	}

	/**
	 * The ranking tab of a detail page : the players who killed that very raid boss the most.
	 * @param player : The {@link Player} reading the book, whose own row is highlighted.
	 * @param bossId : The npcId of the shown raid boss.
	 * @return One row per player, holding his position, his name, his clan and his amount of kills.
	 */
	private TabContent getBossRankContent(Player player, int bossId)
	{
		final List<RankRow> ranking = new ArrayList<>();

		for (Entry<Integer, Map<Integer, HuntData>> entry : _hunts.entrySet())
		{
			final HuntData data = entry.getValue().get(bossId);
			if (data != null && data.kills() > 0)
				ranking.add(new RankRow(entry.getKey(), data.kills()));
		}

		ranking.sort(Comparator.comparingInt(RankRow::score).reversed());

		final List<TabRow> rows = new ArrayList<>();
		for (String row : getRankRows(player, ranking))
			rows.add(new TabRow(row, -1));

		// A per boss ladder counts kills, where the server wide one counts points.
		return new TabContent(getRankColumns(RaidBookData.getInstance().getColKillsLabel()), rows, List.of(), true);
	}

	/**
	 * @param scoreLabel : The caption of the last column, which tells a kill ladder from a point one.
	 * @return The column header of a ladder, cut out of the very same widths as its rows.
	 */
	private static String getRankColumns(String scoreLabel)
	{
		final RaidBookData data = RaidBookData.getInstance();

		return getColumns(new int[]
		{
			data.getRankPosWidth(),
			data.getRankNameWidth(),
			data.getRankClanWidth(),
			data.getRankPointsWidth()
		}, new String[]
		{
			data.getColPosLabel(),
			data.getColNameLabel(),
			data.getColClanLabel(),
			scoreLabel
		}, new String[]
		{
			data.getRankPosAlign(),
			data.getRankNameAlign(),
			data.getRankClanAlign(),
			data.getRankPointsAlign()
		});
	}

	/**
	 * The row naming the columns of a list, drawn once on top of it rather than sliced along with its rows - a caption which scrolls away with the first page is worth nothing.
	 * @param widths : The width of each column, which has to be the very same set the rows are cut out of.
	 * @param labels : The caption of each column, an empty one leaving that column unnamed.
	 * @param aligns : The alignment of each column.
	 * @return The column header row, drawn on the plain band color the menus use and framed by the very rules a drop group header is framed by - both name what opens under them, so both read alike.
	 */
	private static String getColumns(int[] widths, String[] labels, String[] aligns)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final StringBuilder sb = new StringBuilder(448);

		sb.append(getSeparator());
		StringUtil.append(sb, getRowStart(data.getRowColor()));

		for (int i = 0; i < widths.length; i++)
			StringUtil.append(sb, getCell(widths[i], (i == 0) ? data.getGroupHeight() : 0, aligns[i], colorize(data.getGroupTextColor(), escape(labels[i]))));

		StringUtil.append(sb, ROW_END);
		sb.append(getSeparator());

		return sb.toString();
	}

	/**
	 * @param columns : The already rendered column header, an empty one meaning the list holds none.
	 * @return The height, in pixels, that header takes, the two rules framing it included.
	 */
	private static int getColumnsHeight(String columns)
	{
		final RaidBookData data = RaidBookData.getInstance();

		return (columns.isEmpty()) ? 0 : data.getGroupHeight() + ((data.getSeparator().isEmpty()) ? 0 : 2 * SEPARATOR_HEIGHT);
	}

	/**
	 * Generate and send one of the two ladders of the book : the daily one, ranked on the hunting points summed over every raid boss, and the monthly one, ranked on the amount of days its players
	 * topped that daily ladder.
	 * @param player : The {@link Player} to send the dialog to.
	 * @param filter : The index of the level filter the list was showing.
	 * @param listPage : The page index the list was showing.
	 * @param page : The page index of the ladder to show.
	 * @param mode : Which of the two ladders to show.
	 * @param query : The search query the list was showing.
	 */
	private void showRanking(Player player, int filter, int listPage, int page, int mode, String query)
	{
		final RaidBookData data = RaidBookData.getInstance();

		mode = (mode == MODE_MONTHLY) ? MODE_MONTHLY : MODE_DAILY;

		// The ladder is walked once and handed over to the head as well : building it twice would sum the points of every hunting record of the server twice, for one single page.
		final List<RankRow> ranking = getRanking(mode);
		final List<String> rows = getRankRows(player, ranking);

		final int perPage = data.getRowsPerPage();
		final int pages = Math.max(1, (rows.size() + perPage - 1) / perPage);

		page = Math.min(Math.max(page, 0), pages - 1);

		final int first = page * perPage;
		final int last = Math.min(rows.size(), first + perPage);

		// A daily ladder counts points, a monthly one counts the days which have been won.
		final String columns = getRankColumns((mode == MODE_MONTHLY) ? data.getColWinsLabel() : data.getColPointsLabel());

		final StringBuilder sb = new StringBuilder(4096);

		// The column header is drawn once on top of the list rather than sliced along with it, so it stays readable whatever page is browsed.
		sb.append(columns);

		if (rows.isEmpty())
			sb.append(getEmptyRow(data.getGroupHeight()));

		int band = 1;
		for (int i = first; i < last; i++)
			sb.append(rows.get(i).replace(BAND, getBandAttribute(band++)));

		final int shown = Math.max(1, last - first);
		final int shownMode = mode;
		final String tail = getContext(query);

		String content = HtmCache.getInstance().getHtmForce(RANK_HTM);
		content = content.replace("%title%", escape((mode == MODE_MONTHLY) ? data.getMonthlyRankTitle() : data.getRankTitle()));
		content = content.replace("%header%", getRankHeader(player, ranking, filter, listPage, mode, tail));
		content = content.replace("%menu%", getRankMenu(filter, listPage, mode, tail));
		content = content.replace("%list%", sb.toString());
		content = content.replace("%footer%", getFooter(page, pages, p -> getBypass("r " + filter + " " + listPage + " " + p + " " + shownMode + tail)));
		content = content.replace("%filler%", getFiller(getBlockHeight() + getBlockHeight() + getColumnsHeight(columns) + shown * data.getGroupHeight()));
		content = content.replace("%width%", String.valueOf(data.getWidth()));

		send(player, content);
	}

	/**
	 * The head of a ladder page : the way back to the list, and where the very {@link Player} reading it stands on the shown ladder.
	 * @param player : The {@link Player} the position is computed for.
	 * @param ranking : The already sorted ladder, handed over rather than built again.
	 * @param filter : The index of the level filter the list was showing.
	 * @param listPage : The page index the list was showing.
	 * @param mode : Which of the two ladders is shown.
	 * @param tail : The search query the list was showing, as the tail of a bypass.
	 * @return The header block, closed by the rule cutting the page into blocks.
	 */
	private String getRankHeader(Player player, List<RankRow> ranking, int filter, int listPage, int mode, String tail)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final int rank = getRank(ranking, player.getObjectId());
		final int score = (mode == MODE_MONTHLY) ? getWins(player.getObjectId()) : getPoints(player.getObjectId());
		final String suffix = (mode == MODE_MONTHLY) ? data.getWinsLabel() : data.getPointsLabel();

		final int width = data.getWidth();
		final int linkWidth = Math.max(1, Math.min((width - 2) / 2, data.getListButtonWidth()));
		final int scoreWidth = Math.max(1, (width - linkWidth) / 2);

		final StringBuilder sb = new StringBuilder(640);

		StringUtil.append(sb, getRowStart(data.getRowColor()));
		StringUtil.append(sb, getCell(linkWidth, data.getGroupHeight(), data.getHeaderLinkAlign(), getLink(getBypass("l " + filter + " " + listPage + tail), data.getBackLabel(), data.getTabColor())));
		StringUtil.append(sb, getCell(Math.max(1, width - linkWidth - scoreWidth), 0, data.getHeaderPointsAlign(), colorize(data.getLabelColor(), escape(data.getRankPrefix())) + colorize(data.getValueColor(), (rank > 0) ? String.valueOf(rank) : escape(data.getUnrankedLabel()))));
		StringUtil.append(sb, getCell(scoreWidth, 0, data.getHeaderPointsAlign(), colorize(data.getCountColor(), StringUtil.formatNumber(score) + escape(suffix))));
		StringUtil.append(sb, ROW_END);
		sb.append(getSeparator());

		return sb.toString();
	}

	/**
	 * The menu of a ladder page : the two ladders, and the rewards of the shown one. The shown ladder is written with the active color instead of being a link, the way every other menu of the book
	 * does, so a player always reads which one he browses.
	 * @param filter : The index of the level filter the list was showing.
	 * @param listPage : The page index the list was showing.
	 * @param mode : Which of the two ladders is shown.
	 * @param tail : The search query the list was showing, as the tail of a bypass.
	 * @return The menu row, closed by the rule cutting the page into blocks.
	 */
	private static String getRankMenu(int filter, int listPage, int mode, String tail)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final int cellWidth = Math.max(1, data.getWidth() / 3);

		final String context = " " + filter + " " + listPage;

		final StringBuilder sb = new StringBuilder(512);

		StringUtil.append(sb, getRowStart(data.getRowColor()));
		StringUtil.append(sb, getCell(cellWidth, data.getGroupHeight(), data.getMenuAlign(), (mode == MODE_DAILY) ? colorize(data.getActiveTabColor(), escape(data.getRankDailyLabel())) : getLink(getBypass("r" + context + " 0 " + MODE_DAILY + tail), data.getRankDailyLabel(), data.getTabColor())));
		StringUtil.append(sb, getCell(cellWidth, 0, data.getMenuAlign(), (mode == MODE_MONTHLY) ? colorize(data.getActiveTabColor(), escape(data.getRankMonthlyLabel())) : getLink(getBypass("r" + context + " 0 " + MODE_MONTHLY + tail), data.getRankMonthlyLabel(), data.getTabColor())));
		StringUtil.append(sb, getCell(Math.max(1, data.getWidth() - 2 * cellWidth), 0, data.getMenuAlign(), getLink(getBypass("d" + context + " " + mode + tail), data.getRewardsLabel(), data.getTabColor())));
		StringUtil.append(sb, ROW_END);
		sb.append(getSeparator());

		return sb.toString();
	}

	/**
	 * Generate and send the daily reward page : what each of the rewarded positions of the server wide ladder is handed every day.<br>
	 * <br>
	 * It is laid out the way the shift click window lays out a drop list, since it holds the very same thing - items grouped under what hands them out : one group header per rewarded position,
	 * framed by the rules cutting the page into groups, and the items of that position under it, an icon on the left and the amount written right under the name. A position handing out several items
	 * simply owns several rows, and the header above them says once whose they are.
	 * @param player : The {@link Player} to send the dialog to.
	 * @param filter : The index of the level filter the list was showing.
	 * @param listPage : The page index the list was showing.
	 * @param mode : Which of the two rewards to show - the daily ones or the monthly ones.
	 * @param query : The search query the list was showing.
	 */
	private void showRewards(Player player, int filter, int listPage, int mode, String query)
	{
		final RaidBookData data = RaidBookData.getInstance();

		mode = (mode == MODE_MONTHLY) ? MODE_MONTHLY : MODE_DAILY;

		final boolean monthly = mode == MODE_MONTHLY;
		final boolean enabled = (monthly) ? Config.RAIDBOOK_MONTHLY_ENABLED : Config.RAIDBOOK_DAILY_ENABLED;
		final Map<Integer, List<IntIntHolder>> rewards = (monthly) ? Config.RAIDBOOK_MONTHLY_REWARDS : Config.RAIDBOOK_DAILY_REWARDS;

		final StringBuilder sb = new StringBuilder(2048);

		int groups = 0;
		int rows = 0;

		if (enabled)
		{
			final List<Integer> places = new ArrayList<>(rewards.keySet());
			places.sort(null);

			// The band sitting right above is drawn on the plain band color, so the list starts on the other one rather than stacking two identical blocks.
			int band = 1;

			for (int place : places)
			{
				sb.append(getSeparator());
				sb.append(getPlaceHeader(place).replace(BAND, getBandAttribute(band++)));
				sb.append(getSeparator());

				groups++;

				for (IntIntHolder item : rewards.get(place))
				{
					sb.append(getRewardRow(item).replace(BAND, getBandAttribute(band++)));

					rows++;
				}
			}
		}

		if (rows == 0)
		{
			sb.append(getEmptyRow(data.getRowHeight()));

			rows = 1;
		}

		final int half = Math.max(1, data.getWidth() / 2);
		final int shownMode = mode;
		final String tail = getContext(query);

		final StringBuilder header = new StringBuilder(512);
		StringUtil.append(header, getRowStart(data.getRowColor()));
		StringUtil.append(header, getCell(half, data.getGroupHeight(), data.getMenuAlign(), getLink(getBypass("r " + filter + " " + listPage + " 0 " + shownMode + tail), data.getRankLabel(), data.getTabColor())));
		StringUtil.append(header, getCell(Math.max(1, data.getWidth() - half), 0, data.getMenuAlign(), colorize(data.getActiveTabColor(), escape((monthly) ? data.getMonthlyLabel() : data.getDailyLabel()))));
		StringUtil.append(header, ROW_END);
		header.append(getSeparator());

		// When the next handout is due, read off the schedule of the very task which does it - a reward list nobody can date is half a promise. Emptying the label drops the band altogether.
		final String next = (data.getNextRewardLabel().isEmpty()) ? "" : escape(data.getNextRewardLabel()) + getNextRewardText(mode);

		if (!next.isEmpty())
		{
			header.append(getBandContent(next, data.getNextRewardAlign()));
			header.append(getSeparator());
		}

		final int groupHeight = data.getGroupHeight() + ((data.getSeparator().isEmpty()) ? 0 : 2 * SEPARATOR_HEIGHT);

		String content = HtmCache.getInstance().getHtmForce(DAILY_HTM);
		content = content.replace("%title%", escape((monthly) ? data.getMonthlyTitle() : data.getDailyTitle()));
		content = content.replace("%header%", header.toString());
		content = content.replace("%list%", sb.toString());

		// The page holds everything it has to show, but the selector row is still emitted : it is what the shared "overhead" of the layout counts on.
		content = content.replace("%footer%", getFooter(0, 1, p -> getBypass("d " + filter + " " + listPage + " " + shownMode + tail)));
		content = content.replace("%filler%", getFiller(getBlockHeight() + getBandHeight(next) + groups * groupHeight + rows * data.getRowHeight()));
		content = content.replace("%width%", String.valueOf(data.getWidth()));

		send(player, content);
	}

	/**
	 * @param mode : Which of the two rewards to look at.
	 * @return The date the next handout of that reward is due, rendered with the pattern of the datapack, and the "nextRewardUnknown" label when its task isn't scheduled at all.
	 */
	private static String getNextRewardText(int mode)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final long time = getNextRewardTime(mode);
		if (time <= 0)
			return escape(data.getNextRewardUnknown());

		return escape(new SimpleDateFormat(data.getNextRewardPattern()).format(new Date(time)));
	}

	/**
	 * @param place : The rewarded position of the ladder.
	 * @return The header row opening the rewards of one position, cut out of the whole layout width - a position owns no chance to write on its right, where a drop group does.
	 */
	private static String getPlaceHeader(int place)
	{
		final RaidBookData data = RaidBookData.getInstance();

		return getRowStart() + getCell(data.getWidth(), data.getGroupHeight(), data.getGroupAlign(), colorize(data.getGroupTextColor(), place + escape(data.getPlaceSuffix()))) + ROW_END;
	}

	/**
	 * One row of the daily reward page, drawn the way the shift click window draws a dropped item : the icon on the left, then the name on one line and the amount right under it - an amount as long as
	 * an adena one doesn't fit next to a name on a single line.
	 * @param item : The rewarded item and its amount.
	 * @return The row, its background color left as the {@link #BAND} placeholder.
	 */
	private static String getRewardRow(IntIntHolder item)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final StringBuilder sb = new StringBuilder(512);

		StringUtil.append(sb, getRowStart());
		StringUtil.append(sb, getCell(data.getRewardIconWidth(), data.getRowHeight(), data.getRewardIconAlign(), getIcon(item.getId())));
		StringUtil.append(sb, getCell(Math.max(1, data.getWidth() - data.getRewardIconWidth()), 0, data.getRewardNameAlign(), colorize(data.getNameColor(), escape(truncate(getItemName(item.getId()), data.getNameChars()))) + "<br1>" + colorize(data.getCountColor(), escape(data.getCountPrefix()) + StringUtil.formatNumber(item.getValue()))));
		StringUtil.append(sb, ROW_END);

		return sb.toString();
	}

	/**
	 * @param player : The {@link Player} reading the book, whose own row is highlighted.
	 * @param ranking : The already sorted ladder to render.
	 * @return One row per position, holding the position itself, the name and the clan of the player, and his score. Their background color is left as the {@link #BAND} placeholder.
	 */
	private static List<String> getRankRows(Player player, List<RankRow> ranking)
	{
		final RaidBookData data = RaidBookData.getInstance();
		final Map<Integer, String> clans = getClanNames();

		final List<String> rows = new ArrayList<>();

		for (int i = 0; i < Math.min(Config.RAIDBOOK_RANKING_SIZE, ranking.size()); i++)
		{
			final RankRow row = ranking.get(i);

			final String name = PlayerInfoTable.getInstance().getPlayerName(row.objectId());
			if (name == null)
				continue;

			final String clan = clans.getOrDefault(row.objectId(), data.getNoClanLabel());
			final boolean self = row.objectId() == player.getObjectId();

			final StringBuilder sb = new StringBuilder(512);

			StringUtil.append(sb, getRowStart());
			StringUtil.append(sb, getCell(data.getRankPosWidth(), data.getGroupHeight(), data.getRankPosAlign(), colorize(data.getLabelColor(), String.valueOf(i + 1))));
			StringUtil.append(sb, getCell(data.getRankNameWidth(), 0, data.getRankNameAlign(), colorize((self) ? data.getSelfColor() : data.getNameColor(), escape(truncate(name, data.getNameChars())))));
			StringUtil.append(sb, getCell(data.getRankClanWidth(), 0, data.getRankClanAlign(), colorize(data.getCountColor(), escape(truncate(clan, data.getNameChars())))));
			StringUtil.append(sb, getCell(data.getRankPointsWidth(), 0, data.getRankPointsAlign(), colorize(data.getCountColor(), StringUtil.formatNumber(row.score()))));
			StringUtil.append(sb, ROW_END);

			rows.add(sb.toString());
		}

		return rows;
	}

	/**
	 * The whole progress bar line of a hunting level : the bar itself, the counter written next to it, and - when asked for - the spacers centering both of them on the row.
	 * @param kills : The amount of kills of one {@link Player} on one raid boss.
	 * @param height : The height, in pixels, of the row the bar sits on. It is written on the first emitted cell, the way every other row of the book does.
	 * @param centered : Whether the bar and its counter are centered on the row, which is what a detail page does - a list row reads better with its bar starting under the name of its boss.
	 * @return The cells of the line, which always add up to the layout width.
	 */
	private static String getBarCells(int kills, int height, boolean centered)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final int width = data.getWidth();

		// The bar sits in a cell slightly wider than itself : a cell holding something of its very width leaves the client no slack, and it wraps that content onto the next line.
		final int barWidth = Math.max(1, Math.min(width - 1, getBarSpan() + BAR_SLACK));
		final int counterWidth = (centered) ? Math.max(1, Math.min(width - barWidth - 1, data.getBarCounterWidth())) : Math.max(1, width - barWidth);
		final int pad = (centered) ? Math.max(0, (width - barWidth - counterWidth) / 2) : 0;

		final StringBuilder sb = new StringBuilder(448);

		// The height rides on the very first emitted cell, whichever it turns out to be.
		int first = height;

		if (pad > 0)
		{
			sb.append(getCell(pad, first, data.getBarAlign(), ""));
			first = 0;
		}

		sb.append(getCell(barWidth, first, data.getBarAlign(), getBar(kills)));
		sb.append(getCell(counterWidth, 0, data.getBarCounterAlign(), colorize(data.getCountColor(), " " + getProgressText(kills))));

		final int rest = width - pad - barWidth - counterWidth;
		if (rest > 0)
			sb.append(getCell(rest, 0, data.getBarAlign(), ""));

		return sb.toString();
	}

	/**
	 * The bar itself : a <b>table of its own</b>, carrying the track color as its background, holding the filled part of the current level as an image stretched to that very progress. A full level
	 * covers its whole track.<br>
	 * <br>
	 * It has to be a table, and it has to be nested inside the cell of the row : the client only handles the bgcolor attribute on tables, so a bare cell can't be given a track color of its own. The
	 * two halves used to be two textures instead, which is what a stock client can't show - "L2UI.SquareWhite" and "L2UI.SquareGray" are its two hairline textures and they read as the very same grey
	 * once they sit next to each other, so the bar showed one single block whatever the progress.<br>
	 * <br>
	 * The image is drawn one pixel short of its own cell, for the very reason the bar is given a wider cell than itself. A full bar is the exception : its cell is left unsized, so the image alone
	 * fills the table and the track is covered whole.
	 * @param kills : The amount of kills of one {@link Player} on one raid boss.
	 * @return The bar, as a table measuring {@link #getBarSpan()} whatever the progress.
	 */
	private static String getBar(int kills)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final int span = getBarSpan();
		final int filled = Math.min(span, Math.max(0, (int) Math.round(span * getProgress(kills))));
		final int height = data.getBarHeight();

		final StringBuilder sb = new StringBuilder(320);

		StringUtil.append(sb, "<table width=", span, ((data.getBarTrackColor().isEmpty()) ? "" : " bgcolor=\"" + data.getBarTrackColor() + "\""), "><tr>");

		if (filled >= span)
			StringUtil.append(sb, "<td height=", height, ">", getBarImage(span, height), "</td>");
		else if (filled > 0)
		{
			StringUtil.append(sb, "<td width=", filled, " height=", height, ">", getBarImage(filled - 1, height), "</td>");
			StringUtil.append(sb, "<td width=", span - filled, "></td>");
		}
		else
			StringUtil.append(sb, "<td height=", height, "></td>");

		sb.append(ROW_END);

		return sb.toString();
	}

	/**
	 * @param width : The width, in pixels, to draw the image at.
	 * @param height : The height, in pixels, to draw it at.
	 * @return The filled part of the bar, empty when the datapack holds no texture for it - which leaves the bare track, and is how a datapack drops the fill without moving anything.
	 */
	private static String getBarImage(int width, int height)
	{
		final String texture = RaidBookData.getInstance().getBarFilled();

		return (texture.isEmpty()) ? "" : "<img src=\"" + texture + "\" width=" + Math.max(1, width) + " height=" + height + ">";
	}

	/**
	 * @return The width, in pixels, the bar itself takes. The cell holding it, and the counter written next to it, are cut out of whatever is left of the layout width.
	 */
	private static int getBarSpan()
	{
		final RaidBookData data = RaidBookData.getInstance();

		return Math.max(1, Math.min(data.getWidth() - BAR_SLACK - 2, data.getBarWidth()));
	}

	/**
	 * @param kills : The amount of kills of one {@link Player} on one raid boss.
	 * @return How far into the current hunting level those kills stand, between 0 and 1. A capped level always reads as full.
	 */
	private static double getProgress(int kills)
	{
		final int level = getHuntLevel(kills);
		if (Config.RAIDBOOK_MAX_LEVEL > 0 && level >= Config.RAIDBOOK_MAX_LEVEL)
			return 1.;

		final int lower = getLevelStart(level);
		final int upper = getLevelStart(level + 1);

		return Math.min(1., Math.max(0., (kills - lower) / (double) Math.max(1, upper - lower)));
	}

	/**
	 * The counter written next to the progress bar. It counts <b>inside the current hunting level</b>, exactly like the bar standing in front of it : an absolute counter next to a relative bar reads
	 * as a broken bar - "10/15" sitting next to an empty bar is what a freshly reached level used to look like. The absolute amount of kills is what the hunting block writes on its own line.
	 * @param kills : The amount of kills of one {@link Player} on one raid boss.
	 * @return The kills done into the current level over the kills that level takes.
	 */
	private static String getProgressText(int kills)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final int level = getHuntLevel(kills);
		if (Config.RAIDBOOK_MAX_LEVEL > 0 && level >= Config.RAIDBOOK_MAX_LEVEL)
			return escape(data.getMaxLevelLabel());

		final int lower = getLevelStart(level);
		final int upper = getLevelStart(level + 1);

		return (kills - lower) + escape(data.getProgressRange()) + Math.max(1, upper - lower);
	}

	/**
	 * The bottom row of a page, holding the page selector. It is always emitted, even empty : an occasionally missing row would shorten a page by one row height, and the selector would move around.
	 * @param page : The currently shown page index.
	 * @param pages : The total amount of pages.
	 * @param bypass : The bypass builder, fed with a page index.
	 * @return The footer row, replacing the %footer% variable.
	 */
	private static String getFooter(int page, int pages, IntFunction<String> bypass)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final int cellWidth = data.getPageWidth();

		int first = 0;
		int last = 0;
		boolean hasPrev = false;
		boolean hasNext = false;

		if (pages > 1)
		{
			hasPrev = page > 0;
			hasNext = page < pages - 1;

			// Whatever the row can hold, the arrows taking a cell of their own.
			final int room = data.getWidth() / cellWidth - ((hasPrev) ? 1 : 0) - ((hasNext) ? 1 : 0);
			final int shown = Math.max(1, Math.min(data.getMaxPages(), room));

			// Center the shown window of pages on the current page.
			first = Math.max(0, page - shown / 2);
			last = Math.min(pages, first + shown);
			first = Math.max(0, last - shown);
		}

		final int cells = (last - first) + ((hasPrev) ? 1 : 0) + ((hasNext) ? 1 : 0);

		// The left cell takes whatever the selector leaves, which pins the selector to the right edge.
		final int leftWidth = Math.max(1, data.getWidth() - cells * cellWidth);

		final StringBuilder sb = new StringBuilder(640);

		StringUtil.append(sb, "<table width=", data.getWidth(), "><tr><td width=", leftWidth, " height=", data.getGroupHeight(), " align=left></td>");

		if (hasPrev)
			sb.append(getPageCell(cellWidth, getLink(bypass.apply(page - 1), data.getPrevPageLabel(), data.getPageColor())));

		for (int i = first; i < last; i++)
		{
			final String label = String.valueOf(i + 1);

			sb.append(getPageCell(cellWidth, (i == page) ? colorize(data.getActivePageColor(), label) : getLink(bypass.apply(i), label, data.getPageColor())));
		}

		if (hasNext)
			sb.append(getPageCell(cellWidth, getLink(bypass.apply(page + 1), data.getNextPageLabel(), data.getPageColor())));

		sb.append(ROW_END);

		return sb.toString();
	}

	/**
	 * The dialog owns a fixed height, so padding every page up to one single total keeps the page selector at the very same spot - and, the total being slightly above the dialog, keeps the scrollbar
	 * shown everywhere.
	 * @param used : The height, in pixels, everything but the HTM overhead already takes on the current page.
	 * @return The spacer filling the bottom of the page, replacing the %filler% variable.
	 */
	private static String getFiller(int used)
	{
		final RaidBookData data = RaidBookData.getInstance();
		if (data.getPageHeight() <= 0)
			return "";

		final int missing = data.getPageHeight() - data.getOverhead() - used;

		return (missing <= 0) ? "" : "<img height=" + missing + ">";
	}

	/**
	 * @param height : The height, in pixels, the row takes.
	 * @return The row shown instead of an empty list, already striped - it is the only row of its page.
	 */
	private static String getEmptyRow(int height)
	{
		final RaidBookData data = RaidBookData.getInstance();

		return getRowStart(data.getAltRowColor()) + getCell(data.getWidth(), height, data.getEmptyAlign(), colorize(data.getDisabledColor(), escape(data.getEmptyLabel()))) + ROW_END;
	}

	/**
	 * @return The horizontal rule cutting a page into blocks, empty when the datapack holds no separator texture.
	 */
	private static String getSeparator()
	{
		final RaidBookData data = RaidBookData.getInstance();

		return (data.getSeparator().isEmpty()) ? "" : "<img src=\"" + data.getSeparator() + "\" width=" + data.getWidth() + " height=" + SEPARATOR_HEIGHT + ">";
	}

	/**
	 * @return The opening tags of one two columns block, drawn on the plain band color of the page.
	 */
	private static String getBlockStart()
	{
		final RaidBookData data = RaidBookData.getInstance();

		return "<table width=" + data.getWidth() + ((data.getRowColor().isEmpty()) ? "" : " bgcolor=\"" + data.getRowColor() + "\"") + ">";
	}

	private static String getStatRow(String leftLabel, long leftValue, String rightLabel, long rightValue)
	{
		return getStatRow(leftLabel, StringUtil.formatNumber(leftValue), rightLabel, StringUtil.formatNumber(rightValue));
	}

	/**
	 * One line of a two columns block, holding two values side by side. Both of them are right aligned on the edge of their own column, which is what keeps the numbers of a block readable whatever
	 * their magnitude.
	 * @param leftLabel : The caption of the left column.
	 * @param leftValue : The already rendered value of the left column.
	 * @param rightLabel : The caption of the right column.
	 * @param rightValue : The already rendered value of the right column.
	 * @return One line, as a pair of caption/value cells per column.
	 */
	private static String getStatRow(String leftLabel, String leftValue, String rightLabel, String rightValue)
	{
		return getStatRow(leftLabel, leftValue, rightLabel, rightValue, RaidBookData.getInstance().getHeaderLabelWidth());
	}

	/**
	 * @param leftLabel : The caption of the left column.
	 * @param leftValue : The already rendered value of the left column.
	 * @param rightLabel : The caption of the right column.
	 * @param rightValue : The already rendered value of the right column.
	 * @param rightLabelWidth : The width, in pixels, of the caption cell of the right column. A short caption sitting in front of a long value is given one of its own : the value takes whatever the
	 *            caption leaves of the column, and a value which doesn't fit wraps - which makes the whole row taller than the ones around it.
	 * @return One line, as a pair of caption/value cells per column.
	 */
	private static String getStatRow(String leftLabel, String leftValue, String rightLabel, String rightValue, int rightLabelWidth)
	{
		final RaidBookData data = RaidBookData.getInstance();

		// The gap sits between the two columns, so the caption of the right one never touches the value of the left one, which is right aligned on the column edge.
		final int gap = Math.min(data.getHeaderGap(), data.getWidth() - 2);
		final int columnWidth = Math.max(2, (data.getWidth() - gap) / 2);
		final int labelWidth = Math.max(1, Math.min(data.getHeaderLabelWidth(), columnWidth - 1));
		final int rightWidth = Math.max(1, Math.min(rightLabelWidth, columnWidth - 1));

		final StringBuilder sb = new StringBuilder(512);

		sb.append("<tr>");
		sb.append(getCell(labelWidth, data.getHeaderHeight(), data.getStatLabelAlign(), colorize(data.getLabelColor(), escape(leftLabel))));
		sb.append(getCell(columnWidth - labelWidth, 0, data.getStatValueAlign(), colorize(data.getValueColor(), leftValue)));

		if (gap > 0)
			sb.append(getCell(gap, 0, data.getStatLabelAlign(), ""));

		sb.append(getCell(rightWidth, 0, data.getStatLabelAlign(), colorize(data.getLabelColor(), escape(rightLabel))));

		// The last cell takes whatever is left of the layout width, which absorbs the rounding of an odd width.
		sb.append(getCell(Math.max(1, data.getWidth() - columnWidth - gap - rightWidth), 0, data.getStatValueAlign(), colorize(data.getValueColor(), rightValue)));
		sb.append("</tr>");

		return sb.toString();
	}

	private static String getIcon(int itemId)
	{
		final RaidBookData data = RaidBookData.getInstance();

		return "<img src=\"" + ItemIconData.getInstance().getIcon(itemId) + "\" width=" + data.getIconSize() + " height=" + data.getIconSize() + ">";
	}

	/**
	 * @param itemId : The item to name.
	 * @return The name of the given item, its bare id when the datapack doesn't hold it.
	 */
	private static String getItemName(int itemId)
	{
		final Item item = ItemData.getInstance().getTemplate(itemId);

		return (item == null) ? String.valueOf(itemId) : item.getName();
	}

	/**
	 * @param chance : The already computed chance, in percent.
	 * @return The chance cell content. A chance the pattern of the datapack rounds down to a bare zero gets the "nearZero" label instead, since a shown 0% would read as "never".
	 */
	private static String getChanceText(double chance)
	{
		final RaidBookData data = RaidBookData.getInstance();
		final DecimalFormat format = new DecimalFormat(data.getChancePattern(), NUMBER_SYMBOLS);

		final String text = format.format(chance);

		// Comparing against the formatted zero rather than against a threshold keeps this right whatever amount of decimals the pattern holds.
		if (chance > 0 && text.equals(format.format(0)))
			return escape(data.getNearZeroLabel());

		return escape(text + data.getChanceSuffix());
	}

	private static String format(double value)
	{
		return new DecimalFormat(RaidBookData.getInstance().getChancePattern(), NUMBER_SYMBOLS).format(value);
	}

	/**
	 * Each row is rendered as its own table, since the client only handles the bgcolor attribute on tables.
	 * @return The opening tags of a striped row, its background color left as the {@link #BAND} placeholder.
	 */
	private static String getRowStart()
	{
		return "<table width=" + RaidBookData.getInstance().getWidth() + BAND + "><tr>";
	}

	/**
	 * @param color : The background color of the row, empty keeping it see-through.
	 * @return The opening tags of a row owning a fixed color - a header, a menu or a button row.
	 */
	private static String getRowStart(String color)
	{
		return "<table width=" + RaidBookData.getInstance().getWidth() + ((color.isEmpty()) ? "" : " bgcolor=\"" + color + "\"") + "><tr>";
	}

	/**
	 * @param index : The index of the band on the current page, group headers and rows counted alike, 0 being the first one.
	 * @return The bgcolor attribute of the given band, empty meaning transparent.
	 */
	private static String getBandAttribute(int index)
	{
		final RaidBookData data = RaidBookData.getInstance();
		final String color = (index % 2 == 0) ? data.getRowColor() : data.getAltRowColor();

		return (color.isEmpty()) ? "" : " bgcolor=\"" + color + "\"";
	}

	private static String getPageCell(int width, String content)
	{
		final RaidBookData data = RaidBookData.getInstance();

		return getCell(width, data.getGroupHeight(), data.getMenuAlign(), content);
	}

	private static String getCell(int width, int height, String align, String content)
	{
		final StringBuilder sb = new StringBuilder(64);

		sb.append("<td width=").append(width);

		if (height > 0)
			sb.append(" height=").append(height);

		sb.append(" align=").append(align).append('>').append(content).append("</td>");

		return sb.toString();
	}

	private static String getBypass(String command)
	{
		return BYPASS + command;
	}

	private static String getLink(String bypass, String label, String color)
	{
		return "<a action=\"bypass -h " + bypass + "\">" + colorize(color, escape(label)) + "</a>";
	}

	/**
	 * @param color : The color to apply, an empty {@link String} keeping the client default.
	 * @param text : The text to wrap.
	 * @return The given text, wrapped into a font tag when a color is set.
	 */
	private static String colorize(String color, String text)
	{
		return (color.isEmpty() || text.isEmpty()) ? text : "<font color=\"" + color + "\">" + text + "</font>";
	}

	/**
	 * Every single datapack string goes through this on its way to the client, and none may skip it : the XML parser hands over decoded text, so a "&amp;lt;" of the XML reaches here as a bare "&lt;"
	 * the client would then swallow as the start of a tag - along with the rest of its cell.
	 * @param text : The datapack text to render.
	 * @return The given text, with its angle brackets turned into entities the client renders as is.
	 */
	private static String escape(String text)
	{
		return (text.indexOf('<') < 0 && text.indexOf('>') < 0) ? text : text.replace("<", "&lt;").replace(">", "&gt;");
	}

	/**
	 * Shorten a name which wouldn't fit its column, since a wrapped text makes the whole row taller than the others.
	 * @param text : The text to shorten.
	 * @param maxChars : The maximum amount of characters, 0 disabling the shortening.
	 * @return The given text, shortened and suffixed by the ellipsis when needed.
	 */
	private static String truncate(String text, int maxChars)
	{
		if (maxChars <= 0 || text.length() <= maxChars)
			return text;

		final String ellipsis = RaidBookData.getInstance().getEllipsis();
		final int cut = Math.max(1, maxChars - ellipsis.length());

		String result = text.substring(0, cut);

		final int space = result.lastIndexOf(' ');
		if (space * 3 > cut * 2)
			result = result.substring(0, space);

		return result.stripTrailing() + ellipsis;
	}

	private static void send(Player player, String content)
	{
		final NpcHtmlMessage html = new NpcHtmlMessage(0);
		html.setHtml(content);

		player.sendPacket(html);
		player.sendPacket(ActionFailed.STATIC_PACKET);
	}

	public static RaidBookManager getInstance()
	{
		return SingletonHolder.INSTANCE;
	}

	private static class SingletonHolder
	{
		protected static final RaidBookManager INSTANCE = new RaidBookManager();
	}
}
