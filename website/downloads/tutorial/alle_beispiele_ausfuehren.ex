-- =============================================================================
-- Euphorix Tutorial Suite - Alle 12 Kapitel ausführen
-- Aufruf: ./euphorix tutorial/alle_beispiele_ausfuehren.ex
-- =============================================================================

include std/os.e

constant KAPITEL = {
    "tutorial/01_datenstrukturen.ex",
    "tutorial/02_text_und_regex.ex",
    "tutorial/03_dateisystem_und_io.ex",
    "tutorial/04_mathematik_und_statistik.ex",
    "tutorial/05_datum_und_uhrzeit.ex",
    "tutorial/06_json_und_xml.ex",
    "tutorial/07_datenbanken.ex",
    "tutorial/08_netzwerk_und_web.ex",
    "tutorial/09_nebenlaeufigkeit.ex",
    "tutorial/10_web_und_gui.ex",
    "tutorial/11_system_und_cli.ex",
    "tutorial/12_interop_und_testing.ex"
}

procedure main()
    puts(1, "#####################################################################\n")
    puts(1, "  EUPHORIX TUTORIAL-SUITE: 12 KAPITEL & ALLE STANDARDMODULE\n")
    puts(1, "#####################################################################\n\n")

    for i = 1 to length(KAPITEL) do
        sequence datei = KAPITEL[i]
        sequence cmd = sprintf("./euphorix %s", {datei})
        integer res = system_exec(cmd, 2)
        if res != 0 then
            printf(2, "Fehler beim Ausführen von %s (Exit-Code: %d)\n", {datei, res})
            abort(1)
        end if
        puts(1, "\n---------------------------------------------------------------------\n\n")
    end for

    puts(1, "=====================================================================\n")
    puts(1, "  ALLE 12 TUTORIAL-KAPITEL ERFOLGREICH AUSGEFÜHRT! (100% SUCCESS)\n")
    puts(1, "=====================================================================\n")
end procedure

main()
