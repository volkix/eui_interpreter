--****
-- == Language Server Protocol (LSP) Unit Tests (tests/t_lsp.e)
--
-- Tests for Euphorix LSP Server (--lsp): JSON-RPC 2.0 communication,
-- live diagnostics (syntax checking), auto-completion, hover help,
-- signature help, formatting, and standard library indexing.
--

include std/unittest.e
include std/pipeio.e as pipeio
include std/filesys.e
include std/search.e
include std/os.e
include std/convert.e

set_test_verbosity(TEST_SHOW_ALL)

function make_lsp_msg(sequence payload)
    return sprintf("Content-Length: %d\r\n\r\n%s", {length(payload), payload})
end function

-- Test helper
test_equal("make_lsp_msg contains Content-Length", 1, match("Content-Length:", make_lsp_msg("{\"jsonrpc\":\"2.0\"}")) > 0)

function read_lsp_msg(atom pout, integer max_tries = 50)
    sequence buf = ""
    integer content_len = -1
    for t = 1 to max_tries do
        sequence chunk = pipeio:read(pout, 4096)
        if length(chunk) > 0 then
            buf &= chunk
            if content_len = -1 then
                integer hdr_end = match("\r\n\r\n", buf)
                if hdr_end > 0 then
                    sequence hdr = buf[1..hdr_end-1]
                    integer cl_pos = match("Content-Length:", hdr)
                    if cl_pos > 0 then
                        sequence len_str = hdr[cl_pos + 15..$]
                        content_len = to_integer(len_str)
                    end if
                end if
            end if
            if content_len >= 0 then
                integer hdr_end = match("\r\n\r\n", buf)
                if length(buf) >= hdr_end + 3 + content_len then
                    exit
                end if
            end if
        end if
        sleep(0.05)
    end for
    return buf
end function

-- 2. Spawning LSP Server
object proc = pipeio:exec("./euphorix --lsp")
test_equal("LSP server process spawned successfully", 1, sequence(proc) and length(proc) >= 4)

if sequence(proc) and length(proc) >= 4 then
    atom pin = proc[pipeio:STDIN]
    atom pout = proc[pipeio:STDOUT]

    -- A. Send initialize request
    sequence init_req = make_lsp_msg("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"capabilities\":{}}}")
    pipeio:write(pin, init_req)
    sequence resp = read_lsp_msg(pout)

    test_equal("LSP initialize response contains euphorix-lsp", 1, match("euphorix-lsp", resp) > 0)
    test_equal("LSP initialize response contains completionProvider", 1, match("completionProvider", resp) > 0)
    test_equal("LSP initialize response contains signatureHelpProvider", 1, match("signatureHelpProvider", resp) > 0)

    -- B. Test didOpen with deliberate syntax error
    sequence bad_code = "procedure bad()\n    puts(1, \"unclosed)\nend procedure\n"
    sequence open_req = make_lsp_msg(sprintf("{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"file:///tmp/test_lsp_error.ex\",\"languageId\":\"euphoria\",\"version\":1,\"text\":\"%s\"}}}", {
        "procedure bad()\\n    puts(1, \\\"unclosed)\\nend procedure\\n"
    }))
    pipeio:write(pin, open_req)
    sequence diag_resp = read_lsp_msg(pout)

    test_equal("LSP diagnostics triggered on syntax error", 1, match("publishDiagnostics", diag_resp) > 0)

    -- C. Test completion for keywords and builtins
    sequence comp_req = make_lsp_msg("{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"textDocument/completion\",\"params\":{\"textDocument\":{\"uri\":\"file:///tmp/test_lsp_error.ex\"},\"position\":{\"line\":0,\"character\":0}}}")
    pipeio:write(pin, comp_req)
    sequence comp_resp = read_lsp_msg(pout)

    test_equal("LSP completion response contains suggestions", 1, match("\"label\"", comp_resp) > 0)
    test_equal("LSP completion includes mcp_server template", 1, match("mcp_server", comp_resp) > 0)

    -- D. Test hover on 'procedure'
    sequence hover_req = make_lsp_msg("{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"textDocument/hover\",\"params\":{\"textDocument\":{\"uri\":\"file:///tmp/test_lsp_error.ex\"},\"position\":{\"line\":0,\"character\":5}}}")
    pipeio:write(pin, hover_req)
    sequence hover_resp = read_lsp_msg(pout)

    test_equal("LSP hover response returned", 1, match("\"id\":3", hover_resp) > 0 and match("procedure", hover_resp) > 0)

    -- E. Test didOpen on clean file with std/io.e and std/vsui.e includes
    sequence clean_code = "include std/io.e\\ninclude std/vsui.e as vsui\\nprocedure main()\\n    puts(1, \\\"OK\\\\n\\\")\\nend procedure\\n"
    sequence clean_open_req = make_lsp_msg(sprintf("{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"file:///home/volkix/prj/intpret/demo/test_clean.ex\",\"languageId\":\"euphoria\",\"version\":1,\"text\":\"%s\"}}}", {
        clean_code
    }))
    pipeio:write(pin, clean_open_req)
    sequence clean_diag_resp = read_lsp_msg(pout)

    test_equal("LSP clean file produces zero diagnostic errors", 1, match("\"diagnostics\":[]", clean_diag_resp) > 0)

    -- F. Test didChange with vsui: prefix and completion
    sequence changed_code = "include std/io.e\\ninclude std/vsui.e as vsui\\nvsui:\\n"
    sequence change_req = make_lsp_msg(sprintf("{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didChange\",\"params\":{\"textDocument\":{\"uri\":\"file:///home/volkix/prj/intpret/demo/test_clean.ex\",\"version\":2},\"contentChanges\":[{\"text\":\"%s\"}]}}", {
        changed_code
    }))
    pipeio:write(pin, change_req)
    -- read diagnostics emitted on change
    sequence change_diag = read_lsp_msg(pout)

    sequence vsui_comp_req = make_lsp_msg("{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"textDocument/completion\",\"params\":{\"textDocument\":{\"uri\":\"file:///home/volkix/prj/intpret/demo/test_clean.ex\"},\"position\":{\"line\":2,\"character\":5},\"context\":{\"triggerCharacter\":\":\"}}}")
    pipeio:write(pin, vsui_comp_req)
    sequence vsui_comp_resp = read_lsp_msg(pout)

    test_equal("LSP vsui: completion contains numinput", 1, match("numinput", vsui_comp_resp) > 0)

    -- G. Test document formatting
    sequence fmt_req = make_lsp_msg("{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"textDocument/formatting\",\"params\":{\"textDocument\":{\"uri\":\"file:///home/volkix/prj/intpret/demo/test_clean.ex\"},\"options\":{\"tabSize\":4,\"insertSpaces\":true}}}")
    pipeio:write(pin, fmt_req)
    sequence fmt_resp = read_lsp_msg(pout)

    test_equal("LSP formatting returns textEdit", 1, match("newText", fmt_resp) > 0 and match("\"id\":5", fmt_resp) > 0)

    -- Clean shutdown
    pipeio:close(pin)
    pipeio:close(pout)
    pipeio:kill(proc)
end if

test_report()
