package org.jmx4perl.client.request;

import java.io.IOException;
import java.io.InputStreamReader;
import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.nio.charset.Charset;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.apache.http.*;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.client.methods.HttpUriRequest;
import org.apache.http.entity.StringEntity;
import org.jmx4perl.client.J4pException;
import org.jmx4perl.client.response.J4pResponse;
import org.json.simple.*;
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
    private static final Pattern SLASH_PATTERN = Pattern.compile("/+");
    private static final Pattern ESCAPED_SLASH_PATTERN = Pattern.compile("%2F");

    public J4pRequestManager(String pJ4pServerUrl) {
        j4pServerUrl = pJ4pServerUrl;
    }

    /**
     * Get the HttpRequest for executing the given single request
     *
     * @param pRequest request to convert
     * @param pPreferredMethod HTTP method preferred
     * @return the request used with HttpClient to obtain the result.
     */
    protected HttpUriRequest getHttpRequest(J4pRequest pRequest,String pPreferredMethod) throws J4pException {
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
            throw new J4pException("Unsupported encoding utf-8: " + e,e);
        }
    }

    /**
     * Get an HTTP Request for requesting multips requests at once
     *
     * @param pRequests requests to put into a HTTP request
     * @return HTTP request to send to the server
     */
    protected <T extends J4pRequest> HttpUriRequest getHttpRequest(List<T> pRequests) throws J4pException {
        JSONArray bulkRequest = new JSONArray();
        HttpPost postReq = new HttpPost(j4pServerUrl);
        for (T request : pRequests) {
            JSONObject requestContent = request.toJson();
            bulkRequest.add(requestContent);
        }
        try {
            postReq.setEntity(new StringEntity(bulkRequest.toJSONString(),"utf-8"));
            return postReq;
        } catch (UnsupportedEncodingException e) {
            // UTF-8 should be supported for sure
            throw new J4pException("Unsupported encoding utf-8: " + e,e);
        }
    }


    /**
     * Extract the complete JSON response out of a HTTP response
     *
     * @param pRequest the original J4p request
     * @param pHttpResponse the resulting http response
     * @param <T> J4p Request
     * @return JSON content of the answer
     * @throws J4pException when parsing of the answer fails
     */
    protected JSONAware extractJsonResponse(HttpResponse pHttpResponse) throws J4pException {
        try {
            HttpEntity entity = pHttpResponse.getEntity();
            JSONParser parser = new JSONParser();
            Header contentEncoding = entity.getContentEncoding();
            if (contentEncoding != null) {
                return (JSONAware) parser.parse(new InputStreamReader(entity.getContent(), Charset.forName(contentEncoding.getValue())));
            } else {
                return (JSONAware) parser.parse(new InputStreamReader(entity.getContent()));
            }
        } catch (IOException e) {
            throw new J4pException("IO-Error while reading the response: " + e,e);
        } catch (ParseException e) {
            // It's a parese exception. Now, check whether the HTTResponse is
            // an error and prepare the proper J4pExcetpipon
            StatusLine statusLine = pHttpResponse.getStatusLine();
            if (HttpStatus.SC_OK != statusLine.getStatusCode()) {
                throw new J4pException(statusLine.getStatusCode() + " " + statusLine.getReasonPhrase());
            }
            throw new J4pException("Could not parse answer: " + e,e);
        }
    }

    /**
     * Extract a {@link J4pResponse} out of a JSON object
     *
     * @param pRequest request which lead to the response
     * @param pJsonResponse JSON response
     * @param <T> request type.
     * @param <R> response type
     * @return the J4p response
     */
    protected <R extends J4pResponse<T>,T extends J4pRequest> R extractResponse(T pRequest,JSONObject pJsonResponse) {
        return pRequest.<R>createResponse(pJsonResponse);
    }

    // Escape a part for usage as part of URI path
    private String escape(String pPart) throws J4pException {
        Matcher matcher = SLASH_PATTERN.matcher(pPart);
        int index = 0;
        StringBuilder ret = new StringBuilder();
        while (matcher.find()) {
            String part = pPart.subSequence(index, matcher.start()).toString();
            ret.append(part).append("/");
            ret.append(escapeSlash(pPart, matcher));
            ret.append("/");
            index = matcher.end();
        }
        if (index != pPart.length()) {
            ret.append(pPart.substring(index,pPart.length()));
        }
        return uriEscape(ret);
    }

    private String escapeSlash(String pPart, Matcher pMatcher) {
        StringBuilder ret = new StringBuilder();
        String separator = pPart.substring(pMatcher.start(), pMatcher.end());
        int len = separator.length();
        for (int i = 0;i<len;i++) {
            if (i == 0 && pMatcher.start() == 0) {
                ret.append("^");
            } else if (i == len - 1 && pMatcher.end() == pPart.length()) {
                ret.append("+");
            } else {
                ret.append("-");
            }
        }
        return ret.toString();
    }

    private String uriEscape(StringBuilder pRet) throws J4pException {
        // URI Escape unsafe chars
        try {
            String encodedRet = URLEncoder.encode(pRet.toString(),"utf-8");
            // Translate all "/" back...
            return ESCAPED_SLASH_PATTERN.matcher(encodedRet).replaceAll("/");
        } catch (UnsupportedEncodingException e) {
            throw new J4pException("Platform doesn't support UTF-8 encoding",e);
        }
    }

}
