package org.jmx4perl.client.response;

import org.jmx4perl.client.request.J4pVersionRequest;
import org.json.simple.JSONObject;

/**
 * @author roland
 * @since Apr 24, 2010
 */
public class J4pVersionResponse extends J4pResponse<J4pVersionRequest> {

    private String agentVersion;

    private String protocolVersion;

    public J4pVersionResponse(J4pVersionRequest pRequest, JSONObject pResponse) {
        super(pRequest,pResponse);
        JSONObject value = getValue();
        agentVersion = (String) value.get("agent");
        protocolVersion = (String) value.get("protocol");
    }

    public String getAgentVersion() {
        return agentVersion;
    }

    public String getProtocolVersion() {
        return protocolVersion;
    }
}
