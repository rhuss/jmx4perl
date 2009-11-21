package org.jmx4perl.jsr160;

import org.jmx4perl.backend.RequestDispatcher;
import org.jmx4perl.JmxRequest;
import org.jmx4perl.config.Restrictor;
import org.jmx4perl.converter.json.ObjectToJsonConverter;
import org.jmx4perl.converter.StringToObjectConverter;

import javax.management.InstanceNotFoundException;
import javax.management.AttributeNotFoundException;
import javax.management.ReflectionException;
import javax.management.MBeanException;

/**
 * Dispatcher for calling JSR-160 connectors
 *
 * @author roland
 * @since Nov 11, 2009
 */
public class Jsr160RequestDispatcher implements RequestDispatcher {

    public Jsr160RequestDispatcher(ObjectToJsonConverter objectToJsonConverter,
                                   StringToObjectConverter stringToObjectConverter,
                                   Restrictor restrictor) {

    }

    public Object dispatchRequest(JmxRequest pJmxReq)
            throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException {
        return null;
    }

    public boolean canHandle(JmxRequest pJmxRequest) {
        return false;
    }
}
