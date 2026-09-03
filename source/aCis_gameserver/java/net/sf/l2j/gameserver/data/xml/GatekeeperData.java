package net.sf.l2j.gameserver.data.xml;

import java.nio.file.Path;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import net.sf.l2j.commons.data.xml.IXmlReader;

import net.sf.l2j.Config;
import net.sf.l2j.gameserver.enums.GatekeeperPointType;
import net.sf.l2j.gameserver.enums.GatekeeperTabType;
import net.sf.l2j.gameserver.enums.GatekeeperTerritory;
import net.sf.l2j.gameserver.model.actor.Player;
import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperArea;
import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperColumn;
import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperMenu;
import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperPoint;
import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperTab;
import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperTable;
import net.sf.l2j.gameserver.taskmanager.GameTimeTaskManager;

import org.w3c.dom.Document;
import org.w3c.dom.NamedNodeMap;
import org.w3c.dom.Node;

/**
 * This class loads and stores {@link GatekeeperMenu}s, used by the GlobalGatekeeper script.<br>
 * <br>
 * Everything the player sees is datapack driven, on data/xml/gatekeeper.xml : the content (Npc ids, menu tabs, areas, teleport points and their prices), but also the whole appearance - column
 * widths and captions (&lt;layout&gt;), colors (&lt;colors&gt;) and labels (&lt;labels&gt;).<br>
 * <br>
 * The behavior and the economy are server side instead, on config/mods/gatekeeper.properties. The database only retains teleport counters, handled by
 * {@link net.sf.l2j.gameserver.data.manager.GatekeeperStatsManager}.
 */
public class GatekeeperData implements IXmlReader
{
	/** The script name, used to generate internal bypasses. Must match the GlobalGatekeeper class name. */
	public static final String SCRIPT_NAME = "GlobalGatekeeper";

	/** Id of the &lt;table&gt; describing the areas list page. */
	public static final String AREAS_TABLE = "areas";
	/** Id of the &lt;table&gt; describing the teleport points list page. */
	public static final String POINTS_TABLE = "points";
	/** Id of the &lt;table&gt; describing the popular points list page. */
	public static final String POPULAR_TABLE = "popular";

	/** Fallback returned by {@link #getTable(String)}, so an unknown table id doesn't break the whole dialog. */
	private static final GatekeeperTable EMPTY_TABLE = new GatekeeperTable("?", 0);

	private final Map<Integer, GatekeeperMenu> _menus = new HashMap<>();
	private final Map<Integer, GatekeeperMenu> _npcs = new HashMap<>();
	private final Map<Integer, GatekeeperPoint> _points = new HashMap<>();
	private final Map<String, GatekeeperTable> _tables = new LinkedHashMap<>();

	private int _width;
	private int _rowHeight;
	private int _headerHeight;
	private int _tabHeight;
	private int _tabColumns;
	private int _maxPages;
	private int _pageHeight;
	private String _ellipsis;

	private String _rowColor;
	private String _altRowColor;
	private String _headerColor;
	private String _headerTextColor;
	private String _titleColor;
	private String _tabBarColor;
	private String _tabColor;
	private String _activeTabColor;
	private String _nameColor;
	private String _pointColor;
	private String _priceColor;
	private String _freeColor;
	private String _disabledColor;
	private String _pageColor;
	private String _activePageColor;
	private String _territoryColor;

	private String _nobleLabel;
	private String _lockedLabel;
	private String _freeLabel;
	private String _emptyLabel;
	private String _backLabel;
	private String _prevPageLabel;
	private String _nextPageLabel;
	private String _listLabel;
	private String _popupSeparator;
	private int _currencyChars;
	private boolean _isCurrencyLowerCase;

	protected GatekeeperData()
	{
		load();
	}

	@Override
	public void load()
	{
		setDefaultLayout();
		setDefaultColors();
		setDefaultLabels();

		// IXmlReader only catches the parser exceptions ; without this, a single malformed attribute would abort the whole server startup.
		try
		{
			parseFile("./data/xml/gatekeeper.xml");
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't fully read gatekeeper.xml ; the gatekeeper runs on whatever has been read so far.", e);
		}

		LOGGER.info("Loaded {} gatekeeper menus, {} teleport points for {} npcs.", _menus.size(), _points.size(), _npcs.size());
	}

	@Override
	public void parseDocument(Document doc, Path path)
	{
		forEach(doc, "list", listNode ->
		{
			forEach(listNode, "layout", layoutNode ->
			{
				final NamedNodeMap attrs = layoutNode.getAttributes();

				_width = Math.max(1, parseInt(attrs, "width", _width));
				_rowHeight = Math.max(1, parseInt(attrs, "rowHeight", _rowHeight));
				_headerHeight = Math.max(1, parseInt(attrs, "headerHeight", _headerHeight));
				_tabHeight = Math.max(1, parseInt(attrs, "tabHeight", _tabHeight));
				_tabColumns = Math.max(1, parseInt(attrs, "tabColumns", _tabColumns));
				_maxPages = Math.max(1, parseInt(attrs, "maxPages", _maxPages));
				_pageHeight = Math.max(0, parseInt(attrs, "pageHeight", _pageHeight));
				_ellipsis = parseString(attrs, "ellipsis", _ellipsis);

				forEach(layoutNode, "table", tableNode ->
				{
					final NamedNodeMap tableAttrs = tableNode.getAttributes();
					final String tableId = parseToken(tableAttrs, "id", "");
					if (tableId.isEmpty())
					{
						LOGGER.warn("A gatekeeper layout table is missing its id.");
						return;
					}

					final GatekeeperTable table = new GatekeeperTable(tableId, parseInt(tableAttrs, "overhead", 0));

					forEach(tableNode, "column", columnNode ->
					{
						final NamedNodeMap columnAttrs = columnNode.getAttributes();
						final String columnId = parseToken(columnAttrs, "id", "");
						if (columnId.isEmpty())
						{
							LOGGER.warn("A column of the gatekeeper layout table '{}' is missing its id.", tableId);
							return;
						}

						table.addColumn(new GatekeeperColumn(columnId, parseString(columnAttrs, "header", ""), parseInt(columnAttrs, "width", 1), parseInt(columnAttrs, "maxChars", 0), parseToken(columnAttrs, "align", "left")));
					});

					if (table.getColumns().isEmpty())
					{
						LOGGER.warn("The gatekeeper layout table '{}' doesn't hold any column ; the default one is kept.", tableId);
						return;
					}

					if (table.getWidth() != _width)
						LOGGER.warn("The columns of the gatekeeper layout table '{}' sum up to {} instead of the layout width {} ; the rows won't be aligned.", tableId, table.getWidth(), _width);

					_tables.put(tableId, table);
				});
			});

			forEach(listNode, "colors", colorsNode ->
			{
				final NamedNodeMap attrs = colorsNode.getAttributes();

				_rowColor = parseToken(attrs, "row", _rowColor);
				_altRowColor = parseToken(attrs, "altRow", _altRowColor);
				_headerColor = parseToken(attrs, "header", _headerColor);
				_headerTextColor = parseToken(attrs, "headerText", _headerTextColor);
				_titleColor = parseToken(attrs, "title", _titleColor);
				_tabBarColor = parseToken(attrs, "tabBar", _tabBarColor);
				_tabColor = parseToken(attrs, "tab", _tabColor);
				_activeTabColor = parseToken(attrs, "activeTab", _activeTabColor);
				_nameColor = parseToken(attrs, "name", _nameColor);
				_pointColor = parseToken(attrs, "point", _pointColor);
				_priceColor = parseToken(attrs, "price", _priceColor);
				_freeColor = parseToken(attrs, "free", _freeColor);
				_disabledColor = parseToken(attrs, "disabled", _disabledColor);
				_pageColor = parseToken(attrs, "page", _pageColor);
				_activePageColor = parseToken(attrs, "activePage", _activePageColor);
				_territoryColor = parseToken(attrs, "territory", _territoryColor);
			});

			forEach(listNode, "labels", labelsNode ->
			{
				final NamedNodeMap attrs = labelsNode.getAttributes();

				_nobleLabel = parseString(attrs, "noble", _nobleLabel);
				_lockedLabel = parseString(attrs, "locked", _lockedLabel);
				_freeLabel = parseString(attrs, "free", _freeLabel);
				_emptyLabel = parseString(attrs, "empty", _emptyLabel);
				_backLabel = parseString(attrs, "back", _backLabel);
				_prevPageLabel = parseString(attrs, "prevPage", _prevPageLabel);
				_nextPageLabel = parseString(attrs, "nextPage", _nextPageLabel);
				_listLabel = parseString(attrs, "list", _listLabel);
				_popupSeparator = parseString(attrs, "popupSeparator", _popupSeparator);
				_currencyChars = Math.max(0, parseInt(attrs, "currencyChars", _currencyChars));
				_isCurrencyLowerCase = parseBool(attrs, "currencyLowerCase", _isCurrencyLowerCase);
			});

			forEach(listNode, "menu", menuNode -> parseMenu(menuNode));

			forEach(listNode, "npc", npcNode ->
			{
				final NamedNodeMap attrs = npcNode.getAttributes();
				final int npcId = parseInt(attrs, "id", 0);
				final int menuId = parseInt(attrs, "menu", 0);

				final GatekeeperMenu menu = _menus.get(menuId);
				if (menu == null)
				{
					LOGGER.warn("Npc id {} refers to the missing gatekeeper menu id {}.", npcId, menuId);
					return;
				}

				if (_npcs.put(npcId, menu) != null)
					LOGGER.warn("Npc id {} is registered more than once ; the last menu is used.", npcId);
			});
		});
	}

	private void parseMenu(Node menuNode)
	{
		final NamedNodeMap menuAttrs = menuNode.getAttributes();
		final int menuId = parseInt(menuAttrs, "id", 0);
		final int menuPriceId = parseInt(menuAttrs, "priceId", Config.GATEKEEPER_DEFAULT_PRICE_ID);
		final int menuPrice = parseInt(menuAttrs, "price", Config.GATEKEEPER_DEFAULT_PRICE);
		final int menuNoblePrice = parseInt(menuAttrs, "noblePrice", Config.GATEKEEPER_DEFAULT_NOBLE_PRICE);

		final GatekeeperMenu menu = new GatekeeperMenu(menuId);
		final AtomicInteger tabIndex = new AtomicInteger();

		forEach(menuNode, "item", itemNode ->
		{
			final NamedNodeMap itemAttrs = itemNode.getAttributes();
			final String name = parseString(itemAttrs, "name", "?");
			final String color = parseToken(itemAttrs, "color", _tabColor);
			final String bypass = parseString(itemAttrs, "bypass");
			final int tabPriceId = parseInt(itemAttrs, "priceId", menuPriceId);
			final int tabPrice = parseInt(itemAttrs, "price", menuPrice);
			final int tabNoblePrice = parseInt(itemAttrs, "noblePrice", menuNoblePrice);

			String page = parseString(itemAttrs, "page");
			if (page != null && !isValidPage(page))
			{
				LOGGER.warn("Gatekeeper menu id {} holds the invalid page '{}'.", menuId, page);
				page = null;
			}

			final GatekeeperTabType type = findTabType(itemNode, itemAttrs, bypass, page);
			if (type == null)
			{
				LOGGER.warn("Gatekeeper menu id {} holds the tab '{}' without any content.", menuId, name);
				return;
			}

			String intro = parseToken(itemAttrs, "intro", null);
			if (intro != null && !isValidPage(intro))
			{
				LOGGER.warn("Gatekeeper menu id {} holds the invalid intro '{}'.", menuId, intro);
				intro = null;
			}

			final int index = tabIndex.getAndIncrement();
			final GatekeeperTab tab = new GatekeeperTab(index, name, color, type, generateBypass(type, index, bypass, page), page, intro, parseInt(itemAttrs, "introHeight", 0));

			if (type == GatekeeperTabType.AREAS)
			{
				final AtomicInteger areaIndex = new AtomicInteger();

				// The children are walked in document order, so an area and a standalone point can be freely interleaved on the very same page.
				for (Node child = itemNode.getFirstChild(); child != null; child = child.getNextSibling())
				{
					final String childName = child.getNodeName();

					if ("area".equals(childName))
					{
						final NamedNodeMap areaAttrs = child.getAttributes();
						final String areaName = parseString(areaAttrs, "name", "?");
						final int areaPriceId = parseInt(areaAttrs, "priceId", tabPriceId);
						final int areaPrice = parseInt(areaAttrs, "price", tabPrice);
						final int areaNoblePrice = parseInt(areaAttrs, "noblePrice", tabNoblePrice);

						final GatekeeperArea area = new GatekeeperArea(areaIndex.get(), areaName, parseString(areaAttrs, "capital", ""), false);

						forEach(child, "loc", locNode ->
						{
							final GatekeeperPoint point = parsePoint(locNode, areaName, areaPriceId, areaPrice, areaNoblePrice);
							if (point == null)
								return;

							area.addPoint(point);
							menu.addPoint(point);
						});

						if (area.getPoints().isEmpty())
						{
							LOGGER.warn("Gatekeeper area '{}' of menu id {} doesn't hold any valid point.", areaName, menuId);
							continue;
						}

						areaIndex.incrementAndGet();
						tab.addArea(area);
					}
					else if ("loc".equals(childName))
					{
						// A point written next to the areas becomes a row teleporting right away, instead of leading to a sub list.
						final GatekeeperPoint point = parsePoint(child, name, tabPriceId, tabPrice, tabNoblePrice);
						if (point == null)
							continue;

						final GatekeeperArea area = new GatekeeperArea(areaIndex.getAndIncrement(), point.getFullName(), parseString(child.getAttributes(), "capital", ""), true);
						area.addPoint(point);

						menu.addPoint(point);
						tab.addArea(area);
					}
				}
			}
			else if (type == GatekeeperTabType.POINTS)
			{
				// The tab directly holds points ; wrap them into a single implicit area, named after the tab.
				final GatekeeperArea area = new GatekeeperArea(0, name, parseString(itemAttrs, "capital", ""), false);

				forEach(itemNode, "loc", locNode ->
				{
					final GatekeeperPoint point = parsePoint(locNode, name, tabPriceId, tabPrice, tabNoblePrice);
					if (point == null)
						return;

					area.addPoint(point);
					menu.addPoint(point);
				});

				if (area.getPoints().isEmpty())
				{
					LOGGER.warn("Gatekeeper tab '{}' of menu id {} doesn't hold any valid point.", name, menuId);
					return;
				}

				tab.addArea(area);
			}

			menu.addTab(tab);
		});

		if (menu.getTabs().isEmpty())
		{
			LOGGER.warn("Gatekeeper menu id {} doesn't hold any valid tab.", menuId);
			return;
		}

		_menus.put(menuId, menu);
	}

	private GatekeeperPoint parsePoint(Node locNode, String areaName, int areaPriceId, int areaPrice, int areaNoblePrice)
	{
		final NamedNodeMap attrs = locNode.getAttributes();
		final int id = parseInt(attrs, "id", -1);
		if (id < 0)
		{
			LOGGER.warn("A gatekeeper point of the area '{}' is missing its id.", areaName);
			return null;
		}

		// Noblesse points own their own default price, since they are usually free on retail.
		final GatekeeperPointType type = parseEnum(attrs, GatekeeperPointType.class, "type", GatekeeperPointType.STANDARD);
		final int defaultPrice = (type == GatekeeperPointType.NOBLE) ? areaNoblePrice : areaPrice;
		final GatekeeperTerritory territory = parseEnum(attrs, GatekeeperTerritory.class, "territory", GatekeeperTerritory.FIELDS);
		final int[] mobLevels = parseMobLevels(attrs, areaName);

		final GatekeeperPoint point = new GatekeeperPoint(id, parseString(attrs, "name", areaName), parseString(attrs, "point", ""), type, territory, parseInt(attrs, "priceId", areaPriceId), Math.max(-1, parseInt(attrs, "price", defaultPrice)), parseInt(attrs, "castleId", 0), parseInt(attrs, "minLevel", 1), parseInt(attrs, "maxLevel", 127), mobLevels[0], mobLevels[1], parseInt(attrs, "x", 0), parseInt(attrs, "y", 0), parseInt(attrs, "z", 0));

		final GatekeeperPoint existing = _points.put(id, point);
		if (existing != null)
			LOGGER.warn("Gatekeeper point id {} is used more than once ; teleport counters will be shared.", id);

		return point;
	}

	/**
	 * A tolerant reader of the "lvl" attribute, holding a single value ("47") or a range ("20-25") of monster levels.
	 * @param attrs : The attributes to read.
	 * @param areaName : The area name, only used to log a clear warning.
	 * @return A {min, max} pair, both -1 when the attribute is missing or malformed.
	 */
	private static int[] parseMobLevels(NamedNodeMap attrs, String areaName)
	{
		final String value = parseTrimmed(attrs, "lvl");
		if (value == null)
			return new int[] { -1, -1 };

		try
		{
			final int dash = value.indexOf('-');
			if (dash < 0)
			{
				final int level = Integer.parseInt(value);
				return new int[] { level, level };
			}

			return new int[] { Integer.parseInt(value.substring(0, dash)), Integer.parseInt(value.substring(dash + 1)) };
		}
		catch (NumberFormatException e)
		{
			LOGGER.warn("The gatekeeper point of the area '{}' holds an invalid lvl attribute '{}'.", areaName, value);
			return new int[] { -1, -1 };
		}
	}

	/**
	 * @param itemNode : The tab {@link Node} to test.
	 * @param attrs : The tab attributes.
	 * @param bypass : The XML defined bypass, if any.
	 * @param page : The XML defined page, if any.
	 * @return The {@link GatekeeperTabType} of the tab, or null if the tab holds no content at all.
	 */
	private static GatekeeperTabType findTabType(Node itemNode, NamedNodeMap attrs, String bypass, String page)
	{
		if (hasChild(itemNode, "area"))
			return GatekeeperTabType.AREAS;

		if (hasChild(itemNode, "loc"))
			return GatekeeperTabType.POINTS;

		if (page != null)
			return GatekeeperTabType.PAGE;

		final Node typeNode = attrs.getNamedItem("type");
		if (typeNode != null && "popular".equalsIgnoreCase(typeNode.getNodeValue()))
			return GatekeeperTabType.POPULAR;

		// Support the internal command written as a regular bypass, as done on the areas holder tabs.
		if (bypass != null)
		{
			final String prefix = "Quest " + SCRIPT_NAME + " ";
			if (bypass.startsWith(prefix))
				return (bypass.substring(prefix.length()).startsWith("Popular")) ? GatekeeperTabType.POPULAR : null;

			return GatekeeperTabType.EXTERNAL;
		}

		return null;
	}

	/**
	 * Internal tabs own a generated bypass, in order to always point on their own index - whatever the XML defined bypass is.
	 * @param type : The {@link GatekeeperTabType} of the tab.
	 * @param index : The index of the tab, within its {@link GatekeeperMenu}.
	 * @param bypass : The XML defined bypass, if any.
	 * @param page : The XML defined page, if any.
	 * @return The bypass to fire when the tab is clicked.
	 */
	private static String generateBypass(GatekeeperTabType type, int index, String bypass, String page)
	{
		switch (type)
		{
			case AREAS:
				return "Quest " + SCRIPT_NAME + " List " + index + " 0";

			case POINTS:
				return "Quest " + SCRIPT_NAME + " Area " + index + " 0 0";

			case POPULAR:
				return "Quest " + SCRIPT_NAME + " Popular " + index + " 0";

			case PAGE:
				return "Quest " + SCRIPT_NAME + " Page " + index + " " + page;

			default:
				return bypass;
		}
	}

	private static boolean hasChild(Node node, String name)
	{
		for (Node child = node.getFirstChild(); child != null; child = child.getNextSibling())
		{
			if (name.equals(child.getNodeName()))
				return true;
		}
		return false;
	}

	/**
	 * A tolerant {@link IXmlReader#parseInteger(NamedNodeMap, String, Integer)}, since this file is meant to be hand tuned : a stray space around a value would otherwise throw, and take the whole
	 * server startup down with it.
	 * @param attrs : The attributes to read.
	 * @param name : The attribute name to read.
	 * @param defaultValue : The value returned when the attribute is missing, empty or not a number.
	 * @return The parsed value.
	 */
	private int parseInt(NamedNodeMap attrs, String name, int defaultValue)
	{
		final String value = parseTrimmed(attrs, name);
		if (value == null)
			return defaultValue;

		try
		{
			return Integer.parseInt(value);
		}
		catch (NumberFormatException e)
		{
			LOGGER.warn("The gatekeeper attribute '{}' holds '{}', which isn't a number ; {} is used instead.", name, value, defaultValue);
			return defaultValue;
		}
	}

	/**
	 * A tolerant {@link IXmlReader#parseBoolean(NamedNodeMap, String, Boolean)}, which doesn't silently read a spaced " true" as false.
	 * @param attrs : The attributes to read.
	 * @param name : The attribute name to read.
	 * @param defaultValue : The value returned when the attribute is missing or empty.
	 * @return The parsed value.
	 */
	private static boolean parseBool(NamedNodeMap attrs, String name, boolean defaultValue)
	{
		final String value = parseTrimmed(attrs, name);

		return (value == null) ? defaultValue : Boolean.parseBoolean(value);
	}

	/**
	 * @param attrs : The attributes to read.
	 * @param name : The attribute name to read.
	 * @return The trimmed value of the given attribute, null if it is missing or blank.
	 */
	/**
	 * Same as {@link IXmlReader#parseString(NamedNodeMap, String, String)}, minus the surrounding spaces - which would leak into a color or an align attribute, and break the generated tag.
	 * @param attrs : The attributes to read.
	 * @param name : The attribute name to read.
	 * @param defaultValue : The value returned when the attribute is missing. An explicitly empty attribute stays empty.
	 * @return The trimmed value of the given attribute.
	 */
	private static String parseToken(NamedNodeMap attrs, String name, String defaultValue)
	{
		final Node node = attrs.getNamedItem(name);

		return (node == null) ? defaultValue : node.getNodeValue().trim();
	}

	/**
	 * @param attrs : The attributes to read.
	 * @param name : The attribute name to read.
	 * @return The trimmed value of the given attribute, null if it is missing or blank.
	 */
	private static String parseTrimmed(NamedNodeMap attrs, String name)
	{
		final Node node = attrs.getNamedItem(name);
		if (node == null)
			return null;

		final String value = node.getNodeValue().trim();

		return (value.isEmpty()) ? null : value;
	}

	/**
	 * @param page : The filename to test.
	 * @return True if the filename is a plain HTM filename, without any path separator.
	 */
	public static boolean isValidPage(String page)
	{
		if (page.isEmpty() || page.contains("/") || page.contains("\\") || page.contains("..") || page.contains(" "))
			return false;

		return page.endsWith(".htm") || page.endsWith(".html");
	}

	/**
	 * Set the built-in layout, used as long as the XML doesn't override it. Every width sums up to {@link #getWidth()}, which is mandatory to keep the columns aligned.
	 */
	private void setDefaultLayout()
	{
		_width = 280;
		_rowHeight = 18;
		_headerHeight = 18;
		_tabHeight = 18;
		_tabColumns = 4;
		_maxPages = 10;
		_pageHeight = 390;
		_ellipsis = "...";

		_tables.clear();

		final GatekeeperTable areas = new GatekeeperTable(AREAS_TABLE, 195);
		areas.addColumn(new GatekeeperColumn("name", "Name", 106, 16, "left"));
		areas.addColumn(new GatekeeperColumn("price", "Price", 92, 0, "left"));
		areas.addColumn(new GatekeeperColumn("capital", "Capital", 82, 13, "left"));
		_tables.put(areas.getId(), areas);

		final GatekeeperTable points = new GatekeeperTable(POINTS_TABLE, 96);
		points.addColumn(new GatekeeperColumn("name", "Location", 150, 25, "left"));
		points.addColumn(new GatekeeperColumn("price", "Price", 92, 0, "left"));
		points.addColumn(new GatekeeperColumn("action", "", 38, 0, "right"));
		_tables.put(points.getId(), points);

		final GatekeeperTable popular = new GatekeeperTable(POPULAR_TABLE, 96);
		popular.addColumn(new GatekeeperColumn("name", "Location", 150, 25, "left"));
		popular.addColumn(new GatekeeperColumn("price", "Price", 92, 0, "left"));
		popular.addColumn(new GatekeeperColumn("action", "", 38, 0, "right"));
		_tables.put(popular.getId(), popular);
	}

	/**
	 * Set the built-in colors, used as long as the XML doesn't override them. An empty {@link String} disables the related tag - a transparent background, or a raw text without any font.
	 */
	private void setDefaultColors()
	{
		_rowColor = "000000";
		_altRowColor = "";
		_headerColor = "000000";
		_headerTextColor = "9F9F9F";
		_titleColor = "LEVEL";
		_tabBarColor = "000000";
		_tabColor = "FFFFFF";
		_activeTabColor = "LEVEL";
		_nameColor = "";
		_pointColor = "8F8F8F";
		_priceColor = "LEVEL";
		_freeColor = "00FF00";
		_disabledColor = "707070";
		_pageColor = "";
		_activePageColor = "LEVEL";
		_territoryColor = "FFFFFF";
	}

	private void setDefaultLabels()
	{
		_nobleLabel = "noble";
		_lockedLabel = "-";
		_freeLabel = "0";
		_emptyLabel = "-";
		_backLabel = "<< back";
		_prevPageLabel = "<<";
		_nextPageLabel = ">>";
		_listLabel = "List";
		_popupSeparator = " -- ";
		_currencyChars = 0;
		_isCurrencyLowerCase = false;
	}

	public void reload()
	{
		_menus.clear();
		_npcs.clear();
		_points.clear();

		load();
	}

	/**
	 * @param npcId : The Npc id to test.
	 * @return The {@link GatekeeperMenu} associated to the given Npc id, or null if the Npc isn't a global gatekeeper.
	 */
	public GatekeeperMenu getMenuByNpcId(int npcId)
	{
		return _npcs.get(npcId);
	}

	public GatekeeperMenu getMenu(int menuId)
	{
		return _menus.get(menuId);
	}

	public int[] getNpcIds()
	{
		return _npcs.keySet().stream().mapToInt(Integer::intValue).toArray();
	}

	/**
	 * @param id : The {@link GatekeeperPoint} id to retrieve.
	 * @return The {@link GatekeeperPoint} matching the given id, whatever the {@link GatekeeperMenu} holding it.
	 */
	public GatekeeperPoint getPoint(int id)
	{
		return _points.get(id);
	}

	public Map<Integer, GatekeeperPoint> getPoints()
	{
		return Collections.unmodifiableMap(_points);
	}

	public int getRowsPerPage()
	{
		return Config.GATEKEEPER_ROWS_PER_PAGE;
	}

	/**
	 * @return The casting time, in milliseconds, of the teleport animation played before the actual teleport. 0 disables the animation.
	 */
	public int getTeleportDelay()
	{
		return Config.GATEKEEPER_TELEPORT_DELAY;
	}

	public int getPopularLimit()
	{
		return Config.GATEKEEPER_POPULAR_LIMIT;
	}

	public int getPopularMinCount()
	{
		return Config.GATEKEEPER_POPULAR_MIN_COUNT;
	}

	/**
	 * Compute the price to pay for a given {@link GatekeeperPoint}.<br>
	 * <br>
	 * The base price is either the one set on the XML, or - when unset - the one derived from the distance between the {@link Player} and the point. That base is then affected by the level, the
	 * karma and the day/night rates. Every single modifier can be individually disabled from config/mods/gatekeeper.properties.
	 * @param player : The {@link Player} to test.
	 * @param point : The {@link GatekeeperPoint} to reach.
	 * @return The amount of {@link GatekeeperPoint#getPriceId()} items to pay.
	 */
	public int getCalculatedPrice(Player player, GatekeeperPoint point)
	{
		if (Config.FREE_TELEPORT)
			return 0;

		final int fixedPrice = point.getPrice();

		// The whole dynamic pricing is disabled ; only XML defined prices are used.
		if (!Config.GATEKEEPER_PRICING_ENABLED)
			return Math.max(0, fixedPrice);

		double price = (fixedPrice >= 0) ? fixedPrice : getDistancePrice(player, point);
		if (price <= 0)
			return 0;

		if (Config.GATEKEEPER_LEVEL_PRICE_ENABLED)
			price *= getLevelPriceRate(player.getStatus().getLevel());

		if (Config.GATEKEEPER_KARMA_PRICE_ENABLED)
			price *= getKarmaPriceRate(player.getKarma());

		if (Config.GATEKEEPER_NIGHT_PRICE_ENABLED && GameTimeTaskManager.getInstance().isNight())
			price *= Config.GATEKEEPER_NIGHT_PRICE_RATE;

		// Round the result, but never turn a paying teleport into a free one.
		return (int) Math.max(1, Math.min(Math.round(price / Config.GATEKEEPER_PRICE_ROUNDING) * (long) Config.GATEKEEPER_PRICE_ROUNDING, Integer.MAX_VALUE));
	}

	/**
	 * The ratio isn't capped at RefDistance, otherwise every point of a remote area would end up sharing the very same price.<br>
	 * Only CapPrice bounds the result, and it is meant to be high enough to rarely trigger.
	 * @param player : The {@link Player} used as starting point.
	 * @param point : The {@link GatekeeperPoint} to reach.
	 * @return The base price of the teleport, derived from the 2D distance : NearPrice on the spot, FarPrice at RefDistance, growing beyond.
	 */
	private static double getDistancePrice(Player player, GatekeeperPoint point)
	{
		if (!Config.GATEKEEPER_DISTANCE_PRICE_ENABLED)
			return 0;

		final double ratio = point.distance2D(player.getX(), player.getY()) / Config.GATEKEEPER_REF_DISTANCE;
		final double price = Config.GATEKEEPER_NEAR_PRICE + (Config.GATEKEEPER_FAR_PRICE - Config.GATEKEEPER_NEAR_PRICE) * Math.pow(ratio, Config.GATEKEEPER_DISTANCE_CURVE);

		return (Config.GATEKEEPER_CAP_PRICE > 0) ? Math.min(price, Config.GATEKEEPER_CAP_PRICE) : price;
	}

	/**
	 * @param level : The level of the {@link Player}.
	 * @return The level rate, from LevelPriceMinRate at LevelPriceFrom up to 1 at LevelPriceTo.
	 */
	private static double getLevelPriceRate(int level)
	{
		if (Config.GATEKEEPER_LEVEL_PRICE_TO <= Config.GATEKEEPER_LEVEL_PRICE_FROM)
			return 1;

		final double ratio = Math.min(1, Math.max(0, (double) (level - Config.GATEKEEPER_LEVEL_PRICE_FROM) / (Config.GATEKEEPER_LEVEL_PRICE_TO - Config.GATEKEEPER_LEVEL_PRICE_FROM)));

		return Config.GATEKEEPER_LEVEL_PRICE_MIN_RATE + (1 - Config.GATEKEEPER_LEVEL_PRICE_MIN_RATE) * ratio;
	}

	/**
	 * @param karma : The karma of the {@link Player}.
	 * @return The karma rate, from 1 without karma up to 1 + KarmaPriceRate at KarmaPriceCap.
	 */
	private static double getKarmaPriceRate(int karma)
	{
		if (karma <= 0)
			return 1;

		return 1 + Config.GATEKEEPER_KARMA_PRICE_RATE * Math.min(1, (double) karma / Config.GATEKEEPER_KARMA_PRICE_CAP);
	}

	/**
	 * @param id : The table id, being {@link #AREAS_TABLE}, {@link #POINTS_TABLE} or {@link #POPULAR_TABLE}.
	 * @return The {@link GatekeeperTable} describing the columns of a generated list page, never null.
	 */
	public GatekeeperTable getTable(String id)
	{
		return _tables.getOrDefault(id, EMPTY_TABLE);
	}

	/**
	 * @return The width, in pixels, of every generated table - the tab bar, the header and the rows of the lists.
	 */
	public int getWidth()
	{
		return _width;
	}

	/**
	 * @return The height, in pixels, of a single row of a list. It also drives the filler pushing the page selector to the bottom of the dialog.
	 */
	public int getRowHeight()
	{
		return _rowHeight;
	}

	public int getHeaderHeight()
	{
		return _headerHeight;
	}

	public int getTabHeight()
	{
		return _tabHeight;
	}

	/**
	 * @return The maximum amount of tabs shown on a single row of the tab bar ; above it, the tabs are spread on multiple rows.
	 */
	public int getTabColumns()
	{
		return _tabColumns;
	}

	/**
	 * @return The maximum amount of page links shown by the page selector, centered on the current page.
	 */
	public int getMaxPages()
	{
		return _maxPages;
	}

	/**
	 * @return The suffix appended to a shortened cell content.
	 */
	public String getEllipsis()
	{
		return _ellipsis;
	}

	/**
	 * The dialog owns a fixed height ; padding every list up to that very same total keeps the page selector at one spot, and keeps the scrollbar shown on every single page.
	 * @return The height, in pixels, a page is padded up to - the tab bar, the HTM overhead and the list rows included. 0 disables the padding.
	 */
	public int getPageHeight()
	{
		return _pageHeight;
	}

	/**
	 * @return The background color of the odd rows of the lists.
	 */
	public String getRowColor()
	{
		return _rowColor;
	}

	/**
	 * @return The background color of the even rows of the lists ; empty means transparent.
	 */
	public String getAltRowColor()
	{
		return _altRowColor;
	}

	public String getHeaderColor()
	{
		return _headerColor;
	}

	public String getHeaderTextColor()
	{
		return _headerTextColor;
	}

	/**
	 * @return The color of the headline of the dialogs, fed to the HTMs as %titleColor%.
	 */
	public String getTitleColor()
	{
		return _titleColor;
	}

	public String getTabBarColor()
	{
		return _tabBarColor;
	}

	/**
	 * @return The default color of the tabs, overridden by the "color" attribute of a given tab.
	 */
	public String getTabColor()
	{
		return _tabColor;
	}

	public String getActiveTabColor()
	{
		return _activeTabColor;
	}

	/**
	 * @return The color of the name column of the lists ; empty keeps the client default.
	 */
	public String getNameColor()
	{
		return _nameColor;
	}

	public String getPointColor()
	{
		return _pointColor;
	}

	public String getPriceColor()
	{
		return _priceColor;
	}

	public String getFreeColor()
	{
		return _freeColor;
	}

	/**
	 * @return The color of everything the {@link Player} can't use - locked points, unreachable capitals, empty lists.
	 */
	public String getDisabledColor()
	{
		return _disabledColor;
	}

	public String getPageColor()
	{
		return _pageColor;
	}

	public String getActivePageColor()
	{
		return _activePageColor;
	}

	/**
	 * @return The color of the territory type, shown on the action column of the teleport points lists.
	 */
	public String getTerritoryColor()
	{
		return _territoryColor;
	}

	/**
	 * @return The label shown on the action column, when the point requires noblesse.
	 */
	public String getNobleLabel()
	{
		return _nobleLabel;
	}

	/**
	 * @return The label shown on the action column, when the point is unreachable.
	 */
	public String getLockedLabel()
	{
		return _lockedLabel;
	}

	/**
	 * @return The label shown on the price column, when the teleport is free.
	 */
	public String getFreeLabel()
	{
		return _freeLabel;
	}

	/**
	 * @return The label shown instead of an empty list.
	 */
	public String getEmptyLabel()
	{
		return _emptyLabel;
	}

	/**
	 * @return The label of the link leading back to the areas list.
	 */
	public String getBackLabel()
	{
		return _backLabel;
	}

	/**
	 * @return The label shown on the action column, when the row leads to a sub list instead of teleporting.
	 */
	public String getListLabel()
	{
		return _listLabel;
	}

	/**
	 * @return The label of the "previous page" link of the page selector.
	 */
	public String getPrevPageLabel()
	{
		return _prevPageLabel;
	}

	/**
	 * @return The text written between the destination and its price, on the confirmation box shown before a teleport.
	 */
	public String getPopupSeparator()
	{
		return _popupSeparator;
	}

	/**
	 * @return The amount of characters kept of the currency name, on the price column. 0 shows the whole name, localized by the client.
	 */
	public int getCurrencyChars()
	{
		return _currencyChars;
	}

	/**
	 * @return True if the shortened currency name is lowercased.
	 */
	public boolean isCurrencyLowerCase()
	{
		return _isCurrencyLowerCase;
	}

	/**
	 * @return The label of the "next page" link of the page selector.
	 */
	public String getNextPageLabel()
	{
		return _nextPageLabel;
	}

	public static GatekeeperData getInstance()
	{
		return SingletonHolder.INSTANCE;
	}

	private static class SingletonHolder
	{
		protected static final GatekeeperData INSTANCE = new GatekeeperData();
	}
}
