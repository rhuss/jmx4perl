package org.cpan.jmx4perl.converter;

/**
 * @author roland
 * @since Jun 11, 2009
 */
public class StringToObjectConverter {

    public Object convertFromString(String pType, String pValue) {
        // TODO: Look for an external solution or support more types
        // At least use a map for lookup
        if (String.class.getName().equals(pType)) {
            return pValue;
        } else if (Integer.class.getName().equals(pType) || "int".equals(pType)){
            return Integer.parseInt(pValue);
        } else if (Long.class.getName().equals(pType) || "long".equals(pType)){
            return Long.parseLong(pValue);
        } else if (Boolean.class.getName().equals(pType) || "boolean".equals(pType)){
            return Boolean.parseBoolean(pValue);
        } else {
            throw new IllegalArgumentException("Cannot convert string " + pValue + " to type " + pType);
        }
    }
}
