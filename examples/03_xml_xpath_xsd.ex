-- =============================================================================
-- Beispiel 03: XML DOM, W3C XPath 1.0, XSD & RelaxNG (std/xml.e)
-- Aufruf: ./euphorix examples/03_xml_xpath_xsd.ex
-- =============================================================================
include std/xml.e
include std/text.e

procedure assert_eq(sequence name, object actual, object expected)
    if not equal(actual, expected) then
        printf(2, "FEHLER in %s!\n  Erwartet: %s\n  Erhalten: %s\n", {name, sprint(expected), sprint(actual)})
        abort(1)
    end if
end procedure

puts(1, "=== Beispiel 03: XML DOM, XPath 1.0, XSD & RelaxNG ===\n")

sequence rechnung_xml = `<?xml version="1.0" encoding="UTF-8"?>
<rechnung nr="RE-2026-042" datum="2026-11-07">
    <empfaenger land="DE">
        <firma>Müller &amp; Söhne GmbH</firma>
        <ort>München</ort>
    </empfaenger>
    <positionen>
        <pos nr="1" mwst="19">
            <bezeichnung>Linux Server-Lizenz</bezeichnung>
            <betrag>450.00</betrag>
        </pos>
        <pos nr="2" mwst="7">
            <bezeichnung>Fachbuch C++20 &amp; Euphoria</bezeichnung>
            <betrag>49.90</betrag>
        </pos>
    </positionen>
</rechnung>`

-- 1. XML parsen und per Pfad/Attribut auslesen
sequence root = xml:decode(rechnung_xml)
assert_eq("Rechnungs-Nr", xml:attr(root, "nr"), "RE-2026-042")

sequence firma_node = xml:find_first(root, "rechnung/empfaenger/firma")
assert_eq("Firma (UTF-8 & Entity)", xml:text(firma_node), "Müller & Söhne GmbH")

-- 2. W3C XPath 1.0 Abfragen (Elemente, Attribute & XPath-Funktionen wie sum()/count())
sequence pos_7 = xml:xpath(root, "//pos[@mwst='7']/bezeichnung")
assert_eq("XPath 7% MwSt Position", xml:text(pos_7[1]), "Fachbuch C++20 & Euphoria")

sequence anzahl_pos = xml:xpath(root, "count(//pos)")
assert_eq("XPath count(//pos)", anzahl_pos[1], 2)

sequence summe_betrag = xml:xpath(root, "sum(//pos/betrag)")
assert_eq("XPath sum(//pos/betrag)", summe_betrag[1], 499.90)

-- 3. W3C XML Schema (XSD 1.0) Validierung
sequence rechnung_xsd = `<?xml version="1.0" encoding="UTF-8"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:element name="rechnung">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="empfaenger">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="firma" type="xs:string"/>
              <xs:element name="ort" type="xs:string"/>
            </xs:sequence>
            <xs:attribute name="land" type="xs:string" use="required"/>
          </xs:complexType>
        </xs:element>
        <xs:element name="positionen">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="pos" maxOccurs="unbounded">
                <xs:complexType>
                  <xs:sequence>
                    <xs:element name="bezeichnung" type="xs:string"/>
                    <xs:element name="betrag" type="xs:decimal"/>
                  </xs:sequence>
                  <xs:attribute name="nr" type="xs:integer" use="required"/>
                  <xs:attribute name="mwst" type="xs:integer" use="required"/>
                </xs:complexType>
              </xs:element>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:sequence>
      <xs:attribute name="nr" type="xs:string" use="required"/>
      <xs:attribute name="datum" type="xs:date" use="required"/>
    </xs:complexType>
  </xs:element>
</xs:schema>`

assert_eq("XSD Validierung (gültig)", xml:is_valid_xsd(rechnung_xml, rechnung_xsd), 1)

-- 4. RelaxNG Schema-Validierung
sequence notiz_rng = `
<element name="notiz" xmlns="http://relaxng.org/ns/structure/1.0">
  <attribute name="prioritaet"/>
  <element name="titel"><text/></element>
  <element name="inhalt"><text/></element>
</element>`

sequence notiz_xml = xml:element("notiz", {{"prioritaet", "hoch"}}, {
    xml:element("titel", {}, {}, "Backup prüfen"),
    xml:element("inhalt", {}, {}, "Tägliches SQLite-Backup erfolgreich.")
})

assert_eq("RelaxNG Validierung (gültig)", xml:is_valid_relaxng(notiz_xml, notiz_rng), 1)
puts(1, "  [OK] Alle XML DOM, XPath 1.0, XSD & RelaxNG Beispiele erfolgreich!\n")
