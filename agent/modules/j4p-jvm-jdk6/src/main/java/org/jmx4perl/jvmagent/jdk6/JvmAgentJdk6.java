package org.jmx4perl.jvmagent.jdk6;

import com.sun.net.httpserver.HttpServer;
import org.jmx4perl.Config;

import java.io.IOException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.util.HashMap;
import java.util.Map;

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
 * A JVM level agent using the JDK6 HTTP Server {@link com.sun.net.httpserver.HttpServer}
 *
 * @author roland
 * @since Mar 3, 2010
 */
public class JvmAgentJdk6 {

    private static final int DEFAULT_PORT = 8778;
    private static final int DEFAULT_BACKLOG = 10;
    private static final String J4P_CONTEXT = "/j4p/";

    private JvmAgentJdk6() {}


    /**
     * Entry point for the agent
     *
     * @param agentArgs arguments as given on the command line
     */
    public static void premain(String agentArgs) {
        try {
            final HttpServer server = createServer(parseArgs(agentArgs));
            server.createContext(J4P_CONTEXT,new J4pHttpHandler(J4P_CONTEXT,new HashMap<Config,String>() /* empty for now */));
            ThreadGroup threadGroup = new ThreadGroup("j4p");
            threadGroup.setDaemon(false);
            Thread starterThread = new Thread(threadGroup,new Runnable() {
                @Override
                public void run() {
                    server.start();
                }
            });
            starterThread.start();
            Thread cleaner = new CleanUpThread(server,threadGroup);
            cleaner.start();
        } catch (IOException e) {
            System.err.println("j4p: Cannot create HTTP-Server: " + e);
        }
    }

    private static void startServer(final HttpServer pServer) {
        ThreadGroup threadGroup = new ThreadGroup("j4p");
        threadGroup.setDaemon(false);
        Thread starterThread = new Thread(threadGroup,new Runnable() {
            @Override
            public void run() {
                pServer.start();
            }
        });
        starterThread.start();
    }


    private static HttpServer createServer(Map<String, String> pArguments) throws IOException {
        int port = DEFAULT_PORT;
        if (pArguments.get("port") != null) {
            port = Integer.parseInt(pArguments.get("port"));
        }
        InetAddress address;
        if (pArguments.get("host") != null) {
            address = InetAddress.getByName(pArguments.get("host"));
        } else {
            address = InetAddress.getLocalHost();
        }
        int backLog = DEFAULT_BACKLOG;
        if (pArguments.get("backlog") != null) {
            backLog = Integer.parseInt(pArguments.get("backlog"));
        }
        InetSocketAddress socketAddress = new InetSocketAddress(address,port);
        System.out.println("j4p: Agent URL http://" + address.getHostAddress() + ":" + port + J4P_CONTEXT);
        return HttpServer.create(socketAddress,backLog);
    }

    private static Map<String, String> parseArgs(String pAgentArgs) {
        Map<String,String> ret = new HashMap<String,String>();
        if (pAgentArgs != null && pAgentArgs.length() > 0) {
            for (String arg : pAgentArgs.split(",")) {
                String[] prop = arg.split("=");
                if (prop == null || prop.length != 2) {
                    System.err.println("j4p: Invalid option '" + arg + "'. Ignoring");
                } else {
                    ret.put(prop[0],prop[1]);
                }
            }
        }
        return ret;
    }
}
