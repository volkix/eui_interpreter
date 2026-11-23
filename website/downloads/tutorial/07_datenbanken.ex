-- =============================================================================
-- Euphorix Tutorial - Kapitel 7: Relationale & Embedded Datenbanken
-- Behandelte Module: std/sqlite.e, std/pgsql.e, std/eds.e
-- Ausführen mit: ./euphorix tutorial/07_datenbanken.ex
-- =============================================================================

include std/sqlite.e as sqlite
include std/pgsql.e as pgsql
include std/eds.e as eds
include std/filesys.e

puts(1, "=====================================================================\n")
puts(1, "  KAPITEL 7: Relationale Datenbanken (SQLite, PostgreSQL) & EDS\n")
puts(1, "=====================================================================\n\n")

-- -----------------------------------------------------------------------------
-- 1. std/sqlite.e - Embedded SQLite 3 Datenbank (In-Memory oder Datei)
-- Schnelle relationale SQL-Engine mit Prepared Statements und Transaktionen.
-- -----------------------------------------------------------------------------
puts(1, "--- 1. std/sqlite.e ---\n")
integer db = sqlite:open(":memory:")

-- Tabellenstruktur anlegen
sqlite:exec(db, `
    CREATE TABLE kunden (
        id      INTEGER PRIMARY KEY AUTOINCREMENT,
        firma   TEXT NOT NULL,
        umsatz  REAL DEFAULT 0.0
    );
`)

-- Parametrisierte Inserts (Schutz vor SQL-Injection)
sqlite:exec(db, "INSERT INTO kunden (firma, umsatz) VALUES (?, ?);", {"Alpha Industrie AG", 125000.50})
sqlite:exec(db, "INSERT INTO kunden (firma, umsatz) VALUES (?, ?);", {"Beta Solutions GmbH", 84200.00})
sqlite:exec(db, "INSERT INTO kunden (firma, umsatz) VALUES (?, ?);", {"Gamma Logistics KG", 210900.75})

-- SQL Abfrage ausführen
sequence kunden = sqlite:query(db, "SELECT id, firma, umsatz FROM kunden ORDER BY umsatz DESC;")
for i = 1 to length(kunden) do
    printf(1, "  [%d] %s: %.2f € Umsatz\n", {kunden[i][1], kunden[i][2], kunden[i][3]})
end for

-- Aggregatfunktion
atom gesamt_umsatz = sqlite:query_value(db, "SELECT SUM(umsatz) FROM kunden;")
printf(1, "Gesamtumsatz aller Kunden: %.2f €\n", {gesamt_umsatz})
sqlite:close(db)
puts(1, "\n")


-- -----------------------------------------------------------------------------
-- 2. std/pgsql.e - Native PostgreSQL Enterprise-Schnittstelle
-- Client-Treiber für PostgreSQL Serverdatenbanken mit Pooling & Transaktionen.
-- -----------------------------------------------------------------------------
puts(1, "--- 2. std/pgsql.e ---\n")
printf(1, "PostgreSQL-Treiber im System verfügbar: %d (1 = Ja)\n", {pgsql:is_available()})
puts(1, "Hinweis: Verbindung mit pgsql:open(\"host=db.intern dbname=prod user=app\")\n\n")


-- -----------------------------------------------------------------------------
-- 3. std/eds.e - Euphoria Database System (Native NoSQL Key-Value / Record DB)
-- Extrem kompakte, blitzschnelle integrierte Datenbank ohne externe Abhängigkeiten.
-- -----------------------------------------------------------------------------
puts(1, "--- 3. std/eds.e ---\n")
sequence eds_datei = "tutorial_eds.edb"
delete_file(eds_datei)

if eds:db_create(eds_datei) = eds:DB_OK then
    -- Tabelle anlegen und auswählen
    eds:db_create_table("benutzer")
    eds:db_select_table("benutzer")

    -- Beliebige Euphoria-Objekte unter einem Schlüssel speichern
    eds:db_insert(1001, {"Max Mustermann", "Geschäftsführer", {"Admin", "Finanzen"}})
    eds:db_insert(1002, {"Erika Musterfrau", "Entwicklungsleiterin", {"Dev", "Architektur"}})

    -- Datensatz über Schlüssel abfragen
    if eds:db_find_key(1001) > 0 then
        sequence datensatz = eds:db_record_data(eds:db_find_key(1001))
        printf(1, "EDS Datensatz 1001 gefunden: %s (%s)\n", {datensatz[1], datensatz[2]})
    end if

    eds:db_close()
    delete_file(eds_datei)
    puts(1, "EDS Datenbank erfolgreich getestet und bereinigt.\n")
end if
