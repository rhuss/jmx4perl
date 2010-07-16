package org.jmx4perl.backend;

/**
 * MBean interface for accessing the {@link MBeanServerHandler}
 *
 * @author roland
 * @since Jul 2, 2010
 */
public interface MBeanServerHandlerMBean {

    // Name of MBean used for registration
    String OBJECT_NAME = "jmx4perl:type=ServerHandler";

    /**
     * Get a summary information of all MBeans found on the server
     *
     * @return the servers information.
     */
    String mBeanServersInfo();
}
