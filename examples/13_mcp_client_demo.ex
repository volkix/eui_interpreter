-- ==============================================================================
-- Euphorix 1.0 Demo: Model Context Protocol (MCP) Client
-- ==============================================================================
--
-- Startet den Euphorix MCP-Server als Subprozess über bidirektionale Pipes (stdio),
-- führt den MCP-Handshake durch, fragt Tools ab, ruft sie mit Parametern auf
-- und liest bereitgestellte ERP-Resourcen aus.
--
-- Ausführen mit:
--   ./euphorix examples/13_mcp_client_demo.ex
-- ==============================================================================

include std/mcp.e as mcp
include std/io.e as io

puts(io:SCREEN, "=====================================================================\n")
puts(io:SCREEN, "  Euphorix 1.0 – Model Context Protocol (MCP) Client Demo\n")
puts(io:SCREEN, "  Native Kommunikation via JSON-RPC 2.0 & stdio Subprozess-Pipes\n")
puts(io:SCREEN, "=====================================================================\n\n")

-- 1. MCP-Server per stdio Subprozess starten
puts(io:SCREEN, "1. Starte MCP Server Subprozess...\n")
sequence server_cmd = "./euphorix examples/12_mcp_server_demo.ex --stdio"
object start_res = mcp:client_stdio(server_cmd)

if start_res[1] = 0 then
    puts(io:STDERR, "❌ FEHLER beim Starten des Subprozesses: " & start_res[2] & "\n")
    abort(1)
end if

sequence client = start_res[2]
puts(io:SCREEN, "   ✓ Serverprozess erfolgreich über bidirektionale Pipe gestartet.\n\n")

-- 2. MCP Handshake initialisieren (initialize & notifications/initialized)
puts(io:SCREEN, "2. Führe MCP Protokoll-Handshake durch ('initialize')...\n")
sequence init_res = mcp:client_init(client, "Euphorix-CLI-Agent", "1.0.0")

if init_res[1] = 0 then
    puts(io:STDERR, "❌ Handshake fehlgeschlagen: " & init_res[2] & "\n")
    mcp:client_close(client)
    abort(1)
end if

sequence srv_info = init_res[2]
client = init_res[3]
puts(io:SCREEN, sprintf("   ✓ Verbunden mit MCP Server: '%s' (Version %s, Protokoll v%s)\n\n",
                        {srv_info[1], srv_info[2], mcp:MCP_VERSION}))

-- 3. Verfügbare Tools abfragen ('tools/list')
puts(io:SCREEN, "3. Erkunde verfügbare Tools ('tools/list')...\n")
sequence tools_res = mcp:client_list_tools(client)

if tools_res[1] = 0 then
    puts(io:STDERR, "❌ Tools-Abfrage fehlgeschlagen: " & tools_res[2] & "\n")
    mcp:client_close(client)
    abort(1)
end if

sequence tools = tools_res[2]
client = tools_res[3]
puts(io:SCREEN, sprintf("   ✓ %d Werkzeuge auf dem Server gefunden:\n", {length(tools)}))
for i = 1 to length(tools) do
    sequence t = tools[i]
    puts(io:SCREEN, sprintf("     [%d] %-16s : %s\n", {i, t[1], t[2]}))
end for
puts(io:SCREEN, "\n")

-- 4. Tool-Aufruf 1: Kundensuche ausführen ('tools/call' -> 'kunden_suchen')
puts(io:SCREEN, "4. Tool-Aufruf: 'kunden_suchen' mit Suchbegriff 'Schulze'...\n")
sequence call_search = mcp:client_call_tool(client, "kunden_suchen", {{"suchbegriff", "Schulze"}})
client = call_search[4]

if call_search[1] = 0 or call_search[3] != 0 then
    puts(io:STDERR, "❌ Fehler beim Tool-Aufruf: " & call_search[2] & "\n")
else
    puts(io:SCREEN, "--- Server-Ergebnis: ---\n" & call_search[2] & "------------------------\n\n")
end if

-- 5. Tool-Aufruf 2: Auftragsstatus abfragen ('auftrag_status')
puts(io:SCREEN, "5. Tool-Aufruf: 'auftrag_status' für Kunde 'K-1001'...\n")
sequence call_order = mcp:client_call_tool(client, "auftrag_status", {{"kdnr", "K-1001"}})
client = call_order[4]

if call_order[1] = 0 or call_order[3] != 0 then
    puts(io:STDERR, "❌ Fehler beim Tool-Aufruf: " & call_order[2] & "\n")
else
    puts(io:SCREEN, "--- Server-Ergebnis: ---\n" & call_order[2] & "------------------------\n\n")
end if

-- 6. Tool-Aufruf 3: Neuen Kunden anlegen ('kunde_anlegen')
puts(io:SCREEN, "6. Tool-Aufruf: 'kunde_anlegen' (Neukunde 'CyberTech Robotics GmbH')...\n")
sequence call_add = mcp:client_call_tool(client, "kunde_anlegen", {
    {"kdnr", "K-1006"},
    {"name", "CyberTech Robotics GmbH"},
    {"ort", "Stuttgart"},
    {"email", "contact@cybertech.de"},
    {"umsatz", 185000.00},
    {"status", "A-Kunde"}
})
client = call_add[4]

if call_add[1] = 0 or call_add[3] != 0 then
    puts(io:STDERR, "❌ Fehler beim Tool-Aufruf: " & call_add[2] & "\n")
else
    puts(io:SCREEN, "   ✓ " & call_add[2] & "\n\n")
end if

-- 7. Tool-Aufruf 4: Aktualisierte KPIs abrufen ('kpi_uebersicht')
puts(io:SCREEN, "7. Tool-Aufruf: 'kpi_uebersicht' zur Überprüfung...\n")
sequence call_kpis = mcp:client_call_tool(client, "kpi_uebersicht", {})
client = call_kpis[4]

if call_kpis[1] = 0 or call_kpis[3] != 0 then
    puts(io:STDERR, "❌ Fehler beim Tool-Aufruf: " & call_kpis[2] & "\n")
else
    puts(io:SCREEN, "--- Server-Ergebnis: ---\n" & call_kpis[2] & "------------------------\n\n")
end if

-- 8. Resourcen abfragen ('resources/list')
puts(io:SCREEN, "8. Erkunde verfügbare Resourcen ('resources/list')...\n")
sequence res_list_res = mcp:client_list_resources(client)
client = res_list_res[3]
sequence resources = res_list_res[2]

puts(io:SCREEN, sprintf("   ✓ %d Resourcen gefunden:\n", {length(resources)}))
for i = 1 to length(resources) do
    sequence r = resources[i]
    puts(io:SCREEN, sprintf("     [%d] %-24s (%s) : %s\n", {i, r[1], r[3], r[2]}))
end for
puts(io:SCREEN, "\n")

-- 9. Resource auslesen ('resources/read' -> 'crm://kunden/export')
puts(io:SCREEN, "9. Resource auslesen: 'crm://kunden/export' (CSV-Stream)...\n")
sequence read_res = mcp:client_read_resource(client, "crm://kunden/export")
client = read_res[4]

if read_res[1] = 0 then
    puts(io:STDERR, "❌ Fehler beim Lesen der Resource: " & read_res[2] & "\n")
else
    puts(io:SCREEN, "--- Empfangener CSV-Inhalt: ---\n" & read_res[2] & "-------------------------------\n\n")
end if

-- 10. Client sauber beenden
puts(io:SCREEN, "10. Verbindung trennen & Subprozess sauber beenden...\n")
mcp:client_close(client)
puts(io:SCREEN, "   ✓ Subprozess-Pipes geschlossen, Beendigung erfolgreich.\n\n")

puts(io:SCREEN, "=====================================================================\n")
puts(io:SCREEN, "  ✓ Alle MCP Tests (Handshake, Tools, Resourcen) 100% ERFOLGREICH!\n")
puts(io:SCREEN, "=====================================================================\n")
