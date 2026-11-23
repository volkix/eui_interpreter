-- =============================================================================
-- Euphorix Tutorial - Kapitel 2: Strings, Textverarbeitung & Reguläre Ausdrücke
-- Behandelte Module: std/text.e, std/regex.e, std/utf8.e, std/wildcard.e,
--                    std/pretty.e
-- Ausführen mit: ./euphorix tutorial/02_text_und_regex.ex
-- =============================================================================

include std/text.e
include std/regex.e as re
include std/utf8.e as utf8
include std/wildcard.e
include std/pretty.e

puts(1, "=====================================================================\n")
puts(1, "  KAPITEL 2: Strings, Text, Regex & Unicode\n")
puts(1, "=====================================================================\n\n")

-- -----------------------------------------------------------------------------
-- 1. std/text.e - String-Manipulation & Formatierung
-- Schnelles Bereinigen von Leerzeichen, Groß-/Kleinschreibung und Formatstrings.
-- -----------------------------------------------------------------------------
puts(1, "--- 1. std/text.e ---\n")
sequence rohtext = "   OpenEuphoria & Euphorix 2026   "
sequence sauber = trim(rohtext)
printf(1, "Getrimmt:  '%s'\n", {sauber})
printf(1, "Großbuchstaben: '%s'\n", {upper(sauber)})
printf(1, "Wortanfang groß (proper): '%s'\n", {proper("hallo welt aus europa")})

-- Formatierung mit Platzhaltern [1], [2]
sequence meldung = format("Benutzer [1] hat [2] ungelesene Nachrichten in [3].", {"Anna", 4, "Postfach"})
printf(1, "Formatiert: %s\n\n", {meldung})


-- -----------------------------------------------------------------------------
-- 2. std/regex.e - Reguläre Ausdrücke (PCRE kompatibel)
-- Validierung von Mustern und Extrahieren von Treffergruppen.
-- -----------------------------------------------------------------------------
puts(1, "--- 2. std/regex.e ---\n")
re:regex mail_re = re:new(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
sequence test_email = "kontakt@euphorix-lang.org"

if re:is_match(mail_re, test_email) then
    printf(1, "E-Mail '%s' ist gültig!\n", {test_email})
else
    printf(1, "E-Mail '%s' ist ungültig!\n", {test_email})
end if

-- Suchen und Ersetzen mit Regex
re:regex datum_re = re:new(`(\d{4})-(\d{2})-(\d{2})`)
sequence text_mit_datum = "Release-Datum: 2026-11-23 auf Server"
sequence formatiert = re:find_replace(datum_re, text_mit_datum, `\3.\2.\1`)
printf(1, "Ersetztes Datumsformat: %s\n\n", {formatiert})


-- -----------------------------------------------------------------------------
-- 3. std/utf8.e - UTF-8 Validierung & Zeichenzähler
-- Unterscheidung zwischen Byte-Länge und visueller Zeichenlänge.
-- -----------------------------------------------------------------------------
puts(1, "--- 3. std/utf8.e ---\n")
sequence unicode_text = "München, Zürich & Köln 🥨"
printf(1, "Text: %s\n", {unicode_text})
printf(1, "Speicherlänge in Bytes: %d\n", {length(unicode_text)})
printf(1, "Echte UTF-8 Zeichenanzahl: %d\n", {utf8:len(unicode_text)})
printf(1, "Gültige UTF-8 Kodierung: %d (1 = Ja)\n\n", {utf8:valid(unicode_text)})


-- -----------------------------------------------------------------------------
-- 4. std/wildcard.e - Schnelle Wildcard-Muster (* und ?)
-- Leichtgewichtige Filter ohne Regex-Kompilierungszeit.
-- -----------------------------------------------------------------------------
puts(1, "--- 4. std/wildcard.e ---\n")
sequence datei = "rechnung_2026_11.pdf"
printf(1, "Datei: %s\n", {datei})
printf(1, "Passt auf 'rechnung_*.pdf'? %d\n", {wildcard:is_match("rechnung_*.pdf", datei)})
printf(1, "Passt auf '*.txt'?          %d\n\n", {wildcard:is_match("*.txt", datei)})


-- -----------------------------------------------------------------------------
-- 5. std/pretty.e - Strukturierte Konsolenausgabe (Pretty-Print)
-- Formatiertes Einrücken verschachtelter Daten für Logging & Debugging.
-- -----------------------------------------------------------------------------
puts(1, "--- 5. std/pretty.e ---\n")
sequence konfig = {
    {"server", "lighttpd"},
    {"port", 8080},
    {"features", {"gzip", "ssl", "rewrite"}}
}
puts(1, "Pretty-Print der Konfiguration:\n")
pretty_print(1, konfig, {2})
puts(1, "\n\n")
