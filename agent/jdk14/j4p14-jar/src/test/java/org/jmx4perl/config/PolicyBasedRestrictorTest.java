package org.jmx4perl.config;


import java.io.InputStream;

import junit.framework.TestCase;

import javax.management.ObjectName;
import javax.management.MalformedObjectNameException;

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
 * @author roland
 * @since Jul 29, 2009
 */
public class PolicyBasedRestrictorTest extends TestCase {

    public void testBasics() throws MalformedObjectNameException {
        InputStream is = getClass().getResourceAsStream("/access-sample1.xml");
        PolicyBasedRestrictor restrictor = new PolicyBasedRestrictor(is);
        assertTrue(restrictor.isAttributeReadAllowed(new ObjectName("java.lang:type=Memory"),"Verbose"));
        assertFalse(restrictor.isAttributeWriteAllowed(new ObjectName("java.lang:type=Memory"),"Verbose"));
        assertFalse(restrictor.isAttributeReadAllowed(new ObjectName("java.lang:type=Memory"),"NonHeapMemoryUsage"));
        assertTrue(restrictor.isOperationAllowed(new ObjectName("java.lang:type=Memory"),"gc"));
        assertFalse(restrictor.isOperationAllowed(new ObjectName("java.lang:type=Threading"),"gc"));
        assertTrue(restrictor.isTypeAllowed("read"));
    }

    public void testRestrictIp() {
        InputStream is = getClass().getResourceAsStream("/access-sample1.xml");
        PolicyBasedRestrictor restrictor = new PolicyBasedRestrictor(is);

        String ips[][] = {
                { "11.0.18.32", "true" },
                { "planck", "true" },
                { "heisenberg", "false" },
                { "10.0.11.125", "true" },
                { "10.0.11.126", "false" },
                { "11.1.18.32", "false" },
                { "192.168.15.3", "true" },
                { "192.168.15.8", "true" },
                { "192.168.16.3", "false" }
        };

        for (int i = 0; i<ips.length; i++) {
            String check[]  = ips[i];
            String res = restrictor.isRemoteAccessAllowed(check[0],null) ? "true" : "false";
            assertEquals("Ip " + check[0] + " is " +
                    (check[1].equals("false") ? "not " : "") +
                    "allowed",check[1],res);
        }
    }

    // Patterns doesnt work with 14
    public void XtestPatterns() throws MalformedObjectNameException {
        InputStream is = getClass().getResourceAsStream("/access-sample2.xml");
        PolicyBasedRestrictor restrictor = new PolicyBasedRestrictor(is);
        assertTrue(restrictor.isAttributeReadAllowed(new ObjectName("java.lang:type=Memory"),"HeapMemoryUsage"));
        assertFalse(restrictor.isAttributeReadAllowed(new ObjectName("java.lang:type=Memory"),"NonHeapMemoryUsage"));
        assertTrue(restrictor.isAttributeReadAllowed(new ObjectName("jmx4perl:type=Config,name=Bla"),"Debug"));
        assertFalse(restrictor.isOperationAllowed(new ObjectName("jmx4perl:type=Threading"),"gc"));
        assertTrue(restrictor.isTypeAllowed("read"));
    }

    public void testNoRestrictions() throws MalformedObjectNameException {
        InputStream is = getClass().getResourceAsStream("/access-sample3.xml");
        PolicyBasedRestrictor restrictor = new PolicyBasedRestrictor(is);
        assertTrue(restrictor.isAttributeReadAllowed(new ObjectName("java.lang:type=Memory"),"HeapMemoryUsage"));
        assertTrue(restrictor.isAttributeReadAllowed(new ObjectName("java.lang:type=Memory"),"NonHeapMemoryUsage"));
        assertTrue(restrictor.isAttributeReadAllowed(new ObjectName("jmx4perl:type=Config,name=Bla"),"Debug"));
        assertTrue(restrictor.isOperationAllowed(new ObjectName("jmx4perl:type=Threading"),"gc"));
        assertTrue(restrictor.isTypeAllowed("read"));
    }
}
