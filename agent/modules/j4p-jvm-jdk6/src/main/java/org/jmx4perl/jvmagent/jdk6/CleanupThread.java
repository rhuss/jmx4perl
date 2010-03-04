package org.jmx4perl.jvmagent.jdk6;

import com.sun.net.httpserver.HttpServer;

/**
 * Thread for stopping the HttpServer as soon as every non-daemon
 * thread has exited. This thread was inspired by the ideas from
 * Daniel Fuchs (although the implementation is different)
 * (http://blogs.sun.com/jmxetc/entry/more_on_premain_and_jmx)
 *
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
            boolean retry = true;
            while (retry) {
                Thread[] threads = null;
                int nrThreads = 0;
                boolean fits = false;
                int inc = 50;
                while (!fits) {
                    try {
                        threads = new Thread[Thread.activeCount()+inc];
                        nrThreads = Thread.enumerate(threads);
                        fits = true;
                    } catch (ArrayIndexOutOfBoundsException exp) {
                        inc += 50;
                    }
                }
                retry = false;
                for (int i=0;i<nrThreads;i++) {
                    final Thread t = threads[i];
                    if (t.isDaemon() ||
                            t.getThreadGroup().equals(threadGroup) ||
                            t.getName().startsWith("DestroyJavaVM")) {
                        continue;
                    }
                    try {
                        t.join();
                    } catch (Exception ex) {
                        // Ignore that one.
                    } finally {
                        retry = true;
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

