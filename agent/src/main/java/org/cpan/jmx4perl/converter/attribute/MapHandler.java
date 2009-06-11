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

package org.cpan.jmx4perl.converter.attribute;

import org.cpan.jmx4perl.converter.StringToObjectConverter;
import org.json.simple.JSONObject;

import javax.management.AttributeNotFoundException;
import java.lang.reflect.InvocationTargetException;
import java.util.Map;
import java.util.Stack;

/**
 * @author roland
 * @since Apr 19, 2009
 */
public class MapHandler implements AttributeConverter.Handler {

    public Class getType() {
        return Map.class;
    }

    public Object extractObject(AttributeConverter pConverter, Object pValue,
                         Stack<String> pExtraArgs,boolean jsonify) throws AttributeNotFoundException {
        Map<Object,Object> map = (Map<Object,Object>) pValue;

        if (!pExtraArgs.isEmpty()) {
            String decodedKey = pExtraArgs.pop();
            for (Map.Entry entry : map.entrySet()) {
                // We dont access the map via a lookup since the key
                // are potentially object but we have to deal with string
                // representations
                if(decodedKey.equals(entry.getKey().toString())) {
                    return pConverter.extractObject(entry.getValue(),pExtraArgs,jsonify);
                }
            }
            throw new IllegalArgumentException("Map key " + decodedKey +
                    " is unknown for map " + trimString(pValue.toString()));
        } else {
            if (jsonify) {
                JSONObject ret = new JSONObject();
                for(Map.Entry entry : map.entrySet()) {
                    ret.put(entry.getKey(),
                            pConverter.extractObject(entry.getValue(),pExtraArgs,jsonify));
                }
                return ret;
            } else {
                return map;
            }
        }
    }

    public Object setObjectValue(StringToObjectConverter pConverter, Object pInner, String pAttribute, String pValueS)
            throws IllegalAccessException, InvocationTargetException {
        Map<Object,Object> map = (Map<Object,Object>) pInner;
        Object oldValue = null;
        Object oldKey = pAttribute;
        for (Map.Entry entry : map.entrySet()) {
            // We dont access the map via a lookup since the key
            // are potentially object but we have to deal with string
            // representations
            if(pAttribute.equals(entry.getKey().toString())) {
                oldValue = entry.getValue();
                oldKey = entry.getKey();
                break;
            }
        }
        Object value =
                oldValue != null ?
                        pConverter.convertFromString(oldValue.getClass().getName(),pValueS) :
                        pValueS;
        map.put(oldKey,value);
        return oldValue;
    }

    private String trimString(String pString) {
        if (pString.length() > 400) {
            return pString.substring(0,400) + " ...";
        } else {
            return pString;
        }
    }
}