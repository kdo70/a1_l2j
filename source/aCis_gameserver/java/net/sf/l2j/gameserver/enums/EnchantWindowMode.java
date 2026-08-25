package net.sf.l2j.gameserver.enums;

/**
 * Describes what happens to the enchant window once an enchant attempt is over.
 */
public enum EnchantWindowMode
{
	/** Retail behavior : the window is closed after every attempt. */
	OFF,
	/**
	 * The window is reopened with the next scroll of the same type. Works with an unmodified client, but the client
	 * rebuilds the item list on reopening, so the player has to select the item again.
	 */
	REOPEN,
	/**
	 * The window is left untouched, keeping the item selection alive ; the player only has to press "Enchant" again.
	 * <b>Requires a patched client</b> whose ItemEnchantWnd.HandleEnchantResult doesn't hide and clear the window.
	 */
	KEEP;

	public boolean isEnabled()
	{
		return this != OFF;
	}
}
