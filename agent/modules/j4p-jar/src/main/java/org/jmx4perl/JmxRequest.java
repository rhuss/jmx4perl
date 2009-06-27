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

package org.jmx4perl;

import org.json.simple.JSONObject;

import javax.management.MalformedObjectNameException;
import javax.management.ObjectName;
import java.io.UnsupportedEncodingException;
import java.net.URLDecoder;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * A JMX request which knows how to translate from a REST Url. Additionally
 * it can be easily translated into a JSON format for inclusion into a response
 * from {@link AgentServlet}
 * <p>
 * The REST-Url which gets recognized has the following format:
 * <p>
 * <pre>
 *    &lt;base_url&gt;/&lt;type&gt;/&lt;param1&gt;/&lt;param2&gt;/....
 * </pre>
 * <p>
 * where <code>base_url<code> is the URL specifying the overall servlet (including
 * the servlet context, something like "http://localhost:8080/j4p-agent"),
 * <code>type</code> the operational mode and <code>param1 .. paramN<code>
 * the provided parameters which are dependend on the <code>type<code>
 * <p>
 * The following types are recognized so far, along with there parameters:
 *
 * <ul>
 *   <li>Type: <b>read</b> ({@link Type#READ}<br/>
 *       Parameters: <code>param1<code> = MBean name, <code>param2</code> = Attribute name,
 *       <code>param3 ... paramN</code> = Inner Path.
 *       The inner path is optional and specifies a path into complex MBean attributes
 *       like collections or maps. If within collections/arrays/tabular data,
 *       <code>paramX</code> should specify
 *       a numeric index, in maps/composite data <code>paramX</code> is a used as a string
 *       key.</li>
 *   <li>Type: <b>write</b> ({@link Type#WRITE}<br/>
 *       Parameters: <code>param1</code> = MBean name, <code>param2</code> = Attribute name,
 *       <code>param3</code> = value, <code>param4 ... paramN</code> = Inner Path.
 *       The value must be URL encoded (with UTF-8 as charset), and must be convertable into
 *       a data structure</li>
 *   <li>Type: <b>exec</b> ({@link Type#EXEC}<br/>
 *       Parameters: <code>param1</code> = MBean name, <code>param2</code> = operation name,
 *       <code>param4 ... paramN</code> = arguments for the operation.
 *       The arguments must be URL encoded (with UTF-8 as charset), and must be convertable into
 *       a data structure</li>
 *    <li>Type: <b>version</b> ({@link Type#VERSION}<br/>
 *        Parameters: none
 *    <li>Type: <b>search</b> ({@link Type#SEARCH}<br/>
 *        Parameters: <code>param1</code> = MBean name pattern
 * </ul>
 * @author roland
 * @since Apr 19, 2009
 */
public class JmxRequest extends JSONObject {

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


    private String objectNameS;
    private ObjectName objectName;
    private String attributeName;
    private String value;
    private List<String> extraArgs;
    private String operation;
    private Type type;

    private static final Pattern SLASH_ESCAPE_PATTERN = Pattern.compile("^-*\\+?$");

    JmxRequest(String pPathInfo) {
        try {
            if (pPathInfo != null && pPathInfo.length() > 0) {

                // Get all path elements as a reverse stack
                Stack<String> elements = extractElementsFromPath(pPathInfo);

                type = extractType(elements.pop());

                Processor processor = processorMap.get(type);
                if (processor == null) {
                    throw new UnsupportedOperationException("Type " + type + " is not supported (yet)");
                }

                processor.process(this,elements);

                // Extract all additional args from the remaining path info
                extraArgs = new ArrayList<String>();
                while (!elements.isEmpty()) {
                    extraArgs.add(elements.pop());
                }

                // Setup JSON representation
                put("type",type.getValue());
                processor.setupJSON(this);
            }
        } catch (NoSuchElementException exp) {
            throw new IllegalArgumentException("Invalid path info " + pPathInfo,exp);
        } catch (MalformedObjectNameException e) {
            throw new IllegalArgumentException(
                    "Invalid object name \"" + objectNameS +
                            "\": " + e.getMessage(),e);
        } catch (UnsupportedEncodingException e) {
            throw new IllegalStateException("Internal: Illegal encoding for URL conversion: " + e,e);
        }
    }

    /*
    We need to use this special treating for slashes (i.e. to escape with '/-/') because URI encoding doesnt work
    well with HttpRequest.pathInfo() since in Tomcat/JBoss slash seems to be decoded to early so that it get messed up
    and answers with a "HTTP/1.x 400 Invalid URI: noSlash" without returning any further indications

    For the rest of unsafe chars, we use uri decoding (as anybody should do). It could be of course the case,
    that the pathinfo has been already uri decoded (dont know by heart)
     */
    private Stack<String> extractElementsFromPath(String path) throws UnsupportedEncodingException {
        String[] elements = (path.startsWith("/") ? path.substring(1) : path).split("/");

        Stack<String> ret = new Stack<String>();
        Stack<String> elementStack = new Stack<String>();

        for (int i=elements.length-1;i>=0;i--) {
            elementStack.push(elements[i]);
        }

        extractElements(ret,elementStack,null);
        // Reverse stack
        Collections.reverse(ret);
        return ret;
    }

    private void extractElements(Stack<String> ret, Stack<String> pElementStack,StringBuffer previousBuffer)
            throws UnsupportedEncodingException {
        if (pElementStack.isEmpty()) {
            return;
        }
        String element = pElementStack.pop();
        Matcher matcher = SLASH_ESCAPE_PATTERN.matcher(element);
        if (matcher.matches()) {
            if (ret.isEmpty()) {
                return;
            }
            StringBuffer val;
            if (previousBuffer == null) {
                val = new StringBuffer(ret.pop());
            } else {
                val = previousBuffer;
            }
            // Decode to value
            for (int j=0;j<element.length();j++) {
                val.append("/");
            }
            // Special escape at the end indicates that this is the last element in the path
            if (!element.substring(element.length()-1,1).equals("+")) {
                if (!pElementStack.isEmpty()) {
                    val.append(URLDecoder.decode(pElementStack.pop(),"UTF-8"));
                }
                extractElements(ret,pElementStack,val);
                return;
            } else {
                ret.push(URLDecoder.decode(val.toString(),"UTF-8"));
                extractElements(ret,pElementStack,null);
                return;
            }
        }
        if (previousBuffer != null) {
            ret.push(URLDecoder.decode(previousBuffer.toString(),"UTF-8"));
        }
        ret.push(URLDecoder.decode(element,"UTF-8"));
        extractElements(ret,pElementStack,null);
    }

    private Type extractType(String pTypeS) {
        for (Type t : Type.values()) {
            if (t.getValue().equals(pTypeS)) {
                return t;
            }
        }
        throw new IllegalArgumentException("Invalid request type '" + pTypeS + "'");
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




    public String getValue() {
        return value;
    }

    public Type getType() {
        return type;
    }

    public String getOperation() {
        return operation;
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

    // ==================================================================================
    // Dedicated parser for the various operations. They are installed as static processors.
    interface Processor {
        void process(JmxRequest r,Stack<String> e)
                throws MalformedObjectNameException;
        void setupJSON(JmxRequest r);
    }

    private static Map<Type,Processor> processorMap;

    static {
        processorMap = new HashMap<Type, Processor>();
        processorMap.put(Type.READ,new Processor() {
            public void process(JmxRequest r,Stack<String> e) throws MalformedObjectNameException {
                r.objectNameS = e.pop();
                r.objectName = new ObjectName(r.objectNameS);
                r.attributeName = e.pop();
            }

            public void setupJSON(JmxRequest r) {
                r.put("mbean",r.objectName.getCanonicalName());
                r.put("attribute",r.attributeName);
                String path = r.getExtraArgsAsPath();
                if (path != null) {
                    r.put("path",path);
                }
            }
        });
        processorMap.put(Type.WRITE,new Processor() {

            public void process(JmxRequest r, Stack<String> e) throws MalformedObjectNameException {
                r.objectNameS = e.pop();
                r.objectName = new ObjectName(r.objectNameS);
                r.attributeName = e.pop();
                r.value = e.pop();
            }

            public void setupJSON(JmxRequest r) {
                r.put("mbean",r.objectName.getCanonicalName());
                r.put("attribute",r.attributeName);
                String path = r.getExtraArgsAsPath();
                if (path != null) {
                    r.put("path",path);
                }
                r.put("value",r.value);
            }
        });
        processorMap.put(Type.EXEC,new Processor() {

            public void process(JmxRequest r, Stack<String> e) throws MalformedObjectNameException {
                r.objectNameS = e.pop();
                r.objectName = new ObjectName(r.objectNameS);
                r.operation = e.pop();
            }

            public void setupJSON(JmxRequest r) {
                r.put("mbean",r.objectName.getCanonicalName());
                r.put("operation",r.operation);
                if (r.extraArgs.size() > 0) {
                    r.put("arguments",r.extraArgs);
                }
            }
        });

        processorMap.put(Type.LIST,new Processor() {
            public void process(JmxRequest r, Stack<String> e) throws MalformedObjectNameException {
            }

            public void setupJSON(JmxRequest r) {
            }
        });
        processorMap.put(Type.VERSION,new Processor() {

            public void process(JmxRequest r, Stack<String> e) throws MalformedObjectNameException {
            }

            public void setupJSON(JmxRequest r) {
            }
        });

        processorMap.put(Type.SEARCH,new Processor() {
            public void process(JmxRequest r,Stack<String> e) throws MalformedObjectNameException {
                r.objectNameS = e.pop();
                r.objectName = new ObjectName(r.objectNameS);
            }

            public void setupJSON(JmxRequest r) {
                r.put("mbean",r.objectName.getCanonicalName());
            }
        });
    }
}
