package org.cpan.jmx4perl.history;

import org.json.simple.JSONArray;
import org.json.simple.JSONObject;

import java.util.LinkedList;
import java.io.Serializable;

/**
 * @author roland
* @since Jun 12, 2009
*/
public class HistoryEntry implements Serializable {
    private LinkedList<ValueEntry> values;
    private int maxEntries;

    HistoryEntry(int pMaxEntries) {
        maxEntries = pMaxEntries;
        values = new LinkedList<ValueEntry>();
    }

    public Object jsonifyValues() {
        JSONArray jValues = new JSONArray();
        for (ValueEntry vEntry : values) {
            JSONObject o = new JSONObject();
            o.put("value",vEntry.getValue());
            o.put("timestamp",vEntry.getTimestamp());
            jValues.add(o);
        }
        return jValues;
    }


    public int getMaxEntries() {
        return maxEntries;
    }

    public void setMaxEntries(int pMaxEntries) {
        maxEntries = pMaxEntries;
    }


    public void add(Object pObject, long pTime) {
        values.addFirst(new ValueEntry(pObject,pTime));
        trim();
    }

    public void trim() {
        // Trim
        while (values.size() > maxEntries) {
            values.removeLast();
        }
    }
}
