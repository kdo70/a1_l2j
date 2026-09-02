package net.sf.l2j.gameserver.model.records;

import net.sf.l2j.gameserver.model.actor.template.NpcTemplate;

/**
 * The whole two line plate one kind of monster wears above its head, as config/npcs/nameplates.properties writes it : the words the title is made of, the colors both lines are painted with, and the
 * two texts every kind shares - the word the level is announced with and the mark an aggressive monster carries.<br>
 * <br>
 * The name and the title carry a color each, and they travel to the client as two separate dwords of the NpcInfo packet, so a kind is free to paint one and leave the other alone. A config saying
 * nothing about the title's color gives it the name's, which is what a single color meant back when there was only one.<br>
 * <br>
 * A title reads "&lt;text&gt; &lt;levelLabel&gt; &lt;level&gt;&lt;aggressiveMark&gt;", the text being dropped by the kind that carries none : "Raid Boss Lvl 80*", "Lvl 12". The server builds it itself,
 * for every monster whose own title in data/xml/npcs is empty - a monster carrying a title of its own keeps it.
 * @param text : The words naming the kind, empty for the kind carrying none.
 * @param nameColor : The color of the name, the lower line, as RRGGBB, or {@link NpcTemplate#NO_NAME_COLOR} to leave it to the client.
 * @param titleColor : The color of the title, the upper line, same deal.
 * @param levelLabel : The word the level is announced with, "Lvl".
 * @param aggressiveMark : The mark an aggressive monster carries at the very end, "*".
 */
public record MonsterNameplate(String text, int nameColor, int titleColor, String levelLabel, String aggressiveMark)
{
	/**
	 * @param level : The level of the monster.
	 * @param aggressive : True when the monster walks up to players on its own, which is what the mark announces.
	 * @return The title a monster of this kind wears.
	 */
	public String format(int level, boolean aggressive)
	{
		return getHead() + level + (aggressive ? aggressiveMark : "");
	}

	/**
	 * @return Everything a title of this kind holds in front of the level itself.
	 */
	private String getHead()
	{
		return (text.isEmpty() ? "" : text + " ") + levelLabel + " ";
	}
}
