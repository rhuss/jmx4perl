package org.jmx4perl.client.request;

import org.jmx4perl.AgentServlet;
import org.jmx4perl.client.J4pClient;
import org.jmx4perl.it.ItSetup;
import org.junit.AfterClass;
import org.junit.BeforeClass;
import org.mortbay.jetty.Server;
import org.mortbay.jetty.servlet.Context;
import org.mortbay.jetty.servlet.ServletHolder;

/**
 * @author roland
 * @since Apr 26, 2010
 */
abstract public class AbstractJ4pIntegrationTest {

    private static Server jettyServer;
    private static ItSetup itSetup;

    private static final int JETTY_DEFAULT_PORT = 8234;
    private static final String SEVER_BASE_URL = "http://localhost:" + JETTY_DEFAULT_PORT;
    private static final String J4P_CONTEXT = "/j4p";

    protected static final String J4P_DEFAULT_URL = SEVER_BASE_URL + J4P_CONTEXT;

    static String j4pUrl;

    // Client which can be used by subclasses for testing
    protected J4pClient j4pClient;

    public AbstractJ4pIntegrationTest() {
        j4pClient = new J4pClient(j4pUrl);
    }

    @BeforeClass
	public static void start() throws Exception {
        String testUrl = System.getProperty("j4p.url");
        if (testUrl == null) {
            jettyServer = new Server(JETTY_DEFAULT_PORT);
            Context jettyContext = new Context(jettyServer, "/");
            jettyContext.addServlet(new ServletHolder(new AgentServlet()), J4P_CONTEXT + "/*");
            jettyServer.start();
            j4pUrl = J4P_DEFAULT_URL;
            itSetup = new ItSetup();
            itSetup.start();
        } else {
            j4pUrl = testUrl;
            itSetup = null;
        }
	}

    @AfterClass
	public static void stop() throws Exception {
		if (jettyServer != null) {
			jettyServer.stop();
		}
        if (itSetup != null) {
            itSetup.stop();
        }
	}
}
