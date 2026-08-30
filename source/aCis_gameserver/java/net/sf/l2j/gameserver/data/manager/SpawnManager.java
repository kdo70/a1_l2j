package net.sf.l2j.gameserver.data.manager;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

import net.sf.l2j.commons.data.StatSet;
import net.sf.l2j.commons.geometry.Triangle;
import net.sf.l2j.commons.geometry.algorithm.Kong;
import net.sf.l2j.commons.logging.CLogger;
import net.sf.l2j.commons.pool.ConnectionPool;

import net.sf.l2j.Config;
import net.sf.l2j.gameserver.data.xml.NpcData;
import net.sf.l2j.gameserver.enums.CabalType;
import net.sf.l2j.gameserver.enums.SealType;
import net.sf.l2j.gameserver.model.actor.Npc;
import net.sf.l2j.gameserver.model.actor.template.NpcTemplate;
import net.sf.l2j.gameserver.model.location.Location;
import net.sf.l2j.gameserver.model.location.Point2D;
import net.sf.l2j.gameserver.model.location.SpawnLocation;
import net.sf.l2j.gameserver.model.memo.SpawnMemo;
import net.sf.l2j.gameserver.model.records.PrivateData;
import net.sf.l2j.gameserver.model.spawn.ASpawn;
import net.sf.l2j.gameserver.model.spawn.MultiSpawn;
import net.sf.l2j.gameserver.model.spawn.NpcMaker;
import net.sf.l2j.gameserver.model.spawn.Spawn;
import net.sf.l2j.gameserver.model.spawn.SpawnData;
import net.sf.l2j.gameserver.model.spawn.Territory;
import net.sf.l2j.gameserver.scripting.Quest;

/**
 * Loads spawn list based on {@link Territory}s and {@link NpcMaker}s.<br>
 * Handles spawn/respawn/despawn of various {@link Npc} in the game using events.<br>
 * Locally stores individual {@link Spawn}s (e.g. quests, temporary spawned {@link Npc}s).<br>
 * Loads/stores {@link Npc}s' {@link SpawnData} to/from database.<br>
 * <br>
 * The whole spawn list lives in the database, spread over six tables : "spawnlist_territories" and
 * "spawnlist_territory_nodes" describe the polygons, "spawnlist_makers" and "spawnlist_maker_params" the spawn groups,
 * "spawnlist_npcs" (with "spawnlist_npc_params" and "spawnlist_npc_privates") the spawns themselves. A seventh table,
 * "spawnlist_custom", holds the {@link Spawn}s a GM created with //spawn ; those are the only individual {@link Spawn}s
 * which survive a restart.
 */
public class SpawnManager
{
	private static final CLogger LOGGER = new CLogger(SpawnManager.class.getName());
	
	private static final String LOAD_SPAWN_DATAS = "SELECT * FROM spawn_data ORDER BY name";
	private static final String TRUNCATE_SPAWN_DATAS = "TRUNCATE spawn_data";
	private static final String SAVE_SPAWN_DATAS = "INSERT INTO spawn_data (name, status, current_hp, current_mp, loc_x, loc_y, loc_z, heading, db_value, respawn_time) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
	
	private static final String LOAD_TERRITORIES = "SELECT name, min_z, max_z FROM spawnlist_territories";
	private static final String LOAD_TERRITORY_NODES = "SELECT territory, x, y FROM spawnlist_territory_nodes ORDER BY territory, order_id";
	private static final String LOAD_MAKERS = "SELECT name, territory, ban_territory, maximum_npcs, maker_type, event, spawn_time FROM spawnlist_makers WHERE enabled > 0 ORDER BY name";
	private static final String LOAD_MAKER_PARAMS = "SELECT maker, name, val FROM spawnlist_maker_params";
	private static final String LOAD_NPCS = "SELECT maker, order_id, npc_id, total, respawn, respawn_rand, pos, db_name FROM spawnlist_npcs WHERE enabled > 0 ORDER BY maker, order_id";
	private static final String LOAD_NPC_PARAMS = "SELECT maker, npc_order, name, val FROM spawnlist_npc_params";
	private static final String LOAD_NPC_PRIVATES = "SELECT maker, npc_order, npc_id, weight, respawn FROM spawnlist_npc_privates ORDER BY maker, npc_order, order_id";
	
	private static final String UPDATE_MAKER_SPAWN_TOTAL = "UPDATE spawnlist_npcs SET total = ? WHERE maker = ? AND order_id = ?";
	private static final String UPDATE_MAKER_SPAWN_POS = "UPDATE spawnlist_npcs SET pos = ? WHERE maker = ? AND order_id = ?";
	private static final String DELETE_MAKER_SPAWN = "DELETE FROM spawnlist_npcs WHERE maker = ? AND order_id = ?";
	private static final String DELETE_MAKER_SPAWN_PARAMS = "DELETE FROM spawnlist_npc_params WHERE maker = ? AND npc_order = ?";
	private static final String DELETE_MAKER_SPAWN_PRIVATES = "DELETE FROM spawnlist_npc_privates WHERE maker = ? AND npc_order = ?";
	
	private static final String LOAD_CUSTOM_SPAWNS = "SELECT id, npc_id, loc_x, loc_y, loc_z, heading, respawn_delay, respawn_random FROM spawnlist_custom WHERE enabled > 0 ORDER BY id";
	private static final String ADD_CUSTOM_SPAWN = "INSERT INTO spawnlist_custom (npc_id, loc_x, loc_y, loc_z, heading, respawn_delay, respawn_random, created_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
	private static final String UPDATE_CUSTOM_SPAWN = "UPDATE spawnlist_custom SET loc_x = ?, loc_y = ?, loc_z = ?, heading = ? WHERE id = ?";
	private static final String DELETE_CUSTOM_SPAWN = "DELETE FROM spawnlist_custom WHERE id = ?";
	
	private final Map<String, SpawnData> _spawnData = new ConcurrentHashMap<>();
	
	private final Set<Territory> _territories = ConcurrentHashMap.newKeySet();
	private final Set<NpcMaker> _makers = ConcurrentHashMap.newKeySet();
	private final Set<Spawn> _spawns = ConcurrentHashMap.newKeySet();
	
	private final List<Spawn> _customSpawns = new CopyOnWriteArrayList<>();
	
	private int _dynamicGroupId = 0;
	
	public SpawnManager()
	{
		load();
	}
	
	public void load()
	{
		loadSpawnData();
		LOGGER.info("Loaded {} spawn data.", _spawnData.size());
		
		loadTerritories();
		LOGGER.info("Loaded {} territories.", _territories.size());
		
		loadMakers();
		LOGGER.info("Loaded {} NPC makers.", _makers.size());
		
		loadCustomSpawns();
		LOGGER.info("Loaded {} custom spawns.", _customSpawns.size());
	}
	
	/**
	 * Load all {@link Territory}s from database. Nodes are read first and grouped by {@link Territory} name, hence the ORDER BY : the order of nodes is the order the polygon is walked, and triangulation depends on it.
	 */
	private void loadTerritories()
	{
		final Map<String, List<Point2D>> nodes = new HashMap<>();
		
		try (Connection con = ConnectionPool.getConnection();
			Statement st = con.createStatement();
			ResultSet rs = st.executeQuery(LOAD_TERRITORY_NODES))
		{
			while (rs.next())
				nodes.computeIfAbsent(rs.getString("territory"), k -> new ArrayList<>()).add(new Point2D(rs.getInt("x"), rs.getInt("y")));
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't load territory nodes.", e);
			return;
		}
		
		try (Connection con = ConnectionPool.getConnection();
			Statement st = con.createStatement();
			ResultSet rs = st.executeQuery(LOAD_TERRITORIES))
		{
			while (rs.next())
			{
				final String name = rs.getString("name");
				
				final List<Point2D> coords = nodes.get(name);
				if (coords == null)
				{
					LOGGER.warn("Territory \"{}\" holds no node.", name);
					continue;
				}
				
				try
				{
					_territories.add(new Territory(name, Kong.doTriangulation(coords), rs.getInt("min_z"), rs.getInt("max_z")));
				}
				catch (Exception e)
				{
					LOGGER.warn("Cannot load territory \"{}\", {}", name, e.getMessage());
				}
			}
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't load territories.", e);
		}
	}
	
	/**
	 * Load all {@link NpcMaker}s and their {@link MultiSpawn}s from database. Every satellite table is read as a whole and indexed by maker name first, so the makers themselves are built in a single pass.
	 */
	private void loadMakers()
	{
		final Map<String, Map<String, String>> makerParams = new HashMap<>();
		final Map<String, Map<Integer, SpawnMemo>> npcParams = new HashMap<>();
		final Map<String, Map<Integer, List<PrivateData>>> npcPrivates = new HashMap<>();
		final Map<String, List<StatSet>> npcs = new HashMap<>();
		
		try (Connection con = ConnectionPool.getConnection();
			Statement st = con.createStatement())
		{
			// Maker AI parameters. "@" is a datapack marker of a referenced value, it isn't part of the value itself.
			try (ResultSet rs = st.executeQuery(LOAD_MAKER_PARAMS))
			{
				while (rs.next())
					makerParams.computeIfAbsent(rs.getString("maker"), k -> new HashMap<>()).put(rs.getString("name"), rs.getString("val").replace("@", ""));
			}
			
			// Spawn AI parameters.
			try (ResultSet rs = st.executeQuery(LOAD_NPC_PARAMS))
			{
				while (rs.next())
					npcParams.computeIfAbsent(rs.getString("maker"), k -> new HashMap<>()).computeIfAbsent(rs.getInt("npc_order"), k -> new SpawnMemo()).put(rs.getString("name"), rs.getString("val"));
			}
			
			// Spawn privates.
			try (ResultSet rs = st.executeQuery(LOAD_NPC_PRIVATES))
			{
				while (rs.next())
					npcPrivates.computeIfAbsent(rs.getString("maker"), k -> new HashMap<>()).computeIfAbsent(rs.getInt("npc_order"), k -> new ArrayList<>()).add(new PrivateData(rs.getInt("npc_id"), rs.getInt("weight"), rs.getInt("respawn")));
			}
			
			// Spawns.
			try (ResultSet rs = st.executeQuery(LOAD_NPCS))
			{
				while (rs.next())
				{
					final StatSet set = new StatSet();
					set.set("order", rs.getInt("order_id"));
					set.set("npcId", rs.getInt("npc_id"));
					set.set("total", rs.getInt("total"));
					set.set("respawn", rs.getInt("respawn"));
					set.set("respawnRand", rs.getInt("respawn_rand"));
					
					final String pos = rs.getString("pos");
					if (pos != null)
						set.set("pos", pos);
					
					final String dbName = rs.getString("db_name");
					if (dbName != null)
						set.set("dbName", dbName);
					
					npcs.computeIfAbsent(rs.getString("maker"), k -> new ArrayList<>()).add(set);
				}
			}
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't load NPC makers content.", e);
			return;
		}
		
		try (Connection con = ConnectionPool.getConnection();
			Statement st = con.createStatement();
			ResultSet rs = st.executeQuery(LOAD_MAKERS))
		{
			while (rs.next())
			{
				final String name = rs.getString("name");
				
				final StatSet set = new StatSet();
				set.set("name", name);
				set.set("maximumNpcs", rs.getInt("maximum_npcs"));
				set.set("maker", rs.getString("maker_type"));
				set.set("aiParams", makerParams.getOrDefault(name, Collections.emptyMap()));
				
				final String event = rs.getString("event");
				if (event != null)
					set.set("event", event);
				
				final String spawnTime = rs.getString("spawn_time");
				if (spawnTime != null)
					set.set("spawnTime", spawnTime);
				
				// Retrieve the Territory.
				Territory territory = findTerritory(rs.getString("territory"));
				if (territory != null)
					set.put("t", territory);
				
				// Retrieve the banned Territory, if any.
				final String banName = rs.getString("ban_territory");
				if (banName != null)
				{
					territory = findTerritory(banName);
					if (territory != null)
						set.put("bt", territory);
				}
				
				final NpcMaker maker = new NpcMaker(set);
				
				// Feed MultiSpawn List.
				final List<MultiSpawn> spawns = new ArrayList<>();
				for (StatSet npc : npcs.getOrDefault(name, Collections.emptyList()))
				{
					// Get related NpcTemplate.
					final int npcId = npc.getInteger("npcId");
					final NpcTemplate template = NpcData.getInstance().getTemplate(npcId);
					if (template == null)
					{
						LOGGER.warn("NpcTemplate was not found for NPC id {} in NpcMaker name {}.", npcId, name);
						continue;
					}
					
					final int order = npc.getInteger("order");
					
					// Get the SpawnData or create a new one, if it doesn't exist.
					SpawnData spawnData = null;
					
					final String dbName = npc.getString("dbName", null);
					if (dbName != null)
						spawnData = _spawnData.computeIfAbsent(dbName, sd -> new SpawnData(dbName));
					
					try
					{
						final MultiSpawn multiSpawn = new MultiSpawn(maker, template, npc.getInteger("total"), npc.getInteger("respawn"), npc.getInteger("respawnRand"), npcPrivates.getOrDefault(name, Collections.emptyMap()).getOrDefault(order, Collections.emptyList()), npcParams.getOrDefault(name, Collections.emptyMap()).getOrDefault(order, new SpawnMemo()), parseCoords(npc.getString("pos", null)), spawnData);
						multiSpawn.setDbOrder(order);
						
						spawns.add(multiSpawn);
					}
					catch (Exception e)
					{
						LOGGER.error("Can't create MultiSpawn for maker {}, npc id {}", e, name, npcId);
					}
				}
				
				// Set spawns on the NpcMaker.
				maker.setSpawns(spawns);
				
				// Create a new NpcMaker and add it to the List.
				_makers.add(maker);
			}
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't load NPC makers.", e);
		}
	}
	
	/**
	 * Parse the "pos" column of a spawn row.
	 * @param pos : Either "X;Y;Z;heading" for a fixed spawn, or N times "X;Y;Z;heading;chance" for a random pick among fixed positions. Null means the spawn is random over the {@link NpcMaker} {@link Territory}.
	 * @return The coordinates set, null when no position is defined.
	 */
	private static int[][] parseCoords(String pos)
	{
		if (pos == null || pos.isEmpty())
			return null;
		
		final String[] loc = pos.split(";");
		
		// Fixed position (X, Y, Z, heading).
		if (loc.length < 5)
		{
			final int[][] coords = new int[1][4];
			coords[0][0] = Integer.parseInt(loc[0]);
			coords[0][1] = Integer.parseInt(loc[1]);
			coords[0][2] = Integer.parseInt(loc[2]);
			coords[0][3] = Integer.parseInt(loc[3]);
			
			return coords;
		}
		
		// Random position with chance (N x [X, Y, Z, heading, chance]).
		final int[][] coords = new int[loc.length / 5][5];
		for (int i = 0; i < loc.length / 5; i++)
		{
			coords[i][0] = Integer.parseInt(loc[i * 5]);
			coords[i][1] = Integer.parseInt(loc[i * 5 + 1]);
			coords[i][2] = Integer.parseInt(loc[i * 5 + 2]);
			coords[i][3] = Integer.parseInt(loc[i * 5 + 3]);
			coords[i][4] = Integer.parseInt(loc[i * 5 + 4].split("%")[0]);
		}
		
		return coords;
	}
	
	public SpawnData getSpawnData(String name)
	{
		return _spawnData.get(name);
	}
	
	/**
	 * Reload {@link Territory}s and {@link NpcMaker}s and spawn NPCs.
	 */
	public void reload()
	{
		// Save dynamic data.
		save();
		
		// Clear entries.
		_spawnData.clear();
		_territories.clear();
		_makers.clear();
		_spawns.clear();
		_customSpawns.clear();
		
		// Load and spawn.
		load();
		spawn();
	}
	
	/**
	 * Save NPC data.
	 */
	public void save()
	{
		// Update NPCs' spawn data.
		_makers.stream().map(NpcMaker::getSpawns).flatMap(List::stream).forEach(MultiSpawn::updateSpawnData);
		_spawns.forEach(Spawn::updateSpawnData);
		
		// Save spawn data.
		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement delete = con.prepareStatement(TRUNCATE_SPAWN_DATAS);
			PreparedStatement ps = con.prepareStatement(SAVE_SPAWN_DATAS))
		{
			// Delete all previous entries.
			delete.execute();
			
			// Save SpawnDatas.
			for (SpawnData data : _spawnData.values())
			{
				// Skip spawn data, which NPC did not spawn at all.
				byte status = data.getStatus();
				if (status < 0)
					continue;
				
				try
				{
					ps.setString(1, data.getName());
					ps.setInt(2, status);
					ps.setInt(3, data.getCurrentHp());
					ps.setInt(4, data.getCurrentMp());
					ps.setInt(5, data.getX());
					ps.setInt(6, data.getY());
					ps.setInt(7, data.getZ());
					ps.setInt(8, data.getHeading());
					ps.setInt(9, data.getDBValue());
					ps.setLong(10, data.getRespawnTime());
					ps.addBatch();
				}
				catch (Exception e)
				{
					LOGGER.warn("Couldn't save spawn data for name \"{}\".", e, data.getName());
				}
			}
			
			ps.executeBatch();
			
			LOGGER.info("Spawn data has been saved.");
		}
		catch (Exception e)
		{
			LOGGER.warn("Couldn't save spawn data.", e);
		}
	}
	
	/**
	 * Load all {@link SpawnData}s from database.
	 */
	private final void loadSpawnData()
	{
		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement ps = con.prepareStatement(LOAD_SPAWN_DATAS);
			ResultSet rs = ps.executeQuery();)
		{
			while (rs.next())
			{
				final String name = rs.getString("name");
				_spawnData.put(name, new SpawnData(name, rs));
			}
		}
		catch (Exception e)
		{
			LOGGER.warn("Couldn't load spawn data.", e);
		}
	}
	
	/**
	 * Load all GM-made {@link Spawn}s from database. They are only built here ; the actual spawn happens in {@link #spawn()}, since {@link NpcTemplate}s must already be loaded and the world ready.
	 */
	private final void loadCustomSpawns()
	{
		try (Connection con = ConnectionPool.getConnection();
			Statement st = con.createStatement();
			ResultSet rs = st.executeQuery(LOAD_CUSTOM_SPAWNS))
		{
			while (rs.next())
			{
				final int id = rs.getInt("id");
				final int npcId = rs.getInt("npc_id");
				
				final NpcTemplate template = NpcData.getInstance().getTemplate(npcId);
				if (template == null)
				{
					LOGGER.warn("NpcTemplate was not found for NPC id {} in custom spawn id {}.", npcId, id);
					continue;
				}
				
				try
				{
					final Spawn spawn = new Spawn(template);
					spawn.setDbId(id);
					spawn.setLoc(rs.getInt("loc_x"), rs.getInt("loc_y"), rs.getInt("loc_z"), rs.getInt("heading"));
					spawn.setRespawnDelay(rs.getInt("respawn_delay"));
					spawn.setRespawnRandom(rs.getInt("respawn_random"));
					
					_customSpawns.add(spawn);
				}
				catch (Exception e)
				{
					LOGGER.error("Can't create custom Spawn id {}, npc id {}", e, id, npcId);
				}
			}
		}
		catch (Exception e)
		{
			LOGGER.warn("Couldn't load custom spawns.", e);
		}
	}
	
	/**
	 * Store a GM-made {@link Spawn} into database, so it survives a restart, and register its row id on it.
	 * @param spawn : The {@link Spawn} to store. Its {@link Npc} is expected to be already spawned.
	 * @param creator : The name of the {@link net.sf.l2j.gameserver.model.actor.Player} who created it.
	 * @return True if the {@link Spawn} has been stored, false otherwise.
	 */
	public boolean addCustomSpawn(Spawn spawn, String creator)
	{
		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement ps = con.prepareStatement(ADD_CUSTOM_SPAWN, Statement.RETURN_GENERATED_KEYS))
		{
			ps.setInt(1, spawn.getNpcId());
			ps.setInt(2, spawn.getLocX());
			ps.setInt(3, spawn.getLocY());
			ps.setInt(4, spawn.getLocZ());
			ps.setInt(5, spawn.getHeading());
			ps.setInt(6, spawn.getRespawnDelay());
			ps.setInt(7, spawn.getRespawnRandom());
			ps.setString(8, creator);
			ps.setLong(9, System.currentTimeMillis());
			ps.executeUpdate();
			
			try (ResultSet rs = ps.getGeneratedKeys())
			{
				if (rs.next())
					spawn.setDbId(rs.getInt(1));
			}
			
			_customSpawns.add(spawn);
			return true;
		}
		catch (Exception e)
		{
			LOGGER.warn("Couldn't store custom spawn of NPC id {}.", e, spawn.getNpcId());
			return false;
		}
	}
	
	/**
	 * Drop a GM-made {@link Spawn} from database. Does nothing on a {@link Spawn} which was never stored (script and quest spawns).
	 * @param spawn : The {@link Spawn} to drop.
	 */
	public void deleteCustomSpawn(Spawn spawn)
	{
		_customSpawns.remove(spawn);
		
		final int dbId = spawn.getDbId();
		if (dbId == 0)
			return;
		
		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement ps = con.prepareStatement(DELETE_CUSTOM_SPAWN))
		{
			ps.setInt(1, dbId);
			ps.executeUpdate();
			
			spawn.setDbId(0);
		}
		catch (Exception e)
		{
			LOGGER.warn("Couldn't delete custom spawn id {}.", e, dbId);
		}
	}
	
	/**
	 * Drop one NPC from a {@link MultiSpawn}, both in memory and in the "spawnlist_npcs" table. The row holds an amount of NPCs, so it is decremented ; the last one takes the whole row away, AI parameters and privates included.<br>
	 * The {@link Npc} itself isn't touched, the caller is expected to have deleted it already.
	 * @param spawn : The {@link MultiSpawn} to shrink.
	 * @return True if the spawn list has been updated, false otherwise.
	 */
	public boolean deleteMakerSpawn(MultiSpawn spawn)
	{
		final String maker = spawn.getNpcMaker().getName();
		final int order = spawn.getDbOrder();
		final int total = spawn.getTotal() - 1;
		
		try (Connection con = ConnectionPool.getConnection())
		{
			if (total > 0)
			{
				try (PreparedStatement ps = con.prepareStatement(UPDATE_MAKER_SPAWN_TOTAL))
				{
					ps.setInt(1, total);
					ps.setString(2, maker);
					ps.setInt(3, order);
					ps.executeUpdate();
				}
			}
			else
			{
				for (String query : new String[]
				{
					DELETE_MAKER_SPAWN_PRIVATES,
					DELETE_MAKER_SPAWN_PARAMS,
					DELETE_MAKER_SPAWN
				})
				{
					try (PreparedStatement ps = con.prepareStatement(query))
					{
						ps.setString(1, maker);
						ps.setInt(2, order);
						ps.executeUpdate();
					}
				}
			}
			
			spawn.decreaseTotal();
			return true;
		}
		catch (Exception e)
		{
			LOGGER.warn("Couldn't delete spawn of NPC id {} from maker {}.", e, spawn.getNpcId(), maker);
			return false;
		}
	}
	
	/**
	 * Pin a {@link MultiSpawn} to given {@link SpawnLocation}, both in memory and in the "spawnlist_npcs" table.<br>
	 * All NPCs of a row share its position, so this is only called on a row holding a single NPC.
	 * @param spawn : The {@link MultiSpawn} to move.
	 * @param loc : The new {@link SpawnLocation}.
	 * @return True if the spawn list has been updated, false otherwise.
	 */
	public boolean updateMakerSpawnPos(MultiSpawn spawn, SpawnLocation loc)
	{
		final String maker = spawn.getNpcMaker().getName();
		final int order = spawn.getDbOrder();
		
		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement ps = con.prepareStatement(UPDATE_MAKER_SPAWN_POS))
		{
			ps.setString(1, loc.getX() + ";" + loc.getY() + ";" + loc.getZ() + ";" + loc.getHeading());
			ps.setString(2, maker);
			ps.setInt(3, order);
			ps.executeUpdate();
			
			spawn.setCoords(new int[][]
			{
				{
					loc.getX(),
					loc.getY(),
					loc.getZ(),
					loc.getHeading()
				}
			});
			return true;
		}
		catch (Exception e)
		{
			LOGGER.warn("Couldn't move spawn of NPC id {} from maker {}.", e, spawn.getNpcId(), maker);
			return false;
		}
	}
	
	/**
	 * Store the current {@link SpawnLocation} of a GM-made {@link Spawn} back into the "spawnlist_custom" table.
	 * @param spawn : The {@link Spawn} to update. Its location is expected to be set already.
	 * @return True if the row has been updated, false otherwise.
	 */
	public boolean updateCustomSpawnLoc(Spawn spawn)
	{
		final int dbId = spawn.getDbId();
		if (dbId == 0)
			return false;
		
		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement ps = con.prepareStatement(UPDATE_CUSTOM_SPAWN))
		{
			ps.setInt(1, spawn.getLocX());
			ps.setInt(2, spawn.getLocY());
			ps.setInt(3, spawn.getLocZ());
			ps.setInt(4, spawn.getHeading());
			ps.setInt(5, dbId);
			ps.executeUpdate();
			
			return true;
		}
		catch (Exception e)
		{
			LOGGER.warn("Couldn't move custom spawn id {}.", e, dbId);
			return false;
		}
	}
	
	/**
	 * Spawn all possible {@link Npc} to the world at server start.<br>
	 * Native, day/night, events allowed on start, Seven Signs, etc.
	 */
	public void spawn()
	{
		if (Config.NO_SPAWNS)
			return;
		
		// Spawn native NPCs (where on-start condition is met):
		// 1) without "event"
		// 2) with "event" + "onStart=true"
		long total = _makers.stream().filter(NpcMaker::isOnStart).mapToInt(NpcMaker::spawnAll).sum();
		LOGGER.info("Spawned {} NPCs.", total);
		
		// Spawn GM-made NPCs. doSpawn registers them back into the individual spawns set.
		long custom = _customSpawns.stream().filter(spawn -> spawn.doSpawn(false) != null).count();
		LOGGER.info("Spawned {} custom NPCs.", custom);
		
		// Spawn event NPCs.
		for (String event : Config.SPAWN_EVENTS)
			spawnEventNpcs(event, true);
		
		// Spawn Seven Signs NPCs.
		notifySevenSignsChange();
	}
	
	/**
	 * Spawn Seven Signs NPCs depending on period and status.
	 */
	public void notifySevenSignsChange()
	{
		// Despawn all SevenSigns NPCs.
		
		// Seal of Avarice NPCs.
		despawnEventNpcs("ssq_seal1_none", false);
		despawnEventNpcs("ssq_seal1_dawn", false);
		despawnEventNpcs("ssq_seal1_twilight", false);
		
		// Seal of Gnosis NPCs.
		despawnEventNpcs("ssq_seal2_none", false);
		despawnEventNpcs("ssq_seal2_dawn", false);
		despawnEventNpcs("ssq_seal2_twilight", false);
		
		// Event NPCs.
		despawnEventNpcs("ssq_event", false);
		
		// Spawn required Seven Signs NPCs.
		switch (SevenSignsManager.getInstance().getCurrentPeriod())
		{
			case RECRUITING, COMPETITION:
				// Spawn Seven Signs event NPCs.
				long spawn = spawnEventNpcs("ssq_event", false);
				LOGGER.info("Spawned {} Seven Signs - Event NPCs.", spawn);
				break;
			
			case RESULTS, SEAL_VALIDATION:
				// Get this period Seven Signs winner.
				final CabalType cabalWon = SevenSignsManager.getInstance().getWinningCabal();
				
				// Check Seal of Avarice winner.
				switch (SevenSignsManager.getInstance().getSealOwner(SealType.AVARICE))
				{
					case NORMAL:
						spawn = spawnEventNpcs("ssq_seal1_none", false);
						LOGGER.info("Spawned {} Seven Signs - Seal of Avarice NPCs, winning cabal none.", spawn);
						break;
					
					case DUSK:
						if (cabalWon == CabalType.DUSK)
						{
							spawn = spawnEventNpcs("ssq_seal1_twilight", false);
							LOGGER.info("Spawned {} Seven Signs - Seal of Avarice NPCs, winning cabal Dusk.", spawn);
						}
						else
						{
							spawn = spawnEventNpcs("ssq_seal1_none", false);
							LOGGER.info("Spawned {} Seven Signs - Seal of Avarice NPCs, winning cabal Dawn, seal cabal Dusk.", spawn);
						}
						break;
					
					case DAWN:
						if (cabalWon == CabalType.DAWN)
						{
							spawn = spawnEventNpcs("ssq_seal1_dawn", false);
							LOGGER.info("Spawned {} Seven Signs - Seal of Avarice NPCs, winning cabal Dawn.", spawn);
						}
						else
						{
							spawn = spawnEventNpcs("ssq_seal1_none", false);
							LOGGER.info("Spawned {} Seven Signs - Seal of Avarice NPCs, winning cabal Dusk, seal cabal Dawn.", spawn);
						}
						break;
				}
				
				// Check Seal of Gnosis winner.
				switch (SevenSignsManager.getInstance().getSealOwner(SealType.GNOSIS))
				{
					case NORMAL:
						spawn = spawnEventNpcs("ssq_seal2_none", false);
						LOGGER.info("Spawned {} Seven Signs - Seal of Gnosis NPCs, winning cabal none.", spawn);
						break;
					
					case DUSK:
						if (cabalWon == CabalType.DUSK)
						{
							spawn = spawnEventNpcs("ssq_seal2_twilight", false);
							LOGGER.info("Spawned {} Seven Signs - Seal of Gnosis NPCs, winning cabal Dusk.", spawn);
						}
						else
						{
							spawn = spawnEventNpcs("ssq_seal2_none", false);
							LOGGER.info("Spawned {} Seven Signs - Seal of Gnosis NPCs, winning cabal Dawn, seal cabal Dusk.", spawn);
						}
						break;
					
					case DAWN:
						if (cabalWon == CabalType.DAWN)
						{
							spawn = spawnEventNpcs("ssq_seal2_dawn", false);
							LOGGER.info("Spawned {} Seven Signs - Seal of Gnosis NPCs, winning cabal Dawn.", spawn);
						}
						else
						{
							spawn = spawnEventNpcs("ssq_seal2_none", false);
							LOGGER.info("Spawned {} Seven Signs - Seal of Gnosis NPCs, winning cabal Dusk, seal cabal Dawn.", spawn);
						}
						break;
				}
				break;
		}
	}
	
	/**
	 * Despawn all NPCs from {@link NpcMaker} and individual spawns.
	 */
	public final void despawn()
	{
		// Despawn all NPCs from NpcMakers.
		long total = _makers.stream().mapToInt(NpcMaker::deleteAll).sum();
		LOGGER.info("Despawned {} NPCs.", total);
		
		// Despawn all NPCs from individual spawns.
		_spawns.forEach(Spawn::doDelete);
	}
	
	/**
	 * @param name : The name.
	 * @return the {@link Territory} of given ID, null when none.
	 */
	public final Territory getTerritory(String name)
	{
		return _territories.stream().filter(t -> t.getName().equalsIgnoreCase(name)).findFirst().orElse(null);
	}
	
	/**
	 * @param names : The name(s) of the {@link Territory}(s).
	 * @return the {@link Territory} of given name(s).
	 */
	private final Territory findTerritory(String names)
	{
		final String[] list = names.split(";");
		if (list.length == 0)
			return null;
		
		// A single territory is defined.
		if (list.length == 1)
			return getTerritory(list[0]);
		
		// Collect territories informations.
		final String groupedName = "grouped_" + String.format("%03d", _dynamicGroupId++);
		final List<Triangle> shapes = new ArrayList<>();
		
		int minZ = Integer.MAX_VALUE;
		int maxZ = Integer.MIN_VALUE;
		
		for (String name : list)
		{
			final Territory territory = getTerritory(name);
			if (territory == null)
			{
				LOGGER.warn("Territory {} does not exist.", name);
				return null;
			}
			
			minZ = Math.min(minZ, territory.getMinZ());
			maxZ = Math.max(maxZ, territory.getMaxZ());
			
			shapes.addAll(territory.getShapes());
		}
		
		// Create a new Territory.
		final Territory t = new Territory(groupedName, shapes, minZ, maxZ);
		
		_territories.add(t);
		return t;
	}
	
	/**
	 * @param loc : The {@link Location} to test.
	 * @return the {@link List} of all {@link NpcMaker}s at a given {@link Location}.
	 */
	public final List<NpcMaker> getNpcMakers(Location loc)
	{
		return _makers.stream().filter(m -> m.getTerritory().isInside(loc)).toList();
	}
	
	/**
	 * @param name : The {@link String} used as name.
	 * @return the {@link NpcMaker} of given name, null when none.
	 */
	public final NpcMaker getNpcMaker(String name)
	{
		return _makers.stream().filter(nm -> nm.getName().equalsIgnoreCase(name)).findFirst().orElse(null);
	}
	
	/**
	 * Add {@link Quest} to {@link NpcMaker} of given name, to handle all NPCs being dead event.
	 * @param name : The name.
	 * @param quest : The {@link Quest} to be added.
	 */
	public final void addQuestEventByName(String name, Quest quest)
	{
		_makers.stream().filter(nm -> nm.getName().equalsIgnoreCase(name)).forEach(nm -> nm.addQuestEvent(quest));
	}
	
	/**
	 * Add {@link Quest} to {@link NpcMaker} of given event name, to handle all NPCs being dead event.
	 * @param event : The event name.
	 * @param quest : The {@link Quest} to be added.
	 */
	public final void addQuestEventByEvent(String event, Quest quest)
	{
		_makers.stream().filter(nm -> event.equals(nm.getEvent())).forEach(nm -> nm.addQuestEvent(quest));
	}
	
	/**
	 * Spawn NPCs with given event name.
	 * @param event : Type of spawn.
	 * @param message : When true, display LOGGER message about spawn.
	 * @return the amount of spawned NPCs.
	 */
	public final long spawnEventNpcs(String event, boolean message)
	{
		if (event == null || event.length() == 0)
			return 0;
		
		long total = _makers.stream().filter(nm -> event.equals(nm.getEvent())).mapToInt(NpcMaker::spawnAll).sum();
		
		if (message)
			LOGGER.info("Spawned {} \"{}\" NPCs.", total, event);
		
		return total;
	}
	
	/**
	 * Immediately respawn all dead NPCs in {@link NpcMaker}s with given event name.<br>
	 * Currently running respawn tasks are canceled.
	 * @param event : Type of spawn.
	 * @param message : When true, display LOGGER message about spawn.
	 * @return the amount of spawned NPCs.
	 */
	public final long respawnEventNpcs(String event, boolean message)
	{
		if (event == null || event.length() == 0)
			return 0;
		
		long total = _makers.stream().filter(nm -> event.equals(nm.getEvent())).mapToInt(NpcMaker::respawnAll).sum();
		
		if (message)
			LOGGER.info("Respawned {} \"{}\" NPCs.", total, event);
		
		return total;
	}
	
	/**
	 * Despawn NPCs in {@link NpcMaker}s with given event name.
	 * @param event : Type of spawn.
	 * @param message : When true, display LOGGER message about despawn.
	 * @return the mount of despawned NPCs.
	 */
	public final long despawnEventNpcs(String event, boolean message)
	{
		if (event == null || event.length() == 0)
			return 0;
		
		long total = _makers.stream().filter(nm -> event.equals(nm.getEvent())).mapToInt(NpcMaker::deleteAll).sum();
		
		if (message)
			LOGGER.info("Despawned {} \"{}\" NPCs.", total, event);
		
		return total;
	}
	
	/**
	 * Spawn NPCs with given event name.
	 * @param time : time to spawn.
	 * @param param1 : time to spawn parameter 1.
	 * @param param2 : time to spawn parameter 2.
	 * @param param3 : time to spawn parameter 3.
	 * @param message : When true, display LOGGER message about spawn.
	 * @return the amount of spawned NPCs.
	 */
	public final long startSpawnTime(String time, String param1, String param2, String param3, boolean message)
	{
		if (time == null || time.isEmpty())
			return 0;
		
		long total = _makers.stream().filter(nm ->
		{
			if (nm.getMakerSpawnTime() == null)
				return false;
			
			if (!time.equalsIgnoreCase(nm.getMakerSpawnTime().getName()))
				return false;
			
			final String[] spawnTimeParams = nm.getMakerSpawnTimeParams();
			if (spawnTimeParams == null)
				return false;
			
			if (spawnTimeParams.length > 0)
			{
				if (param1 == null)
					return false;
				
				if (!param1.equalsIgnoreCase(spawnTimeParams[0]))
					return false;
				
				if (spawnTimeParams.length > 1)
				{
					if (param2 == null)
						return false;
					
					if (!param2.equalsIgnoreCase(spawnTimeParams[1]))
						return false;
				}
				
				if (spawnTimeParams.length > 2)
				{
					if (param3 == null)
						return false;
					
					if (!param3.equalsIgnoreCase(spawnTimeParams[2]))
						return false;
				}
			}
			
			return true;
		}).mapToInt(NpcMaker::spawnAll).sum();
		
		if (message)
			LOGGER.info("Spawned {} \"{}\" NPCs.", total, time);
		
		return total;
	}
	
	/**
	 * Despawn NPCs in {@link NpcMaker}s with given event name.
	 * @param time : time to despawn.
	 * @param param1 : time to despawn parameter 1.
	 * @param param2 : time to despawn parameter 2.
	 * @param param3 : time to despawn parameter 3.
	 * @param message : When true, display LOGGER message about despawn.
	 * @return the mount of despawned NPCs.
	 */
	public final long stopSpawnTime(String time, String param1, String param2, String param3, boolean message)
	{
		if (time == null || time.isEmpty())
			return 0;
		
		long total = _makers.stream().filter(nm ->
		{
			if (nm.getMakerSpawnTime() == null)
				return false;
			
			if (!time.equalsIgnoreCase(nm.getMakerSpawnTime().getName()))
				return false;
			
			final String[] spawnTimeParams = nm.getMakerSpawnTimeParams();
			if (spawnTimeParams == null)
				return false;
			
			if (spawnTimeParams.length > 0)
			{
				if (param1 == null)
					return false;
				
				if (!param1.equalsIgnoreCase(spawnTimeParams[0]))
					return false;
				
				if (spawnTimeParams.length > 1)
				{
					if (param2 == null)
						return false;
					
					if (!param2.equalsIgnoreCase(spawnTimeParams[1]))
						return false;
				}
				
				if (spawnTimeParams.length > 2)
				{
					if (param3 == null)
						return false;
					
					if (!param3.equalsIgnoreCase(spawnTimeParams[2]))
						return false;
				}
			}
			
			return true;
		}).mapToInt(NpcMaker::deleteAll).sum();
		
		if (message)
			LOGGER.info("Despawned {} \"{}\" NPCs.", total, time);
		
		return total;
	}
	
	/**
	 * Add an individual {@link Spawn}.
	 * @param spawn : {@link Spawn} to be added.
	 */
	public void addSpawn(Spawn spawn)
	{
		_spawns.add(spawn);
	}
	
	/**
	 * Remove an individual {@link Spawn}.
	 * @param spawn : {@link Spawn} to be removed.
	 */
	public void deleteSpawn(Spawn spawn)
	{
		_spawns.remove(spawn);
	}
	
	/**
	 * @param npcId : The {@link Npc} ID.
	 * @return The first found {@link ASpawn} of given {@link Npc}.
	 */
	public final ASpawn getSpawn(int npcId)
	{
		ASpawn result = _makers.stream().flatMap(nm -> nm.getSpawns().stream()).filter(ms -> ms.getNpcId() == npcId).findFirst().orElse(null);
		if (result == null)
			result = _spawns.stream().filter(s -> s.getNpcId() == npcId).findFirst().orElse(null);
		
		return result;
	}
	
	/**
	 * @param npcAlias : The {@link Npc} ID.
	 * @return The first found {@link ASpawn} of given {@link Npc}.
	 */
	public final ASpawn getSpawn(String npcAlias)
	{
		ASpawn result = _makers.stream().flatMap(nm -> nm.getSpawns().stream()).filter(ms -> ms.getTemplate().getAlias().equalsIgnoreCase(npcAlias)).findFirst().orElse(null);
		if (result == null)
			result = _spawns.stream().filter(s -> s.getTemplate().getAlias().equalsIgnoreCase(npcAlias)).findFirst().orElse(null);
		
		return result;
	}
	
	/**
	 * @param npcId : The {@link Npc} ID.
	 * @return The first found {@link Npc} of given npcId.
	 */
	public final Npc getNpc(int npcId)
	{
		final ASpawn spawn = getSpawn(npcId);
		if (spawn == null)
			return null;
		
		return spawn.getNpc();
	}
	
	public static final SpawnManager getInstance()
	{
		return SingletonHolder.INSTANCE;
	}
	
	private static class SingletonHolder
	{
		protected static final SpawnManager INSTANCE = new SpawnManager();
	}
}