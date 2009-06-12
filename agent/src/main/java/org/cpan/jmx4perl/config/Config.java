package org.cpan.jmx4perl.config;

import org.cpan.jmx4perl.history.HistoryKey;
import org.cpan.jmx4perl.history.HistoryStore;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.ObjectOutputStream;

/**
 * @author roland
 * @since Jun 12, 2009
 */
public class Config implements ConfigMBean {

    private HistoryStore historyStore;

    public String getMBeanName() {
        return "jmx4perl:type=Config";
    }

    public Config(HistoryStore pHistoryStore) {
        historyStore = pHistoryStore;
    }

    public void setHistoryEntriesForAttribute(String pMBean, String pAttribute, String pPath, int pMaxEntries) {
        HistoryKey key = new HistoryKey(pMBean,pAttribute,pPath);
        historyStore.configure(key,pMaxEntries);
    }

    public void setHistoryEntriesForOperation(String pMBean, String pOperation, int pMaxEntries) {
        HistoryKey key = new HistoryKey(pMBean,pOperation);
        historyStore.configure(key,pMaxEntries);
    }

    public void resetHistoryEntries() {
        historyStore.reset();
    }

    public int getHistoryMaxEntries() {
        return historyStore.getGlobalMaxEntries();
    }

    public void setHistoryMaxEntries(int pLimit) {
        historyStore.setGlobalMaxEntries(pLimit);
    }


    public int getHistorySize() throws IOException {
        ByteArrayOutputStream bOut = new ByteArrayOutputStream();
        ObjectOutputStream oOut = new ObjectOutputStream(bOut);
        oOut.writeObject(historyStore);
        return bOut.size();
    }
}
