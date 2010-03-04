package org.jmx4perl.jvmagent.jdk6;

import com.sun.net.httpserver.HttpServer;

/**
 * @author roland
 * @since Mar 3, 2010
 */
class CleanUpThread extends Thread {

    private HttpServer server;
    private ThreadGroup threadGroup;

    CleanUpThread(HttpServer pServer,ThreadGroup pThreadGroup) {
        super("J4P Agent Cleanup Thread");
        server = pServer;
        threadGroup = pThreadGroup;
        setDaemon(true);
    }

    @Override
    public void run() {
        try {
            boolean finished = false;
            while (!finished) {
                final Thread[] all = new Thread[Thread.activeCount()+100];
                final int count = Thread.enumerate(all);
                finished = true;
                for (int i=0;i<count;i++) {
                    final Thread t = all[i];
                    // daemon and our own threadgroup
                    if (t.isDaemon() ||
                            t.getThreadGroup().equals(threadGroup) ||
                            t.getName().startsWith("DestroyJavaVM")) {
                        continue;
                    }
                    // Non daemon, non RMI Reaper: join it, break the for
                    // loop, continue in the while loop (loop=true)
                    finished = false;
                    try {
                        t.join();
                    } catch (Exception ex) {
                        // Ignore that one.
                    }
                    break;
                }
            }
        } finally {
            // All non-daemon threads stopped ==> server can be stopped, too
            server.stop(0);
        }
    }
}

