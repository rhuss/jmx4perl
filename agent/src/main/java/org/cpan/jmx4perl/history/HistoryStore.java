package org.cpan.jmx4perl.history;

import org.json.simple.JSONObject;

import org.cpan.jmx4perl.JmxRequest;
import static org.cpan.jmx4perl.JmxRequest.Type.*;

import java.util.Map;
import java.util.HashMap;
import java.io.Serializable;

/**
 * Store for remembering old values.
 *
 * @author roland
 * @since Jun 12, 2009
 */
public class HistoryStore implements Serializable {

    // Hard limit for number of entries for a single history track
    private int globalMaxEntries;

    private Map<HistoryKey, HistoryEntry> historyStore;

    public HistoryStore(int pTotalMaxEntries) {
        globalMaxEntries = pTotalMaxEntries;
        historyStore = new HashMap<HistoryKey, HistoryEntry>();
    }

    public int getGlobalMaxEntries() {
        return globalMaxEntries;
    }

    public void setGlobalMaxEntries(int pGlobalMaxEntries) {
        globalMaxEntries = pGlobalMaxEntries;
    }

    /**
     * Configure the history length for a specific entry. If the length
     * is 0 disable history for this key
     *
     * @param pKey history key
     * @param pMaxEntries number of maximal entries. If larger than globalMaxEntries,
     * then globalMaxEntries is used instead.
     */
    public void configure(HistoryKey pKey,int pMaxEntries) {
        HistoryEntry entry = historyStore.get(pKey);

        if (pMaxEntries == 0) {
            if (entry != null) {
                historyStore.remove(pKey);
            }
            return;
        }

        if (pMaxEntries > globalMaxEntries) {
            pMaxEntries = globalMaxEntries;
        }

        if (entry != null) {
            entry.setMaxEntries(pMaxEntries);
            entry.trim();
        } else {
            entry = new HistoryEntry(pMaxEntries);
            historyStore.put(pKey,entry);
        }
    }

    /**
     * Reset the complete store
     */
    public synchronized void reset() {
        historyStore = new HashMap<HistoryKey, HistoryEntry>();
    }

    public void updateAndAdd(JmxRequest pJmxReq, JSONObject pJson) {
        long timestamp = System.currentTimeMillis() / 1000;
        pJson.put("timestamp",timestamp);

        JmxRequest.Type type  = pJmxReq.getType();
        if (type == EXEC || type == READ || type == WRITE) {
            HistoryEntry entry = historyStore.get(new HistoryKey(pJmxReq));
            if (entry != null) {
                synchronized(entry) {
                    // A history data to json object for the response
                    pJson.put("history",entry.jsonifyValues());

                    // Update history for next time
                    if (type == EXEC || type == READ) {
                        entry.add(pJson.get("value"),timestamp);
                    } else if (type == WRITE) {
                        // The new value to set as string representation
                        entry.add(pJmxReq.getValue(),timestamp);
                    }
                }
            }
        }
    }


}
