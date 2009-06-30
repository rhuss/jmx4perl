package org.jmx4perl.it;

/**
 * @author roland
 * @since Jun 30, 2009
 */
public interface OperationCheckingMBean {

    void reset();
    
    int fetchNumber(String arg);
}
