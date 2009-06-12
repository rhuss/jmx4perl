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
 * A commercial license is available as well. You can either apply the GPL or
 * obtain a commercial license for closed source development. Please contact
 * roland@cpan.org for further information.
 */

package org.cpan.jmx4perl;


import org.cpan.jmx4perl.converter.StringToObjectConverter;
import org.cpan.jmx4perl.converter.attribute.AttributeConverter;
import org.cpan.jmx4perl.handler.*;
import org.cpan.jmx4perl.history.HistoryStore;
import org.cpan.jmx4perl.config.Config;
import org.json.simple.JSONObject;

import javax.management.*;
import javax.naming.InitialContext;
import javax.naming.NamingException;
import javax.servlet.ServletConfig;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.lang.management.ManagementFactory;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.*;

/**
 * Agent servlet which connects to a local JMX MBeanServer for
 * JMX operations. This agent is a part of <a href="">Jmx4Perl</a>,
 * a Perl package for accessing JMX from within perl.
 * <p>
 * It uses a REST based approach which translates a GET Url into a
 * request. See {@link JmxRequest} for details about the URL format.
 * <p>
 * For now, only the request type
 * {@link org.cpan.jmx4perl.JmxRequest.Type#READ} for reading MBean
 * attributes is supported.
 * <p>
 * For the transfer via JSON only certain types are supported. Among basic types
 * like strings or numbers, collections, arrays and maps are also supported (which
 * translate into the corresponding JSON structure). Additional the OpenMBean types
 * {@link javax.management.openmbean.CompositeData} and {@link javax.management.openmbean.TabularData}
 * are supported as well. Refer to {@link org.cpan.jmx4perl.converter.attribute.AttributeConverter}
 * for additional information.
 *
 * For the client part, please read the documentation of
 * <a href="http://search.cpan.org/dist/jmx4perl">jmx4perl</a>.
 *
 * @author roland@cpan.org
 * @since Apr 18, 2009
 */
public class AgentServlet extends HttpServlet {

    // Converter for converting various attribute object types
    // a JSON representation
    private AttributeConverter attributeConverter;

    // String to object converters for setting attributes and arguments
    // of operations
    private StringToObjectConverter stringToObjectConverter;

    // The MBeanServers to use
    private Set<MBeanServer> mBeanServers;

    // Use debugging ?
    private boolean debug = false;

    // Map with all request handlers
    private Map<JmxRequest.Type,RequestHandler> requestHandlerMap;

    // History handler
    private HistoryStore historyStore;

    // Whether we are running under JBoss
    boolean isJBoss = checkForClass("org.jboss.mx.util.MBeanServerLocator");

    // MBean used for configuration
    private Config configMBean;

    @Override
    public void init() throws ServletException {
        super.init();

        // Central objects
        stringToObjectConverter = new StringToObjectConverter();
        attributeConverter = new AttributeConverter(stringToObjectConverter);

        // Get all MBean servers we can find
        mBeanServers = findMBeanServers();

        // Set debugging configuration
        ServletConfig config = getServletConfig();
        String doDebug = config.getInitParameter("debug");
        if (doDebug != null && Boolean.valueOf(doDebug)) {
            debug = true;
        }

        registerRequestHandler();
        registerOwnMBeans();
    }

    @Override
    public void destroy() {
        unregisterOwnMBeans();
        super.destroy();

    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        handle(req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        handle(req,resp);
    }

    private void handle(HttpServletRequest pReq, HttpServletResponse pResp) throws IOException {
        JSONObject json = null;
        JmxRequest jmxReq = null;
        int code = 200;
        Throwable throwable = null;
        try {
            jmxReq = new JmxRequest(pReq.getPathInfo());
            if (debug) log("Request: " + jmxReq.toString());

            Object retValue = callRequestHandler(jmxReq);
            if (debug) log("Return: " + retValue);

            json = attributeConverter.convertToJson(retValue,jmxReq);
            historyStore.updateAndAdd(jmxReq,json);

            json.put("status",200 /* success */);
            if (debug) log("Response: " + json);
        } catch (AttributeNotFoundException exp) {
            code = 404;
            throwable = exp;
        } catch (InstanceNotFoundException exp) {
            code = 404;
            throwable = exp;
        } catch (UnsupportedOperationException exp) {
            code = 404;
            throwable = exp;
        } catch (IllegalArgumentException exp) {
            code = 400;
            throwable = exp;
        } catch (IllegalStateException exp) {
            code = 500;
            throwable = exp;
        } catch (Exception exp) {
            code = 500;
            throwable = exp;
        } catch (Error error) {
            code = 500;
            throwable = error;
        } finally {
            if (code != 200) {
                json = getErrorJSON(code,throwable,jmxReq);
                if (debug) {
                    log("Error " + code,throwable);
                }
            } else if (debug) {
                log("Success");
            }
            sendResponse(pResp,code,json.toJSONString());
        }
    }

    private Object callRequestHandler(JmxRequest pJmxReq)
            throws ReflectionException, InstanceNotFoundException, MBeanException, AttributeNotFoundException {
        JmxRequest.Type type = pJmxReq.getType();
        RequestHandler handler = requestHandlerMap.get(type);
        if (handler == null) {
            throw new UnsupportedOperationException("Unsupported operation '" + pJmxReq.getType() + "'");
        }
        if (handler.handleAllServersAtOnce()) {
            return handler.handleRequest(mBeanServers,pJmxReq);
        } else {
            try {
                wokaroundJBossBug(pJmxReq);
                AttributeNotFoundException attrException = null;
                InstanceNotFoundException objNotFoundException = null;
                for (MBeanServer s : mBeanServers) {
                    try {
                        return handler.handleRequest(s, pJmxReq);
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
                throw new RuntimeException("Internal error for " + pJmxReq.getAttributeName() +
                        "' on object " + pJmxReq.getObjectName() + ": " + e);
            } catch (MBeanException e) {
                throw new RuntimeException("Exception while fetching the attribute '" + pJmxReq.getAttributeName() +
                        "' on object " + pJmxReq.getObjectName() + ": " + e);
            }
        }
    }

    private JSONObject getErrorJSON(int pErrorCode, Throwable pExp, JmxRequest pJmxReq) {
        JSONObject jsonObject = new JSONObject();
        jsonObject.put("status",pErrorCode);
        jsonObject.put("error",pExp.toString());
        StringWriter writer = new StringWriter();
        pExp.printStackTrace(new PrintWriter(writer));
        jsonObject.put("stacktrace",writer.toString());
        return jsonObject;
    }


    private void sendResponse(HttpServletResponse pResp, int pStatusCode, String pJsonTxt) throws IOException {
        try {
            pResp.setCharacterEncoding("utf-8");
            pResp.setContentType("text/plain");
        } catch (NoSuchMethodError error) {
            // For a Servlet 2.3 container, set the charset by hand
            pResp.setContentType("text/plain; charset=utf-8");
        }
        pResp.setStatus(pStatusCode);
        PrintWriter writer = pResp.getWriter();
        writer.write(pJsonTxt);
    }


    private void registerRequestHandler() {
        RequestHandler handlers[] = {
                new ReadHandler(),
                new WriteHandler(attributeConverter),
                new ExecHandler(stringToObjectConverter),
                new ListHandler(),
                new VersionHandler()
        };

        requestHandlerMap = new HashMap<JmxRequest.Type,RequestHandler>();
        for (RequestHandler handler : handlers) {
            requestHandlerMap.put(handler.getType(),handler);
        }
    }

    private void registerOwnMBeans() {
        int maxEntries;
        ServletConfig config = getServletConfig();
        try {
            maxEntries = Integer.parseInt(config.getInitParameter("historyMaxEntries"));
        } catch (NumberFormatException exp) {
            maxEntries = 10;
        }
        historyStore = new HistoryStore(maxEntries);
        if (mBeanServers.size() > 0) {
            try {
                configMBean = new Config(historyStore);
                ObjectName name = new ObjectName(configMBean.getMBeanName());
                mBeanServers.iterator().next().registerMBean(configMBean,name);
                //ManagementFactory.getPlatformMBeanServer().registerMBean(configMBean,name);
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
    }

    // Remove MBeans again.
    private void unregisterOwnMBeans() {
        if (configMBean != null) {
            ObjectName name = null;
            try {
                name = new ObjectName(configMBean.getMBeanName());
                mBeanServers.iterator().next().unregisterMBean(name);
            } catch (MalformedObjectNameException e) {
                // wont happen
                log("Invalid name for config MBean: " + e,e);
            } catch (InstanceNotFoundException e) {
                log("No Mbean registered with name " + name + ": " + e,e);
            } catch (MBeanRegistrationException e) {
                log("Cannot unregister MBean: " + e,e);
            }
        }
    }



    // ==========================================================================
    // Helper

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

        // =========================================================
        addJBossMBeanServer(servers);
        addFromMBeanServerFactory(servers);
        addFromJndiContext(servers);
        servers.add(ManagementFactory.getPlatformMBeanServer());

        if (servers.size() == 0) {
			throw new IllegalStateException("Unable to locate any MBeanServer instance");
		}
        if (debug) {
            log("Found " + servers.size() + " MBeanServers");
            for (MBeanServer s : mBeanServers) {
                log("    " + s.toString() +
                        ": default domain = " + s.getDefaultDomain() + ", " +
                        s.getDomains().length + " domains, " +
                        s.getMBeanCount() + " MBeans");
            }
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
        } catch (NamingException e) { /* can happen on non-Weblogic platforms */ }
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

    // Execute a request for all known MBeanServers until the first doesnt croak
    // At the time being we dont need this one, but keep this method as reference.
    private void wokaroundJBossBug(JmxRequest pJmxReq) throws ReflectionException, InstanceNotFoundException {
        if (isJBoss) {
            try {
                // invoking getMBeanInfo() works around a bug in getAttribute() that fails to
                // refetch the domains from the platform (JDK) bean server
                for (MBeanServer s : mBeanServers) {
                    try {
                        s.getMBeanInfo(pJmxReq.getObjectName());
                        return;
                    } catch (InstanceNotFoundException exp) {
                        // Only one can have the name. So, this exception
                        // is being expected to happen
                    }
                }
            } catch (IntrospectionException e) {
                throw new RuntimeException("Workaround for JBoss failed for object " + pJmxReq.getObjectName() + ": " + e);
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
