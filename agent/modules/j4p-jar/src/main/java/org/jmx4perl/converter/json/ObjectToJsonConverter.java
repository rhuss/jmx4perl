package org.jmx4perl.converter.json;


import org.jmx4perl.Config;
import org.jmx4perl.JmxRequest;
import org.jmx4perl.converter.StringToObjectConverter;
import org.jmx4perl.converter.json.simplifier.ClassHandler;
import org.jmx4perl.converter.json.simplifier.DomElementHandler;
import org.jmx4perl.converter.json.simplifier.FileHandler;
import org.jmx4perl.converter.json.simplifier.UrlHandler;
import static org.jmx4perl.Config.*;

import org.json.simple.JSONObject;
import javax.management.AttributeNotFoundException;
import java.lang.reflect.InvocationTargetException;
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
 * A converter which convert attribute and return values
 * into a JSON representation. It uses certain handlers for this which
 * are registered programatically in the constructor.
 *
 * Each handler gets a reference to this converter object so that it
 * can use it for a recursive solution of nested objects.
 *
 * @author roland
 * @since Apr 19, 2009
 */
public class ObjectToJsonConverter {

    // List of dedicated handlers
    private List<Handler> handlers;

    private ArrayHandler arrayHandler;

    // Thread-Local set in order to prevent infinite recursions
    private ThreadLocal<StackContext> stackContextLocal = new ThreadLocal<StackContext>();

    // Thread-Local for the fault handler when extracting value
    private ThreadLocal<JmxRequest.ValueFaultHandler> faultHandlerLocal = new ThreadLocal<JmxRequest.ValueFaultHandler>();

    // Used for converting string to objects when setting attributes
    private StringToObjectConverter stringToObjectConverter;

    private Integer hardMaxDepth,hardMaxCollectionSize,hardMaxObjects;

    public ObjectToJsonConverter(StringToObjectConverter pStringToObjectConverter,
                                 Map<Config,String> pConfig) {
        initLimits(pConfig);

        handlers = new ArrayList<Handler>();

        // Collection handlers
        handlers.add(new ListHandler());
        handlers.add(new MapHandler());

        // Special, well known objects
        handlers.add(new ClassHandler());
        handlers.add(new FileHandler());
        handlers.add(new DomElementHandler());
        handlers.add(new UrlHandler());

        handlers.add(new CompositeDataHandler());
        handlers.add(new TabularDataHandler());

        // Must be last in handlers, used default algorithm
        handlers.add(new BeanHandler());

        arrayHandler = new ArrayHandler();

        stringToObjectConverter = pStringToObjectConverter;
    }

    public JSONObject convertToJson(Object pValue, JmxRequest pRequest)
            throws AttributeNotFoundException {
        Stack<String> extraStack = reverseArgs(pRequest);

        setupContext(pRequest);

        try {
            Object jsonResult = extractObject(pValue,extraStack,true);
            JSONObject jsonObject = new JSONObject();
            jsonObject.put("value",jsonResult);
            jsonObject.put("request",pRequest.toJSON());
            return jsonObject;
        } finally {
            clearContext();
        }
    }

    /**
     * Get values for a write request. This method returns an array with two objects.
     * If no path is given (<code>pRequest.getExtraArgs() == null</code>), the returned values
     *  are the new value
     * and the old value. However, if a path is set, the returned new value is the outer value (which
     * can be set by an corresponding JMX set operation) and the old value is the value
     * of the object specified by the given path.
     *
     * @param pType type of the outermost object to set as returned by an MBeanInfo structure.
     * @param pCurrentValue the object of the outermost object which can be null
     * @param pRequest the initial request
     * @return object array with two elements (see above)
     *
     * @throws AttributeNotFoundException if no such attribute exists (as specified in the request)
     * @throws IllegalAccessException if access to MBean fails
     * @throws InvocationTargetException reflection error when setting an object's attribute
     */
    public Object[] getValues(String pType, Object pCurrentValue, JmxRequest pRequest)
            throws AttributeNotFoundException, IllegalAccessException, InvocationTargetException {
        List<String> extraArgs = pRequest.getExtraArgs();

        if (extraArgs != null && extraArgs.size() > 0) {
            if (pCurrentValue == null ) {
                throw new IllegalArgumentException(
                        "Cannot set value with path when parent object is not set");
            }

            String lastPathElement = extraArgs.remove(extraArgs.size()-1);
            Stack<String> extraStack = reverseArgs(pRequest);
            // Get the object pointed to do with path-1
            Object inner = extractObject(pCurrentValue,extraStack,false);
            // Set the attribute pointed to by the path elements
            // (depending of the parent object's type)
            Object oldValue = setObjectValue(inner,lastPathElement,pRequest.getValue());

            // We set an inner value, hence we have to return provided value itself.
            return new Object[] {
                    pCurrentValue,
                    oldValue
            };
        } else {
            // Return the objectified value
            return new Object[] {
                    stringToObjectConverter.convertFromString(pType,pRequest.getValue()),
                    pCurrentValue
            };
        }
    }

    // =================================================================================

    private void initLimits(Map<Config, String> pConfig) {
        // Max traversal depth
        if (pConfig != null) {
            hardMaxDepth = getNullSaveIntLimit(MAX_DEPTH.getValue(pConfig));

            // Max size of collections
            hardMaxCollectionSize = getNullSaveIntLimit(MAX_COLLECTION_SIZE.getValue(pConfig));

            // Maximum of overal objects returned by one traversal.
            hardMaxObjects = getNullSaveIntLimit(MAX_OBJECTS.getValue(pConfig));
        } else {
            hardMaxDepth = getNullSaveIntLimit(MAX_DEPTH.getDefaultValue());
            hardMaxCollectionSize = getNullSaveIntLimit(MAX_COLLECTION_SIZE.getDefaultValue());
            hardMaxObjects = getNullSaveIntLimit(MAX_OBJECTS.getDefaultValue());
        }
    }

    private Integer getNullSaveIntLimit(String pValue) {
        Integer ret = pValue != null ? Integer.parseInt(pValue) : null;
        // "0" is interpreted as no limit
        return (ret != null && ret == 0) ? null : ret;
    }

    private Stack<String> reverseArgs(JmxRequest pRequest) {
        Stack<String> extraStack = new Stack<String>();
        List<String> extraArgs = pRequest.getExtraArgs();
        if (extraArgs != null) {
            // Needs first extra argument at top of the stack
            for (int i = extraArgs.size() - 1;i >=0;i--) {
                extraStack.push(extraArgs.get(i));
            }
        }
        return extraStack;
    }


    public Object extractObject(Object pValue,Stack<String> pExtraArgs,boolean jsonify)
            throws AttributeNotFoundException {
        StackContext stackContext = stackContextLocal.get();
        String limitReached = checkForLimits(pValue,stackContext);
        if (limitReached != null) {
            return limitReached;
        }
        try {
            stackContext.push(pValue);
            stackContext.incObjectCount();

            if (pValue == null) {
                return null;
            }

            if (pValue.getClass().isArray()) {
                // Special handling for arrays
                return arrayHandler.extractObject(this,pValue,pExtraArgs,jsonify);
            }
            return callHandler(pValue, pExtraArgs, jsonify);
        } finally {
            stackContext.pop();
        }
    }

    private String checkForLimits(Object pValue, StackContext pStackContext) {
        Integer maxDepth = pStackContext.getMaxDepth();
        if (maxDepth != null && pStackContext.size() > maxDepth) {
            // We use its string representation
            return pValue.toString();
        }
        if (pValue != null && pStackContext.alreadyVisited(pValue)) {
            return "[Reference " + pValue.getClass().getName() + "@" + Integer.toHexString(pValue.hashCode()) + "]";
        }
        if (exceededMaxObjects()) {
            return "[Object limit exceeded]";
        }
        return null;
    }

    private Object callHandler(Object pValue, Stack<String> pExtraArgs, boolean jsonify)
            throws AttributeNotFoundException {
        Class pClazz = pValue.getClass();
        for (Handler handler : handlers) {
            if (handler.getType() != null && handler.getType().isAssignableFrom(pClazz)) {
                return handler.extractObject(this,pValue,pExtraArgs,jsonify);
            }
        }
        throw new IllegalStateException(
                "Internal error: No handler found for class " + pClazz +
                    " (object: " + pValue + ", extraArgs: " + pExtraArgs + ")");
    }

    // returns the old value
    private Object setObjectValue(Object pInner, String pAttribute, String pValue)
            throws IllegalAccessException, InvocationTargetException {

        // Call various handlers depending on the type of the inner object, as is extract Object

        Class clazz = pInner.getClass();
        if (clazz.isArray()) {
            return arrayHandler.setObjectValue(stringToObjectConverter,pInner,pAttribute,pValue);
        }
        for (Handler handler : handlers) {
            if (handler.getType() != null && handler.getType().isAssignableFrom(clazz)) {
                return handler.setObjectValue(stringToObjectConverter,pInner,pAttribute,pValue);
            }
        }

        throw new IllegalStateException(
                "Internal error: No handler found for class " + clazz + " for getting object value." +
                        " (object: " + pInner + ", attribute: " + pAttribute + ", value: " + pValue + ")");


       }

    // Used for testing only. Hence final and package local
    final ThreadLocal<StackContext> getStackContextLocal() {
        return stackContextLocal;
    }



    // Check whether JSR77 classes are available
    // Not used for the moment, but left here for reference
    /*
    private boolean knowsAboutJsr77() {
        try {
            Class.forName("javax.management.j2ee.statistics.Stats");
            // This is for Weblogic 9, which seems to have "Stats" but not the rest
            Class.forName("javax.management.j2ee.statistics.JMSStats");
            return true;
        } catch (ClassNotFoundException exp) {
            return false;
        }
    }
    */

    // =============================================================================
    // Handler interface for dedicated handler

    public interface Handler {
        // Type for which this handler is responsiple
        Class getType();

        // Extract an object from pValue. In the simplest case, this is the value itself.
        // For more complex data types, it is converted into a JSON structure if possible
        // (and if 'jsonify' is true). pExtraArgs is not nul, this returns only a substructure,
        // specified by the path represented by this stack
        Object extractObject(ObjectToJsonConverter pConverter,Object pValue,Stack<String> pExtraArgs,boolean jsonify)
                throws AttributeNotFoundException;

        // Set an object value on a certrain attribute.
        Object setObjectValue(StringToObjectConverter pConverter,Object pInner, String pAttribute, String pValue)
                throws IllegalAccessException, InvocationTargetException;
    }


    // =============================================================================

    int getCollectionLength(int originalLength) {
        ObjectToJsonConverter.StackContext ctx = stackContextLocal.get();
        Integer maxSize = ctx.getMaxCollectionSize();
        if (maxSize != null && originalLength > maxSize) {
            return maxSize;
        } else {
            return originalLength;
        }
    }

    /**
     * Get the fault handler used for dealing with exceptions during value extraction.
     *
     * @return the fault handler
     */
    public JmxRequest.ValueFaultHandler getValueFaultHandler() {
        ObjectToJsonConverter.StackContext ctx = stackContextLocal.get();
        return ctx.getValueFaultHandler();
    }


    boolean exceededMaxObjects() {
        ObjectToJsonConverter.StackContext ctx = stackContextLocal.get();
        return ctx.getMaxObjects() != null && ctx.getObjectCount() > ctx.getMaxObjects();
    }

    void clearContext() {
        stackContextLocal.remove();
    }

    void setupContext(JmxRequest pRequest) {
        Integer maxDepth = getLimit(pRequest.getProcessingConfigAsInt(Config.MAX_DEPTH),hardMaxDepth);
        Integer maxCollectionSize = getLimit(pRequest.getProcessingConfigAsInt(Config.MAX_COLLECTION_SIZE),hardMaxCollectionSize);
        Integer maxObjects = getLimit(pRequest.getProcessingConfigAsInt(Config.MAX_OBJECTS),hardMaxObjects);

        setupContext(maxDepth, maxCollectionSize, maxObjects, pRequest.getValueFaultHandler());
    }

    void setupContext(Integer pMaxDepth, Integer pMaxCollectionSize, Integer pMaxObjects,
                      JmxRequest.ValueFaultHandler pValueFaultHandler) {
        StackContext stackContext = new StackContext(pMaxDepth,pMaxCollectionSize,pMaxObjects,pValueFaultHandler);
        stackContextLocal.set(stackContext);
    }

    private Integer getLimit(Integer pReqValue, Integer pHardLimit) {
        if (pReqValue == null) {
            return pHardLimit;
        }
        if (pHardLimit != null) {
            return pReqValue > pHardLimit ? pHardLimit : pReqValue;
        } else {
            return pReqValue;
        }
    }


    // =============================================================================
    // Context used for detecting call loops and the like

    private static final Set<Class> SIMPLE_TYPES = new HashSet<Class>(Arrays.asList(
            String.class,
            Number.class,
            Long.class,
            Integer.class,
            Boolean.class,
            Date.class
    ));

    static class StackContext {

        private Set objectsInCallStack = new HashSet();
        private Stack callStack = new Stack();
        private Integer maxDepth;
        private Integer maxCollectionSize;
        private Integer maxObjects;

        private int objectCount = 0;
        private JmxRequest.ValueFaultHandler valueFaultHandler;

        public StackContext(Integer pMaxDepth, Integer pMaxCollectionSize, Integer pMaxObjects, JmxRequest.ValueFaultHandler pValueFaultHandler) {
            maxDepth = pMaxDepth;
            maxCollectionSize = pMaxCollectionSize;
            maxObjects = pMaxObjects;
            valueFaultHandler = pValueFaultHandler;
        }

        void push(Object object) {
            callStack.push(object);

            if (object != null && !SIMPLE_TYPES.contains(object.getClass())) {
                objectsInCallStack.add(object);
            }
        }

        Object pop() {
            Object ret = callStack.pop();
            if (ret != null && !SIMPLE_TYPES.contains(ret.getClass())) {
                objectsInCallStack.remove(ret);
            }
            return ret;
        }

        boolean alreadyVisited(Object object) {
            return objectsInCallStack.contains(object);
        }

        int stackLevel() {
            return callStack.size();
        }

        public int size() {
            return objectsInCallStack.size();
        }

        public void setMaxDepth(Integer pMaxDepth) {
            maxDepth = pMaxDepth;
        }

        public Integer getMaxDepth() {
            return maxDepth;
        }


        public Integer getMaxCollectionSize() {
            return maxCollectionSize;
        }

        public void incObjectCount() {
            objectCount++;
        }

        public int getObjectCount() {
            return objectCount;
        }

        public Integer getMaxObjects() {
            return maxObjects;
        }

        public JmxRequest.ValueFaultHandler getValueFaultHandler() {
            return valueFaultHandler;
        }
    }



}
