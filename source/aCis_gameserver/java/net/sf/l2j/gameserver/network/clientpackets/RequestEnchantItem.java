package net.sf.l2j.gameserver.network.clientpackets;

import net.sf.l2j.commons.random.Rnd;

import net.sf.l2j.Config;
import net.sf.l2j.gameserver.data.SkillTable;
import net.sf.l2j.gameserver.data.xml.ArmorSetData;
import net.sf.l2j.gameserver.enums.Paperdoll;
import net.sf.l2j.gameserver.model.actor.Player;
import net.sf.l2j.gameserver.model.item.ArmorSet;
import net.sf.l2j.gameserver.model.item.instance.ItemInstance;
import net.sf.l2j.gameserver.model.item.kind.Armor;
import net.sf.l2j.gameserver.model.item.kind.Item;
import net.sf.l2j.gameserver.model.item.kind.Weapon;
import net.sf.l2j.gameserver.network.SystemMessageId;
import net.sf.l2j.gameserver.network.serverpackets.ChooseInventoryItem;
import net.sf.l2j.gameserver.network.serverpackets.EnchantResult;
import net.sf.l2j.gameserver.network.serverpackets.SkillList;
import net.sf.l2j.gameserver.network.serverpackets.SystemMessage;
import net.sf.l2j.gameserver.skills.L2Skill;

public final class RequestEnchantItem extends AbstractEnchantPacket
{
	private int _objectId;
	
	@Override
	protected void readImpl()
	{
		_objectId = readD();
	}
	
	@Override
	protected void runImpl()
	{
		final Player player = getClient().getPlayer();
		if (player == null || _objectId == 0)
			return;
		
		if (!player.isOnline() || getClient().isDetached())
		{
			player.setActiveEnchantItem(null);
			return;
		}
		
		if (player.isProcessingTransaction() || player.isOperating())
		{
			player.sendPacket(SystemMessageId.CANNOT_ENCHANT_WHILE_STORE);
			player.setActiveEnchantItem(null);
			player.sendPacket(EnchantResult.CANCELLED);
			return;
		}
		
		final ItemInstance item = player.getInventory().getItemByObjectId(_objectId);
		ItemInstance scroll = player.getActiveEnchantItem();
		
		if (item == null || scroll == null)
		{
			player.cancelActiveEnchant();
			return;
		}
		
		// template for scroll
		final EnchantScroll scrollTemplate = getEnchantScroll(scroll);
		if (scrollTemplate == null)
			return;

		// Memorize the scroll item id, since the ItemInstance can be destroyed below.
		final int scrollItemId = scroll.getItemId();

		// first validation check
		if (!scrollTemplate.isValid(item) || !isEnchantable(item))
		{
			player.sendPacket(SystemMessageId.INAPPROPRIATE_ENCHANT_CONDITION);
			player.setActiveEnchantItem(null);
			player.sendPacket(EnchantResult.CANCELLED);
			return;
		}
		
		// attempting to destroy scroll
		scroll = player.getInventory().destroyItem(scroll.getObjectId(), 1);
		if (scroll == null)
		{
			player.sendPacket(SystemMessageId.NOT_ENOUGH_ITEMS);
			player.setActiveEnchantItem(null);
			player.sendPacket(EnchantResult.CANCELLED);
			return;
		}
		
		if (player.getActiveTradeList() != null)
		{
			player.cancelActiveTrade();
			player.sendPacket(SystemMessageId.TRADE_ATTEMPT_FAILED);
			return;
		}
		
		synchronized (item)
		{
			double chance = scrollTemplate.getChance(item);
			
			// last validation check
			if (item.getOwnerId() != player.getObjectId() || !isEnchantable(item) || chance < 0)
			{
				player.sendPacket(SystemMessageId.INAPPROPRIATE_ENCHANT_CONDITION);
				player.setActiveEnchantItem(null);
				player.sendPacket(EnchantResult.CANCELLED);
				return;
			}
			
			// success
			if (Rnd.nextDouble() < chance)
			{
				// announce the success
				SystemMessage sm;
				
				if (item.getEnchantLevel() == 0)
				{
					sm = SystemMessage.getSystemMessage(SystemMessageId.S1_SUCCESSFULLY_ENCHANTED);
					sm.addItemName(item.getItemId());
					player.sendPacket(sm);
				}
				else
				{
					sm = SystemMessage.getSystemMessage(SystemMessageId.S1_S2_SUCCESSFULLY_ENCHANTED);
					sm.addNumber(item.getEnchantLevel());
					sm.addItemName(item.getItemId());
					player.sendPacket(sm);
				}
				
				item.setEnchantLevel(item.getEnchantLevel() + 1, player);
				
				// If item is equipped, verify the skill obtention (+4 duals, +6 armorset).
				if (item.isEquipped())
				{
					final Item it = item.getItem();
					
					// Add skill bestowed by +4 duals.
					if (it instanceof Weapon weapon && item.getEnchantLevel() == 4)
					{
						final L2Skill enchant4Skill = weapon.getEnchant4Skill();
						if (enchant4Skill != null)
						{
							player.addSkill(enchant4Skill, false);
							player.sendPacket(new SkillList(player));
						}
					}
					// Add skill bestowed by +6 armorset.
					else if (it instanceof Armor && item.getEnchantLevel() == 6)
					{
						// Checks if player is wearing a chest item
						final int chestId = player.getInventory().getItemIdFrom(Paperdoll.CHEST);
						if (chestId != 0)
						{
							final ArmorSet armorSet = ArmorSetData.getInstance().getSet(chestId);
							if (armorSet != null && armorSet.isEnchanted6(player)) // has all parts of set enchanted to 6 or more
							{
								final int skillId = armorSet.getEnchant6skillId();
								if (skillId > 0)
								{
									final L2Skill skill = SkillTable.getInstance().getInfo(skillId, 1);
									if (skill != null)
									{
										player.addSkill(skill, false);
										player.sendPacket(new SkillList(player));
									}
								}
							}
						}
					}
				}
				player.sendPacket(EnchantResult.SUCCESS);
			}
			else
			{
				// Drop passive skills from items.
				if (item.isEquipped())
				{
					final Item it = item.getItem();
					
					// Remove skill bestowed by +4 duals.
					if (it instanceof Weapon weapon && item.getEnchantLevel() >= 4)
					{
						final L2Skill enchant4Skill = weapon.getEnchant4Skill();
						if (enchant4Skill != null)
						{
							player.removeSkill(enchant4Skill.getId(), false);
							player.sendPacket(new SkillList(player));
						}
					}
					// Add skill bestowed by +6 armorset.
					else if (it instanceof Armor && item.getEnchantLevel() >= 6)
					{
						// Checks if player is wearing a chest item
						final int chestId = player.getInventory().getItemIdFrom(Paperdoll.CHEST);
						if (chestId != 0)
						{
							final ArmorSet armorSet = ArmorSetData.getInstance().getSet(chestId);
							if (armorSet != null && armorSet.isEnchanted6(player)) // has all parts of set enchanted to 6 or more
							{
								final int skillId = armorSet.getEnchant6skillId();
								if (skillId > 0)
								{
									player.removeSkill(skillId, false);
									player.sendPacket(new SkillList(player));
								}
							}
						}
					}
				}
				
				if (scrollTemplate.isBlessed())
				{
					// blessed enchant - clear enchant value
					player.sendPacket(SystemMessageId.BLESSED_ENCHANT_FAILED);
					
					item.setEnchantLevel(0, player);
					player.sendPacket(EnchantResult.UNSUCCESS);
				}
				else
				{
					// enchant failed, destroy item
					int crystalId = item.getItem().getCrystalItemId();
					int count = item.getCrystalCount() - (item.getItem().getCrystalCount() + 1) / 2;
					if (count < 1)
						count = 1;
					
					final ItemInstance destroyItem = player.getInventory().destroyItem(item);
					if (destroyItem == null)
					{
						player.setActiveEnchantItem(null);
						player.sendPacket(EnchantResult.CANCELLED);
						return;
					}
					
					if (crystalId != 0)
					{
						player.getInventory().addItem(crystalId, count);
						player.sendPacket(SystemMessage.getSystemMessage(SystemMessageId.EARNED_S2_S1_S).addItemName(crystalId).addItemNumber(count));
					}
					
					// Messages.
					if (item.getEnchantLevel() > 0)
						player.sendPacket(SystemMessage.getSystemMessage(SystemMessageId.ENCHANTMENT_FAILED_S1_S2_EVAPORATED).addNumber(item.getEnchantLevel()).addItemName(item.getItemId()));
					else
						player.sendPacket(SystemMessage.getSystemMessage(SystemMessageId.ENCHANTMENT_FAILED_S1_EVAPORATED).addItemName(item.getItemId()));
					
					player.sendPacket((crystalId == 0) ? EnchantResult.UNK_RESULT_4 : EnchantResult.UNK_RESULT_1);
				}
			}
			
			player.broadcastUserInfo();

			// Feed the enchant window with another scroll, or simply close it.
			if (!keepEnchantWindowOpened(player, scrollItemId, item))
				player.setActiveEnchantItem(null);
		}
	}

	/**
	 * Try to keep the enchant window opened, using another {@link ItemInstance} scroll of the very same item id.
	 * <p>
	 * It only happens if {@link Config#ENCHANT_KEEP_WINDOW_OPENED} is enabled, if the enchanted item survived the
	 * attempt and can still be enchanted by that type of scroll, and if such a scroll is still owned. Not sending the
	 * order is what closes the window, so every early return below doubles as "the run is over".
	 * <p>
	 * A stock client rebuilds its item list upon reopening, which costs the player a new item selection. A client
	 * whose ItemEnchantWnd was rebuilt from tools/client keeps the list and the selection, so pressing "Enchant"
	 * again is enough.
	 * @param player : The {@link Player} who made the enchant attempt.
	 * @param scrollItemId : The item id of the scroll consumed by the enchant attempt.
	 * @param item : The {@link ItemInstance} which was the target of the enchant attempt.
	 * @return True if the enchant window has been kept opened, false otherwise.
	 */
	private static boolean keepEnchantWindowOpened(Player player, int scrollItemId, ItemInstance item)
	{
		if (!Config.ENCHANT_KEEP_WINDOW_OPENED)
			return false;

		// The enchanted item must have survived the attempt ; a destroyed item isn't part of the inventory anymore.
		if (player.getInventory().getItemByObjectId(item.getObjectId()) != item)
			return false;

		// We need another scroll of the very same type.
		final ItemInstance scroll = player.getInventory().getItemByItemId(scrollItemId);
		if (scroll == null)
			return false;

		// That scroll must still be able to enchant that item (enchant limits, notably).
		final EnchantScroll scrollTemplate = getEnchantScroll(scroll);
		if (scrollTemplate == null || !scrollTemplate.isValid(item) || !isEnchantable(item))
			return false;

		player.setActiveEnchantItem(scroll);
		player.sendPacket(new ChooseInventoryItem(scroll.getItemId()));
		return true;
	}
}