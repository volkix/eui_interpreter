# Euphorix – Vollständige Reproduktionsanleitung (Playbook & Guide)

Dieses Dokument beschreibt die Architektur, Voraussetzungen und alle manuellen sowie automatisierten Schritte, um das Projekt **Euphorix** (den modernen, hochperformanten OpenEuphoria-kompatiblen Interpreter auf Basis der Java 25 VM) von Grund auf neu zu erstellen, zu paketieren, zu testen und zu dokumentieren.

Zusätzlich steht das automatisierte Skript [REPRODUCE.sh](file:///home/volkix/prj/intpret/REPRODUCE.sh) bereit, welches alle Schritte in einem einzigen Durchlauf ausführt.

---

## 1. Systemvoraussetzungen

### Benötigte Softwarepakete
* **Betriebssystem:** Linux 64-Bit (Ubuntu 22.04+, Debian 12+, Arch, Fedora etc.)
* **Java:** OpenJDK 25 (unter `/home/volkix/prg/jdk25` oder im Systempfad via `$JAVA_HOME`)
* **Build-Tool:** Apache Maven 3.8+ (`mvn`)
* **Paketierungs-Tools (für Standalone-Binary):**
  * `jlink` (Bestandteil des OpenJDK JDK)
  * `tar`, `xz-utils`
* **Optional (für PDF-Generierung & Hilfsskripte):**
  * `python3` mit `reportlab` (falls PDFs neu erzeugt werden sollen)

### Empfohlene Umgebungsvariablen
```bash
export JDK25_HOME="/home/volkix/prg/jdk25"
export JAVA_HOME="$JDK25_HOME"
export PATH="$JAVA_HOME/bin:$PATH"
```

---

## 2. Projektarchitektur im Überblick

Euphorix wurde nach einer initialen C++-Konzeption vollständig auf einer modernen **Java 25 VM** implementiert. Dadurch vereint es maximale Portabilität, Speichersicherheit und Zero-Dependency-Ausführung ohne externe C-Bibliotheken:

```
├── pom.xml                     Maven-Projektkonfiguration (Fat-JAR mit shade-plugin)
├── Makefile                    Zentraler Build-Einstieg (make all, make test, etc.)
├── REPRODUCE.sh                End-to-End Automationsskript
├── REPRODUCTION_GUIDE.md       Dieses Handbuch
├── PROMPT_LOG.md               Vollständige Historie aller 157 Benutzeranweisungen
├── java/
│   └── src/main/java/eu/       Java 25 Interpreter-Quellcode:
│       ├── Main.java           CLI-Einstiegspunkt
│       ├── VM.java             Optimierte Bytecode-VM mit Switch-Dispatch
│       ├── Parser.java         OpenEuphoria 4.x Parser & AST-Generator
│       ├── Lexer.java          Scanner für Euphoria-Tokens
│       ├── Builtins.java       Inhärente Core-Funktionen & machine_func/machine_proc
│       ├── Value.java          Euphoria Datenmodell (Atom, Integer, Sequence, String)
│       ├── StdLib.java         Eingebaute Standard-Bibliothek (I/O, Math, Regex, OS)
│       ├── DataEngine.java     Datenbank-Engine (SQLite via JDBC, PostgreSQL)
│       └── NetworkEngine.java  HTTP/1.1 & HTTP/2 Client und integrierter Server
├── eu_include/                 OpenEuphoria Standard-Bibliothek (.e / .ex)
│   ├── std/                    Standard-Module (sequence.e, text.e, map.e, math.e...)
│   └── euphoria/               Kernmodule
├── html/                       VSUI / CGIBash Web-UI Framework
│   ├── css/                    Styling für moderne Webkomponenten
│   ├── js/                     Komponentenlogik (Grids, Forms, Databinding)
│   └── vsui.e                  Euphoria-Wrapper für Webkomponenten
├── examples/                   Praxisbeispiele (REST-API, SQLite, UI5, VSUI, UTF-8)
├── tests/                      Testsuite inklusive OpenEuphoria-Referenztests
├── tools/
│   ├── RunAllTests.java        Paralleler Hochleistungs-Testrunner in Java 25
│   ├── build_standalone.sh     Baut die autarke Single-Binary via jlink
│   ├── build_website.ex        Webseiten-Generator in Euphoria
│   ├── generate_tutorial.py    Generiert die interaktiven Tutorials
│   └── generate_pdf.py         Generiert formatierte PDF-Handbücher
└── website/                    Generierter Web-Auftritt (lighttpd-fertig)
```

---

## 3. Schnelleinklick-Reproduktion (Automatisch)

Der schnellste Weg, das gesamte Projekt neu zu bauen, zu prüfen und die Website zu erzeugen:

```bash
# Gesamter Build-, Test- und Generierungszyklus:
./REPRODUCE.sh

# Oder nur ausgewählte Einzelschritte:
./REPRODUCE.sh build       # Baut nur das JAR und Starter-Skripte
./REPRODUCE.sh standalone  # Baut die autarke Single-Binary
./REPRODUCE.sh test        # Führt die Kern- und Modultests aus
./REPRODUCE.sh test-all    # Startet alle OpenEuphoria-Referenztests
./REPRODUCE.sh website     # Erzeugt die Dokumentations-Webseite
```

---

## 4. Manuelle Schritt-für-Schritt Anleitung

### Schritt 4.1: Maven Fat-JAR kompilieren
Das Maven Shade Plugin bündelt den gesamten Java-Code und alle Laufzeit-Abhängigkeiten (z. B. SQLite JDBC, PostgreSQL JDBC) in ein einziges `euphorix.jar`:

```bash
JAVA_HOME=/home/volkix/prg/jdk25 mvn clean package -DskipTests
cp target/euphorix-1.0.0.jar euphorix.jar
ln -sf euphorix.jar eui.jar
```

### Schritt 4.2: Starter-Skript und Symlinks anlegen
Erstellen Sie das ausführbare Shell-Skript `euphorix`:

```bash
cat << 'EOF' > euphorix
#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JDK25="${JDK25_HOME:-/home/volkix/prg/jdk25}"
JAVA_BIN="java"
if [ -x "$JDK25/bin/java" ]; then
    JAVA_BIN="$JDK25/bin/java"
fi
exec "$JAVA_BIN" \
    --enable-native-access=ALL-UNNAMED \
    -Dfile.encoding=UTF-8 \
    -Dawt.useSystemAAFontSettings=lcd \
    -Dswing.aatext=true \
    -Dsun.java2d.renderer=sun.java2d.marlin.MarlinRenderingEngine \
    -Djdk.internal.httpclient.disableHostnameVerification=true \
    -jar "$DIR/euphorix.jar" "$@"
EOF
chmod +x euphorix

# OpenEuphoria-Kompatibilitätslinks
ln -sf euphorix eui-java
ln -sf euphorix eui
ln -sf euphorix eux
```

Testen Sie den Interpreter:
```bash
./euphorix -v
./euphorix examples/hello.ex
```

### Schritt 4.3: Autarke Single-Binary bauen (`euphorix-standalone`)
Mittels `jlink` wird ein auf ca. 60 MB abgespecktes JRE erzeugt und zusammen mit dem JAR in eine autarke ELF-Binärdatei verpackt. Diese läuft auf jedem 64-Bit Linux ganz ohne vorinstalliertes Java:

```bash
./tools/build_standalone.sh euphorix-standalone
ln -sf euphorix-standalone eui-standalone
ln -sf euphorix-standalone eux-standalone

# Test der Standalone-Binary:
./euphorix-standalone -v
```

### Schritt 4.4: Tests ausführen
Führen Sie die Basis- und Feature-Tests aus:

```bash
# Kern- und Integrationstests (via Makefile)
make test

# Oder die vollständige OpenEuphoria-Referenztestsuite (über 80 Tests):
java tools/RunAllTests.java ./euphorix
```

### Schritt 4.5: Dokumentation & Website generieren
Die Dokumentations-Webseite wird direkt durch ein in Euphoria geschriebenes Tool generiert:

```bash
./euphorix tools/build_website.ex
```
Ergebnis:
* `website/index.html` (Hauptportal mit Downloads & Code-Preview)
* `website/tutorial.html` (Interaktives Tutorial)
* `website/downloads/HANDBUCH.pdf` (Deutsches Komplett-Handbuch als PDF)
* `website/downloads/MANUAL.pdf` (Englisches Referenzhandbuch als PDF)
* `website/lighttpd_sample.conf` (Konfiguration für den lighttpd Webserver)

---

## 5. Deployment auf dem Webserver (lighttpd)

Wenn Sie die Webseite auf Ihrem Server veröffentlichen möchten:

```bash
# Bereitstellung via rsync oder scp:
rsync -avz website/ user@webserver:/var/www/html/euphorix/

# lighttpd Konfiguration einbinden (Auszug aus lighttpd_sample.conf):
# server.document-root = "/var/www/html/euphorix"
# index-file.names = ( "index.html" )
```

---

## 6. Historische Prompt-Referenz

Eine vollständige chronologische Auflistung aller 157 Benutzeranweisungen, die während der Entwicklung von Euphorix gegeben wurden, finden Sie in:
👉 [PROMPT_LOG.md](file:///home/volkix/prj/intpret/PROMPT_LOG.md)
