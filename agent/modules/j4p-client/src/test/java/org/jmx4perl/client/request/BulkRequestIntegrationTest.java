package org.jmx4perl.client.request;

import java.util.List;

import javax.management.MalformedObjectNameException;

import org.jmx4perl.client.J4pException;
import org.jmx4perl.client.response.*;
import org.junit.Test;

import static org.junit.Assert.*;

/**
 * @author roland
 * @since Jun 9, 2010
 */
public class BulkRequestIntegrationTest extends AbstractJ4pIntegrationTest {

    @Test
    public void simpleBulkRequest() throws MalformedObjectNameException, J4pException {
        J4pRequest req1 = new J4pExecRequest(itSetup.getOperationMBean(),"fetchNumber","inc");
        J4pVersionRequest req2 = new J4pVersionRequest();
        List resp = j4pClient.execute(req1,req2);
        assertEquals(resp.size(),2);
        assertTrue(resp.get(0) instanceof J4pExecResponse);
        assertTrue(resp.get(1) instanceof J4pVersionResponse);
        List<J4pResponse<J4pRequest>> typeSaveResp = j4pClient.execute(req1,req2);
        for (J4pResponse<?> r : typeSaveResp) {
            assertTrue(r instanceof J4pExecResponse || r instanceof J4pVersionResponse);
        }
    }
}
