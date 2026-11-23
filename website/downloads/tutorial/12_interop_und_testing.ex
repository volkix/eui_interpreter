-- =============================================================================
-- Euphorix Tutorial - Kapitel 12: Interop, Java, Testing, Crypto & Speicher
-- Behandelte Module: std/unittest.e, std/java.e, std/convert.e, std/base64.e,
--                    std/hash.e, std/types.e, std/flags.e, std/utils.e,
--                    std/machine.e, std/memory.e
-- Ausführen mit: ./euphorix tutorial/12_interop_und_testing.ex
-- =============================================================================

include std/java.e as java
include std/convert.e
include std/base64.e
include std/hash.e
include std/types.e
include std/flags.e
include std/utils.e
include std/machine.e
include std/memory.e
include std/unittest.e

puts(1, "=====================================================================\n")
puts(1, "  KAPITEL 12: Java-Interop, Hashes, Typen, Speicher & Testing\n")
puts(1, "=====================================================================\n\n")

-- -----------------------------------------------------------------------------
-- 1. std/java.e - Nahtlose Java-Interoperabilität & JDK 25 Zugriff
-- Beliebige Java-Klassen instanziieren und statische/dynamische Methoden aufrufen.
-- -----------------------------------------------------------------------------
puts(1, "--- 1. std/java.e ---\n")
object java_version = java:call_static("java.lang.System", "getProperty", {"java.version"})
object os_name = java:call_static("java.lang.System", "getProperty", {"os.name"})
printf(1, "Unterliegende Java-Laufzeit: %s (%s)\n\n", {java_version, os_name})


-- -----------------------------------------------------------------------------
-- 2. std/convert.e - Datentyp- & Zahlensystem-Konvertierungen
-- Hexadezimal-Parsing, Zahlenformatierung und Konvertierungen.
-- -----------------------------------------------------------------------------
puts(1, "--- 2. std/convert.e ---\n")
atom hex_val = hex_text("DEADBEEF")
printf(1, "Hex 'DEADBEEF' als Integer:  %.0f\n", {hex_val})
printf(1, "Zahl formatiert (to_string): %s\n\n", {to_string(12345.67)})


-- -----------------------------------------------------------------------------
-- 3. std/base64.e - Standard Base64 Kodierung & Dekodierung
-- Übertragung von Binärdaten in JSON, E-Mail und HTTP-Headern.
-- -----------------------------------------------------------------------------
puts(1, "--- 3. std/base64.e ---\n")
sequence geheimtext = "Euphorix: Schnelle virtuelle Maschine!"
sequence b64 = encode(geheimtext)
printf(1, "Original:  '%s'\n", {geheimtext})
printf(1, "Base64:    %s\n", {b64})
printf(1, "Dekodiert: '%s'\n\n", {decode(b64)})


-- -----------------------------------------------------------------------------
-- 4. std/hash.e - Hashing-Algorithmen
-- MD5, Adler32, Fletcher32 und Prüfsummen.
-- -----------------------------------------------------------------------------
puts(1, "--- 4. std/hash.e ---\n")
atom hash_val = hash("BenutzerPasswort2026", stdhash:MD5)
printf(1, "Berechneter MD5 Hashwert: %d\n\n", {hash_val})


-- -----------------------------------------------------------------------------
-- 5. std/types.e, std/flags.e & std/utils.e - Typprüfung & Bitmasken
-- Strikte Validierungen und Inline-Bedingungen.
-- -----------------------------------------------------------------------------
puts(1, "--- 5. std/types.e, std/flags.e & std/utils.e ---\n")
printf(1, "Ist 'A' ein Buchstabe? %d (1 = Ja)\n", {t_alpha("A")})
printf(1, "Ist '9' ein Buchstabe? %d (0 = Nein)\n", {t_alpha("9")})
printf(1, "Ternärer Operator iff(10 > 5): %d\n", {iff(10 > 5, 42, 99)})

atom maske = 0
maske = or_bits(maske, 8) -- Bit 4 setzen
printf(1, "Bit 4 aktiv:           %d\n\n", {and_bits(maske, 8) != 0})


-- -----------------------------------------------------------------------------
-- 6. std/machine.e & std/memory.e - Maschinenspeicher & Raw Pointers
-- Low-Level Pointers, Speicherallokationen (allocate/free) und Peek/Poke.
-- -----------------------------------------------------------------------------
puts(1, "--- 6. std/machine.e & std/memory.e ---\n")
atom speicher_ptr = allocate(16)
poke(speicher_ptr, 123)
printf(1, "Speicher-Adresse:      #%08x\n", {speicher_ptr})
printf(1, "Gelesener Wert (peek): %d\n", {peek(speicher_ptr)})
free(speicher_ptr)
puts(1, "Speicherblock sauber freigegeben.\n\n")


-- -----------------------------------------------------------------------------
-- 7. std/unittest.e - Integriertes Unit-Testing Framework
-- Testfälle deklarieren und strukturierte Testberichte erzeugen.
-- -----------------------------------------------------------------------------
puts(1, "--- 7. std/unittest.e ---\n")
set_test_verbosity(TEST_SHOW_ALL)
test_equal("Mathematische Addition", 5 + 5, 10)
test_true("Größer-Vergleich", 100 > 50)
test_false("Gleichheitsprüfung", equal("Alpha", "Beta"))
test_report()
