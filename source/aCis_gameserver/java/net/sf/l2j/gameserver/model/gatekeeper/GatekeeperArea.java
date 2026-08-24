package net.sf.l2j.gameserver.model.gatekeeper;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * A group of {@link GatekeeperPoint}s, shown as a single row of the areas list page.
 */
public class GatekeeperArea
{
	private final List<GatekeeperPoint> _points = new ArrayList<>();

	private final int _index;
	private final String _name;
	private final String _capital;

	public GatekeeperArea(int index, String name, String capital)
	{
		_index = index;
		_name = name;
		_capital = capital;
	}

	@Override
	public String toString()
	{
		return "GatekeeperArea [_index=" + _index + ", _name=" + _name + ", _capital=" + _capital + ", _points=" + _points.size() + "]";
	}

	public int getIndex()
	{
		return _index;
	}

	public String getName()
	{
		return _name;
	}

	public String getCapital()
	{
		return _capital;
	}

	public List<GatekeeperPoint> getPoints()
	{
		return Collections.unmodifiableList(_points);
	}

	public void addPoint(GatekeeperPoint point)
	{
		_points.add(point);
	}

	/**
	 * @return The first {@link GatekeeperPoint} of this area, which is used as price reference on the areas list page - null if the area is empty.
	 */
	public GatekeeperPoint getMainPoint()
	{
		return (_points.isEmpty()) ? null : _points.get(0);
	}
}
