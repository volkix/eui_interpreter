--****
-- == SAP UI5 Web Components Unit & Integration Tests (tests/t_ui5.e)
--
-- Tests component rendering, HTML escaping, horizon themes,
-- client-server bridge updates, and full page creation.
--

include std/unittest.e
include std/ui5.e as ui5
include std/search.e as search

set_test_verbosity(TEST_SHOW_ALL)

-- 1. Page & Version Configuration
test_equal("default version is 2.29.0", ui5:DEFAULT_VERSION, "2.29.0")
test_equal("default theme is sap_horizon", ui5:THEME_HORIZON, "sap_horizon")

sequence my_page = ui5:page("Test Dashboard", "<p>Inhalt</p>", {
    {"theme", ui5:THEME_HORIZON_DARK},
    {"version", "2.29.0"}
})
test_true("page contains DOCTYPE", match("<!DOCTYPE html>", my_page) > 0)
test_true("page contains title", match("<title>Test Dashboard</title>", my_page) > 0)
test_true("page sets dark theme config", match("\"theme\": \"sap_horizon_dark\"", my_page) > 0)
test_true("page includes UI5 v2.29 webcomponents script",
          match("@ui5/webcomponents@2.29.0/dist/webcomponents.min.js", my_page) > 0)
test_true("page includes UI5 fiori v2.29 script",
          match("@ui5/webcomponents-fiori@2.29.0/dist/webcomponents-fiori.min.js", my_page) > 0)
test_true("page includes UI5 icons v2.29 script",
          match("@ui5/webcomponents-icons@2.29.0/dist/AllIcons.js", my_page) > 0)
test_true("page includes euphorixUI5 bridge runtime",
          match("window.euphorixUI5", my_page) > 0)

-- 2. ShellBar Rendering
sequence sb = ui5:shellbar("Meine Firma", "ERP Dashboard", {
    {"profile", "VS"},
    {"notifications", "1"},
    {"co_pilot", "1"}
})
test_true("shellbar tag", match("<ui5-shellbar", sb) > 0)
test_true("shellbar primary title", match("primary-title=\"Meine Firma\"", sb) > 0)
test_true("shellbar secondary title", match("secondary-title=\"ERP Dashboard\"", sb) > 0)
test_true("shellbar avatar initials", match("initials=\"VS\"", sb) > 0)
test_true("shellbar notifications", match("show-notifications", sb) > 0)
test_true("shellbar co-pilot", match("show-co-pilot", sb) > 0)

-- 3. Card Rendering
sequence card_html = ui5:card("Offene Bestellungen", "<p>3 Bestellungen</p>", {
    {"subtitle", "Status: Aktiv"},
    {"status", "3 Items"},
    {"icon", "order-status"}
})
test_true("card tag", match("<ui5-card", card_html) > 0)
test_true("card header slot", match("<ui5-card-header slot=\"header\"", card_html) > 0)
test_true("card title", match("title-text=\"Offene Bestellungen\"", card_html) > 0)
test_true("card subtitle", match("subtitle-text=\"Status: Aktiv\"", card_html) > 0)
test_true("card status", match("status=\"3 Items\"", card_html) > 0)
test_true("card avatar icon", match("<ui5-icon name=\"order-status\" slot=\"avatar\"", card_html) > 0)

-- 4. Table Rendering
sequence cols = {{"Artikel-Nr.", "120px"}, {"Bezeichnung", ""}, {"Menge", "80px"}}
sequence rows = {
    {"#1001", "SSD NVMe 2TB", "15"},
    {"#1002", "DDR5 RAM 64GB", "4"}
}
sequence tbl = ui5:table(cols, rows, {{"id", "tbl_items"}})
test_true("table tag", match("<ui5-table id=\"tbl_items\"", tbl) > 0)
test_true("table column 1", match("slot=\"columns\" style=\"width: 120px;\"><span>Artikel-Nr.</span>", tbl) > 0)
test_true("table column 2", match("slot=\"columns\"><span>Bezeichnung</span>", tbl) > 0)
test_true("table row 1 data", match("<span>SSD NVMe 2TB</span>", tbl) > 0)
test_true("table row 2 data", match("<span>DDR5 RAM 64GB</span>", tbl) > 0)

-- 5. Button & Form Inputs
sequence btn = ui5:button("btn_save", "Speichern", {
    {"design", ui5:DESIGN_EMPHASIZED},
    {"icon", "save"},
    {"action", "on_save_item"},
    {"data-param-entity", "order"}
})
test_true("button tag", match("<ui5-button id=\"btn_save\"", btn) > 0)
test_true("button design emphasized", match("design=\"Emphasized\"", btn) > 0)
test_true("button icon save", match("icon=\"save\"", btn) > 0)
test_true("button action attribute", match("data-ui5-action=\"on_save_item\"", btn) > 0)
test_true("button extra param", match("data-param-entity=\"order\"", btn) > 0)
test_true("button text", match(">Speichern</ui5-button>", btn) > 0)

sequence inp = ui5:input("user_email", "admin@firma.de", {
    {"placeholder", "E-Mail..."},
    {"type", "Email"},
    {"value_state", ui5:STATE_SUCCESS}
})
test_true("input tag", match("<ui5-input id=\"user_email\"", inp) > 0)
test_true("input value", match("value=\"admin@firma.de\"", inp) > 0)
test_true("input placeholder", match("placeholder=\"E-Mail...\"", inp) > 0)
test_true("input state success", match("value-state=\"Success\"", inp) > 0)

sequence sw = ui5:switch_btn("sw_active", "Aktiv", "Inaktiv", 1)
test_true("switch tag", match("<ui5-switch id=\"sw_active\"", sw) > 0)
test_true("switch checked", match("checked", sw) > 0)
test_true("switch text on", match("text-on=\"Aktiv\"", sw) > 0)

sequence sel = ui5:select("sel_prio", {
    {"low", "Niedrig", 0},
    {"high", "Dringend", 1}
})
test_true("select tag", match("<ui5-select id=\"sel_prio\">", sel) > 0)
test_true("select option low", match("<ui5-option value=\"low\">Niedrig</ui5-option>", sel) > 0)
test_true("select option high selected", match("<ui5-option value=\"high\" selected>Dringend</ui5-option>", sel) > 0)

sequence dp = ui5:datepicker("dp_deadline", "2026-12-31")
test_true("datepicker tag", match("<ui5-datepicker id=\"dp_deadline\"", dp) > 0)
test_true("datepicker value", match("value=\"2026-12-31\"", dp) > 0)

-- 6. Dialog & Toast & Badges
sequence dlg = ui5:dialog("dlg_edit", "Eintrag bearbeiten", "<p>Formular...</p>",
                          ui5:button("btn_ok", "OK"))
test_true("dialog tag", match("<ui5-dialog id=\"dlg_edit\"", dlg) > 0)
test_true("dialog header", match("header-text=\"Eintrag bearbeiten\"", dlg) > 0)
test_true("dialog footer slot", match("slot=\"footer\"", dlg) > 0)

sequence tst = ui5:toast("toast_saved", "Erfolgreich gespeichert!", 4000)
test_true("toast tag", match("<ui5-toast id=\"toast_saved\" duration=\"4000\">Erfolgreich gespeichert!</ui5-toast>", tst) > 0)

sequence bdg = ui5:badge("In Bearbeitung", 8)
test_true("badge tag", match("<ui5-badge color-scheme=\"8\">In Bearbeitung</ui5-badge>", bdg) > 0)

sequence prog = ui5:progress_indicator(75, "75% abgeschlossen", ui5:STATE_INFORMATION)
test_true("progress indicator value", match("value=\"75\"", prog) > 0)
test_true("progress indicator text", match("display-value=\"75% abgeschlossen\"", prog) > 0)

-- 7. Reactive Bridge Responses
sequence resp_patch = ui5:updates({
    ui5:patch("content_area", "<b>Aktualisiert!</b>"),
    ui5:set_val("user_email", "neu@firma.de"),
    ui5:toast_show("toast_saved", "Neu geladen"),
    ui5:open_dialog("dlg_edit")
})
test_equal("bridge response status is 200", resp_patch[1], 200)
test_equal("bridge content-type is json", resp_patch[3], "application/json; charset=utf-8")
test_true("response json contains patch type", match("\"type\":\"patch\"", resp_patch[2]) > 0)
test_true("response json contains target id", match("\"id\":\"content_area\"", resp_patch[2]) > 0)
test_true("response json contains setValue", match("\"type\":\"setValue\"", resp_patch[2]) > 0)
test_true("response json contains toast", match("\"type\":\"toast\"", resp_patch[2]) > 0)
test_true("response json contains dialogOpen", match("\"type\":\"dialogOpen\"", resp_patch[2]) > 0)

-- 8. Application creation & context value helper
integer my_app = ui5:app("Warenwirtschaft", 9090, ui5:THEME_HORIZON, "2.29.0")
test_true("app created with valid handle", my_app > 0)

sequence sample_ctx = {{"name", "Volker"}, {"count", "42"}}
test_equal("val helper finds existing key", ui5:val(sample_ctx, "name"), "Volker")
test_equal("val helper finds count key", ui5:val(sample_ctx, "count"), "42")
test_equal("val helper returns default for missing key", ui5:val(sample_ctx, "missing", "default"), "default")

-- 9. Extended Component Catalog (UI5 v2.29)
sequence t_title = ui5:title("Übersicht", ui5:TITLE_H1)
test_true("title tag and level H1", match("<ui5-title level=\"H1\">Übersicht</ui5-title>", t_title) > 0)

sequence t_lbl = ui5:ui_label("Kundennummer", "inp_kdnr", 1)
test_true("label tag and required", match("<ui5-label for=\"inp_kdnr\" required>Kundennummer</ui5-label>", t_lbl) > 0)

sequence t_lnk = ui5:link("SAP Dokumentation", "https://sap.github.io/ui5-webcomponents/", ui5:LINK_EMPHASIZED)
test_true("link tag and design", match("<ui5-link href=\"https://sap.github.io/ui5-webcomponents/\" design=\"Emphasized\">SAP Dokumentation</ui5-link>", t_lnk) > 0)

sequence t_tog = ui5:toggle_button("btn_pin", "Anheften", 1, {{"icon", "hint"}})
test_true("toggle button pressed", match("<ui5-toggle-button id=\"btn_pin\" design=\"Default\" pressed icon=\"hint\">Anheften</ui5-toggle-button>", t_tog) > 0)

sequence t_seg = ui5:segmented_button("seg_view", {{"v_day", "Tag", 1}, {"v_week", "Woche", 0}, {"v_month", "Monat", 0}})
test_true("segmented button tag", match("<ui5-segmented-button id=\"seg_view\">", t_seg) > 0)
test_true("segmented button item selected", match("<ui5-segmented-button-item id=\"v_day\" selected>Tag</ui5-segmented-button-item>", t_seg) > 0)

sequence t_step = ui5:step_input("num_qty", 5, 1, 50, 1)
test_true("step input tag and attributes", match("<ui5-step-input id=\"num_qty\" value=\"5\" min=\"1\" max=\"50\" step=\"1\"", t_step) > 0)

sequence t_sld = ui5:slider("sld_pct", 40, 0, 100, 5)
test_true("slider tag and values", match("<ui5-slider id=\"sld_pct\" value=\"40\" min=\"0\" max=\"100\" step=\"5\"", t_sld) > 0)

sequence t_rsld = ui5:range_slider("rsld_range", 25, 75, 0, 100, 5)
test_true("range slider tag and values", match("<ui5-range-slider id=\"rsld_range\" start-value=\"25\" end-value=\"75\"", t_rsld) > 0)

sequence t_rate = ui5:rating_indicator("rate_stars", 4.5, 5)
test_true("rating indicator tag", match("<ui5-rating-indicator id=\"rate_stars\" value=\"4.5\" max=\"5\">", t_rate) > 0)

sequence t_rad = ui5:radio_button("rb_express", "shipping_type", "Expresslieferung", "express", 1)
test_true("radio button checked", match("<ui5-radio-button id=\"rb_express\" name=\"shipping_type\" text=\"Expresslieferung\" value=\"express\" checked>", t_rad) > 0)

sequence t_cb = ui5:combobox("cb_city", "Berlin", {{"Berlin", "Hauptstadt"}, {"München", "Bayern"}})
test_true("combobox tag", match("<ui5-combobox id=\"cb_city\" value=\"Berlin\"", t_cb) > 0)
test_true("combobox item", match("<ui5-cb-item text=\"Berlin\" additional-text=\"Hauptstadt\"></ui5-cb-item>", t_cb) > 0)

sequence t_mcb = ui5:multi_combobox("mcb_tags", {{"Java", 1}, {"Euphoria", 1}, {"TypeScript", 0}})
test_true("multi combobox item selected", match("<ui5-mcb-item text=\"Java\" selected></ui5-mcb-item>", t_mcb) > 0)

sequence t_time = ui5:time_picker("tp_start", "08:30:00")
test_true("time picker tag", match("<ui5-time-picker id=\"tp_start\" value=\"08:30:00\"", t_time) > 0)

sequence t_dt = ui5:datetime_picker("dtp_meeting", "2026-11-20T14:00")
test_true("datetime picker tag", match("<ui5-datetime-picker id=\"dtp_meeting\" value=\"2026-11-20T14:00\">", t_dt) > 0)

sequence t_dr = ui5:daterange_picker("drp_period", "2026-11-01 - 2026-11-30")
test_true("daterange picker tag", match("<ui5-daterange-picker id=\"drp_period\" value=\"2026-11-01 - 2026-11-30\">", t_dr) > 0)

sequence t_list = ui5:list({{"Task 1", "Dringend", "alert", "Heute"}, {"Task 2", "Erledigt", "accept", "Gestern"}}, {{"header", "Aufgaben"}})
test_true("list tag", match("<ui5-list header-text=\"Aufgaben\">", t_list) > 0)
test_true("list item attributes", match("<ui5-li description=\"Dringend\" icon=\"alert\" additional-text=\"Heute\">Task 1</ui5-li>", t_list) > 0)

sequence t_tabs = ui5:tab_container({{"Allgemein", "<p>Stammdaten</p>", "hint", 1}, {"Posten", "<p>Positionen</p>", "activity-items", 0}})
test_true("tabcontainer tag", match("<ui5-tabcontainer>", t_tabs) > 0)
test_true("tab item selected", match("<ui5-tab text=\"Allgemein\" icon=\"hint\" selected>", t_tabs) > 0)

sequence t_bc = ui5:breadcrumbs({{"Home", "/"}, {"Vertrieb", "/sales"}, {"Aufträge", "/sales/orders"}})
test_true("breadcrumbs item", match("<ui5-breadcrumbs-item href=\"/sales/orders\">Aufträge</ui5-breadcrumbs-item>", t_bc) > 0)

sequence t_bar = ui5:bar("<b>Links</b>", "<i>Mitte</i>", "<button>Rechts</button>", ui5:BAR_HEADER)
test_true("bar design", match("<ui5-bar design=\"Header\">", t_bar) > 0)
test_true("bar start slot", match("<div slot=\"startContent\"><b>Links</b></div>", t_bar) > 0)

sequence t_av = ui5:avatar("VS", ui5:AVATAR_L, ui5:AVATAR_CIRCLE)
test_true("avatar tag and attributes", match("<ui5-avatar initials=\"VS\" size=\"L\" shape=\"Circle\"></ui5-avatar>", t_av) > 0)

sequence t_busy = ui5:busy_indicator(1, ui5:BUSY_MEDIUM, "Lade Daten...")
test_true("busy indicator active", match("<ui5-busy-indicator size=\"Medium\" active text=\"Lade Daten...\">", t_busy) > 0)

sequence t_tl = ui5:timeline({{"Auftrag erteilt", "2026-11-19 10:00", "accept", "Max Mustermann"}})
test_true("timeline item", match("<ui5-timeline-item title-text=\"Auftrag erteilt\" subtitle-text=\"2026-11-19 10:00\"", t_tl) > 0)

sequence t_tag = ui5:tag("Freigegeben", 8)
test_true("tag element", match("<ui5-tag color-scheme=\"8\">Freigegeben</ui5-tag>", t_tag) > 0)

test_report()
