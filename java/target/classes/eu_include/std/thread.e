--****
-- == High-Performance Virtual Threads & Async / Await (std/thread.e)
--
-- Powered by Java 25 Virtual Threads (Project Loom).
-- Provides non-blocking, multi-core concurrency, fire-and-forget / joinable threads,
-- and lightweight Async/Await Futures without manual lock synchronization.
--

namespace thread

constant
    M_THREAD_SPAWN   = 320,
    M_THREAD_ASYNC   = 321,
    M_THREAD_AWAIT   = 322,
    M_THREAD_IS_DONE = 323,
    M_THREAD_JOIN    = 324,
    M_THREAD_SLEEP   = 325,
    M_THREAD_CURRENT = 326,
    M_THREAD_CANCEL  = 327

--**
-- Start an independent background task on a lightweight Java 25 Virtual Thread.
-- Returns the unique thread ID (> 0).
public function spawn(integer routine_id, sequence args = {})
    return machine_func(M_THREAD_SPAWN, {routine_id, args})
end function

--**
-- Run a function asynchronously in the background and return a Job / Future handle.
-- The return value of the function can later be retrieved via [[:await]].
public function async(integer routine_id, sequence args = {})
    return machine_func(M_THREAD_ASYNC, {routine_id, args})
end function

--**
-- Wait for an asynchronous job to finish and return its result value.
-- If ##timeout## is negative (-1), waits indefinitely.
-- If ##timeout## is positive, returns "TIMEOUT" if not finished within that time.
public function await(atom job_id, atom timeout = -1)
    return machine_func(M_THREAD_AWAIT, {job_id, timeout})
end function

--**
-- Check whether an asynchronous job has finished without blocking.
-- Returns 1 if completed, 0 if still running.
public function is_done(atom job_id)
    return machine_func(M_THREAD_IS_DONE, job_id)
end function

--**
-- Wait for a list of asynchronous jobs to complete and return a sequence of their results.
public function await_all(sequence job_ids, atom timeout = -1)
    sequence results = repeat(0, length(job_ids))
    for i = 1 to length(job_ids) do
        results[i] = await(job_ids[i], timeout)
    end for
    return results
end function

--**
-- Wait for an independent thread to terminate.
-- Returns 1 if the thread has finished, 0 if timeout expired.
public function join(atom thread_id, atom timeout = 0)
    return machine_func(M_THREAD_JOIN, {thread_id, timeout})
end function

--**
-- Pause the current Virtual Thread non-blockingly for ##seconds##.
-- Other virtual threads continue running with zero performance degradation.
public procedure sleep(atom seconds)
    machine_proc(M_THREAD_SLEEP, seconds)
end procedure

--**
-- Return the integer ID of the currently executing thread.
public function current()
    return machine_func(M_THREAD_CURRENT, 0)
end function

--**
-- Cancel an active async job or interrupt a running virtual thread.
public procedure cancel(atom job_or_thread_id)
    machine_proc(M_THREAD_CANCEL, job_or_thread_id)
end procedure
