--****
-- == OpenEuphoria Swing GUI Demo
--
-- Demonstriert die native Java 25 Swing-Integration in OpenEuphoria.
--

include std/gui.e as gui
include std/text.e
include std/java.e as java

-- 1. Hauptfenster anlegen (620x460)
atom win = gui:window("OpenEuphoria 4.1 GUI Demo (Java 25 Swing & GTK)", 620, 460)
gui:set_layout(win, gui:BORDER_LAYOUT)
gui:set_padding(win, 12, 14, 12, 14)

-- 2. Header Panel (Nord)
atom pnl_top = gui:panel(gui:GRID_LAYOUT, 2, 1, 0, 6)
gui:set_padding(pnl_top, 5, 5, 12, 5)

atom lbl_title = gui:text_label("OpenEuphoria GUI: Native Linux-Oberfläche", gui:ALIGN_CENTER)
gui:set_font(lbl_title, "Ubuntu", 17, 1)

atom lbl_sub = gui:text_label("100% UTF-8 Unterstützung für Umlaute (ä, ö, ü, ß) & moderne Schriftarten", gui:ALIGN_CENTER)
gui:set_font(lbl_sub, "Ubuntu", 12, 0)

gui:add(pnl_top, lbl_title)
gui:add(pnl_top, lbl_sub)
gui:add(win, pnl_top, gui:NORTH)

-- 3. Center Formular Panel
atom pnl_center = gui:panel(gui:GRID_LAYOUT, 5, 2, 14, 12)
gui:set_padding(pnl_center, 10, 15, 10, 15)

atom lbl_name = gui:text_label("Benutzername:")
atom txt_name = gui:text_field("Euphoria Entwickler", 20)

atom lbl_lang = gui:text_label("Bevorzugte Plattform:")
atom cmb_lang = gui:combo_box({"Linux 64-Bit (Höchste Leistung)", "Ubuntu / Debian (Zuverlässig)", "Arch / Fedora (Aktuell)", "Server Headless (Minimal)"})

atom lbl_mode = gui:text_label("Einstellungen:")
atom cb_expert = gui:check_box("Automatische Überprüfung aktivieren", 1)

atom lbl_pbar = gui:text_label("Fortschritt:")
atom pbar = gui:progress_bar(0, 100)
gui:set_value(pbar, 65)

atom lbl_status_title = gui:text_label("Aktueller Status:")
atom lbl_status = gui:text_label("Bereit für Eingaben & Aktionen")
gui:set_font(lbl_status, "Ubuntu", 12, 1)

gui:add(pnl_center, lbl_name)
gui:add(pnl_center, txt_name)
gui:add(pnl_center, lbl_lang)
gui:add(pnl_center, cmb_lang)
gui:add(pnl_center, lbl_mode)
gui:add(pnl_center, cb_expert)
gui:add(pnl_center, lbl_pbar)
gui:add(pnl_center, pbar)
gui:add(pnl_center, lbl_status_title)
gui:add(pnl_center, lbl_status)

gui:add(win, pnl_center, gui:CENTER)

-- 4. Event Handler
integer action_count = 0

procedure on_submit(atom sender)
    action_count += 1
    sequence name = gui:get_text(txt_name)
    integer expert = gui:is_selected(cb_expert)
    
    integer next_val = (action_count * 20)
    if next_val > 100 then next_val = 100 end if
    gui:set_value(pbar, next_val)
    gui:set_text(lbl_status, sprintf("Aktion #%d von '%s' ausgeführt", {action_count, name}))
    
    gui:msgbox("Aktion ausgeführt",
        sprintf("Hallo %s!\n\nDein Euphoria-Callback wurde erfolgreich im Swing Event-Thread verarbeitet!\n\nUmlaute-Test: ä ö ü Ä Ö Ü ß\nAktivierte Aktionen: %d\nErweiterte Optionen: %d", 
        {name, action_count, expert}),
        gui:MSG_INFO)
end procedure

procedure on_file_pick(atom sender)
    sequence path = gui:file_dialog("Datei zur Demonstration auswählen", 0, ".")
    if length(path) > 0 then
        gui:set_text(lbl_status, "Ausgewählt: " & path)
        gui:msgbox("Datei ausgewählt", "Ausgewählter Pfad:\n" & path, gui:MSG_INFO)
    else
        gui:set_text(lbl_status, "Dateiauswahl abgebrochen")
    end if
end procedure

procedure on_quit(atom sender)
    gui:close_window(win)
end procedure

-- 5. Buttons Panel (Süd)
atom pnl_bottom = gui:panel(gui:FLOW_LAYOUT)
gui:set_padding(pnl_bottom, 8, 5, 8, 5)

atom btn_submit = gui:button("Aktion ausführen", routine_id("on_submit"))
atom btn_file   = gui:button("Datei auswählen...", routine_id("on_file_pick"))
atom btn_quit   = gui:button("Schließen",          routine_id("on_quit"))

gui:add(pnl_bottom, btn_submit)
gui:add(pnl_bottom, btn_file)
gui:add(pnl_bottom, btn_quit)
gui:add(win, pnl_bottom, gui:SOUTH)

-- 6. Fenster anzeigen
gui:show(win)

-- Warten bis Fenster geschlossen wird
gui:wait_window(win)
