package org.jmx4perl.config;

import org.jmx4perl.JmxRequest;

import javax.management.ObjectName;
import javax.servlet.http.HttpServletRequest;

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
 * @author roland
 * @since Jul 28, 2009
 */
public interface Restrictor {

    /**
     * Check whether the provided command type is allowed in principal
     *
     * @param pType type to check
     * @return true, if the type is allowed, false otherwise
     */
    boolean isTypeAllowed(String pType);

    /**
     * Check whether reading of an attribute is allowed
     *
     * @param pName MBean name
     * @param pAttribute attribute to check
     * @return true if access is allowed
     */
    boolean isAttributeReadAllowed(ObjectName pName,String pAttribute);

    /**
     * Check whether writing of an attribute is allowed
     *
     * @param pName MBean name
     * @param pAttribute attribute to check
     * @return true if access is allowed
     */
    boolean isAttributeWriteAllowed(ObjectName pName,String pAttribute);

    /**
     * Check whether execution of an operation is allowed
     *
     * @param pName MBean name
     * @param pOperation attribute to check
     * @return true if access is allowed
     */
    boolean isOperationAllowed(ObjectName pName,String pOperation);

    /**
     * Check whether access from the connected client is allowed. If at least
     * one of the given parameters matches, then this method returns true.
     *
     * @return true is access is allowed
     */
    boolean isRemoteAccessAllowed(String pHost, String pAddress);
}
