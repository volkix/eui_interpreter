--****
-- == JSON Parser, Builder & Serializer (std/json.e)
--
-- Powered by the Java JSON engine with tagged AST representation,
-- dot/bracket path queries (`"user.items[1].name"`), and pretty printing.
--

namespace json

constant
    M_JSON_PARSE     = 210,
    M_JSON_STRINGIFY = 211,
    M_JSON_JSONPATH  = 213

public constant
    JSON_NULL   = -9000,
    JSON_BOOL   = -9001,
    JSON_NUMBER = -9002,
    JSON_STRING = -9003,
    JSON_ARRAY  = -9004,
    JSON_OBJECT = -9005

-- =============================================================================
-- 1. Constructors & Type Inspection
-- =============================================================================

public function null()
    return {JSON_NULL, 0}
end function

public function bool(integer b)
    if b != 0 then
        return {JSON_BOOL, 1}
    end if
    return {JSON_BOOL, 0}
end function

public function str(sequence s)
    return {JSON_STRING, s}
end function

public function array(sequence items = {})
    return {JSON_ARRAY, items}
end function

public function object_new(sequence pairs = {})
    return {JSON_OBJECT, pairs}
end function

public function type_of(object v)
    if atom(v) then
        return JSON_NUMBER
    end if
    if length(v) = 2 and integer(v[1]) then
        integer t = v[1]
        if t <= JSON_NULL and t >= JSON_OBJECT then
            return t
        end if
    end if
    return JSON_STRING
end function

public function is_null(object v)
    return sequence(v) and length(v) = 2 and equal(v[1], JSON_NULL)
end function

public function is_bool(object v)
    if sequence(v) and length(v) = 2 then
        return equal(v[1], JSON_BOOL)
    end if
    return 0
end function

public function is_object(object v)
    if sequence(v) and length(v) = 2 then
        return equal(v[1], JSON_OBJECT)
    end if
    return 0
end function

public function is_array(object v)
    if sequence(v) and length(v) = 2 then
        return equal(v[1], JSON_ARRAY)
    end if
    return 0
end function

public function unwrap(object v)
    if atom(v) then
        return v
    end if
    if length(v) = 2 and integer(v[1]) then
        integer t = v[1]
        if t = JSON_STRING or t = JSON_BOOL or t = JSON_NUMBER or t = JSON_ARRAY then
            return v[2]
        elsif t = JSON_NULL then
            return 0
        end if
    end if
    return v
end function

-- =============================================================================
-- 2. Parsing & Serialization
-- =============================================================================

--**
-- Parse a JSON string and return `{ok, doc_or_error}`.
public function parse(sequence json_str)
    return machine_func(M_JSON_PARSE, json_str)
end function

--**
-- Parse a JSON string and return the parsed document directly (or `{0, err}` on error).
public function decode(sequence json_str)
    sequence res = machine_func(M_JSON_PARSE, json_str)
    if res[1] = 1 then
        return res[2]
    end if
    return res
end function

--**
-- Serialize a JSON document or Euphoria value to a JSON string.
-- Set `indent > 0` (e.g. `2`) for pretty-printed output.
public function stringify(object val, integer indent = 0)
    return machine_func(M_JSON_STRINGIFY, {val, indent})
end function

public function encode(object val, integer indent = 0)
    return machine_func(M_JSON_STRINGIFY, {val, indent})
end function

-- =============================================================================
-- 3. Path Queries & Object Manipulation
-- =============================================================================

function find_in_object(sequence pairs, sequence key, integer ref_out)
    for i = 1 to length(pairs) do
        sequence kv = pairs[i]
        if length(kv) >= 2 and equal(kv[1], key) then
            if ref_out then
                return {1, kv[2]}
            end if
            return i
        end if
    end for
    if ref_out then
        return {0, 0}
    end if
    return 0
end function

function parse_int_simple(sequence s)
    integer val = 0
    for i = 1 to length(s) do
        integer c = s[i]
        if c >= '0' and c <= '9' then
            val = val * 10 + (c - '0')
        end if
    end for
    return val
end function

--**
-- Navigate a JSON document using a key, an integer index, a path list (e.g. `{"artikel", 2, "preis"}` or `{1, "name"}`),
-- or a dot/bracket string path (e.g. `"user.roles[2]"` or `"name"`),
-- returning the raw JSON node or `default_val` if not found.
public function get_node(object doc, object path, object default_val = 0)
    object cur = doc
    if atom(path) then
        integer idx = floor(path)
        if not is_array(cur) or idx < 1 or idx > length(cur[2]) then
            return default_val
        end if
        return cur[2][idx]
    end if

    -- Check if `path` is a sequence of path steps (e.g. `{1, "name"}` or `{"artikel", 2, "preis"}`)
    integer is_step_list = 0
    for k = 1 to length(path) do
        if sequence(path[k]) then
            is_step_list = 1
            exit
        end if
    end for

    if is_step_list then
        for k = 1 to length(path) do
            object step = path[k]
            if atom(step) then
                integer idx = floor(step)
                if not is_array(cur) or idx < 1 or idx > length(cur[2]) then
                    return default_val
                end if
                cur = cur[2][idx]
            else
                if not is_object(cur) then
                    return default_val
                end if
                sequence found = find_in_object(cur[2], step, 1)
                if found[1] = 0 then
                    return default_val
                end if
                cur = found[2]
            end if
        end for
        return cur
    end if

    integer i = 1
    integer n = length(path)

    while i <= n do
        if path[i] = '.' then
            i += 1
        end if
        if i > n then
            exit
        end if

        if path[i] = '[' then
            integer close_b = i + 1
            while close_b <= n and path[close_b] != ']' do
                close_b += 1
            end while
            integer idx = parse_int_simple(path[i + 1 .. close_b - 1])
            if not is_array(cur) then
                return default_val
            end if
            sequence items = cur[2]
            if idx < 1 or idx > length(items) then
                return default_val
            end if
            cur = items[idx]
            i = close_b + 1
        else
            integer seg_end = i
            while seg_end <= n and path[seg_end] != '.' and path[seg_end] != '[' do
                seg_end += 1
            end while
            sequence key = path[i .. seg_end - 1]
            if not is_object(cur) then
                return default_val
            end if
            sequence found = find_in_object(cur[2], key, 1)
            if found[1] = 0 then
                return default_val
            end if
            cur = found[2]
            i = seg_end
        end if
    end while

    return cur
end function

--**
-- Navigate a JSON document using a key, an integer index, a path list (`{1, "name"}`),
-- or a dot/bracket string path (e.g. `"user.address.city"` or `"items[1].price"`),
-- automatically unwrapping primitive JSON strings, booleans, and numbers.
public function get(object doc, object path, object default_val = 0)
    object sentinel = {-999999, -999999}
    object node = get_node(doc, path, sentinel)
    if equal(node, sentinel) then
        return default_val
    end if
    return unwrap(node)
end function

--**
-- Check whether a JSON object contains `key` (or path).
public function has(object doc, sequence path)
    object sentinel = {-999999, -999999}
    object node = get_node(doc, path, sentinel)
    return not equal(node, sentinel)
end function

--**
-- Set or update a property `key` on a JSON object and return the updated object.
public function set(sequence obj_doc, sequence key, object val)
    if not is_object(obj_doc) then
        return obj_doc
    end if
    object wrapped = val
    if sequence(val) and not (length(val) = 2 and integer(val[1]) and val[1] <= JSON_NULL and val[1] >= JSON_OBJECT) then
        wrapped = {JSON_STRING, val}
    end if
    sequence pairs = obj_doc[2]
    for i = 1 to length(pairs) do
        if equal(pairs[i][1], key) then
            pairs[i][2] = wrapped
            return {JSON_OBJECT, pairs}
        end if
    end for
    pairs = append(pairs, {key, wrapped})
    return {JSON_OBJECT, pairs}
end function

--**
-- Return a sequence of all keys in a JSON object.
public function keys(object obj_doc)
    if not is_object(obj_doc) then
        return {}
    end if
    sequence pairs = obj_doc[2]
    sequence res = {}
    for i = 1 to length(pairs) do
        res = append(res, pairs[i][1])
    end for
    return res
end function

--**
-- Return the number of properties in a JSON object or elements in a JSON array.
public function size(object doc)
    if is_object(doc) or is_array(doc) then
        return length(doc[2])
    end if
    return 0
end function

--**
-- Execute a RFC 9535 JSONPath query via `jsoncons::jsonpath` (e.g. `"$.employees[?(@.role == 'Network')].name"`),
-- returning a sequence of unwrapped matching items.
public function jsonpath(object doc_or_str, sequence expr)
    object res_arr = machine_func(M_JSON_JSONPATH, {doc_or_str, expr})
    if is_array(res_arr) then
        sequence items = res_arr[2]
        sequence out = {}
        for i = 1 to length(items) do
            out = append(out, unwrap(items[i]))
        end for
        return out
    end if
    return {}
end function

