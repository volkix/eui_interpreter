include std/json.e
include std/json_schema.e
include std/xml.e
include std/sqlite.e
include std/utf8.e
include std/text.e

procedure assert_eq(sequence name, object actual, object expected)
    if not equal(actual, expected) then
        printf(2, "FEHLER in %s!\n  Erwartet: %s\n  Erhalten: %s\n", {name, sprint(expected), sprint(actual)})
        abort(1)
    end if
end procedure

puts(1, "=== JSON/JSONPath & JSON-Schema 2020-12 (jsoncons), XML/XPath/XSD (libxml2) & SQLite3 Test ===\n")

-- =============================================================================
-- 1. JSON & JSONPath Verarbeitung (jsoncons 1.5)
-- =============================================================================
sequence raw_json = `{
    "company": "Euphorix GmbH",
    "founded": 1993,
    "active": true,
    "employees": [
        {"id": 1, "name": "Anna", "role": "Core"},
        {"id": 2, "name": "Bernd", "role": "Network"}
    ]
}`

object doc = json:decode(raw_json)
assert_eq("json:is_object", json:is_object(doc), 1)
assert_eq("json:get String", json:get(doc, "company"), "Euphorix GmbH")
assert_eq("json:get Integer", json:get(doc, "founded"), 1993)
assert_eq("json:get Bool", json:get(doc, "active"), 1)
assert_eq("json:get Array-Pfad [2]", json:get(doc, "employees[2].name"), "Bernd")

-- RFC 9535 JSONPath Filter-Query via jsoncons::jsonpath!
sequence net_devs = json:jsonpath(doc, "$.employees[?(@.role == 'Network')].name")
assert_eq("json:jsonpath Filter", net_devs, {"Bernd"})

object small_obj = json:object_new({{"a", 10}, {"b", json:bool(0)}})
small_obj = json:set(small_obj, "c", "Hallo")
assert_eq("json:stringify", json:stringify(small_obj), `{"a":10,"b":false,"c":"Hallo"}`)
puts(1, "  [OK] JSON Parser, RFC 9535 JSONPath & Serializer (jsoncons 1.5)\n")

-- =============================================================================
-- 2. JSON-Schema Draft 2020-12 Validierung (jsoncons::jsonschema)
-- =============================================================================
sequence schema_2020_12 = `{
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "type": "object",
    "required": ["id", "username", "age", "coords"],
    "dependentRequired": {
        "credit_card": ["billing_address"]
    },
    "defs": {
        "coord": {"type": "number"}
    },
    "properties": {
        "id":              {"type": "integer", "minimum": 1},
        "username":        {"type": "string",  "minLength": 3, "maxLength": 20, "pattern": "^[A-Za-z0-9_]+$"},
        "age":             {"type": "integer", "minimum": 18, "maximum": 120},
        "coords":          {
            "type": "array",
            "prefixItems": [{"type": "number"}, {"type": "number"}],
            "items": false
        },
        "credit_card":     {"type": "string"},
        "billing_address": {"type": "string"}
    },
    "unevaluatedProperties": false
}`

sequence valid_user = `{
    "id": 101,
    "username": "volkix_eu",
    "age": 34,
    "coords": [52.52, 13.405]
}`

sequence invalid_user = `{
    "id": 102,
    "username": "ab",
    "age": 15,
    "coords": [52.52, 13.405, 99.0],
    "credit_card": "4111-XXXX"
}`

assert_eq("json_schema 2020-12 (gültig)", json_schema:is_valid(valid_user, schema_2020_12), 1)
assert_eq("json_schema 2020-12 (ungültig)", json_schema:is_valid(invalid_user, schema_2020_12), 0)

sequence val_res = json_schema:validate(invalid_user, schema_2020_12)
assert_eq("json_schema 2020-12 Fehleranzahl >= 3", length(val_res[json_schema:ERRORS]) >= 3, 1)
puts(1, "  [OK] JSON-Schema Draft 2020-12 (prefixItems, dependentRequired, unevaluatedProperties via jsoncons)\n")

-- =============================================================================
-- 3. XML, W3C XPath 1.0 & W3C XSD XML-Schema (libxml2 2.15)
-- =============================================================================
sequence raw_xml = `<?xml version="1.0" encoding="UTF-8"?>
<catalog library="Zentralbibliothek">
    <book id="b1" category="coding">
        <title lang="de">Moderne Euphoria Programmierung &amp; C++20</title>
        <price>39.95</price>
    </book>
    <book id="b2" category="linux">
        <title lang="en">Linux System Internals</title>
        <price>49.00</price>
    </book>
</catalog>`

sequence xml_root = xml:decode(raw_xml)
assert_eq("xml:tag", xml:tag(xml_root), "catalog")
assert_eq("xml:attr", xml:attr(xml_root, "library"), "Zentralbibliothek")

sequence first_title = xml:find_first(xml_root, "catalog/book/title")
assert_eq("xml:find_first Text & Entity-Decode", xml:text(first_title), "Moderne Euphoria Programmierung & C++20")
assert_eq("xml:find_first Attribut", xml:attr(first_title, "lang"), "de")

-- W3C XPath 1.0 Abfrage über libxml2
sequence xpath_hits = xml:xpath(xml_root, "//book[@category='linux']/title")
assert_eq("xml:xpath Trefferanzahl", length(xpath_hits), 1)
assert_eq("xml:xpath Titel", xml:text(xpath_hits[1]), "Linux System Internals")

-- W3C XML Schema (XSD 1.0) Validierung über libxml2
sequence catalog_xsd = `<?xml version="1.0" encoding="UTF-8"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:element name="catalog">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="book" maxOccurs="unbounded">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="title">
                <xs:complexType>
                  <xs:simpleContent>
                    <xs:extension base="xs:string">
                      <xs:attribute name="lang" type="xs:string" use="required"/>
                    </xs:extension>
                  </xs:simpleContent>
                </xs:complexType>
              </xs:element>
              <xs:element name="price" type="xs:decimal"/>
            </xs:sequence>
            <xs:attribute name="id" type="xs:string" use="required"/>
            <xs:attribute name="category" type="xs:string" use="required"/>
          </xs:complexType>
        </xs:element>
      </xs:sequence>
      <xs:attribute name="library" type="xs:string" use="required"/>
    </xs:complexType>
  </xs:element>
</xs:schema>`

assert_eq("xml:is_valid_xsd (gültiges XML)", xml:is_valid_xsd(raw_xml, catalog_xsd), 1)
sequence broken_xml = `<catalog library="Test"><book id="b1" category="coding"><title lang="de">Buch</title><price>KEINE_ZAHL</price></book></catalog>`
assert_eq("xml:is_valid_xsd (ungültiger xs:decimal Preis)", xml:is_valid_xsd(broken_xml, catalog_xsd), 0)

puts(1, "  [OK] XML DOM, W3C XPath 1.0 & W3C XSD Schema-Validierung (libxml2 2.15)\n")

-- =============================================================================
-- 4. SQLite 3.46 Datenbank-Anbindung (statisch gelinktes libsqlite3.a)
-- =============================================================================
integer db = sqlite:open(":memory:")
assert_eq("sqlite:open", db > 0, 1)

assert_eq("sqlite:exec CREATE TABLE",
    sqlite:exec(db, "CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT NOT NULL, price REAL, note TEXT);"),
    1
)

sqlite:begin(db)
assert_eq("sqlite:exec INSERT 1",
    sqlite:exec(db, "INSERT INTO products (name, price, note) VALUES (?, ?, ?);", {"SSD 2TB", 129.99, "NVMe"}),
    1
)
assert_eq("sqlite:exec INSERT 2",
    sqlite:exec(db, "INSERT INTO products (name, price, note) VALUES (?, ?, ?);", {"RAM 64GB", 189.50, sqlite:SQL_NULL}),
    1
)
assert_eq("sqlite:last_insert_id", sqlite:last_insert_id(db), 2)
sqlite:commit(db)

assert_eq("sqlite:query_value COUNT(*)",
    sqlite:query_value(db, "SELECT COUNT(*) FROM products;"),
    2
)

sequence rows = sqlite:query(db, "SELECT id, name, price, note FROM products WHERE price > ? ORDER BY id;", {100.0})
assert_eq("sqlite:query Zeilenanzahl", length(rows), 2)
assert_eq("sqlite:query Zeile 1 Name", rows[1][2], "SSD 2TB")
assert_eq("sqlite:query Zeile 2 NULL-Prüfung", sqlite:is_null(rows[2][4]), 1)

sequence assoc_rows = sqlite:query_assoc(db, "SELECT id, name FROM products ORDER BY id;")
assert_eq("sqlite:query_assoc -> json:stringify",
    json:stringify(json:array(assoc_rows)),
    `[{"id":1,"name":"SSD 2TB"},{"id":2,"name":"RAM 64GB"}]`
)

assert_eq("sqlite:close", sqlite:close(db), 1)
puts(1, "  [OK] SQLite 3.46 (:memory:, Prepared Statements, Transaktionen & JSON-Export)\n")

-- =============================================================================
-- 5. UTF-8 String-Verarbeitung (std/utf8.e via libxml2 + C.UTF-8)
-- =============================================================================
sequence u_str = "Größe €"
assert_eq("Byte-Länge length()", length(u_str), 11)
assert_eq("UTF-8 Zeichenanzahl utf8:len()", utf8:len(u_str), 7)
assert_eq("utf8:valid()", utf8:valid(u_str), 1)
assert_eq("utf8:char_at(3)", utf8:char_at(u_str, 3), "ö")
assert_eq("utf8:slice(3, 5)", utf8:slice(u_str, 3, 5), "öße")
assert_eq("utf8:find('€')", utf8:find("€", u_str), 7)
assert_eq("utf8:upper('äöü test')", utf8:upper("äöü test"), "ÄÖÜ TEST")
assert_eq("utf8:lower('ÄÖÜ TEST')", utf8:lower("ÄÖÜ TEST"), "äöü test")
sequence cps = utf8:to_codepoints(u_str)
assert_eq("utf8:to_codepoints Länge", length(cps), 7)
assert_eq("utf8:from_codepoints Roundtrip", utf8:from_codepoints(cps), u_str)
puts(1, "  [OK] UTF-8 Zeichen-Indexierung, Slicing, Upper/Lower & Codepoints (std/utf8.e)\n")

puts(1, "=== Alle JSON/JSONPath, JSON-Schema 2020-12, XML/XPath/XSD, SQLite & UTF-8 Tests erfolgreich bestanden! ===\n")
