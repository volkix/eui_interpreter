-- =============================================================================
-- examples/oe4_features.ex
-- Testet die Features von Euphorix mit OpenEuphoria-Syntax:
--   1. Echte `include`-Direktive direkt aus eu_include/std/sort.e
--   2. `ifdef LINUX then ... end ifdef`
--   3. Default-Parameter & ausgelassene Argumente (`foo(10, , 30)`)
--   4. Forward-Referenzen (Aufruf einer Funktion vor ihrer Deklaration)
--   5. Benutzerdefinierte `type`-Prüfung zur Laufzeit
--   6. `routine_id()`, `call_func()` und `custom_sort()` aus `std/sort.e`
--   7. Bit-Operationen, `replace()`, `find_from()`, Datei-I/O (`open`/`puts`/`gets`/`close`)
-- =============================================================================

include std/sort.e as stdsort
include std/mathcons.e

puts(1, "=== Euphorix Feature-Test (OpenEuphoria-Syntax) ===\n\n")

-- 1. Bedingte Kompilierung (`ifdef`)
ifdef LINUX and BITS64 then
    puts(1, "1) ifdef-Test     : Läuft auf 64-Bit Linux (EU4)!\n")
elsedef
    puts(1, "1) ifdef-Test     : Andere Plattform\n")
end ifdef

-- 2. Benutzerdefinierter `type` (wird bei Zuweisung automatisch geprüft!)
type positive_int(integer x)
    return x > 0
end type

positive_int anzahl = 42
printf(1, "2) Custom Type    : positive_int anzahl = %d (PI aus std/mathcons.e = %.5f)\n",
       {anzahl, PI})

-- 3. Default-Parameter & ausgelassene Argumente + Forward-Call
function berechne(integer a, integer b = 10, integer c = 100)
    return vorwaerts_verdoppeln(a) + b + c
end function

function vorwaerts_verdoppeln(integer x)
    return x * 2
end function

printf(1, "3) Default & Fwd  : berechne(5) = %d, berechne(5, , 200) = %d\n",
       {berechne(5), berechne(5, , 200)})

-- 4. Standardbibliothek `std/sort.e` inkl. `routine_id()` und `call_func()`
sequence studenten = {
    {"Clara", 22},
    {"Anton", 19},
    {"Berta", 25},
    {"David", 18}
}

function vergleiche_alter(object a, object b)
    return compare(a[2], b[2])
end function

integer cmp_id = routine_id("vergleiche_alter")
sequence nach_alter = stdsort:custom_sort(cmp_id, studenten)

puts(1, "4) std/sort.e custom_sort(routine_id(\"vergleiche_alter\")):\n   ")
? nach_alter

-- 5. Bit-Operationen & `replace()`
sequence bits = and_bits({#FF, #0F, #AA}, #55)
sequence rep  = replace("Hallo Welt", "OpenEuphoria", 7, 10)
printf(1, "5) Bit-Ops & Replace: \"%s\", and_bits = {%d, %d, %d}\n",
       {rep, bits[1], bits[2], bits[3]})

-- 6. Datei-I/O (`open`, `puts`, `gets`, `close`)
constant TMP_FILE = "/tmp/eui_io_test.txt"
integer fn = open(TMP_FILE, "w")
puts(fn, "Zeile 1 aus eui\nZeile 2 aus eui\n")
close(fn)

fn = open(TMP_FILE, "r")
object line1 = gets(fn)
object line2 = gets(fn)
close(fn)
printf(1, "6) Datei-I/O Test : Gelesen -> %s", {line1})
