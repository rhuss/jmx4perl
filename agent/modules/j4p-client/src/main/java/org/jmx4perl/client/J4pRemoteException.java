package org.jmx4perl.client;

/**
 * Exception occured on the remote side (i.e the server).
 *
 * @author roland
 * @since Jun 9, 2010
 */
public class J4pRemoteException extends J4pException {

    // Status code of the error
    private int status;

    // Stacktrace of a remote exception (optional)
    String remoteStacktrace;

    /**
     * Constructor for a remote exception
     *
     * @param pMessage error message of the exception occurred remotely
     * @param pStatus status code
     * @param pStacktrace stacktrace of the remote exception
     */
    public J4pRemoteException(String pMessage,int pStatus,String pStacktrace) {
        super(pMessage);
        status = pStatus;
        remoteStacktrace = pStacktrace;
    }

    /**
     * The status code of the exception (similar to HTTP error code)
     *
     * @return status code
     */
    public int getStatus() {
        return status;
    }

    /**
     * Remote stackrace of the error occured
     *
     * @return stacktrace
     */
    public String getRemoteStackTrace() {
        return remoteStacktrace;
    }
}
