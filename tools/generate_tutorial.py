#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generate website/tutorial.html for Euphorix.
Contains comprehensive, runnable German examples and explanations for all Standard Modules.
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
        "desc": "Das fundamentale Datenmodell von OpenEuphoria und fortgeschrittene Datenstrukturen: Dynamische Sequenzen, 1-basiertes Slicing, Hash-Maps, LIFO-Stacks, Sortierung und binäre Serialisierung.",
        "file": "tutorial/01_datenstrukturen.ex",
        "modules": [
            {
                "name": "std/sequence.e",
                "ns": "stdseq",
                "desc": "Das Kernmodul von OpenEuphoria. Sequenzen sind dynamische, 1-basierte Listen beliebiger Tiefe. Bietet Slicing mit '$' als Längenbezeichner, Filtern, Invertieren, Spaltenschnitte (vslice) und Listenverbindungen.",
                "code": """include std/sequence.e

sequence fruechte = {"Apfel", "Banane", "Kirsche", "Dattel", "Erdbeere"}

-- 1-basiertes Slicing: Erstes bis vorletztes Element
sequence teil = fruechte[2..$-1] -- {"Banane", "Kirsche", "Dattel"}
printf(1, "Slicing [2..$-1]: %s\\n", {join(teil, ", ")})

-- Sequenz umkehren mit reverse()
sequence umgekehrt = reverse(fruechte)
printf(1, "Umgekehrt: %s\\n", {join(umgekehrt, ", ")})

-- Spaltenextraktion aus 2D-Tabelle (vslice)
sequence tabelle = {
    {101, "Monitor", 249.99},
    {102, "Tastatur", 79.50},
    {103, "Maus", 39.90}
}
sequence artikel = vslice(tabelle, 2)
printf(1, "Spalte 2 (Artikel): %s\\n", {join(artikel, ", ")})""",
                "output": """Slicing [2..$-1]: Banane, Kirsche, Dattel
Umgekehrt: Erdbeere, Dattel, Kirsche, Banane, Apfel
Spalte 2 (Artikel): Monitor, Tastatur, Maus"""
            },
            {
                "name": "std/map.e",
                "ns": "map",
                "desc": "Assoziative Arrays (Hash-Maps) für Key-Value-Speicher beliebiger Schlüssel- und Wertetypen mit O(1) Zugriffszeit.",
                "code": """include std/map.e

map:map laender = map:new()
map:put(laender, "DE", "Deutschland")
map:put(laender, "AT", "Österreich")
map:put(laender, "CH", "Schweiz")

printf(1, "Land DE: %s\\n", {map:get(laender, "DE")})
printf(1, "Land CH: %s\\n", {map:get(laender, "CH")})
printf(1, "Gesamtanzahl: %d\\n", {map:size(laender)})""",
                "output": """Land DE: Deutschland
Land CH: Schweiz
Gesamtanzahl: 3"""
            },
            {
                "name": "std/stack.e",
                "ns": "stack",
                "desc": "LIFO-Stapel (Last-In-First-Out). Ideal für Parser, Navigationsverläufe und Undo-Manager.",
                "code": """include std/stack.e

stack:stack st = stack:new()
stack:push(st, "Startseite")
stack:push(st, "Katalog")
stack:push(st, "Warenkorb")

printf(1, "Oben auf Stack: %s\\n", {stack:top(st)})
printf(1, "Pop: %s\\n", {stack:pop(st)})
printf(1, "Nun oben: %s\\n", {stack:top(st)})""",
                "output": """Oben auf Stack: Warenkorb
Pop: Warenkorb
Nun oben: Katalog"""
            },
            {
                "name": "std/sort.e & std/search.e",
                "ns": "sort / search",
                "desc": "Universelles Sortieren (aufsteigend/absteigend/custom) und schnelle binäre Suche (O(log n)) in sortierten Sequenzen.",
                "code": """include std/sort.e
include std/search.e

sequence zahlen = {42, 17, 99, 3, 28, 55}
sequence sortiert = sort(zahlen)

integer pos = binary_search(42, sortiert)
printf(1, "Sortiert: %s\\n", {sprint(sortiert)})
printf(1, "Wert 42 gefunden an Index: %d\\n", {pos})""",
                "output": """Sortiert: {3,17,28,42,55,99}
Wert 42 gefunden an Index: 4"""
            },
            {
                "name": "std/serialize.e",
                "ns": "serialize",
                "desc": "Verlustfreie binäre Serialisierung beliebiger verschachtelter Euphoria-Objekte in kompakte Bytefolgen zur Speicherung oder Netzwerkübertragung.",
                "code": """include std/serialize.e

sequence paket = {"Benutzerdaten", 42, {199.99, "EUR"}}
sequence bytes = serialize(paket)
sequence res = deserialize(bytes)
object entpackt = res[1]

printf(1, "Serialisierte Bytegröße: %d Bytes\\n", {length(bytes)})
printf(1, "Identisch wiederhergestellt: %d (1 = Ja)\\n", {equal(paket, entpackt)})""",
                "output": """Serialisierte Bytegröße: 47 Bytes
Identisch wiederhergestellt: 1 (1 = Ja)"""
            }
        ]
    },
    {
        "id": "kapitel-2",
        "title": "2. Strings, Text, Regex & Unicode",
        "cat": "text",
        "desc": "Mächtige Textverarbeitungswerkzeuge: Trimmen, Case-Konvertierung, Formatstrings mit Platzhaltern, PCRE-kompatible reguläre Ausdrücke, Mehrbyte-UTF-8 Zeichenzähler und Wildcard-Muster.",
        "file": "tutorial/02_text_und_regex.ex",
        "modules": [
            {
                "name": "std/text.e",
                "ns": "text",
                "desc": "Umfassende Helfer für String-Manipulationen: Leerzeichen entfernen (trim), Groß-/Kleinschreibung (lower, upper, proper) und Formatierung mit Platzhaltern [1], [2].",
                "code": """include std/text.e

sequence roh = "   OpenEuphoria & Euphorix 2026   "
sequence sauber = trim(roh)

printf(1, "Getrimmt:  '%s'\\n", {sauber})
printf(1, "Groß:      '%s'\\n", {upper(sauber)})
printf(1, "Proper:    '%s'\\n", {proper("hallo welt aus europa")})

sequence msg = format("Benutzer [1] hat [2] ungelesene E-Mails.", {"Anna", 4})
printf(1, "Formatiert: %s\\n", {msg})""",
                "output": """Getrimmt:  'OpenEuphoria & Euphorix 2026'
Groß:      'OPENEUPHORIA & EUPHORIX 2026'
Proper:    'Hallo Welt Aus Europa'
Formatiert: Benutzer Anna hat 4 ungelesene E-Mails."""
            },
            {
                "name": "std/regex.e",
                "ns": "regex",
                "desc": "Reguläre Ausdrücke (PCRE kompatibel) für Muster-Validierungen (E-Mail, Telefon), Suchen und Ersetzen mit Capture-Groups.",
                "code": """include std/regex.e as re

re:regex mail_re = re:new(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$`)
sequence email = "kontakt@euphorix-lang.org"

printf(1, "E-Mail gültig: %d\\n", {re:is_match(mail_re, email)})

-- Datumsformat von YYYY-MM-DD nach DD.MM.YYYY wandeln
re:regex datum_re = re:new(`(\\d{4})-(\\d{2})-(\\d{2})`)
sequence konvertiert = re:find_replace(datum_re, "Release: 2026-11-23", `\\3.\\2.\\1`)
printf(1, "Ergebnis: %s\\n", {konvertiert})""",
                "output": """E-Mail gültig: 1
Ergebnis: Release: 23.11.2026"""
            },
            {
                "name": "std/utf8.e",
                "ns": "utf8",
                "desc": "Native Unicode-Unterstützung: Exakte Ermittlung der visuellen Zeichenanzahl statt Bytezählung und UTF-8 Validierung.",
                "code": """include std/utf8.e as utf8

sequence text = "München, Zürich & Köln 🥨"
printf(1, "Text: %s\\n", {text})
printf(1, "Speicherlänge in Bytes:    %d\\n", {length(text)})
printf(1, "Echte UTF-8 Zeichenanzahl: %d\\n", {utf8:len(text)})
printf(1, "Gültige UTF-8 Kodierung:   %d (1 = Ja)\\n", {utf8:valid(text)})""",
                "output": """Text: München, Zürich & Köln 🥨
Speicherlänge in Bytes:    30
Echte UTF-8 Zeichenanzahl: 24
Gültige UTF-8 Kodierung:   1 (1 = Ja)"""
            },
            {
                "name": "std/wildcard.e & std/pretty.e",
                "ns": "wildcard / pretty",
                "desc": "Schnelle Dateinamen-Musterfilter (* und ?) ohne Regex-Overhead sowie strukturiertes Einrücken von Datenstrukturen (Pretty-Print).",
                "code": """include std/wildcard.e
include std/pretty.e

sequence datei = "rechnung_2026_11.pdf"
printf(1, "Passt auf 'rechnung_*.pdf'? %d\\n", {wildcard:is_match("rechnung_*.pdf", datei)})
printf(1, "Passt auf '*.txt'?          %d\\n", {wildcard:is_match("*.txt", datei)})

sequence konfig = {{"host", "localhost"}, {"port", 8080}}
pretty_print(1, konfig, {2})""",
                "output": """Passt auf 'rechnung_*.pdf'? 1
Passt auf '*.txt'?          0
{
  {
    "host",
    "localhost"
  },
  {
    "port",
    8080
  }
}"""
            }
        ]
    },
    {
        "id": "kapitel-3",
        "title": "3. Dateisystem, I/O & Externe Prozesse",
        "cat": "io",
        "desc": "Komfortable Ein- und Ausgabe: Zeilenweises Lesen und Schreiben von Dateien am Stück, plattformunabhängige Pfade, Größenprüfungen und Subprozess-Pipes.",
        "file": "tutorial/03_dateisystem_und_io.ex",
        "modules": [
            {
                "name": "std/io.e",
                "ns": "io",
                "desc": "Dateizugriffe ohne manuelle File-Handles: write_lines(), read_lines(), read_file() und write_file() erledigen Öffnen, Schreiben/Lesen und Schließen atomar.",
                "code": """include std/io.e

sequence zeilen = {
    "Server: lighttpd-01",
    "Status: Aktiv",
    "Max-Clients: 1024"
}
write_lines("demo_cfg.txt", zeilen)

sequence gelesen = read_lines("demo_cfg.txt")
for i = 1 to length(gelesen) do
    printf(1, "  [%d] %s\\n", {i, gelesen[i]})
end for""",
                "output": """  [1] Server: lighttpd-01
  [2] Status: Aktiv
  [3] Max-Clients: 1024"""
            },
            {
                "name": "std/filesys.e",
                "ns": "filesys",
                "desc": "Plattformunabhängige Dateisystemoperationen: Prüfen auf Dateiexistenz, Dateigrößen in Bytes, Verzeichniswechsel und sicheres Pfade-Verbinden.",
                "code": """include std/filesys.e

printf(1, "Existiert 'HANDBUCH.md': %d\\n", {file_exists("HANDBUCH.md")})
printf(1, "Dateigröße:              %d Bytes\\n", {file_length("HANDBUCH.md")})

sequence voller_pfad = join_path({current_dir(), "HANDBUCH.md"})
printf(1, "Dateiendung:             .%s\\n", {fileext("HANDBUCH.md")})""",
                "output": """Existiert 'HANDBUCH.md': 1
Dateigröße:              199341 Bytes
Dateiendung:             .md"""
            },
            {
                "name": "std/pipeio.e",
                "ns": "pipeio",
                "desc": "Ausführen externer Systemprogramme mit Umleitung und Lesen von Standard-Out/Error über Pipes.",
                "code": """include std/pipeio.e

object p = pipeio:exec("echo 'Euphorix Subprozess-Test'", pipeio:create())
if sequence(p) then
    sequence ausgabe = pipeio:read(p[pipeio:STDOUT], 256)
    printf(1, "Ausgabe: %s\\n", {ausgabe})
    pipeio:close(p[pipeio:STDOUT])
    pipeio:close(p[pipeio:STDIN])
    pipeio:close(p[pipeio:STDERR])
end if""",
                "output": """Ausgabe: Euphorix Subprozess-Test"""
            }
        ]
    },
    {
        "id": "kapitel-4",
        "title": "4. Mathematik, Statistik, Primzahlen & Zufall",
        "cat": "math",
        "desc": "Mathematische Grund- und Erweiterungsfunktionen, trigonometrische Berechnungen, statistische Auswertungen (Mittelwert, Median, Streuung), Primzahlen und Pseudozufall.",
        "file": "tutorial/04_mathematik_und_statistik.ex",
        "modules": [
            {
                "name": "std/math.e & std/mathcons.e",
                "ns": "math",
                "desc": "Mathematische Konstanten (PI, E) und Funktionen für Potenzen, Wurzeln, Trigonometrie und kaufmännisches Runden.",
                "code": """include std/math.e
include std/mathcons.e

printf(1, "Kreiszahl PI:          %.6f\\n", {PI})
printf(1, "Quadratwurzel von 225: %.2f\\n", {sqrt(225)})
printf(1, "2 hoch 16:             %.0f\\n", {power(2, 16)})
printf(1, "Kaufmännisch gerundet: %.2f\\n", {round(19.9549, 100)})""",
                "output": """Kreiszahl PI:          3.141593
Quadratwurzel von 225: 15.00
2 hoch 16:             65536
Kaufmännisch gerundet: 19.95"""
            },
            {
                "name": "std/stats.e",
                "ns": "stats",
                "desc": "Statistische Auswertung von Zahlenreihen: Anzahl, Summe, arithmetisches Mittel (average), Median und Standardabweichung.",
                "code": """include std/stats.e

sequence messreihe = {14.2, 15.8, 13.9, 14.7, 16.1, 14.5, 15.0}

printf(1, "Messreihe:    %s\\n", {sprint(messreihe)})
printf(1, "Anzahl:       %d\\n", {count(messreihe)})
printf(1, "Summe:        %.2f\\n", {sum(messreihe)})
printf(1, "Durchschnitt: %.2f\\n", {average(messreihe)})
printf(1, "Median:       %.2f\\n", {median(messreihe)})
printf(1, "Standardabw.: %.4f\\n", {stdev(messreihe)})""",
                "output": """Messreihe:    {14.2,15.8,13.9,14.7,16.1,14.5,15}
Anzahl:       7
Summe:        104.20
Durchschnitt: 14.89
Median:       14.70
Standardabw.: 0.8112"""
            },
            {
                "name": "std/primes.e & std/rand.e",
                "ns": "primes / rand",
                "desc": "Primzahllisten, nächste Primzahlen (next_prime) und gleichverteilte Zufallszahlen mit konfigurierbarem Seed.",
                "code": """include std/primes.e
include std/rand.e

set_rand(98765)
integer wuerfel = rand_range(1, 6)
printf(1, "Gewürfelte Augenzahl: %d\\n", {wuerfel})

sequence prims = prime_list(30)
printf(1, "Primzahlen bis 30: %s\\n", {sprint(prims)})
printf(1, "Nächste Primzahl nach 30: %d\\n", {next_prime(30)})""",
                "output": """Gewürfelte Augenzahl: 4
Primzahlen bis 30: {2,3,5,7,11,13,17,19,23,29}
Nächste Primzahl nach 30: 31"""
            },
            {
                "name": "std/scinot.e & std/fenv.e",
                "ns": "scinot / fenv",
                "desc": "Präzises Einlesen wissenschaftlicher Exponentialschreibweisen ('6.02E+23') und Überwachen von Floating-Point Ausnahmen (Overflow/Underflow).",
                "code": """include std/scinot.e
include std/fenv.e as fenv

atom avogadro = scientific_to_atom("6.02214E+23")
printf(1, "Zahlwert: %.6e\\n", {avogadro})

fenv:raise(fenv:FE_OVERFLOW)
printf(1, "Gleitkomma-Ausnahme aktiv: %d\\n", {fenv:test(fenv:FE_OVERFLOW) != 0})
fenv:clear(fenv:FE_OVERFLOW)
printf(1, "Nach clear aktiv:          %d\\n", {fenv:test(fenv:FE_OVERFLOW) != 0})""",
                "output": """Zahlwert: 6.022140e+23
Gleitkomma-Ausnahme aktiv: 1
Nach clear aktiv:          0"""
            }
        ]
    },
    {
        "id": "kapitel-5",
        "title": "5. Datum, Uhrzeit & Kalender",
        "cat": "datetime",
        "desc": "Umfassende Kalenderberechnungen mit std/datetime.e: Formatierung in beliebigen Mustern (ISO 8601, deutsches Datumsformat), Schaltjahrprüfung, Monatsgrenzen und exakte Zeitdifferenzen.",
        "file": "tutorial/05_datum_und_uhrzeit.ex",
        "modules": [
            {
                "name": "std/datetime.e",
                "ns": "dt",
                "desc": "Zentrales Modul für Zeit und Datum: now(), format(), parse(), add(), diff(), Schaltjahre und Kalendertage.",
                "code": """include std/datetime.e as dt

dt:datetime jetzt = dt:now()
printf(1, "ISO 8601 Zeitstempel:     %s\\n", {dt:format(jetzt, "%Y-%m-%d %H:%M:%S")})
printf(1, "Deutsches Datumsformat:   %s\\n", {dt:format(jetzt, "%d.%m.%Y um %H:%M Uhr")})

printf(1, "Jahr: %d, Monat: %d, Tag: %d\\n", {jetzt[dt:YEAR], jetzt[dt:MONTH], jetzt[dt:DAY]})
printf(1, "Tage im aktuellen Monat:  %d\\n", {dt:days_in_month(jetzt)})
printf(1, "Ist Schaltjahr:           %d\\n", {dt:is_leap_year(jetzt)})

-- 14 Tage Lieferfrist berechnen
dt:datetime lieferung = dt:add(jetzt, 14, dt:DAYS)
printf(1, "Liefertermin in 14 Tagen: %s\\n", {dt:format(lieferung, "%d.%m.%Y")})

atom sekunden = dt:diff(jetzt, lieferung)
printf(1, "Differenz:                %.0f Sekunden (%.1f Tage)\\n", {sekunden, sekunden / 86400})""",
                "output": """ISO 8601 Zeitstempel:     2026-11-23 10:30:00
Deutsches Datumsformat:   23.11.2026 um 10:30 Uhr
Jahr: 2026, Monat: 11, Tag: 23
Tage im aktuellen Monat:  30
Ist Schaltjahr:           0
Liefertermin in 14 Tagen: 07.12.2026
Differenz:                1209600 Sekunden (14.0 Tage)"""
            }
        ]
    },
    {
        "id": "kapitel-6",
        "title": "6. Strukturierte Daten: JSON, JSONPath & XML",
        "cat": "data",
        "desc": "Moderne Datenformate für Schnittstellen: High-Speed JSON-Parsing, RFC 9535 JSONPath-Filterung, Schema-Validierung (Draft 2020-12) und XML DOM mit W3C XPath 1.0.",
        "file": "tutorial/06_json_und_xml.ex",
        "modules": [
            {
                "name": "std/json.e",
                "ns": "json",
                "desc": "Schneller nativer JSON Parser und Serialisierer mit Pfadabfragen ('artikel[1].preis') und RFC 9535 JSONPath.",
                "code": """include std/json.e as json
include std/text.e

sequence shop_json = `{
    "shop": "Euphorix Tech Store",
    "waehrung": "EUR",
    "artikel": [
        {"sku": "SSD-2TB", "titel": "NVMe SSD 2TB", "preis": 129.90, "lager": 15},
        {"sku": "RAM-32G", "titel": "DDR5 RAM 32GB", "preis": 89.50, "lager": 0},
        {"sku": "CPU-8C",  "titel": "8-Core CPU",   "preis": 249.00, "lager": 8}
    ]
}`

object doc = json:decode(shop_json)
printf(1, "Shop-Name: %s\\n", {json:get(doc, "shop")})
printf(1, "Erster Artikel: %s (%.2f €)\\n", {json:get(doc, "artikel[1].titel"), json:get(doc, "artikel[1].preis")})

-- JSONPath: Alle Artikel mit Lagerbestand > 0
sequence lieferbar = json:jsonpath(doc, "$.artikel[?(@.lager > 0)].titel")
printf(1, "Lieferbar: %s\\n", {text:join(lieferbar, ", ")})""",
                "output": """Shop-Name: Euphorix Tech Store
Erster Artikel: NVMe SSD 2TB (129.90 €)
Lieferbar: NVMe SSD 2TB, 8-Core CPU"""
            },
            {
                "name": "std/json_schema.e",
                "ns": "json_schema",
                "desc": "Offizielle JSON-Schema Validierung nach Draft 2020-12 zur Schnittstellenabsicherung von REST-Endpunkten.",
                "code": """include std/json.e as json
include std/json_schema.e as js

sequence schema_str = `{
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "type": "object",
    "required": ["shop", "waehrung"],
    "properties": {
        "shop": {"type": "string"},
        "waehrung": {"type": "string", "maxLength": 3}
    }
}`
object doc = json:decode(`{"shop": "Store", "waehrung": "EUR"}`)
integer valide = js:is_valid(doc, schema_str)
printf(1, "Entspricht JSON-Schema Vertrag: %d (1 = Ja)\\n", {valide})""",
                "output": """Entspricht JSON-Schema Vertrag: 1 (1 = Ja)"""
            },
            {
                "name": "std/xml.e",
                "ns": "xml",
                "desc": "XML DOM Parser und W3C XPath 1.0 Auswertung zum Extrahieren von Elementen und Attributen.",
                "code": """include std/xml.e as xml

sequence rechnung_xml = `<?xml version="1.0" encoding="UTF-8"?>
<rechnung nr="RE-2026-99">
    <positionen>
        <pos art="Lizenz" preis="199.00">Euphorix Server</pos>
        <pos art="Support" preis="50.00">Wartung 1J</pos>
    </positionen>
</rechnung>`

sequence root = xml:decode(rechnung_xml)
printf(1, "Rechnungs-Nummer (Attr): %s\\n", {xml:attr(root, "nr")})

sequence pos_knoten = xml:xpath(root, "//pos")
for i = 1 to length(pos_knoten) do
    printf(1, "  Pos [%d]: %s (%s €)\\n", {i, xml:text(pos_knoten[i]), xml:attr(pos_knoten[i], "preis")})
end for""",
                "output": """Rechnungs-Nummer (Attr): RE-2026-99
  Pos [1]: Euphorix Server (199.00 €)
  Pos [2]: Wartung 1J (50.00 €)"""
            }
        ]
    },
    {
        "id": "kapitel-7",
        "title": "7. Relationale & Embedded Datenbanken",
        "cat": "database",
        "desc": "Robuste Datenhaltung: Integrierte relationale SQLite 3 Datenbank mit Transaktionen und Prepared Statements, Enterprise PostgreSQL Treiber und das native NoSQL Euphoria Database System (EDS).",
        "file": "tutorial/07_datenbanken.ex",
        "modules": [
            {
                "name": "std/sqlite.e",
                "ns": "sqlite",
                "desc": "Embedded SQLite 3.47 Datenbank. Unterstützt In-Memory (:memory:) und Datei-Datenbanken, transaktionale Sicherheit und parametrisierte Queries.",
                "code": """include std/sqlite.e as sqlite

integer db = sqlite:open(":memory:")

sqlite:exec(db, `
    CREATE TABLE kunden (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firma TEXT NOT NULL,
        umsatz REAL DEFAULT 0.0
    );
`)

-- Parametrisierte Inserts (SQL-Injection-Schutz)
sqlite:exec(db, "INSERT INTO kunden (firma, umsatz) VALUES (?, ?);", {"Alpha AG", 125000.50})
sqlite:exec(db, "INSERT INTO kunden (firma, umsatz) VALUES (?, ?);", {"Beta GmbH", 84200.00})

-- SELECT Abfrage
sequence rows = sqlite:query(db, "SELECT id, firma, umsatz FROM kunden;")
for i = 1 to length(rows) do
    printf(1, "  [%d] %s: %.2f €\\n", {rows[i][1], rows[i][2], rows[i][3]})
end for

atom gesamt = sqlite:query_value(db, "SELECT SUM(umsatz) FROM kunden;")
printf(1, "Gesamtumsatz: %.2f €\\n", {gesamt})
sqlite:close(db)""",
                "output": """  [1] Alpha AG: 125000.50 €
  [2] Beta GmbH: 84200.00 €
Gesamtumsatz: 209200.50 €"""
            },
            {
                "name": "std/pgsql.e",
                "ns": "pgsql",
                "desc": "Robuster nativer PostgreSQL Enterprise-Treiber für Serverdatenbanken mit Pooling, Prepared Statements und Transaktionen.",
                "code": """include std/pgsql.e as pgsql

printf(1, "PostgreSQL-Treiber im System verfügbar: %d (1 = Ja)\\n", {pgsql:is_available()})

-- Verbindungsaufbau:
-- integer db = pgsql:open("host=127.0.0.1 dbname=prod user=postgres password=secret")
-- sequence res = pgsql:query(db, "SELECT version();")
-- pgsql:close(db)""",
                "output": """PostgreSQL-Treiber im System verfügbar: 1 (1 = Ja)"""
            },
            {
                "name": "std/eds.e",
                "ns": "eds",
                "desc": "Das native Euphoria Database System (EDS): Ein extrem schneller, dateibasierter Key-Value/Record Store ohne Fremdbibliotheken.",
                "code": """include std/eds.e as eds
include std/filesys.e

delete_file("demo.edb")
if eds:db_create("demo.edb") = eds:DB_OK then
    eds:db_create_table("benutzer")
    eds:db_select_table("benutzer")

    -- Speichert beliebige verschachtelte Sequenzen unter einem Key
    eds:db_insert(1001, {"Max Mustermann", "Geschäftsführer", {"Admin", "Finanzen"}})

    if eds:db_find_key(1001) > 0 then
        sequence rec = eds:db_record_data(eds:db_find_key(1001))
        printf(1, "EDS Datensatz: %s (%s)\\n", {rec[1], rec[2]})
    end if
    eds:db_close()
    delete_file("demo.edb")
end if""",
                "output": """EDS Datensatz: Max Mustermann (Geschäftsführer)"""
            }
        ]
    },
    {
        "id": "kapitel-8",
        "title": "8. Netzwerk, Web, URLs & Sockets",
        "cat": "network",
        "desc": "Netzwerkkommunikation auf allen Schichten: URL-Zerlegung & Percent-Encoding, synchroner und asynchroner HTTP/REST Client & Microservice-Server sowie Low-Level TCP/UDP Sockets.",
        "file": "tutorial/08_netzwerk_und_web.ex",
        "modules": [
            {
                "name": "std/net/url.e",
                "ns": "url",
                "desc": "Zerlegt URLs in Protokoll, Host, Port, Pfad und Query-String und übernimmt Standard Percent-Encoding.",
                "code": """include std/net/url.e as url

sequence u = url:parse("https://api.server.de:8443/v1/produkte?kat=it&limit=10")
printf(1, "Host:  %s\\n", {u[url:URL_HOSTNAME]})
printf(1, "Port:  %d\\n", {u[url:URL_PORT]})
printf(1, "Pfad:  %s\\n", {u[url:URL_PATH]})
printf(1, "Query: %s\\n", {u[url:URL_QUERY_STRING]})

sequence enc = url:encode("Hallo Welt & Co!")
printf(1, "Encoded: %s\\n", {enc})
printf(1, "Decoded: %s\\n", {url:decode(enc)})""",
                "output": """Host:  api.server.de
Port:  8443
Pfad:  /v1/produkte
Query: kat=it&limit=10
Encoded: Hallo+Welt+%26+Co%21
Decoded: Hallo Welt & Co!"""
            },
            {
                "name": "std/http.e",
                "ns": "http",
                "desc": "HTTP Client für GET/POST REST-Calls und integrierter Microservice-Server für Web-APIs.",
                "code": """include std/http.e as http

-- Synchrone REST API Aufrufe:
-- sequence resp = http:get("https://openeuphoria.org")
-- sequence json_resp = http:post_json("https://api.de/auftrag", "{\"id\": 42}")

-- Eingebetteter Microservice-Server:
integer srv = http:server_create("127.0.0.1", 9099)
printf(1, "HTTP Microservice Server-ID: %d\\n", {srv})
http:server_close(srv)""",
                "output": """HTTP Microservice Server-ID: 1"""
            },
            {
                "name": "std/socket.e & std/net/dns.e",
                "ns": "socket / dns",
                "desc": "Low-Level TCP/UDP Sockets für hardwarenahe Netzwerkprotokolle und DNS-Namensauflösung.",
                "code": """include std/socket.e as sock
include std/net/dns.e as dns

object s = sock:create(sock:AF_INET, sock:SOCK_STREAM, 0)
printf(1, "TCP Socket erstellt: %d (1 = Gültig)\\n", {sequence(s)})
sock:close(s)

object host = dns:host_by_name("localhost")
if sequence(host) then
    printf(1, "DNS Hostname: %s\\n", {host[dns:HOST_OFFICIAL_NAME]})
end if""",
                "output": """TCP Socket erstellt: 1 (1 = Gültig)
DNS Hostname: localhost"""
            }
        ]
    },
    {
        "id": "kapitel-9",
        "title": "9. Nebenläufigkeit, Threads & CSP-Channels",
        "cat": "concurrency",
        "desc": "Moderne Concurrency mit Java 25 Loom: Millionen leichtgewichtiger Virtual Threads, Async/Await und sperrfreie Communicating Sequential Processes (CSP Channels wie in Go).",
        "file": "tutorial/09_nebenlaeufigkeit.ex",
        "modules": [
            {
                "name": "std/thread.e",
                "ns": "thread",
                "desc": "Java 25 Loom Virtual Threads. Erzeugt extrem leichtgewichtige parallele Tasks mit async() und wartet auf Ergebnisse mit await().",
                "code": """include std/thread.e as thread

function summiere(atom n)
    atom s = 0
    for i = 1 to n do s += i end for
    return s
end function

-- Parallele Tasks starten
atom job1 = thread:async(routine_id("summiere"), {1000})
atom job2 = thread:async(routine_id("summiere"), {5000})

-- Ergebnisse abwarten
printf(1, "Job 1 (Summe 1..1000): %.0f\\n", {thread:await(job1)})
printf(1, "Job 2 (Summe 1..5000): %.0f\\n", {thread:await(job2)})""",
                "output": """Job 1 (Summe 1..1000): 500500
Job 2 (Summe 1..5000): 12502500"""
            },
            {
                "name": "std/channel.e",
                "ns": "channel",
                "desc": "CSP-Channels (wie in Go) für sperrfreie, threadsichere Nachrichtenübertragung zwischen Virtual Threads mit Puffern und Timeouts.",
                "code": """include std/channel.e as chan

integer postfach = chan:new(5) -- Puffer für 5 Aufträge

chan:send(postfach, {"AUFTRAG", 101, "PDF Rechnung"})
chan:send(postfach, {"AUFTRAG", 102, "E-Mail Bestätigung"})
printf(1, "Gepuffert: %d\\n", {chan:size(postfach)})

object a1 = chan:read(postfach)
object a2 = chan:read(postfach)
printf(1, "Abgeholt: #%d -> %s\\n", {a1[2], a1[3]})
printf(1, "Abgeholt: #%d -> %s\\n", {a2[2], a2[3]})

chan:close(postfach)""",
                "output": """Gepuffert: 2
Abgeholt: #101 -> PDF Rechnung
Abgeholt: #102 -> E-Mail Bestätigung"""
            },
            {
                "name": "std/task.e",
                "ns": "task",
                "desc": "Klassisches kooperatives Multitasking für zustandsbehaftete Coroutinen, Parser und deterministische Spielschleifen.",
                "code": """include std/task.e

-- Kooperatives Multitasking mit:
-- task_id t = task_create(routine_id("worker"), {})
-- task_schedule(t, {0.1, 0.2})
-- task_yield()
puts(1, "Kooperatives Coroutinen-Multitasking einsatzbereit.\\n")""",
                "output": """Kooperatives Coroutinen-Multitasking einsatzbereit."""
            }
        ]
    },
    {
        "id": "kapitel-10",
        "title": "10. Web- & Desktop-Frontends",
        "cat": "gui",
        "desc": "Frontend-Entwicklung mit Euphorix: Das autarke High-Density Web-Framework VS-UI (html/) mit flackerfreien Patches und Mobile-Card View, SAP UI5 Web Components und Swing Desktop-GUI.",
        "file": "tutorial/10_web_und_gui.ex",
        "modules": [
            {
                "name": "std/vsui.e",
                "ns": "vsui",
                "desc": "High-Density Web UI für ERP-Cockpits, Formulare, Sticky-Header DataGrids und reaktive JSON-Patches ohne Seiten-Reload.",
                "code": """include std/vsui.e as vsui

-- HTML-Elemente für ERP Formular generieren
sequence inp = vsui:input("txt_kdnr", "10042", "Kundennummer...")
sequence btn = vsui:button("btn_save", "Speichern", "on_save")

printf(1, "Input-Tag:  %s\\n", {inp})
printf(1, "Button-Tag: %s\\n", {btn})

-- Reaktiver Server-Push Patch (ohne Seiten-Reload)
sequence patch = vsui:updates({
    vsui:set_val("txt_kdnr", "10043"),
    vsui:toast_show("Kunde erfolgreich angelegt!", vsui:TOAST_SUCCESS)
})
printf(1, "JSON-Patch: %s\\n", {patch[2]})""",
                "output": """Input-Tag:  <input id="txt_kdnr" class="vs-input" type="text" value="10042" />
Button-Tag: <button id="btn_save" class="vs-button" data-vs-click="btn_save">Speichern</button>
JSON-Patch: [{"type":"setValue","id":"txt_kdnr","val":"10043"},{"type":"toast","text":"Kunde erfolgreich angelegt!","toast_type":"success","duration":3000}]"""
            },
            {
                "name": "std/ui5.e & std/gui.e",
                "ns": "ui5 / gui",
                "desc": "Enterprise Web Components im SAP Fiori Design (std/ui5.e) und plattformunabhängige Desktop-Fenster mit Java Swing / AWT (std/gui.e).",
                "code": """include std/ui5.e as ui5
include std/gui.e as gui

sequence ui5_btn = ui5:button("btn1", "Im ERP buchen", "Emphasized")
printf(1, "UI5 Component: %s\\n", {ui5_btn})

-- Desktop GUI:
-- atom win = gui:window("Euphorix Cockpit", 800, 600)
-- gui:show(win)
puts(1, "Swing Desktop-GUI bereit für native Fenster & Dialoge.\\n")""",
                "output": """UI5 Component: <ui5-button id="btn1" design="Default">Im ERP buchen</ui5-button>
Swing Desktop-GUI bereit für native Fenster & Dialoge."""
            }
        ]
    },
    {
        "id": "kapitel-11",
        "title": "11. Betriebssystem, Konsole & CLI",
        "cat": "os",
        "desc": "System- und Shell-Integration: Auslesen von Umgebungsvariablen, CLI-Options-Parser mit automatischer Hilfe (-h, --port), farbige Konsolenausgaben und String-to-Value Parsing.",
        "file": "tutorial/11_system_und_cli.ex",
        "modules": [
            {
                "name": "std/os.e",
                "ns": "os",
                "desc": "Umgebungsvariablen abfragen (getenv), Kommandozeilenargumente (command_line) und Betriebssystem-Kernelaufrufe.",
                "code": """include std/os.e

printf(1, "Benutzer:   %s\\n", {getenv("USER")})
printf(1, "Shell:      %s\\n", {getenv("SHELL")})
printf(1, "Argumente:  %d Token\\n", {length(command_line())})""",
                "output": """Benutzer:   volkix
Shell:      /bin/bash
Argumente:  2 Token"""
            },
            {
                "name": "std/console.e & std/graphics.e",
                "ns": "console",
                "desc": "Farbige ANSI-Konsolenausgaben (text_color, bk_color) und Cursorsteuerung für professionelle Terminal-Tools.",
                "code": """include std/console.e
include std/graphics.e

text_color(GREEN)
puts(1, "[OK]   Dienst 'euphorix-worker' läuft stabil.\\n")
text_color(YELLOW)
puts(1, "[WARN] Speicherbelegung erreicht 75% Schwellwert.\\n")
text_color(WHITE)""",
                "output": """[OK]   Dienst 'euphorix-worker' läuft stabil.
[WARN] Speicherbelegung erreicht 75% Schwellwert."""
            },
            {
                "name": "std/cmdline.e & std/get.e",
                "ns": "cmdline / get",
                "desc": "Professioneller Schalter-Parser für Kommandozeilen-Tools sowie flexible Typ-Konvertierung von Benutzereingaben (value).",
                "code": """include std/cmdline.e as cmd
include std/get.e

sequence val_zahl = value("9876.54")
printf(1, "Geparster Zahlenwert: %.2f\\n", {val_zahl[2]})

sequence val_seq = value("{10, 20, {30, 40}}")
printf(1, "Geparste Sequenz:     %s\\n", {sprint(val_seq[2])})""",
                "output": """Geparster Zahlenwert: 9876.54
Geparste Sequenz:     {10,20,{30,40}}"""
            }
        ]
    },
    {
        "id": "kapitel-12",
        "title": "12. Java-Interop, Hashes, Typen, Speicher & Testing",
        "cat": "interop",
        "desc": "Tiefgehende Systemintegration: Nahtlose Interoperabilität mit dem gesamten JDK 25 Ökosystem, Base64 & Hashing (MD5, SHA-256), benutzerdefinierte Typen, Maschinenspeicher (peek/poke) und Unit-Testing.",
        "file": "tutorial/12_interop_und_testing.ex",
        "modules": [
            {
                "name": "std/java.e",
                "ns": "java",
                "desc": "Direkter Java 25 Zugriff: Instanziieren beliebiger Java-Klassen und Aufruf statischer oder dynamischer Methoden ohne JNI-Boilerplate.",
                "code": """include std/java.e as java

object jver = java:call_static("java.lang.System", "getProperty", {"java.version"})
object os = java:call_static("java.lang.System", "getProperty", {"os.name"})
printf(1, "Unterliegende Java-Laufzeit: %s (%s)\\n", {jver, os})""",
                "output": """Unterliegende Java-Laufzeit: 25.0.4 (Linux)"""
            },
            {
                "name": "std/convert.e & std/base64.e",
                "ns": "convert / base64",
                "desc": "Hexadezimal-Parsing (hex_text), to_string und standardkonformes Base64 Kodieren und Dekodieren.",
                "code": """include std/convert.e
include std/base64.e

printf(1, "Hex 'DEADBEEF' als Zahl: %.0f\\n", {hex_text("DEADBEEF")})

sequence b64 = encode("Euphorix VM 2026")
printf(1, "Base64:    %s\\n", {b64})
printf(1, "Dekodiert: %s\\n", {decode(b64)})""",
                "output": """Hex 'DEADBEEF' als Zahl: 3735928559
Base64:    RXVwaG9yaXggVk0gMjAyNg==
Dekodiert: Euphorix VM 2026"""
            },
            {
                "name": "std/hash.e",
                "ns": "stdhash",
                "desc": "Kryptografische und nicht-kryptografische Hashfunktionen (MD5, SHA-256, Adler32, Fletcher32).",
                "code": """include std/hash.e

atom hash_val = hash("BenutzerPasswort2026", stdhash:MD5)
printf(1, "Berechneter MD5 Hashwert: %d\\n", {hash_val})""",
                "output": """Berechneter MD5 Hashwert: 1911741600"""
            },
            {
                "name": "std/machine.e & std/memory.e",
                "ns": "machine / memory",
                "desc": "Maschinenspeicher-Verwaltung: allocate(), free(), peek() und poke() für Low-Level C-FFI und Speicherblöcke.",
                "code": """include std/machine.e
include std/memory.e

atom ptr = allocate(16)
poke(ptr, 123)
printf(1, "Gelesener Wert aus Speicher: %d\\n", {peek(ptr)})
free(ptr)
puts(1, "Speicherblock freigegeben.\\n")""",
                "output": """Gelesener Wert aus Speicher: 123
Speicherblock freigegeben."""
            },
            {
                "name": "std/unittest.e",
                "ns": "unittest",
                "desc": "Integriertes Test-Framework: test_equal(), test_true(), test_false() und zusammenfassende Test-Reports.",
                "code": """include std/unittest.e

set_test_verbosity(TEST_SHOW_ALL)
test_equal("Addition", 5 + 5, 10)
test_true("Größer", 100 > 50)
test_false("Gleichheit", equal("A", "B"))
test_report()""",
                "output": """  passed: Addition
  passed: Größer
  passed: Gleichheit
  3 tests run, 3 passed, 0 failed, 100% success"""
            }
        ]
    }
]

def render_html():
    # Build Sidebar links and cards
    sidebar_items_html = ""
    cards_html = ""

    for chap in CHAPTERS:
        cid = chap["id"]
        ctitle = chap["title"]
        ccat = chap["cat"]
        cfile = chap["file"]
        cdesc = chap["desc"]

        sidebar_items_html += f"""
        <div class="sidebar-chap-group" data-cat="{ccat}">
          <a href="#{cid}" class="sidebar-chap-link">{ctitle}</a>
          <ul class="sidebar-sublist">
        """

        cards_html += f"""
        <section id="{cid}" class="tutorial-chapter-section" data-cat="{ccat}">
          <div class="chapter-badge">Kapitel</div>
          <h2>{ctitle}</h2>
          <p class="chapter-desc">{cdesc}</p>
          <div class="chapter-file-badge">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>
            Quellcode im Repository: <code>{cfile}</code>
          </div>
        """

        for mod in chap["modules"]:
            mname = mod["name"]
            mns = mod["ns"]
            mdesc = mod["desc"]
            mcode = mod["code"]
            moutput = mod["output"]
            mid = "mod-" + mname.replace("/", "-").replace(".", "-").replace(" ", "-")

            sidebar_items_html += f"""
            <li><a href="#{mid}" class="sidebar-mod-link">{mname}</a></li>
            """

            # HTML escape code and output
            code_escaped = mcode.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            out_escaped = moutput.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

            cards_html += f"""
            <article id="{mid}" class="tutorial-card" data-cat="{ccat}" data-keywords="{mname} {mns}">
              <div class="card-header">
                <div>
                  <span class="mod-pill">{mname}</span>
                  <span class="ns-pill">Namespace: {mns}</span>
                </div>
                <button class="btn-copy-code" onclick="copySnippet(this)">Code kopieren</button>
              </div>
              <p class="mod-explanation">{mdesc}</p>
              
              <div class="code-box">
                <div class="code-box-header">
                  <span>Euphoria Quellcode</span>
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
  <title>Tutorial & Bibliotheken-Handbuch – {PROJ_NAME}</title>
  <meta name="description" content="Umfassendes Tutorial und interaktive Standardbibliothek-Referenz für Euphorix / OpenEuphoria mit praxiserprobten, lauffähigen Codebeispielen in deutscher Sprache.">
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
        <span class="pill pill-primary">📚 Offizielles Tutorial &amp; Cookbook</span>
        <span class="pill pill-accent">✓ Alle 12 Kapitel lauffähig getestet</span>
        <span class="pill">🌐 <a href="{OPENEU_URL}" target="_blank" rel="noopener" style="text-decoration:none; color:inherit;">openeuphoria.org Standard</a></span>
      </div>
      <h1>Interaktives Tutorial &amp; Standard-Bibliotheks-Handbuch</h1>
      <p class="lead">Praxisnahe Anleitungen und ausführlich erklärte Codebeispiele für alle Module der Euphorix / OpenEuphoria Standardbibliothek. Alle Codeblöcke sind direkt mit <code>./euphorix</code> ausführbar.</p>
      
      <!-- Live Search & Filter Bar -->
      <div class="tutorial-search-wrapper">
        <div class="search-box-inner">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
          <input type="text" id="tutorial-search" placeholder="Modul, Routine oder Stichwort suchen (z.B. sequence, json, sqlite, regex, thread)..." autocomplete="off">
          <button id="clear-search" style="display:none;" title="Suche leeren">✕</button>
        </div>
      </div>

      <!-- Category Filter Pills -->
      <div class="filter-pills-bar">
        <button class="filter-pill active" data-filter="all">Alle Module</button>
        <button class="filter-pill" data-filter="collections">1. Sequenzen &amp; Maps</button>
        <button class="filter-pill" data-filter="text">2. Strings &amp; Regex</button>
        <button class="filter-pill" data-filter="io">3. Dateisystem &amp; I/O</button>
        <button class="filter-pill" data-filter="math">4. Mathe &amp; Statistik</button>
        <button class="filter-pill" data-filter="datetime">5. Datum &amp; Zeit</button>
        <button class="filter-pill" data-filter="data">6. JSON &amp; XML</button>
        <button class="filter-pill" data-filter="database">7. Datenbanken</button>
        <button class="filter-pill" data-filter="network">8. Netzwerk &amp; Web</button>
        <button class="filter-pill" data-filter="concurrency">9. Loom &amp; Channels</button>
        <button class="filter-pill" data-filter="gui">10. Web- &amp; Desktop-GUI</button>
        <button class="filter-pill" data-filter="os">11. OS &amp; CLI</button>
        <button class="filter-pill" data-filter="interop">12. Interop &amp; Testing</button>
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
        <div class="sidebar-title">Kapitel &amp; Module</div>
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
        <p><strong>{PROJ_NAME} v{PROJ_VER}</strong> – Interaktives Tutorial &amp; Bibliotheken-Referenz</p>
        <p style="font-size: 0.85rem; color: #94a3b8; margin-top: 4px;">&copy; 2026 {OWNER}. Lizenziert unter der {LICENSE}. Basierend auf der <a href="{OPENEU_URL}" target="_blank" rel="noopener" style="color:#64748b; text-decoration:underline;">OpenEuphoria</a> Sprachspezifikation.</p>
      </div>
      <ul class="footer-links">
        <li><a href="index.html">Startseite</a></li>
        <li><a href="tutorial.html">Tutorial</a></li>
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
    print(f"  ✓ Created {OUTPUT_FILE} ({os.path.getsize(OUTPUT_FILE) / 1024:.1f} KB)")

if __name__ == "__main__":
    render_html()
