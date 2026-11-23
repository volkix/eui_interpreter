--****
-- == Native Business PDF Report Engine for Euphorix (std/pdf_report.e)
--
-- Generates clean, corporate-styled PDF 1.4 reports, tables, invoices, and summaries.
-- Features deep-blue header banners, metadata blocks, zebra-striped data tables,
-- column auto-layout, automatic multi-page pagination, and page footers with numbering.
--

namespace pdf_report

constant
    M_PDF_REPORT = 342

--**
-- Create a professional PDF business report.
--
-- Parameters:
-- * `filepath`: Destination PDF path (e.g. `"umsatz_bericht.pdf"`)
-- * `title`: Report title header (e.g. `"Monatsbericht November 2026"`)
-- * `metadata`: Sequence of info strings (e.g. `{"Kunde: ACME Corp", "Abteilung: IT", "Status: Freigegeben"}`)
-- * `headers`: Column header titles (e.g. `{"ArtNr", "Artikel", "Menge", "Preis", "Gesamt"}`)
-- * `rows`: Data rows (sequence of sequences)
-- * `options`: Optional styling options (reserved for future extensions)
--
-- Returns `1` on success, `0` on error.
public function create_report(sequence filepath, sequence title, sequence metadata,
                             sequence headers, sequence rows, sequence options = {})
    return machine_func(M_PDF_REPORT, {filepath, title, metadata, headers, rows, options})
end function

--**
-- Convenience alias for quickly exporting a table to PDF.
public function export_table(sequence filepath, sequence title, sequence headers, sequence rows)
    return create_report(filepath, title, {}, headers, rows, {})
end function
