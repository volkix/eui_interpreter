-- =============================================================================
-- Euphorix Tutorial - Kapitel 8: Netzwerk, URLs, HTTP-Client/Server & Sockets
-- Behandelte Module: std/http.e, std/socket.e, std/net/url.e, std/net/dns.e
-- Ausführen mit: ./euphorix tutorial/08_netzwerk_und_web.ex
-- =============================================================================

include std/http.e as http
include std/socket.e as sock
include std/net/url.e as url
include std/net/dns.e as dns

puts(1, "=====================================================================\n")
puts(1, "  KAPITEL 8: Netzwerk, URL-Verarbeitung, HTTP & Sockets\n")
puts(1, "=====================================================================\n\n")

-- -----------------------------------------------------------------------------
-- 1. std/net/url.e - URLs analysieren & Percent-Encoding
-- Zerlegen in Protokoll, Host, Port, Pfad und Parameter.
-- -----------------------------------------------------------------------------
puts(1, "--- 1. std/net/url.e ---\n")
sequence api_url = "https://api.beispiel.de:8443/v1/produkte?kategorie=hardware&limit=20"
sequence teile = url:parse(api_url)

printf(1, "Host:           %s\n", {teile[url:URL_HOSTNAME]})
printf(1, "Port:           %d\n", {teile[url:URL_PORT]})
printf(1, "Pfad:           %s\n", {teile[url:URL_PATH]})
printf(1, "Query-String:   %s\n", {teile[url:URL_QUERY_STRING]})

sequence enc = url:encode("Suchbegriff mit Leerzeichen & Sonderzeichen")
printf(1, "URL Encoded:    %s\n", {enc})
printf(1, "URL Decoded:    %s\n\n", {url:decode(enc)})


-- -----------------------------------------------------------------------------
-- 2. std/http.e - HTTP/REST Client & Integrierter Microservice-Server
-- Synchrone GET/POST Aufrufe und Server-Routing.
-- -----------------------------------------------------------------------------
puts(1, "--- 2. std/http.e ---\n")
puts(1, "HTTP-Client API bereit für synchrone REST-Calls:\n")
puts(1, "  - http:get(\"https://api.server.de/daten\")\n")
puts(1, "  - http:post_json(\"https://api.server.de/post\", \"{\\\"status\\\": 1}\")\n")

-- Demonstrativer HTTP Microservice Server
integer srv = http:server_create("127.0.0.1", 9099)
printf(1, "HTTP Microservice Server-Instanz erstellt auf Port 9099: ID %d\n", {srv})
http:server_close(srv)
puts(1, "Server-Instanz nach Demo sauber geschlossen.\n\n")


-- -----------------------------------------------------------------------------
-- 3. std/socket.e - Low-Level BSD/TCP Sockets
-- Verbindungen auf Transportebene für eigene Netzwerkprotokolle.
-- -----------------------------------------------------------------------------
puts(1, "--- 3. std/socket.e ---\n")
object s = sock:create(sock:AF_INET, sock:SOCK_STREAM, 0)
integer ist_gueltig = sequence(s)
printf(1, "TCP Streaming-Socket erstellt: %d (1 = Gültig)\n", {ist_gueltig})
sock:close(s)
puts(1, "Socket geschlossen.\n\n")


-- -----------------------------------------------------------------------------
-- 4. std/net/dns.e - Domain Name System Lookups
-- Auflösung von Hostnamen zu IP-Adressen (IPv4/IPv6).
-- -----------------------------------------------------------------------------
puts(1, "--- 4. std/net/dns.e ---\n")
object host_info = dns:host_by_name("localhost")
if sequence(host_info) then
    printf(1, "Offizieller Hostname: %s\n", {host_info[dns:HOST_OFFICIAL_NAME]})
end if
