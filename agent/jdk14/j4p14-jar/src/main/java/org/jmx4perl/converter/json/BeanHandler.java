package org.jmx4perl.converter.json;

import org.jmx4perl.converter.StringToObjectConverter;
import org.json.simple.JSONObject;

import javax.management.AttributeNotFoundException;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
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
 * @author roland
 * @since Apr 19, 2009
 */
public class BeanHandler implements ObjectToJsonConverter.Handler {

    final private static Set FINAL_CLASSES = new HashSet(Arrays.asList(
            new Class[] {
                    String.class,
                    Number.class,
                    Byte.class,
                    Double.class,
                    Float.class,
                    Long.class,
                    Short.class,
                    Integer.class,
                    Boolean.class,
                    Date.class
            }
    ));

    final private static Set IGNORE_METHODS = new HashSet(Arrays.asList(
            new String[] { "getClass" }
    ));
    private static final String[] GETTER_PREFIX = new String[] { "get", "is"};


    public Class getType() {
        return Object.class;
    }

    public Object extractObject(ObjectToJsonConverter pConverter, Object pValue,
                                Stack pExtraArgs,boolean jsonify)
            throws AttributeNotFoundException {
        if (!pExtraArgs.isEmpty()) {
            String attribute = (String) pExtraArgs.pop();
            Object attributeValue = extractBeanAttribute(pValue,attribute);
            return pConverter.extractObject(attributeValue,pExtraArgs,jsonify);
        } else {
            if (!jsonify) {
                return pValue;
            }
            if (pValue.getClass().isPrimitive() || FINAL_CLASSES.contains(pValue.getClass())) {
                return pValue.toString();
            } else {
                List attributes = extractBeanAttributes(pValue);
                if (attributes != null && attributes.size() > 0) {
                    Map ret = new JSONObject();
                    for (Iterator it = attributes.iterator(); it.hasNext(); ) {
                        String attribute = (String) it.next();
                        Object value = extractBeanAttribute(pValue,attribute);
                        if (value == null) {
                            ret.put(attribute,null);
                        } else if (value == pValue) {
                            // Break Cycle
                            ret.put(attribute,"[this]");
                        } else {
                            ret.put(attribute,
                                    pConverter.extractObject(value,pExtraArgs,jsonify));
                        }
                    }
                    return ret;
                } else {
                    // No further attributes, return string representation
                    return pValue.toString();
                }
            }
        }
    }

    private List extractBeanAttributes(Object pValue) {
        List attrs = new ArrayList();
        Method[] methods = pValue.getClass().getMethods();
        for (int j = 0; j < methods.length; j++) {
            Method method = methods[j];
            if (Modifier.isStatic(method.getModifiers()) || IGNORE_METHODS.contains(method.getName())) {
                continue;
            }
            String name = method.getName();

            for (int i = 0; i < GETTER_PREFIX.length; i++) {
                String pref = GETTER_PREFIX[i];
                if (name.startsWith(pref) && name.length() > pref.length()
                        && method.getParameterTypes().length == 0) {
                    int len = pref.length();
                    String attribute =
                            new StringBuffer(name.substring(len,len+1).toLowerCase()).
                                    append(name.substring(len+1)).toString();
                    attrs.add(attribute);
                }
            }
        }
        return attrs;
    }

    private Object extractBeanAttribute(Object pValue, String pAttribute)
            throws AttributeNotFoundException {
        Class clazz = pValue.getClass();

        Method method = null;

        for (int i = 0; i < GETTER_PREFIX.length; i++) {
            String pref = GETTER_PREFIX[i];
            String methodName =
                    new StringBuffer(pref)
                            .append(pAttribute.substring(0,1).toUpperCase())
                            .append(pAttribute.substring(1)).toString();
            try {
                method = clazz.getMethod(methodName, new Class[0]);
            } catch (NoSuchMethodException e) {
                // Try next one
                continue;
            }
            // We found a valid method
            break;
        }
        if (method == null) {
            throw new AttributeNotFoundException(
                    "No getter known for attribute " + pAttribute + " for class " + pValue.getClass().getName());
        }
        try {
            method.setAccessible(true);
            return method.invoke(pValue, new Object[0]);
        } catch (IllegalAccessException e) {
            throw new IllegalStateException("Error while extracting " + pAttribute
                    + " from " + pValue);
        } catch (InvocationTargetException e) {
            throw new IllegalStateException("Error while extracting " + pAttribute
                    + " from " + pValue);
        }
    }

    // Using standard set semantics
    public Object setObjectValue(StringToObjectConverter pConverter,Object pInner, String pAttribute, String pValue)
            throws IllegalAccessException, InvocationTargetException {
        // Move this to plain object handler
        String rest = new StringBuffer(pAttribute.substring(0,1).toUpperCase())
                .append(pAttribute.substring(1)).toString();
        String setter = new StringBuffer("set").append(rest).toString();
        String getter = new StringBuffer("get").append(rest).toString();

        Class clazz = pInner.getClass();
        Method found = null;
        Method[] methods = pValue.getClass().getMethods();
        for (int j = 0; j < methods.length; j++) {
            Method method = methods[j];
            if (method.getName().equals(setter)) {
                found = method;
                break;
            }
        }
        if (found == null) {
            throw new IllegalArgumentException(
                    "No Method " + setter + " known for object of type " + clazz.getName());
        }
        Class params[] = found.getParameterTypes();
        if (params.length != 1) {
            throw new IllegalArgumentException(
                    "Invalid parameter signature for " + setter + " known for object of type "
                            + clazz.getName() + ". Setter must take exactly one parameter.");
        }
        Object oldValue;
        try {
            Method getMethod = clazz.getMethod(getter, new Class[0]);
            oldValue = getMethod.invoke(pInner, new Object[0]);
        } catch (NoSuchMethodException exp) {
            // Ignored, we simply dont return an old value
            oldValue = null;
        }
        found.invoke(pInner,new Object[] { pConverter.convertFromString(params[0].getName(),pValue) });
        return oldValue;
    }
}
