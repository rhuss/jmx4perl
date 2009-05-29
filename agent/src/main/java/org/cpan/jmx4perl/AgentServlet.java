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


import org.cpan.jmx4perl.converter.AttributeToJsonConverter;
import org.json.simple.JSONObject;

import javax.management.*;
import javax.servlet.ServletException;
import javax.servlet.ServletConfig;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.lang.management.ManagementFactory;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Agent servlet which connects to a local JMX MBeanServer for
 * JMX operations. This agent is a part of <a href="">Jmx4Perl</a>,
 * a Perl package for accessing JMX from within perl.
 * <p>
 * It uses a REST based approach which translates a GET Url into a
 * request. See {@link JmxRequest} for details about the URL format.
 * <p>
 * For now, only the request type
 * {@link org.cpan.jmx4perl.JmxRequest.Type#READ_ATTRIBUTE} for reading MBean
 * attributes is supported.
 * <p>
 * For the transfer via JSON only certain types are supported. Among basic types
 * like strings or numbers, collections, arrays and maps are also supported (which
 * translate into the corresponding JSON structure). Additional the OpenMBean types
 * {@link javax.management.openmbean.CompositeData} and {@link javax.management.openmbean.TabularData}
 * are supported as well. Refer to {@link org.cpan.jmx4perl.converter.AttributeToJsonConverter}
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
    private AttributeToJsonConverter jsonConverter;

    // Are we running within JBoss ?
    private boolean isJBoss;

    // The MBeanServer to use
    private MBeanServer mBeanServer;

    // Use debugging ?
    private boolean debug = false;

    @Override
    public void init() throws ServletException {
        super.init();
        jsonConverter = new AttributeToJsonConverter();
        isJBoss = checkForClass("org.jboss.mx.util.MBeanServerLocator");
        mBeanServer = findMBeanServer();
        ServletConfig config = getServletConfig();
        String doDebug = config.getInitParameter("debug");
        if (doDebug != null && Boolean.valueOf(doDebug)) {
            debug = true;
        }
    }


    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        handle(req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        handle(req,resp);
    }

    private void handle(HttpServletRequest pReq, HttpServletResponse pResp) throws IOException {
        JSONObject json = null;
        JmxRequest jmxReq = null;
        int code = 200;
        Throwable throwable = null;
        try {
            jmxReq = new JmxRequest(pReq.getPathInfo());
            if (debug) {
                log(jmxReq.toString());
            }
            Object retValue;
            JmxRequest.Type type = jmxReq.getType();
            if (type == JmxRequest.Type.READ_ATTRIBUTE) {
                retValue = getMBeanAttribute(jmxReq);
                if (debug) {
                    log("Return: " + retValue.toString());
                }
            } else if (type == JmxRequest.Type.LIST_MBEANS) {
                retValue = listMBeans();
            } else {
                throw new UnsupportedOperationException("Unsupported operation '" + jmxReq.getType() + "'");
            }
            json = jsonConverter.convertToJson(retValue,jmxReq);
            json.put("status",200 /* success */);
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
            }
            if (debug) {
                log("Success");
            }
            sendResponse(pResp,code,json.toJSONString());
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

    private Object listMBeans() throws InstanceNotFoundException {
        try {
            MBeanServer server = getMBeanServer();
            Map<String /* domain */,
                    Map<String /* props */,
                            Map<String /* attribute/operation */,
                                    List<String /* names */>>>> ret =
                    new HashMap<String, Map<String, Map<String, List<String>>>>();
            for (Object nameObject : server.queryNames((ObjectName) null,(QueryExp) null)) {
                ObjectName name = (ObjectName) nameObject;
                MBeanInfo mBeanInfo = server.getMBeanInfo(name);

                Map mBeansMap = getOrCreateMap(ret,name.getDomain());
                Map mBeanMap = getOrCreateMap(mBeansMap,name.getCanonicalKeyPropertyListString());

                addAttributes(mBeanMap, mBeanInfo);
                addOperations(mBeanMap, mBeanInfo);

                // Trim if needed
                if (mBeanMap.size() == 0) {
                    mBeansMap.remove(name.getCanonicalKeyPropertyListString());
                    if (mBeansMap.size() == 0) {
                        ret.remove(name.getDomain());
                    }
                }
            }
            return ret;
        } catch (ReflectionException e) {
            throw new IllegalStateException("Internal error while retrieving list: " + e,e);
        } catch (IntrospectionException e) {
            throw new IllegalStateException("Internal error while retrieving list: " + e,e);
        }
    }

    private void addOperations(Map pMBeanMap, MBeanInfo pMBeanInfo) {
        // Extract operations
        Map opMap = new HashMap();
        for (MBeanOperationInfo opInfo : pMBeanInfo.getOperations()) {
            Map map = new HashMap();
            List argList = new ArrayList();
            for (MBeanParameterInfo paramInfo :  opInfo.getSignature()) {
                Map args = new HashMap();
                args.put("desc",paramInfo.getDescription());
                args.put("name",paramInfo.getName());
                args.put("type",paramInfo.getType());
                argList.add(args);
            }
            map.put("args",argList);
            map.put("ret",opInfo.getReturnType());
            map.put("desc",opInfo.getDescription());
            opMap.put(opInfo.getName(),map);
        }
        if (opMap.size() > 0) {
            pMBeanMap.put("op",opMap);
        }
    }

    private void addAttributes(Map pMBeanMap, MBeanInfo pMBeanInfo) {
        // Extract atributes
        Map attrMap = new HashMap();
        for (MBeanAttributeInfo attrInfo : pMBeanInfo.getAttributes()) {
            Map map = new HashMap();
            map.put("type",attrInfo.getType());
            map.put("desc",attrInfo.getDescription());
            map.put("rw",new Boolean(attrInfo.isWritable() && attrInfo.isReadable()));
            attrMap.put(attrInfo.getName(),map);
        }
        if (attrMap.size() > 0) {
            pMBeanMap.put("attr",attrMap);
        }
    }

    private void sendResponse(HttpServletResponse pResp, int pStatusCode, String pJsonTxt) throws IOException {
        pResp.setContentType("text/plain");
        pResp.setCharacterEncoding("utf-8");
        pResp.setStatus(pStatusCode);
        PrintWriter writer = pResp.getWriter();
        writer.write(pJsonTxt);
    }

    private Object getMBeanAttribute(JmxRequest pJmxReq) throws AttributeNotFoundException, InstanceNotFoundException {
        try {
            wokaroundJBossBug(pJmxReq);
            return getMBeanServer().getAttribute(pJmxReq.getObjectName(), pJmxReq.getAttributeName());
        } catch (ReflectionException e) {
            throw new RuntimeException("Internal error for " + pJmxReq.getAttributeName() +
                    "' on object " + pJmxReq.getObjectName() + ": " + e);
        } catch (MBeanException e) {
            throw new RuntimeException("Exception while fetching the attribute '" + pJmxReq.getAttributeName() +
                    "' on object " + pJmxReq.getObjectName() + ": " + e);
        }
    }

    // ==========================================================================
    // Helper

    private MBeanServer getMBeanServer() {
        return mBeanServer;
    }

    /**
     * Use various ways for gettint to the MBeanServer which should be exposed via this
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
    private MBeanServer findMBeanServer() {

        // Check for JBoss MBeanServer via its utility class
        try {
            Class locatorClass = Class.forName("org.jboss.mx.util.MBeanServerLocator");
            Method method = locatorClass.getMethod("locateJBoss");
            return (MBeanServer) method.invoke(null);
        }
        catch (ClassNotFoundException e) { /* Ok, its *not* JBoss, continue with search ... */ }
        catch (NoSuchMethodException e) { }
        catch (IllegalAccessException e) { }
        catch (InvocationTargetException e) { }

        List servers = MBeanServerFactory.findMBeanServer(null);
        MBeanServer server = null;
        if (servers != null && servers.size() > 0) {
			server = (MBeanServer) servers.get(0);
		}

		if (server == null) {
            // Attempt to load the PlatformMBeanServer.
            server = ManagementFactory.getPlatformMBeanServer();
		}

		if (server == null) {
			throw new IllegalStateException("Unable to locate an MBeanServer instance");
		}
		return server;
	}

    private void wokaroundJBossBug(JmxRequest pJmxReq) throws ReflectionException, InstanceNotFoundException {
        if (isJBoss) {
            try {
                // invoking getMBeanInfo() works around a bug in getAttribute() that fails to
                // refetch the domains from the platform (JDK) bean server
                getMBeanServer().getMBeanInfo(pJmxReq.getObjectName());
            } catch (IntrospectionException e) {
                throw new RuntimeException("Workaround for JBoss failed for object " + pJmxReq.getObjectName() + ": " + e);
            }
        }
    }

    private Map getOrCreateMap(Map pMap, String pKey) {
        Map nMap = (Map) pMap.get(pKey);
        if (nMap == null) {
            nMap = new HashMap();
            pMap.put(pKey,nMap);
        }
        return nMap;
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
