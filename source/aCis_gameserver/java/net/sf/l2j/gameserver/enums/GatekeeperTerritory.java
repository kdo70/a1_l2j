package net.sf.l2j.gameserver.enums;

import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperPoint;

/**
 * The kind of ground a {@link GatekeeperPoint} sits on, shown on the action column of the teleport points lists.
 */
public enum GatekeeperTerritory
{
	TOWN("Town"),
	VILLAGE("Village"),
	FIELDS("Fields"),
	DUNGEON("Dungeon");

	private final String _label;

	GatekeeperTerritory(String label)
	{
		_label = label;
	}

	/**
	 * @return The label shown on the action column of the teleport points lists.
	 */
	public String getLabel()
	{
		return _label;
	}
}
