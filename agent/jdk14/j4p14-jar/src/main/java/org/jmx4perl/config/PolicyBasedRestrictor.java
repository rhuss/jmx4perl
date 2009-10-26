package org.jmx4perl.config;

import org.jmx4perl.JmxRequest;
import org.w3c.dom.Document;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;

import javax.management.MalformedObjectNameException;
import javax.management.ObjectName;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import java.io.IOException;
import java.io.InputStream;
import java.util.*;
import java.util.regex.Pattern;

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
 * Restrictor, which is based on a policy file
 *
 * @author roland
 * @since Jul 28, 2009
 */
public class PolicyBasedRestrictor implements Restrictor {

    private Set typeSet;
    private Set patternNameSet;
    private Map mBeanReadAttributes;
    private Map mBeanWriteAttributes;
    private Map mBeanOperations;
    private Set allowedHostsSet;
    private Set allowedSubnetsSet;

    // Simple patterns, could be mor specific
    private static final Pattern IP_PATTERN = Pattern.compile("^[\\d.]+$");
    private static final Pattern SUBNET_PATTERN = Pattern.compile("^[\\d.]+/[\\d.]+$");

    public PolicyBasedRestrictor(InputStream pInput) {
        Exception exp = null;
        try {
            Document doc =
                    DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(pInput);
            initTypeSet(doc);
            initMBeanSets(doc);
            initAllowedHosts(doc);
        }
        catch (SAXException e) { exp = e; }
        catch (IOException e) { exp = e; }
        catch (ParserConfigurationException e) { exp = e; }
        catch (MalformedObjectNameException e) { exp = e; }
        finally {
            if (exp != null) {
                throw new RuntimeException("Cannot parse policy file",exp);
            }
        }
    }

    // ===============================================================================
    // Lookup methods

    public boolean isTypeAllowed(String pType) {
        return typeSet == null || typeSet.contains(pType);
    }

    public boolean isAttributeReadAllowed(ObjectName pName, String pAttribute) {
        return lookupMBean(mBeanReadAttributes,pName, pAttribute);
    }

    public boolean isAttributeWriteAllowed(ObjectName pName, String pAttribute) {
        return lookupMBean(mBeanWriteAttributes,pName, pAttribute);
    }

    public boolean isOperationAllowed(ObjectName pName, String pOperation) {
        return lookupMBean(mBeanOperations,pName, pOperation);
    }

    public boolean isRemoteAccessAllowed(String pHost, String pAddress) {
        if (allowedHostsSet == null) {
            return true;
        }
        String[] addr = new String[] { pHost, pAddress };
        for (int i = 0; i < addr.length; i++) {
            if (addr[i] == null) {
                continue;
            }
            if (allowedHostsSet.contains(addr[i])) {
                return true;
            }
            if (allowedSubnetsSet != null && IP_PATTERN.matcher(addr[i]).matches()) {
                for (Iterator it = allowedSubnetsSet.iterator(); it.hasNext(); ) {
                    String subnet = (String) it.next();
                    if (IpChecker.matches(subnet,addr[i])) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    // ===============================================================================
    // Lookup methods

    private boolean lookupMBean(Map pMap, ObjectName pName, String pAttribute) {
        if (pMap == null) {
            return true;
        }
        Set attributes = (Set) pMap.get(pName);
        if (attributes == null) {
            ObjectName pattern = findMatchingMBeanPattern(pName);
            if (pattern != null) {
                attributes = (Set) pMap.get(pattern);
            }
        }
        return attributes != null && attributes.contains(pAttribute);
    }

    private ObjectName findMatchingMBeanPattern(ObjectName pName) {
        for (Iterator it = patternNameSet.iterator(); it.hasNext();) {
            ObjectName pattern = (ObjectName) it.next();
            if (pattern.equals(pName)) {
                return pattern;
            }
        }
        return null;
    }


    // ===============================================================================
    // Parsing routines
    private void initTypeSet(Document pDoc) {
        NodeList nodes = pDoc.getElementsByTagName("commands");
        if (nodes.getLength() > 0) {
            // Leave typeSet null if no commands has been given...
            typeSet = new HashSet();
        }
        for (int i = 0;i<nodes.getLength();i++) {
            Node node = nodes.item(i);
            NodeList childs = node.getChildNodes();
            for (int j = 0;j<childs.getLength();j++) {
                Node commandNode = childs.item(j);
                if (commandNode.getNodeType() != Node.ELEMENT_NODE) {
                    continue;
                }
                assertNodeName(commandNode,new String[] { "command" });
                String typeName = getTextValue(commandNode);
                String type = typeName.toLowerCase();
                typeSet.add(type);
            }
        }
    }

    private String getTextValue(Node pNode) {
        NodeList childs = pNode.getChildNodes();
        StringBuffer ret = new StringBuffer();
        for (int i = 0; i < childs.getLength(); i++) {
            if (childs.item(i).getNodeType() == Node.TEXT_NODE) {
                ret.append(childs.item(i).getNodeValue());
            }
        }
        return ret.toString().trim();
    }

    private void initMBeanSets(Document pDoc) throws MalformedObjectNameException {
        NodeList nodes = pDoc.getElementsByTagName("mbeans");
        if (nodes.getLength() > 0) {
            // Build up maps only if mbeans are given to restrict
            patternNameSet = new HashSet();
            mBeanReadAttributes = new HashMap();
            mBeanWriteAttributes = new HashMap();
            mBeanOperations = new HashMap();
        }
        for (int i = 0;i<nodes.getLength();i++) {
            Node node = nodes.item(i);
            if (node.getNodeType() != Node.ELEMENT_NODE) {
                continue;
            }
            NodeList childs = node.getChildNodes();
            for (int j = 0;j<childs.getLength();j++) {
                Node mBeanNode = childs.item(j);
                if (mBeanNode.getNodeType() != Node.ELEMENT_NODE) {
                    continue;
                }
                assertNodeName(mBeanNode,new String[] { "mbean" });
                NodeList params = mBeanNode.getChildNodes();
                String name = null;
                Set readAttributes = new HashSet();
                Set writeAttributes = new HashSet();
                Set operations = new HashSet();
                for (int k = 0; k<params.getLength(); k++) {
                    Node param = params.item(k);
                    if (param.getNodeType() != Node.ELEMENT_NODE) {
                        continue;
                    }
                    assertNodeName(param,new String[] { "name","attribute","operation" });
                    String tag = param.getNodeName();
                    if (tag.equals("name")) {
                        if (name != null) {
                            throw new IllegalStateException("<name> given twice as MBean name");
                        } else {
                            name = getTextValue(param);
                        }
                    } else if (tag.equals("attribute")) {
                        Node mode = param.getAttributes().getNamedItem("mode");
                        readAttributes.add(getTextValue(param));
                        if (mode == null || !mode.getNodeValue().equalsIgnoreCase("read")) {
                            writeAttributes.add(getTextValue(param));
                        }
                    } else {
                        operations.add(getTextValue(param));
                    }
                }
                if (name == null) {
                    throw new IllegalStateException("No <name> given for <mbean>");
                }
                ObjectName oName = new ObjectName(name);
                if (oName.isPattern()) {
                    patternNameSet.add(oName);
                }
                mBeanReadAttributes.put(oName,readAttributes);
                mBeanWriteAttributes.put(oName,writeAttributes);
                mBeanOperations.put(oName,operations);
            }
        }
    }

    private void initAllowedHosts(Document pDoc) {
        NodeList nodes = pDoc.getElementsByTagName("remote");
        if (nodes.getLength() == 0) {
            // No restrictions found
            allowedHostsSet = null;
            return;
        }

        allowedHostsSet = new HashSet();
        for (int i = 0;i<nodes.getLength();i++) {
            Node node = nodes.item(i);
            NodeList childs = node.getChildNodes();
            for (int j = 0;j<childs.getLength();j++) {
                Node hostNode = childs.item(j);
                if (hostNode.getNodeType() != Node.ELEMENT_NODE) {
                    continue;
                }
                assertNodeName(hostNode,new String[] { "host" });
                String host = getTextValue(hostNode).toLowerCase();
                if (SUBNET_PATTERN.matcher(host).matches()) {
                    if (allowedSubnetsSet == null) {
                        allowedSubnetsSet = new HashSet();
                    }
                    allowedSubnetsSet.add(host);
                } else {
                    allowedHostsSet.add(host);
                }
            }
        }
    }

    private void assertNodeName(Node pNode, String[] pExpected) {

        for (int i = 0; i < pExpected.length; i++ ) {
            if (pNode.getNodeName().equals(pExpected[i])) {
                return;
            }
        }
        StringBuffer buffer = new StringBuffer();
        for (int i=0;i<pExpected.length;i++) {
            buffer.append(pExpected[i]);
            if (i<pExpected.length-1) {
                buffer.append(",");
            }
        }
        throw new IllegalStateException(
                "Expected element " + buffer.toString() + " but got " + pNode.getNodeName());
    }



}
