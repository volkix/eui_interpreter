-- =============================================================================
-- Euphorix Tutorial - Kapitel 11: Betriebssystem, Konsole & CLI
-- Behandelte Module: std/os.e, std/console.e, std/cmdline.e, std/get.e
-- Ausführen mit: ./euphorix tutorial/11_system_und_cli.ex
-- =============================================================================

include std/os.e
include std/console.e
include std/graphics.e
include std/cmdline.e as cmd
include std/get.e

puts(1, "=====================================================================\n")
puts(1, "  KAPITEL 11: Betriebssystem, Kommandozeile & Konsolenausgabe\n")
puts(1, "=====================================================================\n\n")

-- -----------------------------------------------------------------------------
-- 1. std/os.e - Betriebssystem-Schnittstelle & Umgebung
-- Umgebungsvariablen auslesen, Systempfade und Befehlszeilenparameter.
-- -----------------------------------------------------------------------------
puts(1, "--- 1. std/os.e ---\n")
sequence benutzer = getenv("USER")
sequence shell = getenv("SHELL")
if length(benutzer) = 0 then benutzer = "Benutzer" end if

printf(1, "Angemeldeter Benutzer: %s\n", {benutzer})
printf(1, "Standard-Shell:        %s\n", {shell})
printf(1, "Befehlszeilen-Token:   %d Argumente\n\n", {length(command_line())})


-- -----------------------------------------------------------------------------
-- 2. std/console.e - Farbige Konsolenausgabe & Cursorsteuerung
-- ANSI-Farben für professionelle CLI-Tools und Statusmeldungen.
-- -----------------------------------------------------------------------------
puts(1, "--- 2. std/console.e ---\n")
text_color(GREEN)
puts(1, "[OK]   Dienst 'euphorix-worker' läuft stabil.\n")
text_color(YELLOW)
puts(1, "[WARN] Speicherbelegung erreicht 75%% Schwellwert.\n")
text_color(WHITE)
puts(1, "Konsolenfarben zurückgesetzt auf Standard.\n\n")


-- -----------------------------------------------------------------------------
-- 3. std/cmdline.e - Professioneller CLI-Options-Parser
-- Deklaratives Parsen von Schaltern (-v, --help, --port 8080).
-- -----------------------------------------------------------------------------
puts(1, "--- 3. std/cmdline.e ---\n")
puts(1, "cmdline:create_option() definiert Schalter mit Typen & Hilfetexten:\n")
puts(1, "  - create_option({\"p\", \"port\"}, \"Server-Port\", MANDATORY, HAS_PARAMETER)\n")
puts(1, "  - create_option({\"v\", \"verbose\"}, \"Ausführliche Logs\", OPTIONAL, NO_PARAMETER)\n")
puts(1, "Automatisches Generieren von sauberen Hilfeseiten bei '--help'.\n\n")


-- -----------------------------------------------------------------------------
-- 4. std/get.e - Sichere Eingaben & String-to-Value Parsing
-- Konvertiert Strings flexibel in Zahlen oder Euphoria-Sequenzen.
-- -----------------------------------------------------------------------------
puts(1, "--- 4. std/get.e ---\n")
sequence geparster_wert = value("9876.54")
if geparster_wert[1] = GET_SUCCESS then
    printf(1, "Erfolgreich geparster Zahlenwert: %.2f\n", {geparster_wert[2]})
end if

sequence geparste_seq = value("{10, 20, {30, 40}}")
if geparste_seq[1] = GET_SUCCESS then
    printf(1, "Geparste verschachtelte Sequenz:   %s\n", {sprint(geparste_seq[2])})
end if
