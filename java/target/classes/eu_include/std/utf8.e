--****
-- == UTF-8 String Engine (std/utf8.e)
--
-- Powered by Java 25 Unicode and UTF-8 string manipulation engine.
--
-- In Euphoria, string literals (`"Größe €"`) are stored as UTF-8 byte sequences:
-- * `length("Größe €")` returns `11` (byte count).
-- * `utf8:len("Größe €")` returns `7` (Unicode character / codepoint count).
--

namespace utf8

constant
    M_UTF8_VALID           = 240,
    M_UTF8_LEN             = 241,
    M_UTF8_SLICE           = 242,
    M_UTF8_TO_CODEPOINTS   = 243,
    M_UTF8_FROM_CODEPOINTS = 244,
    M_UTF8_UPPER           = 245,
    M_UTF8_LOWER           = 246,
    M_UTF8_FIND            = 247

--**
-- Return `1` if `s` is a valid UTF-8 byte sequence, `0` otherwise.
public function valid(sequence s)
    return machine_func(M_UTF8_VALID, s)
end function

--**
-- Return the number of Unicode characters (codepoints) in UTF-8 string `s`.
public function len(sequence s)
    return machine_func(M_UTF8_LEN, s)
end function

--**
-- Return the `idx`-th Unicode character (1-based) as a UTF-8 string (e.g. `"ö"`).
public function char_at(sequence s, integer idx)
    return machine_func(M_UTF8_SLICE, {s, idx, idx})
end function

--**
-- Extract a UTF-8 substring from character position `start_cp` to `end_cp` (1-based, inclusive).
-- Never splits multi-byte UTF-8 characters.
public function slice(sequence s, integer start_cp, integer end_cp)
    return machine_func(M_UTF8_SLICE, {s, start_cp, end_cp})
end function

--**
-- Decode a UTF-8 byte string into a sequence of Unicode codepoint integers (UTF-32),
-- e.g. `"Größe"` -> `{71, 114, 246, 223, 101}`.
public function to_codepoints(sequence s)
    return machine_func(M_UTF8_TO_CODEPOINTS, s)
end function

--**
-- Encode a sequence of Unicode codepoint integers (or a single codepoint atom) into a UTF-8 string.
public function from_codepoints(object cp_seq)
    return machine_func(M_UTF8_FROM_CODEPOINTS, cp_seq)
end function

--**
-- Convert a UTF-8 string to uppercase (supporting Unicode characters like `ä -> Ä`, `ö -> Ö`, `ü -> Ü`).
public function upper(sequence s)
    return machine_func(M_UTF8_UPPER, s)
end function

--**
-- Convert a UTF-8 string to lowercase (supporting Unicode characters like `Ä -> ä`, `Ö -> ö`, `Ü -> ü`).
public function lower(sequence s)
    return machine_func(M_UTF8_LOWER, s)
end function

--**
-- Find the 1-based Unicode character (codepoint) position of `needle` inside `haystack`,
-- starting at character `start_cp` (default `1`). Returns `0` if not found.
public function find(sequence needle, sequence haystack, integer start_cp = 1)
    return machine_func(M_UTF8_FIND, {needle, haystack, start_cp})
end function

--**
-- Return the number of UTF-8 bytes in `s` (alias for `length(s)`).
public function byte_length(sequence s)
    return length(s)
end function

--**
-- UTF-8 Byte Order Mark (`EF BB BF`)
public constant UTF8_BOM = {239, 187, 191}

--**
-- Remove a leading UTF-8 BOM (`{239, 187, 191}`) from `s` if present.
public function strip_bom(sequence s)
    if length(s) >= 3 and s[1] = 239 and s[2] = 187 and s[3] = 191 then
        return s[4..$]
    end if
    return s
end function

--**
-- Read a single complete UTF-8 character (1 to 4 bytes) from open file handle `fn`.
-- Returns the UTF-8 character as a string (e.g. `"€"` or `"ä"`), or `-1` at EOF.
public function getc_utf8(integer fn)
    integer b1 = getc(fn)
    if b1 < 0 then
        return -1
    end if
    integer needed = 1
    if b1 >= #F0 then
        needed = 4
    elsif b1 >= #E0 then
        needed = 3
    elsif b1 >= #C0 then
        needed = 2
    end if
    sequence ch = {b1}
    for i = 2 to needed do
        integer bn = getc(fn)
        if bn < 0 then
            exit
        end if
        ch = append(ch, bn)
    end for
    return ch
end function

--**
-- Read a single complete Unicode codepoint integer (e.g. `8364` for `'€'`) from open file handle `fn`,
-- or `-1` at EOF.
public function getc_codepoint(integer fn)
    object ch = getc_utf8(fn)
    if atom(ch) then
        return -1
    end if
    sequence cps = to_codepoints(ch)
    if length(cps) = 0 then
        return -1
    end if
    return cps[1]
end function

--**
-- Read an entire UTF-8 file into a string. Automatically removes a leading UTF-8 BOM
-- when `remove_bom = 1` (the default). Returns `-1` if the file cannot be opened.
public function read_file(sequence path, integer remove_bom = 1)
    integer fn = open(path, "rb")
    if fn < 0 then
        return -1
    end if
    sequence out = ""
    object line = gets(fn)
    while sequence(line) do
        out &= line
        line = gets(fn)
    end while
    close(fn)
    if remove_bom then
        out = strip_bom(out)
    end if
    return out
end function

--**
-- Read all lines from a UTF-8 file as a sequence of UTF-8 strings (without trailing `\r` or `\n`).
-- Automatically removes a leading UTF-8 BOM on the first line when `remove_bom = 1` (default).
-- Returns `-1` if the file cannot be opened.
public function read_lines(sequence path, integer remove_bom = 1)
    integer fn = open(path, "rb")
    if fn < 0 then
        return -1
    end if
    sequence lines = {}
    object line = gets(fn)
    integer first = 1
    while sequence(line) do
        if first and remove_bom then
            line = strip_bom(line)
            first = 0
        end if
        while length(line) > 0 and (line[$] = '\n' or line[$] = '\r') do
            line = line[1..$-1]
        end while
        lines = append(lines, line)
        line = gets(fn)
    end while
    close(fn)
    return lines
end function

--**
-- Write a UTF-8 string `content` to `path`. Optionally prepends a UTF-8 BOM when `add_bom = 1`.
-- Returns `1` on success, `0` on failure.
public function write_file(sequence path, sequence content, integer add_bom = 0)
    integer fn = open(path, "wb")
    if fn < 0 then
        return 0
    end if
    if add_bom then
        puts(fn, UTF8_BOM)
    end if
    puts(fn, content)
    close(fn)
    return 1
end function
