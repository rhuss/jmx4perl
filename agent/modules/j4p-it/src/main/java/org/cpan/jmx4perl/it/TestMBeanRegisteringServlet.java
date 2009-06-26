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
package org.cpan.jmx4perl.it;


import org.cpan.jmx4perl.MBeanServerHandler;

import javax.servlet.http.HttpServlet;
import javax.servlet.ServletConfig;
import javax.servlet.ServletException;
import javax.management.*;
import java.util.Set;
import java.util.List;
import java.util.ArrayList;


public class TestMBeanRegisteringServlet extends HttpServlet {

    private MBeanServerHandler mBeanHandler;

    private String domain = "jmx4perl";

    private String[] strangeNames = {
            "simple",
            "/slash-simple/",
            "/--/",
//            "äöüßÄÖÜ"

    };
    private List<ObjectName> nameTestBeans = new ArrayList<ObjectName>();

    @Override
    public void init(ServletConfig config) throws ServletException {
        mBeanHandler = new MBeanServerHandler();
        registerMBeansForNameTest();


    }

    private void registerMBeansForNameTest() {
        // Register my test mbeans
        for (String name : strangeNames) {
            try {
                ObjectName oName = mBeanHandler.registerMBean(
                        new ObjectNameChecking(),domain + ":type=naming,name=" + name);
                nameTestBeans.add(oName);
                System.out.println("Registered " + oName);
            } catch (Exception e) {
                System.out.println("Exception while registering " + name + e);
            }
        }
    }

    @Override
    public void destroy() {
        unregisterMBeansForNameTest();
    }

    private void unregisterMBeansForNameTest() {
        for (ObjectName name : nameTestBeans) {
            try {
                mBeanHandler.unregisterMBean(name);
            } catch (Exception e) {
                System.out.println("Exception while unregistering " + name + e);
            }
        }
    }
}
