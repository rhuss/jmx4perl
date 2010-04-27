package org.jmx4perl.client.request;

import java.io.IOException;
import java.io.InputStreamReader;
import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.nio.charset.Charset;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.apache.http.Header;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.client.methods.HttpUriRequest;
import org.apache.http.entity.StringEntity;
import org.jmx4perl.client.response.J4pResponse;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;

/**
 * Class doing the hard work of conversion between HTTP request/responses and
 * J4p request/responses.
 *
 * @author roland
 * @since Apr 25, 2010
 */
public class J4pRequestManager {

    // j4p agent URL for the agent server
    protected String j4pServerUrl;

    // Escape patterns
    private Pattern slashPattern = Pattern.compile("/+");
    private Pattern escapedSlashPattern = Pattern.compile("%2F");


    public J4pRequestManager(String pJ4pServerUrl) {
        j4pServerUrl = pJ4pServerUrl;
    }

    /**
     * Get the HttpRequest for executing the given request
     *
     * @param pRequest request to convert
     * @param pPreferredMethod HTTP method preferred
     * @return the request used with HttpClient to obtain the result.
     */
    protected HttpUriRequest getHttpRequest(J4pRequest pRequest,String pPreferredMethod) {
        String method = pPreferredMethod;
        if (method == null) {
            method = pRequest.getPreferredHttpMethod();
        }
        if (method == null) {
            method = HttpGet.METHOD_NAME;
        }
        if (method.equals(HttpGet.METHOD_NAME)) {
            List<String> parts = pRequest.getRequestParts();
            // If parts == null the request decides, that POST *must* be used
            if (parts != null) {
                StringBuilder requestPath = new StringBuilder();
                requestPath.append(pRequest.getType().getValue());
                for (String p : parts) {
                    requestPath.append("/");
                    requestPath.append(escape(p));
                }
                // TODO: Option handling, special escaping
                return new HttpGet(j4pServerUrl + "/" + requestPath.toString());
            }
        }
        try {
            // We are using a post method as fallback
            // TODO: Option handling
            JSONObject requestContent = pRequest.toJson();
            HttpPost postReq = new HttpPost(j4pServerUrl);
            postReq.setEntity(new StringEntity(requestContent.toJSONString(),"utf-8"));
            return postReq;
        } catch (UnsupportedEncodingException e) {
            // UTF-8 should be supported for sure
            throw new IllegalStateException("Unsupported encoding utf-8: " + e,e);
        }
    }


    // Escape a part for usage as part of URI path
    private String escape(String pPart) {
        Matcher matcher = slashPattern.matcher(pPart);
        int index = 0;
        StringBuilder ret = new StringBuilder();
        while (matcher.find()) {
            String part = pPart.subSequence(index, matcher.start()).toString();
            ret.append(part);
            String separator = pPart.substring(matcher.start(),matcher.end());
            ret.append("/");
            int len = separator.length();
            for (int i = 0;i<len;i++) {
                if (i == 0 && matcher.start() == 0) {
                    ret.append("^");
                } else if (i == len - 1 && matcher.end() == pPart.length()) {
                    ret.append("+");
                } else {
                    ret.append("-");
                }
            }
            ret.append("/");
            index = matcher.end();
        }
        if (index != pPart.length()) {
            ret.append(pPart.substring(index,pPart.length()));
        }

        // URI Escape unsafe chars
        try {
            String encodedRet = URLEncoder.encode(ret.toString(),"utf-8");
            // Translate all "/" back...
            return escapedSlashPattern.matcher(encodedRet).replaceAll("/");
        } catch (UnsupportedEncodingException e) {
            throw new IllegalStateException("Platform doesn't support UTF-8 encoding");
        }
    }

    /**
     * Extract a response out of a resulting HttpResponse and a given request
     *
     * @param pRequest request which lead to the response
     * @param pHttpResponse HttpResponse as received from the agen
     * @param <T> request type.
     * @return the J4p response
     * @throws java.io.IOException when extracting of the answer fails
     * @throws org.json.simple.parser.ParseException when parsing of the JSON answer fails
     */
    protected <R extends J4pResponse<T>,T extends J4pRequest> R extractResponse(T pRequest, HttpResponse pHttpResponse)
            throws IOException, ParseException {
        HttpEntity entity = pHttpResponse.getEntity();
        JSONParser parser = new JSONParser();
        Header contentEncoding = entity.getContentEncoding();
        JSONObject responseJSON;
        if (contentEncoding != null) {
            responseJSON = (JSONObject) parser.parse(new InputStreamReader(entity.getContent(), Charset.forName(contentEncoding.getValue())));
        } else {
            responseJSON = (JSONObject) parser.parse(new InputStreamReader(entity.getContent()));
        }
        return pRequest.<R>createResponse(responseJSON);
    }
}
