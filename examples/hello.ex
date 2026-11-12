-- =============================================================================
-- examples/hello.ex
-- Demonstriert die Stärken von OpenEuphoria 4.x auf unserer neuen Register-VM:
--   1. Automatische Vektor-/Sequenz-Arithmetik
--   2. Copy-on-Write (CoW) Wertsemantik & 1-basierte Indizierung mit `$`
--   3. Slicing & Slice-Ersetzung (`s[2..3] = ...`)
--   4. OpenEuphoria 4.x `enum`, `switch`, `loop ... until`, `function`/`procedure`
-- =============================================================================

puts(1, "=== OpenEuphoria 4.x Clean-Room VM Demo ===\n\n")

-- 1. Vektor-Arithmetik direkt auf beliebig verschachtelten Sequenzen
sequence a = {10, 20, 30, 40}
sequence b = {1, 2, 3, 4}
sequence sum_ab = a + b * 2

puts(1, "1) Sequenz-Arithmetik (a + b * 2):\n   ")
? sum_ab

-- 2. Copy-on-Write (CoW) Beweis:
--    `kopie = a` kopiert noch nichts (nur ref_count++).
--    Erst `kopie[2] = 999` triggert CoW, sodass `a` unverändert bleibt!
sequence kopie = a
kopie[2] = 999
kopie[$] = 777 -- `$` referenziert automatisch `length(kopie)`

printf(1, "2) Copy-on-Write Test:\n   Original a : {%d, %d, %d, %d}\n   Kopie      : {%d, %d, %d, %d}\n",
       {a[1], a[2], a[3], a[4], kopie[1], kopie[2], kopie[3], kopie[4]})

-- 3. Slicing und Slice-Zuweisung
sequence text = "Hallo Welt!"
text[7..10] = "Euphoria"
printf(1, "3) Slice-Mutation: \"%s\" (Länge: %d)\n", {text, length(text)})

-- 4. Funktionen, Rekursion & Typprüfung
function quicksort(sequence s)
    if length(s) <= 1 then
        return s
    end if
    object pivot = s[1]
    sequence kleiner = {}
    sequence groesser = {}
    for i = 2 to length(s) do
        if compare(s[i], pivot) < 0 then
            kleiner = append(kleiner, s[i])
        else
            groesser = append(groesser, s[i])
        end if
    end for
    return quicksort(kleiner) & {pivot} & quicksort(groesser)
end function

sequence unsortiert = {42, 7, 19, 3, 88, 12, 1, 55}
sequence sortiert = quicksort(unsortiert)
puts(1, "4) Quicksort Ergebnis:\n   ")
? sortiert

-- 5. OpenEuphoria 4.x `enum` und `switch`
enum STATUS_OK = 1, STATUS_WARN, STATUS_ERR

procedure pruefe_status(integer code)
    switch code do
        case STATUS_OK then
            puts(1, "5) Switch-Test: Status ist OK!\n")
        case STATUS_WARN then
            puts(1, "5) Switch-Test: Warnung!\n")
        case else
            puts(1, "5) Switch-Test: Fehler!\n")
    end switch
end procedure

pruefe_status(STATUS_OK)
