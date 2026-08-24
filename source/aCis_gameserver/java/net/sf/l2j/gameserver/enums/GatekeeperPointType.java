package net.sf.l2j.gameserver.enums;

import net.sf.l2j.gameserver.model.gatekeeper.GatekeeperPoint;

/**
 * The requirement type of a {@link GatekeeperPoint}.
 */
public enum GatekeeperPointType
{
	/** Available for everyone. */
	STANDARD,

	/** Available for noblesse {@link net.sf.l2j.gameserver.model.actor.Player}s only. */
	NOBLE;
}
