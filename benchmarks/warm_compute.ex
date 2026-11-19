function run_sieve()
    atom t0 = time()
    integer LIMIT = 2000000
    sequence is_prime = repeat(1, LIMIT)
    is_prime[1] = 0
    integer i = 2
    while i * i <= LIMIT do
        if is_prime[i] then
            integer j = i * i
            while j <= LIMIT do
                is_prime[j] = 0
                j += i
            end while
        end if
        i += 1
    end while
    integer primes = 0
    for k = 1 to LIMIT do
        if is_prime[k] then
            primes += 1
        end if
    end for
    return {time() - t0, primes}
end function

function run_loop()
    atom t0 = time()
    atom acc = 0
    for k = 1 to 10000000 do
        acc += (k * 3) - 1
    end for
    return {time() - t0, acc}
end function

function fib(integer n)
    if n <= 1 then return n end if
    return fib(n - 1) + fib(n - 2)
end function

function run_fib()
    atom t0 = time()
    integer f32 = fib(32)
    return {time() - t0, f32}
end function

puts(1, "=== WARM-UP BENCHMARK (JVM C2 JIT / Go In-Process) ===\n")
for iter = 1 to 5 do
    sequence s = run_sieve()
    sequence l = run_loop()
    sequence f = run_fib()
    printf(1, "Pass #%d: sieve2M=%.4fs loop10M=%.4fs fib32=%.4fs (primes=%d, acc=%.0f, fib=%d)\n",
           {iter, s[1], l[1], f[1], s[2], l[2], f[2]})
end for
