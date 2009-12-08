package org.jmx4perl;

import org.jmx4perl.backend.BackendManager;
import org.jmx4perl.backend.LogHandler;
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
import java.util.List;

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
public class AgentServlet extends HttpServlet implements LogHandler {

    private static final long serialVersionUID = 42L;

    // POST- and GET- HttpRequestHandler
    private HttpRequestHandler httpGetHandler, httpPostHandler;

    // Backend dispatcher
    private BackendManager backendManager;

    @Override
    public void init(ServletConfig pConfig) throws ServletException {
        super.init(pConfig);

        // Different HTTP request handlers
        httpGetHandler = newGetHttpRequestHandler();
        httpPostHandler = newPostHttpRequestHandler();

        backendManager = new BackendManager(pConfig,this);

    }

    @Override
    public void destroy() {
        backendManager.unregisterOwnMBeans();
        super.destroy();
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        handle(httpGetHandler,req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        handle(httpPostHandler,req,resp);
    }

    private void handle(HttpRequestHandler pReqHandler,HttpServletRequest pReq, HttpServletResponse pResp) throws IOException {
        JSONAware json = null;
        int code = 200;
        try {
            // Check access policy
            checkClientIPAccess(pReq);

            // Dispatch for the proper HTTP request method
            json = pReqHandler.handleRequest(pReq,pResp);
            code = extractResultCode(json);
            if (backendManager.isDebug()) backendManager.log("Response: " + json);
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
        JSONAware handleRequest(HttpServletRequest pReq, HttpServletResponse pResp) throws IOException, MalformedObjectNameException;
    }


    private HttpRequestHandler newPostHttpRequestHandler() {
        return new HttpRequestHandler() {
            public JSONAware handleRequest(HttpServletRequest pReq, HttpServletResponse pResp)
                    throws IOException, MalformedObjectNameException {
                List<JmxRequest> jmxRequests;
                String encoding = pReq.getCharacterEncoding();
                jmxRequests = JmxRequestFactory.createRequestsFromInputStream(
                        encoding != null ?
                                new InputStreamReader(pReq.getInputStream(),encoding) :
                                new InputStreamReader(pReq.getInputStream()));
                JSONArray responseList = new JSONArray();
                for (JmxRequest jmxReq : jmxRequests) {
                    boolean debug = backendManager.isDebug() && !"debugInfo".equals(jmxReq.getOperation());
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
            public JSONAware handleRequest(HttpServletRequest pReq, HttpServletResponse pResp) {
                JmxRequest jmxReq =
                        JmxRequestFactory.createRequestFromUrl(pReq.getPathInfo(),pReq.getParameterMap());
                if (backendManager.isDebug() && !"debugInfo".equals(jmxReq.getOperation())) {
                    logRequest(pReq, jmxReq);
                }
                return executeRequest(jmxReq);
            }
        };
    }


    private JSONObject executeRequest(JmxRequest jmxReq) {
        // Call handler and retrieve return value
        try {
            return backendManager.handleRequest(jmxReq);
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
        } catch (IOException e) {
            return getErrorJSON(500,e);
        }
    }

    // =======================================================================

    private void logRequest(HttpServletRequest pReq, JmxRequest pJmxReq) {
        backendManager.log("URI: " + pReq.getRequestURI());
        backendManager.log("Path-Info: " + pReq.getPathInfo());
        backendManager.log("Request: " + pJmxReq.toString());
    }

    private void checkClientIPAccess(HttpServletRequest pReq) {
        if (!backendManager.isRemoteAccessAllowed(pReq.getRemoteHost(),pReq.getRemoteAddr())) {
            throw new SecurityException("No access from client " + pReq.getRemoteAddr() + " allowed");
        }
    }


    private JSONObject getErrorJSON(int pErrorCode, Throwable pExp) {
        JSONObject jsonObject = new JSONObject();
        jsonObject.put("status",pErrorCode);
        jsonObject.put("error",pExp.toString());
        StringWriter writer = new StringWriter();
        pExp.printStackTrace(new PrintWriter(writer));
        jsonObject.put("stacktrace",writer.toString());
        if (backendManager.isDebug()) {
            backendManager.log("Error " + pErrorCode,pExp);
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

}
