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
 * Request. A <code>JmxRequest</code> can be obtained only from a
 * {@link org.jmx4perl.JmxRequestFactory}
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
    private List<String> attributeNames;
    private String value;
    private List<String> extraArgs;
    private String operation;
    private Type type;
    private TargetConfig targetConfig = null;

    // Max depth of returned JSON structure when deserializing.
    private int maxDepth = 0;
    private int maxCollectionSize = 0;
    private int maxObjects = 0;

    /**
     * Create a request with the given type (with no MBean name)
     *
     * @param pType requests type
     */
    JmxRequest(Type pType) {
        type = pType;
    }

    /**
     * Create a request with given type for a certain MBean.
     * Other parameters of the request need to be set explicitely via a setter.
     *
     * @param pType requests type
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
        Object attrVal = pMap.get("attribute");
        if (attrVal != null) {
            attributeNames = new ArrayList<String>();
            if (attrVal instanceof String) {
                attributeNames.add((String) attrVal);
            } else if (attrVal instanceof Collection) {
                for (Object val : (Collection) attrVal) {
                    attributeNames.add((String) val);
                }
            }
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

        Map target = (Map) pMap.get("target");
        if (target != null) {
            targetConfig = new TargetConfig(target);
        }

    }

    public String getObjectNameAsString() {
        return objectNameS;
    }

    public ObjectName getObjectName() {
        return objectName;
    }

    public String getAttributeName() {
        if (attributeNames == null) {
            return null;
        }
        if (attributeNames.size() != 1) {
            throw new IllegalStateException("Request contains more than one attribute (attrs = " +
                    "" + attributeNames + "). Use getAttributeNames() instead.");
        }
        return attributeNames.get(0);
    }

    public List<String> getAttributeNames() {
        return attributeNames;
    }

    public List<String> getExtraArgs() {
        return extraArgs;
    }

    public String getExtraArgsAsPath() {
        if (extraArgs != null && extraArgs.size() > 0) {
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
        if (attributeNames != null) {
            attributeNames.clear();
        } else {
            attributeNames = new ArrayList<String>(1);
        }
        attributeNames.add(pName);
    }

    void setAttributeNames(List<String> pAttributeNames) {
        attributeNames = pAttributeNames;
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

    public TargetConfig getTargetConfig() {
        return targetConfig;
    }

    public String getTargetConfigUrl() {
        if (targetConfig == null) {
            return null;
        } else {
            return targetConfig.getUrl();
        }
    }

    @Override
    public String toString() {
        StringBuffer ret = new StringBuffer("JmxRequest[");
        if (type == Type.READ) {
            ret.append("READ mbean=").append(objectNameS);
            if (attributeNames != null && attributeNames.size() > 1) {
                ret.append(", attribute=[");
                for (int i = 0;i<attributeNames.size();i++) {
                    ret.append(attributeNames.get(i));
                    if (i < attributeNames.size() - 1) {
                        ret.append(",");
                    }
                }
                ret.append("]");
            } else {
                ret.append(", attribute=").append(getAttributeName());
            }
        } else if (type == Type.WRITE) {
            ret.append("WRITE mbean=").append(objectNameS).append(", attribute=").append(getAttributeName())
                    .append(", value=").append(value);
        } else if (type == Type.EXEC) {
            ret.append("EXEC mbean=").append(objectNameS).append(", operation=").append(operation);
        } else {
            ret.append(type).append(" mbean=").append(objectNameS);
        }
        if (extraArgs != null && extraArgs.size() > 0) {
            ret.append(", extra=").append(extraArgs);
        }
        if (targetConfig != null) {
            ret.append(", target=").append(targetConfig);
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
        if (attributeNames != null && attributeNames.size() > 0) {
            if (attributeNames.size() > 1) {
                ret.put("attribute",attributeNames);
            } else {
                ret.put("attribute",attributeNames.get(0));
            }
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
        if (targetConfig != null) {
            ret.put("target", targetConfig.toJSON());
        }
        return ret;
    }

    // ===============================================================================
    // Proxy configuration

    public static class TargetConfig {
        private String url;
        private Map<String,Object> env;

        public TargetConfig(Map pMap) {
            String url = (String) pMap.get("url");
            if (url == null) {
                throw new IllegalArgumentException("No service url given for JSR-160 target");
            }
            this.url = url;
            String user = (String) pMap.get("user");
            if (user != null) {
                env = new HashMap<String, Object>();
                env.put("user",user);
                String pwd = (String) pMap.get("password");
                if (pwd != null) {
                    env.put("password",pwd);
                }
            }
        }

        public String getUrl() {
            return url;
        }

        public Map<String, Object> getEnv() {
            return env;
        }

        public JSONObject toJSON() {
            JSONObject ret = new JSONObject();
            ret.put("url", url);
            if (env != null) {
                ret.put("env", env);
            }
            return ret;
        }

        @Override
        public String toString() {
            return "TargetConfig[" +
                    url +
                    ", " + env +
                    "]";
        }
    }

}
