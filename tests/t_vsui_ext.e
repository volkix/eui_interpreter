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

test_report()
