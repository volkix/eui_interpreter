--****
-- == Bytecode Compilation & Standalone Execution Unit Tests (tests/t_bytecode.e)
--
-- Tests for Euphorix AOT Bytecode Compilation (.exb), Standalone Binary Binding (--bind),
-- and Startup Performance Benchmarks (--time).
--

include std/unittest.e
include std/filesys.e
include std/io.e

set_test_verbosity(TEST_SHOW_ALL)

-- 1. Create a sample Euphoria program to compile
sequence sample_src = 
`include std/math.e as math
function berechne(atom a, atom b)
    return sqrt(a * a + b * b)
end function
atom r = berechne(3.0, 4.0)
printf(1, "HYPOT_RESULT=%.2f\n", {r})
`

sequence tmp_ex  = "/tmp/t_sample_script.ex"
sequence tmp_exb = "/tmp/t_sample_script.exb"
sequence tmp_app = "/tmp/t_sample_app"
sequence tmp_out = "/tmp/t_sample_script.out"

procedure write_sample()
    integer fn_h = open(tmp_ex, "w")
    if fn_h > 0 then
        puts(fn_h, sample_src)
        close(fn_h)
    end if
end procedure

write_sample()
test_true("sample source file created", file_exists(tmp_ex))

-- 2. Test --compile (-b)
integer ec_compile = system_exec("./euphorix --compile " & tmp_ex & " -o " & tmp_exb, 2)
test_equal("compile command succeeds with exit code 0", ec_compile, 0)
test_true("compiled bytecode file (.exb) exists", file_exists(tmp_exb))

-- 3. Verify EXB magic header ("EXB1")
integer fh = open(tmp_exb, "rb")
test_true("bytecode file can be opened for reading", fh > 0)
if fh > 0 then
    sequence magic = {getc(fh), getc(fh), getc(fh), getc(fh)}
    close(fh)
    test_equal("bytecode file starts with magic EXB1", magic, {'E', 'X', 'B', '1'})
end if

-- 4. Test running the bytecode directly: euphorix datei.exb
integer ec_run = system_exec("./euphorix " & tmp_exb & " > " & tmp_out, 2)
test_equal("bytecode execution succeeds with exit code 0", ec_run, 0)
object out_bytes = read_file(tmp_out)
test_true("output file is non-empty", sequence(out_bytes) and length(out_bytes) > 0)
if sequence(out_bytes) then
    test_true("output contains expected calculation result", match("HYPOT_RESULT=5.00", out_bytes) > 0)
end if

-- 5. Test --bind to create self-executing bound executable
integer ec_bind = system_exec("./euphorix --bind " & tmp_ex & " -o " & tmp_app, 2)
test_equal("bind command succeeds with exit code 0", ec_bind, 0)
test_true("bound executable exists", file_exists(tmp_app))

-- 6. Test running bound executable
integer ec_bound_run = system_exec(tmp_app & " > " & tmp_out, 2)
test_equal("bound executable execution succeeds with exit code 0", ec_bound_run, 0)
object bound_out = read_file(tmp_out)
if sequence(bound_out) then
    test_true("bound executable output contains expected result", match("HYPOT_RESULT=5.00", bound_out) > 0)
end if

-- 7. Test --time benchmark flag on both source and bytecode
integer ec_time_ex  = system_exec("./euphorix --time " & tmp_ex & " > /dev/null", 2)
integer ec_time_exb = system_exec("./euphorix --time " & tmp_exb & " > /dev/null", 2)
test_equal("--time on source code succeeds", ec_time_ex, 0)
test_equal("--time on bytecode succeeds", ec_time_exb, 0)

-- 8. Test dedicated runtime.jar execution
integer ec_rt_jar = system_exec("java -jar runtime.jar " & tmp_exb & " > " & tmp_out, 2)
test_equal("runtime.jar execution succeeds with exit code 0", ec_rt_jar, 0)
object rt_out = read_file(tmp_out)
if sequence(rt_out) then
    test_true("runtime.jar output contains expected result", match("HYPOT_RESULT=5.00", rt_out) > 0)
end if

-- 9. Test ./euphorix-rt launcher script
integer ec_rt_bin = system_exec("./euphorix-rt " & tmp_exb & " > " & tmp_out, 2)
test_equal("euphorix-rt launcher succeeds with exit code 0", ec_rt_bin, 0)
object rt_bin_out = read_file(tmp_out)
if sequence(rt_bin_out) then
    test_true("euphorix-rt output contains expected result", match("HYPOT_RESULT=5.00", rt_bin_out) > 0)
end if

-- 10. Test that runtime.jar rejects uncompiled .ex source files
integer ec_rt_reject = system_exec("java -jar runtime.jar " & tmp_ex & " > /dev/null 2>&1", 2)
test_not_equal("runtime.jar rejects .ex source file (non-zero exit code)", ec_rt_reject, 0)

-- 11. Verify runtime.jar is stripped of Compiler and source includes
integer ec_has_compiler = system_exec("unzip -l runtime.jar 'eu/Compiler*' > /dev/null 2>&1", 2)
integer ec_has_include  = system_exec("unzip -l runtime.jar 'eu_include/*' > /dev/null 2>&1", 2)
test_not_equal("runtime.jar does not contain eu/Compiler*.class", ec_has_compiler, 0)
test_not_equal("runtime.jar does not contain eu_include/* source files", ec_has_include, 0)

-- Cleanup temporary files
delete_file(tmp_ex)
delete_file(tmp_exb)
delete_file(tmp_app)
delete_file(tmp_out)

test_report()
