package org.jmx4perl.it;

import javax.management.MBeanRegistration;
import javax.management.ObjectName;
import javax.management.MBeanServer;

/**
 * @author roland
 * @since Jun 30, 2009
 */
public class OperationChecking implements OperationCheckingMBean, MBeanRegistration {

    String name;

    int counter = 0;

    public OperationChecking(String pName) {
        name = pName;
    }

    public void reset() {
        counter = 0;
    }

    public int fetchNumber(String arg) {
        if ("inc".equals(arg)) {
            return counter++;
        } else {
            throw new IllegalArgumentException("Invalid arg " + arg);
        }
    }

    public ObjectName preRegister(MBeanServer pMBeanServer, ObjectName pObjectName) throws Exception {
        return new ObjectName(name);
    }

    public void postRegister(Boolean pBoolean) {
    }

    public void preDeregister() throws Exception {
    }

    public void postDeregister() {
    }
}
