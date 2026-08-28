package net.sf.l2j.gameserver.data.xml;

import java.nio.file.Path;
import java.util.HashMap;
import java.util.Map;

import net.sf.l2j.commons.data.xml.IXmlReader;

import net.sf.l2j.gameserver.model.item.kind.Item;

import org.w3c.dom.Document;
import org.w3c.dom.NamedNodeMap;

/**
 * Loads and stores the client side icon of every {@link Item}, held by data/xml/itemIcons.xml.<br>
 * <br>
 * Interlude keeps the icon of an item on the client only - weapongrp.dat, armorgrp.dat and etcitemgrp.dat - so the server can't guess it. The XML is the very same table, extracted out of a client
 * by tools/icons/grp_to_icons.ps1, and it only exists so that generated HTMs can draw an item.<br>
 * <br>
 * An item the table doesn't know falls back on the "default" icon of the root node, which keeps a missing entry from breaking the layout of a page.
 */
public class ItemIconData implements IXmlReader
{
	/** The package every icon of the client lives in ; the XML holds the bare names. */
	private static final String ICON_PACKAGE = "icon.";

	private final Map<Integer, String> _icons = new HashMap<>();

	private String _defaultIcon = "noimage";

	protected ItemIconData()
	{
		load();
	}

	@Override
	public void load()
	{
		parseFile("./data/xml/itemIcons.xml");

		LOGGER.info("Loaded {} item icons.", _icons.size());
	}

	@Override
	public void parseDocument(Document doc, Path path)
	{
		forEach(doc, "list", listNode ->
		{
			_defaultIcon = parseString(listNode.getAttributes(), "default", _defaultIcon);

			forEach(listNode, "item", itemNode ->
			{
				final NamedNodeMap attrs = itemNode.getAttributes();
				final Integer itemId = parseInteger(attrs, "id");
				final String icon = parseString(attrs, "icon");

				if (itemId == null || icon == null || icon.isEmpty())
					return;

				_icons.put(itemId, icon);
			});
		});
	}

	public void reload()
	{
		_icons.clear();

		load();
	}

	/**
	 * @param itemId : The {@link Item} id to check.
	 * @return The icon of the given {@link Item}, ready to be fed to an &lt;img&gt; tag - the default icon if the table doesn't know that item.
	 */
	public String getIcon(int itemId)
	{
		return ICON_PACKAGE + _icons.getOrDefault(itemId, _defaultIcon);
	}

	public static ItemIconData getInstance()
	{
		return SingletonHolder.INSTANCE;
	}

	private static class SingletonHolder
	{
		protected static final ItemIconData INSTANCE = new ItemIconData();
	}
}
