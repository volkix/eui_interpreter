# Euphorix VS Code Extension

Sprachunterstützung und Language Server Protocol (LSP) für **Euphorix / OpenEuphoria** in Visual Studio Code.

## Funktionen

* ⚡ **Syntax-Highlighting**: TextMate-Grammatik für Euphoria-Keywords, Typen, Routinen, Strings, Hex/Binär-Zahlen und Kommentare.
* 🔍 **Echtzeit-Diagnose (Diagnostics)**: Direkte Anzeige von Syntaxfehlern mit genauer Zeilen- und Spaltenangabe beim Tippen.
* 💡 **Code-Vervollständigung (IntelliSense)**:
  * OpenEuphoria Schlüsselwörter und Snippets (`function`, `procedure`, `if`, `for`, `while`, `switch`)
  * Eingebaute Built-in Funktionen (`puts`, `printf`, `length`, `append`, etc.)
  * Standardbibliotheken bei Eingabe von `vsui:`, `map:`, `json:`, `sequence:`, `io:`, `math:`, `sqlite:`, etc.
  * Im aktuellen Dokument deklarierte Funktionen und Prozeduren.
* 📖 **Hover-Dokumentation**: Formatierte Parametererklärungen und Beschreibungen bei Mauszeiger über Routinen.
* 🎯 **Gehe zu Definition (F12 / Strg+Klick)**: Direkter Sprung zur Deklaration von Funktionen, Prozeduren und Konstanten.
* 🌳 **Dokument-Gliederung (Outline)**: Anzeige aller Prozeduren, Funktionen und Typen in der VS Code Symbolleiste.

## Installation

### Option A: Lokale Entwicklung / Manuelle Installation
Kopieren Sie den Ordner `editors/vscode` in Ihr VS Code Erweiterungsverzeichnis:

```bash
# Linux / macOS:
cp -r editors/vscode ~/.vscode/extensions/euphorix-lsp

# Windows:
xcopy /E /I editors\vscode %USERPROFILE%\.vscode\extensions\euphorix-lsp
```

### Option B: Über Generic LSP Client
Falls Sie keine separate Extension installieren möchten, können Sie das beliebte Plugin **Generic LSP Client** oder **glspc** in VS Code nutzen und in Ihrer `settings.json` Folgendes eintragen:

```json
{
  "generic-lsp.server": {
    "command": "/home/volkix/prj/intpret/euphorix",
    "args": ["--lsp"],
    "languages": ["euphoria"]
  }
}
```

## Konfiguration

In den VS Code Einstellungen (`settings.json`):

```json
{
  "euphorix.executablePath": "/home/volkix/prj/intpret/euphorix",
  "euphorix.lsp.enable": true
}
```
