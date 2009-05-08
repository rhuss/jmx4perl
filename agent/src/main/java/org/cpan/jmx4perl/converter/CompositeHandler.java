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

package org.cpan.jmx4perl.converter;

import org.json.simple.JSONObject;

import javax.management.openmbean.CompositeData;
import java.io.UnsupportedEncodingException;
import java.net.URLDecoder;
import java.util.Stack;
import java.util.Set;

/**
 * @author roland
 * @since Apr 19, 2009
 */
public class CompositeHandler implements AttributeToJsonConverter.Handler {

    public Class getType() {
        return CompositeData.class;
    }

    public Object handle(AttributeToJsonConverter pConverter, Object pValue,
                         Stack<String> pExtraArgs) {
        CompositeData cd = (CompositeData) pValue;

        if (!pExtraArgs.isEmpty()) {
            try {
                String decodedKey = URLDecoder.decode(pExtraArgs.pop(), "UTF-8");
                return pConverter.prepareForJson(cd.get(decodedKey),pExtraArgs);
            } catch (UnsupportedEncodingException exp) {
                throw new RuntimeException("Internal: Encoding UTF-8 not supported");
            }
        } else {
            JSONObject ret = new JSONObject();
            for (String key : (Set<String>) cd.getCompositeType().keySet()) {
                ret.put(key,pConverter.prepareForJson(cd.get(key),pExtraArgs));
            }
            return ret;
        }
    }
}