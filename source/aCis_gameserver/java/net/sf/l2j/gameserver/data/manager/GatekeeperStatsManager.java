package net.sf.l2j.gameserver.data.manager;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

import net.sf.l2j.commons.logging.CLogger;
import net.sf.l2j.commons.pool.ConnectionPool;
import net.sf.l2j.commons.pool.ThreadPool;

import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperPoint;

/**
 * Loads and stores the amount of times each {@link GatekeeperPoint} has been used.<br>
 * <br>
 * The database is only read once, at startup. Counters are then handled in memory ; a teleport simply increments an {@link AtomicInteger} and flags the point id as dirty. Dirty entries are batch
 * written every {@link #FLUSH_PERIOD}, and on shutdown - which means the write amount doesn't depend on the teleport amount, but on the amount of distinct points used within a period.<br>
 * <br>
 * The popularity ranking is a sorted view of the memory content, cached during {@link #RANKING_TTL} to avoid sorting it on each dialog opening.
 */
public class GatekeeperStatsManager
{
	private static final CLogger LOGGER = new CLogger(GatekeeperStatsManager.class.getName());

	private static final String LOAD_STATS = "SELECT loc_id, teleport_count, last_used FROM gatekeeper_stats";
	private static final String STORE_STAT = "INSERT INTO gatekeeper_stats (loc_id, teleport_count, last_used) VALUES (?,?,?) ON DUPLICATE KEY UPDATE teleport_count=VALUES(teleport_count), last_used=VALUES(last_used)";
	private static final String TRUNCATE_STATS = "TRUNCATE gatekeeper_stats";

	/** The delay between two database flushes, in milliseconds. */
	private static final long FLUSH_PERIOD = 300000L;

	/** The lifetime of the cached popularity ranking, in milliseconds. */
	private static final long RANKING_TTL = 30000L;

	private final Map<Integer, Stat> _stats = new ConcurrentHashMap<>();
	private final Set<Integer> _dirtyIds = ConcurrentHashMap.newKeySet();

	private volatile List<Integer> _ranking = Collections.emptyList();
	private volatile long _rankingTimestamp;

	protected GatekeeperStatsManager()
	{
		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement ps = con.prepareStatement(LOAD_STATS);
			ResultSet rs = ps.executeQuery())
		{
			while (rs.next())
				_stats.put(rs.getInt("loc_id"), new Stat(rs.getInt("teleport_count"), rs.getLong("last_used") * 1000L));
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't load gatekeeper teleport counters.", e);
		}
		LOGGER.info("Loaded {} gatekeeper teleport counters.", _stats.size());

		ThreadPool.scheduleAtFixedRate(this::store, FLUSH_PERIOD, FLUSH_PERIOD);
	}

	/**
	 * Increment the teleport counter of a given {@link GatekeeperPoint} id. The database isn't hit, the entry is only flagged as dirty.
	 * @param pointId : The {@link GatekeeperPoint} id to increment.
	 */
	public void increase(int pointId)
	{
		_stats.computeIfAbsent(pointId, id -> new Stat(0, 0)).increase();
		_dirtyIds.add(pointId);
	}

	/**
	 * @param pointId : The {@link GatekeeperPoint} id to test.
	 * @return The amount of times the given {@link GatekeeperPoint} id has been used.
	 */
	public int getCount(int pointId)
	{
		final Stat stat = _stats.get(pointId);
		return (stat == null) ? 0 : stat.getCount();
	}

	/**
	 * @param pointId : The {@link GatekeeperPoint} id to test.
	 * @return The timestamp of the last use of the given {@link GatekeeperPoint} id, 0 if never used.
	 */
	public long getLastUsed(int pointId)
	{
		final Stat stat = _stats.get(pointId);
		return (stat == null) ? 0 : stat.getLastUsed();
	}

	/**
	 * @return The {@link List} of used {@link GatekeeperPoint} ids, sorted by descending teleport count. The result is cached during {@link #RANKING_TTL}.
	 */
	public List<Integer> getRanking()
	{
		final long currentTime = System.currentTimeMillis();
		if (currentTime - _rankingTimestamp < RANKING_TTL)
			return _ranking;

		_ranking = _stats.entrySet().stream().filter(e -> e.getValue().getCount() > 0).sorted(Comparator.comparingInt((Map.Entry<Integer, Stat> e) -> e.getValue().getCount()).reversed()).map(Map.Entry::getKey).toList();
		_rankingTimestamp = currentTime;

		return _ranking;
	}

	/**
	 * Write every dirty entry on the database, using a single batch. Called periodically and on shutdown.
	 */
	public void store()
	{
		if (_dirtyIds.isEmpty())
			return;

		final List<Integer> ids = new ArrayList<>(_dirtyIds);
		_dirtyIds.removeAll(ids);

		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement ps = con.prepareStatement(STORE_STAT))
		{
			for (int id : ids)
			{
				final Stat stat = _stats.get(id);
				if (stat == null)
					continue;

				ps.setInt(1, id);
				ps.setInt(2, stat.getCount());
				ps.setLong(3, stat.getLastUsed() / 1000L);
				ps.addBatch();
			}
			ps.executeBatch();
		}
		catch (Exception e)
		{
			// Feed back the ids, in order to retry on the next flush.
			_dirtyIds.addAll(ids);

			LOGGER.error("Couldn't store gatekeeper teleport counters.", e);
		}
	}

	/**
	 * Clean both memory and database from any teleport counter.
	 */
	public void cleanUp()
	{
		_stats.clear();
		_dirtyIds.clear();
		_ranking = Collections.emptyList();
		_rankingTimestamp = 0;

		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement ps = con.prepareStatement(TRUNCATE_STATS))
		{
			ps.executeUpdate();
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't delete gatekeeper teleport counters.", e);
		}
	}

	private static final class Stat
	{
		private final AtomicInteger _count;

		private volatile long _lastUsed;

		protected Stat(int count, long lastUsed)
		{
			_count = new AtomicInteger(count);
			_lastUsed = lastUsed;
		}

		public void increase()
		{
			_count.incrementAndGet();
			_lastUsed = System.currentTimeMillis();
		}

		public int getCount()
		{
			return _count.get();
		}

		public long getLastUsed()
		{
			return _lastUsed;
		}
	}

	public static GatekeeperStatsManager getInstance()
	{
		return SingletonHolder.INSTANCE;
	}

	private static class SingletonHolder
	{
		protected static final GatekeeperStatsManager INSTANCE = new GatekeeperStatsManager();
	}
}
