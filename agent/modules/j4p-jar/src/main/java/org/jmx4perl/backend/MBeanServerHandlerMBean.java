package org.jmx4perl.backend;

/**
 * MBean interface for accessing the {@link MBeanServerHandler}
 *
 * @author roland
 * @since Jul 2, 2010
 */
public interface MBeanServerHandlerMBean {

    String OBJECT_NAME = "jmx4perl:type=ServerHandler";

    String mBeanServersInfo();
}
