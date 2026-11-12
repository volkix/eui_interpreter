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
OUTPUT="${1:-$DIR/euphorix-standalone}"
BUILD_TMP="/tmp/euphorix-standalone-build-$$"

echo "=== Erstelle autarkes Single-Binary: $OUTPUT ==="
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

echo "4. Kopiere euphorix.jar..."
JAR_SRC="$DIR/euphorix.jar"
if [ ! -f "$JAR_SRC" ]; then JAR_SRC="$DIR/eui.jar"; fi
cp "$JAR_SRC" "$BUILD_TMP/euphorix.jar"

echo "5. Komprimiere Runtime & Fat-JAR (xz)..."
(cd "$BUILD_TMP" && tar -cf - jre euphorix.jar | xz -T0 -6 > payload.tar.xz)

echo "6. Assembliere Single-Binary Executable..."
cat << 'EOF' > "$BUILD_TMP/stub.sh"
#!/bin/sh
set -e
# Euphorix Standalone Single-Binary (Bundled Java 25 JRE - OpenEuphoria Syntax)
CACHE_BASE="${XDG_CACHE_HOME:-$HOME/.cache}/euphorix/java25-runtime"
EXE_HASH="$(sha256sum "$0" 2>/dev/null | awk '{print substr($1,1,16)}')"
TARGET_DIR="$CACHE_BASE/$EXE_HASH"

if [ ! -d "$TARGET_DIR" ] || [ ! -x "$TARGET_DIR/jre/bin/java" ]; then
    mkdir -p "$TARGET_DIR"
    ARCHIVE_LINE=$(awk '/^__PAYLOAD_BELOW__/ {print NR + 1; exit 0; }' "$0")
    tail -n +"$ARCHIVE_LINE" "$0" | tar -xJ -C "$TARGET_DIR"
fi

exec "$TARGET_DIR/jre/bin/java" \
    --enable-native-access=ALL-UNNAMED \
    -Dfile.encoding=UTF-8 \
    -Dawt.useSystemAAFontSettings=lcd \
    -Dswing.aatext=true \
    -Dsun.java2d.renderer=sun.java2d.marlin.MarlinRenderingEngine \
    -Djdk.internal.httpclient.disableHostnameVerification=true \
    -jar "$TARGET_DIR/euphorix.jar" "$@"

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
