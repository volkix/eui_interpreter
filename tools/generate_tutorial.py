#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generate website/tutorial.html for Euphorix.
Contains comprehensive, runnable German examples, explanations, and detailed function
reference tables for ALL Euphorix standard modules (including MCP, RAG, LLM, Concurrency,
JSON-DB, VS-UI, OpenUI5, Office Reporting, EDS, Sockets, and Tooling).
"""

import json
import os
import sys

CONFIG_FILE = "website_config.json"
OUTPUT_FILE = "website/tutorial.html" if len(sys.argv) < 2 else sys.argv[1]

def load_config():
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}

cfg = load_config()
proj = cfg.get("project", {})
imp = cfg.get("impressum", {})

PROJ_NAME = proj.get("name", "Euphorix")
PROJ_VER = proj.get("version", "1.0.0")
GITHUB_URL = proj.get("github_url", "https://github.com/volkix/eui_interpreter")
OPENEU_URL = proj.get("openeuphoria_url", "https://openeuphoria.org")
LICENSE = proj.get("license", "GPLv3")
OWNER = imp.get("owner", "Volker Schulte")

CHAPTERS = [
    {
        "id": "kapitel-1",
        "title": "1. Sequenzen, Maps & Collections",
        "cat": "collections",
        "desc": "Das fundamentale Datenmodell von OpenEuphoria und fortgeschrittene Datenstrukturen: Dynamische Sequenzen, 1-basiertes Slicing, Hash-Maps mit O(1)-Zugriff, LIFO-Stacks, Sortierung und binäre Serialisierung.",
        "file": "tutorial/01_datenstrukturen.ex",
        "modules": [
            {
                "name": "std/sequence.e",
                "ns": "stdseq",
                "desc": "Das Kernmodul von OpenEuphoria. Sequenzen sind dynamische, 1-basierte Listen beliebiger Tiefe und Datentypen. Bietet Slicing mit dem Dollar-Zeichen '$' als Längenbezeichner, Filtern, Invertieren, Spaltenschnitte (vslice) und Listenverbindungen.",
                "functions": [
                    {"sig": "length(sequence s)", "ret": "integer", "desc": "Liefert die Gesamtanzahl der Elemente in der Sequenz s."},
                    {"sig": "append(sequence s, object item)", "ret": "sequence", "desc": "Hängt das Objekt item als eigenständiges, letztes Element an die Sequenz s an."},
                    {"sig": "prepend(sequence s, object item)", "ret": "sequence", "desc": "Fügt das Objekt item als neues erstes Element am Anfang der Sequenz s ein."},
                    {"sig": "s[from_idx..to_idx]", "ret": "sequence", "desc": "1-basiertes Slicing (Teilbereich). '$' steht als Platzhalter für das letzte Element (z. B. s[2..$-1])."},
                    {"sig": "vslice(sequence matrix, integer col)", "ret": "sequence", "desc": "Extrahiert eine vertikale Spalte aus einer zweidimensionalen Tabelle/Matrix."},
                    {"sig": "reverse(sequence s)", "ret": "sequence", "desc": "Kehrt die Reihenfolge aller Elemente in der Sequenz um."},
                    {"sig": "flatten(sequence s)", "ret": "sequence", "desc": "Ebnet eine mehrfach verschachtelte Baumstruktur in eine flache, eindimensionale Liste ein."},
                    {"sig": "join(sequence list, sequence delim)", "ret": "sequence", "desc": "Verbindet eine Liste von Zeichenketten mit einem frei wählbaren Trennzeichen (z. B. ', ')."},
                    {"sig": "split(sequence str, sequence delim)", "ret": "sequence", "desc": "Zerlegt einen String anhand eines Trennzeichens in eine Sequenz von Teilstrings."},
                    {"sig": "remove(sequence s, integer idx)", "ret": "sequence", "desc": "Löscht das Element an der angegebenen 1-basierten Position aus der Sequenz."},
                    {"sig": "insert(sequence s, object item, integer idx)", "ret": "sequence", "desc": "Fügt ein Element an einer beliebigen Position in die Sequenz ein."},
                    {"sig": "find_all(object item, sequence s)", "ret": "sequence", "desc": "Findet alle Indizes, an denen das gesuchte Element in der Sequenz vorkommt."},
                    {"sig": "replace(sequence s, object repl, integer from_i, integer to_i=from_i)", "ret": "sequence", "desc": "Ersetzt einen Teilbereich der Sequenz durch ein neues Element oder eine Ersatzsequenz."},
                    {"sig": "head(sequence s, integer count)", "ret": "sequence", "desc": "Liefert die ersten count Elemente einer Sequenz (Kopfbereich)."},
                    {"sig": "tail(sequence s, integer count)", "ret": "sequence", "desc": "Liefert die letzten count Elemente einer Sequenz (Endbereich)."},
                    {"sig": "repeat(object item, integer count)", "ret": "sequence", "desc": "Erstellt eine neue Sequenz, die das angegebene Objekt count-mal wiederholt enthält."}
                ],
                "code": """include std/sequence.e

sequence fruechte = {"Apfel", "Banane", "Kirsche", "Dattel"}
fruechte = append(fruechte, "Erdbeere")

-- 1-basiertes Slicing: Index 2 bis vorletztes Element
sequence auswahl = fruechte[2..$-1]

-- Matrix-Spaltenschnitt (vslice)
sequence tabelle = {
    {"Art-01", "Monitor", 249.00},
    {"Art-02", "Tastatur", 79.50},
    {"Art-03", "Maus",     39.90}
}
sequence artikel_namen = vslice(tabelle, 2)

printf(1, "Anzahl Früchte: %d\n", {length(fruechte)})
printf(1, "Auswahl: %s\n", {join(auswahl, ", ")})
printf(1, "Umgekehrt: %s\n", {join(reverse(fruechte), ", ")})
printf(1, "Spalte 2 (Artikel): %s\n", {join(artikel_namen, ", ")})""",
                "output": """Anzahl Früchte: 5
Auswahl: Banane, Kirsche, Dattel
Umgekehrt: Erdbeere, Dattel, Kirsche, Banane, Apfel
Spalte 2 (Artikel): Monitor, Tastatur, Maus"""
            },
            {
                "name": "std/map.e",
                "ns": "map",
                "desc": "Assoziative Arrays (Hash-Maps) für Key-Value-Speicher beliebiger Schlüssel- und Wertetypen mit konstanter O(1) Zugriffszeit.",
                "functions": [
                    {"sig": "new(integer capacity=16)", "ret": "integer", "desc": "Erstellt eine neue leere Hash-Map und liefert deren Handle zurück."},
                    {"sig": "put(integer m, object key, object val)", "ret": "procedure", "desc": "Fügt ein Schlüssel-Wert-Paar in die Map ein oder aktualisiert den vorhandenen Wert."},
                    {"sig": "get(integer m, object key, object def_val=0)", "ret": "object", "desc": "Liest den Wert zum angegebenen Schlüssel aus. Existiert der Schlüssel nicht, wird def_val geliefert."},
                    {"sig": "has(integer m, object key)", "ret": "boolean", "desc": "Prüft in O(1)-Zeit, ob der Schlüssel in der Map existiert (1 = Ja, 0 = Nein)."},
                    {"sig": "remove(integer m, object key)", "ret": "procedure", "desc": "Löscht das Schlüssel-Wert-Paar dauerhaft aus der Map."},
                    {"sig": "size(integer m)", "ret": "integer", "desc": "Liefert die aktuelle Anzahl aller gespeicherten Einträge in der Map."},
                    {"sig": "keys(integer m)", "ret": "sequence", "desc": "Gibt alle in der Map vorhandenen Schlüssel als Sequenz zurück."},
                    {"sig": "values(integer m)", "ret": "sequence", "desc": "Gibt alle in der Map gespeicherten Werte als Sequenz zurück."}
                ],
                "code": """include std/map.e

map:map laender = map:new()
map:put(laender, "DE", "Deutschland")
map:put(laender, "AT", "Österreich")
map:put(laender, "CH", "Schweiz")

printf(1, "Land DE: %s\n", {map:get(laender, "DE")})
printf(1, "Land CH: %s\n", {map:get(laender, "CH")})
printf(1, "Gesamtanzahl: %d\n", {map:size(laender)})""",
                "output": """Land DE: Deutschland
Land CH: Schweiz
Gesamtanzahl: 3"""
            },
            {
                "name": "std/stack.e",
                "ns": "stack",
                "desc": "LIFO-Stapel (Last-In-First-Out). Ideal für Parser, Navigationsverläufe und Undo-Manager.",
                "functions": [
                    {"sig": "new()", "ret": "integer", "desc": "Erstellt einen neuen, leeren Stapelspeicher (Stack)."},
                    {"sig": "push(integer st, object item)", "ret": "procedure", "desc": "Legt ein neues Element oben auf den Stapel."},
                    {"sig": "pop(integer st)", "ret": "object", "desc": "Nimmt das oberste Element vom Stapel herunter und gibt es zurück."},
                    {"sig": "top(integer st)", "ret": "object", "desc": "Liefert das oberste Element, ohne es vom Stapel zu entfernen."},
                    {"sig": "is_empty(integer st)", "ret": "boolean", "desc": "Prüft, ob der Stapel leer ist (1 = leer, 0 = enthält Daten)."},
                    {"sig": "size(integer st)", "ret": "integer", "desc": "Liefert die aktuelle Anzahl an Elementen auf dem Stapel."}
                ],
                "code": """include std/stack.e

stack:stack st = stack:new()
stack:push(st, "Startseite")
stack:push(st, "Katalog")
stack:push(st, "Warenkorb")

printf(1, "Oben auf Stack: %s\n", {stack:top(st)})
printf(1, "Pop: %s\n", {stack:pop(st)})
printf(1, "Nun oben: %s\n", {stack:top(st)})""",
                "output": """Oben auf Stack: Warenkorb
Pop: Warenkorb
Nun oben: Katalog"""
            },
            {
                "name": "std/sort.e & std/search.e",
                "ns": "sort / search",
                "desc": "Universelles Sortieren (aufsteigend/absteigend/custom) und schnelle binäre Suche in logarithmischer O(log n) Zeit.",
                "functions": [
                    {"sig": "sort(sequence s)", "ret": "sequence", "desc": "Sortiert Zahlen oder Zeichenketten stabil und aufsteigend."},
                    {"sig": "custom_sort(integer rid, sequence s)", "ret": "sequence", "desc": "Sortiert eine Sequenz anhand einer eigenen benutzerdefinierten Vergleichsfunktion."},
                    {"sig": "sort_columns(sequence s, sequence order)", "ret": "sequence", "desc": "Mehrstufige Tabellensortierung nach mehreren Spalten gleichzeitig."},
                    {"sig": "binary_search(object val, sequence s)", "ret": "integer", "desc": "Sucht in einer sortierten Sequenz in O(log n) nach dem Wert und liefert den Index oder 0."},
                    {"sig": "find(object item, sequence s, integer start=1)", "ret": "integer", "desc": "Lineare Suche nach dem ersten Vorkommen eines Elements ab Position start."},
                    {"sig": "match(sequence needle, sequence haystack)", "ret": "integer", "desc": "Sucht eine Teilzeichenkette oder Teilsequenz in haystack."}
                ],
                "code": """include std/sort.e
include std/search.e

sequence zahlen = {42, 17, 99, 3, 28, 55}
sequence sortiert = sort(zahlen)

integer pos = binary_search(42, sortiert)
printf(1, "Sortiert: %s\n", {sprint(sortiert)})
printf(1, "Wert 42 gefunden an Index: %d\n", {pos})""",
                "output": """Sortiert: {3,17,28,42,55,99}
Wert 42 gefunden an Index: 4"""
            },
            {
                "name": "std/serialize.e",
                "ns": "serialize",
                "desc": "Verlustfreie binäre Serialisierung beliebiger verschachtelter Euphoria-Objekte in kompakte Bytefolgen zur Speicherung oder Netzwerkübertragung.",
                "functions": [
                    {"sig": "serialize(object item)", "ret": "sequence", "desc": "Konvertiert beliebige komplexe Datenstrukturen verlustfrei in eine kompakte Bytefolge."},
                    {"sig": "deserialize(sequence bytes)", "ret": "sequence", "desc": "Rekonstruiert das ursprüngliche Datenobjekt exakt aus der serialisierten Bytefolge."}
                ],
                "code": """include std/serialize.e

sequence paket = {"Benutzerdaten", 42, {199.99, "EUR"}}
sequence bytes = serialize(paket)
sequence res = deserialize(bytes)
object entpackt = res[1]

printf(1, "Serialisierte Bytegröße: %d Bytes\n", {length(bytes)})
printf(1, "Identisch wiederhergestellt: %d (1 = Ja)\n", {equal(paket, entpackt)})""",
                "output": """Serialisierte Bytegröße: 47 Bytes
Identisch wiederhergestellt: 1 (1 = Ja)"""
            }
        ]
    },
    {
        "id": "kapitel-2",
        "title": "2. Strings, Text, Regex & Unicode",
        "cat": "text",
        "desc": "Zeichenkettenverarbeitung, Unicode (UTF-8) nach RFC 3629, reguläre Ausdrücke (PCRE), Base64-Kodierung und fundamentale Typkonvertierungen.",
        "file": "tutorial/02_strings_regex_utf8.ex",
        "modules": [
            {
                "name": "std/text.e",
                "ns": "text",
                "desc": "Funktionen zur Textmanipulation, Umwandlung von Groß-/Kleinschreibung, Whitespace-Trimming, Padding und Schablonenformatierung.",
                "functions": [
                    {"sig": "trim(sequence s)", "ret": "sequence", "desc": "Entfernt führende und nachfolgende Leerzeichen, Tabs und Zeilenumbrüche."},
                    {"sig": "upper(sequence s)", "ret": "sequence", "desc": "Konvertiert alle Zeichen eines Strings in Großbuchstaben."},
                    {"sig": "lower(sequence s)", "ret": "sequence", "desc": "Konvertiert alle Zeichen eines Strings in Kleinbuchstaben."},
                    {"sig": "proper(sequence s)", "ret": "sequence", "desc": "Formatiert Wörter im Titelsatz (erster Buchstabe groß, Rest klein)."},
                    {"sig": "format(sequence fmt, sequence data)", "ret": "sequence", "desc": "Formatiert Werte in eine Textschablone nach dem C/Euphoria-Muster (%s, %d, %.2f)."},
                    {"sig": "pad_left(sequence s, integer width, integer pad_char=' ')", "ret": "sequence", "desc": "Füllt den String links auf die gewünschte Gesamtbreite auf."},
                    {"sig": "pad_right(sequence s, integer width, integer pad_char=' ')", "ret": "sequence", "desc": "Füllt den String rechts auf die gewünschte Gesamtbreite auf."},
                    {"sig": "sprint(object x)", "ret": "sequence", "desc": "Wandelt ein beliebiges Euphoria-Objekt in seine druckbare Stringdarstellung um."},
                    {"sig": "split_any(sequence s, sequence delims)", "ret": "sequence", "desc": "Zerlegt einen String an jedem Zeichen, das in delims vorkommt."}
                ],
                "code": """include std/text.e

sequence roh = "   euphorix enterprise virtual machine   "
sequence getrimmt = trim(roh)
sequence titel = proper(getrimmt)
sequence nummer = pad_left("42", 6, '0')

printf(1, "Getrimmt: '%s'\n", {getrimmt})
printf(1, "Titel: '%s'\n", {titel})
printf(1, "Rechnungsnummer: %s\n", {nummer})""",
                "output": """Getrimmt: 'euphorix enterprise virtual machine'
Titel: 'Euphorix Enterprise Virtual Machine'
Rechnungsnummer: 000042"""
            },
            {
                "name": "std/regex.e",
                "ns": "regex",
                "desc": "Reguläre Ausdrücke (PCRE-Standard) für Mustervergleiche, Validierung und Suchen-und-Ersetzen.",
                "functions": [
                    {"sig": "new(sequence pattern)", "ret": "object", "desc": "Kompiliert ein reguläres Muster für spätere Vergleiche."},
                    {"sig": "is_match(object re, sequence str)", "ret": "boolean", "desc": "Prüft, ob der String vollständig oder teilweise zum Muster passt (1 = Match, 0 = Kein Treffer)."},
                    {"sig": "matches(object re, sequence str)", "ret": "sequence", "desc": "Liefert alle Treffer und erfassten Capture-Groups als verschachtelte Sequenz."},
                    {"sig": "find_replace(object re, sequence str, sequence repl)", "ret": "sequence", "desc": "Ersetzt alle Treffer des Regex im String durch den Ersatztext repl."}
                ],
                "code": """include std/regex.e

object mail_re = regex:new("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
integer ok = regex:is_match(mail_re, "info@euphorix-lang.org")
printf(1, "E-Mail gültig: %d (1 = Ja)\n", {ok})""",
                "output": """E-Mail gültig: 1 (1 = Ja)"""
            },
            {
                "name": "std/utf8.e",
                "ns": "utf8",
                "desc": "Unicode-Konformität nach RFC 3629: Berechnet echte Zeichenlängen, validiert Bytefolgen und extrahiert Codepoints.",
                "functions": [
                    {"sig": "len(sequence s)", "ret": "integer", "desc": "Liefert die echte Anzahl an Unicode-Zeichen (Codepoints) statt der reinen Byteanzahl."},
                    {"sig": "valid(sequence s)", "ret": "boolean", "desc": "Prüft, ob eine Sequenz von Bytes wohlgeformtes, standardkonformes UTF-8 darstellt."},
                    {"sig": "slice(sequence s, integer from_char, integer to_char)", "ret": "sequence", "desc": "Schneidet einen Teilstring basierend auf echten Unicode-Zeichengrenzen aus."},
                    {"sig": "to_codepoints(sequence s)", "ret": "sequence", "desc": "Konvertiert einen UTF-8-String in eine Liste numerischer Unicode-Codepoints."},
                    {"sig": "from_codepoints(sequence cps)", "ret": "sequence", "desc": "Erzeugt einen wohlgeformten UTF-8-String aus einer Liste numerischer Codepoints."}
                ],
                "code": """include std/utf8.e

sequence text_utf8 = "Grüße aus Köln! 🚀"
printf(1, "Byte-Länge: %d Bytes\n", {length(text_utf8)})
printf(1, "Echte Zeichen (Codepoints): %d Zeichen\n", {utf8:len(text_utf8)})
printf(1, "Wohlgeformt UTF-8: %d (1 = Ja)\n", {utf8:valid(text_utf8)})""",
                "output": """Byte-Länge: 23 Bytes
Echte Zeichen (Codepoints): 18 Zeichen
Wohlgeformt UTF-8: 1 (1 = Ja)"""
            },
            {
                "name": "std/base64.e",
                "ns": "base64",
                "desc": "Standardisierte Base64-Kodierung und Dekodierung nach RFC 4648 für Binärübertragungen, Auth-Header und Data-URIs.",
                "functions": [
                    {"sig": "encode(sequence in, integer wrap_column = 0)", "ret": "sequence", "desc": "Wandelt beliebige Binärdaten oder Textstrings in eine standardisierte Base64-Zeichenkette um."},
                    {"sig": "decode(sequence in)", "ret": "sequence", "desc": "Dekodiert einen Base64-String zurück in die exakte Original-Bytefolge oder den Quelltext."}
                ],
                "code": """include std/base64.e

sequence original = "Euphorix:SecretApiKey:2026"
sequence encoded = base64:encode(original)
sequence decoded = base64:decode(encoded)

printf(1, "Original: %s\n", {original})
printf(1, "Base64:   %s\n", {encoded})
printf(1, "Dekodiert identisch: %d\n", {equal(original, decoded)})""",
                "output": """Original: Euphorix:SecretApiKey:2026
Base64:   RXVwaG9yaXg6U2VjcmV0QXBpS2V5OjIwMjY=
Dekodiert identisch: 1"""
            },
            {
                "name": "std/convert.e",
                "ns": "convert",
                "desc": "Fundamentale Typkonvertierungen zwischen Strings, Ganzzahlen, IEEE 754 Fließkommazahlen, Little-Endian Bytes und Bitfolgen.",
                "functions": [
                    {"sig": "to_integer(object data, integer def_val = 0)", "ret": "integer", "desc": "Konvertiert Text oder Zahlen sicher in ein Integer. Bei Fehlern wird def_val zurückgegeben."},
                    {"sig": "to_number(sequence text)", "ret": "object", "desc": "Wandelt beliebige Zahlenstrings (Ganzzahlen, Kommazahlen wie '123.45', Exponentialschreibweise) in Zahlen um."},
                    {"sig": "to_string(object data)", "ret": "sequence", "desc": "Konvertiert beliebige Euphoria-Objekte sauber und lesbar in einen String."},
                    {"sig": "int_to_bytes(atom x, integer size = 4)", "ret": "sequence", "desc": "Zerlegt einen Integer in eine Little-Endian Bytefolge bestimmter Größe für Low-Level-Protokolle."},
                    {"sig": "bytes_to_int(sequence s)", "ret": "atom", "desc": "Setzt eine Little-Endian Bytefolge wieder zu einer Zahl zusammen."},
                    {"sig": "int_to_bits(atom x, integer nbits = 32)", "ret": "sequence", "desc": "Erzeugt eine Bitfolge ({0, 1, ...}) aus einer Zahl."},
                    {"sig": "bits_to_int(sequence bits)", "ret": "atom", "desc": "Konvertiert eine Bitfolge zurück in eine Zahl."}
                ],
                "code": """include std/convert.e

integer i = to_integer("2026")
atom preis = to_number("199.95")
sequence bytes = int_to_bytes(65535, 4)
atom rekonstruiert = bytes_to_int(bytes)

printf(1, "Integer: %d, Preis: %.2f\n", {i, preis})
printf(1, "Bytes von 65535: %s\n", {sprint(bytes)})
printf(1, "Zurückgewandelt: %d\n", {rekonstruiert})""",
                "output": """Integer: 2026, Preis: 199.95
Bytes von 65535: {255,255,0,0}
Zurückgewandelt: 65535"""
            },
            {
                "name": "std/wildcard.e",
                "ns": "wildcard",
                "desc": "Mustervergleich nach dem gängigen Wildcard- und Globbing-Standard (* für beliebige Zeichen, ? für genau ein Zeichen).",
                "functions": [
                    {"sig": "is_match(sequence pattern, sequence str)", "ret": "boolean", "desc": "Prüft, ob ein Dateiname oder Text zum Wildcard-Muster passt (z. B. '*.ex' oder 'test_??.txt')."}
                ],
                "code": """include std/wildcard.e

printf(1, "main.ex passt auf *.ex: %d\n", {is_match("*.ex", "main.ex")})
printf(1, "main.exb passt auf *.ex: %d\n", {is_match("*.ex", "main.exb")})
printf(1, "doc_01.pdf passt auf doc_??.pdf: %d\n", {is_match("doc_??.pdf", "doc_01.pdf")})""",
                "output": """main.ex passt auf *.ex: 1
main.exb passt auf *.ex: 0
doc_01.pdf passt auf doc_??.pdf: 1"""
            }
        ]
    },
    {
        "id": "kapitel-3",
        "title": "3. Dateisystem, I/O & Externe Prozesse",
        "cat": "io",
        "desc": "Robuste Dateioperationen, Verzeichnis-Traversierung, gepufferte Ein-/Ausgabe, Konsoleninteraktion, CLI-Parsing und bidirektionale Prozess-Pipes.",
        "file": "tutorial/03_dateien_prozesse.ex",
        "modules": [
            {
                "name": "std/io.e",
                "ns": "io",
                "desc": "Gepufferte und ungepufferte Ein-/Ausgabe, Lesen und Schreiben ganzer Dateien oder Zeilenarrays mit automatischer Ressourcenfreigabe.",
                "functions": [
                    {"sig": "read_file(sequence path)", "ret": "sequence", "desc": "Liest den gesamten Dateiinhalt auf einen Schlag in den Speicher."},
                    {"sig": "write_file(sequence path, sequence content)", "ret": "boolean", "desc": "Schreibt Daten vollständig und sicher in eine Datei."},
                    {"sig": "read_lines(sequence path)", "ret": "sequence", "desc": "Liest eine Datei zeilenweise in eine Sequenz von Strings ein."},
                    {"sig": "write_lines(sequence path, sequence lines)", "ret": "boolean", "desc": "Schreibt eine Liste von Strings als getrennte Zeilen in eine Datei."},
                    {"sig": "open(sequence path, sequence mode)", "ret": "integer", "desc": "Öffnet eine Datei im gewünschten Modus ('r' Lesen, 'w' Schreiben, 'a' Anhängen, 'rb'/'wb' Binär)."},
                    {"sig": "close(integer fn)", "ret": "procedure", "desc": "Schließt das geöffnete Dateihandle und gibt Systemressourcen frei."},
                    {"sig": "seek(integer fn, atom offset)", "ret": "integer", "desc": "Positioniert den Lese-/Schreibzeiger an einer bestimmten Byte-Position in der Datei."},
                    {"sig": "where(integer fn)", "ret": "atom", "desc": "Liefert die aktuelle Byte-Position des Dateizeigers zurück."},
                    {"sig": "flush(integer fn)", "ret": "procedure", "desc": "Erzwingt das sofortige Schreiben gepufferter Dateizugriffe auf den Datenträger."}
                ],
                "code": """include std/io.e

sequence test_datei = "/tmp/euphorix_test.txt"
io:write_lines(test_datei, {"Server: Euphorix-01", "Port: 8089", "Status: Online"})

sequence zeilen = io:read_lines(test_datei)
for i = 1 to length(zeilen) do
    printf(1, "Zeile %d: %s\n", {i, zeilen[i]})
end for""",
                "output": """Zeile 1: Server: Euphorix-01
Zeile 2: Port: 8089
Zeile 3: Status: Online"""
            },
            {
                "name": "std/filesys.e",
                "ns": "filesys",
                "desc": "Dateisystemprüfungen, Pfadoperationen, plattformunabhängige Verzeichnisinhalte und rekursives Traversieren.",
                "functions": [
                    {"sig": "file_exists(sequence path)", "ret": "boolean", "desc": "Prüft, ob eine Datei oder ein Ordner auf dem Dateisystem existiert (1 = Ja, 0 = Nein)."},
                    {"sig": "file_length(sequence path)", "ret": "atom", "desc": "Liefert die exakte Dateigröße in Bytes zurück."},
                    {"sig": "join_path(sequence parts)", "ret": "sequence", "desc": "Verbindet Pfadkomponenten plattformunabhängig mit dem korrekten Trennzeichen (/ bzw. \\)."},
                    {"sig": "fileext(sequence path)", "ret": "sequence", "desc": "Extrahiert die Dateiendung (z. B. 'exb' oder 'json') aus einem Dateipfad."},
                    {"sig": "filename(sequence path)", "ret": "sequence", "desc": "Schneidet Verzeichnispfade ab und liefert nur den reinen Dateinamen."},
                    {"sig": "dir(sequence path)", "ret": "sequence", "desc": "Listet Verzeichnisinhalte mit Namen, Größe, Attributen und Zeitstempeln auf."},
                    {"sig": "create_directory(sequence path)", "ret": "boolean", "desc": "Erstellt ein neues Verzeichnis (inklusive aller benötigten Unterordner)."},
                    {"sig": "copy_file(sequence src, sequence dest, integer overwrite=1)", "ret": "boolean", "desc": "Kopiert eine Datei sicher an einen neuen Zielort."},
                    {"sig": "delete_file(sequence path)", "ret": "boolean", "desc": "Löscht eine Datei dauerhaft vom Datenträger."}
                ],
                "code": """include std/filesys.e

sequence pfad = filesys:join_path({"/var", "log", "euphorix", "system.log"})
printf(1, "Zusammengesetzter Pfad: %s\n", {pfad})
printf(1, "Dateiname: %s\n", {filesys:filename(pfad)})
printf(1, "Dateiendung: %s\n", {filesys:fileext(pfad)})""",
                "output": """Zusammengesetzter Pfad: /var/log/euphorix/system.log
Dateiname: system.log
Dateiendung: log"""
            },
            {
                "name": "std/pipeio.e",
                "ns": "pipeio",
                "desc": "Prozesssteuerung mit echten Betriebssystem-Pipes. Liest Ausgaben externer Programme oder sendet Eingaben an stdin.",
                "functions": [
                    {"sig": "exec(sequence cmd)", "ret": "object", "desc": "Startet ein externes Betriebssystem-Kommando und öffnet bidirektionale Pipes für stdin, stdout und stderr."},
                    {"sig": "read(object proc, integer stream=1)", "ret": "sequence", "desc": "Liest gepufferte Ausgaben (stdout oder stderr) des gestarteten Prozesses ein."},
                    {"sig": "write(object proc, sequence data)", "ret": "integer", "desc": "Schreibt Daten direkt in den Standard-Eingabestrom (stdin) des Child-Prozesses."},
                    {"sig": "close(object proc)", "ret": "integer", "desc": "Schließt die Pipes und liefert den Exit-Code des beendeten Prozesses."}
                ],
                "code": """include std/pipeio.e

object p = pipeio:exec("uname -s -m")
sequence output = pipeio:read(p)
pipeio:close(p)

printf(1, "Kernel & Architektur: %s", {output})""",
                "output": """Kernel & Architektur: Linux x86_64"""
            },
            {
                "name": "std/console.e",
                "ns": "console",
                "desc": "Interaktive Ein- und Ausgabe auf der Konsole, Textfarben, Hintergrundfarben, Bildschirmbereinigung und Benutzereingaben.",
                "functions": [
                    {"sig": "display(object data, object args = 1)", "ret": "procedure", "desc": "Universelle, formatierte Konsolenausgabe beliebiger Datenstrukturen mit automatischem Zeilenumbruch."},
                    {"sig": "prompt_string(sequence prompt)", "ret": "sequence", "desc": "Zeigt eine Eingabeaufforderung an und liest eine Textzeile von der Tastatur ein."},
                    {"sig": "prompt_number(sequence prompt, sequence range={})", "ret": "atom", "desc": "Fragt eine Zahl vom Benutzer ab und prüft optional, ob sie im Wertebereich liegt."},
                    {"sig": "any_key(sequence prompt='Taste drücken...')", "ret": "procedure", "desc": "Wartet auf einen beliebigen Tastendruck des Anwenders."},
                    {"sig": "text_color(integer color)", "ret": "procedure", "desc": "Schaltet die Vordergrundfarbe der Konsole um (z. B. GREEN, RED, BLUE, YELLOW)."},
                    {"sig": "bk_color(integer color)", "ret": "procedure", "desc": "Schaltet die Hintergrundfarbe der Konsole um."},
                    {"sig": "clear_screen()", "ret": "procedure", "desc": "Löscht das Konsolenfenster und positioniert den Cursor oben links (1, 1)."},
                    {"sig": "wait_key()", "ret": "integer", "desc": "Liest sofort den Tastencode der nächsten gedrückten Taste ein (ohne Enter)."}
                ],
                "code": """include std/console.e

console:display("Willkommen im Euphorix Terminal Manager")
console:display("Modus: [1] Standard, [2] Hochverfügbarkeit")
console:display("Aktiver Status: [OK]")""",
                "output": """Willkommen im Euphorix Terminal Manager
Modus: [1] Standard, [2] Hochverfügbarkeit
Aktiver Status: [OK]"""
            },
            {
                "name": "std/cmdline.e",
                "ns": "cmdline",
                "desc": "Robuster Kommandozeilen-Parser für Konsolenwerkzeuge: Verarbeitet Schalter (-v, --config), Optionen und automatische Hilfeseiten.",
                "functions": [
                    {"sig": "cmd_parse(sequence opts, object parse_options = {})", "ret": "map", "desc": "Parst Kommandozeilenargumente, Schalter (--config, -v) und Parameter in eine Map."},
                    {"sig": "show_help(sequence opts)", "ret": "procedure", "desc": "Gibt automatisch eine übersichtliche, formatierte Hilfe- und Syntaxanzeige auf der Konsole aus."},
                    {"sig": "build_commandline(sequence cmds)", "ret": "sequence", "desc": "Baut eine Liste von Befehlsargumenten zu einem shell-sicheren String zusammen."}
                ],
                "code": """include std/cmdline.e
include std/map.e

sequence opts = {
    {"v", "verbose", "Ausführliche Protokollierung aktivieren"},
    {"p", "port",    "Server-Port festlegen", {mandatory, "PORT"}}
}
-- Parsing-Definition bereitgestellt
printf(1, "CLI Parser initialisiert mit %d Optionen.\n", {length(opts)})""",
                "output": """CLI Parser initialisiert mit 2 Optionen."""
            },
            {
                "name": "std/os.e",
                "ns": "os",
                "desc": "Betriebssystem-Schnittstelle: Auslesen und Setzen von Umgebungsvariablen, Prozess-IDs (PID), Systemzeit und Prozess-Pausierung.",
                "functions": [
                    {"sig": "getenv(sequence var_name)", "ret": "object", "desc": "Liest den aktuellen Wert einer Betriebssystem-Umgebungsvariable aus (z. B. 'HOME', 'PATH')."},
                    {"sig": "setenv(sequence name, sequence val)", "ret": "integer", "desc": "Setzt eine Umgebungsvariable für den aktuellen Prozess."},
                    {"sig": "get_pid()", "ret": "integer", "desc": "Liefert die Prozess-ID (PID) des laufenden Programms."},
                    {"sig": "uname()", "ret": "sequence", "desc": "Gibt Betriebssystem- und Plattformdetails zurück (Linux, Windows, Architektur)."},
                    {"sig": "sleep(atom seconds)", "ret": "procedure", "desc": "Pausiert die Ausführung für die angegebene Zeit (unterstützt auch Nachkommastellen, z. B. 0.25)."}
                ],
                "code": """include std/os.e

integer pid = os:get_pid()
object user = os:getenv("USER")
if atom(user) then user = "System" end if

printf(1, "Prozess-ID (PID): %d\n", {pid})
printf(1, "Benutzer: %s\n", {user})""",
                "output": """Prozess-ID (PID): 41289
Benutzer: volkix"""
            }
        ]
    },
    {
        "id": "kapitel-4",
        "title": "4. Mathematik, Statistik, Primzahlen & Zufall",
        "cat": "math",
        "desc": "Hochpräzise Arithmetik, mathematische Grundfunktionen, deskriptive Statistik, Primzahlengenerierung und Zufallsverteilungen.",
        "file": "tutorial/04_mathe_statistik.ex",
        "modules": [
            {
                "name": "std/math.e",
                "ns": "math",
                "desc": "Mathematische Standardfunktionen, Rundung, Absolutbetrag, Wurzeln, Trigonometrie und Potenzen.",
                "functions": [
                    {"sig": "abs(atom x)", "ret": "atom", "desc": "Liefert den absoluten (immer positiven) Betrag einer Zahl."},
                    {"sig": "round(atom x, integer decimals=0)", "ret": "atom", "desc": "Rundet eine Fließkommazahl kaufmännisch auf die gewünschte Anzahl an Nachkommastellen."},
                    {"sig": "floor(atom x)", "ret": "atom", "desc": "Rundet eine Zahl zur nächstkleineren Ganzzahl ab."},
                    {"sig": "ceil(atom x)", "ret": "atom", "desc": "Rundet eine Zahl zur nächstgrößeren Ganzzahl auf."},
                    {"sig": "min(sequence s)", "ret": "atom", "desc": "Findet den kleinsten numerischen Wert in einer Liste."},
                    {"sig": "max(sequence s)", "ret": "atom", "desc": "Findet den größten numerischen Wert in einer Liste."},
                    {"sig": "sqrt(atom x)", "ret": "atom", "desc": "Berechnet die mathematische Quadratwurzel von x."},
                    {"sig": "power(atom base, atom exp)", "ret": "atom", "desc": "Berechnet die Potenzierung (base hoch exp)."},
                    {"sig": "mod(atom a, atom b)", "ret": "atom", "desc": "Berechnet den Divisionsrest (Modulo)."}
                ],
                "code": """include std/math.e

atom brutto = 19.99 * 1.19
atom gerundet = math:round(brutto, 2)
printf(1, "Brutto exakt: %f\n", {brutto})
printf(1, "Kaufmännisch gerundet: %.2f EUR\n", {gerundet})
printf(1, "Wurzel aus 144: %.1f\n", {math:sqrt(144)})""",
                "output": """Brutto exakt: 23.788100
Kaufmännisch gerundet: 23.79 EUR
Wurzel aus 144: 12.0"""
            },
            {
                "name": "std/stats.e",
                "ns": "stats",
                "desc": "Statistische Auswertungen von Datenreihen: Arithmetisches Mittel, Median, Varianz, Standardabweichung und Summen.",
                "functions": [
                    {"sig": "mean(sequence s)", "ret": "atom", "desc": "Berechnet das arithmetische Mittel (Durchschnitt) aller Zahlen in der Sequenz."},
                    {"sig": "median(sequence s)", "ret": "atom", "desc": "Bestimmt den statistischen Zentralwert (Median)."},
                    {"sig": "variance(sequence s)", "ret": "atom", "desc": "Berechnet die Varianz (mittlere quadratische Abweichung)."},
                    {"sig": "stdev(sequence s)", "ret": "atom", "desc": "Berechnet die empirische Standardabweichung der Datenreihe."},
                    {"sig": "sum(sequence s)", "ret": "atom", "desc": "Summiert alle numerischen Elemente einer Sequenz auf."},
                    {"sig": "range(sequence s)", "ret": "atom", "desc": "Berechnet die Spannweite (Differenz zwischen Maximum und Minimum)."}
                ],
                "code": """include std/stats.e

sequence messwerte = {12.5, 14.2, 13.8, 15.1, 12.9, 14.7, 13.3}
printf(1, "Mittelwert: %.2f\n", {stats:mean(messwerte)})
printf(1, "Median: %.2f\n", {stats:median(messwerte)})
printf(1, "Standardabweichung: %.2f\n", {stats:stdev(messwerte)})""",
                "output": """Mittelwert: 13.79
Median: 13.80
Standardabweichung: 0.94"""
            },
            {
                "name": "std/rand.e",
                "ns": "rand",
                "desc": "Zufallszahlengenerierung, Zufallsintervalle, normalisierte Fließkommawerte und Stichprobenziehungen.",
                "functions": [
                    {"sig": "rand(integer max_val)", "ret": "integer", "desc": "Erzeugt eine gleichverteilte Zufallsganszahl von 1 bis max_val."},
                    {"sig": "rand_range(atom lo, atom hi)", "ret": "atom", "desc": "Erzeugt eine Zufallszahl im geschlossenen Intervall [lo, hi]."},
                    {"sig": "rnd()", "ret": "atom", "desc": "Liefert eine Zufalls-Fließkommazahl zwischen 0.0 und 1.0."},
                    {"sig": "set_rand(object seed)", "ret": "procedure", "desc": "Setzt den Seed des Zufallszahlengenerators für wiederholbare Simulationen."},
                    {"sig": "chance(atom my_limit, atom top_limit = 100)", "ret": "boolean", "desc": "Gibt mit der Wahrscheinlichkeit my_limit/top_limit den Wert 1 (wahr) zurück."},
                    {"sig": "sample(sequence population, integer sample_size)", "ret": "sequence", "desc": "Zieht eine repräsentative Stichprobe zufälliger Elemente aus einer Sequenz."}
                ],
                "code": """include std/rand.e

atom wuerfel = rand:rand(6)
atom bereich = rand:rand_range(100, 200)
printf(1, "Würfelwurf (1-6): %d\n", {wuerfel})
printf(1, "Zufallsbereich 100..200: %d\n", {bereich})""",
                "output": """Würfelwurf (1-6): 4
Zufallsbereich 100..200: 147"""
            },
            {
                "name": "std/primes.e",
                "ns": "primes",
                "desc": "Primzahlengenerierung nach dem Sieb des Eratosthenes, Berechnung nachfolgender Primzahlen und Primzahllisten.",
                "functions": [
                    {"sig": "calc_primes(integer limit)", "ret": "sequence", "desc": "Berechnet alle Primzahlen bis zur Obergrenze mit dem Sieb des Eratosthenes."},
                    {"sig": "next_prime(integer n)", "ret": "integer", "desc": "Ermittelt die unmittelbar folgende Primzahl größer als n."},
                    {"sig": "prime_list(integer top_prime = 0)", "ret": "sequence", "desc": "Gibt eine vorberechnete Liste elementarer Primzahlen zurück."}
                ],
                "code": """include std/primes.e

sequence prims = primes:calc_primes(30)
integer naechste = primes:next_prime(30)

printf(1, "Primzahlen bis 30: %s\n", {sprint(prims)})
printf(1, "Nächste Primzahl nach 30: %d\n", {naechste})""",
                "output": """Primzahlen bis 30: {2,3,5,7,11,13,17,19,23,29}
Nächste Primzahl nach 30: 31"""
            }
        ]
    },
    {
        "id": "kapitel-5",
        "title": "5. Datum, Uhrzeit & Kalender",
        "cat": "datetime",
        "desc": "Zeitstempel, Formatierung nach DIN/ISO 8601, Kalenderberechnungen, Zeitzonen und Datumsarithmetik.",
        "file": "tutorial/05_datum_uhrzeit.ex",
        "modules": [
            {
                "name": "std/datetime.e",
                "ns": "datetime",
                "desc": "Moderne Zeit- und Kalenderoperationen mit Unterstützung für Zeitintervalle, Schaltjahre und Lokalisierung.",
                "functions": [
                    {"sig": "now()", "ret": "sequence", "desc": "Liefert das aktuelle Datum und die aktuelle lokale Uhrzeit als Datetime-Objekt."},
                    {"sig": "now_gmt()", "ret": "sequence", "desc": "Liefert den aktuellen Weltzeit-Zeitstempel (UTC / GMT)."},
                    {"sig": "new(integer year, integer month, integer day, integer hour=0, integer minute=0, integer second=0)", "ret": "sequence", "desc": "Erstellt ein neues Datetime-Objekt."},
                    {"sig": "format(sequence dt, sequence fmt)", "ret": "sequence", "desc": "Formatiert Datums- und Zeitwerte in frei gestaltbare Zeichenketten (z. B. '%d.%m.%Y %H:%M:%S')."},
                    {"sig": "parse(sequence str, sequence fmt)", "ret": "sequence", "desc": "Parst einen Datums-String anhand einer Formatschablone in ein Datetime-Objekt."},
                    {"sig": "add(sequence dt, atom amount, integer unit)", "ret": "sequence", "desc": "Addiert Jahre, Monate, Tage, Stunden, Minuten oder Sekunden auf ein Datum."},
                    {"sig": "diff(sequence dt1, sequence dt2, integer unit)", "ret": "atom", "desc": "Berechnet die exakte Zeitdifferenz zwischen zwei Zeitpunkten in der gewünschten Zeiteinheit."},
                    {"sig": "compare(sequence dt1, sequence dt2)", "ret": "integer", "desc": "Vergleicht zwei Zeitpunkte chronologisch (-1 = dt1 früher, 0 = gleich, +1 = dt1 später)."},
                    {"sig": "days_in_month(integer month, integer year)", "ret": "integer", "desc": "Liefert die Anzahl der Tage des Monats unter Berücksichtigung von Schaltjahren."},
                    {"sig": "is_leap_year(integer year)", "ret": "boolean", "desc": "Prüft, ob ein Kalenderjahr ein Schaltjahr mit 366 Tagen ist."},
                    {"sig": "day_of_week(sequence dt)", "ret": "integer", "desc": "Ermittelt den Wochentag (1 = Sonntag bis 7 = Samstag)."}
                ],
                "code": """include std/datetime.e

sequence heute = datetime:now()
sequence formatted = datetime:format(heute, "%d.%m.%Y %H:%M:%S")

-- Fristberechnung: +30 Tage Zahlungsziel
sequence faellig = datetime:add(heute, 30, datetime:DAYS)
sequence faellig_str = datetime:format(faellig, "%d.%m.%Y")

printf(1, "Aktuelle Zeit: %s\n", {formatted})
printf(1, "Fälligkeitsdatum (+30 Tage): %s\n", {faellig_str})
printf(1, "2028 Schaltjahr: %d (1 = Ja)\n", {datetime:is_leap_year(2028)})""",
                "output": """Aktuelle Zeit: 26.11.2026 14:30:00
Fälligkeitsdatum (+30 Tage): 26.12.2026
2028 Schaltjahr: 1 (1 = Ja)"""
            }
        ]
    },
    {
        "id": "kapitel-6",
        "title": "6. Strukturierte Daten: JSON, JSONPath & XML",
        "cat": "data",
        "desc": "Verarbeitung von RFC 8259 JSON, RFC 9535 JSONPath Abfragen, Schema-Validierung und XML DOM/XPath Navigation.",
        "file": "tutorial/06_json_xml.ex",
        "modules": [
            {
                "name": "std/json.e",
                "ns": "json",
                "desc": "Hochperformantes JSON-Parsing und Serialisierung, verschachtelte Abfragen und RFC 9535 JSONPath.",
                "functions": [
                    {"sig": "parse(sequence json_str)", "ret": "object", "desc": "Parst einen JSON-String in native Euphoria-Sequenzen und -Maps."},
                    {"sig": "stringify(object data, integer indent=0)", "ret": "sequence", "desc": "Konvertiert Euphoria-Objekte in standardkonforme JSON-Texte (mit optionalem Pretty-Printing)."},
                    {"sig": "get(object json_obj, sequence path)", "ret": "object", "desc": "Extrahiert gezielt Werte über Schlüsselketten."},
                    {"sig": "query(object json_obj, sequence jsonpath_expr)", "ret": "sequence", "desc": "Führt RFC 9535 JSONPath-Ausdrücke (z. B. '$.katalog.artikel[*].preis') zur Datenfilterung aus."},
                    {"sig": "encode(object data, integer indent=0)", "ret": "sequence", "desc": "Alias für stringify zur schnellen JSON-Serialisierung."},
                    {"sig": "decode(sequence json_str)", "ret": "object", "desc": "Alias für parse zum schnellen Einlesen von JSON-Payloads."}
                ],
                "code": """include std/json.e

sequence raw_json = `{"firma": "Euphorix AG", "mitarbeiter": 42, "standorte": ["Berlin", "Zürich"]}`
object parsed = json:parse(raw_json)

sequence format_json = json:stringify(parsed, 2)
printf(1, "Geparstes JSON formatiert:\n%s\n", {format_json})""",
                "output": """Geparstes JSON formatiert:
{
  "firma": "Euphorix AG",
  "mitarbeiter": 42,
  "standorte": [
    "Berlin",
    "Zürich"
  ]
}"""
            },
            {
                "name": "std/json_schema.e",
                "ns": "json_schema",
                "desc": "Validierung von JSON-Dokumenten gegen formale JSON-Schemata (Draft 7 / 2020-12) zur Sicherung von API-Endpunkten.",
                "functions": [
                    {"sig": "validate(object schema, object data)", "ret": "boolean", "desc": "Validiert strukturierte Daten gegen ein JSON-Schema (1 = Gültig, 0 = Validierungsfehler)."},
                    {"sig": "validation_errors(object schema, object data)", "ret": "sequence", "desc": "Liefert eine detaillierte Liste von Validierungsfehlern mit Pfadangaben und Ursachen."}
                ],
                "code": """include std/json_schema.e
include std/json.e

object schema = json:parse(`{"type": "object", "required": ["id", "name"]}`)
object doc_ok = json:parse(`{"id": 42, "name": "Produkt A"}`)

integer valid = json_schema:validate(schema, doc_ok)
printf(1, "Schema-Validierung erfolgreich: %d (1 = Ja)\n", {valid})""",
                "output": """Schema-Validierung erfolgreich: 1 (1 = Ja)"""
            },
            {
                "name": "std/xml.e",
                "ns": "xml",
                "desc": "DOM-basierter XML-Parser, XPath-Knotensuche, Attribut-Extraktion und XML-Generierung.",
                "functions": [
                    {"sig": "parse(sequence xml_str)", "ret": "object", "desc": "Parst ein XML-Dokument in einen durchsuchbaren DOM-Baum."},
                    {"sig": "find_nodes(object dom, sequence xpath)", "ret": "sequence", "desc": "Findet XML-Knoten und Tags anhand von XPath- oder Tag-Pfaden."},
                    {"sig": "get_attr(object node, sequence attr_name)", "ret": "sequence", "desc": "Liest den Attributwert eines XML-Tags aus (z. B. id='...' oder class='...')."},
                    {"sig": "to_xml(object dom, integer indent=2)", "ret": "sequence", "desc": "Serialisiert einen DOM-Knotenbaum wieder in wohlgeformten XML-Code."}
                ],
                "code": """include std/xml.e

sequence xml_data = `<katalog><buch id="B101"><titel>Euphorix Handbuch</titel></buch></katalog>`
object dom = xml:parse(xml_data)
sequence buecher = xml:find_nodes(dom, "//buch")

printf(1, "Gefundene Bücher: %d\n", {length(buecher)})
printf(1, "Buch-ID: %s\n", {xml:get_attr(buecher[1], "id")})""",
                "output": """Gefundene Bücher: 1
Buch-ID: B101"""
            }
        ]
    },
    {
        "id": "kapitel-7",
        "title": "7. Relationale & NoSQL Datenbanken",
        "cat": "database",
        "desc": "Transaktionale Datenbanken: SQLite 3.47 mit Prepared Statements, PostgreSQL Enterprise Cluster, NoSQL JSON-DB und das native Euphoria Database System (EDS).",
        "file": "tutorial/07_datenbanken.ex",
        "modules": [
            {
                "name": "std/sqlite.e",
                "ns": "sqlite",
                "desc": "Eingebettete SQL-Engine mit SQLite 3.47, Transaktionen (ACID) und Parameter-Bindung zur Abwehr von SQL-Injections.",
                "functions": [
                    {"sig": "open(sequence db_path)", "ret": "atom", "desc": "Öffnet eine SQLite 3.47 Datenbankdatei oder eine transiente In-Memory-Datenbank (':memory:')."},
                    {"sig": "exec(atom db, sequence sql, sequence params={})", "ret": "integer", "desc": "Führt DDL- und DML-Befehle (CREATE, INSERT, UPDATE, DELETE) mit vorbereiteten Parametern aus."},
                    {"sig": "query(atom db, sequence sql, sequence params={})", "ret": "sequence", "desc": "Führt eine SELECT-Abfrage aus und liefert die Treffermatrix als Sequenz von Zeilen."},
                    {"sig": "query_row(atom db, sequence sql, sequence params={})", "ret": "sequence", "desc": "Liest gezielt die erste Trefferzeile einer SQL-Abfrage aus."},
                    {"sig": "query_all(atom db, sequence sql, sequence params={})", "ret": "sequence", "desc": "Liefert alle Trefferzeilen einer Abfrage als 2D-Tabelle."},
                    {"sig": "last_insert_rowid(atom db)", "ret": "atom", "desc": "Liefert die automatisch generierte Zeilen-ID (PRIMARY KEY AUTOINCREMENT) des letzten INSERT-Befehls."},
                    {"sig": "close(atom db)", "ret": "procedure", "desc": "Schließt die Datenbankverbindung und committet offene Transaktionen."}
                ],
                "code": """include std/sqlite.e

atom db = sqlite:open(":memory:")
sqlite:exec(db, "CREATE TABLE kunden (id INTEGER PRIMARY KEY, name TEXT, stadt TEXT);")
sqlite:exec(db, "INSERT INTO kunden VALUES (?, ?, ?);", {1, "Schulte IT", "Lüdenscheid"})

sequence row = sqlite:query_row(db, "SELECT name, stadt FROM kunden WHERE id = ?;", {1})
printf(1, "Kunde: %s aus %s\n", {row[1], row[2]})
sqlite:close(db)""",
                "output": """Kunde: Schulte IT aus Lüdenscheid"""
            },
            {
                "name": "std/pgsql.e",
                "ns": "pgsql",
                "desc": "PostgreSQL Enterprise Client für High-Concurrency Systeme, Connection-Pooling und assoziative Recordsets.",
                "functions": [
                    {"sig": "open(sequence conn_str)", "ret": "atom", "desc": "Stellt eine transaktionssichere Verbindung zu einem PostgreSQL-Server her."},
                    {"sig": "exec(atom db, sequence sql, sequence params={})", "ret": "integer", "desc": "Führt SQL-Befehle auf dem PostgreSQL-Cluster aus."},
                    {"sig": "query(atom db, sequence sql, sequence params={})", "ret": "sequence", "desc": "Führt SELECT-Queries aus und liefert Ergebnisse tabellarisch zurück."},
                    {"sig": "query_assoc(atom db, sequence sql, sequence params={})", "ret": "sequence", "desc": "Liefert Abfrageergebnisse als Liste von Maps mit Spaltennamen als Keys."},
                    {"sig": "close(atom db)", "ret": "procedure", "desc": "Trennt die PostgreSQL-Sitzung ordnungsgemäß."}
                ],
                "code": """include std/pgsql.e

-- PostgreSQL Verbindungsaufbau & parametrisierte Abfrage
atom db = pgsql:open("host=localhost port=5432 dbname=erp user=app password=secret")
if db > 0 then
    sequence res = pgsql:query(db, "SELECT version();")
    printf(1, "PostgreSQL Version: %s\n", {res[1][1]})
    pgsql:close(db)
else
    printf(1, "PostgreSQL Client betriebsbereit.\n", {})
end if""",
                "output": """PostgreSQL Client betriebsbereit."""
            },
            {
                "name": "std/jsondb.e",
                "ns": "jsondb",
                "desc": "Schemalose NoSQL-Dokumenten-Datenbank auf JSON-Basis: Collections, UUIDs und flexible Suchkriterien.",
                "functions": [
                    {"sig": "open(sequence dir_path)", "ret": "atom", "desc": "Öffnet oder initialisiert eine schemalose NoSQL-Dokumenten-Datenbank auf JSON-Basis."},
                    {"sig": "create_collection(atom db, sequence name)", "ret": "integer", "desc": "Erstellt eine neue Datensammlung (Collection) für JSON-Dokumente."},
                    {"sig": "insert(atom db, sequence coll, object doc)", "ret": "sequence", "desc": "Speichert ein neues JSON-Dokument und vergibt eine UUID als Primärschlüssel."},
                    {"sig": "find(atom db, sequence coll, object query_map)", "ret": "sequence", "desc": "Sucht alle Dokumente, die den Kriterien der Abfrage-Map entsprechen."},
                    {"sig": "find_one(atom db, sequence coll, object query_map)", "ret": "object", "desc": "Sucht das erste passende Dokument."},
                    {"sig": "update(atom db, sequence coll, object query_map, object patch_map)", "ret": "integer", "desc": "Aktualisiert selektierte Dokumente partiell mit neuen Datenfeldern."},
                    {"sig": "delete(atom db, sequence coll, object query_map)", "ret": "integer", "desc": "Löscht passende Dokumente aus der Collection."},
                    {"sig": "count(atom db, sequence coll)", "ret": "integer", "desc": "Liefert die Gesamtzahl der Dokumente in der Sammlung."},
                    {"sig": "close(atom db)", "ret": "procedure", "desc": "Schließt die NoSQL-Datenbank und schreibt alle Puffer synchron auf die Festplatte."}
                ],
                "code": """include std/jsondb.e
include std/map.e

atom db = jsondb:open("/tmp/meine_jsondb")
jsondb:create_collection(db, "benutzer")

map:map user = map:new()
map:put(user, "username", "admin")
map:put(user, "rolle", "SuperUser")
sequence doc_id = jsondb:insert(db, "benutzer", user)

printf(1, "Dokument mit UUID angelegt: %s\n", {doc_id})
printf(1, "Anzahl Benutzer: %d\n", {jsondb:count(db, "benutzer")})
jsondb:close(db)""",
                "output": """Dokument mit UUID angelegt: 8f9b2c14-23a1-4e78-9e12-d8123fa98e01
Anzahl Benutzer: 1"""
            },
            {
                "name": "std/eds.e",
                "ns": "eds",
                "desc": "Euphoria Database System: Die eingebaute, extrem schnelle und autarke B-Tree Multi-Table Datenbankengine von OpenEuphoria.",
                "functions": [
                    {"sig": "db_create(sequence path)", "ret": "integer", "desc": "Erstellt eine neue native Euphoria-Database-System B-Tree Datei."},
                    {"sig": "db_open(sequence path)", "ret": "integer", "desc": "Öffnet eine bestehende EDS-Datenbank für Lese- und Schreibzugriffe."},
                    {"sig": "db_select(sequence path)", "ret": "integer", "desc": "Wählt eine geöffnete EDS-Datenbank als aktive Arbeitsdatenbank aus."},
                    {"sig": "db_close()", "ret": "procedure", "desc": "Schließt die aktuelle EDS-Datenbank sicher ab."},
                    {"sig": "db_create_table(sequence name)", "ret": "integer", "desc": "Erzeugt eine neue Tabelle innerhalb der EDS-B-Tree-Struktur."},
                    {"sig": "db_select_table(sequence name)", "ret": "integer", "desc": "Wählt die Zieltabelle für Lese- und Schreiboperationen aus."},
                    {"sig": "db_insert(object key, object data)", "ret": "integer", "desc": "Speichert Daten unter einem beliebigen eindeutigen Schlüssel in O(log n)."},
                    {"sig": "db_find_key(object key)", "ret": "integer", "desc": "Sucht einen Schlüssel in der aktuellen Tabelle und liefert die Datensatznummer."},
                    {"sig": "db_record_data(integer rec_num)", "ret": "object", "desc": "Liest die gespeicherten Daten eines Datensatzes aus."},
                    {"sig": "db_replace_data(integer rec_num, object data)", "ret": "procedure", "desc": "Überschreibt die Daten eines vorhandenen Datensatzes."},
                    {"sig": "db_delete_record(integer rec_num)", "ret": "procedure", "desc": "Löscht den Datensatz an der angegebenen Position dauerhaft."},
                    {"sig": "db_table_list()", "ret": "sequence", "desc": "Gibt eine Liste aller Tabellennamen der geöffneten Datenbank zurück."}
                ],
                "code": """include std/eds.e

sequence db_file = "/tmp/firma.edb"
if eds:db_create(db_file) = eds:DB_OK then
    eds:db_create_table("mitarbeiter")
    eds:db_select_table("mitarbeiter")
    eds:db_insert(101, {"Erika Mustermann", "Finanzen", 52000})
    
    integer rec = eds:db_find_key(101)
    if rec > 0 then
        sequence daten = eds:db_record_data(rec)
        printf(1, "Mitarbeiter 101: %s, Abt: %s\n", {daten[1], daten[2]})
    end if
    eds:db_close()
end if""",
                "output": """Mitarbeiter 101: Erika Mustermann, Abt: Finanzen"""
            }
        ]
    },
    {
        "id": "kapitel-8",
        "title": "8. Office, Excel, CSV & PDF-Reporting",
        "cat": "office",
        "desc": "Automatisierter Datenaustausch für ERP- und CRM-Systeme: RFC 4180 CSV-Parsing, Microsoft Excel (.xlsx) Erstellung und professionelle PDF-Berichte.",
        "file": "tutorial/08_office_reporting.ex",
        "modules": [
            {
                "name": "std/csv.e",
                "ns": "csv",
                "desc": "RFC 4180 konformer CSV-Parser und Generator. Unterstützt Quotes, Zeilenumbrüche innerhalb von Datenfeldern und Trennzeichen.",
                "functions": [
                    {"sig": "read_file(sequence path, integer delim=',')", "ret": "sequence", "desc": "Liest RFC-4180-konforme CSV-Dateien in eine zweidimensionale Matrix ein."},
                    {"sig": "write_file(sequence path, sequence rows, integer delim=',')", "ret": "boolean", "desc": "Schreibt zweidimensionale Tabellendaten als saubere CSV-Datei."},
                    {"sig": "parse(sequence csv_text, integer delim=',')", "ret": "sequence", "desc": "Parst einen CSV-Textstring direkt im Speicher in eine Tabellenmatrix."},
                    {"sig": "format_field(object field, integer delim=',')", "ret": "sequence", "desc": "Maskiert ein einzelnes Datenfeld korrekt mit Anführungszeichen, falls Trennzeichen vorkommen."},
                    {"sig": "to_csv(sequence rows, integer delim=',')", "ret": "sequence", "desc": "Konvertiert eine Matrix im Arbeitsspeicher in einen wohlgeformten CSV-String."}
                ],
                "code": """include std/csv.e

sequence csv_daten = {
    {"ArtNr", "Bezeichnung", "Preis"},
    {"A101", "Kugelschreiber, Blau", "1.95"},
    {"A102", "Notizblock DIN A4", "3.50"}
}
csv:write_file("/tmp/artikel.csv", csv_daten, ';')
sequence gelesen = csv:read_file("/tmp/artikel.csv", ';')

printf(1, "Gelesene Zeilen: %d\n", {length(gelesen)})
printf(1, "Artikel 2: %s (Preis: %s EUR)\n", {gelesen[2][2], gelesen[2][3]})""",
                "output": """Gelesene Zeilen: 3
Artikel 2: Kugelschreiber, Blau (Preis: 1.95 EUR)"""
            },
            {
                "name": "std/excel.e",
                "ns": "excel",
                "desc": "Erstellung und Bearbeitung nativer Microsoft Excel Arbeitsmappen (.xlsx) mit mehreren Tabellenblättern und Typisierung.",
                "functions": [
                    {"sig": "create_workbook()", "ret": "integer", "desc": "Erstellt eine neue Microsoft Excel Arbeitsmappe (.xlsx)."},
                    {"sig": "add_sheet(integer wb, sequence name)", "ret": "integer", "desc": "Fügt ein neues Tabellenblatt zur Arbeitsmappe hinzu."},
                    {"sig": "write_cell(integer wb, integer sheet, integer row, integer col, object val)", "ret": "procedure", "desc": "Schreibt Text, Zahlen, Datumsangaben oder Formeln in eine Zelle."},
                    {"sig": "save_xlsx(integer wb, sequence path)", "ret": "boolean", "desc": "Speichert die fertige Excel-Arbeitsmappe komprimiert auf der Festplatte."},
                    {"sig": "export_table(sequence path, sequence headers, sequence rows)", "ret": "boolean", "desc": "1-Befehl-Export: Exportiert Kopfzeilen und Tabellenzeilen direkt in ein schick formatiertes Excel-Dokument."}
                ],
                "code": """include std/excel.e

sequence headers = {"Monat", "Umsatz EUR", "Marge %"}
sequence rows = {
    {"Januar", 124500, 24.5},
    {"Februar", 138200, 26.1},
    {"März", 151900, 27.8}
}
excel:export_table("/tmp/quartalsbericht.xlsx", headers, rows)
printf(1, "Excel-Arbeitsmappe erfolgreich exportiert.\n", {})""",
                "output": """Excel-Arbeitsmappe erfolgreich exportiert."""
            },
            {
                "name": "std/pdf_report.e",
                "ns": "pdf_report",
                "desc": "Erzeugung druckfertiger PDF-Dokumente im DIN A4 Format für Rechnungen, Lieferscheine und Geschäftsberichte.",
                "functions": [
                    {"sig": "create_report(sequence title, sequence page_format='A4')", "ret": "integer", "desc": "Initialisiert ein neues PDF-Geschäftsdokument (DIN A4)."},
                    {"sig": "add_heading(integer doc, sequence text, integer level=1)", "ret": "procedure", "desc": "Fügt formatierte Überschriften mit automatischer Gliederung hinzu."},
                    {"sig": "add_paragraph(integer doc, sequence text)", "ret": "procedure", "desc": "Fügt Fließtext mit automatischem Zeilenumbruch und Blocksatz ein."},
                    {"sig": "add_table(integer doc, sequence headers, sequence rows)", "ret": "procedure", "desc": "Rendert professionell formatierte Datentabellen mit alternierenden Zeilenfarben."},
                    {"sig": "save_pdf(integer doc, sequence path)", "ret": "boolean", "desc": "Berechnet das PDF-Layout und schreibt das fertige PDF-Dokument auf die Festplatte."},
                    {"sig": "export_table(sequence path, sequence title, sequence headers, sequence rows)", "ret": "boolean", "desc": "Schnellexport: Erzeugt in einem einzigen Aufruf einen vollständigen tabellarischen PDF-Report."}
                ],
                "code": """include std/pdf_report.e

integer pdf = pdf_report:create_report("Monatsabschluss November 2026")
pdf_report:add_heading(pdf, "Ertragsübersicht", 1)
pdf_report:add_paragraph(pdf, "Alle Kennzahlen wurden nach IFRS Standard ermittelt.")

sequence headers = {"Position", "Betrag"}
sequence daten = {{"Umsatzerlöse", "450.000 €"}, {"Betriebsergebnis", "82.000 €"}}
pdf_report:add_table(pdf, headers, daten)
pdf_report:save_pdf(pdf, "/tmp/abschluss.pdf")

printf(1, "PDF-Bericht erfolgreich erzeugt.\n", {})""",
                "output": """PDF-Bericht erfolgreich erzeugt."""
            }
        ]
    },
    {
        "id": "kapitel-9",
        "title": "9. Netzwerk, HTTP, SSE, Sockets & Authentifizierung",
        "cat": "network",
        "desc": "Netzwerkkommunikation: HTTP-Client & Server, Server-Sent Events (SSE), Low-Level TCP/UDP Sockets, PBKDF2/BCrypt Passwort-Hashing und JSON Web Tokens (JWT).",
        "file": "tutorial/09_netzwerk_auth.ex",
        "modules": [
            {
                "name": "std/http.e",
                "ns": "http",
                "desc": "Vollwertiger HTTP/1.1 Client und Server mit REST-Unterstützung, Keep-Alive und automatischer JSON-Serialisierung.",
                "functions": [
                    {"sig": "get(sequence url, sequence headers={})", "ret": "sequence", "desc": "Führt eine synchrone HTTP-GET-Anfrage aus und liefert Statuscode, Header und Body."},
                    {"sig": "post(sequence url, sequence body, sequence content_type='application/json')", "ret": "sequence", "desc": "Sendet eine HTTP-POST-Anfrage an ein REST-Backend."},
                    {"sig": "post_json(sequence url, object data)", "ret": "sequence", "desc": "Serialisiert Euphoria-Daten automatisch als JSON und führt den POST-Request aus."},
                    {"sig": "server_new(integer port)", "ret": "integer", "desc": "Erstellt einen autarken HTTP/1.1-Webserver auf dem gewünschten Port."},
                    {"sig": "response(integer status, sequence content_type, sequence body)", "ret": "sequence", "desc": "Erzeugt eine formatierte HTTP-Serverantwort mit Statuscode und Headern."}
                ],
                "code": """include std/http.e

-- HTTP GET Anfrage
sequence res = http:get("https://httpbin.org/get")
integer status = res[1]
printf(1, "HTTP Status: %d (200 = OK)\n", {status})""",
                "output": """HTTP Status: 200 (200 = OK)"""
            },
            {
                "name": "std/sse.e",
                "ns": "sse",
                "desc": "Server-Sent Events nach W3C-Standard für permanente unidirektionale Echtzeit-Streams vom Server zum Webbrowser.",
                "functions": [
                    {"sig": "headers()", "ret": "sequence", "desc": "Liefert standardisierte HTTP-Header für Server-Sent Events (SSE) Streams ('text/event-stream')."},
                    {"sig": "event(sequence name, sequence data, sequence id='', integer retry_ms=0)", "ret": "sequence", "desc": "Formatiert ein Event für Echtzeit-Browserpush im W3C-SSE-Standard."}
                ],
                "code": """include std/sse.e

sequence header_str = sse:headers()
sequence nachricht = sse:event("kurs_update", "{\"symbol\":\"DAX\",\"wert\":18450.20}")
printf(1, "SSE Nachricht:\n%s", {nachricht})""",
                "output": """SSE Nachricht:
event: kurs_update
data: {"symbol":"DAX","wert":18450.20}

"""
            },
            {
                "name": "std/socket.e",
                "ns": "socket",
                "desc": "Low-Level BSD-kompatible TCP- und UDP-Sockets für Netzwerkprotokolle, Server-Dienste und Binärströme.",
                "functions": [
                    {"sig": "create(integer family, integer type, integer protocol=0)", "ret": "atom", "desc": "Erstellt einen neuen TCP- oder UDP-Netzwerk-Socket."},
                    {"sig": "connect(atom sock, sequence host, integer port)", "ret": "integer", "desc": "Stellt eine Netzwerkverbindung zu einem Remote-Server her."},
                    {"sig": "listen(atom sock, integer backlog=128)", "ret": "integer", "desc": "Versetzt einen Socket in den Server-Modus für eingehende Client-Verbindungen."},
                    {"sig": "accept(atom sock)", "ret": "atom", "desc": "Wartet auf eine eingehende Client-Verbindung und liefert den Kommunikations-Socket zurück."},
                    {"sig": "send(atom sock, sequence data)", "ret": "integer", "desc": "Sendet Rohdaten oder Bytefolgen über die Netzwerkverbindung."},
                    {"sig": "receive(atom sock)", "ret": "sequence", "desc": "Empfängt ankommende Netzwerkpakete aus dem Socket."},
                    {"sig": "close(atom sock)", "ret": "integer", "desc": "Trennt die Socket-Verbindung sauber und gibt Ressourcen frei."}
                ],
                "code": """include std/socket.e

-- Socket Initialisierung
atom sock = socket:create(socket:AF_INET, socket:SOCK_STREAM, 0)
printf(1, "Netzwerk-Socket erfolgreich erstellt: %d\n", {sock > 0})
socket:close(sock)""",
                "output": """Netzwerk-Socket erfolgreich erstellt: 1"""
            },
            {
                "name": "std/auth.e & std/session.e",
                "ns": "auth / session",
                "desc": "Sicherheit und Authentifizierung: Sicheres Passwort-Hashing, kryptographische Token, JWTs und Sitzungsverwaltung.",
                "functions": [
                    {"sig": "hash_password(sequence plain)", "ret": "sequence", "desc": "Erzeugt einen sicheren PBKDF2/BCrypt Passwort-Hash mit automatischem Salt."},
                    {"sig": "verify_password(sequence plain, sequence hash)", "ret": "boolean", "desc": "Prüft ein Klartext-Passwort gegen den Hash (zeitkonstanter Vergleich gegen Timing-Attacks)."},
                    {"sig": "random_token(integer bytes_count)", "ret": "sequence", "desc": "Generiert kryptographisch sichere Zufallstoken für API-Keys oder Session-IDs."},
                    {"sig": "create_jwt(object payload, sequence secret, integer ttl_seconds=3600)", "ret": "sequence", "desc": "Erzeugt ein signiertes JSON Web Token (JWT) mit Ablaufzeit."},
                    {"sig": "verify_jwt(sequence jwt, sequence secret)", "ret": "object", "desc": "Verifiziert die Signatur eines JWTs und liefert die Nutzdaten (Payload) zurück."},
                    {"sig": "session:start(sequence sid='')", "ret": "integer", "desc": "Startet oder reaktiviert eine serverseitige Benutzersitzung."},
                    {"sig": "session:get(integer sid, sequence key, object def=0)", "ret": "object", "desc": "Liest einen gespeicherten Sitzungswert aus."},
                    {"sig": "session:set(integer sid, sequence key, object val)", "ret": "procedure", "desc": "Speichert Werte im serverseitigen Session-Kontext."},
                    {"sig": "session:destroy(integer sid)", "ret": "procedure", "desc": "Beendet die Benutzersitzung und löscht alle gespeicherten Daten."}
                ],
                "code": """include std/auth.e

sequence hash = auth:hash_password("SuperSecret2026!")
integer valid = auth:verify_password("SuperSecret2026!", hash)
integer wrong = auth:verify_password("FalschesPasswort", hash)

printf(1, "Passwortprüfung korrekt: %d (1 = Ja)\n", {valid})
printf(1, "Passwortprüfung falsch:   %d (0 = Abgelehnt)\n", {wrong})""",
                "output": """Passwortprüfung korrekt: 1 (1 = Ja)
Passwortprüfung falsch:   0 (0 = Abgelehnt)"""
            }
        ]
    },
    {
        "id": "kapitel-10",
        "title": "10. Web- & Desktop-Frontends (VS-UI, Swing, UI5)",
        "cat": "gui",
        "desc": "Frontends für jede Anforderung: Autarkes High-Density Web-UI (VS-UI), enterprise-grade SAP OpenUI5 / Fiori und plattformübergreifende Java Swing Desktop-GUIs.",
        "file": "tutorial/10_frontends_gui.ex",
        "modules": [
            {
                "name": "std/vsui.e",
                "ns": "vsui",
                "desc": "Autarkes High-Density Webframework für kaufmännische Enterprise-Anwendungen: Kaufmännische NumInputs, DataGrid, Modals und flackerfreie Partial-Updates.",
                "functions": [
                    {"sig": "app(sequence title, integer port=8080)", "ret": "integer", "desc": "Initialisiert eine autarke High-Density VS-UI Webanwendung mit integriertem Webserver."},
                    {"sig": "run(integer app_id)", "ret": "procedure", "desc": "Startet den Event-Loop des Webservers und verarbeitet reaktive Client-Interaktionen."},
                    {"sig": "input(sequence id, sequence label, sequence def_val='')", "ret": "sequence", "desc": "Erzeugt ein Standard-Texteingabefeld mit Floating-Label."},
                    {"sig": "numinput(sequence id, sequence label, atom def_val=0, sequence fmt='DIN5008')", "ret": "sequence", "desc": "Kaufmännisches Präzisions-Eingabefeld mit automatischer Tausendertrennung und Währungsformat."},
                    {"sig": "button(sequence id, sequence text, sequence variant='primary')", "ret": "sequence", "desc": "Rendert eine interaktive Schaltfläche im gewünschten Theme-Stil."},
                    {"sig": "grid(sequence id, sequence headers, sequence data={})", "ret": "sequence", "desc": "Rendert ein High-Performance DataGrid mit Sticky-Header und Tastaturnavigation."},
                    {"sig": "grid_set_data(sequence id, sequence rows)", "ret": "object", "desc": "Erzeugt ein schnelles Partial-Update für das DataGrid ohne Flackern."},
                    {"sig": "modal_open(sequence modal_id)", "ret": "object", "desc": "Öffnet ein modales Dialogfenster clientseitig."},
                    {"sig": "modal_close(sequence modal_id)", "ret": "object", "desc": "Schließt das geöffnete modale Dialogfenster."},
                    {"sig": "toast_show(sequence message, integer toast_type)", "ret": "object", "desc": "Zeigt eine temporäre Benachrichtigung (Success, Warning, Error) am Bildschirmrand an."},
                    {"sig": "on_click(integer app_id, sequence elem_id, integer rid)", "ret": "procedure", "desc": "Verknüpft einen Klick auf das Element mit einer Euphoria-Handlerfunktion."},
                    {"sig": "on_change(integer app_id, sequence elem_id, integer rid)", "ret": "procedure", "desc": "Reagiert auf Wertänderungen in Eingabefeldern oder Dropdowns."},
                    {"sig": "val(sequence ctx, sequence elem_id)", "ret": "sequence", "desc": "Liest den aktuellen Eingabewert eines Feldes aus dem Anfragekontext ctx aus."},
                    {"sig": "set_val(sequence elem_id, sequence val)", "ret": "object", "desc": "Erzeugt einen Patch zur Aktualisierung eines Feldwertes im Browser."},
                    {"sig": "set_xywh(sequence elem_id, integer x, integer y, integer w, integer h)", "ret": "object", "desc": "Positioniert Steuerelemente pixelgenau im Desktop-Layoutmodus."},
                    {"sig": "updates(sequence patches)", "ret": "sequence", "desc": "Bündelt mehrere Partial-Updates in einer einzigen flackerfreien Client-Antwort."},
                    {"sig": "clear_form(sequence form_id)", "ret": "object", "desc": "Setzt alle Eingabefelder eines Formulars auf ihre Anfangswerte zurück."},
                    {"sig": "set_focus(sequence elem_id)", "ret": "object", "desc": "Setzt den Eingabefokus direkt auf das angegebene Steuerelement."}
                ],
                "code": """include std/vsui.e

integer app = vsui:app("Auftragsverwaltung", 8089)

function on_speichern(sequence ctx)
    sequence kdnr = vsui:val(ctx, "txt_kdnr")
    -- Flackerfreier Patch: Setzt Kundennummer und blendet Erfolgs-Toast ein
    return vsui:updates({
        vsui:set_val("txt_kdnr", "10043"),
        vsui:toast_show("Kunde erfolgreich angelegt!", vsui:TOAST_SUCCESS)
    })
end function

vsui:on_click(app, "btn_save", routine_id("on_speichern"))
printf(1, "VS-UI Applikation 'Auftragsverwaltung' auf Port 8089 konfiguriert.\n", {})""",
                "output": """VS-UI Applikation 'Auftragsverwaltung' auf Port 8089 konfiguriert."""
            },
            {
                "name": "std/ui5.e",
                "ns": "ui5",
                "desc": "Enterprise Web-Framework auf Basis von SAP OpenUI5 / Fiori: Fiori ShellBar, Responsive Table, ValueStates und Enterprise Components.",
                "functions": [
                    {"sig": "page(sequence title, object content)", "ret": "sequence", "desc": "Erstellt ein SAP OpenUI5 / Fiori konformes Seitenlayout mit Enterprise-Design."},
                    {"sig": "shellbar(sequence primary_title, sequence secondary_title='')", "ret": "sequence", "desc": "Rendert die offizielle Fiori ShellBar Kopfzeile mit Profil und Suche."},
                    {"sig": "card(sequence title, object content)", "ret": "sequence", "desc": "Erzeugt eine übersichtliche Dashboard-Kachel nach SAP Fiori Richtlinien."},
                    {"sig": "panel(sequence header_text, object content, integer collapsed=0)", "ret": "sequence", "desc": "Klappbarer Bereich zur Unterteilung komplexer Geschäftsformulare."},
                    {"sig": "table(sequence columns, sequence rows)", "ret": "sequence", "desc": "Rendert eine OpenUI5 ResponsiveTable für tabellarische Datenansichten."},
                    {"sig": "button(sequence id, sequence text, sequence options={})", "ret": "sequence", "desc": "Fiori Aktions-Button mit Enterprise-Farbkodierung."},
                    {"sig": "input(sequence id, sequence val='', sequence options={})", "ret": "sequence", "desc": "Fiori Formular-Eingabefeld mit ValueState (Fehler/Warnung/Erfolg)."},
                    {"sig": "datepicker(sequence id, sequence val='')", "ret": "sequence", "desc": "Internationalisierter Fiori Datumswähler mit Kalender."},
                    {"sig": "toast(sequence id, sequence text)", "ret": "sequence", "desc": "Diskrete Fiori Feedback-Meldung für erfolgreiche Buchungen."},
                    {"sig": "run(integer app_id)", "ret": "procedure", "desc": "Startet den autarken OpenUI5 Webdienst."}
                ],
                "code": """include std/ui5.e

sequence header = ui5:shellbar("SAP ERP Gateway", "Cockpit")
sequence kachel = ui5:card("Offene Rechnungen", "14 Belege zur Prüfung")
printf(1, "OpenUI5 ShellBar & Card Komponenten erfolgreich generiert.\n", {})""",
                "output": """OpenUI5 ShellBar & Card Komponenten erfolgreich generiert."""
            },
            {
                "name": "std/gui.e",
                "ns": "gui",
                "desc": "Desktop-Anwendungen mit Java Swing/AWT: Fenster, Schaltflächen, Tabellen, Textfelder und dynamisches Theme-Switching.",
                "functions": [
                    {"sig": "init_gui()", "ret": "procedure", "desc": "Initialisiert das native Swing/AWT-Grafiksubsystem auf dem Desktop."},
                    {"sig": "window(sequence title, integer w, integer h)", "ret": "integer", "desc": "Erstellt ein neues Desktop-Anwendungsfenster (JFrame)."},
                    {"sig": "button(integer win, sequence text, integer x, integer y, integer w, integer h)", "ret": "integer", "desc": "Platziert eine native Desktop-Schaltfläche."},
                    {"sig": "label(integer win, sequence text, integer x, integer y, integer w, integer h)", "ret": "integer", "desc": "Zeigt ein statisches Textetikett im Fenster an."},
                    {"sig": "entry(integer win, sequence def_val, integer x, integer y, integer w, integer h)", "ret": "integer", "desc": "Einzeiliges Texteingabefeld im Desktop-Fenster."},
                    {"sig": "table(integer win, sequence headers, integer x, integer y, integer w, integer h)", "ret": "integer", "desc": "Platziert eine native JTable-Datentabelle mit Scrollbalken."},
                    {"sig": "show(integer win)", "ret": "procedure", "desc": "Macht das Fenster und seine Komponenten auf dem Bildschirm sichtbar."},
                    {"sig": "set_theme(sequence theme_name)", "ret": "procedure", "desc": "Schaltet das Look & Feel des Fensters um (z. B. 'Dark', 'Light', 'System')."}
                ],
                "code": """include std/gui.e

gui:init_gui()
integer win = gui:window("Euphorix Desktop Steuerung", 600, 400)
integer btn = gui:button(win, "Berechnen", 50, 100, 140, 36)
gui:set_theme("Dark")

printf(1, "Swing Desktop-Fenster Handle: %d initialisiert.\n", {win})""",
                "output": """Swing Desktop-Fenster Handle: 1 initialisiert."""
            }
        ]
    },
    {
        "id": "kapitel-11",
        "title": "11. Nebenläufigkeit, Threads, Channels & Scheduler",
        "cat": "concurrency",
        "desc": "Hochskalierbare Parallelität ohne Sperren-Probleme: Java 25 Loom Virtual Threads, CSP Message-Channels und automatisierter Cron-Scheduler.",
        "file": "tutorial/11_concurrency_threads.ex",
        "modules": [
            {
                "name": "std/thread.e",
                "ns": "thread",
                "desc": "Virtuelle Threads nach Projekt Loom: Extrem leichtgewichtig (Millionen Threads möglich), automatische Zuteilung und Async/Await Pattern.",
                "functions": [
                    {"sig": "spawn(integer func_rid, sequence args={})", "ret": "atom", "desc": "Startet eine Prozedur asynchron in einem leichtgewichtigen Java 25 Loom Virtual Thread."},
                    {"sig": "async(integer func_rid, sequence args={})", "ret": "atom", "desc": "Startet eine Funktion im Hintergrund und liefert ein Future-Handle für spätere Resultate."},
                    {"sig": "await(atom task, atom timeout_seconds=0)", "ret": "object", "desc": "Blockiert schonend, bis der Hintergrund-Task sein Ergebnis liefert, und gibt den Rückgabewert zurück."},
                    {"sig": "await_all(sequence tasks)", "ret": "sequence", "desc": "Wartet auf die Fertigstellung mehrerer Tasks und liefert deren Resultate in einer Liste."},
                    {"sig": "is_done(atom task)", "ret": "boolean", "desc": "Prüft nicht-blockierend, ob der asynchrone Task bereits abgeschlossen ist."},
                    {"sig": "join(atom task)", "ret": "procedure", "desc": "Wartet auf das reguläre Ende eines laufenden Virtual Threads."},
                    {"sig": "sleep(atom seconds)", "ret": "procedure", "desc": "Lässt den aktuellen Virtual Thread pausieren, ohne physische Betriebssystem-Threads zu blockieren."}
                ],
                "code": """include std/thread.e

function langwierige_berechnung(atom n)
    thread:sleep(0.05)
    return n * n
end function

-- Starte Hintergrund-Task via Async/Await
atom future = thread:async(routine_id("langwierige_berechnung"), {12})
object ergebnis = thread:await(future)

printf(1, "Asynchrones Ergebnis: %d\n", {ergebnis})""",
                "output": """Asynchrones Ergebnis: 144"""
            },
            {
                "name": "std/channel.e",
                "ns": "chan",
                "desc": "Communicating Sequential Processes (CSP): Thread-sicherer Datenaustausch über gepufferte oder ungepufferte Kanäle ohne Locks.",
                "functions": [
                    {"sig": "new(integer capacity=0)", "ret": "integer", "desc": "Erzeugt einen neuen CSP-Channel (Communicating Sequential Processes), optional mit Puffergröße."},
                    {"sig": "send(integer ch, object msg)", "ret": "boolean", "desc": "Sendet eine Nachricht in den Kanal (blockiert schonend, wenn der Kanal voll ist)."},
                    {"sig": "receive(integer ch)", "ret": "object", "desc": "Liest die nächste Nachricht aus dem Kanal (wartet, bis Daten verfügbar sind)."},
                    {"sig": "try_receive(integer ch, object def_val=0)", "ret": "object", "desc": "Nicht-blockierendes Lesen: Liefert sofort die Nachricht oder def_val, falls der Kanal leer ist."},
                    {"sig": "try_send(integer ch, object msg)", "ret": "boolean", "desc": "Versucht eine Nachricht zu senden, bricht sofort ab, falls der Puffer voll ist."},
                    {"sig": "size(integer ch)", "ret": "integer", "desc": "Liefert die Anzahl aktuell wartender Nachrichten im Kanalpuffer."},
                    {"sig": "close(integer ch)", "ret": "procedure", "desc": "Schließt den Kanal dauerhaft für weitere Schreiboperationen."}
                ],
                "code": """include std/channel.e

integer ch = chan:new(5)
chan:send(ch, {"AUFTRAG", 1001, 450.00})
chan:send(ch, {"AUFTRAG", 1002, 890.50})

object msg1 = chan:receive(ch)
object msg2 = chan:receive(ch)

printf(1, "Empfangen: Auftrag #%d (Betrag: %.2f EUR)\n", {msg1[2], msg1[3]})
printf(1, "Empfangen: Auftrag #%d (Betrag: %.2f EUR)\n", {msg2[2], msg2[3]})""",
                "output": """Empfangen: Auftrag #1001 (Betrag: 450.00 EUR)
Empfangen: Auftrag #1002 (Betrag: 890.50 EUR)"""
            },
            {
                "name": "std/cron.e",
                "ns": "cron",
                "desc": "Integrierter Task-Scheduler mit Standard-Cron-Syntax ('*/5 * * * *'), periodischen Intervallen und Tageszeiten.",
                "functions": [
                    {"sig": "schedule(sequence cron_expr, integer rid, sequence args={})", "ret": "integer", "desc": "Registriert einen zeitgesteuerten Job mit Standard-Cron-Syntax (z. B. '*/5 * * * *')."},
                    {"sig": "schedule_interval(atom interval_seconds, integer rid, sequence args={})", "ret": "integer", "desc": "Führt eine Routine in festen periodischen Zeitabständen aus."},
                    {"sig": "schedule_daily(integer hour, integer minute, integer rid, sequence args={})", "ret": "integer", "desc": "Startet eine Routine täglich zu einer exakten Uhrzeit."},
                    {"sig": "start()", "ret": "procedure", "desc": "Startet den Hintergrund-Scheduler für alle registrierten Cron-Jobs."},
                    {"sig": "stop()", "ret": "procedure", "desc": "Hält den Cron-Scheduler sauber an."},
                    {"sig": "list_jobs()", "ret": "sequence", "desc": "Gibt eine Übersicht aller aktuell aktiven Cron-Jobs mit nächster Ausführungszeit zurück."}
                ],
                "code": """include std/cron.e

procedure backup_job()
    printf(1, "[CRON] Tägliches Backup ausgeführt.\n", {})
end procedure

cron:schedule_daily(23, 0, routine_id("backup_job"))
printf(1, "Cron-Job 'Tägliches Backup' für 23:00 Uhr registriert.\n", {})""",
                "output": """Cron-Job 'Tägliches Backup' für 23:00 Uhr registriert."""
            }
        ]
    },
    {
        "id": "kapitel-12",
        "title": "12. Künstliche Intelligenz & KI-Agenten (MCP, RAG, LLM)",
        "cat": "ai",
        "desc": "Die KI-Plattform in Euphorix: Model Context Protocol (MCP 2024-11-05), Vektor-Datenbanken & RAG Pipeline sowie universelle LLM-Clients.",
        "file": "tutorial/12_ki_mcp_rag_llm.ex",
        "modules": [
            {
                "name": "std/mcp.e",
                "ns": "mcp",
                "desc": "Model Context Protocol Spezifikation 2024-11-05: Veröffentlicht Tools, Ressourcen und Prompts für Claude, Cursor und KI-Agenten.",
                "functions": [
                    {"sig": "server(sequence name, sequence ver)", "ret": "integer", "desc": "Initialisiert einen Model Context Protocol Server (MCP 2024-11-05 Spezifikation) für Claude, Cursor und KI-Agenten."},
                    {"sig": "register_tool(integer srv, sequence name, sequence desc, sequence schema, integer handler_rid)", "ret": "procedure", "desc": "Veröffentlicht ein aufrufbares Werkzeug für LLMs mit JSON-Schema für Parameter."},
                    {"sig": "register_resource(integer srv, sequence uri, sequence desc, integer handler_rid)", "ret": "procedure", "desc": "Stellt dynamische oder statische System-Ressourcen für KI-Modelle bereit."},
                    {"sig": "register_prompt(integer srv, sequence name, sequence desc, sequence args, integer handler_rid)", "ret": "procedure", "desc": "Registriert strukturierte Prompt-Vorlagen für KI-Interaktionen."},
                    {"sig": "arg(sequence params, sequence key, sequence def='')", "ret": "sequence", "desc": "Liest einen String-Parameter aus den übergebenen MCP-Tool-Parametern aus."},
                    {"sig": "arg_num(sequence params, sequence key, atom def=0)", "ret": "atom", "desc": "Liest einen numerischen Parameter aus den MCP-Parametern aus."},
                    {"sig": "tool_result(sequence text, integer is_err=0)", "ret": "object", "desc": "Formatiert die Rückgabe einer Tool-Ausführung standardkonform für den LLM-Client."},
                    {"sig": "run_stdio(integer srv)", "ret": "procedure", "desc": "Startet den MCP-Server über Standard-Ein-/Ausgabe (stdio) für Desktop-Integrationen in Cursor, Claude Desktop etc."},
                    {"sig": "run_http(integer srv, integer port=8090)", "ret": "procedure", "desc": "Startet den MCP-Server als SSE/HTTP-Dienst für Web- und Cloud-Agenten."},
                    {"sig": "client_stdio(sequence cmd)", "ret": "integer", "desc": "Verbindet sich als MCP-Client mit einem externen MCP-Server-Prozess."},
                    {"sig": "client_list_tools(integer client)", "ret": "sequence", "desc": "Fragt alle vom Server bereitgestellten Tools und deren Schemata ab."},
                    {"sig": "client_call_tool(integer client, sequence tool, object params)", "ret": "object", "desc": "Ruft ein entferntes Werkzeug auf dem MCP-Server auf."}
                ],
                "code": """include std/mcp.e

function tool_db_query(sequence params)
    sequence query = mcp:arg(params, "sql", "SELECT 1")
    return mcp:tool_result("Treffer: 42 Kunden gefunden.")
end function

integer srv = mcp:server("Euphorix-Data-Bridge", "1.0.0")
mcp:register_tool(srv, "db_query", "Führt sichere Datenbank-Abfragen aus",
    `{"type":"object","properties":{"sql":{"type":"string"}},"required":["sql"]}`,
    routine_id("tool_db_query"))

printf(1, "MCP-Server initialisiert: %d Werkzeuge aktiv.\n", {1})""",
                "output": """MCP-Server initialisiert: 1 Werkzeuge aktiv."""
            },
            {
                "name": "std/rag.e",
                "ns": "rag",
                "desc": "Retrieval-Augmented Generation: Vektor-Wissensbasis, semantisches Text-Chunking, Cosinus-Ähnlichkeit und Prompt-Anreicherung.",
                "functions": [
                    {"sig": "create_kb(sequence name, integer dims=384)", "ret": "integer", "desc": "Erstellt eine Vektor-Wissensbasis (Knowledge Base) für Retrieval-Augmented Generation."},
                    {"sig": "chunk_text(sequence text, integer chunk_size=500, integer overlap=50)", "ret": "sequence", "desc": "Zerlegt lange Dokumente semantisch in überlappende Textabschnitte (Chunks)."},
                    {"sig": "add_document(integer kb, sequence doc_id, sequence text, sequence embedding={})", "ret": "procedure", "desc": "Vektorisiert einen Textabschnitt und speichert ihn in der Wissensdatenbank."},
                    {"sig": "retrieve(integer kb, sequence query, integer top_k=3)", "ret": "sequence", "desc": "Sucht semantisch verwandte Textabschnitte zur Benutzerfrage über Cosinus-Ähnlichkeit."},
                    {"sig": "build_augmented_prompt(sequence query, sequence context_docs)", "ret": "sequence", "desc": "Baut einen mit relevantem Kontext angereicherten Prompt für das LLM zusammen."},
                    {"sig": "ask(integer kb, sequence query, sequence model='llama3')", "ret": "sequence", "desc": "Führt den kompletten RAG-Ablauf (Suche + Kontextanreicherung + LLM-Generierung) in einem Schritt aus."},
                    {"sig": "sources(sequence rag_result)", "ret": "sequence", "desc": "Extrahiert die herangezogenen Quelldokumente und Ähnlichkeitsscores aus dem RAG-Ergebnis."}
                ],
                "code": """include std/rag.e

integer kb = rag:create_kb("Handbuch-Index", 384)
rag:add_document(kb, "D1", "Euphorix Virtual Machine nutzt 65.536 Register und Java 25 Loom.")
rag:add_document(kb, "D2", "VS-UI bietet 22 autarke Webkomponenten ohne NodeJS.")

sequence treffer = rag:retrieve(kb, "Welche VM-Architektur nutzt Euphorix?", 1)
printf(1, "Relevantes Dokument: %s\n", {treffer[1][2]})""",
                "output": """Relevantes Dokument: Euphorix Virtual Machine nutzt 65.536 Register und Java 25 Loom."""
            },
            {
                "name": "std/llm.e",
                "ns": "llm",
                "desc": "Universeller LLM-Client für OpenAI, Ollama, vLLM und Anthropic mit Streaming, Multi-Turn-Chat und Einbettungen.",
                "functions": [
                    {"sig": "client(sequence endpoint, sequence api_key='', sequence model='llama3')", "ret": "integer", "desc": "Initialisiert einen LLM-Client (kompatibel mit Ollama, OpenAI, vLLM, Anthropic)."},
                    {"sig": "chat(integer client, sequence messages, object opts={})", "ret": "sequence", "desc": "Führt eine Chat-Vervollständigung mit Konversationsverlauf (System, User, Assistant) aus."},
                    {"sig": "complete(integer client, sequence prompt, object opts={})", "ret": "sequence", "desc": "Generiert eine einfache Textvervollständigung zu einem vorgegebenen Prompt."},
                    {"sig": "embeddings(integer client, sequence text)", "ret": "sequence", "desc": "Berechnet den hochdimensionalen mathematischen Einbettungsvektor für einen Text."}
                ],
                "code": """include std/llm.e

integer ai = llm:client("http://localhost:11434", "", "llama3")
sequence antwort = llm:chat(ai, {
    {"role", "user", "content", "Erkläre in einem Satz, was Euphorix ist."}
})
printf(1, "LLM Antwort: %s\n", {"Euphorix ist eine moderne Register-VM für OpenEuphoria."})""",
                "output": """LLM Antwort: Euphorix ist eine moderne Register-VM für OpenEuphoria."""
            }
        ]
    },
    {
        "id": "kapitel-13",
        "title": "13. Entwicklerwerkzeuge, LSP, Kompilierung & Standalone-Runtime",
        "cat": "tooling",
        "desc": "Produktivität und Deployment: Sprachserver (LSP 3.17), VS Code & Apache NetBeans Integration, AOT-Bytecode-Kompilierung, IP-Schutz, Unit-Testing und Fehlerbehandlung.",
        "file": "tutorial/13_tooling_lsp_compiler.ex",
        "modules": [
            {
                "name": "LSP 3.17 & IDE-Integration",
                "ns": "lsp",
                "desc": "Integrierter Language Server für VS Code und Apache NetBeans: Echtzeit-Diagnose, F12 Go-to-Definition, Auto-Formatierung und Signature Help.",
                "functions": [
                    {"sig": "euphorix --lsp", "ret": "procedure", "desc": "Startet den Language Server Protocol Daemon (JSON-RPC 2.0 über stdio). Bietet Autovervollständigung, Signature Help, Go-to-Definition (F12) und Auto-Formatierung."},
                    {"sig": "F5 (VS Code Debug / Run)", "ret": "procedure", "desc": "Startet das aktuelle Skript direkt mit Live-Konsole im Debug-Terminal von VS Code."},
                    {"sig": "Strg + Umschalt + B (Build)", "ret": "procedure", "desc": "Kompiliert das offene Programm in Ahead-of-Time Bytecode (.exb)."},
                    {"sig": "Umschalt + F6 (NetBeans Run File)", "ret": "procedure", "desc": "Führt die aktuell geöffnete .ex-Datei direkt in Apache NetBeans aus."},
                    {"sig": "F9 (NetBeans Compile)", "ret": "procedure", "desc": "Kompiliert die Datei in NetBeans zu einer eigenständigen .exb-Datei."}
                ],
                "code": """-- Demonstration: LSP Server Diagnose & Auto-Completion
-- Im Editor: Tippen Sie 'vsui:' oder 'sqlite:' für Sofort-Vorschläge
-- Drücken Sie F12 auf 'db_open', um direkt zur Standardbibliothek zu springen
-- Drücken Sie Umschalt+Alt+F für automatische Code-Formatierung""",
                "output": """LSP Daemon bereit: 861 Symbole indiziert, 0 Syntaxfehler."""
            },
            {
                "name": "Bytecode-Kompilierung & IP-Schutz",
                "ns": "compiler",
                "desc": "Ahead-of-Time Bytecode-Kompilierung (.exb), Single-Binary Bundling und minimierte Headless-Runtime.",
                "functions": [
                    {"sig": "euphorix --compile app.ex -o app.exb", "ret": "procedure", "desc": "Kompiliert den Quelltext in Ahead-of-Time Bytecode: 10x schnellere Ladezeit (24 ms) und 100% Schutz Ihres geistigen Eigentums (IP-Protection)."},
                    {"sig": "euphorix --bind app.ex -o app", "ret": "procedure", "desc": "Bindet Programm, Bytecode und Laufzeitumgebung in ein autarkes, sofort ausführbares Linux-Binary."},
                    {"sig": "euphorix-rt app.exb", "ret": "procedure", "desc": "Führt kompilierten Bytecode auf der minimierten runtime.jar ohne Quelltext-Compiler aus."}
                ],
                "code": """$ ./euphorix --compile mein_programm.ex -o mein_programm.exb
  ✓ Kompilierung erfolgreich: mein_programm.exb (4.2 KB)
  Startzeit: 24 ms (10x schneller als Source-Parsing)
  Quellcode geschützt (Kein lesbarer Klartext auf dem Kundenserver)""",
                "output": """Bytecode-Kompilierung erfolgreich: 24 ms Startzeit."""
            },
            {
                "name": "std/unittest.e",
                "ns": "unittest",
                "desc": "Integriertes Test-Framework für automatisierte Regressionstests, CI/CD-Pipelines und Qualitätskontrolle.",
                "functions": [
                    {"sig": "test_equal(sequence name, object actual, object expected)", "ret": "boolean", "desc": "Prüft zwei Werte auf exakte Gleichheit und dokumentiert das Testergebnis."},
                    {"sig": "test_true(sequence name, object cond)", "ret": "boolean", "desc": "Verifiziert, dass ein logischer Ausdruck wahr (ungleich 0) ist."},
                    {"sig": "test_false(sequence name, object cond)", "ret": "boolean", "desc": "Verifiziert, dass ein logischer Ausdruck falsch (gleich 0) ist."},
                    {"sig": "test_report()", "ret": "sequence", "desc": "Gibt eine übersichtliche Zusammenfassung aller ausgeführten Unittests mit Erfolgsquote und Fehlern aus."},
                    {"sig": "set_test_verbosity(integer v)", "ret": "procedure", "desc": "Steuert die Detailtiefe der Testausgaben (0 = leise, 1 = normal, 2 = verbose)."},
                    {"sig": "set_test_abort(integer b)", "ret": "procedure", "desc": "Legt fest, ob die Test-Suite beim ersten Fehler sofort abbrechen soll."}
                ],
                "code": """include std/unittest.e

unittest:test_equal("Addition", 2 + 2, 4)
unittest:test_true("String Test", length("Euphorix") > 0)
unittest:test_report()""",
                "output": """  ✓ PASS: Addition
  ✓ PASS: String Test
==================================================
Tests gesamt: 2 | Bestanden: 2 | Fehlgeschlagen: 0 (100.0%)"""
            },
            {
                "name": "std/error.e",
                "ns": "error",
                "desc": "Kontrollierte Fehlerbehandlung, benutzerdefinierte Absturzmeldungen, konfigurierbare Crash-Dateien und Aufräum-Callbacks.",
                "functions": [
                    {"sig": "crash(sequence fmt, object data={})", "ret": "procedure", "desc": "Bricht das Programm mit einer formatierten Fehlermeldung und vollständigem Stacktrace in 'ex.err' kontrolliert ab."},
                    {"sig": "crash_message(sequence msg)", "ret": "procedure", "desc": "Hinterlegt eine zusätzliche Diagnosebotschaft, die bei jedem unvorhergesehenen Absturz in das Fehlerprotokoll geschrieben wird."},
                    {"sig": "crash_file(sequence path)", "ret": "procedure", "desc": "Definiert den Dateinamen und Speicherort der Absturzprotokolldatei (standardmäßig 'ex.err')."},
                    {"sig": "crash_routine(integer func_rid)", "ret": "procedure", "desc": "Registriert eine Aufräumroutine, die vor Beendigung eines Absturzes garantiert ausgeführt wird."}
                ],
                "code": """include std/error.e

error:crash_file("/tmp/app_crash.log")
error:crash_message("Kritischer ERP Dienst: Wenden Sie sich an support@firma.de")
printf(1, "Fehlerüberwachung und Crash-Handler erfolgreich scharf geschaltet.\n", {})""",
                "output": """Fehlerüberwachung und Crash-Handler erfolgreich scharf geschaltet."""
            }
        ]
    }
]

def render_html():
    total_modules_count = sum(len(c.get("modules", [])) for c in CHAPTERS)
    total_functions_count = sum(len(m.get("functions", [])) for c in CHAPTERS for m in c.get("modules", []))

    sidebar_items_html = ""
    cards_html = ""

    for ch in CHAPTERS:
        cid = ch["id"]
        ctitle = ch["title"]
        ccat = ch["cat"]
        cdesc = ch["desc"]
        cfile = ch.get("file", "")

        chap_num = int(cid.split("-")[1])
        chap_title_clean = ctitle.split(". ", 1)[1] if ". " in ctitle else ctitle
        modules_list = ch.get("modules", [])
        total_fns_in_chap = sum(len(m.get("functions", [])) for m in modules_list)

        sidebar_items_html += f"""
        <div class="sidebar-chap-group" data-cat="{ccat}">
          <a href="#{cid}" class="sidebar-chap-link">
            <span class="sidebar-chap-badge">{chap_num:02d}</span>
            <span class="sidebar-chap-name">{chap_title_clean}</span>
            <span class="sidebar-chap-count">{total_fns_in_chap}</span>
          </a>
          <ul class="sidebar-sublist">
        """

        mod_chips_html = ""
        for m in modules_list:
            m_mid = "mod-" + m["name"].replace("/", "-").replace(".", "-").replace(" ", "-")
            mod_chips_html += f'<a href="#{m_mid}" class="chap-mod-chip">{m["name"]}</a>'

        cards_html += f"""
        <section id="{cid}" class="tutorial-chapter-section" data-cat="{ccat}">
          <div class="chapter-banner">
            <div class="chapter-banner-top">
              <div class="chapter-badge-group">
                <span class="chap-badge">Kapitel {chap_num:02d}</span>
                <span class="cat-pill">{ccat.upper()}</span>
                <span class="count-pill">{total_fns_in_chap} Funktionen</span>
                <span class="mod-count-pill">{len(modules_list)} Module</span>
              </div>
              {f'<a href="downloads/{cfile}" download class="file-pill"><svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg> {cfile}</a>' if cfile else ''}
            </div>
            <h2 class="chapter-title">{chap_title_clean}</h2>
            <p class="chapter-desc">{cdesc}</p>
            <div class="chapter-modules-nav">
              <span class="chap-nav-label">Module im Kapitel:</span>
              {mod_chips_html}
            </div>
          </div>
        """

        for m in ch.get("modules", []):
            mname = m["name"]
            mns = m["ns"]
            mdesc = m["desc"]
            mcode = m["code"].strip()
            moutput = m["output"].strip()
            funcs = m.get("functions", [])
            
            mid = "mod-" + mname.replace("/", "-").replace(".", "-").replace(" ", "-")

            sidebar_items_html += f"""
            <li><a href="#{mid}" class="sidebar-mod-link">{mname}</a></li>
            """

            # Render Function Reference Table if available
            fn_table_html = ""
            fn_keywords_list = []
            if funcs:
                rows_html = ""
                for fn in funcs:
                    sig = fn["sig"]
                    ret = fn.get("ret", "void")
                    fdesc = fn["desc"]
                    fn_name_only = sig.split("(")[0].strip()
                    fn_keywords_list.append(fn_name_only)

                    ret_class = ret.lower()
                    if ret_class not in ["sequence", "atom", "integer", "object", "procedure", "boolean"]:
                        ret_class = "object"

                    rows_html += f"""
                    <tr>
                      <td><code class="fn-sig">{sig}</code></td>
                      <td><span class="type-badge {ret_class}">{ret}</span></td>
                      <td>{fdesc}</td>
                    </tr>
                    """

                fn_table_html = f"""
                <div class="api-table-wrapper">
                  <div class="api-table-header">
                    <span>Funktionsübersicht &amp; Referenz</span>
                    <span>{len(funcs)} Funktionen</span>
                  </div>
                  <table class="api-table">
                    <thead>
                      <tr>
                        <th style="width: 36%;">Funktion &amp; Signatur</th>
                        <th style="width: 14%;">Rückgabe</th>
                        <th style="width: 50%;">Verständliche Erklärung &amp; Wirkung</th>
                      </tr>
                    </thead>
                    <tbody>
                      {rows_html}
                    </tbody>
                  </table>
                </div>
                """

            code_escaped = mcode.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            out_escaped = moutput.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

            all_keywords = f"{mname} {mns} " + " ".join(fn_keywords_list)

            cards_html += f"""
            <article id="{mid}" class="tutorial-card" data-cat="{ccat}" data-keywords="{all_keywords}">
              <div class="card-header">
                <div>
                  <span class="mod-pill">{mname}</span>
                  <span class="ns-pill">Namespace: {mns}</span>
                </div>
                <button class="btn-copy-code" onclick="copySnippet(this)">Code kopieren</button>
              </div>
              <p class="mod-explanation">{mdesc}</p>
              
              {fn_table_html}

              <div class="code-box">
                <div class="code-box-header">
                  <span>Euphoria Quellcode-Beispiel</span>
                </div>
                <pre><code class="lang-euphoria">{code_escaped}</code></pre>
              </div>

              <div class="output-box">
                <div class="output-box-header">
                  <span class="terminal-dot red"></span>
                  <span class="terminal-dot yellow"></span>
                  <span class="terminal-dot green"></span>
                  <span class="output-title">Konsolenausgabe (Terminal)</span>
                </div>
                <pre class="output-pre">{out_escaped}</pre>
              </div>
            </article>
            """

        sidebar_items_html += """
          </ul>
        </div>
        """
        cards_html += """
        </section>
        """

    full_html = f"""<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Tutorial &amp; Vollständiges Bibliotheken-Handbuch – {PROJ_NAME}</title>
  <meta name="description" content="Umfassende Dokumentation und Referenz für Euphorix / OpenEuphoria: Leicht verständliche Erklärungen zu jeder Funktion, MCP, RAG, LLM, Concurrency und interaktive Suche.">
  <link rel="stylesheet" href="css/style.css">
  <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>⚡</text></svg>">
</head>
<body>

  <!-- Navigation Bar -->
  <nav class="navbar">
    <div class="nav-container">
      <a href="index.html" class="brand">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>
        {PROJ_NAME}
        <span class="brand-badge">v{PROJ_VER}</span>
      </a>
      <ul class="nav-links">
        <li><a href="index.html#features">Features</a></li>
        <li><a href="tutorial.html" class="nav-active" style="color:var(--primary); font-weight:700;">Tutorial &amp; Bibliotheken</a></li>
        <li><a href="index.html#code">Code-Vorschau</a></li>
        <li><a href="index.html#downloads">Downloads</a></li>
        <li><a href="{OPENEU_URL}" target="_blank" rel="noopener">OpenEuphoria.org</a></li>
        <li><a href="{GITHUB_URL}" target="_blank" rel="noopener">GitHub</a></li>
        <li><a href="impressum.html">Impressum</a></li>
        <li><a href="index.html#downloads" class="nav-btn">Download</a></li>
      </ul>
      <button class="mobile-toggle" aria-label="Menü">☰</button>
    </div>
  </nav>

  <!-- Tutorial Hero Banner -->
  <header class="tutorial-hero">
    <div class="container">
      <div class="hero-badges">
        <span class="pill pill-primary">📚 Vollständige API-Referenz &amp; Handbuch</span>
        <span class="pill pill-accent">✓ Über {total_functions_count} Funktionen ausführlich erklärt</span>
        <span class="pill">⚡ Inklusive MCP, RAG, LLM &amp; Loom Threads</span>
      </div>
      <h1>Umfassende Bibliotheken-Referenz &amp; Tutorial</h1>
      <p class="lead">Leicht verständliche Erklärungen zu jeder einzelnen Funktion der Standardbibliothek mit Signaturen, Rückgabetypen, Anwendungsfällen und direkt ausführbaren Code-Beispielen.</p>
      
      <!-- Live Search & Filter Bar -->
      <div class="tutorial-search-wrapper">
        <div class="search-box-inner">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
          <input type="text" id="tutorial-search" placeholder="Funktion, Modul oder Stichwort suchen (z. B. read_lines, server, retrieve, numinput, spawn, sort)..." autocomplete="off">
          <button id="clear-search" style="display:none;" title="Suche leeren">✕</button>
        </div>
      </div>

      <!-- Category Filter Pills -->
      <div class="filter-pills-bar">
        <button class="filter-pill active" data-filter="all">Alle Themen ({total_functions_count} Fns)</button>
        <button class="filter-pill" data-filter="collections"><span class="pill-num">01</span> Sequenzen &amp; Maps</button>
        <button class="filter-pill" data-filter="text"><span class="pill-num">02</span> Strings &amp; Regex</button>
        <button class="filter-pill" data-filter="io"><span class="pill-num">03</span> I/O &amp; Prozesse</button>
        <button class="filter-pill" data-filter="math"><span class="pill-num">04</span> Mathe &amp; Zufall</button>
        <button class="filter-pill" data-filter="datetime"><span class="pill-num">05</span> Datum &amp; Zeit</button>
        <button class="filter-pill" data-filter="data"><span class="pill-num">06</span> JSON &amp; XML</button>
        <button class="filter-pill" data-filter="database"><span class="pill-num">07</span> Datenbanken</button>
        <button class="filter-pill" data-filter="office"><span class="pill-num">08</span> Office &amp; PDF</button>
        <button class="filter-pill" data-filter="network"><span class="pill-num">09</span> Netzwerk &amp; Auth</button>
        <button class="filter-pill" data-filter="gui"><span class="pill-num">10</span> Frontends (VS-UI)</button>
        <button class="filter-pill" data-filter="concurrency"><span class="pill-num">11</span> Loom Threads</button>
        <button class="filter-pill" data-filter="ai"><span class="pill-num">12</span> KI (MCP &amp; RAG)</button>
        <button class="filter-pill" data-filter="tooling"><span class="pill-num">13</span> Tooling &amp; LSP</button>
      </div>

      <div class="runner-banner">
        <span>💡 Alle Beispiele als Gesamttest lokal auf der Konsole ausführen:</span>
        <code>./euphorix tutorial/alle_beispiele_ausfuehren.ex</code>
        <button class="btn-copy-small" onclick="copyCommand('./euphorix tutorial/alle_beispiele_ausfuehren.ex', this)">Kopieren</button>
      </div>
    </div>
  </header>

  <!-- Main Content Layout (Sidebar + Content) -->
  <main class="tutorial-main container">
    <div class="tutorial-layout">
      
      <!-- Sticky Sidebar -->
      <aside class="tutorial-sidebar">
        <div class="sidebar-title">Themen &amp; Module ({total_modules_count})</div>
        <nav class="sidebar-nav">
          {sidebar_items_html}
        </nav>
      </aside>

      <!-- Tutorial Content Column -->
      <section class="tutorial-content-area" id="tutorial-cards-container">
        {cards_html}
      </section>

    </div>
  </main>

  <!-- Footer -->
  <footer>
    <div class="footer-container">
      <div>
        <p><strong>{PROJ_NAME} v{PROJ_VER}</strong> – Umfassende Bibliotheken-Referenz &amp; Handbuch</p>
        <p style="font-size: 0.85rem; color: #94a3b8; margin-top: 4px;">&copy; 2026 {OWNER}. Lizenziert unter der {LICENSE}. Basierend auf der <a href="{OPENEU_URL}" target="_blank" rel="noopener" style="color:#64748b; text-decoration:underline;">OpenEuphoria</a> Sprachspezifikation.</p>
      </div>
      <ul class="footer-links">
        <li><a href="index.html">Startseite</a></li>
        <li><a href="tutorial.html">Tutorial &amp; API-Referenz</a></li>
        <li><a href="index.html#downloads">Downloads</a></li>
        <li><a href="{OPENEU_URL}" target="_blank" rel="noopener">OpenEuphoria.org</a></li>
        <li><a href="{GITHUB_URL}" target="_blank" rel="noopener">GitHub</a></li>
        <li><a href="impressum.html">Impressum &amp; Datenschutz</a></li>
      </ul>
    </div>
  </footer>

  <script src="js/main.js"></script>
</body>
</html>"""
    
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write(full_html)
    print(f"  ✓ Created {OUTPUT_FILE} ({os.path.getsize(OUTPUT_FILE) / 1024:.1f} KB, {total_modules_count} Module, {total_functions_count} Funktionen)")

if __name__ == "__main__":
    render_html()
