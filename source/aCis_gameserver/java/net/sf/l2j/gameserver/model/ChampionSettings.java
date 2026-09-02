package net.sf.l2j.gameserver.model;

import java.time.DayOfWeek;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;

import net.sf.l2j.commons.logging.CLogger;

import net.sf.l2j.gameserver.enums.ChampionType;
import net.sf.l2j.gameserver.model.actor.template.NpcTemplate;
import net.sf.l2j.gameserver.model.item.DropData;

/**
 * The whole behavior of one flavor of champion monsters - red or blue - as config/mods/championmobs.properties describes it : how often it shows up and on which monsters, how much tougher and how
 * much more rewarding a champion of that flavor is, what it drops on top of its regular table, and the hours it is handed out at all.<br>
 * <br>
 * Both flavors are read the very same way, out of the very same keys prefixed by their own name, so nothing but the prefix tells them apart on the config file.<br>
 * <br>
 * The schedule of a flavor is its own too : a list of {@link Window}s read from "ChampionMobs&lt;flavor&gt;Schedule", "1-5-0:24" being every working day. A flavor whose property is empty is handed
 * out around the clock, which is what a server not caring about hours writes.
 */
public class ChampionSettings
{
	private static final CLogger LOGGER = new CLogger(ChampionSettings.class.getName());

	/** The amount of days a week holds, which is what a day range wrapping over its end runs over. */
	private static final int WEEK_DAYS = 7;

	/** The hour a window covering the very end of a day is written with, midnight being both the 0 of a day and the 24 of the previous one. */
	private static final int END_OF_DAY = 24;

	/**
	 * One window of the schedule : the days it covers, and the hours of those days it runs on. The end hour is excluded, so "20:23" ends the very moment 23:00 strikes and "0:24" is a whole day.
	 */
	private record Window(Set<DayOfWeek> days, int from, int to)
	{
		/**
		 * @param now : The moment to test.
		 * @return True if the given moment sits inside this window.
		 */
		private boolean matches(LocalDateTime now)
		{
			final int hour = now.getHour();

			if (from < to)
				return days.contains(now.getDayOfWeek()) && hour >= from && hour < to;

			// An end hour below the start hour wraps over midnight, so the tail of the window belongs to the day after the one it opened on.
			return (days.contains(now.getDayOfWeek()) && hour >= from) || (days.contains(now.minusDays(1).getDayOfWeek()) && hour < to);
		}
	}

	private final ChampionType _type;
	private final List<Window> _schedule = new ArrayList<>();

	private boolean _enabled;
	private boolean _passive;
	private int _frequency;
	private String _title = "";
	private int _nameColor = NpcTemplate.NO_NAME_COLOR;
	private int _titleColor = NpcTemplate.NO_NAME_COLOR;
	private int _minLevel;
	private int _maxLevel;

	private int _hpMultiplier = 1;
	private double _pAtkMultiplier = 1.;
	private double _pDefMultiplier = 1.;
	private double _mAtkMultiplier = 1.;
	private double _mDefMultiplier = 1.;

	private double _xpMultiplier = 1.;
	private double _spMultiplier = 1.;
	private double _adenaMultiplier = 1.;
	private double _dropMultiplier = 1.;
	private double _spoilMultiplier = 1.;

	private List<DropData> _drops = Collections.emptyList();

	public ChampionSettings(ChampionType type)
	{
		_type = type;
	}

	public ChampionType getType()
	{
		return _type;
	}

	/**
	 * @return True if this flavor is both enabled and inside one of the windows of its schedule, which is what lets a monster become one of its champions right now.
	 */
	public boolean isActive()
	{
		if (!_enabled || _frequency <= 0)
			return false;

		final LocalDateTime now = LocalDateTime.now();

		for (Window window : _schedule)
		{
			if (window.matches(now))
				return true;
		}

		return false;
	}

	/**
	 * @param level : The level of the tested monster.
	 * @return True if a monster of the given level is allowed to become a champion of this flavor.
	 */
	public boolean isAllowedLevel(int level)
	{
		return level >= _minLevel && level <= _maxLevel;
	}

	public boolean isPassive()
	{
		return _passive;
	}

	public int getFrequency()
	{
		return _frequency;
	}

	public String getTitle()
	{
		return _title;
	}

	/**
	 * @return The color the name of such a champion - the lower line - is painted with, as RRGGBB, or {@link NpcTemplate#NO_NAME_COLOR} to leave it alone.
	 */
	public int getNameColor()
	{
		return _nameColor;
	}

	/**
	 * @return The color the title of such a champion - the upper line - is painted with, as RRGGBB, or {@link NpcTemplate#NO_NAME_COLOR} to leave it alone. A config naming no color of its own for it
	 *         gives it the name's, which is what one single color used to mean.
	 */
	public int getTitleColor()
	{
		return _titleColor;
	}

	public int getHpMultiplier()
	{
		return _hpMultiplier;
	}

	public double getPAtkMultiplier()
	{
		return _pAtkMultiplier;
	}

	public double getPDefMultiplier()
	{
		return _pDefMultiplier;
	}

	public double getMAtkMultiplier()
	{
		return _mAtkMultiplier;
	}

	public double getMDefMultiplier()
	{
		return _mDefMultiplier;
	}

	public double getXpMultiplier()
	{
		return _xpMultiplier;
	}

	public double getSpMultiplier()
	{
		return _spMultiplier;
	}

	public double getAdenaMultiplier()
	{
		return _adenaMultiplier;
	}

	public double getDropMultiplier()
	{
		return _dropMultiplier;
	}

	public double getSpoilMultiplier()
	{
		return _spoilMultiplier;
	}

	/**
	 * @return The extra drops such a champion carries on top of the table of its own template, every one of them rolled on its own.
	 */
	public List<DropData> getDrops()
	{
		return _drops;
	}

	public void setEnabled(boolean enabled)
	{
		_enabled = enabled;
	}

	public void setPassive(boolean passive)
	{
		_passive = passive;
	}

	public void setFrequency(int frequency)
	{
		_frequency = frequency;
	}

	public void setTitle(String title)
	{
		_title = title;
	}

	public void setNameColor(int nameColor)
	{
		_nameColor = nameColor;
	}

	public void setTitleColor(int titleColor)
	{
		_titleColor = titleColor;
	}

	public void setLevelRange(int minLevel, int maxLevel)
	{
		_minLevel = minLevel;
		_maxLevel = maxLevel;
	}

	public void setStatMultipliers(int hp, double pAtk, double pDef, double mAtk, double mDef)
	{
		_hpMultiplier = hp;
		_pAtkMultiplier = pAtk;
		_pDefMultiplier = pDef;
		_mAtkMultiplier = mAtk;
		_mDefMultiplier = mDef;
	}

	public void setRewardMultipliers(double xp, double sp, double adena, double drop, double spoil)
	{
		_xpMultiplier = xp;
		_spMultiplier = sp;
		_adenaMultiplier = adena;
		_dropMultiplier = drop;
		_spoilMultiplier = spoil;
	}

	public void setDrops(List<DropData> drops)
	{
		_drops = drops;
	}

	/**
	 * Read the "ChampionMobs&lt;flavor&gt;Schedule" property of this flavor, holding the hours it is handed out at : a list of windows written as "days-from:to", the days being cut off on the last
	 * dash so a range can carry one of its own. "1-5-0:24" is every working day, "6,7-0:24" every weekend, "1-20:23" a Monday evening, and an end hour below the start hour wraps over midnight.<br>
	 * <br>
	 * An empty property means no restriction at all : this flavor is then handed out around the clock, and its own "Enable" is the only switch left.
	 * @param value : The raw property.
	 */
	public void setSchedule(String value)
	{
		_schedule.clear();

		if (value == null || value.isBlank())
		{
			_schedule.add(new Window(EnumSet.allOf(DayOfWeek.class), 0, END_OF_DAY));
			return;
		}

		for (String rawEntry : value.split(";"))
		{
			final String entry = rawEntry.trim();
			if (entry.isEmpty())
				continue;

			final Window window = parseWindow(entry);
			if (window != null)
				_schedule.add(window);
		}
	}

	/**
	 * @param entry : The entry to read, "days-from:to". The days are cut off on the last dash, so a day range may carry one of its own.
	 * @return The window the given entry holds, null when it doesn't read as one - a warning is logged in that case.
	 */
	private static Window parseWindow(String entry)
	{
		final int dash = entry.lastIndexOf('-');
		if (dash <= 0)
		{
			LOGGER.warn("Couldn't read the champion schedule entry '{}' ; days-from:to was expected.", entry);
			return null;
		}

		final String[] parts = entry.substring(dash + 1).split(":");
		if (parts.length != 2)
		{
			LOGGER.warn("Couldn't read the champion schedule entry '{}' ; days-from:to was expected.", entry);
			return null;
		}

		final Set<DayOfWeek> days = parseDays(entry.substring(0, dash));
		if (days == null || days.isEmpty())
		{
			LOGGER.warn("Couldn't read the days of the champion schedule entry '{}' ; 1 is Monday and 7 is Sunday.", entry);
			return null;
		}

		final int from;
		final int to;

		try
		{
			from = Integer.parseInt(parts[0].trim());
			to = Integer.parseInt(parts[1].trim());
		}
		catch (NumberFormatException e)
		{
			LOGGER.warn("Couldn't read the hours of the champion schedule entry '{}' ; two hours were expected.", entry);
			return null;
		}

		// An empty window would either never open or, once wrapped over midnight, never close.
		if (from < 0 || from >= END_OF_DAY || to <= 0 || to > END_OF_DAY || from == to)
		{
			LOGGER.warn("Couldn't read the hours of the champion schedule entry '{}' ; they must differ and sit between 0 and 24.", entry);
			return null;
		}

		return new Window(days, from, to);
	}

	/**
	 * @param value : The days part of a schedule entry, being "*", a comma separated list, a range, or any mix of the two last ones.
	 * @return The days it holds, 1 being Monday and 7 Sunday, null when it doesn't read as days at all.
	 */
	private static Set<DayOfWeek> parseDays(String value)
	{
		final String days = value.trim();
		final Set<DayOfWeek> result = EnumSet.noneOf(DayOfWeek.class);

		if (days.equals("*") || days.equalsIgnoreCase("all"))
			return EnumSet.allOf(DayOfWeek.class);

		try
		{
			for (String rawToken : days.split(","))
			{
				final String token = rawToken.trim();
				if (token.isEmpty())
					continue;

				final int dash = token.indexOf('-');
				if (dash < 0)
				{
					result.add(DayOfWeek.of(Integer.parseInt(token)));
					continue;
				}

				final int first = Integer.parseInt(token.substring(0, dash).trim());
				final int last = Integer.parseInt(token.substring(dash + 1).trim());

				if (first < 1 || first > WEEK_DAYS || last < 1 || last > WEEK_DAYS)
					return null;

				// A range is walked forward, so it may wrap over the end of the week : "6-2" is the weekend plus Monday and Tuesday.
				for (int day = first; day != last; day = (day % WEEK_DAYS) + 1)
					result.add(DayOfWeek.of(day));

				result.add(DayOfWeek.of(last));
			}
		}
		catch (Exception e)
		{
			return null;
		}

		return result;
	}

	/**
	 * Read a "ChampionMobs&lt;flavor&gt;Drop" property, holding the extra drops a champion of that flavor carries on top of the table of its own template.<br>
	 * <br>
	 * One entry reads "itemId:min-max:chance", the amount being allowed to be a fixed one : "57:1000-2000:100;6673:1:5" gives 1000 to 2000 adena every time, and a single Gold Einhasad five times
	 * out of a hundred. The chance is a plain percent, decimals included.
	 * @param key : The name of the property, used by the warnings.
	 * @param value : The raw property.
	 * @return The drops it holds, an empty {@link List} when it holds none.
	 */
	public static List<DropData> parseDrops(String key, String value)
	{
		if (value == null || value.isBlank())
			return Collections.emptyList();

		final List<DropData> result = new ArrayList<>();

		for (String rawEntry : value.split(";"))
		{
			final String entry = rawEntry.trim();
			if (entry.isEmpty())
				continue;

			final String[] parts = entry.split(":");
			if (parts.length != 3)
			{
				LOGGER.warn("Couldn't read the drop '{}' of '{}' ; itemId:min-max:chance was expected.", entry, key);
				continue;
			}

			try
			{
				final int itemId = Integer.parseInt(parts[0].trim());

				final String amount = parts[1].trim();
				final int dash = amount.indexOf('-');

				final int min = Integer.parseInt(((dash < 0) ? amount : amount.substring(0, dash)).trim());
				final int max = (dash < 0) ? min : Integer.parseInt(amount.substring(dash + 1).trim());

				final double chance = Double.parseDouble(parts[2].trim());

				if (itemId <= 0 || min <= 0 || max < min || chance <= 0)
				{
					LOGGER.warn("Couldn't read the drop '{}' of '{}' ; the item, the amounts and the chance must all be positive.", entry, key);
					continue;
				}

				result.add(new DropData(itemId, min, max, Math.min(100., chance)));
			}
			catch (NumberFormatException e)
			{
				LOGGER.warn("Couldn't read the drop '{}' of '{}' ; one of its values isn't a number.", entry, key);
			}
		}

		return result;
	}
}
