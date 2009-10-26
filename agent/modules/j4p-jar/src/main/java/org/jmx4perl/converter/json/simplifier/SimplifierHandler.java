package org.jmx4perl.converter.json.simplifier;

import org.jmx4perl.converter.StringToObjectConverter;
import org.jmx4perl.converter.json.ObjectToJsonConverter;
import org.json.simple.JSONObject;

import javax.management.AttributeNotFoundException;
import java.lang.reflect.InvocationTargetException;
import java.util.HashMap;
import java.util.Map;
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
 * @author roland
 * @since Jul 27, 2009
 */
abstract class SimplifierHandler<T> implements ObjectToJsonConverter.Handler {

    private Map<String, Extractor<T>> extractorMap;

    private Class<T> type;

    SimplifierHandler(Class<T> pType) {
        extractorMap = new HashMap<String, Extractor<T>>();
        type = pType;
        init(extractorMap);
    }

    public Class getType() {
        return type;
    }

    public Object extractObject(ObjectToJsonConverter pConverter, Object pValue, Stack<String> pExtraArgs, boolean jsonify)
            throws AttributeNotFoundException {
        if (pExtraArgs.size() > 0) {
            String element = pExtraArgs.pop();
            Extractor<T> extractor = extractorMap.get(element);
            if (extractor == null) {
                throw new IllegalArgumentException("Illegal path element " + element + " for object " + pValue);
            }

            Object attributeValue = null;
            try {
                attributeValue = extractor.extract((T) pValue);
                return pConverter.extractObject(attributeValue,pExtraArgs,jsonify);
            } catch (SkipAttributeException e) {
                throw new IllegalArgumentException("Illegal path element " + element + " for object " + pValue,e);
            }
        } else {
            JSONObject ret = new JSONObject();
            for (Map.Entry<String, Extractor<T>> entry : extractorMap.entrySet()) {
                Object value = null;
                try {
                    value = entry.getValue().extract((T) pValue);
                } catch (SkipAttributeException e) {
                    // Skip this one ...
                    continue;
                }
                ret.put(entry.getKey(),
                        pConverter.extractObject(value,pExtraArgs,jsonify));
            }
            return ret;
        }
    }

    public Object setObjectValue(StringToObjectConverter pConverter, Object pInner,
                                 String pAttribute, String pValue) throws IllegalAccessException, InvocationTargetException {
        return null;
    }

    @SuppressWarnings("unchecked")
    protected void addExtractors(Object[][] pAttrExtractors) {
        for (int i = 0;i< pAttrExtractors.length; i++) {
            extractorMap.put((String) pAttrExtractors[i][0],
                             (Extractor<T>) pAttrExtractors[i][1]);
        }
    }


    // ============================================================================
    interface Extractor<T> {
        Object extract(T value) throws SkipAttributeException;
    }

    static class SkipAttributeException extends Exception {}

    // Add extractors to map
    abstract void init(Map<String, Extractor<T>> pExtractorMap);
}
