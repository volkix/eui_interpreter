--****
-- == Communicating Sequential Processes (CSP) Channels (std/channel.e)
--
-- Go-style thread-safe communication pipes backed by Java Concurrent Blocking Queues.
-- Allows safe, lock-free data transfer between Virtual Threads.
--

namespace channel

constant
    M_CHANNEL_NEW         = 330,
    M_CHANNEL_SEND        = 331,
    M_CHANNEL_RECEIVE     = 332,
    M_CHANNEL_TRY_SEND    = 333,
    M_CHANNEL_TRY_RECEIVE = 334,
    M_CHANNEL_CLOSE       = 335,
    M_CHANNEL_SIZE        = 336,
    M_CHANNEL_IS_CLOSED   = 337

public constant
    OK       = 1,
    TIMEOUT  = 0,
    CLOSED   = -1

--**
-- Create a new Channel.
-- * ##capacity = 0## creates an unbuffered rendezvous channel (synchronous handoff).
-- * ##capacity > 0## creates a buffered channel with the given queue size.
public function new(integer capacity = 0)
    return machine_func(M_CHANNEL_NEW, capacity)
end function

--**
-- Send a value into the channel.
-- Blocks until space is available or timeout expires.
-- Returns:
-- *  1 (OK): Sent successfully
-- *  0 (TIMEOUT): Timeout expired
-- * -1 (CLOSED): Channel is closed
public function send(atom ch, object val, atom timeout = -1)
    return machine_func(M_CHANNEL_SEND, {ch, val, timeout})
end function

--**
-- Receive a message from the channel.
-- Blocks until a message is available or timeout expires.
-- Returns a 2-element sequence: `{status, value}`
-- * `{1, val}`: Success
-- * `{0, 0}`: Timeout
-- * `{-1, 0}`: Channel is closed
public function receive(atom ch, atom timeout = -1)
    return machine_func(M_CHANNEL_RECEIVE, {ch, timeout})
end function

--**
-- Convenience wrapper: receives and returns the message value directly.
-- Returns ##default_val## if closed or timed out.
public function read(atom ch, object default_val = 0, atom timeout = -1)
    sequence r = receive(ch, timeout)
    if r[1] = OK then
        return r[2]
    else
        return default_val
    end if
end function

--**
-- Non-blocking send. Returns 1 if sent immediately, 0 if queue full, -1 if closed.
public function try_send(atom ch, object val)
    return machine_func(M_CHANNEL_TRY_SEND, {ch, val})
end function

--**
-- Non-blocking receive. Returns `{status, value}` immediately.
public function try_receive(atom ch)
    return machine_func(M_CHANNEL_TRY_RECEIVE, ch)
end function

--**
-- Close a channel. Pending items can still be drained; subsequent sends will fail.
public procedure close(atom ch)
    machine_proc(M_CHANNEL_CLOSE, ch)
end procedure

--**
-- Return the current number of buffered items in the channel.
public function size(atom ch)
    return machine_func(M_CHANNEL_SIZE, ch)
end function

--**
-- Return 1 if the channel has been closed, 0 if open.
public function is_closed(atom ch)
    return machine_func(M_CHANNEL_IS_CLOSED, ch)
end function
