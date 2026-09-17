package net.sf.l2j.gameserver.handler.admincommandhandlers;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.StringTokenizer;

import net.sf.l2j.gameserver.data.SkillTable;
import net.sf.l2j.gameserver.handler.IAdminCommandHandler;
import net.sf.l2j.gameserver.model.actor.Player;
import net.sf.l2j.gameserver.model.holder.IntIntHolder;
import net.sf.l2j.gameserver.model.item.instance.ItemInstance;
import net.sf.l2j.gameserver.model.itemcontainer.listeners.ItemPassiveSkillsListener;
import net.sf.l2j.gameserver.network.serverpackets.NpcHtmlMessage;
import net.sf.l2j.gameserver.skills.L2Skill;

/**
 * The skills a single item carries on its own - the "skills" column of the items table, see docs/item-skills.md.
 * <ul>
 * <li>//itemskills [page] : the equipment of your target (or yours), worn first ;</li>
 * <li>//itemskills &lt;objectId&gt; : that item, its skills, a delete button per skill and a form to add one ;</li>
 * <li>//itemskills &lt;objectId&gt; add &lt;skillId&gt; &lt;level&gt; : add a skill, or move it to that level if the item already carries it ;</li>
 * <li>//itemskills &lt;objectId&gt; del &lt;skillId&gt; : take one skill off.</li>
 * </ul>
 * A worn item hands the change to its owner at once, and the owner's appearance is sent again, as the enchant glow depends on these skills.
 */
public class AdminItemSkills implements IAdminCommandHandler
{
	private static final String[] ADMIN_COMMANDS =
	{
		"admin_itemskills"
	};

	private static final int ITEMS_PER_PAGE = 10;

	@Override
	public void useAdminCommand(String command, Player player)
	{
		final StringTokenizer st = new StringTokenizer(command, " ");
		st.nextToken(); // skip command

		final Player owner = getTargetPlayer(player, true);

		if (!st.hasMoreTokens())
		{
			showList(player, owner, 1);
			return;
		}

		final String first = st.nextToken();
		if (first.equals("page"))
		{
			showList(player, owner, parseInt(st.hasMoreTokens() ? st.nextToken() : "1", 1));
			return;
		}

		final ItemInstance item = owner.getInventory().getItemByObjectId(parseInt(first, 0));
		if (item == null)
		{
			player.sendMessage(owner.getName() + " doesn't own that item any more.");
			showList(player, owner, 1);
			return;
		}

		if (st.hasMoreTokens())
		{
			final String action = st.nextToken();
			if (action.equals("add"))
			{
				// The client sends nothing at all for an empty edit box, so both numbers may be missing.
				final int skillId = parseInt(st.hasMoreTokens() ? st.nextToken() : "", 0);
				final int level = parseInt(st.hasMoreTokens() ? st.nextToken() : "", 0);
				addSkill(player, owner, item, skillId, level);
			}
			else if (action.equals("del"))
				removeSkill(player, owner, item, parseInt(st.hasMoreTokens() ? st.nextToken() : "", 0));
		}

		showItem(player, owner, item);
	}

	@Override
	public String[] getAdminCommandList()
	{
		return ADMIN_COMMANDS;
	}

	private static void addSkill(Player player, Player owner, ItemInstance item, int skillId, int level)
	{
		if (skillId <= 0 || level <= 0)
		{
			player.sendMessage("Type a skill id and a level, both above 0.");
			return;
		}

		final L2Skill skill = SkillTable.getInstance().getInfo(skillId, level);
		if (skill == null)
		{
			player.sendMessage("There is no skill " + skillId + " at level " + level + ".");
			return;
		}

		final List<IntIntHolder> skills = getSkills(item);

		// One level per skill : adding a skill the item already carries moves it.
		boolean moved = false;
		for (int i = 0; i < skills.size(); i++)
		{
			if (skills.get(i).getId() == skillId)
			{
				skills.set(i, new IntIntHolder(skillId, level));
				moved = true;
				break;
			}
		}

		if (!moved)
			skills.add(new IntIntHolder(skillId, level));

		apply(owner, item, skills);
		player.sendMessage(skill.getName() + " (" + skillId + ") level " + level + (moved ? " is now the level carried by " : " added to ") + item.getItemName() + ".");
	}

	private static void removeSkill(Player player, Player owner, ItemInstance item, int skillId)
	{
		final List<IntIntHolder> skills = getSkills(item);
		if (!skills.removeIf(s -> s.getId() == skillId))
		{
			player.sendMessage(item.getItemName() + " doesn't carry skill " + skillId + ".");
			return;
		}

		apply(owner, item, skills);
		player.sendMessage("Skill " + skillId + " removed from " + item.getItemName() + ".");
	}

	private static List<IntIntHolder> getSkills(ItemInstance item)
	{
		final List<IntIntHolder> skills = new ArrayList<>();
		final IntIntHolder[] current = item.getCustomSkills();
		if (current != null)
		{
			for (IntIntHolder skill : current)
				skills.add(new IntIntHolder(skill.getId(), skill.getValue()));
		}
		return skills;
	}

	/**
	 * Write the skills back on the item - which saves it and refreshes the owner's inventory and tooltip - then hand them to the owner if he wears it, and send his appearance again for the enchant glow.
	 * @param owner : The {@link Player} owning the item.
	 * @param item : The {@link ItemInstance} to edit.
	 * @param skills : The skills the item carries from now on.
	 */
	private static void apply(Player owner, ItemInstance item, List<IntIntHolder> skills)
	{
		final StringBuilder sb = new StringBuilder();
		for (IntIntHolder skill : skills)
		{
			if (sb.length() > 0)
				sb.append(';');

			sb.append(skill.getId()).append(':').append(skill.getValue());
		}

		final IntIntHolder[] oldSkills = item.getCustomSkills();
		item.setCustomSkills(sb.toString(), owner);

		if (item.isEquipped())
		{
			ItemPassiveSkillsListener.getInstance().onCustomSkillsChanged(owner, item, oldSkills);
			owner.broadcastUserInfo();
		}
	}

	private void showList(Player player, Player owner, int page)
	{
		// What can carry skills is what can be worn : worn items first, in slot order, then the rest by name.
		final List<ItemInstance> items = new ArrayList<>();
		for (ItemInstance item : owner.getInventory().getItems())
		{
			if (item.isEquipable())
				items.add(item);
		}
		items.sort(Comparator.comparing((ItemInstance i) -> !i.isEquipped()).thenComparingInt(i -> i.isEquipped() ? i.getLocationSlot() : 0).thenComparing(ItemInstance::getItemName));

		final int pages = Math.max(1, (items.size() + ITEMS_PER_PAGE - 1) / ITEMS_PER_PAGE);
		page = Math.max(1, Math.min(page, pages));

		final StringBuilder sb = new StringBuilder();
		if (items.isEmpty())
			sb.append("<tr><td>Nothing that can be worn.</td></tr>");

		for (int i = (page - 1) * ITEMS_PER_PAGE; i < Math.min(items.size(), page * ITEMS_PER_PAGE); i++)
		{
			final ItemInstance item = items.get(i);
			final IntIntHolder[] skills = item.getCustomSkills();

			sb.append("<tr><td width=190><a action=\"bypass -h admin_itemskills ").append(item.getObjectId()).append("\">");
			if (item.getEnchantLevel() > 0)
				sb.append('+').append(item.getEnchantLevel()).append(' ');
			sb.append(item.getItemName()).append("</a>");
			if (item.isEquipped())
				sb.append(" <font color=\"B09878\">worn</font>");
			sb.append("</td><td width=70 align=right>");
			if (skills != null)
				sb.append("<font color=\"LEVEL\">").append(skills.length).append(skills.length == 1 ? " skill" : " skills").append("</font>");
			sb.append("</td></tr>");
		}

		final StringBuilder nav = new StringBuilder();
		for (int p = 1; p <= pages && pages > 1; p++)
		{
			if (p == page)
				nav.append(p).append(' ');
			else
				nav.append("<a action=\"bypass -h admin_itemskills page ").append(p).append("\">").append(p).append("</a> ");
		}

		final NpcHtmlMessage html = new NpcHtmlMessage(0);
		html.setFile("data/html/admin/itemskills.htm");
		html.replace("%owner%", owner.getName());
		html.replace("%items%", sb.toString());
		html.replace("%pages%", nav.toString());
		player.sendPacket(html);
	}

	private static void showItem(Player player, Player owner, ItemInstance item)
	{
		final IntIntHolder[] skills = item.getCustomSkills();

		final StringBuilder sb = new StringBuilder();
		if (skills == null)
			sb.append("<tr><td>This item carries no skill.</td></tr>");
		else
		{
			for (IntIntHolder skill : skills)
			{
				final L2Skill info = skill.getSkill();
				sb.append("<tr><td width=180>").append((info == null) ? "?" : info.getName()).append(" <font color=\"B09878\">").append(skill.getId()).append("</font></td>");
				sb.append("<td width=40>Lv ").append(skill.getValue()).append("</td>");
				sb.append("<td width=40><button value=\"Del\" action=\"bypass -h admin_itemskills ").append(item.getObjectId()).append(" del ").append(skill.getId()).append("\" width=40 height=15 back=\"sek.cbui94\" fore=\"sek.cbui92\"></td></tr>");
			}
		}

		final NpcHtmlMessage html = new NpcHtmlMessage(0);
		html.setFile("data/html/admin/itemskills_item.htm");
		html.replace("%owner%", owner.getName());
		html.replace("%name%", ((item.getEnchantLevel() > 0) ? "+" + item.getEnchantLevel() + " " : "") + item.getItemName());
		html.replace("%state%", item.isEquipped() ? "worn - changes apply at once" : "not worn - skills are given when it is put on");
		html.replace("%skills%", sb.toString());
		html.replace("%objectId%", item.getObjectId());
		player.sendPacket(html);
	}

	private static int parseInt(String value, int fallback)
	{
		try
		{
			return Integer.parseInt(value.trim());
		}
		catch (NumberFormatException e)
		{
			return fallback;
		}
	}
}
