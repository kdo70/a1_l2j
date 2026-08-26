package net.sf.l2j.gameserver.model.gatekeeper;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * The column set of a single generated list page, described by a &lt;table&gt; node of the &lt;layout&gt; of data/xml/gatekeeper.xml.<br>
 * <br>
 * The script refers to the columns by their id, so a missing column simply falls back on a hidden one instead of breaking the whole dialog.
 */
public class GatekeeperTable
{
	/** Fallback used when the XML doesn't define a column the script asks for ; it renders a narrow, empty cell. */
	private static final GatekeeperColumn MISSING_COLUMN = new GatekeeperColumn("?", "", 1, 0, "left");

	private final Map<String, GatekeeperColumn> _columns = new LinkedHashMap<>();

	private final String _id;
	private final int _overhead;

	public GatekeeperTable(String id, int overhead)
	{
		_id = id;
		_overhead = Math.max(0, overhead);
	}

	@Override
	public String toString()
	{
		return "GatekeeperTable [_id=" + _id + ", _overhead=" + _overhead + ", _columns=" + _columns.keySet() + "]";
	}

	public String getId()
	{
		return _id;
	}

	/**
	 * @return The height, in pixels, everything but the list rows and the tab bar takes on the HTM of this page - texts, separators, headline, header row and page selector included. Substracted
	 *         from the layout page height to know how much the list has to be padded with.
	 */
	public int getOverhead()
	{
		return _overhead;
	}

	public void addColumn(GatekeeperColumn column)
	{
		_columns.put(column.getId(), column);
	}

	/**
	 * @param id : The column id to retrieve.
	 * @return The {@link GatekeeperColumn} matching the given id, never null.
	 */
	public GatekeeperColumn getColumn(String id)
	{
		return _columns.getOrDefault(id, MISSING_COLUMN);
	}

	public List<GatekeeperColumn> getColumns()
	{
		return Collections.unmodifiableList(new ArrayList<>(_columns.values()));
	}

	/**
	 * @return The sum of the widths of every column, which is the width the enclosing table must own.
	 */
	public int getWidth()
	{
		return _columns.values().stream().mapToInt(GatekeeperColumn::getWidth).sum();
	}
}
