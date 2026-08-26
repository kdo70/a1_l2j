package net.sf.l2j.gameserver.data.manager;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ScheduledFuture;

import net.sf.l2j.commons.logging.CLogger;
import net.sf.l2j.commons.pool.ThreadPool;

import net.sf.l2j.Config;
import net.sf.l2j.gameserver.model.actor.Player;
import net.sf.l2j.gameserver.network.GameClient;
import net.sf.l2j.gameserver.network.serverpackets.ExShowScreenMessage;

/**
 * Checks the version a client reports against {@link Config#CLIENT_VERSION}, and disconnects the ones which don't match.<br>
 * <br>
 * A client rebuilt from tools/client reports with the {@link #BYPASS} bypass as soon as it enters the world ; that report is expected within {@link Config#CLIENT_VERSION_TIMEOUT}, which is what makes a stock client - it never reports anything - fail the check as well. Both the mismatch and the silence end the same way : {@link Config#CLIENT_VERSION_MESSAGE} on the screen and in the chat, then the connection is closed {@link #KICK_DELAY} later, so the message has the time to be drawn.<br>
 * <br>
 * An empty {@link Config#CLIENT_VERSION} disables the whole thing and nothing below ever runs.
 */
public class ClientVersionManager
{
	private static final CLogger LOGGER = new CLogger(ClientVersionManager.class.getName());
	
	/** The bypass a rebuilt client reports its version with, followed by that version. */
	public static final String BYPASS = "_ver ";
	
	/** Longest version honored ; a longer report is malformed and counts as a mismatch. */
	private static final int MAX_VERSION_LENGTH = 32;
	
	/** How long {@link Config#CLIENT_VERSION_MESSAGE} stays on the screen, in ms. */
	private static final int MESSAGE_TIME = 10000;
	
	/** Delay between that message and the disconnection, in ms. */
	private static final long KICK_DELAY = 3000L;
	
	/** The clients which entered the world and didn't report yet, with the task which kicks them if they never do. Keyed by connection, so a relog is another entry ; an entry drops itself as soon as either happens. */
	private final Map<GameClient, ScheduledFuture<?>> _pending = new ConcurrentHashMap<>();
	
	/**
	 * @return True if a version is configured, false if the check is disabled.
	 */
	public boolean isEnabled()
	{
		return !Config.CLIENT_VERSION.isEmpty();
	}
	
	/**
	 * Start waiting for the version report of a {@link Player} which just entered the world.
	 * @param player : The {@link Player} to wait for.
	 */
	public void onEnterWorld(Player player)
	{
		if (!isEnabled())
			return;
		
		final GameClient client = player.getClient();
		if (client == null)
			return;
		
		_pending.put(client, ThreadPool.schedule(() ->
		{
			_pending.remove(client);
			
			kick(client, null);
		}, Config.CLIENT_VERSION_TIMEOUT));
	}
	
	/**
	 * Handle the version a client reported. Only the first report of a session counts ; the following ones are dropped, which is what keeps that bypass - it is answered ahead of the flood protector - from being worth spamming.
	 * @param client : The {@link GameClient} which reported.
	 * @param version : The version it reported.
	 */
	public void onReport(GameClient client, String version)
	{
		if (!isEnabled())
			return;
		
		final ScheduledFuture<?> task = _pending.remove(client);
		if (task == null)
			return;
		
		task.cancel(false);
		
		if (version.length() <= MAX_VERSION_LENGTH && version.equals(Config.CLIENT_VERSION))
			return;
		
		kick(client, version);
	}
	
	/**
	 * Tell a {@link GameClient} to update, then close it.
	 * @param client : The {@link GameClient} to disconnect.
	 * @param version : The version it reported, or null if it reported none.
	 */
	private static void kick(GameClient client, String version)
	{
		final Player player = client.getPlayer();
		if (player == null || client.isDetached())
			return;
		
		LOGGER.info("{} is being disconnected, its client reports '{}' while '{}' is expected.", player.getName(), (version == null) ? "nothing" : version, Config.CLIENT_VERSION);
		
		player.sendPacket(new ExShowScreenMessage(Config.CLIENT_VERSION_MESSAGE, MESSAGE_TIME));
		player.sendMessage(Config.CLIENT_VERSION_MESSAGE);
		
		ThreadPool.schedule(client::closeNow, KICK_DELAY);
	}
	
	public static ClientVersionManager getInstance()
	{
		return SingletonHolder.INSTANCE;
	}
	
	private static class SingletonHolder
	{
		protected static final ClientVersionManager INSTANCE = new ClientVersionManager();
	}
}
