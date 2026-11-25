--****
-- == Euphorix VS-UI Enterprise Cockpit Demo Server (std/vsui.e)
--
-- Starten mit: ./euphorix demo/vsui_demo.ex
-- Im Browser öffnen: http://127.0.0.1:8089/
--
-- 100% autarke High-Density Web-UI Suite mit nativen Assets aus html/
-- (ldom.js, vsevent.js, vsgrid.js, globalblauklein.css, vs.css, vs-mobile.css).
--

include std/vsui.e as vsui
include std/sqlite.e as sqlite
include std/convert.e as conv

puts(1, "=====================================================================\n")
puts(1, "  Euphorix 1.0 – VS-UI High-Density Enterprise Cockpit Server\n")
puts(1, "  Native Web-UI Suite mit lokalen Assets aus ./html/\n")
puts(1, "=====================================================================\n\n")

-- 1. SQLite Datenbank für das interaktive Demo anlegen
integer db = sqlite:open(":memory:")
sqlite:exec(db, "CREATE TABLE kunden (" &
                "kdnr TEXT PRIMARY KEY, " &
                "name TEXT, " &
                "ort TEXT, " &
                "email TEXT, " &
                "datum TEXT, " &
                "uhrzeit TEXT, " &
                "umsatz REAL, " &
                "status TEXT, " &
                "aktiv INTEGER, " &
                "notiz TEXT);")

sqlite:exec(db, "CREATE TABLE auftraege (" &
                "id INTEGER PRIMARY KEY AUTOINCREMENT, " &
                "kdnr TEXT, " &
                "artnr TEXT, " &
                "bezeichnung TEXT, " &
                "menge INTEGER, " &
                "preis REAL, " &
                "status TEXT);")

sqlite:exec(db, "CREATE TABLE dokumente (" &
                "id INTEGER PRIMARY KEY AUTOINCREMENT, " &
                "filename TEXT, " &
                "groesse INTEGER, " &
                "mimetype TEXT, " &
                "uhrzeit TEXT);")

-- Initiale Demodaten: Kunden
sqlite:exec(db, "INSERT INTO kunden (kdnr, name, ort, email, datum, uhrzeit, umsatz, status, aktiv, notiz) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);",
            {"K-1001", "Schulze Maschinenbau AG", "Frankfurt", "kontakt@schulze-ag.de", "2026-01-15", "09:30", 142500.00, "A-Kunde", 1, "Rahmenvertrag Werkzeugbau bis 2028"})
sqlite:exec(db, "INSERT INTO kunden (kdnr, name, ort, email, datum, uhrzeit, umsatz, status, aktiv, notiz) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);",
            {"K-1002", "Bäcker & Partner Logistik GmbH", "Hamburg", "dispo@baecker-logistik.com", "2026-02-01", "11:15", 87400.50, "B-Kunde", 1, "Logistik-Hub Nord, feste Tourenplanung"})
sqlite:exec(db, "INSERT INTO kunden (kdnr, name, ort, email, datum, uhrzeit, umsatz, status, aktiv, notiz) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);",
            {"K-1003", "Albrecht IT Services", "München", "office@albrecht-it.de", "2026-02-18", "14:00", 31200.00, "C-Kunde", 0, "Aktuell in Umstrukturierung"})
sqlite:exec(db, "INSERT INTO kunden (kdnr, name, ort, email, datum, uhrzeit, umsatz, status, aktiv, notiz) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);",
            {"K-1004", "Nordic Clean Energy KG", "Bremen", "info@nordic-energy.eu", "2026-03-05", "10:45", 215800.75, "A-Kunde", 1, "Windpark-Steuerungsprojekt Phase 2"})
sqlite:exec(db, "INSERT INTO kunden (kdnr, name, ort, email, datum, uhrzeit, umsatz, status, aktiv, notiz) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);",
            {"K-1005", "Rhein-Ruhr Werkzeugtechnik", "Dortmund", "vertrieb@rr-werkzeuge.de", "2026-03-12", "16:20", 98300.00, "B-Kunde", 1, "Just-in-Time Liefervereinbarung"})

-- Initiale Demodaten: Aufträge
sqlite:exec(db, "INSERT INTO auftraege (kdnr, artnr, bezeichnung, menge, preis, status) VALUES (?, ?, ?, ?, ?, ?);",
            {"K-1001", "ART-501", "CNC Drehfräs-Modul X1", 2, 45000.00, "In Fertigung"})
sqlite:exec(db, "INSERT INTO auftraege (kdnr, artnr, bezeichnung, menge, preis, status) VALUES (?, ?, ?, ?, ?, ?);",
            {"K-1002", "ART-108", "Schwerlast Transportcontainer", 10, 850.00, "Versendet"})
sqlite:exec(db, "INSERT INTO auftraege (kdnr, artnr, bezeichnung, menge, preis, status) VALUES (?, ?, ?, ?, ?, ?);",
            {"K-1004", "ART-920", "Windkraft Generatorsteuerung", 1, 115000.00, "Freigegeben"})

-- Initiale Demodaten: Archivierte Dokumente
sqlite:exec(db, "INSERT INTO dokumente (filename, groesse, mimetype, uhrzeit) VALUES (?, ?, ?, ?);",
            {"Rechnung_2026_0114.pdf", 148200, "application/pdf", "2026-11-24 09:15"})
sqlite:exec(db, "INSERT INTO dokumente (filename, groesse, mimetype, uhrzeit) VALUES (?, ?, ?, ?);",
            {"Lieferschein_LS-4402.pdf", 92100, "application/pdf", "2026-11-24 10:20"})
sqlite:exec(db, "INSERT INTO dokumente (filename, groesse, mimetype, uhrzeit) VALUES (?, ?, ?, ?);",
            {"Kundenexport_Q3.csv", 34500, "text/csv", "2026-11-24 11:05"})

-- Hilfsfunktion: DataGrid Kunden
function render_kunden_grid()
    sequence rows = sqlite:query(db, "SELECT kdnr, name, ort, email, datum, umsatz, status, aktiv FROM kunden ORDER BY kdnr ASC;")
    sequence grid_rows = {}

    for i = 1 to length(rows) do
        sequence r = rows[i]
        sequence kdnr   = r[1]
        sequence name   = r[2]
        sequence ort    = r[3]
        sequence email  = r[4]
        sequence datum  = r[5]
        atom umsatz     = r[6]
        sequence status = r[7]
        integer aktiv   = r[8]

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
            sprintf("<a href=\"mailto:%s\" style=\"color:var(--vs-blau,#41518b);\">%s</a>", {email, email}),
            datum,
            sprintf("%.2f €", {umsatz}),
            status,
            aktiv_badge,
            del_btn
        })
    end for

    sequence cols = {
        {"Kd-Nr.", "85px"},
        {"Firma / Name", "210px"},
        {"Ort", "110px"},
        {"E-Mail", "160px"},
        {"Erfasst am", "95px"},
        {"Jahresumsatz", "110px"},
        {"Kategorie", "90px"},
        {"Status", "75px"},
        {"Aktion", "85px"}
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

-- Hilfsfunktion: DataGrid Dokumente / Belegarchiv
function render_dokumente_grid()
    sequence rows = sqlite:query(db, "SELECT id, filename, groesse, mimetype, uhrzeit FROM dokumente ORDER BY id DESC;")
    sequence grid_rows = {}
    for i = 1 to length(rows) do
        sequence r = rows[i]
        integer doc_id  = r[1]
        sequence fname  = r[2]
        integer fsize   = r[3]
        sequence fmtype = r[4]
        sequence ftime  = r[5]
        sequence size_str
        if fsize < 1024 then
            size_str = sprintf("%d B", {fsize})
        elsif fsize < 1048576 then
            size_str = sprintf("%.1f KB", {fsize / 1024.0})
        else
            size_str = sprintf("%.2f MB", {fsize / 1048576.0})
        end if
        sequence del_btn = vsui:button(sprintf("btn_deldoc_%d", {doc_id}), "🗑️ Löschen", {
            {"action", "delete_dokument"},
            {"style", "background:#c0392b; color:white; font-size:11px; padding:2px 8px;"},
            {"data-param-docid", sprintf("%d", {doc_id})}
        })
        grid_rows = append(grid_rows, {
            sprintf("#%d", {doc_id}),
            "📄 <b>" & vsui:escape_html(fname) & "</b>",
            size_str,
            fmtype,
            ftime,
            del_btn
        })
    end for
    sequence cols = {
        {"ID", "60px"},
        {"Dateiname", "250px"},
        {"Dateigröße", "100px"},
        {"Format / MIME", "150px"},
        {"Hochgeladen am", "150px"},
        {"Aktionen", "110px"}
    }
    return vsui:grid("grd_dokumente", cols, grid_rows)
end function

-- 2. Hauptseite des Enterprise Cockpits
function render_cockpit_page(sequence req)
    -- Schnellformular mit allen Steuerelementen: Input, Date, Time, Num, Combo, Check, Textarea
    sequence form_content = {
        "<div id=\"form_kunde\">\n",
        "  <div style=\"display: grid; grid-template-columns: repeat(auto-fit, minmax(210px, 1fr)); gap: 12px; margin-bottom: 12px;\">\n",
        "    <div>" & vsui:ui_label("Kd-Nr.*:", "txt_kdnr") & "<br/>" &
                      vsui:input("txt_kdnr", "K-1006", {{"placeholder", "z.B. K-1006"}}) & "</div>\n",
        "    <div>" & vsui:ui_label("Firma / Name*:", "txt_name") & "<br/>" &
                      vsui:input("txt_name", "", {{"placeholder", "Vollständiger Firmenname"}}) & "</div>\n",
        "    <div>" & vsui:ui_label("E-Mail Adresse*:", "txt_email") & "<br/>" &
                      vsui:input("txt_email", "kontakt@firma.de", {{"placeholder", "name@domain.de"}}) & "</div>\n",
        "    <div>" & vsui:ui_label("Standort / Ort:", "txt_ort") & "<br/>" &
                      vsui:input("txt_ort", "Stuttgart") & "</div>\n",
        "    <div>" & vsui:ui_label("Erfassungsdatum:", "dt_erfasst") & "<br/>" &
                      vsui:dateinput("dt_erfasst", "2026-11-24") & "</div>\n",
        "    <div>" & vsui:ui_label("Uhrzeit:", "tm_erfasst") & "<br/>" &
                      vsui:timeinput("tm_erfasst", "10:00") & "</div>\n",
        "    <div>" & vsui:ui_label("Geplanter Jahresumsatz (€):", "num_umsatz") & "<br/>" &
                      vsui:numinput("num_umsatz", 65000.00) & "</div>\n",
        "    <div>" & vsui:ui_label("Kundenkategorie:", "cmb_status") & "<br/>" &
                      vsui:combo("cmb_status", {{"A-Kunde", "A-Kunde (Premium Partner)"}, {"B-Kunde", "B-Kunde (Standard)"}, {"C-Kunde", "C-Kunde (Basis)"}}, "B-Kunde") & "</div>\n",
        "    <div style=\"display:flex; align-items:flex-end; padding-bottom:6px;\">" &
                      vsui:check("chk_aktiv", "Konto sofort aktiv schalten", 1) & "</div>\n",
        "  </div>\n",
        "  <div style=\"margin-bottom: 14px;\">\n",
        "    " & vsui:ui_label("Notizen & Kundenkonditionen:", "txt_notiz") & "<br/>\n",
        "    " & vsui:textarea("txt_notiz", "Erste Kontaktaufnahme über Fachmesse Hannover 2026.", 3) & "\n",
        "  </div>\n",
        "  <div style=\"display:flex; gap: 8px;\">\n",
        "    " & vsui:button("btn_add_kunde", "💾 Kunde anlegen", {{"action", "add_kunde"}, {"style", "background:var(--vs-blau, #41518b); color:white; font-weight:bold;"}}),
        "    " & vsui:button("btn_clear_kunde", "🧹 Formular leeren", {{"action", "clear_form"}}),
        "    " & vsui:button("btn_open_info", "ℹ️ Systeminfo Dialog", {{"action", "open_info_modal"}}),
        "  </div>\n",
        "</div>\n"
    }

    -- Header-Banner
    sequence header_bar = {
        "<div style=\"background: var(--vs-blau, #41518b); color: white; padding: 10px 18px; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 2px 5px rgba(0,0,0,0.2);\">\n",
        "  <div style=\"display:flex; align-items:center; gap:12px;\">\n",
        "    <span style=\"font-size: 20px; font-weight: bold; letter-spacing: 0.5px;\">⚡ Euphorix CRM / ERP Cockpit</span>\n",
        "    <span style=\"background: rgba(255,255,255,0.2); padding: 3px 8px; border-radius: 3px; font-size: 11px;\">VS-UI High-Density Suite</span>\n",
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

    -- Splitter für Kundenstamm: DataGrid links, Schnellansicht/Detail-Panel rechts
    sequence details_sidebar = {
        "<div style=\"padding:6px;\">",
        "  <h4 style=\"margin-top:0; color:var(--vs-blau,#41518b);\">📌 Schnellansicht & Filter</h4>",
        "  <p style=\"font-size:12px; color:#555;\">Wählen Sie im DataGrid eine Zeile oder nutzen Sie das Live-Suchfeld oben rechts über der Tabelle.</p>",
        "  <hr style=\"border:0; border-top:1px solid #ddd; margin:10px 0;\"/>",
        "  <div style=\"font-size:12px; line-height:1.6;\">",
        "    <b>Top-Kunde:</b> Nordic Clean Energy KG<br/>",
        "    <b>Volumen:</b> 215.800,75 €<br/>",
        "    <b>Zahlungsziel:</b> 30 Tage netto<br/>",
        "    <b>Status:</b> Premium A-Partner",
        "  </div>",
        "  <hr style=\"border:0; border-top:1px solid #ddd; margin:10px 0;\"/>",
        "  <div style=\"font-size:11px; color:#777;\">Die Tabellenansicht unterstützt Sticky-Header, Spaltensortierung und automatischen Mobile-Card-View auf Displays &le; 768px.</div>",
        "</div>"
    }

    sequence kunden_splitter = vsui:splitter("splt_kunden",
        "<div id=\"kunden_grid_box\">" & render_kunden_grid() & "</div>",
        details_sidebar,
        72
    )

    -- Tab 4: Responsive SVG Charts & Diagramme
    sequence charts_content = {
        "<div style=\"display:flex; justify-content:space-between; align-items:center; margin-bottom:12px;\">\n",
        "  <span style=\"font-size:13px; color:#555;\">Autarke Vektor-Diagramme (SVG) direkt auf dem Server generiert – ohne Third-Party JS.</span>\n",
        "  " & vsui:button("btn_update_charts", "🔄 Live-Update: Quartalsdaten aktualisieren", {{"action", "update_charts"}, {"style", "background:var(--vs-gruen,#3e8548); color:white; font-size:12px;"}}),
        "</div>\n",
        "<div style=\"display: grid; grid-template-columns: repeat(auto-fit, minmax(360px, 1fr)); gap: 14px;\">\n",
        "  <div class=\"vs-panel\">" & vsui:chart("chart_quartal", "bar", {"Q1/26", "Q2/26", "Q3/26", "Q4/26 (Plan)"}, {142500, 187400, 215800, 265000}, {{"title", "Quartalsumsatz 2026 (EUR)"}}) & "</div>\n",
        "  <div class=\"vs-panel\">" & vsui:chart("chart_kategorien", "doughnut", {"A-Kunden", "B-Kunden", "C-Kunden"}, {55, 30, 15}, {{"title", "Kundenanteile nach Kategorie (%)"}}) & "</div>\n",
        "</div>\n"
    }

    -- Tab 5: Drag & Drop Upload Dropzone und Dokumenten-Archiv
    sequence upload_content = {
        vsui:panel("pnl_upload_docs", "Zentraler Dokumenten- & Beleg-Upload", {
            "<p style=\"font-size:13px; color:#555; margin-top:0;\">Ziehen Sie Ausgangsrechnungen, Lieferscheine oder CSV-Exportdateien direkt in die Dropzone oder wählen Sie diese manuell per Knopfdruck aus:</p>",
            vsui:upload("drop_belege", "/api/upload", {
                {"prompt", "Dateien hier ablegen (PDF, CSV, XLSX, Bilder) oder per Knopfdruck auswählen"},
                {"accept", ".pdf,.csv,.xlsx,.txt,.png,.jpg"}
            }),
            "<div style=\"margin-top:10px; font-size:11px; color:#777;\">Die Dropzone nutzt die native ES6-Upload-Engine mit Drag & Drop, nativem Dateiauswahldialog und animiertem Fortschrittsbalken.</div>"
        }),
        vsui:panel("pnl_archive_docs", "Archivierte Belege & Dokumente (SQLite)", {
            "<div id=\"docs_grid_box\">" & render_dokumente_grid() & "</div>"
        })
    }

    -- Tabs mit allen 5 Modulen
    sequence main_tabs = vsui:tabs("cockpit_tabs", {
        {"👥 Kundenstamm & Details", kunden_splitter},
        {"📦 Auftragsübersicht", "<div id=\"auftraege_grid_box\">" & render_auftraege_grid() & "</div>"},
        {"➕ Kunden erfassen (Formular)", vsui:group("Kundenstammdaten erfassen", form_content)},
        {"📊 Analysen & Charts", charts_content},
        {"📁 Dokumenten-Upload", upload_content}
    })

    -- Collapsible Informations- & Architekturleiste
    sequence collapse_section = vsui:collapse("col_info", {
        {"Über die Euphorix VS-UI Suite (html/)",
         "<p>Diese Benutzeroberfläche nutzt Volker Schultes hauseigenes Web-UI-Framework (integriert im Projekt unter <code>html/</code>).</p>" &
         "<ul>" &
         "  <li><b>100% Autark & Offline-fähig:</b> Läuft komplett autark ohne Internet- oder Cloud-Zugriff.</li>" &
         "  <li><b>High-Density UI:</b> Optimiert für datenintensive Fachanwendungen mit <code>globalblauklein.css</code>, <code>vs.css</code> und <code>vs-mobile.css</code>.</li>" &
         "  <li><b>Echtes Two-Way Eventing:</b> UI-Ereignisse (Klicks, Änderungen) werden direkt an OpenEuphoria-Handler weitergeleitet.</li>" &
         "  <li><b>Virtuelle Java 25 Threads:</b> Extrem skalierbarer HTTP-Server mit minimalem Ressourcenbedarf.</li>" &
         "</ul>"},
        {"Dokumentation der REST- & Event-API",
         "<p>Events werden über <code>POST /__vs_event</code> als JSON ausgetauscht. Antworten enthalten gezielte DOM-Patches (<code>patch</code>, <code>setValue</code>, <code>toast</code>, <code>modalOpen</code>, <code>fieldError</code>).</p>"}
    })

    -- Modal Dialog
    sequence modal_dlg = vsui:modal("modal_sysinfo", "Systeminformationen: Euphorix VS-UI Suite", {
        "<p><b>Version:</b> Euphorix 1.0.0 (Java 25 VM)</p>\n",
        "<p><b>UI-Framework:</b> High-Density VS-UI Suite (integriert in <code>./html/</code>)</p>\n",
        "<p><b>Assets:</b> ldom.js, vsevent.js, vsgrid.js, globalblauklein.css, vs.css, vs-mobile.css</p>\n",
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

    return vsui:page("Euphorix CRM / ERP Cockpit (VS-UI)", full_body)
end function

-- 3. Event Handler
function on_add_kunde(sequence ctx)
    sequence kdnr   = vsui:val(ctx, "txt_kdnr", "")
    sequence name   = vsui:val(ctx, "txt_name", "")
    sequence email  = vsui:val(ctx, "txt_email", "")
    sequence ort    = vsui:val(ctx, "txt_ort", "Unbekannt")
    sequence datum  = vsui:val(ctx, "dt_erfasst", "2026-11-24")
    sequence zeit   = vsui:val(ctx, "tm_erfasst", "10:00")
    sequence notiz  = vsui:val(ctx, "txt_notiz", "")
    sequence ums_s  = vsui:val(ctx, "num_umsatz", "0")
    sequence status = vsui:val(ctx, "cmb_status", "B-Kunde")
    integer aktiv   = equal(vsui:val(ctx, "chk_aktiv", "0"), "1")

    -- 1. Validierung der Pflichtfelder mit Fehlertooltips
    sequence val_kdnr = vsui:validate_required(ctx, "txt_kdnr", "Kundennummer")
    if val_kdnr[1] = 0 then
        return vsui:updates({
            vsui:field_error("txt_kdnr", val_kdnr[2]),
            vsui:set_focus("txt_kdnr"),
            vsui:toast_show(val_kdnr[2], vsui:TOAST_WARNING, 3500)
        })
    end if

    sequence val_name = vsui:validate_required(ctx, "txt_name", "Kundenname")
    if val_name[1] = 0 then
        return vsui:updates({
            vsui:field_clear_error("txt_kdnr"),
            vsui:field_error("txt_name", val_name[2]),
            vsui:set_focus("txt_name"),
            vsui:toast_show(val_name[2], vsui:TOAST_WARNING, 3500)
        })
    end if

    sequence val_mail = vsui:validate_email(email)
    if val_mail[1] = 0 then
        return vsui:updates({
            vsui:field_clear_error("txt_kdnr"),
            vsui:field_clear_error("txt_name"),
            vsui:field_error("txt_email", val_mail[2]),
            vsui:set_focus("txt_email"),
            vsui:toast_show(val_mail[2], vsui:TOAST_WARNING, 3500)
        })
    end if

    -- Alle Validierungen bestanden -> Fehler zurücksetzen
    atom umsatz = 0.0
    object v = conv:to_number(ums_s)
    if sequence(v) and length(v) = 2 and v[1] = 0 then
        umsatz = v[2]
    elsif atom(v) then
        umsatz = v
    end if

    sqlite:exec(db, "INSERT OR REPLACE INTO kunden (kdnr, name, ort, email, datum, uhrzeit, umsatz, status, aktiv, notiz) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);",
                {kdnr, name, ort, email, datum, zeit, umsatz, status, aktiv, notiz})

    integer kunden_anz = sqlite:query_value(db, "SELECT COUNT(*) FROM kunden;", {}, 0)
    atom umsatz_ges    = 0.0
    object u_val       = sqlite:query_value(db, "SELECT COALESCE(SUM(umsatz), 0.0) FROM kunden;", {}, 0.0)
    if atom(u_val) then umsatz_ges = u_val end if

    return vsui:updates({
        vsui:field_clear_error("txt_kdnr"),
        vsui:field_clear_error("txt_name"),
        vsui:field_clear_error("txt_email"),
        vsui:patch("kunden_grid_box", render_kunden_grid()),
        vsui:patch("kpi_kunden", sprintf("%d", {kunden_anz})),
        vsui:patch("kpi_umsatz", sprintf("%.2f €", {umsatz_ges})),
        vsui:clear_form("form_kunde"),
        vsui:set_focus("txt_kdnr"),
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

function on_clear_form(sequence ctx)
    return vsui:updates({
        vsui:field_clear_error("txt_kdnr"),
        vsui:field_clear_error("txt_name"),
        vsui:field_clear_error("txt_email"),
        vsui:clear_form("form_kunde"),
        vsui:set_focus("txt_kdnr"),
        vsui:toast_show("Formularfelder geleert.", vsui:TOAST_INFO, 2000)
    })
end function

function on_update_charts(sequence ctx)
    -- Simuliertes Update mit frischen Quartalszahlen
    sequence frische_labels = {"Q1/26 (Ist)", "Q2/26 (Ist)", "Q3/26 (Hochrechnung)", "Q4/26 (Ziel)"}
    sequence frische_werte  = {155000, 210000, 245000, 310000}

    return vsui:updates({
        vsui:chart_set_data("chart_quartal", "bar", frische_labels, frische_werte),
        vsui:toast_show("Quartalsdaten live im SVG-Chart aktualisiert!", vsui:TOAST_SUCCESS, 3000)
    })
end function

function on_file_upload(sequence ctx)
    sequence fname = vsui:val(ctx, "filename", "unbenannt.dat")
    sequence fsize_str = vsui:val(ctx, "size", "0")
    sequence fmtype = vsui:val(ctx, "type", "application/octet-stream")
    integer fsize = 0
    object num = conv:to_number(fsize_str)
    if sequence(num) and length(num) = 2 and num[1] = 0 then
        fsize = floor(num[2])
    elsif atom(num) then
        fsize = floor(num)
    end if

    sequence ts = "2026-11-25 11:50"
    sqlite:exec(db, "INSERT INTO dokumente (filename, groesse, mimetype, uhrzeit) VALUES (?, ?, ?, ?);",
                {fname, fsize, fmtype, ts})

    return vsui:updates({
        vsui:patch("docs_grid_box", render_dokumente_grid()),
        vsui:toast_show(sprintf("Dokument '%s' erfolgreich hochgeladen und archiviert!", {fname}), vsui:TOAST_SUCCESS, 3500)
    })
end function

function on_delete_dokument(sequence ctx)
    sequence docid_s = vsui:val(ctx, "docid", "")
    if length(docid_s) > 0 then
        sqlite:exec(db, "DELETE FROM dokumente WHERE id = ?;", {docid_s})
    end if
    return vsui:updates({
        vsui:patch("docs_grid_box", render_dokumente_grid()),
        vsui:toast_show("Dokument gelöscht.", vsui:TOAST_INFO, 2500)
    })
end function

function on_open_info(sequence ctx)
    return vsui:updates({
        vsui:modal_open("modal_sysinfo")
    })
end function

-- 4. Server registrieren und starten
integer app = vsui:app("Euphorix CRM Cockpit (VS-UI)", 8089)
vsui:page_route(app, "/", routine_id("render_cockpit_page"))
vsui:on_event(app, "add_kunde", routine_id("on_add_kunde"))
vsui:on_event(app, "delete_kunde", routine_id("on_delete_kunde"))
vsui:on_event(app, "clear_form", routine_id("on_clear_form"))
vsui:on_event(app, "file_upload", routine_id("on_file_upload"))
vsui:on_event(app, "upload_complete", routine_id("on_file_upload"))
vsui:on_event(app, "delete_dokument", routine_id("on_delete_dokument"))
vsui:on_event(app, "update_charts", routine_id("on_update_charts"))
vsui:on_event(app, "open_info_modal", routine_id("on_open_info"))

vsui:run(app)
