-- ==============================================================================
-- Euphorix 1.0 Demo: Enterprise CRM Model Context Protocol (MCP) Server
-- ==============================================================================
--
-- Starten als Standard-I/O Server (für Claude Desktop, Antigravity, Cursor):
--   ./euphorix examples/12_mcp_server_demo.ex --stdio
--
-- Starten als HTTP + Server-Sent Events Server:
--   ./euphorix examples/12_mcp_server_demo.ex --http
--   Web-Info im Browser: http://127.0.0.1:8095/
-- ==============================================================================

include std/mcp.e as mcp
include std/sqlite.e as sqlite
include std/convert.e as conv
include std/io.e as io

-- 1. SQLite In-Memory Datenbank mit Demodaten initialisieren
integer db = sqlite:open(":memory:")

sqlite:exec(db, "CREATE TABLE kunden (" &
                "kdnr TEXT PRIMARY KEY, " &
                "name TEXT, " &
                "ort TEXT, " &
                "email TEXT, " &
                "umsatz REAL, " &
                "status TEXT);")

sqlite:exec(db, "CREATE TABLE auftraege (" &
                "id INTEGER PRIMARY KEY AUTOINCREMENT, " &
                "kdnr TEXT, " &
                "artnr TEXT, " &
                "bezeichnung TEXT, " &
                "menge INTEGER, " &
                "preis REAL, " &
                "status TEXT);")

-- Demodaten einfügen
sqlite:exec(db, "INSERT INTO kunden VALUES ('K-1001', 'Schulze Maschinenbau AG', 'Frankfurt', 'kontakt@schulze-ag.de', 142500.00, 'A-Kunde');")
sqlite:exec(db, "INSERT INTO kunden VALUES ('K-1002', 'Bäcker & Partner Logistik', 'Hamburg', 'dispo@baecker-logistik.com', 87400.50, 'B-Kunde');")
sqlite:exec(db, "INSERT INTO kunden VALUES ('K-1003', 'Albrecht IT Services', 'München', 'office@albrecht-it.de', 31200.00, 'C-Kunde');")
sqlite:exec(db, "INSERT INTO kunden VALUES ('K-1004', 'Nordic Clean Energy KG', 'Bremen', 'info@nordic-energy.eu', 215800.75, 'A-Kunde');")
sqlite:exec(db, "INSERT INTO kunden VALUES ('K-1005', 'Rhein-Ruhr Werkzeuge', 'Dortmund', 'vertrieb@rr-werkzeuge.de', 98300.00, 'B-Kunde');")

sqlite:exec(db, "INSERT INTO auftraege (kdnr, artnr, bezeichnung, menge, preis, status) VALUES ('K-1001', 'ART-501', 'CNC Drehfräs-Modul X1', 2, 45000.00, 'In Fertigung');")
sqlite:exec(db, "INSERT INTO auftraege (kdnr, artnr, bezeichnung, menge, preis, status) VALUES ('K-1002', 'ART-108', 'Schwerlast Container', 10, 850.00, 'Versendet');")
sqlite:exec(db, "INSERT INTO auftraege (kdnr, artnr, bezeichnung, menge, preis, status) VALUES ('K-1004', 'ART-920', 'Windkraft Generatorsteuerung', 1, 115000.00, 'Freigegeben');")

-- 2. MCP Server Instanz erstellen
integer srv = mcp:server("Euphorix-CRM-Server", "1.0.0", "Enterprise CRM & ERP MCP Server für OpenEuphoria")

-- ==============================================================================
-- 3. Tool Implementierungen
-- ==============================================================================

-- Tool 1: kunden_suchen
function tool_kunden_suchen(sequence args)
    sequence query = mcp:arg(args, "suchbegriff", "")
    sequence sql = "SELECT kdnr, name, ort, email, umsatz, status FROM kunden " &
                   "WHERE name LIKE ? OR ort LIKE ? OR kdnr LIKE ? ORDER BY kdnr ASC;"
    sequence param = "%" & query & "%"
    sequence rows = sqlite:query(db, sql, {param, param, param})

    if length(rows) = 0 then
        return mcp:tool_result("Keine Kunden gefunden für Suchbegriff: '" & query & "'")
    end if

    sequence out = sprintf("Gefundene Kunden (%d Treffer):\n", {length(rows)})
    out &= "KdNr    | Firma / Name               | Ort       | Umsatz      | Status\n"
    out &= "-------------------------------------------------------------------------\n"
    for i = 1 to length(rows) do
        sequence r = rows[i]
        out &= sprintf("%-7s | %-26s | %-9s | %9.2f € | %s\n",
                       {r[1], r[2], r[3], r[5], r[6]})
    end for
    return mcp:tool_result(out)
end function

-- Tool 2: kunde_anlegen
function tool_kunde_anlegen(sequence args)
    sequence kdnr   = mcp:arg(args, "kdnr", "")
    sequence name   = mcp:arg(args, "name", "")
    sequence ort    = mcp:arg(args, "ort", "Unbekannt")
    sequence email  = mcp:arg(args, "email", "info@kunde.de")
    atom umsatz     = mcp:arg_num(args, "umsatz", 0.0)
    sequence status = mcp:arg(args, "status", "B-Kunde")

    if length(kdnr) = 0 or length(name) = 0 then
        return mcp:tool_error("Fehler: 'kdnr' und 'name' sind Pflichtfelder.")
    end if

    sqlite:exec(db, "INSERT OR REPLACE INTO kunden (kdnr, name, ort, email, umsatz, status) VALUES (?, ?, ?, ?, ?, ?);",
                {kdnr, name, ort, email, umsatz, status})

    return mcp:tool_result(sprintf("Kunde '%s' (%s) mit %.2f € Umsatz erfolgreich im CRM angelegt.",
                                   {name, kdnr, umsatz}))
end function

-- Tool 3: auftrag_status
function tool_auftrag_status(sequence args)
    sequence kdnr = mcp:arg(args, "kdnr", "")
    if length(kdnr) = 0 then
        return mcp:tool_error("Fehler: Parameter 'kdnr' ist erforderlich.")
    end if

    sequence rows = sqlite:query(db, "SELECT id, artnr, bezeichnung, menge, preis, status FROM auftraege WHERE kdnr = ?;", {kdnr})
    if length(rows) = 0 then
        return mcp:tool_result("Keine offenen oder abgeschlossenen Aufträge für Kunde " & kdnr & " gefunden.")
    end if

    sequence out = sprintf("Aufträge für Kunde %s (%d Vorgänge):\n", {kdnr, length(rows)})
    for i = 1 to length(rows) do
        sequence r = rows[i]
        out &= sprintf("  • #%d: %s (%dx zu je %.2f €) - Status: %s\n",
                       {r[1], r[3], r[4], r[5], r[6]})
    end for
    return mcp:tool_result(out)
end function

-- Tool 4: kpi_uebersicht
function tool_kpi_uebersicht(sequence args)
    integer kunden_anz = sqlite:query_value(db, "SELECT COUNT(*) FROM kunden;", {}, 0)
    atom umsatz_ges    = 0.0
    object u_val       = sqlite:query_value(db, "SELECT COALESCE(SUM(umsatz), 0.0) FROM kunden;", {}, 0.0)
    if atom(u_val) then umsatz_ges = u_val end if
    integer auftrag_anz = sqlite:query_value(db, "SELECT COUNT(*) FROM auftraege;", {}, 0)

    sequence out = "=== Euphorix CRM Live Kennzahlen ===\n"
    out &= sprintf("  • Aktive Kunden:    %d\n", {kunden_anz})
    out &= sprintf("  • Gesamt-Pipeline:  %.2f €\n", {umsatz_ges})
    out &= sprintf("  • Aufträge im Lauf: %d\n", {auftrag_anz})
    return mcp:tool_result(out)
end function

-- Tools registrieren
mcp:register_tool(srv, "kunden_suchen", "Sucht Kunden im CRM nach Name, Ort oder Kundennummer", {
    {"suchbegriff", "string", "Suchbegriff (z.B. Firmenname, Ort oder K-1001)", 1}
}, routine_id("tool_kunden_suchen"))

mcp:register_tool(srv, "kunde_anlegen", "Erfasst einen neuen Kundenstammsatz in der SQLite Datenbank", {
    {"kdnr", "string", "Eindeutige Kundennummer (z.B. K-1006)", 1},
    {"name", "string", "Vollständiger Firmenname", 1},
    {"ort", "string", "Standort / Ort", 0},
    {"email", "string", "Kontakt E-Mail Adresse", 0},
    {"umsatz", "number", "Geplanter Jahresumsatz in Euro", 0},
    {"status", "string", "Kundenkategorie (A-Kunde, B-Kunde, C-Kunde)", 0}
}, routine_id("tool_kunde_anlegen"))

mcp:register_tool(srv, "auftrag_status", "Fragt alle Aufträge und deren Status für einen Kunden ab", {
    {"kdnr", "string", "Kundennummer (z.B. K-1001)", 1}
}, routine_id("tool_auftrag_status"))

mcp:register_tool(srv, "kpi_uebersicht", "Liefert aggregierte Unternehmens-KPIs (Kundenanzahl, Umsatz, Aufträge)", {}, routine_id("tool_kpi_uebersicht"))

-- ==============================================================================
-- 4. Resource Implementierungen
-- ==============================================================================

function res_kunden_export(sequence uri)
    sequence rows = sqlite:query(db, "SELECT kdnr, name, ort, email, umsatz, status FROM kunden ORDER BY kdnr ASC;")
    sequence csv = "KdNr;Name;Ort;EMail;Umsatz;Status\n"
    for i = 1 to length(rows) do
        sequence r = rows[i]
        csv &= sprintf("%s;%s;%s;%s;%.2f;%s\n", {r[1], r[2], r[3], r[4], r[5], r[6]})
    end for
    return mcp:resource_result(uri, "text/csv; charset=utf-8", csv)
end function

function res_stats_kpi(sequence uri)
    integer kunden_anz = sqlite:query_value(db, "SELECT COUNT(*) FROM kunden;", {}, 0)
    atom umsatz_ges    = 0.0
    object u_val       = sqlite:query_value(db, "SELECT COALESCE(SUM(umsatz), 0.0) FROM kunden;", {}, 0.0)
    if atom(u_val) then umsatz_ges = u_val end if
    integer auftrag_anz = sqlite:query_value(db, "SELECT COUNT(*) FROM auftraege;", {}, 0)

    sequence json_str = sprintf(`{"kunden": %d, "umsatz_eur": %.2f, "auftraege": %d, "zeitstempel": "2026-11-25T12:00:00Z"}`,
                                {kunden_anz, umsatz_ges, auftrag_anz})
    return mcp:resource_result(uri, "application/json; charset=utf-8", json_str)
end function

mcp:register_resource(srv, "crm://kunden/export", "Kundenstamm CSV Export", "text/csv", routine_id("res_kunden_export"), "Vollständiger tabellarischer Export aller Kunden")
mcp:register_resource(srv, "crm://stats/kpi", "Live KPI JSON Feed", "application/json", routine_id("res_stats_kpi"), "Echtzeit-Kennzahlen des ERP-Systems als JSON")

-- ==============================================================================
-- 5. Prompt Implementierungen
-- ==============================================================================

function prompt_vertriebs_briefing(sequence args)
    sequence kdnr = mcp:arg(args, "kdnr", "K-1001")
    sequence prompt_text = sprintf("Bitte erstelle ein umfassendes Vertriebs-Briefing für das Kundengespräch mit %s. " &
                                   "Nutze das Tool 'kunden_suchen' und 'auftrag_status', um die Historie und offene Aufträge abzufragen.", {kdnr})
    return mcp:prompt_result("Vertriebs-Briefing", {
        {"user", prompt_text}
    })
end function

mcp:register_prompt(srv, "vertriebs_briefing", "Erstellt einen Vertriebsleitfaden vor Kundenterminen", {
    {"kdnr", "Kundennummer", 1}
}, routine_id("prompt_vertriebs_briefing"))

-- ==============================================================================
-- 6. Server Starten (stdio oder HTTP)
-- ==============================================================================

sequence args = command_line()
integer is_http = 0
for i = 1 to length(args) do
    if equal(args[i], "--http") or equal(args[i], "--run") then
        is_http = 1
        exit
    end if
end for

if is_http then
    mcp:serve_http(srv, 8095, "0.0.0.0")
else
    -- Standard I/O (Default): Direkt nutzbar für Desktop AI Assistenten
    mcp:run_stdio(srv)
end if
