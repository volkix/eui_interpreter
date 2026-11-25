# Euphorix 1.0 – Next-Gen VM for OpenEuphoria

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Java 25](https://img.shields.io/badge/Java-25%20(Loom%20%7C%20FFM)-orange.svg)](https://openjdk.org/)
[![Language: OpenEuphoria](https://img.shields.io/badge/Language-OpenEuphoria%20(Procedural)-indigo.svg)](https://openeuphoria.org)
[![Platform](https://img.shields.io/badge/Platform-Linux%2064--bit%20%7C%20Windows-green.svg)]()
[![Tests](https://img.shields.io/badge/Tests-100%25%20Passing-brightgreen.svg)]()

> **About the Language:** [OpenEuphoria](https://openeuphoria.org) is an elegant, purely **procedural programming language with a remarkably simple, intuitive syntax** and powerful dynamic *sequences* as its core data structure. Without the cognitive overhead and boilerplate of complex object-oriented hierarchies, programs remain readable, predictable, and exceptionally fast to write.
>
> **About Euphorix:** **Euphorix** is an independent, clean-room high-performance Virtual Machine written in Java 25. It natively interprets the OpenEuphoria 4.x language and standard libraries, while seamlessly incorporating modern enterprise capabilities: millions of **Java 25 Loom Virtual Threads**, lock-free **Go-style CSP Channels**, an integrated **High-Density Web-UI framework (VS-UI)**, native **SQLite 3 & PostgreSQL** database drivers, **RFC 9535 JSONPath**, **W3C XPath 1.0**, and zero-overhead Java interop.

Available as both a lightweight executable wrapper (`euphorix` / `euphorix.jar`) and a **completely self-contained 53 MB single-binary** (`euphorix-standalone`) requiring no pre-installed Java or external runtime.

---

## 📖 Documentation & Tutorials

* 🇩🇪 **[HANDBUCH.md](HANDBUCH.md)** & **[HANDBUCH.pdf](website/downloads/HANDBUCH.pdf)** – Vollständiges deutschsprachiges Handbuch (16 Kapitel, 886 Standardroutinen, KI-Agenten, MCP, RAG, Architektur & Tutorials).
* 🇬🇧 **[MANUAL.md](MANUAL.md)** & **[MANUAL.pdf](website/downloads/MANUAL.pdf)** – Comprehensive English User & Developer Manual (16 chapters, complete standard library reference, AI agents, MCP & RAG).
* 📚 **[tutorial/](tutorial/)** & **[website/tutorial.html](website/tutorial.html)** – **12 praxisnahe Kapitel** mit ausführlich erklärten, 100% lauffähigen Codebeispielen für alle Standard-Include-Dateien (`std/*.e`).
* 🌐 **[website/](website/)** – Statische, produktionsfertige Präsentations- und Dokumentations-Webseite für Webserver (z. B. **lighttpd**), inklusive konfigurierbarem Impressum & DSGVO-Datenschutz (`make website`).

---

## 🚀 Key Highlights & Architecture

* **Procedural Programming & Clear Syntax**:
  * Purely procedural language specification based on [openeuphoria.org](https://openeuphoria.org).
  * First-class, dynamically sized, 1-based **Sequences** (`s[2..$-1]`) replace convoluted object boilerplate.
* **Clean-Room Register-Based VM**:
  * 65,536 virtual registers with Copy-on-Write (CoW) memory semantics.
  * Tagged values with 48-bit fast integers and 64-bit IEEE-754 floating point numbers.
* **High-Density Web-UI Framework (`std/vsui.e`)**:
  * Integrated, self-contained business web framework with local assets (`./html/`).
  * Sticky table headers, responsive mobile card view, interactive modals, tabs, splitters, and flicker-free reactive JSON patches (`vsui:updates()`) without full page reloads.
  * Enterprise alternative: SAP UI5 Web Components 2.29 (`std/ui5.e`).
* **Java 25 Loom Concurrency**:
  * **Virtual Threads**: Non-blocking concurrency across CPU cores via Java 25 (`thread:spawn`, `thread:async`, `thread:await`).
  * **Go-Style CSP Channels**: Thread-safe, lock-free message passing queues between parallel threads (`std/channel.e`).
* **Enterprise Database Engines**:
  * **SQLite 3.47**: Statically linked via JDBC (`std/sqlite.e`) with in-memory (`:memory:`) support, parameterized queries, and transactions.
  * **PostgreSQL 42.7**: High-performance enterprise database driver (`std/pgsql.e`).
  * **EDS (Euphoria Database System)**: Ultra-fast native NoSQL key-value & record database (`std/eds.e`).
* **Structured Data & Protocols**:
  * **UTF-8 Engine**: Native multibyte Unicode string casing, slicing, and codepoint analysis (`std/utf8.e`).
  * **JSON & JSONPath**: Fast JSON decoding, RFC 9535 JSONPath querying, and JSON Schema Draft 2020-12 validation (`std/json.e`, `std/json_schema.e`).
  * **XML**: DOM parser, W3C XPath 1.0 evaluations, and XSD schema validation (`std/xml.e`).
  * **HTTP Client & Microservice Server**: Built-in REST client and microservice HTTP server (`std/http.e`, `std/socket.e`, `std/net/url.e`).
* **Java Interoperability & Desktop GUI**:
  * Seamless reflection-free JDK 25 interop (`std/java.e`).
  * Desktop GUI with Swing/AWT and FlatLaf dark/light themes (`std/gui.e`).

---

## 📦 Quick Start

### 1. Interactive REPL
```bash
# Launch interactive REPL
./euphorix
```

### 2. Run Scripts
```bash
# Linux (with Java 25 installed)
./euphorix my_script.ex
# or short:
./eux my_script.ex

# Linux (Standalone single-binary, zero dependencies)
./euphorix-standalone my_script.ex

# Windows
euphorix.cmd my_script.ex
```

### 3. Run the Complete Tutorial Suite (12 Chapters)
```bash
./euphorix tutorial/alle_beispiele_ausfuehren.ex
```

### 4. Run the High-Density Web-UI Demo
```bash
./euphorix demo/vsui_demo.ex
# Open in browser: http://localhost:8089/
```

### 5. Build the Documentation Website & PDFs
```bash
make website
# Generates website/ ready to be copied to lighttpd:
# scp -r website/* user@server:/var/www/html/
```

---

## 💡 Code Examples

### 1. High-Density Web-UI with Reactive Patches (`std/vsui.e`)
```euphoria
include std/vsui.e as vsui

integer app = vsui:app("ERP Cockpit", 8089)

function on_speichern(sequence ctx)
    sequence kdnr = vsui:val(ctx, "txt_kdnr")
    sequence firma = vsui:val(ctx, "txt_firma")

    -- Reactive patch: updates UI without full page reload
    return vsui:updates({
        vsui:grid_set_data("grid_kunden", {{kdnr, firma, "Aktiv"}}),
        vsui:clear_form("form_kunden"),
        vsui:toast_show("Kunde erfolgreich angelegt!", vsui:TOAST_SUCCESS)
    })
end function

vsui:on_click(app, "btn_save", routine_id("on_speichern"))
vsui:run(app)
```

### 2. Concurrency: Loom Virtual Threads & CSP Channels
```euphoria
include std/thread.e as thread
include std/channel.e as chan

integer postfach = chan:new(10)

procedure worker(integer id)
    for i = 1 to 5 do
        chan:send(postfach, sprintf("Auftrag #%d von Worker %d", {i, id}))
    end for
end procedure

-- Spawn 50 lightweight virtual threads
for w = 1 to 50 do
    thread:spawn(routine_id("worker"), {w})
end for

-- Read messages from channel
for m = 1 to 250 do
    printf(1, "Empfangen: %s\n", {chan:read(postfach)})
end for
chan:close(postfach)
```

### 3. SQLite Database & RFC 9535 JSONPath
```euphoria
include std/sqlite.e as sqlite
include std/json.e as json

integer db = sqlite:open(":memory:")
sqlite:exec(db, "CREATE TABLE artikel (sku TEXT, titel TEXT, preis REAL, lager INT);")
sqlite:exec(db, "INSERT INTO artikel VALUES (?, ?, ?, ?);", {"SSD-2TB", "NVMe SSD", 129.90, 15})
sqlite:exec(db, "INSERT INTO artikel VALUES (?, ?, ?, ?);", {"RAM-32G", "DDR5 RAM", 89.50, 0})

sequence rows = sqlite:query_assoc(db, "SELECT * FROM artikel;")
object doc = json:decode(json:encode(rows))

-- JSONPath query: select titles of items in stock
sequence auf_lager = json:jsonpath(doc, "$[?(@.lager > 0)].titel")
printf(1, "Auf Lager: %s\n", {auf_lager[1]})
sqlite:close(db)
```

---

## 🛠️ Build & Verification

```bash
# 1. Build Fat-JAR (euphorix.jar) and Linux launcher wrapper
make

# 2. Build completely self-contained single-binary with bundled minimal JRE (53 MB)
make standalone

# 3. Run the complete automated test suite (100% passing)
make test

# 4. Generate documentation website, interactive tutorial & publication PDFs
make website
```

---

## 📁 Repository Structure

```
├── HANDBUCH.md                  # Vollständiges deutsches Handbuch (15 Kapitel, 861 Routinen)
├── MANUAL.md                    # Comprehensive English Developer Manual (15 chapters)
├── README.md                    # Project overview & architectural guide
├── Makefile                     # Build, test, standalone & website automation
├── pom.xml                      # Maven build descriptor (Java 25, SQLite, PostgreSQL, FlatLaf)
├── euphorix (eui-java, eux)     # Linux executable launcher & aliases
├── euphorix.cmd / .bat          # Windows batch launchers
├── euphorix.jar (eui.jar)       # Executable Fat-JAR (19 MB)
├── euphorix-standalone          # Self-extracting single-binary with minimal JRE (53 MB)
│
├── html/                        # Integrated static UI assets (CSS, JS, icons)
├── eu_include/                  # Standard library include files (OpenEuphoria compatible)
│   ├── std/
│   │   ├── vsui.e               # High-Density Web-UI framework (VS-UI)
│   │   ├── ui5.e                # SAP UI5 Web Components 2.29
│   │   ├── thread.e             # Java 25 Loom Virtual Threads & Async/Await
│   │   ├── channel.e            # Communicating Sequential Processes (CSP Channels)
│   │   ├── sqlite.e             # Embedded SQLite 3 database engine
│   │   ├── pgsql.e              # Native PostgreSQL driver
│   │   ├── eds.e                # Euphoria Database System (native NoSQL engine)
│   │   ├── json.e / json_schema.e # JSON & RFC 9535 JSONPath, Draft 2020-12 Validator
│   │   ├── xml.e                # XML DOM, W3C XPath 1.0 & XSD Validator
│   │   ├── http.e / socket.e    # HTTP/REST Client & Microservice Server
│   │   ├── sequence.e / map.e   # Sequences, Collections, Hash-Maps & Stacks
│   │   ├── text.e / regex.e     # String formatting & PCRE regular expressions
│   │   ├── datetime.e           # Date, time & calendar calculations
│   │   ├── java.e / gui.e       # JDK 25 interop & Swing/FlatLaf Desktop GUI
│   │   └── ...                  # All 74 standard include files
│   └── euphoria/                # Tokenizer, keywords, debug & compiler modules
│
├── tutorial/                    # 12 runnable tutorial chapters with German explanations
│   ├── 01_datenstrukturen.ex    # Sequenzen, Slicing, Maps, Stacks, Sort, Search, Serialize
│   ├── 02_text_und_regex.ex     # Strings, Formatierung, Regex, UTF-8, Wildcards, Pretty
│   ├── 03_dateisystem_und_io.ex # Datei-IO, Filesystem-Checks, Pipes
│   ├── 04_mathematik_und_statistik.ex # Mathe, Potenzen, Statistik, Primzahlen, Scinot, Fenv
│   ├── 05_datum_und_uhrzeit.ex  # Timestamps, ISO-Formatierung, Fristen, Differenzen
│   ├── 06_json_und_xml.ex       # JSON, JSONPath, Schema-Validierung, XML/XPath
│   ├── 07_datenbanken.ex        # SQLite Transaktionen, PostgreSQL, EDS NoSQL DB
│   ├── 08_netzwerk_und_web.ex   # URLs, HTTP-REST Client/Server, Sockets, DNS
│   ├── 09_nebenlaeufigkeit.ex   # Loom Virtual Threads, CSP Channels, Tasks
│   ├── 10_web_und_gui.ex        # VS-UI Web-Anwendung, SAP UI5, Swing GUI
│   ├── 11_system_und_cli.ex     # OS-Umgebung, ANSI-Konsole, CLI-Options-Parser
│   ├── 12_interop_und_testing.ex# Java JDK 25, Hex, Base64, Hashes, Memory & Testing
│   └── alle_beispiele_ausfuehren.ex # Master test runner executing all 12 chapters
│
├── website/                     # Production-ready static website (lighttpd ready)
│   ├── index.html               # Main website with feature matrix, code tabs & downloads
│   ├── tutorial.html            # Interactive library cookbook with live search & filter
│   ├── impressum.html           # Centralized legal notice & GDPR privacy policy
│   ├── css/style.css            # Responsive, dark/navy themed stylesheet
│   ├── js/main.js               # Search filter, code copy & tab controller
│   ├── downloads/               # Self-contained binaries, JAR, PDFs & tutorial code
│   └── lighttpd_sample.conf     # Server configuration template for lighttpd
│
├── website_config.json          # Central configuration for site metadata, downloads & legal info
├── tools/                       # Build tools & generators
│   ├── build_website.ex         # Native Euphoria website builder (`make website`)
│   ├── generate_tutorial.py     # Tutorial HTML generator
│   ├── generate_pdf.py          # Headless Chrome PDF manual generator
│   └── build_standalone.sh      # Minimal JRE bundler via jlink
│
├── java/src/main/java/eu/       # Java 25 Register VM implementation
├── demo/                        # GUI & Web-UI interactive demonstrations
├── examples/                    # REST microservices, database, XML, and stdlib examples
└── tests/                       # Automated regression & unit test suite (100% passing)
```

---

## ⚖️ License

This project is licensed under the **GNU General Public License v3.0 (GPLv3)**.  
See the [LICENSE](LICENSE) file for the full license text.
