#!/usr/bin/env bash
# ==============================================================================
# Euphorix 1.0 - Build Standalone Single-Binary (Bundled Minimal Java 25 JRE)
# ==============================================================================
# Erzeugt eine einzige, autarke Linux-64-Bit-Binärdatei ('euphorix-standalone'),
# die eine auf 60 MB abgespeckte OpenJDK-25-Runtime (via jlink) und euphorix.jar
# enthält. Führt OpenEuphoria-Syntax ohne vorinstalliertes Java aus!
# ==============================================================================
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JDK25="${JDK25_HOME:-/home/volkix/prg/jdk25}"
OUTPUT=""
APP_SRC=""

while [ $# -gt 0 ]; do
    case "$1" in
        --app)
            APP_SRC="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        *)
            if [ -z "$OUTPUT" ]; then
                OUTPUT="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$OUTPUT" ]; then
    if [ -n "$APP_SRC" ]; then
        BASE_APP="$(basename "$APP_SRC")"
        OUTPUT="$DIR/${BASE_APP%.*}-standalone"
    else
        OUTPUT="$DIR/euphorix-standalone"
    fi
fi

BUILD_TMP="/tmp/euphorix-standalone-build-$$"

echo "=== Erstelle autarkes Single-Binary: $OUTPUT ==="
if [ -n "$APP_SRC" ]; then
    echo "    Gebündelte Anwendung: $APP_SRC (Precompiled Bytecode)"
fi
echo "1. Prüfe Voraussetzungen..."
if [ ! -x "$JDK25/bin/jlink" ]; then
    echo "Fehler: jlink nicht gefunden unter $JDK25/bin/jlink" >&2
    exit 1
fi

echo "2. Baue euphorix.jar mit Maven..."
(cd "$DIR" && JAVA_HOME="$JDK25" mvn -q package -DskipTests)

rm -rf "$BUILD_TMP"
mkdir -p "$BUILD_TMP"
trap 'rm -rf "$BUILD_TMP"' EXIT

echo "3. Erstelle minimales Java-25-JRE mit jlink (ca. 60 MB)..."
"$JDK25/bin/jlink" \
    --add-modules java.base,java.desktop,java.management,java.naming,java.net.http,java.security.jgss,java.sql,java.xml,jdk.httpserver,jdk.unsupported \
    --strip-debug \
    --no-man-pages \
    --no-header-files \
    --compress=zip-6 \
    --output "$BUILD_TMP/jre"

echo "4. Kopiere JAR, Web-Assets (html/) & Anwendung..."
JAR_SRC="$DIR/euphorix.jar"
if [ ! -f "$JAR_SRC" ]; then JAR_SRC="$DIR/eui.jar"; fi

# Falls eine Anwendung angegeben wurde: zu Bytecode kompilieren
if [ -n "$APP_SRC" ]; then
    if [[ "$APP_SRC" == *.exb ]]; then
        cp "$APP_SRC" "$BUILD_TMP/app.exb"
    else
        echo "   Kompiliere $APP_SRC -> Bytecode (app.exb)..."
        "$JDK25/bin/java" -jar "$JAR_SRC" --compile "$APP_SRC" -o "$BUILD_TMP/app.exb"
    fi
fi

# Für Anwendungs-Bundles bevorzugen wir die schlanke runtime.jar ohne Compiler/Quellcode
if [ -n "$APP_SRC" ] && [ -f "$DIR/runtime.jar" ]; then
    cp "$DIR/runtime.jar" "$BUILD_TMP/runtime.jar"
    PAYLOAD_ITEMS="jre runtime.jar"
else
    cp "$JAR_SRC" "$BUILD_TMP/euphorix.jar"
    PAYLOAD_ITEMS="jre euphorix.jar"
fi

# Statische Web-Assets für VS-UI einbinden
if [ -d "$DIR/html" ]; then
    cp -r "$DIR/html" "$BUILD_TMP/html"
    PAYLOAD_ITEMS="$PAYLOAD_ITEMS html"
fi

if [ -n "$APP_SRC" ]; then
    PAYLOAD_ITEMS="$PAYLOAD_ITEMS app.exb"
fi

echo "5. Komprimiere Runtime & Fat-JAR (xz)..."
(cd "$BUILD_TMP" && tar -cf - $PAYLOAD_ITEMS | xz -T0 -6 > payload.tar.xz)

echo "6. Assembliere Single-Binary Executable..."
cat << 'EOF' > "$BUILD_TMP/stub.sh"
#!/bin/sh
set -e
# Euphorix Standalone Single-Binary (Bundled Java 25 JRE & Assets)
CACHE_BASE="${XDG_CACHE_HOME:-$HOME/.cache}/euphorix/java25-runtime"
EXE_HASH="$(sha256sum "$0" 2>/dev/null | awk '{print substr($1,1,16)}')"
TARGET_DIR="$CACHE_BASE/$EXE_HASH"

if [ ! -d "$TARGET_DIR" ] || [ ! -x "$TARGET_DIR/jre/bin/java" ]; then
    mkdir -p "$TARGET_DIR"
    ARCHIVE_LINE=$(awk '/^__PAYLOAD_BELOW__/ {print NR + 1; exit 0; }' "$0")
    tail -n +"$ARCHIVE_LINE" "$0" | tar -xJ -C "$TARGET_DIR"
fi

export VSUI_STATIC_DIR="$TARGET_DIR/html"
export EUPHORIX_HTML="$TARGET_DIR/html"

RUNNER_JAR="$TARGET_DIR/runtime.jar"
if [ ! -f "$RUNNER_JAR" ]; then RUNNER_JAR="$TARGET_DIR/euphorix.jar"; fi

if [ -f "$TARGET_DIR/app.exb" ]; then
    if [ $# -eq 0 ]; then
        exec "$TARGET_DIR/jre/bin/java" \
            --enable-native-access=ALL-UNNAMED \
            -Dfile.encoding=UTF-8 \
            -Dvsui.static.dir="$TARGET_DIR/html" \
            -Dawt.useSystemAAFontSettings=lcd \
            -Dswing.aatext=true \
            -Dsun.java2d.renderer=sun.java2d.marlin.MarlinRenderingEngine \
            -Djdk.internal.httpclient.disableHostnameVerification=true \
            -jar "$RUNNER_JAR" "$TARGET_DIR/app.exb"
    else
        exec "$TARGET_DIR/jre/bin/java" \
            --enable-native-access=ALL-UNNAMED \
            -Dfile.encoding=UTF-8 \
            -Dvsui.static.dir="$TARGET_DIR/html" \
            -Dawt.useSystemAAFontSettings=lcd \
            -Dswing.aatext=true \
            -Dsun.java2d.renderer=sun.java2d.marlin.MarlinRenderingEngine \
            -Djdk.internal.httpclient.disableHostnameVerification=true \
            -jar "$RUNNER_JAR" "$TARGET_DIR/app.exb" "$@"
    fi
else
    exec "$TARGET_DIR/jre/bin/java" \
        --enable-native-access=ALL-UNNAMED \
        -Dfile.encoding=UTF-8 \
        -Dvsui.static.dir="$TARGET_DIR/html" \
        -Dawt.useSystemAAFontSettings=lcd \
        -Dswing.aatext=true \
        -Dsun.java2d.renderer=sun.java2d.marlin.MarlinRenderingEngine \
        -Djdk.internal.httpclient.disableHostnameVerification=true \
        -jar "$RUNNER_JAR" "$@"
fi

__PAYLOAD_BELOW__
EOF

cat "$BUILD_TMP/stub.sh" "$BUILD_TMP/payload.tar.xz" > "$OUTPUT"
chmod +x "$OUTPUT"

# Create symlink for eui-standalone compatibility
if [ "$(basename "$OUTPUT")" = "euphorix-standalone" ]; then
    ln -sf "euphorix-standalone" "$DIR/eui-standalone"
fi

SIZE=$(du -h "$OUTPUT" | awk '{print $1}')
echo "=== Fertig! Single-Binary erfolgreich erstellt ==="
echo "Datei : $OUTPUT ($SIZE)"
echo "Test  : $OUTPUT -v"
