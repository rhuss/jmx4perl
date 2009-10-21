package org.jmx4perl.converter.json.simplifier;

import org.jmx4perl.converter.json.ObjectToJsonConverter;
import org.jmx4perl.converter.StringToObjectConverter;
import org.json.simple.JSONObject;

import javax.management.AttributeNotFoundException;
import java.util.Map;
import java.util.HashMap;
import java.util.Stack;
import java.util.Iterator;
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
 * @since Jul 27, 2009
 */
abstract class SimplifierHandler implements ObjectToJsonConverter.Handler {

    Map extractorMap;

    private Class type;

    SimplifierHandler(Class pType) {
        extractorMap = new HashMap();
        type = pType;
        init(extractorMap);
    }

    public Class getType() {
        return type;
    }

    public Object extractObject(ObjectToJsonConverter pConverter, Object pValue, Stack pExtraArgs, boolean jsonify)
            throws AttributeNotFoundException {
        if (pExtraArgs.size() > 0) {
            String element = (String) pExtraArgs.pop();
            Extractor extractor = (Extractor) extractorMap.get(element);
            if (extractor == null) {
                throw new IllegalArgumentException("Illegal path element " + element + " for object " + pValue);
            }

            Object attributeValue = null;
            try {
                attributeValue = extractor.extract(pValue);
                return pConverter.extractObject(attributeValue,pExtraArgs,jsonify);
            } catch (SkipAttributeException e) {
                throw new IllegalArgumentException("Illegal path element " + element + " for object " + pValue);
            }
        } else {
            JSONObject ret = new JSONObject();
            for (Iterator it = extractorMap.entrySet().iterator(); it.hasNext(); ) {
                Map.Entry entry = (Map.Entry) it.next();
                Object value = null;
                try {
                    value = ((Extractor) entry.getValue()).extract(pValue);
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


    // ============================================================================
    interface Extractor {
        Object extract(Object value) throws SkipAttributeException;
    }

    static class SkipAttributeException extends Exception {}

    // Add extractors to map
    abstract void init(Map pExtractorMap);
}
