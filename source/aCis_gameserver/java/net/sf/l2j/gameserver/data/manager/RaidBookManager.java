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
	private static final String SAVE_PENDING = "INSERT INTO raidboss_daily_rewards (char_id, place, item_id, count) VALUES (?,?,?,?)";
	private static final String READ_PENDING = "SELECT place, item_id, count FROM raidboss_daily_rewards WHERE char_id = ?";
	private static final String CLEAR_PENDING = "DELETE FROM raidboss_daily_rewards WHERE char_id = ?";

	private static final String ROW_END = "</tr></table>";

	/**
	 * The placeholder standing where the background color of a row goes. A row is rendered once, then striped when it lands on a page : a stripe which follows the absolute index of a row would flip
	 * from one page to the next, and the first row of a page would sometimes repeat the color of the menu sitting right above it.
	 */
	private static final String BAND = "%band%";

	/** Height, in pixels, of the rule cutting the blocks of a page apart. The separator textures are hairlines, and the filler math relies on that height being fixed. */
	private static final int SEPARATOR_HEIGHT = 1;

	/** Amount of lines the statistics block of a detail page holds : two for the rewards, three for the combat stats. Both blocks are two columns wide, so a line carries two stats. */
	private static final int STATS_ROWS = 5;

	/** Amount of lines the hunting block of a detail page holds : the hunting level and the amount of kills, then the damage bonus and what the next level takes. */
	private static final int HUNT_ROWS = 2;

	/** {@link DecimalFormat} isn't thread safe and several {@link Player}s can browse the book at once, so a formatter is built per cell ; only its symbols are shared. */
	private static final DecimalFormatSymbols NUMBER_SYMBOLS = DecimalFormatSymbols.getInstance(Locale.ENGLISH);

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
	 * The whole content of a tab : its rows, the header of each of its groups, and whether it is paged at all - the reward tab isn't, since a player reads the coming levels as one single block.
	 */
	private record TabContent(List<TabRow> rows, List<String> headers, boolean paged)
	{
	}

	/** One daily reward waiting for its winner to log in. */
	private record PendingReward(int place, int itemId, int count)
	{
	}

	private final Map<Integer, Map<Integer, HuntData>> _hunts = new ConcurrentHashMap<>();
	private final Map<Integer, Deque<KillRecord>> _history = new ConcurrentHashMap<>();

	/** The objectIds owning a daily reward they haven't been handed yet, which is what spares a database read on every single login. */
	private final Set<Integer> _pending = ConcurrentHashMap.newKeySet();

	/** The sorted list of the raid bosses of the server, built once and dropped by {@link #reload()} - the templates don't move on their own. */
	private volatile List<NpcTemplate> _bosses;

	protected RaidBookManager()
	{
		loadHunts();
		loadHistory();
		loadPending();

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

		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement ps = con.prepareStatement(SAVE_HUNT))
		{
			ps.setInt(1, player.getObjectId());
			ps.setInt(2, bossId);
			ps.setInt(3, kills);
			ps.setInt(4, current.points());
			ps.executeUpdate();
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't save the raid boss hunting record of {}.", e, player.getName());
		}

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
		if (!Config.RAIDBOOK_ENABLED || !Config.RAIDBOOK_DAILY_ENABLED || Config.RAIDBOOK_DAILY_REWARDS.isEmpty())
			return;

		final List<RankRow> ranking = getRanking();

		int rewarded = 0;

		for (Entry<Integer, List<IntIntHolder>> entry : Config.RAIDBOOK_DAILY_REWARDS.entrySet())
		{
			final int place = entry.getKey();
			if (place > ranking.size())
				continue;

			final int objectId = ranking.get(place - 1).objectId();

			store(objectId, place, entry.getValue());
			rewarded++;

			// The winner may very well be online, and waiting for his next login to be told would read as a missing reward.
			final Player player = World.getInstance().getPlayer(objectId);
			if (player != null)
				deliver(player);
		}

		LOGGER.info("Handed out the raid book daily rewards to {} player(s).", rewarded);
	}

	private void store(int objectId, int place, List<IntIntHolder> items)
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
				ps.addBatch();
			}
			ps.executeBatch();
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't store the raid book daily reward of the objectId {}.", e, objectId);
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
					rewards.add(new PendingReward(rs.getInt("place"), rs.getInt("item_id"), rs.getInt("count")));
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

			inform(player, data.getDailyMessage().replace("%place%", String.valueOf(reward.place())).replace("%item%", getItemName(reward.itemId())).replace("%count%", StringUtil.formatNumber(reward.count())), true);
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
	 * @param objectId : The objectId of the {@link Player} to check.
	 * @return The position of that {@link Player} on the server wide ladder, 0 when he holds no point at all.
	 */
	private int getRank(int objectId)
	{
		final List<RankRow> rows = getRanking();

		for (int i = 0; i < rows.size(); i++)
		{
			if (rows.get(i).objectId() == objectId)
				return i + 1;
		}

		return 0;
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

		showList(player, 0, 0);
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

			switch (action)
			{
				case "l":
					showList(player, Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()));
					break;

				case "i":
					showDetail(player, Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()));
					break;

				case "f":
					final int bossId = Integer.parseInt(st.nextToken());

					search(player, bossId);
					showDetail(player, bossId, Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()));
					break;

				case "r":
					showRanking(player, Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()));
					break;

				case "d":
					showDaily(player, Integer.parseInt(st.nextToken()), Integer.parseInt(st.nextToken()));
					break;
			}
		}
		catch (Exception e)
		{
			LOGGER.warn("Couldn't handle the raid book bypass '{}'.", e, command);
		}
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
	 * Generate and send the main page of the book : the ranking position of the {@link Player} on its head, the level filter menu right under it, then one row per raid boss.
	 * @param player : The {@link Player} to send the dialog to.
	 * @param filter : The index of the shown level filter.
	 * @param page : The page index to show.
	 */
	private void showList(Player player, int filter, int page)
	{
		final RaidBookData data = RaidBookData.getInstance();

		filter = Math.min(Math.max(filter, 0), data.getFilters().size() - 1);

		final LevelFilter levelFilter = data.getFilter(filter);
		final List<NpcTemplate> bosses = getBosses().stream().filter(t -> levelFilter.matches(t.getLevel())).toList();

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
			sb.append(getBossRow(player, bosses.get(i), filter, page).replace(BAND, getBandAttribute(band++)));

		final int shown = Math.max(1, last - first);

		// The page selector is built by a lambda, so the browsed range has to be handed to it as a final.
		final int index = filter;

		String content = HtmCache.getInstance().getHtmForce(LIST_HTM);
		content = content.replace("%title%", escape(data.getBookTitle()));
		content = content.replace("%header%", getListHeader(player, filter, page));
		content = content.replace("%filters%", getFilters(index));
		content = content.replace("%list%", sb.toString());
		content = content.replace("%footer%", getFooter(page, pages, p -> getBypass("l " + index + " " + p)));
		content = content.replace("%filler%", getFiller(getBlockHeight() + getBlockHeight() + shown * data.getRowHeight()));
		content = content.replace("%width%", String.valueOf(data.getWidth()));

		send(player, content);
	}

	/**
	 * The head of the main page, telling the very {@link Player} where he stands on the server wide ladder and linking to it.
	 * @param player : The {@link Player} the position is computed for.
	 * @param filter : The index of the shown level filter, so the ladder knows where to come back to.
	 * @param page : The shown page index, for the same reason.
	 * @return The header block, closed by the rule cutting the page into blocks.
	 */
	private String getListHeader(Player player, int filter, int page)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final int rank = getRank(player.getObjectId());
		final int points = getPoints(player.getObjectId());

		final int width = data.getWidth();
		final int linkWidth = Math.max(1, Math.min(width - 2, data.getListButtonWidth()));
		final int pointsWidth = Math.max(1, (width - linkWidth) / 2);

		final StringBuilder sb = new StringBuilder(512);

		StringUtil.append(sb, getRowStart(data.getRowColor()));
		StringUtil.append(sb, getCell(Math.max(1, width - linkWidth - pointsWidth), data.getGroupHeight(), "left", colorize(data.getLabelColor(), escape(data.getRankPrefix())) + colorize(data.getValueColor(), (rank > 0) ? String.valueOf(rank) : escape(data.getUnrankedLabel()))));
		StringUtil.append(sb, getCell(pointsWidth, 0, "right", colorize(data.getCountColor(), StringUtil.formatNumber(points) + escape(data.getPointsLabel()))));
		StringUtil.append(sb, getCell(linkWidth, 0, "center", getLink(getBypass("r " + filter + " " + page + " 0"), data.getRankLabel(), data.getTabColor())));
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
	private static String getFilters(int filter)
	{
		final RaidBookData data = RaidBookData.getInstance();
		final List<LevelFilter> filters = data.getFilters();

		final int cellWidth = Math.max(1, data.getWidth() / filters.size());

		final StringBuilder sb = new StringBuilder(512);

		StringUtil.append(sb, getRowStart(data.getRowColor()));

		for (int i = 0; i < filters.size(); i++)
		{
			// The last cell takes whatever is left of the layout width, which absorbs the rounding of an uneven division.
			final int width = (i == filters.size() - 1) ? Math.max(1, data.getWidth() - i * cellWidth) : cellWidth;
			final String label = escape(filters.get(i).label());

			StringUtil.append(sb, getCell(width, data.getGroupHeight(), "center", (i == filter) ? colorize(data.getActiveFilterColor(), label) : getLink(getBypass("l " + i + " 0"), filters.get(i).label(), data.getFilterColor())));
		}

		StringUtil.append(sb, ROW_END);
		sb.append(getSeparator());

		return sb.toString();
	}

	/**
	 * One row of the main page. The name column holds the name and the level of the raid boss on its first line and nothing but the progress bar on its second one : the client breaks the line right
	 * after an image, so anything written next to a bar lands on a third line and makes the row taller than the ones around it. The counter of the bar rides under the hunting level instead, which is
	 * the column it belongs to anyway.
	 * @param player : The {@link Player} the hunting record is read for.
	 * @param template : The raid boss to render.
	 * @param filter : The index of the shown level filter, carried over to the detail page.
	 * @param page : The shown page index, carried over for the same reason.
	 * @return The whole row, rendered as its own table, its background color left as the {@link #BAND} placeholder.
	 */
	private String getBossRow(Player player, NpcTemplate template, int filter, int page)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final int kills = getKills(player.getObjectId(), template.getNpcId());
		final int level = getHuntLevel(kills);

		final String name = colorize(data.getNameColor(), escape(truncate(template.getName(), data.getNameChars()))) + " " + colorize(data.getBossLevelColor(), escape(data.getLevelPrefix()) + template.getLevel());

		final StringBuilder sb = new StringBuilder(768);

		StringUtil.append(sb, getRowStart());
		StringUtil.append(sb, getCell(data.getListNameWidth(), data.getRowHeight(), "left", name + "<br1>" + getBar(kills)));
		StringUtil.append(sb, getCell(data.getListLevelWidth(), 0, "center", colorize(data.getHuntLevelColor(), escape(data.getHuntLevelPrefix()) + level) + "<br1>" + colorize(data.getCountColor(), getProgressText(kills))));
		StringUtil.append(sb, getCell(data.getListButtonWidth(), 0, "center", getLink(getBypass("i " + template.getNpcId() + " " + TAB_REWARDS + " 0 " + filter + " " + page), data.getDetailsLabel(), data.getTabColor())));
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
	 */
	private void showDetail(Player player, int bossId, int tab, int page, int filter, int listPage)
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

		if (rows.isEmpty())
			sb.append(getEmptyRow(data.getGroupHeight()));

		// The tab menu right above is drawn on the plain band color, so the content starts on the other one.
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
		final String context = " " + shownTab + " " + page + " " + filter + " " + listPage;

		String html = HtmCache.getInstance().getHtmForce(DETAIL_HTM);
		html = html.replace("%title%", escape(template.getName()) + " - " + escape(data.getLevelPrefix()) + template.getLevel());
		html = html.replace("%stats%", getStats(player, template));
		html = html.replace("%hunt%", getHunt(player, bossId));
		html = html.replace("%buttons%", getDetailButtons(bossId, context, filter, listPage));
		html = html.replace("%tabs%", getTabs(bossId, shownTab, filter, listPage));
		html = html.replace("%content%", sb.toString());
		html = html.replace("%footer%", getFooter(page, pages, p -> getBypass("i " + bossId + " " + shownTab + " " + p + " " + filter + " " + listPage)));
		html = html.replace("%filler%", getFiller(getStatsHeight() + getHuntHeight() + data.getGroupHeight() + getBlockHeight() + shownGroups * groupHeight + shown * data.getGroupHeight()));
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
	private static String getStats(Player player, NpcTemplate template)
	{
		final RaidBookData data = RaidBookData.getInstance();
		final BossStats stats = getBossStats(template, player.getStatus().getLevel());

		final StringBuilder sb = new StringBuilder(1536);

		sb.append(getBlockStart());
		sb.append(getStatRow(data.getHpLabel(), stats.hp(), data.getExpLabel(), stats.exp()));
		sb.append(getStatRow(data.getMpLabel(), stats.mp(), data.getSpLabel(), stats.sp()));
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
	 * The hunting block of a detail page : the hunting level and the amount of kills on the first line, the damage bonus and what the next level takes on the second one, then the progress bar itself.
	 * The bar owns its whole row : the client breaks the line right after an image, so a counter written next to it would grow the row by a line.
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

		sb.append(getBlockStart());
		sb.append(getStatRow(data.getHuntLabel(), String.valueOf(level), data.getKillsLabel(), String.valueOf(kills)));
		sb.append(getStatRow(data.getBonusLabel(), format(getDamageBonus(level)) + "%", data.getNextLevelLabel(), (capped) ? escape(data.getMaxLevelLabel()) : String.valueOf(Math.max(0, next))));
		sb.append("</table>");

		StringUtil.append(sb, getRowStart(data.getRowColor()));
		StringUtil.append(sb, getCell(data.getWidth(), data.getGroupHeight(), "center", getBar(kills)));
		StringUtil.append(sb, ROW_END);

		sb.append(getSeparator());

		return sb.toString();
	}

	/**
	 * @return The height, in pixels, the statistics block of a detail page takes, the two rules framing it included.
	 */
	private static int getStatsHeight()
	{
		final RaidBookData data = RaidBookData.getInstance();

		return STATS_ROWS * data.getHeaderHeight() + ((data.getSeparator().isEmpty()) ? 0 : 2 * SEPARATOR_HEIGHT);
	}

	/**
	 * @return The height, in pixels, the hunting block of a detail page takes, the progress bar row and the closing rule included.
	 */
	private static int getHuntHeight()
	{
		final RaidBookData data = RaidBookData.getInstance();

		return HUNT_ROWS * data.getHeaderHeight() + data.getGroupHeight() + ((data.getSeparator().isEmpty()) ? 0 : SEPARATOR_HEIGHT);
	}

	/**
	 * The button row of a detail page : the way back to the list on the left, the radar marker on the right.
	 * @param bossId : The npcId of the shown raid boss.
	 * @param context : The tab, page, filter and list page the search button has to come back to.
	 * @param filter : The index of the level filter the list was showing.
	 * @param listPage : The page index the list was showing.
	 * @return The button row.
	 */
	private static String getDetailButtons(int bossId, String context, int filter, int listPage)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final int half = Math.max(1, data.getWidth() / 2);

		final StringBuilder sb = new StringBuilder(512);

		StringUtil.append(sb, getRowStart(data.getRowColor()));
		StringUtil.append(sb, getCell(half, data.getGroupHeight(), "center", getLink(getBypass("l " + filter + " " + listPage), data.getBackLabel(), data.getTabColor())));
		StringUtil.append(sb, getCell(Math.max(1, data.getWidth() - half), 0, "center", getLink(getBypass("f " + bossId + context), data.getSearchLabel(), data.getActiveTabColor())));
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
	private static String getTabs(int bossId, int tab, int filter, int listPage)
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

			StringUtil.append(sb, getCell(width, data.getGroupHeight(), "center", (i == tab) ? colorize(data.getActiveTabColor(), escape(labels[i])) : getLink(getBypass("i " + bossId + " " + i + " 0 " + filter + " " + listPage), labels[i], data.getTabColor())));
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
				StringUtil.append(sb, getCell(data.getRewardIconWidth(), data.getGroupHeight(), "center", getIcon(item.getId())));
				StringUtil.append(sb, getCell(data.getRewardNameWidth(), 0, "left", colorize(data.getNameColor(), escape(truncate(getItemName(item.getId()), data.getNameChars()))) + " " + colorize(data.getCountColor(), escape(data.getCountPrefix()) + StringUtil.formatNumber(item.getValue()))));
				StringUtil.append(sb, getCell(data.getRewardLevelWidth(), 0, "right", colorize(data.getHuntLevelColor(), escape(data.getLevelPrefix()) + shown)));
				StringUtil.append(sb, ROW_END);

				rows.add(new TabRow(sb.toString(), -1));
			}
		}

		return new TabContent(rows, List.of(), false);
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

		return new TabContent(rows, headers, true);
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
		StringUtil.append(sb, getCell(Math.max(1, data.getWidth() - data.getDropChanceWidth()), data.getGroupHeight(), "left", colorize(data.getGroupTextColor(), escape(caption))));
		StringUtil.append(sb, getCell(data.getDropChanceWidth(), 0, "right", colorize(data.getChanceColor(chance), getChanceText(chance))));
		StringUtil.append(sb, ROW_END);

		return sb.toString();
	}

	private static String getDropRow(DropRow drop)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final String amount = (drop.min() == drop.max()) ? StringUtil.formatNumber(drop.min()) : StringUtil.formatNumber(drop.min()) + data.getCountRange() + StringUtil.formatNumber(drop.max());

		final StringBuilder sb = new StringBuilder(512);

		StringUtil.append(sb, getRowStart());
		StringUtil.append(sb, getCell(data.getDropIconWidth(), data.getGroupHeight(), "center", getIcon(drop.itemId())));
		StringUtil.append(sb, getCell(data.getDropNameWidth(), 0, "left", colorize(data.getNameColor(), escape(truncate(getItemName(drop.itemId()), data.getNameChars()))) + " " + colorize(data.getCountColor(), escape(data.getCountPrefix() + amount))));
		StringUtil.append(sb, getCell(data.getDropChanceWidth(), 0, "right", colorize(data.getChanceColor(drop.chance()), getChanceText(drop.chance()))));
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
			StringUtil.append(sb, getCell(data.getHistoryNameWidth(), data.getGroupHeight(), "left", colorize(data.getValueColor(), escape(truncate(record.playerName(), data.getNameChars())))));
			StringUtil.append(sb, getCell(data.getHistoryClanWidth(), 0, "left", colorize(data.getCountColor(), escape(truncate(clan, data.getNameChars())))));
			StringUtil.append(sb, getCell(data.getHistoryTimeWidth(), 0, "right", colorize(data.getLabelColor(), escape(format.format(new Date(record.time()))))));
			StringUtil.append(sb, ROW_END);

			rows.add(new TabRow(sb.toString(), -1));
		}

		return new TabContent(rows, List.of(), true);
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

		return new TabContent(rows, List.of(), true);
	}

	/**
	 * Generate and send the server wide ladder, summing the points of every raid boss.
	 * @param player : The {@link Player} to send the dialog to.
	 * @param filter : The index of the level filter the list was showing.
	 * @param listPage : The page index the list was showing.
	 * @param page : The page index of the ladder to show.
	 */
	private void showRanking(Player player, int filter, int listPage, int page)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final List<String> rows = getRankRows(player, getRanking());

		final int perPage = data.getRowsPerPage();
		final int pages = Math.max(1, (rows.size() + perPage - 1) / perPage);

		page = Math.min(Math.max(page, 0), pages - 1);

		final int first = page * perPage;
		final int last = Math.min(rows.size(), first + perPage);

		final StringBuilder sb = new StringBuilder(4096);

		if (rows.isEmpty())
			sb.append(getEmptyRow(data.getGroupHeight()));

		int band = 1;
		for (int i = first; i < last; i++)
			sb.append(rows.get(i).replace(BAND, getBandAttribute(band++)));

		final int shown = Math.max(1, last - first);

		String content = HtmCache.getInstance().getHtmForce(RANK_HTM);
		content = content.replace("%title%", escape(data.getRankTitle()));
		content = content.replace("%header%", getRankHeader(player, filter, listPage));
		content = content.replace("%list%", sb.toString());
		content = content.replace("%footer%", getFooter(page, pages, p -> getBypass("r " + filter + " " + listPage + " " + p)));
		content = content.replace("%filler%", getFiller(getBlockHeight() + shown * data.getGroupHeight()));
		content = content.replace("%width%", String.valueOf(data.getWidth()));

		send(player, content);
	}

	/**
	 * The head of the ladder page : the way back to the list, the link to the daily rewards, and the position of the very {@link Player} reading it.
	 * @param player : The {@link Player} the position is computed for.
	 * @param filter : The index of the level filter the list was showing.
	 * @param listPage : The page index the list was showing.
	 * @return The header block, closed by the rule cutting the page into blocks.
	 */
	private String getRankHeader(Player player, int filter, int listPage)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final int rank = getRank(player.getObjectId());
		final int points = getPoints(player.getObjectId());

		final int width = data.getWidth();
		final int linkWidth = Math.max(1, Math.min((width - 2) / 2, data.getListButtonWidth()));
		final int dailyWidth = Math.max(1, Math.min(width - linkWidth - 2, data.getListButtonWidth() + 20));
		final int pointsWidth = Math.max(1, (width - linkWidth - dailyWidth) / 2);

		final StringBuilder sb = new StringBuilder(640);

		StringUtil.append(sb, getRowStart(data.getRowColor()));
		StringUtil.append(sb, getCell(linkWidth, data.getGroupHeight(), "center", getLink(getBypass("l " + filter + " " + listPage), data.getBackLabel(), data.getTabColor())));
		StringUtil.append(sb, getCell(Math.max(1, width - linkWidth - dailyWidth - pointsWidth), 0, "right", colorize(data.getLabelColor(), escape(data.getRankPrefix())) + colorize(data.getValueColor(), (rank > 0) ? String.valueOf(rank) : escape(data.getUnrankedLabel()))));
		StringUtil.append(sb, getCell(pointsWidth, 0, "right", colorize(data.getCountColor(), StringUtil.formatNumber(points) + escape(data.getPointsLabel()))));
		StringUtil.append(sb, getCell(dailyWidth, 0, "center", getLink(getBypass("d " + filter + " " + listPage), data.getDailyLabel(), data.getActiveTabColor())));
		StringUtil.append(sb, ROW_END);
		sb.append(getSeparator());

		return sb.toString();
	}

	/**
	 * Generate and send the daily reward page : what each of the rewarded positions of the server wide ladder is handed every day.
	 * @param player : The {@link Player} to send the dialog to.
	 * @param filter : The index of the level filter the list was showing.
	 * @param listPage : The page index the list was showing.
	 */
	private void showDaily(Player player, int filter, int listPage)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final List<String> rows = new ArrayList<>();

		if (Config.RAIDBOOK_DAILY_ENABLED)
		{
			final List<Integer> places = new ArrayList<>(Config.RAIDBOOK_DAILY_REWARDS.keySet());
			places.sort(null);

			for (int place : places)
			{
				for (IntIntHolder item : Config.RAIDBOOK_DAILY_REWARDS.get(place))
				{
					final StringBuilder row = new StringBuilder(512);

					StringUtil.append(row, getRowStart());
					StringUtil.append(row, getCell(data.getRewardIconWidth(), data.getGroupHeight(), "center", getIcon(item.getId())));
					StringUtil.append(row, getCell(data.getRewardNameWidth(), 0, "left", colorize(data.getNameColor(), escape(truncate(getItemName(item.getId()), data.getNameChars()))) + " " + colorize(data.getCountColor(), escape(data.getCountPrefix()) + StringUtil.formatNumber(item.getValue()))));
					StringUtil.append(row, getCell(data.getRewardLevelWidth(), 0, "right", colorize(data.getHuntLevelColor(), place + escape(data.getPlaceSuffix()))));
					StringUtil.append(row, ROW_END);

					rows.add(row.toString());
				}
			}
		}

		final StringBuilder sb = new StringBuilder(2048);

		if (rows.isEmpty())
			sb.append(getEmptyRow(data.getGroupHeight()));

		int band = 1;
		for (String row : rows)
			sb.append(row.replace(BAND, getBandAttribute(band++)));

		final int shown = Math.max(1, rows.size());

		final int half = Math.max(1, data.getWidth() / 2);

		final StringBuilder header = new StringBuilder(384);
		StringUtil.append(header, getRowStart(data.getRowColor()));
		StringUtil.append(header, getCell(half, data.getGroupHeight(), "center", getLink(getBypass("r " + filter + " " + listPage + " 0"), data.getRankLabel(), data.getTabColor())));
		StringUtil.append(header, getCell(Math.max(1, data.getWidth() - half), 0, "center", colorize(data.getActiveTabColor(), escape(data.getDailyLabel()))));
		StringUtil.append(header, ROW_END);
		header.append(getSeparator());

		String content = HtmCache.getInstance().getHtmForce(DAILY_HTM);
		content = content.replace("%title%", escape(data.getDailyTitle()));
		content = content.replace("%header%", header.toString());
		content = content.replace("%list%", sb.toString());

		// The page holds everything it has to show, but the selector row is still emitted : it is what the shared "overhead" of the layout counts on.
		content = content.replace("%footer%", getFooter(0, 1, p -> getBypass("d " + filter + " " + listPage)));
		content = content.replace("%filler%", getFiller(getBlockHeight() + shown * data.getGroupHeight()));
		content = content.replace("%width%", String.valueOf(data.getWidth()));

		send(player, content);
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
			StringUtil.append(sb, getCell(data.getRankPosWidth(), data.getGroupHeight(), "center", colorize(data.getLabelColor(), String.valueOf(i + 1))));
			StringUtil.append(sb, getCell(data.getRankNameWidth(), 0, "left", colorize((self) ? data.getSelfColor() : data.getNameColor(), escape(truncate(name, data.getNameChars())))));
			StringUtil.append(sb, getCell(data.getRankClanWidth(), 0, "left", colorize(data.getCountColor(), escape(truncate(clan, data.getNameChars())))));
			StringUtil.append(sb, getCell(data.getRankPointsWidth(), 0, "right", colorize(data.getCountColor(), StringUtil.formatNumber(row.score()))));
			StringUtil.append(sb, ROW_END);

			rows.add(sb.toString());
		}

		return rows;
	}

	/**
	 * The progress bar of a hunting level, drawn as two textures side by side - the filled part of the current level, then whatever is left of it. It always owns a line of its own : the client breaks
	 * the line right after an image, so whatever is written next to a bar lands under it anyway.
	 * @param kills : The amount of kills of one {@link Player} on one raid boss.
	 * @return The bar, or an empty {@link String} when the datapack holds no texture.
	 */
	private static String getBar(int kills)
	{
		final RaidBookData data = RaidBookData.getInstance();
		if (data.getBarFilled().isEmpty() && data.getBarEmpty().isEmpty())
			return "";

		final int width = data.getBarWidth();
		final int filled = Math.min(width, Math.max(0, (int) Math.round(width * getProgress(kills))));

		final StringBuilder sb = new StringBuilder(160);

		// A zero width image is drawn at its own texture width by the client, so an empty side is simply left out.
		if (filled > 0 && !data.getBarFilled().isEmpty())
			StringUtil.append(sb, "<img src=\"", data.getBarFilled(), "\" width=", filled, " height=", data.getBarHeight(), ">");

		if (filled < width && !data.getBarEmpty().isEmpty())
			StringUtil.append(sb, "<img src=\"", data.getBarEmpty(), "\" width=", width - filled, " height=", data.getBarHeight(), ">");

		return sb.toString();
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

		final int lower = getKillsForLevel(level);
		final int upper = getKillsForLevel(level + 1);

		return Math.min(1., Math.max(0., (kills - lower) / (double) Math.max(1, upper - lower)));
	}

	/**
	 * @param kills : The amount of kills of one {@link Player} on one raid boss.
	 * @return The text sitting next to the progress bar, being the kills done over the kills the next level takes.
	 */
	private static String getProgressText(int kills)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final int level = getHuntLevel(kills);
		if (Config.RAIDBOOK_MAX_LEVEL > 0 && level >= Config.RAIDBOOK_MAX_LEVEL)
			return escape(data.getMaxLevelLabel());

		return kills + "/" + getKillsForLevel(level + 1);
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

		return getRowStart(data.getAltRowColor()) + getCell(data.getWidth(), height, "center", colorize(data.getDisabledColor(), escape(data.getEmptyLabel()))) + ROW_END;
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
		final RaidBookData data = RaidBookData.getInstance();

		// The gap sits between the two columns, so the caption of the right one never touches the value of the left one, which is right aligned on the column edge.
		final int gap = Math.min(data.getHeaderGap(), data.getWidth() - 2);
		final int columnWidth = Math.max(2, (data.getWidth() - gap) / 2);
		final int labelWidth = Math.max(1, Math.min(data.getHeaderLabelWidth(), columnWidth - 1));

		final StringBuilder sb = new StringBuilder(512);

		sb.append("<tr>");
		sb.append(getCell(labelWidth, data.getHeaderHeight(), "left", colorize(data.getLabelColor(), escape(leftLabel))));
		sb.append(getCell(columnWidth - labelWidth, 0, "right", colorize(data.getValueColor(), leftValue)));

		if (gap > 0)
			sb.append(getCell(gap, 0, "left", ""));

		sb.append(getCell(labelWidth, 0, "left", colorize(data.getLabelColor(), escape(rightLabel))));

		// The last cell takes whatever is left of the layout width, which absorbs the rounding of an odd width.
		sb.append(getCell(Math.max(1, data.getWidth() - columnWidth - gap - labelWidth), 0, "right", colorize(data.getValueColor(), rightValue)));
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
		return "<td width=" + width + " height=" + RaidBookData.getInstance().getGroupHeight() + " align=center>" + content + "</td>";
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
