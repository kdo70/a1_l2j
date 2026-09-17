package net.sf.l2j.gameserver.model.item;

/**
 * The enchant glow code a weapon shows, sent to the client in place of its enchant level.<br>
 * <br>
 * The code carries both the EnchantGlow rung and the enchant level. The patched engine.dll turns it back into a rung through a table of its own, and the client reads the row Enchant&lt;code&gt; of env.int for the opacity of the effect - so every level has a row of its own (see docs/enchant-glow.md) :
 * <ul>
 * <li>below +4 : 0, no glow ;</li>
 * <li>+4..+15 : the enchant level itself - the engine gives +4 rung 4, +5..+9 rung 7, +10..+15 rung 10 ;</li>
 * <li>from +16 : 16 + 4 * (level - 16) + the skills the item carries on its own (the "skills" column, 3 at most) - none gives rung 12, 1 gives 14, 2 gives 15, 3 and more give 17.</li>
 * </ul>
 * The code is a byte of at most 127, so levels above {@link #MAX_LEVEL} show as that level.
 */
public final class EnchantGlow
{
	/** The last level with a code of its own : 16 + 4 * (43 - 16) + 3 = 127. */
	public static final int MAX_LEVEL = 43;

	private EnchantGlow()
	{
	}

	/**
	 * @param enchant : The enchant level of the weapon.
	 * @param skillCount : The number of skills that very item carries.
	 * @return The glow code to send as the enchant effect, 0 for no glow.
	 */
	public static int getCode(int enchant, int skillCount)
	{
		if (enchant < 4)
			return 0;

		if (enchant < 16)
			return enchant;

		return 16 + 4 * (Math.min(enchant, MAX_LEVEL) - 16) + Math.min(Math.max(skillCount, 0), 3);
	}
}
