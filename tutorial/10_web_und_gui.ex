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
-- 1. std/vsui.e - High-Density Web UI (aus cgibash/html)
-- Autarkes, reaktives Webframework für ERP-Cockpits, Formulare & DataGrids.
-- -----------------------------------------------------------------------------
puts(1, "--- 1. std/vsui.e ---\n")

-- Formular-Elemente generieren
sequence fld_kdnr = vsui:input("txt_kdnr", "10042", "Kundennummer...")
sequence fld_name = vsui:input("txt_name", "Alpha GmbH", "Firmenname...")
sequence btn_save = vsui:button("btn_save", "Speichern", "on_save", "width: 140px;")

printf(1, "Generiertes Input-HTML:  %s\n", {fld_kdnr})
printf(1, "Generierter Button-HTML: %s\n", {btn_save})

-- Dynamischer Client-Patch ohne Seiten-Reload
sequence patch_antw = vsui:updates({
    vsui:set_val("txt_kdnr", "10043"),
    vsui:toast_show("Kunde erfolgreich angelegt!", vsui:TOAST_SUCCESS)
})
printf(1, "Reaktiver JSON-Patch:    %s\n\n", {patch_antw[2]})


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
puts(1, "Läuft nativ auf Linux (X11/Wayland), macOS und Windows ohne externe Treiber.\n")
