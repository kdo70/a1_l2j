package net.sf.l2j.gameserver.data.xml;

import java.nio.file.Path;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import net.sf.l2j.commons.data.xml.IXmlReader;

import net.sf.l2j.Config;
import net.sf.l2j.gameserver.enums.GatekeeperPointType;
import net.sf.l2j.gameserver.enums.GatekeeperTabType;
import net.sf.l2j.gameserver.model.actor.Player;
import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperArea;
import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperMenu;
import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperPoint;
import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperTab;
import net.sf.l2j.gameserver.taskmanager.GameTimeTaskManager;

import org.w3c.dom.Document;
import org.w3c.dom.NamedNodeMap;
import org.w3c.dom.Node;

/**
 * This class loads and stores {@link GatekeeperMenu}s, used by the GlobalGatekeeper script.<br>
 * <br>
 * Every piece of content (Npc ids, menu tabs, areas, teleport points and their prices) is datapack driven ; the database only retains teleport counters, handled by
 * {@link net.sf.l2j.gameserver.data.manager.GatekeeperStatsManager}.
 */
public class GatekeeperData implements IXmlReader
{
	/** The script name, used to generate internal bypasses. Must match the GlobalGatekeeper class name. */
	public static final String SCRIPT_NAME = "GlobalGatekeeper";

	private static final String DEFAULT_TAB_COLOR = "FFFFFF";

	private final Map<Integer, GatekeeperMenu> _menus = new HashMap<>();
	private final Map<Integer, GatekeeperMenu> _npcs = new HashMap<>();
	private final Map<Integer, GatekeeperPoint> _points = new HashMap<>();

	private int _rowsPerPage;
	private int _popularLimit;
	private int _popularMinCount;
	private int _defaultPriceId;
	private int _defaultPrice;
	private int _defaultNoblePrice;
	private int _teleportDelay;

	private String _goLabel;
	private String _nobleLabel;
	private String _lockedLabel;
	private String _freeLabel;
	private String _emptyLabel;
	private String _backLabel;
	private String _rowColor;

	private boolean _isPricingEnabled;
	private int _priceRounding;

	private boolean _isDistancePriceEnabled;
	private int _minDistancePrice;
	private int _maxDistancePrice;
	private double _maxDistance;
	private double _distanceCurve;

	private boolean _isLevelPriceEnabled;
	private int _levelPriceFrom;
	private int _levelPriceTo;
	private double _levelPriceMinRate;

	private boolean _isKarmaPriceEnabled;
	private int _karmaPriceCap;
	private double _karmaPriceRate;

	private boolean _isNightPriceEnabled;
	private double _nightPriceRate;

	protected GatekeeperData()
	{
		load();
	}

	@Override
	public void load()
	{
		setDefaultSettings();

		parseFile("./data/xml/gatekeeper.xml");
		LOGGER.info("Loaded {} gatekeeper menus, {} teleport points for {} npcs.", _menus.size(), _points.size(), _npcs.size());
	}

	@Override
	public void parseDocument(Document doc, Path path)
	{
		forEach(doc, "list", listNode ->
		{
			forEach(listNode, "settings", settingsNode ->
			{
				final NamedNodeMap attrs = settingsNode.getAttributes();

				_rowsPerPage = Math.max(1, parseInteger(attrs, "rowsPerPage", _rowsPerPage));
				_popularLimit = Math.max(1, parseInteger(attrs, "popularLimit", _popularLimit));
				_popularMinCount = Math.max(1, parseInteger(attrs, "popularMinCount", _popularMinCount));
				_defaultPriceId = parseInteger(attrs, "defaultPriceId", _defaultPriceId);
				_defaultPrice = Math.max(-1, parseInteger(attrs, "defaultPrice", _defaultPrice));
				_defaultNoblePrice = Math.max(-1, parseInteger(attrs, "defaultNoblePrice", _defaultNoblePrice));
				_teleportDelay = Math.min(60000, Math.max(0, parseInteger(attrs, "teleportDelay", _teleportDelay)));

				_goLabel = parseString(attrs, "goLabel", _goLabel);
				_nobleLabel = parseString(attrs, "nobleLabel", _nobleLabel);
				_lockedLabel = parseString(attrs, "lockedLabel", _lockedLabel);
				_freeLabel = parseString(attrs, "freeLabel", _freeLabel);
				_emptyLabel = parseString(attrs, "emptyLabel", _emptyLabel);
				_backLabel = parseString(attrs, "backLabel", _backLabel);
				_rowColor = parseString(attrs, "rowColor", _rowColor);
			});

			forEach(listNode, "pricing", pricingNode ->
			{
				final NamedNodeMap attrs = pricingNode.getAttributes();

				_isPricingEnabled = parseBoolean(attrs, "enabled", _isPricingEnabled);
				_priceRounding = Math.max(1, parseInteger(attrs, "rounding", _priceRounding));

				_isDistancePriceEnabled = parseBoolean(attrs, "distance", _isDistancePriceEnabled);
				_minDistancePrice = Math.max(0, parseInteger(attrs, "minPrice", _minDistancePrice));
				_maxDistancePrice = Math.max(_minDistancePrice, parseInteger(attrs, "maxPrice", _maxDistancePrice));
				_maxDistance = Math.max(1, parseDouble(attrs, "maxDistance", _maxDistance));
				_distanceCurve = Math.max(0.1, parseDouble(attrs, "distanceCurve", _distanceCurve));

				_isLevelPriceEnabled = parseBoolean(attrs, "level", _isLevelPriceEnabled);
				_levelPriceFrom = Math.max(1, parseInteger(attrs, "levelFrom", _levelPriceFrom));
				_levelPriceTo = Math.max(_levelPriceFrom, parseInteger(attrs, "levelTo", _levelPriceTo));
				_levelPriceMinRate = Math.min(1, Math.max(0, parseDouble(attrs, "levelMinRate", _levelPriceMinRate)));

				_isKarmaPriceEnabled = parseBoolean(attrs, "karma", _isKarmaPriceEnabled);
				_karmaPriceCap = Math.max(1, parseInteger(attrs, "karmaCap", _karmaPriceCap));
				_karmaPriceRate = Math.max(0, parseDouble(attrs, "karmaRate", _karmaPriceRate));

				_isNightPriceEnabled = parseBoolean(attrs, "night", _isNightPriceEnabled);
				_nightPriceRate = Math.max(0, parseDouble(attrs, "nightRate", _nightPriceRate));
			});

			forEach(listNode, "menu", menuNode -> parseMenu(menuNode));

			forEach(listNode, "npc", npcNode ->
			{
				final NamedNodeMap attrs = npcNode.getAttributes();
				final int npcId = parseInteger(attrs, "id", 0);
				final int menuId = parseInteger(attrs, "menu", 0);

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
		final int menuId = parseInteger(menuAttrs, "id", 0);
		final int menuPriceId = parseInteger(menuAttrs, "priceId", _defaultPriceId);
		final int menuPrice = parseInteger(menuAttrs, "price", _defaultPrice);
		final int menuNoblePrice = parseInteger(menuAttrs, "noblePrice", _defaultNoblePrice);

		final GatekeeperMenu menu = new GatekeeperMenu(menuId);
		final AtomicInteger tabIndex = new AtomicInteger();

		forEach(menuNode, "item", itemNode ->
		{
			final NamedNodeMap itemAttrs = itemNode.getAttributes();
			final String name = parseString(itemAttrs, "name", "?");
			final String color = parseString(itemAttrs, "color", DEFAULT_TAB_COLOR);
			final String bypass = parseString(itemAttrs, "bypass");
			final int tabPriceId = parseInteger(itemAttrs, "priceId", menuPriceId);
			final int tabPrice = parseInteger(itemAttrs, "price", menuPrice);
			final int tabNoblePrice = parseInteger(itemAttrs, "noblePrice", menuNoblePrice);

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

			final int index = tabIndex.getAndIncrement();
			final GatekeeperTab tab = new GatekeeperTab(index, name, color, type, generateBypass(type, index, bypass, page), page);

			if (type == GatekeeperTabType.AREAS)
			{
				final AtomicInteger areaIndex = new AtomicInteger();

				forEach(itemNode, "area", areaNode ->
				{
					final NamedNodeMap areaAttrs = areaNode.getAttributes();
					final String areaName = parseString(areaAttrs, "name", "?");
					final int areaPriceId = parseInteger(areaAttrs, "priceId", tabPriceId);
					final int areaPrice = parseInteger(areaAttrs, "price", tabPrice);
					final int areaNoblePrice = parseInteger(areaAttrs, "noblePrice", tabNoblePrice);

					final GatekeeperArea area = new GatekeeperArea(areaIndex.getAndIncrement(), areaName, parseString(areaAttrs, "capital", ""));

					forEach(areaNode, "loc", locNode ->
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
						return;
					}

					tab.addArea(area);
				});
			}
			else if (type == GatekeeperTabType.POINTS)
			{
				// The tab directly holds points ; wrap them into a single implicit area, named after the tab.
				final GatekeeperArea area = new GatekeeperArea(0, name, parseString(itemAttrs, "capital", ""));

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
		final int id = parseInteger(attrs, "id", -1);
		if (id < 0)
		{
			LOGGER.warn("A gatekeeper point of the area '{}' is missing its id.", areaName);
			return null;
		}

		// Noblesse points own their own default price, since they are usually free on retail.
		final GatekeeperPointType type = parseEnum(attrs, GatekeeperPointType.class, "type", GatekeeperPointType.STANDARD);
		final int defaultPrice = (type == GatekeeperPointType.NOBLE) ? areaNoblePrice : areaPrice;

		final GatekeeperPoint point = new GatekeeperPoint(id, parseString(attrs, "name", areaName), parseString(attrs, "point", ""), type, parseInteger(attrs, "priceId", areaPriceId), Math.max(-1, parseInteger(attrs, "price", defaultPrice)), parseInteger(attrs, "castleId", 0), parseInteger(attrs, "minLevel", 1), parseInteger(attrs, "maxLevel", 127), parseInteger(attrs, "x", 0), parseInteger(attrs, "y", 0), parseInteger(attrs, "z", 0));

		final GatekeeperPoint existing = _points.put(id, point);
		if (existing != null)
			LOGGER.warn("Gatekeeper point id {} is used more than once ; teleport counters will be shared.", id);

		return point;
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
	 * @param page : The filename to test.
	 * @return True if the filename is a plain HTM filename, without any path separator.
	 */
	public static boolean isValidPage(String page)
	{
		if (page.isEmpty() || page.contains("/") || page.contains("\\") || page.contains("..") || page.contains(" "))
			return false;

		return page.endsWith(".htm") || page.endsWith(".html");
	}

	private void setDefaultSettings()
	{
		_rowsPerPage = 12;
		_popularLimit = 20;
		_popularMinCount = 1;
		_defaultPriceId = 57;
		_defaultPrice = -1;
		_defaultNoblePrice = 0;
		_teleportDelay = 5000;

		_isPricingEnabled = true;
		_priceRounding = 100;

		_isDistancePriceEnabled = true;
		_minDistancePrice = 15000;
		_maxDistancePrice = 100000;
		_maxDistance = 200000;
		_distanceCurve = 1.5;

		_isLevelPriceEnabled = true;
		_levelPriceFrom = 1;
		_levelPriceTo = 80;
		_levelPriceMinRate = 0.4;

		_isKarmaPriceEnabled = true;
		_karmaPriceCap = 10000;
		_karmaPriceRate = 1;

		_isNightPriceEnabled = true;
		_nightPriceRate = 1.25;

		_goLabel = "&gt;&gt;";
		_nobleLabel = "noble";
		_lockedLabel = "-";
		_freeLabel = "0";
		_emptyLabel = "-";
		_backLabel = "&lt;&lt; back";
		_rowColor = "000000";
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
		return _rowsPerPage;
	}

	/**
	 * @return The casting time, in milliseconds, of the teleport animation played before the actual teleport. 0 disables the animation.
	 */
	public int getTeleportDelay()
	{
		return _teleportDelay;
	}

	public int getPopularLimit()
	{
		return _popularLimit;
	}

	public int getPopularMinCount()
	{
		return _popularMinCount;
	}

	/**
	 * Compute the price to pay for a given {@link GatekeeperPoint}.<br>
	 * <br>
	 * The base price is either the one set on the XML, or - when unset - the one derived from the distance between the {@link Player} and the point. That base is then affected by the level, the
	 * karma and the day/night rates. Every single modifier can be individually disabled from the XML pricing node.
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
		if (!_isPricingEnabled)
			return Math.max(0, fixedPrice);

		double price = (fixedPrice >= 0) ? fixedPrice : getDistancePrice(player, point);
		if (price <= 0)
			return 0;

		if (_isLevelPriceEnabled)
			price *= getLevelPriceRate(player.getStatus().getLevel());

		if (_isKarmaPriceEnabled)
			price *= getKarmaPriceRate(player.getKarma());

		if (_isNightPriceEnabled && GameTimeTaskManager.getInstance().isNight())
			price *= _nightPriceRate;

		// Round the result, but never turn a paying teleport into a free one.
		return (int) Math.max(1, Math.min(Math.round(price / _priceRounding) * (long) _priceRounding, Integer.MAX_VALUE));
	}

	/**
	 * @param player : The {@link Player} used as starting point.
	 * @param point : The {@link GatekeeperPoint} to reach.
	 * @return The base price of the teleport, interpolated between minPrice and maxPrice using the 2D distance.
	 */
	private double getDistancePrice(Player player, GatekeeperPoint point)
	{
		if (!_isDistancePriceEnabled)
			return 0;

		final double ratio = Math.min(1, point.distance2D(player.getX(), player.getY()) / _maxDistance);

		return _minDistancePrice + (_maxDistancePrice - _minDistancePrice) * Math.pow(ratio, _distanceCurve);
	}

	/**
	 * @param level : The level of the {@link Player}.
	 * @return The level rate, from levelMinRate at levelFrom up to 1 at levelTo.
	 */
	private double getLevelPriceRate(int level)
	{
		if (_levelPriceTo <= _levelPriceFrom)
			return 1;

		final double ratio = Math.min(1, Math.max(0, (double) (level - _levelPriceFrom) / (_levelPriceTo - _levelPriceFrom)));

		return _levelPriceMinRate + (1 - _levelPriceMinRate) * ratio;
	}

	/**
	 * @param karma : The karma of the {@link Player}.
	 * @return The karma rate, from 1 without karma up to 1 + karmaRate at karmaCap.
	 */
	private double getKarmaPriceRate(int karma)
	{
		if (karma <= 0)
			return 1;

		return 1 + _karmaPriceRate * Math.min(1, (double) karma / _karmaPriceCap);
	}

	/**
	 * @return The label of the teleport link, shown on the action column.
	 */
	public String getGoLabel()
	{
		return _goLabel;
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
	 * @return The background color of the odd rows of the lists.
	 */
	public String getRowColor()
	{
		return _rowColor;
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
