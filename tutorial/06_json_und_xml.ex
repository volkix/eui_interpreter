-- =============================================================================
-- Euphorix Tutorial - Kapitel 6: Strukturierte Daten mit JSON & XML
-- Behandelte Module: std/json.e, std/json_schema.e, std/xml.e
-- Ausführen mit: ./euphorix tutorial/06_json_und_xml.ex
-- =============================================================================

include std/json.e as json
include std/json_schema.e as js
include std/xml.e as xml
include std/text.e

puts(1, "=====================================================================\n")
puts(1, "  KAPITEL 6: JSON, JSONPath, Schema-Validierung & XML DOM/XPath\n")
puts(1, "=====================================================================\n\n")

-- -----------------------------------------------------------------------------
-- 1. std/json.e - High-Speed JSON-Parsing & RFC 9535 JSONPath
-- Dekodieren, Pfadzugriff und JSONPath-Filterung.
-- -----------------------------------------------------------------------------
puts(1, "--- 1. std/json.e ---\n")
sequence shop_json = `{
    "shop": "Euphorix Tech Store",
    "waehrung": "EUR",
    "artikel": [
        {"sku": "SSD-2TB", "titel": "NVMe SSD 2TB", "preis": 129.90, "lager": 15},
        {"sku": "RAM-32G", "titel": "DDR5 RAM 32GB", "preis": 89.50, "lager": 0},
        {"sku": "CPU-8C",  "titel": "8-Core CPU",   "preis": 249.00, "lager": 8}
    ]
}`

object doc = json:decode(shop_json)
printf(1, "Shop-Name:                %s\n", {json:get(doc, "shop")})
printf(1, "Erster Artikel (Pfad):    %s (%.2f €)\n", {json:get(doc, "artikel[1].titel"), json:get(doc, "artikel[1].preis")})

-- RFC 9535 JSONPath: Nur verfügbare Artikel (lager > 0)
sequence lieferbar = json:jsonpath(doc, "$.artikel[?(@.lager > 0)].titel")
sequence namen = {}
for i = 1 to length(lieferbar) do
    namen = append(namen, lieferbar[i])
end for
printf(1, "Verfügbare Artikel:       %s\n\n", {text:join(namen, ", ")})


-- -----------------------------------------------------------------------------
-- 2. std/json_schema.e - JSON Schema Draft 2020-12 Validierung
-- Absichern von Daten- und API-Schnittstellen gegen Verträge.
-- -----------------------------------------------------------------------------
puts(1, "--- 2. std/json_schema.e ---\n")
sequence schema_def = `{
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "type": "object",
    "required": ["shop", "waehrung"],
    "properties": {
        "shop": {"type": "string"},
        "waehrung": {"type": "string", "maxLength": 3}
    }
}`
integer gueltig = js:is_valid(doc, schema_def)
printf(1, "Entspricht JSON-Schema:   %d (1 = Ja, valide)\n\n", {gueltig})


-- -----------------------------------------------------------------------------
-- 3. std/xml.e - XML DOM & W3C XPath 1.0
-- XML Dokumente parsen, Attribute lesen und Auswertung über XPath.
-- -----------------------------------------------------------------------------
puts(1, "--- 3. std/xml.e ---\n")
sequence rechnung_xml = `<?xml version="1.0" encoding="UTF-8"?>
<rechnung nr="RE-2026-99">
    <kunde land="DE">
        <firma>Schulte Software &amp; Consulting</firma>
    </kunde>
    <positionen>
        <pos art="Lizenz" preis="199.00">Euphorix Server</pos>
        <pos art="Support" preis="50.00">Wartung 1J</pos>
    </positionen>
</rechnung>`

sequence root = xml:decode(rechnung_xml)
printf(1, "Rechnungs-Nummer (Attr):  %s\n", {xml:attr(root, "nr")})

-- XPath 1.0 Abfrage: Alle Bezeichnungen
sequence pos_knoten = xml:xpath(root, "//pos")
for i = 1 to length(pos_knoten) do
    printf(1, "  Position [%d]: %s (Preis: %s €)\n", {i, xml:text(pos_knoten[i]), xml:attr(pos_knoten[i], "preis")})
end for
