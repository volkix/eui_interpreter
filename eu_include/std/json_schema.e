--****
-- == Native JSON-Schema Validator (std/json_schema.e)
--
-- Supports Draft-07 / 2020-12 JSON-Schema validation (`type`, `required`, `properties`,
-- `additionalProperties`, `items`, `minItems`, `maxItems`, `uniqueItems`, `minimum`,
-- `maximum`, `exclusiveMinimum`, `exclusiveMaximum`, `multipleOf`, `minLength`,
-- `maxLength`, `pattern`, `format`, `enum`, `const`, `allOf`, `anyOf`, `oneOf`, `not`).
--

namespace json_schema

include std/json.e

constant M_JSON_SCHEMA_VALIDATE = 212

public constant
    VALID   = 1,
    ERRORS  = 2

public constant
    ERR_PATH    = 1,
    ERR_MESSAGE = 2

function is_raw_json_text(object v)
    if not sequence(v) or length(v) = 0 then
        return 0
    end if
    if length(v) = 2 and integer(v[1]) and v[1] <= json:JSON_NULL and v[1] >= json:JSON_OBJECT then
        return 0
    end if
    for i = 1 to length(v) do
        if not integer(v[i]) or v[i] < 1 or v[i] > 255 then
            return 0
        end if
    end for
    return 1
end function

function ensure_parsed_node(object doc_or_str)
    if is_raw_json_text(doc_or_str) then
        sequence p = json:parse(doc_or_str)
        if p[1] = 1 then
            return {1, p[2]}
        end if
        return {0, p[2]}
    end if
    return {1, doc_or_str}
end function

--**
-- Validate `instance` (parsed JSON node or JSON string) against `schema` (parsed JSON node or JSON string).
-- Returns `{ is_valid (1 or 0), { {json_pointer_path, message}, ... } }`.
public function validate(object instance_or_str, object schema_or_str)
    sequence inst_p = ensure_parsed_node(instance_or_str)
    if inst_p[1] = 0 then
        return {0, {{"/", "Ungültiges Instanz-JSON: " & inst_p[2]}}}
    end if
    sequence sch_p = ensure_parsed_node(schema_or_str)
    if sch_p[1] = 0 then
        return {0, {{"/", "Ungültiges Schema-JSON: " & sch_p[2]}}}
    end if
    return machine_func(M_JSON_SCHEMA_VALIDATE, {inst_p[2], sch_p[2]})
end function

--**
-- Return `1` if `instance_or_str` conforms to `schema_or_str`, or `0` otherwise.
public function is_valid(object instance_or_str, object schema_or_str)
    sequence res = validate(instance_or_str, schema_or_str)
    return res[VALID]
end function

--**
-- Format all validation errors from `validate()` into human-readable `"<path>: <message>"` strings.
public function format_errors(sequence validation_res)
    sequence errs = validation_res[ERRORS]
    sequence list = {}
    for i = 1 to length(errs) do
        sequence e = errs[i]
        list = append(list, e[ERR_PATH] & ": " & e[ERR_MESSAGE])
    end for
    return list
end function
