package org.cpan.jmx4perl.history;

import java.io.Serializable;

/**
 * @author roland
* @since Jun 12, 2009
*/
class ValueEntry implements Serializable {
    private Object value;
    private long timestamp;

    ValueEntry(Object pValue, long pTimestamp) {
        value = pValue;
        timestamp = pTimestamp;
    }

    public Object getValue() {
        return value;
    }

    public long getTimestamp() {
        return timestamp;
    }
}
