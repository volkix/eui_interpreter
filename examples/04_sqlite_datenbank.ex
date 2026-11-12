-- =============================================================================
-- Beispiel 04: SQLite 3.46 Datenbank, Transaktionen & JSON-Export (std/sqlite.e)
-- Aufruf: ./eui examples/04_sqlite_datenbank.ex
-- =============================================================================
include std/sqlite.e
include std/json.e
include std/text.e

procedure assert_eq(sequence name, object actual, object expected)
    if not equal(actual, expected) then
        printf(2, "FEHLER in %s!\n  Erwartet: %s\n  Erhalten: %s\n", {name, sprint(expected), sprint(actual)})
        abort(1)
    end if
end procedure

puts(1, "=== Beispiel 04: SQLite 3.46 Datenbank & JSON-Export ===\n")

integer db = sqlite:open(":memory:")
assert_eq("Datenbank geöffnet", db > 0, 1)

-- 1. Tabellen anlegen
assert_eq("CREATE TABLE",
    sqlite:exec(db, `
        CREATE TABLE abteilungen (
            id   INTEGER PRIMARY KEY,
            name TEXT NOT NULL
        );
        CREATE TABLE mitarbeiter (
            id           INTEGER PRIMARY KEY,
            name         TEXT NOT NULL,
            abteilung_id INTEGER NOT NULL,
            gehalt       REAL NOT NULL,
            notiz        TEXT
        );
    `),
    1
)

-- 2. Transaktion mit Prepared Statements ('?' Platzhalter)
sqlite:begin(db)
sqlite:exec(db, "INSERT INTO abteilungen (id, name) VALUES (?, ?);", {1, "Entwicklung"})
sqlite:exec(db, "INSERT INTO abteilungen (id, name) VALUES (?, ?);", {2, "Infrastruktur"})

sqlite:exec(db, "INSERT INTO mitarbeiter (name, abteilung_id, gehalt, notiz) VALUES (?, ?, ?, ?);",
    {"Dr. Müller", 1, 92000.0, "Teamleiter C++20"})
sqlite:exec(db, "INSERT INTO mitarbeiter (name, abteilung_id, gehalt, notiz) VALUES (?, ?, ?, ?);",
    {"Sabine Köhler", 1, 84500.0, sqlite:SQL_NULL})
sqlite:exec(db, "INSERT INTO mitarbeiter (name, abteilung_id, gehalt, notiz) VALUES (?, ?, ?, ?);",
    {"Lukas Weiß", 2, 79000.0, "Linux-Architekt"})
sqlite:commit(db)

-- 3. Rollback-Demonstration
sqlite:begin(db)
sqlite:exec(db, "DELETE FROM mitarbeiter;")
assert_eq("Während Transaktion gelöscht", sqlite:query_value(db, "SELECT COUNT(*) FROM mitarbeiter;"), 0)
sqlite:rollback(db)
assert_eq("Nach Rollback wieder 3 Mitarbeiter", sqlite:query_value(db, "SELECT COUNT(*) FROM mitarbeiter;"), 3)

-- 4. JOIN-Abfrage und direkte JSON-Serialisierung via sqlite:query_assoc()
sequence rows_assoc = sqlite:query_assoc(db, `
    SELECT m.id, m.name, a.name AS abteilung, m.gehalt
    FROM mitarbeiter m
    JOIN abteilungen a ON a.id = m.abteilung_id
    WHERE m.gehalt >= ?
    ORDER BY m.id;
`, {80000.0})

assert_eq("Trefferanzahl >= 80k", length(rows_assoc), 2)
assert_eq("1. Mitarbeiter Name (UTF-8)", json:get(rows_assoc[1], "name"), "Dr. Müller")
assert_eq("2. Mitarbeiter Name (UTF-8)", json:get(rows_assoc[2], "name"), "Sabine Köhler")

sequence json_export = json:stringify(json:array(rows_assoc))
printf(1, "  JSON-Export : %s\n", {json_export})

sqlite:close(db)
puts(1, "  [OK] Alle SQLite-Transaktions-, JOIN- und JSON-Export-Tests erfolgreich!\n")
