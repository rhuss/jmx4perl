package org.jmx4perl.jvmagent.jdk6;

import com.sun.net.httpserver.Headers;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import org.jmx4perl.*;
import org.json.simple.JSONAware;
import org.json.simple.JSONObject;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.URI;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * HttpHandler for handling a j4p request
 *
 * @author roland
 * @since Mar 3, 2010
 */
public class J4pHttpHandler implements HttpHandler,LogHandler {

    // Backendmanager for doing request
    private BackendManager backendManager;

    // The HttpRequestHandler
    private HttpRequestHandler requestHandler;

    // Context of this request
    private String context;

    // Content type matching
    private Pattern contentTypePattern = Pattern.compile(".*;\\s*charset=([^;,]+)\\s*.*");


    public J4pHttpHandler(Map<Config,String> pConfig) {        
        context = pConfig.get(Config.AGENT_CONTEXT);
        if (!context.endsWith("/")) {
            context += "/";
        }
        backendManager = new BackendManager(pConfig,this);
        requestHandler = new HttpRequestHandler(backendManager,this);
    }

    @Override
    public void handle(HttpExchange pExchange) throws IOException {
        JSONAware json = null;
        int code = 200;
        try {
            // Check access policy
            InetSocketAddress address = pExchange.getRemoteAddress();
            requestHandler.checkClientIPAccess(address.getHostName(),address.getAddress().getHostAddress());
            String method = pExchange.getRequestMethod();

            // Dispatch for the proper HTTP request method
            URI uri = pExchange.getRequestURI();
            if ("GET".equalsIgnoreCase(method)) {
                String path = uri.getPath();
                if (path.startsWith(context)) {
                    path = path.substring(context.length());
                }
                while (path.startsWith("/") && path.length() > 1) {
                    path = path.substring(1);
                }
                JmxRequest jmxReq =
                        JmxRequestFactory.createRequestFromUrl(path,null);
                if (backendManager.isDebug() && !"debugInfo".equals(jmxReq.getOperation())) {
                    debug("URI: " + uri);
                    debug("Path-Info: " + path);
                    debug("Request: " + jmxReq.toString());
                }
                json = requestHandler.executeRequest(jmxReq);
            } else if ("POST".equalsIgnoreCase(method)) {
                if (backendManager.isDebug()) {
                    debug("URI: " + uri);
                }
                String encoding = null;
                Headers headers = pExchange.getRequestHeaders();
                String cType =  headers.getFirst("Content-Type");
                if (cType != null) {
                    Matcher matcher = contentTypePattern.matcher(cType);
                    if (matcher.matches()) {
                        encoding = matcher.group(1);
                    }
                }
                InputStream is = pExchange.getRequestBody();
                json = requestHandler.handleRequestInputStream(is, encoding);
            } else {
                throw new IllegalArgumentException("HTTP Method " + method + " is not supported.");
            }
            code = requestHandler.extractResultCode(json);
            if (backendManager.isDebug()) {
                backendManager.info("Response: " + json);
            }
        } catch (Throwable exp) {
            JSONObject error = requestHandler.handleThrowable(exp);
            code = (Integer) error.get("status");
            json = error;
        } finally {
            sendResponse(pExchange,code,json.toJSONString());
        }

    }

    private void sendResponse(HttpExchange pExchange, int pCode, String s) throws IOException {
        OutputStream out = null;
        try {
            Headers headers = pExchange.getResponseHeaders();
            headers.set("Content-Type","text/plain; charset=utf-8");
            byte[] response = s.getBytes();
            pExchange.sendResponseHeaders(pCode,response.length);
            out = pExchange.getResponseBody();
            out.write(response);
        } finally {
            if (out != null) {
                // Always close in order to finish the request.
                // Otherwise the thread blocks.
                out.close();
            }
        }
    }

    @Override
    public void debug(String message) {
        System.err.println("DEBUG: " + message);
    }

    @Override
    public void info(String message) {
        System.err.println("INFO: " + message);
    }

    @Override
    public void error(String message, Throwable t) {
        System.err.println("ERROR: " + message);
    }
}
