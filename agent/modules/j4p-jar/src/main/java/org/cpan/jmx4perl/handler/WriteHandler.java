package org.cpan.jmx4perl.handler;

import org.cpan.jmx4perl.JmxRequest;
import org.cpan.jmx4perl.converter.attribute.AttributeConverter;

import javax.management.*;
import java.lang.reflect.InvocationTargetException;

/**
 * @author roland
 * @since Jun 12, 2009
 */
public class WriteHandler extends RequestHandler {

    private AttributeConverter attributeConverter;

    public WriteHandler(AttributeConverter pAttributeConverter) {
        attributeConverter = pAttributeConverter;
    }

    public JmxRequest.Type getType() {
        return JmxRequest.Type.WRITE;
    }

    public Object handleRequest(MBeanServer server, JmxRequest request)
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
}

