package org.jmx4perl;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

import javax.management.*;

import org.jmx4perl.backend.RequestDispatcher;
import org.jmx4perl.config.Restrictor;
import org.jmx4perl.converter.StringToObjectConverter;
import org.jmx4perl.converter.json.ObjectToJsonConverter;
import org.json.simple.JSONObject;
import org.junit.*;

import static junit.framework.Assert.*;
import static org.junit.Assert.assertEquals;

/**
 * @author roland
 * @since Jun 15, 2010
 */
public class BackendManagerTest implements LogHandler {

    BackendManager backendManager;

    @Before
    public void setup() {
    }

    @After
    public void tearDown() {
        if (backendManager != null) {
            backendManager.unregisterOwnMBeans();
        }
    }

    @Test
    public void simplRead() throws MalformedObjectNameException, InstanceNotFoundException, IOException, ReflectionException, AttributeNotFoundException, MBeanException {
        backendManager = new BackendManager(new HashMap(),this);
        JmxRequest req = new JmxRequestBuilder(JmxRequest.Type.READ,"java.lang:type=Memory")
                .attribute("HeapMemoryUsage")
                .build();
        JSONObject ret = backendManager.handleRequest(req);
        assertTrue(Long.parseLong( (String) ((Map) ret.get("value")).get("used")) > 0);
    }


    @Test
    public void requestDispatcher() throws MalformedObjectNameException, InstanceNotFoundException, IOException, ReflectionException, AttributeNotFoundException, MBeanException {
        Map<Config,String> config = new HashMap<Config, String>();
        config.put(Config.DISPATCHER_CLASSES,RequestDispatcherTest.class.getName());
        backendManager = new BackendManager(config,this);
        JmxRequest req = new JmxRequestBuilder(JmxRequest.Type.READ,"java.lang:type=Memory").build();
        JSONObject ret = backendManager.handleRequest(req);
        assertTrue(RequestDispatcherTest.called);
    }

    @Test
    public void requestDispatcherWithWrongDispatcher() throws MalformedObjectNameException, InstanceNotFoundException, IOException, ReflectionException, AttributeNotFoundException, MBeanException {
        try {
            Map<Config,String> config = new HashMap<Config, String>();
            config.put(Config.DISPATCHER_CLASSES,RequestDispatcherWrong.class.getName());
            backendManager = new BackendManager(config,this);
            fail();
        } catch (IllegalArgumentException exp) {
            assertTrue(exp.getMessage().contains("invalid constructor"));
        }
    }

    public void debug(String message) {
        System.out.println("D> " + message);
    }

    public void info(String message) {
        System.out.println("I> " + message);
    }

    public void error(String message, Throwable t) {
        System.out.println("E> " + message);
        t.printStackTrace(System.out);
    }

    // =========================================================================================

    static class RequestDispatcherTest implements RequestDispatcher {

        static boolean called = false;

        public RequestDispatcherTest(ObjectToJsonConverter pObjectToJsonConverter,StringToObjectConverter pStringConverter,Restrictor pRestrictor) {
            assertNotNull(pObjectToJsonConverter);
            assertNotNull(pStringConverter);
            assertNotNull(pRestrictor);
        }

        public Object dispatchRequest(JmxRequest pJmxReq) throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException, IOException {
            called = true;
            if (pJmxReq.getType() == JmxRequest.Type.READ) {
                return new JSONObject();
            } else if (pJmxReq.getType() == JmxRequest.Type.WRITE) {
                return "faultyFormat";
            }
            return null;
        }

        public boolean canHandle(JmxRequest pJmxRequest) {
            return true;
        }

        public boolean useReturnValueWithPath(JmxRequest pJmxRequest) {
            return false;
        }
    }

    // ========================================================

    static class RequestDispatcherWrong implements RequestDispatcher {

        // No special constructor --> fail

        public Object dispatchRequest(JmxRequest pJmxReq) throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException, IOException {
            return null;
        }

        public boolean canHandle(JmxRequest pJmxRequest) {
            return false;
        }

        public boolean useReturnValueWithPath(JmxRequest pJmxRequest) {
            return false;
        }
    }
}
