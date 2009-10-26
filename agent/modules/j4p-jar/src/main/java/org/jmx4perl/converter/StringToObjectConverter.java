package org.jmx4perl.converter;

import java.util.Map;
import java.util.HashMap;

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


    private static final Map<String,Extractor> EXTRACTOR_MAP = new HashMap<String,Extractor>();

    static {
        EXTRACTOR_MAP.put(Integer.class.getName(),new IntExtractor());
        EXTRACTOR_MAP.put("int",new IntExtractor());
        EXTRACTOR_MAP.put(Long.class.getName(),new LongExtractor());
        EXTRACTOR_MAP.put("long",new LongExtractor());
        EXTRACTOR_MAP.put(Boolean.class.getName(),new BooleanExtractor());
        EXTRACTOR_MAP.put("boolean",new BooleanExtractor());
        EXTRACTOR_MAP.put(String.class.getName(),new StringExtractor());
    }

    public Object convertFromString(String pType, String pValue) {
        // TODO: Look for an external solution or support more types
        if ("[null]".equals(pValue)) {
            return null;
        }

        // Special string value
        if ("\"\"".equals(pValue)) {
            if (matchesType(pType,String.class)) {
                return "";
            }
            throw new IllegalArgumentException("Cannot convert empty string tag to type " + pType);
        }

        Extractor extractor = EXTRACTOR_MAP.get(pType);
        if (extractor == null) {
            throw new IllegalArgumentException("Cannot convert string " + pValue + " to type " + pType + " because no converter could be found");
        }
        return extractor.extract(pValue);
    }

    private boolean matchesType(String pType, Class pClass) {
        return pClass.getName().equals(pType);
    }

    // ===========================================================================
    // Extractor interface
    private interface Extractor {
        Object extract(String pValue);
    }

    private static class StringExtractor implements Extractor {
        public Object extract(String pValue) { return pValue; }
    }
    private static class IntExtractor implements Extractor {
        public Object extract(String pValue) { return Integer.parseInt(pValue); }
    }
    private static class LongExtractor implements Extractor {
        public Object extract(String pValue) { return Long.parseLong(pValue); }
    }
    private static class BooleanExtractor implements Extractor {
        public Object extract(String pValue) { return Boolean.parseBoolean(pValue); }
    }
}
