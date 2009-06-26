package org.cpan.jmx4perl.handler;

import org.cpan.jmx4perl.JmxRequest;
import org.cpan.jmx4perl.Version;

import javax.management.*;

/**
 * @author roland
 * @since Jun 12, 2009
 */
public class VersionHandler extends RequestHandler {
    public JmxRequest.Type getType() {
        return JmxRequest.Type.VERSION;
    }

    public Object handleRequest(MBeanServer server, JmxRequest request)
            throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException {
        return Version.getVersion();
    }
}
