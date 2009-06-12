package org.cpan.jmx4perl.history;

import org.cpan.jmx4perl.JmxRequest;
import org.cpan.jmx4perl.JmxRequest.Type;
import static org.cpan.jmx4perl.JmxRequest.Type.*;

import java.io.Serializable;

/**
 * @author roland
* @since Jun 12, 2009
*/
public class HistoryKey implements Serializable {

    private String type;
    private String mBean;
    private String secondary;
    private String path;

    HistoryKey(JmxRequest pJmxReq) {
        Type rType = pJmxReq.getType();
        if (rType != EXEC && rType != READ && rType != WRITE) {
            throw new IllegalArgumentException(
                    "History supports only READ/WRITE/EXEC commands (and not " + rType + ")");
        }
        mBean = pJmxReq.getObjectNameAsString();
        if (mBean == null) {
            throw new IllegalArgumentException("Mbean name must not be null");
        }
        if (rType == EXEC) {
            type = "operation";
            secondary = pJmxReq.getOperation();
            path = null;
        } else {
            type = "attribute";
            secondary = pJmxReq.getAttributeName();
            path = pJmxReq.getExtraArgsAsPath();
        }
        if (secondary == null) {
            throw new IllegalArgumentException(
                    (rType == EXEC ? "Operation" : "Attribute") + " name must not be null");
        }
    }

    public HistoryKey(String pMBean, String pOperation) {
        type = "operation";
        mBean = pMBean;
        secondary = pOperation;
        path = null;
    }

    public HistoryKey(String pMBean, String pAttribute, String pPath) {
        type = "attribute";
        mBean = pMBean;
        secondary = pAttribute;
        path = pPath;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        HistoryKey that = (HistoryKey) o;

        if (!mBean.equals(that.mBean)) return false;
        if (path != null ? !path.equals(that.path) : that.path != null) return false;
        if (!secondary.equals(that.secondary)) return false;
        if (!type.equals(that.type)) return false;

        return true;
    }

    @Override
    public int hashCode() {
        int result = type.hashCode();
        result = 31 * result + mBean.hashCode();
        result = 31 * result + secondary.hashCode();
        result = 31 * result + (path != null ? path.hashCode() : 0);
        return result;
    }
}
