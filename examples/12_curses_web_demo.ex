-- =============================================================================
-- Beispiel 12: Moderne Vollbild-Terminal-Oberfläche (VS-TUI) im Webbrowser
-- Nutzt 100% des Browser-Fensters (100vw x 100vh) ohne Retro-Ränder.
--
-- Voller Funktionsumfang wie vsui.e:
--   * Modul-Tabs (👥 Kundenstamm, 📦 Aufträge, ➕ Erfassen, 📊 Kennzahlen)
--   * Master-Detail-Splitter (DataGrid links, Detailkarte rechts)
--   * Automatisches Viewport-Scrolling & echte TUI-Scrollbar (▲, █, ░, ▼)
--   * Grafische Einbindung von Bildern (Firmenlogo, Artikelbilder) im Terminal
--   * Numerische Felder mit deutscher Währungsformatierung (vsnuminput)
--   * Datums- & Zeitfelder (vsdateinput mit Popup-Kalender)
--   * Dropdowns, Checkboxen, großzügige mehrzeilige Textareas
--   * Fehlerfreie Unicode-Balkendiagramme (vschart)
--   * Toast-Meldungen & schwebende Modal-Dialoge
--   * Reine Mausbedienung + Standard-Tastatur (Pfeile, Enter, Esc, / für Suche)
--   * KEINE Funktionstasten (F1-F12), dadurch keine Browser-Konflikte!
--
-- Starten mit:
--   ./euphorix examples/12_curses_web_demo.ex
-- Anschließend im Browser öffnen:
--   http://localhost:8092
-- =============================================================================

include std/vstui.e as tui
include std/http.e as http
include std/json.e as json
include std/text.e
include std/search.e
include std/io.e as io
include std/filesys.e as filesys
include std/get.e as get

puts(1, "=====================================================================\n")
puts(1, "  Euphorix VS-TUI Cockpit (100% Vollbild-Terminal im Browser)\n")
puts(1, "  URL: http://localhost:8092\n")
puts(1, "=====================================================================\n")

-- 1. Anwendungszustand & Daten
integer active_tab     = 1
integer selected_row   = 1
integer selected_order = 1
sequence toast_msg     = ""
sequence toast_type    = "success"
sequence modal_title   = ""
sequence modal_lines   = {}
sequence status_msg    = "Bereit. Zeilen und Buttons sind direkt mit der Maus anklickbar."

-- TUI Kalender-Popup Zustand
sequence cal_target_field = ""
integer cal_year  = 2026
integer cal_month = 11
integer cal_day   = 27

-- Umfangreicher Kundenstamm (20 Datensätze zum Testen des automatischen Scrollens)
sequence kunden = {
    {"K-1001", "Schulze GmbH", "Dortmund", "info@schulze.de", 14250.00, "2026-11-20", "A-Kunde", 1, "Top-Kunde im Maschinenbau.\nRahmenvertrag bis 2028 verlängert.\nAnsprechpartner Herr Dr. Schulze."},
    {"K-1002", "Meyer & Co. KG", "Bochum", "kontakt@meyer.com", 28900.50, "2026-11-22", "A-Kunde", 1, "Rahmenvertrag 2026 aktiv.\nLieferung frei Haus vereinbart.\nSkonto 2% bei Zahlung in 14 Tagen."},
    {"K-1003", "Bauer Logistik", "Essen", "dispo@bauer.de", 4890.00, "2026-11-24", "C-Kunde", 0, "Zahlungsverzug mahnen.\nKreditlimit vorerst gesperrt."},
    {"K-1004", "Schmidt IT AG", "Köln", "admin@schmidt.de", 45150.00, "2026-11-25", "A-Kunde", 1, "Cloud-Migration gebucht.\nHigh-Priority Support 24/7."},
    {"K-1005", "Hoffmann Handel", "Düsseldorf", "verkauf@hoffmann.de", 9340.00, "2026-11-26", "B-Kunde", 1, "Interesse an ERP-Suite.\nDemo-Termin vereinbart."},
    {"K-1006", "Weber Maschinen", "Münster", "leitung@weber-m.de", 31200.00, "2026-11-15", "A-Kunde", 1, "Modernisierung Fertigungshalle 3.\nUpgrade auf 10G-Netzwerk."},
    {"K-1007", "Fischer Elektronik", "Wuppertal", "einkauf@fischer-el.de", 12400.00, "2026-11-16", "B-Kunde", 1, "Regelmäßige Nachbestellungen von Racks.\nZuverlässiger Zahler."},
    {"K-1008", "Becker Medizintechnik", "Bonn", "service@becker-med.de", 54300.00, "2026-11-18", "A-Kunde", 1, "Reinraum-Servertechnik.\nStrikte SLAs und Redundanzpflicht."},
    {"K-1009", "Wagner Chemie AG", "Leverkusen", "it@wagner-chemie.de", 68900.00, "2026-11-19", "A-Kunde", 1, "Sicherheitszertifizierung ISO 27001.\nProjektphase läuft planmäßig."},
    {"K-1010", "Koch Bauunternehmung", "Duisburg", "info@koch-bau.de", 7800.00, "2026-11-21", "B-Kunde", 1, "Baustellenanbindung per Glasfaser.\nErweiterung im Frühjahr geplant."},
    {"K-1011", "Richter & Söhne", "Krefeld", "zentrale@richter-gmbh.de", 16450.00, "2026-11-22", "B-Kunde", 1, "Modernisierung der Buchhaltungssysteme.\nSchulung der Mitarbeiter abgeschlossen."},
    {"K-1012", "Klein Datensysteme", "Aachen", "technik@klein-data.de", 22100.00, "2026-11-23", "A-Kunde", 1, "Forschungsprojekt KI-Infrastruktur.\nClustererweiterung angefragt."},
    {"K-1013", "Wolf Logistikzentrum", "Mönchengladbach", "dispo@wolf-log.de", 11200.00, "2026-11-23", "B-Kunde", 1, "Barcode- und Scannersysteme vernetzt."},
    {"K-1014", "Schröder Automobil", "Siegen", "it-support@schroeder-auto.de", 38700.00, "2026-11-24", "A-Kunde", 1, "Lieferantenportal integriert.\nNächster Audit im Januar."},
    {"K-1015", "Neumann Druckhaus", "Hagen", "produktion@neumann-print.de", 6500.00, "2026-11-25", "C-Kunde", 1, "Digitaldruckmaschinen vernetzt."},
    {"K-1016", "Schwarz Lebensmittel", "Hamm", "einkauf@schwarz-food.de", 19800.00, "2026-11-25", "B-Kunde", 1, "Kühlkettenüberwachung mit Sensoren."},
    {"K-1017", "Zimmermann Holzbau", "Paderborn", "buero@zimmermann-holz.de", 8400.00, "2026-11-26", "B-Kunde", 1, "CAD-Arbeitsplätze angebunden."},
    {"K-1018", "Braun Medienservice", "Bielefeld", "kontakt@braun-media.de", 15300.00, "2026-11-26", "B-Kunde", 1, "Streaming-Server und Storage-Pools."},
    {"K-1019", "Krüger Stahlbau", "Gelsenkirchen", "dispo@krueger-stahl.de", 27400.00, "2026-11-27", "A-Kunde", 1, "Großauftrag Trägerkonstruktion."},
    {"K-1020", "Hartmann Pharma", "Münster", "pharma@hartmann-lab.de", 82000.00, "2026-11-27", "A-Kunde", 1, "Labornetzwerk hochsicher isoliert."},
    {"K-1021", "Lange Feinmechanik", "Solingen", "info@lange-fm.de", 17500.00, "2026-11-20", "B-Kunde", 1, "CNC-Steuerungen modernisiert."},
    {"K-1022", "Werner & Partner", "Bonn", "kanzlei@werner-law.de", 13200.00, "2026-11-21", "B-Kunde", 1, "Dokumentenmanagement im Einsatz."},
    {"K-1023", "Krause Metallbau", "Oberhausen", "einkauf@krause-mb.de", 21800.00, "2026-11-22", "A-Kunde", 1, "Hallenvernetzung abgeschlossen."},
    {"K-1024", "Meier Energie", "Herne", "service@meier-energie.de", 34600.00, "2026-11-23", "A-Kunde", 1, "Smart-Grid Monitoring aktiv."},
    {"K-1025", "Lehmann Logistik", "Krefeld", "dispo@lehmann-log.de", 9800.00, "2026-11-24", "C-Kunde", 0, "Bonitätsprüfung ausstehend."},
    {"K-1026", "Köhler Kunststoff", "Bottrop", "it@koehler-plast.de", 15400.00, "2026-11-25", "B-Kunde", 1, "Extrudersteuerungen angebunden."},
    {"K-1027", "Herrmann Software", "Marl", "info@herrmann-soft.de", 41200.00, "2026-11-25", "A-Kunde", 1, "DevOps Cluster im Rechenzentrum."},
    {"K-1028", "König Textil AG", "Mönchengladbach", "einkauf@koenig-tex.de", 18900.00, "2026-11-26", "B-Kunde", 1, "Weberei-Sensoren vernetzt."},
    {"K-1029", "Huber Verpackung", "Ratingen", "kontakt@huber-pack.de", 29300.00, "2026-11-26", "A-Kunde", 1, "Automatisierte Palettierung."},
    {"K-1030", "Vogel Haustechnik", "Lüdenscheid", "service@vogel-ht.de", 11700.00, "2026-11-27", "B-Kunde", 1, "Wärmepumpen-Fernwartung."}
}

-- Auftragsliste mit zugeordneten Produktgrafiken (16 Datensätze zum Durchscrollen)
sequence auftraege = {
    {"#501", "K-1001", "A-801", "Server-Rack 42HE High-Density", "2", "3.400,00 €", "Geliefert", "/img/art_server.svg"},
    {"#502", "K-1002", "A-104", "USV 3000VA Smart Online", "4", "4.800,00 €", "In Bearbeitung", "/img/art_usv.svg"},
    {"#503", "K-1004", "A-992", "Glasfaser-Trunk 10G OM4", "1", "12.500,00 €", "Neu", "/img/art_fiber.svg"},
    {"#504", "K-1005", "A-205", "Klimasteuerung RZ InRow 12kW", "1", "6.200,00 €", "Geliefert", "/img/art_klima.svg"},
    {"#505", "K-1006", "A-801", "Server-Rack 42HE High-Density", "1", "1.700,00 €", "Versendet", "/img/art_server.svg"},
    {"#506", "K-1008", "A-104", "USV 3000VA Smart Online", "2", "2.400,00 €", "In Bearbeitung", "/img/art_usv.svg"},
    {"#507", "K-1009", "A-992", "Glasfaser-Trunk 10G OM4", "3", "37.500,00 €", "Neu", "/img/art_fiber.svg"},
    {"#508", "K-1010", "A-205", "Klimasteuerung RZ InRow 12kW", "2", "12.400,00 €", "Geliefert", "/img/art_klima.svg"},
    {"#509", "K-1012", "A-801", "Server-Rack 42HE High-Density", "4", "6.800,00 €", "Versendet", "/img/art_server.svg"},
    {"#510", "K-1014", "A-104", "USV 3000VA Smart Online", "1", "1.200,00 €", "Geliefert", "/img/art_usv.svg"},
    {"#511", "K-1016", "A-205", "Klimasteuerung RZ InRow 12kW", "1", "6.200,00 €", "In Bearbeitung", "/img/art_klima.svg"},
    {"#512", "K-1018", "A-992", "Glasfaser-Trunk 10G OM4", "2", "25.000,00 €", "Neu", "/img/art_fiber.svg"},
    {"#513", "K-1019", "A-801", "Server-Rack 42HE High-Density", "2", "3.400,00 €", "Versendet", "/img/art_server.svg"},
    {"#514", "K-1020", "A-104", "USV 3000VA Smart Online", "6", "7.200,00 €", "In Bearbeitung", "/img/art_usv.svg"},
    {"#515", "K-1001", "A-992", "Glasfaser-Trunk 10G OM4", "1", "12.500,00 €", "Geliefert", "/img/art_fiber.svg"},
    {"#516", "K-1002", "A-205", "Klimasteuerung RZ InRow 12kW", "1", "6.200,00 €", "Neu", "/img/art_klima.svg"},
    {"#517", "K-1021", "A-801", "Server-Rack 42HE High-Density", "2", "3.400,00 €", "Versendet", "/img/art_server.svg"},
    {"#518", "K-1022", "A-104", "USV 3000VA Smart Online", "2", "2.400,00 €", "In Bearbeitung", "/img/art_usv.svg"},
    {"#519", "K-1023", "A-992", "Glasfaser-Trunk 10G OM4", "4", "50.000,00 €", "Neu", "/img/art_fiber.svg"},
    {"#520", "K-1024", "A-205", "Klimasteuerung RZ InRow 12kW", "1", "6.200,00 €", "Geliefert", "/img/art_klima.svg"},
    {"#521", "K-1026", "A-801", "Server-Rack 42HE High-Density", "3", "5.100,00 €", "In Bearbeitung", "/img/art_server.svg"},
    {"#522", "K-1027", "A-104", "USV 3000VA Smart Online", "5", "6.000,00 €", "Versendet", "/img/art_usv.svg"},
    {"#523", "K-1028", "A-992", "Glasfaser-Trunk 10G OM4", "2", "25.000,00 €", "Geliefert", "/img/art_fiber.svg"},
    {"#524", "K-1029", "A-205", "Klimasteuerung RZ InRow 12kW", "2", "12.400,00 €", "Neu", "/img/art_klima.svg"},
    {"#525", "K-1030", "A-801", "Server-Rack 42HE High-Density", "1", "1.700,00 €", "Geliefert", "/img/art_server.svg"}
}

-- Formular-Puffer für Neukunden-Erfassung
sequence form_kdnr   = "K-1021"
sequence form_name   = "Neuer Kunde GmbH"
sequence form_ort    = "Münster"
sequence form_email  = "info@neuerkunde.de"
atom form_umsatz     = 18500.00
sequence form_datum  = "2026-11-27"
sequence form_status = "B-Kunde"
integer form_aktiv   = 1
sequence form_notiz  = "Erstkontakt über Fachmesse Hannover.\nInteresse an Server-Infrastruktur und Redundanzlösungen.\nAngebot über 42HE-Racks angefordert."

-- 2. TUI Vollbild-Screen aufbauen (126 x 38 Raster)
function build_screen()
    sequence scr = tui:create(126, 38, "Euphorix ERP Cockpit (VS-TUI)")

    -- 1. Kopfzeile (Zeile 1) mit Firmenlogo
    scr = tui:draw_header(scr, "  VS-TUI ERP Cockpit", "Vollbild Terminal Engine (100vw x 100vh)", "admin@vsitsolutions.de")
    scr = tui:draw_image(scr, "img_hdr_logo", "/img/vsitsolutions.jpeg", 2, 1, 10, 1, "", "contain")

    -- 2. Modul-Tabs (Zeile 3)
    sequence tabs_list = {
        {"👥 Kundenstamm & Details", "tab_kunden"},
        {"📦 Auftragsübersicht & Artikel", "tab_auftraege"},
        {"➕ Neukunde erfassen", "tab_neukunde"},
        {"📊 Kennzahlen & Diagramme", "tab_charts"}
    }
    scr = tui:draw_tabs(scr, tabs_list, active_tab, 2, 3, 124)

    -- 3. KPI-Stat-Cards (Zeilen 5 bis 8)
    atom summe_umsatz = 0.0
    for i = 1 to length(kunden) do summe_umsatz += kunden[i][5] end for
    sequence kpi_items = {
        {"Jahresumsatz 2026", tui:format_num_de(summe_umsatz, 2, "€"), "↗ +16.4%", 1},
        {"Aktive Kunden", sprintf("%d Kunden", {length(kunden)}), "↗ +5", 1},
        {"Auftragsvolumen", "149.900,00 €", "↗ +11.2%", 1},
        {"Offene Lieferungen", "5 Aufträge", "↘ -2", 0}
    }
    scr = tui:draw_kpi_cards(scr, kpi_items, 2, 5, 124)

    -- 4. Modul-Inhalt je nach aktivem Tab (Zeilen 10 bis 36)
    if active_tab = 1 then
        -- =====================================================================
        -- TAB 1: MASTER-DETAIL SPLITTER (Kundenliste links, Detailkarte rechts)
        -- =====================================================================
        -- Linke Seite: DataGrid mit automatischem Viewport-Scrolling & TUI Scrollbar
        sequence grid_headers = {
            {"Kd-Nr.", 9},
            {"Firmenname", 22},
            {"Ort", 14},
            {"Jahresumsatz", 16},
            {"Status", 11}
        }
        sequence grid_rows = {}
        for i = 1 to length(kunden) do
            sequence k = kunden[i]
            grid_rows = append(grid_rows, {
                k[1],
                k[2],
                k[3],
                tui:format_num_de(k[5], 2, "€"),
                k[7]
            })
        end for
        scr = tui:draw_table(scr, "grd_kunden", grid_headers, grid_rows, 2, 10, 76, 26, selected_row)

        -- Rechte Seite: Detailkarte des ausgewählten Kunden (Breite 46, Höhe 26)
        scr = tui:box(scr, 80, 10, 46, 26, "Kundendetails (Master-Detail)", tui:C_BORDER, tui:C_BG_PANEL)
        if selected_row >= 1 and selected_row <= length(kunden) then
            sequence sel = kunden[selected_row]
            
            -- Felder mit einheitlicher rechter Rahmenausrichtung
            scr = tui:draw_input(scr, "txt_kdnr", "Kundennr.:", sel[1], 83, 11, 14)
            scr = tui:draw_input(scr, "txt_name", "Firma:    ", sel[2], 83, 13, 24)
            scr = tui:draw_input(scr, "txt_ort",  "Ort:      ", sel[3], 83, 15, 24)
            scr = tui:draw_input(scr, "txt_mail", "E-Mail:   ", sel[4], 83, 17, 24)
            
            -- Numerisches Feld mit deutscher Währungsformatierung (vsnuminput)
            scr = tui:draw_numinput(scr, "num_umsatz", "Umsatz:   ", sel[5], 2, "€", 83, 19, 18)
            
            -- Datum & Dropdown
            scr = tui:draw_dateinput(scr, "dt_erfasst", "Erfasst:  ", sel[6], 83, 21, 18)
            scr = tui:draw_combo(scr, "cmb_status", "Status:   ", sel[7], 83, 23, 18)
            scr = tui:draw_checkbox(scr, "chk_aktiv", "Konto aktiv & freigeschaltet", sel[8], 83, 25)

            -- Großes Notizfeld (Höhe 6 Zeilen = 4 volle Zeilen Textbereich!)
            scr = tui:draw_textarea(scr, "txa_notiz", "Notizen & Historie", {sel[9]}, 83, 27, 40, 5)

            -- Aktionsbuttons unten
            scr = tui:draw_button(scr, "btn_save_detail", "💾 Speichern", 83, 33, "primary")
            scr = tui:draw_button(scr, "btn_new_from_detail", "➕ Neu", 101, 33, "accent")
            scr = tui:draw_button(scr, "btn_delete_kunde", "🗑 Löschen", 112, 33, "danger")
        end if

    elsif active_tab = 2 then
        -- =====================================================================
        -- TAB 2: AUFTRAGSÜBERSICHT & ARTIKELVORSCHAU MIT BILD
        -- =====================================================================
        sequence auftrag_headers = {
            {"Auftrag", 10},
            {"Kunde", 10},
            {"Art.-Nr.", 11},
            {"Artikelbezeichnung", 26},
            {"Preis", 13}
        }
        sequence auftrag_rows = {}
        for i = 1 to length(auftraege) do
            sequence a = auftraege[i]
            auftrag_rows = append(auftrag_rows, {
                a[1], a[2], a[3], a[4], a[6]
            })
        end for
        -- DataGrid links (Breite 76, Höhe 26) mit eigenem Scrolling über selected_order!
        scr = tui:draw_table(scr, "grd_auftraege", auftrag_headers, auftrag_rows, 2, 10, 76, 26, selected_order)

        -- Rechte Seite: Artikel- und Auftragsdetails mit echtem Bild (Breite 46, Höhe 26)
        scr = tui:box(scr, 80, 10, 46, 26, "Artikel- & Auftragsdetails", tui:C_BORDER, tui:C_BG_PANEL)
        if selected_order >= 1 and selected_order <= length(auftraege) then
            sequence ord = auftraege[selected_order]
            
            -- Header-Info
            sequence ord_info = sprintf("Auftrag: %s   Kunde: %s", {ord[1], ord[2]})
            scr = tui:print_at(scr, 83, 11, ord_info, tui:C_CYAN, tui:C_BG_PANEL)

            -- Echtes Produktbild (Server-Rack, USV, Glasfaser, Klima)
            sequence art_img = ord[8]
            scr = tui:draw_image(scr, "img_artikel_preview", art_img, 83, 12, 40, 10, "Produktabbildung", "contain")

            -- Artikel-Stammdaten & Status
            scr = tui:print_at(scr, 83, 23, "Artikel-Nr.:  " & ord[3], tui:C_MUTED, tui:C_BG_PANEL)
            scr = tui:print_at(scr, 83, 24, "Bezeichnung: " & ord[4], tui:C_TEXT, tui:C_BG_PANEL)
            scr = tui:print_at(scr, 83, 26, "Menge:       " & ord[5] & " Stück", tui:C_TEXT, tui:C_BG_PANEL)
            scr = tui:print_at(scr, 83, 27, "Gesamtpreis: " & ord[6], tui:C_GREEN, tui:C_BG_PANEL)
            
            sequence st_color = tui:C_TEXT
            if equal(ord[7], "Geliefert") then st_color = tui:C_GREEN
            elsif equal(ord[7], "In Bearbeitung") then st_color = tui:C_AMBER
            elsif equal(ord[7], "Versendet") then st_color = tui:C_CYAN
            end if
            scr = tui:print_at(scr, 83, 29, "Status:      " & ord[7], st_color, tui:C_BG_PANEL)

            -- Aktionsbuttons
            scr = tui:draw_button(scr, "btn_order_deliver", "🚚 Als geliefert", 83, 32, "primary")
            scr = tui:draw_button(scr, "btn_order_print", "📄 Beleg drucken", 104, 32, "accent")
        end if

    elsif active_tab = 3 then
        -- =====================================================================
        -- TAB 3: NEUKUNDEN-REGISTRIERUNG (Vollständiges Eingabeformular)
        -- =====================================================================
        scr = tui:box(scr, 15, 10, 96, 26, "Neuen Kundenstammsatz anlegen", tui:C_BORDER, tui:C_BG_PANEL)
        
        scr = tui:print_at(scr, 18, 12, "Erfassen Sie die Stammdaten für Neukunden mit automatischer Validierung:", tui:C_MUTED, tui:C_BG_PANEL)
        
        scr = tui:draw_input(scr, "f_kdnr",  "Kundennummer: ", form_kdnr,  18, 14, 18)
        scr = tui:draw_dateinput(scr, "f_datum", "Erfassungsdatum:", form_datum, 58, 14, 18)

        scr = tui:draw_input(scr, "f_name",  "Firmenname:   ", form_name,  18, 16, 18)
        scr = tui:draw_combo(scr, "f_status", "Kundenkategorie:", form_status, 58, 16, 18)

        scr = tui:draw_input(scr, "f_ort",   "Standort/Ort: ", form_ort,   18, 18, 18)
        scr = tui:draw_checkbox(scr, "f_aktiv", "Kunde sofort aktiv schalten", form_aktiv, 58, 18)

        scr = tui:draw_input(scr, "f_email", "E-Mail-Adresse:", form_email, 18, 20, 18)
        -- Numerisches Feld für Umsatz/Kreditlimit mit Nachkommastellen & Währung
        scr = tui:draw_numinput(scr, "f_umsatz", "Kreditlimit:   ", form_umsatz, 2, "€", 58, 20, 18)

        -- Großzügiges Notizfeld (Höhe 6 Zeilen = 4 volle Zeilen Text!)
        scr = tui:draw_textarea(scr, "f_notiz", "Ergänzende Bemerkungen & Konditionen", {form_notiz}, 18, 23, 88, 6)

        -- 3-zeilige Buttons: Beschriftung in Zeile 2 zentriert, Zeile 3 mit Hotkey/Subtitle
        scr = tui:draw_button(scr, "btn_submit_neukunde", "💾 Neukunden verbindlich speichern", 18, 31, "primary", 42, 3, "[Eingabe / Submit]")
        scr = tui:draw_button(scr, "btn_reset_form", "✕ Formular leeren", 64, 31, "danger", 25, 3)

    elsif active_tab = 4 then
        -- =====================================================================
        -- TAB 4: KENNZAHLEN, DIAGRAMME & LOGO-DARSTELLUNG
        -- =====================================================================
        sequence q_labels = {"Q1/26 (Ist)", "Q2/26 (Ist)", "Q3/26 (Plan)", "Q4/26 (Plan)"}
        sequence q_values = {142500, 187400, 215800, 265000}
        -- Balkendiagramm mit echten Unicode-Balken █ (ohne Fragezeichen!)
        scr = tui:draw_barchart(scr, "ch_quartal", "Quartalsumsatz 2026 (EUR)", q_labels, q_values, 2, 10, 60, 12)

        sequence k_labels = {"A-Kunden", "B-Kunden", "C-Kunden", "Partner"}
        sequence k_values = {58, 26, 12, 4}
        scr = tui:draw_barchart(scr, "ch_kategorien", "Kundenanteile nach Kategorie (%)", k_labels, k_values, 64, 10, 62, 12)

        -- Info-Panel links darunter
        scr = tui:box(scr, 2, 23, 60, 13, "Vollbild-TUI Engine Vorteile", tui:C_BORDER, tui:C_BG_PANEL)
        scr = tui:print_at(scr, 4, 25, "• 100% Vollbild-Terminal: 100vw x 100vh ohne Ränder.", tui:C_TEXT, tui:C_BG_PANEL)
        scr = tui:print_at(scr, 4, 26, "• Bilddarstellung: Integriert Grafiken direkt im Grid.", tui:C_GREEN, tui:C_BG_PANEL)
        scr = tui:print_at(scr, 4, 27, "• DataGrid Scrolling: TUI-Scrollbar & Zähler.", tui:C_TEXT, tui:C_BG_PANEL)
        scr = tui:print_at(scr, 4, 28, "• Native Inputs: Zahlenformatierung, Datepicker-Popup.", tui:C_TEXT, tui:C_BG_PANEL)
        scr = tui:print_at(scr, 4, 29, "• Keine F-Tasten: Tastatur + Maus ohne Konflikte.", tui:C_MUTED, tui:C_BG_PANEL)
        scr = tui:draw_button(scr, "btn_demo_toast", "📢 Test-Toast", 4, 32, "accent")
        scr = tui:draw_button(scr, "btn_demo_modal", "🗔 Test-Modal", 22, 32, "primary")

        -- Rechtes Panel: Firmenlogo in hoher Auflösung (JPEG)
        scr = tui:draw_image(scr, "img_company_logo", "/img/vsitsolutions.jpeg", 64, 23, 62, 13, "VS IT-Solutions GmbH - Technologieführerschaft", "contain")
    end if

    -- 5. Toast-Benachrichtigung oben rechts (falls aktiv)
    if length(toast_msg) > 0 then
        scr = tui:draw_toast(scr, toast_msg, toast_type)
    end if

    -- 6. Schwebender Modal-Dialog oder TUI-Kalender (falls aktiv)
    if length(modal_title) > 0 then
        scr = tui:draw_modal(scr, "win_modal", modal_title, modal_lines, {
            {"close_modal", "  Verstanden [Enter/Esc]  ", "primary"}
        })
    elsif length(cal_target_field) > 0 then
        scr = tui:draw_calendar_modal(scr, cal_target_field, cal_year, cal_month, cal_day)
    end if

    -- 7. Statuszeile unten (Zeile 38)
    scr = tui:draw_footer(scr, status_msg, "↑/↓ & Mausrad: Scrollen  •  Klick: Zeile/Button  •  Enter: Speichern  •  Esc: Abbrechen")

    return scr
end function

-- 3. HTTP Server & Event-Handling
function handle_index(sequence req)
    sequence scr = build_screen()
    sequence html = tui:render_page(scr, "Euphorix ERP Cockpit (Modern VS-TUI)")
    return http:response(200, html, "text/html; charset=utf-8")
end function

-- Statische Bilddateien aus html/img/ ausliefern (JPEG, PNG, SVG, WebP)
function handle_static_img(sequence req)
    sequence path = req[http:REQ_PATH]
    sequence filepath = "html" & path
    if filesys:file_exists(filepath) then
        object bytes = io:read_file(filepath)
        if sequence(bytes) then
            sequence mime = "image/jpeg"
            if search:ends(".png", filepath) then mime = "image/png"
            elsif search:ends(".svg", filepath) then mime = "image/svg+xml"
            elsif search:ends(".webp", filepath) then mime = "image/webp"
            elsif search:ends(".gif", filepath) then mime = "image/gif"
            end if
            return http:response(200, bytes, mime, {{"Cache-Control", "public, max-age=86400"}})
        end if
    end if
    return http:response(404, "Bild nicht gefunden: " & path, "text/plain; charset=utf-8")
end function

function handle_tui_event(sequence req)
    sequence body_str = req[http:REQ_BODY]
    object parsed = json:parse(body_str)

    if sequence(parsed) and length(parsed) >= 2 and parsed[1] = 1 and json:is_object(parsed[2]) then
        object doc = parsed[2]
        sequence action = json:get(doc, "action", "")
        object fields = json:get(doc, "fields", {})

        -- Modal schließen bei Klick oder Escape
        if length(modal_title) > 0 then
            if equal(action, "close_modal") or equal(action, "escape") or equal(action, "enter") then
                modal_title = ""
                modal_lines = {}
                status_msg = "Dialog geschlossen."
            end if
        elsif length(cal_target_field) > 0 then
            -- TUI Kalender-Events
            if equal(action, "cal_btn_cancel") or equal(action, "escape") then
                cal_target_field = ""
                status_msg = "Datumsauswahl abgebrochen."
            elsif equal(action, "cal_prev_month") then
                cal_month -= 1
                if cal_month < 1 then
                    cal_month = 12
                    cal_year -= 1
                end if
            elsif equal(action, "cal_next_month") then
                cal_month += 1
                if cal_month > 12 then
                    cal_month = 1
                    cal_year += 1
                end if
            elsif search:begins("cal_select_", action) then
                sequence d_str = action[12..$]
                object v = get:value(d_str)
                if v[1] = get:GET_SUCCESS and integer(v[2]) then
                    cal_day = v[2]
                end if
            elsif equal(action, "cal_btn_today") then
                cal_year  = 2026
                cal_month = 11
                cal_day   = 27
                status_msg = "Heutiges Datum ausgewählt."
            elsif equal(action, "cal_btn_apply") or equal(action, "enter") then
                sequence new_dt = sprintf("%04d-%02d-%02d", {cal_year, cal_month, cal_day})
                if equal(cal_target_field, "dt_erfasst") then
                    kunden[selected_row][6] = new_dt
                elsif equal(cal_target_field, "f_datum") then
                    form_datum = new_dt
                end if
                toast_msg = sprintf("Datum '%s' übernommen!", {new_dt})
                toast_type = "success"
                status_msg = toast_msg
                cal_target_field = ""
            end if
        else
            -- Toast schließen
            if equal(action, "close_toast") then
                toast_msg = ""
            -- TUI-Kalender öffnen
            elsif search:begins("open_date_", action) then
                cal_target_field = action[11..$]
                sequence cur_dt = "2026-11-27"
                if equal(cal_target_field, "dt_erfasst") and length(kunden[selected_row][6]) >= 10 then
                    cur_dt = kunden[selected_row][6]
                elsif equal(cal_target_field, "f_datum") and length(form_datum) >= 10 then
                    cur_dt = form_datum
                end if
                object py = get:value(cur_dt[1..4])
                object pm = get:value(cur_dt[6..7])
                object pd = get:value(cur_dt[9..10])
                if py[1] = get:GET_SUCCESS and integer(py[2]) then cal_year = py[2] end if
                if pm[1] = get:GET_SUCCESS and integer(pm[2]) then cal_month = pm[2] end if
                if pd[1] = get:GET_SUCCESS and integer(pd[2]) then cal_day = pd[2] end if
                status_msg = "TUI-Datumsauswahl geöffnet."
            -- Tab-Wechsel
            elsif equal(action, "tab_1") or equal(action, "tab_kunden") then
                active_tab = 1
                status_msg = "Tab gewechselt: 👥 Kundenstamm & Details"
            elsif equal(action, "tab_2") or equal(action, "tab_auftraege") then
                active_tab = 2
                status_msg = "Tab gewechselt: 📦 Auftragsübersicht & Artikel"
            elsif equal(action, "tab_3") or equal(action, "tab_neukunde") then
                active_tab = 3
                status_msg = "Tab gewechselt: ➕ Neukunde erfassen"
            elsif equal(action, "tab_4") or equal(action, "tab_charts") then
                active_tab = 4
                status_msg = "Tab gewechselt: 📊 Kennzahlen & Diagramme"

            -- Tastaturnavigation & Mausrad-Scrolling (Pfeiltasten & Wheel)
            elsif equal(action, "arrow_down") or equal(action, "wheel_down") then
                if active_tab = 1 then
                    if selected_row < length(kunden) then
                        selected_row += 1
                        status_msg = sprintf("Kunde ausgewählt: %s (%s)", {kunden[selected_row][2], kunden[selected_row][1]})
                    end if
                elsif active_tab = 2 then
                    if selected_order < length(auftraege) then
                        selected_order += 1
                        status_msg = sprintf("Auftrag ausgewählt: %s (%s - %s)", {auftraege[selected_order][1], auftraege[selected_order][4], auftraege[selected_order][6]})
                    end if
                end if
            elsif equal(action, "arrow_up") or equal(action, "wheel_up") then
                if active_tab = 1 then
                    if selected_row > 1 then
                        selected_row -= 1
                        status_msg = sprintf("Kunde ausgewählt: %s (%s)", {kunden[selected_row][2], kunden[selected_row][1]})
                    end if
                elsif active_tab = 2 then
                    if selected_order > 1 then
                        selected_order -= 1
                        status_msg = sprintf("Auftrag ausgewählt: %s (%s - %s)", {auftraege[selected_order][1], auftraege[selected_order][4], auftraege[selected_order][6]})
                    end if
                end if

            -- Scrollbar Aktionen Kundenliste (▲ / ▼)
            elsif equal(action, "grd_kunden_page_up") then
                selected_row = selected_row - 5
                if selected_row < 1 then selected_row = 1 end if
                status_msg = sprintf("Kundenliste nach oben geblättert zu Zeile %d", {selected_row})
            elsif equal(action, "grd_kunden_page_down") then
                selected_row = selected_row + 5
                if selected_row > length(kunden) then selected_row = length(kunden) end if
                status_msg = sprintf("Kundenliste nach unten geblättert zu Zeile %d", {selected_row})

            -- Scrollbar Aktionen Auftragsliste (▲ / ▼)
            elsif equal(action, "grd_auftraege_page_up") then
                selected_order = selected_order - 5
                if selected_order < 1 then selected_order = 1 end if
                status_msg = sprintf("Auftragsliste nach oben geblättert zu Zeile %d", {selected_order})
            elsif equal(action, "grd_auftraege_page_down") then
                selected_order = selected_order + 5
                if selected_order > length(auftraege) then selected_order = length(auftraege) end if
                status_msg = sprintf("Auftragsliste nach unten geblättert zu Zeile %d", {selected_order})

            -- Zeilenauswahl per Mausklick auf Kundenzeile
            elsif search:match("grd_kunden_select_", action) = 1 then
                active_tab = 1
                sequence num_str = action[19..$]
                object v = get:value(num_str)
                if v[1] = get:GET_SUCCESS and integer(v[2]) and v[2] >= 1 and v[2] <= length(kunden) then
                    selected_row = v[2]
                    status_msg = sprintf("Klick auf Zeile #%d: Kunde '%s' geladen.", {selected_row, kunden[selected_row][2]})
                end if

            -- Zeilenauswahl per Mausklick auf Auftragszeile
            elsif search:match("grd_auftraege_select_", action) = 1 then
                active_tab = 2
                sequence num_str = action[22..$]
                object v = get:value(num_str)
                if v[1] = get:GET_SUCCESS and integer(v[2]) and v[2] >= 1 and v[2] <= length(auftraege) then
                    selected_order = v[2]
                    status_msg = sprintf("Klick auf Auftrag #%d: '%s' geladen.", {selected_order, auftraege[selected_order][4]})
                end if

            -- Auftrag als geliefert markieren
            elsif equal(action, "btn_order_deliver") then
                auftraege[selected_order][7] = "Geliefert"
                toast_msg = sprintf("Auftrag %s als GELIEFERT markiert!", {auftraege[selected_order][1]})
                toast_type = "success"
                status_msg = toast_msg
            elsif equal(action, "btn_order_print") then
                toast_msg = sprintf("Lieferschein für Auftrag %s wird generiert...", {auftraege[selected_order][1]})
                toast_type = "info"

            -- Checkbox Toggle
            elsif equal(action, "chk_aktiv") then
                kunden[selected_row][8] = not kunden[selected_row][8]
                status_msg = iff(kunden[selected_row][8], "Konto auf AKTIV gesetzt.", "Konto auf GESPERRT gesetzt.")
                toast_msg = status_msg
                toast_type = iff(kunden[selected_row][8], "success", "warning")
            elsif equal(action, "f_aktiv") then
                form_aktiv = not form_aktiv
                status_msg = iff(form_aktiv, "Neukunde wird sofort AKTIV geschaltet.", "Neukunde bleibt vorerst GESPERRT.")

            -- Status / Kategorie durchschalten (Combo Cycle)
            elsif search:begins("combo_cycle_", action) then
                sequence cid = action[13..$]
                if equal(cid, "cmb_status") then
                    sequence cur_st = kunden[selected_row][7]
                    if equal(cur_st, "A-Kunde") then cur_st = "B-Kunde"
                    elsif equal(cur_st, "B-Kunde") then cur_st = "C-Kunde"
                    elsif equal(cur_st, "C-Kunde") then cur_st = "Partner"
                    else cur_st = "A-Kunde"
                    end if
                    kunden[selected_row][7] = cur_st
                    status_msg = sprintf("Status geändert auf: %s", {cur_st})
                elsif equal(cid, "f_status") then
                    if equal(form_status, "A-Kunde") then form_status = "B-Kunde"
                    elsif equal(form_status, "B-Kunde") then form_status = "C-Kunde"
                    elsif equal(form_status, "C-Kunde") then form_status = "Partner"
                    else form_status = "A-Kunde"
                    end if
                    status_msg = sprintf("Kategorie geändert auf: %s", {form_status})
                end if

            -- Speichern (übernimmt alle editierten Werte aus den Feldern!)
            elsif equal(action, "btn_save_detail") then
                if json:is_object(fields) then
                    sequence n_kdnr = json:get(fields, "txt_kdnr", kunden[selected_row][1])
                    sequence n_name = json:get(fields, "txt_name", kunden[selected_row][2])
                    sequence n_ort  = json:get(fields, "txt_ort",  kunden[selected_row][3])
                    sequence n_mail = json:get(fields, "txt_mail", kunden[selected_row][4])
                    sequence n_ums  = json:get(fields, "num_umsatz", "")
                    sequence n_dt   = json:get(fields, "dt_erfasst", kunden[selected_row][6])
                    sequence n_notiz= json:get(fields, "txa_notiz", kunden[selected_row][9])

                    if length(n_kdnr) > 0 then kunden[selected_row][1] = n_kdnr end if
                    if length(n_name) > 0 then kunden[selected_row][2] = n_name end if
                    if length(n_ort) > 0  then kunden[selected_row][3] = n_ort end if
                    if length(n_mail) > 0 then kunden[selected_row][4] = n_mail end if
                    if length(n_ums) > 0  then kunden[selected_row][5] = tui:parse_num_de(n_ums) end if
                    if length(n_dt) > 0   then kunden[selected_row][6] = n_dt end if
                    if length(n_notiz) > 0 then kunden[selected_row][9] = n_notiz end if
                end if
                toast_msg = sprintf("Kunde '%s' (%s) erfolgreich gespeichert!", {kunden[selected_row][2], kunden[selected_row][1]})
                toast_type = "success"
                status_msg = "Datensatz aktualisiert & in Tabelle übernommen."

            -- Neu erfassen
            elsif equal(action, "btn_new_from_detail") then
                active_tab = 3
                status_msg = "Wechsel zum Neukunden-Erfassungsformular."

            -- Löschen
            elsif equal(action, "btn_delete_kunde") then
                modal_title = "Kundenstammsatz löschen?"
                modal_lines = {
                    sprintf("Möchten Sie den Kunden '%s'", {kunden[selected_row][2]}),
                    sprintf("mit der Kundennummer '%s' wirklich löschen?", {kunden[selected_row][1]}),
                    "",
                    "Hinweis: Dieser Vorgang kann nicht widerrufen werden."
                }

            -- Neukunde verbindlich speichern
            elsif equal(action, "btn_submit_neukunde") then
                if json:is_object(fields) then
                    form_kdnr  = json:get(fields, "f_kdnr", form_kdnr)
                    form_name  = json:get(fields, "f_name", form_name)
                    form_ort   = json:get(fields, "f_ort", form_ort)
                    form_email = json:get(fields, "f_email", form_email)
                    sequence u_str = json:get(fields, "f_umsatz", "")
                    if length(u_str) > 0 then form_umsatz = tui:parse_num_de(u_str) end if
                    form_datum = json:get(fields, "f_datum", form_datum)
                    form_notiz = json:get(fields, "f_notiz", form_notiz)
                end if
                kunden = append(kunden, {
                    form_kdnr, form_name, form_ort, form_email, form_umsatz, form_datum, form_status, form_aktiv, form_notiz
                })
                selected_row = length(kunden)
                active_tab = 1
                toast_msg = sprintf("Neukunde '%s' erfolgreich angelegt!", {form_name})
                toast_type = "success"
                status_msg = "Neukunde in Datenbank übernommen."

            -- Formular leeren
            elsif equal(action, "btn_reset_form") then
                form_kdnr  = sprintf("K-%d", {1000 + length(kunden) + 1})
                form_name  = ""
                form_ort   = ""
                form_email = ""
                form_umsatz= 0.0
                form_datum = "2026-11-27"
                form_status= "B-Kunde"
                form_aktiv = 1
                form_notiz = ""
                status_msg = "Formularfelder geleert."

            -- Demo Aktionen
            elsif equal(action, "btn_demo_toast") then
                toast_msg = "Reaktiver Toast: Alle Systeme laufen stabil auf Java 25 VM!"
                toast_type = "info"
            elsif equal(action, "btn_demo_modal") then
                modal_title = "Euphorix TUI Systemstatus"
                modal_lines = {
                    "Laufzeitumgebung: Euphorix Register-VM (Java 25 Loom)",
                    "Terminal-Engine:   vstui.e (Vollbild 100vw x 100vh)",
                    "Grafik-Support:    Bilder & Logos nativ integriert",
                    "Bedienung:        Mausklick + Standard-Tastatur"
                }
            end if
        end if
    end if

    sequence scr = build_screen()
    sequence screen_html = tui:render_patch(scr)
    sequence resp_json = json:encode({json:JSON_OBJECT, {{"html", screen_html}}})
    return http:response_json(200, resp_json)
end function

-- 4. Server starten auf Port 8092
integer port = 8092
integer srv = http:server_create("0.0.0.0", port)
http:route(srv, "GET",  "/", routine_id("handle_index"))
http:route(srv, "GET",  "/img/*", routine_id("handle_static_img"))
http:route(srv, "POST", "/__tui_event", routine_id("handle_tui_event"))

puts(1, "VS-TUI Server läuft auf http://localhost:8092\n")
puts(1, "Drücken Sie Strg+C zum Beenden.\n\n")

http:serve_forever(srv)
