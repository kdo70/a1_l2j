package net.sf.l2j.gameserver.data.sql;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import net.sf.l2j.commons.logging.CLogger;
import net.sf.l2j.commons.pool.ConnectionPool;

import net.sf.l2j.gameserver.data.xml.ItemData;
import net.sf.l2j.gameserver.enums.DropType;
import net.sf.l2j.gameserver.model.actor.template.NpcTemplate;
import net.sf.l2j.gameserver.model.item.DropCategory;
import net.sf.l2j.gameserver.model.item.DropData;

/**
 * Loads and stores the {@link DropCategory}s of every {@link NpcTemplate}, held by the "droplist" table.<br>
 * <br>
 * One row is one item of one category of one NPC. Rows sharing (npc_id, category) form a single {@link DropCategory} ; its type and chance are properties of the whole category, so they are read from its first row and ignored on the following ones. Rows are grouped in a single pass, hence the ORDER BY.<br>
 * <br>
 * {@link NpcTemplate#getDropData()} reads through this table, which means {@link #reload()} is enough to apply a droplist edit on a running server - no NPC template reload involved. The map is swapped as a whole, so a reload can't be seen half-applied by a dying {@link net.sf.l2j.gameserver.model.actor.instance.Monster}.
 */
public class DropTable
{
	private static final CLogger LOGGER = new CLogger(DropTable.class.getName());
	
	private static final String LOAD_DROPS = "SELECT npc_id, category, drop_type, category_chance, item_id, min_count, max_count, chance FROM droplist WHERE enabled > 0 ORDER BY npc_id, category, order_id";
	
	private volatile Map<Integer, List<DropCategory>> _drops = Collections.emptyMap();
	
	protected DropTable()
	{
		load();
	}
	
	public void load()
	{
		final Map<Integer, List<DropCategory>> drops = new HashMap<>();
		
		int categories = 0;
		int items = 0;
		
		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement ps = con.prepareStatement(LOAD_DROPS);
			ResultSet rs = ps.executeQuery())
		{
			int currentNpcId = -1;
			int currentCategory = -1;
			DropCategory category = null;
			
			while (rs.next())
			{
				final int npcId = rs.getInt("npc_id");
				final int categoryId = rs.getInt("category");
				
				// First row of a category : create it. It is registered only once it holds a valid drop.
				if (category == null || npcId != currentNpcId || categoryId != currentCategory)
				{
					currentNpcId = npcId;
					currentCategory = categoryId;
					category = null;
					
					final String type = rs.getString("drop_type");
					try
					{
						category = new DropCategory(Enum.valueOf(DropType.class, type), rs.getDouble("category_chance"));
					}
					catch (IllegalArgumentException e)
					{
						LOGGER.warn("Droplist data for undefined drop type: {}, npcId: {}.", type, npcId);
						continue;
					}
				}
				
				final int itemId = rs.getInt("item_id");
				if (ItemData.getInstance().getTemplate(itemId) == null)
				{
					LOGGER.warn("Droplist data for undefined itemId: {}.", itemId);
					continue;
				}
				
				if (category.isEmpty())
				{
					drops.computeIfAbsent(npcId, k -> new ArrayList<>()).add(category);
					categories++;
				}
				
				category.add(new DropData(itemId, rs.getInt("min_count"), rs.getInt("max_count"), rs.getDouble("chance")));
				items++;
			}
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't load droplist.", e);
			return;
		}
		
		_drops = drops;
		
		LOGGER.info("Loaded {} drop categories ({} items) for {} NPCs.", categories, items, drops.size());
	}
	
	public void reload()
	{
		load();
	}
	
	/**
	 * @param npcId : The {@link NpcTemplate} id to check.
	 * @return the {@link List} of {@link DropCategory}s of a given {@link NpcTemplate} id, an empty {@link List} if it drops nothing.
	 */
	public List<DropCategory> getDrops(int npcId)
	{
		return _drops.getOrDefault(npcId, Collections.emptyList());
	}
	
	public static DropTable getInstance()
	{
		return SingletonHolder.INSTANCE;
	}
	
	private static class SingletonHolder
	{
		protected static final DropTable INSTANCE = new DropTable();
	}
}
