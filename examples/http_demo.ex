include std/http.e
include std/text.e

procedure assert_eq(sequence name, object actual, object expected)
    if not equal(actual, expected) then
        printf(2, "FEHLER in %s!\n  Erwartet: %s\n  Erhalten: %s\n", {name, sprint(expected), sprint(actual)})
        abort(1)
    end if
end procedure

-- =============================================================================
-- Route-Handler für HTTP & HTTPS Server
-- =============================================================================

function handle_hello(sequence req)
    sequence query = req[http:REQ_QUERY]
    sequence ua    = http:header_get(req[http:REQ_HEADERS], "User-Agent")
    return http:response_json(
        200,
        sprintf("{\"status\":\"ok\",\"query\":\"%s\",\"agent\":\"%s\"}", {query, ua}),
        {{"X-Server-Engine", "Euphoria-ModernHTTP"}}
    )
end function

function handle_echo_json(sequence req)
    sequence body  = req[http:REQ_BODY]
    sequence ctype = http:header_get(req[http:REQ_HEADERS], "Content-Type")
    return http:response_json(
        201,
        sprintf("{\"received\":%s,\"content_type\":\"%s\"}", {body, ctype})
    )
end function

function handle_tls_secret(sequence req)
    sequence token = http:header_get(req[http:REQ_HEADERS], "X-Auth-Token", "none")
    return http:response_json(
        200,
        sprintf("{\"tls\":true,\"method\":\"%s\",\"token\":\"%s\"}", {req[http:REQ_METHOD], token})
    )
end function

puts(1, "=== Modern HTTP & HTTPS Client (libcurl) + Server (libssl) Test ===\n")

-- =============================================================================
-- 1. HTTP Server + libcurl HTTP Client Test
-- =============================================================================
integer http_port = 18088
integer srv = http:server_create("127.0.0.1", http_port)
if srv <= 0 then
    puts(2, "HTTP-Server konnte nicht gestartet werden!\n")
    abort(1)
end if

http:route(srv, "GET",  "/hello",    routine_id("handle_hello"))
http:route(srv, "POST", "/api/echo", routine_id("handle_echo_json"))

integer bg_http = http:server_background(srv, 3)

-- 1a. GET Request mit Query-String via libcurl
sequence r1 = http:get(sprintf("http://127.0.0.1:%d/hello?lang=euphoria", {http_port}))
assert_eq("HTTP GET Status", r1[http:STATUS], 200)
assert_eq("HTTP GET Body",   r1[http:BODY], "{\"status\":\"ok\",\"query\":\"lang=euphoria\",\"agent\":\"Euphoria-libcurl/4.1\"}")
assert_eq("HTTP GET Custom Header", http:header_get(r1[http:HEADERS], "x-server-engine"), "Euphoria-ModernHTTP")
puts(1, "  [OK] HTTP GET /hello?lang=euphoria (libcurl -> Euphoria HTTP Server)\n")

-- 1b. POST JSON Request via libcurl
sequence r2 = http:post_json(sprintf("http://127.0.0.1:%d/api/echo", {http_port}), "{\"id\":42}")
assert_eq("HTTP POST JSON Status", r2[http:STATUS], 201)
assert_eq("HTTP POST JSON Body",   r2[http:BODY], "{\"received\":{\"id\":42},\"content_type\":\"application/json; charset=utf-8\"}")
puts(1, "  [OK] HTTP POST /api/echo (JSON via libcurl -> Euphoria HTTP Server)\n")

-- 1c. Automatischer 404 Not Found Handler
sequence r3 = http:get(sprintf("http://127.0.0.1:%d/unbekannt", {http_port}))
assert_eq("HTTP 404 Status", r3[http:STATUS], 404)
assert_eq("HTTP 404 Body",   r3[http:BODY], "{\"error\":\"Not Found\",\"path\":\"/unbekannt\"}")
puts(1, "  [OK] HTTP 404 Routing (/unbekannt)\n")

http:server_close(srv, bg_http)

-- =============================================================================
-- 2. HTTPS (TLS) Server + libcurl HTTPS Client Test
-- =============================================================================
sequence cert_file = "/tmp/eu_test_cert.pem"
sequence key_file  = "/tmp/eu_test_key.pem"
integer gen_rc = system_exec(
    "openssl req -x509 -newkey rsa:2048 -nodes -keyout " & key_file &
    " -out " & cert_file & " -days 1 -subj '/CN=127.0.0.1' >/dev/null 2>&1",
    2
)
assert_eq("OpenSSL Test-Zertifikat generieren", gen_rc, 0)

integer https_port = 18443
integer tls_srv = http:server_create_tls("127.0.0.1", https_port, cert_file, key_file)
if tls_srv <= 0 then
    printf(2, "HTTPS-Server konnte nicht gestartet werden (Code %d)!\n", {tls_srv})
    abort(1)
end if

http:route(tls_srv, "GET", "/secure", routine_id("handle_tls_secret"))
integer bg_https = http:server_background(tls_srv, 1)

-- HTTPS GET mit Custom-Header via libcurl (verify_ssl = 0 für selbstsigniertes Test-Zertifikat)
sequence r_tls = http:get(
    sprintf("https://127.0.0.1:%d/secure", {https_port}),
    {{"X-Auth-Token", "Bearer-Secret-99"}},
    0
)
assert_eq("HTTPS GET Status", r_tls[http:STATUS], 200)
assert_eq("HTTPS GET Body",   r_tls[http:BODY], "{\"tls\":true,\"method\":\"GET\",\"token\":\"Bearer-Secret-99\"}")
puts(1, "  [OK] HTTPS (TLS) GET https://127.0.0.1:18443/secure (libcurl TLS -> libssl.so.3 Server)\n")

http:server_close(tls_srv, bg_https)
system_exec("rm -f " & cert_file & " " & key_file, 2)

puts(1, "=== Alle HTTP & HTTPS (libcurl + libssl) Tests erfolgreich bestanden! ===\n")
