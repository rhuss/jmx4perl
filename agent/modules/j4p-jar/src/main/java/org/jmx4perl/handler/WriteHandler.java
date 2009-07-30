package org.jmx4perl.handler;

import org.jmx4perl.JmxRequest;
import org.jmx4perl.config.Restrictor;
import org.jmx4perl.converter.json.ObjectToJsonConverter;

import javax.management.*;
import java.lang.reflect.InvocationTargetException;

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
public class WriteHandler extends RequestHandler {

    private ObjectToJsonConverter objectToJsonConverter;

    public WriteHandler(Restrictor pRestrictor, ObjectToJsonConverter pObjectToJsonConverter) {
        super(pRestrictor);
        objectToJsonConverter = pObjectToJsonConverter;
    }

    @Override
    public JmxRequest.Type getType() {
        return JmxRequest.Type.WRITE;
    }

    @Override
    public Object doHandleRequest(MBeanServer server, JmxRequest request)
            throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException {

        if (!restrictor.isAttributeWriteAllowed(request.getObjectName(),request.getAttributeName())) {
            throw new SecurityException("Writing attribute " + request.getAttributeName() +
                    " forbidden for MBean " + request.getObjectNameAsString());
        }

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
        Object[] values = objectToJsonConverter.getValues(type,oldValue,request);
        Attribute attribute = new Attribute(request.getAttributeName(),values[0]);
        server.setAttribute(request.getObjectName(),attribute);
        return values[1];
    }
}

