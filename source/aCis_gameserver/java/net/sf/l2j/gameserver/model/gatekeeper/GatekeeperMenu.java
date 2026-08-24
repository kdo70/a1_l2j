package net.sf.l2j.gameserver.model.gatekeeper;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import net.sf.l2j.gameserver.enums.GatekeeperTabType;

/**
 * A whole Gatekeeper dialog, being a {@link List} of {@link GatekeeperTab}s. Multiple Npcs can share the same menu.
 */
public class GatekeeperMenu
{
	private final List<GatekeeperTab> _tabs = new ArrayList<>();

	/** Holds every {@link GatekeeperPoint} reachable from this menu, used as bypass whitelist. */
	private final Map<Integer, GatekeeperPoint> _points = new HashMap<>();

	private final int _id;

	public GatekeeperMenu(int id)
	{
		_id = id;
	}

	@Override
	public String toString()
	{
		return "GatekeeperMenu [_id=" + _id + ", _tabs=" + _tabs.size() + ", _points=" + _points.size() + "]";
	}

	public int getId()
	{
		return _id;
	}

	public List<GatekeeperTab> getTabs()
	{
		return Collections.unmodifiableList(_tabs);
	}

	public void addTab(GatekeeperTab tab)
	{
		_tabs.add(tab);
	}

	public GatekeeperTab getTab(int index)
	{
		return (index < 0 || index >= _tabs.size()) ? null : _tabs.get(index);
	}

	/**
	 * @return The {@link GatekeeperTab} shown when the {@link net.sf.l2j.gameserver.model.actor.Player} initially talks to the Npc - being the first areas holder tab, or the first tab.
	 */
	public GatekeeperTab getDefaultTab()
	{
		for (GatekeeperTab tab : _tabs)
		{
			if (tab.getType() == GatekeeperTabType.AREAS)
				return tab;
		}
		return getTab(0);
	}

	public void addPoint(GatekeeperPoint point)
	{
		_points.put(point.getId(), point);
	}

	/**
	 * @param id : The {@link GatekeeperPoint} id to retrieve.
	 * @return The {@link GatekeeperPoint} of this menu, or null if this menu doesn't hold it. Acts as a bypass whitelist.
	 */
	public GatekeeperPoint getPoint(int id)
	{
		return _points.get(id);
	}

	public Map<Integer, GatekeeperPoint> getPoints()
	{
		return Collections.unmodifiableMap(_points);
	}
}
