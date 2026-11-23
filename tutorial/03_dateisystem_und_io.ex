-- =============================================================================
-- Euphorix Tutorial - Kapitel 3: Dateisystem, I/O & Pipes
-- Behandelte Module: std/io.e, std/filesys.e, std/pipeio.e
-- Ausführen mit: ./euphorix tutorial/03_dateisystem_und_io.ex
-- =============================================================================

include std/io.e
include std/filesys.e
include std/pipeio.e

puts(1, "=====================================================================\n")
puts(1, "  KAPITEL 3: Dateisystem, I/O & Externe Prozesse\n")
puts(1, "=====================================================================\n\n")

-- -----------------------------------------------------------------------------
-- 1. std/io.e - Dateien lesen, schreiben und zeilenweise verarbeiten
-- Komfortable Dateioperationen ohne manuelles Öffnen und Schließen von Handles.
-- -----------------------------------------------------------------------------
puts(1, "--- 1. std/io.e ---\n")
sequence test_pfad = "tutorial_temp.txt"
sequence inhalt = {
    "Server-Name: lighttpd-prod-01",
    "Status: Aktiv",
    "Max-Verbindungen: 1024"
}

-- Zeilen schreiben
write_lines(test_pfad, inhalt)
printf(1, "Datei '%s' mit %d Zeilen geschrieben.\n", {test_pfad, length(inhalt)})

-- Zeilenweise wieder einlesen
sequence gelesene_zeilen = read_lines(test_pfad)
for i = 1 to length(gelesene_zeilen) do
    printf(1, "  [%d] %s\n", {i, gelesene_zeilen[i]})
end for
puts(1, "\n")


-- -----------------------------------------------------------------------------
-- 2. std/filesys.e - Dateisystem-Checks, Pfadoperationen & Verzeichnisse
-- Prüfen von Rechten, Dateigrößen und plattformunabhängige Pfade.
-- -----------------------------------------------------------------------------
puts(1, "--- 2. std/filesys.e ---\n")
printf(1, "Existiert '%s': %d (1 = Ja)\n", {test_pfad, file_exists(test_pfad)})
printf(1, "Dateigröße: %d Bytes\n", {file_length(test_pfad)})

-- Pfade plattformunabhängig verbinden
sequence voller_pfad = join_path({current_dir(), test_pfad})
printf(1, "Vollständiger Pfad: %s\n", {voller_pfad})
printf(1, "Dateiendung: .%s\n", {fileext(test_pfad)})

-- Temporäre Datei wieder sauber aufräumen
delete_file(test_pfad)
printf(1, "Nach Löschen existiert: %d (0 = Nein)\n\n", {file_exists(test_pfad)})


-- -----------------------------------------------------------------------------
-- 3. std/pipeio.e - Externe Subprozesse mit I/O-Pipes anbinden
-- Ausführen von Systemkommandos und Einlesen des Outputs in Echtzeit.
-- -----------------------------------------------------------------------------
puts(1, "--- 3. std/pipeio.e ---\n")
object pipe_process = pipeio:exec("echo 'Euphorix Subprozess-Test'", pipeio:create())
if sequence(pipe_process) then
    sequence ausgabe = pipeio:read(pipe_process[pipeio:STDOUT], 256)
    printf(1, "Gelesene Ausgabe aus Subprozess-Pipe: %s\n", {ausgabe})
    pipeio:close(pipe_process[pipeio:STDOUT])
    pipeio:close(pipe_process[pipeio:STDIN])
    pipeio:close(pipe_process[pipeio:STDERR])
end if
