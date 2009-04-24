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
 * Contact roland@cpan.org for any licensing questions.
 */

package org.cpan.jmx4perl;


import org.cpan.jmx4perl.converter.AttributeToJsonConverter;

import javax.management.*;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.io.PrintWriter;
import java.lang.management.ManagementFactory;
import java.lang.reflect.Method;
import java.lang.reflect.InvocationTargetException;
import java.util.List;

/**
 * Entry servlet which connects to JMX MBeanServer
 * for fetching attributes which are returned in a fixed
 * JSON format.
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

    @Override
    public void init() throws ServletException {
        super.init();
        jsonConverter = new AttributeToJsonConverter();
        isJBoss = checkForClass("org.jboss.mx.util.MBeanServerLocator");
        mBeanServer = findMBeanServer();
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
        JmxRequest jmxReq = new JmxRequest(pReq.getPathInfo());
        Object retValue = null;
        if (jmxReq.getType() == JmxRequest.Type.READ_ATTRIBUTE) {
            retValue = getMBeanAttribute(jmxReq);
        } else {
            throw new UnsupportedOperationException("Unsupported operation '" + jmxReq.getType() + "'");
        }
        String jsonTxt = jsonConverter.convertToJson(retValue,jmxReq);
        sendResponse(pResp, jsonTxt);
    }

    private void sendResponse(HttpServletResponse pResp, String pJsonTxt) throws IOException {
        pResp.setContentType("text/plain");
        pResp.setCharacterEncoding("utf-8");
        PrintWriter writer = pResp.getWriter();
        writer.write(pJsonTxt);
    }

    private Object getMBeanAttribute(JmxRequest pJmxReq) {
        try {
            wokaroundJBossBug(pJmxReq);
            return getMBeanServer().getAttribute(pJmxReq.getObjectName(), pJmxReq.getAttributeName());
        } catch (AttributeNotFoundException ex) {
            throw new IllegalArgumentException("No attribute '" + pJmxReq.getAttributeName() + "' :" + ex);
        } catch (InstanceNotFoundException ex) {
            throw new IllegalArgumentException("No object with name '" + pJmxReq.getObjectName() + "' : " + ex);
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

    private boolean checkForClass(String pClassName) {
        try {
            Class.forName(pClassName);
            return true;
        } catch (ClassNotFoundException e) {
            return false;
        }
    }

}
