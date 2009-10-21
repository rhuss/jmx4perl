package org.jmx4perl.handler;


import org.jmx4perl.JmxRequest;
import org.jmx4perl.config.Restrictor;

import javax.management.*;
import java.util.*;

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
 * @since Jun 12, 2009
 */
public class ListHandler extends RequestHandler {
    public String getType() {
        return "list";
    }

    public ListHandler(Restrictor pRestrictor) {
        super(pRestrictor);
    }

    public boolean handleAllServersAtOnce() {
        return true;
    }

    public Object doHandleRequest(Set pServers, JmxRequest request)
            throws InstanceNotFoundException {
        try {
            Map ret = new HashMap();

            for (Iterator it = pServers.iterator();it.hasNext();) {
                MBeanServer server = (MBeanServer) it.next();
                for (Iterator it2 = server.queryNames((ObjectName) null,(QueryExp) null).iterator();
                        it2.hasNext();) {
                    ObjectName name = (ObjectName) it2.next();
                    MBeanInfo mBeanInfo = server.getMBeanInfo(name);

                    Map mBeansMap = getOrCreateMap(ret,name.getDomain());
                    Map mBeanMap = getOrCreateMap(mBeansMap,name.getCanonicalKeyPropertyListString());

                    addAttributes(mBeanMap, mBeanInfo);
                    addOperations(mBeanMap, mBeanInfo);

                    // Trim if needed
                    if (mBeanMap.size() == 0) {
                        mBeansMap.remove(name.getCanonicalKeyPropertyListString());
                        if (mBeansMap.size() == 0) {
                            ret.remove(name.getDomain());
                        }
                    }
                }
            }
            return ret;
        } catch (ReflectionException e) {
            throw new IllegalStateException("Internal error while retrieving list: " + e);
        } catch (IntrospectionException e) {
            throw new IllegalStateException("Internal error while retrieving list: " + e);
        }

    }

    private void addOperations(Map pMBeanMap, MBeanInfo pMBeanInfo) {
        // Extract operations
        Map opMap = new HashMap();
        MBeanOperationInfo[] opInfos = pMBeanInfo.getOperations();
        for (int j = 0; j < opInfos.length; j++) {
            MBeanOperationInfo opInfo = opInfos[j];
            Map map = new HashMap();
            List argList = new ArrayList();
            MBeanParameterInfo infos[] = opInfo.getSignature();
            for (int i = 0; i<infos.length;i++) {
                MBeanParameterInfo paramInfo = infos[i];
                Map args = new HashMap();
                args.put("desc",paramInfo.getDescription());
                args.put("name",paramInfo.getName());
                args.put("type",paramInfo.getType());
                argList.add(args);
            }
            map.put("args",argList);
            map.put("ret",opInfo.getReturnType());
            map.put("desc",opInfo.getDescription());
            opMap.put(opInfo.getName(),map);
        }
        if (opMap.size() > 0) {
            pMBeanMap.put("op",opMap);
        }
    }

    private void addAttributes(Map pMBeanMap, MBeanInfo pMBeanInfo) {
        // Extract atributes
        Map attrMap = new HashMap();
        MBeanAttributeInfo attrInfos[] = pMBeanInfo.getAttributes();
        for (int i = 0; i < attrInfos.length; i++) {
            MBeanAttributeInfo attrInfo = attrInfos[i];
            Map map = new HashMap();
            map.put("type",attrInfo.getType());
            map.put("desc",attrInfo.getDescription());
            map.put("rw",Boolean.valueOf(attrInfo.isWritable() && attrInfo.isReadable()));
            attrMap.put(attrInfo.getName(),map);
        }
        if (attrMap.size() > 0) {
            pMBeanMap.put("attr",attrMap);
        }
    }

    private Map getOrCreateMap(Map pMap, String pKey) {
        Map nMap = (Map) pMap.get(pKey);
        if (nMap == null) {
            nMap = new HashMap();
            pMap.put(pKey,nMap);
        }
        return nMap;
    }

    // will not be called
    public Object doHandleRequest(MBeanServer server, JmxRequest request) throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException {
        return null;
    }


}
