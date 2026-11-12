-- Euphorix Comprehensive Standard Library & Feature Test Suite (OpenEuphoria Syntax)
include std/sequence.e
include std/sort.e
include std/math.e
include std/types.e
include std/text.e
include std/search.e
include std/convert.e
include std/dll.e
include std/os.e
include std/filesys.e
include std/datetime.e as dt
include std/regex.e as re
include std/map.e as map
include std/base64.e as b64
include std/wildcard.e as wc
include std/socket.e as sock
include std/net/dns.e as dns
include euphoria/info.e as info

procedure assert_eq(sequence msg, object actual, object expected)
    if not equal(actual, expected) then
        puts(1, "FAIL: " & msg & "\n  actual:   ")
        ? actual
        puts(1, "  expected: ")
        ? expected
        abort(1)
    end if
    puts(1, "[OK] " & msg & "\n")
end procedure

puts(1, "=== Euphorix Complete Feature & Stdlib Test (OpenEuphoria Syntax) ===\n")

-- 1. Complex default parameter expressions (referencing earlier parameters & functions)
function slice_with_default(sequence s, integer start_idx = 1, integer stop_idx = length(s) - 1)
    return s[start_idx .. stop_idx]
end function

assert_eq("complex default params", slice_with_default({10, 20, 30, 40}), {10, 20, 30})
assert_eq("complex default params override", slice_with_default({10, 20, 30, 40}, 2), {20, 30})

-- 2. Short-circuit evaluation in if/while with sequences
sequence sc_seq = "hello"
integer sc_ok = 0
if atom(sc_seq) and sc_seq > 0 then
    sc_ok = -1
elsif sequence(sc_seq) and length(sc_seq) = 5 then
    sc_ok = 1
end if
assert_eq("short-circuit and/or with sequences", sc_ok, 1)

-- 3. while <cond> with entry do
integer we_sum = 0
integer we_i = 0
while we_i < 4 with entry do
    we_sum += we_i
entry
    we_i += 1
end while
assert_eq("while <cond> with entry do", we_sum, 1 + 2 + 3)

-- 4. delete_routine() and delete()
sequence deleted_log = {}
procedure on_cleanup(object x)
    deleted_log = append(deleted_log, length(x))
end procedure

object tracked = delete_routine({100, 200, 300}, routine_id("on_cleanup"))
delete(tracked)
assert_eq("delete_routine and delete()", deleted_log, {3})

-- 5. C-FFI (std/dll.e, open_dll, define_c_func, c_func, sizeof)
assert_eq("sizeof(C_POINTER)", sizeof(C_POINTER), 8)
atom libc = open_dll("")
integer c_strlen = define_c_func(libc, "strlen", {C_POINTER}, C_LONG)
atom str_ptr = allocate_string("OpenEuphoria C-FFI!")
assert_eq("c_func strlen via dlopen/dlsym", c_func(c_strlen, {str_ptr}), 19)
free(str_ptr)

-- 6. euphoria/info.e & std/os.e
assert_eq("info:version_major", info:version_major(), 4)
assert_eq("os:instance() > 0", instance() > 0, 1)
sequence u = uname()
assert_eq("os:uname() Linux", u[1], "Linux")
assert_eq("os:setenv / getenv", setenv("EU_TEST_VAR", "42", 1), 1)
assert_eq("getenv(EU_TEST_VAR)", getenv("EU_TEST_VAR"), "42")
assert_eq("os:unsetenv", unsetenv("EU_TEST_VAR"), 1)

-- 7. std/filesys.e
sequence cur = current_dir()
assert_eq("filesys:current_dir non-empty", length(cur) > 0, 1)
object d = dir("examples")
assert_eq("filesys:dir(examples) is sequence", sequence(d) and length(d) >= 3, 1)
assert_eq("filesys:file_exists(Makefile)", file_exists("Makefile"), 1)
assert_eq("filesys:filename", filename("/path/to/archive.tar.gz"), "archive.tar.gz")
assert_eq("filesys:fileext", fileext("/path/to/archive.tar.gz"), "gz")

-- 8. std/datetime.e
dt:datetime d1 = dt:new(2026, 11, 6, 12, 30, 0)
assert_eq("datetime:format", dt:format(d1, "%Y-%m-%d %H:%M"), "2026-11-06 12:30")
dt:datetime d2 = dt:add(d1, 5, dt:DAYS)
assert_eq("datetime:add 5 days", dt:format(d2, "%Y-%m-%d"), "2026-11-11")

-- 9. std/regex.e
re:regex pat = re:new(`([a-z]+)=([0-9]+)`)
assert_eq("regex:is_match", re:is_match(pat, "foo=123"), 1)
object all_matches = re:find_all(pat, "a=10, b=25, c=99")
assert_eq("regex:find_all count", length(all_matches), 3)
object replaced = re:find_replace(pat, "x=42", `\2:\1`)
assert_eq("regex:find_replace backrefs", replaced, "42:x")

-- 10. std/map.e
map:map m = map:new()
map:put(m, "alpha", 100)
map:put(m, "beta", 200)
assert_eq("map:has(alpha)", map:has(m, "alpha"), 1)
assert_eq("map:get(beta)", map:get(m, "beta", -1), 200)

-- 11. std/sequence.e, std/sort.e, std/text.e, std/math.e, std/convert.e
assert_eq("sort", sort({9, 3, 7, 1, 5}), {1, 3, 5, 7, 9})
assert_eq("upper/lower/trim", trim(upper("  euphoria 4.1  ")), "EUPHORIA 4.1")
assert_eq("stdseq:split & join", stdseq:join(stdseq:split("a,b,c", ','), "-"), "a-b-c")
assert_eq("re:split", re:split(re:new(`,\s*`), "one, two, three"), {"one", "two", "three"})
assert_eq("int_to_bytes & bytes_to_int", bytes_to_int(int_to_bytes(12345678)), 12345678)
assert_eq("math:gcd & sum", {gcd(48, 18), sum({1, 2, 3, 4, 5})}, {6, 15})
assert_eq("base64:encode/decode", b64:decode(b64:encode("OpenEuphoria 4.1")), "OpenEuphoria 4.1")
assert_eq("wildcard:is_match", wc:is_match("*.ex", "stdlib_full_test.ex"), 1)
assert_eq("socket:AF_INET & SOCK_STREAM", {sock:AF_INET, sock:SOCK_STREAM}, {2, 1})

-- 12. Modernized Socket Engine (IPv4/IPv6 Dual-Stack, poll-backed select, TCP & DNS)
object host_info = dns:host_by_name("localhost")
assert_eq("dns:host_by_name(localhost)", sequence(host_info) and length(host_info[3]) >= 1, 1)

sock:socket srv = sock:create(sock:AF_INET, sock:SOCK_STREAM, 0)
sock:set_option(srv, sock:SOL_SOCKET, sock:SO_REUSEADDR, 1)
assert_eq("socket:bind 127.0.0.1:49188", sock:bind(srv, "127.0.0.1", 49188), sock:OK)
assert_eq("socket:listen", sock:listen(srv, 4), sock:OK)

sock:socket cli = sock:create(sock:AF_INET, sock:SOCK_STREAM, 0)
assert_eq("socket:connect localhost:49188", sock:connect(cli, "localhost", 49188), sock:OK)

sequence sel = sock:select({srv}, {cli}, {}, 0, 50000)
assert_eq("socket:select via poll()", length(sel), 2)

object acc = sock:accept(srv)
assert_eq("socket:accept client ip", acc[2], "127.0.0.1")
sock:socket peer = acc[1]

assert_eq("socket:send", sock:send(cli, "Ping over TCP!"), 14)
assert_eq("socket:receive", sock:receive(peer), "Ping over TCP!")

sock:close(peer)
sock:close(cli)
sock:close(srv)

-- IPv6 Dual-Stack UDP test (`::1`)
sock:socket udp6 = sock:create(sock:AF_INET6, sock:SOCK_DGRAM, 0)
if sock:bind(udp6, "::1", 49189) = sock:OK then
    assert_eq("socket:IPv6 UDP send_to ::1", sock:send_to(udp6, "IPv6-OK", "::1", 49189), 7)
    object pkt6 = sock:receive_from(udp6)
    assert_eq("socket:IPv6 UDP receive_from ::1", {pkt6[1], pkt6[3]}, {"::1", "IPv6-OK"})
end if
sock:close(udp6)

puts(1, "=== ALL STDLIB & LANGUAGE TESTS PASSED ===\n")
