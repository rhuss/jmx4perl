package org.cpan.jmx4perl.config;

import java.io.IOException;

/**
 * MBean for handling configuration issues
 *
 *
 * @author roland
 * @since Jun 12, 2009
 */
public interface ConfigMBean {

    // Operations
    void setHistoryEntriesForAttribute(String pMBean,String pAttribute,String pPath,int pMaxEntries);

    void setHistoryEntriesForOperation(String pMBean,String pOperation,int pMaxEntries);

    void resetHistoryEntries();

    // Attribute
    int getHistorySize() throws IOException;
    int getHistoryMaxEntries();
    void setHistoryMaxEntries(int pLimit);
}
