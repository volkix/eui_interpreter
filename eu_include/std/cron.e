--****
-- == Task Scheduler & Cron Engine for Euphorix (std/cron.e)
--
-- Executes periodic or scheduled background tasks on lightweight Java 25 Virtual Threads.
-- Supports interval timers (e.g. every N seconds/minutes) and daily scheduled jobs
-- at specific wall-clock times (HH:MM).
--

namespace cron

include std/thread.e as thread
include std/datetime.e as dt

-- Job Structure:
-- {id, name, type (1=interval, 2=daily), param (interval_secs or {hour, minute}), routine_id, args, last_run, is_running}
constant
    JOB_ID       = 1,
    JOB_NAME     = 2,
    JOB_TYPE     = 3,
    JOB_PARAM    = 4,
    JOB_RID      = 5,
    JOB_ARGS     = 6,
    JOB_LAST_RUN = 7

public constant
    TYPE_INTERVAL = 1,
    TYPE_DAILY    = 2

sequence jobs = {}
integer scheduler_running = 0
atom scheduler_thread_id = 0
integer next_job_id = 1

--**
-- Schedule a background task to run every `interval_seconds`.
-- Returns unique job ID (> 0).
public function schedule_interval(sequence name, atom interval_seconds, integer routine_id, sequence args = {})
    integer id = next_job_id
    next_job_id += 1
    jobs = append(jobs, {id, name, TYPE_INTERVAL, interval_seconds, routine_id, args, 0})
    return id
end function

--**
-- Schedule a background task to run daily at a specific wall-clock time (`hour`, `minute`).
-- Example: `schedule_daily("nightly_backup", 2, 0, routine_id("run_backup"))` (runs at 02:00)
public function schedule_daily(sequence name, integer hour, integer minute, integer routine_id, sequence args = {})
    integer id = next_job_id
    next_job_id += 1
    jobs = append(jobs, {id, name, TYPE_DAILY, {hour, minute}, routine_id, args, 0})
    return id
end function

-- Internal scheduler loop executing in a dedicated virtual thread
procedure scheduler_worker()
    while scheduler_running do
        atom now_sec = time()
        sequence d_now = date() -- {year, month, day, hour, minute, second, ...}
        integer cur_hour = d_now[4]
        integer cur_minute = d_now[5]

        for i = 1 to length(jobs) do
            sequence job = jobs[i]
            integer should_run = 0

            if job[JOB_TYPE] = TYPE_INTERVAL then
                atom interval = job[JOB_PARAM]
                atom last_run = job[JOB_LAST_RUN]
                if last_run = 0 or (now_sec - last_run) >= interval then
                    should_run = 1
                end if
            elsif job[JOB_TYPE] = TYPE_DAILY then
                sequence target_time = job[JOB_PARAM]
                if cur_hour = target_time[1] and cur_minute = target_time[2] then
                    atom last_run = job[JOB_LAST_RUN]
                    -- Run only once per minute
                    if last_run = 0 or (now_sec - last_run) >= 60 then
                        should_run = 1
                    end if
                end if
            end if

            if should_run then
                jobs[i][JOB_LAST_RUN] = now_sec
                integer rid = job[JOB_RID]
                sequence args = job[JOB_ARGS]
                -- Execute job asynchronously on a fresh virtual thread
                thread:spawn(rid, args)
            end if
        end for

        thread:sleep(1) -- Sleep 1 second between scheduler checks
    end while
end procedure

--**
-- Start the background scheduler.
public procedure start()
    if not scheduler_running then
        scheduler_running = 1
        scheduler_thread_id = thread:spawn(routine_id("scheduler_worker"), {})
    end if
end procedure

--**
-- Stop the background scheduler.
public procedure stop()
    scheduler_running = 0
end procedure

--**
-- Return a list of all registered scheduled jobs.
public function list_jobs()
    return jobs
end function

--**
-- Immediately trigger a job by name once.
public function trigger_now(sequence name)
    for i = 1 to length(jobs) do
        if equal(jobs[i][JOB_NAME], name) then
            jobs[i][JOB_LAST_RUN] = time()
            thread:spawn(jobs[i][JOB_RID], jobs[i][JOB_ARGS])
            return 1
        end if
    end for
    return 0
end function
