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

package org.cpan.jmx4perl;

import org.json.simple.JSONObject;

import javax.management.ObjectName;
import javax.management.MalformedObjectNameException;
import java.util.*;

/**
 * @author roland
* @since Apr 19, 2009
*/
public class JmxRequest extends JSONObject {

    /**
     * Enumeration for encapsulationg the request mode. For
     * now only reading of attributes are supported
     */
    enum Type {
        // Supported:
        READ_ATTRIBUTE("read"),

        // Unsupported:
        WRITE_ATTRIBUTE("write"),
        EXEC_OPERATION("exec"),
        REGISTER_NOTIFICATION("regnotif"),
        REMOVE_NOTIFICATION("remnotif");

        private String value;

        Type(String pValue) {
            value = pValue;
        }

        public String getValue() {
            return value;
        }
    };


    String objectNameS;
    ObjectName objectName;
    String attributeName;
    List<String> extraArgs;

    private Type type;

    JmxRequest(String pPathInfo) {
        try {
            if (pPathInfo != null && pPathInfo.length() > 0) {
                StringTokenizer tok = new StringTokenizer(pPathInfo,"/");
                String typeS = tok.nextToken();
                type = extractType(typeS);
                objectNameS = tok.nextToken();
                objectName = new ObjectName(objectNameS);
                if (type == Type.READ_ATTRIBUTE) {
                    attributeName = tok.nextToken();
                    extraArgs = new ArrayList<String>();
                    while (tok.hasMoreTokens()) {
                        extraArgs.add(tok.nextToken());
                    }
                } else {
                    throw new UnsupportedOperationException("Type " + type + " is not supported (yet)");
                }
                setupJSON();
            }
        } catch (NoSuchElementException exp) {
            throw new IllegalArgumentException("Invalid path info " + pPathInfo);
        } catch (MalformedObjectNameException e) {
            throw new IllegalArgumentException(
                    "Invalid object name " + objectNameS +
                            ": " + e.getMessage());
        }
    }

    private Type extractType(String pTypeS) {
        for (Type t : Type.values()) {
            if (t.getValue().equals(pTypeS)) {
                return t;
            }
        }
        throw new IllegalArgumentException("Invalid request type '" + pTypeS + "'");
    }

    private void setupJSON() {
        put("attribute",getAttributeName());
        if (extraArgs.size() > 0) {
            StringBuffer buf = new StringBuffer();
            Iterator<String> it = extraArgs.iterator();
            while (it.hasNext()) {
                buf.append(it.next());
                if (it.hasNext()) {
                    buf.append("/");
                }
            }
            put("innerPath",buf.toString());
        }
        JSONObject name = new JSONObject();
        name.put("domain",objectName.getDomain());
        name.put("canonical",objectName.getCanonicalName());
        name.put("keys",objectName.getKeyPropertyList());
        put("name",name);
    }

    public String getObjectNameAsString() {
        return objectNameS;
    }

    public ObjectName getObjectName() {
        return objectName;
    }

    public String getAttributeName() {
        return attributeName;
    }

    public List<String> getExtraArgs() {
        return extraArgs;
    }

    public Type getType() {
        return type;
    }
}
