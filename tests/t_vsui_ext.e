include std/unittest.e

set_test_verbosity(TEST_SHOW_ALL)
include std/vsui.e as vsui

-- 1. Test Field Error & Clear
sequence err_patch = vsui:field_error("txt_email", "Ungültige E-Mail Adresse")
test_equal("field_error type", "fieldError", err_patch[1][2])
test_equal("field_error id", "txt_email", err_patch[2][2])
test_equal("field_error msg", "Ungültige E-Mail Adresse", err_patch[3][2])

sequence clr_patch = vsui:field_clear_error("txt_email")
test_equal("field_clear_error type", "fieldClearError", clr_patch[1][2])
test_equal("field_clear_error id", "txt_email", clr_patch[2][2])

-- 2. Test Form Validation Helpers
sequence ctx = {{"username", "max_muster"}, {"email", "max@muster.de"}, {"age", "28"}, {"empty_field", ""}}

sequence v_req_ok = vsui:validate_required(ctx, "username", "Benutzername")
test_equal("validate_required ok", 1, v_req_ok[1])

sequence v_req_fail = vsui:validate_required(ctx, "empty_field", "Zusatzfeld")
test_equal("validate_required fail", 0, v_req_fail[1])
test_true("validate_required fail msg", length(v_req_fail[2]) > 0)

sequence v_email_ok = vsui:validate_email("kontakt@unternehmen.com")
test_equal("validate_email ok", 1, v_email_ok[1])

sequence v_email_fail = vsui:validate_email("keine_email_adresse")
test_equal("validate_email fail", 0, v_email_fail[1])

sequence v_num_ok = vsui:validate_number("42.5")
test_equal("validate_number ok", 1, v_num_ok[1])

sequence v_num_fail = vsui:validate_number("abc")
test_equal("validate_number fail", 0, v_num_fail[1])

-- 3. Test Drag & Drop Upload Component
sequence upload_html = vsui:upload("drop_belege", "/api/upload_beleg", {{"prompt", "Beleg-Dateien hier ablegen"}})
test_true("upload contains container id", match("id=\"drop_belege\"", upload_html) > 0)
test_true("upload contains dropzone class", match("vs-upload-dropzone", upload_html) > 0)
test_true("upload contains prompt text", match("Beleg-Dateien hier ablegen", upload_html) > 0)
test_true("upload contains progress bar", match("vs-upload-progress-bar", upload_html) > 0)

-- 4. Test Native Responsive SVG Charts
sequence chart_labels = {"Januar", "Februar", "März", "April", "Mai"}
sequence chart_data = {1200, 1850, 1400, 2400, 3100}

-- Bar Chart
sequence bar_svg = vsui:chart("umsatz_chart", "bar", chart_labels, chart_data, {{"title", "Umsatzentwicklung 2026"}})
test_true("bar chart has container id", match("id=\"umsatz_chart_chart\"", bar_svg) > 0)
test_true("bar chart has svg tag", match("<svg", bar_svg) > 0)
test_true("bar chart has title", match("Umsatzentwicklung 2026", bar_svg) > 0)
test_true("bar chart has rect bars", match("<rect", bar_svg) > 0)
test_true("bar chart has labels", match("Januar", bar_svg) > 0)

-- Line Chart
sequence line_svg = vsui:chart("trend_chart", "line", chart_labels, chart_data, {{"title", "Trendkurve"}})
test_true("line chart has polyline", match("<polyline", line_svg) > 0)
test_true("line chart has circles", match("<circle", line_svg) > 0)

-- Pie Chart
sequence pie_svg = vsui:chart("verteilung_chart", "pie", {"Produkt A", "Produkt B", "Produkt C"}, {45, 30, 25})
test_true("pie chart has path slices", match("<path", pie_svg) > 0)
test_true("pie chart has legend", match("Produkt A", pie_svg) > 0)

-- Chart Set Data Patch
sequence chart_patch = vsui:chart_set_data("umsatz_chart", "bar", chart_labels, {1500, 2100, 1900, 2800, 3500})
test_equal("chart_set_data type is patch", "patch", chart_patch[1][2])
test_equal("chart_set_data target id", "umsatz_chart_chart", chart_patch[2][2])
test_true("chart_set_data html not empty", length(chart_patch[3][2]) > 100)

-- 5. Test Treeview (vstreeview)
sequence tree_nodes = {
    {"Hauptordner 1", {
        {"Unterordner A", {}, 0},
        {"Unterordner B", {{"Datei 1.txt", {}, 0}}, 1}
    }, 1},
    {"Hauptordner 2", {}, 0}
}
sequence tree_html = vsui:treeview("tree_katalog", tree_nodes)
test_true("treeview contains id", match("id=\"tree_katalog\"", tree_html) > 0)
test_true("treeview class", match("class=\"vs-treeview\"", tree_html) > 0)
test_true("treeview node 1", match("Hauptordner 1", tree_html) > 0)
test_true("treeview toggle empty for leaf", match("vs-treeview-toggle empty", tree_html) > 0)
test_true("treeview subnode Datei 1.txt", match("Datei 1.txt", tree_html) > 0)

-- 6. Test Blocker (vsblocker)
sequence blk_html = vsui:blocker("blk_loading", 8888)
test_true("blocker id", match("id=\"blk_loading\"", blk_html) > 0)
test_true("blocker class", match("class=\"blocker\"", blk_html) > 0)
test_true("blocker z-index", match("z-index: 8888", blk_html) > 0)

sequence p_blk_show = vsui:blocker_show("blk_busy", 9999)
test_equal("blockerShow type", "blockerShow", p_blk_show[1][2])
test_equal("blockerShow id", "blk_busy", p_blk_show[2][2])

sequence p_blk_hide = vsui:blocker_hide("blk_busy")
test_equal("blockerHide type", "blockerHide", p_blk_hide[1][2])

-- 7. Test Tooltip & Contextmenu Helpers (vstooltip & vscontextmenu)
sequence btn_with_tip = vsui:with_tooltip("<button id=\"btn_help\">Hilfe</button>", "Klicken für Hilfe")
test_true("with_tooltip data-vs-tooltip", match("data-vs-tooltip=\"Klicken für Hilfe\"", btn_with_tip) > 0)

sequence row_with_ctx = vsui:with_contextmenu("<tr id=\"row_1\"><td>Daten</td></tr>", {
    {"Bearbeiten", "edit_item"},
    {"-"},
    {"Löschen", "del_item"}
})
test_true("with_contextmenu data-vs-contextmenu", match("data-vs-contextmenu='[", row_with_ctx) > 0)
test_true("with_contextmenu contains edit", match("Bearbeiten", row_with_ctx) > 0)
test_true("with_contextmenu contains divider", match("\"divider\":true", row_with_ctx) > 0)

-- 8. Test Positioning & setXYWH (ldom integration)
sequence btn_xywh = vsui:button("btn_pos", "Verschieben", {vsui:opt_xywh(100, 250, 180, 36)})
test_true("button has position absolute", match("position:absolute", btn_xywh) > 0)
test_true("button left 100px", match("left:100px", btn_xywh) > 0)
test_true("button top 250px", match("top:250px", btn_xywh) > 0)
test_true("button width 180px", match("width:180px", btn_xywh) > 0)
test_true("button height 36px", match("height:36px", btn_xywh) > 0)

sequence p_xywh = vsui:set_xywh("grd_kunden", 20, 80, 800, 500)
test_equal("set_xywh patch type", "setXYWH", p_xywh[1][2])
test_equal("set_xywh patch id", "grd_kunden", p_xywh[2][2])
test_equal("set_xywh patch x", 20, p_xywh[3][2])
test_equal("set_xywh patch y", 80, p_xywh[4][2])

sequence p_cwin = vsui:center_win("mdl_dialog", "both")
test_equal("center_win patch type", "centerWin", p_cwin[1][2])
test_equal("center_win patch axis", "both", p_cwin[3][2])

sequence p_cpar = vsui:center_parent("btn_pos", "x")
test_equal("center_parent patch type", "centerParent", p_cpar[1][2])

test_report()
