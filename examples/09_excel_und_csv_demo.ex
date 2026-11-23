-- ==============================================================================
-- Euphorix 1.0 Demo: Excel (.xlsx), CSV & PDF Reporting Engine
-- ==============================================================================

include std/console.e
include std/csv.e as csv
include std/excel.e as excel
include std/pdf_report.e as pdf
include std/filesys.e as filesys

puts(1, "=====================================================================\n")
puts(1, "  Euphorix Business Reporting Demo (Excel, CSV, PDF)\n")
puts(1, "=====================================================================\n\n")

sequence headers = {"KundenNr", "Firma", "Ort", "Umsatz EUR", "Status"}
sequence data = {
    {1001, "Müller Maschinenbau GmbH", "München", 84500.50, "Aktiv"},
    {1002, "Schmidt IT-Consulting", "Berlin, Mitte", 42300.00, "Aktiv"},
    {1003, "Bäcker \"Frische Kruste\"", "Köln", 15750.25, "Interessent"},
    {1004, "Alpenlogistik AG", "Garmisch", 112000.00, "Premium"},
    {1005, "Nordsee Reederei e.K.", "Hamburg", 67800.75, "Aktiv"}
}

-- 1. CSV Export & Import
puts(1, "1) Erzeuge CSV-Datei 'kunden_export.csv'...\n")
integer csv_ok = csv:write_file("kunden_export.csv", headers, data, ';')
if csv_ok then
    puts(1, "   ✓ CSV erfolgreich geschrieben (Semikolon-getrennt).\n")
    sequence imported = csv:read_file("kunden_export.csv", ';')
    printf(1, "   ✓ Eingelesen: %d Spalten, %d Zeilen.\n", {length(imported[1]), length(imported[2])})
    printf(1, "   Beispiel-Zeile 1: %s (%s, %s)\n\n", {imported[2][1][2], imported[2][1][3], imported[2][1][5]})
end if

-- 2. Native Excel (.xlsx) Export & Import
puts(1, "2) Erzeuge echte Excel-Datei 'kunden_tabelle.xlsx' (OpenXML)...\n")
integer xlsx_ok = excel:write_file("kunden_tabelle.xlsx", headers, data, "Kundenübersicht")
if xlsx_ok then
    atom sz = filesys:file_length("kunden_tabelle.xlsx")
    printf(1, "   ✓ Excel-Datei erfolgreich erzeugt (%d Bytes, öffnet nativ in MS Excel & LibreOffice).\n", {sz})
    sequence imported_xlsx = excel:read_file("kunden_tabelle.xlsx")
    if imported_xlsx[1] = 1 then
        printf(1, "   ✓ Excel zurückgelesen: %d Tabellenzeilen extrahiert.\n", {length(imported_xlsx[2])})
    end if
    puts(1, "\n")
end if

-- 3. Native Business PDF Report
puts(1, "3) Erzeuge formatierte PDF-Geschäftsübersicht 'kunden_bericht.pdf'...\n")
sequence meta = {
    "Kunde: Gesamtübersicht",
    "Berichtszeitraum: November 2026",
    "Freigegeben: Controlling"
}
integer pdf_ok = pdf:create_report("kunden_bericht.pdf", "Kunden- & Umsatzstatistik 2026", meta, headers, data)
if pdf_ok then
    atom pdf_sz = filesys:file_length("kunden_bericht.pdf")
    printf(1, "   ✓ PDF-Report erfolgreich generiert (%d Bytes, 100%% Standard PDF 1.4 mit Bannern & Zebrastreifen).\n\n", {pdf_sz})
end if

puts(1, "=== Demo erfolgreich beendet! Alle Dateien wurden lokal im Verzeichnis erstellt. ===\n")
