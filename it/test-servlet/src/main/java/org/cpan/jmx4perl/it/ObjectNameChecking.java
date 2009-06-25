package org.cpan.jmx4perl.it;

/**
 * @author roland
 * @since Jun 25, 2009
 */
public class ObjectNameChecking implements ObjectNameCheckingMBean {

    public String getOk() {
        return "OK";
    }
}
