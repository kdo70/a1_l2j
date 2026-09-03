package net.sf.l2j.gameserver.taskmanager;

import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import net.sf.l2j.commons.pool.ThreadPool;
import net.sf.l2j.commons.random.Rnd;

import net.sf.l2j.gameserver.model.actor.Npc;

/**
 * Handle all {@link Npc} AI tasks.<br>
 * <br>
 * Rather than ticking the whole world on a single, shared one second boundary, {@link Npc}s are spread over
 * {@link #BUCKET_COUNT} buckets. Each bucket keeps its own one second period, but starts offset from the others. An
 * {@link Npc} is therefore still processed once per second, while world decisions (wander, social, aggro decay) are
 * spread over the whole second - which both removes the visible "lockstep" behavior and flattens the CPU spike.
 */
public final class AiTaskManager
{
	/** Amount of buckets the {@link Npc}s are spread over. Bucket N ticks at (N * {@link #TICK_DELAY}) ms. */
	private static final int BUCKET_COUNT = 20;
	private static final long PERIOD = 1000L;
	private static final long TICK_DELAY = PERIOD / BUCKET_COUNT;
	
	private final Set<Npc>[] _buckets;
	private final Map<Npc, Integer> _npcs = new ConcurrentHashMap<>();
	
	@SuppressWarnings("unchecked")
	protected AiTaskManager()
	{
		_buckets = new Set[BUCKET_COUNT];
		
		for (int i = 0; i < BUCKET_COUNT; i++)
		{
			final Set<Npc> bucket = ConcurrentHashMap.newKeySet();
			_buckets[i] = bucket;
			
			// Run each bucket once per second, offset from the previous one.
			ThreadPool.scheduleAtFixedRate(() -> run(bucket), TICK_DELAY * (i + 1), PERIOD);
		}
	}
	
	private static final void run(Set<Npc> bucket)
	{
		// Loop all Npcs of that bucket.
		for (Npc npc : bucket)
			npc.getAI().runAI();
	}
	
	/**
	 * Add the {@link Npc} set as parameter to the {@link AiTaskManager}, in a randomly picked bucket.
	 * @param npc : The {@link Npc} to add.
	 */
	public final void add(Npc npc)
	{
		npc.setAISleeping(false);
		
		// Already registered ; don't reroll the bucket, it would shift its tick.
		if (_npcs.containsKey(npc))
			return;
		
		final int index = Rnd.get(BUCKET_COUNT);
		
		_npcs.put(npc, index);
		_buckets[index].add(npc);
	}
	
	/**
	 * Remove the {@link Npc} set as parameter from the {@link AiTaskManager}.
	 * @param npc : The {@link Npc} to remove.
	 */
	public final void remove(Npc npc)
	{
		npc.setAISleeping(true);
		
		final Integer index = _npcs.remove(npc);
		if (index != null)
			_buckets[index].remove(npc);
	}
	
	public static final AiTaskManager getInstance()
	{
		return SingletonHolder.INSTANCE;
	}
	
	private static final class SingletonHolder
	{
		protected static final AiTaskManager INSTANCE = new AiTaskManager();
	}
}
