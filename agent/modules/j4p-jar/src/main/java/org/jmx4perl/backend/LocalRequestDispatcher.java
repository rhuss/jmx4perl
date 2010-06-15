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

    public boolean useReturnValueWithPath(JmxRequest pJmxRequest) {
        JsonRequestHandler handler = requestHandlerManager.getRequestHandler(pJmxRequest.getType());
        return handler.useReturnValueWithPath();
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
        // Websphere adds extra parts to the object name if registered explicitely, but
        // we need a defined name on the client side. So we register it with 'null' in websphere
        // and let the bean define its name. On the other side, Resin throws an exception
        // if registering with a null name, so we have to do this explicite check.
        return mBeanServerHandler.registerMBean(
                new Config(pHistoryStore,pDebugStore,mBeanServerHandler),
                mBeanServerHandler.checkForClass("com.ibm.websphere.management.AdminServiceFactory") ?
                        null :
                        Config.OBJECT_NAME);
    }
}
