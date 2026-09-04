package net.sf.l2j.gameserver.scripting.task;

import net.sf.l2j.gameserver.data.manager.RaidBookManager;
import net.sf.l2j.gameserver.scripting.ScheduledQuest;

/**
 * Hands out the monthly rewards of the raid boss book, on the first day of every month, and wipes the board it read them off.<br>
 * <br>
 * The monthly ladder ranks the players on the amount of days they topped the daily one, so it is only ever fed by {@link RaidBookDailyReward} - which is why this task is scheduled a few minutes after
 * it on data/xml/scripts.xml : the day which just ended still belongs to the month being closed.<br>
 * <br>
 * The rewarded positions and what each of them gives live on config/mods/raidbook.properties. A winner who happens to be offline doesn't lose anything : the reward waits for him in database and is
 * handed out on his next login.
 */
public final class RaidBookMonthlyReward extends ScheduledQuest
{
	public RaidBookMonthlyReward()
	{
		super(-1, "task");
	}

	@Override
	public final void onStart()
	{
		RaidBookManager.getInstance().runMonthlyRewards();
	}

	@Override
	public final void onEnd()
	{
		// Do nothing.
	}
}
