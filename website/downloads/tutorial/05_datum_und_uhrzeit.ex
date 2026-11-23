-- =============================================================================
-- Euphorix Tutorial - Kapitel 5: Datum, Uhrzeit & Kalenderberechnungen
-- Behandeltes Modul: std/datetime.e
-- Ausführen mit: ./euphorix tutorial/05_datum_und_uhrzeit.ex
-- =============================================================================

include std/datetime.e as dt

puts(1, "=====================================================================\n")
puts(1, "  KAPITEL 5: Datum, Uhrzeit & Kalenderberechnungen\n")
puts(1, "=====================================================================\n\n")

-- -----------------------------------------------------------------------------
-- 1. std/datetime.e - Aktuelle Zeit, Parsing, Formatierung & Zeitrechnung
-- Exakte Berechnungen mit Zeitzonen, Schaltjahren und Zeitdifferenzen.
-- -----------------------------------------------------------------------------
puts(1, "--- 1. std/datetime.e ---\n")

-- Aktuelle Zeitstempel
dt:datetime jetzt = dt:now()
printf(1, "Aktueller Zeitstempel (ISO):   %s\n", {dt:format(jetzt, "%Y-%m-%d %H:%M:%S")})
printf(1, "Deutsches Standardformat:      %s\n", {dt:format(jetzt, "%d.%m.%Y um %H:%M Uhr")})

-- Einzelkomponenten
printf(1, "Jahr: %d, Monat: %d, Tag: %d\n", {jetzt[dt:YEAR], jetzt[dt:MONTH], jetzt[dt:DAY]})
printf(1, "Tage im aktuellen Monat:       %d\n", {dt:days_in_month(jetzt)})
printf(1, "Ist Schaltjahr:                %d\n", {dt:is_leap_year(jetzt)})

-- Zeitreise: Tage und Stunden addieren
dt:datetime liefertermin = dt:add(jetzt, 14, dt:DAYS)
printf(1, "Liefertermin in 14 Tagen:      %s\n", {dt:format(liefertermin, "%d.%m.%Y")})

-- Zeitdifferenz in Sekunden
atom sekunden = dt:diff(jetzt, liefertermin)
printf(1, "Differenz:                     %.0f Sekunden (%.1f Tage)\n\n", {sekunden, sekunden / 86400})
