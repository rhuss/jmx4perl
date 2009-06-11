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


import org.cpan.jmx4perl.converter.attribute.AttributeConverter;
import org.cpan.jmx4perl.converter.StringToObjectConverter;
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

    // Are we running within JBoss ?
    private boolean isJBoss;

    // The MBeanServers to use
    private Set<MBeanServer> mBeanServers;

    // Use debugging ?
    private boolean debug = false;

    @Override
    public void init() throws ServletException {
        super.init();
        stringToObjectConverter = new StringToObjectConverter();
        attributeConverter = new AttributeConverter(stringToObjectConverter);
        isJBoss = checkForClass("org.jboss.mx.util.MBeanServerLocator");
        mBeanServers = findMBeanServers();
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
            if (type == JmxRequest.Type.READ) {
                retValue = getMBeanAttribute(jmxReq);
            } else if (type == JmxRequest.Type.WRITE) {
                retValue = setMBeanAttribute(jmxReq);
            } else if (type == JmxRequest.Type.EXEC) {
                retValue = executeMBeanOperation(jmxReq);
            } else if (type == JmxRequest.Type.LIST) {
                retValue = listMBeans();
            } else if (type == JmxRequest.Type.VERSION) {
                retValue = Version.getVersion();
            } else {
                throw new UnsupportedOperationException("Unsupported operation '" + jmxReq.getType() + "'");
            }
            json = attributeConverter.convertToJson(retValue,jmxReq);
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
            } else if (debug) {
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
            Map<String /* domain */,
                    Map<String /* props */,
                            Map<String /* attribute/operation */,
                                    List<String /* names */>>>> ret =
                    new HashMap<String, Map<String, Map<String, List<String>>>>();
            for (MBeanServer server : mBeanServers) {
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

    private Object getMBeanAttribute(JmxRequest pJmxReq) throws AttributeNotFoundException, InstanceNotFoundException {
        return executeJmxOperation(
                pJmxReq,
                new JmxRequestExecutor() {
                    public Object execute(JmxRequest request, MBeanServer server)
                            throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException {
                        return server.getAttribute(request.getObjectName(), request.getAttributeName());
                    }
                }
        );
    }

    // Set the MBean attribute and return the old value
    private Object setMBeanAttribute(JmxRequest pJmxReq) throws AttributeNotFoundException, InstanceNotFoundException {
        return executeJmxOperation(
                pJmxReq,
                new JmxRequestExecutor() {
                    public Object execute(JmxRequest request, MBeanServer server)
                            throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException {
                        try {
                            return setAttribute(request, server);
                        } catch (IntrospectionException exp) {
                            throw new IllegalArgumentException("Cannot get info for MBean " + request.getObjectName() + ": " +exp,exp);
                        } catch (InvalidAttributeValueException e) {
                            throw new IllegalArgumentException("Invalid value " + request.getValue() + " for attribute " +
                                    request.getAttributeName() + ", MBean " + request.getObjectNameAsString());
                        } catch (IllegalAccessException e) {
                            throw new IllegalArgumentException("Cannot set value " + request.getValue() + " for attribute " +
                                    request.getAttributeName() + ", MBean " + request.getObjectNameAsString(),e);
                        } catch (InvocationTargetException e) {
                            throw new IllegalArgumentException("Cannot set value " + request.getValue() + " for attribute " +
                                    request.getAttributeName() + ", MBean " + request.getObjectNameAsString(),e);
                        }
                    }
                }
        );

    }

    private Object executeMBeanOperation(JmxRequest pJmxReq)
            throws InstanceNotFoundException, AttributeNotFoundException {
        return executeJmxOperation(
                pJmxReq,
                new JmxRequestExecutor() {
                    public Object execute(JmxRequest request, MBeanServer server)
                            throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException {
                        String[] paramClazzes = new String[0];
                        paramClazzes = extractOperationTypes(server,request);
                        Object[] params = new Object[paramClazzes.length];
                        List<String> args = request.getExtraArgs();
                        if (args.size() != paramClazzes.length) {
                            throw new IllegalArgumentException("Invalid operation parameters. Operation " +
                                    request.getOperation() + " requires " + paramClazzes.length +
                                    " parameters, not " + args.size() + " as given");
                        }
                        for (int i = 0;i <  paramClazzes.length; i++) {
                            params[i] = stringToObjectConverter.convertFromString(paramClazzes[i],args.get(i));
                        }
                        return server.invoke(request.getObjectName(),request.getOperation(),params,paramClazzes);
                    }
                }
        );
    }

    private String[] extractOperationTypes(MBeanServer pServer, JmxRequest pRequest)
            throws ReflectionException, InstanceNotFoundException {
        try {
            MBeanInfo mBeanInfo = pServer.getMBeanInfo(pRequest.getObjectName());
            for (MBeanOperationInfo opInfo : mBeanInfo.getOperations()) {
                if (opInfo.getName().equals(pRequest.getOperation())) {
                    MBeanParameterInfo[] pInfos = opInfo.getSignature();
                    String[] types = new String[pInfos.length];
                    for (int i=0;i<pInfos.length;i++) {
                        types[i] = pInfos[i].getType();
                    }
                    return types;
                }
            }
        } catch (IntrospectionException e) {
            throw new IllegalStateException("Cannot extract MBeanInfo for " + pRequest.getObjectNameAsString());
        }
        throw new IllegalArgumentException(
                "Cannot extract type info for operation " + pRequest.getOperation() +
                " on MBean " + pRequest.getObjectNameAsString());
    }


    // =================================================================================

    private Object setAttribute(JmxRequest request, MBeanServer server)
            throws MBeanException, AttributeNotFoundException, InstanceNotFoundException,
            ReflectionException, IntrospectionException, InvalidAttributeValueException, IllegalAccessException, InvocationTargetException {
        // Old value, will throw an exception if attribute is not known. That's good.
        Object oldValue = server.getAttribute(request.getObjectName(), request.getAttributeName());

        MBeanInfo mInfo = server.getMBeanInfo(request.getObjectName());
        MBeanAttributeInfo aInfo = null;
        for (MBeanAttributeInfo i : mInfo.getAttributes()) {
            if (i.getName().equals(request.getAttributeName())) {
                aInfo = i;
                break;
            }
        }
        if (aInfo == null) {
            throw new AttributeNotFoundException("No attribute " + request.getAttributeName() +
                    " found for MBean " + request.getObjectNameAsString());
        }
        String type = aInfo.getType();
        Object[] values = attributeConverter.getValues(type,oldValue,request);
        Attribute attribute = new Attribute(request.getAttributeName(),values[0]);
        server.setAttribute(request.getObjectName(),attribute);
        return values[1];
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
    private Object executeJmxOperation(JmxRequest pJmxReq, JmxRequestExecutor pOperation)
            throws InstanceNotFoundException, AttributeNotFoundException {
        try {
            wokaroundJBossBug(pJmxReq);
            AttributeNotFoundException attrException = null;
            InstanceNotFoundException objNotFoundException = null;
            for (MBeanServer s : mBeanServers) {
                try {
                    return pOperation.execute(pJmxReq,s);
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

    private interface JmxRequestExecutor {
        Object execute(JmxRequest request,MBeanServer server)
                throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException;
    }

    private void wokaroundJBossBug(JmxRequest pJmxReq) throws ReflectionException, InstanceNotFoundException {
        if (isJBoss) {
            try {
                // invoking getMBeanInfo() works around a bug in getAttribute() that fails to
                // refetch the domains from the platform (JDK) bean server
                for (MBeanServer s : mBeanServers) {
                    try {
                        s.getMBeanInfo(pJmxReq.getObjectName());
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
