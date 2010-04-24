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
     * Enumeration for encapsulating the request mode.
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

    // Processing configuration for tis request object
    private Map<Config, String> processingConfig = new HashMap<Config, String>();

    // A value fault handler for dealing with exception when extracting values
    ValueFaultHandler valueFaultHandler = NOOP_VALUE_FAULT_HANDLER;

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
        List l = (List) pMap.get("arguments");
        if (l != null && l.size() > 0) {
            extraArgs = new ArrayList<String>();
            for (Object val : l) {
                extraArgs.add(val != null ? val.toString() : null);
            }
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

        Map<String,?> config = (Map<String,?>) pMap.get("config");
        if (config != null) {
            for (String key : config.keySet()) {
                setProcessingConfig(key,config.get(key));
            }
        }

        s = getProcessingConfig(Config.IGNORE_ERRORS);
        if (s != null && s.matches("^(true|yes|on|1)$")) {
            valueFaultHandler = IGNORE_VALUE_FAULT_HANDLER;
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
                buf.append(escapePathPart(it.next()));
                if (it.hasNext()) {
                    buf.append("/");
                }
            }
            return buf.toString();
        } else {
            return null;
        }
    }

    private static String escapePathPart(String pPathPart) {
        return pPathPart.replaceAll("/","\\\\/");
    }

    private static String unescapePathPart(String pPathPart) {
        return pPathPart.replaceAll("\\\\/","/");
    }

    static List<String> splitPath(String pPath) {
        // Split on '/' but not on '\/':
        String[] elements = pPath.split("(?<!\\\\)/+");
        List<String> ret = new ArrayList<String>();
        for (String element : elements) {
            ret.add(unescapePathPart(element));
        }
        return ret;
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

    /**
     * Get a processing configuration or null if not set
     * @param pConfig configuration key to fetch
     * @return string value or <code>null</code> if not set
     */
    public String getProcessingConfig(Config pConfig) {
        return processingConfig.get(pConfig);
    }

    /**
     * Get a processing configuration as integer or null
     * if not set
     *
     * @param pConfig configuration to lookup
     * @return integer value of configuration or null if not set.
     */
    public Integer getProcessingConfigAsInt(Config pConfig) {
        String value = processingConfig.get(pConfig);
        if (value != null) {
            return Integer.parseInt(value);
        } else {
            return null;
        }
    }

    void setProcessingConfig(String pKey, Object pValue) {
        Config cKey = Config.getByKey(pKey);
        if (cKey != null) {
            processingConfig.put(cKey,pValue != null ? pValue.toString() : null);
        }
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

    /**
     * Handle an exception occured during value extraction
     *
     * @param pFault the fault occured
     * @return a replacement value if this should be used instead or the exception is rethrown if
     *         the handler doesn't handle it
     */
    public <T extends Throwable> Object handleValueFault(T pFault) throws T {
        return valueFaultHandler.handleException(pFault);
    }

    /**
     * Get tha value fault handler, which can be passwed around. {@link #handleValueFault(Throwable)}
     * @return the value fault handler
     */
    public ValueFaultHandler getValueFaultHandler() {
        return valueFaultHandler;
    }

    // ===============================================================================
    // Proxy configuration

    public static class TargetConfig {
        private String url;
        private Map<String,Object> env;

        public TargetConfig(Map pMap) {
            url = (String) pMap.get("url");
            if (url == null) {
                throw new IllegalArgumentException("No service url given for JSR-160 target");
            }
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

    // =======================================================================================================
    // Inner interface in order to deal with value exception
    public interface ValueFaultHandler {
        /**
         * Handle the given exception and return an object
         * which can be used as a replacement for the real
         * value
         *
         * @param exception exception to ignore
         * @return replacement value or the exception is rethrown if this handler doesnt handle this exception
         * @throws T if the handler doesnt handel the exception
         */
        <T extends Throwable> Object handleException(T exception) throws T;
    }

    final private static ValueFaultHandler NOOP_VALUE_FAULT_HANDLER = new ValueFaultHandler() {
        public <T extends Throwable> Object handleException(T exception) throws T {
            // Dont handle exception on our own, we rethrow it
            throw exception;
        }
    };

    final private static ValueFaultHandler IGNORE_VALUE_FAULT_HANDLER = new ValueFaultHandler() {
        public <T extends Throwable> Object handleException(T exception) throws T {
            return "ERROR: " + exception.getMessage() + " (" + exception.getClass() + ")";
        }
    };


}
