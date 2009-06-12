package org.cpan.jmx4perl.handler;

import org.cpan.jmx4perl.JmxRequest;

import javax.management.*;

/**
 * @author roland
 * @since Jun 12, 2009
 */
public class ReadHandler extends RequestHandler {

    public JmxRequest.Type getType() {
        return JmxRequest.Type.READ;
    }

    public Object handleRequest(MBeanServer server, JmxRequest request)
            throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException {
        return server.getAttribute(request.getObjectName(), request.getAttributeName());
    }
}
