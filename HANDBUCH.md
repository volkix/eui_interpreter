# Euphorix 1.0 (Java 25 VM für OpenEuphoria-Syntax) – Entwicklerhandbuch & API-Referenz

> 🇬🇧 **English version available:** [MANUAL.md](file:///home/volkix/prj/intpret/MANUAL.md) | 📄 **Übersicht:** [README.md](file:///home/volkix/prj/intpret/README.md) | ⚖️ **Lizenz:** [GNU GPLv3](file:///home/volkix/prj/intpret/LICENSE)

> [!NOTE]
> **Hinweis zur OpenEuphoria-Syntax:** **Euphorix** ist eine eigenständige, von Grund auf neu entwickelte Hochleistungs-VM in Java 25. Sie interpretiert die etablierte, intuitive **OpenEuphoria 4.x-Syntax** und Standardbibliothek in Reinform, erweitert diese jedoch um modernste Java-25-Fähigkeiten (Virtual Threads, Go-Style Channels, Async/Await Futures, Swing/FlatLaf Desktop-GUI, JDBC für SQLite & PostgreSQL, UTF-8 und JSON/XML).

Dieses Handbuch ist die vollständige Dokumentation und Referenz für **Euphorix** (`./euphorix` bzw. `euphorix-standalone` und `euphorix.jar`). Kompatibilitäts-Aliase wie `./eui-java` und `./eui-standalone` bleiben vollumfänglich erhalten.

Die Laufzeitumgebung kombiniert die schlanke, intuitive Syntax von OpenEuphoria mit den modernsten Fähigkeiten der Java-Plattform (OpenJDK 25):
* **Virtuelle Threads (Project Loom)** für hochskalierbare Server, asynchrone Pipelines und Subprozesse – komplett **ohne fehleranfälliges POSIX `fork()`**.
* **Nahtlose Java-Interoperabilität (`std/java.e`)**: Laden externer JAR-Dateien zur Laufzeit, Instanziierung von Java-Klassen, Aufruf statischer und dynamischer Methoden, Feldzugriffe sowie dynamische Proxy-Listener für Callbacks.
* **Native GUI-Entwicklung mit Java Swing & AWT (`std/gui.e`)**: Modernes Linux-Desktop-Design via **GTK+ Look & Feel**, gestochen scharfes **Subpixel-LCD-Antialiasing**, native Ubuntu-Typografie und deklarative Widget-Erstellung.
* **Vollständige UTF-8-Unterstützung**: Konsistente Verarbeitung deutscher Umlaute (`ä`, `ö`, `ü`, `ß`) und weltweiter Unicode-Zeichen durchgehend in Lexer, Compiler, Bytecode-VM, Swing-GUI und I/O.
* **Integrierte Enterprise-Module**: JSON & RFC 9535 JSONPath, JSON-Schema (Draft 2020-12), XML DOM mit W3C XPath 1.0 & XSD, SQLite 3 & PostgreSQL (JDBC), HTTP/HTTPS Client & Server sowie Dual-Stack IPv4/IPv6 Sockets.
* **C-FFI & nativer Rohspeicher**: Direkte Einbindung nativer Linux-Bibliotheken (`.so`) über das JDK 25 Foreign Function & Memory (FFM) API (`java.lang.foreign.*`).

---

## Inhaltsverzeichnis

1. [Architektur, Installation & Build (Java 25 `eui.jar` auf Linux 64-Bit)](#1-architektur-installation--build-java-25-euijar-auf-linux-64-bit)
   - 1.1 [Projektstruktur & Fat-JAR Konzept](#11-projektstruktur--fat-jar-konzept)
   - 1.2 [Virtual Threads Architektur (Subprozesse & Nebenläufigkeit ohne `fork()`)](#12-virtual-threads-architektur-subprozesse--nebenläufigkeit-ohne-fork)
   - 1.3 [Native C-Einbindung (.so) via JDK 25 FFM API](#13-native-c-einbindung-so-via-jdk-25-ffm-api)
   - 1.4 [Voraussetzungen & Maven-Build](#14-voraussetzungen--maven-build)
   - 1.5 [Externe Java-Bibliotheken verwalten & einbinden via pom.xml](#15-externe-java-bibliotheken-verwalten--einbinden-via-pomxml)
   - 1.6 [Autarkes Single-Binary mit integrierter Minimal-JRE (`./eui-standalone`)](#16-autarkes-single-binary-mit-integrierter-minimal-jre-eui-standalone)
   - 1.7 [Plattformunabhängigkeit & Windows-Unterstützung (`eui.cmd` / `eui.bat`)](#17-plattformunabhängigkeit--windows-unterstützung-euicmd--euibat)
2. [Vollständige Sprach-, Syntax- & Standard-Referenz](#2-vollständige-sprach--syntax---standard-referenz)
   - 2.1 [Datentypen & Typsystem](#21-datentypen--typsystem)
   - 2.2 [Sichtbarkeiten, Namespaces & Includes](#22-sichtbarkeiten-namespaces--includes)
   - 2.3 [Operatoren, Indizierung & Slicing](#23-operatoren-indizierung--slicing)
   - 2.4 [Kontrollstrukturen & Schleifen](#24-kontrollstrukturen--schleifen)
   - 2.5 [Prozeduren, Funktionen & Callbacks](#25-prozeduren-funktionen--callbacks)
   - 2.6 [Bedingte Kompilierung (`ifdef`)](#26-bedingte-kompilierung-ifdef)
   - 2.7 [Alle fest eingebauten Built-in Routinen](#27-alle-fest-eingebauten-built-in-routinen)
   - 2.8 [Die wichtigsten Module der Standardbibliothek (`std/*.e`)](#28-die-wichtigsten-module-der-standardbibliothek-stde)
3. [Java-Interoperabilität & JAR-Integration (`std/java.e`)](#3-java-interoperabilität--jar-integration-stdjavae)
   - 3.1 [Laden externer JAR-Dateien (`java:load_jar`)](#31-laden-externer-jar-dateien-javaload_jar)
   - 3.2 [Klassenauflösung & Objekterzeugung](#32-klassenauflösung--objekterzeugung)
   - 3.3 [Methodenaufrufe (statisch & dynamisch)](#33-methodenaufrufe-statisch--dynamisch)
   - 3.4 [Lesen und Schreiben von Feldern](#34-lesen-und-schreiben-von-feldern)
   - 3.5 [Automatisches Typ-Matching & Konvertierungen](#35-automatisches-typ-matching--konvertierungen)
   - 3.6 [Ereignis-Listener & Callbacks (`java:create_listener`)](#36-ereignis-listener--callbacks-javacreate_listener)
   - 3.7 [Subprozess-Pipes mit Virtual Threads](#37-subprozess-pipes-mit-virtual-threads)
4. [Grafische Benutzeroberflächen mit Swing & AWT (`std/gui.e`)](#4-grafische-benutzeroberflächen-mit-swing--awt-stdguie)
   - 4.1 [Linux-Desktop-Integration & Theme-Auswahl (`gui:set_theme`)](#41-linux-desktop-integration--theme-auswahl-guiset_theme)
   - 4.2 [Typografie & Subpixel-Antialiasing](#42-typografie--subpixel-antialiasing)
   - 4.3 [Fensterverwaltung (`window`, `show`, `wait_window`)](#43-fensterverwaltung-window-show-wait_window)
   - 4.4 [Layout-Manager mit Abstandssteuerung (`hgap`/`vgap`)](#44-layout-manager-mit-abstandssteuerung-hgapvgap)
   - 4.5 [Widget-Komponenten-Referenz](#45-widget-komponenten-referenz)
   - 4.6 [Eigenschaften, Styling & Polsterung](#46-eigenschaften-styling--polsterung)
   - 4.7 [Standard-Dialoge (Message, Input, Confirm, FileDialog)](#47-standard-dialoge-message-input-confirm-filedialog)
   - 4.8 [Vollständiges Demo-Programm (`demo/gui_demo.ex`)](#48-vollständiges-demo-programm-demogui_demoex)
5. [UTF-8 String-Verarbeitung (`std/utf8.e` & VM-Engine)](#5-utf-8-string-verarbeitung-stdutf8e--vm-engine)
6. [JSON & RFC 9535 JSONPath (`std/json.e`)](#6-json--rfc-9535-jsonpath-stdjsone)
7. [JSON-Schema Draft 2020-12 (`std/json_schema.e`)](#7-json-schema-draft-2020-12-stdjson_schemae)
8. [XML DOM, W3C XPath 1.0 & XSD (`std/xml.e`)](#8-xml-dom-w3c-xpath-10--xsd-stdxmle)
9. [SQL-Datenbanken: SQLite 3 (`std/sqlite.e`) & PostgreSQL (`std/pgsql.e`)](#9-sql-datenbanken-sqlite-3-stdsqlitee--postgresql-stdpgsqle)
10. [HTTP- & HTTPS-Client und Server (`std/http.e`)](#10-http---https-client-und-server-stdhttpe)
11. [Dual-Stack Netzwerk & Sockets (`std/socket.e` & `std/net/dns.e`)](#11-dual-stack-netzwerk--sockets-stdsockete--stdnetdnse)
12. [Demos, Beispiele & Ausführung](#12-demos-beispiele--ausführung)
13. [Moderne Nebenläufigkeit: Virtual Threads, Async/Await & Channels (`std/thread.e`, `std/channel.e`, `std/task.e`)](#13-moderne-nebenläufigkeit-virtual-threads-asyncawait--channels-stdthreade-stdchannele-stdtaske)
   - 13.1 [Weg 1: Klassische Tasks mit Virtual Threads (`task:create_thread`)](#131-weg-1-klassische-tasks-mit-virtual-threads-taskcreate_thread)
   - 13.2 [Weg 2: Channels / Go-Style Concurrency (`std/channel.e`)](#132-weg-2-channels--go-style-concurrency-stdchannele)
   - 13.3 [Weg 3: Async / Await Futures (`std/thread.e`)](#133-weg-3-async--await-futures-stdthreade)

---

## 1. Architektur, Installation & Build (Java 25 `eui.jar` auf Linux 64-Bit)

### 1.1 Projektstruktur & Fat-JAR Konzept

Der Interpreter ist als **autarkes Fat-JAR (`eui.jar`)** konzipiert. Beim Bauen mit Maven werden alle Abhängigkeiten (JDBC-Treiber, Jackson JSON, eingebettete Standardbibliothek) in ein einziges Archiv gebündelt:

```
prj/intpret/
├── eui-java                 <- Ausführbares Shell-Startskript mit optimierten JVM-Flags
├── eui.jar                  <- Autarkes Java-25-Fat-JAR (18,5 MB inkl. aller Abhängigkeiten)
├── pom.xml                  <- Maven Projektdatei für JDK 25 & Maven-Shade-Plugin
├── eu_include/              <- Standardbibliothek (std/*.e, euphoria/*.e)
│   ├── std/
│   │   ├── gui.e            <- Swing & AWT Desktop GUI API
│   │   ├── java.e           <- Java Interoperabilität, JAR-Loader & Virtual Thread Pipes
│   │   ├── utf8.e           <- Unicode & UTF-8 Textverarbeitung
│   │   ├── json.e           <- JSON & RFC 9535 JSONPath
│   │   ├── json_schema.e    <- JSON-Schema Draft 2020-12
│   │   ├── xml.e            <- XML DOM, XPath 1.0, XSD
│   │   ├── sqlite.e         <- SQLite 3 API
│   │   ├── pgsql.e          <- PostgreSQL API
│   │   ├── http.e           <- HTTP/HTTPS Client & Server
│   │   └── ...              <- sequence.e, math.e, regex.e, socket.e usw.
├── java/src/main/java/eu/   <- Java 25 Quellcode
│   ├── Main.java            <- CLI-Einstiegspunkt, UTF-8 & AWT-Property-Setup
│   ├── Lexer.java           <- Lexer mit nativer UTF-8-Multi-Byte-Unterstützung
│   ├── Compiler.java        <- Single-Pass Bytecode-Compiler & Constant Folder
│   ├── Bytecode.java        <- 3-Adress-Register-Instruktionssatz (OpCodes)
│   ├── VM.java              <- Register-VM mit Virtual Threads & Engine-Dispatch
│   ├── Value.java           <- 48-Bit Int, IEEE-754 Atom & Copy-on-Write Sequenzen
│   ├── JavaInterop.java     <- Reflection, JAR-ClassLoader, Dynamic Proxy & Pipes
│   └── DataEngines.java     <- JSON, XPath & Schema-Engines
└── demo/
    └── gui_demo.ex          <- Interaktive GTK+ Swing-GUI Demonstration
```

#### Das Startskript `./eui-java`
Das Startskript sorgt für optimale Linux-64-Bit-JVM-Einstellungen:
```bash
#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JAR="$DIR/eui.jar"
exec /home/volkix/prg/jdk25/bin/java \
    --enable-native-access=ALL-UNNAMED \
    -Dfile.encoding=UTF-8 \
    -Dawt.useSystemAAFontSettings=lcd \
    -Dswing.aatext=true \
    -Dsun.java2d.renderer=sun.java2d.marlin.MarlinRenderingEngine \
    -Djdk.internal.httpclient.disableHostnameVerification=true \
    -jar "$JAR" "$@"
```

---

### 1.2 Virtual Threads Architektur (Subprozesse & Nebenläufigkeit ohne `fork()`)

In C-Programmen erzeugt `fork()` eine vollständige Kopie des Adressraums des Prozesses. Unter modernen Java-Laufzeitumgebungen ist `fork()` veraltet, birgt Deadlock-Risiken bei Multithreading und erzeugt unnötigen Overhead.

Die Java 25 Edition nutzt stattdessen **Virtuelle Threads (Project Loom)**:
1. **Subprozess-Pipes (`pipe_open`, `pipe_read`, `pipe_write`, `pipe_close`)**:
   Jeder externe Subprozess wird asynchron über `java.lang.ProcessBuilder` gestartet. Zwei leichtgewichtige Virtual Threads lesen kontinuierlich `stdout` und `stderr` in lock-freie `LinkedBlockingQueue`-Puffer ein. Es gibt keine Blockaden des Euphoria-Hauptthreads und keine Deadlocks bei vollen OS-Pipe-Puffern.
2. **HTTP- & HTTPS-Server**:
   Anfragen an `http:server_create` werden auf einem virtuellen Thread-Pool verarbeitet. Tausende gleichzeitige Verbindungen benötigen nur minimale Systemressourcen.
3. **Reentrante Callbacks**:
   Ereignisse aus GUI- und Hintergrund-Threads können über die Proxy-Engine sicher in den Euphoria-Interpreter zurückrufen (`VM.invokeRoutine`).

---

### 1.3 Native C-Einbindung (.so) via JDK 25 FFM API

Die klassischen OpenEuphoria C-FFI-Funktionen (`open_dll`, `define_c_func`, `define_c_proc`, `c_func`, `c_proc`, `allocate`, `free`, `peek*`, `poke*`) arbeiten über das moderne **JDK 25 Foreign Function & Memory (FFM) API**:
* Shared Libraries (`.so`) werden über `SymbolLookup.libraryLookup(Path, Arena)` geöffnet.
* Funktionsaufrufe werden über `Linker.nativeLinker().downcallHandle()` mit exakten nativen ABI-Typen (`ValueLayout.JAVA_INT`, `JAVA_LONG`, `ADDRESS`, `JAVA_DOUBLE`) durchgeführt.
* Speicherreservierung erfolgt über native `MemorySegment.allocateNative()`.

Damit können beliebige Linux-Systembibliotheken (z. B. `libc.so.6`, `libm.so.6`, `libcrypto.so`) ohne C-Compiler direkt aus Euphoria aufgerufen werden.

---

### 1.4 Voraussetzungen & Maven-Build

* **Betriebssystem**: Linux 64-Bit (`x86_64`)
* **Java SDK**: OpenJDK 25 (unter `/home/volkix/prg/jdk25` oder via `JAVA_HOME`)
* **Build-Tool**: Apache Maven (`mvn`)

```bash
# Bauen des Fat-JARs eui.jar
JAVA_HOME=/home/volkix/prg/jdk25 mvn clean package -DskipTests

# Ausführen eines Euphoria-Programms
./eui-java demo/gui_demo.ex

# Ausführen der Unit-Test-Suite (Java 25 Runner)
./tools/run_all_tests ./eui-java tests/t_gui.e tests/t_java_interop.e tests/t_concurrency.ex
```

---

### 1.5 Externe Java-Bibliotheken verwalten & einbinden via `pom.xml`

Das Verwalten von Abhängigkeiten über die zentrale [`pom.xml`](file:///home/volkix/prj/intpret/pom.xml) ist der eleganteste und stabilste Weg, das gesamte Java-Ökosystem in OpenEuphoria nutzbar zu machen.

#### Funktionsweise des Fat-JAR Dependency-Managements:
1. **Zentrale Definition**: Jede in `pom.xml` eingetragene `<dependency>` wird von Maven automatisch aus Maven Central heruntergeladen – inklusive aller transitiven Abhängigkeiten.
2. **Automatisches Bundling (Shading)**: Das `maven-shade-plugin` entpackt alle Klassen der Abhängigkeiten und verschmilzt sie direkt in die Datei `eui.jar`.
3. **Sofortige Verfügbarkeit in Euphoria**: Es müssen keine Classpaths, Umgebungsvariablen oder separate `.jar`-Dateien auf Zielsystemen verwaltet werden. Jede Klasse aus den Dependencies steht in OpenEuphoria sofort über `java:new_object()` und `java:call_static()` bereit.

#### Beispiel: Eine neue Java-Bibliothek hinzufügen (3 Schritte)

Wenn Sie beispielsweise Diagramme mit **JFreeChart**, PDF-Erzeugung mit **iText/OpenPDF** oder Barcodes mit **ZXing** in Euphoria nutzen möchten:

1. **In `pom.xml` eintragen**:
   ```xml
   <dependencies>
       <!-- Beispiel: JFreeChart für Datenvisualisierung -->
       <dependency>
           <groupId>org.jfree</groupId>
           <artifactId>jfreechart</artifactId>
           <version>1.5.4</version>
       </dependency>
   </dependencies>
   ```

2. **Fat-JAR neu paketieren**:
   ```bash
   JAVA_HOME=/home/volkix/prg/jdk25 mvn package -DskipTests
   ```

3. **Direkt in Euphoria verwenden**:
   ```euphoria
   include std/java.e as java

   -- Die Klassen der neuen Library sind sofort verfügbar:
   atom chart = java:call_static("org.jfree.chart.ChartFactory", "createBarChart", {
       "Umsatz 2026", "Kategorie", "EUR", dataset
   })
   ```

#### Aktuell in `pom.xml` vorkonfigurierte Enterprise-Dependencies:
* **SQLite JDBC** (`org.xerial:sqlite-jdbc`): Vollständige native SQLite-Unterstützung.
* **PostgreSQL JDBC** (`org.postgresql:postgresql`): Direkte PostgreSQL-Server-Verbindungen.
* **Jackson Databind** (`com.fasterxml.jackson.core:jackson-databind`): High-Speed JSON- und RFC 9535 JSONPath-Engine.
* **FlatLaf Modern Look & Feel** (`com.formdev:flatlaf`): Moderner Desktop-Skin (Light, Dark, HiDPI).
* **SLF4J-NOP** (`org.slf4j:slf4j-nop`): Lautloses Logging für saubere CLI-Ausgaben.

---

### 1.6 Autarkes Single-Binary mit integrierter Minimal-JRE (`./eui-standalone`)

Sie können den gesamten Interpreter inklusive einer **auf ca. 60 MB abgespeckten Java-25-Runtime** in eine **einzige, eigenständige Binärdatei** packen:

```bash
# Erzeugt ./eui-standalone (ca. 53 MB xz-komprimiert)
make standalone
# oder direkt:
./tools/build_standalone.sh ./eui-standalone
```

#### Wie das Single-Binary funktioniert:
1. **`jlink` (Java Linker)** analysiert die Module und extrahiert exakt die benötigten JVM-Komponenten (`java.base`, `java.desktop`, `java.sql`, `java.net.http`, `java.xml` etc.). Header, Manuals, Debug-Symbole und ungenutzte Module werden entfernt (von ~400 MB auf 60 MB).
2. Das Skript [`tools/build_standalone.sh`](file:///home/volkix/prj/intpret/tools/build_standalone.sh) verpackt die Mini-JRE und `eui.jar` in ein komprimiertes Payload-Archiv mit einem intelligenten Selbstextraktions-Header.
3. **Ausführung**:
   - Die erzeugte Datei [`eui-standalone`](file:///home/volkix/prj/intpret/eui-standalone) kann auf jeden beliebigen Linux-64-Bit-Rechner kopiert werden (z. B. nach `/usr/local/bin/eui`).
   - Auf der Zielmaschine **muss kein Java und kein JDK installiert sein**!
   - Beim ersten Start entpackt sich das Bundle automatisch nach `~/.cache/openeuphoria/java25-runtime/<hash>/`. Alle nachfolgenden Aufrufe starten sofort aus dem Cache.
   - **Vorteil gegenüber GraalVM**: Volle Unterstützung für dynamisches Nachladen von JARs (`java:load_jar`), Swing & GTK+ Desktop-GUIs, Virtual Threads und JIT-Optimierung ohne Closed-World-Einschränkungen!

### 1.7 Plattformunabhängigkeit & Windows-Unterstützung (`eui.cmd` / `eui.bat`)

Dank des reinen Java-25-Bytecode-Kerns läuft `eui.jar` ohne jegliche Modifikation direkt unter **Microsoft Windows** (10, 11, Server) und **macOS**:

* **Dynamische OS-Erkennung**: Beim Kompilieren werden Symbole wie `WINDOWS`, `WIN32` bzw. `LINUX`, `UNIX` dynamisch über `System.getProperty("os.name")` gesetzt. `platform()` liefert unter Windows automatisch `2` (`WIN32`).
* **Pfade & Umgebungsvariablen**: `EUINC` trennt Pfade plattformgerecht über `File.pathSeparator` (Semikolon `;` unter Windows, Doppelpunkt `:` unter Linux).
* **Shell & Subprozesse**: Shell-Aufrufe (`system()`, `JavaInterop.pipeExec`) verwenden unter Windows automatisch `cmd.exe /c` statt `/bin/sh -c`.
* **Windows-Starter**: Zur bequemen Ausführung liegen im Projektverzeichnis [eui.cmd](file:///home/volkix/prj/intpret/eui.cmd) und [eui.bat](file:///home/volkix/prj/intpret/eui.bat) bereit:
  ```cmd
  eui.cmd mein_skript.ex
  ```

---

## 2. Vollständige Sprach-, Syntax- & Standard-Referenz

### 2.1 Datentypen & Typsystem

OpenEuphoria besitzt ein klares, hierarchisches Typsystem aus vier Grundtypen:

```
        object (jeder Wert: Zahl oder Sequenz)
       /      \
    atom      sequence (Liste beliebiger Länge und Tiefe, z. B. {1, "Text", {2, 3}})
     |
  integer (48-Bit-Ganzzahl ohne Nachkommastellen)
```

- **`integer`**: 48-Bit-Ganzzahlen im Wertebereich von `-140737488355328` bis `+140737488355327`.
- **`atom`**: Jede Zahl – ganze Zahlen oder 64-Bit IEEE-754 Gleitkommazahlen (`double`).
- **`sequence`**: Beliebig schachtelbare, **1-basierte** Listen (`{}`). Strings sind Sequenzen von Zeichencodes (in UTF-8-Bytes).
- **`object`**: Universeller Typ, der sowohl `atom` als auch `sequence` aufnehmen kann.

#### Variablen, Konstanten & Aufzählungen
```euphoria
integer anzahl = 42
atom preis = 19.95
sequence name = "Euphoria"
constant MWST = 0.19, WAEHRUNG = "EUR"
enum STATUS_BEREIT = 1, STATUS_AKTIV, STATUS_FERTIG
```

#### Eigene Typen definieren (`type ... end type`)
```euphoria
type prozent(object x)
    return integer(x) and x >= 0 and x <= 100
end type

prozent rabatt = 15   -- Wird bei Zuweisung zur Laufzeit geprüft
```

---

### 2.2 Sichtbarkeiten, Namespaces & Includes

| Schlüsselwort | Bedeutung |
|---|---|
| *(ohne)* | Nur innerhalb der aktuellen Datei sichtbar (`local`). |
| `export` | Sichtbar für Dateien, die diese Datei direkt einbinden. |
| `public` | Sichtbar für Einbinder (und wird weitergereicht). |
| `global` | Im gesamten Programm global verfügbar. |
| `override` | Überschreibt gezielt eine eingebaute oder globale Routine. |

```euphoria
-- In bibliothek.e:
namespace bib
public function verdopple(atom x)
    return x * 2
end function

-- Im Hauptprogramm:
include bibliothek.e as b
? b:verdopple(21)   -- Ausgabe: 42
```

---

### 2.3 Operatoren, Indizierung & Slicing

#### Indizierung und Slicing (1-basiert)
* `s[1]`: Erstes Element
* `s[$]`: Letztes Element (`$` entspricht `length(s)`)
* `s[$-1]`: Vorletztes Element
* `s[2..4]`: Teilsequenz von Position 2 bis 4
* `s[2..$-1]`: Teilsequenz ohne erstes und letztes Element

#### Sequenz-Verkettung & Elementweise Operationen
* `&`: Hängt Sequenzen oder Elemente flach aneinander (`"Hallo " & "Welt"`).
* Alle Rechenoperatoren (`+`, `-`, `*`, `/`) arbeiten automatisch elementweise:
  `{10, 20} * 2` ergibt `{20, 40}`.
* **Gleichheitsprüfung**: Der Operator `=` vergleicht elementweise. Für den Vergleich zweier Sequenzen als Ganzes dient **`equal(a, b)`**!

---

### 2.4 Kontrollstrukturen & Schleifen

```euphoria
-- 1. Verzweigung
if bedingung then
    aktion1()
elsif andere_bedingung then
    aktion2()
else
    aktion3()
end if

-- 2. Switch-Anweisung
switch befehl do
    case "start", "run" then
        start()
        break
    case "stop" then
        stop()
        break
    case else
        unbekannt()
end switch

-- 3. Zählschleife
for i = 1 to 10 by 2 do
    ? i
end for

-- 4. Kopfgesteuerte Schleife
while laeuft do
    verarbeite()
end while

-- 5. Fußgesteuerte Schleife
loop do
    schritt()
    until fertig
```

---

### 2.5 Prozeduren, Funktionen & Callbacks

* **`procedure`**: Führt Aktionen aus, gibt keinen Wert zurück.
* **`function`**: Gibt immer einen Wert über `return <wert>` zurück.
* **Default-Parameter**: Parameter können Standardwerte haben (`function f(integer a, integer b = 10)`).
* **Mehrfachzuweisung**:
  ```euphoria
  function koordinaten()
      return {12.5, 48.2}
  end function
  atom x, y
  {x, y} = koordinaten()
  ```
* **Routinen-IDs & Callbacks**:
  `integer rid = routine_id("meine_funktion")`
  `object ergebnis = call_func(rid, {arg1, arg2})`

---

### 2.6 Bedingte Kompilierung (`ifdef`)

```euphoria
ifdef LINUX then
    constant OS_NAME = "Linux"
elsifdef WINDOWS then
    constant OS_NAME = "Windows"
end ifdef
```
Vordefinierte Symbole in `./eui-java`: `EU4`, `EU4_0`, `EU4_1`, `UNIX`, `LINUX`, `BITS64`, `LONG64`, `JAVA`, `JAVA25`, `CONSOLE`.

---

### 2.7 Alle fest eingebauten Built-in Routinen

#### Typprüfungen & Vergleiche
* `integer(x)`: `1` wenn Ganzzahl, sonst `0`.
* `atom(x)`: `1` wenn Zahl (`integer` oder `double`), sonst `0`.
* `sequence(x)`: `1` wenn Liste/String, sonst `0`.
* `object(x)`: `1` wenn Variable initialisiert ist.
* `equal(a, b)`: Prüft beliebige Objekte auf Gleichheit (`1` oder `0`).
* `compare(a, b)`: Lexikographischer Vergleich (`-1`, `0`, `+1`).

#### Sequenz- & Stringoperationen
* `length(s)`: Anzahl der Elemente / Bytes in `s`.
* `append(s, x)`: Hängt `x` als Element an das Ende an.
* `prepend(s, x)`: Fügt `x` am Anfang ein.
* `repeat(item, count)`: Erzeugt Sequenz aus `count` Wiederholungen von `item`.
* `find(needle, haystack, start=1)`: Findet Element in Sequenz (gibt 1-basierten Index oder `0`).
* `match(sub, haystack, start=1)`: Sucht Teilsequenz in Sequenz (gibt Startposition oder `0`).
* `insert(s, item, index)` / `splice(s, items, index)`: Fügt Element oder Teilsequenz ein.
* `remove(s, start, stop=start)`: Entfernt Elemente im Bereich.
* `replace(s, rep, start, stop=start)`: Ersetzt Bereich durch `rep`.

#### Konsole & Datei-I/O
* `puts(fn, text)`: Textausgabe auf Datei/Kanal (`1` = STDOUT, `2` = STDERR).
* `printf(fn, fmt, values)`: Formatierte Ausgabe (`%d`, `%f`, `%s`, `%x`).
* `sprintf(fmt, values)`: Formatiert String ohne Ausgabe.
* `gets(fn)`: Liest Zeile aus Datei (oder `-1` bei EOF).
* `getc(fn)`: Liest einzelnes Byte (oder `-1` bei EOF).
* `open(path, mode)`: Öffnet Datei (`"r"`, `"w"`, `"a"`, `"rb"`, `"wb"`).
* `close(fn)`: Schließt Datei.
* `seek(fn, pos)` / `where(fn)`: Dateizeiger positionieren und abfragen.

#### Mathematik
* `floor(x)`, `remainder(a, b)`, `sqrt(x)`, `power(base, exp)`, `log(x)`, `sin(x)`, `cos(x)`, `tan(x)`, `arctan(x)`.

---

### 2.8 Die wichtigsten Module der Standardbibliothek (`std/*.e`)

* **`std/sequence.e`**: `split`, `join`, `flatten`, `reverse`, `unique`, `filter`, `apply`, `slice`, `vslice`.
* **`std/search.e`**: `find_all`, `match_all`, `find_replace`, `match_replace`, `begins`, `ends`, `binary_search`.
* **`std/sort.e`**: `sort`, `custom_sort`, `sort_columns`.
* **`std/text.e`**: `trim`, `upper`, `lower`, `pad_head`, `pad_tail`, `format`.
* **`std/math.e`**: `abs`, `round`, `ceil`, `trunc`, `sum`, `average`, `min`, `max`, `gcd`.
* **`std/io.e`**: `read_file`, `write_file`, `read_lines`, `write_lines`, `append_lines`.
* **`std/filesys.e`**: `file_exists`, `dir`, `current_dir`, `chdir`, `create_directory`, `delete_file`, `copy_file`, `pathname`, `filename`.
* **`std/datetime.e`**: `datetime:now()`, `datetime:new()`, `datetime:format()`, `datetime:diff()`, `datetime:add()`.
* **`std/map.e`**: `map:new()`, `map:put()`, `map:get()`, `map:has()`, `map:remove()`, `map:keys()`, `map:values()`.
* **`std/regex.e`**: `regex:new()`, `regex:is_match()`, `regex:find()`, `regex:find_replace()`, `regex:split()`.

---

## 3. Java-Interoperabilität & JAR-Integration (`std/java.e`)

Das Modul `std/java.e` ermöglicht den vollständigen, bidirektionalen Zugriff auf das Java 25-Ökosystem und beliebige externe JAR-Archive direkt aus OpenEuphoria.

### 3.1 Laden externer JAR-Dateien (`java:load_jar`)

Sie können beliebige `.jar`-Bibliotheken zur Laufzeit dynamisch in den Classpath laden:

```euphoria
include std/java.e as java

integer ok = java:load_jar("lib/meine_bibliothek.jar")
if not ok then
    puts(2, "Fehler: JAR konnte nicht geladen werden!\n")
end if
```

---

### 3.2 Klassenauflösung & Objekterzeugung

* **`java:find_class(sequence class_name) -> atom`**  
  Ermittelt das Klassen-Handle (`Class<?>`) anhand des vollqualifizierten Namens:
  ```euphoria
  atom cls_calc = java:find_class("com.beispiel.Calculator")
  ```
* **`java:new_object(object class_or_name, sequence args = {}) -> atom`**  
  Ruft den passenden Konstruktor auf und instanziiert das Java-Objekt. Gibt ein numerisches Handle (`> 0`) zurück:
  ```euphoria
  atom sb = java:new_object("java.lang.StringBuilder", {"Startwert: "})
  atom list = java:new_object("java.util.ArrayList", {})
  ```

---

### 3.3 Methodenaufrufe (statisch & dynamisch)

* **`java:call_method(atom handle, sequence method_name, sequence args = {}) -> object`**  
  Ruft eine Instanzmethode auf:
  ```euphoria
  java:call_method(sb, "append", {123})
  java:call_method(sb, "append", {" EUR"})
  sequence text = java:to_string(sb)   -- "Startwert: 123 EUR"
  ```
* **`java:call_static(object class_or_name, sequence method_name, sequence args = {}) -> object`**  
  Ruft eine statische Klassenmethode auf:
  ```euphoria
  atom zeit = java:call_static("java.lang.System", "currentTimeMillis", {})
  atom wurzel = java:call_static("java.lang.Math", "sqrt", {144.0})   -- 12.0
  atom maxi = java:call_static("java.lang.Math", "max", {10, 25})    -- 25
  ```

---

### 3.4 Lesen und Schreiben von Feldern

* **`java:get_field(atom obj_or_class, sequence field_name) -> object`**  
  Liest den Wert eines Feldes (Instanz- oder statisches Feld):
  ```euphoria
  atom max_int = java:get_field("java.lang.Integer", "MAX_VALUE")
  atom pi = java:get_field("java.lang.Math", "PI")
  ```
* **`java:set_field(atom obj_or_class, sequence field_name, object value)`**  
  Schreibt einen neuen Wert in ein zugängliches Feld:
  ```euphoria
  java:set_field(mein_obj, "konfiguration", "Produktion")
  ```

---

### 3.5 Automatisches Typ-Matching & Konvertierungen

Der Interop-Layer konvertiert Datentypen bidirektional und wählt automatisch die am besten passende Java-Methode anhand eines Scoring-Verfahrens aus:

| Euphoria-Typ | Java-Typen (automatische Konvertierung) |
|---|---|
| `integer` | `int`, `Integer`, `long`, `Long`, `short`, `byte`, `boolean` (`!= 0`) |
| `atom` (Float) | `double`, `Double`, `float`, `Float` |
| `sequence` (String) | `java.lang.String`, `java.lang.CharSequence` (UTF-8) |
| `sequence` (Zahlen) | `byte[]`, `int[]`, `long[]` |
| `sequence` (Objekte) | `java.util.List<?>`, `java.lang.Object[]` |
| Java-Handle (`atom > 0`) | Referenz auf registrierte Java-Instanz |
| `0` | `null` |

---

### 3.6 Ereignis-Listener & Callbacks (`java:create_listener`)

Über **`java:create_listener(sequence interface_name, integer routine_id)`** erzeugt die Laufzeitumgebung einen dynamischen `java.lang.reflect.Proxy`. Wenn Swing oder ein Java-Framework eine Event-Methode aufruft, wird der Aufruf automatisch an die entsprechende Euphoria-Routine weitergeleitet:

```euphoria
procedure on_button_click(atom sender)
    puts(1, "Button wurde geklickt!\n")
end procedure

atom listener = java:create_listener("java.awt.event.ActionListener", routine_id("on_button_click"))
java:call_method(btn, "addActionListener", {listener})
```
*Die Handles bleiben identisch:* Ruft ein Callback auf `sender` auf, entspricht der Wert exakt dem Handle, das bei der Erzeugung des Widgets vergeben wurde (`sender = btn`).

---

### 3.7 Subprozess-Pipes mit Virtual Threads

Für das Ausführen externer Linux-Befehle mit voller Streaming-Kontrolle stehen Virtual-Thread-Pipes bereit:

```euphoria
atom pipe = java:pipe_open("uname -a", java:PIPE_READ)
sequence zeile = java:pipe_read_line(pipe)
puts(1, "System: " & zeile & "\n")
java:pipe_close(pipe)
```

---

## 4. Grafische Benutzeroberflächen mit Swing & AWT (`std/gui.e`)

Das Modul `std/gui.e` bietet eine declarative, intuitive High-Level-API zur Entwicklung grafischer Desktop-Anwendungen für Linux.

### 4.1 Linux-Desktop-Integration & Theme-Auswahl (`gui:set_theme`)

Beim Initialisieren der GUI (`gui:init_gui()`) aktiviert das Modul standardmäßig das native **GTK+ Look and Feel** (`com.sun.java.swing.plaf.gtk.GTKLookAndFeel`):
* Die Anwendung übernimmt Farben, Schaltflächen, Eingabefeld-Designs, Fokus-Rahmen und Bildlaufleisten des aktiven Linux-Desktop-Themes (GNOME, Ubuntu, XFCE).
* Mit der Prozedur **`gui:set_theme(sequence theme_name)`** lässt sich das Erscheinungsbild der gesamten Benutzeroberfläche jederzeit anpassen:
  * `"gtk"`: Natives Linux-Desktop-Theme (Standard)
  * `"flatlaf"` oder `"flatlaf-light"`: Moderner, flacher Hell-Modus (via `com.formdev.flatlaf`)
  * `"flatlaf-dark"` oder `"dark"`: Eleganter Dunkelmodus für moderne Desktop-Tools
  * `"nimbus"`: Moderner Vektor-Look von Swing
  * `"system"`: Standard-Systemdesign des Hostsystems

```euphoria
include std/gui.e as gui

-- Vor dem Erzeugen der Widgets auf Dark-Mode umschalten:
gui:set_theme("flatlaf-dark")

atom win = gui:window("Dark-Mode Anwendung", 600, 400)
```

---

### 4.2 Typografie & Subpixel-Antialiasing

Durch die JVM-Parameter `-Dawt.useSystemAAFontSettings=lcd` und `-Dswing.aatext=true` sowie die Marlin-2D-Engine rendert die GUI Texte mit gestochen scharfem LCD-Subpixel-Antialiasing:
* **Standardschriftart**: `Ubuntu` (bzw. `SansSerif`) in Größe 13pt.
* **Individuelle Anpassung**: Mit `gui:set_font(widget, "Ubuntu", 16, 1)` lassen sich Schriftfamilie, Größe und Fettung (`is_bold = 1`) jederzeit festlegen.

---

### 4.3 Fensterverwaltung (`window`, `show`, `wait_window`)

```euphoria
-- Fenster anlegen (Titel, Breite, Höhe, Schließaktion)
atom win = gui:window("Meine Anwendung", 600, 400, gui:CLOSE_ON_EXIT)

-- Fenster anzeigen
gui:show(win)

-- Hauptschleife: Blockiert den Thread, bis das Fenster geschlossen wird
gui:wait_window(win)
```

Konstanten für Schließaktionen:
* `gui:CLOSE_ON_EXIT` (Standard): Beendet die Anwendung beim Klick auf das Schließen-Kreuz.
* `gui:DISPOSE_ON_CLOSE`: Schließt das Fenster und gibt Grafikressourcen frei.
* `gui:HIDE_ON_CLOSE`: Versteckt das Fenster nur.

---

### 4.4 Layout-Manager mit Abstandssteuerung (`hgap`/`vgap`)

* **`gui:BORDER_LAYOUT`**: Unterteilt den Container in 5 Regionen (`gui:NORTH`, `gui:SOUTH`, `gui:EAST`, `gui:WEST`, `gui:CENTER`).
* **`gui:FLOW_LAYOUT`**: Ordnet Elemente zentriert in einer fließenden Reihe an.
* **`gui:GRID_LAYOUT`**: Exaktes Tabellenraster mit Spalten, Zeilen und Abständen.

```euphoria
-- Erzeugt ein 5-Zeilen, 2-Spalten Formular-Panel mit 14px H-Gap und 12px V-Gap:
atom pnl = gui:panel(gui:GRID_LAYOUT, 5, 2, 14, 12)
```

---

### 4.5 Widget-Komponenten-Referenz

| Funktion | Beschreibung |
|---|---|
| `gui:text_label(sequence text, integer align = ALIGN_LEFT) -> atom` | Erzeugt ein Textlabel (`ALIGN_LEFT`, `ALIGN_CENTER`, `ALIGN_RIGHT`). |
| `gui:text_field(sequence text = "", integer columns = 20) -> atom` | Einzeiliges Texteingabefeld. |
| `gui:text_area(sequence text = "", integer rows = 5, integer cols = 20) -> atom` | Mehrzeiliges Textfeld. |
| `gui:scroll_pane(atom client_widget) -> atom` | Scroll-Container für Textbereiche oder Listen. |
| `gui:button(sequence text, integer on_click_rid = 0) -> atom` | Druckknopf mit optionalem Klick-Callback. |
| `gui:check_box(sequence text, integer checked = 0) -> atom` | Kontrollkästchen (Checkbox). |
| `gui:radio_button(sequence text, integer selected = 0) -> atom` | Optionsfeld (Radio-Button). |
| `gui:combo_box(sequence items = {}) -> atom` | Dropdown-Auswahlbox. |
| `gui:progress_bar(integer min_val = 0, integer max_val = 100) -> atom` | Fortschrittsbalken mit Textanzeige. |
| `gui:slider(integer min_val = 0, integer max_val = 100, integer init_val = 50) -> atom` | Schieberegler. |
| `gui:panel(integer layout_type = FLOW_LAYOUT, integer rows = 0, integer cols = 0, integer hgap = 0, integer vgap = 0) -> atom` | Panel-Container zur Strukturierung. |

---

### 4.6 Eigenschaften, Styling & Polsterung

* **`gui:set_text(atom widget, sequence text)`** / **`gui:get_text(atom widget) -> sequence`**: Text setzen oder lesen (z. B. aus Eingabefeldern oder Labels).
* **`gui:set_value(atom widget, integer val)`** / **`gui:get_value(atom widget) -> integer`**: Wert von Fortschrittsbalken oder Schiebereglern.
* **`gui:is_selected(atom widget) -> integer`** / **`gui:set_selected(atom widget, integer selected)`**: Status von Checkboxen und Radio-Buttons abfragen oder setzen.
* **`gui:set_padding(atom widget, integer top, integer left, integer bottom, integer right)`**: Innenabstand (Padding in Pixeln).
* **`gui:set_font(atom widget, sequence name = "Ubuntu", integer size = 13, integer is_bold = 0)`**: Schriftart anpassen.
* **`gui:set_enabled(atom widget, integer enabled)`**: Widget aktivieren oder ausgrauen.

---

### 4.7 Standard-Dialoge (Message, Input, Confirm, FileDialog)

* **`gui:msgbox(sequence title, sequence message, integer icon_type = MSG_INFO)`**:
  Zeigt einen Dialog an (`MSG_INFO`, `MSG_WARN`, `MSG_ERROR`, `MSG_QUESTION`).
* **`gui:input_box(sequence title, sequence prompt, sequence default_val = "") -> sequence`**:
  Fordert eine Texteingabe an.
* **`gui:confirm_box(sequence title, sequence message) -> integer`**:
  Ja/Nein-Bestätigungsdialog (gibt `1` für Ja, `0` für Nein zurück).
* **`gui:file_dialog(sequence title = "Datei auswählen", integer is_save = 0, sequence start_dir = ".") -> sequence`**:
  Nativer Datei-Öffnen- oder -Speichern-Dialog. Gibt den ausgewählten Pfad zurück oder `""` bei Abbruch.

---

### 4.8 Vollständiges Demo-Programm (`demo/gui_demo.ex`)

Das folgende vollständige Programm demonstriert ein sauberes, zentriertes zweispaltiges Formular mit Callbacks und voller UTF-8-Unterstützung:

```euphoria
include std/gui.e as gui
include std/text.e

-- 1. Fenster anlegen (620x460 Pixel)
atom win = gui:window("OpenEuphoria 4.1 GUI Demo (Java 25 Swing & GTK)", 620, 460)
gui:set_layout(win, gui:BORDER_LAYOUT)
gui:set_padding(win, 12, 14, 12, 14)

-- 2. Header
atom pnl_top = gui:panel(gui:GRID_LAYOUT, 2, 1, 0, 6)
atom lbl_title = gui:text_label("OpenEuphoria GUI: Native Linux-Oberfläche", gui:ALIGN_CENTER)
gui:set_font(lbl_title, "Ubuntu", 17, 1)
atom lbl_sub = gui:text_label("100% UTF-8 Unterstützung für Umlaute (ä, ö, ü, ß) & moderne Schriftarten", gui:ALIGN_CENTER)
gui:set_font(lbl_sub, "Ubuntu", 12, 0)
gui:add(pnl_top, lbl_title)
gui:add(pnl_top, lbl_sub)
gui:add(win, pnl_top, gui:NORTH)

-- 3. Formularbereich (5 Zeilen, 2 Spalten)
atom pnl_center = gui:panel(gui:GRID_LAYOUT, 5, 2, 14, 12)
atom lbl_name = gui:text_label("Benutzername:")
atom txt_name = gui:text_field("Euphoria Entwickler", 20)

atom lbl_lang = gui:text_label("Bevorzugte Plattform:")
atom cmb_lang = gui:combo_box({"Linux 64-Bit (Höchste Leistung)", "Ubuntu / Debian (Zuverlässig)", "Arch / Fedora (Aktuell)"})

atom lbl_mode = gui:text_label("Einstellungen:")
atom cb_expert = gui:check_box("Automatische Überprüfung aktivieren", 1)

atom lbl_pbar = gui:text_label("Fortschritt:")
atom pbar = gui:progress_bar(0, 100)
gui:set_value(pbar, 65)

atom lbl_status_title = gui:text_label("Aktueller Status:")
atom lbl_status = gui:text_label("Bereit für Eingaben & Aktionen")
gui:set_font(lbl_status, "Ubuntu", 12, 1)

gui:add(pnl_center, lbl_name)
gui:add(pnl_center, txt_name)
gui:add(pnl_center, lbl_lang)
gui:add(pnl_center, cmb_lang)
gui:add(pnl_center, lbl_mode)
gui:add(pnl_center, cb_expert)
gui:add(pnl_center, lbl_pbar)
gui:add(pnl_center, pbar)
gui:add(pnl_center, lbl_status_title)
gui:add(pnl_center, lbl_status)
gui:add(win, pnl_center, gui:CENTER)

-- 4. Callbacks
integer count = 0
procedure on_submit(atom sender)
    count += 1
    sequence name = gui:get_text(txt_name)
    gui:set_text(lbl_status, sprintf("Aktion #%d von '%s' ausgeführt", {count, name}))
    gui:msgbox("Bestätigung", 
        sprintf("Hallo %s!\n\nAktion erfolgreich im Swing Event-Thread verarbeitet!\nUmlaute-Test: ä ö ü Ä Ö Ü ß", {name}),
        gui:MSG_INFO)
end procedure

procedure on_file_pick(atom sender)
    sequence path = gui:file_dialog("Datei auswählen", 0, ".")
    if length(path) > 0 then
        gui:set_text(lbl_status, "Ausgewählt: " & path)
    end if
end procedure

procedure on_quit(atom sender)
    gui:close_window(win)
end procedure

-- 5. Buttons (Süd)
atom pnl_bottom = gui:panel(gui:FLOW_LAYOUT)
atom btn_submit = gui:button("Aktion ausführen", routine_id("on_submit"))
atom btn_file   = gui:button("Datei auswählen...", routine_id("on_file_pick"))
atom btn_quit   = gui:button("Schließen",          routine_id("on_quit"))
gui:add(pnl_bottom, btn_submit)
gui:add(pnl_bottom, btn_file)
gui:add(pnl_bottom, btn_quit)
gui:add(win, pnl_bottom, gui:SOUTH)

-- 6. Anzeigen & Warten
gui:show(win)
gui:wait_window(win)
```

---

## 5. UTF-8 String-Verarbeitung (`std/utf8.e` & VM-Engine)

### Vollständige UTF-8-Integration im Java 25 Interpreter
1. **String-Literale im Quellcode**:
   Der Lexer liest Quellcodedateien im UTF-8-Format ein. Zeichen `> 127` (z. B. `ä`, `ö`, `ü`, `ß`, `€`) werden als echte UTF-8-Multi-Byte-Sequenzen in die Bytecode-Konstantentabelle eingetragen (`"ü"` $\rightarrow$ `{195, 188}`).
2. **Robuste Konvertierung in `Value.toUtf8String()`**:
   Beim Übertragen an Java (Swing-GUI, JDBC, HTTP, JSON) decodiert die VM die Bytesequenzen verlustfrei. Sollten unvollständige Einzelbytes vorliegen, greift ein automatischer Fallback auf ISO-8859-1, sodass niemals fehlerhafte Zeichen (`\uFFFD`) im GUI oder in der Ausgabe entstehen.
3. **Zeichengenaue Operationen (`std/utf8.e`)**:
   * `utf8:len(s)`: Anzahl der tatsächlichen Unicode-Zeichen (Codepoints).
   * `utf8:slice(s, start_cp, end_cp)`: Schneidet nach Zeichenposition statt Byte-Index.
   * `utf8:upper(s)` / `utf8:lower(s)`: Echte Unicode-Groß-/Kleinschreibung für alle Alphabete und Umlaute.
   * `utf8:to_codepoints(s)` / `utf8:from_codepoints(cps)`: Umwandlung in 32-Bit-Unicode-Zahlen (z. B. `'€'` $\rightarrow$ `8364`).

---

## 6. JSON & RFC 9535 JSONPath (`std/json.e`)

Das Modul `std/json.e` nutzt intern **Jackson Databind**:
* Schnelles Parsen und Pretty-Printing (`json:parse`, `json:stringify`, `json:pretty`).
* **RFC 9535 JSONPath**: Direkte Auswertung komplexer Pfadausdrücke mit Filtern:
  ```euphoria
  sequence r = json:path_query(doc, "$.store.book[?(@.price < 10)].title")
  ```
* Direkte Kompatibilität mit Datenbank-Ergebnissen (`sqlite:query_assoc`, `pgsql:query_assoc`).

---

## 7. JSON-Schema Draft 2020-12 (`std/json_schema.e`)

Validiert JSON-Datenstrukturen gegen den aktuellen Standard **Draft 2020-12**:
* `json_schema:validate(data, schema) -> sequence`: Gibt `{valid, error_list}` zurück.
* `json_schema:is_valid(data, schema) -> integer`: Schnelle boolesche Prüfung (`1` oder `0`).

---

## 8. XML DOM, W3C XPath 1.0 & XSD (`std/xml.e`)

Basiert auf den JDK-eigenen XML-Engines (`javax.xml.parsers`, `javax.xml.xpath`, `javax.xml.validation`):
* **DOM**: `xml:parse(xml_str)`, `xml:stringify(node)`, `xml:element()`, `xml:tag()`, `xml:text()`, `xml:attr()`.
* **W3C XPath 1.0**: `xml:xpath(doc, "//katalog/buch[@id='B1']/titel")` oder Skalarfunktionen `xml:xpath(doc, "sum(//preis)")`.
* **XSD Schema-Validierung**: `xml:validate_xsd(doc, xsd_str)`.

---

## 9. SQL-Datenbanken: SQLite 3 (`std/sqlite.e`) & PostgreSQL (`std/pgsql.e`)

Beide Module bieten eine **identische, einheitliche API** über JDBC:

| Funktion | SQLite 3 (`std/sqlite.e`) | PostgreSQL (`std/pgsql.e`) |
|---|---|---|
| Verbinden | `sqlite:open("daten.db")` | `pgsql:open("postgresql://user:pass@host:5432/db")` |
| Schließen | `sqlite:close(db)` | `pgsql:close(db)` |
| DDL/DML | `sqlite:exec(db, sql, params)` | `pgsql:exec(db, sql, params)` |
| SELECT (Zeilen) | `sqlite:query(db, sql, params)` | `pgsql:query(db, sql, params)` |
| SELECT (JSON-Objekte) | `sqlite:query_assoc(db, sql, params)` | `pgsql:query_assoc(db, sql, params)` |
| Einzelwert | `sqlite:query_value(db, sql, params)` | `pgsql:query_value(db, sql, params)` |
| Transaktionen | `sqlite:begin`, `commit`, `rollback` | `pgsql:begin`, `commit`, `rollback` |

---

## 10. HTTP- & HTTPS-Client und Server (`std/http.e`)

* **Client**: Basiert auf Java 25 `HttpClient`:
  `http:get`, `http:post`, `http:post_json`, `http:put`, `http:delete_req`, `http:request`. Unterstützt Custom-Header, Timeouts und automatische TLS-Verifikation.
* **Server**: Basiert auf `com.sun.net.httpserver` mit virtuellem Thread-Pool:
  `http:server_create(port)`, `http:route(srv, method, path, handler_rid)`, `http:response_json(status, body)`, `http:server_background(srv)`.

---

## 11. Dual-Stack Netzwerk & Sockets (`std/socket.e` & `std/net/dns.e`)

NIO-Socketkanäle für IPv4- und IPv6-Netzwerkverbindungen:
* `sockets:tcp_connect(host, port, timeout_ms)`
* `sockets:tcp_listen(port, bind_addr, backlog)`
* `sockets:tcp_accept(srv_sock, timeout_ms)`
* `sockets:send_all(sock, data)`
* `sockets:recv_line(sock)`

---

## 12. Demos, Beispiele & Ausführung

Alle Beispielprogramme befinden sich in `demo/` und `examples/` und können direkt gestartet werden:

```bash
# 1. Interaktive Desktop-GUI starten
./eui-java demo/gui_demo.ex

# 2. REST-API Microservice mit SQLite & Schema-Validierung
./eui-java examples/05_rest_api_microservice.ex

# 3. Datenbank-Integrationstests
./eui-java examples/04_sqlite_datenbank.ex
./eui-java examples/06_postgresql_datenbank.ex

# 4. XML & XPath
./eui-java examples/03_xml_xpath_xsd.ex

# 5. Alle Unit-Tests für GUI, Java-Interop & Concurrency ausführen (Java 25 Runner)
./tools/run_all_tests ./eui-java tests/t_gui.e tests/t_java_interop.e tests/t_concurrency.ex
```

---

## 13. Moderne Nebenläufigkeit: Virtual Threads, Async/Await & Channels (`std/thread.e`, `std/channel.e`, `std/task.e`)

Durch die Umstellung auf Java 25 Virtual Threads (Project Loom) überwindet OpenEuphoria die historische Beschränkung auf Single-Core-Multitasking. Blockierende Netzwerk-, Datenbank- oder Datei-Operationen blockieren nie wieder das Gesamtsystem. Drei eng integrierte Wege decken alle Anwendungsfälle ab:

### 13.1 Weg 1: Klassische Tasks mit Virtual Threads (`task:create_thread`)

Das Modul `std/task.e` behält 100 % Abwärtskompatibilität zum bisherigen kooperativen Scheduler, bietet aber mit `create_thread` den direkten Sprung auf Java 25 Virtual Threads:

```euphoria
include std/task.e
include std/thread.e

procedure worker(sequence name)
    for i = 1 to 5 do
        thread:sleep(0.1) -- Blockiert NICHT das Hauptprogramm!
        printf(1, "Task %s: Schritt %d\n", {name, i})
    end for
end procedure

-- Startet als preemptiver Virtual Thread auf separaten CPU-Kernen:
atom t1 = task:create_thread(routine_id("worker"), {"A"})
atom t2 = task:create_thread(routine_id("worker"), {"B"})
```

### 13.2 Weg 2: Channels / Go-Style Concurrency (`std/channel.e`)

Thread-sichere Röhren (CSP - Communicating Sequential Processes) ermöglichen synchronisationsfreie Datenübertragung ohne Locks oder Race Conditions:

```euphoria
include std/thread.e
include std/channel.e

atom ch = channel:new(10) -- Pufferkapazität 10

procedure producer(atom out_ch)
    for i = 1 to 5 do
        channel:send(out_ch, sprintf("Paket #%d", {i}))
    end for
    channel:close(out_ch)
end procedure

thread:spawn(routine_id("producer"), {ch})

-- Verbraucher liest bis Channel geschlossen ist:
while 1 do
    sequence msg = channel:receive(ch)
    if msg[1] != channel:OK then exit end if
    printf(1, "Empfangen: %s\n", {msg[2]})
end while
```

### 13.3 Weg 3: Async / Await Futures (`std/thread.e`)

Das ergonomischste Muster für Entwickler: Asynchrone Jobs starten und Ergebnisse synchron abholen, wenn sie benötigt werden:

```euphoria
include std/thread.e

function compute_pi_chunk(atom terms)
    atom sum = 0
    -- Aufwändige mathematische Berechnung...
    return sum
end function

-- Parallel im Hintergrund starten:
atom job1 = thread:async(routine_id("compute_pi_chunk"), {1000000})
atom job2 = thread:async(routine_id("compute_pi_chunk"), {2000000})

-- Hauptprogramm macht derweil andere Dinge (z.B. GUI-Events verarbeiten)
if not thread:is_done(job1) then
    puts(1, "Job 1 rechnet noch...\n")
end if

-- Auf Ergebnisse warten:
atom res1 = thread:await(job1)
atom res2 = thread:await(job2)

-- Oder mehrere Jobs auf einmal abholen:
-- sequence alle_ergebnisse = thread:await_all({job1, job2})
```

