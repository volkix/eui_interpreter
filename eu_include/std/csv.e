--****
-- == RFC 4180 CSV Engine for Euphorix (std/csv.e)
--
-- High-performance CSV parser and serializer with support for custom delimiters
-- (comma, semicolon, tab), quoted strings, embedded newlines, and UTF-8 encoding.
--

namespace csv

include std/io.e as io
include std/text.e as text

--**
-- Format a single value as a valid CSV field (escaping quotes and commas).
public function format_field(object val, integer delimiter = ',', integer quote_all = 0)
    sequence s = ""
    if atom(val) then
        s = sprintf("%g", val)
    elsif sequence(val) then
        -- Check if flat string
        integer is_str = 1
        for i = 1 to length(val) do
            if not integer(val[i]) then
                is_str = 0
                exit
            end if
        end for
        if is_str then
            s = val
        else
            s = sprintf("%s", {val})
        end if
    end if

    integer needs_quotes = quote_all
    for i = 1 to length(s) do
        integer c = s[i]
        if c = delimiter or c = '"' or c = '\r' or c = '\n' then
            needs_quotes = 1
            exit
        end if
    end for

    if not needs_quotes then
        return s
    end if

    sequence out = "\""
    for i = 1 to length(s) do
        integer c = s[i]
        if c = '"' then
            out &= "\"\""
        else
            out &= c
        end if
    end for
    out &= "\""
    return out
end function

--**
-- Convert headers and rows sequences to a CSV string.
public function to_csv(sequence headers, sequence rows, integer delimiter = ',', integer quote_all = 0)
    sequence out = ""
    if length(headers) > 0 then
        for c = 1 to length(headers) do
            if c > 1 then out &= delimiter end if
            out &= format_field(headers[c], delimiter, quote_all)
        end for
        out &= "\r\n"
    end if

    for r = 1 to length(rows) do
        sequence row = rows[r]
        for c = 1 to length(row) do
            if c > 1 then out &= delimiter end if
            out &= format_field(row[c], delimiter, quote_all)
        end for
        out &= "\r\n"
    end for
    return out
end function

--**
-- Parse a CSV text into a sequence of rows: `{ {col1, col2, ...}, ... }`.
public function parse(sequence csv_text, integer delimiter = ',')
    sequence rows = {}
    sequence cur_row = {}
    sequence cur_field = ""
    integer in_quotes = 0
    integer len = length(csv_text)
    integer i = 1

    while i <= len do
        integer c = csv_text[i]

        if in_quotes then
            if c = '"' then
                if i + 1 <= len and csv_text[i + 1] = '"' then
                    cur_field &= '"'
                    i += 1
                else
                    in_quotes = 0
                end if
            else
                cur_field &= c
            end if
        else
            if c = '"' then
                in_quotes = 1
            elsif c = delimiter then
                cur_row = append(cur_row, cur_field)
                cur_field = ""
            elsif c = '\r' then
                if i + 1 <= len and csv_text[i + 1] = '\n' then
                    i += 1
                end if
                cur_row = append(cur_row, cur_field)
                cur_field = ""
                rows = append(rows, cur_row)
                cur_row = {}
            elsif c = '\n' then
                cur_row = append(cur_row, cur_field)
                cur_field = ""
                rows = append(rows, cur_row)
                cur_row = {}
            else
                cur_field &= c
            end if
        end if
        i += 1
    end while

    if length(cur_field) > 0 or length(cur_row) > 0 then
        cur_row = append(cur_row, cur_field)
        rows = append(rows, cur_row)
    end if

    return rows
end function

--**
-- Write headers and rows to a CSV file.
-- Returns `1` on success, `0` on error.
public function write_file(sequence filepath, sequence headers, sequence rows, integer delimiter = ',', integer quote_all = 0)
    sequence text_data = to_csv(headers, rows, delimiter, quote_all)
    integer fn = open(filepath, "wb")
    if fn < 0 then
        return 0
    end if
    puts(fn, text_data)
    close(fn)
    return 1
end function

--**
-- Read a CSV file and return `{headers, rows}`.
-- If `has_header = 0`, `headers` will be empty and all rows will be in `rows`.
public function read_file(sequence filepath, integer delimiter = ',', integer has_header = 1)
    integer fn = open(filepath, "rb")
    if fn < 0 then
        return {{}, {}}
    end if

    sequence content = ""
    object line = gets(fn)
    while sequence(line) do
        content &= line
        line = gets(fn)
    end while
    close(fn)

    -- Strip UTF-8 BOM if present
    if length(content) >= 3 and content[1] = #EF and content[2] = #BB and content[3] = #BF then
        content = content[4..$]
    end if

    sequence all_rows = parse(content, delimiter)
    if length(all_rows) = 0 then
        return {{}, {}}
    end if

    if has_header then
        sequence headers = all_rows[1]
        sequence data_rows = all_rows[2..$]
        return {headers, data_rows}
    else
        return {{}, all_rows}
    end if
end function
