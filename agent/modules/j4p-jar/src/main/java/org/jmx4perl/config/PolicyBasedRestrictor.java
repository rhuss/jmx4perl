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
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
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

    private Set<JmxRequest.Type> typeSet;
    private Set<ObjectName> patternNameSet;
    private Map<ObjectName,Set<String>> mBeanReadAttributes;
    private Map<ObjectName, Set<String>> mBeanWriteAttributes;
    private Map<ObjectName, Set<String>> mBeanOperations;
    private Set<String> allowedHostsSet;
    private Set<String> allowedSubnetsSet;

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
                throw new IllegalStateException("Cannot parse policy file",exp);
            }
        }
    }

    // ===============================================================================
    // Lookup methods

    public boolean isTypeAllowed(JmxRequest.Type pType) {
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

    public boolean isRemoteAccessAllowed(String ... pHostOrAddress) {
        if (allowedHostsSet == null) {
            return true;
        }
        for (String addr : pHostOrAddress) {
            if (allowedHostsSet.contains(addr)) {
                return true;
            }
            if (allowedSubnetsSet != null && IP_PATTERN.matcher(addr).matches()) {
                for (String subnet : allowedSubnetsSet) {
                    if (IpChecker.matches(subnet,addr)) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    // ===============================================================================
    // Lookup methods

    private boolean lookupMBean(Map<ObjectName, Set<String>> pMap, ObjectName pName, String pAttribute) {
        if (pMap == null) {
            return true;
        }
        Set<String> attributes = pMap.get(pName);
        if (attributes == null) {
            ObjectName pattern = findMatchingMBeanPattern(pName);
            if (pattern != null) {
                attributes = pMap.get(pattern);
            }
        }
        return attributes != null && attributes.contains(pAttribute);
    }

    private ObjectName findMatchingMBeanPattern(ObjectName pName) {
        for (ObjectName pattern : patternNameSet) {
            if (pattern.apply(pName)) {
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
            typeSet = new HashSet<JmxRequest.Type>();
        }
        for (int i = 0;i<nodes.getLength();i++) {
            Node node = nodes.item(i);
            NodeList childs = node.getChildNodes();
            for (int j = 0;j<childs.getLength();j++) {
                Node commandNode = childs.item(j);
                if (commandNode.getNodeType() != Node.ELEMENT_NODE) {
                    continue;
                }
                assertNodeName(commandNode,"command");
                String typeName = commandNode.getTextContent().trim();
                JmxRequest.Type type = JmxRequest.Type.valueOf(typeName.toUpperCase());
                typeSet.add(type);
            }
        }
    }

    private void initMBeanSets(Document pDoc) throws MalformedObjectNameException {
        NodeList nodes = pDoc.getElementsByTagName("mbeans");
        if (nodes.getLength() > 0) {
            // Build up maps only if mbeans are given to restrict
            patternNameSet = new HashSet<ObjectName>();
            mBeanReadAttributes = new HashMap<ObjectName, Set<String>>();
            mBeanWriteAttributes = new HashMap<ObjectName, Set<String>>();
            mBeanOperations = new HashMap<ObjectName, Set<String>>();
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
                assertNodeName(mBeanNode,"mbean");
                NodeList params = mBeanNode.getChildNodes();
                String name = null;
                Set<String> readAttributes = new HashSet<String>();
                Set<String> writeAttributes = new HashSet<String>();
                Set<String> operations = new HashSet<String>();
                for (int k = 0; k<params.getLength(); k++) {
                    Node param = params.item(k);
                    if (param.getNodeType() != Node.ELEMENT_NODE) {
                        continue;
                    }
                    assertNodeName(param,"name","attribute","operation");
                    String tag = param.getNodeName();
                    if (tag.equals("name")) {
                        if (name != null) {
                            throw new IllegalStateException("<name> given twice as MBean name");
                        } else {
                            name = param.getTextContent().trim();
                        }
                    } else if (tag.equals("attribute")) {
                        Node mode = param.getAttributes().getNamedItem("mode");
                        readAttributes.add(param.getTextContent().trim());
                        if (mode == null || !mode.getNodeValue().equalsIgnoreCase("read")) {
                            writeAttributes.add(param.getTextContent().trim());
                        }
                    } else {
                        operations.add(param.getTextContent().trim());
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

        allowedHostsSet = new HashSet<String>();
        for (int i = 0;i<nodes.getLength();i++) {
            Node node = nodes.item(i);
            NodeList childs = node.getChildNodes();
            for (int j = 0;j<childs.getLength();j++) {
                Node hostNode = childs.item(j);
                if (hostNode.getNodeType() != Node.ELEMENT_NODE) {
                    continue;
                }
                assertNodeName(hostNode,"host");
                String host = hostNode.getTextContent().trim().toLowerCase();
                if (SUBNET_PATTERN.matcher(host).matches()) {
                    if (allowedSubnetsSet == null) {
                        allowedSubnetsSet = new HashSet<String>();
                    }
                    allowedSubnetsSet.add(host);
                } else {
                    allowedHostsSet.add(host);
                }
            }
        }
    }

    private void assertNodeName(Node pNode, String ... pExpected) {
        for (String expected : pExpected) {
            if (pNode.getNodeName().equals(expected)) {
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
