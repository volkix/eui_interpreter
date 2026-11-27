-- Unit Tests für std/vstui.e (Moderne Vollbild-TUI Engine 100vw x 100vh)

include std/unittest.e
include std/vstui.e as tui
include std/search.e

set_test_verbosity(TEST_SHOW_ALL)

-- 1. Puffer-Dimensionen & Erstellung
sequence scr = tui:create(126, 36, "Test TUI")
test_equal("tui width is 126", scr[1], 126)
test_equal("tui height is 36", scr[2], 36)
test_equal("tui lines count", length(scr[3]), 36)
test_equal("tui line cols count", length(scr[3][1]), 126)

-- 2. Deutsche Währungs- und Zahlenformatierung (wie vsnuminput)
test_equal("format_num_de 14250.50", tui:format_num_de(14250.50, 2, "€"), "14.250,50 €")
test_equal("format_num_de negative", tui:format_num_de(-890.00, 2, "€"), "-890,00 €")
test_equal("format_num_de integer", tui:format_num_de(1000000, 0, ""), "1.000.000")
test_equal("parse_num_de 14.250,50 €", tui:parse_num_de("14.250,50 €"), 14250.50)
test_equal("parse_num_de negative", tui:parse_num_de("-890,00 €"), -890.00)
test_equal("parse_num_de simple", tui:parse_num_de("18500"), 18500)

-- 3. Kastenrahmen & Geometrie
scr = tui:box(scr, 2, 2, 50, 10, "Kundenkarte", tui:C_BORDER, tui:C_BG_PANEL)
test_equal("box top-left corner", scr[3][2][2][1], "┌")
test_equal("box top-right corner", scr[3][2][51][1], "┐")
test_equal("box bot-left corner", scr[3][11][2][1], "└")
test_equal("box bot-right corner", scr[3][11][51][1], "┘")

-- 4. Modul-Tabs
scr = tui:draw_tabs(scr, {{"Kunden", "tab_1"}, {"Aufträge", "tab_2"}}, 1, 2, 13, 100)
test_equal("tab 1 active background", scr[3][13][3][3], tui:C_SEL_BG)

-- 5. KPI-Stat-Cards
sequence cards = {{"Umsatz", "142.500 €", "+12%", 1}, {"Kunden", "5", "+1", 1}}
scr = tui:draw_kpi_cards(scr, cards, 2, 15, 100)
test_equal("kpi card 1 corner", scr[3][15][2][1], "┌")

-- 6. Formularfelder (Eingabe, Numerisch, Datum, Zeit, Combo, Checkbox, Textarea)
scr = tui:draw_input(scr, "txt_name", "Name:", "Schulze GmbH", 5, 20, 20)
scr = tui:draw_numinput(scr, "num_val", "Betrag:", 14250.50, 2, "€", 35, 20, 16)
scr = tui:draw_dateinput(scr, "dt_val", "Datum:", "2026-11-27", 5, 22, 14)
scr = tui:draw_timeinput(scr, "tm_val", "Zeit:", "14:30", 30, 22, 10)
scr = tui:draw_combo(scr, "cmb_kat", "Kategorie:", "A-Kunde", 5, 24, 18)
scr = tui:draw_checkbox(scr, "chk_act", "Aktiv", 1, 5, 26)
scr = tui:draw_textarea(scr, "txa_notiz", "Notiz", {"Zeile 1", "Zeile 2"}, 5, 28, 40, 4)

sequence html_fields = tui:render_patch(scr)
test_true("patch contains native text input", search:match("id=\"txt_name\"", html_fields) > 0)
test_true("patch contains native numinput", search:match("class=\"vstui-input vstui-numinput\" id=\"num_val\"", html_fields) > 0)
test_true("patch contains native combo input", search:match("class=\"vstui-input vstui-combo\" id=\"cmb_kat\"", html_fields) > 0)

-- 7. Buttons (Speichern, Löschen)
scr = tui:draw_button(scr, "btn_save", "Speichern", 5, 33, "primary")
scr = tui:draw_button(scr, "btn_del", "Löschen", 20, 33, "danger")

-- 7b. 3-zeilige Buttons (h = 3, Block- & Rahmen-Stil)
sequence btn_scr = tui:create(50, 10)
btn_scr = tui:draw_button(btn_scr, "btn_multiline", "Hauptaktion", 5, 2, "primary", 20, 3, "[Strg+S]")
sequence btn_patch = tui:render_patch(btn_scr)
test_true("multiline button has label in center row", search:match("Hauptaktion", btn_patch) > 0)
test_true("multiline button has subtitle in row 3", search:match("[Strg+S]", btn_patch) > 0)

sequence framed_scr = tui:create(50, 10)
framed_scr = tui:draw_button(framed_scr, "btn_framed", "Abbrechen", 5, 2, "framed", 15, 3)
sequence framed_patch = tui:render_patch(framed_scr)
test_true("framed button has top border", search:match("┌", framed_patch) > 0)
test_true("framed button has text row", search:match("Abbrechen", framed_patch) > 0)
test_true("framed button has bottom border", search:match("└", framed_patch) > 0)

-- 8. Diagramm & Toast & Modal & Bild
scr = tui:draw_barchart(scr, "ch_sales", "Umsatz", {"Q1", "Q2"}, {1000, 2500}, 50, 20, 50, 8)
sequence ch_patch = tui:render_patch(scr)
test_true("barchart contains solid unicode block", search:match("█", ch_patch) > 0)
test_false("barchart does not contain question mark replacement", search:match("&#65533;", ch_patch) > 0)

scr = tui:draw_image(scr, "img_logo", "/img/vsitsolutions.jpeg", 2, 2, 20, 5, "Logo", "contain")
sequence img_patch = tui:render_patch(scr)
test_true("patch contains native image element", search:match("class=\"vstui-image\" id=\"img_logo\"", img_patch) > 0)
test_true("patch image src correct", search:match("src=\"/img/vsitsolutions.jpeg\"", img_patch) > 0)

-- 8b. Viewport-Scrolling & TUI Scrollbar in Table
sequence big_rows = {}
for i = 1 to 50 do
    big_rows = append(big_rows, {sprintf("K-%d", {i}), sprintf("Kunde %d", {i}), "Stadt", "1.000 €", "A-Kunde"})
end for
sequence table_scr = tui:create(100, 20)
table_scr = tui:draw_table(table_scr, "grd_test", {{"ID", 10}, {"Name", 20}, {"Ort", 10}, {"Umsatz", 12}, {"Status", 10}}, big_rows, 2, 2, 90, 16, 25)
sequence tbl_patch = tui:render_patch(table_scr)
test_true("table contains scroll up button", search:match("▲", tbl_patch) > 0)
test_true("table contains scroll down button", search:match("▼", tbl_patch) > 0)
test_true("table contains row counter in frame", search:match("25/50", tbl_patch) > 0)
test_true("table scrolled to selected row 25", search:match("Kunde 25", tbl_patch) > 0)

scr = tui:draw_toast(scr, "Erfolgreich gespeichert!", "success")
scr = tui:draw_modal(scr, "win_dlg", "Bestätigung", {"Wirklich löschen?"}, {{"ok", "Ja"}, {"cancel", "Nein"}})

-- 8c. TUI Kalender-Modal (Datumsauswahl) in 2. Screenebene
sequence cal_scr = tui:create(100, 25)
cal_scr = tui:print_at(cal_scr, 10, 10, "Basisfeld unverändert", tui:C_TEXT, tui:C_BG_PAGE)
cal_scr = tui:draw_calendar_modal(cal_scr, "f_datum", 2026, 11, 27)
sequence cal_patch = tui:render_patch(cal_scr)
test_true("cal patch contains modal overlay container", search:match("vstui-modal-overlay", cal_patch) > 0)
test_true("cal patch contains modal window", search:match("vstui-modal-window", cal_patch) > 0)
test_true("base screen cell intact under overlay", search:match("Basisfeld unverändert", cal_patch) > 0)
test_true("cal patch contains November 2026", search:match("November 2026", cal_patch) > 0)
test_true("cal patch contains weekday Mo", search:match("Mo", cal_patch) > 0)
test_true("cal patch highlights day 27", search:match("[27]", cal_patch) > 0)
test_true("cal patch contains Heute button", search:match("cal_btn_today", cal_patch) > 0)
test_true("cal patch contains Übernehmen button", search:match("cal_btn_apply", cal_patch) > 0)
test_true("cal patch contains Abbrechen button", search:match("cal_btn_cancel", cal_patch) > 0)

-- 9. HTML Rendering (100vw x 100vh)
sequence html = tui:render_page(scr, "VS-TUI Test")
test_true("html contains 100vw", search:match("100vw", html) > 0)
test_true("html contains 100vh", search:match("100vh", html) > 0)
test_true("html contains collectFormData", search:match("collectFormData", html) > 0)
test_true("html contains JetBrains Mono or modern font", search:match("DejaVu Sans Mono", html) > 0)
test_false("html does not contain F-key listeners", search:match("fKeyMatch", html) > 0)
test_true("html contains wheel scrolling listener", search:match("wheel_up", html) > 0)
test_true("patch does not contain newline gap", search:match("\n", tui:render_patch(scr)) = 0)

test_report()
