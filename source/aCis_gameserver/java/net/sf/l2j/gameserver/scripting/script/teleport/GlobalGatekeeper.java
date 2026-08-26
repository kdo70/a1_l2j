package net.sf.l2j.gameserver.scripting.script.teleport;

import java.util.List;
import java.util.Set;
import java.util.StringTokenizer;
import java.util.concurrent.ConcurrentHashMap;

import net.sf.l2j.commons.lang.StringUtil;
import net.sf.l2j.commons.pool.ThreadPool;

import net.sf.l2j.gameserver.data.cache.HtmCache;
import net.sf.l2j.gameserver.data.manager.CastleManager;
import net.sf.l2j.gameserver.data.manager.GatekeeperStatsManager;
import net.sf.l2j.gameserver.data.xml.GatekeeperData;
import net.sf.l2j.gameserver.data.xml.ItemData;
import net.sf.l2j.gameserver.enums.GatekeeperPointType;
import net.sf.l2j.gameserver.enums.GatekeeperTabType;
import net.sf.l2j.gameserver.enums.GaugeColor;
import net.sf.l2j.gameserver.model.actor.Npc;
import net.sf.l2j.gameserver.model.actor.Player;
import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperArea;
import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperColumn;
import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperMenu;
import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperPoint;
import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperTab;
import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperTable;
import net.sf.l2j.gameserver.model.item.kind.Item;
import net.sf.l2j.gameserver.model.residence.castle.Castle;
import net.sf.l2j.gameserver.network.SystemMessageId;
import net.sf.l2j.gameserver.network.serverpackets.ActionFailed;
import net.sf.l2j.gameserver.network.serverpackets.MagicSkillCanceled;
import net.sf.l2j.gameserver.network.serverpackets.MagicSkillUse;
import net.sf.l2j.gameserver.network.serverpackets.NpcHtmlMessage;
import net.sf.l2j.gameserver.network.serverpackets.SetupGauge;
import net.sf.l2j.gameserver.scripting.Quest;

/**
 * A fully datapack driven Gatekeeper.<br>
 * <br>
 * Npc ids, menu tabs, areas, teleport points, prices, but also every color, label and column of the dialog are described on data/xml/gatekeeper.xml, while the behavior and the economy live on
 * config/gatekeeper.properties. The HTMs of this script folder only hold the static parts of the pages ; every table is generated here, so the header always matches the rows.<br>
 * <br>
 * Teleport counters are handled by {@link GatekeeperStatsManager}.
 * <ul>
 * <li>List &lt;tab&gt; &lt;page&gt; : shows the areas of a tab.</li>
 * <li>Area &lt;tab&gt; &lt;area&gt; &lt;page&gt; : shows the teleport points of an area.</li>
 * <li>Popular &lt;tab&gt; &lt;page&gt; : shows the most used teleport points of the menu.</li>
 * <li>Page &lt;tab&gt; &lt;file&gt; : shows an additional datapack HTM.</li>
 * <li>Tp &lt;tab&gt; &lt;area&gt; &lt;page&gt; &lt;point&gt; : teleports the Player, area being -1 from the popular tab and -2 from the capital column of the areas list.</li>
 * </ul>
 * The teleport itself is delayed by the "TeleportDelay" setting, during which the /unstuck casting animation is played.
 */
public class GlobalGatekeeper extends Quest
{
	private static final String ROW_END = "</tr></table>";

	/** Area index used by the Tp bypass, when it is fired from the popular tab. */
	private static final int FROM_POPULAR = -1;
	/** Area index used by the Tp bypass, when it is fired from the capital column of the areas list. */
	private static final int FROM_AREAS = -2;

	/** The GM /unstuck skill, only used for its casting animation. */
	private static final int ESCAPE_SKILL_ID = 2100;

	private final Set<Integer> _pendingTeleports = ConcurrentHashMap.newKeySet();

	public GlobalGatekeeper()
	{
		super(-1, "teleport");

		final int[] npcIds = GatekeeperData.getInstance().getNpcIds();
		if (npcIds.length == 0)
			return;

		// FIRST_TALK overrides the default Npc dialog, while TALKED allows the "Quest GlobalGatekeeper" bypasses.
		addFirstTalkId(npcIds);
		addTalkId(npcIds);
	}

	@Override
	public String onFirstTalk(Npc npc, Player player)
	{
		final GatekeeperMenu menu = GatekeeperData.getInstance().getMenuByNpcId(npc.getNpcId());
		if (menu == null)
			return null;

		showTab(npc, player, menu, menu.getDefaultTab(), 0);

		return null;
	}

	@Override
	public String onTalk(Npc npc, Player player)
	{
		return onFirstTalk(npc, player);
	}

	@Override
	public String onAdvEvent(String event, Npc npc, Player player)
	{
		if (npc == null || player == null)
			return null;

		final GatekeeperMenu menu = GatekeeperData.getInstance().getMenuByNpcId(npc.getNpcId());
		if (menu == null)
			return null;

		final StringTokenizer st = new StringTokenizer(event, " ");
		if (!st.hasMoreTokens())
			return null;

		final String command = st.nextToken();

		try
		{
			switch (command)
			{
				case "List":
				{
					final GatekeeperTab tab = menu.getTab(Integer.parseInt(st.nextToken()));
					final int page = (st.hasMoreTokens()) ? Integer.parseInt(st.nextToken()) : 0;

					showAreas(npc, player, menu, tab, page);
					break;
				}
				case "Area":
				{
					final GatekeeperTab tab = menu.getTab(Integer.parseInt(st.nextToken()));
					if (tab == null)
						break;

					final GatekeeperArea area = tab.getArea(Integer.parseInt(st.nextToken()));
					final int page = (st.hasMoreTokens()) ? Integer.parseInt(st.nextToken()) : 0;

					showPoints(npc, player, menu, tab, area, page);
					break;
				}
				case "Popular":
				{
					final GatekeeperTab tab = menu.getTab(Integer.parseInt(st.nextToken()));
					final int page = (st.hasMoreTokens()) ? Integer.parseInt(st.nextToken()) : 0;

					showPopular(npc, player, menu, tab, page);
					break;
				}
				case "Page":
				{
					final GatekeeperTab tab = menu.getTab(Integer.parseInt(st.nextToken()));
					if (tab == null || !st.hasMoreTokens())
						break;

					showPage(npc, player, menu, tab, st.nextToken());
					break;
				}
				case "Tp":
				{
					final GatekeeperTab tab = menu.getTab(Integer.parseInt(st.nextToken()));
					final int areaIndex = Integer.parseInt(st.nextToken());
					final int page = Integer.parseInt(st.nextToken());
					final int pointId = Integer.parseInt(st.nextToken());

					if (teleport(player, menu, pointId) || tab == null)
						break;

					// The teleport failed ; refresh the list the Player comes from.
					if (areaIndex == FROM_AREAS)
						showAreas(npc, player, menu, tab, page);
					else if (areaIndex == FROM_POPULAR)
						showPopular(npc, player, menu, tab, page);
					else
						showPoints(npc, player, menu, tab, tab.getArea(areaIndex), page);
					break;
				}
			}
		}
		catch (Exception e)
		{
			LOGGER.warn("Couldn't handle the event '{}' of {}.", e, event, toString());
		}

		return null;
	}

	/**
	 * Show the content of a {@link GatekeeperTab}, based on its {@link GatekeeperTabType}.
	 * @param npc : The {@link Npc} used as dialog holder.
	 * @param player : The {@link Player} to send the dialog to.
	 * @param menu : The {@link GatekeeperMenu} of the {@link Npc}.
	 * @param tab : The {@link GatekeeperTab} to show.
	 * @param page : The page index to show.
	 */
	private void showTab(Npc npc, Player player, GatekeeperMenu menu, GatekeeperTab tab, int page)
	{
		if (tab == null)
			return;

		switch (tab.getType())
		{
			case AREAS:
				showAreas(npc, player, menu, tab, page);
				break;

			case POINTS:
				showPoints(npc, player, menu, tab, tab.getArea(0), page);
				break;

			case POPULAR:
				showPopular(npc, player, menu, tab, page);
				break;

			case PAGE:
				showPage(npc, player, menu, tab, tab.getPage());
				break;

			default:
				break;
		}
	}

	private void showAreas(Npc npc, Player player, GatekeeperMenu menu, GatekeeperTab tab, int page)
	{
		if (tab == null || tab.getType() != GatekeeperTabType.AREAS)
			return;

		final GatekeeperData data = GatekeeperData.getInstance();
		final GatekeeperTable table = data.getTable(GatekeeperData.AREAS_TABLE);
		final GatekeeperColumn nameColumn = table.getColumn("name");
		final GatekeeperColumn priceColumn = table.getColumn("price");
		final GatekeeperColumn capitalColumn = table.getColumn("capital");

		final List<GatekeeperArea> areas = tab.getAreas();
		final int perPage = data.getRowsPerPage();
		final int pages = getPageCount(areas.size(), perPage);

		page = Math.min(Math.max(page, 0), pages - 1);

		final int first = page * perPage;
		final int last = Math.min(areas.size(), first + perPage);

		final StringBuilder sb = new StringBuilder();

		for (int i = first; i < last; i++)
		{
			final GatekeeperArea area = areas.get(i);
			final GatekeeperPoint main = area.getMainPoint();

			// A direct row teleports right away ; a regular one leads to the points list of its area.
			final String name = (area.isDirect()) ? getPointLink(main, player, tab.getIndex(), FROM_AREAS, page, truncate(area.getName(), nameColumn.getMaxChars())) : "<a action=\"bypass -h Quest " + getName() + " Area " + tab.getIndex() + " " + i + " 0\">" + colorize(data.getNameColor(), escape(truncate(area.getName(), nameColumn.getMaxChars()))) + "</a>";
			final String action = (area.isDirect()) ? getActionText(main, player, tab.getIndex(), FROM_AREAS, page) : getCapitalText(area, player, tab.getIndex(), page, capitalColumn);

			StringUtil.append(sb, getRowStart(i - first), nameColumn.getCell(data.getRowHeight(), name), priceColumn.getCell(0, getPriceText(main, player)), capitalColumn.getCell(0, action), ROW_END);
		}

		String content = getHtmlText("areas.htm");
		content = content.replace("%menu%", getMenu(menu, tab));
		content = content.replace("%header%", getHeader(table));
		content = content.replace("%list%", sb.toString());
		content = content.replace("%filler%", getFiller(menu, table, last - first));
		content = content.replace("%pages%", getPages("Quest " + getName() + " List " + tab.getIndex(), page, pages));
		content = content.replace("%pk%", (player.getKarma() > 0) ? getFragment("pk.htm") : "");

		sendHtml(npc, player, content);
	}

	private void showPoints(Npc npc, Player player, GatekeeperMenu menu, GatekeeperTab tab, GatekeeperArea area, int page)
	{
		if (tab == null || area == null)
			return;

		final GatekeeperData data = GatekeeperData.getInstance();
		final GatekeeperTable table = data.getTable(GatekeeperData.POINTS_TABLE);
		final GatekeeperColumn nameColumn = table.getColumn("name");
		final GatekeeperColumn priceColumn = table.getColumn("price");
		final GatekeeperColumn actionColumn = table.getColumn("action");

		final List<GatekeeperPoint> points = area.getPoints();
		final int perPage = data.getRowsPerPage();
		final int pages = getPageCount(points.size(), perPage);

		page = Math.min(Math.max(page, 0), pages - 1);

		final int first = page * perPage;
		final int last = Math.min(points.size(), first + perPage);

		final StringBuilder sb = new StringBuilder();

		for (int i = first; i < last; i++)
		{
			final GatekeeperPoint point = points.get(i);

			StringUtil.append(sb, getRowStart(i - first), nameColumn.getCell(data.getRowHeight(), getFullNameText(point, player, nameColumn.getMaxChars())), priceColumn.getCell(0, getPriceText(point, player)), actionColumn.getCell(0, getActionText(point, player, tab.getIndex(), area.getIndex(), page)), ROW_END);
		}

		String content = getHtmlText("locations.htm");
		content = content.replace("%menu%", getMenu(menu, tab));
		content = content.replace("%area%", escape(area.getName()));
		content = content.replace("%header%", getHeader(table));
		content = content.replace("%locations%", sb.toString());
		content = content.replace("%filler%", getFiller(menu, table, last - first));
		content = content.replace("%pages%", getPages("Quest " + getName() + " Area " + tab.getIndex() + " " + area.getIndex(), page, pages));
		content = content.replace("%back%", (tab.isFlat()) ? "" : getCenteredRow("<a action=\"bypass -h Quest " + getName() + " List " + tab.getIndex() + " 0\">" + escape(data.getBackLabel()) + "</a>"));

		sendHtml(npc, player, content);
	}

	private void showPopular(Npc npc, Player player, GatekeeperMenu menu, GatekeeperTab tab, int page)
	{
		if (tab == null)
			return;

		final GatekeeperData data = GatekeeperData.getInstance();
		final GatekeeperStatsManager stats = GatekeeperStatsManager.getInstance();

		final GatekeeperTable table = data.getTable(GatekeeperData.POPULAR_TABLE);
		final GatekeeperColumn nameColumn = table.getColumn("name");
		final GatekeeperColumn priceColumn = table.getColumn("price");
		final GatekeeperColumn actionColumn = table.getColumn("action");

		// Keep the points of this menu only, above the minimum amount of uses, up to the configured limit.
		final List<GatekeeperPoint> points = stats.getRanking().stream().filter(id -> stats.getCount(id) >= data.getPopularMinCount()).map(id -> menu.getPoint(id)).filter(point -> point != null).limit(data.getPopularLimit()).toList();

		final int perPage = data.getRowsPerPage();
		final int pages = getPageCount(points.size(), perPage);

		page = Math.min(Math.max(page, 0), pages - 1);

		final int first = page * perPage;
		final int last = Math.min(points.size(), first + perPage);

		final StringBuilder sb = new StringBuilder();

		if (points.isEmpty())
			StringUtil.append(sb, getRowStart(0), "<td width=", data.getWidth(), " height=", data.getRowHeight(), ">", colorize(data.getDisabledColor(), escape(data.getEmptyLabel())), "</td>", ROW_END);

		for (int i = first; i < last; i++)
		{
			final GatekeeperPoint point = points.get(i);

			StringUtil.append(sb, getRowStart(i - first), nameColumn.getCell(data.getRowHeight(), getFullNameText(point, player, nameColumn.getMaxChars())), priceColumn.getCell(0, getPriceText(point, player)), actionColumn.getCell(0, getActionText(point, player, tab.getIndex(), FROM_POPULAR, page)), ROW_END);
		}

		String content = getHtmlText("popular.htm");
		content = content.replace("%menu%", getMenu(menu, tab));
		content = content.replace("%header%", getHeader(table));
		content = content.replace("%locations%", sb.toString());
		content = content.replace("%filler%", getFiller(menu, table, Math.max(1, last - first)));
		content = content.replace("%pages%", getPages("Quest " + getName() + " Popular " + tab.getIndex(), page, pages));

		sendHtml(npc, player, content);
	}

	private void showPage(Npc npc, Player player, GatekeeperMenu menu, GatekeeperTab tab, String fileName)
	{
		if (tab == null || fileName == null || !GatekeeperData.isValidPage(fileName))
			return;

		String content = getHtmlText(fileName);
		content = content.replace("%menu%", getMenu(menu, tab));

		sendHtml(npc, player, content);
	}

	/**
	 * Test every teleport condition, take the price and teleport the {@link Player}. On success, the teleport counter of the {@link GatekeeperPoint} is incremented.
	 * @param player : The {@link Player} to teleport.
	 * @param menu : The {@link GatekeeperMenu} of the Npc, used as bypass whitelist.
	 * @param pointId : The {@link GatekeeperPoint} id to reach.
	 * @return True if the {@link Player} has been teleported, false otherwise.
	 */
	private boolean teleport(Player player, GatekeeperMenu menu, int pointId)
	{
		// The point must be reachable from this Npc menu.
		final GatekeeperPoint point = menu.getPoint(pointId);
		if (point == null)
			return false;

		// A teleport animation is already running ; don't take the price twice.
		if (_pendingTeleports.contains(player.getObjectId()))
		{
			player.sendPacket(ActionFailed.STATIC_PACKET);
			return true;
		}

		if (player.isDead() || player.isOperating() || player.isInOlympiadMode() || player.isInObserverMode() || player.isFestivalParticipant() || player.isCursedWeaponEquipped())
		{
			player.sendMessage("You can't be teleported right now.");
			return false;
		}

		if (point.getType() == GatekeeperPointType.NOBLE && !player.isNoble())
		{
			player.sendPacket(SystemMessageId.NOBLESSE_ONLY);
			return false;
		}

		final int level = player.getStatus().getLevel();
		if (level < point.getMinLevel() || level > point.getMaxLevel())
		{
			player.sendMessage("Your level doesn't allow you to reach " + point.getFullName() + ".");
			return false;
		}

		if (point.getCastleId() > 0)
		{
			final Castle castle = CastleManager.getInstance().getCastleById(point.getCastleId());
			if (castle != null && castle.getSiege().isInProgress())
			{
				player.sendPacket(SystemMessageId.CANNOT_PORT_VILLAGE_IN_SIEGE);
				return false;
			}
		}

		final int price = point.getCalculatedPrice(player);
		if (price > 0 && !player.destroyItemByItemId(point.getPriceId(), price, true))
		{
			player.sendPacket(SystemMessageId.YOU_NOT_ENOUGH_ADENA);
			return false;
		}

		final int delay = GatekeeperData.getInstance().getTeleportDelay();
		if (delay <= 0)
		{
			doTeleport(player, point);
			return true;
		}

		final int objectId = player.getObjectId();

		_pendingTeleports.add(objectId);

		// Mimic the /unstuck cast, without actually casting the skill (which owns its own teleport effect).
		final boolean wasImmobilized = player.isImmobilized();

		player.abortAll(false);
		player.setIsImmobilized(true);
		player.broadcastPacket(new MagicSkillUse(player, player, ESCAPE_SKILL_ID, 1, delay, 0));
		player.sendPacket(new SetupGauge(GaugeColor.BLUE, delay));

		ThreadPool.schedule(() ->
		{
			_pendingTeleports.remove(objectId);

			if (!wasImmobilized)
				player.setIsImmobilized(false);

			// The Player died or left the world meanwhile ; cancel the animation and refund the price.
			if (player.isDead() || !player.isOnline())
			{
				player.broadcastPacket(new MagicSkillCanceled(objectId));

				if (price > 0 && player.isOnline())
					giveItems(player, point.getPriceId(), price);

				return;
			}

			doTeleport(player, point);
		}, delay);

		return true;
	}

	/**
	 * Teleport the {@link Player} and increment the teleport counter of the {@link GatekeeperPoint}.
	 * @param player : The {@link Player} to teleport.
	 * @param point : The {@link GatekeeperPoint} to reach.
	 */
	private static void doTeleport(Player player, GatekeeperPoint point)
	{
		player.teleportTo(point, 20);

		GatekeeperStatsManager.getInstance().increase(point.getId());
	}

	/**
	 * @param area : The {@link GatekeeperArea} to render.
	 * @param player : The {@link Player} used to test conditions.
	 * @param tabIndex : The index of the current {@link GatekeeperTab}, used to build the bypass.
	 * @param page : The current page of the areas list, used to build the bypass.
	 * @param column : The {@link GatekeeperColumn} holding the cell, used to shorten the capital name.
	 * @return The capital cell content, being a direct teleport link to the main point of the area.
	 */
	private String getCapitalText(GatekeeperArea area, Player player, int tabIndex, int page, GatekeeperColumn column)
	{
		if (area.getCapital().isEmpty())
			return "";

		final GatekeeperData data = GatekeeperData.getInstance();
		final String capital = truncate(area.getCapital(), column.getMaxChars());

		final GatekeeperPoint main = area.getMainPoint();
		if (main == null || !main.isAvailableFor(player))
			return colorize(data.getDisabledColor(), escape(capital));

		return "<a action=\"bypass -h Quest " + getName() + " Tp " + tabIndex + " " + FROM_AREAS + " " + page + " " + main.getId() + "\" msg=\"811;" + getPopupText(main, player) + "\">" + colorize(data.getNameColor(), escape(capital)) + "</a>";
	}

	/**
	 * Each row of a list is rendered as its own table, since the client only handles the bgcolor attribute on tables.
	 * @param row : The index of the row on the current page, 0 being the first one.
	 * @return The opening tags of a list row, alternating both row colors.
	 */
	private static String getRowStart(int row)
	{
		final GatekeeperData data = GatekeeperData.getInstance();
		final String color = (row % 2 == 0) ? data.getAltRowColor() : data.getRowColor();

		return "<table width=" + data.getWidth() + ((color.isEmpty()) ? "" : " bgcolor=\"" + color + "\"") + "><tr>";
	}

	/**
	 * The header is generated out of the very same {@link GatekeeperColumn}s as the rows, which is the only way to keep both aligned whatever the datapack layout is.
	 * @param table : The {@link GatekeeperTable} to render.
	 * @return The header row of a list, replacing the %header% variable.
	 */
	private static String getHeader(GatekeeperTable table)
	{
		final GatekeeperData data = GatekeeperData.getInstance();
		final StringBuilder sb = new StringBuilder(256);

		StringUtil.append(sb, "<table width=", data.getWidth(), (data.getHeaderColor().isEmpty()) ? "" : " bgcolor=\"" + data.getHeaderColor() + "\"", "><tr>");

		for (GatekeeperColumn column : table.getColumns())
			sb.append(column.getCell(data.getHeaderHeight(), colorize(data.getHeaderTextColor(), escape(column.getHeader()))));

		sb.append(ROW_END);

		return sb.toString();
	}

	/**
	 * The dialog owns a fixed height, so padding every page up to one single total keeps the page selector at the very same spot - and, the total being slightly above the dialog, keeps the
	 * scrollbar shown everywhere.
	 * @param menu : The {@link GatekeeperMenu} being shown, whose tab bar height varies with its amount of tabs.
	 * @param table : The {@link GatekeeperTable} of the page, holding the static height of its HTM.
	 * @param shown : The amount of rows actually rendered on the current page.
	 * @return The spacer pushing the bottom of the page down, replacing the %filler% variable.
	 */
	private static String getFiller(GatekeeperMenu menu, GatekeeperTable table, int shown)
	{
		final GatekeeperData data = GatekeeperData.getInstance();
		if (data.getPageHeight() <= 0)
			return "";

		final int missing = data.getPageHeight() - table.getOverhead() - getMenuRows(menu) * data.getTabHeight() - shown * data.getRowHeight();

		return (missing <= 0) ? "" : "<img height=" + missing + ">";
	}

	/**
	 * @param menu : The {@link GatekeeperMenu} to measure.
	 * @return The amount of rows the tab bar of the given menu spans over.
	 */
	private static int getMenuRows(GatekeeperMenu menu)
	{
		return getPageCount(menu.getTabs().size(), GatekeeperData.getInstance().getTabColumns());
	}

	/**
	 * @param menu : The {@link GatekeeperMenu} to render.
	 * @param active : The currently shown {@link GatekeeperTab}.
	 * @return The whole tab bar, replacing the %menu% variable.
	 */
	private static String getMenu(GatekeeperMenu menu, GatekeeperTab active)
	{
		final List<GatekeeperTab> tabs = menu.getTabs();
		if (tabs.isEmpty())
			return "";

		final GatekeeperData data = GatekeeperData.getInstance();

		// Spread the tabs on multiple rows, in order to keep them readable.
		final int rows = getPageCount(tabs.size(), data.getTabColumns());
		final int columns = getPageCount(tabs.size(), rows);
		final int width = Math.max(data.getWidth() / columns, 1);

		// The last column of a row absorbs the rounding, so the bar always spans the whole width.
		final int lastWidth = Math.max(data.getWidth() - width * (columns - 1), 1);

		final StringBuilder sb = new StringBuilder(256);

		StringUtil.append(sb, "<table width=", data.getWidth(), (data.getTabBarColor().isEmpty()) ? "" : " bgcolor=\"" + data.getTabBarColor() + "\"", "><tr>");

		for (int i = 0; i < tabs.size(); i++)
		{
			if (i > 0 && i % columns == 0)
				sb.append("</tr><tr>");

			final GatekeeperTab tab = tabs.get(i);
			final boolean isLast = (i % columns) == (columns - 1);

			StringUtil.append(sb, "<td width=", (isLast) ? lastWidth : width, " height=", data.getTabHeight(), " align=center><a action=\"bypass -h ", tab.getBypass(), "\">", colorize((tab == active) ? data.getActiveTabColor() : tab.getColor(), escape(tab.getName())), "</a></td>");
		}

		sb.append(ROW_END);

		return sb.toString();
	}

	/**
	 * The page selector is rendered as a single table row, since the client turns every link of a &lt;center&gt; block into its own line.
	 * @param bypass : The bypass to fire, the page index being appended to it.
	 * @param page : The currently shown page index.
	 * @param pages : The total amount of pages.
	 * @return The page selector, replacing the %pages% variable - an empty {@link String} if a single page exists.
	 */
	private static String getPages(String bypass, int page, int pages)
	{
		if (pages <= 1)
			return "";

		final GatekeeperData data = GatekeeperData.getInstance();
		final int maxPages = data.getMaxPages();

		// Center the shown window of pages on the current page.
		int first = Math.max(0, page - maxPages / 2);
		final int last = Math.min(pages, first + maxPages);
		first = Math.max(0, last - maxPages);

		final boolean hasPrev = page > 0;
		final boolean hasNext = page < pages - 1;

		// Every cell owns the same width, so the selector doesn't jump around while browsing the pages.
		final int cellWidth = Math.max(1, data.getWidth() / (maxPages + 2));
		final int cells = (last - first) + ((hasPrev) ? 1 : 0) + ((hasNext) ? 1 : 0);
		final int lead = Math.max(0, (data.getWidth() - cells * cellWidth) / 2);
		final int trail = Math.max(0, data.getWidth() - lead - cells * cellWidth);

		final StringBuilder sb = new StringBuilder(512);

		StringUtil.append(sb, "<table width=", data.getWidth(), "><tr>");

		if (lead > 0)
			StringUtil.append(sb, "<td width=", lead, " height=", data.getRowHeight(), "></td>");

		if (hasPrev)
			StringUtil.append(sb, getPageCell(cellWidth, "<a action=\"bypass -h " + bypass + " " + (page - 1) + "\">" + colorize(data.getPageColor(), escape(data.getPrevPageLabel())) + "</a>"));

		for (int i = first; i < last; i++)
		{
			final String label = String.valueOf(i + 1);

			sb.append(getPageCell(cellWidth, (i == page) ? colorize(data.getActivePageColor(), label) : "<a action=\"bypass -h " + bypass + " " + i + "\">" + colorize(data.getPageColor(), label) + "</a>"));
		}

		if (hasNext)
			sb.append(getPageCell(cellWidth, "<a action=\"bypass -h " + bypass + " " + (page + 1) + "\">" + colorize(data.getPageColor(), escape(data.getNextPageLabel())) + "</a>"));

		if (trail > 0)
			StringUtil.append(sb, "<td width=", trail, "></td>");

		sb.append(ROW_END);

		return sb.toString();
	}

	private static String getPageCell(int width, String content)
	{
		return "<td width=" + width + " height=" + GatekeeperData.getInstance().getRowHeight() + " align=center>" + content + "</td>";
	}

	/**
	 * @param content : The already rendered content to center.
	 * @return A single, full width and centered row - used by the %back% variable, which must stay on one line.
	 */
	private static String getCenteredRow(String content)
	{
		final GatekeeperData data = GatekeeperData.getInstance();

		return "<table width=" + data.getWidth() + "><tr><td width=" + data.getWidth() + " height=" + data.getRowHeight() + " align=center>" + content + "</td>" + ROW_END;
	}

	/**
	 * @param point : The {@link GatekeeperPoint} to render, can be null.
	 * @param player : The {@link Player} used to compute the price.
	 * @return The price cell content of a given {@link GatekeeperPoint}.
	 */
	private static String getPriceText(GatekeeperPoint point, Player player)
	{
		if (point == null)
			return "";

		final GatekeeperData data = GatekeeperData.getInstance();

		final int price = point.getCalculatedPrice(player);
		if (price <= 0)
			return colorize(data.getFreeColor(), escape(data.getFreeLabel()));

		return colorize(data.getPriceColor(), StringUtil.formatNumber(price)) + " " + getCurrencyText(point.getPriceId());
	}

	/**
	 * @param priceId : The currency item id to render.
	 * @return The currency shown next to a price - either its whole name, localized by the client, or the first "currencyChars" characters of its server side name.
	 */
	private static String getCurrencyText(int priceId)
	{
		final GatekeeperData data = GatekeeperData.getInstance();

		// &#itemId; is replaced by the client with the localized item name.
		if (data.getCurrencyChars() <= 0)
			return "&#" + priceId + ";";

		final Item item = ItemData.getInstance().getTemplate(priceId);
		if (item == null)
			return "";

		final String name = item.getName();
		final String shortened = (name.length() <= data.getCurrencyChars()) ? name : name.substring(0, data.getCurrencyChars());

		return escape((data.isCurrencyLowerCase()) ? shortened.toLowerCase() : shortened);
	}

	/**
	 * The client confirmation box only accepts a single parameter, so the price is appended to the destination name.
	 * @param point : The {@link GatekeeperPoint} to render.
	 * @param player : The {@link Player} used to compute the price.
	 * @return The content of the confirmation box shown before the teleport.
	 */
	private static String getPopupText(GatekeeperPoint point, Player player)
	{
		final int price = point.getCalculatedPrice(player);
		if (price <= 0)
			return point.getFullName();

		final Item item = ItemData.getInstance().getTemplate(point.getPriceId());

		return point.getFullName() + " (" + StringUtil.formatNumber(price) + ((item == null) ? "" : " " + item.getName()) + ")";
	}

	/**
	 * The sub-point name doesn't own its own column anymore ; it is appended to the location name, and kept apart by its own color.
	 * @param point : The {@link GatekeeperPoint} to render.
	 * @param player : The {@link Player} used to test conditions.
	 * @param maxChars : The maximum amount of characters of the name column.
	 * @return The name cell content of a given {@link GatekeeperPoint}, greyed as a whole if the {@link Player} can't use it.
	 */
	private static String getFullNameText(GatekeeperPoint point, Player player, int maxChars)
	{
		final GatekeeperData data = GatekeeperData.getInstance();
		final String text = truncate(point.getFullName(), maxChars);

		if (!point.isAvailableFor(player))
			return colorize(data.getDisabledColor(), escape(text));

		// The separator may have been cut away by the shortening ; only split when it survived.
		final int index = text.indexOf(GatekeeperPoint.POINT_SEPARATOR);
		if (index < 0)
			return colorize(data.getNameColor(), escape(text));

		return colorize(data.getNameColor(), escape(text.substring(0, index))) + colorize(data.getPointColor(), escape(text.substring(index)));
	}

	/**
	 * @param point : The {@link GatekeeperPoint} to reach, can be null.
	 * @param player : The {@link Player} used to test conditions.
	 * @param tabIndex : The index of the current {@link GatekeeperTab}, used to refresh the dialog on failure.
	 * @param areaIndex : The index of the current {@link GatekeeperArea}.
	 * @param page : The currently shown page index.
	 * @param name : The name to render, already shortened.
	 * @return The given name, turned into a teleport link - greyed and left plain if the {@link Player} can't use the point.
	 */
	private static String getPointLink(GatekeeperPoint point, Player player, int tabIndex, int areaIndex, int page, String name)
	{
		if (point == null)
			return "";

		final GatekeeperData data = GatekeeperData.getInstance();
		if (!point.isAvailableFor(player))
			return colorize(data.getDisabledColor(), escape(name));

		return "<a action=\"bypass -h Quest " + GatekeeperData.SCRIPT_NAME + " Tp " + tabIndex + " " + areaIndex + " " + page + " " + point.getId() + "\" msg=\"811;" + getPopupText(point, player) + "\">" + colorize(data.getNameColor(), escape(name)) + "</a>";
	}

	/**
	 * @param point : The {@link GatekeeperPoint} to render.
	 * @param player : The {@link Player} used to test conditions.
	 * @param tabIndex : The index of the current {@link GatekeeperTab}, used to refresh the dialog on failure.
	 * @param areaIndex : The index of the current {@link GatekeeperArea}, -1 when fired from the popular tab.
	 * @param page : The currently shown page index.
	 * @return The action cell content of a given {@link GatekeeperPoint}.
	 */
	private static String getActionText(GatekeeperPoint point, Player player, int tabIndex, int areaIndex, int page)
	{
		final GatekeeperData data = GatekeeperData.getInstance();

		if (!point.isAvailableFor(player))
			return colorize(data.getDisabledColor(), escape((point.getType() == GatekeeperPointType.NOBLE) ? data.getNobleLabel() : data.getLockedLabel()));

		return "<a action=\"bypass -h Quest " + GatekeeperData.SCRIPT_NAME + " Tp " + tabIndex + " " + areaIndex + " " + page + " " + point.getId() + "\" msg=\"811;" + getPopupText(point, player) + "\">" + escape(data.getGoLabel()) + "</a>";
	}

	/**
	 * The XML parser turns the &amp;lt; of a datapack text into a raw &lt;, which the client would then read as the start of a tag - swallowing the rest of the label.
	 * @param text : The datapack text to render.
	 * @return The given text, with its angle brackets turned back into entities the client renders as is.
	 */
	private static String escape(String text)
	{
		return (text.indexOf('<') < 0 && text.indexOf('>') < 0) ? text : text.replace("<", "&lt;").replace(">", "&gt;");
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
	 * Shorten a cell content which wouldn't fit its column, since a wrapped text makes the whole row taller than the others.<br>
	 * The cut falls back on the last word boundary, but only when it keeps most of the room - otherwise a "Talking Island Village" would end up as a bare "Talking...".
	 * @param text : The text to shorten.
	 * @param maxChars : The maximum amount of characters, 0 disabling the shortening.
	 * @return The given text, shortened and suffixed by the ellipsis when needed.
	 */
	private static String truncate(String text, int maxChars)
	{
		if (maxChars <= 0 || text.length() <= maxChars)
			return text;

		final String ellipsis = GatekeeperData.getInstance().getEllipsis();
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

	/**
	 * @param fileName : The optional HTM to retrieve on this script folder.
	 * @return The content of the given HTM, an empty {@link String} if it doesn't exist.
	 */
	private String getFragment(String fileName)
	{
		final String content = HtmCache.getInstance().getHtm("./data/html/script/" + getDescr() + "/" + getName() + "/" + fileName);
		return (content == null) ? "" : content;
	}

	/**
	 * Feed the generic variables of a given content, then send it to the {@link Player}.
	 * @param npc : The {@link Npc} used as dialog holder.
	 * @param player : The {@link Player} to send the dialog to.
	 * @param content : The HTM content to send.
	 */
	private static void sendHtml(Npc npc, Player player, String content)
	{
		final GatekeeperData data = GatekeeperData.getInstance();
		final String title = npc.getTitle();

		content = content.replace("%objectId%", String.valueOf(npc.getObjectId()));
		content = content.replace("%npcName%", npc.getName());
		content = content.replace("%npcTitle%", (title == null) ? "" : title);
		content = content.replace("%playerName%", player.getName());
		content = content.replace("%width%", String.valueOf(data.getWidth()));
		content = content.replace("%titleColor%", data.getTitleColor());

		final NpcHtmlMessage html = new NpcHtmlMessage(npc.getObjectId());
		html.setHtml(content);

		player.sendPacket(html);
		player.sendPacket(ActionFailed.STATIC_PACKET);
	}
}
