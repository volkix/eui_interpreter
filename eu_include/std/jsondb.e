--****
-- == Embedded JSON Document Database with Indexing & Schema Filtering (std/jsondb.e)
--
-- Provides a high-performance, embedded JSON document store built directly on top of
-- the Euphoria Database System (std/eds.e), JSON parser (std/json.e), and
-- JSON-Schema Draft 2020-12 validator (std/json_schema.e).
--
-- Key Capabilities:
-- * **Collections**: Schema-flexible JSON document collections (stored as EDS tables).
-- * **Secondary Indexing**: Arbitrary dot-path indexes (e.g. `"email"`, `"address.city"`, `"status"`).
-- * **O(log N) Binary Search**: Instant indexed lookups via EDS sorted B-tree keys.
-- * **Range Queries**: Fast indexed range scanning (`find_range`).
-- * **JSON-Schema Search (`find_by_schema`)**: Filter and find documents using declarative JSON Schemas.
-- * **Schema Enforcement**: Optional collection-level schema validation on insert and update.
--
-- Namespace: `jsondb`
--

namespace jsondb

include std/eds.e as eds
include std/json.e as json
include std/json_schema.e as schema
include std/convert.e as conv
include std/search.e as search

constant META_TABLE = "__jsondb_meta__"
constant SENTINEL_NONE = {-999888, -777666}

-- =============================================================================
-- Internal Helpers
-- =============================================================================

function sanitize_field(sequence field_path)
    sequence out = ""
    for i = 1 to length(field_path) do
        integer c = field_path[i]
        if (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') then
            out &= c
        else
            out &= '_'
        end if
    end for
    return out
end function

function idx_table_name(sequence col_name, sequence field_path)
    return "__idx_" & col_name & "__" & sanitize_field(field_path)
end function

function is_raw_json(object v)
    if not sequence(v) or length(v) = 0 then return 0 end if
    if length(v) = 2 and integer(v[1]) and v[1] <= json:JSON_NULL and v[1] >= json:JSON_OBJECT then
        return 0
    end if
    for i = 1 to length(v) do
        if not integer(v[i]) or v[i] < 1 or v[i] > 255 then return 0 end if
    end for
    return 1
end function

function to_json_str(object doc)
    if is_raw_json(doc) then
        return doc
    end if
    return json:stringify(doc)
end function

function to_json_ast(object doc)
    if is_raw_json(doc) then
        sequence p = json:parse(doc)
        if p[1] = 1 then
            return p[2]
        end if
        return {}
    end if
    return doc
end function

function get_meta(sequence col_name)
    integer cur_tbl = eds:current_db -- keep track
    eds:db_select_table(META_TABLE)
    integer pos = eds:db_find_key(col_name)
    if pos > 0 then
        return eds:db_record_data(pos)
    end if
    return {}
end function

procedure set_meta(sequence col_name, sequence meta_data)
    eds:db_select_table(META_TABLE)
    integer pos = eds:db_find_key(col_name)
    if pos > 0 then
        eds:db_replace_data(pos, meta_data)
    else
        eds:db_insert(col_name, meta_data)
    end if
end procedure

-- =============================================================================
-- 1. Database & Collection Management
-- =============================================================================

--**
-- Create a new JSON database file.
public function create_db(sequence filepath)
    integer res = eds:db_create(filepath)
    if res != eds:DB_OK then
        return {0, sprintf("Fehler beim Erstellen der Datenbank: %d", {res})}
    end if
    res = eds:db_create_table(META_TABLE)
    if res != eds:DB_OK then
        return {0, sprintf("Fehler beim Erstellen der Meta-Tabelle: %d", {res})}
    end if
    return {1, filepath}
end function

--**
-- Open an existing JSON database file.
public function open_db(sequence filepath)
    integer res = eds:db_open(filepath, eds:DB_LOCK_NO)
    if res != eds:DB_OK then
        return {0, sprintf("Fehler beim Öffnen der Datenbank: %d", {res})}
    end if
    integer tbl_res = eds:db_select_table(META_TABLE)
    if tbl_res != eds:DB_OK then
        return {0, "Ungültige JSON-Datenbank: Meta-Tabelle fehlt."}
    end if
    return {1, filepath}
end function

--**
-- Close the currently open JSON database.
public procedure close_db()
    eds:db_close()
end procedure

--**
-- Create a new document collection with optional JSON-Schema enforcement.
--
-- Parameters:
-- * `col_name`: Collection name (e.g. `"kunden"`, `"auftraege"`)
-- * `schema_or_str`: Optional JSON-Schema definition to validate all future documents on insert/update.
public function create_collection(sequence col_name, object schema_or_str = {})
    eds:db_select_table(META_TABLE)
    if length(get_meta(col_name)) > 0 then
        return {0, sprintf("Collection '%s' existiert bereits.", {col_name})}
    end if

    integer res = eds:db_create_table(col_name)
    if res != eds:DB_OK and res != eds:DB_EXISTS_ALREADY then
        return {0, sprintf("Fehler beim Erstellen der Collection '%s': %d", {col_name, res})}
    end if

    sequence schema_str = ""
    if sequence(schema_or_str) and length(schema_or_str) > 0 then
        schema_str = to_json_str(schema_or_str)
    end if

    -- Meta format: {col_name, schema_str, indexes_list, next_id_counter}
    sequence meta = {col_name, schema_str, {}, 1}
    set_meta(col_name, meta)
    return {1, col_name}
end function

--**
-- Set or update the JSON-Schema for a collection.
public function set_collection_schema(sequence col_name, object schema_or_str)
    sequence meta = get_meta(col_name)
    if length(meta) = 0 then
        return {0, sprintf("Collection '%s' nicht gefunden.", {col_name})}
    end if
    meta[2] = to_json_str(schema_or_str)
    set_meta(col_name, meta)
    return {1, col_name}
end function

--**
-- Return a list of all collections in the database.
public function list_collections()
    eds:db_select_table(META_TABLE)
    integer total = eds:db_table_size()
    sequence cols = {}
    for i = 1 to total do
        cols = append(cols, eds:db_record_key(i))
    end for
    return cols
end function

-- =============================================================================
-- 2. Index Management
-- =============================================================================

--**
-- Create a secondary index on a field path (e.g. `"email"`, `"adresse.stadt"`, `"status"`).
-- Automatically backfills the index with all existing documents in the collection.
public function create_index(sequence col_name, sequence field_path)
    sequence meta = get_meta(col_name)
    if length(meta) = 0 then
        return {0, sprintf("Collection '%s' nicht gefunden.", {col_name})}
    end if

    sequence indexes = meta[3]
    for i = 1 to length(indexes) do
        if equal(indexes[i], field_path) then
            return {1, "Index existiert bereits."}
        end if
    end for

    sequence idx_name = idx_table_name(col_name, field_path)
    integer res = eds:db_create_table(idx_name)
    if res != eds:DB_OK and res != eds:DB_EXISTS_ALREADY then
        return {0, sprintf("Fehler beim Erstellen der Index-Tabelle '%s': %d", {idx_name, res})}
    end if

    -- Backfill index with existing collection records
    eds:db_select_table(col_name)
    integer total = eds:db_table_size()
    for i = 1 to total do
        object doc_id = eds:db_record_key(i)
        sequence json_str = eds:db_record_data(i)
        sequence ast = to_json_ast(json_str)
        if json:has(ast, field_path) then
            object field_val = json:get(ast, field_path)
            eds:db_select_table(idx_name)
            eds:db_insert({field_val, doc_id}, doc_id)
            eds:db_select_table(col_name)
        end if
    end for

    -- Save index in metadata
    indexes = append(indexes, field_path)
    meta[3] = indexes
    set_meta(col_name, meta)
    return {1, field_path}
end function

--**
-- List all registered secondary indexes for a collection.
public function list_indexes(sequence col_name)
    sequence meta = get_meta(col_name)
    if length(meta) = 0 then return {} end if
    return meta[3]
end function

-- =============================================================================
-- 3. Document CRUD Operations
-- =============================================================================

--**
-- Insert a new JSON document into a collection.
-- Validates against the collection schema if defined and updates all secondary indexes.
--
-- Parameters:
-- * `col_name`: Collection name
-- * `doc_or_str`: Document as JSON string or parsed JSON AST object
-- * `custom_id`: Optional custom document ID (e.g. `"K-1001"`). If empty, auto-generates ID.
--
-- Returns `{1, doc_id}` on success, or `{0, error_message}` on failure.
public function insert(sequence col_name, object doc_or_str, object custom_id = {})
    sequence meta = get_meta(col_name)
    if length(meta) = 0 then
        return {0, sprintf("Collection '%s' nicht gefunden.", {col_name})}
    end if

    sequence json_str = to_json_str(doc_or_str)
    sequence ast = to_json_ast(doc_or_str)

    -- 1. Validate against collection schema if defined
    sequence schema_str = meta[2]
    if length(schema_str) > 0 then
        sequence val_res = schema:validate(json_str, schema_str)
        if val_res[schema:VALID] = 0 then
            sequence errs = schema:format_errors(val_res)
            sequence msg = "Dokument entspricht nicht dem JSON-Schema:"
            for e = 1 to length(errs) do
                msg &= "\n  • " & errs[e]
            end for
            return {0, msg}
        end if
    end if

    -- 2. Determine document ID
    object doc_id = custom_id
    if length(doc_id) = 0 then
        if json:has(ast, "_id") then
            doc_id = json:get(ast, "_id")
        else
            integer next_num = meta[4]
            doc_id = sprintf("doc_%d", {next_num})
            meta[4] = next_num + 1
            set_meta(col_name, meta)
        end if
    end if

    -- 3. Insert into collection table
    eds:db_select_table(col_name)
    integer res = eds:db_insert(doc_id, json_str)
    if res != eds:DB_OK then
        return {0, sprintf("Dokument mit ID '%s' existiert bereits.", {sprint(doc_id)})}
    end if

    -- 4. Update all secondary indexes
    sequence indexes = meta[3]
    for i = 1 to length(indexes) do
        sequence field_path = indexes[i]
        if json:has(ast, field_path) then
            object field_val = json:get(ast, field_path)
            sequence idx_name = idx_table_name(col_name, field_path)
            eds:db_select_table(idx_name)
            eds:db_insert({field_val, doc_id}, doc_id)
        end if
    end for

    return {1, doc_id}
end function

--**
-- Retrieve a document by its primary ID.
-- Returns `{1, json_string}` on success, or `{0, "Not found"}`.
public function get(sequence col_name, object doc_id)
    eds:db_select_table(col_name)
    integer pos = eds:db_find_key(doc_id)
    if pos <= 0 then
        return {0, sprintf("Dokument '%s' nicht gefunden.", {sprint(doc_id)})}
    end if
    return {1, eds:db_record_data(pos)}
end function

--**
-- Delete a document by its ID and clean up all secondary indexes.
public function delete(sequence col_name, object doc_id)
    sequence meta = get_meta(col_name)
    if length(meta) = 0 then
        return {0, sprintf("Collection '%s' nicht gefunden.", {col_name})}
    end if

    eds:db_select_table(col_name)
    integer pos = eds:db_find_key(doc_id)
    if pos <= 0 then
        return {0, sprintf("Dokument '%s' nicht gefunden.", {sprint(doc_id)})}
    end if

    sequence json_str = eds:db_record_data(pos)
    sequence ast = to_json_ast(json_str)

    -- Remove from secondary indexes
    sequence indexes = meta[3]
    for i = 1 to length(indexes) do
        sequence field_path = indexes[i]
        if json:has(ast, field_path) then
            object field_val = json:get(ast, field_path)
            sequence idx_name = idx_table_name(col_name, field_path)
            eds:db_select_table(idx_name)
            integer idx_pos = eds:db_find_key({field_val, doc_id})
            if idx_pos > 0 then
                eds:db_delete_record(idx_pos)
            end if
        end if
    end for

    -- Delete from collection table
    eds:db_select_table(col_name)
    eds:db_delete_record(pos)
    return {1, doc_id}
end function

--**
-- Update an existing document by ID.
public function update(sequence col_name, object doc_id, object new_doc_or_str)
    sequence del_res = delete(col_name, doc_id)
    if del_res[1] = 0 then
        return del_res
    end if
    return insert(col_name, new_doc_or_str, doc_id)
end function

--**
-- Return the total number of documents in a collection.
public function count(sequence col_name)
    eds:db_select_table(col_name)
    return eds:db_table_size()
end function

-- =============================================================================
-- 4. Searching & Querying (Indexed & JSON-Schema)
-- =============================================================================

--**
-- Return all documents in a collection as a list of `{doc_id, json_string}` tuples.
public function find_all(sequence col_name)
    eds:db_select_table(col_name)
    integer total = eds:db_table_size()
    sequence list = {}
    for i = 1 to total do
        list = append(list, {eds:db_record_key(i), eds:db_record_data(i)})
    end for
    return list
end function

--**
-- Find documents by exact match on a field path.
-- Uses the secondary index for instant O(log N) binary search if an index exists.
-- Otherwise performs a full collection scan.
public function find_by(sequence col_name, sequence field_path, object search_val)
    sequence meta = get_meta(col_name)
    if length(meta) = 0 then return {} end if

    -- Check if index exists for this field
    integer has_idx = 0
    sequence indexes = meta[3]
    for i = 1 to length(indexes) do
        if equal(indexes[i], field_path) then
            has_idx = 1
            exit
        end if
    end for

    sequence results = {}

    if has_idx then
        -- Fast Indexed Search: O(log N) binary lookup
        sequence idx_name = idx_table_name(col_name, field_path)
        eds:db_select_table(idx_name)

        integer pos = eds:db_find_key({search_val, 0})
        if pos < 0 then
            pos = -pos
        end if

        integer total = eds:db_table_size()
        while pos <= total do
            object idx_key = eds:db_record_key(pos)
            if not equal(idx_key[1], search_val) then
                exit
            end if

            object doc_id = idx_key[2]
            eds:db_select_table(col_name)
            integer main_pos = eds:db_find_key(doc_id)
            if main_pos > 0 then
                results = append(results, {doc_id, eds:db_record_data(main_pos)})
            end if

            eds:db_select_table(idx_name)
            pos += 1
        end while
    else
        -- Full collection scan
        eds:db_select_table(col_name)
        integer total = eds:db_table_size()
        for i = 1 to total do
            object doc_id = eds:db_record_key(i)
            sequence json_str = eds:db_record_data(i)
            sequence ast = to_json_ast(json_str)
            if json:has(ast, field_path) and equal(json:get(ast, field_path), search_val) then
                results = append(results, {doc_id, json_str})
            end if
        end for
    end if

    return results
end function

--**
-- Find documents within a numeric range on an indexed field: `min_val <= field_value <= max_val`.
public function find_range(sequence col_name, sequence field_path, atom min_val, atom max_val)
    sequence meta = get_meta(col_name)
    if length(meta) = 0 then return {} end if

    sequence idx_name = idx_table_name(col_name, field_path)
    eds:db_select_table(idx_name)

    integer pos = eds:db_find_key({min_val, 0})
    if pos < 0 then pos = -pos end if

    integer total = eds:db_table_size()
    sequence results = {}

    while pos <= total do
        object idx_key = eds:db_record_key(pos)
        atom val = idx_key[1]
        if val > max_val then exit end if

        object doc_id = idx_key[2]
        eds:db_select_table(col_name)
        integer main_pos = eds:db_find_key(doc_id)
        if main_pos > 0 then
            results = append(results, {doc_id, eds:db_record_data(main_pos)})
        end if

        eds:db_select_table(idx_name)
        pos += 1
    end while

    return results
end function

--**
-- Search documents in a collection using a declarative JSON-Schema.
--
-- Every document is evaluated against the provided JSON-Schema Draft 2020-12 specification.
-- Only documents that satisfy the schema are returned.
--
-- Parameters:
-- * `col_name`: Collection name
-- * `schema_or_str`: JSON Schema definition (string or AST)
--
-- Example schema:
-- `{"type": "object", "properties": {"status": {"const": "aktiv"}, "alter": {"minimum": 18, "maximum": 65}}}`
public function find_by_schema(sequence col_name, object schema_or_str)
    sequence meta = get_meta(col_name)
    if length(meta) = 0 then return {} end if

    sequence schema_str = to_json_str(schema_or_str)
    eds:db_select_table(col_name)
    integer total = eds:db_table_size()
    sequence matches = {}

    for i = 1 to total do
        object doc_id = eds:db_record_key(i)
        sequence json_str = eds:db_record_data(i)
        if schema:is_valid(json_str, schema_str) then
            matches = append(matches, {doc_id, json_str})
        end if
    end for

    return matches
end function
