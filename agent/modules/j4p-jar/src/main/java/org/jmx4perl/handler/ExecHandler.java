package org.jmx4perl.handler;

import org.jmx4perl.JmxRequest;
import org.jmx4perl.config.Restrictor;
import org.jmx4perl.converter.StringToObjectConverter;

import javax.management.*;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

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
public class ExecHandler extends JsonRequestHandler {
    private StringToObjectConverter stringToObjectConverter;

    public ExecHandler(Restrictor pRestrictor,StringToObjectConverter pStringToObjectConverter) {
        super(pRestrictor);
        stringToObjectConverter = pStringToObjectConverter;
    }

    @Override
    public JmxRequest.Type getType() {
        return JmxRequest.Type.EXEC;
    }

    @Override
    public Object doHandleRequest(MBeanServerConnection server, JmxRequest request)
            throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException, IOException {
        if (!restrictor.isOperationAllowed(request.getObjectName(),request.getOperation())) {
            throw new SecurityException("Operation " + request.getOperation() +
                    " forbidden for MBean " + request.getObjectNameAsString());
        }
        OperationAndParamType types = extractOperationTypes(server,request);
        Object[] params = new Object[types.paramClasses.length];
        List<String> args = request.getExtraArgs();
        if (args.size() != types.paramClasses.length) {
            throw new IllegalArgumentException("Invalid operation parameters. Operation " +
                    request.getOperation() + " on " + request.getObjectName() + " requires " + types.paramClasses.length +
                    " parameters, not " + args.size() + " as given");
        }
        for (int i = 0;i <  types.paramClasses.length; i++) {
            params[i] = stringToObjectConverter.convertFromString(types.paramClasses[i],args.get(i));
        }

        // Remove args from request, so that the rest can be interpreted as path for the return
        // value
        for (int i = 0; i < types.paramClasses.length; i++) {
            // Remove from front
            args.remove(0);
        }

        return server.invoke(request.getObjectName(),types.operationName,params,types.paramClasses);
    }

    private OperationAndParamType extractOperationTypes(MBeanServerConnection pServer, JmxRequest pRequest)
            throws ReflectionException, InstanceNotFoundException, IOException {
        List<String> opArgs = splitOperation(pRequest.getOperation());
        String operation = opArgs.get(0);
        List<String> types = null;
        if (opArgs.size() > 1) {
            types = opArgs.subList(1,opArgs.size());
        }


        try {
            MBeanInfo mBeanInfo = pServer.getMBeanInfo(pRequest.getObjectName());
            List<MBeanParameterInfo[]> paramInfos = new ArrayList<MBeanParameterInfo[]>();
            for (MBeanOperationInfo opInfo : mBeanInfo.getOperations()) {
                if (opInfo.getName().equals(operation)) {
                    paramInfos.add(opInfo.getSignature());
                }
            }
            if (paramInfos.size() == 0) {
                throw new IllegalArgumentException("No operation " + operation +
                        " found on MBean " + pRequest.getObjectNameAsString());
            }
            if (types == null && paramInfos.size() > 1) {
                    throw new IllegalArgumentException(
                            getErrorMessageForMissingSignature(pRequest, operation, paramInfos));
            }
            OUTER:
            for (MBeanParameterInfo[]  infos : paramInfos) {
                String[] paramClasses = new String[infos.length];
                if (types != null && types.size() != infos.length) {
                    // Number of arguments dont match
                    continue OUTER;
                }
                for (int i=0;i<infos.length;i++) {
                    String type = infos[i].getType();
                    if (types != null && !type.equals(types.get(i))) {
                        // Non-matching signature
                        continue OUTER;
                    }
                    paramClasses[i] = type;
                }
                // If we did it until here, we are finished.
                return new OperationAndParamType(operation,paramClasses);
            }
            throw new IllegalArgumentException(
                    "No operation " + pRequest.getOperation() + " on MBean " + pRequest.getObjectNameAsString() + " exists. " +
                            "Known signatures: " + signatureToString(paramInfos));
        } catch (IntrospectionException e) {
            throw new IllegalStateException("Cannot extract MBeanInfo for " + pRequest.getObjectNameAsString());
        }
    }

    private List<String> splitOperation(String pOperation) {
        List<String> ret = new ArrayList<String>();
        Pattern p = Pattern.compile("^(.*)\\((.*)\\)$");
        Matcher m = p.matcher(pOperation);
        if (m.matches()) {
            ret.add(m.group(1));
            String[] args = m.group(2).split("\\s*,\\s*");
            ret.addAll(Arrays.asList(args));
        } else {
            ret.add(pOperation);
        }
        return ret;
    }

    private String getErrorMessageForMissingSignature(JmxRequest pRequest, String pOperation, List<MBeanParameterInfo[]> pParamInfos) {
        StringBuffer msg = new StringBuffer("Operation ");
        msg.append(pOperation).
                append(" on MBEan ").
                append(pRequest.getObjectNameAsString()).
                append(" is overloaded. Signatures found: ");
        msg.append(signatureToString(pParamInfos));
        msg.append(". Use a signature when specifying the operation.");
        return msg.toString();
    }

    private String signatureToString(List<MBeanParameterInfo[]> pParamInfos) {
        StringBuffer ret = new StringBuffer();
        for (MBeanParameterInfo[] ii : pParamInfos) {
            ret.append("(");
            for (MBeanParameterInfo i : ii) {
                ret.append(i.getType()).append(",");
            }
            ret.setLength(ret.length()-1);
            ret.append("),");
        }
        ret.setLength(ret.length()-1);
        return ret.toString();
    }

    // ==================================================================================
    // Used for parsing
    private static class OperationAndParamType {
        private OperationAndParamType(String pOperationName, String[] pParamClazzes) {
            operationName = pOperationName;
            paramClasses = pParamClazzes;
        }

        String operationName;
        String paramClasses[];
    }

}
