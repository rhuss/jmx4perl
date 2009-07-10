package org.jmx4perl.converter.attribute.stats;

import org.jmx4perl.converter.StringToObjectConverter;
import org.jmx4perl.converter.attribute.ObjectToJsonConverter;
import org.json.simple.JSONObject;

import javax.management.AttributeNotFoundException;
import javax.management.j2ee.statistics.Statistic;
import java.lang.reflect.InvocationTargetException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
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
 * @since Jul 10, 2009
 */
public class StatisticHandler implements ObjectToJsonConverter.Handler {

    protected List<String> supportedAttributes;

    protected AttributeFetcher attributeFetcher = new AttributeFetcher();

    public StatisticHandler() {
        supportedAttributes = new ArrayList<String>();
        supportedAttributes.addAll(Arrays.asList(
                "name","unit","description","startTime","lastSampleTime"
        ));
    }

    public Class getType() {
        return Statistic.class;
    }

    public Object extractObject(ObjectToJsonConverter pConverter,
                                Object pValue,
                                Stack<String> pExtraArgs,
                                boolean jsonify)
            throws AttributeNotFoundException {
        if (!pExtraArgs.isEmpty()) {
            String attribute = pExtraArgs.pop();
            return attributeFetcher.fetchAttribute(pValue,attribute);
        } else {
            if (jsonify) {
                JSONObject ret = new JSONObject();
                for (String attribute : supportedAttributes) {
                    ret.put(attribute,attributeFetcher.fetchAttribute(pValue,attribute));
                }
                return ret;
            } else {
                return pValue;
            }
        }
    }

    public Object setObjectValue(StringToObjectConverter pConverter, Object pInner, String pAttribute, String pValue) throws IllegalAccessException, InvocationTargetException {
        return new IllegalArgumentException("Cannot set attributes since Statistic " + pInner + " is a read-only object");
    }
}
