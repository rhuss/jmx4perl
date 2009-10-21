package org.jmx4perl.converter;

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
 * @since Jun 11, 2009
 */
public class StringToObjectConverter {

    public Object convertFromString(String pType, String pValue) {
        // TODO: Look for an external solution or support more types
        // At least use a map for lookup
        if ("[null]".equals(pValue)) {
            return null;
        } else if ("\"\"".equals(pValue)) {
            if (String.class.getName().equals(pType)) {
                return "";
            } else {
                throw new IllegalArgumentException("Cannot convert empty string tag to type " + pType);
            }
        }
        if (String.class.getName().equals(pType)) {
            return pValue;
        } else if (Integer.class.getName().equals(pType) || "int".equals(pType)){
            return Integer.getInteger(pValue);
        } else if (Long.class.getName().equals(pType) || "long".equals(pType)){
            return Long.getLong(pValue);
        } else if (Boolean.class.getName().equals(pType) || "boolean".equals(pType)){
            return new Boolean(pValue);
        } else {
            throw new IllegalArgumentException("Cannot convert string " + pValue + " to type " + pType);
        }
    }
}
