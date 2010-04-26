package org.jmx4perl.client;

import java.io.IOException;

import org.apache.http.HttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.DefaultHttpClient;
import org.jmx4perl.client.request.J4pRequest;
import org.jmx4perl.client.request.J4pRequestManager;
import org.jmx4perl.client.response.J4pResponse;
import org.json.simple.parser.ParseException;


/**
 * Client class for accessing the j4p agent
 *
 * @author roland
 * @since Apr 24, 2010
 */
public class J4pClient extends J4pRequestManager {

    // Http client used for connecting the j4p Agent
    private DefaultHttpClient httpClient = new DefaultHttpClient();


    public J4pClient(String pJ4pServerUrl) {
        super(pJ4pServerUrl);
    }

    /**
     * Execute a single J4pRequest returning the appropriate result.
     * The HTTP Method used is determined automatically.
     *
     * @param pRequest request to execute
     * @return the response as returned by the server
     * @throws java.io.IOException when the execution fails
     * @throws org.json.simple.parser.ParseException if parsing of the JSON answer fails
     */
    public <T extends J4pRequest> J4pResponse<T> execute(T pRequest) throws IOException, ParseException {
        HttpResponse response = httpClient.execute(getHttpRequest(pRequest,null));
        return extractResponse(pRequest,response);
    }
}
