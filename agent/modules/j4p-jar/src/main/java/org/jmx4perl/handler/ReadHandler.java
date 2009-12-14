package org.jmx4perl.handler;

import org.jmx4perl.JmxRequest;
import org.jmx4perl.config.Restrictor;

import javax.management.*;
import java.io.IOException;

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
public class ReadHandler extends JsonRequestHandler {

    public ReadHandler(Restrictor pRestrictor) {
        super(pRestrictor);
    }

    @Override
    public JmxRequest.Type getType() {
        return JmxRequest.Type.READ;
    }

    @Override
    public Object doHandleRequest(MBeanServerConnection server, JmxRequest request)
            throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException, IOException {
        if (!restrictor.isAttributeReadAllowed(request.getObjectName(),request.getAttributeName())) {
            throw new SecurityException("Reading attribute " + request.getAttributeName() +
                    " is forbidden for MBean " + request.getObjectNameAsString());
        }

        return server.getAttribute(request.getObjectName(), request.getAttributeName());
    }
}
