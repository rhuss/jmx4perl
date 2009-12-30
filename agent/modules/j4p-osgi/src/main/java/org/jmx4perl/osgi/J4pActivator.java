package org.jmx4perl.osgi;

import org.jmx4perl.AgentServlet;
import org.osgi.framework.*;
import org.osgi.service.http.HttpService;
import org.osgi.service.http.NamespaceException;

import javax.servlet.ServletException;

/**
 * @author roland
 * @since Dec 27, 2009
 */
public class J4pActivator implements BundleActivator {

    // Context associated with this activator
    private BundleContext bundleContext;

    // Listener used for monitoring HttpService
    private ServiceListener httpServiceListener;

    public void start(BundleContext pBundleContext) throws Exception {
        bundleContext = pBundleContext;
        final ServiceReference sRef = pBundleContext.getServiceReference(HttpService.class.getName());
        if (sRef != null) {
            registerServlet(sRef);
        }
        httpServiceListener = createServiceListener();
        pBundleContext.addServiceListener(httpServiceListener,"(objectClass=" + HttpService.class.getName() + ")");
    }

    public void stop(BundleContext pBundleContext) throws Exception {
        assert pBundleContext.equals(bundleContext);
        ServiceReference sRef = pBundleContext.getServiceReference(HttpService.class.getName());
        if (sRef != null) {
            unregisterServlet(sRef);
        }
        pBundleContext.removeServiceListener(httpServiceListener);
    }


    private ServiceListener createServiceListener() {
        return new ServiceListener() {
            public void serviceChanged(ServiceEvent pServiceEvent) {
                try {
                    if (pServiceEvent.getType() == ServiceEvent.REGISTERED) {
                        registerServlet(pServiceEvent.getServiceReference());
                    } else if (pServiceEvent.getType() == ServiceEvent.UNREGISTERING) {
                        unregisterServlet(pServiceEvent.getServiceReference());
                    }
                } catch (ServletException e) {
                    // TODO: Log this.
                    e.printStackTrace();  //To change body of catch statement use File | Settings | File Templates.
                } catch (NamespaceException e) {
                    // TODO: Log this.
                    e.printStackTrace();  //To change body of catch statement use File | Settings | File Templates.
                }
            }
        };
    }


    private void unregisterServlet(ServiceReference sRef) {
        if (sRef != null) {
            HttpService service = (HttpService) bundleContext.getService(sRef);
            service.unregister("/j4p");
        }
    }

    private void registerServlet(ServiceReference pSRef) throws ServletException, NamespaceException {
        HttpService service = (HttpService) bundleContext.getService(pSRef);
        service.registerServlet("/j4p", new AgentServlet(), null, null);
    }

}
