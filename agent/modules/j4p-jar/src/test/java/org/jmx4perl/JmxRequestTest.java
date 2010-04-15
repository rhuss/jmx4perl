package org.jmx4perl;

import java.util.Arrays;
import java.util.List;

import javax.management.MalformedObjectNameException;

import org.junit.Test;

import static org.junit.Assert.assertEquals;

/**
 * @author roland
 * @since Apr 15, 2010
 */
public class JmxRequestTest {

    @Test
    public void testPathSplitting() throws MalformedObjectNameException {
        JmxRequest req =
                new JmxRequestBuilder(JmxRequest.Type.LIST,"test:name=split").
                        build();
        List<String> paths = req.splitPath("hello/world");
        assertEquals(2,paths.size());
        assertEquals("hello",paths.get(0));
        assertEquals("world",paths.get(1));

        paths = req.splitPath("hello\\/world/second");
        assertEquals(2,paths.size());
        assertEquals("hello/world",paths.get(0));
        assertEquals("second",paths.get(1));
    }

    @Test
    public void testPathGlueing() throws MalformedObjectNameException {
        JmxRequest req =
                new JmxRequestBuilder(JmxRequest.Type.LIST,"test:name=split").
                        build();
        req.setExtraArgs(Arrays.asList("hello/world","second"));
        String combined = req.getExtraArgsAsPath();
        assertEquals("hello\\/world/second",combined);
    }
}
