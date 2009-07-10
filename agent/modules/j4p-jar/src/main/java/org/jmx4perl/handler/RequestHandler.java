package org.jmx4perl.handler;

import org.jmx4perl.JmxRequest;

import javax.management.*;
import java.util.Set;

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
 * @since Jun 12, 2009
 */
public abstract class RequestHandler {

    /**
     * The type of request which can be served by this handler
     * @return the request typ of this handler
     */
    abstract public JmxRequest.Type getType();

    /**
     * Override this if you want all servers as list in the argument, e.g.
     * to query each server on your own. By default, dispatching of the servers
     * are done for you
     *
     * @return whether you want to have
     * {@link #handleRequest(javax.management.MBeanServer, org.jmx4perl.JmxRequest)}
     * (<code>false</code>) or
     * {@link #handleRequest(java.util.Set, org.jmx4perl.JmxRequest)} (<code>true</code>) called.
     */
    public boolean handleAllServersAtOnce() {
        return false;
    }

    /**
     * Handle a request for a single server and throw an
     * {@link javax.management.InstanceNotFoundException}
     * if the request cannot be handle by the provided server
     *
     * @param server server to try
     * @param request reqiest to process
     * @return the object result from the request
     *
     * @throws InstanceNotFoundException if the provided server cant handle the request
     * @throws AttributeNotFoundException
     * @throws ReflectionException
     * @throws MBeanException
     */
    abstract public Object handleRequest(MBeanServer server,JmxRequest request)
            throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException;

    /**
     * Override this if you want to have all servers at once for processing the request
     * (like need for merging infos as for a <code>list</code> command). This method
     * is only called whem {@link #handleAllServersAtOnce()} returns <code>true</code>
     *
     * @param servers all MBeans servers detected
     * @param request request to process
     * @return the object found
     */
    public Object handleRequest(Set<MBeanServer> servers, JmxRequest request)
                throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException    {
        return null;
    }
}
