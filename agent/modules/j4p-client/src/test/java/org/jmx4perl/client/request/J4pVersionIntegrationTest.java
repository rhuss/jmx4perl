package org.jmx4perl.client.request;

import java.io.IOException;

import org.apache.http.client.methods.HttpPost;
import org.jmx4perl.Version;
import org.jmx4perl.client.J4pClient;
import org.jmx4perl.client.response.J4pVersionResponse;
import org.json.simple.parser.ParseException;
import org.junit.Test;

import static org.junit.Assert.*;

/**
 * @author roland
 * @since Apr 26, 2010
 */
public class J4pVersionIntegrationTest extends AbstractJ4pIntegrationTest {


    @Test
    public void versionGetRequest() throws IOException, ParseException {
        J4pVersionRequest req = new J4pVersionRequest();
        J4pVersionResponse resp = (J4pVersionResponse) j4pClient.execute(req);
        assertEquals("Proper agent version",Version.getAgentVersion(),resp.getAgentVersion());
        assertEquals("Proper protocol version",Version.getProtocolVersion(),resp.getProtocolVersion());
        assertTrue("Request timestamp",resp.getRequestDate().getTime() <= System.currentTimeMillis());
    }

    @Test
    public void versionPostRequest() throws IOException, ParseException {
        J4pVersionRequest req = new J4pVersionRequest();
        req.setPreferredHttpMethod(HttpPost.METHOD_NAME);
        J4pVersionResponse resp = (J4pVersionResponse) j4pClient.execute(req);
        assertEquals("Proper agent version",Version.getAgentVersion(),resp.getAgentVersion());
        assertEquals("Proper protocol version",Version.getProtocolVersion(),resp.getProtocolVersion());
        assertTrue("Request timestamp",resp.getRequestDate().getTime() <= System.currentTimeMillis());
    }


}
