package net.sf.l2j.gameserver.model.gatekeeper;

/**
 * A single column of a {@link GatekeeperTable}, entirely described by the &lt;layout&gt; node of data/xml/gatekeeper.xml.<br>
 * <br>
 * Both the header cell and the row cells of a list share that very same definition, which is the only way to keep them aligned.
 */
public class GatekeeperColumn
{
	private final String _id;
	private final String _header;
	private final int _width;
	private final int _maxChars;
	private final String _align;

	public GatekeeperColumn(String id, String header, int width, int maxChars, String align)
	{
		_id = id;
		_header = header;
		_width = Math.max(1, width);
		_maxChars = Math.max(0, maxChars);
		_align = align;
	}

	@Override
	public String toString()
	{
		return "GatekeeperColumn [_id=" + _id + ", _width=" + _width + ", _maxChars=" + _maxChars + "]";
	}

	public String getId()
	{
		return _id;
	}

	/**
	 * @return The caption shown on the header row of the list. An empty {@link String} generates an empty header cell.
	 */
	public String getHeader()
	{
		return _header;
	}

	public int getWidth()
	{
		return _width;
	}

	/**
	 * @return The amount of characters above which the cell content is shortened, 0 meaning "never shorten".
	 */
	public int getMaxChars()
	{
		return _maxChars;
	}

	/**
	 * @return The align attribute of the cell - "left", "center" or "right".
	 */
	public String getAlign()
	{
		return _align;
	}

	/**
	 * @param height : The height of the cell, 0 to let the client compute it.
	 * @param content : The already rendered content of the cell.
	 * @return This column, rendered as a single &lt;td&gt;.
	 */
	public String getCell(int height, String content)
	{
		final StringBuilder sb = new StringBuilder(64);

		sb.append("<td width=").append(_width);

		if (height > 0)
			sb.append(" height=").append(height);

		sb.append(" align=").append(_align).append('>').append(content).append("</td>");

		return sb.toString();
	}
}
