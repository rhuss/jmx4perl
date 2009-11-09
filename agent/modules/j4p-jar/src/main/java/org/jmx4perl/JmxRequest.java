package org.jmx4perl;

import org.json.simple.JSONObject;

import javax.management.MalformedObjectNameException;
import javax.management.ObjectName;
import java.util.*;

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
 * Representation of a JMX request which is converted from an GET or POST HTTP
 * Request. A <code>JmxRequest</code> can be obtained only from a {@link org.jmx4perl.JmxRequestFactory}
 *
 * @author roland
 * @since Apr 19, 2009
 */
public class JmxRequest {

    /**
     * Enumeration for encapsulationg the request mode.
     */
    public enum Type {
        // Supported:
        READ("read"),
        LIST("list"),
        WRITE("write"),
        EXEC("exec"),
        VERSION("version"),
        SEARCH("search"),

        // Unsupported:
        REGNOTIF("regnotif"),
        REMNOTIF("remnotif"),
        CONFIG("config");

        private String value;

        Type(String pValue) {
            value = pValue;
        }

        public String getValue() {
            return value;
        }
    };

    // Attributes
    private String objectNameS;
    private ObjectName objectName;
    private String attributeName;
    private String value;
    private List<String> extraArgs;
    private String operation;
    private Type type;

    // Max depth of returned JSON structure when deserializing.
    private int maxDepth = 0;
    private int maxCollectionSize = 0;
    private int maxObjects = 0;




    /**
     * Create a request with the given type (with no MBean name)
     *
     * @param pType request's type
     */
    JmxRequest(Type pType) throws MalformedObjectNameException {
        this(pType,null);
    }

    /**
     * Create a request with given type for a certain MBean.
     * Other parameters of the request need to be set explicitely via a setter.
     *
     * @param pType request's type
     * @param pObjectNameS MBean name in string representation
     * @throws MalformedObjectNameException if the name couldnot properly translated
     *         into a JMX {@link javax.management.ObjectName}
     */
    JmxRequest(Type pType,String pObjectNameS) throws MalformedObjectNameException {
        type = pType;
        if (pObjectNameS != null) {
            objectNameS = pObjectNameS;
            objectName = new ObjectName(objectNameS);
        }
    }

    /**
     * Create a request out of a parameter map
     *
     */
    JmxRequest(Map<String,?> pMap) throws MalformedObjectNameException {
        type = Type.valueOf((String) pMap.get("type"));
        if (type == null) {
            throw new IllegalArgumentException("Type is required");
        }
        String s = (String) pMap.get("mbean");
        if (s != null) {
            objectNameS = s;
            objectName = new ObjectName(s);
        }
        s = (String) pMap.get("attribute");
        if (s != null) {
            attributeName = s;
        }
        s = (String) pMap.get("path");
        if (s != null) {
            extraArgs = splitPath(s);
        } else {
            extraArgs = new ArrayList<String>();
        }
        List<String> l = (List<String>) pMap.get("arguments");
        if (l != null) {
            extraArgs = l;
        }
        s = (String) pMap.get("value");
        if (s != null) {
             value = s;
        }
        s = (String) pMap.get("operation");
        if (s != null) {
            operation = s;
        }
    }

    public String getObjectNameAsString() {
        return objectNameS;
    }

    public ObjectName getObjectName() {
        return objectName;
    }

    public String getAttributeName() {
        return attributeName;
    }

    public List<String> getExtraArgs() {
        return extraArgs;
    }

    public String getExtraArgsAsPath() {
        if (extraArgs.size() > 0) {
            StringBuffer buf = new StringBuffer();
            Iterator<String> it = extraArgs.iterator();
            while (it.hasNext()) {
                buf.append(it.next());
                if (it.hasNext()) {
                    buf.append("/");
                }
            }
            return buf.toString();
        } else {
            return null;
        }
    }

    private List<String> splitPath(String pPath) {
        String[] elements = pPath.split("/");
        return Arrays.asList(elements);
    }



    public String getValue() {
        return value;
    }

    public Type getType() {
        return type;
    }

    public String getOperation() {
        return operation;
    }

    public int getMaxDepth() {
        return maxDepth;
    }

    public int getMaxCollectionSize() {
        return maxCollectionSize;
    }

    public int getMaxObjects() {
        return maxObjects;
    }

    void setAttributeName(String pName) {
        attributeName = pName;
    }

    void setValue(String pValue) {
        value = pValue;
    }

    void setOperation(String pOperation) {
        operation = pOperation;
    }

    void setExtraArgs(List<String> pExtraArgs) {
        extraArgs = pExtraArgs;
    }

    void setMaxObjects(int pMaxObjects) {
        maxObjects = pMaxObjects;
    }

    void setMaxCollectionSize(int pMaxCollectionSize) {
        maxCollectionSize = pMaxCollectionSize;
    }

    void setMaxDepth(int pMaxDepth) {
        maxDepth = pMaxDepth;
    }

    @Override
    public String toString() {
        StringBuffer ret = new StringBuffer("JmxRequest[");
        if (type == Type.READ) {
            ret.append("READ mbean=").append(objectNameS).append(", attribute=").append(attributeName);
        } else if (type == Type.WRITE) {
            ret.append("WRITE mbean=").append(objectNameS).append(", attribute=").append(attributeName)
                    .append(", value=").append(value);
        } else if (type == Type.EXEC) {
            ret.append("EXEC mbean=").append(objectNameS).append(", operation=").append(operation);
        } else {
            ret.append(type).append(" mbean=").append(objectNameS);
        }
        if (extraArgs != null && extraArgs.size() > 0) {
            ret.append(", extra=").append(extraArgs);
        }
        ret.append("]");
        return ret.toString();
    }


    /**
     * Return this request in a proper JSON representation
     * @return this object in a JSON representation
     */
    public JSONObject toJSON() {
        JSONObject ret = new JSONObject();
        ret.put("type",type.value);
        if (objectName != null) {
            ret.put("mbean",objectName.getCanonicalName());
        }
        if (attributeName != null) {
            ret.put("attribute",attributeName);
        }
        if (extraArgs != null && extraArgs.size() > 0) {
            if (type == Type.READ || type == Type.WRITE) {
                ret.put("path",getExtraArgsAsPath());
            } else if (type == Type.EXEC) {
                ret.put("arguments",extraArgs);
            }
        }
        if (value != null) {
            ret.put("value",value);
        }
        if (operation != null) {
            ret.put("operation",operation);
        }
        return ret;
    }
}
