package org.jmx4perl.converter.json.simplifier;

import java.io.File;
import java.io.IOException;
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
 * Special deserialization for Files to shorten the info
 *
 * @author roland
 * @since Jul 27, 2009
 */
public class FileHandler extends SimplifierHandler {


    public FileHandler() {
        super(File.class);
    }

    // ==================================================================================
    void init(Map pExtractorMap) {
        extractorMap.put("name",new Extractor() {
            public Object extract(Object file) {
                return ((File) file).getName();
            }
        });

        extractorMap.put("modified",new Extractor() {
            public Object extract(Object file) {
                return new Long(((File) file).lastModified());
            }
        });

        extractorMap.put("length",new Extractor() {
            public Object extract(Object file) {
                return new Long(((File) file).length());
            }
        });

        extractorMap.put("directory",new Extractor() {
            public Object extract(Object file) {
                return new Boolean(((File) file).isDirectory());
            }
        });

        extractorMap.put("canonicalPath",new Extractor() {
            public Object extract(Object file) {
                try {
                    return ((File) file).getCanonicalPath();
                } catch (IOException exp) {
                    return null;
                }
            }
        });

        extractorMap.put("exists",new Extractor() {
            public Object extract(Object file) {
                return new Boolean(((File) file).exists());
            }
        });
    }
}
