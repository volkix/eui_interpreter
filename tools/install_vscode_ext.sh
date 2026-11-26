#!/usr/bin/env bash
# ==============================================================================
# Install Euphorix LSP Extension directly into VS Code extensions directory
# ==============================================================================
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXT_SRC="$DIR/editors/vscode"
TARGET_DIR="$HOME/.vscode/extensions/euphorix.euphorix-lsp-1.0.0"

echo "=== Installiere Euphorix VS Code Extension ==="

# Clean obsolete entries and old links
mkdir -p "$HOME/.vscode/extensions"
rm -rf "$TARGET_DIR"
rm -rf "$HOME/.vscode/extensions/euphorix-lsp"
rm -f "$HOME/.vscode/extensions/.obsolete"

# Copy extension files
mkdir -p "$TARGET_DIR"
cp -r "$EXT_SRC"/* "$TARGET_DIR"/

echo "✓ Extension erfolgreich installiert in: $TARGET_DIR"
echo "✓ Bereit für VS Code! Öffnen Sie eine beliebige .ex oder .e Datei in VS Code."
