-- =============================================================================
-- Beispiel 02: JSON, JSONPath & JSON-Schema Draft 2020-12 (jsoncons 1.5)
-- Aufruf: ./eui examples/02_json_und_schema.ex
-- =============================================================================
include std/json.e
include std/json_schema.e
include std/text.e

procedure assert_eq(sequence name, object actual, object expected)
    if not equal(actual, expected) then
        printf(2, "FEHLER in %s!\n  Erwartet: %s\n  Erhalten: %s\n", {name, sprint(expected), sprint(actual)})
        abort(1)
    end if
end procedure

puts(1, "=== Beispiel 02: JSON, JSONPath & JSON-Schema 2020-12 ===\n")

-- 1. Komplexes JSON-Dokument mit UTF-8 parsen
sequence shop_json = `{
    "shop": "Technik-Markt München",
    "waehrung": "EUR",
    "geoeffnet": true,
    "filialleiter": null,
    "artikel": [
        {"sku": "NVME-2TB", "titel": "PCIe 4.0 SSD 2TB", "preis": 129.90, "lager": 15, "tags": ["speicher", "ssd"]},
        {"sku": "DDR5-64G", "titel": "DDR5 RAM 64GB Kit", "preis": 199.50, "lager": 4,  "tags": ["speicher", "ram"]},
        {"sku": "GPU-16G",  "titel": "Workstation GPU",   "preis": 799.00, "lager": 0,  "tags": ["grafik", "gpu"]}
    ]
}`

object doc = json:decode(shop_json)
assert_eq("Shop-Name (UTF-8)", json:get(doc, "shop"), "Technik-Markt München")
assert_eq("Geöffnet (Bool)",   json:get(doc, "geoeffnet"), 1)
assert_eq("Null-Prüfung",      json:is_null(json:get_node(doc, "filialleiter")), 1)
assert_eq("Pfad-Zugriff [2]",  json:get(doc, "artikel[2].sku"), "DDR5-64G")
assert_eq("Verschachtelt",     json:get(doc, "artikel[1].tags[2]"), "ssd")

-- 2. RFC 9535 JSONPath Abfragen über jsoncons::jsonpath
-- Alle Artikel-Titel mit Lagerbestand > 0:
sequence auf_lager = json:jsonpath(doc, "$.artikel[?(@.lager > 0)].titel")
assert_eq("JSONPath Filter (lager > 0)", auf_lager, {"PCIe 4.0 SSD 2TB", "DDR5 RAM 64GB Kit"})

-- Alle SKUs mit Preis >= 150:
sequence teuer_skus = json:jsonpath(doc, "$.artikel[?(@.preis >= 150.0)].sku")
assert_eq("JSONPath Filter (preis >= 150)", teuer_skus, {"DDR5-64G", "GPU-16G"})

-- 3. JSON-Dokument programmatisch erstellen & verändern
object bestellung = json:object_new({
    {"bestell_nr", 2026001},
    {"kunde", "Max Mustermann"},
    {"bezahlt", json:bool(1)},
    {"positionen", json:array({
        json:object_new({{"sku", "NVME-2TB"}, {"menge", 2}}),
        json:object_new({{"sku", "DDR5-64G"}, {"menge", 1}})
    })}
})
bestellung = json:set(bestellung, "versandart", "Express")
assert_eq("Bestell-Kunde", json:get(bestellung, "kunde"), "Max Mustermann")
assert_eq("Position 1 Menge", json:get(bestellung, "positionen[1].menge"), 2)

-- 4. JSON-Schema Draft 2020-12 Validierung
sequence bestell_schema = `{
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "type": "object",
    "required": ["bestell_nr", "kunde", "bezahlt", "positionen"],
    "properties": {
        "bestell_nr": {"type": "integer", "minimum": 1000},
        "kunde":      {"type": "string", "minLength": 3},
        "bezahlt":    {"type": "boolean"},
        "versandart": {"type": "string", "enum": ["Standard", "Express", "Abholung"]},
        "positionen": {
            "type": "array",
            "minItems": 1,
            "items": {
                "type": "object",
                "required": ["sku", "menge"],
                "properties": {
                    "sku":   {"type": "string", "pattern": "^[A-Z0-9-]+$"},
                    "menge": {"type": "integer", "minimum": 1, "maximum": 99}
                },
                "additionalProperties": false
            }
        }
    },
    "additionalProperties": false
}`

assert_eq("Gültige Bestellung validieren", json_schema:is_valid(bestellung, bestell_schema), 1)

-- Fehlerhafte Bestellung testen (ungültige Versandart + Menge = 0):
object fehler_bestellung = json:set(bestellung, "versandart", "Drohne")
sequence val = json_schema:validate(fehler_bestellung, bestell_schema)
assert_eq("Ungültige Bestellung erkannt", val[json_schema:VALID], 0)
sequence err_texte = json_schema:format_errors(val)
printf(1, "  Erkannter Schema-Fehler: %s\n", {err_texte[1]})

puts(1, "  [OK] Alle JSON, JSONPath & JSON-Schema 2020-12 Beispiele erfolgreich!\n")
