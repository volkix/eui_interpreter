-- =============================================================================
-- examples/sieve.ex
-- Benchmark: Sieb des Eratosthenes + In-Place Copy-on-Write Sequenz-Mutation
-- =============================================================================

constant LIMIT = 500_000

atom t0 = time()

-- Erstellt eine Sequenz mit 500.000 Einsen in einem einzigen Aufruf
sequence is_prime = repeat(1, LIMIT)
is_prime[1] = 0

integer p = 2
while p * p <= LIMIT do
    if is_prime[p] = 1 then
        for multiple = p * p to LIMIT by p do
            -- Da `is_prime` ref_count == 1 hat, mutiert unsere VM dies
            -- 100% in-place ohne eine einzige Heap-Allokation!
            is_prime[multiple] = 0
        end for
    end if
    p += 1
end while

integer count = 0
for i = 2 to LIMIT do
    if is_prime[i] = 1 then
        count += 1
    end if
end for

atom elapsed = time() - t0
printf(1, "Sieb des Eratosthenes bis %d:\n", LIMIT)
printf(1, "  Gefundene Primzahlen : %d\n", count)
printf(1, "  Laufzeit             : %.4f Sekunden\n", elapsed)
