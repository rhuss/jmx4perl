package org.cpan.jmx4perl.config;

import java.io.IOException;

/**
 * MBean for handling configuration issues from outside.
 *
 * @author roland
 * @since Jun 12, 2009
 */
public interface ConfigMBean {

    // Operations
    /**
     * Switch on history tracking for a specific attribute. If <code>pMaxEntries</code> is null
     * history tracking is switched off.
     * @param pMBean MBean object name
     * @param pAttribute attribute name
     * @param pPath inner path (optional)
     * @param pMaxEntries max last entries to remember, if 0 history tracking is switched off.
     */
    void setHistoryEntriesForAttribute(String pMBean,String pAttribute,String pPath,int pMaxEntries);

    /**
     * Switch on history tracking for an operation. If <code>pMaxEntries</code> is null
     * history tracking is switched off. The return value of the operation will be tracked.
     * @param pMBean MBean object name
     * @param pOperation operation to track
     * @param pMaxEntries max last entries to remember, if 0 history tracking is switched off.
     */
    void setHistoryEntriesForOperation(String pMBean,String pOperation,int pMaxEntries);

    /**
     * Remove all history entries and switch off history tracking globally.
     */
    void resetHistoryEntries();

    /**
     * Get latest debug information if debugging is switched on. The returned output
     * will not take more than {@link #getMaxDebugEntries()} lines.
     *
     * @return debug info in plain ascii.
     */
    String debugInfo();

    /**
     * Reset all debug information stored internally
     */
    void resetDebugInfo();

    /**
     * Return information about the found MBeanServers
     * @return info about MBeanServers
     */
    String mBeanServerInfo();

    // Attributes

    /**
     * Get the size in bytes which the history mechanism requires in total if serialized.
     *
     * @return size of the complete history in bytes
     * @throws IOException if serialization (which is required for the size determination) fails.
     */
    int getHistorySize() throws IOException;

    /**
     * Number of global limit for history entries. No attribute historization can exceed this
     * limit (i.e if in {@link #setHistoryEntriesForAttribute(String, String, String, int)
     * the <code>pMaxEntries</code> is set larger than this limit, the global limit will be taken}
     *
     * @return the global history limit
     */
    int getHistoryMaxEntries();

    /**
     * Set the global history limit
     * @param pLimit limit to set
     */
    void setHistoryMaxEntries(int pLimit);

    /**
     * Check, whether debugging is switched on
     * @return state of debugging
     */
    boolean isDebug();

    /**
     * Set debugging to given state
     * @param pSwitch true, if debugging should be switched on, false otherwise
     */
    void setDebug(boolean pSwitch);

    /**
     * Number of debug entries to remember
     *
     * @return number of debug entries
     */
    int getMaxDebugEntries();

    /**
     * Set the number of debugging info to remember
     * @param pNumber entries to set
     */
    void setMaxDebugEntries(int pNumber);

}
