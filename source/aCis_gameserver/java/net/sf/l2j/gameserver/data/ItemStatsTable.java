package net.sf.l2j.gameserver.data;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import net.sf.l2j.gameserver.data.xml.ItemData;
import net.sf.l2j.gameserver.enums.SayType;
import net.sf.l2j.gameserver.enums.skills.Stats;
import net.sf.l2j.gameserver.model.World;
import net.sf.l2j.gameserver.model.actor.Player;
import net.sf.l2j.gameserver.model.item.instance.ItemInstance;
import net.sf.l2j.gameserver.model.item.kind.Item;
import net.sf.l2j.gameserver.model.item.kind.Weapon;
import net.sf.l2j.gameserver.network.serverpackets.CreatureSay;

/**
 * Hands clients the item numbers they otherwise read from their own weapongrp/armorgrp/etcitemgrp.dat : P.Atk, M.Atk, defenses, attack speed, weight and the like, taken from the {@link Item} templates of the datapack.<br>
 * <br>
 * Nothing is sent on its own initiative. A client rebuilt from tools/client asks with the {@link #BYPASS} bypass - {@link #INVENTORY} for the whole inventory, once its item list arrived, or a list of item ids for anything it is about to draw a tooltip for - and only then gets an answer. A stock client never asks and never sees a thing.<br>
 * <br>
 * A row is "itemId,pAtk,mAtk,pAtkSpd,pDef,mDef,sDef,shieldRate,evasion,mpBonus,mpConsume,soulshots,spiritshots,weight", all decimal, and rows are joined with ';' behind a leading {@link #TAG}. {@link #RESET} tells the client to drop everything it holds, and goes out to the clients which asked for something when the templates are reloaded.
 */
public class ItemStatsTable
{
	/** Marks a chat message as an item stat feed. */
	public static final String TAG = "~is~";
	
	/** The bypass a rebuilt client asks with, followed by {@link #INVENTORY} or by item ids separated by ','. */
	public static final String BYPASS = "_itemstats ";
	
	/** The request standing for "everything I carry", which a client sends once its item list arrived. */
	private static final String INVENTORY = "i";
	
	/** Tells the client to drop the rows it holds ; it asks again for whatever it needs next. */
	private static final String RESET = TAG + "r";
	
	/** Longest message this class builds. 100 is the longest chat line this server accepts from a client - the incoming limit is unknown, so that is the safe assumption. */
	private static final int MAX_MESSAGE_LENGTH = 100;
	
	/** Item ids honored in a single request ; the rest of the request is dropped. */
	private static final int MAX_REQUEST_IDS = 32;
	
	/** Distinct item ids answered for an {@link #INVENTORY} request ; a bagful of an Interlude Player fits in there. */
	private static final int MAX_INVENTORY_IDS = 128;
	
	private final Map<Integer, String> _rows = new ConcurrentHashMap<>();
	private final Set<Integer> _clients = ConcurrentHashMap.newKeySet();
	
	/**
	 * Drop the generated rows and tell the {@link Player}s which asked for some to do the same. The next requests regenerate them out of the current {@link Item} templates.
	 */
	public void reload()
	{
		_rows.clear();
		
		for (int objectId : _clients)
		{
			final Player player = World.getInstance().getPlayer(objectId);
			if (player != null)
				player.sendPacket(new CreatureSay(0, SayType.ALL, "", RESET));
		}
		
		_clients.clear();
	}
	
	/**
	 * Answer a {@link Player} request with the rows it asked for. Item ids this server doesn't know are silently skipped, which is how the client learns to stop asking for them.
	 * @param player : The {@link Player} which asked.
	 * @param request : {@link #INVENTORY}, or item ids separated by ','.
	 */
	public void handleRequest(Player player, String request)
	{
		final List<String> rows = new ArrayList<>();
		
		if (request.equals(INVENTORY))
			fillWithInventory(player, rows);
		else
			fillWithIds(request, rows);
		
		if (rows.isEmpty())
			return;
		
		_clients.add(player.getObjectId());
		
		final StringBuilder sb = new StringBuilder(TAG);
		
		for (String row : rows)
		{
			if (sb.length() > TAG.length())
			{
				if (sb.length() + 1 + row.length() > MAX_MESSAGE_LENGTH)
				{
					player.sendPacket(new CreatureSay(0, SayType.ALL, "", sb.toString()));
					sb.setLength(TAG.length());
				}
				else
					sb.append(';');
			}
			
			sb.append(row);
		}
		
		player.sendPacket(new CreatureSay(0, SayType.ALL, "", sb.toString()));
	}
	
	private void fillWithInventory(Player player, List<String> rows)
	{
		final Set<Integer> itemIds = new HashSet<>();
		
		for (ItemInstance item : player.getInventory().getItems())
		{
			if (itemIds.size() >= MAX_INVENTORY_IDS)
				break;
			
			if (itemIds.add(item.getItemId()))
				rows.add(getRow(item.getItem()));
		}
	}
	
	private void fillWithIds(String request, List<String> rows)
	{
		int ids = 0;
		
		for (String token : request.split(","))
		{
			if (++ids > MAX_REQUEST_IDS)
				break;
			
			final int itemId;
			
			try
			{
				itemId = Integer.parseInt(token.trim());
			}
			catch (NumberFormatException e)
			{
				continue;
			}
			
			final Item item = ItemData.getInstance().getTemplate(itemId);
			if (item != null)
				rows.add(getRow(item));
		}
	}
	
	/**
	 * @param item : The {@link Item} to describe.
	 * @return The row of that {@link Item}, generated on first use and held onto until the templates are reloaded.
	 */
	private String getRow(Item item)
	{
		String row = _rows.get(item.getItemId());
		if (row == null)
		{
			row = generateRow(item);
			_rows.put(item.getItemId(), row);
		}
		return row;
	}
	
	private static String generateRow(Item item)
	{
		final Weapon weapon = (item instanceof Weapon w) ? w : null;
		final StringBuilder sb = new StringBuilder(48);
		
		sb.append(item.getItemId());
		
		append(sb, item.getStatValue(Stats.POWER_ATTACK));
		append(sb, item.getStatValue(Stats.MAGIC_ATTACK));
		append(sb, item.getStatValue(Stats.POWER_ATTACK_SPEED));
		append(sb, item.getStatValue(Stats.POWER_DEFENCE));
		append(sb, item.getStatValue(Stats.MAGIC_DEFENCE));
		append(sb, item.getStatValue(Stats.SHIELD_DEFENCE));
		append(sb, item.getStatValue(Stats.SHIELD_RATE));
		append(sb, item.getStatValue(Stats.EVASION_RATE));
		append(sb, item.getStatValue(Stats.MAX_MP));
		
		sb.append(',').append((weapon == null) ? 0 : weapon.getBaseMpConsume());
		sb.append(',').append((weapon == null) ? 0 : weapon.getSoulShotCount());
		sb.append(',').append((weapon == null) ? 0 : weapon.getSpiritShotCount());
		sb.append(',').append(item.getWeight());
		
		return sb.toString();
	}
	
	private static void append(StringBuilder sb, double value)
	{
		sb.append(',').append((int) value);
	}
	
	public static ItemStatsTable getInstance()
	{
		return SingletonHolder.INSTANCE;
	}
	
	private static class SingletonHolder
	{
		protected static final ItemStatsTable INSTANCE = new ItemStatsTable();
	}
}
