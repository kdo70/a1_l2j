package net.sf.l2j.gameserver.data;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

import net.sf.l2j.gameserver.enums.SayType;
import net.sf.l2j.gameserver.model.World;
import net.sf.l2j.gameserver.model.actor.Player;
import net.sf.l2j.gameserver.model.holder.IntIntHolder;
import net.sf.l2j.gameserver.model.item.instance.ItemInstance;
import net.sf.l2j.gameserver.model.item.kind.Item;
import net.sf.l2j.gameserver.network.serverpackets.CreatureSay;

/**
 * Hands clients what an item carries on top of its template : the skills it grants to whoever equips it, and the color of its name. Both live on the item itself - two Short Swords can hold different ones - so everything here is keyed by objectId, not by item id.<br>
 * <br>
 * Nothing is sent on its own initiative. A client rebuilt from tools/client asks with the {@link #BYPASS} bypass - {@link #INVENTORY} for the whole inventory, once its item list arrived, or a list of objectIds for anything it is about to draw a tooltip for - and only then gets an answer. A stock client never asks and never sees a thing.<br>
 * <br>
 * A row is "objectId,red-green-blue,skillId-level,skillId-level,...", all decimal, the color being {@link #NO_COLOR} when the item leaves its name to the client and the skills being optional. Rows are joined with ';' behind a leading {@link #TAG}. An item the client asked about and which carries nothing is answered all the same, so that it stops asking.
 */
public class ItemSkillsTable
{
	/** Marks a chat message as an item skill feed. */
	public static final String TAG = "~ik~";

	/** The bypass a rebuilt client asks with, followed by {@link #INVENTORY} or by objectIds separated by ','. */
	public static final String BYPASS = "_itemskills ";

	/** The request standing for "everything I carry", which a client sends once its item list arrived. */
	private static final String INVENTORY = "i";

	/** Stands in the color field of a row when the item leaves its name to the client. */
	private static final String NO_COLOR = "n";

	/** Longest message this class builds. 100 is the longest chat line this server accepts from a client - the incoming limit is unknown, so that is the safe assumption. */
	private static final int MAX_MESSAGE_LENGTH = 100;

	/** ObjectIds honored in a single request ; the rest of the request is dropped. */
	private static final int MAX_REQUEST_IDS = 8;

	/**
	 * Answer a {@link Player} request with the rows it asked for.
	 * @param player : The {@link Player} which asked.
	 * @param request : {@link #INVENTORY}, or objectIds separated by ','.
	 */
	public void handleRequest(Player player, String request)
	{
		final List<String> rows = new ArrayList<>();

		if (request.equals(INVENTORY))
		{
			// The inventory is answered for what carries something only ; the rest is asked for one by one, if a tooltip ever shows up.
			for (ItemInstance item : player.getInventory().getItems())
			{
				if (hasCustomData(item))
					rows.add(generateRow(item));
			}
		}
		else
			fillWithIds(request, rows);

		send(player, rows);
	}

	/**
	 * Send the row of a single {@link ItemInstance} to a {@link Player}, which is how a change made while he is online reaches his tooltips. Sent whether that item carries something or not, since it is also how the client learns it carries nothing anymore.
	 * @param player : The {@link Player} to send the row to.
	 * @param item : The {@link ItemInstance} to describe.
	 */
	public void sendTo(Player player, ItemInstance item)
	{
		send(player, List.of(generateRow(item)));
	}

	/**
	 * Send the rows of a bunch of {@link ItemInstance}s to a {@link Player}, ahead of the window about to show them.<br>
	 * <br>
	 * The client asks by itself for what it doesn't know, but one item per drawn tooltip and through a flood protector - a store or a trade window is a dozen items met at once, which is the case that trip doesn't survive.
	 * @param player : The {@link Player} to send the rows to.
	 * @param items : The {@link ItemInstance}s to describe ; the ones carrying nothing are left out, they have nothing to show.
	 */
	public void sendTo(Player player, Collection<ItemInstance> items)
	{
		final List<String> rows = new ArrayList<>();

		for (ItemInstance item : items)
		{
			if (item != null && hasCustomData(item))
				rows.add(generateRow(item));
		}

		send(player, rows);
	}

	private static void send(Player player, List<String> rows)
	{
		if (rows.isEmpty())
			return;

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

	private static void fillWithIds(String request, List<String> rows)
	{
		int ids = 0;

		for (String token : request.split(","))
		{
			if (++ids > MAX_REQUEST_IDS)
				break;

			final int objectId;

			try
			{
				objectId = Integer.parseInt(token.trim());
			}
			catch (NumberFormatException e)
			{
				continue;
			}

			// An objectId which is no item of this world - a shop line, a multisell entry - is answered with an empty
			// row all the same, so that the client stops asking about it.
			if (World.getInstance().getObject(objectId) instanceof ItemInstance item)
				rows.add(generateRow(item));
			else
				rows.add(objectId + "," + NO_COLOR);
		}
	}

	private static boolean hasCustomData(ItemInstance item)
	{
		return item.getCustomSkills() != null || item.getNameColor() != Item.NO_NAME_COLOR;
	}

	private static String generateRow(ItemInstance item)
	{
		final StringBuilder sb = new StringBuilder(32);

		sb.append(item.getObjectId()).append(',');

		final int color = item.getNameColor();
		if (color == Item.NO_NAME_COLOR)
			sb.append(NO_COLOR);
		else
			sb.append((color >> 16) & 0xFF).append('-').append((color >> 8) & 0xFF).append('-').append(color & 0xFF);

		final IntIntHolder[] skills = item.getCustomSkills();
		if (skills != null)
		{
			for (IntIntHolder skill : skills)
			{
				// A row can't be split over two messages - the client reads one as the whole truth about that item -
				// so the skills which don't fit a message are dropped rather than sent as a row nobody can read.
				if (sb.length() + 12 > MAX_MESSAGE_LENGTH - TAG.length())
					break;

				sb.append(',').append(skill.getId()).append('-').append(skill.getValue());
			}
		}

		return sb.toString();
	}

	public static ItemSkillsTable getInstance()
	{
		return SingletonHolder.INSTANCE;
	}

	private static class SingletonHolder
	{
		protected static final ItemSkillsTable INSTANCE = new ItemSkillsTable();
	}
}
