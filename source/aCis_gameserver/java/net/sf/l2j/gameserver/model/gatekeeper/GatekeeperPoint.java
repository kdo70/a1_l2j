package net.sf.l2j.gameserver.model.gatekeeper;

import net.sf.l2j.gameserver.data.xml.GatekeeperData;
import net.sf.l2j.gameserver.enums.GatekeeperPointType;
import net.sf.l2j.gameserver.model.actor.Player;
import net.sf.l2j.gameserver.model.location.Location;

/**
 * A datatype extending {@link Location}, used to retain a single Gatekeeper teleport point.<br>
 * <br>
 * Contrary to {@link net.sf.l2j.gameserver.model.location.TeleportLocation}, a point owns a unique id, which is used as the database key of its teleport counter.
 */
public class GatekeeperPoint extends Location
{
	/** Written between the name and the sub-point name of {@link #getFullName()}, and used by the script to color both halves apart. */
	public static final String POINT_SEPARATOR = " - ";

	private final int _id;
	private final String _name;
	private final String _point;
	private final GatekeeperPointType _type;
	private final int _priceId;
	private final int _price;
	private final int _castleId;
	private final int _minLevel;
	private final int _maxLevel;

	public GatekeeperPoint(int id, String name, String point, GatekeeperPointType type, int priceId, int price, int castleId, int minLevel, int maxLevel, int x, int y, int z)
	{
		super(x, y, z);

		_id = id;
		_name = name;
		_point = point;
		_type = type;
		_priceId = priceId;
		_price = price;
		_castleId = castleId;
		_minLevel = minLevel;
		_maxLevel = maxLevel;
	}

	@Override
	public String toString()
	{
		return "GatekeeperPoint [_id=" + _id + ", _name=" + getFullName() + ", _type=" + _type + ", _priceId=" + _priceId + ", _price=" + _price + ", _castleId=" + _castleId + "]";
	}

	public int getId()
	{
		return _id;
	}

	public String getName()
	{
		return _name;
	}

	public String getPoint()
	{
		return _point;
	}

	/**
	 * @return The name of the point, suffixed by its sub-point name (if any).
	 */
	public String getFullName()
	{
		return (_point.isEmpty()) ? _name : _name + POINT_SEPARATOR + _point;
	}

	public GatekeeperPointType getType()
	{
		return _type;
	}

	public int getPriceId()
	{
		return _priceId;
	}

	/**
	 * @return The XML defined price, -1 when unset - which means the price is derived from the distance.
	 */
	public int getPrice()
	{
		return _price;
	}

	public int getCastleId()
	{
		return _castleId;
	}

	public int getMinLevel()
	{
		return _minLevel;
	}

	public int getMaxLevel()
	{
		return _maxLevel;
	}

	/**
	 * @param player : The {@link Player} to test.
	 * @return True if the {@link Player} fulfills noblesse and level conditions of this {@link GatekeeperPoint}.
	 */
	public boolean isAvailableFor(Player player)
	{
		if (_type == GatekeeperPointType.NOBLE && !player.isNoble())
			return false;

		final int level = player.getStatus().getLevel();
		return level >= _minLevel && level <= _maxLevel;
	}

	/**
	 * @param player : The {@link Player} to test.
	 * @return The price to pay, computed by {@link GatekeeperData#getCalculatedPrice(Player, GatekeeperPoint)}.
	 */
	public int getCalculatedPrice(Player player)
	{
		return GatekeeperData.getInstance().getCalculatedPrice(player, this);
	}
}
