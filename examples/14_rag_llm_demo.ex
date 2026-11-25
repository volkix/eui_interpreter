-- ==============================================================================
-- Euphorix 1.0 Demo: Retrieval-Augmented Generation (RAG) mit LLM & FTS5
-- ==============================================================================
--
-- Demonstriert eine vollständige, autarke RAG-Pipeline in Euphorix:
-- 1. Automatisches Chunking & Ingestion von Fachdokumenten
-- 2. Hybride Retrieval-Suche: SQLite FTS5 (BM25) + Vektor-Embeddings (Cosinus-Ähnlichkeit)
-- 3. Prompt-Augmentierung mit Quellenangaben & Zitaten
-- 4. Antwortgenerierung über das LLM-Modul (std/llm.e)
--
-- Ausführen mit:
--   ./euphorix examples/14_rag_llm_demo.ex          (100% Offline Mock-Modell)
--   ./euphorix examples/14_rag_llm_demo.ex --ollama (Lokales Ollama LLM, z.B. Llama3)
--   ./euphorix examples/14_rag_llm_demo.ex --openai (OpenAI API mit OPENAI_API_KEY)
-- ==============================================================================

include std/rag.e as rag
include std/llm.e as llm
include std/io.e as io
include std/os.e as os

puts(io:SCREEN, "=====================================================================\n")
puts(io:SCREEN, "  Euphorix 1.0 – Retrieval-Augmented Generation (RAG) & LLM Demo\n")
puts(io:SCREEN, "  Hybrides Retrieval (SQLite FTS5 BM25 + Vektoren) & Prompt-Synthese\n")
puts(io:SCREEN, "=====================================================================\n\n")

-- 1. LLM Client konfigurieren
sequence args = command_line()
object llm_cli = {}
sequence provider_name = "Offline-Modell (Deterministische Synthese-Engine)"

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
    provider_name = "Lokales Ollama (llama3:latest auf http://localhost:11434)"
elsif use_openai then
    sequence key = os:getenv("OPENAI_API_KEY")
    if length(key) = 0 then key = "sk-demo-key" end if
    llm_cli = llm:client(llm:PROVIDER_OPENAI, {
        {"model", "gpt-4o-mini"},
        {"api_key", key}
    })
    provider_name = "OpenAI (gpt-4o-mini via REST API)"
else
    llm_cli = llm:client(llm:PROVIDER_MOCK)
end if

puts(io:SCREEN, "Verwendetes LLM-Backend: " & provider_name & "\n\n")

-- 2. Wissensdatenbank (Knowledge Base) initialisieren
sequence kb = rag:create_kb("euphorix_knowledge_base", llm_cli, ":memory:")

puts(io:SCREEN, "1. Ingestion: Fachdokumentation in Wissensdatenbank indizieren...\n")

-- Dokument 1: VS-UI Web-Framework
sequence doc1_content =
    "Das VS-UI Framework (integriert in std/vsui.e) ist eine autarke High-Density Web-UI Suite " &
    "für datenintensive Fachanwendungen. Es basiert auf den nativen Assets globalblauklein.css, " &
    "vs.css und ldom.js. Eingabefelder werden über vsui:input(), vsui:numinput() und vsui:combo() erstellt.\n\n" &
    "Die Formularvalidierung erfolgt server-seitig: Schlägt die Validierung eines Pflichtfelds fehl, " &
    "sendet der Server ein vsui:field_error(id, meldung) Patch zurück. Im Browser wird das Feld " &
    "mit der CSS-Klasse vs-field-error rot umrahmt und der Fehler-Tooltip vs-error-tip eingeblendet. " &
    "Zusätzlich kann mit vsui:toast_show(meldung, typ) eine animierte Benachrichtigung angezeigt werden.\n\n" &
    "Für Datei-Uploads bietet vsui:upload(id, ziel_url) eine native Drag & Drop Dropzone mit " &
    "Dateiauswahldialog und animiertem Upload-Fortschrittsbalken. Dateiinhalte werden als JSON-Payload " &
    "an die serverseitige Route POST /api/upload übertragen und dort verarbeitet."

-- Dokument 2: Datenbanken & Volltextsuche
sequence doc2_content =
    "Euphorix bietet mit std/sqlite.e eine vollständig integrierte SQLite 3 Datenbank-Engine. " &
    "Datenbanken können wahlweise persistent als Datei oder extrem schnell im Arbeitsspeicher " &
    "mittels ':memory:' geöffnet werden.\n\n" &
    "Für die Volltextsuche und Relevanzanalyse steht das SQLite-Modul FTS5 zur Verfügung. " &
    "Virtuelle Tabellen werden mit CREATE VIRTUAL TABLE name USING fts5(...) angelegt. " &
    "Die Suche erfolgt über den MATCH-Operator mit automatischer Relevanzsortierung nach dem " &
    "BM25-Ranking-Algorithmus (ORDER BY rank ASC).\n\n" &
    "Für relationale Unternehmensdatenbanken unterstützt Euphorix neben SQLite auch native " &
    "PostgreSQL-Verbindungen über std/pgsql.e und Transaktionssicherheit über Commit und Rollback."

-- Dokument 3: Model Context Protocol (MCP)
sequence doc3_content =
    "Das Model Context Protocol (std/mcp.e) ermöglicht die standardisierte Anbindung von Euphorix " &
    "an moderne KI-Systeme (wie Claude Desktop, Antigravity, Cursor und autonome Agenten) nach der " &
    "MCP-Spezifikation 2024-11-05.\n\n" &
    "Als MCP-Server stellt Euphorix eigene Datenbanken und Logik als Tools (mcp:register_tool) " &
    "und Ressourcen (mcp:register_resource) bereit. Als Transport-Wege werden Standard-I/O (stdio) " &
    "für lokale Desktop-Assistenten und HTTP mit Server-Sent Events (GET /sse und POST /messages) " &
    "für Web-Netzwerke unterstützt.\n\n" &
    "Als MCP-Client kann Euphorix beliebige externe MCP-Server als Subprozess über std/pipeio.e steuern " &
    "und Werkzeuge dynamisch erkunden und ausführen."

integer c1 = rag:add_document(kb, "MAN-01", "VS-UI High-Density Web-Framework", doc1_content)
integer c2 = rag:add_document(kb, "MAN-02", "SQLite & FTS5 Volltextsuche", doc2_content)
integer c3 = rag:add_document(kb, "MAN-03", "Model Context Protocol (MCP) Integration", doc3_content)

puts(io:SCREEN, sprintf("   ✓ Dokument 1 ('%s'): %d Abschnitte indiziert.\n", {"VS-UI Framework", c1}))
puts(io:SCREEN, sprintf("   ✓ Dokument 2 ('%s'): %d Abschnitte indiziert.\n", {"SQLite & FTS5", c2}))
puts(io:SCREEN, sprintf("   ✓ Dokument 3 ('%s'): %d Abschnitte indiziert.\n\n", {"MCP Integration", c3}))

-- 3. Fragen an die Wissensdatenbank stellen
sequence test_fragen = {
    "Wie funktioniert die Validierung von Pflichtfeldern und die Fehleranzeige in VS-UI?",
    "Welche Möglichkeiten bietet SQLite in Euphorix für Volltextsuche und Ranking?",
    "Wie kann ein Euphorix-Programm über das Model Context Protocol als KI-Server fungieren?"
}

for q = 1 to length(test_fragen) do
    sequence frage = test_fragen[q]
    puts(io:SCREEN, "---------------------------------------------------------------------\n")
    puts(io:SCREEN, sprintf("🔎 RAG-Abfrage #%d: \"%s\"\n", {q, frage}))
    puts(io:SCREEN, "---------------------------------------------------------------------\n")

    -- Führe RAG-Pipeline aus
    sequence rag_res = rag:ask(kb, frage, {{"top_k", 2}, {"mode", "hybrid"}})

    -- Gefundene Quellen anzeigen
    puts(io:SCREEN, "📚 Gefundene Quellen (Hybrides BM25 + Vektor Ranking):\n")
    puts(io:SCREEN, rag:format_sources(rag_res) & "\n")

    -- Antwort ausgeben
    puts(io:SCREEN, "🤖 Generierte Antwort (LLM Grounded Response):\n")
    puts(io:SCREEN, rag:answer(rag_res) & "\n\n")
end for

rag:close_kb(kb)

puts(io:SCREEN, "=====================================================================\n")
puts(io:SCREEN, "  ✓ RAG-Pipeline Demo erfolgreich abgeschlossen!\n")
puts(io:SCREEN, "=====================================================================\n")
