--****
-- == Server-Sent Events (SSE) Engine for Euphorix (std/sse.e)
--
-- Enables live, real-time push streaming to web browsers without WebSocket overhead.
-- Formats standard W3C text/event-stream frames and HTTP response headers.
--

namespace sse

--**
-- Format a Server-Sent Events message frame.
--
-- Parameters:
-- * `event_name`: Custom event name (e.g. `"update"`, `"status"`, `"notification"`)
-- * `data`: Data payload string (e.g. JSON or HTML snippet)
-- * `id`: Optional message ID string
-- * `retry_ms`: Optional reconnection time in milliseconds
--
-- Returns formatted SSE message string ready to be sent over HTTP connection.
public function event(sequence event_name, sequence data, sequence id = "", integer retry_ms = 0)
    sequence out = ""
    if length(id) > 0 then
        out &= "id: " & id & "\n"
    end if
    if length(event_name) > 0 then
        out &= "event: " & event_name & "\n"
    end if
    if retry_ms > 0 then
        out &= sprintf("retry: %d\n", retry_ms)
    end if

    -- Support multi-line data payloads
    sequence lines = {}
    sequence cur = ""
    for i = 1 to length(data) do
        if data[i] = '\n' then
            lines = append(lines, cur)
            cur = ""
        elsif data[i] != '\r' then
            cur &= data[i]
        end if
    end for
    lines = append(lines, cur)

    for i = 1 to length(lines) do
        out &= "data: " & lines[i] & "\n"
    end for
    out &= "\n"
    return out
end function

--**
-- Standard HTTP headers required for establishing a Server-Sent Events connection.
public function headers()
    return {
        {"Content-Type", "text/event-stream; charset=utf-8"},
        {"Cache-Control", "no-cache, no-transform"},
        {"Connection", "keep-alive"},
        {"X-Accel-Buffering", "no"}
    }
end function
