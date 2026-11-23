--****
-- == Native Excel (.xlsx) Engine for Euphorix (std/excel.e)
--
-- Generates and reads valid OpenXML Microsoft Excel (.xlsx) spreadsheets natively.
-- Zero external dependencies, pure Java 25 zip & xml engine underneath.
-- Compatible with Microsoft Excel, LibreOffice Calc, and Google Sheets.
--

namespace excel

constant
    M_EXCEL_WRITE = 340,
    M_EXCEL_READ  = 341

--**
-- Write a dataset to an Excel (.xlsx) file.
--
-- Parameters:
-- * `filepath`: Destination path (e.g. `"kunden.xlsx"`)
-- * `headers`: Sequence of column titles (e.g. `{"ID", "Name", "Umsatz"}`)
-- * `rows`: Sequence of row sequences (e.g. `{ {1, "Müller", 4500.50}, ... }`)
-- * `sheet_name`: Name of worksheet (default: `"Tabelle1"`)
--
-- Returns `1` on success, `0` on error.
public function write_file(sequence filepath, sequence headers, sequence rows, sequence sheet_name = "Tabelle1")
    return machine_func(M_EXCEL_WRITE, {filepath, sheet_name, headers, rows})
end function

--**
-- Export a database/grid table directly to an Excel file.
public function export_table(sequence filepath, sequence headers, sequence rows, sequence sheet_name = "Export")
    return write_file(filepath, headers, rows, sheet_name)
end function

--**
-- Read an Excel (.xlsx) file.
-- Returns `{ok, rows}` where `rows` is a sequence of all rows found in sheet 1.
-- On error, returns `{0, error_message}`.
public function read_file(sequence filepath)
    return machine_func(M_EXCEL_READ, filepath)
end function
