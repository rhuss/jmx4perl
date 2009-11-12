package org.jmx4perl.backend;

import org.jmx4perl.JmxRequest;
import org.jmx4perl.config.Config;
import org.jmx4perl.config.DebugStore;
import org.jmx4perl.config.Restrictor;
import org.jmx4perl.converter.StringToObjectConverter;
import org.jmx4perl.converter.json.ObjectToJsonConverter;
import org.jmx4perl.handler.*;
import org.jmx4perl.history.HistoryStore;

import javax.management.*;
import java.util.HashMap;
import java.util.Map;

/**
 * Dispatcher which dispatches to one or more local {@link javax.management.MBeanServer}.
 *
 * @author roland
 * @since Nov 11, 2009
 */
public class LocalRequestDispatcher implements RequestDispatcher {

    // Map with all json request handlers
    private static final Map<JmxRequest.Type, JsonRequestHandler> REQUEST_HANDLER_MAP =
            new HashMap<JmxRequest.Type, JsonRequestHandler>();

    // Handler for finding and merging the various MBeanHandler
    private MBeanServerHandler mBeanServerHandler;

    public LocalRequestDispatcher(ObjectToJsonConverter objectToJsonConverter,
                                  StringToObjectConverter stringToObjectConverter,
                                  Restrictor restrictor) {
        // Get all MBean servers we can find. This is done by a dedicated
        // handler object
        mBeanServerHandler = new MBeanServerHandler();

        registerRequestHandlers(objectToJsonConverter,stringToObjectConverter,restrictor);
    }

    public Object dispatchRequest(JmxRequest pJmxReq)
            throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException {
        JmxRequest.Type type = pJmxReq.getType();
        JsonRequestHandler handler = REQUEST_HANDLER_MAP.get(type);
        if (handler == null) {
            throw new UnsupportedOperationException("Unsupported operation '" + pJmxReq.getType() + "'");
        }
        return mBeanServerHandler.dispatchRequest(handler, pJmxReq);
    }

    // Can handle any request
    public boolean canHandle(JmxRequest pJmxRequest) {
        return true;
    }

    private void registerRequestHandlers(ObjectToJsonConverter objectToJsonConverter,
                                         StringToObjectConverter stringToObjectConverter,
                                         Restrictor restrictor) {
        JsonRequestHandler handlers[] = {
                new ReadHandler(restrictor),
                new WriteHandler(restrictor,objectToJsonConverter),
                new ExecHandler(restrictor,stringToObjectConverter),
                new ListHandler(restrictor),
                new VersionHandler(restrictor),
                new SearchHandler(restrictor)
        };
        for (JsonRequestHandler handler : handlers) {
            REQUEST_HANDLER_MAP.put(handler.getType(),handler);
        }
    }

    public void unregisterLocalMBean(ObjectName pMBeanName)
            throws MBeanRegistrationException, InstanceNotFoundException,
            MalformedObjectNameException {
        mBeanServerHandler.unregisterMBean(pMBeanName);
    }

    public ObjectName registerConfigMBean(HistoryStore pHistoryStore, DebugStore pDebugStore)
            throws MBeanRegistrationException, NotCompliantMBeanException,
            MalformedObjectNameException, InstanceAlreadyExistsException {
        return mBeanServerHandler.registerMBean(
                new Config(pHistoryStore,pDebugStore,mBeanServerHandler));
    }
}
