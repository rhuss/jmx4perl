package org.jmx4perl;

import org.jmx4perl.config.DebugStore;
import org.jmx4perl.config.Restrictor;
import org.jmx4perl.config.RestrictorFactory;
import org.jmx4perl.converter.StringToObjectConverter;
import org.jmx4perl.converter.json.ObjectToJsonConverter;
import org.jmx4perl.history.HistoryStore;
import org.json.simple.JSONObject;

import javax.management.*;
import javax.servlet.ServletConfig;

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
 * Backendmanager for dispatching to various backends based on a given
 * {@link org.jmx4perl.JmxRequest}
 *
 * @author roland
 * @since Nov 11, 2009
 */
public class BackendManager {

    LocalRequestDispatcher localDispatcher;

    // Converter for converting various attribute object types
    // a JSON representation
    private ObjectToJsonConverter objectToJsonConverter;

    // Handling access restrictions
    private Restrictor restrictor;

    // History handler
    private HistoryStore historyStore;

    // Storage for storing debug information
    private DebugStore debugStore;

    // MBean used for configuration
    private ObjectName configMBeanName;

    // Loghandler for dispatching logs
    private LogHandler logHandler;

    public BackendManager(ServletConfig pConfig, LogHandler pLogHandler) {
        // Central objects
        StringToObjectConverter stringToObjectConverter = new StringToObjectConverter();
        objectToJsonConverter = new ObjectToJsonConverter(stringToObjectConverter,pConfig);

        // Access restrictor
        restrictor = RestrictorFactory.buildRestrictor();

        // Log handler for putting out debug
        logHandler = pLogHandler;

        localDispatcher = new LocalRequestDispatcher(objectToJsonConverter,
                                                     stringToObjectConverter,
                                                     restrictor);
        // TODO: Lookup remote dispatchers used for proxying

        // Backendstore for remembering state
        initStores(pConfig);
        registerOwnMBeans();
    }

    /**
     * Handle a single JMXRequest. The response status is set to 200 if the request
     * was successful
     *
     * @param pJmxReq request to perform
     * @return the already converted answer.
     * @throws InstanceNotFoundException
     * @throws AttributeNotFoundException
     * @throws ReflectionException
     * @throws MBeanException
     */
    public JSONObject handleRequest(JmxRequest pJmxReq) throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException {

        Object retValue = localDispatcher.dispatchRequest(pJmxReq);
        JSONObject json = objectToJsonConverter.convertToJson(retValue,pJmxReq);

        // Update global history store
        historyStore.updateAndAdd(pJmxReq,json);
        boolean debug = isDebug() && !"debugInfo".equals(pJmxReq.getOperation());
        if (debug) log("Response: " + json);
        // Ok, we did it ...
        json.put("status",200 /* success */);
        if (debug) log("Success");
        return json;
    }

    private void initStores(ServletConfig pConfig) {
        int maxEntries;
        try {
            maxEntries = Integer.parseInt(pConfig.getInitParameter("historyMaxEntries"));
        } catch (NumberFormatException exp) {
            maxEntries = 10;
        }

        String doDebug = pConfig.getInitParameter("debug");
        boolean debug = false;
        if (doDebug != null && Boolean.valueOf(doDebug)) {
            debug = true;
        }
        int maxDebugEntries = 100;
        try {
            maxEntries = Integer.parseInt(pConfig.getInitParameter("debugMaxEntries"));
        } catch (NumberFormatException exp) {
            maxDebugEntries = 100;
        }

        historyStore = new HistoryStore(maxEntries);
        debugStore = new DebugStore(maxDebugEntries,debug);
    }

    private void registerOwnMBeans() {
        try {
            configMBeanName = localDispatcher.registerConfigMBean(historyStore,debugStore);
        } catch (NotCompliantMBeanException e) {
            log("Error registering config MBean: " + e,e);
        } catch (MBeanRegistrationException e) {
            log("Cannot register MBean: " + e,e);
        } catch (MalformedObjectNameException e) {
            log("Invalid name for config MBean: " + e,e);
        } catch (InstanceAlreadyExistsException e) {
            log("Config MBean already exists: " + e,e);
        }
    }

    // Remove MBeans again.
    void unregisterOwnMBeans() {
        if (configMBeanName != null) {
            try {
                localDispatcher.unregisterLocalMBean(configMBeanName);
            } catch (MalformedObjectNameException e) {
                // wont happen
                log("Invalid name for config MBean: " + e,e);
            } catch (InstanceNotFoundException e) {
                log("No Mbean registered with name " + configMBeanName + ": " + e,e);
            } catch (MBeanRegistrationException e) {
                log("Cannot unregister MBean: " + e,e);
            }
        } else {
            log("Internal Problem: No ConfigMBean name !");
        }
    }


    public boolean isRemoteAccessAllowed(String pRemoteHost, String pRemoteAddr) {
        return restrictor.isRemoteAccessAllowed(pRemoteHost,pRemoteAddr);
    }

    public void log(String msg) {
        logHandler.log(msg);
        if (debugStore != null) {
            debugStore.log(msg);
        }
    }

    public void log(String message, Throwable t) {
        logHandler.log(message,t);
        if (debugStore != null) {
            debugStore.log(message, t);
        }
    }

    boolean isDebug() {
        return debugStore != null ? debugStore.isDebug() : false;
    }
}
