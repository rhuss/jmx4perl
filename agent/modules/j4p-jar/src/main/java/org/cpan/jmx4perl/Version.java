package org.cpan.jmx4perl;

/**
 * Class holding the version of this agent. This gets updated automatically
 * when jmx4perl is build.
 *
 * @author roland
 * @since Jun 11, 2009
 */
public class Version {
    private static String VERSION = "0.20_4";

    public static String getVersion() {
        return VERSION;
    }
}
