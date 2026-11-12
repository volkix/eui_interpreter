-- Concurrency Verification Test: Threads, Async/Await & Channels
include std/thread.e
include std/channel.e
include std/task.e

procedure assert_equal(sequence test_name, object actual, object expected)
    if equal(actual, expected) then
        printf(1, "PASS: %s\n", {test_name})
    else
        printf(1, "FAIL: %s (erwartet: %v, erhalten: %v)\n", {test_name, expected, actual})
        abort(1)
    end if
end procedure

-- =========================================================================
-- 1. Test Async / Await
-- =========================================================================
function compute_square(atom x)
    thread:sleep(0.05)
    return x * x
end function

atom job1 = thread:async(routine_id("compute_square"), {7})
atom job2 = thread:async(routine_id("compute_square"), {12})

object res1 = thread:await(job1)
object res2 = thread:await(job2)

assert_equal("thread:async / await 7^2", res1, 49)
assert_equal("thread:async / await 12^2", res2, 144)

-- Test await_all
atom jA = thread:async(routine_id("compute_square"), {2})
atom jB = thread:async(routine_id("compute_square"), {3})
atom jC = thread:async(routine_id("compute_square"), {4})
sequence all_res = thread:await_all({jA, jB, jC})
assert_equal("thread:await_all {2,3,4}", all_res, {4, 9, 16})

-- =========================================================================
-- 2. Test Channels (Go-Style CSP)
-- =========================================================================
atom ch = channel:new(5) -- buffered channel capacity 5

procedure worker_producer(atom ch_id, sequence prefix, integer count)
    for i = 1 to count do
        channel:send(ch_id, sprintf("%s-%d", {prefix, i}))
    end for
end procedure

atom t1 = thread:spawn(routine_id("worker_producer"), {ch, "Msg", 4})
thread:join(t1)

assert_equal("channel:size after 4 sends", channel:size(ch), 4)

sequence rec1 = channel:receive(ch)
assert_equal("channel:receive 1 status", rec1[1], channel:OK)
assert_equal("channel:receive 1 data", rec1[2], "Msg-1")

object rec2 = channel:read(ch)
assert_equal("channel:read 2", rec2, "Msg-2")

channel:close(ch)
assert_equal("channel:is_closed", channel:is_closed(ch), 1)

-- Drain remaining messages
object rec3 = channel:read(ch)
object rec4 = channel:read(ch)
assert_equal("channel:read 3", rec3, "Msg-3")
assert_equal("channel:read 4", rec4, "Msg-4")

-- Next read on closed empty channel returns default
sequence rec_empty = channel:receive(ch)
assert_equal("channel:receive on closed empty", rec_empty[1], channel:CLOSED)

-- =========================================================================
-- 3. Test Task Virtual Thread
-- =========================================================================
atom ch_task = channel:new(1)
procedure task_worker(atom ch_out)
    thread:sleep(0.02)
    channel:send(ch_out, "TaskThreadOK")
end procedure

atom tid = task:create_thread(routine_id("task_worker"), {ch_task})
object task_msg = channel:read(ch_task)
assert_equal("task:create_thread execution", task_msg, "TaskThreadOK")

puts(1, "--- Alle Nebenläufigkeits-Tests (Async/Await, Channels, Virtual Tasks) erfolgreich bestanden! ---\n")
