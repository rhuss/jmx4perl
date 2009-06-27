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

package org.jmx4perl.converter.attribute;

import org.jmx4perl.converter.StringToObjectConverter;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.Stack;

/**
 * @author roland
 * @since Apr 19, 2009
 */
public class PlainValueHandler implements AttributeConverter.Handler {

    public Class getType() {
        return Object.class;
    }

    public Object extractObject(AttributeConverter pConverter, Object pValue, Stack pExtraArgs,boolean jsonify) {
        // TODO: Check extra args for an expression which should be applied to the
        // value object to get the 'real' value.
        // I.e. if pExtraArgs is not empty extract via an expression language the
        // next element.
        return jsonify ? pValue.toString() : pValue;
    }

    // Using standard sett semantics
    public Object setObjectValue(StringToObjectConverter pConverter,Object pInner, String pAttribute, String pValue)
            throws IllegalAccessException, InvocationTargetException {
        // Move this to plain object handler
        String rest = new StringBuffer(pAttribute.substring(0,1).toUpperCase())
                .append(pAttribute.substring(1)).toString();
        String setter = new StringBuffer("set").append(rest).toString();
        String getter = new StringBuffer("get").append(rest).toString();

        Class clazz = pInner.getClass();
        Method found = null;
        for (Method method : clazz.getMethods()) {
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
            Method getMethod = clazz.getMethod(getter);
            oldValue = getMethod.invoke(pInner);
        } catch (NoSuchMethodException exp) {
            // Ignored, we simply dont return an old value
            oldValue = null;
        }
        found.invoke(pInner,pConverter.convertFromString(params[0].getName(),pValue));
        return oldValue;
    }
}
