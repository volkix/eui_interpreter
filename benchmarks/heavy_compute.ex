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
atom t1 = time()

atom acc = 0
for k = 1 to 10000000 do
    acc += (k * 3) - 1
end for
atom t2 = time()

function fib(integer n)
    if n <= 1 then return n end if
    return fib(n - 1) + fib(n - 2)
end function
integer f32 = fib(32)
atom t3 = time()

printf(1, "BENCH sieve2M=%.4f loop10M=%.4f fib32=%.4f (primes=%d acc=%d fib=%d)\n",
       {t1 - t0, t2 - t1, t3 - t2, primes, acc, f32})
