package net.sf.l2j.gameserver.taskmanager;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import net.sf.l2j.commons.pool.ThreadPool;

import net.sf.l2j.gameserver.model.actor.Npc;
import net.sf.l2j.gameserver.network.serverpackets.MagicSkillUse;

/**
 * Replay the visual skill of the registered {@link Npc}s, so their effect (a light beam, a magic circle...) never stops.<br>
 * <br>
 * A cast animation only lives for its hit time, so it has to be sent again and again ; the period is the NPC own one. Only the NPCs carrying a visual skill are registered, the ones wearing a static {@link net.sf.l2j.gameserver.enums.skills.AbnormalEffect} mask cost nothing and never come here.
 */
public final class NpcVisualEffectTaskManager implements Runnable
{
	private static final int TICK_DELAY = 500;

	private final Map<Npc, Long> _npcs = new ConcurrentHashMap<>();

	protected NpcVisualEffectTaskManager()
	{
		ThreadPool.scheduleAtFixedRate(this, TICK_DELAY, TICK_DELAY);
	}

	@Override
	public final void run()
	{
		// List is empty, skip.
		if (_npcs.isEmpty())
			return;

		// Get current time.
		final long currentTime = System.currentTimeMillis();

		// Loop all Npcs.
		for (Map.Entry<Npc, Long> entry : _npcs.entrySet())
		{
			final Npc npc = entry.getKey();

			// The Npc is gone or lost its visual skill, drop it.
			if (npc.isDecayed() || npc.getVisualSkillId() <= 0)
			{
				_npcs.remove(npc);
				continue;
			}

			// The previous animation is still running.
			if (currentTime < entry.getValue())
				continue;

			final int period = npc.getVisualSkillPeriod();

			_npcs.put(npc, currentTime + period);

			// The hit time covers the whole period, so the animation doesn't blink between two replays.
			npc.broadcastPacket(new MagicSkillUse(npc, npc, npc.getVisualSkillId(), npc.getVisualSkillLevel(), period, 0));
		}
	}

	/**
	 * Add the {@link Npc} set as parameter to the {@link NpcVisualEffectTaskManager}. Npcs without a visual skill are ignored.
	 * @param npc : The {@link Npc} to add.
	 */
	public final void add(Npc npc)
	{
		if (npc.getVisualSkillId() <= 0)
			return;

		// Play it on the next tick.
		_npcs.put(npc, 0L);
	}

	/**
	 * Remove the {@link Npc} set as parameter from the {@link NpcVisualEffectTaskManager}.
	 * @param npc : The {@link Npc} to remove.
	 */
	public final void remove(Npc npc)
	{
		_npcs.remove(npc);
	}

	public static final NpcVisualEffectTaskManager getInstance()
	{
		return SingletonHolder.INSTANCE;
	}

	private static class SingletonHolder
	{
		protected static final NpcVisualEffectTaskManager INSTANCE = new NpcVisualEffectTaskManager();
	}
}
