package net.sf.l2j.gameserver.enums;

/**
 * The two flavors a champion monster can take. Each one owns its very own settings block on config/mods/championmobs.properties, the aura it glows with, and the color its name and title are painted
 * with - so a player tells a red champion from a blue one before reading a single word.
 */
public enum ChampionType
{
	RED("Red", TeamType.RED, 0xFF4040),
	BLUE("Blue", TeamType.BLUE, 0x4080FF);

	private final String _prefix;
	private final TeamType _team;
	private final int _defaultNameColor;

	private ChampionType(String prefix, TeamType team, int defaultNameColor)
	{
		_prefix = prefix;
		_team = team;
		_defaultNameColor = defaultNameColor;
	}

	/**
	 * @return The name this flavor is written with on config/mods/championmobs.properties, sitting between "ChampionMobs" and the setting itself.
	 */
	public String getPrefix()
	{
		return _prefix;
	}

	/**
	 * @return The team aura this flavor glows with, which is what draws the colored ring under the monster.
	 */
	public TeamType getTeam()
	{
		return _team;
	}

	/**
	 * @return The color the name and the title of this flavor are painted with when the config holds none, as RRGGBB.
	 */
	public int getDefaultNameColor()
	{
		return _defaultNameColor;
	}

	/**
	 * @param value : The name to read, case insensitive.
	 * @return The matching {@link ChampionType}, null when the given name isn't one.
	 */
	public static ChampionType parse(String value)
	{
		if (value == null)
			return null;

		for (ChampionType type : values())
		{
			if (type.name().equalsIgnoreCase(value.trim()))
				return type;
		}

		return null;
	}
}
