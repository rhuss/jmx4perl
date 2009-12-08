package org.jmx4perl.mule;

import org.jmx4perl.AgentServlet;
import org.mortbay.jetty.Server;
import org.mortbay.jetty.servlet.Context;
import org.mortbay.jetty.servlet.ServletHolder;
import org.mule.AbstractAgent;
import org.mule.api.MuleException;
import org.mule.api.lifecycle.InitialisationException;
import org.mule.api.lifecycle.StartException;
import org.mule.api.lifecycle.StopException;

/**
 * @author roland
 * @since Dec 8, 2009
 */
public class J4pAgent extends AbstractAgent {

    // Jetty server to use
    private Server server;

    // Default port
    private int port = 8888;

    protected J4pAgent() {
        super("j4p-agent");
    }

    @Override
    public void stop() throws MuleException {
        try {
            server.stop();
        } catch (Exception e) {
            throw new StopException(e,this);
        }
    }

    @Override
    public void start() throws MuleException {
        try {
            server.start();
        } catch (Exception e) {
            throw new StartException(e,this);
        }
    }

    @Override
    public void dispose() {
    }

    @Override
    public void registered() {
    }

    @Override
    public void unregistered() {
    }

    @Override
    public void initialise() throws InitialisationException {
        server = new Server(getPort());
        Context root = new Context(server,"/j4p",Context.SESSIONS);
        root.addServlet(new ServletHolder(new AgentServlet()), "/*");
    }

    public int getPort() {
        return port;
    }

    public void setPort(int pPort) {
        port = pPort;
    }
}
