package org.jmx4perl.converter.json;

import org.jmx4perl.converter.json.ObjectToJsonConverter;
import org.jmx4perl.converter.StringToObjectConverter;
import org.junit.Before;
import org.junit.Test;
import org.junit.After;
import static org.junit.Assert.*;
import javax.management.AttributeNotFoundException;
import java.util.Stack;
import java.util.Map;
import java.io.File;

/*
 * jmx4perl - WAR Agent for exporting JMX via JSON
 *
 * Copyright (C) 2009 Roland Huß, roland@cpan.org
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 * A commercial license is available as well. Please contact roland@cpan.org for
 * further details.
 */

/**
 * Testing the converter
 *
 * @author roland
 * @since Jul 24, 2009
 */
public class ObjectToJsonConverterTest {

    private ObjectToJsonConverter converter;

    @Before
    public void setup() {
        converter = new ObjectToJsonConverter(new StringToObjectConverter(), pConfig);
        converter.setupContext(0,0,0);
    }

    @After
    public void tearDown() {
        converter.clearContext();
    }

    @Test
    public void basics() throws AttributeNotFoundException {
        Map result = (Map) converter.extractObject(new SelfRefBean1(),new Stack<String>(),true);
        assertNotNull("Bean2 is set",result.get("bean2"));
        assertNotNull("Binary attribute is set",result.get("strong"));
    }

    @Test
    public void checkDeadLockDetection() throws AttributeNotFoundException {
        Map result = (Map) converter.extractObject(new SelfRefBean1(),new Stack<String>(),true);
        assertNotNull("Bean 2 is set",result.get("bean2"));
        assertNotNull("Bean2:Bean1 is set",((Map)result.get("bean2")).get("bean1"));
        assertEquals("Reference breackage",((Map)result.get("bean2")).get("bean1").getClass(),String.class);
        assertTrue("Bean 3 should be resolved",result.get("bean3") instanceof Map);
    }

    public void stackOverflowTest() throws AttributeNotFoundException {
        File test = new File(".");
        Map result = (Map) converter.extractObject(test,new Stack<String>(),true);
        String c = (String) ((Map) result.get("canonicalFile")).get("canonicalFile");
        assertTrue("Recurence detected",c.contains("Reference"));
    }


    @Test
    public void maxDepth() throws AttributeNotFoundException {
        ObjectToJsonConverter.StackContext ctx = converter.stackContextLocal.get();
        ctx.setMaxDepth(1);
        Map result = (Map) converter.extractObject(new SelfRefBean1(),new Stack<String>(),true);
        String c = (String) ((Map) result.get("bean2")).get("bean1");
        assertTrue("Recurence detected",c.contains("Depth limit"));
    }

    // ============================================================================
    // TestBeans:

    class SelfRefBean1 {

        SelfRefBean2 bean2;
        SelfRefBean3 bean3;

        boolean strong;

        SelfRefBean1() {
            bean3 = new SelfRefBean3(this);
            bean2 = new SelfRefBean2(this,bean3);
        }

        public SelfRefBean2 getBean2() {
            return bean2;
        }

        public SelfRefBean3 getBean3() {
            return bean3;
        }

        public boolean isStrong() {
            return strong;
        }
    }

    class SelfRefBean2 {

        SelfRefBean1 bean1;
        SelfRefBean3 bean3;

        SelfRefBean2(SelfRefBean1 pBean1,SelfRefBean3 pBean3) {
            bean1 = pBean1;
            bean3 = pBean3;
        }

        public SelfRefBean1 getBean1() {
            return bean1;
        }

        public SelfRefBean3 getBean3() {
            return bean3;
        }
    }

    class SelfRefBean3 {

        SelfRefBean1 bean1;

        SelfRefBean3(SelfRefBean1 pBean1) {
            bean1 = pBean1;
        }

        public SelfRefBean1 getBean1() {
            return bean1;
        }
    }
}

