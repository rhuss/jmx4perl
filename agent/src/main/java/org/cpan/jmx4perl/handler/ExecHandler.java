package org.cpan.jmx4perl.handler;

import org.cpan.jmx4perl.JmxRequest;
import org.cpan.jmx4perl.converter.StringToObjectConverter;

import javax.management.*;
import java.util.List;

/**
 * @author roland
 * @since Jun 12, 2009
 */
public class ExecHandler extends RequestHandler {
    private StringToObjectConverter stringToObjectConverter;

    public ExecHandler(StringToObjectConverter pStringToObjectConverter) {
        stringToObjectConverter = pStringToObjectConverter;
    }

    public JmxRequest.Type getType() {
        return JmxRequest.Type.EXEC;
    }

    public Object handleRequest(MBeanServer server, JmxRequest request)
            throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException {
        String[] paramClazzes;
        paramClazzes = extractOperationTypes(server,request);
        Object[] params = new Object[paramClazzes.length];
        List<String> args = request.getExtraArgs();
        if (args.size() != paramClazzes.length) {
            throw new IllegalArgumentException("Invalid operation parameters. Operation " +
                    request.getOperation() + " requires " + paramClazzes.length +
                    " parameters, not " + args.size() + " as given");
        }
        for (int i = 0;i <  paramClazzes.length; i++) {
            params[i] = stringToObjectConverter.convertFromString(paramClazzes[i],args.get(i));
        }
        return server.invoke(request.getObjectName(),request.getOperation(),params,paramClazzes);
    }

    private String[] extractOperationTypes(MBeanServer pServer, JmxRequest pRequest)
            throws ReflectionException, InstanceNotFoundException {
        try {
            MBeanInfo mBeanInfo = pServer.getMBeanInfo(pRequest.getObjectName());
            for (MBeanOperationInfo opInfo : mBeanInfo.getOperations()) {
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
