-- =============================================================================
-- Beispiel 01: UTF-8 Textverarbeitung in Euphoria (std/utf8.e)
-- Aufruf: ./eui examples/01_utf8_textverarbeitung.ex
-- =============================================================================
include std/utf8.e
include std/text.e

procedure assert_eq(sequence name, object actual, object expected)
    if not equal(actual, expected) then
        printf(2, "FEHLER in %s!\n  Erwartet: %s\n  Erhalten: %s\n", {name, sprint(expected), sprint(actual)})
        abort(1)
    end if
end procedure

puts(1, "=== Beispiel 01: UTF-8 Textverarbeitung (std/utf8.e) ===\n")

-- 1. Unterschied zwischen Byte-Länge length() und Zeichen-Länge utf8:len()
sequence text = "München: Größe 42 € – Café"
integer byte_len = length(text)
integer char_len = utf8:len(text)

printf(1, "  Text        : %s\n", {text})
printf(1, "  Byte-Länge  : %d Bytes (length)\n", {byte_len})
printf(1, "  Zeichen     : %d Unicode-Codepoints (utf8:len)\n", {char_len})

assert_eq("utf8:valid", utf8:valid(text), 1)
assert_eq("Byte-Länge > Zeichen-Länge", byte_len > char_len, 1)
assert_eq("Zeichenanzahl", char_len, 26)

-- 2. Einzelne UTF-8-Zeichen per Index abrufen (1-basiert)
assert_eq("2. Zeichen ('ü')",  utf8:char_at(text, 2),  "ü")
assert_eq("12. Zeichen ('ö')", utf8:char_at(text, 12), "ö")
assert_eq("19. Zeichen ('€')", utf8:char_at(text, 19), "€")
assert_eq("26. Zeichen ('é')", utf8:char_at(text, 26), "é")

-- 3. Zeichengenaues Slicing ohne Zerstörung von Multi-Byte-Sequenzen
assert_eq("utf8:slice(1, 7)",   utf8:slice(text, 1, 7),   "München")
assert_eq("utf8:slice(10, 14)", utf8:slice(text, 10, 14), "Größe")
assert_eq("utf8:slice(23, 26)", utf8:slice(text, 23, 26), "Café")

-- 4. Zeichenposition suchen mit utf8:find()
assert_eq("utf8:find('Größe')", utf8:find("Größe", text), 10)
assert_eq("utf8:find('€')",     utf8:find("€", text),     19)
assert_eq("utf8:find('Café')",  utf8:find("Café", text),  23)

-- 5. Unicode-Groß-/Kleinschreibung (inkl. Umlaute & Akzente)
sequence klein = "äöü éèê München"
sequence gross = utf8:upper(klein)
printf(1, "  utf8:upper  : '%s' -> '%s'\n", {klein, gross})
assert_eq("utf8:upper", gross, "ÄÖÜ ÉÈÊ MÜNCHEN")
assert_eq("utf8:lower", utf8:lower(gross), "äöü éèê münchen")

-- 6. Umwandlung in UTF-32 Codepoints (1 Integer pro Zeichen) und zurück
sequence cps = utf8:to_codepoints("Größe €")
-- 'G'=71, 'r'=114, 'ö'=246, 'ß'=223, 'e'=101, ' '=32, '€'=8364
assert_eq("Codepoint-Sequenz", cps, {71, 114, 246, 223, 101, 32, 8364})
assert_eq("utf8:from_codepoints", utf8:from_codepoints(cps), "Größe €")

-- 7. UTF-8 Dateien schreiben und lesen (inkl. automatischer UTF-8-BOM-Erkennung)
sequence tmp_path = "/tmp/eui_utf8_test.txt"
sequence datei_inhalt = "Zeile 1: ÄÖÜß\r\nZeile 2: Preis 99 € 🚀\n"
-- Schreibe mit UTF-8 BOM (add_bom = 1), wie es z.B. Windows-Programme oft tun
assert_eq("utf8:write_file mit BOM", utf8:write_file(tmp_path, datei_inhalt, 1), 1)

-- utf8:read_file entfernt das BOM standardmäßig automatisch:
assert_eq("utf8:read_file ohne BOM", utf8:read_file(tmp_path), datei_inhalt)

-- utf8:read_lines liefert die Zeilen ohne BOM und ohne \r\n:
assert_eq("utf8:read_lines", utf8:read_lines(tmp_path), {
    "Zeile 1: ÄÖÜß",
    "Zeile 2: Preis 99 € 🚀"
})

-- Zeichenweises Lesen mit utf8:getc_utf8(fn) (liest jeweils 1 bis 4 Bytes als ganzes UTF-8-Zeichen):
assert_eq("utf8:write_file kurz", utf8:write_file(tmp_path, "Aä€🚀", 0), 1)
integer fn = open(tmp_path, "rb")
assert_eq("getc_utf8 #1", utf8:getc_utf8(fn), "A")
assert_eq("getc_utf8 #2", utf8:getc_utf8(fn), "ä")
assert_eq("getc_utf8 #3", utf8:getc_utf8(fn), "€")
assert_eq("getc_utf8 #4", utf8:getc_utf8(fn), "🚀")
assert_eq("getc_utf8 EOF", utf8:getc_utf8(fn), -1)
close(fn)

puts(1, "  [OK] Alle UTF-8 String- und Datei-Operationen erfolgreich getestet!\n")
