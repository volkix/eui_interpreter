#!/usr/bin/env bash
# ==============================================================================
# Euphorix 1.0 - Automatisches Reproduktions-Skript (End-to-End Build & Test)
# ==============================================================================
# Führt alle nötigen Schritte aus, um das Euphorix-Projekt von Grund auf neu zu
# kompilieren, zu paketieren, zu testen und die Dokumentation zu generieren.
#
# Verwendung:
#   ./REPRODUCE.sh [Befehl]
#
# Befehle:
#   all         (Standard) Vollständiger Durchlauf: Build, Standalone, Tests, Web
#   build       Baut das Maven Fat-JAR (euphorix.jar) und Starter-Skripte
#   standalone  Baut die autarke Single-Binary (euphorix-standalone mit JRE)
#   test        Führt die Kern- und Integrationstests aus
#   test-all    Führt die vollständige OpenEuphoria-Referenztestsuite aus
#   website     Generiert die Dokumentations-Webseite, Tutorials und PDFs
#   clean       Löscht alle erzeugten Build-Artefakte
#   help        Zeigt diese Hilfe an
# ==============================================================================

set -eo pipefail

# Projekt-Basisverzeichnis
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# Farbdefinitionen für die Ausgabe
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info()  { echo -e "${CYAN}${BOLD}[INFO]${NC}  $*"; }
log_step()  { echo -e "${BLUE}${BOLD}[STEP]${NC}  ${BOLD}$*${NC}"; }
log_ok()    { echo -e "${GREEN}${BOLD}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}${BOLD}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}${BOLD}[ERROR]${NC} $*" >&2; }

# ------------------------------------------------------------------------------
# 1. Umgebung & Voraussetzungen prüfen
# ------------------------------------------------------------------------------
check_environment() {
    log_step "1. Prüfe Umgebung und Systemvoraussetzungen..."

    # Java 25 Ermittlung
    if [ -d "/home/volkix/prg/jdk25" ] && [ -x "/home/volkix/prg/jdk25/bin/java" ]; then
        export JAVA_HOME="/home/volkix/prg/jdk25"
    elif [ -n "$JDK25_HOME" ] && [ -x "$JDK25_HOME/bin/java" ]; then
        export JAVA_HOME="$JDK25_HOME"
    fi

    if ! command -v java >/dev/null 2>&1 && [ -z "$JAVA_HOME" ]; then
        log_error "Java (OpenJDK 25) nicht im PATH oder in JAVA_HOME gefunden!"
        exit 1
    fi

    JAVA_CMD="${JAVA_HOME:+$JAVA_HOME/bin/}java"
    JAVA_VER="$($JAVA_CMD -version 2>&1 | head -n 1)"
    log_info "Java Laufzeit: $JAVA_VER (Pfad: $JAVA_CMD)"

    if ! command -v mvn >/dev/null 2>&1; then
        log_error "Apache Maven ('mvn') ist nicht installiert!"
        exit 1
    fi
    MVN_VER="$(mvn -v | head -n 1)"
    log_info "Maven Version: $MVN_VER"

    # Optionale Hilfswerkzeuge
    for tool in tar xz python3; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_ok "Werkzeug '$tool' verfügbar."
        else
            log_warn "Werkzeug '$tool' nicht gefunden (evtl. für Standalone/PDF benötigt)."
        fi
    done
}

# ------------------------------------------------------------------------------
# 2. Maven Fat-JAR kompilieren & Starter-Skripte erzeugen
# ------------------------------------------------------------------------------
build_jar() {
    log_step "2. Kompiliere Java 25 Quellcode und baue Fat-JAR..."

    JAVA_HOME="${JAVA_HOME:-/home/volkix/prg/jdk25}" mvn clean package -DskipTests

    if [ ! -f "target/euphorix-1.0.0.jar" ] && [ ! -f "target/euphorix.jar" ]; then
        # Falls Shade-Plugin direkt nach java/target baut
        if [ -f "java/target/euphorix-1.0.0.jar" ]; then
            cp "java/target/euphorix-1.0.0.jar" "euphorix.jar"
        else
            log_error "Build-Fehler: JAR-Datei konnte nicht erstellt werden!"
            exit 1
        fi
    else
        JAR_FILE="$(ls target/euphorix*.jar | grep -v 'original' | head -n 1)"
        cp "$JAR_FILE" "euphorix.jar"
    fi

    # Kompatibilitäts-Symlink eui.jar
    ln -sf "euphorix.jar" "eui.jar"
    log_ok "euphorix.jar erfolgreich erstellt ($(du -h euphorix.jar | awk '{print $1}'))."

    log_step "3. Erzeuge Starter-Skript 'euphorix' und Symlinks..."
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

    # Symlinks für Abwärtskompatibilität zu OpenEuphoria
    ln -sf euphorix eui-java
    ln -sf euphorix eui
    ln -sf euphorix eux
    log_ok "Starter-Skripte (euphorix, eui, eux, eui-java) angelegt."
}

# ------------------------------------------------------------------------------
# 3. Autarkes Standalone-Binary bauen
# ------------------------------------------------------------------------------
build_standalone() {
    log_step "4. Baue autarkes Single-Binary (euphorix-standalone mit jlink)..."
    if [ -f "tools/build_standalone.sh" ]; then
        JDK25_HOME="${JAVA_HOME:-/home/volkix/prg/jdk25}" ./tools/build_standalone.sh euphorix-standalone
        ln -sf euphorix-standalone eui-standalone
        ln -sf euphorix-standalone eux-standalone
        log_ok "Single-Binary 'euphorix-standalone' erfolgreich erstellt ($(du -h euphorix-standalone | awk '{print $1}'))."
    else
        log_warn "tools/build_standalone.sh nicht gefunden. Überspringe Standalone-Bau."
    fi
}

# ------------------------------------------------------------------------------
# 4. Standard- & Integrationstests ausführen
# ------------------------------------------------------------------------------
run_tests() {
    log_step "5. Führe Kern- und Integrationstests aus..."

    if [ ! -x "./euphorix" ]; then
        log_error "Interpreter './euphorix' nicht gefunden. Bitte zuerst './REPRODUCE.sh build' ausführen!"
        exit 1
    fi

    log_info "1/4: Einfacher Smoke-Test..."
    ./euphorix examples/hello.ex >/dev/null
    ./euphorix examples/sieve.ex >/dev/null
    log_ok "Basis-Programme laufen fehlerfrei."

    log_info "2/4: Standard-Bibliothek Tests..."
    ./euphorix examples/oe4_features.ex >/dev/null
    ./euphorix examples/stdlib_full_test.ex >/dev/null
    log_ok "Standard-Bibliothek funktionsfähig."

    log_info "3/4: Erweiterte Module (UTF-8, JSON/Schema, XML, SQLite, REST, SAPUI5, VSUI)..."
    ./euphorix examples/01_utf8_textverarbeitung.ex >/dev/null
    ./euphorix examples/02_json_und_schema.ex >/dev/null
    ./euphorix examples/03_xml_xpath_xsd.ex >/dev/null
    ./euphorix examples/04_sqlite_datenbank.ex >/dev/null
    ./euphorix examples/07_sapui5_webcomponents_demo.ex >/dev/null
    ./euphorix examples/08_cgibash_html_demo.ex >/dev/null
    log_ok "Moderne Subsysteme erfolgreich validiert."

    log_info "4/4: UI- & Nebenläufigkeits-Tests..."
    ./euphorix tests/t_gui.e >/dev/null
    ./euphorix tests/t_ui5.e >/dev/null
    ./euphorix tests/t_vsui.e >/dev/null
    ./euphorix tests/t_java_interop.e >/dev/null
    ./euphorix tests/t_concurrency.ex >/dev/null
    log_ok "Alle Kern- und Integrationstests bestanden!"
}

# ------------------------------------------------------------------------------
# 5. Vollständige Testsuite ausführen (OpenEuphoria Referenztests)
# ------------------------------------------------------------------------------
run_all_tests() {
    log_step "Führe vollständige OpenEuphoria-Referenztestsuite aus..."
    if [ -x "./euphorix" ] && [ -f "tools/RunAllTests.java" ]; then
        java tools/RunAllTests.java ./euphorix
    else
        log_error "RunAllTests.java oder ./euphorix fehlt!"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# 6. Dokumentation, Tutorial und Webseite generieren
# ------------------------------------------------------------------------------
build_website() {
    log_step "6. Generiere Dokumentation, Tutorials und Webseite..."
    if [ ! -x "./euphorix" ]; then
        log_error "Interpreter './euphorix' nicht gefunden. Bitte zuerst './REPRODUCE.sh build' ausführen!"
        exit 1
    fi

    ./euphorix tools/build_website.ex
    log_ok "Webseite in 'website/' und PDFs in 'website/downloads/' erfolgreich erzeugt."
}

# ------------------------------------------------------------------------------
# 7. Aufräumen
# ------------------------------------------------------------------------------
clean() {
    log_step "Räume Build-Artefakte auf..."
    make clean 2>/dev/null || true
    rm -rf website/downloads/*.pdf website/downloads/*.jar website/downloads/*standalone
    log_ok "Aufräumen abgeschlossen."
}

# ------------------------------------------------------------------------------
# Hilfe anzeigen
# ------------------------------------------------------------------------------
show_help() {
    echo -e "${BOLD}Euphorix 1.0 - Reproduktions- und Automations-Skript${NC}"
    echo ""
    echo "Verwendung:"
    echo "  ./REPRODUCE.sh [Befehl]"
    echo ""
    echo "Befehle:"
    echo "  all         (Standard) Vollständiger Durchlauf: Build, Standalone, Tests, Web"
    echo "  build       Baut nur das Maven Fat-JAR (euphorix.jar) und Starter-Skripte"
    echo "  standalone  Baut nur die autarke Single-Binary (euphorix-standalone)"
    echo "  test        Führt die Kern- und Integrationstests aus"
    echo "  test-all    Führt die vollständige OpenEuphoria-Referenztestsuite aus"
    echo "  website     Erzeugt die Dokumentations-Webseite und Handbuch-PDFs"
    echo "  clean       Löscht alle erzeugten Build-Dateien"
    echo "  help        Zeigt diese Hilfe an"
}

# ------------------------------------------------------------------------------
# Hauptlogik / Befehlsverteiler
# ------------------------------------------------------------------------------
COMMAND="${1:-all}"

case "$COMMAND" in
    all)
        check_environment
        build_jar
        build_standalone
        run_tests
        build_website
        echo ""
        echo -e "${GREEN}${BOLD}======================================================================${NC}"
        echo -e "${GREEN}${BOLD}  Euphorix wurde erfolgreich von Grund auf reproduziert und getestet!  ${NC}"
        echo -e "${GREEN}${BOLD}======================================================================${NC}"
        echo "Erstellte Artefakte:"
        echo "  - Fat-JAR        : $PROJECT_DIR/euphorix.jar"
        echo "  - CLI-Launcher   : $PROJECT_DIR/euphorix (Symlinks: eui, eux, eui-java)"
        echo "  - Single-Binary  : $PROJECT_DIR/euphorix-standalone"
        echo "  - Web-Portal     : $PROJECT_DIR/website/index.html"
        echo "  - Tutorial-Portal: $PROJECT_DIR/website/tutorial.html"
        echo "  - PDF-Handbücher : $PROJECT_DIR/website/downloads/HANDBUCH.pdf, MANUAL.pdf"
        echo "  - Prompt-Log     : $PROJECT_DIR/PROMPT_LOG.md"
        echo ""
        ;;
    build)
        check_environment
        build_jar
        ;;
    standalone)
        check_environment
        build_standalone
        ;;
    test)
        run_tests
        ;;
    test-all)
        run_all_tests
        ;;
    website)
        build_website
        ;;
    clean)
        clean
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unbekannter Befehl: '$COMMAND'"
        echo ""
        show_help
        exit 1
        ;;
esac
