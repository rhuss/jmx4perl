package org.jmx4perl.client.request;

import java.util.Arrays;
import java.util.List;

import javax.management.ObjectName;

import org.jmx4perl.client.response.J4pResponse;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;

/**
 * A read request to get one or more attributes from
 * one or more MBeans within a single request.
 *
 * @author roland
 * @since Apr 24, 2010
 */
public class J4pReadRequest extends J4pMBeanRequest {

    // Name of attribute to request
    private String[] attributes;

    /**
     * Create a READ request to request one or more attributes
     * from the remote j4p agent
     *
     * @param pObjectName Name of the MBean to request, which can be a pattern in
     *                    which case the given attributes are looked at all MBeans matched
     *                    by this pattern. If an attribute doesnt fit to a matched MBean it is
     *                    ignored.
     * @param pAttribute one or more attributes to request.
     */
    protected J4pReadRequest(ObjectName pObjectName,String ... pAttribute) {
        super(J4pType.READ, pObjectName);
        attributes = pAttribute;
    }

    /**
     * Get all attributes of this request
     *
     * @return attributes
     */
    public String[] getAttributes() {
        return attributes;
    }

    /**
     * If this request is for a single attribute, this attribute is returned
     * by this getter.
     * @return single attribute
     * @throws IllegalArgumentException if no or more than one attribute are used when this request was
     *         constructed.
     */
    public String getAttribute() {
        if (attributes == null || !hasSingleAttribute()) {
            throw new IllegalArgumentException("More than one attribute given for this request");
        }
        return attributes[0];
    }

    @Override
    List<String> getRequestParts() {
        if (hasSingleAttribute()) {
            List<String> ret = super.getRequestParts();
            ret.add(attributes[0]);
            return ret;
        } else {
            return null;
        }
    }

    @Override
    JSONObject toJson() {
        JSONObject ret = super.toJson();
        if (hasSingleAttribute()) {
            ret.put("attribute",attributes[0]);
        } else {
            JSONArray attrs = new JSONArray();
            attrs.addAll(Arrays.asList(attributes));
            ret.put("attribute",attrs);
        }
        return ret;
    }

    @Override
    <T extends J4pRequest> J4pResponse<T> createResponse(JSONObject pResponse) {
        return null;
    }

    private boolean hasSingleAttribute() {
        return attributes != null && attributes.length == 1;
    }


}
