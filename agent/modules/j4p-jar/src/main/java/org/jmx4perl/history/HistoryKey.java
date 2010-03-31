package org.jmx4perl.history;

import org.jmx4perl.JmxRequest;
import org.jmx4perl.JmxRequest.Type;
import static org.jmx4perl.JmxRequest.Type.*;

import java.io.Serializable;

/*
 * jmx4perl - WAR Agent for exporting JMX via JSON
 *
 * Copyright (C) 2009 Roland Huß, roland@cpan.org
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
 * A commercial license is available as well. Please contact roland@cpan.org for
 * further details.
 */

/**
 * @author roland
 * @since Jun 12, 2009
 */
public class HistoryKey implements Serializable {

    private static final long serialVersionUID = 42L;

    private String type;
    private String mBean;
    private String secondary;
    private String path;
    private String target;

    HistoryKey(JmxRequest pJmxReq) {
        validate(pJmxReq);
        Type rType = pJmxReq.getType();
        if (pJmxReq.getTargetConfig() != null) {
            target = pJmxReq.getTargetConfig().getUrl();
        }
        mBean = pJmxReq.getObjectNameAsString();
        if (rType == EXEC) {
            type = "operation";
            secondary = pJmxReq.getOperation();
            path = null;
        } else {
            type = "attribute";
            secondary = pJmxReq.getAttributeName();
            if (pJmxReq.getType() == JmxRequest.Type.READ && secondary == null) {
                secondary = "(all)";
            }
            path = pJmxReq.getExtraArgsAsPath();
        }
        if (secondary == null) {
            throw new IllegalArgumentException(type + " name must not be null");
        }
    }

    private void validate(JmxRequest pJmxRequest) {
        Type rType = pJmxRequest.getType();
        if (rType != EXEC && rType != READ && rType != WRITE) {
            throw new IllegalArgumentException(
                    "History supports only READ/WRITE/EXEC commands (and not " + rType + ")");
        }
        if (pJmxRequest.getObjectNameAsString() == null) {
            throw new IllegalArgumentException("Mbean name must not be null");
        }
        if (pJmxRequest.getObjectName().isPattern()) {
            throw new IllegalArgumentException("Mbean name must not be a pattern");
        }
        if (pJmxRequest.getAttributeNames() != null && pJmxRequest.getAttributeNames().size() > 1) {
            throw new IllegalArgumentException("A key cannot contain more than one attribute");
        }
    }

    public HistoryKey(String pMBean, String pOperation, String pTarget) {
        type = "operation";
        mBean = pMBean;
        secondary = pOperation;
        path = null;
        target = pTarget;
    }

    public HistoryKey(String pMBean, String pAttribute, String pPath,String pTarget) {
        type = "attribute";
        mBean = pMBean;
        secondary = pAttribute;
        path = pPath;
        target = pTarget;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        HistoryKey that = (HistoryKey) o;

        if (!mBean.equals(that.mBean)) return false;
        if (path != null ? !path.equals(that.path) : that.path != null) return false;
        if (!secondary.equals(that.secondary)) return false;
        if (target != null ? !target.equals(that.target) : that.target != null)
            return false;
        if (!type.equals(that.type)) return false;

        return true;
    }

    @Override
    public int hashCode() {
        int result = type.hashCode();
        result = 31 * result + mBean.hashCode();
        result = 31 * result + secondary.hashCode();
        result = 31 * result + (path != null ? path.hashCode() : 0);
        result = 31 * result + (target != null ? target.hashCode() : 0);
        return result;
    }
}
