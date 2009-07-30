package org.jmx4perl.converter.json.simplifier;

import org.w3c.dom.Element;

import java.util.Map;

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
 * Special deserialization for DOM Elements to shorten the info
 *
 * @author roland
 * @since Jul 27, 2009
 */
public class DomElementHandler extends SimplifierHandler<Element> {


    public DomElementHandler() {
        super(Element.class);
    }

    // ==================================================================================
    @Override
    void init(Map<String, SimplifierHandler.Extractor<Element>> pExtractorMap) {
        pExtractorMap.put("value",new Extractor<Element>() {
            public Object extract(Element element) {
                return element.getNodeValue();
            }
        });
        pExtractorMap.put("name",new Extractor<Element>() {
            public Object extract(Element element) {
                return element.getNodeName();
            }
        });
        pExtractorMap.put("hasChildNodes",new Extractor<Element>() {
            public Object extract(Element element) {
                return element.hasChildNodes();
            }
        });
    }
}