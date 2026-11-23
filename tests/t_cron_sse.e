include std/unittest.e

set_test_verbosity(TEST_SHOW_ALL)
include std/cron.e as cron
include std/sse.e as sse

-- 1. Test Server-Sent Events (SSE)
sequence sse_msg = sse:event("status_update", "Server läuft einwandfrei", "msg_001")
test_true("sse has id", match("id: msg_001\n", sse_msg) > 0)
test_true("sse has event", match("event: status_update\n", sse_msg) > 0)
test_true("sse has data", match("data: Server läuft einwandfrei\n", sse_msg) > 0)

-- Multiline SSE message
sequence multi_sse = sse:event("log", "Zeile 1\nZeile 2\nZeile 3")
test_true("sse multiline has data 1", match("data: Zeile 1\n", multi_sse) > 0)
test_true("sse multiline has data 2", match("data: Zeile 2\n", multi_sse) > 0)
test_true("sse multiline has data 3", match("data: Zeile 3\n", multi_sse) > 0)

sequence sse_hdrs = sse:headers()
test_equal("sse headers count", 4, length(sse_hdrs))
test_equal("sse content-type is text/event-stream", "text/event-stream; charset=utf-8", sse_hdrs[1][2])

-- 2. Test Cron Task Scheduler
integer task_counter = 0

procedure dummy_task()
    task_counter += 1
end procedure

integer job1 = cron:schedule_interval("check_health", 5, routine_id("dummy_task"))
test_true("job1 id > 0", job1 > 0)

integer job2 = cron:schedule_daily("midnight_report", 0, 0, routine_id("dummy_task"))
test_true("job2 id > 0", job2 > 0)

sequence all_jobs = cron:list_jobs()
test_equal("total registered jobs", 2, length(all_jobs))
test_equal("job1 name", "check_health", all_jobs[1][2])
test_equal("job2 name", "midnight_report", all_jobs[2][2])

-- Trigger manually
test_equal("trigger job1 returns 1", 1, cron:trigger_now("check_health"))
test_equal("trigger unknown job returns 0", 0, cron:trigger_now("unbekannter_job"))

test_report()
