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
 */

package org.cpan.jmx4perl.converter;


import org.json.simple.JSONObject;
import org.cpan.jmx4perl.JmxRequest;

import java.util.ArrayList;
import java.util.List;
import java.util.Stack;

/**
 * A converter which convert attribute and return values
 * into a JSON representation. It uses certain handlers for this which
 * are registered programatically in the constructor.
 *
 * Each handler gets a reference to this converter object so that it
 * can use it for a recursive solution of nested objects.
 *
 * @author roland
 * @since Apr 19, 2009
 */
public class AttributeToJsonConverter {

    List<Handler> handlers;

    ArrayHandler arrayHandler;

    public AttributeToJsonConverter() {
        handlers = new ArrayList<Handler>();

        handlers.add(new CompositeHandler());
        handlers.add(new TabularDataHandler());
        handlers.add(new CollectionHandler());
        handlers.add(new MapHandler());
        handlers.add(new PlainValueHandler());

        arrayHandler = new ArrayHandler();
    }

    public JSONObject convertToJson(Object pValue, JmxRequest pRequest) {
        Stack<String> extraStack = new Stack<String>();
        List<String> extraArgs = pRequest.getExtraArgs();
        if (extraArgs != null) {
            // Needs first extra argument at top of the stack
            for (int i = extraArgs.size() - 1;i >=0;i--) {
                extraStack.push(extraArgs.get(i));
            }
        }

        Object jsonResult = prepareForJson(pValue,extraStack);
        JSONObject jsonObject = new JSONObject();
        jsonObject.put("value",jsonResult);
        jsonObject.put("request",pRequest);
        return jsonObject;
    }

    Object prepareForJson(Object pValue,Stack<String> pExtraArgs) {
        if (pValue == null) {
            return null;
        }
        Class clazz = pValue.getClass();
        if (clazz.isArray()) {
            return arrayHandler.handle(this,pValue,pExtraArgs);
        }
        for (Handler handler : handlers) {
            if (handler.getType() != null && handler.getType().isAssignableFrom(clazz)) {
                return handler.handle(this,pValue,pExtraArgs);
            }
        }

        throw new RuntimeException(
                "Internal error: No handler found for class " + clazz +
                        " (object: " + pValue + ", extraArgs: " + pExtraArgs + ")");
    }


    // =============================================================================
    // Handler interface for dedicated handler

    public interface Handler {
        Class getType();
        Object handle(AttributeToJsonConverter pConverter,Object pValue,Stack<String> pExtraArgs);
    }
}
