package eu;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Language Server Protocol (LSP) 3.17 Implementation for Euphorix (OpenEuphoria syntax).
 * <p>
 * Provides real-time syntax checking (diagnostics), comprehensive code completion (IntelliSense with snippets),
 * signature help (parameter hints), hover documentation, go-to-definition, document outline,
 * and automatic code formatting for IDEs like Apache NetBeans and VS Code.
 */
public final class LspServer {

    private static final ObjectMapper MAPPER = new ObjectMapper();
    private static final Map<String, String> OPEN_DOCS = new ConcurrentHashMap<>();

    // Standard Library & Built-in Documentation Cache
    private static final Map<String, RoutineDoc> BUILTIN_DOCS = new LinkedHashMap<>();
    private static final Map<String, List<RoutineDoc>> NAMESPACE_DOCS = new LinkedHashMap<>();
    private static final Map<String, List<RoutineDoc>> GLOBAL_STD_DOCS = new LinkedHashMap<>();
    private static final Map<String, String> KEYWORD_DOCS = new LinkedHashMap<>();
    private static final Map<String, String> KEYWORD_SNIPPETS = new LinkedHashMap<>();
    private static final Map<String, String> TEMPLATE_SNIPPETS = new LinkedHashMap<>();
    private static final Map<String, String> TEMPLATE_DOCS = new LinkedHashMap<>();

    public static record RoutineDoc(
            String name,
            String ns,
            String signature,
            String desc,
            String filePath,
            int line,
            List<String> paramNames,
            int kind
    ) {}

    static {
        initDocCache();
        indexStandardLibrary();
    }

    private static void initDocCache() {
        // Keywords
        KEYWORD_DOCS.put("function", "**function** `name(params) ... return val ... end function`\n\nDefiniert eine Funktion mit Rückgabewert.");
        KEYWORD_DOCS.put("procedure", "**procedure** `name(params) ... end procedure`\n\nDefiniert eine Prozedur ohne Rückgabewert.");
        KEYWORD_DOCS.put("type", "**type** `name(object x) ... return bool ... end type`\n\nDefiniert einen benutzerdefinierten Typ (Prädikatfunktion).");
        KEYWORD_DOCS.put("sequence", "**sequence** – Dynamische, 1-basierte Liste beliebiger Länge und Schachtelungstiefe.");
        KEYWORD_DOCS.put("atom", "**atom** – Numerischer Wert: 48-Bit Integer oder 64-Bit IEEE-754 Fließkommazahl.");
        KEYWORD_DOCS.put("integer", "**integer** – 48-Bit Ganzzahlwert ohne Nachkommastellen.");
        KEYWORD_DOCS.put("object", "**object** – Universeller Basistyp: Kann jedes atom oder jede sequence halten.");
        KEYWORD_DOCS.put("constant", "**constant** `NAME = wert` – Deklariert unveränderliche Konstanten.");
        KEYWORD_DOCS.put("enum", "**enum** `A, B, C` – Deklariert aufzählbare Konstanten.");
        KEYWORD_DOCS.put("public", "**public** – Exportiert Symbole für externe Dateien.");
        KEYWORD_DOCS.put("export", "**export** – Exportiert Symbole für die direkt inkludierende Datei.");
        KEYWORD_DOCS.put("global", "**global** – Exportiert Symbole global für alle Projektdateien.");
        KEYWORD_DOCS.put("include", "**include** `pfad [as alias]` – Bindet externe Euphoria-Bibliotheken ein.");
        KEYWORD_DOCS.put("if", "**if** `bedingung then ... [elsif ... then] [else ...] end if` – Bedingte Verzweigung.");
        KEYWORD_DOCS.put("while", "**while** `bedingung do ... end while` – Kopfgesteuerte Schleife.");
        KEYWORD_DOCS.put("for", "**for** `var = start to ende [by schritt] do ... end for` – Zählschleife.");
        KEYWORD_DOCS.put("loop", "**loop ... until** `bedingung` – Fußgesteuerte Schleife mit optionalem `entry`.");
        KEYWORD_DOCS.put("switch", "**switch** `wert [with fallthru] do case X then ... case else ... end switch`");
        KEYWORD_DOCS.put("return", "**return** `[wert]` – Beendet Routine und gibt optional einen Wert zurück.");
        KEYWORD_DOCS.put("exit", "**exit** `[label]` – Verlässt die aktuelle oder benannte Schleife vorzeitig.");
        KEYWORD_DOCS.put("break", "**break** `[label]` – Verlässt einen switch- oder Schleifenblock.");
        KEYWORD_DOCS.put("continue", "**continue** `[label]` – Springt zum nächsten Schleifendurchlauf.");
        KEYWORD_DOCS.put("retry", "**retry** – Wiederholt den aktuellen Schleifendurchlauf ohne Inkrement.");

        KEYWORD_SNIPPETS.put("function", "function ${1:name}(${2:params})\n\t${0}\n\treturn 0\nend function");
        KEYWORD_SNIPPETS.put("procedure", "procedure ${1:name}(${2:params})\n\t${0}\nend procedure");
        KEYWORD_SNIPPETS.put("type", "type ${1:name}(object x)\n\treturn ${0:1}\nend type");
        KEYWORD_SNIPPETS.put("if", "if ${1:condition} then\n\t${0}\nend if");
        KEYWORD_SNIPPETS.put("ifelse", "if ${1:condition} then\n\t${2}\nelse\n\t${0}\nend if");
        KEYWORD_SNIPPETS.put("for", "for ${1:i} = ${2:1} to ${3:count} do\n\t${0}\nend for");
        KEYWORD_SNIPPETS.put("while", "while ${1:condition} do\n\t${0}\nend while");
        KEYWORD_SNIPPETS.put("switch", "switch ${1:val} do\n\tcase ${2:1} then\n\t\t${0}\n\tcase else\nend switch");
        KEYWORD_SNIPPETS.put("loop", "loop\n\t${0}\nuntil ${1:condition}");

        // Euphorix Superpowers Templates
        TEMPLATE_SNIPPETS.put("mcp_server", "include std/mcp.e\n\ninteger srv = mcp:server(\"${1:my-mcp-server}\", \"1.0.0\", \"${2:Euphorix MCP Server}\")\n\nfunction on_${3:tool}(sequence args)\n\treturn mcp:tool_result(\"${4:Tool result OK}\")\nend function\nmcp:register_tool(srv, \"${3:tool}\", \"${5:Beschreibung}\", routine_id(\"on_${3:tool}\"))\n\nmcp:run_stdio(srv)\n");
        TEMPLATE_DOCS.put("mcp_server", "### MCP Server Template\nErstellt einen vollständigen Stdio-basierten MCP Server für Claude Desktop und KI-Agenten.");

        TEMPLATE_SNIPPETS.put("mcp_tool", "function on_${1:tool_name}(sequence args)\n\tsequence val = mcp:arg(args, \"${2:param}\", \"\")\n\t${0}\n\treturn mcp:tool_result(\"Ergebnis: \" & val)\nend function\nmcp:register_tool(srv, \"${1:tool_name}\", \"${3:Beschreibung}\", routine_id(\"on_${1:tool_name}\"))\n");
        TEMPLATE_DOCS.put("mcp_tool", "### MCP Tool Registration Template\nRegistriert ein aufrufbares Werkzeug mit Argument-Parser und Rückgabewert.");

        TEMPLATE_SNIPPETS.put("rag_pipeline", "include std/rag.e\n\nsequence kb = rag:create_kb(\"${1:knowledge_base}\", {}, \":memory:\")\nrag:add_document(kb, \"doc1\", \"${2:Titel}\", \"${3:Inhalt}\")\nsequence results = rag:retrieve(kb, \"${4:Suchbegriff}\", 3)\n");
        TEMPLATE_DOCS.put("rag_pipeline", "### RAG Pipeline Template\nInitialisiert eine semantische Wissensdatenbank mit Volltext- und Vektorspeicher.");

        TEMPLATE_SNIPPETS.put("llm_chat", "include std/llm.e\n\nsequence cli = llm:client(llm:PROVIDER_OLLAMA, {{\"model\", \"${1:llama3}\"}})\nsequence reply = llm:complete(cli, \"${2:Frage an das Modell}\")\nputs(1, reply & \"\\n\")\n");
        TEMPLATE_DOCS.put("llm_chat", "### Universal LLM Client Template\nVerbindet mit lokalem Ollama oder OpenAI/Anthropic/DeepSeek und führt Prompts aus.");

        TEMPLATE_SNIPPETS.put("vsui_app", "include std/vsui.e as vsui\n\ninteger app = vsui:app(\"${1:Meine Anwendung}\", ${2:8089})\n\nfunction on_submit(sequence ctx)\n\tsequence name = vsui:val(ctx, \"name\")\n\treturn vsui:updates({vsui:set_val(\"out\", \"Hallo, \" & name)})\nend function\nvsui:on_click(app, \"btn_submit\", routine_id(\"on_submit\"))\n\nvsui:run(app)\n");
        TEMPLATE_DOCS.put("vsui_app", "### VS-UI Web-Anwendung Template\nStartet eine reaktive Browser-GUI mit DIN 5008 Steuerelementen und Event-Schleife.");

        TEMPLATE_SNIPPETS.put("thread_spawn", "include std/thread.e\n\nprocedure worker_task()\n\t${0}\nend procedure\nthread:spawn(routine_id(\"worker_task\"), {})\n");
        TEMPLATE_DOCS.put("thread_spawn", "### Loom Virtual Thread Template\nFührt eine Routine nebenläufig in einem leichtgewichtigen Java 25 Virtual Thread aus.");

        // Built-ins (selection of most frequent)
        addBuiltin("puts", "puts(integer fn, object text)", "Gibt einen Text oder Zeichencodes auf die Datei oder Konsole fn aus (1=stdout, 2=stderr).", List.of("fn", "text"));
        addBuiltin("printf", "printf(integer fn, sequence fmt, object args)", "Gibt formatierten Text gemäß Formatstring fmt aus.", List.of("fn", "fmt", "args"));
        addBuiltin("print", "print(integer fn, object x)", "Gibt eine vollständige Datenstruktur in Euphoria-Syntax aus.", List.of("fn", "x"));
        addBuiltin("length", "length(sequence s)", "Liefert die Anzahl der Elemente in der Sequenz s.", List.of("s"));
        addBuiltin("append", "append(sequence s, object item)", "Hängt ein Element als eigenständiges letztes Element an s an.", List.of("s", "item"));
        addBuiltin("prepend", "prepend(sequence s, object item)", "Fügt ein Element am Anfang von s ein.", List.of("s", "item"));
        addBuiltin("equal", "equal(object a, object b)", "Vergleicht a und b auf strukturelle Gleichheit (1 = gleich, 0 = ungleich).", List.of("a", "b"));
        addBuiltin("compare", "compare(object a, object b)", "Vergleicht a und b (-1: a < b, 0: gleich, 1: a > b).", List.of("a", "b"));
        addBuiltin("find", "find(object item, sequence s, integer start=1)", "Sucht das erste Vorkommen von item in s und liefert den 1-basierten Index (oder 0).", List.of("item", "s", "start"));
        addBuiltin("match", "match(sequence needle, sequence haystack, integer start=1)", "Sucht das Vorkommen einer Teilsequenz in haystack.", List.of("needle", "haystack", "start"));
        addBuiltin("routine_id", "routine_id(sequence name)", "Liefert die numerische Kennung einer Routine für dynamische Callbacks.", List.of("name"));
        addBuiltin("call_func", "call_func(integer id, sequence args)", "Ruft eine Funktion dynamisch über ihre routine_id auf.", List.of("id", "args"));
        addBuiltin("call_proc", "call_proc(integer id, sequence args)", "Ruft eine Prozedur dynamisch über ihre routine_id auf.", List.of("id", "args"));
        addBuiltin("command_line", "command_line()", "Liefert die Liste aller Aufrufparameter der Kommandozeile als Sequenz.", List.of());
        addBuiltin("getenv", "getenv(sequence varname)", "Liest den Wert einer Umgebungsvariable aus dem Betriebssystem.", List.of("varname"));
        addBuiltin("abort", "abort(integer exit_code)", "Beendet das Programm sofort mit dem angegebenen Exit-Code.", List.of("exit_code"));
        addBuiltin("power", "power(atom base, atom exp)", "Berechnet base hoch exp.", List.of("base", "exp"));
        addBuiltin("sqrt", "sqrt(atom x)", "Berechnet die Quadratwurzel aus x.", List.of("x"));
        addBuiltin("rand", "rand(integer max_val)", "Erzeugt eine Pseudozufallszahl zwischen 1 und max_val.", List.of("max_val"));
        addBuiltin("time", "time()", "Liefert die vergangene Systemzeit in Sekunden (mit Mikrosekundenauflösung).", List.of());
        addBuiltin("date", "date()", "Liefert aktuelles Datum/Uhrzeit als 8-teilige Sequenz {Jahr, Monat, Tag, Std, Min, Sek, Wochentag, Jahrestag}.", List.of());
        addBuiltin("system", "system(sequence cmd, integer mode=0)", "Führt einen Betriebssystembefehl in einer Subshell aus.", List.of("cmd", "mode"));
        addBuiltin("system_exec", "system_exec(sequence cmd, integer mode=0)", "Führt einen Betriebssystembefehl direkt aus und liefert den Exit-Code.", List.of("cmd", "mode"));
        addBuiltin("open", "open(sequence filename, sequence mode)", "Öffnet eine Datei (\"r\", \"w\", \"a\", \"rb\", \"wb\").", List.of("filename", "mode"));
        addBuiltin("close", "close(integer fn)", "Schließt ein geöffnetes Dateihandle.", List.of("fn"));
        addBuiltin("gets", "gets(integer fn)", "Liest die nächste Zeile aus der Datei fn inklusive Newline.", List.of("fn"));
        addBuiltin("getc", "getc(integer fn)", "Liest das nächste Zeichen (Byte) aus der Datei fn oder -1 bei EOF.", List.of("fn"));
    }

    private static void addBuiltin(String name, String sig, String desc, List<String> params) {
        BUILTIN_DOCS.put(name, new RoutineDoc(name, "", sig, desc, "", 0, params, 12)); // 12 = Function
    }

    /**
     * Finds the stdlib directory on disk.
     */
    public static Path findStdDir() {
        String[] candidates = {
            "eu_include/std",
            "../eu_include/std",
            "/home/volkix/prj/intpret/eu_include/std"
        };
        for (String c : candidates) {
            Path p = Path.of(c).toAbsolutePath().normalize();
            if (Files.isDirectory(p)) {
                return p;
            }
        }
        return null;
    }

    /**
     * Dynamically indexes all standard library files in eu_include/std/*.e.
     */
    private static void indexStandardLibrary() {
        Path stdDir = findStdDir();
        if (stdDir == null) return;

        try (var stream = Files.walk(stdDir, 2)) {
            stream.filter(p -> Files.isRegularFile(p) && p.toString().endsWith(".e")).forEach(p -> {
                try {
                    indexStdFile(p);
                } catch (Exception ignored) {}
            });
        } catch (Exception ignored) {}
    }

    private static void indexStdFile(Path file) throws Exception {
        List<String> lines = Files.readAllLines(file, StandardCharsets.UTF_8);
        String fileName = file.getFileName().toString();
        String defaultNs = fileName.substring(0, fileName.length() - 2); // e.g. "mcp.e" -> "mcp"
        String ns = defaultNs;

        Pattern nsPattern = Pattern.compile("(?i)^\\s*namespace\\s+([a-zA-Z0-9_]+)");
        Pattern routinePattern = Pattern.compile("(?i)^\\s*(public|export|global)?\\s*(function|procedure|type)\\s+([a-zA-Z0-9_]+)\\s*\\(([^)]*)\\)");
        Pattern constPattern = Pattern.compile("(?i)^\\s*(public|export|global)?\\s*constant\\s+([a-zA-Z0-9_]+)");

        StringBuilder docBuf = new StringBuilder();

        for (int l = 0; l < lines.size(); l++) {
            String line = lines.get(l);
            String trimmed = line.trim();

            if (trimmed.startsWith("--**") || trimmed.startsWith("--")) {
                String commentText = trimmed.replaceFirst("^--\\**\\s*", "");
                if (!commentText.startsWith("===") && !commentText.startsWith("---")) {
                    if (!docBuf.isEmpty()) docBuf.append("\n");
                    docBuf.append(commentText);
                }
                continue;
            }

            Matcher nsm = nsPattern.matcher(line);
            if (nsm.find()) {
                ns = nsm.group(1);
            }

            Matcher rm = routinePattern.matcher(line);
            if (rm.find()) {
                String type = rm.group(2).toLowerCase();
                String rName = rm.group(3);
                String paramsStr = rm.group(4).trim();

                List<String> pNames = new ArrayList<>();
                if (!paramsStr.isEmpty()) {
                    for (String part : paramsStr.split(",")) {
                        String clean = part.trim().split("=")[0].trim();
                        String[] words = clean.split("\\s+");
                        pNames.add(words[words.length - 1]);
                    }
                }

                String signature = String.format("%s:%s(%s)", ns, rName, paramsStr);
                String docText = docBuf.toString().trim();
                docBuf.setLength(0);

                int kind = type.equals("function") ? 12 : (type.equals("procedure") ? 6 : 5);
                RoutineDoc doc = new RoutineDoc(rName, ns, signature, docText, file.toAbsolutePath().toString(), l, pNames, kind);

                NAMESPACE_DOCS.computeIfAbsent(ns, k -> new ArrayList<>()).add(doc);
                GLOBAL_STD_DOCS.computeIfAbsent(rName.toLowerCase(), k -> new ArrayList<>()).add(doc);
                continue;
            }

            Matcher cm = constPattern.matcher(line);
            if (cm.find()) {
                String cName = cm.group(2);
                String signature = String.format("constant %s:%s", ns, cName);
                String docText = docBuf.toString().trim();
                docBuf.setLength(0);

                RoutineDoc doc = new RoutineDoc(cName, ns, signature, docText, file.toAbsolutePath().toString(), l, List.of(), 14);
                NAMESPACE_DOCS.computeIfAbsent(ns, k -> new ArrayList<>()).add(doc);
                GLOBAL_STD_DOCS.computeIfAbsent(cName.toLowerCase(), k -> new ArrayList<>()).add(doc);
                continue;
            }

            if (!trimmed.isEmpty()) {
                docBuf.setLength(0);
            }
        }
    }

    /**
     * Start the LSP JSON-RPC loop reading from standard input and writing to standard output.
     */
    public static void runStdio() {
        System.err.println("[EUPHORIX-LSP] Language Server 1.0 gestartet (bereit für NetBeans / VS Code).");
        try {
            InputStream in = System.in;
            OutputStream out = System.out;

            while (true) {
                JsonNode request = readMessage(in);
                if (request == null) break;

                handleMessage(request, out);
            }
        } catch (Exception e) {
            System.err.println("[EUPHORIX-LSP] Beendet: " + e.getMessage());
        }
    }

    private static JsonNode readMessage(InputStream in) throws Exception {
        int contentLength = -1;
        ByteArrayOutputStream lineBuf = new ByteArrayOutputStream();

        while (true) {
            int b = in.read();
            if (b < 0) return null; // EOF
            if (b == '\n') {
                String line = lineBuf.toString(StandardCharsets.US_ASCII).trim();
                lineBuf.reset();
                if (line.isEmpty()) {
                    break;
                }
                if (line.toLowerCase().startsWith("content-length:")) {
                    contentLength = Integer.parseInt(line.substring(15).trim());
                }
            } else if (b != '\r') {
                lineBuf.write(b);
            }
        }

        if (contentLength < 0) return null;
        byte[] payload = in.readNBytes(contentLength);
        if (payload.length < contentLength) return null;

        return MAPPER.readTree(payload);
    }

    private static void sendMessage(OutputStream out, JsonNode msg) throws Exception {
        byte[] bytes = MAPPER.writeValueAsBytes(msg);
        String header = "Content-Length: " + bytes.length + "\r\n\r\n";
        synchronized (out) {
            out.write(header.getBytes(StandardCharsets.US_ASCII));
            out.write(bytes);
            out.flush();
        }
    }

    private static void sendResponse(OutputStream out, JsonNode id, Object result) throws Exception {
        ObjectNode res = MAPPER.createObjectNode();
        res.put("jsonrpc", "2.0");
        res.set("id", id);
        res.set("result", MAPPER.valueToTree(result));
        sendMessage(out, res);
    }

    private static void sendNotification(OutputStream out, String method, Object params) throws Exception {
        ObjectNode note = MAPPER.createObjectNode();
        note.put("jsonrpc", "2.0");
        note.put("method", method);
        note.set("params", MAPPER.valueToTree(params));
        sendMessage(out, note);
    }

    private static void handleMessage(JsonNode msg, OutputStream out) throws Exception {
        String method = msg.path("method").asText("");
        JsonNode id = msg.path("id");
        JsonNode params = msg.path("params");

        switch (method) {
            case "initialize" -> handleInitialize(id, params, out);
            case "initialized" -> {} // client confirmation
            case "shutdown" -> sendResponse(out, id, null);
            case "exit" -> System.exit(0);

            case "textDocument/didOpen" -> {
                String uri = params.path("textDocument").path("uri").asText();
                String text = params.path("textDocument").path("text").asText();
                OPEN_DOCS.put(uri, text);
                diagnoseDocument(uri, text, out);
            }
            case "textDocument/didChange" -> {
                String uri = params.path("textDocument").path("uri").asText();
                JsonNode contentChanges = params.path("contentChanges");
                if (contentChanges.isArray() && !contentChanges.isEmpty()) {
                    String text = contentChanges.get(contentChanges.size() - 1).path("text").asText();
                    OPEN_DOCS.put(uri, text);
                    diagnoseDocument(uri, text, out);
                }
            }
            case "textDocument/didClose" -> {
                String uri = params.path("textDocument").path("uri").asText();
                OPEN_DOCS.remove(uri);
                ObjectNode p = MAPPER.createObjectNode();
                p.put("uri", uri);
                p.set("diagnostics", MAPPER.createArrayNode());
                sendNotification(out, "textDocument/publishDiagnostics", p);
            }

            case "textDocument/completion" -> handleCompletion(id, params, out);
            case "textDocument/signatureHelp" -> handleSignatureHelp(id, params, out);
            case "textDocument/hover" -> handleHover(id, params, out);
            case "textDocument/definition" -> handleDefinition(id, params, out);
            case "textDocument/documentSymbol" -> handleDocumentSymbol(id, params, out);
            case "textDocument/formatting" -> handleFormatting(id, params, out);

            default -> {
                if (!id.isMissingNode() && !id.isNull()) {
                    sendResponse(out, id, null);
                }
            }
        }
    }

    private static void handleInitialize(JsonNode id, JsonNode params, OutputStream out) throws Exception {
        ObjectNode capabilities = MAPPER.createObjectNode();
        capabilities.put("textDocumentSync", 1); // Full sync

        ObjectNode comp = MAPPER.createObjectNode();
        comp.put("resolveProvider", false);
        ArrayNode triggers = comp.putArray("triggerCharacters");
        triggers.add(":");
        triggers.add(".");
        triggers.add("%");
        triggers.add("/");
        triggers.add(" ");
        triggers.add("(");
        triggers.add("\"");
        capabilities.set("completionProvider", comp);

        ObjectNode sig = MAPPER.createObjectNode();
        ArrayNode sigTriggers = sig.putArray("triggerCharacters");
        sigTriggers.add("(");
        sigTriggers.add(",");
        capabilities.set("signatureHelpProvider", sig);

        capabilities.put("hoverProvider", true);
        capabilities.put("definitionProvider", true);
        capabilities.put("documentSymbolProvider", true);
        capabilities.put("documentFormattingProvider", true);

        ObjectNode serverInfo = MAPPER.createObjectNode();
        serverInfo.put("name", "euphorix-lsp");
        serverInfo.put("version", "1.0.0");

        ObjectNode result = MAPPER.createObjectNode();
        result.set("capabilities", capabilities);
        result.set("serverInfo", serverInfo);

        sendResponse(out, id, result);
    }

    public static String uriToPath(String uri) {
        if (uri == null || uri.isBlank()) return "";
        if (uri.startsWith("file:")) {
            try {
                return Path.of(URI.create(uri)).toAbsolutePath().toString();
            } catch (Exception e) {
                String s = uri;
                if (s.startsWith("file:///")) s = s.substring(7);
                else if (s.startsWith("file://")) s = s.substring(6);
                else if (s.startsWith("file:")) s = s.substring(5);
                try {
                    return Paths.get(s).toAbsolutePath().toString();
                } catch (Exception ex) {
                    return s;
                }
            }
        }
        return uri;
    }

    public static Path resolveIncludePath(String target, String currentDocPath) {
        if (target == null || target.isBlank()) return null;
        target = target.replace("\"", "").replace("'", "").trim();

        // 1. Check in stdlib
        Path stdDir = findStdDir();
        if (stdDir != null) {
            Path stdParent = stdDir.getParent();
            Path candidate = stdParent.resolve(target);
            if (Files.exists(candidate)) return candidate.toAbsolutePath().normalize();
            Path directStd = stdDir.resolve(target.startsWith("std/") ? target.substring(4) : target);
            if (Files.exists(directStd)) return directStd.toAbsolutePath().normalize();
        }

        // 2. Check relative to current document
        if (currentDocPath != null && !currentDocPath.isBlank()) {
            Path docFile = Path.of(currentDocPath);
            Path parent = docFile.getParent();
            if (parent != null) {
                Path localCandidate = parent.resolve(target);
                if (Files.exists(localCandidate)) return localCandidate.toAbsolutePath().normalize();
            }
        }

        // 3. Check current workspace
        Path wsCandidate = Path.of(target);
        if (Files.exists(wsCandidate)) return wsCandidate.toAbsolutePath().normalize();

        return null;
    }

    private static void diagnoseDocument(String uri, String text, OutputStream out) throws Exception {
        String fsPath = uriToPath(uri);
        Compiler compiler = new Compiler(text, fsPath);
        Bytecode.Program prog = new Bytecode.Program();
        boolean ok = compiler.compile(prog);

        ObjectNode p = MAPPER.createObjectNode();
        p.put("uri", uri);
        ArrayNode diags = p.putArray("diagnostics");

        if (!ok) {
            ObjectNode d = diags.addObject();
            String[] docLines = text.split("\r?\n", -1);
            int safeLine = Math.min(Math.max(0, compiler.errorLine - 1), Math.max(0, docLines.length - 1));
            String lineContent = (safeLine < docLines.length) ? docLines[safeLine] : "";
            int safeCol = Math.min(Math.max(0, compiler.errorCol - 1), lineContent.length());
            int endCol = Math.min(safeCol + 5, Math.max(safeCol + 1, lineContent.length()));

            ObjectNode range = d.putObject("range");
            ObjectNode start = range.putObject("start");
            start.put("line", safeLine);
            start.put("character", safeCol);
            ObjectNode end = range.putObject("end");
            end.put("line", safeLine);
            end.put("character", endCol);

            d.put("severity", 1); // 1 = Error
            d.put("source", "euphorix");
            d.put("message", compiler.errorRaw != null && !compiler.errorRaw.isBlank()
                    ? compiler.errorRaw : compiler.errorMessage());
        }

        sendNotification(out, "textDocument/publishDiagnostics", p);
    }

    private static void handleCompletion(JsonNode id, JsonNode params, OutputStream out) throws Exception {
        String uri = params.path("textDocument").path("uri").asText();
        int line = params.path("position").path("line").asInt();
        int character = params.path("position").path("character").asInt();

        String doc = OPEN_DOCS.getOrDefault(uri, "");
        String[] lines = doc.split("\r?\n", -1);
        String currentLine = (line >= 0 && line < lines.length) ? lines[line] : "";
        String prefixBeforeCursor = (character <= currentLine.length())
                ? currentLine.substring(0, character) : currentLine;

        String curWord = extractWordAt(currentLine, character).toLowerCase();
        ArrayNode items = MAPPER.createArrayNode();
        Set<String> seenLabels = new HashSet<>();

        // 0. Check if user typed "include ..."
        Matcher incMatcher = Pattern.compile("(?i)include\\s+[\"']?([a-zA-Z0-9_/\\.\\-]*)$").matcher(prefixBeforeCursor);
        if (incMatcher.find()) {
            String partial = incMatcher.group(1).toLowerCase();
            String[] stdIncludes = {
                "std/io.e", "std/vsui.e", "std/map.e", "std/json.e", "std/json_schema.e",
                "std/mcp.e", "std/rag.e", "std/llm.e", "std/gui.e", "std/thread.e", "std/channel.e",
                "std/task.e", "std/cron.e", "std/sqlite.e", "std/pgsql.e", "std/eds.e",
                "std/utf8.e", "std/xml.e", "std/excel.e", "std/csv.e", "std/pdf_report.e",
                "std/auth.e", "std/session.e", "std/sse.e", "std/socket.e", "std/net/dns.e",
                "std/net/url.e", "std/ui5.e", "std/sequence.e", "std/text.e", "std/regex.e",
                "std/math.e", "std/stats.e", "std/rand.e", "std/datetime.e", "std/filesys.e",
                "std/pipeio.e", "std/search.e", "std/sort.e", "std/console.e", "std/os.e",
                "std/unittest.e", "std/java.e", "std/jsondb.e"
            };
            for (String inc : stdIncludes) {
                if (partial.isEmpty() || inc.toLowerCase().startsWith(partial) || (inc.startsWith("std/") && inc.substring(4).toLowerCase().startsWith(partial))) {
                    ObjectNode item = items.addObject();
                    item.put("label", inc);
                    item.put("kind", 17); // 17 = File
                    item.put("detail", "Standardbibliothek Include");
                    item.put("insertText", inc);
                }
            }
        } else if (Pattern.compile("([a-zA-Z0-9_]+):([a-zA-Z0-9_]*)$").matcher(prefixBeforeCursor).find()) {
            // 1. Check if user typed "namespace:" (e.g. "mcp:", "rag:", "llm:", "vsui:", "map:", "json:")
            Matcher nsMatcher = Pattern.compile("([a-zA-Z0-9_]+):([a-zA-Z0-9_]*)$").matcher(prefixBeforeCursor);
            if (nsMatcher.find()) {
                String ns = nsMatcher.group(1);
                String partial = nsMatcher.group(2).toLowerCase();
                List<RoutineDoc> docs = NAMESPACE_DOCS.get(ns);
                if (docs != null) {
                    for (RoutineDoc r : docs) {
                        if (partial.isEmpty() || r.name().toLowerCase().startsWith(partial)) {
                            if (seenLabels.add(r.name())) {
                                ObjectNode item = items.addObject();
                                item.put("label", r.name());
                                item.put("kind", r.kind());
                                item.put("detail", r.signature());
                                item.put("documentation", r.desc());
                                item.put("insertText", r.name());
                            }
                        }
                    }
                }
            }
        } else {
            // 2. High-Value Templates & Snippets
            for (Map.Entry<String, String> entry : TEMPLATE_SNIPPETS.entrySet()) {
                String name = entry.getKey();
                if (seenLabels.add(name)) {
                    ObjectNode item = items.addObject();
                    item.put("label", name);
                    item.put("kind", 15); // 15 = Snippet
                    item.put("detail", "Euphorix Template: " + name);
                    item.put("documentation", TEMPLATE_DOCS.getOrDefault(name, ""));
                    item.put("insertTextFormat", 2); // 2 = Snippet
                    item.put("insertText", entry.getValue());
                }
            }

            // 3. Keywords with Snippets
            for (Map.Entry<String, String> entry : KEYWORD_DOCS.entrySet()) {
                String kw = entry.getKey();
                if (seenLabels.add(kw)) {
                    ObjectNode item = items.addObject();
                    item.put("label", kw);
                    item.put("kind", 14); // 14 = Keyword
                    item.put("detail", "Euphoria Schlüsselwort");
                    item.put("documentation", entry.getValue());
                    String snippet = KEYWORD_SNIPPETS.get(kw);
                    if (snippet != null) {
                        item.put("insertTextFormat", 2); // 2 = Snippet
                        item.put("insertText", snippet);
                    } else {
                        item.put("insertText", kw);
                    }
                }
            }

            // 4. Built-in functions
            for (RoutineDoc r : BUILTIN_DOCS.values()) {
                if (seenLabels.add(r.name())) {
                    ObjectNode item = items.addObject();
                    item.put("label", r.name());
                    item.put("kind", 3); // 3 = Function
                    item.put("detail", r.signature());
                    item.put("documentation", r.desc());
                    item.put("insertText", r.name());
                }
            }

            // 5. Standard Namespaces (mcp:, rag:, llm:, vsui:, map:, json:, etc.)
            for (String ns : NAMESPACE_DOCS.keySet()) {
                String label = ns + ":";
                if (seenLabels.add(label)) {
                    ObjectNode item = items.addObject();
                    item.put("label", label);
                    item.put("kind", 9); // 9 = Module
                    item.put("detail", "Standardmodul " + ns);
                    item.put("insertText", label);
                }
            }

            // 6. Document-local symbols (extract functions/procedures/types/constants from current file)
            Pattern userRoutinePattern = Pattern.compile("(?i)(public|export|global)?\\s*(function|procedure|type)\\s+([a-zA-Z0-9_]+)\\s*\\(([^)]*)\\)");
            Matcher m = userRoutinePattern.matcher(doc);
            while (m.find()) {
                String type = m.group(2).toLowerCase();
                String name = m.group(3);
                String args = m.group(4);
                if (seenLabels.add(name)) {
                    ObjectNode item = items.addObject();
                    item.put("label", name);
                    item.put("kind", type.equals("function") ? 3 : (type.equals("procedure") ? 2 : 5));
                    item.put("detail", type + " " + name + "(" + args + ")");
                    item.put("insertText", name);
                }
            }

            // Local constants
            Pattern constPattern = Pattern.compile("(?i)^\\s*(public|export|global)?\\s*constant\\s+([a-zA-Z0-9_]+)");
            for (String l : lines) {
                Matcher cm = constPattern.matcher(l);
                if (cm.find()) {
                    String cname = cm.group(2);
                    if (seenLabels.add(cname)) {
                        ObjectNode item = items.addObject();
                        item.put("label", cname);
                        item.put("kind", 21); // 21 = Constant
                        item.put("detail", "constant " + cname);
                        item.put("insertText", cname);
                    }
                }
            }

            // Local variables
            Pattern varPattern = Pattern.compile("(?i)^\\s*(public|export|global)?\\s*(integer|atom|sequence|object)\\s+([a-zA-Z0-9_,\\s=]+)");
            for (String l : lines) {
                Matcher vm = varPattern.matcher(l);
                if (vm.find()) {
                    String vtype = vm.group(2).toLowerCase();
                    String decls = vm.group(3);
                    for (String part : decls.split(",")) {
                        String vname = part.split("=")[0].trim();
                        if (!vname.isEmpty() && seenLabels.add(vname) && Character.isLetter(vname.charAt(0))) {
                            ObjectNode item = items.addObject();
                            item.put("label", vname);
                            item.put("kind", 6); // 6 = Variable
                            item.put("detail", vtype + " " + vname);
                            item.put("insertText", vname);
                        }
                    }
                }
            }

            // 7. Global Standard Library Routines (matching typed word or common utilities)
            int stdCount = 0;
            for (Map.Entry<String, List<RoutineDoc>> entry : GLOBAL_STD_DOCS.entrySet()) {
                String rNameLower = entry.getKey();
                if (!curWord.isEmpty() && !rNameLower.startsWith(curWord)) {
                    continue;
                }
                for (RoutineDoc r : entry.getValue()) {
                    if (seenLabels.add(r.name())) {
                        ObjectNode item = items.addObject();
                        item.put("label", r.name());
                        item.put("kind", r.kind());
                        item.put("detail", r.signature() + " (std/" + r.ns() + ".e)");
                        if (r.desc() != null && !r.desc().isBlank()) {
                            String shortDesc = r.desc().length() > 250 ? r.desc().substring(0, 247) + "..." : r.desc();
                            item.put("documentation", shortDesc);
                        }
                        item.put("insertText", r.name());
                        stdCount++;
                        if (stdCount >= 60) break;
                    }
                }
                if (stdCount >= 60) break;
            }
        }

        ObjectNode result = MAPPER.createObjectNode();
        result.put("isIncomplete", false);
        result.set("items", items);
        sendResponse(out, id, result);
    }

    private static void handleSignatureHelp(JsonNode id, JsonNode params, OutputStream out) throws Exception {
        String uri = params.path("textDocument").path("uri").asText();
        int line = params.path("position").path("line").asInt();
        int character = params.path("position").path("character").asInt();

        String doc = OPEN_DOCS.getOrDefault(uri, "");
        String[] lines = doc.split("\r?\n", -1);
        if (line < 0 || line >= lines.length) {
            sendResponse(out, id, null);
            return;
        }

        String curLine = lines[line];
        if (character > curLine.length()) character = curLine.length();
        String prefix = curLine.substring(0, character);

        // Scan backwards to find the opening '(' of enclosing call
        int parenDepth = 0;
        int commaCount = 0;
        int openParenIdx = -1;
        for (int i = prefix.length() - 1; i >= 0; i--) {
            char ch = prefix.charAt(i);
            if (ch == ')') {
                parenDepth++;
            } else if (ch == '(') {
                if (parenDepth > 0) {
                    parenDepth--;
                } else {
                    openParenIdx = i;
                    break;
                }
            } else if (ch == ',' && parenDepth == 0) {
                commaCount++;
            }
        }

        if (openParenIdx <= 0) {
            sendResponse(out, id, null);
            return;
        }

        int fnEnd = openParenIdx;
        while (fnEnd > 0 && Character.isWhitespace(prefix.charAt(fnEnd - 1))) {
            fnEnd--;
        }
        int fnStart = fnEnd;
        while (fnStart > 0 && (Character.isLetterOrDigit(prefix.charAt(fnStart - 1)) || prefix.charAt(fnStart - 1) == '_' || prefix.charAt(fnStart - 1) == ':')) {
            fnStart--;
        }
        String fullFnName = prefix.substring(fnStart, fnEnd).trim();
        if (fullFnName.isEmpty()) {
            sendResponse(out, id, null);
            return;
        }

        RoutineDoc found = findRoutine(fullFnName, doc, uri);
        if (found == null) {
            sendResponse(out, id, null);
            return;
        }

        ObjectNode sigHelp = MAPPER.createObjectNode();
        ArrayNode sigs = sigHelp.putArray("signatures");
        ObjectNode sig = sigs.addObject();
        sig.put("label", found.signature());
        if (found.desc() != null && !found.desc().isBlank()) {
            ObjectNode docNode = sig.putObject("documentation");
            docNode.put("kind", "markdown");
            docNode.put("value", found.desc());
        }

        ArrayNode paramsArr = sig.putArray("parameters");
        for (String p : found.paramNames()) {
            ObjectNode paramNode = paramsArr.addObject();
            paramNode.put("label", p);
        }

        sigHelp.put("activeSignature", 0);
        sigHelp.put("activeParameter", Math.min(commaCount, Math.max(0, found.paramNames().size() - 1)));

        sendResponse(out, id, sigHelp);
    }

    private static void handleHover(JsonNode id, JsonNode params, OutputStream out) throws Exception {
        String uri = params.path("textDocument").path("uri").asText();
        int line = params.path("position").path("line").asInt();
        int character = params.path("position").path("character").asInt();

        String doc = OPEN_DOCS.getOrDefault(uri, "");
        String[] lines = doc.split("\r?\n", -1);
        if (line < 0 || line >= lines.length) {
            sendResponse(out, id, null);
            return;
        }

        String curLine = lines[line];
        String word = extractWordAt(curLine, character);
        if (word.isEmpty()) {
            sendResponse(out, id, null);
            return;
        }

        String markdown = null;

        // Check namespace prefix: "mcp:server", "vsui:numinput"
        String ns = extractNamespacePrefix(curLine, character);
        if (ns != null && NAMESPACE_DOCS.containsKey(ns)) {
            for (RoutineDoc r : NAMESPACE_DOCS.get(ns)) {
                if (r.name().equals(word)) {
                    markdown = String.format("### `%s`\n\n%s\n\n*Definiert in `std/%s.e`*", r.signature(), r.desc(), ns);
                    break;
                }
            }
        }

        if (markdown == null && BUILTIN_DOCS.containsKey(word)) {
            RoutineDoc r = BUILTIN_DOCS.get(word);
            markdown = String.format("### `%s`\n\n%s\n\n*Euphoria Built-in*", r.signature(), r.desc());
        }

        if (markdown == null && GLOBAL_STD_DOCS.containsKey(word.toLowerCase())) {
            List<RoutineDoc> matches = GLOBAL_STD_DOCS.get(word.toLowerCase());
            if (!matches.isEmpty()) {
                RoutineDoc r = matches.get(0);
                markdown = String.format("### `%s`\n\n%s\n\n*Standardbibliothek `std/%s.e`*", r.signature(), r.desc(), r.ns());
            }
        }

        if (markdown == null && KEYWORD_DOCS.containsKey(word)) {
            markdown = KEYWORD_DOCS.get(word);
        }

        if (markdown == null && NAMESPACE_DOCS.containsKey(word)) {
            markdown = String.format("### Standardmodul `%s`\n\nStellt %d Routinen und Konstanten bereit.", word, NAMESPACE_DOCS.get(word).size());
        }

        // Search user-defined routine in doc
        if (markdown == null) {
            Pattern p = Pattern.compile("(?i)(public|export|global)?\\s*(function|procedure|type)\\s+" + Pattern.quote(word) + "\\s*\\(([^)]*)\\)");
            Matcher m = p.matcher(doc);
            if (m.find()) {
                markdown = String.format("### `%s %s(%s)`\n\n*Im aktuellen Dokument deklariert*",
                        m.group(2), word, m.group(3));
            }
        }

        if (markdown != null) {
            ObjectNode hover = MAPPER.createObjectNode();
            ObjectNode contents = hover.putObject("contents");
            contents.put("kind", "markdown");
            contents.put("value", markdown);
            sendResponse(out, id, hover);
        } else {
            sendResponse(out, id, null);
        }
    }

    private static void handleDefinition(JsonNode id, JsonNode params, OutputStream out) throws Exception {
        String uri = params.path("textDocument").path("uri").asText();
        int line = params.path("position").path("line").asInt();
        int character = params.path("position").path("character").asInt();

        String doc = OPEN_DOCS.getOrDefault(uri, "");
        String[] lines = doc.split("\r?\n", -1);
        if (line < 0 || line >= lines.length) {
            sendResponse(out, id, null);
            return;
        }

        String curLine = lines[line];

        // 1. Check if cursor is on an include path: "include std/mcp.e" or "include helper.e"
        Matcher incMatcher = Pattern.compile("(?i)include\\s+[\"']?([a-zA-Z0-9_/\\.\\-]+)[\"']?").matcher(curLine);
        if (incMatcher.find()) {
            int incStart = incMatcher.start(1);
            int incEnd = incMatcher.end(1);
            if (character >= incStart && character <= incEnd) {
                String target = incMatcher.group(1);
                Path resolved = resolveIncludePath(target, uriToPath(uri));
                if (resolved != null && Files.exists(resolved)) {
                    ObjectNode loc = MAPPER.createObjectNode();
                    loc.put("uri", resolved.toUri().toString());
                    ObjectNode range = loc.putObject("range");
                    ObjectNode start = range.putObject("start");
                    start.put("line", 0);
                    start.put("character", 0);
                    ObjectNode end = range.putObject("end");
                    end.put("line", 0);
                    end.put("character", 0);
                    sendResponse(out, id, loc);
                    return;
                }
            }
        }

        String word = extractWordAt(curLine, character);
        if (word.isEmpty()) {
            sendResponse(out, id, null);
            return;
        }

        // 2. Check current document
        Pattern p = Pattern.compile("(?i)^\\s*(public|export|global)?\\s*(function|procedure|type|constant|integer|atom|sequence|object)\\s+.*\\b" + Pattern.quote(word) + "\\b");
        for (int l = 0; l < lines.length; l++) {
            Matcher m = p.matcher(lines[l]);
            if (m.find()) {
                ObjectNode loc = MAPPER.createObjectNode();
                loc.put("uri", uri);
                ObjectNode range = loc.putObject("range");
                ObjectNode start = range.putObject("start");
                start.put("line", l);
                start.put("character", m.start());
                ObjectNode end = range.putObject("end");
                end.put("line", l);
                end.put("character", m.end());
                sendResponse(out, id, loc);
                return;
            }
        }

        // 3. Check standard library
        String ns = extractNamespacePrefix(curLine, character);
        String searchKey = (ns != null && !ns.isEmpty()) ? ns + ":" + word : word;
        RoutineDoc stdDoc = findRoutine(searchKey, doc, uri);
        if (stdDoc != null && stdDoc.filePath() != null && !stdDoc.filePath().isBlank()) {
            Path stdPath = Path.of(stdDoc.filePath());
            if (Files.exists(stdPath)) {
                ObjectNode loc = MAPPER.createObjectNode();
                loc.put("uri", stdPath.toUri().toString());
                ObjectNode range = loc.putObject("range");
                ObjectNode start = range.putObject("start");
                start.put("line", Math.max(0, stdDoc.line()));
                start.put("character", 0);
                ObjectNode end = range.putObject("end");
                end.put("line", Math.max(0, stdDoc.line()));
                end.put("character", 20);
                sendResponse(out, id, loc);
                return;
            }
        }

        sendResponse(out, id, null);
    }

    private static void handleDocumentSymbol(JsonNode id, JsonNode params, OutputStream out) throws Exception {
        String uri = params.path("textDocument").path("uri").asText();
        String doc = OPEN_DOCS.getOrDefault(uri, "");
        String[] lines = doc.split("\r?\n", -1);

        ArrayNode symbols = MAPPER.createArrayNode();
        Pattern p = Pattern.compile("(?i)^\\s*(public|export|global)?\\s*(function|procedure|type|constant|enum)\\s+([a-zA-Z0-9_]+)");

        for (int l = 0; l < lines.length; l++) {
            Matcher m = p.matcher(lines[l]);
            if (m.find()) {
                String type = m.group(2).toLowerCase();
                String name = m.group(3);
                int kind = switch (type) {
                    case "function" -> 12; // Function
                    case "procedure" -> 6; // Method
                    case "type" -> 5;      // Class
                    case "constant" -> 14; // Constant
                    case "enum" -> 10;     // Enum
                    default -> 13;         // Variable
                };

                ObjectNode s = symbols.addObject();
                s.put("name", name);
                s.put("kind", kind);
                s.put("detail", type);

                ObjectNode range = s.putObject("range");
                ObjectNode start = range.putObject("start");
                start.put("line", l);
                start.put("character", 0);
                ObjectNode end = range.putObject("end");
                end.put("line", l);
                end.put("character", lines[l].length());

                s.set("selectionRange", range);
            }
        }

        sendResponse(out, id, symbols);
    }

    private static void handleFormatting(JsonNode id, JsonNode params, OutputStream out) throws Exception {
        String uri = params.path("textDocument").path("uri").asText();
        JsonNode options = params.path("options");
        int tabSize = options.path("tabSize").asInt(4);
        boolean insertSpaces = options.path("insertSpaces").asBoolean(true);
        String indentStr = insertSpaces ? " ".repeat(tabSize) : "\t";

        String doc = OPEN_DOCS.getOrDefault(uri, "");
        String[] lines = doc.split("\r?\n", -1);

        StringBuilder formatted = new StringBuilder();
        int currentIndent = 0;

        for (int i = 0; i < lines.length; i++) {
            String raw = lines[i];
            String trimmed = raw.trim();

            if (trimmed.isEmpty()) {
                formatted.append("\n");
                continue;
            }

            String lower = trimmed.toLowerCase();
            boolean dedentThis = false;
            if (lower.startsWith("end ") || lower.equals("end") ||
                lower.startsWith("else") || lower.startsWith("elsif ") ||
                lower.startsWith("case ") || lower.startsWith("case\t") ||
                lower.equals("case") || lower.startsWith("until ") ||
                lower.startsWith("entry")) {
                dedentThis = true;
            }

            if (dedentThis && currentIndent > 0) {
                currentIndent--;
            }

            for (int k = 0; k < currentIndent; k++) {
                formatted.append(indentStr);
            }
            formatted.append(trimmed).append("\n");

            boolean indentNext = false;
            if (lower.startsWith("function ") || lower.startsWith("procedure ") || lower.startsWith("type ") ||
                lower.startsWith("public function ") || lower.startsWith("public procedure ") || lower.startsWith("public type ") ||
                lower.startsWith("export function ") || lower.startsWith("export procedure ") || lower.startsWith("export type ") ||
                lower.startsWith("global function ") || lower.startsWith("global procedure ") || lower.startsWith("global type ") ||
                (lower.startsWith("if ") && lower.endsWith("then")) ||
                (lower.startsWith("elsif ") && lower.endsWith("then")) ||
                lower.equals("else") ||
                (lower.startsWith("while ") && lower.endsWith("do")) ||
                (lower.startsWith("for ") && lower.endsWith("do")) ||
                lower.equals("loop") ||
                (lower.startsWith("switch ") && lower.contains("do")) ||
                (lower.startsWith("case ") && lower.endsWith("then"))) {
                indentNext = true;
            }

            if (indentNext) {
                currentIndent++;
            }
        }

        String resText = formatted.toString();
        if (!doc.endsWith("\n") && resText.endsWith("\n")) {
            resText = resText.substring(0, resText.length() - 1);
        }

        ObjectNode edit = MAPPER.createObjectNode();
        ObjectNode range = edit.putObject("range");
        ObjectNode start = range.putObject("start");
        start.put("line", 0);
        start.put("character", 0);
        ObjectNode end = range.putObject("end");
        end.put("line", Math.max(0, lines.length));
        end.put("character", 0);
        edit.put("newText", resText);

        ArrayNode edits = MAPPER.createArrayNode();
        edits.add(edit);

        sendResponse(out, id, edits);
    }

    private static RoutineDoc findRoutine(String key, String currentDoc, String uri) {
        if (key.contains(":")) {
            String[] parts = key.split(":", 2);
            String ns = parts[0];
            String rName = parts[1];
            List<RoutineDoc> docs = NAMESPACE_DOCS.get(ns);
            if (docs != null) {
                for (RoutineDoc r : docs) {
                    if (r.name().equalsIgnoreCase(rName)) return r;
                }
            }
        } else {
            if (BUILTIN_DOCS.containsKey(key)) {
                return BUILTIN_DOCS.get(key);
            }
            List<RoutineDoc> stdMatches = GLOBAL_STD_DOCS.get(key.toLowerCase());
            if (stdMatches != null && !stdMatches.isEmpty()) {
                return stdMatches.get(0);
            }

            // Local search
            Pattern p = Pattern.compile("(?i)(public|export|global)?\\s*(function|procedure|type)\\s+" + Pattern.quote(key) + "\\s*\\(([^)]*)\\)");
            Matcher m = p.matcher(currentDoc);
            if (m.find()) {
                String type = m.group(2).toLowerCase();
                String args = m.group(3).trim();
                List<String> pNames = new ArrayList<>();
                if (!args.isEmpty()) {
                    for (String part : args.split(",")) {
                        String clean = part.trim().split("=")[0].trim();
                        String[] words = clean.split("\\s+");
                        pNames.add(words[words.length - 1]);
                    }
                }
                String sig = String.format("%s %s(%s)", type, key, args);
                return new RoutineDoc(key, "", sig, "Im aktuellen Dokument deklariert", uriToPath(uri), 0, pNames, type.equals("function") ? 12 : 6);
            }
        }
        return null;
    }

    private static String extractNamespacePrefix(String curLine, int character) {
        if (curLine == null || character <= 0 || character > curLine.length()) return null;
        int colonIdx = curLine.lastIndexOf(':', character);
        if (colonIdx > 0) {
            int nsStart = colonIdx - 1;
            while (nsStart >= 0 && (Character.isLetterOrDigit(curLine.charAt(nsStart)) || curLine.charAt(nsStart) == '_')) {
                nsStart--;
            }
            return curLine.substring(nsStart + 1, colonIdx);
        }
        return null;
    }

    private static String extractWordAt(String line, int pos) {
        if (line == null || line.isEmpty() || pos < 0 || pos > line.length()) return "";
        int start = Math.min(pos, line.length() - 1);
        while (start >= 0 && (Character.isLetterOrDigit(line.charAt(start)) || line.charAt(start) == '_')) {
            start--;
        }
        start++;
        int end = Math.min(pos, line.length());
        while (end < line.length() && (Character.isLetterOrDigit(line.charAt(end)) || line.charAt(end) == '_')) {
            end++;
        }
        return (start < end) ? line.substring(start, end) : "";
    }
}
