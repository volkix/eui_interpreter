-- =============================================================================
-- Euphorix Tutorial - Kapitel 10: Web- & Desktop-Frontends
-- Behandelte Module: std/vsui.e, std/ui5.e, std/gui.e
-- Ausführen mit: ./euphorix tutorial/10_web_und_gui.ex
-- =============================================================================

include std/vsui.e as vsui
include std/ui5.e as ui5
include std/gui.e as gui

puts(1, "=====================================================================\n")
puts(1, "  KAPITEL 10: Web- & Desktop-Frameworks (VS-UI, SAP UI5, Swing)\n")
puts(1, "=====================================================================\n\n")

-- -----------------------------------------------------------------------------
-- 1. std/vsui.e - High-Density Web-UI Suite (html/)
-- Autarkes, reaktives Webframework (HTMX & Vaadin Fusion) für ERP-Cockpits.
-- -----------------------------------------------------------------------------
puts(1, "--- 1. std/vsui.e (HTMX & Vaadin Fusion) ---\n")

-- Formular-Elemente generieren (mit opt_xywh Positionierung und kaufmännischem numinput)
sequence fld_kdnr   = vsui:input("txt_kdnr", "10042", "Kundennummer...")
sequence fld_umsatz = vsui:numinput("num_umsatz", 50000.0, 2, {vsui:opt_xywh(10, 50, 160, 28)})
sequence btn_save   = vsui:button("btn_save", "Speichern", "on_save", "width: 140px;")

printf(1, "Generiertes Input-HTML:    %s\n", {fld_kdnr})
printf(1, "Kaufm. NumInput-HTML:      %s\n", {fld_umsatz})
printf(1, "Generierter Button-HTML:   %s\n", {btn_save})

-- Kaufmännische Zahlenformatierung (DIN 5008)
printf(1, "Formatierte Zahl (2 NK):   %s €\n", {vsui:format_num_de(50000.0, 2)})

-- Dynamischer Client-Patch ohne Seiten-Reload (HTMX-Hypermedia-Prinzip)
sequence patch_antw = vsui:updates({
    vsui:set_val("txt_kdnr", "10043"),
    vsui:set_xywh("win_detail", 100, 150, 500, 400),
    vsui:toast_show("Kunde erfolgreich angelegt!", vsui:TOAST_SUCCESS)
})
printf(1, "Reaktiver JSON-Patch:      %s\n\n", {patch_antw[2]})


-- -----------------------------------------------------------------------------
-- 2. std/ui5.e - SAP UI5 Web Components 2.29
-- Moderne Enterprise-Webkomponenten mit Fiori-Design und voller Zugänglichkeit.
-- -----------------------------------------------------------------------------
puts(1, "--- 2. std/ui5.e ---\n")
sequence ui5_btn = ui5:button("btn_sap", "Im ERP buchen", "Emphasized")
sequence ui5_inp = ui5:input("inp_sap", "Material-Nummer eingeben")
printf(1, "UI5 Web Component Button: %s\n", {ui5_btn})
printf(1, "UI5 Web Component Input:  %s\n\n", {ui5_inp})


-- -----------------------------------------------------------------------------
-- 3. std/gui.e - Native Desktop-Benutzeroberflächen mit Java Swing / AWT
-- Fenster, Dialoge, Buttons und Tabellen für Desktop-Betriebssysteme.
-- -----------------------------------------------------------------------------
puts(1, "--- 3. std/gui.e ---\n")
puts(1, "Plattformunabhängige Desktop-UIs mit gui:window(), gui:button() und Events.\n")
puts(1, "Läuft nativ auf Linux (X11/Wayland), macOS und Windows ohne externe Treiber.\n\n")

-- -----------------------------------------------------------------------------
-- 4. Deployment & Standalone: AOT-Bytecode (.exb) & Single-Binary (52 MB)
-- -----------------------------------------------------------------------------
puts(1, "--- 4. Deployment & Standalone-Bundling ---\n")
puts(1, "Bytecode-Kompilierung: ./euphorix --compile app.ex -o app.exb (10x schnellerer Start)\n")
puts(1, "Reine Runtime:         java -jar runtime.jar app.exb (ohne Compiler/Quellcode)\n")
puts(1, "52 MB Single-Binary:   ./tools/build_standalone.sh --app app.ex (Zero-Dependency)\n")
puts(1, "Enthält Webserver & alle 22 VS-UI-Assets eingebettet – ideal hinter lighttpd/Nginx.\n")
