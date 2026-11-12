--****
-- == Modern HTTP & HTTPS Client + Server API (std/http.e)
--
-- * **HTTP/HTTPS Client**: Powered natively by `libcurl.so.4` (TLS 1.2/1.3, HTTP/2,
--   automatic redirects, gzip/deflate/br decompression, custom headers, JSON helpers).
-- * **HTTP/HTTPS Server**: Powered by POSIX `poll()` + `libssl.so.3` with declarative
--   routing (`http:route`) and response helpers (`http:response_json`, `http:response_html`).
--

namespace http

-- Machine function IDs in the VM
constant
    M_HTTP_REQUEST       = 200,
    M_HTTP_SERVER_NEW    = 201,
    M_HTTP_SERVER_ACCEPT = 202,
    M_HTTP_SERVER_REPLY  = 203,
    M_HTTP_SERVER_CLOSE  = 204,
    M_HTTP_FORK          = 205,
    M_HTTP_KILL_WAIT     = 206

-- Response tuple indices returned by `get()`, `post()`, `request()`, etc.
public constant
    STATUS  = 1,
    BODY    = 2,
    HEADERS = 3

-- Request tuple indices passed to server route handlers or returned by `accept_request()`
public constant
    REQ_CONN_ID   = 1,
    REQ_METHOD    = 2,
    REQ_PATH      = 3,
    REQ_QUERY     = 4,
    REQ_BODY      = 5,
    REQ_HEADERS   = 6,
    REQ_CLIENT_IP = 7

-- Internal route table: `{ {srv_id, method, path, handler_rid}, ... }`
sequence server_routes = {}

function to_lower_ascii(sequence s)
    sequence res = s
    for i = 1 to length(res) do
        integer c = res[i]
        if c >= 'A' and c <= 'Z' then
            res[i] = c + 32
        end if
    end for
    return res
end function

-- =============================================================================
-- 1. HTTP / HTTPS Client API (backed by libcurl.so.4)
-- =============================================================================

--**
-- Execute a general HTTP/HTTPS request via `libcurl`.
-- Returns `{status_code, body_string, headers_list}`.
public function request(sequence method, sequence url, sequence body = "",
                        sequence headers = {}, integer timeout_ms = 10000,
                        integer verify_ssl = 1)
    return machine_func(M_HTTP_REQUEST, {method, url, body, headers, timeout_ms, verify_ssl})
end function

--**
-- Perform an HTTP/HTTPS GET request.
public function get(sequence url, sequence headers = {}, integer verify_ssl = 1)
    return request("GET", url, "", headers, 10000, verify_ssl)
end function

--**
-- Perform an HTTP/HTTPS POST request.
public function post(sequence url, sequence body, sequence headers = {}, integer verify_ssl = 1)
    return request("POST", url, body, headers, 10000, verify_ssl)
end function

--**
-- Perform an HTTP/HTTPS POST request with `Content-Type: application/json`.
public function post_json(sequence url, sequence json_body, sequence headers = {}, integer verify_ssl = 1)
    sequence h = append(headers, {"Content-Type", "application/json; charset=utf-8"})
    h = append(h, {"Accept", "application/json"})
    return request("POST", url, json_body, h, 10000, verify_ssl)
end function

--**
-- Perform an HTTP/HTTPS PUT request.
public function put(sequence url, sequence body, sequence headers = {}, integer verify_ssl = 1)
    return request("PUT", url, body, headers, 10000, verify_ssl)
end function

--**
-- Perform an HTTP/HTTPS DELETE request.
public function delete_req(sequence url, sequence headers = {}, integer verify_ssl = 1)
    return request("DELETE", url, "", headers, 10000, verify_ssl)
end function

--**
-- Case-insensitive lookup of a header value in a `{ {key, val}, ... }` header sequence.
public function header_get(sequence headers, sequence name, sequence default_val = "")
    sequence target = to_lower_ascii(name)
    for i = 1 to length(headers) do
        sequence kv = headers[i]
        if length(kv) >= 2 then
            if equal(to_lower_ascii(kv[1]), target) then
                return kv[2]
            end if
        end if
    end for
    return default_val
end function

-- =============================================================================
-- 2. HTTP / HTTPS Server API (backed by poll() + libssl.so.3)
-- =============================================================================

--**
-- Create a plain HTTP server listening on `host:port`.
-- Returns `server_id` (> 0) on success, or `< 0` on error.
public function server_create(sequence host = "127.0.0.1", integer port = 8080)
    return machine_func(M_HTTP_SERVER_NEW, {host, port, "", ""})
end function

--**
-- Create an HTTPS (TLS) server listening on `host:port` using a PEM certificate and private key.
-- Returns `server_id` (> 0) on success, or `< 0` on error.
public function server_create_tls(sequence host, integer port, sequence cert_pem, sequence key_pem)
    return machine_func(M_HTTP_SERVER_NEW, {host, port, cert_pem, key_pem})
end function

--**
-- Register a route handler function `function handler(sequence req)` for `(srv_id, method, path)`.
-- Setting `method = "*"` matches any HTTP method.
public procedure route(integer srv_id, sequence method, sequence path, integer handler_rid)
    server_routes = append(server_routes, {srv_id, method, path, handler_rid})
end procedure

--**
-- Construct a server response tuple `{status, body, content_type, extra_headers}`.
public function response(integer status, sequence body,
                         sequence content_type = "text/plain; charset=utf-8",
                         sequence extra_headers = {})
    return {status, body, content_type, extra_headers}
end function

--**
-- Construct a JSON server response (`application/json; charset=utf-8`).
public function response_json(integer status, sequence json_body, sequence extra_headers = {})
    return {status, json_body, "application/json; charset=utf-8", extra_headers}
end function

--**
-- Construct an HTML server response (`text/html; charset=utf-8`).
public function response_html(integer status, sequence html_body, sequence extra_headers = {})
    return {status, html_body, "text/html; charset=utf-8", extra_headers}
end function

--**
-- Wait up to `timeout_ms` for an incoming HTTP/HTTPS request on `srv_id`.
-- Returns `0` on timeout, `< 0` on error, or `{conn_id, method, path, query, body, headers, client_ip}`.
public function accept_request(integer srv_id, integer timeout_ms = 5000)
    return machine_func(M_HTTP_SERVER_ACCEPT, {srv_id, timeout_ms})
end function

--**
-- Send a response tuple `{status, body, content_type, extra_headers}` to `conn_id` and close the connection.
public function reply(integer conn_id, sequence resp)
    integer status = resp[1]
    sequence body  = resp[2]
    sequence ctype = "text/plain; charset=utf-8"
    sequence extra = {}
    if length(resp) >= 3 then
        ctype = resp[3]
    end if
    if length(resp) >= 4 then
        extra = resp[4]
    end if
    return machine_func(M_HTTP_SERVER_REPLY, {conn_id, status, body, ctype, extra})
end function

--**
-- Accept and dispatch a single HTTP/HTTPS request using registered routes (`http:route`).
-- Returns `1` if a request was processed, `0` on timeout, or `< 0` on error.
public function handle_one(integer srv_id, integer timeout_ms = 5000)
    object req = accept_request(srv_id, timeout_ms)
    if atom(req) then
        return req
    end if

    integer conn_id = req[REQ_CONN_ID]
    sequence method = req[REQ_METHOD]
    sequence path   = req[REQ_PATH]

    integer matched_rid = -1
    for i = 1 to length(server_routes) do
        sequence r = server_routes[i]
        if r[1] = srv_id then
            if (equal(r[2], "*") or equal(r[2], method)) and equal(r[3], path) then
                matched_rid = r[4]
                exit
            end if
        end if
    end for

    sequence resp
    if matched_rid >= 0 then
        resp = call_func(matched_rid, {req})
    else
        resp = response_json(404, "{\"error\":\"Not Found\",\"path\":\"" & path & "\"}")
    end if

    reply(conn_id, resp)
    return 1
end function

--**
-- Blocking server loop that continuously accepts and dispatches requests on `srv_id`.
public procedure serve_forever(integer srv_id)
    while 1 do
        integer r = handle_one(srv_id, 5000)
        if r < 0 then
            exit
        end if
    end while
end procedure

--**
-- Start the HTTP/HTTPS server `srv_id` in a non-blocking background worker process.
-- If `max_requests > 0`, the worker exits automatically after serving `max_requests`.
-- Returns the worker PID (`> 0`) to the caller.
public function server_background(integer srv_id, integer max_requests = 0)
    integer pid = machine_func(M_HTTP_FORK, 0)
    if pid = 0 then
        integer count = 0
        while max_requests <= 0 or count < max_requests do
            integer r = handle_one(srv_id, 5000)
            if r < 0 then
                exit
            elsif r = 1 then
                count += 1
            end if
        end while
        machine_func(M_HTTP_SERVER_CLOSE, srv_id)
        abort(0)
    end if
    return pid
end function

--**
-- Close an HTTP/HTTPS server socket and free its TLS context (if any).
-- If `bg_pid > 0`, also terminates and reaps the background server worker process.
public function server_close(integer srv_id, integer bg_pid = 0)
    if bg_pid > 0 then
        machine_func(M_HTTP_KILL_WAIT, {bg_pid, 15})
    end if
    return machine_func(M_HTTP_SERVER_CLOSE, srv_id)
end function

