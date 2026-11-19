--****
-- == PostgreSQL Client Engine (std/pgsql.e)
--
-- Powered by the Java PostgreSQL engine & JDBC driver, providing a uniform API
-- with `std/sqlite.e`:
-- * Supports both PostgreSQL `$1, $2` and SQLite-style `?` placeholders in `params`.
-- * Supports URI (`postgresql://user:pass@host:5432/db`) and key-value connection strings.
-- * Automatically maps PostgreSQL OIDs (`BOOL`, `INT2/4/8`, `FLOAT4/8/NUMERIC`, `TEXT/JSONB`, `NULL`)
--   to Euphoria types and JSON-compatible associative objects (`query_assoc`).
--

namespace pgsql

include std/json.e

constant
    M_PGSQL_OPEN   = 250,
    M_PGSQL_CLOSE  = 251,
    M_PGSQL_EXEC   = 252,
    M_PGSQL_QUERY  = 253,
    M_PGSQL_INFO   = 254,
    M_PGSQL_ESCAPE = 255

public constant
    SQL_NULL  = {json:JSON_NULL, 0},
    OK        = 1,
    COL_NAMES = 2,
    ROWS      = 3

--**
-- Return `1` if PostgreSQL support is available in the runtime, `0` otherwise.
public function is_available()
    return machine_func(M_PGSQL_INFO, {0, 4})
end function

--**
-- Return `1` if `val` represents an SQL `NULL` value.
public function is_null(object val)
    return sequence(val) and length(val) = 2 and equal(val[1], json:JSON_NULL)
end function

--**
-- Connect to a PostgreSQL server using a connection string or URI
-- (e.g. `"host=127.0.0.1 port=5432 dbname=mydb user=postgres password=secret"` or
-- `"postgresql://user:pass@127.0.0.1:5432/mydb"`).
-- Returns `db_id (> 0)` on success, or `0` on failure (check `pgsql:errmsg()`).
public function open(sequence conninfo = "")
    return machine_func(M_PGSQL_OPEN, conninfo)
end function

--**
-- Alias for `pgsql:open(conninfo)`.
public function connect(sequence conninfo = "")
    return machine_func(M_PGSQL_OPEN, conninfo)
end function

--**
-- Close an open PostgreSQL connection.
public function close(integer db_id)
    return machine_func(M_PGSQL_CLOSE, db_id)
end function

--**
-- Execute DDL/DML SQL statement(s) (`CREATE TABLE`, `INSERT`, `UPDATE`, `DELETE`)
-- with optional `$1, $2` or `?` parameter bindings. Returns `1` on success, `0` on error.
public function exec(integer db_id, sequence sql, sequence params = {})
    return machine_func(M_PGSQL_EXEC, {db_id, sql, params})
end function

--**
-- Execute a `SELECT` (or `INSERT ... RETURNING`) query and return `{ok, column_names, rows}`.
public function query_raw(integer db_id, sequence sql, sequence params = {})
    return machine_func(M_PGSQL_QUERY, {db_id, sql, params})
end function

--**
-- Execute a `SELECT` (or `RETURNING`) query and return the list of rows `{ {col1, col2, ...}, ... }`.
public function query(integer db_id, sequence sql, sequence params = {})
    sequence res = machine_func(M_PGSQL_QUERY, {db_id, sql, params})
    if res[OK] = 1 then
        return res[ROWS]
    end if
    return {}
end function

--**
-- Execute a `SELECT` query and return the first row, or `default_val` if empty.
public function query_one(integer db_id, sequence sql, sequence params = {}, object default_val = {})
    sequence rows = query(db_id, sql, params)
    if length(rows) > 0 then
        return rows[1]
    end if
    return default_val
end function

--**
-- Execute a `SELECT` query and return the single scalar value of the first column of the first row
-- (e.g. `SELECT COUNT(*) FROM users` or `INSERT ... RETURNING id`), or `default_val` if no row is returned.
public function query_value(integer db_id, sequence sql, sequence params = {}, object default_val = 0)
    sequence rows = query(db_id, sql, params)
    if length(rows) > 0 and length(rows[1]) > 0 then
        return rows[1][1]
    end if
    return default_val
end function

--**
-- Execute a `SELECT` query and return a list of JSON-compatible associative objects
-- (`json:JSON_OBJECT`), allowing access via `json:get(row, "col_name")` or direct
-- serialization via `json:stringify(json:array(rows))`.
public function query_assoc(integer db_id, sequence sql, sequence params = {})
    sequence res = machine_func(M_PGSQL_QUERY, {db_id, sql, params})
    if res[OK] = 0 then
        return {}
    end if
    sequence cols = res[COL_NAMES]
    sequence rows = res[ROWS]
    sequence out  = {}
    for r = 1 to length(rows) do
        sequence row = rows[r]
        sequence pairs = {}
        for c = 1 to length(cols) do
            object cell = row[c]
            if sequence(cell) and not is_null(cell) then
                cell = {json:JSON_STRING, cell}
            end if
            pairs = append(pairs, {cols[c], cell})
        end for
        out = append(out, {json:JSON_OBJECT, pairs})
    end for
    return out
end function

--**
-- Return the number of rows affected (`INSERT`, `UPDATE`, `DELETE`) by the most recent statement.
public function changes(integer db_id)
    return machine_func(M_PGSQL_INFO, {db_id, 1})
end function

--**
-- Return the PostgreSQL server version integer (e.g. `160004` for PostgreSQL 16.4).
public function server_version(integer db_id)
    return machine_func(M_PGSQL_INFO, {db_id, 2})
end function

--**
-- Return the last PostgreSQL error message string.
public function errmsg(integer db_id = 0)
    return machine_func(M_PGSQL_INFO, {db_id, 3})
end function

--**
-- Safely escape a string literal (`'...'`) using `PQescapeLiteral`.
public function escape_literal(integer db_id, sequence val)
    return machine_func(M_PGSQL_ESCAPE, {db_id, val, 0})
end function

--**
-- Safely escape an SQL identifier (`"..."`, e.g. table or column name) using `PQescapeIdentifier`.
public function escape_identifier(integer db_id, sequence ident)
    return machine_func(M_PGSQL_ESCAPE, {db_id, ident, 1})
end function

--**
-- Transaction helpers: `begin(db)`, `commit(db)`, `rollback(db)`.
public function begin(integer db_id)
    return exec(db_id, "BEGIN;")
end function

public function commit(integer db_id)
    return exec(db_id, "COMMIT;")
end function

public function rollback(integer db_id)
    return exec(db_id, "ROLLBACK;")
end function
