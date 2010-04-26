package org.jmx4perl.client.response;

import org.jmx4perl.client.request.J4pReadRequest;
import org.json.simple.JSONObject;

/**
 * @author roland
 * @since Apr 26, 2010
 */
public class J4pReadResponse extends J4pResponse<J4pReadRequest> {
    public J4pReadResponse(J4pReadRequest pRequest, JSONObject pJsonResponse) {
        super(pRequest, pJsonResponse);
    }
}
