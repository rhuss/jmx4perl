package org.cpan.jmx4perl.handler;

import org.cpan.jmx4perl.JmxRequest;

import javax.management.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * Handler responsible for searching for MBean names.
 * @author roland
 * @since Jun 18, 2009
 */
public class SearchHandler extends RequestHandler {
    @Override
    public JmxRequest.Type getType() {
        return JmxRequest.Type.SEARCH;
    }

    @Override
    public Object handleRequest(MBeanServer server, JmxRequest request)
            throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException {
        Set<ObjectName> names = server.queryNames(request.getObjectName(),null);
        if (names == null || names.size() == 0) {
            throw new InstanceNotFoundException("No MBean with pattern " + request.getObjectNameAsString() + " found");
        }
        List<String> ret = new ArrayList<String>();
        for (ObjectName name : names) {
            ret.add(name.getCanonicalName());
        }
        return ret;
    }
}
