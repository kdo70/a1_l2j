package net.sf.l2j.gameserver.data.sql;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;

import net.sf.l2j.commons.logging.CLogger;
import net.sf.l2j.commons.pool.ConnectionPool;

import net.sf.l2j.Config;
import net.sf.l2j.gameserver.data.xml.RecipeData;
import net.sf.l2j.gameserver.enums.actors.OperateType;
import net.sf.l2j.gameserver.model.World;
import net.sf.l2j.gameserver.model.actor.Player;
import net.sf.l2j.gameserver.model.records.ManufactureItem;
import net.sf.l2j.gameserver.model.records.Recipe;
import net.sf.l2j.gameserver.model.trade.TradeItem;
import net.sf.l2j.gameserver.network.GameClient;
import net.sf.l2j.gameserver.network.GameClient.GameClientState;

/**
 * Stores on shutdown and restores on startup the offline shops : {@link Player}s who disconnected while their private shop was opened.
 */
public class OfflineTradersTable
{
	private static final CLogger LOGGER = new CLogger(OfflineTradersTable.class.getName());
	
	private static final String SAVE_OFFLINE_STATUS = "INSERT INTO character_offline_trade (charId, time, type, title) VALUES (?, ?, ?, ?)";
	private static final String SAVE_OFFLINE_ITEMS = "INSERT INTO character_offline_trade_items (charId, item, count, price) VALUES (?, ?, ?, ?)";
	private static final String CLEAR_OFFLINE_TABLE = "DELETE FROM character_offline_trade";
	private static final String CLEAR_OFFLINE_TABLE_ITEMS = "DELETE FROM character_offline_trade_items";
	private static final String LOAD_OFFLINE_STATUS = "SELECT * FROM character_offline_trade";
	private static final String LOAD_OFFLINE_ITEMS = "SELECT * FROM character_offline_trade_items WHERE charId = ?";
	
	protected OfflineTradersTable()
	{
	}
	
	/**
	 * Store all {@link Player}s currently holding an opened private shop into the database.
	 */
	public void storeOffliners()
	{
		int nTraders = 0;
		
		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement clearStatus = con.prepareStatement(CLEAR_OFFLINE_TABLE);
			PreparedStatement clearItems = con.prepareStatement(CLEAR_OFFLINE_TABLE_ITEMS);
			PreparedStatement saveStatus = con.prepareStatement(SAVE_OFFLINE_STATUS);
			PreparedStatement saveItems = con.prepareStatement(SAVE_OFFLINE_ITEMS))
		{
			clearStatus.execute();
			clearItems.execute();
			
			// Avoid half done saves.
			con.setAutoCommit(false);
			
			for (Player player : World.getInstance().getPlayers())
			{
				try
				{
					if (!player.isInStoreMode())
						continue;
					
					switch (player.getOperateType())
					{
						case BUY, SELL, PACKAGE_SELL:
							if (!Config.OFFLINE_TRADE_ENABLE)
								continue;
							break;
						
						case MANUFACTURE:
							if (!Config.OFFLINE_CRAFT_ENABLE)
								continue;
							break;
					}
					
					saveStatus.setInt(1, player.getObjectId());
					saveStatus.setLong(2, (player.getOfflineStartTime() > 0) ? player.getOfflineStartTime() : System.currentTimeMillis());
					saveStatus.setInt(3, player.getOperateType().getId());
					
					String title = null;
					
					switch (player.getOperateType())
					{
						case BUY:
							title = player.getBuyList().getTitle();
							
							for (TradeItem tradeItem : player.getBuyList())
							{
								saveItems.setInt(1, player.getObjectId());
								saveItems.setInt(2, tradeItem.getItemId());
								saveItems.setInt(3, tradeItem.getCount());
								saveItems.setInt(4, tradeItem.getPrice());
								saveItems.executeUpdate();
								saveItems.clearParameters();
							}
							break;
						
						case SELL, PACKAGE_SELL:
							title = player.getSellList().getTitle();
							
							for (TradeItem tradeItem : player.getSellList())
							{
								saveItems.setInt(1, player.getObjectId());
								saveItems.setInt(2, tradeItem.getObjectId());
								saveItems.setInt(3, tradeItem.getCount());
								saveItems.setInt(4, tradeItem.getPrice());
								saveItems.executeUpdate();
								saveItems.clearParameters();
							}
							break;
						
						case MANUFACTURE:
							title = player.getManufactureList().getStoreName();
							
							for (ManufactureItem manufactureItem : player.getManufactureList())
							{
								saveItems.setInt(1, player.getObjectId());
								saveItems.setInt(2, manufactureItem.recipeId());
								saveItems.setInt(3, 0);
								saveItems.setInt(4, manufactureItem.cost());
								saveItems.executeUpdate();
								saveItems.clearParameters();
							}
							break;
					}
					
					saveStatus.setString(4, title);
					saveStatus.executeUpdate();
					saveStatus.clearParameters();
					
					con.commit();
					nTraders++;
				}
				catch (Exception e)
				{
					LOGGER.error("Couldn't save offline trader {}.", e, player.getObjectId());
				}
			}
			
			LOGGER.info("Saved {} offline trader(s).", nTraders);
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't save offline traders.", e);
		}
	}
	
	/**
	 * Restore all previously stored offline shops from the database, and clean the offline tables.
	 */
	public void restoreOfflineTraders()
	{
		int nTraders = 0;
		
		try (Connection con = ConnectionPool.getConnection();
			PreparedStatement ps = con.prepareStatement(LOAD_OFFLINE_STATUS);
			ResultSet rs = ps.executeQuery())
		{
			while (rs.next())
			{
				final long time = rs.getLong("time");
				if (Config.OFFLINE_MAX_DAYS > 0 && time + Config.OFFLINE_MAX_DAYS * 86400000L <= System.currentTimeMillis())
					continue;
				
				final OperateType type = OperateType.getById(rs.getInt("type"));
				if (type == OperateType.NONE)
					continue;
				
				Player player = null;
				
				try
				{
					final GameClient client = new GameClient(null);
					client.setDetached(true);
					
					player = Player.restore(rs.getInt("charId"));
					if (player == null)
						continue;
					
					client.setPlayer(player);
					client.setAccountName(player.getAccountName());
					client.setState(GameClientState.IN_GAME);
					
					player.setClient(client);
					player.setOfflineStartTime(time);
					player.spawnMe(player.getX(), player.getY(), player.getZ());
					
					try (PreparedStatement itemsPs = con.prepareStatement(LOAD_OFFLINE_ITEMS))
					{
						itemsPs.setInt(1, player.getObjectId());
						
						try (ResultSet items = itemsPs.executeQuery())
						{
							switch (type)
							{
								case BUY:
									while (items.next())
									{
										if (player.getBuyList().addItemByItemId(items.getInt("item"), items.getInt("count"), items.getInt("price"), 0) == null)
											throw new IllegalStateException("Invalid buy list item.");
									}
									player.getBuyList().setTitle(rs.getString("title"));
									break;
								
								case SELL, PACKAGE_SELL:
									while (items.next())
									{
										if (player.getSellList().addItem(items.getInt("item"), items.getInt("count"), items.getInt("price")) == null)
											throw new IllegalStateException("Invalid sell list item.");
									}
									player.getSellList().setTitle(rs.getString("title"));
									player.getSellList().setPackaged(type == OperateType.PACKAGE_SELL);
									break;
								
								case MANUFACTURE:
									while (items.next())
									{
										final int recipeId = items.getInt("item");
										final Recipe recipe = RecipeData.getInstance().getRecipeList(recipeId);
										if (recipe == null)
											throw new IllegalStateException("Invalid manufacture recipe.");
										
										player.getManufactureList().add(new ManufactureItem(recipeId, items.getInt("price"), recipe.isDwarven()));
									}
									player.getManufactureList().setStoreName(rs.getString("title"));
									break;
							}
						}
					}
					
					player.sitDown();
					
					if (Config.OFFLINE_SET_NAME_COLOR)
						player.getAppearance().setNameColor(Config.OFFLINE_NAME_COLOR);
					
					player.setOperateType(type);
					player.setOnlineStatus(true, true);
					player.broadcastUserInfo();
					
					nTraders++;
				}
				catch (Exception e)
				{
					LOGGER.error("Couldn't load offline trader {}.", e, (player == null) ? 0 : player.getObjectId());
					
					if (player != null)
						player.deleteMe();
				}
			}
			
			try (Statement st = con.createStatement())
			{
				st.execute(CLEAR_OFFLINE_TABLE);
				st.execute(CLEAR_OFFLINE_TABLE_ITEMS);
			}
		}
		catch (Exception e)
		{
			LOGGER.error("Couldn't load offline traders.", e);
		}
		
		LOGGER.info("Loaded {} offline trader(s).", nTraders);
	}
	
	public static OfflineTradersTable getInstance()
	{
		return SingletonHolder.INSTANCE;
	}
	
	private static class SingletonHolder
	{
		protected static final OfflineTradersTable INSTANCE = new OfflineTradersTable();
	}
}
