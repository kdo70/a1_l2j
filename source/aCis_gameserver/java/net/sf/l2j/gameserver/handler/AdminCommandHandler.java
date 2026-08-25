package net.sf.l2j.gameserver.handler;

public class AdminCommandHandler extends AbstractHandler<String, IAdminCommandHandler>
{
	protected AdminCommandHandler()
	{
		super(IAdminCommandHandler.class, "admincommandhandlers");
	}

	@Override
	protected void registerHandler(IAdminCommandHandler handler)
	{
		// Commands are keyed by their own name ; hashing them would silently drop one of two colliding commands.
		for (String id : handler.getAdminCommandList())
			_entries.put(id, handler);
	}

	@Override
	public IAdminCommandHandler getHandler(Object key)
	{
		if (!(key instanceof String adminCommand))
			return null;

		final int index = adminCommand.indexOf(" ");
		final String command = (index == -1) ? adminCommand : adminCommand.substring(0, index);

		return super.getHandler(command);
	}
	
	public static AdminCommandHandler getInstance()
	{
		return SingletonHolder.INSTANCE;
	}
	
	private static class SingletonHolder
	{
		protected static final AdminCommandHandler INSTANCE = new AdminCommandHandler();
	}
}