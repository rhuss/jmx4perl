package org.jmx4perl.jsr160;

import org.jmx4perl.JmxRequest;
import org.jmx4perl.backend.RequestDispatcher;
import org.jmx4perl.config.Restrictor;
import org.jmx4perl.converter.StringToObjectConverter;
import org.jmx4perl.converter.json.ObjectToJsonConverter;
import org.jmx4perl.handler.JsonRequestHandler;
import org.jmx4perl.handler.RequestHandlerManager;

import javax.management.*;
import javax.management.remote.JMXConnector;
import javax.management.remote.JMXConnectorFactory;
import javax.management.remote.JMXServiceURL;
import java.io.IOException;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Map;

/**
 * Dispatcher for calling JSR-160 connectors
 *
 * @author roland
 * @since Nov 11, 2009
 */
public class Jsr160RequestDispatcher implements RequestDispatcher {

    private RequestHandlerManager requestHandlerManager;

    public Jsr160RequestDispatcher(ObjectToJsonConverter objectToJsonConverter,
                                   StringToObjectConverter stringToObjectConverter,
                                   Restrictor restrictor) {
        requestHandlerManager = new RequestHandlerManager(
                objectToJsonConverter, stringToObjectConverter, restrictor);
    }

    /**
     * Call a remote connector based on the connection information contained in
     * the request.
     *
     * @param pJmxReq the request to dispatch
     * @return
     * @throws InstanceNotFoundException
     * @throws AttributeNotFoundException
     * @throws ReflectionException
     * @throws MBeanException
     * @throws IOException
     */
    public Object dispatchRequest(JmxRequest pJmxReq)
            throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException, IOException {

        JsonRequestHandler handler = requestHandlerManager.getRequestHandler(pJmxReq.getType());
        MBeanServerConnection connection = getConnection(pJmxReq);
        if (handler.handleAllServersAtOnce()) {
            // There is no way to get remotely all MBeanServers ...
            return handler.handleRequest(new HashSet<MBeanServerConnection>(Arrays.asList(connection)),pJmxReq);
        } else {
            return handler.handleRequest(connection,pJmxReq);
        }
    }

    private MBeanServerConnection getConnection(JmxRequest pJmxReq) throws IOException {
        JmxRequest.TargetConfig targetConfig = pJmxReq.getTargetConfig();
        if (targetConfig == null) {
            throw new IllegalArgumentException("No proxy configuration in request " + pJmxReq);
        }
        String urlS = targetConfig.getUrl();
        JMXServiceURL url = new JMXServiceURL(urlS);
        Map env = targetConfig.getEnv();
        JMXConnector connector = JMXConnectorFactory.connect(url,env);
        return connector.getMBeanServerConnection();
    }

    public boolean canHandle(JmxRequest pJmxRequest) {
        return pJmxRequest.getTargetConfig() != null;
    }
}
