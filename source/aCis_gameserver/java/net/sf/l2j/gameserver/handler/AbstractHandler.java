package net.sf.l2j.gameserver.handler;

import java.io.File;
import java.lang.reflect.Modifier;
import java.net.JarURLConnection;
import java.net.URL;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.Map;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

import net.sf.l2j.commons.logging.CLogger;

public abstract class AbstractHandler<K, H>
{
	private static final CLogger LOGGER = new CLogger(AbstractHandler.class.getName());
	
	protected final Map<K, H> _entries = new HashMap<>();
	
	protected abstract void registerHandler(H handler);
	
	protected AbstractHandler(Class<H> handlerInterface, String className)
	{
		final String packagePath = "net/sf/l2j/gameserver/handler/" + className;
		
		try
		{
			final Enumeration<URL> resources = Thread.currentThread().getContextClassLoader().getResources(packagePath);
			while (resources.hasMoreElements())
			{
				final URL resource = resources.nextElement();
				
				// Handle debug process.
				if (resource.getProtocol().equals("file"))
				{
					final File directory = new File(resource.getFile());
					if (!directory.exists())
						continue;
					
					final String packageName = packagePath.replace("/", ".");
					
					for (String file : directory.list())
					{
						if (!file.endsWith(".class"))
							continue;
						
						loadHandler(handlerInterface, packageName + "." + file.substring(0, file.length() - 6));
					}
				}
				// Handle regular JAR process.
				else if (resource.getProtocol().equals("jar"))
				{
					final JarURLConnection conn = (JarURLConnection) resource.openConnection();
					try (JarFile jarFile = conn.getJarFile())
					{
						final Enumeration<JarEntry> entries = jarFile.entries();
						while (entries.hasMoreElements())
						{
							final JarEntry entry = entries.nextElement();
							final String entryName = entry.getName();
							
							if (!entryName.startsWith(packagePath) || !entryName.endsWith(".class"))
								continue;
							
							loadHandler(handlerInterface, entryName.replace('/', '.').replace(".class", ""));
						}
					}
				}
			}
		}
		catch (Exception e)
		{
			LOGGER.warn("Failed to load classes from package {}", e, packagePath);
		}
	}

	/**
	 * Instantiate and register a single handler.<br>
	 * <br>
	 * Failures are contained on that very handler ; a faulty class must not discard the handlers which aren't registered yet.
	 * @param handlerInterface : The interface the class must implement to be registered.
	 * @param className : The fully qualified name of the class to register.
	 */
	private void loadHandler(Class<H> handlerInterface, String className)
	{
		try
		{
			final Class<?> clazz = Class.forName(className);
			if (!handlerInterface.isAssignableFrom(clazz) || clazz.isInterface() || Modifier.isAbstract(clazz.getModifiers()))
				return;

			registerHandler(handlerInterface.cast(clazz.getDeclaredConstructor().newInstance()));
		}
		catch (Exception | LinkageError e)
		{
			LOGGER.error("Couldn't register the handler {}.", e, className);
		}
	}
	
	public int size()
	{
		return _entries.size();
	}
	
	public H getHandler(Object key)
	{
		return _entries.getOrDefault(key, null);
	}
}