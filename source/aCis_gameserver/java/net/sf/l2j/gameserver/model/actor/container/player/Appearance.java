package net.sf.l2j.gameserver.model.actor.container.player;

import net.sf.l2j.gameserver.enums.actors.Sex;

public final class Appearance
{
	/** The pure white the datapack means when it asks for a white name, and which never reaches the client - see {@link #WHITE}. */
	private static final int PURE_WHITE = 0xFFFFFF;

	/**
	 * The white a name is actually drawn with, one single shade off the pure one.<br>
	 * <br>
	 * A pure white travels to the client as 0x00FFFFFF and comes out of it as 0xFFFFFFFF once the alpha is filled in - which is exactly -1, the value the engine reads as <b>"this name owns no color
	 * at all"</b>. Such a name falls through to the level gap gradient the engine then applies, and that gradient is what drew characters in pale blue instead of white.<br>
	 * <br>
	 * One shade off reads as white to the eye and isn't that flag, so the color the server sent is the color the client draws. See docs/npc-name-colors.md, which walks that very engine function.
	 */
	private static final int WHITE = 0xFEFEFE;

	private byte _face;
	private byte _hairColor;
	private byte _hairStyle;
	private Sex _sex;
	private boolean _isVisible = true;
	private int _nameColor = WHITE;
	private int _titleColor = 0xFFFF77;
	
	public Appearance(byte face, byte hColor, byte hStyle, Sex sex)
	{
		_face = face;
		_hairColor = hColor;
		_hairStyle = hStyle;
		_sex = sex;
	}
	
	public byte getFace()
	{
		return _face;
	}
	
	public void setFace(int value)
	{
		_face = (byte) value;
	}
	
	public byte getHairColor()
	{
		return _hairColor;
	}
	
	public void setHairColor(int value)
	{
		_hairColor = (byte) value;
	}
	
	public byte getHairStyle()
	{
		return _hairStyle;
	}
	
	public void setHairStyle(int value)
	{
		_hairStyle = (byte) value;
	}
	
	public Sex getSex()
	{
		return _sex;
	}
	
	public void setSex(Sex sex)
	{
		_sex = sex;
	}
	
	public boolean isVisible()
	{
		return _isVisible;
	}
	
	public void setVisible(boolean val)
	{
		_isVisible = val;
	}
	
	public int getNameColor()
	{
		return _nameColor;
	}
	
	public void setNameColor(int nameColor)
	{
		_nameColor = (nameColor == PURE_WHITE) ? WHITE : nameColor;
	}

	public void setNameColor(int red, int green, int blue)
	{
		setNameColor((red & 0xFF) + ((green & 0xFF) << 8) + ((blue & 0xFF) << 16));
	}
	
	public int getTitleColor()
	{
		return _titleColor;
	}
	
	public void setTitleColor(int titleColor)
	{
		_titleColor = titleColor;
	}
	
	public void setTitleColor(int red, int green, int blue)
	{
		_titleColor = (red & 0xFF) + ((green & 0xFF) << 8) + ((blue & 0xFF) << 16);
	}
}