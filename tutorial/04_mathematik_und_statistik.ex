-- =============================================================================
-- Euphorix Tutorial - Kapitel 4: Mathematik, Statistik & Zufall
-- Behandelte Module: std/math.e, std/mathcons.e, std/rand.e, std/stats.e,
--                    std/primes.e, std/scinot.e, std/fenv.e
-- Ausführen mit: ./euphorix tutorial/04_mathematik_und_statistik.ex
-- =============================================================================

include std/math.e
include std/mathcons.e
include std/rand.e
include std/stats.e
include std/primes.e
include std/scinot.e
include std/fenv.e

puts(1, "=====================================================================\n")
puts(1, "  KAPITEL 4: Mathematik, Statistik, Primzahlen & Zufall\n")
puts(1, "=====================================================================\n\n")

-- -----------------------------------------------------------------------------
-- 1. std/math.e & std/mathcons.e - Trigonometrie, Potenzen & Konstanten
-- Standardfunktionen für wissenschaftliche und kaufmännische Berechnungen.
-- -----------------------------------------------------------------------------
puts(1, "--- 1. std/math.e & std/mathcons.e ---\n")
printf(1, "Kreiszahl PI:          %.6f\n", {PI})
printf(1, "Eulersche Zahl E:      %.6f\n", {E})
printf(1, "Quadratwurzel von 225: %.2f\n", {sqrt(225)})
printf(1, "2 hoch 16:             %.0f\n", {power(2, 16)})
printf(1, "Runden kaufmännisch:   %.2f\n\n", {round(19.9549, 100)})


-- -----------------------------------------------------------------------------
-- 2. std/rand.e - Zufallszahlen & Seed-Verwaltung
-- Generierung von gleichverteilten Pseudozufallszahlen.
-- -----------------------------------------------------------------------------
puts(1, "--- 2. std/rand.e ---\n")
set_rand(98765)
integer wuerfel1 = rand_range(1, 6)
integer wuerfel2 = rand_range(1, 6)
printf(1, "Würfelergebnis: [%d] und [%d] (Summe = %d)\n\n", {wuerfel1, wuerfel2, wuerfel1 + wuerfel2})


-- -----------------------------------------------------------------------------
-- 3. std/stats.e - Statistische Auswertungen
-- Mittelwert (average), Median, Standardabweichung und Summen.
-- -----------------------------------------------------------------------------
puts(1, "--- 3. std/stats.e ---\n")
sequence messreihe = {14.2, 15.8, 13.9, 14.7, 16.1, 14.5, 15.0}
printf(1, "Messreihe:        %s\n", {sprint(messreihe)})
printf(1, "Anzahl Werte:     %d\n", {count(messreihe)})
printf(1, "Summe:            %.2f\n", {sum(messreihe)})
printf(1, "Durchschnitt:     %.2f\n", {average(messreihe)})
printf(1, "Median:           %.2f\n", {median(messreihe)})
printf(1, "Standardabw.:     %.4f\n\n", {stdev(messreihe)})


-- -----------------------------------------------------------------------------
-- 4. std/primes.e - Primzahl-Generierung & Nächste Primzahl
-- Effizientes Berechnen von Primzahlenfolgen und Suchen der nächsten Primzahl.
-- -----------------------------------------------------------------------------
puts(1, "--- 4. std/primes.e ---\n")
sequence primzahlen = prime_list(50)
printf(1, "Alle Primzahlen bis 50: %s\n", {sprint(primzahlen)})
printf(1, "Nächste Primzahl nach 50: %d\n\n", {next_prime(50)})


-- -----------------------------------------------------------------------------
-- 5. std/scinot.e - Wissenschaftliche Notation parsen
-- Konvertiert Strings im Exponentialformat (z.B. 1.25E+08) präzise in Atome.
-- -----------------------------------------------------------------------------
puts(1, "--- 5. std/scinot.e ---\n")
sequence exponent_text = "6.02214E+23"
atom avogadro = scientific_to_atom(exponent_text)
printf(1, "String: '%s' -> Atom-Zahlwert: %.6e\n\n", {exponent_text, avogadro})


-- -----------------------------------------------------------------------------
-- 6. std/fenv.e - Floating-Point Umgebung (IEEE 754 Exceptions)
-- Behandeln und Testen von Gleitkomma-Ausnahmen (Overflow, Inexact etc.).
-- -----------------------------------------------------------------------------
puts(1, "--- 6. std/fenv.e ---\n")
fenv:raise(fenv:FE_OVERFLOW)
printf(1, "Gleitkomma-Ausnahme FE_OVERFLOW aktiv: %d\n", {fenv:test(fenv:FE_OVERFLOW) != 0})
fenv:clear(fenv:FE_OVERFLOW)
printf(1, "Nach fenv:clear() aktiv:               %d\n", {fenv:test(fenv:FE_OVERFLOW) != 0})
