--****
-- == Statically Linked SQLite 3.46 Database Engine (std/sqlite.e)
--
-- Powered by `libsqlite3.a` compiled directly into the `eui` binary (zero external `.so` dependencies).
-- Supports `:memory:` and file databases, parameterized queries (`?`), transactions,
-- and direct JSON-compatible associative row objects (`query_assoc`).
--

namespace sqlite

include std/json.e

constant
    M_SQLITE_OPEN  = 230,
    M_SQLITE_CLOSE = 231,
    M_SQLITE_EXEC  = 232,
    M_SQLITE_QUERY = 233,
    M_SQLITE_INFO  = 234

public constant
    SQL_NULL  = {json:JSON_NULL, 0},
    OK        = 1,
    COL_NAMES = 2,
    ROWS      = 3

--**
-- Return `1` if `val` represents an SQL `NULL` value.
public function is_null(object val)
    return sequence(val) and length(val) = 2 and equal(val[1], json:JSON_NULL)
end function

--**
-- Open an SQLite database file (or `":memory:"` by default).
-- Returns `db_id (> 0)` on success, or `-1` on error.
public function open(sequence path = ":memory:")
    return machine_func(M_SQLITE_OPEN, path)
end function

--**
-- Close an open SQLite database connection.
public function close(integer db_id)
    return machine_func(M_SQLITE_CLOSE, db_id)
end function

--**
-- Execute DDL/DML SQL statement(s) (`CREATE TABLE`, `INSERT`, `UPDATE`, `DELETE`)
-- with optional `?` parameter bindings. Returns `1` on success, `0` on error.
public function exec(integer db_id, sequence sql, sequence params = {})
    return machine_func(M_SQLITE_EXEC, {db_id, sql, params})
end function

--**
-- Execute a `SELECT` query and return `{ok, column_names, rows}`.
public function query_raw(integer db_id, sequence sql, sequence params = {})
    return machine_func(M_SQLITE_QUERY, {db_id, sql, params})
end function

--**
-- Execute a `SELECT` query and return the list of rows `{ {col1, col2, ...}, ... }`.
public function query(integer db_id, sequence sql, sequence params = {})
    sequence res = machine_func(M_SQLITE_QUERY, {db_id, sql, params})
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
-- (e.g. `SELECT COUNT(*) FROM users`), or `default_val` if no row is returned.
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
-- serialization via `json:stringify(rows)`.
public function query_assoc(integer db_id, sequence sql, sequence params = {})
    sequence res = machine_func(M_SQLITE_QUERY, {db_id, sql, params})
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
-- Return the `ROWID` of the most recent successful `INSERT` on `db_id`.
public function last_insert_id(integer db_id)
    return machine_func(M_SQLITE_INFO, {db_id, 1})
end function

--**
-- Return the number of rows modified, inserted, or deleted by the most recent statement.
public function changes(integer db_id)
    return machine_func(M_SQLITE_INFO, {db_id, 2})
end function

--**
-- Return the last SQLite error message string.
public function errmsg(integer db_id = 0)
    return machine_func(M_SQLITE_INFO, {db_id, 3})
end function

--**
-- Transaction helpers: `begin(db)`, `commit(db)`, `rollback(db)`.
public function begin(integer db_id)
    return exec(db_id, "BEGIN TRANSACTION;")
end function

public function commit(integer db_id)
    return exec(db_id, "COMMIT;")
end function

public function rollback(integer db_id)
    return exec(db_id, "ROLLBACK;")
end function
