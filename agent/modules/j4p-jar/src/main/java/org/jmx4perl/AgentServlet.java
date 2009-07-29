package org.jmx4perl;


import org.jmx4perl.config.Config;
import org.jmx4perl.config.DebugStore;
import org.jmx4perl.config.Restrictor;
import org.jmx4perl.config.RestrictorFactory;
import org.jmx4perl.converter.StringToObjectConverter;
import org.jmx4perl.converter.attribute.ObjectToJsonConverter;
import org.jmx4perl.handler.*;
import org.jmx4perl.history.HistoryStore;
import org.json.simple.JSONObject;

import javax.management.*;
import javax.servlet.ServletConfig;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.HashMap;
import java.util.Map;

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
 * Agent servlet which connects to a local JMX MBeanServer for
 * JMX operations. This agent is a part of <a href="">Jmx4Perl</a>,
 * a Perl package for accessing JMX from within perl.
 * <p>
 * It uses a REST based approach which translates a GET Url into a
 * request. See {@link JmxRequest} for details about the URL format.
 * <p>
 * For now, only the request type
 * {@link org.jmx4perl.JmxRequest.Type#READ} for reading MBean
 * attributes is supported.
 * <p>
 * For the transfer via JSON only certain types are supported. Among basic types
 * like strings or numbers, collections, arrays and maps are also supported (which
 * translate into the corresponding JSON structure). Additional the OpenMBean types
 * {@link javax.management.openmbean.CompositeData} and {@link javax.management.openmbean.TabularData}
 * are supported as well. Refer to {@link org.jmx4perl.converter.attribute.ObjectToJsonConverter}
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
    private ObjectToJsonConverter objectToJsonConverter;

    // String to object converters for setting attributes and arguments
    // of operations
    private StringToObjectConverter stringToObjectConverter;

    // Handler for finding and merging the various MBeanHandler
    private MBeanServerHandler mBeanServerHandler;

    // Map with all request handlers
    private Map<JmxRequest.Type,RequestHandler> requestHandlerMap;

    // History handler
    private HistoryStore historyStore;

    // Storage for storing debug information
    private DebugStore debugStore;

    // MBean used for configuration
    private Config configMBean;
    private ObjectName configMBeanName;

    @Override
    public void init() throws ServletException {
        super.init();

        // Get all MBean servers we can find. This is done by a dedicated
        // handler object
        mBeanServerHandler = new MBeanServerHandler();

        // Backendstore for remembering state
        initStores();

        // Central objects
        stringToObjectConverter = new StringToObjectConverter();
        objectToJsonConverter = new ObjectToJsonConverter(stringToObjectConverter);

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
            jmxReq = new JmxRequest(pReq.getPathInfo(),pReq.getParameterMap());
            boolean debug = isDebug() && !"debugInfo".equals(jmxReq.getOperation());
            if (debug) {
                log("URI: " + pReq.getRequestURI());
                log("Path-Info: " + pReq.getPathInfo());
                log("Request: " + jmxReq.toString());
            }

            Object retValue = callRequestHandler(jmxReq);
            if (debug) log("Return: " + retValue);

            json = objectToJsonConverter.convertToJson(retValue,jmxReq);
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
        } catch (SecurityException exception) {
            code = 403;
            // Wipe out stacktrace
            throwable = new Exception(exception.getMessage());
        } catch (Exception exp) {
            code = 500;
            throwable = exp;
        } catch (Error error) {
            code = 500;
            throwable = error;
        } finally {
            if (code != 200) {
                json = getErrorJSON(code,throwable,jmxReq);
                if (isDebug()) {
                    log("Error " + code,throwable);
                }
            } else if (isDebug() && !"debugInfo".equals(jmxReq.getOperation())) {
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
        return mBeanServerHandler.dispatchRequest(handler, pJmxReq);
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

        Restrictor restrictor = RestrictorFactory.buildRestrictor();

        RequestHandler handlers[] = {
                new ReadHandler(restrictor),
                new WriteHandler(restrictor,objectToJsonConverter),
                new ExecHandler(restrictor,stringToObjectConverter),
                new ListHandler(restrictor),
                new VersionHandler(restrictor),
                new SearchHandler(restrictor)
        };

        requestHandlerMap = new HashMap<JmxRequest.Type,RequestHandler>();
        for (RequestHandler handler : handlers) {
            requestHandlerMap.put(handler.getType(),handler);
        }
    }

    private void initStores() {
        int maxEntries;
        ServletConfig config = getServletConfig();
        try {
            maxEntries = Integer.parseInt(config.getInitParameter("historyMaxEntries"));
        } catch (NumberFormatException exp) {
            maxEntries = 10;
        }

        String doDebug = config.getInitParameter("debug");
        boolean debug = false;
        if (doDebug != null && Boolean.valueOf(doDebug)) {
            debug = true;
        }
        int maxDebugEntries = 100;
        try {
            maxEntries = Integer.parseInt(config.getInitParameter("debugMaxEntries"));
        } catch (NumberFormatException exp) {
            maxDebugEntries = 100;
        }

        historyStore = new HistoryStore(maxEntries);
        debugStore = new DebugStore(maxDebugEntries,debug);
        configMBean = new Config(historyStore,debugStore,mBeanServerHandler);

    }

    private void registerOwnMBeans() {
        try {
            configMBeanName = mBeanServerHandler.registerMBean(configMBean);
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
    private void unregisterOwnMBeans() {
        if (configMBeanName != null) {
            try {
                mBeanServerHandler.unregisterMBean(configMBeanName);
            } catch (MalformedObjectNameException e) {
                // wont happen
                log("Invalid name for config MBean: " + e,e);
            } catch (InstanceNotFoundException e) {
                log("No Mbean registered with name " + configMBeanName + ": " + e,e);
            } catch (MBeanRegistrationException e) {
                log("Cannot unregister MBean: " + e,e);
            }
        }
    }


    @Override
    public void log(String msg) {
        super.log(msg);
        debugStore.log(msg);
    }

    @Override
    public void log(String message, Throwable t) {
        super.log(message,t);
        debugStore.log(message, t);
    }

    private boolean isDebug() {
        return debugStore.isDebug();
    }

}
