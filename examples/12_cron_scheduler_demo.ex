-- ==============================================================================
-- Euphorix 1.0 Demo: Cron Task Scheduler & Server-Sent Events (SSE)
-- ==============================================================================

include std/console.e
include std/cron.e as cron
include std/sse.e as sse
include std/thread.e as thread

puts(1, "=====================================================================\n")
puts(1, "  Euphorix Background Tasks (Cron) & Realtime SSE Demo\n")
puts(1, "=====================================================================\n\n")

-- 1. Server-Sent Events (SSE) Formatierung
puts(1, "1) Server-Sent Events (SSE) Streaming-Nachrichten:\n")
sequence msg1 = sse:event("system_status", `{"cpu": 12.4, "memory_mb": 512, "status": "healthy"}`, "evt_101")
puts(1, "   SSE-Nachricht (Browser Event-Stream):\n")
puts(1, "   ----------------------------------------\n")
puts(1, msg1)
puts(1, "   ----------------------------------------\n\n")

-- 2. Cron Task Scheduler
puts(1, "2) Hintergrund-Scheduler mit Java 25 Virtual Threads:\n")

integer execution_counter = 0

procedure job_cleanup()
    execution_counter += 1
    printf(1, "   [CRON-EVENT] Job 'cleanup_cache' ausgeführt (Durchlauf #%d)\n", {execution_counter})
end procedure

procedure job_backup()
    puts(1, "   [CRON-EVENT] Täglicher Backup-Job gestartet.\n")
end procedure

integer id1 = cron:schedule_interval("cleanup_cache", 2, routine_id("job_cleanup"))
integer id2 = cron:schedule_daily("daily_backup", 3, 30, routine_id("job_backup"))

printf(1, "   ✓ 2 Aufgaben registriert: Job #%d (alle 2s) und Job #%d (täglich 03:30 Uhr).\n", {id1, id2})
puts(1, "   Starte Scheduler im Hintergrund für 5 Sekunden...\n\n")

cron:start()
thread:sleep(5)
cron:stop()

puts(1, "\n   ✓ Scheduler gestoppt.\n\n")
puts(1, "=== Demo erfolgreich beendet! ===\n")
