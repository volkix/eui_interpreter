#!/usr/bin/env bash
# ==============================================================================
# Euphorix LSP Integration for Apache NetBeans
# ==============================================================================
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NB_DIR="$HOME/.netbeans/31"
NB_PREFS="$NB_DIR/config/Preferences/org/netbeans/modules/lsp"
GRAMMAR="$DIR/editors/vscode/syntaxes/euphoria.tmLanguage.json"

mkdir -p "$NB_PREFS"
mkdir -p "$NB_DIR/config/Services/MIMEResolver"

CLIENT_PROPS="$NB_PREFS/client.properties"
JSON_DESC='[{"id":"euphorix","extensions":"ex e ew eu","syntaxGrammar":"'$GRAMMAR'","languageServer":"'$DIR'/euphorix --lsp","name":"Euphorix (OpenEuphoria)","icon":"","mimeType":"text/x-ext-euphorix","debugger":false,"languageId":"euphoria"}]'
ESCAPED_DESC=$(printf '%s' "$JSON_DESC" | sed 's/:/\\:/g')

echo "=== Konfiguriere Apache NetBeans für Euphorix LSP ==="
if [ -f "$CLIENT_PROPS" ] && grep -q "language.descriptions=" "$CLIENT_PROPS"; then
    sed -i "s|^language.descriptions=.*|language.descriptions=$ESCAPED_DESC|" "$CLIENT_PROPS"
else
    echo "language.descriptions=$ESCAPED_DESC" >> "$CLIENT_PROPS"
fi

# Ensure valid XML MIME Resolver for NetBeans
cat << 'EOF' > "$NB_DIR/config/Services/MIMEResolver/euphorix.xml"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE MIME-resolver PUBLIC "-//NetBeans//DTD MIME Resolver 1.0//EN" "http://www.netbeans.org/dtds/mime-resolver-1_0.dtd">
<MIME-resolver>
    <file>
        <ext name="ex"/>
        <ext name="e"/>
        <ext name="ew"/>
        <ext name="eu"/>
        <resolver mime="text/x-ext-euphorix"/>
    </file>
</MIME-resolver>
EOF

echo "✓ NetBeans-LSP-Konfiguration aktualisiert in:"
echo "  $CLIENT_PROPS"
echo "✓ NetBeans-MIMEResolver  : $NB_DIR/config/Services/MIMEResolver/euphorix.xml"
echo "✓ Sprachserver-Befehl    : $DIR/euphorix --lsp"
echo "✓ Dateiendungen          : ex e ew eu"
echo "✓ MIME-Typ               : text/x-ext-euphorix"
echo "✓ TextMate-Grammatik     : $GRAMMAR"
echo
echo "NetBeans starten:"
echo "  /home/volkix/prg/netbeans/bin/netbeans &"
