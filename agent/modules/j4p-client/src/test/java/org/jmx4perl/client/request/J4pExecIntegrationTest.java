package org.jmx4perl.client.request;

import java.io.IOException;

import javax.management.MalformedObjectNameException;

import org.jmx4perl.client.response.J4pExecResponse;
import org.json.simple.parser.ParseException;
import org.junit.Test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

/**
 * @author roland
 * @since May 18, 2010
 */
public class J4pExecIntegrationTest extends AbstractJ4pIntegrationTest {

    @Test
    public void simpleOperation() throws MalformedObjectNameException, IOException, ParseException {
        J4pExecRequest request = new J4pExecRequest(itSetup.getOperationMBean(),"fetchNumber","inc");
        J4pExecResponse resp = j4pClient.execute(request);
        assertEquals("0",resp.getValue());
        resp = j4pClient.execute(request);
        assertEquals("1",resp.getValue());
    }

    @Test
    public void failedOperation() throws MalformedObjectNameException, IOException, ParseException {
        J4pExecRequest request = new J4pExecRequest(itSetup.getOperationMBean(),"fetchNumber","bla");
        J4pExecResponse resp = j4pClient.execute(request);
        assertTrue(resp.isError());
    }

    @Test
    public void nullArgumentCheck() throws MalformedObjectNameException, IOException, ParseException {
        J4pExecRequest request = new J4pExecRequest(itSetup.getOperationMBean(),"nullArgumentCheck",null,null);
        J4pExecResponse resp = j4pClient.execute(request);
        assertEquals("true",resp.getValue());
    }

    @Test
    public void emptyStringArgumentCheck() throws MalformedObjectNameException, IOException, ParseException {
        J4pExecRequest request = new J4pExecRequest(itSetup.getOperationMBean(),"emptyStringArgumentCheck","");
        J4pExecResponse resp = j4pClient.execute(request);
        assertEquals("true",resp.getValue());
    }
}
