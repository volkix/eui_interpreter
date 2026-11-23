include std/unittest.e

set_test_verbosity(TEST_SHOW_ALL)
include std/csv.e as csv
include std/excel.e as excel
include std/pdf_report.e as pdf
include std/filesys.e as filesys

test_equal("csv format simple field", "hello", csv:format_field("hello"))
test_equal("csv format field with comma", "\"hello, world\"", csv:format_field("hello, world"))
test_equal("csv format field with quotes", "\"say \"\"hi\"\"\"", csv:format_field("say \"hi\""))

sequence test_headers = {"ID", "Name", "Stadt", "Umsatz"}
sequence test_rows = {
    {1, "Müller GmbH", "München", 12500.50},
    {2, "Schmidt & Co.", "Berlin, Mitte", 8400.00},
    {3, "Bäcker \"Frisch\"", "Köln", 3120.75}
}

sequence csv_str = csv:to_csv(test_headers, test_rows)
test_true("csv string not empty", length(csv_str) > 0)

sequence parsed_rows = csv:parse(csv_str)
test_equal("csv parsed rows count", 4, length(parsed_rows))
test_equal("csv header 1", "ID", parsed_rows[1][1])
test_equal("csv row 1 name", "Müller GmbH", parsed_rows[2][2])
test_equal("csv row 2 stadt with comma", "Berlin, Mitte", parsed_rows[3][3])
test_equal("csv row 3 quotes preserved", "Bäcker \"Frisch\"", parsed_rows[4][2])

-- Test write_file & read_file
sequence tmp_csv = "/tmp/test_export.csv"
test_equal("csv write_file ok", 1, csv:write_file(tmp_csv, test_headers, test_rows))
test_true("csv file exists on disk", filesys:file_exists(tmp_csv) = 1)

sequence read_csv = csv:read_file(tmp_csv)
test_equal("csv read_file has headers", 4, length(read_csv[1]))
test_equal("csv read_file has 3 rows", 3, length(read_csv[2]))
test_equal("csv read_file row 1 Name", "Müller GmbH", read_csv[2][1][2])

-- Test Excel (.xlsx) engine
sequence tmp_xlsx = "/tmp/test_kunden.xlsx"
test_equal("excel write_file ok", 1, excel:write_file(tmp_xlsx, test_headers, test_rows, "Kundenliste"))
test_true("excel file exists on disk", filesys:file_exists(tmp_xlsx) = 1)
test_true("excel file size > 500 bytes", filesys:file_length(tmp_xlsx) > 500)

sequence read_xlsx = excel:read_file(tmp_xlsx)
test_equal("excel read status ok", 1, read_xlsx[1])
sequence xlsx_rows = read_xlsx[2]
test_equal("excel total rows count", 4, length(xlsx_rows))
test_equal("excel header 2", "Name", xlsx_rows[1][2])
test_equal("excel row 1 name", "Müller GmbH", xlsx_rows[2][2])
test_equal("excel row 2 stadt", "Berlin, Mitte", xlsx_rows[3][3])

-- Test PDF Business Report engine
sequence tmp_pdf = "/tmp/test_bericht.pdf"
sequence meta = {"Kunde: ACME Gruppe", "Abteilung: Finanzen", "Status: Geprüft"}
test_equal("pdf create_report ok", 1, pdf:create_report(tmp_pdf, "Monatsbericht Q4 2026", meta, test_headers, test_rows))
test_true("pdf file exists on disk", filesys:file_exists(tmp_pdf) = 1)
test_true("pdf file size > 1000 bytes", filesys:file_length(tmp_pdf) > 1000)

test_report()
