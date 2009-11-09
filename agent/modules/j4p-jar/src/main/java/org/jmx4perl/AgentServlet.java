package org.jmx4perl;


import org.jmx4perl.config.Config;
import org.jmx4perl.config.DebugStore;
import org.jmx4perl.config.Restrictor;
import org.jmx4perl.config.RestrictorFactory;
import org.jmx4perl.converter.StringToObjectConverter;
import org.jmx4perl.converter.json.ObjectToJsonConverter;
import org.jmx4perl.handler.*;
import org.jmx4perl.history.HistoryStore;
import org.json.simple.JSONArray;
import org.json.simple.JSONAware;
import org.json.simple.JSONObject;

import javax.management.*;
import javax.servlet.ServletConfig;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.HashMap;
import java.util.List;
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
 * are supported as well. Refer to {@link org.jmx4perl.converter.json.ObjectToJsonConverter}
 * for additional information.
 *
 * For the client part, please read the documentation of
 * <a href="http://search.cpan.org/dist/jmx4perl">jmx4perl</a>.
 *
 * @author roland@cpan.org
 * @since Apr 18, 2009
 */
public class AgentServlet extends HttpServlet {

    private static final long serialVersionUID = 42L;

    // Converter for converting various attribute object types
    // a JSON representation
    private ObjectToJsonConverter objectToJsonConverter;

    // String to object converters for setting attributes and arguments
    // of operations
    private StringToObjectConverter stringToObjectConverter;

    // Handler for finding and merging the various MBeanHandler
    private MBeanServerHandler mBeanServerHandler;

    // POST- and GET- HttpRequestHandler
    private HttpRequestHandler GET_HANDLER,POST_HANDLER;

    // Map with all json request handlers
    private static final  Map<JmxRequest.Type, JsonRequestHandler> REQUEST_HANDLER_MAP =
            new HashMap<JmxRequest.Type, JsonRequestHandler>();

    // History handler
    private static HistoryStore historyStore;

    // Storage for storing debug information
    private static DebugStore debugStore;

    // MBean used for configuration
    private static Config configMBean;
    private static ObjectName configMBeanName;

    // Handling access restrictions
    private Restrictor restrictor;

    @Override
    public void init(ServletConfig pConfig) throws ServletException {
        super.init(pConfig);

        // Get all MBean servers we can find. This is done by a dedicated
        // handler object
        mBeanServerHandler = new MBeanServerHandler();

        // Backendstore for remembering state
        initStores();

        // Central objects
        stringToObjectConverter = new StringToObjectConverter();
        objectToJsonConverter = new ObjectToJsonConverter(stringToObjectConverter,pConfig);

        // Access restrictor
        restrictor = RestrictorFactory.buildRestrictor();

        registerRequestHandlers();
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
        handle(GET_HANDLER,req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        handle(POST_HANDLER,req,resp);
    }

    private void handle(HttpRequestHandler pReqHandler,HttpServletRequest pReq, HttpServletResponse pResp) throws IOException {
        JSONAware json = null;
        int code = 200;
        Throwable throwable = null;
        try {
            // Check access policy
            checkClientIPAccess(pReq);

            // Dispatch for the proper HTTP request method
            json = pReqHandler.handleRequest(pReq,pResp);
            code = extractResultCode(json);
            if (isDebug()) log("Response: " + json);
        } catch (IllegalArgumentException exp) {
            json = getErrorJSON(code = 400,exp);
        } catch (IllegalStateException exp) {
            json = getErrorJSON(code = 500,exp);
        } catch (SecurityException exp) {
            // Wipe out stacktrace
            json = getErrorJSON(code = 403,new Exception(exp.getMessage()));
        } catch (Exception exp) {
            json = getErrorJSON(code = 500,exp);
        } catch (Error error) {
            json = getErrorJSON(code = 500,error);
        } finally {
            sendResponse(pResp,code,json.toJSONString());
        }
    }

    // Extract an return code. It's the highest status number contained
    // in within the responnses
    private int extractResultCode(JSONAware pJson) {
        if (pJson instanceof List) {
            int maxCode = 0;
            for (JSONAware j : (List<JSONAware>) pJson) {
                int code = extractStatus(j);
                if (code > maxCode) {
                    maxCode = code;
                }
            }
            return maxCode;
        } else {
            return extractStatus(pJson);
        }
    }

    private int extractStatus(JSONAware pJson) {
        if (pJson instanceof JSONObject) {
            JSONObject jsonObject = (JSONObject) pJson;
            if (!jsonObject.containsKey("status")) {
                throw new IllegalStateException("No status given in response " + pJson);
            }
            return (Integer) jsonObject.get("status");
        } else {
            throw new IllegalStateException("Internal: Not a JSONObject but a " + pJson.getClass() + " " + pJson);
        }
    }

    private interface HttpRequestHandler {
        JSONAware handleRequest(HttpServletRequest pReq, HttpServletResponse pResp) throws Exception;
    }


    private HttpRequestHandler newPostHttpRequestHandler() {
        return new HttpRequestHandler() {
            public JSONAware handleRequest(HttpServletRequest pReq, HttpServletResponse pResp)
                    throws Exception {
                List<JmxRequest> jmxRequests;
                String encoding = pReq.getCharacterEncoding();
                jmxRequests = JmxRequestFactory.createRequestsFromInputStream(
                        encoding != null ?
                                new InputStreamReader(pReq.getInputStream(),encoding) :
                                new InputStreamReader(pReq.getInputStream()));
                JSONArray responseList = new JSONArray();
                for (JmxRequest jmxReq : jmxRequests) {
                    boolean debug = isDebug() && !"debugInfo".equals(jmxReq.getOperation());
                    if (debug) logRequest(pReq, jmxReq);

                    // Call handler and retrieve return value
                    JSONObject resp = executeRequest(jmxReq);
                    responseList.add(resp);
                }
                return responseList;
            }
        };
    }

    private HttpRequestHandler newGetHttpRequestHandler() {
        return new HttpRequestHandler() {
            public JSONAware handleRequest(HttpServletRequest pReq, HttpServletResponse pResp) throws Exception {
                JmxRequest jmxReq =
                        JmxRequestFactory.createRequestFromUrl(pReq.getPathInfo(),pReq.getParameterMap());
                if (isDebug() && !"debugInfo".equals(jmxReq.getOperation())) {
                    logRequest(pReq, jmxReq);
                }
                return executeRequest(jmxReq);
            }
        };
    }


    private JSONObject executeRequest(JmxRequest jmxReq) {

        // Call handler and retrieve return value
        try {
            Object retValue = callRequestHandler(jmxReq);
            boolean debug = isDebug() && !"debugInfo".equals(jmxReq.getOperation());
            if (debug) log("Response: " + retValue);
            JSONObject json = objectToJsonConverter.convertToJson(retValue,jmxReq);

            // Update global history store
            historyStore.updateAndAdd(jmxReq,json);

            // Ok, we did it ...
            json.put("status",200 /* success */);
            if (debug) log("Success");
            return json;
        } catch (ReflectionException e) {
            return getErrorJSON(404,e);
        } catch (InstanceNotFoundException e) {
            return getErrorJSON(404,e);
        } catch (MBeanException e) {
            return getErrorJSON(500,e);
        } catch (AttributeNotFoundException e) {
            return getErrorJSON(404,e);
        } catch (UnsupportedOperationException e) {
            return getErrorJSON(500,e);
        }
    }

    // =======================================================================

    private void logRequest(HttpServletRequest pReq, JmxRequest pJmxReq) {
        log("URI: " + pReq.getRequestURI());
        log("Path-Info: " + pReq.getPathInfo());
        log("Request: " + pJmxReq.toString());
    }

    private void checkClientIPAccess(HttpServletRequest pReq) {
        if (!restrictor.isRemoteAccessAllowed(pReq.getRemoteHost(),pReq.getRemoteAddr())) {
            throw new SecurityException("No access from client " + pReq.getRemoteAddr() + " allowed");
        }
    }

    private Object callRequestHandler(JmxRequest pJmxReq)
            throws ReflectionException, InstanceNotFoundException, MBeanException, AttributeNotFoundException {
        JmxRequest.Type type = pJmxReq.getType();
        JsonRequestHandler handler = REQUEST_HANDLER_MAP.get(type);
        if (handler == null) {
            throw new UnsupportedOperationException("Unsupported operation '" + pJmxReq.getType() + "'");
        }
        return mBeanServerHandler.dispatchRequest(handler, pJmxReq);
    }


    private JSONObject getErrorJSON(int pErrorCode, Throwable pExp) {
        JSONObject jsonObject = new JSONObject();
        jsonObject.put("status",pErrorCode);
        jsonObject.put("error",pExp.toString());
        StringWriter writer = new StringWriter();
        pExp.printStackTrace(new PrintWriter(writer));
        jsonObject.put("stacktrace",writer.toString());
        if (isDebug()) {
            log("Error " + pErrorCode,pExp);
        }
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


    private void registerRequestHandlers() {

        JsonRequestHandler handlers[] = {
                new ReadHandler(restrictor),
                new WriteHandler(restrictor,objectToJsonConverter),
                new ExecHandler(restrictor,stringToObjectConverter),
                new ListHandler(restrictor),
                new VersionHandler(restrictor),
                new SearchHandler(restrictor)
        };

        for (JsonRequestHandler handler : handlers) {
            REQUEST_HANDLER_MAP.put(handler.getType(),handler);
        }

        GET_HANDLER = newGetHttpRequestHandler();
        POST_HANDLER = newPostHttpRequestHandler();
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
        } else {
            log("Internal Problem: No ConfigMBean name !");
        }
    }


    @Override
    public void log(String msg) {
        super.log(msg);
        if (debugStore != null) {
            debugStore.log(msg);
        }
    }

    @Override
    public void log(String message, Throwable t) {
        super.log(message,t);
        if (debugStore != null) {
            debugStore.log(message, t);
        }
    }

    private boolean isDebug() {
        return debugStore != null ? debugStore.isDebug() : false;
    }

}
