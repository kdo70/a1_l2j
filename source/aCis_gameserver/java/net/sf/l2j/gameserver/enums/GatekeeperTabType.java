package net.sf.l2j.gameserver.enums;

import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperTab;

/**
 * The behavior of a {@link GatekeeperTab}, computed at XML parsing time.
 */
public enum GatekeeperTabType
{
	/** The tab holds areas ; it generates the areas list page. */
	AREAS,

	/** The tab generates the most used teleport points page. */
	POPULAR,

	/** The tab shows a static datapack HTM. */
	PAGE,

	/** The tab fires a regular bypass, handled by the core (multisell, quest, etc). */
	EXTERNAL;
}
