package org.cpan.jmx4perl.handler;

import org.cpan.jmx4perl.JmxRequest;
import org.cpan.jmx4perl.history.HistoryStore;

import javax.management.*;

/**
 * @author roland
 * @since Jun 12, 2009
 */
public class ConfigHandler extends RequestHandler {

    private HistoryStore historyStore;

    public ConfigHandler(HistoryStore pHistoryStore) {
        historyStore = pHistoryStore;
    }

    public JmxRequest.Type getType() {
        return JmxRequest.Type.CONFIG;
    }

    public Object handleRequest(MBeanServer server, JmxRequest request)
            throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException {
        return null;
    }
}
