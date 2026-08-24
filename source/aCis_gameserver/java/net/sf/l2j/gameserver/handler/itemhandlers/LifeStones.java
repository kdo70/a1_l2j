package net.sf.l2j.gameserver.handler.itemhandlers;

import net.sf.l2j.Config;
import net.sf.l2j.gameserver.data.xml.AugmentationData;
import net.sf.l2j.gameserver.data.xml.ItemData;
import net.sf.l2j.gameserver.enums.ShortcutType;
import net.sf.l2j.gameserver.handler.IItemHandler;
import net.sf.l2j.gameserver.model.Augmentation;
import net.sf.l2j.gameserver.model.actor.Playable;
import net.sf.l2j.gameserver.model.actor.Player;
import net.sf.l2j.gameserver.model.item.LifeStone;
import net.sf.l2j.gameserver.model.item.instance.ItemInstance;
import net.sf.l2j.gameserver.model.item.kind.Item;
import net.sf.l2j.gameserver.network.SystemMessageId;
import net.sf.l2j.gameserver.network.clientpackets.AbstractRefinePacket;

/**
 * Handle the augmentation of the equipped weapon through a double-click on a {@link LifeStone}.<br>
 * The whole validation logic is the same than the NPC-based augmentation process.
 */
public class LifeStones implements IItemHandler
{
	@Override
	public void useItem(Playable playable, ItemInstance item, boolean forceUse)
	{
		if (!Config.AUGMENTATION_VIA_LIFE_STONE)
			return;
		
		if (!(playable instanceof Player player))
			return;
		
		final LifeStone lifeStone = AbstractRefinePacket.getLifeStone(item.getItemId());
		if (lifeStone == null)
			return;
		
		// The stone can only be inserted into an equipped weapon.
		final ItemInstance weapon = player.getActiveWeaponInstance();
		if (weapon == null)
		{
			player.sendMessage("You must first equip a weapon in order to augment it.");
			return;
		}
		
		if (weapon.isAugmented())
		{
			player.sendPacket(SystemMessageId.ONCE_AN_ITEM_IS_AUGMENTED_IT_CANNOT_BE_AUGMENTED_AGAIN);
			return;
		}
		
		// Same conditions than the NPC-based augmentation process.
		if (!AbstractRefinePacket.isValid(player, weapon, item))
		{
			player.sendPacket(SystemMessageId.AUGMENTATION_FAILED_DUE_TO_INAPPROPRIATE_CONDITIONS);
			return;
		}
		
		// Retrieve the configured cost for the life stone grade.
		final int[] cost = switch (lifeStone.grade())
		{
			case AbstractRefinePacket.GRADE_MID -> Config.AUGMENTATION_VIA_LIFE_STONE_COST_MID_GRADE;
			case AbstractRefinePacket.GRADE_HIGH -> Config.AUGMENTATION_VIA_LIFE_STONE_COST_HIGH_GRADE;
			case AbstractRefinePacket.GRADE_TOP -> Config.AUGMENTATION_VIA_LIFE_STONE_COST_TOP_GRADE;
			default -> Config.AUGMENTATION_VIA_LIFE_STONE_COST_NO_GRADE;
		};
		
		final boolean hasCost = cost.length >= 2 && cost[0] > 0 && cost[1] > 0;
		if (hasCost)
		{
			if (player.getInventory().getItemCount(cost[0]) < cost[1])
			{
				final Item costTemplate = ItemData.getInstance().getTemplate(cost[0]);
				player.sendMessage("You need " + cost[1] + " x " + ((costTemplate != null) ? costTemplate.getName() : "item " + cost[0]) + " in order to augment your weapon.");
				return;
			}
		}
		
		// Consume the life stone.
		if (!player.destroyItem(item, 1, false))
			return;
		
		// Consume the cost items.
		if (hasCost && !player.destroyItemByItemId(cost[0], cost[1], false))
			return;
		
		final Augmentation augmentation = AugmentationData.getInstance().generateRandomAugmentation(lifeStone.level(), lifeStone.grade());
		if (!weapon.setAugmentation(augmentation, player))
			return;
		
		// The weapon is equipped, so the augmentation bonuses are applied instantly.
		augmentation.applyBonus(player);
		
		player.broadcastUserInfo();
		player.sendPacket(SystemMessageId.THE_ITEM_WAS_SUCCESSFULLY_AUGMENTED);
		
		// Refresh shortcuts.
		player.getShortcutList().refreshShortcuts(s -> weapon.getObjectId() == s.getId() && s.getType() == ShortcutType.ITEM);
	}
}
