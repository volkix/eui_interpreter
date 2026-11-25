--****
-- == Model Context Protocol (MCP) Standard Library for Euphorix (std/mcp.e)
--
-- Implements the Model Context Protocol (MCP) Specification (v2024-11-05).
-- Provides fully native MCP Server and MCP Client capabilities for OpenEuphoria / Euphorix:
--
-- * **MCP Server**:
--   - Transports: Standard-I/O (`stdio`) for Desktop AI (Claude Desktop, Antigravity, Cursor)
--     and HTTP + Server-Sent Events (`sse`) for web & distributed agents.
--   - Primitives: Tools (`tools/list`, `tools/call`), Resources (`resources/list`, `resources/read`),
--     Prompts (`prompts/list`, `prompts/get`), and JSON-RPC 2.0 lifecycle (`initialize`, `ping`).
--
-- * **MCP Client**:
--   - Transports: Subprocess execution via `std/pipeio.e` (`stdio`) and Remote HTTP (`http`).
--   - Primitives: Handshake (`client_init`), Tool discovery & execution (`client_list_tools`,
--     `client_call_tool`), and Resource inspection (`client_list_resources`, `client_read_resource`).
--

namespace mcp

include std/json.e as json
include std/pipeio.e as pipeio
include std/http.e as http
include std/sse.e as sse
include std/os.e as os
include std/io.e as io
include std/convert.e as conv

-- =============================================================================
-- Protocol Constants & Error Codes (JSON-RPC 2.0 & MCP 2024-11-05)
-- =============================================================================

public constant
    MCP_VERSION = "2024-11-05"

public constant
    ERR_PARSE_ERROR      = -32700,
    ERR_INVALID_REQUEST  = -32600,
    ERR_METHOD_NOT_FOUND = -32601,
    ERR_INVALID_PARAMS   = -32602,
    ERR_INTERNAL_ERROR   = -32603

-- Client Transport Types
public constant
    CLIENT_STDIO = 1,
    CLIENT_HTTP  = 2

-- Server Internal Struct Indices
constant
    SRV_NAME         = 1,
    SRV_VERSION      = 2,
    SRV_DESCRIPTION  = 3,
    SRV_TOOLS        = 4,
    SRV_RESOURCES    = 5,
    SRV_PROMPTS      = 6,
    SRV_INITIALIZED  = 7

sequence registered_servers = {}
sequence http_server_map   = {}

-- =============================================================================
-- 1. MCP Server Creation & Registration
-- =============================================================================

--**
-- Create a new MCP Server instance.
-- Returns `server_id` integer handle.
public function server(sequence name, sequence version = "1.0.0", sequence description = "")
    sequence s = {
        name,           -- SRV_NAME
        version,        -- SRV_VERSION
        description,    -- SRV_DESCRIPTION
        {},             -- SRV_TOOLS
        {},             -- SRV_RESOURCES
        {},             -- SRV_PROMPTS
        0               -- SRV_INITIALIZED
    }
    registered_servers = append(registered_servers, s)
    return length(registered_servers)
end function

--**
-- Helper: build JSON Schema object from parameter specification:
-- `params_list = { {name, type, description, is_required}, ... }`
function build_input_schema(object params_spec)
    if json:is_object(params_spec) then
        return params_spec
    end if
    if not sequence(params_spec) or length(params_spec) = 0 then
        return {
            json:JSON_OBJECT, {
                {"type", {json:JSON_STRING, "object"}},
                {"properties", {json:JSON_OBJECT, {}}}
            }
        }
    end if

    sequence props = {}
    sequence req_list = {}
    for i = 1 to length(params_spec) do
        sequence p = params_spec[i]
        if sequence(p) and length(p) >= 2 and sequence(p[1]) and sequence(p[2]) then
            sequence pname = p[1]
            sequence ptype = p[2]
            sequence pdesc = ""
            integer is_req = 0
            if length(p) >= 3 and sequence(p[3]) then pdesc = p[3] end if
            if length(p) >= 4 and atom(p[4]) then is_req = (p[4] != 0) end if

            sequence prop_pairs = {
                {"type", {json:JSON_STRING, ptype}}
            }
            if length(pdesc) > 0 then
                prop_pairs = append(prop_pairs, {"description", {json:JSON_STRING, pdesc}})
            end if
            props = append(props, {pname, {json:JSON_OBJECT, prop_pairs}})
            if is_req then
                req_list = append(req_list, {json:JSON_STRING, pname})
            end if
        end if
    end for

    sequence schema_pairs = {
        {"type", {json:JSON_STRING, "object"}},
        {"properties", {json:JSON_OBJECT, props}}
    }
    if length(req_list) > 0 then
        schema_pairs = append(schema_pairs, {"required", {json:JSON_ARRAY, req_list}})
    end if

    return {json:JSON_OBJECT, schema_pairs}
end function

--**
-- Register an executable Tool with the server.
--
-- Parameters:
-- * `srv_id`: Server handle from `mcp:server()`
-- * `name`: Unique tool identifier string (e.g. `"kunden_suchen"`)
-- * `description`: Human & AI-readable description of what the tool does
-- * `params_spec`: Parameter list `{ {name, type, desc, is_required}, ... }` or JSON Schema object
-- * `handler_rid`: Routine ID of handler `function my_tool(sequence args)`
public procedure register_tool(integer srv_id, sequence name, sequence description,
                               object params_spec, integer handler_rid)
    if srv_id < 1 or srv_id > length(registered_servers) then return end if
    sequence schema_node = build_input_schema(params_spec)
    registered_servers[srv_id][SRV_TOOLS] = append(
        registered_servers[srv_id][SRV_TOOLS],
        {name, description, schema_node, handler_rid}
    )
end procedure

--**
-- Register a readable Resource with the server.
--
-- Parameters:
-- * `srv_id`: Server handle
-- * `uri`: Standardized URI (e.g. `"crm://kunden/export"` or `"file:///var/logs/app.log"`)
-- * `name`: Friendly display name
-- * `mime_type`: Content MIME type (e.g. `"text/csv"`, `"application/json"`, `"text/plain"`)
-- * `handler_rid`: Routine ID of handler `function my_resource(sequence uri)`
-- * `description`: Optional description
public procedure register_resource(integer srv_id, sequence uri, sequence name,
                                   sequence mime_type, integer handler_rid, sequence description = "")
    if srv_id < 1 or srv_id > length(registered_servers) then return end if
    registered_servers[srv_id][SRV_RESOURCES] = append(
        registered_servers[srv_id][SRV_RESOURCES],
        {uri, name, mime_type, description, handler_rid}
    )
end procedure

--**
-- Register a reusable Prompt template with the server.
public procedure register_prompt(integer srv_id, sequence name, sequence description,
                                 sequence args_spec, integer handler_rid)
    if srv_id < 1 or srv_id > length(registered_servers) then return end if
    registered_servers[srv_id][SRV_PROMPTS] = append(
        registered_servers[srv_id][SRV_PROMPTS],
        {name, description, args_spec, handler_rid}
    )
end procedure

-- =============================================================================
-- 2. Handler Helpers & Result Builders
-- =============================================================================

--**
-- Extract string argument from `args` key-value sequence.
public function arg(sequence args, sequence key, sequence default_val = "")
    for i = 1 to length(args) do
        if sequence(args[i]) and length(args[i]) >= 2 and equal(args[i][1], key) then
            if sequence(args[i][2]) then
                return args[i][2]
            elsif atom(args[i][2]) then
                return sprintf("%g", args[i][2])
            end if
        end if
    end for
    return default_val
end function

--**
-- Extract numeric argument from `args` key-value sequence.
public function arg_num(sequence args, sequence key, atom default_val = 0)
    for i = 1 to length(args) do
        if sequence(args[i]) and length(args[i]) >= 2 and equal(args[i][1], key) then
            object v = args[i][2]
            if atom(v) then
                return v
            elsif sequence(v) then
                object num = conv:to_number(v)
                if sequence(num) and length(num) = 2 and num[1] = 0 then
                    return num[2]
                elsif atom(num) then
                    return num
                end if
            end if
        end if
    end for
    return default_val
end function

--**
-- Extract boolean argument (0 or 1) from `args` key-value sequence.
public function arg_bool(sequence args, sequence key, integer default_val = 0)
    for i = 1 to length(args) do
        if sequence(args[i]) and length(args[i]) >= 2 and equal(args[i][1], key) then
            object v = args[i][2]
            if atom(v) then
                return (v != 0)
            elsif sequence(v) then
                if equal(v, "true") or equal(v, "1") or equal(v, "yes") then
                    return 1
                elsif equal(v, "false") or equal(v, "0") or equal(v, "no") then
                    return 0
                end if
            end if
        end if
    end for
    return default_val
end function

--**
-- Construct a standardized MCP tool execution result.
public function tool_result(sequence text, integer is_error = 0)
    return {
        {"type", "mcp_tool_result"},
        {"text", text},
        {"is_error", (is_error != 0)}
    }
end function

--**
-- Construct a standardized MCP tool error result.
public function tool_error(sequence error_message)
    return tool_result(error_message, 1)
end function

--**
-- Construct an MCP tool result containing JSON data.
public function tool_json_result(object data, integer is_error = 0)
    return tool_result(json:stringify(data, 2), is_error)
end function

--**
-- Construct an MCP resource reading result.
public function resource_result(sequence uri, sequence mime_type, sequence text_content)
    return {
        {"type", "mcp_resource_result"},
        {"uri", uri},
        {"mime_type", mime_type},
        {"text", text_content}
    }
end function

--**
-- Construct an MCP prompt result.
public function prompt_result(sequence description, sequence messages_list)
    return {
        {"type", "mcp_prompt_result"},
        {"description", description},
        {"messages", messages_list}
    }
end function

-- =============================================================================
-- 3. Core JSON-RPC 2.0 & MCP Dispatcher
-- =============================================================================

function make_response(object id_node, object result_node)
    return json:stringify({
        json:JSON_OBJECT, {
            {"jsonrpc", {json:JSON_STRING, "2.0"}},
            {"id", id_node},
            {"result", result_node}
        }
    })
end function

function make_error(object id_node, integer code, sequence message)
    return json:stringify({
        json:JSON_OBJECT, {
            {"jsonrpc", {json:JSON_STRING, "2.0"}},
            {"id", id_node},
            {"error", {
                json:JSON_OBJECT, {
                    {"code", code},
                    {"message", {json:JSON_STRING, message}}
                }
            }}
        }
    })
end function

function extract_pairs(object node)
    sequence out_list = {}
    if json:is_object(node) then
        sequence pairs = node[2]
        for i = 1 to length(pairs) do
            sequence p = pairs[i]
            if sequence(p) and length(p) >= 2 and sequence(p[1]) then
                object val = json:unwrap(p[2])
                sequence val_str = ""
                if sequence(val) then
                    val_str = val
                elsif atom(val) then
                    val_str = sprintf("%g", val)
                end if
                out_list = append(out_list, {p[1], val_str})
            end if
        end for
    end if
    return out_list
end function

function to_content_string(object o)
    if sequence(o) then
        return o
    elsif atom(o) then
        return sprintf("%g", o)
    end if
    return ""
end function

--**
-- Dispatch a raw JSON-RPC string against server `srv_id`.
-- Returns formatted JSON-RPC response string (or `""` if message was a notification).
public function dispatch(integer srv_id, sequence json_str)
    if srv_id < 1 or srv_id > length(registered_servers) then
        return make_error({json:JSON_NULL, 0}, ERR_INTERNAL_ERROR, "Server handle out of range")
    end if

    object parsed = json:parse(json_str)
    if atom(parsed) or parsed[1] = 0 then
        return make_error({json:JSON_NULL, 0}, ERR_PARSE_ERROR, "Invalid JSON-RPC format")
    end if

    object doc = parsed[2]
    sequence method = json:get(doc, "method", "")
    object id_node  = json:get_node(doc, "id", {json:JSON_NULL, 0})
    integer has_id  = (not equal(id_node, {json:JSON_NULL, 0}))

    -- Handle MCP initialize
    if equal(method, "initialize") then
        registered_servers[srv_id][SRV_INITIALIZED] = 1
        sequence srv_info = {
            json:JSON_OBJECT, {
                {"name", {json:JSON_STRING, registered_servers[srv_id][SRV_NAME]}},
                {"version", {json:JSON_STRING, registered_servers[srv_id][SRV_VERSION]}}
            }
        }
        sequence caps = {
            json:JSON_OBJECT, {
                {"tools", {json:JSON_OBJECT, {{"listChanged", {json:JSON_BOOL, 0}}}}},
                {"resources", {json:JSON_OBJECT, {{"subscribe", {json:JSON_BOOL, 0}}, {"listChanged", {json:JSON_BOOL, 0}}}}},
                {"prompts", {json:JSON_OBJECT, {{"listChanged", {json:JSON_BOOL, 0}}}}}
            }
        }
        sequence res_obj = {
            json:JSON_OBJECT, {
                {"protocolVersion", {json:JSON_STRING, MCP_VERSION}},
                {"capabilities", caps},
                {"serverInfo", srv_info}
            }
        }
        return make_response(id_node, res_obj)

    -- Handle initialized notification
    elsif equal(method, "notifications/initialized") then
        registered_servers[srv_id][SRV_INITIALIZED] = 1
        return ""

    -- Handle ping
    elsif equal(method, "ping") then
        return make_response(id_node, {json:JSON_OBJECT, {}})

    -- Handle tools/list
    elsif equal(method, "tools/list") then
        sequence tools_arr = {}
        sequence tools = registered_servers[srv_id][SRV_TOOLS]
        for i = 1 to length(tools) do
            sequence t = tools[i]
            sequence tool_obj = {
                json:JSON_OBJECT, {
                    {"name", {json:JSON_STRING, t[1]}},
                    {"description", {json:JSON_STRING, t[2]}},
                    {"inputSchema", t[3]}
                }
            }
            tools_arr = append(tools_arr, tool_obj)
        end for
        return make_response(id_node, {json:JSON_OBJECT, {{"tools", {json:JSON_ARRAY, tools_arr}}}})

    -- Handle tools/call
    elsif equal(method, "tools/call") then
        sequence tool_name = json:get(doc, "params.name", "")
        object args_node   = json:get_node(doc, "params.arguments", 0)
        sequence args_list = extract_pairs(args_node)

        integer rid = -1
        sequence tools = registered_servers[srv_id][SRV_TOOLS]
        for i = 1 to length(tools) do
            if equal(tools[i][1], tool_name) then
                rid = tools[i][4]
                exit
            end if
        end for

        if rid < 0 then
            return make_error(id_node, ERR_INVALID_PARAMS, "Unbekanntes Tool: " & tool_name)
        end if

        object out_val = call_func(rid, {args_list})
        sequence out_text = ""
        integer is_err = 0

        if sequence(out_val) and length(out_val) >= 3 and
           sequence(out_val[1]) and equal(out_val[1], {"type", "mcp_tool_result"}) then
            out_text = out_val[2][2]
            is_err   = out_val[3][2]
        else
            out_text = to_content_string(out_val)
        end if

        sequence content_arr = {
            {json:JSON_OBJECT, {
                {"type", {json:JSON_STRING, "text"}},
                {"text", {json:JSON_STRING, out_text}}
            }}
        }
        sequence result_obj = {
            json:JSON_OBJECT, {
                {"content", {json:JSON_ARRAY, content_arr}},
                {"isError", {json:JSON_BOOL, is_err}}
            }
        }
        return make_response(id_node, result_obj)

    -- Handle resources/list
    elsif equal(method, "resources/list") then
        sequence res_arr = {}
        sequence resources = registered_servers[srv_id][SRV_RESOURCES]
        for i = 1 to length(resources) do
            sequence r = resources[i]
            sequence robj = {
                json:JSON_OBJECT, {
                    {"uri", {json:JSON_STRING, r[1]}},
                    {"name", {json:JSON_STRING, r[2]}},
                    {"mimeType", {json:JSON_STRING, r[3]}}
                }
            }
            if length(r[4]) > 0 then
                robj[2] = append(robj[2], {"description", {json:JSON_STRING, r[4]}})
            end if
            res_arr = append(res_arr, robj)
        end for
        return make_response(id_node, {json:JSON_OBJECT, {{"resources", {json:JSON_ARRAY, res_arr}}}})

    -- Handle resources/read
    elsif equal(method, "resources/read") then
        sequence uri = json:get(doc, "params.uri", "")
        integer rid = -1
        sequence mime_type = "text/plain"
        sequence resources = registered_servers[srv_id][SRV_RESOURCES]
        for i = 1 to length(resources) do
            if equal(resources[i][1], uri) then
                rid = resources[i][5]
                mime_type = resources[i][3]
                exit
            end if
        end for

        if rid < 0 then
            return make_error(id_node, ERR_INVALID_PARAMS, "Unbekannte Resource: " & uri)
        end if

        object out_val = call_func(rid, {uri})
        sequence out_text = ""
        if sequence(out_val) and length(out_val) >= 4 and
           sequence(out_val[1]) and equal(out_val[1], {"type", "mcp_resource_result"}) then
            mime_type = out_val[3][2]
            out_text  = out_val[4][2]
        else
            out_text = to_content_string(out_val)
        end if

        sequence contents_arr = {
            {json:JSON_OBJECT, {
                {"uri", {json:JSON_STRING, uri}},
                {"mimeType", {json:JSON_STRING, mime_type}},
                {"text", {json:JSON_STRING, out_text}}
            }}
        }
        return make_response(id_node, {json:JSON_OBJECT, {{"contents", {json:JSON_ARRAY, contents_arr}}}})

    -- Handle prompts/list
    elsif equal(method, "prompts/list") then
        sequence prompt_arr = {}
        sequence prompts = registered_servers[srv_id][SRV_PROMPTS]
        for i = 1 to length(prompts) do
            sequence p = prompts[i]
            sequence pobj = {
                json:JSON_OBJECT, {
                    {"name", {json:JSON_STRING, p[1]}},
                    {"description", {json:JSON_STRING, p[2]}}
                }
            }
            prompt_arr = append(prompt_arr, pobj)
        end for
        return make_response(id_node, {json:JSON_OBJECT, {{"prompts", {json:JSON_ARRAY, prompt_arr}}}})

    -- Handle prompts/get
    elsif equal(method, "prompts/get") then
        sequence pname = json:get(doc, "params.name", "")
        object args_node = json:get_node(doc, "params.arguments", 0)
        sequence args_list = extract_pairs(args_node)

        integer rid = -1
        sequence desc = ""
        sequence prompts = registered_servers[srv_id][SRV_PROMPTS]
        for i = 1 to length(prompts) do
            if equal(prompts[i][1], pname) then
                rid = prompts[i][4]
                desc = prompts[i][2]
                exit
            end if
        end for

        if rid < 0 then
            return make_error(id_node, ERR_INVALID_PARAMS, "Unbekannter Prompt: " & pname)
        end if

        object out_val = call_func(rid, {args_list})
        sequence msg_arr = {}
        if sequence(out_val) and length(out_val) >= 3 and
           sequence(out_val[1]) and equal(out_val[1], {"type", "mcp_prompt_result"}) then
            desc = out_val[2][2]
            sequence raw_msgs = out_val[3][2]
            for m = 1 to length(raw_msgs) do
                sequence mitem = raw_msgs[m]
                if sequence(mitem) and length(mitem) >= 2 then
                    msg_arr = append(msg_arr, {
                        json:JSON_OBJECT, {
                            {"role", {json:JSON_STRING, mitem[1]}},
                            {"content", {json:JSON_OBJECT, {
                                {"type", {json:JSON_STRING, "text"}},
                                {"text", {json:JSON_STRING, mitem[2]}}
                            }}}
                        }
                    })
                end if
            end for
        end if

        return make_response(id_node, {
            json:JSON_OBJECT, {
                {"description", {json:JSON_STRING, desc}},
                {"messages", {json:JSON_ARRAY, msg_arr}}
            }
        })
    end if

    -- Method not handled
    if not has_id then
        return ""
    end if
    return make_error(id_node, ERR_METHOD_NOT_FOUND, "Methode nicht unterstützt: " & method)
end function

-- =============================================================================
-- 4. Server Transports: stdio & HTTP/SSE
-- =============================================================================

function trim_line(sequence s)
    integer start_idx = 1
    while start_idx <= length(s) and (s[start_idx] = ' ' or s[start_idx] = '\t' or s[start_idx] = '\r' or s[start_idx] = '\n') do
        start_idx += 1
    end while
    integer end_idx = length(s)
    while end_idx >= start_idx and (s[end_idx] = ' ' or s[end_idx] = '\t' or s[end_idx] = '\r' or s[end_idx] = '\n') do
        end_idx -= 1
    end while
    if start_idx > end_idx then return "" end if
    return s[start_idx .. end_idx]
end function

--**
-- Run the server on Standard Input / Output (`stdio`).
-- This is the native standard transport for Claude Desktop, Antigravity, Cursor, and Roo Code.
-- Runs until the client terminates the pipe (EOF on stdin).
public procedure run_stdio(integer srv_id)
    while 1 do
        object line = gets(io:STDIN)
        if atom(line) then
            -- EOF reached: client disconnected or closed pipe
            exit
        end if
        sequence trimmed = trim_line(line)
        if length(trimmed) > 0 then
            sequence resp = dispatch(srv_id, trimmed)
            if length(resp) > 0 then
                puts(io:STDOUT, resp & "\n")
                io:flush(io:STDOUT)
            end if
        end if
    end while
end procedure

function http_mcp_find_srv(integer srv_http)
    for i = 1 to length(http_server_map) do
        if http_server_map[i][1] = srv_http then
            return http_server_map[i][2]
        end if
    end for
    if length(registered_servers) > 0 then
        return 1
    end if
    return 0
end function

function http_mcp_sse_route(sequence req)
    sequence sse_body = sse:event("endpoint", "/messages")
    return {200, sse_body, "text/event-stream; charset=utf-8", sse:headers()}
end function

function http_mcp_msg_route(sequence req)
    integer srv_id = 1
    if length(http_server_map) > 0 then
        srv_id = http_server_map[1][2]
    end if
    sequence req_body = req[http:REQ_BODY]
    sequence resp = dispatch(srv_id, req_body)
    if length(resp) = 0 then
        resp = `{"jsonrpc":"2.0","result":null}`
    end if
    return http:response_json(200, resp)
end function

function http_mcp_info_route(sequence req)
    integer srv_id = 1
    if length(http_server_map) > 0 then
        srv_id = http_server_map[1][2]
    end if
    sequence s = registered_servers[srv_id]
    sequence html = sprintf("<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>%s (MCP Server)</title>" &
                            "<style>body{font-family:sans-serif;padding:20px;max-width:800px;margin:auto;} " &
                            "code{background:#f0f0f0;padding:2px 6px;border-radius:3px;}</style></head><body>" &
                            "<h1>⚡ %s (v%s)</h1><p>Vollständig aktiver Model Context Protocol Server (MCP v%s).</p>" &
                            "<h3>Verfügbare Endpunkte:</h3>" &
                            "<ul><li><code>GET /sse</code>: Server-Sent Events Discovery Stream</li>" &
                            "<li><code>POST /messages</code>: JSON-RPC 2.0 Message Endpoint</li>" &
                            "<li><code>POST /mcp</code>: Direkter JSON-RPC over HTTP Endpunkt</li></ul>" &
                            "<h3>Registrierte Tools (%d):</h3><ul>",
                            {s[SRV_NAME], s[SRV_NAME], s[SRV_VERSION], MCP_VERSION, length(s[SRV_TOOLS])})
    for i = 1 to length(s[SRV_TOOLS]) do
        sequence t = s[SRV_TOOLS][i]
        html &= sprintf("<li><b>%s</b>: %s</li>", {t[1], t[2]})
    end for
    html &= "</ul><h3>Registrierte Resources:</h3><ul>"
    for i = 1 to length(s[SRV_RESOURCES]) do
        sequence r = s[SRV_RESOURCES][i]
        html &= sprintf("<li><code>%s</code> (%s): %s</li>", {r[1], r[3], r[2]})
    end for
    html &= "</ul></body></html>"
    return http:response_html(200, html)
end function

--**
-- Start an HTTP + SSE MCP Server listening on `host:port`.
-- Returns `{1, srv_http_id}` on success, or `{0, err_msg}` on failure.
public function run_http(integer srv_id, integer port = 8095, sequence host = "0.0.0.0")
    integer srv_http = http:server_create(host, port)
    if srv_http <= 0 then
        return {0, sprintf("HTTP-Server konnte auf Port %d nicht gestartet werden.", {port})}
    end if

    http_server_map = append(http_server_map, {srv_http, srv_id})

    http:route(srv_http, "GET", "/sse", routine_id("http_mcp_sse_route"))
    http:route(srv_http, "POST", "/messages", routine_id("http_mcp_msg_route"))
    http:route(srv_http, "POST", "/mcp", routine_id("http_mcp_msg_route"))
    http:route(srv_http, "POST", "/", routine_id("http_mcp_msg_route"))
    http:route(srv_http, "GET", "/info", routine_id("http_mcp_info_route"))
    http:route(srv_http, "GET", "/", routine_id("http_mcp_info_route"))

    return {1, srv_http}
end function

--**
-- Run the HTTP MCP Server in a blocking loop (suitable for standalone server scripts).
public procedure serve_http(integer srv_id, integer port = 8095, sequence host = "0.0.0.0")
    sequence res = run_http(srv_id, port, host)
    if res[1] = 0 then
        puts(io:STDERR, "[MCP] " & res[2] & "\n")
        return
    end if
    integer srv_http = res[2]
    puts(io:SCREEN, sprintf("⚡ MCP Server '%s' läuft auf http://%s:%d/ (GET /sse & POST /messages)\n",
                            {registered_servers[srv_id][SRV_NAME], host, port}))
    http:serve_forever(srv_http)
end procedure

-- =============================================================================
-- 5. MCP Client Implementation (stdio subprocess & HTTP)
-- =============================================================================

--**
-- Create an MCP Client connected to a subprocess via Standard-I/O pipes.
--
-- Parameters:
-- * `command`: Shell command string (e.g. `"./euphorix server.ex --stdio"` or `"npx -y @modelcontextprotocol/server-sqlite"`)
--
-- Returns `{1, client_handle}` on success, or `{0, error_message}` on failure.
public function client_stdio(sequence command)
    object proc = pipeio:exec(command)
    if atom(proc) or length(proc) != 4 then
        return {0, "Subprozess konnte nicht gestartet werden: " & command}
    end if
    -- Client handle structure:
    -- {CLIENT_TYPE, proc_or_url, buffer, next_id, srv_info, tools_cache}
    sequence client = {CLIENT_STDIO, proc, "", 1, {}, {}}
    return {1, client}
end function

--**
-- Create an MCP Client connected to a remote MCP Server via HTTP.
public function client_http(sequence url)
    sequence client = {CLIENT_HTTP, url, "", 1, {}, {}}
    return {1, client}
end function

function client_request(sequence client, sequence method, sequence params_node)
    integer req_id = client[4]
    client[4] = req_id + 1

    sequence req_pairs = {
        {"jsonrpc", {json:JSON_STRING, "2.0"}},
        {"id", req_id},
        {"method", {json:JSON_STRING, method}}
    }
    if length(params_node) > 0 then
        req_pairs = append(req_pairs, {"params", params_node})
    end if
    sequence req_json = json:stringify({json:JSON_OBJECT, req_pairs})

    if client[1] = CLIENT_STDIO then
        sequence proc = client[2]
        pipeio:write(proc[pipeio:STDIN], req_json & "\n")

        -- Buffered line read
        sequence resp_line = ""
        sequence buf = client[3]
        integer timeout_ticks = 300 -- ~6 seconds
        while timeout_ticks > 0 do
            integer nl_pos = find('\n', buf)
            if nl_pos > 0 then
                resp_line = buf[1 .. nl_pos - 1]
                buf = buf[nl_pos + 1 .. $]
                exit
            end if
            sequence chunk = pipeio:read(proc[pipeio:STDOUT], 2048)
            if length(chunk) > 0 then
                buf &= chunk
            else
                os:sleep(0.02)
                timeout_ticks -= 1
            end if
        end while
        client[3] = buf

        if length(resp_line) = 0 then
            return {0, "Timeout beim Warten auf Server-Antwort", client}
        end if

        object parsed = json:parse(resp_line)
        if atom(parsed) or parsed[1] = 0 then
            return {0, "Ungültiges JSON vom Server empfangen: " & resp_line, client}
        end if
        object doc = parsed[2]
        object err_node = json:get_node(doc, "error", 0)
        if not equal(err_node, 0) then
            sequence err_msg = json:get(doc, "error.message", "JSON-RPC Fehler")
            return {0, err_msg, client}
        end if
        object res_node = json:get_node(doc, "result", 0)
        return {1, res_node, client}

    elsif client[1] = CLIENT_HTTP then
        sequence url = client[2]
        sequence resp = http:post_json(url, req_json)
        if resp[http:STATUS] != 200 then
            return {0, sprintf("HTTP-Fehler %d: %s", {resp[http:STATUS], resp[http:BODY]}), client}
        end if
        object parsed = json:parse(resp[http:BODY])
        if atom(parsed) or parsed[1] = 0 then
            return {0, "Ungültiges JSON vom Server empfangen: " & resp[http:BODY], client}
        end if
        object doc = parsed[2]
        object err_node = json:get_node(doc, "error", 0)
        if not equal(err_node, 0) then
            sequence err_msg = json:get(doc, "error.message", "JSON-RPC Fehler")
            return {0, err_msg, client}
        end if
        object res_node = json:get_node(doc, "result", 0)
        return {1, res_node, client}
    end if

    return {0, "Unbekannter Client-Typ", client}
end function

function client_notify(sequence client, sequence method, sequence params_node = {})
    sequence req_pairs = {
        {"jsonrpc", {json:JSON_STRING, "2.0"}},
        {"method", {json:JSON_STRING, method}}
    }
    if length(params_node) > 0 then
        req_pairs = append(req_pairs, {"params", params_node})
    end if
    sequence req_json = json:stringify({json:JSON_OBJECT, req_pairs})
    if client[1] = CLIENT_STDIO then
        sequence proc = client[2]
        pipeio:write(proc[pipeio:STDIN], req_json & "\n")
    elsif client[1] = CLIENT_HTTP then
        sequence url = client[2]
        http:post_json(url, req_json)
    end if
    return client
end function

--**
-- Perform the MCP handshake (`initialize` and `notifications/initialized`).
-- Returns `{1, server_info, updated_client}` on success, or `{0, err_msg, client}` on failure.
public function client_init(sequence client, sequence client_name = "Euphorix-MCP-Client", sequence client_version = "1.0.0")
    sequence params = {
        json:JSON_OBJECT, {
            {"protocolVersion", {json:JSON_STRING, MCP_VERSION}},
            {"capabilities", {json:JSON_OBJECT, {}}},
            {"clientInfo", {
                json:JSON_OBJECT, {
                    {"name", {json:JSON_STRING, client_name}},
                    {"version", {json:JSON_STRING, client_version}}
                }
            }}
        }
    }
    sequence r = client_request(client, "initialize", params)
    if r[1] = 0 then
        return r
    end if
    object res_node = r[2]
    client = r[3]

    -- Acknowledge initialization
    client = client_notify(client, "notifications/initialized", {})

    sequence srv_name = json:get(res_node, "serverInfo.name", "Unbekannt")
    sequence srv_ver  = json:get(res_node, "serverInfo.version", "1.0.0")
    client[5] = {srv_name, srv_ver}

    return {1, {srv_name, srv_ver}, client}
end function

--**
-- Retrieve the list of available tools from the server.
-- Returns `{1, tools_list, updated_client}`.
-- Each tool is `{name, description, raw_tool_node}`.
public function client_list_tools(sequence client)
    sequence r = client_request(client, "tools/list", {json:JSON_OBJECT, {}})
    if r[1] = 0 then
        return r
    end if
    object res_node = r[2]
    client = r[3]
    object tools_node = json:get_node(res_node, "tools", 0)
    sequence tools_list = {}
    if json:is_array(tools_node) then
        sequence arr = tools_node[2]
        for i = 1 to length(arr) do
            object t = arr[i]
            sequence tname = json:get(t, "name", "")
            sequence tdesc = json:get(t, "description", "")
            tools_list = append(tools_list, {tname, tdesc, t})
        end for
    end if
    client[6] = tools_list
    return {1, tools_list, client}
end function

--**
-- Execute a Tool call on the server.
--
-- Parameters:
-- * `client`: Client handle
-- * `tool_name`: Tool identifier
-- * `args_pairs`: Argument list `{ {key, value}, ... }`
--
-- Returns `{1, content_text, is_error, updated_client}`.
public function client_call_tool(sequence client, sequence tool_name, sequence args_pairs = {})
    sequence arg_obj = {}
    for i = 1 to length(args_pairs) do
        sequence p = args_pairs[i]
        if sequence(p) and length(p) >= 2 and sequence(p[1]) then
            object v = p[2]
            if sequence(v) then
                arg_obj = append(arg_obj, {p[1], {json:JSON_STRING, v}})
            elsif atom(v) then
                arg_obj = append(arg_obj, {p[1], v})
            end if
        end if
    end for
    sequence params = {
        json:JSON_OBJECT, {
            {"name", {json:JSON_STRING, tool_name}},
            {"arguments", {json:JSON_OBJECT, arg_obj}}
        }
    }
    sequence r = client_request(client, "tools/call", params)
    if r[1] = 0 then
        return {r[1], r[2], 1, r[3]}
    end if
    object res_node = r[2]
    client = r[3]

    integer is_err = json:get(res_node, "isError", 0)
    object content_node = json:get_node(res_node, "content", 0)
    sequence text_out = ""
    if json:is_array(content_node) and length(content_node[2]) > 0 then
        text_out = json:get(content_node[2][1], "text", "")
    end if
    return {1, text_out, is_err, client}
end function

--**
-- Retrieve the list of resources from the server.
-- Returns `{1, resources_list, updated_client}`.
-- Each resource is `{uri, name, mimeType, description}`.
public function client_list_resources(sequence client)
    sequence r = client_request(client, "resources/list", {json:JSON_OBJECT, {}})
    if r[1] = 0 then
        return r
    end if
    object res_node = r[2]
    client = r[3]
    object resources_node = json:get_node(res_node, "resources", 0)
    sequence res_list = {}
    if json:is_array(resources_node) then
        sequence arr = resources_node[2]
        for i = 1 to length(arr) do
            object itm = arr[i]
            sequence uri   = json:get(itm, "uri", "")
            sequence name  = json:get(itm, "name", "")
            sequence mime  = json:get(itm, "mimeType", "")
            sequence desc  = json:get(itm, "description", "")
            res_list = append(res_list, {uri, name, mime, desc})
        end for
    end if
    return {1, res_list, client}
end function

--**
-- Read the content of a resource URI from the server.
-- Returns `{1, text_content, mime_type, updated_client}`.
public function client_read_resource(sequence client, sequence uri)
    sequence params = {
        json:JSON_OBJECT, {
            {"uri", {json:JSON_STRING, uri}}
        }
    }
    sequence r = client_request(client, "resources/read", params)
    if r[1] = 0 then
        return {r[1], r[2], "", r[3]}
    end if
    object res_node = r[2]
    client = r[3]

    object contents_node = json:get_node(res_node, "contents", 0)
    sequence text_out = ""
    sequence mime_out = "text/plain"
    if json:is_array(contents_node) and length(contents_node[2]) > 0 then
        text_out = json:get(contents_node[2][1], "text", "")
        mime_out = json:get(contents_node[2][1], "mimeType", "text/plain")
    end if
    return {1, text_out, mime_out, client}
end function

--**
-- Close the client and terminate any associated subprocess.
public procedure client_close(sequence client)
    if client[1] = CLIENT_STDIO and sequence(client[2]) and length(client[2]) = 4 then
        pipeio:kill(client[2])
    end if
end procedure
