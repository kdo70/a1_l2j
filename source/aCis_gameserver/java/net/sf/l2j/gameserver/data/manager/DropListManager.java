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
import net.sf.l2j.gameserver.model.ChampionSettings;
import net.sf.l2j.gameserver.model.World;
import net.sf.l2j.gameserver.model.WorldObject;
import net.sf.l2j.gameserver.model.actor.Player;
import net.sf.l2j.gameserver.model.actor.instance.Monster;
import net.sf.l2j.gameserver.model.actor.status.AttackableStatus;
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
 * A group header is framed by the separator of the datapack, and it is striped along with the item rows - a header being a band like any other, the first one of a page takes the plain color and
 * whatever sits under it the other one. Its caption only tells the one thing a player can't read out of the items themselves - whether the group is a drop or a spoil one - followed by the rank of
 * the group among the ones sharing that caption, so a monster reads "Drop #1, Drop #2, Spoil #1".<br>
 * <br>
 * The shown chance is the chance of the whole draw : the category rolls first ({@link DropCategory#getChance()}), the item is then picked inside of it ({@link DropData#chance()}). The server rates
 * are folded in when "DropListApplyRates" is set - they multiply the amount of rolls of a category, so the result is capped at 100% - and the deep blue penalty of the {@link Player} himself when
 * "DropListApplyLevelPenalty" is, which is what makes the window tell what that very player gets rather than what the table holds. The champion bonus of the monster rides along the rates, since it
 * is one : a champion simply rolls its categories more often. The extra drops a champion carries on top of that table make a group of their own, sitting on top of the list : they are rolled one by
 * one, so the group itself always rolls and only the deep blue penalty ever lowers a row.<br>
 * <br>
 * The first page carries a header laid out the way the status window of a {@link Player} is - two blocks of two columns - telling what the kill itself is worth and what the monster fights with : the
 * HP that has to be dealt and the MP of the monster, the XP and the SP that very {@link Player} earns, then its physical and magical attack, defence and speed. Every number carries the champion
 * bonuses. The header eats whatever amount of item rows its own height takes, so a page keeps the very same height whether it holds the header or not.<br>
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

	/** Height, in pixels, of the rule framing a group header. The separator textures are hairlines, and the filler math relies on that height being fixed. */
	private static final int SEPARATOR_HEIGHT = 1;

	/**
	 * Amount of lines the header of the first page holds : two for the reward block - HP and MP on the left column, XP and SP on the right one - and three for the combat one. Both blocks are two
	 * columns wide, the way the status window of a {@link Player} is, so a line carries two stats instead of one. The height the header takes, and the amount of item rows it costs, are computed out
	 * of it.
	 */
	private static final int HEADER_ROWS = 5;

	/** Amount of rules the header of the first page draws : one cutting its two blocks apart, one closing it. */
	private static final int HEADER_SEPARATORS = 2;

	/** {@link DecimalFormat} isn't thread safe and several {@link Player}s can browse a list at once, so the formatter is built per cell ; only its symbols are shared. */
	private static final DecimalFormatSymbols CHANCE_SYMBOLS = DecimalFormatSymbols.getInstance(Locale.ENGLISH);

	/** A single rendered drop : the whole draw chance of one {@link DropData}, and the amount it gives. */
	private record DropRow(int itemId, double chance, int min, int max)
	{
	}

	/** A single rendered {@link DropCategory} : the chance the group rolls, and its already sorted rows. The champion group is the one holding the extra drops of a champion monster. */
	private record DropGroup(DropType type, boolean champion, double chance, List<DropRow> rows)
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

		final List<DropGroup> groups = getGroups(player, monster);

		int total = 0;
		for (DropGroup group : groups)
			total += group.rows().size();

		final int perPage = data.getRowsPerPage();

		// The header of the first page pays for itself in item rows, so every page keeps the height the filler pads it up to and the page selector never moves.
		final int firstPageRows = (Config.DROPLIST_SHOW_HEADER) ? Math.max(1, perPage - getHeaderRowCost()) : perPage;
		final int pages = getPageCount(total, firstPageRows, perPage);

		page = Math.min(Math.max(page, 0), pages - 1);

		final boolean hasHeader = Config.DROPLIST_SHOW_HEADER && page == 0;

		// A page holds a fixed amount of item rows ; the group headers are drawn on top of them, and the filler takes their height into account.
		final int first = (page == 0) ? 0 : firstPageRows + (page - 1) * perPage;
		final int last = Math.min(total, first + ((page == 0) ? firstPageRows : perPage));

		final StringBuilder sb = new StringBuilder(2048);

		if (total == 0)
			StringUtil.append(sb, getRowStart(getBandColor(0)), "<td width=", data.getWidth(), " height=", data.getRowHeight(), " align=center>", colorize(data.getDisabledColor(), escape(data.getEmptyLabel())), "</td>", ROW_END);

		int shownGroups = 0;
		int shownRows = 0;
		int offset = 0;

		// The stripes run over the whole page, a group header being a band like any other : the first header of a page takes the plain color, whatever sits under it the other one. The page header is
		// a band too, so the list starts on the opposite color rather than stacking two plain blocks.
		int band = (hasHeader) ? 1 : 0;

		// The groups are numbered inside their own caption, so a monster reads "Drop #1, Drop #2, Spoil #1". Both counters run over the whole list, which keeps a number on one group whatever the
		// page it is browsed from.
		int drops = 0;
		int spoils = 0;

		for (DropGroup group : groups)
		{
			final String caption = (group.champion()) ? data.getChampionLabel() : data.getGroupLabel(group.type(), (group.type() == DropType.SPOIL) ? ++spoils : ++drops);

			final int start = offset;
			offset += group.rows().size();

			// Only the groups owning a row of the current page are drawn ; a group spanning several pages gets its header again on each of them.
			if (offset <= first || start >= last)
				continue;

			sb.append(getGroupHeader(group, caption, getBandColor(band++)));
			shownGroups++;

			for (int i = Math.max(first, start); i < Math.min(last, offset); i++)
			{
				sb.append(getRow(group.rows().get(i - start), getBandColor(band++)));
				shownRows++;
			}
		}

		String content = HtmCache.getInstance().getHtmForce(HTM);
		content = content.replace("%header%", (hasHeader) ? getHeader(player, monster) : "");
		content = content.replace("%list%", sb.toString());
		content = content.replace("%filler%", getFiller(shownGroups, Math.max(1, shownRows), (hasHeader) ? getHeaderHeight() : 0));
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
	 * @param player : The {@link Player} the chances are computed for - the level gap penalty is his own.
	 * @param monster : The {@link Monster} to check.
	 * @return Every non empty {@link DropCategory} of the given {@link Monster}, turned into a {@link DropGroup} whose rows are sorted by decreasing chance. The groups themselves are sorted by
	 *         decreasing chance, the spoil ones landing after the regular drops and the herb ones last.
	 */
	private static List<DropGroup> getGroups(Player player, Monster monster)
	{
		// The deep blue penalty of the engine reads the highest attacker level ; the window is a preview, so it reads the level of the very Player it is shown to.
		final double levelMultiplier = (Config.DROPLIST_APPLY_LEVEL_PENALTY) ? monster.getLevelMultiplier(player.getStatus().getLevel()) : 1;

		final List<DropGroup> groups = new ArrayList<>();

		for (DropCategory category : monster.getTemplate().getDropData())
		{
			if (category.isEmpty())
				continue;

			final DropType type = category.getDropType();
			if (type == DropType.SPOIL && !Config.DROPLIST_SHOW_SPOIL)
				continue;

			// The champion bonus is a rate of its own - it multiplies the amount of rolls just the same - so it is folded in along the server ones, and dropped along them too.
			final double rate = (Config.DROPLIST_APPLY_RATES) ? type.getDropRate(monster.isRaidBoss()) * monster.getChampionRateMultiplier(type) : 1;

			// A rate is an amount of rolls of the category, not a multiplier of its chance ; a category rolled more than once is simply shown as a certain one.
			final double chance = Math.min(100, category.getChance() * levelMultiplier * rate);

			final List<DropRow> rows = new ArrayList<>(category.size());

			for (DropData drop : category)
				rows.add(new DropRow(drop.itemId(), Math.min(100, chance * drop.chance() / 100), drop.minDrop(), drop.maxDrop()));

			rows.sort(Comparator.<DropRow> comparingDouble(DropRow::chance).reversed());

			groups.add(new DropGroup(type, false, chance, rows));
		}

		// The extra drops of a champion make a group of their own, sitting on top of the list : they are the very reason a player hunts that monster. Each one is rolled on its own, so the group
		// itself always rolls, and only the deep blue penalty ever lowers a row - the rates multiply the amount of rolls of a category, and these aren't ones.
		final ChampionSettings champion = monster.getChampionSettings();
		if (champion != null && !champion.getDrops().isEmpty())
		{
			final List<DropRow> rows = new ArrayList<>(champion.getDrops().size());

			for (DropData drop : champion.getDrops())
				rows.add(new DropRow(drop.itemId(), Math.min(100, drop.chance() * levelMultiplier), drop.minDrop(), drop.maxDrop()));

			rows.sort(Comparator.<DropRow> comparingDouble(DropRow::chance).reversed());

			groups.add(new DropGroup(DropType.DROP, true, 100, rows));
		}

		groups.sort(Comparator.comparingInt(DropListManager::getRank).thenComparing(Comparator.<DropGroup> comparingDouble(DropGroup::chance).reversed()));

		return groups;
	}

	/**
	 * @param group : The {@link DropGroup} to rank.
	 * @return The sort key pulling the champion group on top of the list, pushing the spoil groups after the regular drops, and the herb ones after the spoil.
	 */
	private static int getRank(DropGroup group)
	{
		if (group.champion())
			return -1;

		switch (group.type())
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
	 * The header of a group, generated out of the very same width as its rows and framed by the separator of the datapack - a background color would fight the alternating rows sitting right under
	 * it, a pair of rules simply cuts the list into groups.
	 * @param group : The {@link DropGroup} to introduce.
	 * @param caption : The caption of the group, already carrying its rank when it owns one.
	 * @param color : The background color of the header, empty keeping it see-through.
	 * @return The header row of the given group : its caption on the left, the chance the whole group rolls on the right.
	 */
	private static String getGroupHeader(DropGroup group, String caption, String color)
	{
		final DropListData data = DropListData.getInstance();
		final StringBuilder sb = new StringBuilder(320);

		sb.append(getSeparator());
		StringUtil.append(sb, "<table width=", data.getWidth(), (color.isEmpty()) ? "" : " bgcolor=\"" + color + "\"", "><tr>");
		StringUtil.append(sb, getCell(Math.max(1, data.getWidth() - data.getChanceWidth()), data.getGroupHeight(), "left", colorize(data.getGroupTextColor(), escape(caption))));
		StringUtil.append(sb, getCell(data.getChanceWidth(), 0, "right", colorize(data.getChanceColor(group.chance()), getChanceText(group.chance()))));
		sb.append(ROW_END);
		sb.append(getSeparator());

		return sb.toString();
	}

	/**
	 * The header of the first page, telling what the list of the drops can't : what the kill is worth, and what the monster fights with. It is laid out the way the status window of a {@link Player}
	 * is - two blocks of two columns, a caption on the left of a column and its value on the right - so a player reads a monster the same way he reads himself.<br>
	 * <br>
	 * The first block holds the pools on the left column and the rewards on the right one : the HP that has to be dealt and the MP of the monster, then the XP and the SP that very {@link Player} is
	 * given. The second one holds the physical stats on the left column and the magical ones on the right : attack, defence and speed. Every number carries the champion bonuses of the monster - the
	 * damage reduction standing in for an HP pool, the stat multipliers being folded in by {@link AttackableStatus} itself.
	 * @param player : The {@link Player} the rewards are computed for - the level gap penalty is his own.
	 * @param monster : The {@link Monster} to describe.
	 * @return The header block, closed by the same rule which frames the group headers.
	 */
	private static String getHeader(Player player, Monster monster)
	{
		final DropListData data = DropListData.getInstance();
		final AttackableStatus status = monster.getStatus();
		final long[] expSp = monster.getExpSpFor(player.getStatus().getLevel());

		final StringBuilder sb = new StringBuilder(1024);

		sb.append(getHeaderBlockStart());
		sb.append(getHeaderRow(data.getHpLabel(), monster.getEffectiveMaxHp(), data.getExpLabel(), expSp[0]));
		sb.append(getHeaderRow(data.getMpLabel(), status.getMaxMp(), data.getSpLabel(), expSp[1]));
		sb.append("</table>");
		sb.append(getSeparator());

		sb.append(getHeaderBlockStart());
		sb.append(getHeaderRow(data.getPAtkLabel(), status.getPAtk(null), data.getMAtkLabel(), status.getMAtk(null, null)));
		sb.append(getHeaderRow(data.getPDefLabel(), status.getPDef(null), data.getMDefLabel(), status.getMDef(null, null)));
		sb.append(getHeaderRow(data.getAtkSpdLabel(), status.getPAtkSpd(), data.getCastSpdLabel(), status.getMAtkSpd()));
		sb.append("</table>");
		sb.append(getSeparator());

		return sb.toString();
	}

	/**
	 * @return The opening tags of one block of the header, both of them being drawn on the plain band color of the list.
	 */
	private static String getHeaderBlockStart()
	{
		final DropListData data = DropListData.getInstance();

		return "<table width=" + data.getWidth() + ((data.getRowColor().isEmpty()) ? "" : " bgcolor=\"" + data.getRowColor() + "\"") + ">";
	}

	/**
	 * One line of the header, holding two stats side by side. Both values are rendered with their thousand separators - an XP amount is way too long to be read raw - and right aligned on the edge of
	 * their own column, which is what keeps the numbers of a block readable whatever their magnitude.
	 * @param leftLabel : The caption of the stat of the left column.
	 * @param leftValue : The number shown on the left column.
	 * @param rightLabel : The caption of the stat of the right column.
	 * @param rightValue : The number shown on the right column.
	 * @return One line of the header, as a pair of caption/value cells per column.
	 */
	private static String getHeaderRow(String leftLabel, long leftValue, String rightLabel, long rightValue)
	{
		final DropListData data = DropListData.getInstance();

		// The gap sits between the two columns, so the caption of the right one never touches the value of the left one, which is right aligned on the column edge.
		final int gap = Math.min(data.getHeaderGap(), data.getWidth() - 2);
		final int columnWidth = Math.max(2, (data.getWidth() - gap) / 2);
		final int labelWidth = Math.max(1, Math.min(data.getHeaderLabelWidth(), columnWidth - 1));

		final StringBuilder sb = new StringBuilder(448);

		sb.append("<tr>");
		sb.append(getCell(labelWidth, data.getHeaderHeight(), "left", colorize(data.getHeaderTextColor(), escape(leftLabel))));
		sb.append(getCell(columnWidth - labelWidth, 0, "right", colorize(data.getHeaderValueColor(), StringUtil.formatNumber(leftValue))));

		if (gap > 0)
			sb.append(getCell(gap, 0, "left", ""));

		sb.append(getCell(labelWidth, 0, "left", colorize(data.getHeaderTextColor(), escape(rightLabel))));

		// The last cell takes whatever is left of the layout width, which absorbs the rounding of an odd width.
		sb.append(getCell(Math.max(1, data.getWidth() - columnWidth - gap - labelWidth), 0, "right", colorize(data.getHeaderValueColor(), StringUtil.formatNumber(rightValue))));
		sb.append("</tr>");

		return sb.toString();
	}

	/**
	 * @return The height, in pixels, the header of the first page takes, the rules cutting its blocks apart and closing it included.
	 */
	private static int getHeaderHeight()
	{
		final DropListData data = DropListData.getInstance();

		return HEADER_ROWS * data.getHeaderHeight() + ((data.getSeparator().isEmpty()) ? 0 : HEADER_SEPARATORS * SEPARATOR_HEIGHT);
	}

	/**
	 * The header doesn't grow the first page, it takes the room of the item rows it covers - which is what keeps every page of the same height, and the page selector at one spot.
	 * @return The amount of item rows the header of the first page costs, rounded up.
	 */
	private static int getHeaderRowCost()
	{
		final int rowHeight = DropListData.getInstance().getRowHeight();

		return (getHeaderHeight() + rowHeight - 1) / rowHeight;
	}

	/**
	 * @return The horizontal rule framing a group header, empty when the datapack holds no separator texture.
	 */
	private static String getSeparator()
	{
		final DropListData data = DropListData.getInstance();

		return (data.getSeparator().isEmpty()) ? "" : "<img src=\"" + data.getSeparator() + "\" width=" + data.getWidth() + " height=" + SEPARATOR_HEIGHT + ">";
	}

	/**
	 * @param row : The {@link DropRow} to render.
	 * @param color : The background color of the row, empty keeping it see-through.
	 * @return The whole row, rendered as its own table.
	 */
	private static String getRow(DropRow row, String color)
	{
		final DropListData data = DropListData.getInstance();
		final Item item = ItemData.getInstance().getTemplate(row.itemId());

		final String name = (item == null) ? String.valueOf(row.itemId()) : truncate(item.getName(), data.getNameChars());

		final StringBuilder sb = new StringBuilder(384);

		StringUtil.append(sb, getRowStart(color));
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
		final DropListData data = DropListData.getInstance();

		final String amount = (row.min() == row.max()) ? StringUtil.formatNumber(row.min()) : StringUtil.formatNumber(row.min()) + data.getCountRange() + StringUtil.formatNumber(row.max());

		return escape(data.getCountPrefix() + amount);
	}

	/**
	 * @param chance : The already computed chance, in percent.
	 * @return The chance cell content. A chance the pattern of the datapack rounds down to a bare zero gets the "nearZero" label instead, since a shown 0% would read as "never".
	 */
	private static String getChanceText(double chance)
	{
		final DropListData data = DropListData.getInstance();
		final DecimalFormat format = new DecimalFormat(data.getChancePattern(), CHANCE_SYMBOLS);

		final String text = format.format(chance);

		// Comparing against the formatted zero rather than against a threshold keeps this right whatever amount of decimals the pattern holds.
		if (chance > 0 && text.equals(format.format(0)))
			return escape(data.getNearZeroLabel());

		return escape(text + data.getChanceSuffix());
	}

	/**
	 * Each row of the list is rendered as its own table, since the client only handles the bgcolor attribute on tables.
	 * @param color : The background color of the row, empty keeping it see-through.
	 * @return The opening tags of a list row.
	 */
	private static String getRowStart(String color)
	{
		return "<table width=" + DropListData.getInstance().getWidth() + ((color.isEmpty()) ? "" : " bgcolor=\"" + color + "\"") + "><tr>";
	}

	/**
	 * The stripes of the page run over the group headers as well as over the item rows : a header is a band like any other, so the item sitting right under one always owns the opposite color.
	 * @param index : The index of the band on the current page, headers and rows counted alike, 0 being the first one.
	 * @return The background color of the given band, empty meaning transparent.
	 */
	private static String getBandColor(int index)
	{
		final DropListData data = DropListData.getInstance();

		return (index % 2 == 0) ? data.getRowColor() : data.getAltRowColor();
	}

	/**
	 * The bottom row of the page, holding the page selector. It is always emitted, even empty : an occasionally missing row would shorten a page by one row height, and pages without a scrollbar
	 * would show up again.<br>
	 * <br>
	 * The selector never wraps : a cell owns the width the datapack reserved for it, and the amount of shown links is whatever fits the layout width out of that - the "maxPages" of the datapack only
	 * lowers it further. Sizing the cells out of "maxPages" instead, as an earlier take did, squeezes them under the width their own content needs, and the client then breaks the row in two.
	 * @param monster : The {@link Monster} used as dialog holder.
	 * @param page : The currently shown page index.
	 * @param pages : The total amount of pages.
	 * @return The footer row, replacing the %footer% variable.
	 */
	private static String getFooter(Monster monster, int page, int pages)
	{
		final DropListData data = DropListData.getInstance();

		// Every cell owns the same width, so the selector doesn't jump around while browsing the pages.
		final int cellWidth = data.getPageWidth();

		int first = 0;
		int last = 0;
		boolean hasPrev = false;
		boolean hasNext = false;

		if (pages > 1)
		{
			hasPrev = page > 0;
			hasNext = page < pages - 1;

			// Whatever the row can hold, the arrows taking a cell of their own.
			final int room = data.getWidth() / cellWidth - ((hasPrev) ? 1 : 0) - ((hasNext) ? 1 : 0);
			final int shown = Math.max(1, Math.min(data.getMaxPages(), room));

			// Center the shown window of pages on the current page.
			first = Math.max(0, page - shown / 2);
			last = Math.min(pages, first + shown);
			first = Math.max(0, last - shown);
		}

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
	 * @param groups : The amount of group headers actually rendered on the current page, each owning its own height and the two rules framing it.
	 * @param rows : The amount of item rows actually rendered on the current page.
	 * @param headerHeight : The height, in pixels, the page header takes, 0 on the pages which don't carry one.
	 * @return The spacer filling the bottom of the page, replacing the %filler% variable.
	 */
	private static String getFiller(int groups, int rows, int headerHeight)
	{
		final DropListData data = DropListData.getInstance();
		if (data.getPageHeight() <= 0)
			return "";

		final int groupHeight = data.getGroupHeight() + ((data.getSeparator().isEmpty()) ? 0 : 2 * SEPARATOR_HEIGHT);
		final int missing = data.getPageHeight() - data.getOverhead() - headerHeight - groups * groupHeight - rows * data.getRowHeight();

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
	 * Every single datapack string goes through this on its way to the client, and none may skip it : the XML parser hands over decoded text, so a "&amp;lt;" of the XML reaches here as a bare "&lt;"
	 * the client would then swallow as the start of a tag - which is what silently emptied the cell holding the "nearZero" label.
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

	/**
	 * @param size : The total amount of item rows to page.
	 * @param firstPageRows : The amount of rows the first page holds, which is lowered by the header it carries.
	 * @param perPage : The amount of rows every other page holds.
	 * @return The amount of pages the list spans, 1 at the very least.
	 */
	private static int getPageCount(int size, int firstPageRows, int perPage)
	{
		if (size <= firstPageRows)
			return 1;

		return 1 + (size - firstPageRows + perPage - 1) / perPage;
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
