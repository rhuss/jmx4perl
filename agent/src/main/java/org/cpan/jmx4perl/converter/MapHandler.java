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
 * Contact roland@cpan.org for any licensing questions.
 */

package org.cpan.jmx4perl.converter;

import org.json.simple.JSONObject;

import java.util.*;
import java.net.URLDecoder;
import java.io.UnsupportedEncodingException;

/**
 * @author roland
 * @since Apr 19, 2009
 */
public class MapHandler implements AttributeToJsonConverter.Handler {

    public Class getType() {
        return Map.class;
    }

    public Object handle(AttributeToJsonConverter pConverter, Object pValue,
                         Stack<String> pExtraArgs) {
        Map<Object,Object> map = (Map<Object,Object>) pValue;

        if (!pExtraArgs.isEmpty()) {
            try {
                String decodedKey = URLDecoder.decode(pExtraArgs.pop(), "UTF-8");
                for (Map.Entry entry : map.entrySet()) {
                    if(decodedKey.equals(entry.getKey().toString())) {
                        return pConverter.prepareForJson(entry.getValue(),pExtraArgs);
                    }
                }
                throw new IllegalArgumentException("Map key " + decodedKey +
                        " is unknown for map " + trimString(pValue.toString()));
            } catch (UnsupportedEncodingException exp) {
                throw new RuntimeException("Internal: Encoding UTF-8 not supported");
            }
        } else {
            JSONObject ret = new JSONObject();
            for(Map.Entry entry : map.entrySet()) {
                ret.put(entry.getKey(),
                        pConverter.prepareForJson(entry.getValue(),pExtraArgs));
            }
            return ret;
        }
    }

    private String trimString(String pString) {
        if (pString.length() > 400) {
            return pString.substring(0,400) + " ...";
        } else {
            return pString;
        }
    }
}