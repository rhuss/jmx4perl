package org.jmx4perl.client;

import java.io.IOException;
import java.util.Arrays;
import java.util.List;

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

    /**
     * Construct a new client for a given server url
     *
     * @param pJ4pServerUrl the agent URL for how to contact the server.
     */
    public J4pClient(String pJ4pServerUrl) {
        super(pJ4pServerUrl);
    }

    /**
     * Execute a single J4pRequest returning the appropriate result.
     * The HTTP Method used is determined automatically.
     *
     * @param pRequest request to execute
     * @return the response as returned by the server
     * @param <R> response type
     * @param <T> request type
     * @throws java.io.IOException when the execution fails
     * @throws org.json.simple.parser.ParseException if parsing of the JSON answer fails
     */
    public <R extends J4pResponse<T>,T extends J4pRequest> R execute(T pRequest) throws IOException, ParseException {
        HttpResponse response = httpClient.execute(getHttpRequest(pRequest,null));
        return this.<R,T>extractResponse(pRequest,response);
    }

    /**
     * Execute multiple requests at once. All given request will result in a single HTTP request where it gets
     * dispatched on the agent side. The results are given back in the same order as the arguments provided.
     *
     * @param pRequests requests to execute
     * @param <R> response type
     * @param <T> request type
     * @return list of responses, one response for each request
     * @throws java.io.IOException when the execution fails
     * @throws org.json.simple.parser.ParseException if parsing of the JSON answer fails
     */
    public <R extends J4pResponse<T>,T extends J4pRequest> List<R> execute(List<T> pRequests) throws IOException,ParseException {
        return null;
    }


    /**
     * Execute multiple requests at once. All given request will result in a single HTTP request where it gets
     * dispatched on the agent side. The results are given back in the same order as the arguments provided.
     *
     * @param pRequests requests to execute
     * @param <R> response type
     * @param <T> request type
     * @return list of responses, one response for each request
     * @throws java.io.IOException when the execution fails
     * @throws org.json.simple.parser.ParseException if parsing of the JSON answer fails
     */
    public <R extends J4pResponse<T>,T extends J4pRequest> List<R> execute(T ... pRequests) throws IOException,ParseException {
        return execute(Arrays.asList(pRequests));
    }
}
