package net.sf.l2j.gameserver.scripting;

import java.util.Objects;
import java.util.concurrent.ScheduledFuture;

import net.sf.l2j.commons.pool.ThreadPool;
import net.sf.l2j.commons.random.Rnd;

import net.sf.l2j.gameserver.model.actor.Npc;
import net.sf.l2j.gameserver.model.actor.Player;

public class QuestTimer
{
	private final Quest _quest;
	private final String _name;
	private final Npc _npc;
	private final Player _player;
	private final long _period;
	
	private volatile boolean _isCancelled;
	
	private ScheduledFuture<?> _schedular;
	
	QuestTimer(Quest quest, String name, Npc npc, Player player, long initial, long period, boolean isRandomized)
	{
		_quest = quest;
		_name = name;
		_npc = npc;
		_player = player;
		_period = period;
		
		if (period > 0)
		{
			// Randomized timer ; spread the very first tick over the whole period, then self-schedule each tick.
			if (isRandomized)
				_schedular = ThreadPool.schedule(this::runRandomizedTick, randomize(initial) + Rnd.get(period));
			else
				_schedular = ThreadPool.scheduleAtFixedRate(this::runTick, initial, period);
		}
		else
			_schedular = ThreadPool.schedule(this::runOnce, initial);
	}
	
	/**
	 * @param delay : The delay to randomize, in milliseconds.
	 * @return The given delay, altered by +/- 30% and floored to 100 milliseconds.
	 */
	private static long randomize(long delay)
	{
		if (delay <= 0)
			return 0;
		
		return Math.max(100L, (delay * Rnd.get(70, 130)) / 100L);
	}
	
	@Override
	public int hashCode()
	{
		return Objects.hash(_name, _npc, _player, _quest);
	}
	
	@Override
	public boolean equals(Object obj)
	{
		if (this == obj)
			return true;
		
		if (obj == null)
			return false;
		
		if (!(obj instanceof QuestTimer other))
			return false;
		
		return Objects.equals(_name, other._name) && Objects.equals(_npc, other._npc) && Objects.equals(_player, other._player) && Objects.equals(_quest, other._quest);
	}
	
	@Override
	public final String toString()
	{
		return _name;
	}
	
	/**
	 * @return The name of the {@link QuestTimer}.
	 */
	public final String getName()
	{
		return _name;
	}
	
	/**
	 * @return The {@link Npc} of the {@link QuestTimer}.
	 */
	public final Npc getNpc()
	{
		return _npc;
	}
	
	/**
	 * @return The {@link Player} of the {@link QuestTimer}.
	 */
	public final Player getPlayer()
	{
		return _player;
	}
	
	private void runTick()
	{
		// Notify.
		_quest.notifyTimer(_name, _npc, _player);
	}
	
	private void runRandomizedTick()
	{
		if (_isCancelled)
			return;
		
		// Schedule the next tick first, so a cancel() fired by the notification below cancels the new task.
		_schedular = ThreadPool.schedule(this::runRandomizedTick, randomize(_period));
		
		// Notify.
		_quest.notifyTimer(_name, _npc, _player);
	}
	
	private void runOnce()
	{
		// Remove it from the Quest first (the timer event may create new timer with same name -> it would be duplicate and skipped).
		_quest.removeQuestTimer(this);
		
		// Notify.
		_quest.notifyTimer(_name, _npc, _player);
	}
	
	/**
	 * Cancel the {@link QuestTimer}.
	 */
	public final void cancel()
	{
		_isCancelled = true;
		
		if (_schedular != null)
		{
			_schedular.cancel(false);
			_schedular = null;
		}
		
		_quest.removeQuestTimer(this);
	}
}