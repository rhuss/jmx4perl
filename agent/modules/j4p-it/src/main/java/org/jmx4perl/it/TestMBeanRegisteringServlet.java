/*
 * jmx4perl - Servlet for registering MBeans for jmx4perl integration test suite
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
package org.jmx4perl.it;


import org.jmx4perl.MBeanServerHandler;

import javax.servlet.http.HttpServlet;
import javax.servlet.ServletConfig;
import javax.servlet.ServletException;
import javax.management.*;
import java.util.List;
import java.util.ArrayList;


public class TestMBeanRegisteringServlet extends HttpServlet {

    private MBeanServerHandler mBeanHandler;

    private String domain = "jmx4perl.it";

    private String[] strangeNames = {
            "simple",
            "/slash-simple/",
            "/--/",
            "with%3acolon",
            "//server/client"
//            "äöüßÄÖÜ"

    };
    private List<ObjectName> testBeans = new ArrayList<ObjectName>();

    @Override
    public void init(ServletConfig config) throws ServletException {
        mBeanHandler = new MBeanServerHandler();
        registerMBeans();


    }

    private void registerMBeans() throws ServletException {
        try {
            // Register my test mbeans
            for (String name : strangeNames) {
                registerMBean(new ObjectNameChecking(domain + ":type=naming,name=" + name));
            }

            // Other MBeans
            registerMBean(new OperationChecking(domain + ":type=operation"));
            registerMBean(new AttributeChecking(domain + ":type=attribute"));

        } catch (Exception exp) {
        }
    }

    private ObjectName registerMBean(Object pObject, String ... pName) throws ServletException {
        try {
            ObjectName oName = mBeanHandler.registerMBean(pObject,pName);
            System.out.println("Registered " + oName);
            testBeans.add(oName);
            return oName;
        } catch (Exception e) {
            throw new ServletException("Cannot register MBean " + (pName != null && pName.length > 0 ? pName[0] : pObject),e);
        }
    }

    @Override
    public void destroy() {
        unregisterMBeans();
    }

    private void unregisterMBeans() {
        for (ObjectName name : testBeans) {
            try {
                mBeanHandler.unregisterMBean(name);
            } catch (Exception e) {
                System.out.println("Exception while unregistering " + name + e);
            }
        }
    }
}
