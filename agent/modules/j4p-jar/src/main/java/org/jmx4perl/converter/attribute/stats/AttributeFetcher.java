package org.jmx4perl.converter.attribute.stats;

import javax.management.AttributeNotFoundException;
import java.lang.reflect.Method;
import java.lang.reflect.InvocationTargetException;

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
 * @since Jul 10, 2009
 */
public class AttributeFetcher {

    public String getMethodName(String pAttribute) {
        // Conditionally convert lower-case naem to upper case name
        String first = pAttribute.substring(0,1).toUpperCase();
        String rest = pAttribute.substring(1);
        return new StringBuffer("get").append(first).append(rest).toString();
    }

    public Object fetchAttribute(Object pValue,String pAttribute) throws AttributeNotFoundException {
        String methodName = getMethodName(pAttribute);
        try {
            Method method = pValue.getClass().getMethod(methodName);
            return method.invoke(pValue);
        } catch (NoSuchMethodException e) {
            throw new AttributeNotFoundException("No attribute " + pAttribute +
                    " known for object " + pValue);
        } catch (IllegalAccessException e) {
            throw new AttributeNotFoundException("IllegalAccessException while accessing attribute "
                    + pAttribute + " of object " + pValue + ": " + e.getMessage());
        } catch (
                InvocationTargetException e) {
            throw new AttributeNotFoundException("InvocationTargetException while accessing attribute "
                    + pAttribute + " of object " + pValue + ": " + e.getMessage());
        }
    }
}
