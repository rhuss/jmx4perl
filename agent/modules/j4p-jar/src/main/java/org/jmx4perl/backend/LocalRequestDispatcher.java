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

/**
 * Dispatcher which dispatches to one or more local {@link javax.management.MBeanServer}.
 *
 * @author roland
 * @since Nov 11, 2009
 */
public class LocalRequestDispatcher implements RequestDispatcher {

    // Handler for finding and merging the various MBeanHandler
    private MBeanServerHandler mBeanServerHandler;

    private RequestHandlerManager requestHandlerManager;

    public LocalRequestDispatcher(ObjectToJsonConverter objectToJsonConverter,
                                  StringToObjectConverter stringToObjectConverter,
                                  Restrictor restrictor) {
        requestHandlerManager = new RequestHandlerManager(objectToJsonConverter,stringToObjectConverter,restrictor);
        // Get all MBean servers we can find. This is done by a dedicated
        // handler object
        mBeanServerHandler = new MBeanServerHandler();
    }

    // Can handle any request
    public boolean canHandle(JmxRequest pJmxRequest) {
        return true;
    }

    public Object dispatchRequest(JmxRequest pJmxReq)
            throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException {
        JsonRequestHandler handler = requestHandlerManager.getRequestHandler(pJmxReq.getType());
        return mBeanServerHandler.dispatchRequest(handler, pJmxReq);
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
                new Config(pHistoryStore,pDebugStore,mBeanServerHandler),Config.OBJECT_NAME);
    }
}
