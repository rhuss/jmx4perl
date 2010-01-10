package org.jmx4perl.osgi;

import org.jmx4perl.AgentServlet;
import org.jmx4perl.Config;
import org.jmx4perl.LogHandler;
import org.osgi.framework.*;
import org.osgi.service.http.HttpContext;
import org.osgi.service.http.HttpService;
import org.osgi.service.http.NamespaceException;
import org.osgi.service.log.LogService;
import org.osgi.util.tracker.ServiceTracker;

import javax.management.MBeanServer;
import javax.management.MBeanServerFactory;
import javax.servlet.ServletException;
import java.util.Dictionary;
import java.util.Hashtable;

import static org.jmx4perl.Config.*;

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
 * @author roland
 * @since Dec 27, 2009
 */
public class J4pActivator implements BundleActivator {

    // Context associated with this activator
    private BundleContext bundleContext;

    // Listener used for monitoring HttpService
    private ServiceListener httpServiceListener;

    // Tracker to be used for the LogService
    private ServiceTracker logTracker;

    // Prefix used for configuration values
    private static final String CONFIG_PREFIX = "org.jmx4perl";

    public void start(BundleContext pBundleContext) throws Exception {
        bundleContext = pBundleContext;

        // Track logging service
        logTracker = new ServiceTracker(pBundleContext, LogService.class.getName(), null);
        logTracker.open();

        final ServiceReference sRef = pBundleContext.getServiceReference(HttpService.class.getName());
        if (sRef != null) {
            registerServlet(sRef, getConfig());
        }
        httpServiceListener = createServiceListener();
        pBundleContext.addServiceListener(httpServiceListener,"(objectClass=" + HttpService.class.getName() + ")");
    }


    public void stop(BundleContext pBundleContext) throws Exception {
        assert pBundleContext.equals(bundleContext);
        ServiceReference sRef = pBundleContext.getServiceReference(HttpService.class.getName());
        if (sRef != null) {
            unregisterServlet(sRef);
        }
        logTracker.close();
        logTracker = null;
        bundleContext.removeServiceListener(httpServiceListener);
        bundleContext = null;
    }


    private ServiceListener createServiceListener() {
        return new ServiceListener() {
            public void serviceChanged(ServiceEvent pServiceEvent) {
                try {
                    if (pServiceEvent.getType() == ServiceEvent.REGISTERED) {
                        registerServlet(pServiceEvent.getServiceReference(), getConfig());
                    } else if (pServiceEvent.getType() == ServiceEvent.UNREGISTERING) {
                        unregisterServlet(pServiceEvent.getServiceReference());
                    }
                } catch (ServletException e) {
                    LogService logService = (LogService) logTracker.getService();
                    if (logService != null) {
                        logService.log(LogService.LOG_ERROR,"Servlet Exception: " + e,e);
                    }
                } catch (NamespaceException e) {
                    LogService logService = (LogService) logTracker.getService();
                    if (logService != null) {
                        logService.log(LogService.LOG_ERROR,"Namespace Exception: " + e,e);
                    }
                }
            }
        };
    }


    private void unregisterServlet(ServiceReference sRef) {
        if (sRef != null) {
            HttpService service = (HttpService) bundleContext.getService(sRef);
            service.unregister(getConfiguration(AGENT_CONTEXT));
        }
    }

    private void registerServlet(ServiceReference pRef, Dictionary<String, String> pConfig) throws ServletException, NamespaceException {
        HttpService service = (HttpService) bundleContext.getService(pRef);
        service.registerServlet(getConfiguration(AGENT_CONTEXT),
                                createServlet(),
                                pConfig,
                                getHttpContext());
    }

    private HttpContext getHttpContext() {
        final String user = getConfiguration(USER);
        final String password = getConfiguration(PASSWORD);
        if (user == null) {
            return new J4pHttpContext();
        } else {
            return new J4pAuthenticatedHttpContext(user, password);
        }
    }

    private AgentServlet createServlet() {
        AgentServlet servlet = new AgentServlet(getLogHandler());
        return servlet;
    }

    private LogHandler getLogHandler() {
        return new LogHandler() {
            public void debug(String message) {
                log(LogService.LOG_DEBUG,message);
            }

            public void info(String message) {
                log(LogService.LOG_INFO,message);
            }

            private void log(int level,String message) {
                LogService logService = (LogService) logTracker.getService();
                if (logService != null) {
                    logService.log(level,message);
                }
            }

            public void error(String message, Throwable t) {
                LogService logService = (LogService) logTracker.getService();
                logService.log(LogService.LOG_ERROR,message,t);
            }
        };
    }

    private Dictionary<String,String> getConfig() {
        Dictionary<String,String> config = new Hashtable<String,String>();
        for (Config key : Config.values()) {
            String value = getConfiguration(key);
            if (value != null) {
                config.put(key.getKeyValue(),value);
            }
        }
        return config;
    }

    private String getConfiguration(Config pKey) {
        // TODO: Use fragments and/or configuration service if available.
        String value = bundleContext.getProperty(CONFIG_PREFIX + "." + pKey);
        if (value == null) {
            value = pKey.getDefaultValue();
        }
        return value;
    }



    // ===========================================================================================
    // Context to use:

}
