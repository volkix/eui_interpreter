-- =============================================================================
-- Euphorix Tutorial - Kapitel 1: Sequenzen, Algorithmen & Collections
-- Behandelte Module: std/sequence.e, std/map.e, std/stack.e, std/sort.e,
--                    std/search.e, std/serialize.e
-- Ausführen mit: ./euphorix tutorial/01_datenstrukturen.ex
-- =============================================================================

include std/sequence.e
include std/map.e
include std/stack.e
include std/sort.e
include std/search.e
include std/serialize.e

puts(1, "=====================================================================\n")
puts(1, "  KAPITEL 1: Sequenzen, Maps & Collections\n")
puts(1, "=====================================================================\n\n")

-- -----------------------------------------------------------------------------
-- 1. std/sequence.e - Das Herzstück von OpenEuphoria
-- Sequenzen sind 1-basierte, dynamisch wachsende Listen beliebiger Datentypen.
-- -----------------------------------------------------------------------------
puts(1, "--- 1. std/sequence.e ---\n")
sequence fruechte = {"Apfel", "Banane", "Kirsche", "Dattel", "Erdbeere"}

-- 1-basiertes Slicing: Erstes bis vorletztes Element
sequence teil = fruechte[2..$-1] -- {"Banane", "Kirsche", "Dattel"}
printf(1, "Slicing [2..$-1]: %s\n", {join(teil, ", ")})

-- Umkehren mit reverse()
sequence umgekehrt = reverse(fruechte)
printf(1, "Umgekehrt: %s\n", {join(umgekehrt, ", ")})

-- Entfernen und Hinzufügen
sequence ohne_banane = remove_item("Banane", fruechte)
printf(1, "Ohne Banane: %s\n", {join(ohne_banane, ", ")})

-- Mehrdimensionale Spaltenextraktion (vslice)
sequence tabelle = {
    {101, "Monitor", 249.99},
    {102, "Tastatur", 79.50},
    {103, "Maus", 39.90}
}
sequence artikel_namen = vslice(tabelle, 2)
printf(1, "Spalte 2 (Artikel): %s\n\n", {join(artikel_namen, ", ")})


-- -----------------------------------------------------------------------------
-- 2. std/map.e - Assoziative Hash-Maps (Key-Value)
-- Schneller wahlfreier Zugriff über Schlüssel beliebigen Typs.
-- -----------------------------------------------------------------------------
puts(1, "--- 2. std/map.e ---\n")
map:map laender = map:new()
map:put(laender, "DE", "Deutschland")
map:put(laender, "AT", "Österreich")
map:put(laender, "CH", "Schweiz")

printf(1, "Hauptland DE: %s\n", {map:get(laender, "DE")})
printf(1, "Hauptland CH: %s\n", {map:get(laender, "CH")})
printf(1, "Anzahl Länder in Map: %d\n\n", {map:size(laender)})


-- -----------------------------------------------------------------------------
-- 3. std/stack.e - LIFO-Stapel (Last-In-First-Out)
-- Perfekt für Undo-Verläufe, Parser und Callstacks.
-- -----------------------------------------------------------------------------
puts(1, "--- 3. std/stack.e ---\n")
stack:stack st = stack:new()
stack:push(st, "Startseite")
stack:push(st, "Katalog")
stack:push(st, "Warenkorb")

printf(1, "Aktuell oben auf Stack: %s\n", {stack:top(st)})
printf(1, "Zurückspringen (Pop): %s\n", {stack:pop(st)})
printf(1, "Nun oben: %s\n\n", {stack:top(st)})


-- -----------------------------------------------------------------------------
-- 4. std/sort.e - Sortieralgorithmen
-- Universelles Sortieren von Zahlen, Strings oder komplexen Datensätzen.
-- -----------------------------------------------------------------------------
puts(1, "--- 4. std/sort.e ---\n")
sequence zahlen = {42, 17, 99, 3, 28, 55}
sequence sortierte_zahlen = sort(zahlen)
printf(1, "Unsortiert: %s\n", {sprint(zahlen)})
printf(1, "Sortiert:   %s\n\n", {sprint(sortierte_zahlen)})


-- -----------------------------------------------------------------------------
-- 5. std/search.e - Fortgeschrittene Suchoperationen
-- Schnelle binäre Suche in sortierten Daten und Mehrfachfunde.
-- -----------------------------------------------------------------------------
puts(1, "--- 5. std/search.e ---\n")
sequence sortierte_liste = {10, 20, 30, 40, 50, 60, 70, 80}
integer ziel = 50
integer gefundener_index = binary_search(ziel, sortierte_liste)
printf(1, "Wert %d gefunden an Position: %d\n\n", {ziel, gefundener_index})


-- -----------------------------------------------------------------------------
-- 6. std/serialize.e - Binäre Serialisierung
-- Beliebige Euphoria-Objekte verlustfrei in Bytefolgen packen und entpacken.
-- -----------------------------------------------------------------------------
puts(1, "--- 6. std/serialize.e ---\n")
sequence datenpaket = {"Benutzerdaten", 42, {199.99, "EUR", {"Rechte", 1, 1, 0}}}
sequence bytes = serialize(datenpaket)
sequence res = deserialize(bytes)
object wiederhergestellt = res[1]

printf(1, "Originalgröße Struktur:  %d Elemente\n", {length(datenpaket)})
printf(1, "Serialisierte Bytegröße: %d Bytes\n", {length(bytes)})
printf(1, "Wiederherstellung identisch: %d (1 = Ja)\n", {equal(datenpaket, wiederhergestellt)})
