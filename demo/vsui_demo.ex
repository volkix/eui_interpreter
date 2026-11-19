--****
-- == Euphorix cgibash/html Enterprise Cockpit Demo Server (std/vsui.e)
--
-- Starten mit: ./euphorix demo/vsui_demo.ex
-- Im Browser öffnen: http://127.0.0.1:8089/
--
-- Basiert direkt auf Volker Schultes cgibash/html Framework (/home/volkix/prj/cgibash/html)
-- mit ldom.js, vsevent.js, vsgrid.js und globalblauklein.css.
--

include std/vsui.e as vsui
include std/sqlite.e as sqlite
include std/convert.e as conv

puts(1, "=====================================================================\n")
puts(1, "  Euphorix 1.0 – cgibash/html Enterprise Cockpit Server\n")
puts(1, "  Alternative Web-UI basierend auf /home/volkix/prj/cgibash/html\n")
puts(1, "=====================================================================\n\n")

-- 1. SQLite Datenbank für das interaktive Demo anlegen
integer db = sqlite:open(":memory:")
sqlite:exec(db, "CREATE TABLE kunden (kdnr TEXT PRIMARY KEY, name TEXT, ort TEXT, umsatz REAL, status TEXT, aktiv INTEGER);")
sqlite:exec(db, "CREATE TABLE auftraege (id INTEGER PRIMARY KEY AUTOINCREMENT, kdnr TEXT, artnr TEXT, bezeichnung TEXT, menge INTEGER, preis REAL, status TEXT);")

-- Initiale Demodaten: Kunden
sqlite:exec(db, "INSERT INTO kunden (kdnr, name, ort, umsatz, status, aktiv) VALUES (?, ?, ?, ?, ?, ?);",
            {"K-1001", "Schulze Maschinenbau AG", "Frankfurt", 142500.00, "A-Kunde", 1})
sqlite:exec(db, "INSERT INTO kunden (kdnr, name, ort, umsatz, status, aktiv) VALUES (?, ?, ?, ?, ?, ?);",
            {"K-1002", "Bäcker & Partner Logistik GmbH", "Hamburg", 87400.50, "B-Kunde", 1})
sqlite:exec(db, "INSERT INTO kunden (kdnr, name, ort, umsatz, status, aktiv) VALUES (?, ?, ?, ?, ?, ?);",
            {"K-1003", "Albrecht IT Services", "München", 31200.00, "C-Kunde", 0})
sqlite:exec(db, "INSERT INTO kunden (kdnr, name, ort, umsatz, status, aktiv) VALUES (?, ?, ?, ?, ?, ?);",
            {"K-1004", "Nordic Clean Energy KG", "Bremen", 215800.75, "A-Kunde", 1})
sqlite:exec(db, "INSERT INTO kunden (kdnr, name, ort, umsatz, status, aktiv) VALUES (?, ?, ?, ?, ?, ?);",
            {"K-1005", "Rhein-Ruhr Werkzeugtechnik", "Dortmund", 98300.00, "B-Kunde", 1})

-- Initiale Demodaten: Aufträge
sqlite:exec(db, "INSERT INTO auftraege (kdnr, artnr, bezeichnung, menge, preis, status) VALUES (?, ?, ?, ?, ?, ?);",
            {"K-1001", "ART-501", "CNC Drehfräs-Modul X1", 2, 45000.00, "In Fertigung"})
sqlite:exec(db, "INSERT INTO auftraege (kdnr, artnr, bezeichnung, menge, preis, status) VALUES (?, ?, ?, ?, ?, ?);",
            {"K-1002", "ART-108", "Schwerlast Transportcontainer", 10, 850.00, "Versendet"})
sqlite:exec(db, "INSERT INTO auftraege (kdnr, artnr, bezeichnung, menge, preis, status) VALUES (?, ?, ?, ?, ?, ?);",
            {"K-1004", "ART-920", "Windkraft Generatorsteuerung", 1, 115000.00, "Freigegeben"})

-- Hilfsfunktion: DataGrid Kunden
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
            aktiv_badge = "<span style=\"background:#27ae60; color:white; padding:2px 6px; font-size:11px; font-weight:bold; border-radius:2px;\">Aktiv</span>"
        else
            aktiv_badge = "<span style=\"background:#7f8c8d; color:white; padding:2px 6px; font-size:11px; border-radius:2px;\">Inaktiv</span>"
        end if

        sequence del_btn = vsui:button(sprintf("btn_del_%s", {kdnr}), "🗑️ Löschen", {
            {"action", "delete_kunde"},
            {"style", "background:#c0392b; color:white; font-size:11px; padding:2px 8px;"},
            {"data-param-kdnr", kdnr}
        })

        grid_rows = append(grid_rows, {
            kdnr,
            sprintf("<b>%s</b>", {name}),
            ort,
            sprintf("%.2f €", {umsatz}),
            status,
            aktiv_badge,
            del_btn
        })
    end for

    sequence cols = {
        {"Kd-Nr.", "90px"},
        {"Firma / Name", "240px"},
        {"Ort", "130px"},
        {"Jahresumsatz", "120px"},
        {"Kategorie", "100px"},
        {"Status", "80px"},
        {"Aktion", "90px"}
    }
    return vsui:grid("grd_kunden", cols, grid_rows)
end function

-- Hilfsfunktion: DataGrid Aufträge
function render_auftraege_grid()
    sequence rows = sqlite:query(db, "SELECT id, kdnr, artnr, bezeichnung, menge, preis, status FROM auftraege ORDER BY id DESC;")
    sequence grid_rows = {}

    for i = 1 to length(rows) do
        sequence r = rows[i]
        integer id      = r[1]
        sequence kdnr   = r[2]
        sequence artnr  = r[3]
        sequence bez    = r[4]
        integer menge   = r[5]
        atom preis      = r[6]
        sequence status = r[7]

        grid_rows = append(grid_rows, {
            sprintf("#%d", {id}),
            kdnr,
            artnr,
            bez,
            sprintf("%d", {menge}),
            sprintf("%.2f €", {preis}),
            sprintf("<b>%s</b>", {status})
        })
    end for

    sequence cols = {
        {"Auftrag-ID", "90px"},
        {"Kunde", "90px"},
        {"Art.-Nr.", "100px"},
        {"Bezeichnung", "240px"},
        {"Menge", "70px"},
        {"Gesamtpreis", "110px"},
        {"Status", "110px"}
    }
    return vsui:grid("grd_auftraege", cols, grid_rows)
end function

-- 2. Hauptseite des Enterprise Cockpits
function render_cockpit_page(sequence req)
    -- Schnellformular
    sequence form_content = {
        "<div style=\"display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px; margin-bottom: 12px;\">\n",
        "  <div>" & vsui:ui_label("Kd-Nr.*:", "txt_kdnr") & "<br/>" &
                  vsui:input("txt_kdnr", "K-1006", {{"placeholder", "z.B. K-1006"}}) & "</div>\n",
        "  <div>" & vsui:ui_label("Firma / Name*:", "txt_name") & "<br/>" &
                  vsui:input("txt_name", "", {{"placeholder", "Vollständiger Kundenname"}}) & "</div>\n",
        "  <div>" & vsui:ui_label("Standort / Ort:", "txt_ort") & "<br/>" &
                  vsui:input("txt_ort", "Stuttgart") & "</div>\n",
        "  <div>" & vsui:ui_label("Geplanter Jahresumsatz (€):", "num_umsatz") & "<br/>" &
                  vsui:numinput("num_umsatz", 65000.00) & "</div>\n",
        "  <div>" & vsui:ui_label("Kundenkategorie:", "cmb_status") & "<br/>" &
                  vsui:combo("cmb_status", {{"A-Kunde", "A-Kunde (Premium Partner)"}, {"B-Kunde", "B-Kunde (Standard)"}, {"C-Kunde", "C-Kunde (Basis)"}}, "B-Kunde") & "</div>\n",
        "  <div style=\"display:flex; align-items:flex-end; padding-bottom:4px;\">" &
                  vsui:check("chk_aktiv", "Sofort aktiv setzen", 1) & "</div>\n",
        "</div>\n",
        "<div style=\"display:flex; gap: 8px;\">\n",
        "  " & vsui:button("btn_add_kunde", "💾 Kunde anlegen", {{"action", "add_kunde"}, {"style", "background:var(--vs-blau, #41518b); color:white; font-weight:bold;"}}),
        "  " & vsui:button("btn_open_info", "ℹ️ Systeminfo Dialog", {{"action", "open_info_modal"}}),
        "</div>\n"
    }

    -- Header-Banner
    sequence header_bar = {
        "<div style=\"background: var(--vs-blau, #41518b); color: white; padding: 10px 18px; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 2px 5px rgba(0,0,0,0.2);\">\n",
        "  <div style=\"display:flex; align-items:center; gap:12px;\">\n",
        "    <span style=\"font-size: 20px; font-weight: bold; letter-spacing: 0.5px;\">⚡ Euphorix CRM / ERP Cockpit</span>\n",
        "    <span style=\"background: rgba(255,255,255,0.2); padding: 3px 8px; border-radius: 3px; font-size: 11px;\">cgibash/html Alternative</span>\n",
        "  </div>\n",
        "  <div style=\"font-size: 12px; display:flex; align-items:center; gap:8px;\">\n",
        "    <span>Angemeldet als: <b>Volker Schulte</b></span>\n",
        "    <span style=\"background:#27ae60; color:white; padding:2px 6px; border-radius:2px; font-size:10px;\">ONLINE</span>\n",
        "  </div>\n",
        "</div>\n"
    }

    -- KPI Panels
    integer kunden_anz = sqlite:query_value(db, "SELECT COUNT(*) FROM kunden;", {}, 0)
    atom umsatz_ges    = 0.0
    object u_val       = sqlite:query_value(db, "SELECT COALESCE(SUM(umsatz), 0.0) FROM kunden;", {}, 0.0)
    if atom(u_val) then umsatz_ges = u_val end if
    integer auftrag_anz = sqlite:query_value(db, "SELECT COUNT(*) FROM auftraege;", {}, 0)

    sequence kpi_row = sprintf("<div style=\"display:grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap:12px; margin: 14px 0;\">\n" &
                               "  <div class=\"vs-panel\" style=\"padding:12px; border-left:4px solid var(--vs-blau,#41518b); background:white;\">" &
                               "    <div style=\"font-size:11px; color:#666;\">GESAMT KUNDEN</div>" &
                               "    <div id=\"kpi_kunden\" style=\"font-size:22px; font-weight:bold; color:var(--vs-blau,#41518b);\">%d</div>" &
                               "  </div>\n" &
                               "  <div class=\"vs-panel\" style=\"padding:12px; border-left:4px solid var(--vs-gruen,#3e8548); background:white;\">" &
                               "    <div style=\"font-size:11px; color:#666;\">JAHRESUMSATZ (PIPELINE)</div>" &
                               "    <div id=\"kpi_umsatz\" style=\"font-size:22px; font-weight:bold; color:var(--vs-gruen,#3e8548);\">%.2f €</div>" &
                               "  </div>\n" &
                               "  <div class=\"vs-panel\" style=\"padding:12px; border-left:4px solid #f39c12; background:white;\">" &
                               "    <div style=\"font-size:11px; color:#666;\">OFFENE AUFTRÄGE</div>" &
                               "    <div id=\"kpi_auftraege\" style=\"font-size:22px; font-weight:bold; color:#f39c12;\">%d</div>" &
                               "  </div>\n" &
                               "</div>\n", {kunden_anz, umsatz_ges, auftrag_anz})

    -- Tabs mit Kundenstamm, Auftragspositionen und Formular
    sequence main_tabs = vsui:tabs("cockpit_tabs", {
        {"👥 Kundenstamm (DataGrid)", "<div id=\"kunden_grid_box\">" & render_kunden_grid() & "</div>"},
        {"📦 Auftragsübersicht", "<div id=\"auftraege_grid_box\">" & render_auftraege_grid() & "</div>"},
        {"➕ Neuen Kunden erfassen", vsui:group("Kundenstammdaten erfassen", form_content)}
    })

    -- Collapsible Informations- & Architekturleiste
    sequence collapse_section = vsui:collapse("col_info", {
        {"Über cgibash/html & Euphorix Integration",
         "<p>Diese Benutzeroberfläche nutzt Volker Schultes hauseigenes Web-UI-Framework unter <code>/home/volkix/prj/cgibash/html</code>.</p>" &
         "<ul>" &
         "  <li><b>Keine externen Abhängigkeiten:</b> Läuft komplett autark ohne Internet/Cloud-Zugriff.</li>" &
         "  <li><b>High-Density UI:</b> Optimiert für datenintensive Fachanwendungen mit <code>globalblauklein.css</code>.</li>" &
         "  <li><b>Echtes Two-Way Eventing:</b> UI-Ereignisse (Klicks, Änderungen) werden direkt an OpenEuphoria-Handler weitergeleitet.</li>" &
         "  <li><b>Virtueller Threading-Server:</b> Skaliert über Java 25 Virtual Threads mit minimalem Ressourcenbedarf.</li>" &
         "</ul>"},
        {"Dokumentation der REST/Event API",
         "<p>Events werden über <code>POST /__vs_event</code> als JSON ausgetauscht. Antworten enthalten gezielte DOM-Patches (<code>patch</code>, <code>setValue</code>, <code>toast</code>, <code>modalOpen</code>).</p>"}
    })

    -- Modal Dialog
    sequence modal_dlg = vsui:modal("modal_sysinfo", "Systeminformationen: Euphorix & cgibash/html", {
        "<p><b>Version:</b> Euphorix 1.0.0 (Java 25 VM)</p>\n",
        "<p><b>UI-Framework:</b> Volker Schultes <code>cgibash/html</code></p>\n",
        "<p><b>Assets:</b> <code>/home/volkix/prj/cgibash/html</code> (ldom.js, vsevent.js, vsgrid.js, globalblauklein.css)</p>\n",
        "<p><b>Datenbank:</b> SQLite 3 In-Memory Engine</p>\n"
    }, vsui:button("btn_close_info", "Schließen", {{"data-vs-close", "modal_sysinfo"}}))

    sequence full_body = {
        header_bar,
        "<div style=\"padding: 12px 18px;\">\n",
        kpi_row,
        main_tabs,
        "<div style=\"margin-top: 14px;\">\n",
        collapse_section,
        "</div>\n",
        "</div>\n",
        modal_dlg
    }

    return vsui:page("Euphorix CRM Cockpit (cgibash/html)", full_body)
end function

-- 3. Event Handler
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

    sqlite:exec(db, "INSERT OR REPLACE INTO kunden (kdnr, name, ort, umsatz, status, aktiv) VALUES (?, ?, ?, ?, ?, ?);",
                {kdnr, name, ort, umsatz, status, aktiv})

    integer kunden_anz = sqlite:query_value(db, "SELECT COUNT(*) FROM kunden;", {}, 0)
    atom umsatz_ges    = 0.0
    object u_val       = sqlite:query_value(db, "SELECT COALESCE(SUM(umsatz), 0.0) FROM kunden;", {}, 0.0)
    if atom(u_val) then umsatz_ges = u_val end if

    return vsui:updates({
        vsui:patch("kunden_grid_box", render_kunden_grid()),
        vsui:patch("kpi_kunden", sprintf("%d", {kunden_anz})),
        vsui:patch("kpi_umsatz", sprintf("%.2f €", {umsatz_ges})),
        vsui:set_val("txt_name", ""),
        vsui:toast_show(sprintf("Kunde '%s' (%s) erfolgreich gespeichert!", {name, kdnr}), vsui:TOAST_SUCCESS, 3000)
    })
end function

function on_delete_kunde(sequence ctx)
    sequence kdnr = vsui:val(ctx, "kdnr", "")
    if length(kdnr) > 0 then
        sqlite:exec(db, "DELETE FROM kunden WHERE kdnr = ?;", {kdnr})
    end if

    integer kunden_anz = sqlite:query_value(db, "SELECT COUNT(*) FROM kunden;", {}, 0)
    atom umsatz_ges    = 0.0
    object u_val       = sqlite:query_value(db, "SELECT COALESCE(SUM(umsatz), 0.0) FROM kunden;", {}, 0.0)
    if atom(u_val) then umsatz_ges = u_val end if

    return vsui:updates({
        vsui:patch("kunden_grid_box", render_kunden_grid()),
        vsui:patch("kpi_kunden", sprintf("%d", {kunden_anz})),
        vsui:patch("kpi_umsatz", sprintf("%.2f €", {umsatz_ges})),
        vsui:toast_show(sprintf("Kunde %s wurde gelöscht.", {kdnr}), vsui:TOAST_INFO, 2500)
    })
end function

function on_open_info(sequence ctx)
    return vsui:updates({
        vsui:modal_open("modal_sysinfo")
    })
end function

-- 4. Server registrieren und starten
integer app = vsui:app("Euphorix CRM Cockpit (cgibash/html)", 8089)
vsui:page_route(app, "/", routine_id("render_cockpit_page"))
vsui:on_event(app, "add_kunde", routine_id("on_add_kunde"))
vsui:on_event(app, "delete_kunde", routine_id("on_delete_kunde"))
vsui:on_event(app, "open_info_modal", routine_id("on_open_info"))

vsui:run(app)
