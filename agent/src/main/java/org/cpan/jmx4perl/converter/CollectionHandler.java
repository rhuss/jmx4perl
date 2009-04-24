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

import java.util.Collection;
import java.util.Iterator;
import java.util.List;
import java.util.Stack;

/**
 * @author roland
 * @since Apr 19, 2009
 */
public class CollectionHandler implements AttributeToJsonConverter.Handler {

    public Class getType() {
        return Collection.class;
    }

    public Object handle(AttributeToJsonConverter pConverter, Object pValue, Stack<String> pExtraArgs) {
        Collection list = (Collection) pValue;
        List ret = null;
        Iterator it = list.iterator();
        if (!pExtraArgs.isEmpty()) {
            int idx = Integer.parseInt(pExtraArgs.pop());
            for (int i = 0;i < list.size(); i++) {
                Object val = it.next();
                if (idx >= 0 && i == idx) {
                    return pConverter.prepareForJson(val,pExtraArgs);
                }
            }
            throw new IllegalArgumentException(
                    "Provided index " + idx + " is out of range [0 .. " +
                            list.size() + " for list " + pValue);
        } else {
            ret = new JSONArray();
            for (int i = 0;i < list.size(); i++) {
                Object val = it.next();
                ret.add(pConverter.prepareForJson(val,pExtraArgs));
            }
            return ret;
        }
    }
}