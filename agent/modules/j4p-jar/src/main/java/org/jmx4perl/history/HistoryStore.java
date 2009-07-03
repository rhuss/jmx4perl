package org.jmx4perl.history;

/*
 * jmx4perl - WAR Agent for exporting JMX via JSON
 *
 * Copyright (C) 2009 Roland Hu§, roland@cpan.org
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 * A commercial license is available as well. You can either apply the GPL or
 * obtain a commercial license for closed source development. Please contact
 * roland@cpan.org for further information.
 */

import org.json.simple.JSONObject;

import org.jmx4perl.JmxRequest;
import static org.jmx4perl.JmxRequest.Type.*;

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
