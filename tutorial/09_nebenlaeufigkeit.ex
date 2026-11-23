-- =============================================================================
-- Euphorix Tutorial - Kapitel 9: Nebenläufigkeit, Threads & CSP-Channels
-- Behandelte Module: std/channel.e, std/thread.e, std/task.e
-- Ausführen mit: ./euphorix tutorial/09_nebenlaeufigkeit.ex
-- =============================================================================

include std/channel.e as chan
include std/thread.e as thread
include std/task.e as task

puts(1, "=====================================================================\n")
puts(1, "  KAPITEL 9: Java 25 Loom Virtual Threads & CSP Channels\n")
puts(1, "=====================================================================\n\n")

-- -----------------------------------------------------------------------------
-- 1. std/thread.e - Java 25 Loom Virtual Threads & Async / Await
-- Skalierbare Hintergrund-Jobs ohne OS-Thread-Limitierungen.
-- -----------------------------------------------------------------------------
puts(1, "--- 1. std/thread.e ---\n")

function rechenaufgabe(atom n)
    atom summe = 0
    for i = 1 to n do
        summe += i
    end for
    return summe
end function

-- Asynchrone Jobs starten
atom job1 = thread:async(routine_id("rechenaufgabe"), {1000})
atom job2 = thread:async(routine_id("rechenaufgabe"), {5000})

-- Auf Ergebnisse warten (Await)
atom erg1 = thread:await(job1)
atom erg2 = thread:await(job2)

printf(1, "Ergebnis Job 1 (Summe 1..1000): %.0f\n", {erg1})
printf(1, "Ergebnis Job 2 (Summe 1..5000): %.0f\n\n", {erg2})


-- -----------------------------------------------------------------------------
-- 2. std/channel.e - Communicating Sequential Processes (CSP Channels wie in Go)
-- Sperrfreie, threadsichere Kommunikation zwischen parallelen Prozessen.
-- -----------------------------------------------------------------------------
puts(1, "--- 2. std/channel.e ---\n")
integer postfach = chan:new(5) -- Puffer für bis zu 5 Nachrichten

-- Nachrichten senden
chan:send(postfach, {"AUFTRAG", 101, "PDF Rechnung erzeugen"})
chan:send(postfach, {"AUFTRAG", 102, "E-Mail Bestätigung senden"})
printf(1, "Nachrichten im Channel gepuffert: %d\n", {chan:size(postfach)})

-- Nachrichten abholen mit chan:read()
object nachricht1 = chan:read(postfach)
object nachricht2 = chan:read(postfach)

printf(1, "Abgeholt 1: [%s] #%d -> %s\n", {nachricht1[1], nachricht1[2], nachricht1[3]})
printf(1, "Abgeholt 2: [%s] #%d -> %s\n", {nachricht2[1], nachricht2[2], nachricht2[3]})

chan:close(postfach)
printf(1, "Channel nach Verarbeitung geschlossen: %d\n\n", {chan:is_closed(postfach)})


-- -----------------------------------------------------------------------------
-- 3. std/task.e - Kooperatives Multitasking
-- Deterministische Coroutinen für zeitgesteuerte Arbeitsabläufe.
-- -----------------------------------------------------------------------------
puts(1, "--- 3. std/task.e ---\n")
puts(1, "Kooperative Tasks über task_create(), task_schedule() und task_yield().\n")
puts(1, "Ideal für zustandsbehaftete Agenten, Simulationsschleifen und Parser.\n")
