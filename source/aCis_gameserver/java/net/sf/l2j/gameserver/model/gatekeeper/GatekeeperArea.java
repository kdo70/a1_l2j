package net.sf.l2j.gameserver.model.gatekeeper;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * A group of {@link GatekeeperPoint}s, shown as a single row of the areas list page.<br>
 * <br>
 * A &lt;loc&gt; written next to the &lt;area&gt; nodes of a tab is wrapped into a "direct" area, holding that single point : its row teleports right away, instead of leading to a sub list. Both
 * kinds can be mixed on the very same page.
 */
public class GatekeeperArea
{
	private final List<GatekeeperPoint> _points = new ArrayList<>();

	private final int _index;
	private final String _name;
	private final String _capital;
	private final boolean _isDirect;

	public GatekeeperArea(int index, String name, String capital, boolean isDirect)
	{
		_index = index;
		_name = name;
		_capital = capital;
		_isDirect = isDirect;
	}

	@Override
	public String toString()
	{
		return "GatekeeperArea [_index=" + _index + ", _name=" + _name + ", _capital=" + _capital + ", _isDirect=" + _isDirect + ", _points=" + _points.size() + "]";
	}

	/**
	 * @return True if this area wraps a single {@link GatekeeperPoint}, whose row teleports the player instead of leading to a sub list.
	 */
	public boolean isDirect()
	{
		return _isDirect;
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
