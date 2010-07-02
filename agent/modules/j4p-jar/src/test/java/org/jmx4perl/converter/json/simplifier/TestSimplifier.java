package org.jmx4perl.converter.json.simplifier;

import java.util.Date;
import java.util.Map;

import org.junit.Ignore;

/**
 * @author roland
 * @since Jul 2, 2010
 */
@Ignore
public class TestSimplifier extends SimplifierExtractor<Date> {
    public TestSimplifier() {
        super(Date.class);
    }

    @Override
    void init(Map<String, AttributeExtractor<Date>> pStringAttributeExtractorMap) {
        Object[][] pAttrs = {
                { "millis", new AttributeExtractor<Date>() {
                    public Object extract(Date value) throws SkipAttributeException {
                        return value.getTime();
                    }
                }
                },
        };
        addExtractors(pAttrs);
    }
}
