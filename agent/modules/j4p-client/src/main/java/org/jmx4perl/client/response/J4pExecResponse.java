package org.jmx4perl.client.response;

import org.jmx4perl.client.request.J4pExecRequest;
import org.json.simple.JSONObject;

/**
 * Response for an execute request
 *
 * @author roland
 * @since May 18, 2010
 */
public class J4pExecResponse extends J4pResponse<J4pExecRequest> {

    public J4pExecResponse(J4pExecRequest pRequest, JSONObject pJsonResponse) {
        super(pRequest, pJsonResponse);
    }
}
