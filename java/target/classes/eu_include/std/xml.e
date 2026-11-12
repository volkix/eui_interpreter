--****
-- == Native XML Parser, DOM Builder, Query & Serializer (std/xml.e)
--
-- Zero-dependency native C++20 XML engine supporting XML declarations, comments,
-- CDATA, entity decoding/encoding, DOM tree construction, and path/tag queries.
--

namespace xml

constant
    M_XML_PARSE        = 220,
    M_XML_STRINGIFY    = 221,
    M_XML_XPATH        = 222,
    M_XML_VALIDATE_XSD = 223,
    M_XML_VALIDATE_RNG = 224

public constant
    XML_ELEMENT = -9100

public constant
    TAG      = 2,
    ATTRS    = 3,
    CHILDREN = 4,
    TEXT     = 5

-- =============================================================================
-- 1. Parsing, Construction & Serialization
-- =============================================================================

--**
-- Parse an XML document string and return `{ok, root_element_or_error}`.
public function parse(sequence xml_str)
    return machine_func(M_XML_PARSE, xml_str)
end function

--**
-- Parse an XML document string and return the root element directly (or `{0, err}` on error).
public function decode(sequence xml_str)
    sequence res = machine_func(M_XML_PARSE, xml_str)
    if res[1] = 1 then
        return res[2]
    end if
    return res
end function

--**
-- Create a new XML element node `{XML_ELEMENT, tag, attrs, children, text}`.
public function element(sequence tag_name, sequence attrs = {}, sequence children = {}, sequence text_val = "")
    return {XML_ELEMENT, tag_name, attrs, children, text_val}
end function

--**
-- Serialize an XML element tree to an XML string.
-- Set `indent > 0` (e.g. `2`) for pretty-printed multi-line output.
public function stringify(sequence node, integer indent = 0)
    return machine_func(M_XML_STRINGIFY, {node, indent})
end function

public function to_string(sequence node, integer indent = 0)
    return machine_func(M_XML_STRINGIFY, {node, indent})
end function

-- =============================================================================
-- 2. Node Inspection & Mutation
-- =============================================================================

public function is_element(object node)
    return sequence(node) and length(node) >= 5 and equal(node[1], XML_ELEMENT)
end function

public function tag(sequence node)
    return node[TAG]
end function

public function text(sequence node)
    return node[TEXT]
end function

public function attrs(sequence node)
    return node[ATTRS]
end function

public function children(sequence node)
    return node[CHILDREN]
end function

--**
-- Get the value of attribute `name` on `node`, or `default_val` if absent.
public function attr(sequence node, sequence name, sequence default_val = "")
    sequence list = node[ATTRS]
    for i = 1 to length(list) do
        sequence kv = list[i]
        if length(kv) >= 2 and equal(kv[1], name) then
            return kv[2]
        end if
    end for
    return default_val
end function

--**
-- Set or update attribute `name` on `node` and return the updated element.
public function set_attr(sequence node, sequence name, sequence val)
    sequence list = node[ATTRS]
    for i = 1 to length(list) do
        if equal(list[i][1], name) then
            list[i][2] = val
            node[ATTRS] = list
            return node
        end if
    end for
    node[ATTRS] = append(list, {name, val})
    return node
end function

--**
-- Append a child element to `node` and return the updated element.
public function add_child(sequence node, sequence child)
    node[CHILDREN] = append(node[CHILDREN], child)
    return node
end function

-- =============================================================================
-- 3. Tree & Path Queries (`find_all`, `find_first`)
-- =============================================================================

function split_slash_path(sequence path)
    sequence parts = {}
    integer start = 1
    for i = 1 to length(path) do
        if path[i] = '/' then
            if i > start then
                parts = append(parts, path[start .. i - 1])
            end if
            start = i + 1
        end if
    end for
    if start <= length(path) then
        parts = append(parts, path[start .. $])
    end if
    return parts
end function

function collect_by_tag_recursive(sequence node, sequence target_tag)
    sequence res = {}
    if equal(node[TAG], target_tag) then
        res = append(res, node)
    end if
    sequence ch = node[CHILDREN]
    for i = 1 to length(ch) do
        sequence sub = collect_by_tag_recursive(ch[i], target_tag)
        for j = 1 to length(sub) do
            res = append(res, sub[j])
        end for
    end for
    return res
end function

--**
-- Find all XML elements matching either a tag name (e.g. `"book"`) recursively,
-- or a slash-separated hierarchy path (e.g. `"catalog/book/title"` or `"book/title"`).
public function find_all(sequence node, sequence tag_or_path)
    if not is_element(node) then
        return {}
    end if
    integer has_slash = 0
    for i = 1 to length(tag_or_path) do
        if tag_or_path[i] = '/' then
            has_slash = 1
            exit
        end if
    end for

    if not has_slash then
        return collect_by_tag_recursive(node, tag_or_path)
    end if

    sequence parts = split_slash_path(tag_or_path)
    if length(parts) = 0 then
        return {}
    end if

    sequence current_set = {}
    integer start_idx = 1
    if equal(node[TAG], parts[1]) then
        current_set = {node}
        start_idx = 2
    else
        current_set = collect_by_tag_recursive(node, parts[1])
        start_idx = 2
    end if

    for p = start_idx to length(parts) do
        sequence seg = parts[p]
        sequence next_set = {}
        for c = 1 to length(current_set) do
            sequence ch = current_set[c][CHILDREN]
            for k = 1 to length(ch) do
                if equal(ch[k][TAG], seg) then
                    next_set = append(next_set, ch[k])
                end if
            end for
        end for
        current_set = next_set
    end for

    return current_set
end function

--**
-- Find the first XML element matching `tag_or_path`, or return `default_val` if none found.
public function find_first(sequence node, sequence tag_or_path, object default_val = 0)
    sequence all = find_all(node, tag_or_path)
    if length(all) > 0 then
        return all[1]
    end if
    return default_val
end function

--**
-- Execute a full W3C XPath 1.0 query (via `libxml2`, e.g. `"//book[@category='coding']/title"`)
-- on a parsed XML node or raw XML string, returning all matching nodes/attribute values.
public function xpath(object node_or_xml, sequence xpath_expr)
    return machine_func(M_XML_XPATH, {node_or_xml, xpath_expr})
end function

--**
-- Validate an XML document (parsed node or XML string) against a W3C XML Schema (XSD 1.0)
-- via `libxml2`. Returns `{is_valid (1 or 0), errors_list}`.
public function validate_xsd(object node_or_xml, sequence xsd_str)
    return machine_func(M_XML_VALIDATE_XSD, {node_or_xml, xsd_str})
end function

public function is_valid_xsd(object node_or_xml, sequence xsd_str)
    sequence res = machine_func(M_XML_VALIDATE_XSD, {node_or_xml, xsd_str})
    return res[1]
end function

--**
-- Validate an XML document (parsed node or XML string) against a RelaxNG schema
-- via `libxml2`. Returns `{is_valid (1 or 0), errors_list}`.
public function validate_relaxng(object node_or_xml, sequence rng_str)
    return machine_func(M_XML_VALIDATE_RNG, {node_or_xml, rng_str})
end function

public function is_valid_relaxng(object node_or_xml, sequence rng_str)
    sequence res = machine_func(M_XML_VALIDATE_RNG, {node_or_xml, rng_str})
    return res[1]
end function


