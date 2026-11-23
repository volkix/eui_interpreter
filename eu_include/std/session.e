--****
-- == HTTP Session Management for Euphorix (std/session.e)
--
-- Server-side session management for web applications and APIs.
-- Provides secure session ID generation, key-value storage per session,
-- cookie parsing and `Set-Cookie` header formatting.
--

namespace session

include std/auth.e as auth
include std/map.e as map
include std/text.e as text

constant
    DEFAULT_COOKIE_NAME = "EUI_SESSION",
    DEFAULT_LIFETIME    = 86400 -- 24 hours

-- Global map of sessions: sid -> {last_access, attributes_map}
map:map active_sessions = map:new()

--**
-- Extract session ID from incoming HTTP `Cookie` header string.
public function extract_sid(sequence cookie_header, sequence cookie_name = DEFAULT_COOKIE_NAME)
    if length(cookie_header) = 0 then
        return ""
    end if

    sequence parts = text:split(cookie_header, ';')
    for i = 1 to length(parts) do
        sequence p = text:trim(parts[i])
        integer eq_pos = find('=', p)
        if eq_pos > 1 then
            sequence name = text:trim(p[1..eq_pos - 1])
            if equal(name, cookie_name) then
                return text:trim(p[eq_pos + 1..$])
            end if
        end if
    end for
    return ""
end function

--**
-- Start or resume a session from an incoming `Cookie` header string (or raw session ID).
-- Returns `{sid, is_new}`.
public function start(sequence cookie_str = "", sequence cookie_name = DEFAULT_COOKIE_NAME)
    sequence sid = extract_sid(cookie_str, cookie_name)
    if length(sid) = 0 and length(cookie_str) > 0 and find('=', cookie_str) = 0 then
        -- Direct session ID passed
        sid = cookie_str
    end if

    if length(sid) > 0 and map:has(active_sessions, sid) then
        object sess_data = map:get(active_sessions, sid)
        -- Update last accessed timestamp
        sess_data[1] = time()
        map:put(active_sessions, sid, sess_data)
        return {sid, 0}
    end if

    -- Create new session
    sequence new_sid = auth:random_token(16)
    map:map attrs = map:new()
    map:put(active_sessions, new_sid, {time(), attrs})
    return {new_sid, 1}
end function

--**
-- Store a key-value attribute in the session.
public procedure set(sequence sid, sequence key, object val)
    if map:has(active_sessions, sid) then
        sequence sess_data = map:get(active_sessions, sid)
        map:map attrs = sess_data[2]
        map:put(attrs, key, val)
        sess_data[1] = time()
        map:put(active_sessions, sid, sess_data)
    end if
end procedure

--**
-- Retrieve a key-value attribute from the session.
public function get(sequence sid, sequence key, object default_val = {})
    if map:has(active_sessions, sid) then
        sequence sess_data = map:get(active_sessions, sid)
        map:map attrs = sess_data[2]
        if map:has(attrs, key) then
            return map:get(attrs, key)
        end if
    end if
    return default_val
end function

--**
-- Check if a key exists in the session.
public function has(sequence sid, sequence key)
    if map:has(active_sessions, sid) then
        sequence sess_data = map:get(active_sessions, sid)
        map:map attrs = sess_data[2]
        return map:has(attrs, key)
    end if
    return 0
end function

--**
-- Destroy an active session.
public procedure destroy(sequence sid)
    if map:has(active_sessions, sid) then
        map:remove(active_sessions, sid)
    end if
end procedure

--**
-- Format a standard HTTP `Set-Cookie` header string.
public function cookie_header(sequence sid, integer max_age = DEFAULT_LIFETIME,
                             sequence cookie_name = DEFAULT_COOKIE_NAME,
                             sequence path = "/", integer http_only = 1)
    sequence out = sprintf("Set-Cookie: %s=%s; Path=%s; Max-Age=%d; SameSite=Lax",
                           {cookie_name, sid, path, max_age})
    if http_only then
        out &= "; HttpOnly"
    end if
    return out
end function
