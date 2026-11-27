-- Tests for VS-UI Frontend-Feinschliff (Dark Mode, Stat Cards, Shortcuts, PWA)
include std/unittest.e
include std/vsui.e as vsui
include std/http.e as http
include std/search.e as search

set_test_verbosity(TEST_SHOW_ALL)

-- 1. Constants
test_equal("TREND_UP is 1", vsui:TREND_UP, 1)
test_equal("TREND_DOWN is -1", vsui:TREND_DOWN, -1)
test_equal("TREND_NEUTRAL is 0", vsui:TREND_NEUTRAL, 0)

-- 2. Stat Cards
sequence sc1 = vsui:stat_card("stat_umsatz", "Tagesumsatz", "142.500,00 €", "+12.4% ggü. Vormonat", vsui:TREND_UP, "💶")
test_true("stat card container id", search:match("id=\"stat_umsatz\"", sc1) > 0)
test_true("stat card class vs-stat-card", search:match("class=\"vs-stat-card\"", sc1) > 0)
test_true("stat card title", search:match("Tagesumsatz", sc1) > 0)
test_true("stat card value", search:match("142.500,00 €", sc1) > 0)
test_true("stat card trend up class", search:match("vs-trend-up", sc1) > 0)
test_true("stat card trend arrow up", search:match("↗ ", sc1) > 0)
test_true("stat card icon", search:match("💶", sc1) > 0)

sequence sc2 = vsui:stat_card("stat_offen", "Offene Posten", "3", "-2 erledigt", vsui:TREND_DOWN, "📦")
test_true("stat card trend down class", search:match("vs-trend-down", sc2) > 0)
test_true("stat card trend arrow down", search:match("↘ ", sc2) > 0)

sequence sc3 = vsui:stat_card("stat_neutral", "Quote", "98%", "Stabil", vsui:TREND_NEUTRAL)
test_true("stat card trend neutral class", search:match("vs-trend-neutral", sc3) > 0)

-- 3. Theme Toggle
sequence tt = vsui:theme_toggle("btn_theme")
test_true("theme toggle id", search:match("id=\"btn_theme\"", tt) > 0)
test_true("theme toggle class", search:match("class=\"vs-theme-toggle\"", tt) > 0)
test_true("theme toggle onclick", search:match("onclick=\"vsToggleTheme()\"", tt) > 0)
test_true("theme toggle icon span", search:match("id=\"vs_theme_icon\"", tt) > 0)
test_true("theme toggle label span", search:match("id=\"vs_theme_label\"", tt) > 0)

-- 4. Keyboard Shortcuts
sequence opts = vsui:with_shortcut({{"action", "on_save"}}, "Ctrl+S")
sequence btn = vsui:button("btn_save", "Speichern", opts)
test_true("button with shortcut attribute", search:match("data-vs-shortcut=\"ctrl+s\"", btn) > 0)

-- 5. PWA Meta Tags in Page
sequence pg = vsui:page("Mein ERP", "<p>Inhalt</p>")
test_true("page includes manifest link", search:match("<link rel=\"manifest\" href=\"/manifest.json\">", pg) > 0)
test_true("page includes theme-color meta", search:match("<meta name=\"theme-color\" content=\"#41518b\">", pg) > 0)
test_true("page includes mobile-web-app-capable", search:match("<meta name=\"mobile-web-app-capable\" content=\"yes\">", pg) > 0)
test_true("page includes theme anti-flash script", search:match("localStorage.getItem('vs-theme')", pg) > 0)
test_true("page bridge includes loading bar", search:match("vs-loading-bar", pg) > 0)
test_true("page bridge includes vsToggleTheme", search:match("window.vsToggleTheme", pg) > 0)
test_true("page bridge includes shortcut keydown listener", search:match("data-vs-shortcut", pg) > 0)
test_true("page bridge registers service worker", search:match("navigator.serviceWorker.register('/sw.js')", pg) > 0)

-- 6. PWA Route Responses
integer test_app = vsui:app("Test ERP Suite", 9099)
sequence req_manifest = {
    1,                  -- REQ_CONN_ID
    "GET",              -- REQ_METHOD
    "/manifest.json",   -- REQ_PATH
    "",                 -- REQ_QUERY
    "",                 -- REQ_BODY
    {},                 -- REQ_HEADERS
    "127.0.0.1"         -- REQ_CLIENT_IP
}
sequence res_m = vsui:internal_route_handler(req_manifest)
test_equal("manifest status 200", res_m[1], 200)
test_true("manifest contains json", search:match("\"display\": \"standalone\"", res_m[2]) > 0)
test_true("manifest content type", search:match("application/manifest+json", res_m[3]) > 0)

sequence req_sw = {
    1,                  -- REQ_CONN_ID
    "GET",              -- REQ_METHOD
    "/sw.js",           -- REQ_PATH
    "",                 -- REQ_QUERY
    "",                 -- REQ_BODY
    {},                 -- REQ_HEADERS
    "127.0.0.1"         -- REQ_CLIENT_IP
}
sequence res_sw = vsui:internal_route_handler(req_sw)
test_equal("sw.js status 200", res_sw[1], 200)
test_true("sw.js contains cache name", search:match("vsui-pwa-v1", res_sw[2]) > 0)
test_true("sw.js content type", search:match("application/javascript", res_sw[3]) > 0)

-- 7. Grid Column Width Alignment (Header & Data Match)
sequence test_grid = vsui:grid("grd_align", {
    {"ID", "80px"},
    {"Name", "200px"}
}, {
    {"1", "Testdaten"}
})
test_true("grid table has table-layout fixed", search:match("table-layout: fixed", test_grid) > 0)
test_true("grid has colgroup tag", search:match("<colgroup>", test_grid) > 0)
test_true("grid colgroup has 80px col", search:match("<col style=\"width: 80px;\">", test_grid) > 0)
test_true("grid colgroup has 200px col", search:match("<col style=\"width: 200px;\">", test_grid) > 0)
test_true("grid table has min-width 280px", search:match("min-width: 280px", test_grid) > 0)
test_true("grid td carries matching width 80px", search:match("<td class=\"vs-tbody-td\" width=\"80px\" style=\"width: 80px;\"", test_grid) > 0)
test_true("grid td carries matching width 200px", search:match("<td class=\"vs-tbody-td\" width=\"200px\" style=\"width: 200px;\"", test_grid) > 0)

test_report()
