package org.jmx4perl.handler;

import org.jmx4perl.JmxRequest;
import org.jmx4perl.config.Restrictor;

import javax.management.*;
import java.io.IOException;
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
 * Handler for managing READ requests for reading attributes.
 *
 * @author roland
 * @since Jun 12, 2009
 */
public class ReadHandler extends JsonRequestHandler {

    public ReadHandler(Restrictor pRestrictor) {
        super(pRestrictor);
    }

    @Override
    public JmxRequest.Type getType() {
        return JmxRequest.Type.READ;
    }

    @Override
    public Object doHandleRequest(MBeanServerConnection server, JmxRequest request)
            throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException, IOException {
        ObjectName oName = request.getObjectName();
        JmxRequest.ValueFaultHandler faultHandler = request.getValueFaultHandler();
        if (oName.isPattern()) {
            Set<ObjectName> names = server.queryNames(oName,null);
            if (names == null || names.size() == 0) {
                throw new InstanceNotFoundException("No MBean with pattern " + request.getObjectNameAsString() +
                        " found for reading attributes");
            }
            Map<String,Object> ret = new HashMap<String, Object>();
            List<String> attributeNames = request.getAttributeNames();
            boolean fetchAll =  attributeNames == null || (attributeNames.contains(null));
            for (ObjectName name : names) {
                List<String> filteredAttributeNames;
                if (fetchAll) {
                    filteredAttributeNames = null;
                    Map values = (Map) fetchAttributes(server,name,filteredAttributeNames,faultHandler,true /* always as map */);
                    if (values != null && values.size() > 0) {
                        ret.put(name.getCanonicalName(),values);
                    }
                } else {
                    filteredAttributeNames = filterAttributeNames(server,name,attributeNames);
                    if (filteredAttributeNames.size() == 0) {
                        continue;
                    }
                    ret.put(name.getCanonicalName(),
                            fetchAttributes(server,name,filteredAttributeNames,faultHandler,true /* always as map */));
                }
            }
            if (ret.size() == 0) {
                throw new IllegalArgumentException("No matching attributes " +
                        request.getAttributeNames() + " found on MBeans " + names);
            }
            return ret;
        } else {
            return fetchAttributes(server,oName,request.getAttributeNames(),faultHandler,!request.isSingleAttribute());
        }
    }

    // Return only those attributes of an mbean which has one of the given names
    private List<String> filterAttributeNames(MBeanServerConnection pServer,ObjectName pName, List<String> pNames)
            throws InstanceNotFoundException, IOException, ReflectionException {
        Set<String> attrs = new HashSet<String>(getAllAttributesNames(pServer,pName));
        List<String> ret = new ArrayList<String>();
        for (String name : pNames) {
            if (attrs.contains(name)) {
                ret.add(name);
            }
        }
        return ret;
    }

    private Object fetchAttributes(MBeanServerConnection pServer, ObjectName pMBeanName, List<String> pAttributeNames,
                                   JmxRequest.ValueFaultHandler pFaultHandler,boolean pAlwaysAsMap)
            throws InstanceNotFoundException, IOException, ReflectionException, AttributeNotFoundException, MBeanException {
        if (pAttributeNames != null && pAttributeNames.size() > 0 &&
                !(pAttributeNames.size() == 1 && pAttributeNames.get(0) == null)) {
            if (pAttributeNames.size() == 1) {
                checkRestriction(pMBeanName, pAttributeNames.get(0));
                // When only a single attribute is requested, return it as plain value (backward compatibility)
                Object ret = pServer.getAttribute(pMBeanName, pAttributeNames.get(0));
                if (pAlwaysAsMap) {
                    Map<String,Object> retMap = new HashMap<String, Object>();
                    retMap.put(pAttributeNames.get(0),ret);
                    return retMap;
                } else {
                    return ret;
                }
            } else {
                return fetchMultiAttributes(pServer,pMBeanName,pAttributeNames,pFaultHandler);
            }
        } else {
            // Return the value of all attributes stored
            List<String> allAttributesNames = getAllAttributesNames(pServer,pMBeanName);
            return fetchMultiAttributes(pServer,pMBeanName,allAttributesNames,pFaultHandler);
        }
    }

    // Return a set of attributes as a map with the attribute name as key and their values as values
    private Map<String,Object> fetchMultiAttributes(MBeanServerConnection pServer, ObjectName pMBeanName, List<String> pAttributeNames,
                                                    JmxRequest.ValueFaultHandler pFaultHandler)
    throws InstanceNotFoundException, IOException, ReflectionException, AttributeNotFoundException, MBeanException {
        Map<String,Object> ret = new HashMap<String, Object>();
        for (String attribute : pAttributeNames) {
            checkRestriction(pMBeanName, attribute);
            try {
                ret.put(attribute,pServer.getAttribute(pMBeanName, attribute));
            } catch (MBeanException e) {
                // The fault handler might to decide to rethrow the
                // exception in which case nothing is put extra intor ret.
                // Otherwise, the replacement value as returned by the
                // fault handler is inserted.
                ret.put(attribute, pFaultHandler.handleException(e));
            } catch (AttributeNotFoundException e) {
                ret.put(attribute, pFaultHandler.handleException(e));
            } catch (InstanceNotFoundException e) {
                ret.put(attribute, pFaultHandler.handleException(e));
            } catch (ReflectionException e) {
                ret.put(attribute, pFaultHandler.handleException(e));
            } catch (IOException e) {
                ret.put(attribute, pFaultHandler.handleException(e));
            } catch (RuntimeException e) {
                ret.put(attribute, pFaultHandler.handleException(e));
            }

        }
        return ret;
    }

    private List<String> getAllAttributesNames(MBeanServerConnection pServer, ObjectName pObjectName)
            throws InstanceNotFoundException, IOException, ReflectionException {
        try {
            MBeanInfo mBeanInfo;
            mBeanInfo = pServer.getMBeanInfo(pObjectName);
            List<String> ret = new ArrayList<String>();
            for (MBeanAttributeInfo attrInfo : mBeanInfo.getAttributes()) {
                ret.add(attrInfo.getName());
            }
            return ret;
        } catch (IntrospectionException e) {
            throw new IllegalStateException("Internal error while retrieving list: " + e,e);
        }
    }

    private void checkRestriction(ObjectName mBeanName, String attribute) {
        if (!restrictor.isAttributeReadAllowed(mBeanName,attribute)) {
            throw new SecurityException("Reading attribute " + attribute +
                    " is forbidden for MBean " + mBeanName.getCanonicalName());
        }
    }
}
