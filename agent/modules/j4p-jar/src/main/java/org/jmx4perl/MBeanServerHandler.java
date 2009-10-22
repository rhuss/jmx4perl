package org.jmx4perl;

import org.jmx4perl.handler.RequestHandler;

import javax.management.*;
import javax.naming.InitialContext;
import javax.naming.NamingException;
import java.util.*;
import java.lang.management.ManagementFactory;
import java.lang.reflect.Method;
import java.lang.reflect.InvocationTargetException;

/*
 * jmx4perl - WAR Agent for exporting JMX via JSON
 *
 * Copyright (C) 2009 Roland Huß, roland@cpan.org
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 * A commercial license is available as well. Please contact roland@cpan.org for
 * further details.
 */

/**
 * Handler for finding and merging various MBeanServers.
 *
 * @author roland
 * @since Jun 15, 2009
 */
public class MBeanServerHandler {

    // The MBeanServers to use
    private Set<MBeanServer> mBeanServers;

    // Whether we are running under JBoss
    private boolean isJBoss = checkForClass("org.jboss.mx.util.MBeanServerLocator");
    // boolean isWebsphere = checkForClass("com.ibm.websphere.management.AdminServiceFactory");

    public MBeanServerHandler() {
        mBeanServers = findMBeanServers();
    }

    /**
     * Dispatch a request to the MBeanServer which can handle it
     *
     * @param pRequestHandler request handler to be called with an MBeanServer
     * @param pJmxReq the request to dispatch
     * @return the result of the request
     */
    public Object dispatchRequest(RequestHandler pRequestHandler, JmxRequest pJmxReq)
            throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException {
        if (pRequestHandler.handleAllServersAtOnce()) {
            return pRequestHandler.handleRequest(mBeanServers,pJmxReq);
        } else {
            try {
                wokaroundJBossBug(pJmxReq);
                AttributeNotFoundException attrException = null;
                InstanceNotFoundException objNotFoundException = null;
                for (MBeanServer s : mBeanServers) {
                    try {
                        return pRequestHandler.handleRequest(s, pJmxReq);
                    } catch (InstanceNotFoundException exp) {
                        // Remember exceptions for later use
                        objNotFoundException = exp;
                    } catch (AttributeNotFoundException exp) {
                        attrException = exp;
                    }
                }
                if (attrException != null) {
                    throw attrException;
                }
                // Must be there, otherwise we would nave have left the loop
                throw objNotFoundException;
            } catch (ReflectionException e) {
                throw new IllegalStateException("Internal error for '" + pJmxReq.getAttributeName() +
                        "' on object " + pJmxReq.getObjectName() + ": " + e,e);
            } catch (MBeanException e) {
                throw new IllegalStateException("Exception while fetching the attribute '" + pJmxReq.getAttributeName() +
                        "' on object " + pJmxReq.getObjectName() + ": " + e,e);
            }
        }
    }

    /**
     * Register a MBean under a certain name to the first availabel MBeans server
     *
     * @param pMBean MBean to register
     * @param pName optional name under which the bean should be registered. If not provided,
     * it depends on whether the MBean to register implements {@link javax.management.MBeanRegistration} or
     * not.
     *
     * @return the name under which the MBean is registered.
     */
    public ObjectName registerMBean(Object pMBean,String ... pName)
            throws MalformedObjectNameException, NotCompliantMBeanException, MBeanRegistrationException, InstanceAlreadyExistsException {
        if (mBeanServers.size() > 0) {
            Exception lastExp = null;
            for (MBeanServer server : mBeanServers) {
                try {
                    if (pName != null && pName.length > 0) {
                        ObjectName oName = new ObjectName(pName[0]);
                        return server.registerMBean(pMBean,oName).getObjectName();
                    } else {
                        // Needs to implement MBeanRegistration interface
                        return server.registerMBean(pMBean,null).getObjectName();
                    }
                } catch (Exception exp) {
                    lastExp = exp;
                }
            }
            if (lastExp != null) {
                throw new IllegalStateException("Could not register " + pMBean + ": " + lastExp,lastExp);
            }
            //ManagementFactory.getPlatformMBeanServer().registerMBean(configMBean,name);
        }
        throw new IllegalStateException("No MBeanServer initialized yet");
    }

    /**
     * Unregisters a MBean under a certain name to the first availabel MBeans server
     *
     * @param pMBeanName object name to unregister
     */
    public void unregisterMBean(ObjectName pMBeanName)
            throws MBeanRegistrationException, InstanceNotFoundException, MalformedObjectNameException {
        if (mBeanServers.size() > 0) {
            mBeanServers.iterator().next().unregisterMBean(pMBeanName);
        } else {
            throw new IllegalStateException("No MBeanServer initialized yet");
        }
    }

    /**
     * Get the set of MBeanServers found
     *
     * @return set of mbean servers
     */
    public Set<MBeanServer> getMBeanServers() {
        return Collections.unmodifiableSet(mBeanServers);
    }

    // =================================================================================

    /**
     * Use various ways for getting to the MBeanServer which should be exposed via this
     * servlet.
     *
     * <ul>
     *   <li>If running in JBoss, use <code>org.jboss.mx.util.MBeanServerLocator</code>
     *   <li>Use {@link javax.management.MBeanServerFactory#findMBeanServer(String)} for
     *       registered MBeanServer and take the <b>first</b> one in the returned list
     *   <li>Finally, use the {@link java.lang.management.ManagementFactory#getPlatformMBeanServer()}
     * </ul>
     *
     * @return the MBeanServer found
     * @throws IllegalStateException if no MBeanServer could be found.
     */
    private Set<MBeanServer> findMBeanServers() {

        // Check for JBoss MBeanServer via its utility class
        Set<MBeanServer> servers = new LinkedHashSet<MBeanServer>();

        addJBossMBeanServer(servers);
        addWebsphereMBeanServer(servers);
        addFromMBeanServerFactory(servers);
        addFromJndiContext(servers);
        servers.add(ManagementFactory.getPlatformMBeanServer());

        if (servers.size() == 0) {
			throw new IllegalStateException("Unable to locate any MBeanServer instance");
		}

		return servers;
	}

    private void addFromJndiContext(Set<MBeanServer> servers) {
        // Weblogic stores the MBeanServer in a JNDI context
        InitialContext ctx;
        try {
            ctx = new InitialContext();
            MBeanServer server = (MBeanServer) ctx.lookup("java:comp/env/jmx/runtime");
            if (server != null) {
                servers.add(server);
            }
        } catch (NamingException e) {
            // expected and can happen on non-Weblogic platforms
        }
    }

    private void addWebsphereMBeanServer(Set<MBeanServer> servers) {
        try {
			/*
			 * this.mbeanServer = AdminServiceFactory.getMBeanFactory().getMBeanServer();
			 */
			Class adminServiceClass = getClass().getClassLoader().loadClass("com.ibm.websphere.management.AdminServiceFactory");
			Method getMBeanFactoryMethod = adminServiceClass.getMethod("getMBeanFactory", new Class[0]);
			Object mbeanFactory = getMBeanFactoryMethod.invoke(null, new Object[0]);
			Method getMBeanServerMethod = mbeanFactory.getClass().getMethod("getMBeanServer", new Class[0]);
			servers.add((MBeanServer) getMBeanServerMethod.invoke(mbeanFactory, new Object[0]));
		}
		catch (ClassNotFoundException ex) {
            // Expected if not running under WAS
		}
		catch (InvocationTargetException ex) {
            // CNFE should be earlier
            throw new IllegalArgumentException("Internal: Found AdminServiceFactory but can not call methods on it (wrong WAS version ?)",ex);
		} catch (IllegalAccessException ex) {
            throw new IllegalArgumentException("Internal: Found AdminServiceFactory but can not call methods on it (wrong WAS version ?)",ex);
        } catch (NoSuchMethodException ex) {
            throw new IllegalArgumentException("Internal: Found AdminServiceFactory but can not call methods on it (wrong WAS version ?)",ex);
        }
    }

    // Special handling for JBoss
    private void addJBossMBeanServer(Set<MBeanServer> servers) {
        try {
            Class locatorClass = Class.forName("org.jboss.mx.util.MBeanServerLocator");
            Method method = locatorClass.getMethod("locateJBoss");
            servers.add((MBeanServer) method.invoke(null));
        }
        catch (ClassNotFoundException e) { /* Ok, its *not* JBoss, continue with search ... */ }
        catch (NoSuchMethodException e) { }
        catch (IllegalAccessException e) { }
        catch (InvocationTargetException e) { }
    }

    // Lookup from MBeanServerFactory
    private void addFromMBeanServerFactory(Set<MBeanServer> servers) {
        List<MBeanServer> beanServers = MBeanServerFactory.findMBeanServer(null);
        if (beanServers != null) {
            servers.addAll(beanServers);
        }
    }

    // =====================================================================================

    private void wokaroundJBossBug(JmxRequest pJmxReq) throws ReflectionException, InstanceNotFoundException {
        // if ((isJBoss || isWebsphere)
        // The workaround was enabled for websphere as well, but it seems
        // to work without it for WAS 7.0
        if (isJBoss && "java.lang".equals(pJmxReq.getObjectName().getDomain())) {
            try {
                // invoking getMBeanInfo() works around a bug in getAttribute() that fails to
                // refetch the domains from the platform (JDK) bean server (e.g. for MXMBeans)
                for (MBeanServer s : mBeanServers) {
                    try {
                        s.getMBeanInfo(pJmxReq.getObjectName());
                        return;
                    } catch (InstanceNotFoundException exp) {
                        // Only one server can have the name. So, this exception
                        // is being expected to happen
                    }
                }
            } catch (IntrospectionException e) {
                throw new IllegalStateException("Workaround for JBoss failed for object " + pJmxReq.getObjectName() + ": " + e);
            }
        }
    }

    private boolean checkForClass(String pClassName) {
        try {
            Class.forName(pClassName);
            return true;
        } catch (ClassNotFoundException e) {
            return false;
        }
    }


}
