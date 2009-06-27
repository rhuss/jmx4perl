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

import org.jmx4perl.JmxRequest;
import org.jmx4perl.JmxRequest.Type;
import static org.jmx4perl.JmxRequest.Type.*;

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
