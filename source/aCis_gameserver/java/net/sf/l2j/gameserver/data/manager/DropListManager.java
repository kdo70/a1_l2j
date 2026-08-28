package net.sf.l2j.gameserver.data.manager;

import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.StringTokenizer;

import net.sf.l2j.commons.lang.StringUtil;
import net.sf.l2j.commons.logging.CLogger;

import net.sf.l2j.Config;
import net.sf.l2j.gameserver.data.cache.HtmCache;
import net.sf.l2j.gameserver.data.xml.DropListData;
import net.sf.l2j.gameserver.data.xml.ItemData;
import net.sf.l2j.gameserver.data.xml.ItemIconData;
import net.sf.l2j.gameserver.enums.DropType;
import net.sf.l2j.gameserver.model.World;
import net.sf.l2j.gameserver.model.WorldObject;
import net.sf.l2j.gameserver.model.actor.Player;
import net.sf.l2j.gameserver.model.actor.instance.Monster;
import net.sf.l2j.gameserver.model.item.DropCategory;
import net.sf.l2j.gameserver.model.item.DropData;
import net.sf.l2j.gameserver.model.item.kind.Item;
import net.sf.l2j.gameserver.network.serverpackets.ActionFailed;
import net.sf.l2j.gameserver.network.serverpackets.NpcHtmlMessage;

/**
 * Generates the drop list window a {@link Player} opens by shift clicking a {@link Monster} - a raid boss being one.<br>
 * <br>
 * The window is a plain HTM dialog held by the monster itself : one single list, paged at the bottom, where every {@link DropCategory} of the monster shows up as a group - its own header row, holding
 * its caption and the chance the whole group rolls, followed by its items sorted by decreasing chance. The groups themselves are sorted by decreasing chance too, but the spoil ones are pushed after
 * the regular drops and the herb ones after the spoil : both are side rewards, and a player reads the list for what the monster actually drops.<br>
 * <br>
 * A regular group is simply numbered - a "drop" or an "adena" caption tells a player nothing he doesn't already read out of the items themselves - while the spoil and herb ones own a name.<br>
 * <br>
 * The shown chance is the chance of the whole draw : the category rolls first ({@link DropCategory#getChance()}), the item is then picked inside of it ({@link DropData#chance()}). The server rates
 * are folded in when "DropListApplyRates" is set - they multiply the amount of rolls of a category, so the result is capped at 100%.<br>
 * <br>
 * A row draws the icon on the left, then the item name on one line and the dropped amount right under it : an amount as long as an adena one doesn't fit next to a name on a single line.<br>
 * <br>
 * The behavior lives on config/mods/droplist.properties, the whole appearance on data/xml/droplist.xml, the item icons on data/xml/itemIcons.xml.
 */
public class DropListManager
{
	private static final CLogger LOGGER = new CLogger(DropListManager.class.getName());

	/** The bypass fired by the generated links, followed by "objectId page". */
	public static final String BYPASS = "_droplist ";

	private static final String HTM = "./data/html/mods/droplist/list.htm";

	private static final String ROW_END = "</tr></table>";

	/** {@link DecimalFormat} isn't thread safe and several {@link Player}s can browse a list at once, so the formatter is built per cell ; only its symbols are shared. */
	private static final DecimalFormatSymbols CHANCE_SYMBOLS = DecimalFormatSymbols.getInstance(Locale.ENGLISH);

	private static final String CHANCE_PATTERN = "#0.##";

	/** A single rendered drop : the whole draw chance of one {@link DropData}, and the amount it gives. */
	private record DropRow(int itemId, double chance, int min, int max)
	{
	}

	/** A single rendered {@link DropCategory} : the chance the group rolls, and its already sorted rows. */
	private record DropGroup(DropType type, double chance, List<DropRow> rows)
	{
	}

	/**
	 * Answer the shift click of a {@link Player} on a {@link Monster}.
	 * @param player : The {@link Player} which clicked.
	 * @param monster : The {@link Monster} which has been clicked.
	 * @return True if the drop list window has been shown, false to let the regular shift click behavior happen.
	 */
	public boolean onShiftClick(Player player, Monster monster)
	{
		if (!Config.DROPLIST_ENABLED)
			return false;

		// Without the skill, the shift click keeps its regular meaning - attacking without moving.
		if (Config.DROPLIST_SKILL_ID > 0 && player.getSkill(Config.DROPLIST_SKILL_ID) == null)
			return false;

		if (player.getTarget() != monster)
			player.setTarget(monster);

		show(player, monster, 0);

		return true;
	}

	/**
	 * Answer a link of an already shown drop list window.
	 * @param player : The {@link Player} which clicked.
	 * @param command : The bypass parameters, being "objectId page".
	 */
	public void handleBypass(Player player, String command)
	{
		if (!Config.DROPLIST_ENABLED)
			return;

		if (Config.DROPLIST_SKILL_ID > 0 && player.getSkill(Config.DROPLIST_SKILL_ID) == null)
			return;

		try
		{
			final StringTokenizer st = new StringTokenizer(command, " ");

			final WorldObject object = World.getInstance().getObject(Integer.parseInt(st.nextToken()));
			if (!(object instanceof Monster monster))
				return;

			show(player, monster, Integer.parseInt(st.nextToken()));
		}
		catch (Exception e)
		{
			LOGGER.warn("Couldn't handle the drop list bypass '{}'.", e, command);
		}
	}

	/**
	 * Generate and send the drop list window.
	 * @param player : The {@link Player} to send the dialog to.
	 * @param monster : The {@link Monster} used as dialog holder.
	 * @param page : The page index to show.
	 */
	private static void show(Player player, Monster monster, int page)
	{
		final DropListData data = DropListData.getInstance();

		final List<DropGroup> groups = getGroups(monster);

		int total = 0;
		for (DropGroup group : groups)
			total += group.rows().size();

		final int perPage = data.getRowsPerPage();
		final int pages = getPageCount(total, perPage);

		page = Math.min(Math.max(page, 0), pages - 1);

		// A page holds a fixed amount of item rows ; the group headers are drawn on top of them, and the filler takes their height into account.
		final int first = page * perPage;
		final int last = Math.min(total, first + perPage);

		final StringBuilder sb = new StringBuilder(2048);

		if (total == 0)
			StringUtil.append(sb, getRowStart(0), "<td width=", data.getWidth(), " height=", data.getRowHeight(), " align=center>", colorize(data.getDisabledColor(), escape(data.getEmptyLabel())), "</td>", ROW_END);

		int shownGroups = 0;
		int shownRows = 0;
		int offset = 0;
		int number = 0;

		for (DropGroup group : groups)
		{
			// The regular groups are numbered - they hold no meaningful name to show - and the counter runs over the whole list, not over the current page only.
			if (getRank(group.type()) == 0)
				number++;

			final int start = offset;
			offset += group.rows().size();

			// Only the groups owning a row of the current page are drawn ; a group spanning several pages gets its header again on each of them.
			if (offset <= first || start >= last)
				continue;

			sb.append(getGroupHeader(group, number));
			shownGroups++;

			for (int i = Math.max(first, start); i < Math.min(last, offset); i++)
				sb.append(getRow(group.rows().get(i - start), shownRows++));
		}

		String content = HtmCache.getInstance().getHtmForce(HTM);
		content = content.replace("%list%", sb.toString());
		content = content.replace("%filler%", getFiller(shownGroups, Math.max(1, shownRows)));
		content = content.replace("%footer%", getFooter(monster, page, pages));
		content = content.replace("%npcName%", monster.getName());
		content = content.replace("%npcLevel%", String.valueOf(monster.getStatus().getLevel()));
		content = content.replace("%objectId%", String.valueOf(monster.getObjectId()));
		content = content.replace("%width%", String.valueOf(data.getWidth()));

		final NpcHtmlMessage html = new NpcHtmlMessage(monster.getObjectId());
		html.setHtml(content);

		player.sendPacket(html);
		player.sendPacket(ActionFailed.STATIC_PACKET);
	}

	/**
	 * @param monster : The {@link Monster} to check.
	 * @return Every non empty {@link DropCategory} of the given {@link Monster}, turned into a {@link DropGroup} whose rows are sorted by decreasing chance. The groups themselves are sorted by
	 *         decreasing chance, the spoil ones landing after the regular drops and the herb ones last.
	 */
	private static List<DropGroup> getGroups(Monster monster)
	{
		final List<DropGroup> groups = new ArrayList<>();

		for (DropCategory category : monster.getTemplate().getDropData())
		{
			if (category.isEmpty())
				continue;

			final DropType type = category.getDropType();
			if (type == DropType.SPOIL && !Config.DROPLIST_SHOW_SPOIL)
				continue;

			final double rate = (Config.DROPLIST_APPLY_RATES) ? type.getDropRate(monster.isRaidBoss()) : 1;

			// A rate is an amount of rolls of the category, not a multiplier of its chance ; a category rolled more than once is simply shown as a certain one.
			final double chance = Math.min(100, category.getChance() * rate);

			final List<DropRow> rows = new ArrayList<>(category.size());

			for (DropData drop : category)
				rows.add(new DropRow(drop.itemId(), Math.min(100, chance * drop.chance() / 100), drop.minDrop(), drop.maxDrop()));

			rows.sort(Comparator.<DropRow> comparingDouble(DropRow::chance).reversed());

			groups.add(new DropGroup(type, chance, rows));
		}

		groups.sort(Comparator.comparingInt((DropGroup group) -> getRank(group.type())).thenComparing(Comparator.<DropGroup> comparingDouble(DropGroup::chance).reversed()));

		return groups;
	}

	/**
	 * @param type : The {@link DropType} to rank.
	 * @return The sort key pushing the spoil groups after the regular drops, and the herb ones after the spoil.
	 */
	private static int getRank(DropType type)
	{
		switch (type)
		{
			case SPOIL:
				return 1;

			case HERB:
				return 2;

			default:
				return 0;
		}
	}

	/**
	 * The header of a group, generated out of the very same width as its rows.
	 * @param group : The {@link DropGroup} to introduce.
	 * @param number : The rank of the group among the regular ones, 1 being the first. Ignored by the spoil and herb groups, which own a name of their own.
	 * @return The header row of the given group : its caption on the left, the chance the whole group rolls on the right.
	 */
	private static String getGroupHeader(DropGroup group, int number)
	{
		final DropListData data = DropListData.getInstance();
		final StringBuilder sb = new StringBuilder(256);

		StringUtil.append(sb, "<table width=", data.getWidth(), (data.getGroupColor().isEmpty()) ? "" : " bgcolor=\"" + data.getGroupColor() + "\"", "><tr>");
		StringUtil.append(sb, getCell(Math.max(1, data.getWidth() - data.getChanceWidth()), data.getGroupHeight(), "left", colorize(data.getGroupTextColor(), escape(data.getGroupLabel(group.type(), number)))));
		StringUtil.append(sb, getCell(data.getChanceWidth(), 0, "right", colorize(data.getChanceColor(group.chance()), getChanceText(group.chance()))));
		sb.append(ROW_END);

		return sb.toString();
	}

	/**
	 * @param row : The {@link DropRow} to render.
	 * @param index : The index of the row on the current page, 0 being the first one.
	 * @return The whole row, rendered as its own table.
	 */
	private static String getRow(DropRow row, int index)
	{
		final DropListData data = DropListData.getInstance();
		final Item item = ItemData.getInstance().getTemplate(row.itemId());

		final String name = (item == null) ? String.valueOf(row.itemId()) : truncate(item.getName(), data.getNameChars());

		final StringBuilder sb = new StringBuilder(384);

		StringUtil.append(sb, getRowStart(index));
		StringUtil.append(sb, getCell(data.getIconWidth(), data.getRowHeight(), "center", "<img src=\"" + ItemIconData.getInstance().getIcon(row.itemId()) + "\" width=" + data.getIconSize() + " height=" + data.getIconSize() + ">"));

		// The name owns a line and the amount the next one : an adena amount is way too long to sit next to a name on a single one.
		StringUtil.append(sb, getCell(data.getNameWidth(), 0, "left", colorize(data.getNameColor(), escape(name)) + "<br1>" + colorize(data.getCountColor(), getCountText(row))));
		StringUtil.append(sb, getCell(data.getChanceWidth(), 0, "right", colorize(data.getChanceColor(row.chance()), getChanceText(row.chance()))));
		StringUtil.append(sb, ROW_END);

		return sb.toString();
	}

	/**
	 * @param row : The {@link DropRow} to render.
	 * @return The amount cell content, a fixed amount being shown alone and a range as "min-max". The rate isn't folded in : it multiplies the amount of rolls, not the amount of a single one.
	 */
	private static String getCountText(DropRow row)
	{
		final String amount = (row.min() == row.max()) ? StringUtil.formatNumber(row.min()) : StringUtil.formatNumber(row.min()) + "-" + StringUtil.formatNumber(row.max());

		return DropListData.getInstance().getCountPrefix() + amount;
	}

	/**
	 * @param chance : The already computed chance, in percent.
	 * @return The chance cell content. A chance the format would round down to a bare "0" is shown as "&lt;0.01%" instead, since a shown 0% would read as "never".
	 */
	private static String getChanceText(double chance)
	{
		if (chance > 0 && chance < 0.01)
			return "&lt;0.01%";

		return new DecimalFormat(CHANCE_PATTERN, CHANCE_SYMBOLS).format(chance) + "%";
	}

	/**
	 * Each row of the list is rendered as its own table, since the client only handles the bgcolor attribute on tables.
	 * @param index : The index of the row on the current page, 0 being the first one.
	 * @return The opening tags of a list row, alternating both row colors.
	 */
	private static String getRowStart(int index)
	{
		final DropListData data = DropListData.getInstance();
		final String color = (index % 2 == 0) ? data.getAltRowColor() : data.getRowColor();

		return "<table width=" + data.getWidth() + ((color.isEmpty()) ? "" : " bgcolor=\"" + color + "\"") + "><tr>";
	}

	/**
	 * The bottom row of the page, holding the page selector. It is always emitted, even empty : an occasionally missing row would shorten a page by one row height, and pages without a scrollbar
	 * would show up again.
	 * @param monster : The {@link Monster} used as dialog holder.
	 * @param page : The currently shown page index.
	 * @param pages : The total amount of pages.
	 * @return The footer row, replacing the %footer% variable.
	 */
	private static String getFooter(Monster monster, int page, int pages)
	{
		final DropListData data = DropListData.getInstance();
		final int maxPages = data.getMaxPages();

		int first = 0;
		int last = 0;
		boolean hasPrev = false;
		boolean hasNext = false;

		if (pages > 1)
		{
			// Center the shown window of pages on the current page.
			first = Math.max(0, page - maxPages / 2);
			last = Math.min(pages, first + maxPages);
			first = Math.max(0, last - maxPages);

			hasPrev = page > 0;
			hasNext = page < pages - 1;
		}

		// Every cell owns the same width, so the selector doesn't jump around while browsing the pages.
		final int cellWidth = Math.max(1, data.getWidth() / (maxPages + 2));
		final int cells = (last - first) + ((hasPrev) ? 1 : 0) + ((hasNext) ? 1 : 0);

		// The left cell takes whatever the selector leaves, which pins the selector to the right edge.
		final int leftWidth = Math.max(1, data.getWidth() - cells * cellWidth);

		final StringBuilder sb = new StringBuilder(512);

		StringUtil.append(sb, "<table width=", data.getWidth(), "><tr><td width=", leftWidth, " height=", data.getGroupHeight(), " align=left></td>");

		if (hasPrev)
			sb.append(getPageCell(cellWidth, "<a action=\"bypass -h " + getBypass(monster, page - 1) + "\">" + colorize(data.getPageColor(), escape(data.getPrevPageLabel())) + "</a>"));

		for (int i = first; i < last; i++)
		{
			final String label = String.valueOf(i + 1);

			sb.append(getPageCell(cellWidth, (i == page) ? colorize(data.getActivePageColor(), label) : "<a action=\"bypass -h " + getBypass(monster, i) + "\">" + colorize(data.getPageColor(), label) + "</a>"));
		}

		if (hasNext)
			sb.append(getPageCell(cellWidth, "<a action=\"bypass -h " + getBypass(monster, page + 1) + "\">" + colorize(data.getPageColor(), escape(data.getNextPageLabel())) + "</a>"));

		sb.append(ROW_END);

		return sb.toString();
	}

	/**
	 * The dialog owns a fixed height, so padding every page up to one single total keeps the page selector at the very same spot - and, the total being slightly above the dialog, keeps the
	 * scrollbar shown everywhere.
	 * @param groups : The amount of group headers actually rendered on the current page, each owning its own height.
	 * @param rows : The amount of item rows actually rendered on the current page.
	 * @return The spacer filling the bottom of the page, replacing the %filler% variable.
	 */
	private static String getFiller(int groups, int rows)
	{
		final DropListData data = DropListData.getInstance();
		if (data.getPageHeight() <= 0)
			return "";

		final int missing = data.getPageHeight() - data.getOverhead() - groups * data.getGroupHeight() - rows * data.getRowHeight();

		return (missing <= 0) ? "" : "<img height=" + missing + ">";
	}

	private static String getPageCell(int width, String content)
	{
		return "<td width=" + width + " height=" + DropListData.getInstance().getGroupHeight() + " align=center>" + content + "</td>";
	}

	private static String getCell(int width, int height, String align, String content)
	{
		final StringBuilder sb = new StringBuilder(64);

		sb.append("<td width=").append(width);

		if (height > 0)
			sb.append(" height=").append(height);

		sb.append(" align=").append(align).append('>').append(content).append("</td>");

		return sb.toString();
	}

	private static String getBypass(Monster monster, int page)
	{
		return BYPASS + monster.getObjectId() + " " + page;
	}

	/**
	 * @param color : The color to apply, an empty {@link String} keeping the client default.
	 * @param text : The text to wrap.
	 * @return The given text, wrapped into a font tag when a color is set.
	 */
	private static String colorize(String color, String text)
	{
		return (color.isEmpty() || text.isEmpty()) ? text : "<font color=\"" + color + "\">" + text + "</font>";
	}

	/**
	 * @param text : The datapack text to render.
	 * @return The given text, with its angle brackets turned into entities the client renders as is.
	 */
	private static String escape(String text)
	{
		return (text.indexOf('<') < 0 && text.indexOf('>') < 0) ? text : text.replace("<", "&lt;").replace(">", "&gt;");
	}

	/**
	 * Shorten an item name which wouldn't fit its column, since a wrapped text makes the whole row taller than the others.
	 * @param text : The text to shorten.
	 * @param maxChars : The maximum amount of characters, 0 disabling the shortening.
	 * @return The given text, shortened and suffixed by the ellipsis when needed.
	 */
	private static String truncate(String text, int maxChars)
	{
		if (maxChars <= 0 || text.length() <= maxChars)
			return text;

		final String ellipsis = DropListData.getInstance().getEllipsis();
		final int cut = Math.max(1, maxChars - ellipsis.length());

		String result = text.substring(0, cut);

		final int space = result.lastIndexOf(' ');
		if (space * 3 > cut * 2)
			result = result.substring(0, space);

		return result.stripTrailing() + ellipsis;
	}

	private static int getPageCount(int size, int perPage)
	{
		return Math.max(1, (size + perPage - 1) / perPage);
	}

	public static DropListManager getInstance()
	{
		return SingletonHolder.INSTANCE;
	}

	private static class SingletonHolder
	{
		protected static final DropListManager INSTANCE = new DropListManager();
	}
}
