package org.jmx4perl.client.response;

import org.jmx4perl.client.request.J4pWriteRequest;
import org.json.simple.JSONObject;

/**
 * Response for a {@link J4pWriteRequest}. As value it returns the old value of the
 * attribute.
 *
 * @author roland
 * @since Jun 5, 2010
 */
public class J4pWriteResponse extends J4pResponse<J4pWriteRequest> {

    public J4pWriteResponse(J4pWriteRequest pRequest, JSONObject pJsonResponse) {
        super(pRequest, pJsonResponse);
    }
}
