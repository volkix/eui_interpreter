-- =============================================================================
-- Beispiel 08: Enterprise CRM / ERP Cockpit mit cgibash/html (std/vsui.e)
-- Aufruf: ./euphorix examples/08_cgibash_html_demo.ex
--
-- Demonstriert:
-- 1) Volker Schultes cgibash/html Framework als schlanke, native Alternative zu UI5
-- 2) High-Density Enterprise Design (globalblauklein.css & vs.css)
-- 3) Komponentensuite: vsbutton, vsinput, vsnuminput, vsdateinput, vscombo, vscheck,
--    vspanel, vscollapse, vsgrid (Sticky Header & Live-Suche), vstabs, vsmodal
-- 4) Integrierter statischer Fileserver für /lib2/*, /css/*, /img/*
-- 5) Reaktive Event-Bridge mit vsevent ("button_click") und DOM-Patches (vsui:patch)
-- 6) SQLite-Anbindung mit automatisiertem End-to-End Selbsttest
-- =============================================================================

include std/vsui.e as vsui
include std/sqlite.e as sqlite
include std/http.e as http
include std/search.e as search
include std/convert.e as conv

puts(1, "=====================================================================\n")
puts(1, "  Beispiel 08: Enterprise Cockpit mit cgibash/html (std/vsui.e)\n")
puts(1, "=====================================================================\n\n")

-- 1. SQLite Datenbank für CRM-Kunden anlegen
integer db = sqlite:open(":memory:")
sqlite:exec(db, "CREATE TABLE kunden (kdnr TEXT PRIMARY KEY, name TEXT, ort TEXT, umsatz REAL, status TEXT, aktiv INTEGER);")

sqlite:exec(db, "INSERT INTO kunden (kdnr, name, ort, umsatz, status, aktiv) VALUES (?, ?, ?, ?, ?, ?);",
            {"K-1001", "Schulze Maschinenbau AG", "Frankfurt", 142500.00, "A-Kunde", 1})
sqlite:exec(db, "INSERT INTO kunden (kdnr, name, ort, umsatz, status, aktiv) VALUES (?, ?, ?, ?, ?, ?);",
            {"K-1002", "Bäcker & Partner Logistik GmbH", "Hamburg", 87400.50, "B-Kunde", 1})
sqlite:exec(db, "INSERT INTO kunden (kdnr, name, ort, umsatz, status, aktiv) VALUES (?, ?, ?, ?, ?, ?);",
            {"K-1003", "Albrecht IT Services", "München", 31200.00, "C-Kunde", 0})
sqlite:exec(db, "INSERT INTO kunden (kdnr, name, ort, umsatz, status, aktiv) VALUES (?, ?, ?, ?, ?, ?);",
            {"K-1004", "Nordic Clean Energy KG", "Bremen", 215800.75, "A-Kunde", 1})

-- Hilfsfunktion: DataGrid-HTML aus der Datenbank erzeugen
function render_kunden_grid()
    sequence rows = sqlite:query(db, "SELECT kdnr, name, ort, umsatz, status, aktiv FROM kunden ORDER BY kdnr ASC;")
    sequence grid_rows = {}

    for i = 1 to length(rows) do
        sequence r = rows[i]
        sequence kdnr   = r[1]
        sequence name   = r[2]
        sequence ort    = r[3]
        atom umsatz     = r[4]
        sequence status = r[5]
        integer aktiv   = r[6]

        sequence aktiv_badge
        if aktiv = 1 then
            aktiv_badge = "<span style=\"background:#27ae60; color:white; padding:2px 6px; font-size:11px; font-weight:bold;\">Aktiv</span>"
        else
            aktiv_badge = "<span style=\"background:#7f8c8d; color:white; padding:2px 6px; font-size:11px;\">Inaktiv</span>"
        end if

        sequence del_btn = vsui:button(sprintf("btn_del_%s", {kdnr}), "Löschen", {
            {"action", "delete_kunde"},
            {"style", "background:#c0392b; color:white; font-size:11px; padding:2px 6px;"},
            {"data-param-kdnr", kdnr}
        })

        sequence row = {
            kdnr,
            name,
            ort,
            sprintf("%.2f €", {umsatz}),
            status,
            aktiv_badge,
            del_btn
        }
        grid_rows = append(grid_rows, row)
    end for

    sequence cols = {
        {"Kd-Nr.", "90px"},
        {"Firma / Name", "240px"},
        {"Ort", "130px"},
        {"Jahresumsatz", "120px"},
        {"Kategorie", "100px"},
        {"Status", "80px"},
        {"Aktion", "80px"}
    }
    return vsui:grid("grd_kunden", cols, grid_rows)
end function

-- 2. Hauptseite des Enterprise Cockpits rendern
function render_cockpit_page(sequence req)
    sequence grid_html = render_kunden_grid()

    -- Eingabeformular für Neukunden
    sequence form_content = {
        "<div style=\"display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px; margin-bottom: 12px;\">\n",
        "  <div>" & vsui:ui_label("Kd-Nr.*:", "txt_kdnr") & "<br/>" &
                  vsui:input("txt_kdnr", "K-1005", {{"placeholder", "z.B. K-1005"}}) & "</div>\n",
        "  <div>" & vsui:ui_label("Firma / Name*:", "txt_name") & "<br/>" &
                  vsui:input("txt_name", "", {{"placeholder", "Vollständiger Name"}}) & "</div>\n",
        "  <div>" & vsui:ui_label("Standort / Ort:", "txt_ort") & "<br/>" &
                  vsui:input("txt_ort", "Köln") & "</div>\n",
        "  <div>" & vsui:ui_label("Geplanter Umsatz (€):", "num_umsatz") & "<br/>" &
                  vsui:numinput("num_umsatz", 50000.00) & "</div>\n",
        "  <div>" & vsui:ui_label("Kategorie:", "cmb_status") & "<br/>" &
                  vsui:combo("cmb_status", {{"A-Kunde", "A-Kunde (Premium)"}, {"B-Kunde", "B-Kunde (Standard)"}, {"C-Kunde", "C-Kunde (Basis)"}}, "B-Kunde") & "</div>\n",
        "  <div style=\"display:flex; align-items:flex-end; padding-bottom:4px;\">" &
                  vsui:check("chk_aktiv", "Sofort freigeschaltet", 1) & "</div>\n",
        "</div>\n",
        "<div style=\"display:flex; gap: 8px;\">\n",
        "  " & vsui:button("btn_add_kunde", "➕ Kunde anlegen", {{"action", "add_kunde"}, {"style", "background:var(--vs-blau, #41518b); color:white; font-weight:bold;"}}),
        "  " & vsui:button("btn_info_modal", "ℹ️ Systeminfo", {{"action", "show_info"}}),
        "</div>\n"
    }

    -- Cockpit-Layout: Header, Tabs, Splitter
    sequence header_bar = {
        "<div style=\"background: var(--vs-blau, #41518b); color: white; padding: 10px 16px; display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;\">\n",
        "  <div>\n",
        "    <span style=\"font-size: 18px; font-weight: bold;\">Euphorix CRM / ERP Cockpit</span>\n",
        "    <span style=\"font-size: 12px; margin-left: 12px; opacity: 0.8;\">Powered by cgibash/html & Java 25 VM</span>\n",
        "  </div>\n",
        "  <div style=\"font-size: 12px;\">Angemeldet: <b>Volker Schulte</b> (Admin)</div>\n",
        "</div>\n"
    }

    -- Details-Bereich (Collapsible)
    sequence collapse_section = vsui:collapse("col_tools", {
        {"Schnellfilter & Export", "<p>Exportoptionen: CSV, JSON, DIN A4 Rechnungsausgabe via <code>printRecord</code>.</p>"},
        {"Hinweise zur Architektur", "<p>Dieses UI basiert direkt auf den im Projekt integrierten Assets unter <code>html/</code> (ldom.js, vsevent.js, globalblauklein.css, vs-mobile.css) ohne externe Cloud-CDNs.</p>"}
    })

    -- Tabs mit Kundenstamm und Formular
    sequence main_tabs = vsui:tabs("crm_tabs", {
        {"Kundenstamm & Suche", "<div id=\"grid_wrapper\">" & grid_html & "</div>"},
        {"Neuen Kunden erfassen", vsui:group("Kundenstammdaten erfassen", form_content)}
    })

    -- Modal Dialog
    sequence modal_dlg = vsui:modal("dlg_info", "Euphorix & cgibash/html Architektur", {
        "<p><b>Framework:</b> Volker Schultes <code>cgibash/html</code></p>\n",
        "<p><b>Frontend:</b> Native ES6 Module (<code>ldom.js</code>, <code>vsevent.js</code>)</p>\n",
        "<p><b>Design:</b> High-Density Enterprise Theme (<code>globalblauklein.css</code>)</p>\n",
        "<p><b>Backend:</b> Euphorix VM (Java 25) mit eingebettetem Multi-Thread HTTP-Server.</p>\n"
    }, vsui:button("btn_close_dlg", "Schließen", {{"data-vs-close", "dlg_info"}}))

    sequence full_content = {
        header_bar,
        "<div style=\"padding: 0 16px;\">\n",
        main_tabs,
        "<div style=\"margin-top: 14px;\">\n",
        collapse_section,
        "</div>\n",
        "</div>\n",
        modal_dlg
    }

    return vsui:page("Euphorix CRM Cockpit (cgibash/html)", full_content)
end function

-- 3. Event-Handler für Neukunden-Erfassung
function on_add_kunde(sequence ctx)
    sequence kdnr   = vsui:val(ctx, "txt_kdnr", "")
    sequence name   = vsui:val(ctx, "txt_name", "")
    sequence ort    = vsui:val(ctx, "txt_ort", "Unbekannt")
    sequence ums_s  = vsui:val(ctx, "num_umsatz", "0")
    sequence status = vsui:val(ctx, "cmb_status", "B-Kunde")
    integer aktiv   = equal(vsui:val(ctx, "chk_aktiv", "0"), "1")

    atom umsatz = 0.0
    object v = conv:to_number(ums_s)
    if sequence(v) and length(v) = 2 and v[1] = 0 then
        umsatz = v[2]
    elsif atom(v) then
        umsatz = v
    end if

    if length(kdnr) = 0 or length(name) = 0 then
        return vsui:updates({
            vsui:toast_show("Bitte Kundennummer und Name angeben!", vsui:TOAST_WARNING, 3000)
        })
    end if

    -- In SQLite einfügen
    sqlite:exec(db, "INSERT OR REPLACE INTO kunden (kdnr, name, ort, umsatz, status, aktiv) VALUES (?, ?, ?, ?, ?, ?);",
                {kdnr, name, ort, umsatz, status, aktiv})

    -- Reaktive DOM-Patches zurückgeben
    return vsui:updates({
        vsui:patch("grid_wrapper", render_kunden_grid()),
        vsui:set_val("txt_name", ""),
        vsui:toast_show(sprintf("Kunde '%s' (%s) erfolgreich gespeichert!", {name, kdnr}), vsui:TOAST_SUCCESS, 3000)
    })
end function

-- Event-Handler für Kunden löschen
function on_delete_kunde(sequence ctx)
    sequence kdnr = vsui:val(ctx, "kdnr", "")
    if length(kdnr) > 0 then
        sqlite:exec(db, "DELETE FROM kunden WHERE kdnr = ?;", {kdnr})
    end if

    return vsui:updates({
        vsui:patch("grid_wrapper", render_kunden_grid()),
        vsui:toast_show(sprintf("Kunde %s wurde gelöscht.", {kdnr}), vsui:TOAST_INFO, 2500)
    })
end function

-- Event-Handler für Modal-Öffnung
function on_show_info(sequence ctx)
    return vsui:updates({
        vsui:modal_open("dlg_info")
    })
end function

-- 4. Anwendungs-Setup
integer app = vsui:app("Euphorix CRM Cockpit", 8089)
vsui:page_route(app, "/", routine_id("render_cockpit_page"))
vsui:on_event(app, "add_kunde", routine_id("on_add_kunde"))
vsui:on_event(app, "delete_kunde", routine_id("on_delete_kunde"))
vsui:on_event(app, "show_info", routine_id("on_show_info"))

-- 5. Automatisierter End-to-End Simulationstest
printf(1, "1. Initialisiere VS-UI Server auf Port 8089...\n")
integer srv = vsui:init_server(app)
if srv <= 0 then
    printf(2, "FEHLER: Server konnte auf Port 8089 nicht gestartet werden: %d\n", {srv})
    abort(1)
end if

-- Server im Hintergrund starten (max 10 Anfragen für diesen Test)
integer worker_pid = http:server_background(srv, 10)
printf(1, "2. Hintergrund-Server läuft (Worker-PID: %d)\n", {worker_pid})

-- Test 1: GET / (HTML Cockpit-Seite)
sequence get_res = http:get("http://127.0.0.1:8089/")
printf(1, "3. GET / -> Status %d (HTML-Länge: %d Bytes)\n", {get_res[http:STATUS], length(get_res[http:BODY])})
if get_res[http:STATUS] != 200 or match("Euphorix CRM / ERP Cockpit", get_res[http:BODY]) = 0 then
    puts(2, "FEHLER: Cockpit-HTML wurde nicht korrekt ausgeliefert!\n")
    abort(1)
end if

-- Test 2: GET /css/globalblauklein.css (Statischer CSS-Dateiserver)
sequence css_res = http:get("http://127.0.0.1:8089/css/globalblauklein.css")
printf(1, "4. GET /css/globalblauklein.css -> Status %d (CSS-Länge: %d Bytes)\n",
       {css_res[http:STATUS], length(css_res[http:BODY])})
if css_res[http:STATUS] != 200 or match("--vs-blau", css_res[http:BODY]) = 0 then
    puts(2, "FEHLER: globalblauklein.css konnte nicht geladen werden!\n")
    abort(1)
end if

-- Test 3: GET /lib2/ldom.js (Statischer ES6-Modulserver)
sequence js_res = http:get("http://127.0.0.1:8089/lib2/ldom.js")
printf(1, "5. GET /lib2/ldom.js -> Status %d (JS-Länge: %d Bytes)\n",
       {js_res[http:STATUS], length(js_res[http:BODY])})
if js_res[http:STATUS] != 200 or match("function _", js_res[http:BODY]) = 0 then
    puts(2, "FEHLER: ldom.js konnte nicht geladen werden!\n")
    abort(1)
end if

-- Test 4: POST /__vs_event für Neukunden 'K-1005'
sequence post_payload = `{"event":"add_kunde","data":{"txt_kdnr":"K-1005","txt_name":"Muster AG","txt_ort":"Düsseldorf","num_umsatz":"75000","cmb_status":"A-Kunde","chk_aktiv":"1"}}`
sequence post_res = http:post_json("http://127.0.0.1:8089/__vs_event", post_payload)
printf(1, "6. POST /__vs_event (add_kunde) -> Status %d (JSON: %s)\n",
       {post_res[http:STATUS], post_res[http:BODY][1..min({60, length(post_res[http:BODY])})]})
if post_res[http:STATUS] != 200 or match("\"type\":\"patch\"", post_res[http:BODY]) = 0 then
    puts(2, "FEHLER: Reaktiver Bridge-Patch fehlgeschlagen!\n")
    abort(1)
end if

-- Test 5: SQLite-Verifikation
sequence verify_db = sqlite:query(db, "SELECT name, ort, umsatz FROM kunden WHERE kdnr = 'K-1005';")
if length(verify_db) != 1 or not equal(verify_db[1][1], "Muster AG") then
    puts(2, "FEHLER: Datensatz K-1005 wurde nicht in SQLite gefunden!\n")
    abort(1)
end if
printf(1, "7. SQLite-Verifikation: '%s' in Düsseldorf mit %.2f € erfolgreich verifiziert!\n",
       {verify_db[1][1], verify_db[1][3]})

-- Test 6: POST /__vs_event für Kunde löschen 'K-1003'
sequence del_payload = `{"event":"button_click","data":{"action":"delete_kunde","kdnr":"K-1003"}}`
sequence del_res = http:post_json("http://127.0.0.1:8089/__vs_event", del_payload)
printf(1, "8. POST /__vs_event (delete_kunde) -> Status %d\n", {del_res[http:STATUS]})
if del_res[http:STATUS] != 200 then
    puts(2, "FEHLER: Löschen via Event-Bridge fehlgeschlagen!\n")
    abort(1)
end if

sequence verify_del = sqlite:query(db, "SELECT kdnr FROM kunden WHERE kdnr = 'K-1003';")
if length(verify_del) != 0 then
    puts(2, "FEHLER: Datensatz K-1003 wurde nicht gelöscht!\n")
    abort(1)
end if
printf(1, "9. SQLite-Verifikation: K-1003 erfolgreich gelöscht!\n")

-- Server-Worker beenden
http:server_close(srv, worker_pid)

puts(1, "\n=== Alle cgibash/html (std/vsui.e) Tests und Demos erfolgreich bestanden! ===\n")
