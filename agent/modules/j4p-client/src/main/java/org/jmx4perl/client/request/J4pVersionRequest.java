package org.jmx4perl.client.request;

import java.util.Collections;
import java.util.List;

import org.jmx4perl.client.response.J4pVersionResponse;
import org.json.simple.JSONObject;

/**
 * @author roland
 * @since Apr 24, 2010
 */
public class J4pVersionRequest extends J4pRequest {

    protected J4pVersionRequest() {
        super(J4pType.VERSION);
    }

    @Override
    List<String> getRequestParts() {
        return Collections.emptyList();
    }

    @Override
    JSONObject toJson() {
        return super.toJson();
    }

    @Override
    J4pVersionResponse createResponse(JSONObject pResponse) {
        return new J4pVersionResponse(this,pResponse);
    }

}
