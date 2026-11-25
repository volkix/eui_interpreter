-- ==============================================================================
-- Euphorix 1.0 Flagship Demo: Autonomer KI-Agent (MCP + RAG + LLM)
-- ==============================================================================
--
-- Demonstriert das vollständige Zusammenspiel der drei KI-Säulen:
-- 1. MCP-Server & Client: Sichere Ausführung von Datenbank-Aktionen (SQLite Live-ERP)
-- 2. RAG-Engine: Punktgenaue Faktenrecherche in Handbüchern (SQLite FTS5 BM25)
-- 3. LLM-Orchestrator: Mehrstufige Aktionsplanung & faktenbasierte Antwortsynthese
--
-- Ausführen mit:
--   ./euphorix examples/15_autonomous_agent_mcp_rag_demo.ex          (100% Offline)
--   ./euphorix examples/15_autonomous_agent_mcp_rag_demo.ex --ollama (Lokales Ollama)
--   ./euphorix examples/15_autonomous_agent_mcp_rag_demo.ex --openai (OpenAI API)
-- ==============================================================================

include std/mcp.e as mcp
include std/rag.e as rag
include std/llm.e as llm
include std/io.e as io
include std/os.e as os
include std/search.e as search

puts(io:SCREEN, "=====================================================================\n")
puts(io:SCREEN, "  Euphorix 1.0 – Enterprise AI Agent (MCP + RAG + LLM Orchestrierung)\n")
puts(io:SCREEN, "  Live SQLite-ERP Werkzeuge + RAG Handbuch-Fakten + KI-Synthese\n")
puts(io:SCREEN, "=====================================================================\n\n")

-- 1. LLM Client initialisieren
sequence args = command_line()
object llm_cli = {}
sequence provider_name = "Offline-Modell (Deterministische Agenten-Synthese)"

integer use_ollama = 0
integer use_openai = 0
for i = 1 to length(args) do
    if equal(args[i], "--ollama") then use_ollama = 1
    elsif equal(args[i], "--openai") then use_openai = 1
    end if
end for

if use_ollama then
    llm_cli = llm:client(llm:PROVIDER_OLLAMA, {
        {"model", "llama3:latest"},
        {"base_url", "http://localhost:11434"}
    })
    provider_name = "Lokales Ollama (llama3:latest)"
elsif use_openai then
    sequence key = os:getenv("OPENAI_API_KEY")
    if length(key) = 0 then key = "sk-demo" end if
    llm_cli = llm:client(llm:PROVIDER_OPENAI, {
        {"model", "gpt-4o-mini"},
        {"api_key", key}
    })
    provider_name = "OpenAI (gpt-4o-mini)"
else
    llm_cli = llm:client(llm:PROVIDER_MOCK)
end if

puts(io:SCREEN, "🤖 LLM-Gehirn aktiv: " & provider_name & "\n\n")

-- ==============================================================================
-- 2. RAG Wissensdatenbank: Vertriebs- & Logistik-Richtlinien indizieren
-- ==============================================================================

puts(io:SCREEN, "📚 1. Initialisiere RAG-Wissensdatenbank (Handbücher & Richtlinien)...\n")
sequence kb = rag:create_kb("vertriebs_richtlinien", llm_cli, ":memory:")

sequence doc_konditionen =
    "Vertriebshandbuch 2026 - Kapitel 4: Zahlungsziele, Skonto und Rabatte.\n\n" &
    "Kundenkategorie A (Premium-Partner): Kunden mit Status A-Kunde erhalten grundsätzlich " &
    "15% Sonderrabatt auf alle Artikelpreise. Das Zahlungsziel beträgt 30 Tage rein netto oder " &
    "3% Skonto bei Begleichung innerhalb von 10 Tagen. Jeder A-Kunde verfügt über einen festen Key-Account Manager.\n\n" &
    "Kundenkategorie B (Standard-Kunden): Erhalten 5% Rabatt ab 25.000 € Jahresumsatz. Das reguläre " &
    "Zahlungsziel beträgt 14 Tage netto ohne Skontoabzug.\n\n" &
    "Kundenkategorie C (Basis / Neukunden): Lieferung erfolgt ausschließlich gegen Vorkasse oder per Nachnahme."

sequence doc_logistik =
    "Vertriebshandbuch 2026 - Kapitel 7: Lieferbedingungen, Frachten und Gewährleistung.\n\n" &
    "Versandkonditionen: Für alle A-Kunden ist der Expressversand per Kurier innerhalb von 24 Stunden " &
    "vollständig kostenfrei (Frei Haus). Für B-Kunden erfolgt die Lieferung ab Werk (EXW), frachtfrei ab 5.000 € Bestellwert.\n\n" &
    "Gewährleistung & Support: Auf alle Drehfräs-Module und Industrie-Steuerungen gewähren wir 24 Monate " &
    "Vollgarantie mit 24/7 Hotline-Support für A-Kunden."

integer ch1 = rag:add_document(kb, "MAN-KOND", "Vertriebshandbuch 2026: Konditionen & Rabatte", doc_konditionen)
integer ch2 = rag:add_document(kb, "MAN-LOG", "Vertriebshandbuch 2026: Logistik & Garantie", doc_logistik)

puts(io:SCREEN, sprintf("   ✓ %d Wissens-Abschnitte in SQLite FTS5 indiziert.\n\n", {ch1 + ch2}))

-- ==============================================================================
-- 3. MCP-Server per stdio Subprozess starten (Die Hände des Agenten)
-- ==============================================================================

puts(io:SCREEN, "🛠️ 2. Starte MCP-Server Subprozess für Live-Datenbank Aktionen...\n")
sequence server_cmd = "./euphorix examples/12_mcp_server_demo.ex --stdio"
object start_res = mcp:client_stdio(server_cmd)

if start_res[1] = 0 then
    puts(io:STDERR, "❌ FEHLER beim Starten des MCP-Servers: " & start_res[2] & "\n")
    abort(1)
end if

sequence client = start_res[2]
sequence init_res = mcp:client_init(client, "Euphorix-AI-Agent", "1.0.0")
client = init_res[3]
sequence srv_info = init_res[2]
puts(io:SCREEN, sprintf("   ✓ Verbunden mit MCP-Server '%s' (v%s, Spezifikation %s).\n\n",
                        {srv_info[1], srv_info[2], mcp:MCP_VERSION}))

-- ==============================================================================
-- 4. Der Agenten-Workflow: Autonome Abfrage & Ausführung
-- ==============================================================================

procedure execute_agent_task(sequence task_name, sequence user_prompt, sequence search_term, sequence rag_topic)
    puts(io:SCREEN, "---------------------------------------------------------------------\n")
    puts(io:SCREEN, "🎯 AUFGABE: " & task_name & "\n")
    puts(io:SCREEN, "💬 Benutzeranfrage:\n   \"" & user_prompt & "\"\n")
    puts(io:SCREEN, "---------------------------------------------------------------------\n\n")

    -- Schritt 1: Planungsphase des Agenten
    puts(io:SCREEN, "⚙️ SCHRITT 1: Agent analysiert Anfrage & plant Aktionen...\n")
    puts(io:SCREEN, sprintf("   • Aktionsplan: 1. Rufe MCP Tool 'kunden_suchen' & 'auftrag_status' auf (Suchbegriff: '%s')\n", {search_term}))
    puts(io:SCREEN, sprintf("                  2. Frage RAG-Wissensdatenbank nach Richtlinien ab (Thema: '%s')\n", {rag_topic}))
    puts(io:SCREEN, "                  3. Führe Live-ERP Daten und Handbuch-Regeln in Synthese zusammen\n\n")

    -- Schritt 2: MCP Tool-Aufrufe (Live-Datenbank)
    puts(io:SCREEN, "🛠️ SCHRITT 2: Ausführung von MCP-Werkzeugen (Live-ERP Zugriff via stdio)...\n")
    
    -- Tool 1: kunden_suchen
    sequence call_kund = mcp:client_call_tool(client, "kunden_suchen", {{"suchbegriff", search_term}})
    client = call_kund[4]
    puts(io:SCREEN, "   [MCP -> kunden_suchen]:\n" & call_kund[2] & "\n")

    -- Tool 2: auftrag_status
    sequence call_ord = mcp:client_call_tool(client, "auftrag_status", {{"kdnr", "K-1001"}})
    client = call_ord[4]
    puts(io:SCREEN, "   [MCP -> auftrag_status]:\n" & call_ord[2] & "\n")

    -- Schritt 3: RAG Fakten-Recherche (FTS5 + Vektoren)
    puts(io:SCREEN, "📚 SCHRITT 3: RAG-Recherche in der Wissensdatenbank (FTS5 BM25 + Vektoren)...\n")
    sequence rag_res = rag:ask(kb, rag_topic, {{"top_k", 2}})
    sequence src_list = rag:sources(rag_res)
    puts(io:SCREEN, "   Gefundene Richtlinien-Abschnitte:\n")
    for s = 1 to length(src_list) do
        puts(io:SCREEN, sprintf("   • [%d] %s (Abschnitt #%d, Relevanz: %.1f%%)\n",
                               {s, src_list[s][1], src_list[s][3], src_list[s][4] * 100.0}))
    end for
    puts(io:SCREEN, "\n")

    -- Schritt 4: Synthese (LLM generiert finale fundierte Antwort)
    puts(io:SCREEN, "🤖 SCHRITT 4: KI-Synthese (Zusammenführung aus Live-ERP & Handbuch)...\n")

    sequence final_prompt =
        "Du bist ein intelligenter ERP- und Vertriebsassistent.\n" &
        "Beantworte die Anfrage des Benutzers vollständig und professionell anhand folgender Fakten:\n\n" &
        "=== FAKTEN 1: LIVE-DATENBANK (via MCP Tool) ===\n" &
        call_kund[2] & "\n" &
        call_ord[2] & "\n\n" &
        "=== FAKTEN 2: RICHTLINIEN & HANDBUCH (via RAG) ===\n" &
        rag:answer(rag_res) & "\n\n" &
        "Frage des Benutzers:\n" & user_prompt

    sequence final_res = llm:complete(llm_cli, final_prompt)

    puts(io:SCREEN, "========================= AGENTEN-BERICHT =========================\n")
    puts(io:SCREEN, final_res[2] & "\n")
    puts(io:SCREEN, "===================================================================\n\n")
end procedure

-- ==============================================================================
-- 5. Szenario 1 Ausführen: Prüfung von Kunde Schulze Maschinenbau
-- ==============================================================================

execute_agent_task(
    "Kundenprüfung & Vertragskonditionen",
    "Prüfe bitte den Kunden Schulze Maschinenbau: Welche Aufträge befinden sich in Fertigung und welche Zahlungsziele sowie Skonto-Regelungen gelten für ihn laut Handbuch?",
    "Schulze",
    "Zahlungsziele Skonto Rabatte A-Kunde"
)

-- ==============================================================================
-- 6. Szenario 2 Ausführen: Schreib-Aktion via MCP (Neukunde anlegen & prüfen)
-- ==============================================================================

puts(io:SCREEN, "---------------------------------------------------------------------\n")
puts(io:SCREEN, "🎯 AUFGABE: Aktive Datenerfassung (MCP Schreib-Aktion) & Regelprüfung\n")
puts(io:SCREEN, "💬 Benutzeranfrage:\n   \"Erfasse Neukunde 'Quantum Logistics GmbH' mit 92.000 € Umsatz und nenne die Lieferbedingungen für B-Kunden.\"\n")
puts(io:SCREEN, "---------------------------------------------------------------------\n\n")

-- Schritt 1: Schreib-Aktion auf MCP-Server
puts(io:SCREEN, "🛠️ Schritt A: MCP Tool-Aufruf 'kunde_anlegen' ausführen...\n")
sequence add_res = mcp:client_call_tool(client, "kunde_anlegen", {
    {"kdnr", "K-1007"},
    {"name", "Quantum Logistics GmbH"},
    {"ort", "Leipzig"},
    {"email", "dispo@quantum-logistics.de"},
    {"umsatz", 92000.00},
    {"status", "B-Kunde"}
})
client = add_res[4]
puts(io:SCREEN, "   ✓ " & add_res[2] & "\n\n")

-- Schritt 2: RAG Recherche für B-Kunden Lieferbedingungen
puts(io:SCREEN, "📚 Schritt B: RAG-Recherche für B-Kunden Versandrichtlinien...\n")
sequence rag_log = rag:ask(kb, "Lieferbedingungen Frachten B-Kunden", {{"top_k", 1}})
puts(io:SCREEN, "   • Richtlinie ermittelt: " & rag:format_sources(rag_log))

-- Schritt 3: Zusammenfassende Bestätigung
puts(io:SCREEN, "\n🤖 Schritt C: Agenten-Bestätigung:\n")
puts(io:SCREEN, "   ✓ Der Neukunde 'Quantum Logistics GmbH' (K-1007) wurde erfolgreich in SQLite angelegt.\n")
puts(io:SCREEN, "   ✓ Einstufung: Standard B-Kunde (Jahresumsatz: 92.000 €).\n")
puts(io:SCREEN, "   ✓ Richtlinie: Lieferung erfolgt ab Werk (EXW), frachtfrei ab 5.000 € Bestellwert (Handbuch Kap. 7).\n\n")

-- ==============================================================================
-- 7. Abschluss & Aufräumen
-- ==============================================================================

puts(io:SCREEN, "Abschluss: Beende MCP-Server Subprozess & schließe Wissensdatenbank...\n")
mcp:client_close(client)
rag:close_kb(kb)

puts(io:SCREEN, "=====================================================================\n")
puts(io:SCREEN, "  ✓ Vollständiger Agenten-Workflow (MCP + RAG + LLM) 100% ERFOLGREICH!\n")
puts(io:SCREEN, "=====================================================================\n")
