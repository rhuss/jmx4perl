package org.jmx4perl.client.request;

import java.util.*;

import javax.management.MalformedObjectNameException;
import javax.management.ObjectName;

import org.jmx4perl.client.response.J4pExecResponse;
import org.jmx4perl.client.response.J4pResponse;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;

/**
 * A execute request for executing a JMX operation
 *
 * @author roland
 * @since May 18, 2010
 */
public class J4pExecRequest extends J4pMBeanRequest {

    // Operation to execute
    private String operation;

    // Operation arguments
    private List<Object> arguments;

    public J4pExecRequest(ObjectName pMBeanName,String pOperation,Object ... pArgs) {
        super(J4pType.EXEC, pMBeanName);
        operation = pOperation;
        arguments = Arrays.asList(pArgs);
    }

    protected J4pExecRequest(String pMBeanName, String pOperation,Object ... pArgs)
            throws MalformedObjectNameException {
        this(new ObjectName(pMBeanName),pOperation,pArgs);
    }

    public String getOperation() {
        return operation;
    }

    public List<Object> getArguments() {
        return arguments;
    }

    @Override
    J4pExecResponse createResponse(JSONObject pResponse) {
        return new J4pExecResponse(this,pResponse);
    }

    @Override
    List<String> getRequestParts() {
        List<String> ret = super.getRequestParts();
        ret.add(operation);
        if (arguments.size() > 0) {
            StringBuilder argBuf = new StringBuilder();
            for (int i = 0; i < arguments.size(); i++) {
                Object arg = arguments.get(i);
                if (arg instanceof Collection) {
                    Collection innerArgs = (Collection) arg;
                    StringBuilder inner = new StringBuilder();
                    Iterator it = innerArgs.iterator();
                    while (it.hasNext()) {
                        inner.append(it.next().toString());
                        if (it.hasNext()) {
                            inner.append(",");
                        }
                    }
                    ret.add(nullEscape(inner.toString()));
                } else {
                    ret.add(nullEscape(arg));
                }
            }
        }
        return ret;
    }

    private String nullEscape(Object pArg) {
        if (pArg == null) {
            return "[null]";
        } else if (pArg instanceof String && ((String) pArg).length() == 0) {
            return "\"\"";
        } else {
            return pArg.toString();
        }
    }

    @Override
    JSONObject toJson() {
        JSONObject ret = super.toJson();
        ret.put("operation",operation);
        if (arguments.size() > 0) {
            JSONArray args = new JSONArray();
            for (Object arg : arguments) {
                if (arg instanceof Collection) {
                    JSONArray innerArray = new JSONArray();
                    for (Object inner : (Collection) arg) {
                        innerArray.add(arg.toString());
                    }
                    args.add(innerArray);
                }
                // TODO: Check for arrays;
                else {
                    args.add(arg.toString());
                }
            }
            ret.put("arguments",args);
        }
        return ret;
    }
}
