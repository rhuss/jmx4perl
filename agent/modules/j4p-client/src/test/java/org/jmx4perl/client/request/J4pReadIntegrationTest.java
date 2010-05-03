package org.jmx4perl.client.request;

import java.io.IOException;
import java.util.List;

import javax.management.MalformedObjectNameException;
import javax.management.ObjectName;

import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.jmx4perl.client.response.J4pReadResponse;
import org.json.simple.parser.ParseException;
import org.junit.Test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

/**
 * @author roland
 * @since Apr 27, 2010
 */
public class J4pReadIntegrationTest extends AbstractJ4pIntegrationTest {

    @Test
    public void nameTest() throws MalformedObjectNameException, IOException, ParseException {
        checkNames(HttpGet.METHOD_NAME,itSetup.getStrangeNames(),itSetup.getEscapedNames());
        checkNames(HttpPost.METHOD_NAME,itSetup.getStrangeNames(),itSetup.getEscapedNames());
    }

    @Test
    public void errorTest() throws MalformedObjectNameException, IOException, ParseException {
        J4pReadRequest req = new J4pReadRequest("no.domain:name=vacuum","oxygen");
        J4pReadResponse resp = j4pClient.execute(req);
        assertTrue(resp.isError());
        assertEquals(404,resp.getStatus());
        assertTrue(resp.getError().contains("InstanceNotFoundException"));
        assertTrue(resp.getStackTrace().contains("InstanceNotFoundException"));

    }

    private void checkNames(String pMethod, List<String> ... pNames) throws MalformedObjectNameException, IOException, ParseException {
        for (int i = 0;i<pNames.length;i++) {
            for (String name : pNames[i]) {
                System.out.println(name);
                ObjectName oName =  new ObjectName(name);
                J4pReadRequest req = new J4pReadRequest(oName,"Ok");
                req.setPreferredHttpMethod(pMethod);
                J4pReadResponse resp = j4pClient.execute(req);
                assertEquals("OK",resp.getValue());
            }
        }
    }
}
