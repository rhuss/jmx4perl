package org.jmx4perl.handler;

import org.jmx4perl.JmxRequest;
import org.jmx4perl.config.Restrictor;

import javax.management.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.Iterator;

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
 * Handler responsible for searching for MBean names.
 * @author roland
 * @since Jun 18, 2009
 */
public class SearchHandler extends RequestHandler {

    public SearchHandler(Restrictor pRestrictor) {
        super(pRestrictor);
    }

    public String getType() {
        return "search";
    }

    public Object doHandleRequest(MBeanServer server, JmxRequest request)
            throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException {
        Set names = server.queryNames(request.getObjectName(),null);
        if (names == null || names.size() == 0) {
            throw new InstanceNotFoundException("No MBean with pattern " + request.getObjectNameAsString() + " found");
        }
        List ret = new ArrayList();
        for (Iterator it = names.iterator(); it.hasNext();) {
            ObjectName name = (ObjectName) it.next();
            ret.add(name.getCanonicalName());
        }
        return ret;
    }
}
