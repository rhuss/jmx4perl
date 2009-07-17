package org.jmx4perl.converter.attribute;


import org.jmx4perl.JmxRequest;
import org.jmx4perl.converter.StringToObjectConverter;
import org.jmx4perl.converter.attribute.stats.*;
import org.json.simple.JSONObject;

import javax.management.AttributeNotFoundException;
import java.lang.reflect.InvocationTargetException;
import java.util.ArrayList;
import java.util.List;
import java.util.Stack;

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

    List<Handler> handlers;

    ArrayHandler arrayHandler;

    // Used for converting string to objects when setting attributes
    private StringToObjectConverter stringToObjectConverter;

    public ObjectToJsonConverter(StringToObjectConverter pStringToObjectConverter) {
        handlers = new ArrayList<Handler>();

        handlers.add(new CompositeHandler());
        handlers.add(new TabularDataHandler());
        handlers.add(new ListHandler());
        handlers.add(new MapHandler());

        if (knowsAboutJsr77()) {
            // Order is important here since theses handle all
            // Stats objets. It goes from the most specific to the
            // least specific
            handlers.add(new JmsProducerStatsHandler());
            handlers.add(new JmsConsumerStatsHandler());
            handlers.add(new JmsSessionStatsHandler());
            handlers.add(new JmsConnectionStatsHandler());
            handlers.add(new JmsStatsHandler());
            handlers.add(new JcaStatsHandler());
            handlers.add(new JdbcConnectionStatsHandler());
            handlers.add(new JdbcStatsHandler());
            handlers.add(new StatsHandler());

            // Statistic objects
            handlers.add(new BoundedRangeStatisticHandler());
            handlers.add(new BoundaryStatisticHandler());
            handlers.add(new RangeStatisticHandler());
            handlers.add(new TimeStatisticHandler());
            handlers.add(new CountStatisticHandler());
            handlers.add(new StatisticHandler());
        }

        // Must be last ...
        handlers.add(new PlainValueHandler());

        arrayHandler = new ArrayHandler();


        stringToObjectConverter = pStringToObjectConverter;
    }


    public JSONObject convertToJson(Object pValue, JmxRequest pRequest)
            throws AttributeNotFoundException {
        Stack<String> extraStack = reverseArgs(pRequest);

        Object jsonResult = extractObject(pValue,extraStack,true);
        JSONObject jsonObject = new JSONObject();
        jsonObject.put("value",jsonResult);
        jsonObject.put("request",pRequest);
        return jsonObject;
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


    public Object extractObject(Object pValue,Stack<String> pExtraArgs,boolean jsonify) throws AttributeNotFoundException {
        if (pValue == null) {
            return null;
        }
        Class clazz = pValue.getClass();
        if (clazz.isArray()) {
            return arrayHandler.extractObject(this,pValue,pExtraArgs,jsonify);
        }
        for (Handler handler : handlers) {
            if (handler.getType() != null && handler.getType().isAssignableFrom(clazz)) {
                return handler.extractObject(this,pValue,pExtraArgs,jsonify);
            }
        }
        throw new RuntimeException(
                "Internal error: No handler found for class " + clazz +
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

        throw new RuntimeException(
                "Internal error: No handler found for class " + clazz + " for getting object value." +
                        " (object: " + pInner + ", attribute: " + pAttribute + ", value: " + pValue + ")");


       }


    // Check whether JSR77 classes are available
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



}
