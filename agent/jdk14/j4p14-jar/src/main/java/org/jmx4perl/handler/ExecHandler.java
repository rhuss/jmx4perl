package org.jmx4perl.handler;

import org.jmx4perl.JmxRequest;
import org.jmx4perl.config.Restrictor;
import org.jmx4perl.converter.StringToObjectConverter;

import javax.management.*;
import java.util.List;

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
 * @since Jun 12, 2009
 */
public class ExecHandler extends RequestHandler {
    private StringToObjectConverter stringToObjectConverter;

    public ExecHandler(Restrictor pRestrictor,StringToObjectConverter pStringToObjectConverter) {
        super(pRestrictor);
        stringToObjectConverter = pStringToObjectConverter;
    }

    public String getType() {
        return "exec";
    }

    public Object doHandleRequest(MBeanServer server, JmxRequest request)
            throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException {
        if (!restrictor.isOperationAllowed(request.getObjectName(),request.getOperation())) {
            throw new SecurityException("Operation " + request.getOperation() +
                    " forbidden for MBean " + request.getObjectNameAsString());
        }
        String[] paramClazzes;
        paramClazzes = extractOperationTypes(server,request);
        Object[] params = new Object[paramClazzes.length];
        List args = request.getExtraArgs();
        if (args.size() != paramClazzes.length) {
            throw new IllegalArgumentException("Invalid operation parameters. Operation " +
                    request.getOperation() + " requires " + paramClazzes.length +
                    " parameters, not " + args.size() + " as given");
        }
        for (int i = 0;i <  paramClazzes.length; i++) {
            params[i] = stringToObjectConverter.convertFromString(paramClazzes[i], (String) args.get(i));
        }

        // Remove args from request, so that the rest can be interpreted as path for the return
        // value
        for (int i = 0; i < paramClazzes.length; i++) {
            // Remove from front
            args.remove(0);
        }

        return server.invoke(request.getObjectName(),request.getOperation(),params,paramClazzes);
    }

    private String[] extractOperationTypes(MBeanServer pServer, JmxRequest pRequest)
            throws ReflectionException, InstanceNotFoundException {
        try {
            MBeanInfo mBeanInfo = pServer.getMBeanInfo(pRequest.getObjectName());
            MBeanOperationInfo infos[] = mBeanInfo.getOperations();
            for (int j = 0; j < infos.length; j++) {
                MBeanOperationInfo opInfo = infos[j];
                if (opInfo.getName().equals(pRequest.getOperation())) {
                    MBeanParameterInfo[] pInfos = opInfo.getSignature();
                    String[] types = new String[pInfos.length];
                    for (int i=0;i<pInfos.length;i++) {
                        types[i] = pInfos[i].getType();
                    }
                    return types;
                }
            }
        } catch (IntrospectionException e) {
            throw new IllegalStateException("Cannot extract MBeanInfo for " + pRequest.getObjectNameAsString());
        }
        throw new IllegalArgumentException(
                "No operation " + pRequest.getOperation() + " on MBean " + pRequest.getObjectNameAsString() + " exists.");
    }

}
