package net.sf.l2j.gameserver.data;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import net.sf.l2j.commons.logging.CLogger;

import net.sf.l2j.gameserver.data.xml.ItemData;
import net.sf.l2j.gameserver.enums.SayType;
import net.sf.l2j.gameserver.model.actor.Player;
import net.sf.l2j.gameserver.model.item.kind.Item;
import net.sf.l2j.gameserver.network.serverpackets.CreatureSay;

/**
 * Feeds clients with the item name colors defined in the items XML ("name_color" property).<br>
 * <br>
 * Interlude carries no item name string, let alone a color, so the table travels as tagged chat messages : a client rebuilt from tools/client reads them and shows nothing, a stock client shows them as plain chat lines - which is why {@link net.sf.l2j.Config#SEND_ITEM_NAME_COLORS} exists and defaults to false.<br>
 * <br>
 * A message is {@link #TAG} followed by "itemId-red-green-blue" groups separated by ';', all decimal. {@link #RESET} is sent first and tells the client to drop the table it holds.
 */
public class ItemNameColorTable
{
	private static final CLogger LOGGER = new CLogger(ItemNameColorTable.class.getName());
	
	/** Marks a chat message as an item name color feed. */
	public static final String TAG = "~ic~";
	
	/** Sent ahead of the table ; empties the client side one. */
	private static final String RESET = TAG + "r";
	
	/** Entries per message. 5 keeps a message under 100 characters, the longest chat line this server accepts from a client - the incoming limit is unknown, so that is the safe assumption. */
	private static final int ENTRIES_PER_MESSAGE = 5;
	
	private volatile List<String> _messages;
	
	/**
	 * Drop the generated messages ; the next {@link #sendTo(Player)} regenerates them out of the current {@link Item} templates.
	 */
	public void reload()
	{
		_messages = null;
	}
	
	/**
	 * Send the whole table to a {@link Player}, as a reset followed by one message per batch of items. Does nothing if no item defines a color.
	 * @param player : The {@link Player} to send the table to.
	 */
	public void sendTo(Player player)
	{
		List<String> messages = _messages;
		if (messages == null)
			_messages = messages = generate();
		
		if (messages.isEmpty())
			return;
		
		player.sendPacket(new CreatureSay(0, SayType.ALL, "", RESET));
		
		for (String message : messages)
			player.sendPacket(new CreatureSay(0, SayType.ALL, "", message));
	}
	
	private static List<String> generate()
	{
		final List<String> messages = new ArrayList<>();
		final StringBuilder sb = new StringBuilder(TAG);
		
		int entries = 0;
		int items = 0;
		
		for (Item item : ItemData.getInstance().getTemplates())
		{
			if (item == null || !item.hasNameColor())
				continue;
			
			final int color = item.getNameColor();
			
			if (entries > 0)
				sb.append(';');
			
			sb.append(item.getItemId()).append('-').append((color >> 16) & 0xFF).append('-').append((color >> 8) & 0xFF).append('-').append(color & 0xFF);
			
			items++;
			
			if (++entries == ENTRIES_PER_MESSAGE)
			{
				messages.add(sb.toString());
				sb.setLength(TAG.length());
				entries = 0;
			}
		}
		
		if (entries > 0)
			messages.add(sb.toString());
		
		if (items > 0)
			LOGGER.info("Loaded {} item name color(s).", items);
		
		return (messages.isEmpty()) ? Collections.emptyList() : messages;
	}
	
	public static ItemNameColorTable getInstance()
	{
		return SingletonHolder.INSTANCE;
	}
	
	private static class SingletonHolder
	{
		protected static final ItemNameColorTable INSTANCE = new ItemNameColorTable();
	}
}
