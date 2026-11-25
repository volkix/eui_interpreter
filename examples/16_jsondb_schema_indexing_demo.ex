-- ==============================================================================
-- Euphorix 1.0 Demo: Eingebettete JSON-Datenbank auf EDS-Basis mit Indizes & JSON-Schema
-- ==============================================================================
--
-- Demonstriert das vollwertige JSON-Dokumenten-Datenbanksystem (std/jsondb.e):
-- 1. Collections & Dokumentenverwaltung auf Basis von EDS (std/eds.e)
-- 2. Sekundärindizes auf beliebige Top-Level- & verschachtelte Felder (z. B. "adresse.stadt")
-- 3. Blitzschnelle O(log N) binäre Suche & numerische Bereichsabfragen
-- 4. Schema-Enforcement: Ablehnung ungültiger Dokumente beim Insert
-- 5. Suche & Filterung mit deklarativen JSON-Schemas (std/json_schema.e)
--
-- Ausführen mit:
--   ./euphorix examples/16_jsondb_schema_indexing_demo.ex
-- ==============================================================================

include std/jsondb.e as jsondb
include std/io.e as io
include std/filesys.e as fs

puts(io:SCREEN, "=====================================================================\n")
puts(io:SCREEN, "  Euphorix 1.0 – JSON Document Database (EDS-Engine + JSON-Schema)\n")
puts(io:SCREEN, "  Indizierte NoSQL-Speicherung, Sekundärindizes & Schema-Filterung\n")
puts(io:SCREEN, "=====================================================================\n\n")

sequence db_file = "/tmp/enterprise_crm.jdb"
if fs:file_exists(db_file) then
    fs:delete_file(db_file)
end if

-- 1. Datenbank erstellen
puts(io:SCREEN, "📁 1. Erstelle neue JSON-Datenbank auf EDS-Basis: " & db_file & "\n")
sequence db_res = jsondb:create_db(db_file)
if db_res[1] = 0 then
    puts(io:STDERR, "Fehler: " & db_res[2] & "\n")
    abort(1)
end if
puts(io:SCREEN, "   ✓ Datenbank erfolgreich initialisiert.\n\n")

-- 2. Collection mit Schema-Enforcement anlegen
puts(io:SCREEN, "📋 2. Erstelle Collection 'kunden' mit striktem JSON-Schema...\n")
sequence kunden_schema =
    "{\n" &
    "  \"type\": \"object\",\n" &
    "  \"required\": [\"name\", \"status\", \"umsatz\"],\n" &
    "  \"properties\": {\n" &
    "    \"name\":   {\"type\": \"string\", \"minLength\": 2},\n" &
    "    \"status\": {\"type\": \"string\", \"enum\": [\"A-Kunde\", \"B-Kunde\", \"C-Kunde\"]},\n" &
    "    \"umsatz\": {\"type\": \"number\", \"minimum\": 0}\n" &
    "  }\n" &
    "}"

sequence col_res = jsondb:create_collection("kunden", kunden_schema)
puts(io:SCREEN, "   ✓ Collection 'kunden' mit Validierungsschema angelegt.\n\n")

-- 3. Sekundärindizes anlegen
puts(io:SCREEN, "⚡ 3. Erstelle Sekundärindizes für blitzschnelle O(log N) Lookups...\n")
jsondb:create_index("kunden", "status")
jsondb:create_index("kunden", "adresse.stadt")
jsondb:create_index("kunden", "umsatz")

sequence idx_list = jsondb:list_indexes("kunden")
puts(io:SCREEN, "   Aktive Indizes auf 'kunden':\n")
for i = 1 to length(idx_list) do
    puts(io:SCREEN, sprintf("   • Index #%d: '%s' (B-Tree sortiert in EDS)\n", {i, idx_list[i]}))
end for
puts(io:SCREEN, "\n")

-- 4. Schema-Prüfung demonstrieren (Ungültiges Dokument wird abgefangen)
puts(io:SCREEN, "🛡️ 4. Test: Versuche ungültiges Dokument einzufügen (negativer Umsatz, ungültiger Status)...\n")
sequence invalid_doc =
    "{\n" &
    "  \"name\": \"X\",\n" &
    "  \"status\": \"Unbekannt\",\n" &
    "  \"umsatz\": -500\n" &
    "}"

sequence ins_bad = jsondb:insert("kunden", invalid_doc, "BAD-01")
if ins_bad[1] = 0 then
    puts(io:SCREEN, "   ✓ Insert wurde wie erwartet abgewehrt!\n" & ins_bad[2] & "\n\n")
else
    puts(io:STDERR, "FEHLER: Ungültiges Dokument wurde fälschlicherweise akzeptiert!\n")
end if

-- 5. Gültige Dokumente einfügen
puts(io:SCREEN, "💾 5. Füge 5 gültige Unternehmens-Dokumente mit verschachtelten Adressen ein...\n")

sequence docs = {
    {
        "K-1001",
        "{\n" &
        "  \"name\": \"Schulze Maschinenbau AG\",\n" &
        "  \"status\": \"A-Kunde\",\n" &
        "  \"umsatz\": 142500.00,\n" &
        "  \"adresse\": {\"stadt\": \"Frankfurt\", \"plz\": \"60311\"},\n" &
        "  \"tags\": [\"Industrie\", \"CNC\", \"Key-Account\"]\n" &
        "}"
    },
    {
        "K-1002",
        "{\n" &
        "  \"name\": \"Müller Feinwerktechnik\",\n" &
        "  \"status\": \"B-Kunde\",\n" &
        "  \"umsatz\": 48200.00,\n" &
        "  \"adresse\": {\"stadt\": \"Stuttgart\", \"plz\": \"70173\"},\n" &
        "  \"tags\": [\"Präzision\", \"Zulieferer\"]\n" &
        "}"
    },
    {
        "K-1003",
        "{\n" &
        "  \"name\": \"Alpha Automation GmbH\",\n" &
        "  \"status\": \"A-Kunde\",\n" &
        "  \"umsatz\": 215000.00,\n" &
        "  \"adresse\": {\"stadt\": \"Frankfurt\", \"plz\": \"60486\"},\n" &
        "  \"tags\": [\"Robotik\", \"Automotive\"]\n" &
        "}"
    },
    {
        "K-1004",
        "{\n" &
        "  \"name\": \"Nordic Logistics e.K.\",\n" &
        "  \"status\": \"B-Kunde\",\n" &
        "  \"umsatz\": 87000.00,\n" &
        "  \"adresse\": {\"stadt\": \"Hamburg\", \"plz\": \"20095\"},\n" &
        "  \"tags\": [\"Spedition\", \"Seefracht\"]\n" &
        "}"
    },
    {
        "K-1005",
        "{\n" &
        "  \"name\": \"Bavaria Clean Energy SE\",\n" &
        "  \"status\": \"A-Kunde\",\n" &
        "  \"umsatz\": 320000.00,\n" &
        "  \"adresse\": {\"stadt\": \"München\", \"plz\": \"80331\"},\n" &
        "  \"tags\": [\"Solar\", \"Speicher\"]\n" &
        "}"
    }
}

for i = 1 to length(docs) do
    sequence res = jsondb:insert("kunden", docs[i][2], docs[i][1])
    puts(io:SCREEN, sprintf("   ✓ Eingefügt: %s (%s)\n", {docs[i][1], res[2]}))
end for
puts(io:SCREEN, sprintf("   Gesamtanzahl Dokumente in 'kunden': %d\n\n", {jsondb:count("kunden")}))

-- 6. Abfragen über Sekundärindizes (O(log N))
puts(io:SCREEN, "🔎 6. Schnelle Index-Suche nach 'status = A-Kunde' (O(log N) via B-Tree Index)...\n")
sequence a_kunden = jsondb:find_by("kunden", "status", "A-Kunde")
puts(io:SCREEN, sprintf("   Gefundene A-Kunden (%d Treffer):\n", {length(a_kunden)}))
for i = 1 to length(a_kunden) do
    puts(io:SCREEN, sprintf("   • ID: %s | Inhalt: %s\n", {a_kunden[i][1], a_kunden[i][2]}))
end for
puts(io:SCREEN, "\n")

puts(io:SCREEN, "🔎 7. Index-Suche auf verschachteltes Feld: 'adresse.stadt = Frankfurt'...\n")
sequence ffm_kunden = jsondb:find_by("kunden", "adresse.stadt", "Frankfurt")
puts(io:SCREEN, sprintf("   Gefundene Kunden in Frankfurt (%d Treffer):\n", {length(ffm_kunden)}))
for i = 1 to length(ffm_kunden) do
    puts(io:SCREEN, sprintf("   • ID: %s\n", {ffm_kunden[i][1]}))
end for
puts(io:SCREEN, "\n")

-- 8. Numerische Bereichsabfrage auf Umsatz
puts(io:SCREEN, "📊 8. Numerische Bereichsabfrage auf Index 'umsatz' (50.000 € bis 200.000 €)...\n")
sequence range_kunden = jsondb:find_range("kunden", "umsatz", 50000.0, 200000.0)
puts(io:SCREEN, sprintf("   Treffer im Umsatzkorridor (%d Treffer):\n", {length(range_kunden)}))
for i = 1 to length(range_kunden) do
    puts(io:SCREEN, sprintf("   • ID: %s\n", {range_kunden[i][1]}))
end for
puts(io:SCREEN, "\n")

-- 9. Suchen mit deklarativem JSON-Schema
puts(io:SCREEN, "🎯 9. Suchen & Filtern mit deklarativem JSON-SCHEMA:\n")
puts(io:SCREEN, "   Kriterium: Finde alle A-Kunden mit einem Jahresumsatz von MINDESTENS 200.000 €...\n\n")

sequence search_schema =
    "{\n" &
    "  \"type\": \"object\",\n" &
    "  \"properties\": {\n" &
    "    \"status\": {\"const\": \"A-Kunde\"},\n" &
    "    \"umsatz\": {\"minimum\": 200000.0}\n" &
    "  },\n" &
    "  \"required\": [\"status\", \"umsatz\"]\n" &
    "}"

sequence schema_matches = jsondb:find_by_schema("kunden", search_schema)
puts(io:SCREEN, sprintf("   Gefundene Dokumente nach Schema-Validierung (%d Treffer):\n", {length(schema_matches)}))
for i = 1 to length(schema_matches) do
    puts(io:SCREEN, sprintf("   • [%s]:\n%s\n", {schema_matches[i][1], schema_matches[i][2]}))
end for

-- 10. Aufräumen
jsondb:close_db()
fs:delete_file(db_file)

puts(io:SCREEN, "=====================================================================\n")
puts(io:SCREEN, "  ✓ JSON-Datenbank Demo auf EDS-Basis 100% ERFOLGREICH!\n")
puts(io:SCREEN, "=====================================================================\n")
