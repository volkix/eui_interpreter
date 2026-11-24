--****
-- == VS-UI Unit Tests (tests/t_vsui.e)
--
-- Tests for Euphorix VS-UI high-density framework (html/).
-- Validates component builders, CSS integration, reactive patches, and server lifecycle.
--

include std/unittest.e
include std/vsui.e as vsui
include std/search.e as search

set_test_verbosity(TEST_SHOW_ALL)

-- 1. Constants & Configuration
test_equal("default static dir points to intpret/html",
           vsui:DEFAULT_STATIC_DIR, "/home/volkix/prj/intpret/html")
test_equal("default port is 8089", vsui:DEFAULT_PORT, 8089)
test_equal("toast types", {vsui:TOAST_INFO, vsui:TOAST_SUCCESS, vsui:TOAST_WARNING, vsui:TOAST_ERROR},
           {"info", "success", "warning", "error"})

-- 2. Page Builder
sequence p = vsui:page("ERP Cockpit", "<h1>Willkommen</h1>", {
    {"container_id", "main_cont"},
    {"head", "<meta name=\"author\" content=\"VS\">"}
})
test_true("page contains HTML5 doctype", match("<!DOCTYPE html>", p) > 0)
test_true("page contains title", match("<title>ERP Cockpit</title>", p) > 0)
test_true("page links to vs.css", match("<link rel=\"stylesheet\" href=\"/css/vs.css\">", p) > 0)
test_true("page links to globalblauklein.css", match("<link rel=\"stylesheet\" href=\"/css/globalblauklein.css\">", p) > 0)
test_true("page includes custom head", match("<meta name=\"author\" content=\"VS\">", p) > 0)
test_true("page has custom container id", match("<div id=\"main_cont\">", p) > 0)
test_true("page includes content", match("<h1>Willkommen</h1>", p) > 0)
test_true("page imports ldom.js module", match("import { e, _, n } from \"/lib2/ldom.js\";", p) > 0)
test_true("page imports vsevent.js module", match("import vsevent from \"/lib2/vsevent.js\";", p) > 0)
test_true("page defines sendVsEvent bridge", match("window.sendVsEvent =", p) > 0)

-- 3. Buttons
sequence b1 = vsui:button("btn_save", "Speichern")
test_true("button tag", match("<button id=\"btn_save\"", b1) > 0)
test_true("button class vs-button", match("class=\"vs-button\"", b1) > 0)
test_true("button default action id", match("data-vs-click=\"btn_save\"", b1) > 0)
test_true("button text", match(">Speichern</button>", b1) > 0)

sequence b2 = vsui:button("btn_del", "Löschen", {
    {"action", "do_delete"},
    {"style", "background: #c0392b; color: white;"},
    {"disabled", "1"},
    {"data-param-artnr", "4711"}
})
test_true("button custom action", match("data-vs-click=\"do_delete\"", b2) > 0)
test_true("button custom style", match("style=\"background: #c0392b; color: white;\"", b2) > 0)
test_true("button disabled", match("disabled", b2) > 0)
test_true("button custom data-param", match("data-param-artnr=\"4711\"", b2) > 0)

-- 4. Form Controls (Input, NumInput, DateInput, TimeInput, Checkbox, TextArea, Combo, Label)
sequence inp = vsui:input("txt_kunde", "Firma Meier", {
    {"placeholder", "Kundenname..."},
    {"readonly", "1"}
})
test_true("input tag and class", match("<input id=\"txt_kunde\" class=\"vs-input\"", inp) > 0)
test_true("input value", match("value=\"Firma Meier\"", inp) > 0)
test_true("input placeholder", match("placeholder=\"Kundenname...\"", inp) > 0)
test_true("input readonly", match("readonly", inp) > 0)

sequence num = vsui:numinput("num_preis", 49.95)
test_true("numinput type number", match("type=\"number\"", num) > 0)
test_true("numinput value", match("value=\"49.95\"", num) > 0)

sequence dinp = vsui:dateinput("dat_faellig", "2026-11-30")
test_true("dateinput type date", match("type=\"date\"", dinp) > 0)
test_true("dateinput value", match("value=\"2026-11-30\"", dinp) > 0)

sequence tinp = vsui:timeinput("tim_start", "08:30")
test_true("timeinput type time", match("type=\"time\"", tinp) > 0)
test_true("timeinput value", match("value=\"08:30\"", tinp) > 0)

sequence chk = vsui:check("chk_aktiv", "Aktiv", 1)
test_true("check type checkbox", match("type=\"checkbox\"", chk) > 0)
test_true("check checked", match("checked", chk) > 0)
test_true("check label", match("<span>Aktiv</span>", chk) > 0)

sequence chk2 = vsui:check("chk_inaktiv", "Gesperrt", 0)
test_true("check unchecked", match("checked", chk2) = 0)

sequence ta = vsui:textarea("txt_memo", "Erste Zeile\nZweite Zeile", 6, {
    {"placeholder", "Notizen eingeben..."}
})
test_true("textarea tag", match("<textarea id=\"txt_memo\" class=\"vs-input\"", ta) > 0)
test_true("textarea rows", match("rows=\"6\"", ta) > 0)
test_true("textarea placeholder", match("placeholder=\"Notizen eingeben...\"", ta) > 0)
test_true("textarea text content", match("Erste Zeile\nZweite Zeile</textarea>", ta) > 0)

sequence cmb = vsui:combo("cmb_status", {
    {"NEW", "Neu eingegangen"},
    {"PRC", "In Bearbeitung"},
    {"FIN", "Abgeschlossen"}
}, "PRC")
test_true("combo tag", match("<select id=\"cmb_status\" class=\"vs-input vs-combo\"", cmb) > 0)
test_true("combo option Neu", match("<option value=\"NEW\">Neu eingegangen</option>", cmb) > 0)
test_true("combo option In Bearbeitung selected", match("<option value=\"PRC\" selected>In Bearbeitung</option>", cmb) > 0)
test_true("combo option Abgeschlossen", match("<option value=\"FIN\">Abgeschlossen</option>", cmb) > 0)

sequence lbl = vsui:ui_label("Kundennummer:", "txt_kdnr")
test_true("label tag", match("<label class=\"vs-label\" for=\"txt_kdnr\">Kundennummer:</label>", lbl) > 0)

-- 5. Layout Components (Group, Panel, Collapse, Grid, Tabs, Modal, Splitter)
sequence grp = vsui:group("Stammdaten", "<p>Stammdaten Felder</p>")
test_true("group fieldset", match("<fieldset class=\"vs-group\"", grp) > 0)
test_true("group legend", match("<legend class=\"vs-legend\"", grp) > 0)
test_true("group text", match("Stammdaten</legend>", grp) > 0)
test_true("group content", match("<p>Stammdaten Felder</p>", grp) > 0)

sequence pnl = vsui:panel("pnl_auftrag", "Auftragsdaten", "<p>Auftrag Pos 1..5</p>")
test_true("panel container", match("<div id=\"pnl_auftrag\" class=\"vs-panel\"", pnl) > 0)
test_true("panel header", match("<div class=\"vs-panel-header\"", pnl) > 0)
test_true("panel header text", match("Auftragsdaten</div>", pnl) > 0)
test_true("panel content", match("<p>Auftrag Pos 1..5</p>", pnl) > 0)

sequence clp = vsui:collapse("col_info", {
    {"Allgemein", "<p>Allgemeine Details</p>", 1},
    {"Historie", "<p>Aktivitätslog</p>", 0}
})
test_true("collapse container", match("<div id=\"col_info\" class=\"vs-collapse\">", clp) > 0)
test_true("collapse details open", match("<details class=\"vscollapsedetail\" open", clp) > 0)
test_true("collapse summary", match("<summary class=\"vscollapsesummary\"", clp) > 0)
test_true("collapse section 1 title", match("Allgemein</summary>", clp) > 0)
test_true("collapse section 2 title", match("Historie</summary>", clp) > 0)

-- vsgrid DataGrid
sequence g = vsui:grid("grd_art", {
    {"ArtNr", "100px"},
    {"Bezeichnung", "250px"},
    {"Einzelpreis", "90px"}
}, {
    {"A001", "Kugelschreiber blau", "1.50 €"},
    {"A002", "Notizblock DIN A4", "2.80 €"},
    {"A003", "Textmarker gelb", "0.95 €"}
})
test_true("grid container", match("<div id=\"grd_art_container\" class=\"vsgrid-container\"", g) > 0)
test_true("grid search input", match("class=\"vs-spreadsheet-search\"", g) > 0)
test_true("grid filter function call", match("oninput=\"filterVsGrid_grd_art(this.value)\"", g) > 0)
test_true("grid sticky table header", match("<table id=\"grd_art_head\" class=\"vs-table-sticky\"", g) > 0)
test_true("grid column header ArtNr", match("<th class=\"vs-thead-th\" style=\"width: 100px;\">ArtNr</th>", g) > 0)
test_true("grid column header Bezeichnung", match("<th class=\"vs-thead-th\" style=\"width: 250px;\">Bezeichnung</th>", g) > 0)
test_true("grid data table", match("<table id=\"grd_art_data\" class=\"vs-table vs-table-responsive\"", g) > 0)
test_true("grid row 1 data", match("Kugelschreiber blau", g) > 0)
test_true("grid row 2 data", match("Notizblock DIN A4", g) > 0)
test_true("grid filter script embedded", match("function filterVsGrid_grd_art(q)", g) > 0)

-- Tabs
sequence tb = vsui:tabs("tb_crm", {
    {"Kunden", "<p>Kundenübersicht</p>"},
    {"Ansprechpartner", "<p>Kontaktliste</p>"}
})
test_true("tabs container", match("<div id=\"tb_crm\" class=\"vs-tabs\">", tb) > 0)
test_true("tabs header Kunden", match("vs-tab-btn active", tb) > 0)
test_true("tabs header Ansprechpartner", match(">Ansprechpartner</button>", tb) > 0)
test_true("tabs pane 1 active", match("<div id=\"tb_crm_pane_1\" class=\"vs-tab-pane active\"", tb) > 0)
test_true("tabs pane 2 hidden", match("<div id=\"tb_crm_pane_2\" class=\"vs-tab-pane\" style=\"display:none;\">", tb) > 0)

-- Modal
sequence mdl = vsui:modal("mdl_confirm", "Bestätigung", "<p>Wirklich löschen?</p>",
                          vsui:button("btn_yes", "Ja, löschen"))
test_true("modal blocker", match("<div id=\"mdl_confirm\" class=\"blocker\"", mdl) > 0)
test_true("modal header title", match("Bestätigung</span>", mdl) > 0)
test_true("modal close button", match("data-vs-close=\"mdl_confirm\"", mdl) > 0)
test_true("modal content", match("<p>Wirklich löschen?</p>", mdl) > 0)
test_true("modal footer button", match("id=\"btn_yes\"", mdl) > 0)

-- Splitter
sequence spl = vsui:splitter("spl_main", "<div>Navigation</div>", "<div>Detailansicht</div>", 30)
test_true("splitter container", match("<div id=\"spl_main\" class=\"vs-splitter-container\"", spl) > 0)
test_true("splitter 30% pane", match("width:30%", spl) > 0)
test_true("splitter 70% pane", match("width:70%", spl) > 0)
test_true("splitter bar", match("class=\"vs-splitter-bar\"", spl) > 0)

-- 6. Reactive Bridge & Patches
sequence p_patch = vsui:patch("status_box", "<span>Erfolgreich geladen</span>")
test_equal("patch structure", p_patch, {{"type", "patch"}, {"id", "status_box"}, {"html", "<span>Erfolgreich geladen</span>"}})

sequence p_append = vsui:append_html("list1", "<li>Neuer Eintrag</li>")
test_equal("append structure", p_append, {{"type", "append"}, {"id", "list1"}, {"html", "<li>Neuer Eintrag</li>"}})

sequence p_set = vsui:set_val("txt_kunde", "Meier & Söhne GmbH")
test_equal("setValue structure", p_set, {{"type", "setValue"}, {"id", "txt_kunde"}, {"val", "Meier & Söhne GmbH"}})

sequence p_toast = vsui:toast_show("Datensatz gespeichert!", vsui:TOAST_SUCCESS, 2500)
test_equal("toast structure", p_toast, {{"type", "toast"}, {"text", "Datensatz gespeichert!"}, {"toast_type", "success"}, {"duration", 2500}})

sequence p_mopen = vsui:modal_open("mdl_confirm")
test_equal("modalOpen structure", p_mopen, {{"type", "modalOpen"}, {"id", "mdl_confirm"}})

sequence p_mclose = vsui:modal_close("mdl_confirm")
test_equal("modalClose structure", p_mclose, {{"type", "modalClose"}, {"id", "mdl_confirm"}})

sequence p_redir = vsui:redirect("/katalog")
test_equal("redirect structure", p_redir, {{"type", "redirect"}, {"url", "/katalog"}})

sequence resp = vsui:updates({p_patch, p_set, p_toast})
test_equal("updates http status", resp[1], 200)
test_true("updates json body contains patch", match("\"type\":\"patch\"", resp[2]) > 0)
test_true("updates json body contains setValue", match("\"type\":\"setValue\"", resp[2]) > 0)
test_true("updates json body contains toast", match("\"type\":\"toast\"", resp[2]) > 0)
test_equal("updates content-type", resp[3], "application/json; charset=utf-8")

-- 7. Value Extraction Helper
sequence form_data = {{"id", "btn_submit"}, {"txt_kunde", "Schulze"}, {"chk_aktiv", "1"}}
test_equal("val helper finds txt_kunde", vsui:val(form_data, "txt_kunde"), "Schulze")
test_equal("val helper finds chk_aktiv", vsui:val(form_data, "chk_aktiv"), "1")
test_equal("val helper default fallback", vsui:val(form_data, "not_found", "standard"), "standard")

-- 8. Application Registration
integer my_app = vsui:app("Test CGIBASH App", 8095)
test_true("app creation id > 0", my_app > 0)

test_report()
