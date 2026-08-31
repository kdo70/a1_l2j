package net.sf.l2j.gameserver.handler.admincommandhandlers;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.StringTokenizer;

import net.sf.l2j.commons.lang.StringUtil;

import net.sf.l2j.gameserver.data.manager.CursedWeaponManager;
import net.sf.l2j.gameserver.data.xml.ArmorSetData;
import net.sf.l2j.gameserver.data.xml.ItemData;
import net.sf.l2j.gameserver.handler.IAdminCommandHandler;
import net.sf.l2j.gameserver.model.actor.Player;
import net.sf.l2j.gameserver.model.item.ArmorSet;
import net.sf.l2j.gameserver.model.item.instance.ItemInstance;
import net.sf.l2j.gameserver.model.item.kind.Item;
import net.sf.l2j.gameserver.network.serverpackets.ExStorageMaxCount;
import net.sf.l2j.gameserver.network.serverpackets.ItemList;
import net.sf.l2j.gameserver.network.serverpackets.NpcHtmlMessage;

public class AdminItem implements IAdminCommandHandler
{
	private static final String[] ADMIN_COMMANDS =
	{
		"admin_give",
		"admin_item",
		"admin_clear_inventory"
	};
	
	private static final String[] GRADES =
	{
		"No Grade",
		"D Grade",
		"C Grade",
		"B Grade",
		"A Grade",
		"S Grade"
	};
	
	private static final int SETS_PER_PAGE = 20;
	
	@Override
	public void useAdminCommand(String command, Player player)
	{
		final Player targetPlayer = getTargetPlayer(player, true);
		
		final StringTokenizer st = new StringTokenizer(command);
		command = st.nextToken();
		
		if (command.startsWith("admin_give"))
		{
			if (!st.hasMoreTokens())
			{
				player.sendMessage("Usage: //give itemId count");
				return;
			}
			
			final String param = st.nextToken();
			if (!StringUtil.isDigit(param))
			{
				player.sendMessage("Usage: //give itemId count");
				return;
			}
			
			final int id = Integer.parseInt(param);
			final int count = (st.hasMoreTokens()) ? Integer.parseInt(st.nextToken()) : 1;
			
			createItem(player, targetPlayer, id, count, 0);
		}
		else if (command.startsWith("admin_item"))
		{
			if (!st.hasMoreTokens())
			{
				sendFile(player, "itemcreation.htm");
				return;
			}
			
			final String param = st.nextToken();
			if (StringUtil.isDigit(param))
			{
				final int id = Integer.parseInt(param);
				final int count = (st.hasMoreTokens()) ? Integer.parseInt(st.nextToken()) : 1;
				final int radius = (st.hasMoreTokens()) ? Integer.parseInt(st.nextToken()) : 0;
				
				createItem(player, targetPlayer, id, count, radius);
				
				sendFile(player, "itemcreation.htm");
			}
			else
			{
				switch (param)
				{
					case "coin":
						try
						{
							final int id = getCoinId(st.nextToken());
							if (id <= 0)
							{
								player.sendMessage("Usage: //item coin name [amount] [radius]");
								return;
							}
							
							final int count = (st.hasMoreTokens()) ? Integer.parseInt(st.nextToken()) : 1;
							final int radius = (st.hasMoreTokens()) ? Integer.parseInt(st.nextToken()) : 0;
							
							createItem(player, targetPlayer, id, count, radius);
						}
						catch (Exception e)
						{
							player.sendMessage("Usage: //item coin name [amount] [radius]");
						}
						sendFile(player, "itemcreation.htm");
						break;
					
					case "set":
					{
						// Every look exists in all six grades, which is far too many sets for one
						// page : browse them grade by grade, "//item set grade <1-6> [page]".
						int grade = 0;
						int page = 0;
						
						if (st.hasMoreTokens())
						{
							final String token = st.nextToken();
							if (token.equals("grade"))
							{
								try
								{
									grade = Integer.parseInt(st.nextToken());
									if (st.hasMoreTokens())
										page = Integer.parseInt(st.nextToken());
								}
								catch (Exception e)
								{
									player.sendMessage("Usage: //item set grade [1-6] [page]");
									return;
								}
							}
							// A chestId hands the whole set over, then comes back to its own page.
							else
							{
								try
								{
									final ArmorSet armorSet = ArmorSetData.getInstance().getSet(Integer.parseInt(token));
									if (armorSet == null)
									{
										player.sendMessage("This chest has no set.");
										return;
									}
									
									for (int itemId : armorSet.getSetItemsId())
									{
										if (itemId > 0)
											targetPlayer.getInventory().addItem(itemId, 1);
									}
									
									if (armorSet.getShield() > 0)
										targetPlayer.getInventory().addItem(armorSet.getShield(), 1);
									
									if (player != targetPlayer)
										player.sendMessage("You have spawned " + armorSet.toString() + " in " + targetPlayer.getName() + "'s inventory.");
									
									grade = armorSet.getSkillLvl();
									if (st.hasMoreTokens())
										page = Integer.parseInt(st.nextToken());
								}
								catch (Exception e)
								{
									player.sendMessage("Usage: //item set [chestId]");
								}
							}
						}
						
						showArmorSets(player, grade, page);
						break;
					}
				}
			}
		}
		else if (command.equals("admin_clear_inventory"))
		{
			final Player toClear = (st.hasMoreTokens()) ? getTargetPlayer(player, st.nextToken(), false) : targetPlayer;
			if (toClear == null)
			{
				player.sendMessage("That player isn't online.");
				return;
			}
			
			clearInventory(player, toClear);
		}
	}
	
	@Override
	public String[] getAdminCommandList()
	{
		return ADMIN_COMMANDS;
	}
	
	/**
	 * Renders data/html/admin/itemsets.htm : the six grades, or one page of the sets of a grade.
	 * @param player : The {@link Player} to send the page to.
	 * @param grade : The set skill level, 1 for No Grade up to 6 for S ; 0 shows the grade index.
	 * @param page : Which page of that grade, zero based.
	 */
	private static void showArmorSets(Player player, int grade, int page)
	{
		final StringBuilder sb = new StringBuilder();
		
		if (grade < 1 || grade > GRADES.length)
		{
			for (int i = 0; i < GRADES.length; i++)
				StringUtil.append(sb, "<tr><td><a action=\"bypass -h admin_item set grade ", i + 1, "\">", GRADES[i], "</a></td></tr>");
		}
		else
		{
			final List<ArmorSet> sets = new ArrayList<>();
			for (ArmorSet armorSet : ArmorSetData.getInstance().getSets())
			{
				if (armorSet.getSkillLvl() == grade)
					sets.add(armorSet);
			}
			sets.sort(Comparator.comparing(ArmorSet::toString));
			
			final int pages = Math.max(1, (sets.size() + SETS_PER_PAGE - 1) / SETS_PER_PAGE);
			page = Math.min(Math.max(page, 0), pages - 1);
			
			StringUtil.append(sb, "<tr><td><a action=\"bypass -h admin_item set\">Back to grades</a></td><td align=right>", GRADES[grade - 1], "</td></tr>");
			
			for (int i = page * SETS_PER_PAGE; i < Math.min((page + 1) * SETS_PER_PAGE, sets.size()); i++)
			{
				final ArmorSet armorSet = sets.get(i);
				StringUtil.append(sb, "<tr><td><a action=\"bypass -h admin_item set ", armorSet.getSetItemsId()[0], " ", page, "\">", armorSet.toString(), "</a></td></tr>");
			}
			
			sb.append("<tr><td>");
			for (int i = 0; i < pages; i++)
				StringUtil.append(sb, "<a action=\"bypass -h admin_item set grade ", grade, " ", i, "\">", (i == page) ? "[" + (i + 1) + "]" : i + 1, "</a>&nbsp;");
			sb.append("</td></tr>");
		}
		
		final NpcHtmlMessage html = new NpcHtmlMessage(0);
		html.setFile("data/html/admin/itemsets.htm");
		html.replace("%sets%", sb.toString());
		player.sendPacket(html);
	}
	
	/**
	 * Destroy every {@link ItemInstance} of a {@link Player} inventory, equipped ones included.
	 * @param player : The {@link Player} who fired the command.
	 * @param targetPlayer : The {@link Player} whose inventory is wiped.
	 */
	private static void clearInventory(Player player, Player targetPlayer)
	{
		if (targetPlayer.isProcessingTransaction() || targetPlayer.isOperating())
		{
			player.sendMessage(targetPlayer.getName() + " is currently trading or running a store.");
			return;
		}
		
		int count = 0;
		for (ItemInstance item : targetPlayer.getInventory().getItems())
		{
			if (!isClearable(targetPlayer, item))
				continue;
			
			if (targetPlayer.destroyItem(item, false))
				count++;
		}
		
		// Paperdoll slots were emptied one by one ; refresh what depends on them, then hand a whole new item list over.
		targetPlayer.refreshExpertisePenalty();
		targetPlayer.refreshWeightPenalty();
		targetPlayer.broadcastUserInfo();
		targetPlayer.sendPacket(new ItemList(targetPlayer, false));
		targetPlayer.sendPacket(new ExStorageMaxCount(targetPlayer));
		
		player.sendMessage("You destroyed " + count + " item(s) from " + ((player == targetPlayer) ? "your" : targetPlayer.getName() + "'s") + " inventory.");
	}
	
	/**
	 * @param player : The owner of the {@link ItemInstance}.
	 * @param item : The {@link ItemInstance} to test.
	 * @return True if the {@link ItemInstance} can be safely destroyed, false if it is a cursed weapon or the control item of an active pet or mount.
	 */
	private static boolean isClearable(Player player, ItemInstance item)
	{
		// Cursed weapons own their lifecycle ; destroying one here would desynchronize CursedWeaponManager.
		if (CursedWeaponManager.getInstance().isCursed(item.getItemId()))
			return false;
		
		// Don't orphan a summoned pet, nor the mount currently being ridden.
		if (item.isSummonItem() && ((player.getSummon() != null && player.getSummon().getControlItemId() == item.getObjectId()) || (player.isMounted() && player.getMountObjectId() == item.getObjectId())))
			return false;
		
		return true;
	}
	
	private static void createItem(Player player, Player targetPlayer, int id, int num, int radius)
	{
		final Item item = ItemData.getInstance().getTemplate(id);
		if (item == null)
		{
			player.sendMessage("This item doesn't exist.");
			return;
		}
		
		if (!targetPlayer.getInventory().validateCapacityByItemId(id, num))
		{
			player.sendMessage("Your target's inventory is full.");
			return;
		}
		
		if (radius > 0)
		{
			player.forEachKnownTypeInRadius(Player.class, radius, p -> p.addItem(id, num, true));
			player.sendMessage("Surrounding players were rewarded with " + num + " " + item.getName() + " in a " + radius + " radius.");
		}
		else
		{
			targetPlayer.addItem(id, num, true);
			
			if (player != targetPlayer)
				player.sendMessage("You have spawned " + num + " " + item.getName() + " (" + id + ") in " + targetPlayer.getName() + "'s inventory.");
		}
	}
	
	private static int getCoinId(String name)
	{
		if (name.equalsIgnoreCase("adena"))
			return 57;
		
		if (name.equalsIgnoreCase("ancient"))
			return 5575;
		
		if (name.equalsIgnoreCase("festival"))
			return 6673;
		
		return 0;
	}
}
