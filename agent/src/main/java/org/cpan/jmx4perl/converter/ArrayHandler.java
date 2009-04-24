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

import org.json.simple.JSONArray;

import java.lang.reflect.Array;
import java.util.List;
import java.util.Stack;

/**
 * @author roland
 * @since Apr 19, 2009
 */
public class ArrayHandler implements AttributeToJsonConverter.Handler {

    public Class getType() {
        // Special handler, no specific Type
        return null;
    }

    public Object handle(AttributeToJsonConverter pConverter, Object pValue, Stack<String> pExtraArgs) {
        int length = Array.getLength(pValue);
        if (!pExtraArgs.isEmpty()) {
            Object obj = Array.get(pValue, Integer.parseInt(pExtraArgs.pop()));
            return pConverter.prepareForJson(obj,pExtraArgs);
        } else {
            List<Object> ret = new JSONArray();
            for (int i=0;i<length;i++) {
                Object obj = Array.get(pValue, i);
                ret.add(pConverter.prepareForJson(obj,pExtraArgs));
            }
            return ret;
        }
    }
}
