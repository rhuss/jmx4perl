package org.jmx4perl.config;

import org.jmx4perl.backend.MBeanServerHandler;
import org.jmx4perl.history.HistoryKey;
import org.jmx4perl.history.HistoryStore;

import javax.management.*;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.ObjectOutputStream;
import java.lang.management.ManagementFactory;
import java.util.Set;


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
public class Config implements ConfigMBean, MBeanRegistration {

    private HistoryStore historyStore;
    private DebugStore debugStore;
    private MBeanServerHandler mBeanServerHandler;


    public Config(HistoryStore pHistoryStore, DebugStore pDebugStore, MBeanServerHandler pMBeanServerHandler) {
        historyStore = pHistoryStore;
        debugStore = pDebugStore;
        mBeanServerHandler = pMBeanServerHandler;
    }

    public void setHistoryEntriesForAttribute(String pMBean, String pAttribute, String pPath, String pTarget, int pMaxEntries) {
        HistoryKey key = new HistoryKey(pMBean,pAttribute,pPath,pTarget);
        historyStore.configure(key,pMaxEntries);
    }

    public void setHistoryEntriesForOperation(String pMBean, String pOperation, String pTarget, int pMaxEntries) {
        HistoryKey key = new HistoryKey(pMBean,pOperation,pTarget);
        historyStore.configure(key,pMaxEntries);
    }

    public void resetHistoryEntries() {
        historyStore.reset();
    }

    public String debugInfo() {
        return debugStore.debugInfo();
    }

    public String mBeanServerInfo() {
        StringBuffer ret = new StringBuffer();
        Set<MBeanServer> mBeanServers = mBeanServerHandler.getMBeanServers();

        ret.append("Found ").append(mBeanServers.size()).append(" MBeanServers\n");
        for (MBeanServer s : mBeanServers) {
            ret.append("    ")
                    .append("++ ")
                    .append(s.toString())
                    .append(": default domain = ")
                    .append(s.getDefaultDomain())
                    .append(", ")
                    .append(s.getMBeanCount())
                        .append(" MBeans\n");

            ret.append("        Domains:\n");
            boolean javaLangFound = false;
            for (String d : s.getDomains()) {
                if ("java.lang".equals(d)) {
                    javaLangFound = true;
                }
                appendDomainInfo(ret, s, d);
            }
            if (!javaLangFound) {
                // JBoss fails to list java.lang in its domain list
                appendDomainInfo(ret,s,"java.lang");
            }
        }
        ret.append("\n");
        ret.append("Platform MBeanServer: ")
                .append(ManagementFactory.getPlatformMBeanServer())
                .append("\n");
        return ret.toString();
    }

    private void appendDomainInfo(StringBuffer pRet, MBeanServer pServer, String pDomain) {
        try {
            pRet.append("         == ").append(pDomain).append("\n");
            Set<ObjectInstance> beans = pServer.queryMBeans(new ObjectName(pDomain + ":*"),null);
            for (ObjectInstance o : beans) {
                String n = o.getObjectName().getCanonicalKeyPropertyListString();
                pRet.append("              ").append(n).append("\n");
            }
        } catch (MalformedObjectNameException e) {
            // Shouldnt happen
            pRet.append("              INTERNAL ERROR: ").append(e).append("\n");
        }
    }

    public void resetDebugInfo() {
        debugStore.resetDebugInfo();
    }

    public int getHistoryMaxEntries() {
        return historyStore.getGlobalMaxEntries();
    }

    public void setHistoryMaxEntries(int pLimit) {
        historyStore.setGlobalMaxEntries(pLimit);
    }

    public boolean isDebug() {
        return debugStore.isDebug();
    }

    public void setDebug(boolean pSwitch) {
        debugStore.setDebug(pSwitch);
    }

    public int getMaxDebugEntries() {
        return debugStore.getMaxDebugEntries();
    }

    public void setMaxDebugEntries(int pNumber) {
        debugStore.setMaxDebugEntries(pNumber);
    }

    public int getHistorySize() throws IOException {
        ByteArrayOutputStream bOut = new ByteArrayOutputStream();
        ObjectOutputStream oOut = new ObjectOutputStream(bOut);
        oOut.writeObject(historyStore);
        return bOut.size();
    }

    // =================================================================================
    // We are providing our own name

    public ObjectName preRegister(MBeanServer pMBeanServer, ObjectName pObjectName) throws MalformedObjectNameException {
        return new ObjectName("jmx4perl:type=Config");
    }

    public void postRegister(Boolean pBoolean) {
    }

    public void preDeregister()  {
    }

    public void postDeregister() {
    }
}
