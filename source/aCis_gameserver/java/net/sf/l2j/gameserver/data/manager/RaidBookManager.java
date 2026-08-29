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
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.StringTokenizer;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.IntFunction;

import net.sf.l2j.commons.lang.StringUtil;
import net.sf.l2j.commons.logging.CLogger;
import net.sf.l2j.commons.pool.ConnectionPool;

import net.sf.l2j.Config;
import net.sf.l2j.gameserver.data.cache.HtmCache;
import net.sf.l2j.gameserver.data.sql.PlayerInfoTable;
import net.sf.l2j.gameserver.data.xml.ItemData;
import net.sf.l2j.gameserver.data.xml.ItemIconData;
import net.sf.l2j.gameserver.data.xml.NpcData;
import net.sf.l2j.gameserver.data.xml.RaidBookData;
import net.sf.l2j.gameserver.data.xml.RaidBookData.LevelFilter;
import net.sf.l2j.gameserver.enums.DropType;
import net.sf.l2j.gameserver.model.actor.Creature;
import net.sf.l2j.gameserver.model.actor.Npc;
import net.sf.l2j.gameserver.model.actor.Player;
import net.sf.l2j.gameserver.model.actor.instance.RaidBoss;
import net.sf.l2j.gameserver.model.actor.template.NpcTemplate;
import net.sf.l2j.gameserver.model.holder.IntIntHolder;
import net.sf.l2j.gameserver.model.item.DropCategory;
import net.sf.l2j.gameserver.model.item.DropData;
import net.sf.l2j.gameserver.model.item.kind.Item;
import net.sf.l2j.gameserver.model.location.Location;
import net.sf.l2j.gameserver.model.spawn.ASpawn;
import net.sf.l2j.gameserver.network.serverpackets.ActionFailed;
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
 * boss into one single server wide ladder.<br>
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

	private static final String LOAD_HUNTS = "SELECT char_id, boss_id, kills, points FROM character_raidboss_kills";
	private static final String SAVE_HUNT = "REPLACE INTO character_raidboss_kills (char_id, boss_id, kills, points) VALUES (?,?,?,?)";
	private static final String LOAD_HISTORY = "SELECT boss_id, char_name, clan_name, kill_time FROM raidboss_kill_history ORDER BY kill_time DESC";
	private static final String SAVE_HISTORY = "INSERT INTO raidboss_kill_history (boss_id, char_name, clan_name, kill_time) VALUES (?,?,?,?)";
	private static final String TRIM_HISTORY = "DELETE FROM raidboss_kill_history WHERE boss_id = ? AND kill_time < ?";

	private static final String ROW_END = "</tr></table>";

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

	private final Map<Integer, Map<Integer, HuntData>> _hunts = new ConcurrentHashMap<>();
	private final Map<Integer, Deque<KillRecord>> _history = new ConcurrentHashMap<>();

	/** The sorted list of the raid bosses of the server, built once and dropped by {@link #reload()} - the templates don't move on their own. */
	private volatile List<NpcTemplate> _bosses;

	protected RaidBookManager()
	{
		loadHunts();
		loadHistory();

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

	/**
	 * Register the kill of a raid boss, which is what feeds the whole book : the killers earn a kill and its ranking points, the ones crossing a hunting level are rewarded for it, and the boss gets
	 * one more line on its history.
	 * @param boss : The {@link RaidBoss} which has been killed.
	 * @param killer : The {@link Player} who dealt the killing blow.
	 */
	public void onRaidBossKill(RaidBoss boss, Player killer)
	{
		if (!Config.RAIDBOOK_ENABLED || killer == null)
			return;

		final int bossId = boss.getNpcId();
		final int points = getKillPoints(boss.getStatus().getLevel());

		// A raid boss is a party target ; crediting the sole killer would make the book unreadable to everyone else who fought it.
		final List<Player> credited = new ArrayList<>();
		if (Config.RAIDBOOK_CREDIT_PARTY && killer.getParty() != null)
			credited.addAll(killer.getParty().getMembers());
		else
			credited.add(killer);

		for (Player player : credited)
			addKill(player, bossId, points);

		// The history tells who landed the killing blow, along with the clan he wore at that very moment.
		addHistory(bossId, killer);
	}

	/**
	 * @param bossLevel : The level of the killed raid boss.
	 * @return The amount of ranking points one kill of such a boss is worth.
	 */
	private static int getKillPoints(int bossLevel)
	{
		return Math.max(0, (int) (Config.RAIDBOOK_POINTS_PER_KILL + bossLevel * Config.RAIDBOOK_POINTS_PER_BOSS_LEVEL));
	}

	private void addKill(Player player, int bossId, int points)
	{
		final Map<Integer, HuntData> playerData = _hunts.computeIfAbsent(player.getObjectId(), k -> new ConcurrentHashMap<>());

		// Two kills of the same boss can be credited to the same character within the same breath - a party wiping two spawns at once - so the record is bumped atomically.
		final HuntData current = playerData.compute(bossId, (k, previous) -> new HuntData(((previous == null) ? 0 : previous.kills()) + 1, ((previous == null) ? 0 : previous.points()) + points));

		final int kills = current.kills();

		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement ps = con.prepareStatement(SAVE_HUNT))
		{
			ps.setInt(1, player.getObjectId());
			ps.setInt(2, bossId);
			ps.setInt(3, current.kills());
			ps.setInt(4, current.points());
			ps.executeUpdate();
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't save the raid boss hunting record of {}.", e, player.getName());
		}

		// A level is crossed by the very kill which reaches its own amount, so the reward is only ever given once.
		final int level = getHuntLevel(kills);
		if (level > getHuntLevel(kills - 1))
			giveLevelReward(player, level);
	}

	/**
	 * @param player : The {@link Player} to reward.
	 * @param level : The hunting level which has just been reached.
	 */
	private static void giveLevelReward(Player player, int level)
	{
		for (IntIntHolder item : getLevelReward(level))
			player.addItem(item.getId(), item.getValue(), true);
	}

	private void addHistory(int bossId, Player killer)
	{
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
			player.sendMessage(data.getNoLocationLabel());
			return;
		}

		player.getRadarList().addMarker(loc.getX(), loc.getY(), loc.getZ());
		player.sendMessage(data.getSearchDoneLabel());
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

		for (int i = first; i < last; i++)
			sb.append(getBossRow(player, bosses.get(i), getBandColor(i - first), filter, page));

		final int shown = Math.max(1, last - first);

		// The page selector is built by a lambda, so the browsed range has to be handed to it as a final.
		final int index = filter;

		String content = HtmCache.getInstance().getHtmForce(LIST_HTM);
		content = content.replace("%title%", escape(data.getBookTitle()));
		content = content.replace("%header%", getListHeader(player, filter, page));
		content = content.replace("%filters%", getFilters(index));
		content = content.replace("%list%", sb.toString());
		content = content.replace("%footer%", getFooter(page, pages, p -> getBypass("l " + index + " " + p)));
		content = content.replace("%filler%", getFiller(getListHeaderHeight() + data.getGroupHeight() + SEPARATOR_HEIGHT + shown * data.getRowHeight()));
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
	 * @return The height, in pixels, the head of the main page takes, the rule closing it included.
	 */
	private static int getListHeaderHeight()
	{
		final RaidBookData data = RaidBookData.getInstance();

		return data.getGroupHeight() + ((data.getSeparator().isEmpty()) ? 0 : SEPARATOR_HEIGHT);
	}

	/**
	 * The level filter menu, drawn as one cell per range. The shown range is written with the active color instead of being a link, so a player always reads which one he browses.
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
	 * One row of the main page : the name and the level of the raid boss on the first line, the progress bar of the hunting level right under it, then the hunting level itself and the link to the
	 * detail page.
	 * @param player : The {@link Player} the hunting record is read for.
	 * @param template : The raid boss to render.
	 * @param color : The background color of the row, empty keeping it see-through.
	 * @param filter : The index of the shown level filter, carried over to the detail page.
	 * @param page : The shown page index, carried over for the same reason.
	 * @return The whole row, rendered as its own table.
	 */
	private String getBossRow(Player player, NpcTemplate template, String color, int filter, int page)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final int kills = getKills(player.getObjectId(), template.getNpcId());
		final int level = getHuntLevel(kills);

		final StringBuilder sb = new StringBuilder(768);

		final String name = colorize(data.getNameColor(), escape(truncate(template.getName(), data.getNameChars()))) + " " + colorize(data.getBossLevelColor(), escape(data.getLevelPrefix()) + template.getLevel());

		StringUtil.append(sb, getRowStart(color));
		StringUtil.append(sb, getCell(data.getListNameWidth(), data.getRowHeight(), "left", name + "<br1>" + getBar(kills) + " " + colorize(data.getCountColor(), getProgressText(kills))));
		StringUtil.append(sb, getCell(data.getListLevelWidth(), 0, "center", colorize(data.getHuntLevelColor(), escape(data.getHuntLevelPrefix()) + level)));
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
			player.sendMessage(data.getNotFoundLabel());
			return;
		}

		tab = Math.min(Math.max(tab, 0), TAB_COUNT - 1);

		final List<String> rows = getTabRows(player, template, tab);

		final int perPage = Config.RAIDBOOK_TAB_ROWS_PER_PAGE;
		final int pages = Math.max(1, (rows.size() + perPage - 1) / perPage);

		page = Math.min(Math.max(page, 0), pages - 1);

		final int first = page * perPage;
		final int last = Math.min(rows.size(), first + perPage);

		final StringBuilder sb = new StringBuilder(4096);

		if (rows.isEmpty())
			sb.append(getEmptyRow(data.getGroupHeight()));

		for (int i = first; i < last; i++)
			sb.append(rows.get(i));

		final int shown = Math.max(1, last - first);
		final int shownTab = tab;

		final String context = " " + shownTab + " " + page + " " + filter + " " + listPage;

		String content = HtmCache.getInstance().getHtmForce(DETAIL_HTM);
		content = content.replace("%title%", escape(template.getName()) + " - " + escape(data.getLevelPrefix()) + template.getLevel());
		content = content.replace("%stats%", getStats(player, template));
		content = content.replace("%hunt%", getHunt(player, bossId));
		content = content.replace("%buttons%", getDetailButtons(bossId, context, filter, listPage));
		content = content.replace("%tabs%", getTabs(bossId, shownTab, filter, listPage));
		content = content.replace("%content%", sb.toString());
		content = content.replace("%footer%", getFooter(page, pages, p -> getBypass("i " + bossId + " " + shownTab + " " + p + " " + filter + " " + listPage)));
		content = content.replace("%filler%", getFiller(getStatsHeight() + getHuntHeight() + 2 * data.getGroupHeight() + SEPARATOR_HEIGHT + shown * data.getGroupHeight()));
		content = content.replace("%width%", String.valueOf(data.getWidth()));

		send(player, content);
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
		StringUtil.append(sb, getCell(data.getWidth(), data.getGroupHeight(), "center", getBar(kills) + " " + colorize(data.getCountColor(), getProgressText(kills))));
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
	 * @return The tab row.
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
	 * @return The already rendered rows of the given tab, one entry per row, which is what the paging then slices.
	 */
	private List<String> getTabRows(Player player, NpcTemplate template, int tab)
	{
		switch (tab)
		{
			case TAB_DROP:
				return getDropRows(player, template);

			case TAB_HISTORY:
				return getHistoryRows(template.getNpcId());

			case TAB_RANK:
				return getBossRankRows(player, template.getNpcId());

			default:
				return getRewardRows(player, template.getNpcId());
		}
	}

	/**
	 * The rewards tab : the coming hunting levels and what each of them gives. It opens on the very next level rather than on the first one - what a player reads a reward list for is what he is about
	 * to earn.
	 * @param player : The {@link Player} the hunting record is read for.
	 * @param bossId : The npcId of the shown raid boss.
	 * @return One row per shown level, an item of a level owning a row of its own.
	 */
	private List<String> getRewardRows(Player player, int bossId)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final int level = getHuntLevel(getKills(player.getObjectId(), bossId));

		final List<String> rows = new ArrayList<>();

		for (int i = 1; i <= Config.RAIDBOOK_SHOWN_REWARDS; i++)
		{
			final int shown = level + i;
			if (Config.RAIDBOOK_MAX_LEVEL > 0 && shown > Config.RAIDBOOK_MAX_LEVEL)
				break;

			for (IntIntHolder item : getLevelReward(shown))
			{
				final Item template = ItemData.getInstance().getTemplate(item.getId());
				final String name = (template == null) ? String.valueOf(item.getId()) : truncate(template.getName(), data.getNameChars());

				final StringBuilder sb = new StringBuilder(512);

				StringUtil.append(sb, getRowStart(getBandColor(rows.size())));
				StringUtil.append(sb, getCell(data.getRewardIconWidth(), data.getGroupHeight(), "center", getIcon(item.getId())));
				StringUtil.append(sb, getCell(data.getRewardNameWidth(), 0, "left", colorize(data.getNameColor(), escape(name)) + " " + colorize(data.getCountColor(), escape(data.getCountPrefix()) + StringUtil.formatNumber(item.getValue()))));
				StringUtil.append(sb, getCell(data.getRewardLevelWidth(), 0, "right", colorize(data.getHuntLevelColor(), escape(data.getLevelPrefix()) + shown)));
				StringUtil.append(sb, ROW_END);

				rows.add(sb.toString());
			}
		}

		return rows;
	}

	/**
	 * The drop tab : the whole drop list of the raid boss, sorted by decreasing chance, without any group header - the book shows what falls, and the categories it falls out of are what the shift
	 * click window is for.<br>
	 * <br>
	 * The chance is the chance of the whole draw : the category rolls first, the item is then picked inside of it. The server rates are folded in when "RaidBookApplyRates" is set - they multiply the
	 * amount of rolls of a category, so the result is capped at 100% - and the deep blue penalty of the very {@link Player} reading the book when "RaidBookApplyLevelPenalty" is.
	 * @param player : The {@link Player} the chances are computed for.
	 * @param template : The shown raid boss.
	 * @return One row per dropped item.
	 */
	private static List<String> getDropRows(Player player, NpcTemplate template)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final double levelMultiplier = (Config.RAIDBOOK_APPLY_LEVEL_PENALTY) ? getLevelMultiplier(player.getStatus().getLevel(), template.getLevel()) : 1;

		final List<DropRow> drops = new ArrayList<>();

		for (DropCategory category : template.getDropData())
		{
			if (category.isEmpty())
				continue;

			final DropType type = category.getDropType();
			if (type == DropType.SPOIL)
				continue;

			final double rate = (Config.RAIDBOOK_APPLY_RATES) ? type.getDropRate(true) : 1;

			// A rate is an amount of rolls of the category, not a multiplier of its chance ; a category rolled more than once is simply shown as a certain one.
			final double chance = Math.min(100, category.getChance() * levelMultiplier * rate);

			for (DropData drop : category)
				drops.add(new DropRow(drop.itemId(), Math.min(100, chance * drop.chance() / 100), drop.minDrop(), drop.maxDrop()));
		}

		drops.sort(Comparator.<DropRow> comparingDouble(DropRow::chance).reversed());

		final List<String> rows = new ArrayList<>(drops.size());

		for (DropRow drop : drops)
		{
			final Item item = ItemData.getInstance().getTemplate(drop.itemId());
			final String name = (item == null) ? String.valueOf(drop.itemId()) : truncate(item.getName(), data.getNameChars());

			final String amount = (drop.min() == drop.max()) ? StringUtil.formatNumber(drop.min()) : StringUtil.formatNumber(drop.min()) + data.getCountRange() + StringUtil.formatNumber(drop.max());

			final StringBuilder sb = new StringBuilder(512);

			StringUtil.append(sb, getRowStart(getBandColor(rows.size())));
			StringUtil.append(sb, getCell(data.getDropIconWidth(), data.getGroupHeight(), "center", getIcon(drop.itemId())));
			StringUtil.append(sb, getCell(data.getDropNameWidth(), 0, "left", colorize(data.getNameColor(), escape(name)) + " " + colorize(data.getCountColor(), escape(data.getCountPrefix() + amount))));
			StringUtil.append(sb, getCell(data.getDropChanceWidth(), 0, "right", colorize(data.getChanceColor(drop.chance()), getChanceText(drop.chance()))));
			StringUtil.append(sb, ROW_END);

			rows.add(sb.toString());
		}

		return rows;
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
	private List<String> getHistoryRows(int bossId)
	{
		final RaidBookData data = RaidBookData.getInstance();
		final SimpleDateFormat format = new SimpleDateFormat(data.getTimePattern());

		final List<String> rows = new ArrayList<>();

		for (KillRecord record : getHistory(bossId))
		{
			final String clan = (record.clanName() == null || record.clanName().isEmpty()) ? data.getNoClanLabel() : record.clanName();

			final StringBuilder sb = new StringBuilder(512);

			StringUtil.append(sb, getRowStart(getBandColor(rows.size())));
			StringUtil.append(sb, getCell(data.getHistoryNameWidth(), data.getGroupHeight(), "left", colorize(data.getValueColor(), escape(record.playerName()))));
			StringUtil.append(sb, getCell(data.getHistoryClanWidth(), 0, "left", colorize(data.getCountColor(), escape(clan))));
			StringUtil.append(sb, getCell(data.getHistoryTimeWidth(), 0, "right", colorize(data.getLabelColor(), escape(format.format(new Date(record.time()))))));
			StringUtil.append(sb, ROW_END);

			rows.add(sb.toString());
		}

		return rows;
	}

	/**
	 * The ranking tab of a detail page : the players who killed that very raid boss the most.
	 * @param player : The {@link Player} reading the book, whose own row is highlighted.
	 * @param bossId : The npcId of the shown raid boss.
	 * @return One row per player, holding his position, his name and his amount of kills.
	 */
	private List<String> getBossRankRows(Player player, int bossId)
	{
		final List<RankRow> ranking = new ArrayList<>();

		for (Map.Entry<Integer, Map<Integer, HuntData>> entry : _hunts.entrySet())
		{
			final HuntData data = entry.getValue().get(bossId);
			if (data != null && data.kills() > 0)
				ranking.add(new RankRow(entry.getKey(), data.kills()));
		}

		ranking.sort(Comparator.comparingInt(RankRow::score).reversed());

		return getRankRows(player, ranking, Config.RAIDBOOK_RANKING_SIZE);
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

		final List<String> rows = getRankRows(player, getRanking(), Config.RAIDBOOK_RANKING_SIZE);

		final int perPage = data.getRowsPerPage();
		final int pages = Math.max(1, (rows.size() + perPage - 1) / perPage);

		page = Math.min(Math.max(page, 0), pages - 1);

		final int first = page * perPage;
		final int last = Math.min(rows.size(), first + perPage);

		final StringBuilder sb = new StringBuilder(4096);

		if (rows.isEmpty())
			sb.append(getEmptyRow(data.getGroupHeight()));

		for (int i = first; i < last; i++)
			sb.append(rows.get(i));

		final int shown = Math.max(1, last - first);

		String content = HtmCache.getInstance().getHtmForce(RANK_HTM);
		content = content.replace("%title%", escape(data.getRankTitle()));
		content = content.replace("%header%", getRankHeader(player, filter, listPage));
		content = content.replace("%list%", sb.toString());
		content = content.replace("%footer%", getFooter(page, pages, p -> getBypass("r " + filter + " " + listPage + " " + p)));
		content = content.replace("%filler%", getFiller(getListHeaderHeight() + shown * data.getGroupHeight()));
		content = content.replace("%width%", String.valueOf(data.getWidth()));

		send(player, content);
	}

	/**
	 * The head of the ladder page : the way back to the list, and the position of the very {@link Player} reading it.
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

		final int linkWidth = Math.max(1, Math.min(data.getWidth() - 2, data.getListButtonWidth()));
		final int pointsWidth = Math.max(1, (data.getWidth() - linkWidth) / 2);

		final StringBuilder sb = new StringBuilder(512);

		StringUtil.append(sb, getRowStart(data.getRowColor()));
		StringUtil.append(sb, getCell(linkWidth, data.getGroupHeight(), "center", getLink(getBypass("l " + filter + " " + listPage), data.getBackLabel(), data.getTabColor())));
		StringUtil.append(sb, getCell(Math.max(1, data.getWidth() - linkWidth - pointsWidth), 0, "right", colorize(data.getLabelColor(), escape(data.getRankPrefix())) + colorize(data.getValueColor(), (rank > 0) ? String.valueOf(rank) : escape(data.getUnrankedLabel()))));
		StringUtil.append(sb, getCell(pointsWidth, 0, "right", colorize(data.getCountColor(), StringUtil.formatNumber(points) + escape(data.getPointsLabel()))));
		StringUtil.append(sb, ROW_END);
		sb.append(getSeparator());

		return sb.toString();
	}

	/**
	 * @param player : The {@link Player} reading the book, whose own row is highlighted.
	 * @param ranking : The already sorted ladder to render.
	 * @param limit : The amount of positions to render.
	 * @return One row per position, holding the position itself, the name of the player and his score.
	 */
	private static List<String> getRankRows(Player player, List<RankRow> ranking, int limit)
	{
		final RaidBookData data = RaidBookData.getInstance();

		final List<String> rows = new ArrayList<>();

		for (int i = 0; i < Math.min(limit, ranking.size()); i++)
		{
			final RankRow row = ranking.get(i);

			final String name = PlayerInfoTable.getInstance().getPlayerName(row.objectId());
			if (name == null)
				continue;

			final boolean self = row.objectId() == player.getObjectId();
			final String nameColor = (self) ? data.getSelfColor() : data.getNameColor();

			final StringBuilder sb = new StringBuilder(448);

			StringUtil.append(sb, getRowStart(getBandColor(rows.size())));
			StringUtil.append(sb, getCell(data.getRankPosWidth(), data.getGroupHeight(), "center", colorize(data.getLabelColor(), String.valueOf(i + 1))));
			StringUtil.append(sb, getCell(data.getRankNameWidth(), 0, "left", colorize(nameColor, escape(truncate(name, data.getNameChars())))));
			StringUtil.append(sb, getCell(data.getRankPointsWidth(), 0, "right", colorize(data.getCountColor(), StringUtil.formatNumber(row.score()))));
			StringUtil.append(sb, ROW_END);

			rows.add(sb.toString());
		}

		return rows;
	}

	/**
	 * The progress bar of a hunting level, drawn as two textures side by side - the filled part of the current level, then whatever is left of it.
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
	 * @return The row shown instead of an empty list.
	 */
	private static String getEmptyRow(int height)
	{
		final RaidBookData data = RaidBookData.getInstance();

		return getRowStart(getBandColor(0)) + getCell(data.getWidth(), height, "center", colorize(data.getDisabledColor(), escape(data.getEmptyLabel()))) + ROW_END;
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
	 * @param color : The background color of the row, empty keeping it see-through.
	 * @return The opening tags of a row.
	 */
	private static String getRowStart(String color)
	{
		return "<table width=" + RaidBookData.getInstance().getWidth() + ((color.isEmpty()) ? "" : " bgcolor=\"" + color + "\"") + "><tr>";
	}

	/**
	 * @param index : The index of the band on the current page, 0 being the first one.
	 * @return The background color of the given band, empty meaning transparent.
	 */
	private static String getBandColor(int index)
	{
		final RaidBookData data = RaidBookData.getInstance();

		return (index % 2 == 0) ? data.getRowColor() : data.getAltRowColor();
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
