package net.sf.l2j.gameserver.scripting.script.teleport;

import java.util.List;
import java.util.StringTokenizer;

import net.sf.l2j.commons.lang.StringUtil;

import net.sf.l2j.gameserver.data.cache.HtmCache;
import net.sf.l2j.gameserver.data.manager.CastleManager;
import net.sf.l2j.gameserver.data.manager.GatekeeperStatsManager;
import net.sf.l2j.gameserver.data.xml.GatekeeperData;
import net.sf.l2j.gameserver.enums.GatekeeperPointType;
import net.sf.l2j.gameserver.enums.GatekeeperTabType;
import net.sf.l2j.gameserver.model.actor.Npc;
import net.sf.l2j.gameserver.model.actor.Player;
import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperArea;
import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperMenu;
import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperPoint;
import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperTab;
import net.sf.l2j.gameserver.model.itemcontainer.PcInventory;
import net.sf.l2j.gameserver.model.residence.castle.Castle;
import net.sf.l2j.gameserver.network.SystemMessageId;
import net.sf.l2j.gameserver.network.serverpackets.ActionFailed;
import net.sf.l2j.gameserver.network.serverpackets.NpcHtmlMessage;
import net.sf.l2j.gameserver.scripting.Quest;

/**
 * A fully datapack driven Gatekeeper.<br>
 * <br>
 * Npc ids, menu tabs, areas, teleport points and prices are described on data/xml/gatekeeper.xml, while the dialog layout is described on generic HTMs, located on this script folder. Teleport
 * counters are handled by {@link GatekeeperStatsManager}.
 * <ul>
 * <li>List &lt;tab&gt; &lt;page&gt; : shows the areas of a tab.</li>
 * <li>Area &lt;tab&gt; &lt;area&gt; &lt;page&gt; : shows the teleport points of an area.</li>
 * <li>Popular &lt;tab&gt; &lt;page&gt; : shows the most used teleport points of the menu.</li>
 * <li>Page &lt;tab&gt; &lt;file&gt; : shows an additional datapack HTM.</li>
 * <li>Tp &lt;tab&gt; &lt;area&gt; &lt;page&gt; &lt;point&gt; : teleports the Player, area being -1 when fired from the popular tab.</li>
 * </ul>
 */
public class GlobalGatekeeper extends Quest
{
	private static final int MENU_WIDTH = 290;
	private static final int MAX_SHOWN_PAGES = 10;


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
					if (areaIndex < 0)
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

		final List<GatekeeperArea> areas = tab.getAreas();
		final int perPage = GatekeeperData.getInstance().getRowsPerPage();
		final int pages = getPageCount(areas.size(), perPage);

		page = Math.min(Math.max(page, 0), pages - 1);

		final StringBuilder sb = new StringBuilder();
		sb.append("<table width=280>");

		for (int i = page * perPage; i < Math.min(areas.size(), (page + 1) * perPage); i++)
		{
			final GatekeeperArea area = areas.get(i);
			final GatekeeperPoint main = area.getMainPoint();

			StringUtil.append(sb, "<tr><td width=130><a action=\"bypass -h Quest ", getName(), " Area ", tab.getIndex(), " ", i, " 0\">", area.getName(), "</a></td><td width=100>", getPriceText(main, player), "</td><td width=50>", area.getCapital(), "</td></tr>");
		}
		sb.append("</table>");

		String content = getHtmlText("areas.htm");
		content = content.replace("%menu%", getMenu(menu, tab));
		content = content.replace("%list%", sb.toString());
		content = content.replace("%pages%", getPages("Quest " + getName() + " List " + tab.getIndex(), page, pages));
		content = content.replace("%pk%", (player.getKarma() > 0) ? getFragment("pk.htm") : "");

		sendHtml(npc, player, content);
	}

	private void showPoints(Npc npc, Player player, GatekeeperMenu menu, GatekeeperTab tab, GatekeeperArea area, int page)
	{
		if (tab == null || area == null)
			return;

		final List<GatekeeperPoint> points = area.getPoints();
		final int perPage = GatekeeperData.getInstance().getRowsPerPage();
		final int pages = getPageCount(points.size(), perPage);

		page = Math.min(Math.max(page, 0), pages - 1);

		final StringBuilder sb = new StringBuilder();
		sb.append("<table width=280>");

		for (int i = page * perPage; i < Math.min(points.size(), (page + 1) * perPage); i++)
		{
			final GatekeeperPoint point = points.get(i);

			StringUtil.append(sb, "<tr><td width=115>", getNameText(point, player), "</td><td width=65>", point.getPoint(), "</td><td width=55>", getPriceText(point, player), "</td><td width=45>", getActionText(point, player, tab.getIndex(), area.getIndex(), page), "</td></tr>");
		}
		sb.append("</table>");

		String content = getHtmlText("locations.htm");
		content = content.replace("%menu%", getMenu(menu, tab));
		content = content.replace("%area%", area.getName());
		content = content.replace("%locations%", sb.toString());
		content = content.replace("%pages%", getPages("Quest " + getName() + " Area " + tab.getIndex() + " " + area.getIndex(), page, pages));
		content = content.replace("%back%", "Quest " + getName() + " List " + tab.getIndex() + " 0");

		sendHtml(npc, player, content);
	}

	private void showPopular(Npc npc, Player player, GatekeeperMenu menu, GatekeeperTab tab, int page)
	{
		if (tab == null)
			return;

		final GatekeeperData data = GatekeeperData.getInstance();
		final GatekeeperStatsManager stats = GatekeeperStatsManager.getInstance();

		// Keep the points of this menu only, above the minimum amount of uses, up to the configured limit.
		final List<GatekeeperPoint> points = stats.getRanking().stream().filter(id -> stats.getCount(id) >= data.getPopularMinCount()).map(id -> menu.getPoint(id)).filter(point -> point != null).limit(data.getPopularLimit()).toList();

		final int perPage = data.getRowsPerPage();
		final int pages = getPageCount(points.size(), perPage);

		page = Math.min(Math.max(page, 0), pages - 1);

		final StringBuilder sb = new StringBuilder();
		sb.append("<table width=280>");

		if (points.isEmpty())
			sb.append("<tr><td><font color=\"707070\">" + data.getEmptyLabel() + "</font></td></tr>");

		for (int i = page * perPage; i < Math.min(points.size(), (page + 1) * perPage); i++)
		{
			final GatekeeperPoint point = points.get(i);

			StringUtil.append(sb, "<tr><td width=105>", getNameText(point, player), "</td><td width=55>", point.getPoint(), "</td><td width=35>", stats.getCount(point.getId()), "</td><td width=45>", getPriceText(point, player), "</td><td width=40>", getActionText(point, player, tab.getIndex(), -1, page), "</td></tr>");
		}
		sb.append("</table>");

		String content = getHtmlText("popular.htm");
		content = content.replace("%menu%", getMenu(menu, tab));
		content = content.replace("%locations%", sb.toString());
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
	private static boolean teleport(Player player, GatekeeperMenu menu, int pointId)
	{
		// The point must be reachable from this Npc menu.
		final GatekeeperPoint point = menu.getPoint(pointId);
		if (point == null)
			return false;

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

		player.teleportTo(point, 20);

		GatekeeperStatsManager.getInstance().increase(point.getId());

		return true;
	}

	/**
	 * @param menu : The {@link GatekeeperMenu} to render.
	 * @param active : The currently shown {@link GatekeeperTab}.
	 * @return The set of &lt;td&gt; used as menu bar, replacing the %menu% variable.
	 */
	private static String getMenu(GatekeeperMenu menu, GatekeeperTab active)
	{
		final List<GatekeeperTab> tabs = menu.getTabs();
		if (tabs.isEmpty())
			return "";

		final int width = Math.max(MENU_WIDTH / tabs.size(), 1);

		final StringBuilder sb = new StringBuilder();
		for (GatekeeperTab tab : tabs)
			StringUtil.append(sb, "<td width=", width, " align=center><a action=\"bypass -h ", tab.getBypass(), "\"><font color=\"", (tab == active) ? "LEVEL" : tab.getColor(), "\">", tab.getName(), "</font></a></td>");

		return sb.toString();
	}

	/**
	 * @param bypass : The bypass to fire, the page index being appended to it.
	 * @param page : The currently shown page index.
	 * @param pages : The total amount of pages.
	 * @return The page selector, replacing the %pages% variable - an empty {@link String} if a single page exists.
	 */
	private static String getPages(String bypass, int page, int pages)
	{
		if (pages <= 1)
			return "";

		// Center the shown window of pages on the current page.
		int first = Math.max(0, page - MAX_SHOWN_PAGES / 2);
		final int last = Math.min(pages, first + MAX_SHOWN_PAGES);
		first = Math.max(0, last - MAX_SHOWN_PAGES);

		final StringBuilder sb = new StringBuilder();
		sb.append("<center>");

		if (page > 0)
			StringUtil.append(sb, "<a action=\"bypass -h ", bypass, " ", page - 1, "\">&lt;&lt;</a>&nbsp;");

		for (int i = first; i < last; i++)
		{
			if (i == page)
				StringUtil.append(sb, "<font color=\"LEVEL\">", i + 1, "</font>&nbsp;");
			else
				StringUtil.append(sb, "<a action=\"bypass -h ", bypass, " ", i, "\">", i + 1, "</a>&nbsp;");
		}

		if (page < pages - 1)
			StringUtil.append(sb, "<a action=\"bypass -h ", bypass, " ", page + 1, "\">&gt;&gt;</a>");

		sb.append("</center>");

		return sb.toString();
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

		final int price = point.getCalculatedPrice(player);
		if (price <= 0)
			return "<font color=\"00FF00\">" + GatekeeperData.getInstance().getFreeLabel() + "</font>";

		return (point.getPriceId() == PcInventory.ADENA_ID) ? StringUtil.formatNumber(price) : StringUtil.formatNumber(price) + " &#" + point.getPriceId() + ";";
	}

	/**
	 * @param point : The {@link GatekeeperPoint} to render.
	 * @param player : The {@link Player} used to test conditions.
	 * @return The name cell content of a given {@link GatekeeperPoint}, greyed if the {@link Player} can't use it.
	 */
	private static String getNameText(GatekeeperPoint point, Player player)
	{
		return (point.isAvailableFor(player)) ? point.getName() : "<font color=\"707070\">" + point.getName() + "</font>";
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
			return "<font color=\"707070\">" + ((point.getType() == GatekeeperPointType.NOBLE) ? data.getNobleLabel() : data.getLockedLabel()) + "</font>";

		return "<a action=\"bypass -h Quest " + GatekeeperData.SCRIPT_NAME + " Tp " + tabIndex + " " + areaIndex + " " + page + " " + point.getId() + "\" msg=\"811;" + point.getFullName() + "\">" + data.getGoLabel() + "</a>";
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
		final String title = npc.getTitle();

		content = content.replace("%objectId%", String.valueOf(npc.getObjectId()));
		content = content.replace("%npcName%", npc.getName());
		content = content.replace("%npcTitle%", (title == null) ? "" : title);
		content = content.replace("%playerName%", player.getName());

		final NpcHtmlMessage html = new NpcHtmlMessage(npc.getObjectId());
		html.setHtml(content);

		player.sendPacket(html);
		player.sendPacket(ActionFailed.STATIC_PACKET);
	}
}
