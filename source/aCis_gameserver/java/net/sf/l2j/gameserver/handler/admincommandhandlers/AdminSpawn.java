package net.sf.l2j.gameserver.handler.admincommandhandlers;

import java.util.List;
import java.util.StringTokenizer;

import net.sf.l2j.commons.data.Pagination;
import net.sf.l2j.commons.lang.StringUtil;

import net.sf.l2j.gameserver.data.manager.FenceManager;
import net.sf.l2j.gameserver.data.manager.SpawnManager;
import net.sf.l2j.gameserver.data.xml.AdminData;
import net.sf.l2j.gameserver.data.xml.NpcData;
import net.sf.l2j.gameserver.handler.IAdminCommandHandler;
import net.sf.l2j.gameserver.model.World;
import net.sf.l2j.gameserver.model.WorldObject;
import net.sf.l2j.gameserver.model.actor.Npc;
import net.sf.l2j.gameserver.model.actor.Player;
import net.sf.l2j.gameserver.model.actor.instance.Fence;
import net.sf.l2j.gameserver.model.actor.template.NpcTemplate;
import net.sf.l2j.gameserver.model.location.SpawnLocation;
import net.sf.l2j.gameserver.model.spawn.ASpawn;
import net.sf.l2j.gameserver.model.spawn.MultiSpawn;
import net.sf.l2j.gameserver.model.spawn.Spawn;
import net.sf.l2j.gameserver.network.SystemMessageId;
import net.sf.l2j.gameserver.network.serverpackets.NpcHtmlMessage;
import net.sf.l2j.gameserver.network.serverpackets.SystemMessage;

public class AdminSpawn implements IAdminCommandHandler
{
	private static final String[] ADMIN_COMMANDS =
	{
		"admin_list_spawns",
		"admin_spawn",
		"admin_delete",
		"admin_recall_npc",
		"admin_unspawnall",
		"admin_respawnall",
		"admin_spawnfence",
		"admin_deletefence",
		"admin_listfence"
	};
	
	@Override
	public void useAdminCommand(String command, Player player)
	{
		if (command.startsWith("admin_list_spawns"))
		{
			final StringTokenizer st = new StringTokenizer(command, " ");
			st.nextToken();
			
			int npcId = 0;
			
			final String entry = (st.hasMoreTokens()) ? st.nextToken() : null;
			final int page = (st.hasMoreTokens()) ? Integer.parseInt(st.nextToken()) : 1;
			
			if (entry == null)
			{
				final Npc npc = getTarget(Npc.class, player, false);
				if (npc == null)
				{
					player.sendPacket(SystemMessageId.INVALID_TARGET);
					return;
				}
				
				npcId = npc.getNpcId();
			}
			else if (StringUtil.isDigit(entry))
				npcId = Integer.parseInt(entry);
			else
			{
				final NpcTemplate template = NpcData.getInstance().getTemplateByName(entry);
				if (template != null)
					npcId = template.getNpcId();
			}
			
			if (npcId == 0)
			{
				player.sendPacket(SystemMessageId.INVALID_TARGET);
				return;
			}
			
			int row = 0 + (8 * (page - 1));
			
			// Generate data.
			final Pagination<Npc> list = new Pagination<>(World.getInstance().getNpcs(npcId).stream(), page, PAGE_LIMIT_8);
			list.append("<html><body>");
			
			for (Npc npc : list)
			{
				list.append((row % 2) == 0 ? "<table width=280 height=41 bgcolor=000000><tr>" : "<table width=280 height=41><tr>");
				list.append("<td><a action=\"bypass -h admin_teleport ", npc.getX(), " ", npc.getY(), " ", npc.getZ(), "\">", row);
				
				final ASpawn spawn = npc.getSpawn();
				if (spawn == null)
					list.append(" - (", npc.getPosition(), ")", "</a>");
				else
					list.append(" - ", spawn, "</a><br1>", spawn.getDescription());
				
				list.append("</td></tr></table><img src=\"L2UI.SquareGray\" width=280 height=1>");
				
				row++;
			}
			
			list.generateSpace(42);
			list.generatePages("bypass admin_list_spawns " + npcId + " %page%");
			list.append("</body></html>");
			
			final NpcHtmlMessage html = new NpcHtmlMessage(0);
			html.setHtml(list.getContent());
			player.sendPacket(html);
		}
		else if (command.startsWith("admin_unspawnall"))
		{
			World.toAllOnlinePlayers(SystemMessage.getSystemMessage(SystemMessageId.NPC_SERVER_NOT_OPERATING));
			SpawnManager.getInstance().despawn();
			World.getInstance().deleteVisibleNpcSpawns();
			AdminData.getInstance().broadcastMessageToGMs("NPCs' unspawn is now complete.");
		}
		else if (command.startsWith("admin_respawnall"))
		{
			// make sure all spawns are deleted
			SpawnManager.getInstance().despawn();
			World.getInstance().deleteVisibleNpcSpawns();
			
			// now respawn all
			NpcData.getInstance().reload();
			SpawnManager.getInstance().reload();
			AdminData.getInstance().broadcastMessageToGMs("NPCs' respawn is now complete.");
		}
		else if (command.startsWith("admin_spawnfence"))
		{
			StringTokenizer st = new StringTokenizer(command, " ");
			try
			{
				st.nextToken();
				int type = Integer.parseInt(st.nextToken());
				int sizeX = (Integer.parseInt(st.nextToken()) / 100) * 100;
				int sizeY = (Integer.parseInt(st.nextToken()) / 100) * 100;
				int height = 1;
				if (st.hasMoreTokens())
					height = Math.min(Integer.parseInt(st.nextToken()), 3);
				
				FenceManager.getInstance().addFence(player.getX(), player.getY(), player.getZ(), type, sizeX, sizeY, height);
				
				listFences(player);
			}
			catch (Exception e)
			{
				player.sendMessage("Usage: //spawnfence <type> <width> <length> [height]");
			}
		}
		else if (command.startsWith("admin_deletefence"))
		{
			StringTokenizer st = new StringTokenizer(command, " ");
			st.nextToken();
			try
			{
				final WorldObject worldObject = World.getInstance().getObject(Integer.parseInt(st.nextToken()));
				if (worldObject instanceof Fence fence)
				{
					FenceManager.getInstance().removeFence(fence);
					
					if (st.hasMoreTokens())
						listFences(player);
				}
				else
					player.sendPacket(SystemMessageId.INVALID_TARGET);
			}
			catch (Exception e)
			{
				player.sendMessage("Usage: //deletefence <objectId>");
			}
		}
		else if (command.startsWith("admin_listfence"))
			listFences(player);
		else if (command.startsWith("admin_spawn"))
		{
			StringTokenizer st = new StringTokenizer(command, " ");
			try
			{
				final String cmd = st.nextToken();
				final String idOrName = st.nextToken();
				
				int respawnTime = 60;
				boolean isTemporary = false;
				
				// Remaining parameters are the respawn delay and the "temp" flag, in any order.
				while (st.hasMoreTokens())
				{
					final String token = st.nextToken();
					if (token.equalsIgnoreCase("temp"))
						isTemporary = true;
					else
						respawnTime = Integer.parseInt(token);
				}
				
				final WorldObject targetWorldObject = getTarget(WorldObject.class, player, true);
				
				NpcTemplate template;
				
				// First parameter was an ID number
				if (idOrName.matches("[0-9]*"))
					template = NpcData.getInstance().getTemplate(Integer.parseInt(idOrName));
				// First parameter wasn't just numbers, so go by name not ID
				else
					template = NpcData.getInstance().getTemplateByName(idOrName.replace('_', ' '));
				
				try
				{
					final Spawn spawn = new Spawn(template);
					spawn.setLoc(targetWorldObject.getPosition());
					spawn.setRespawnDelay(respawnTime);
					
					if (spawn.doSpawn(false) == null)
					{
						player.sendPacket(SystemMessageId.APPLICANT_INFORMATION_INCORRECT);
						return;
					}
					
					// A regular //spawn is stored in database and comes back on restart ; //spawn <id> temp doesn't.
					if (isTemporary)
						player.sendMessage("You spawned " + template.getName() + " until next restart. - Cmd: " + cmd);
					else if (SpawnManager.getInstance().addCustomSpawn(spawn, player.getName()))
						player.sendMessage("You spawned " + template.getName() + ", saved in database. - Cmd: " + cmd);
					else
						player.sendMessage("You spawned " + template.getName() + ", but it couldn't be saved in database. - Cmd: " + cmd);
				}
				catch (Exception e)
				{
					player.sendPacket(SystemMessageId.APPLICANT_INFORMATION_INCORRECT);
				}
			}
			catch (Exception e)
			{
				sendFile(player, "spawns.htm");
			}
		}
		else if (command.startsWith("admin_delete"))
		{
			// Target must be a Npc.
			final WorldObject targetWorldObject = player.getTarget();
			if (!(targetWorldObject instanceof Npc targetNpc))
			{
				player.sendPacket(SystemMessageId.INVALID_TARGET);
				return;
			}
			
			final String name = targetNpc.getName();
			final ASpawn spawn = targetNpc.getSpawn();
			
			// Individual spawn : GM-made ones own a "spawnlist_custom" row, script and quest ones own nothing.
			if (spawn instanceof Spawn individualSpawn)
			{
				final boolean wasStored = individualSpawn.getDbId() > 0;
				
				targetNpc.deleteMe();
				
				SpawnManager.getInstance().deleteSpawn(individualSpawn);
				SpawnManager.getInstance().deleteCustomSpawn(individualSpawn);
				
				player.sendMessage("You deleted " + name + (wasStored ? ", spawn list entry included." : ". It wasn't in the spawn list."));
			}
			// NpcMaker spawn : one NPC less on its "spawnlist_npcs" row, the row itself going away with the last one.
			else if (spawn instanceof MultiSpawn multiSpawn)
			{
				// Detach the Npc first, so the NpcMaker doesn't recognize it on decay and schedule a respawn.
				multiSpawn.removeNpc(targetNpc);
				targetNpc.cancelRespawn();
				targetNpc.deleteMe();
				
				if (SpawnManager.getInstance().deleteMakerSpawn(multiSpawn))
					player.sendMessage("You deleted " + name + " from the spawn list of " + multiSpawn.getNpcMaker().getName() + ".");
				else
					player.sendMessage("You deleted " + name + ", but the spawn list couldn't be updated.");
			}
			else
				player.sendPacket(SystemMessageId.INVALID_TARGET);
		}
		else if (command.startsWith("admin_recall_npc"))
		{
			// Target must be a Npc.
			final WorldObject targetWorldObject = player.getTarget();
			if (!(targetWorldObject instanceof Npc targetNpc))
			{
				player.sendPacket(SystemMessageId.INVALID_TARGET);
				return;
			}
			
			recallNpc(player, targetNpc);
		}
	}
	
	/**
	 * Move a {@link Npc} to a {@link Player} position and make it its new spawn point, so it respawns there.<br>
	 * <br>
	 * The move is stored in the spawn list when it is unambiguous : a GM-made {@link Spawn} owns its "spawnlist_custom" row, and a {@link MultiSpawn} owns its "spawnlist_npcs" row as long as that row holds a single NPC. Otherwise the move only lasts until next restart, since every NPC of a row shares its position.<br>
	 * <br>
	 * Note: a {@link MultiSpawn} NPC keeps walking around its NpcMaker territory, which the new position isn't part of - drop it far away and it will head back.
	 * @param player : The {@link Player} whose position is used.
	 * @param npc : The {@link Npc} to move.
	 */
	public static void recallNpc(Player player, Npc npc)
	{
		final SpawnLocation loc = player.getPosition().clone();
		
		npc.teleportTo(loc, 0);
		
		// Z is validated against geodata upon teleport ; keep where the Npc actually landed.
		loc.set(npc.getX(), npc.getY(), npc.getZ(), loc.getHeading());
		npc.setSpawnLocation(loc);
		
		final String name = npc.getName();
		final ASpawn spawn = npc.getSpawn();
		
		if (spawn instanceof Spawn individualSpawn)
		{
			individualSpawn.setLoc(loc);
			
			if (individualSpawn.getDbId() == 0)
				player.sendMessage("You moved " + name + " here. It isn't in the spawn list, so the move lasts until next restart.");
			else if (SpawnManager.getInstance().updateCustomSpawnLoc(individualSpawn))
				player.sendMessage("You moved " + name + " here, spawn list updated.");
			else
				player.sendMessage("You moved " + name + " here, but the spawn list couldn't be updated.");
		}
		else if (spawn instanceof MultiSpawn multiSpawn)
		{
			if (multiSpawn.getTotal() != 1)
				player.sendMessage("You moved " + name + " here. Its spawn list entry holds " + multiSpawn.getTotal() + " NPCs sharing one position, so the move lasts until it respawns.");
			else if (SpawnManager.getInstance().updateMakerSpawnPos(multiSpawn, loc))
				player.sendMessage("You moved " + name + " here, spawn list updated.");
			else
				player.sendMessage("You moved " + name + " here, but the spawn list couldn't be updated.");
		}
		else
			player.sendMessage("You moved " + name + " here. It has no spawn, so the move lasts until it respawns.");
	}
	
	@Override
	public String[] getAdminCommandList()
	{
		return ADMIN_COMMANDS;
	}
	
	private static void listFences(Player player)
	{
		final List<Fence> fences = FenceManager.getInstance().getFences();
		final StringBuilder sb = new StringBuilder();
		
		sb.append("<html><body>Total Fences: " + fences.size() + "<br><br>");
		for (Fence fence : fences)
			sb.append("<a action=\"bypass -h admin_deletefence " + fence.getObjectId() + " 1\">Fence: " + fence.getObjectId() + " [" + fence.getX() + " " + fence.getY() + " " + fence.getZ() + "]</a><br>");
		sb.append("</body></html>");
		
		final NpcHtmlMessage html = new NpcHtmlMessage(0);
		html.setHtml(sb.toString());
		player.sendPacket(html);
	}
}