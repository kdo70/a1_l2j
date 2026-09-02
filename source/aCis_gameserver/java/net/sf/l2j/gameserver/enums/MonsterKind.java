package net.sf.l2j.gameserver.enums;

import net.sf.l2j.gameserver.model.actor.template.NpcTemplate;

/**
 * The kinds a monster is sorted into by tools/datapack/npc_level_titles.ps1, which writes the kind and the level of every monster into its title - "Raid Boss Lvl 80*".<br>
 * <br>
 * What each kind is called and which colors its two lines are painted with lives on config/npcs/nameplates.properties, under the keys "Monster&lt;kind&gt;Text", "Monster&lt;kind&gt;NameColor" and
 * "Monster&lt;kind&gt;TitleColor" - the name below sitting right after "Monster". The script writes the titles out of that very file, and the server reads the colors back out of it, so nothing but
 * that one file says what a raid boss looks like.<br>
 * <br>
 * The defaults carried here are the ones the feature was written with : the two oranges and the red are the colors the stock client paints the "Raid Boss" and "Quest Monster" titles with, so the
 * monsters the server names and the ones it doesn't look alike. See docs/npc-level-titles.md.
 */
public enum MonsterKind
{
	EPIC("Epic", "Epic Boss", 0xFF0000),
	EPIC_MINION("EpicMinion", "Epic Fighter", 0xFF0000),
	RAID("Raid", "Raid Boss", 0xFE8B3F),
	RAID_MINION("RaidMinion", "Raid Fighter", 0xFE8B3F),
	QUEST("Quest", "Quest Monster", 0xFF8000),
	PLAIN("Plain", "", NpcTemplate.NO_NAME_COLOR);

	private final String _prefix;
	private final String _defaultText;
	private final int _defaultNameColor;

	private MonsterKind(String prefix, String defaultText, int defaultNameColor)
	{
		_prefix = prefix;
		_defaultText = defaultText;
		_defaultNameColor = defaultNameColor;
	}

	/**
	 * @return The name this kind is written with on config/npcs/nameplates.properties, sitting between "Monster" and the setting itself.
	 */
	public String getPrefix()
	{
		return _prefix;
	}

	/**
	 * @return The words this kind carries in front of the level when the config holds none, an empty {@link String} for the kind that carries none at all.
	 */
	public String getDefaultText()
	{
		return _defaultText;
	}

	/**
	 * @return The color the name and the title of this kind are painted with when the config holds none, as RRGGBB, or {@link NpcTemplate#NO_NAME_COLOR} when this kind keeps the client's own color.
	 */
	public int getDefaultNameColor()
	{
		return _defaultNameColor;
	}
}
