-- =============================================================================
-- Beispiel 06: PostgreSQL Datenbank-Anbindung (std/pgsql.e) & JSON-Export
-- Aufruf: ./eui examples/06_postgresql_datenbank.ex
--
-- Demonstriert:
--   1. Verbindungsaufbau per URI ("postgresql://user:pass@host:port/dbname")
--      oder Key-Value-String ("host=... port=... dbname=... user=... password=...")
--   2. Parametrisierte Befehle (sowohl PostgreSQL $1, $2 als auch ? Platzhalter)
--   3. Transaktionen (pgsql:begin, pgsql:commit, pgsql:rollback)
--   4. Automatische Typkonvertierung (INT4/INT8 -> integer, FLOAT8/NUMERIC -> atom,
--      BOOL -> 1/0, TEXT/VARCHAR -> UTF-8 sequence, NULL -> pgsql:SQL_NULL)
--   5. Direkter JSON-Export mit pgsql:query_assoc() + json:stringify()
--
-- Für den automatischen Selbsttest startet dieses Skript im Hintergrund einen
-- lokalen PostgreSQL-v3-Wire-Protocol-Testserver auf Port 15432, sodass das
-- Beispiel auf jeder Maschine ohne laufenden Postgres-Daemon ausführbar ist.
-- =============================================================================
include std/pgsql.e
include std/json.e
include std/socket.e as sock
include std/os.e
include std/text.e

procedure assert_eq(sequence name, object actual, object expected)
    if not equal(actual, expected) then
        printf(2, "FEHLER in %s!\n  Erwartet: %s\n  Erhalten: %s\n", {name, sprint(expected), sprint(actual)})
        abort(1)
    end if
end procedure

-- Hilfsfunktionen für den lokalen PostgreSQL-v3-Testserver
function be32(integer v)
    return {
        and_bits(floor(v / #1000000), #FF),
        and_bits(floor(v / #10000), #FF),
        and_bits(floor(v / #100), #FF),
        and_bits(v, #FF)
    }
end function

function be16(integer v)
    return {
        and_bits(floor(v / #100), #FF),
        and_bits(v, #FF)
    }
end function

function pg_msg(integer msg_type, sequence payload)
    return {msg_type} & be32(length(payload) + 4) & payload
end function

function pg_col_desc(sequence name, integer type_oid)
    -- name\0 + table_oid(4) + attr_num(2) + type_oid(4) + type_len(2) + type_mod(4) + fmt(2)
    return name & {0} & be32(0) & be16(1) & be32(type_oid) & be16(4) & be32(-1) & be16(0)
end function

function pg_data_row(sequence fields)
    sequence body = be16(length(fields))
    for i = 1 to length(fields) do
        object f = fields[i]
        if atom(f) and f = -1 then
            -- SQL NULL (-1 als signed int32 = #FFFFFFFF)
            body &= {#FF, #FF, #FF, #FF}
        else
            body &= be32(length(f)) & f
        end if
    end for
    return pg_msg('D', body)
end function

-- Startet einen minimalen PostgreSQL v3 Wire-Protokoll-Server für den Selbsttest
procedure run_mock_pg_server(object srv_sock)
    object acc = sock:accept(srv_sock)
    if atom(acc) then abort(0) end if
    object client = acc[1]

    -- 1. StartupMessage lesen & AuthenticationCleartextPassword ('R', 3) senden
    object startup = sock:receive(client, 0)
    sock:send(client, pg_msg('R', be32(3)), 0)

    -- 2. Passwort-Paket ('p') lesen & AuthOk ('R', 0) + ReadyForQuery ('Z', 'I') senden
    object pw_pkt = sock:receive(client, 0)
    sock:send(client, pg_msg('R', be32(0)) & pg_msg('Z', "I"), 0)

    -- 3. SQL-Befehle in einer Schleife beantworten
    while 1 do
        object pkt = sock:receive(client, 0)
        if atom(pkt) or length(pkt) = 0 then exit end if
        if pkt[1] = 'X' then exit end if -- Terminate

        -- Extrahiere SQL-Text aus 'Q'-Paket (ab Byte 6 bis vor '\0')
        sequence sql = ""
        if length(pkt) > 6 then
            sql = pkt[6..$-1]
        end if

        if match("SELECT", sql) = 1 then
            -- Sende RowDescription ('T') mit PostgreSQL OIDs:
            -- id (INT4=23), name (TEXT=25), preis (FLOAT8=701), aktiv (BOOL=16), notiz (TEXT=25)
            sequence row_desc = be16(5)
                & pg_col_desc("id",    23)
                & pg_col_desc("name",  25)
                & pg_col_desc("preis", 701)
                & pg_col_desc("aktiv", 16)
                & pg_col_desc("notiz", 25)
            sequence r1 = pg_data_row({"1", "Server-Rack München", "1499.5", "t", -1})
            sequence r2 = pg_data_row({"2", "USV-Modul Größe L",   "450.0",  "f", "Geprüft"})
            sequence cmd = pg_msg('C', "SELECT 2" & {0})
            sequence rdy = pg_msg('Z', "I")
            sock:send(client, pg_msg('T', row_desc) & r1 & r2 & cmd & rdy, 0)
        elsif match("INSERT", sql) = 1 then
            sock:send(client, pg_msg('C', "INSERT 0 2" & {0}) & pg_msg('Z', "I"), 0)
        else
            sock:send(client, pg_msg('C', "OK" & {0}) & pg_msg('Z', "I"), 0)
        end if
    end while
    sock:close(client)
    sock:close(srv_sock)
    abort(0)
end procedure

puts(1, "=== Beispiel 06: PostgreSQL Datenbank (std/pgsql.e) & JSON-Export ===\n")

integer port = 15432
object srv_sock = sock:create(sock:AF_INET, sock:SOCK_STREAM, 0)
sock:bind(srv_sock, "127.0.0.1", port)
sock:listen(srv_sock, 16)
integer pid = machine_func(205, 0) -- Hintergrundprozess für Mock-PG-Server
if pid = 0 then
    run_mock_pg_server(srv_sock)
end if
sleep(0.05)

-- 1. Verbindung über PostgreSQL-URI öffnen
integer db = pgsql:open(sprintf("postgresql://postgres:geheim@127.0.0.1:%d/technik_db", {port}))
assert_eq("pgsql:open erfolgreich", db > 0, 1)

-- 2. DDL & Transaktion mit parametrisiertem INSERT ($1/$2 und ? werden unterstützt)
assert_eq("pgsql:begin", pgsql:begin(db), 1)
assert_eq("CREATE TABLE", pgsql:exec(db, "CREATE TABLE hardware (id SERIAL PRIMARY KEY, name TEXT, preis NUMERIC, aktiv BOOLEAN, notiz TEXT);"), 1)

-- Sowohl PostgreSQL-typische $1, $2, $3 als auch ?-Platzhalter funktionieren nahtlos:
assert_eq("INSERT mit $1..$3", pgsql:exec(db,
    "INSERT INTO hardware (name, preis, aktiv) VALUES ($1, $2, $3);",
    {"Server-Rack München", 1499.50, 1}
), 1)
assert_eq("pgsql:changes nach INSERT", pgsql:changes(db), 2)
assert_eq("pgsql:commit", pgsql:commit(db), 1)

-- 3. Abfrage mit automatischer PostgreSQL-OID-Typkonvertierung
sequence rows = pgsql:query(db, "SELECT id, name, preis, aktiv, notiz FROM hardware WHERE preis > ?;", {100})
assert_eq("Anzahl Zeilen", length(rows), 2)
assert_eq("Zeile 1 ID (integer)",    rows[1][1], 1)
assert_eq("Zeile 1 Name (UTF-8)",    rows[1][2], "Server-Rack München")
assert_eq("Zeile 1 Preis (atom)",    rows[1][3], 1499.5)
assert_eq("Zeile 1 Aktiv (BOOL->1)", rows[1][4], 1)
assert_eq("Zeile 1 Notiz (NULL)",    pgsql:is_null(rows[1][5]), 1)

-- 4. Direkter Export als JSON-Array über pgsql:query_assoc()
sequence assoc_rows = pgsql:query_assoc(db, "SELECT id, name, preis, aktiv, notiz FROM hardware;")
sequence json_export = json:stringify(json:array(assoc_rows))
printf(1, "  JSON-Export : %s\n", {json_export})

object parsed = json:decode(json_export)
assert_eq("JSON Zeile 1 Name",  json:get(parsed, {1, "name"}), "Server-Rack München")
assert_eq("JSON Zeile 2 Notiz", json:get(parsed, {2, "notiz"}), "Geprüft")

-- 5. SQL-Literal- und Identifier-Escaping testen
assert_eq("escape_literal",    pgsql:escape_literal(db, "O'Reilly"), "'O''Reilly'")
assert_eq("escape_identifier", pgsql:escape_identifier(db, "kunden_tabelle"), `"kunden_tabelle"`)

assert_eq("pgsql:close", pgsql:close(db), 1)
sock:close(srv_sock)
machine_func(206, {pid, 0})

puts(1, "  [OK] Alle PostgreSQL-Verbindungs-, Parameter-, Typ- und JSON-Tests erfolgreich!\n")
