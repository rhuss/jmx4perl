package org.jmx4perl.converter.attribute.stats;

import org.jmx4perl.converter.StringToObjectConverter;
import org.jmx4perl.converter.attribute.ObjectToJsonConverter;
import org.json.simple.JSONObject;

import javax.management.AttributeNotFoundException;
import javax.management.j2ee.statistics.Statistic;
import javax.management.j2ee.statistics.Stats;
import javax.management.openmbean.InvalidKeyException;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
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
 * Handler for translating statistic values as obtained from JSR-77. This handler
 * is for pure statistic containing stats.
 *
 * @author roland
 * @since Jul 9, 2009
 */
public class StatsHandler implements ObjectToJsonConverter.Handler {

    protected AttributeFetcher attributeFetcher = new AttributeFetcher();

    public Class getType() {
        return Stats.class;
    }

    public Object extractObject(ObjectToJsonConverter pConverter,
                                Object pValue,
                                Stack<String> pExtraArgs,
                                boolean jsonify)
            throws AttributeNotFoundException {

        Stats stats = (Stats) pValue;

        if (!pExtraArgs.isEmpty()) {
            String key = pExtraArgs.pop();
            try {
                return pConverter.extractObject(extractStatistics(stats,key),pExtraArgs,jsonify);
            }  catch (InvalidKeyException exp) {
                throw new AttributeNotFoundException("Invalid path '" + key + "'");
            }
        } else {
            if (jsonify) {
                JSONObject ret = new JSONObject();
                for (Statistic statistic :  stats.getStatistics()) {
                    ret.put(lowerFirstChar(statistic.getName()),pConverter.extractObject(statistic,pExtraArgs,jsonify));
                }
                return ret;
            } else {
                return stats;
            }
        }
    }

    private String lowerFirstChar(String pName) {
        return pName.substring(0,1).toLowerCase() + pName.substring(1);
    }

    protected String getStatisticsName(Stats pStats,String pName) {
        String[] names = pStats.getStatisticNames();
        for (String name : names) {
            if (name.equalsIgnoreCase(pName)) {
                return name;
            }
        }
        return null;
    }

    private Statistic extractStatistics(Stats pStats, String pName) throws AttributeNotFoundException {
        String statisticName = getStatisticsName(pStats,pName);
        if (statisticName == null) {
            throw new IllegalArgumentException(
                    "No statistics with name '" + pName + "' known for stats " + pStats);
        }

        return (Statistic) attributeFetcher.fetchAttribute(pStats,pName);
    }

    public Object setObjectValue(StringToObjectConverter pConverter, Object pInner, String pAttribute, String pValue) throws IllegalAccessException, InvocationTargetException {
        throw new IllegalArgumentException("A Stats cannot be written to");
    }
}
