package org.jmx4perl.client.response;

import java.util.Date;

import org.jmx4perl.client.request.J4pRequest;
import org.jmx4perl.client.request.J4pType;
import org.json.simple.JSONObject;

/**
 * Representation of a j4p Response as sent by the
 * j4p agent.
 *
 * @author roland
 * @since Apr 24, 2010
 */
abstract public class J4pResponse<T extends J4pRequest> {

    // JSON representation of the returned response
    private JSONObject jsonResponse;

    // request which lead to this response
    private T request;

    // timestamp of this response
    private Date requestDate;

    protected J4pResponse(T pRequest, JSONObject pJsonResponse) {
        request = pRequest;
        jsonResponse = pJsonResponse;
        Long timestamp = (Long) jsonResponse.get("timestamp");
        requestDate = timestamp != null ? new Date(timestamp) : new Date();
    }

    /**
     * Get the request associated with this response
     * @return the request
     */
    public T getRequest() {
        return request;
    }

    /**
     * Get the request/response type
     *
     * @return type
     */
    public J4pType getType() {
        return request.getType();
    }

    /**
     * Date when the request was processed
     *
     * @return request date
     */
    public Date getRequestDate() {
        return requestDate;
    }

    /**
     * Get the value of this response
     *
     * @return json representation of answer
     */
    public Object getValue() {
        return jsonResponse.get("value");
    }

    /**
     * Get status of this response (similar in meaning of HTTP stati)
     *
     * @return status
     */
    public long getStatus() {
        return (Long) jsonResponse.get("status");
    }

    /**
     * Whether the request resulted in an error
     *
     * @return whether this response represents an error
     */
    public boolean isError() {
        return getStatus() != 200;
    }

    /**
     * Get the error string when {@link #isError()} is true. Return <code>null</code>
     * if no error has occured
     *
     * @return error text
     */
    public String getError() {
        return (String) jsonResponse.get("error");
    }

    /**
     * Get the server side stacktrace as string when {@link #isError()} is true. Return <code>null</code>
     * if no error has occured.
     * @return server side stacktrace as string
     */
    public String getStackTrace() {
        return (String) jsonResponse.get("stacktrace");
    }
}
