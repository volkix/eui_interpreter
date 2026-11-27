--****
-- == VS-TUI: Vollbild-Zeichenoberfläche (Modern TUI) im Webbrowser
--
-- Moderne, tastatur- und mausgesteuerte Terminal-Benutzeroberfläche für den gesamten
-- Browser-Bildschirm (100vw x 100vh). Nutzt den vollen Viewport ohne Retrogimmicks.
--
-- Bietet den vollen Funktionsumfang von std/vsui.e im TUI-Design:
--   * Vollbild-Layout mit automatischer Viewport-Ausnutzung (100vw x 100vh)
--   * Modul-Tabs mit Maus- & Pfeiltasten-Navigation
--   * KPI-Stat-Cards mit Trend-Indikatoren (↗, ↘)
--   * Master-Detail-Splitter (DataGrid links, Formulardetails rechts)
--   * Interaktives DataGrid mit Live-Suche und Zeilenauswahl per Klick/Tastatur
--   * Numerische Felder (vsnuminput) mit deutscher Formatierung (14.250,50 €)
--   * Datums- (vsdateinput) und Zeitfelder (vstimeinput)
--   * Dropdowns/Comboboxen (vscombo), Checkboxen (vscheck), Textareas (vstextarea)
--   * TUI-Diagramme (vschart) mit Unicode-Balken (█)
--   * Aktions-Buttons: Speichern, Neu, Löschen, Suchen
--   * Schwebende Modal-Dialoge und Toast-Benachrichtigungen
--   * Reine Mausbedienung + Standard-Tastatur (Pfeile, Tab, Enter, Esc, / für Suche)
--   * KEINE Funktionstasten (F1-F12), um Konflikte mit dem Browser zu verhindern!
--
-- Author: OpenEuphoria / Euphorix Team
--****

namespace vstui

include std/search.e
include std/types.e
include std/text.e
include std/utf8.e as utf8
include std/json.e as json
include std/http.e as http
include std/get.e as get

-- =============================================================================
-- 1. Moderne Farbpalette (Modern Dark Terminal / Slate / Catppuccin)
-- =============================================================================

public constant
    C_BG_PAGE     = "#0b0f19",  -- Tiefes Anthrazit-Schwarz (Seitenhintergrund)
    C_BG_PANEL    = "#111827",  -- Panel-Hintergrund (Slate 900)
    C_BG_CARD     = "#1f2937",  -- Karten- & Detailhintergrund (Slate 800)
    C_BG_INPUT    = "#030712",  -- Eingabefeld-Hintergrund
    C_BORDER      = "#374151",  -- Feiner Rahmen (Slate 700)
    C_BORDER_ACT  = "#60a5fa",  -- Aktiver Fokus-Rahmen (Sky 400)
    C_TEXT        = "#f9fafb",  -- Haupttext (Reinweiß)
    C_MUTED       = "#9ca3af",  -- Sekundärtext (Grau)
    C_DIM         = "#4b5563",  -- Abgedunkelt (Inaktiv)
    C_CYAN        = "#38bdf8",  -- Akzent Cyan / Links
    C_GREEN       = "#34d399",  -- Erfolg / Trend Up (Smaragd)
    C_AMBER       = "#fbbf24",  -- Warnung / Status (Bernstein)
    C_RED         = "#f87171",  -- Fehler / Löschen (Sanftes Rot)
    C_PURPLE      = "#c084fc",  -- Badge Lila
    C_SEL_BG      = "#1d4ed8",  -- Zeilenauswahl Hintergrund (Kräftiges Blau)
    C_SEL_FG      = "#ffffff"   -- Zeilenauswahl Text

-- Screen-Indizes
constant
    TUI_WIDTH     = 1,
    TUI_HEIGHT    = 2,
    TUI_CELLS     = 3,
    TUI_TITLE     = 4,
    TUI_TEXTAREAS = 5,
    TUI_IMAGES    = 6,
    TUI_OVERLAY   = 7

-- Zell-Indizes
constant
    Z_CHAR      = 1,
    Z_FG        = 2,
    Z_BG        = 3,
    Z_ACT       = 4

-- =============================================================================
-- 2. Puffer-Erstellung & Basisoperationen
-- =============================================================================

--**
-- Erzeugt einen modernen TUI-Puffer für die angegebene Breite und Höhe.
-- Standard ist 126 Spalten x 36 Zeilen für eine optimale Vollbild-Ausnutzung.
public function create(integer width = 126, integer height = 36, sequence title = "Euphorix TUI Cockpit")
    sequence cells = repeat(repeat({" ", C_TEXT, C_BG_PAGE, ""}, width), height)
    return {width, height, cells, title, {}, {}, {}}
end function

--**
-- Prüft, ob ein Unicode-Codepoint im Terminal/Monospace-Font 2 Spalten breit (Wide/Emoji) ist.
public function is_wide_cp(integer cp)
    if (cp >= #1F300 and cp <= #1FAFF)       -- Emojis, Symbole, Transport, Pictographs
       or (cp >= #1F000 and cp <= #1F2FF)    -- Mahjong, Domino, Alphanumeric Supp.
       or cp = #2795 or cp = #2796 or cp = #2797 -- ➕ ➖ ➗
       or cp = #2B50                         -- ⭐
       or (cp >= #2E80 and cp <= #9FFF)      -- CJK Radikale & Ideographen
       or (cp >= #AC00 and cp <= #D7AF)      -- Hangul
       or (cp >= #FF01 and cp <= #FF60)      -- Fullwidth ASCII Varianten
    then
        return 1
    end if
    return 0
end function

--**
-- Berechnet die visuelle Spaltenbreite eines UTF-8 Strings im Monospace-Raster.
public function str_display_width(sequence text)
    sequence cps = utf8:to_codepoints(text)
    integer width = 0
    for i = 1 to length(cps) do
        if is_wide_cp(cps[i]) then
            width += 2
        else
            width += 1
        end if
    end for
    return width
end function

--**
-- Setzt ein einzelnes Zeichen an Koordinate (x, y). (1-basiert)
public function set_cell(sequence tui, integer x, integer y, sequence ch, sequence fg = "", sequence bg = "", sequence action = "")
    integer w = tui[TUI_WIDTH]
    integer h = tui[TUI_HEIGHT]
    if x < 1 or x > w or y < 1 or y > h then return tui end if
    if length(fg) = 0 then fg = C_TEXT end if
    if length(bg) = 0 then bg = C_BG_PAGE end if
    tui[TUI_CELLS][y][x] = {ch, fg, bg, action}
    return tui
end function

--**
-- Druckt einen Text ab Koordinate (x, y).
-- Dekodiert UTF-8 sauber in Unicode-Codepoints. Wide-Characters (Emojis) belegen 2 Spalten
-- und erzeugen eine leere Fortsetzungszelle, damit nachfolgende Spalten exakt ausgerichtet bleiben.
public function print_at(sequence tui, integer x, integer y, sequence text, sequence fg = "", sequence bg = "", sequence action = "")
    integer w = tui[TUI_WIDTH]
    integer h = tui[TUI_HEIGHT]
    if y < 1 or y > h then return tui end if
    if length(fg) = 0 then fg = C_TEXT end if
    if length(bg) = 0 then bg = C_BG_PAGE end if

    integer cx = x
    sequence cps = utf8:to_codepoints(text)
    for i = 1 to length(cps) do
        integer cp = cps[i]
        sequence ch = utf8:from_codepoints(cp)
        if is_wide_cp(cp) then
            if cx >= 1 and cx <= w then
                tui[TUI_CELLS][y][cx] = {ch, fg, bg, action}
            end if
            if cx + 1 >= 1 and cx + 1 <= w then
                tui[TUI_CELLS][y][cx + 1] = {"", fg, bg, action}
            end if
            cx += 2
        else
            if cx >= 1 and cx <= w then
                tui[TUI_CELLS][y][cx] = {ch, fg, bg, action}
            end if
            cx += 1
        end if
    end for
    return tui
end function

--**
-- Füllt einen rechteckigen Bereich mit Zeichen und Farben.
public function fill(sequence tui, integer x, integer y, integer w, integer h, sequence ch = " ", sequence fg = "", sequence bg = "")
    if length(fg) = 0 then fg = C_TEXT end if
    if length(bg) = 0 then bg = C_BG_PAGE end if
    for row = y to y + h - 1 do
        for col = x to x + w - 1 do
            tui = set_cell(tui, col, row, ch, fg, bg)
        end for
    end for
    return tui
end function

--**
-- Zeichnet einen modernen, feinen Kastenrahmen (Single Border ┌ ─ ┐ │ └ ┘) mit optionalem Titel.
public function box(sequence tui, integer x, integer y, integer w, integer h, sequence title = "", sequence border_color = "", sequence bg_color = "")
    if length(border_color) = 0 then border_color = C_BORDER end if
    if length(bg_color) = 0 then bg_color = C_BG_PANEL end if

    -- Körper füllen
    tui = fill(tui, x, y, w, h, " ", C_TEXT, bg_color)

    -- Ecken
    tui = set_cell(tui, x, y, "┌", border_color, bg_color)
    tui = set_cell(tui, x + w - 1, y, "┐", border_color, bg_color)
    tui = set_cell(tui, x, y + h - 1, "└", border_color, bg_color)
    tui = set_cell(tui, x + w - 1, y + h - 1, "┘", border_color, bg_color)

    -- Horizontale Linien
    for col = x + 1 to x + w - 2 do
        tui = set_cell(tui, col, y, "─", border_color, bg_color)
        tui = set_cell(tui, col, y + h - 1, "─", border_color, bg_color)
    end for

    -- Vertikale Linien
    for row = y + 1 to y + h - 2 do
        tui = set_cell(tui, x, row, "│", border_color, bg_color)
        tui = set_cell(tui, x + w - 1, row, "│", border_color, bg_color)
    end for

    -- Titel im oberen Rahmen
    if length(title) > 0 and w > (str_display_width(title) + 4) then
        sequence t_str = " " & title & " "
        tui = print_at(tui, x + 2, y, t_str, C_CYAN, bg_color)
    end if

    return tui
end function

-- =============================================================================
-- 3. Hilfsfunktionen zur Zahlenformatierung (wie vsui:format_num_de)
-- =============================================================================

--**
-- Formatiert Zahlen im deutschen Format (14.250,50 €) mit Tausendertrennpunkt und Dezimalkomma.
public function format_num_de(object val, integer nk = 2, sequence currency_sym = "€")
    atom num = 0.0
    if sequence(val) then
        object v = get:value(val)
        if v[1] = get:GET_SUCCESS and (atom(v[2]) or integer(v[2])) then
            num = v[2]
        end if
    elsif atom(val) then
        num = val
    end if

    sequence s
    if nk <= 0 then
        s = sprintf("%.0f", {num})
    else
        s = sprintf(sprintf("%%.%df", nk), {num})
    end if

    integer dot_pos = find('.', s)
    sequence int_part = s
    sequence dec_part = ""
    if dot_pos > 0 then
        int_part = s[1..dot_pos - 1]
        dec_part = s[dot_pos + 1..$]
    end if

    integer is_neg = 0
    if length(int_part) > 0 and int_part[1] = '-' then
        is_neg = 1
        int_part = int_part[2..$]
    end if

    sequence grouped = ""
    integer count = 0
    for i = length(int_part) to 1 by -1 do
        if count > 0 and remainder(count, 3) = 0 then
            grouped = "." & grouped
        end if
        grouped = int_part[i] & grouped
        count += 1
    end for

    if is_neg then grouped = "-" & grouped end if

    sequence res = grouped
    if nk > 0 and length(dec_part) > 0 then
        res &= "," & dec_part
    end if

    if length(currency_sym) > 0 then
        res &= " " & currency_sym
    end if

    return res
end function

--**
-- Parst einen deutschen formatierten Zahlen-String wie "14.250,50 €" oder "18.500,00"
-- in eine atom-Fließkommazahl.
public function parse_num_de(sequence str)
    sequence clean = ""
    for i = 1 to length(str) do
        integer ch = str[i]
        if ch >= '0' and ch <= '9' then
            clean &= ch
        elsif ch = ',' then
            clean &= '.'
        elsif ch = '-' then
            clean &= ch
        end if
    end for
    if length(clean) = 0 then return 0.0 end if
    object v = get:value(clean)
    if v[1] = get:GET_SUCCESS and (integer(v[2]) or atom(v[2])) then
        return v[2]
    end if
    return 0.0
end function

--**
-- Escaped Sonderzeichen für HTML Attribute und Text-Knoten.
function escape_html(sequence s)
    sequence out = ""
    for i = 1 to length(s) do
        object cv = s[i]
        if equal(cv, '<') then out &= "&lt;"
        elsif equal(cv, '>') then out &= "&gt;"
        elsif equal(cv, '&') then out &= "&amp;"
        elsif equal(cv, '"') then out &= "&quot;"
        elsif equal(cv, '\n') then out &= "&#10;"
        else out &= cv
        end if
    end for
    return out
end function

-- =============================================================================
-- 4. High-Level TUI Komponenten (Vollständige Entsprechung zu vsui.e)
-- =============================================================================

--**
-- 1. Moderne Kopfzeile: System-Logo, Titel, Version und Schnellstatus
public function draw_header(sequence tui, sequence app_title, sequence subtitle = "", sequence user_info = "admin@euphorix")
    integer w = tui[TUI_WIDTH]
    tui = fill(tui, 1, 1, w, 1, " ", C_TEXT, C_BG_PANEL)

    -- Logo & Brand
    tui = print_at(tui, 2, 1, "⚡ EUPHORIX", C_CYAN, C_BG_PANEL)
    tui = print_at(tui, 14, 1, "│", C_BORDER, C_BG_PANEL)
    tui = print_at(tui, 16, 1, app_title, C_TEXT, C_BG_PANEL)

    if length(subtitle) > 0 then
        tui = print_at(tui, 16 + utf8:len(app_title) + 1, 1, "(" & subtitle & ")", C_MUTED, C_BG_PANEL)
    end if

    -- Benutzerinfo & Status rechts
    sequence r_info = user_info & "  ● Online"
    integer rx = w - utf8:len(r_info) - 1
    tui = print_at(tui, rx, 1, user_info, C_MUTED, C_BG_PANEL)
    tui = print_at(tui, w - 8, 1, "● Online", C_GREEN, C_BG_PANEL)

    return tui
end function

--**
-- 2. Modul-Tabs: Horizontale Reiter mit Mausbedienung (z.B. Kunden, Aufträge, Formular, Charts)
public function draw_tabs(sequence tui, sequence tab_items, integer active_idx, integer x, integer y, integer w)
    tui = fill(tui, x, y, w, 1, "─", C_BORDER, C_BG_PAGE)
    integer cx = x + 1

    for i = 1 to length(tab_items) do
        sequence itm = tab_items[i]
        sequence label_text = itm[1]
        sequence action = sprintf("tab_%d", {i})
        if length(itm) >= 2 then action = itm[2] end if
        integer is_act = (i = active_idx)

        sequence tab_str = ""
        sequence tab_fg = C_MUTED
        sequence tab_bg = C_BG_CARD

        if is_act then
            tab_str = " [ " & label_text & " ] "
            tab_fg = C_TEXT
            tab_bg = C_SEL_BG
        else
            tab_str = "   " & label_text & "   "
            tab_fg = C_MUTED
            tab_bg = C_BG_PANEL
        end if

        tui = print_at(tui, cx, y, tab_str, tab_fg, tab_bg, action)
        cx += utf8:len(tab_str) + 1
    end for
    return tui
end function

--**
-- 3. KPI-Stat-Cards (vsstatcard): Leistungsindikatoren mit Trendpfeilen (↗, ↘)
public function draw_kpi_cards(sequence tui, sequence cards, integer x, integer y, integer total_w)
    integer n = length(cards)
    if n = 0 then return tui end if
    integer card_w = floor((total_w - (n - 1) * 2) / n)

    integer cx = x
    for i = 1 to n do
        sequence c = cards[i]
        sequence title = c[1]
        sequence val_str = c[2]
        sequence trend = ""
        if length(c) >= 3 then trend = c[3] end if
        integer is_up = 1
        if length(c) >= 4 then is_up = c[4] end if

        -- Kasten
        tui = box(tui, cx, y, card_w, 4, title, C_BORDER, C_BG_PANEL)

        -- Wert fett
        tui = print_at(tui, cx + 2, y + 2, val_str, C_TEXT, C_BG_PANEL)

        -- Trend rechtsbündig
        if length(trend) > 0 then
            sequence trend_fg = iff(is_up, C_GREEN, C_RED)
            integer tx = cx + card_w - utf8:len(trend) - 2
            tui = print_at(tui, tx, y + 2, trend, trend_fg, C_BG_PANEL)
        end if

        cx += card_w + 2
    end for
    return tui
end function

--**
-- 4. Vollbild-DataGrid (vsgrid) mit Spaltenbreiten, Trennlinien und Zeilenauswahl per Klick
-- Unterstützt automatisches Viewport-Scrolling und echte TUI-Scrollbar (▲, █, ░, ▼) bei vielen Datensätzen.
public function draw_table(sequence tui, sequence id, sequence headers, sequence rows,
                           integer x, integer y, integer w, integer h,
                           integer selected_idx = 1, integer scroll_top = 1)
    integer num_cols = length(headers)
    if num_cols = 0 then return tui end if
    integer total_rows = length(rows)
    integer max_rows = h - 4
    if max_rows < 1 then return tui end if

    -- Berechne Viewport-Scrolling
    if total_rows > max_rows then
        if selected_idx < scroll_top then
            scroll_top = selected_idx
        elsif selected_idx >= scroll_top + max_rows then
            scroll_top = selected_idx - max_rows + 1
        end if
        if scroll_top + max_rows - 1 > total_rows then
            scroll_top = total_rows - max_rows + 1
        end if
        if scroll_top < 1 then scroll_top = 1 end if
    else
        scroll_top = 1
    end if

    -- Berechne Spaltenbreiten
    sequence col_widths = repeat(0, num_cols)
    for c = 1 to num_cols do
        integer cw = 14
        if length(headers[c]) >= 2 and integer(headers[c][2]) then
            cw = headers[c][2]
        end if
        col_widths[c] = cw
    end for

    -- Passe letzte Spalte an, damit exakt w ausgefüllt wird
    integer avail_w = w - 2 - (num_cols - 1)
    integer allocated = 0
    for c = 1 to num_cols - 1 do allocated += col_widths[c] end for
    if avail_w > allocated then col_widths[num_cols] = avail_w - allocated end if

    -- 1. Oberer Tabellenrahmen: ┌────┬────┐
    tui = set_cell(tui, x, y, "┌", C_BORDER, C_BG_PANEL)
    integer col_pos = x + 1
    for c = 1 to num_cols do
        for k = 1 to col_widths[c] do
            tui = set_cell(tui, col_pos, y, "─", C_BORDER, C_BG_PANEL)
            col_pos += 1
        end for
        if c < num_cols then
            tui = set_cell(tui, col_pos, y, "┬", C_BORDER, C_BG_PANEL)
            col_pos += 1
        end if
    end for
    tui = set_cell(tui, x + w - 1, y, "┐", C_BORDER, C_BG_PANEL)

    -- Zeilenzähler im Rahmen anzeigen, falls Datensätze scrollbar sind
    if total_rows > max_rows then
        sequence count_str = sprintf("┤ %d/%d ├", {selected_idx, total_rows})
        integer cx_start = x + w - utf8:len(count_str) - 2
        if cx_start > x + 4 then
            tui = print_at(tui, cx_start, y, count_str, C_CYAN, C_BG_PANEL)
        end if
    end if

    -- 2. Header-Zeile: │ Spalte 1 │ Spalte 2 │
    tui = set_cell(tui, x, y + 1, "│", C_BORDER, C_BG_CARD)
    col_pos = x + 1
    for c = 1 to num_cols do
        sequence title = headers[c][1]
        integer cw = col_widths[c]
        sequence padded = " " & title
        if utf8:len(padded) < cw then
            padded &= repeat(' ', cw - utf8:len(padded))
        else
            padded = utf8:slice(padded, 1, cw)
        end if
        tui = print_at(tui, col_pos, y + 1, padded, C_CYAN, C_BG_CARD)
        col_pos += cw
        if c < num_cols then
            tui = set_cell(tui, col_pos, y + 1, "│", C_BORDER, C_BG_CARD)
            col_pos += 1
        end if
    end for
    tui = set_cell(tui, x + w - 1, y + 1, "│", C_BORDER, C_BG_CARD)

    -- 3. Header-Trennlinie: ├────┼────┤
    tui = set_cell(tui, x, y + 2, "├", C_BORDER, C_BG_PANEL)
    col_pos = x + 1
    for c = 1 to num_cols do
        for k = 1 to col_widths[c] do
            tui = set_cell(tui, col_pos, y + 2, "─", C_BORDER, C_BG_PANEL)
            col_pos += 1
        end for
        if c < num_cols then
            tui = set_cell(tui, col_pos, y + 2, "┼", C_BORDER, C_BG_PANEL)
            col_pos += 1
        end if
    end for
    tui = set_cell(tui, x + w - 1, y + 2, "┤", C_BORDER, C_BG_PANEL)

    -- Scrollbar-Position berechnen
    integer track_len = max_rows - 2
    if track_len < 1 then track_len = 1 end if
    atom denom = total_rows - max_rows
    if denom < 1 then denom = 1 end if
    atom progress = (scroll_top - 1) / denom
    integer thumb_pos = 2 + floor(progress * (track_len - 1))

    -- 4. Datenzeilen
    for r = 1 to max_rows do
        integer row_idx = scroll_top + r - 1
        integer curr_y = y + 2 + r
        integer is_sel = (row_idx = selected_idx)
        sequence row_fg = iff(is_sel, C_SEL_FG, C_TEXT)
        sequence row_bg = iff(is_sel, C_SEL_BG, C_BG_PANEL)
        sequence row_act = sprintf("%s_select_%d", {id, row_idx})

        tui = set_cell(tui, x, curr_y, "│", C_BORDER, row_bg)
        col_pos = x + 1

        if row_idx <= total_rows then
            sequence row_data = rows[row_idx]
            for c = 1 to num_cols do
                sequence cell_val = ""
                if c <= length(row_data) then
                    object raw_cell = row_data[c]
                    if sequence(raw_cell) then
                        cell_val = raw_cell
                    elsif integer(raw_cell) then
                        cell_val = sprintf("%d", {raw_cell})
                    elsif atom(raw_cell) then
                        cell_val = sprintf("%g", {raw_cell})
                    end if
                end if
                integer cw = col_widths[c]

                -- Zeiger ▶ für ausgewählte Zeile
                sequence disp = cell_val
                if c = 1 and is_sel then
                    disp = "▶ " & cell_val
                else
                    disp = "  " & cell_val
                end if

                sequence padded = disp
                if utf8:len(padded) < cw then
                    padded &= repeat(' ', cw - utf8:len(padded))
                else
                    padded = utf8:slice(padded, 1, cw)
                end if

                tui = print_at(tui, col_pos, curr_y, padded, row_fg, row_bg, row_act)
                col_pos += cw
                if c < num_cols then
                    tui = set_cell(tui, col_pos, curr_y, "│", C_BORDER, row_bg)
                    col_pos += 1
                end if
            end for
        else
            -- Leere Zeile
            for c = 1 to num_cols do
                integer cw = col_widths[c]
                tui = fill(tui, col_pos, curr_y, cw, 1, " ", C_DIM, C_BG_PANEL)
                col_pos += cw
                if c < num_cols then
                    tui = set_cell(tui, col_pos, curr_y, "│", C_BORDER, C_BG_PANEL)
                    col_pos += 1
                end if
            end for
        end if

        -- Rechte Rahmenzelle oder TUI-Scrollbar (▲, █, ░, ▼)
        if total_rows > max_rows then
            if r = 1 then
                tui = set_cell(tui, x + w - 1, curr_y, "▲", C_CYAN, C_BG_CARD, id & "_page_up")
            elsif r = max_rows then
                tui = set_cell(tui, x + w - 1, curr_y, "▼", C_CYAN, C_BG_CARD, id & "_page_down")
            elsif r = thumb_pos then
                tui = set_cell(tui, x + w - 1, curr_y, "█", C_CYAN, C_BG_PANEL, id & "_scroll_track")
            else
                tui = set_cell(tui, x + w - 1, curr_y, "░", C_BORDER, C_BG_PANEL, id & "_scroll_track")
            end if
        else
            tui = set_cell(tui, x + w - 1, curr_y, "│", C_BORDER, row_bg)
        end if
    end for

    -- 5. Unterer Tabellenabschluss: └────┴────┘
    tui = set_cell(tui, x, y + h - 1, "└", C_BORDER, C_BG_PANEL)
    col_pos = x + 1
    for c = 1 to num_cols do
        for k = 1 to col_widths[c] do
            tui = set_cell(tui, col_pos, y + h - 1, "─", C_BORDER, C_BG_PANEL)
            col_pos += 1
        end for
        if c < num_cols then
            tui = set_cell(tui, col_pos, y + h - 1, "┴", C_BORDER, C_BG_PANEL)
            col_pos += 1
        end if
    end for
    tui = set_cell(tui, x + w - 1, y + h - 1, "┘", C_BORDER, C_BG_PANEL)

    return tui
end function

--**
-- 5. Standard-Texteingabefeld (vsinput)
public function draw_input(sequence tui, sequence id, sequence label_text, sequence val, integer x, integer y, integer field_w, sequence bg = "")
    if length(bg) = 0 then bg = C_BG_PANEL end if
    if length(label_text) > 0 then
        tui = print_at(tui, x, y, label_text, C_MUTED, bg)
        x += utf8:len(label_text) + 1
    end if

    sequence padded = val
    if utf8:len(padded) < field_w then
        padded &= repeat(' ', field_w - utf8:len(padded))
    else
        padded = utf8:slice(padded, 1, field_w)
    end if

    tui = print_at(tui, x, y, "[", C_BORDER, bg)
    tui = print_at(tui, x + 1, y, padded, C_TEXT, C_BG_INPUT, "input:" & id)
    tui = print_at(tui, x + 1 + field_w, y, "]", C_BORDER, bg)
    return tui
end function

--**
-- 5b. Numerisches Eingabefeld (vsnuminput):
-- Rechtsbündig, deutsche Formatierung mit Tausendertrennpunkten, Komma und optionalem Währungssymbol.
public function draw_numinput(sequence tui, sequence id, sequence label_text, object val, integer nk = 2, sequence currency_sym = "€", integer x = 1, integer y = 1, integer field_w = 16, sequence bg = "")
    if length(bg) = 0 then bg = C_BG_PANEL end if
    if length(label_text) > 0 then
        tui = print_at(tui, x, y, label_text, C_MUTED, bg)
        x += utf8:len(label_text) + 1
    end if

    sequence str_val = format_num_de(val, nk, currency_sym)
    -- Rechtsbündig formatieren
    sequence padded = str_val
    if utf8:len(padded) < field_w then
        padded = repeat(' ', field_w - utf8:len(padded)) & padded
    else
        padded = utf8:slice(padded, 1, field_w)
    end if

    tui = print_at(tui, x, y, "[", C_BORDER, bg)
    tui = print_at(tui, x + 1, y, padded, C_GREEN, C_BG_INPUT, "numinput:" & id)
    tui = print_at(tui, x + 1 + field_w, y, "]", C_BORDER, bg)
    return tui
end function

--**
-- 5c. Datums-Eingabefeld (vsdateinput): [ 2026-11-27 📅] mit Klick-Popup
public function draw_dateinput(sequence tui, sequence id, sequence label_text, sequence val, integer x, integer y, integer field_w = 14, sequence bg = "")
    if length(bg) = 0 then bg = C_BG_PANEL end if
    if length(label_text) > 0 then
        tui = print_at(tui, x, y, label_text, C_MUTED, bg)
        x += utf8:len(label_text) + 1
    end if

    -- field_w ist die exakte Breite zwischen [ und ] (wie bei draw_input / draw_numinput)
    integer inp_w = field_w - 2
    if inp_w < 10 then inp_w = 10 end if

    sequence disp = val
    if utf8:len(disp) < inp_w then
        disp &= repeat(' ', inp_w - utf8:len(disp))
    else
        disp = utf8:slice(disp, 1, inp_w)
    end if

    tui = print_at(tui, x, y, "[", C_BORDER, bg)
    tui = print_at(tui, x + 1, y, disp, C_CYAN, C_BG_INPUT, "dateinput:" & id)
    tui = print_at(tui, x + 1 + inp_w, y, " 📅", C_CYAN, bg, "open_date:" & id)
    tui = print_at(tui, x + 1 + field_w, y, "]", C_BORDER, bg)
    return tui
end function

--**
-- 5d. Zeit-Eingabefeld (vstimeinput): [ 10:30 ⏰ ]
public function draw_timeinput(sequence tui, sequence id, sequence label_text, sequence val, integer x, integer y, integer field_w = 10, sequence bg = "")
    if length(bg) = 0 then bg = C_BG_PANEL end if
    if length(label_text) > 0 then
        tui = print_at(tui, x, y, label_text, C_MUTED, bg)
        x += utf8:len(label_text) + 1
    end if
    sequence disp = val & " ⏰"
    sequence padded = disp
    if utf8:len(padded) < field_w then
        padded &= repeat(' ', field_w - utf8:len(padded))
    else
        padded = utf8:slice(padded, 1, field_w)
    end if
    tui = print_at(tui, x, y, "[", C_BORDER, bg)
    tui = print_at(tui, x + 1, y, padded, C_CYAN, C_BG_INPUT, "timeinput:" & id)
    tui = print_at(tui, x + 1 + field_w, y, "]", C_BORDER, bg)
    return tui
end function

--**
-- 5e. Mehrzeiliges Textfeld (vstextarea): Echtes HTML5-Textarea mit Zeilenumbruch und Scrollen
public function draw_textarea(sequence tui, sequence id, sequence label_text, sequence lines, integer x, integer y, integer w, integer h, sequence bg = "")
    if length(bg) = 0 then bg = C_BG_PANEL end if
    tui = box(tui, x, y, w, h, label_text, C_BORDER, C_BG_INPUT)

    sequence text_val = ""
    for r = 1 to length(lines) do
        if r > 1 then text_val &= "\n" end if
        text_val &= lines[r]
    end for

    -- Textarea für native Platzierung registrieren
    sequence ta_entry = {id, x + 1, y, w - 2, h - 2, text_val}
    if length(tui) >= 5 then
        tui[5] = append(tui[5], ta_entry)
    else
        tui = append(tui, {ta_entry})
    end if
    return tui
end function

--**
-- 6. Checkbox (vscheck): [x] Aktiv  /  [ ] Gesperrt
public function draw_checkbox(sequence tui, sequence id, sequence label_text, integer is_checked, integer x, integer y, sequence bg = "")
    if length(bg) = 0 then bg = C_BG_PANEL end if
    sequence chk_box = iff(is_checked, "[x]", "[ ]")
    sequence chk_color = iff(is_checked, C_GREEN, C_MUTED)

    tui = print_at(tui, x, y, chk_box, chk_color, bg, id)
    tui = print_at(tui, x + 4, y, label_text, C_TEXT, bg, id)
    return tui
end function

--**
-- 7. Dropdown / Combobox (vscombo): [ B-Kunde  ▼ ]
public function draw_combo(sequence tui, sequence id, sequence label_text, sequence current_val, integer x, integer y, integer w, sequence bg = "")
    if length(bg) = 0 then bg = C_BG_PANEL end if
    if length(label_text) > 0 then
        tui = print_at(tui, x, y, label_text, C_MUTED, bg)
        x += utf8:len(label_text) + 1
    end if

    sequence padded = current_val
    integer inner_w = w - 4
    if utf8:len(padded) < inner_w then
        padded &= repeat(' ', inner_w - utf8:len(padded))
    else
        padded = utf8:slice(padded, 1, inner_w)
    end if

    tui = print_at(tui, x, y, "[", C_BORDER, bg)
    tui = print_at(tui, x + 1, y, padded, C_CYAN, C_BG_INPUT, "combo:" & id)
    tui = print_at(tui, x + 1 + inner_w, y, " ▼]", C_BORDER, bg, "combo_cycle_" & id)
    return tui
end function

--**
-- 8. Interaktive Schaltflächen (vsbutton):
-- Unterstützt kompakte einzeilige Buttons (h = 1) sowie mehrzeilige Schaltflächen (z.B. h = 3
-- mit zentrierter Beschriftung in Zeile 2 und optionalem Kastenrahmen oder Shortcut-Untertitel).
public function draw_button(sequence tui, sequence id, sequence label_text,
                            integer x, integer y, sequence btn_style = "primary",
                            integer w = 0, integer h = 1, sequence subtitle = "")
    sequence btn_fg = C_TEXT
    sequence btn_bg = C_BG_CARD

    if equal(btn_style, "primary") or equal(btn_style, "success") then
        btn_fg = C_BG_PAGE
        btn_bg = C_GREEN
    elsif equal(btn_style, "danger") then
        btn_fg = C_TEXT
        btn_bg = C_RED
    elsif equal(btn_style, "accent") then
        btn_fg = C_BG_PAGE
        btn_bg = C_CYAN
    elsif equal(btn_style, "framed") then
        btn_fg = C_TEXT
        btn_bg = C_BG_CARD
    elsif equal(btn_style, "muted") then
        btn_fg = C_MUTED
        btn_bg = C_BG_CARD
    end if

    integer text_vis_w = str_display_width(label_text)
    integer sub_vis_w  = str_display_width(subtitle)

    if w <= 0 then
        w = text_vis_w + 4
        if length(subtitle) > 0 and (sub_vis_w + 4) > w then
            w = sub_vis_w + 4
        end if
    else
        -- Wenn eine feste Breite vorgegeben wurde, stellen wir sicher,
        -- dass (w - text_vis_w) gerade ist, damit der Text exakt symmetrisch
        -- zentriert wird (kein Zeichen rechts zu viel bzw. links zu wenig).
        if remainder(w - text_vis_w, 2) != 0 then
            w += 1
        end if
    end if

    if h <= 1 then
        -- Einzeiliger kompakter Standard-Button
        integer pad_l = floor((w - text_vis_w) / 2)
        integer pad_r = w - text_vis_w - pad_l
        if pad_l < 0 then pad_l = 0 end if
        if pad_r < 0 then pad_r = 0 end if
        sequence btn_str = repeat(' ', pad_l) & label_text & repeat(' ', pad_r)
        tui = print_at(tui, x, y, btn_str, btn_fg, btn_bg, id)
    elsif equal(btn_style, "framed") and h >= 3 then
        -- 3-zeiliger Button mit Kastenrahmen (┌───┐ / │ Text │ / └───┘)
        integer inner_w = w - 2
        integer pad_l = floor((inner_w - text_vis_w) / 2)
        integer pad_r = inner_w - text_vis_w - pad_l
        if pad_l < 0 then pad_l = 0 end if
        if pad_r < 0 then pad_r = 0 end if
        sequence padded = repeat(' ', pad_l) & label_text & repeat(' ', pad_r)

        sequence top_b = "┌"
        sequence bot_b = "└"
        for i = 1 to inner_w do
            top_b &= "─"
            bot_b &= "─"
        end for
        top_b &= "┐"
        bot_b &= "┘"
        tui = print_at(tui, x, y, top_b, C_CYAN, btn_bg, id)
        tui = print_at(tui, x, y + 1, "│" & padded & "│", btn_fg, btn_bg, id)
        tui = print_at(tui, x, y + 2, bot_b, C_CYAN, btn_bg, id)
    else
        -- Mehrzeiliger Block-Button (z.B. h = 3: Zeile 1 = Rand, Zeile 2 = Beschriftung, Zeile 3 = Rand/Untertitel)
        integer text_row = y + floor((h - 1) / 2) -- Bei h=3 ist dies Zeile y + 1 (die zweite Zeile!)

        for r = 0 to h - 1 do
            integer cur_y = y + r
            if cur_y = text_row then
                -- Zeile mit Hauptbeschriftung (symmetrisch zentriert in Zeile 2)
                integer pad_l = floor((w - text_vis_w) / 2)
                integer pad_r = w - text_vis_w - pad_l
                if pad_l < 0 then pad_l = 0 end if
                if pad_r < 0 then pad_r = 0 end if
                sequence padded = repeat(' ', pad_l) & label_text & repeat(' ', pad_r)
                tui = print_at(tui, x, cur_y, padded, btn_fg, btn_bg, id)
            elsif length(subtitle) > 0 and cur_y = text_row + 1 then
                -- Optionale Unterzeile (z.B. Tastenkürzel wie "[Enter]")
                integer pad_l = floor((w - sub_vis_w) / 2)
                integer pad_r = w - sub_vis_w - pad_l
                if pad_l < 0 then pad_l = 0 end if
                if pad_r < 0 then pad_r = 0 end if
                sequence padded = repeat(' ', pad_l) & subtitle & repeat(' ', pad_r)
                tui = print_at(tui, x, cur_y, padded, btn_fg, btn_bg, id)
            else
                -- Obere oder untere Randzeile (trägt dieselbe Klick-Action!)
                sequence empty_line = repeat(' ', w)
                tui = print_at(tui, x, cur_y, empty_line, btn_fg, btn_bg, id)
            end if
        end for
    end if

    return tui
end function

--**
-- 8b. Balkendiagramm (vschart): Horizontale Balken mit █, Beschriftung und Werten
public function draw_barchart(sequence tui, sequence id, sequence title, sequence labels, sequence values, integer x, integer y, integer w, integer h)
    tui = box(tui, x, y, w, h, title, C_BORDER, C_BG_PANEL)
    integer n = length(labels)
    if n = 0 then return tui end if

    atom max_val = 1.0
    for i = 1 to length(values) do
        atom v = values[i]
        if v > max_val then max_val = v end if
    end for

    integer max_label_w = 12
    integer avail_bar_w = w - max_label_w - 18
    if avail_bar_w < 10 then avail_bar_w = 10 end if

    for i = 1 to n do
        integer cur_y = y + 1 + i
        if cur_y >= (y + h - 1) then exit end if
        sequence lbl = labels[i]
        atom v = values[i]
        integer bar_len = floor((v / max_val) * avail_bar_w)
        if bar_len < 1 and v > 0 then bar_len = 1 end if

        -- Label
        sequence p_lbl = lbl
        if utf8:len(p_lbl) < max_label_w then
            p_lbl &= repeat(' ', max_label_w - utf8:len(p_lbl))
        else
            p_lbl = utf8:slice(p_lbl, 1, max_label_w)
        end if
        tui = print_at(tui, x + 2, cur_y, p_lbl, C_MUTED, C_BG_PANEL)

        -- Balken (█)
        sequence bar_str = ""
        for b = 1 to bar_len do
            bar_str &= "█"
        end for
        sequence bar_fg = C_CYAN
        if remainder(i, 3) = 0 then bar_fg = C_PURPLE
        elsif remainder(i, 2) = 0 then bar_fg = C_GREEN
        end if
        tui = print_at(tui, x + 2 + max_label_w + 1, cur_y, bar_str, bar_fg, C_BG_PANEL)

        -- Wertanzeige
        sequence val_str = sprintf("%.0f €", {v})
        tui = print_at(tui, x + 2 + max_label_w + 2 + bar_len, cur_y, val_str, C_TEXT, C_BG_PANEL)
    end for
    return tui
end function

--**
-- 8c. Bilddarstellung im Terminal (Logo, Artikelbild, Produktgrafik, Avatar)
-- Integriert Raster- und Vektorgrafiken (JPEG, PNG, SVG, WebP) pixelgenau
-- in die TUI-Zeilen- und Spaltenkoordinaten. Optional mit feinem TUI-Rahmen.
public function draw_image(sequence tui, sequence id, sequence src_url,
                           integer x, integer y, integer w, integer h,
                           sequence border_title = "", sequence object_fit = "contain")
    integer inner_x = x
    integer inner_y = y
    integer inner_w = w
    integer inner_h = h

    if length(border_title) > 0 then
        tui = box(tui, x, y, w, h, border_title, C_BORDER, C_BG_CARD)
        inner_x += 1
        inner_y += 1
        inner_w -= 2
        inner_h -= 2
    end if

    -- Innenbereich mit Leerzeichen füllen, damit Hintergrundtext nicht durchscheint
    tui = fill(tui, inner_x, inner_y, inner_w, inner_h, " ", C_TEXT, C_BG_CARD)

    sequence img_entry = {id, src_url, inner_x, inner_y, inner_w, inner_h, object_fit}
    if length(tui) >= 6 then
        tui[6] = append(tui[6], img_entry)
    else
        while length(tui) < 5 do
            tui = append(tui, {})
        end while
        tui = append(tui, {img_entry})
    end if
    return tui
end function

--**
-- 9. Schwebender Modal-Dialog (vsmodal) als isolierte 2. Screenebene (Overlay)
public function draw_modal(sequence tui, sequence id, sequence title, sequence lines, sequence buttons = {})
    integer mw = 58
    integer mh = length(lines) + 6

    sequence modal_tui = create(mw, mh, title)
    modal_tui = box(modal_tui, 1, 1, mw, mh, title, C_CYAN, C_BG_CARD)

    -- Zeilen
    for i = 1 to length(lines) do
        modal_tui = print_at(modal_tui, 4, 2 + i, lines[i], C_TEXT, C_BG_CARD)
    end for

    -- Buttons unten zentriert
    integer bx = 4
    if length(buttons) = 0 then
        modal_tui = draw_button(modal_tui, "close_modal", "  Schließen [Esc]  ", floor((mw - 22) / 2), mh - 1, "primary")
    else
        for b = 1 to length(buttons) do
            sequence btn = buttons[b]
            sequence btn_style = "primary"
            if length(btn) >= 3 then btn_style = btn[3] end if
            modal_tui = draw_button(modal_tui, btn[1], btn[2], bx, mh - 1, btn_style)
            bx += str_display_width(btn[2]) + 4
        end for
    end if

    if length(tui) < 7 then
        while length(tui) < 6 do tui &= {{}} end while
        tui &= {modal_tui}
    else
        tui[TUI_OVERLAY] = modal_tui
    end if
    return tui
end function

--**
-- 9b. Toast-Benachrichtigung (vstoast) oben rechts
public function draw_toast(sequence tui, sequence text, sequence toast_type = "success")
    integer sw = tui[TUI_WIDTH]
    sequence icon = "✓ "
    sequence t_fg = C_BG_PAGE
    sequence t_bg = C_GREEN
    if equal(toast_type, "warning") then
        icon = "⚠ "
        t_bg = C_AMBER
    elsif equal(toast_type, "error") then
        icon = "✕ "
        t_bg = C_RED
    elsif equal(toast_type, "info") then
        icon = "ℹ "
        t_bg = C_CYAN
    end if

    sequence toast_str = " " & icon & text & " "
    integer tw = utf8:len(toast_str)
    integer tx = sw - tw - 2
    if tx < 2 then tx = 2 end if
    tui = print_at(tui, tx, 2, toast_str, t_fg, t_bg, "close_toast")
    return tui
end function

-- Hilfsfunktionen für Kalenderberechnungen
function day_of_week(integer y, integer m, integer d)
    if m < 3 then
        m += 12
        y -= 1
    end if
    integer k = remainder(y, 100)
    integer j = floor(y / 100)
    integer h = remainder(d + floor(13 * (m + 1) / 5) + k + floor(k / 4) + floor(j / 4) - (2 * j), 7)
    if h < 0 then h += 7 end if
    return remainder(h + 5, 7) + 1 -- 1 = Mo, ..., 7 = So
end function

function days_in_month(integer y, integer m)
    if m = 2 then
        if (remainder(y, 4) = 0 and remainder(y, 100) != 0) or remainder(y, 400) = 0 then
            return 29
        else
            return 28
        end if
    elsif m = 4 or m = 6 or m = 9 or m = 11 then
        return 30
    else
        return 31
    end if
end function

--**
-- 9c. Reiner TUI-Kalender-Dialog (Datumsauswahl im Terminal-Look) als isolierte 2. Screenebene.
-- Läuft unabhängig vom Hauptbildschirm, berührt keine Formularfelder und schützt den Basisscreen.
public function draw_calendar_modal(sequence tui, sequence target_field, integer year, integer month, integer selected_day = 0)
    integer mw = 48
    integer mh = 17

    sequence cal_tui = create(mw, mh, "📅 Datum auswählen")
    cal_tui = box(cal_tui, 1, 1, mw, mh, "📅 Datum auswählen", C_CYAN, C_BG_CARD)

    -- Monatsnavigation: [ ◄ ]  November 2026  [ ► ]
    sequence month_names = {"Januar", "Februar", "März", "April", "Mai", "Juni",
                            "Juli", "August", "September", "Oktober", "November", "Dezember"}
    sequence m_title = sprintf("%s %d", {month_names[month], year})
    cal_tui = draw_button(cal_tui, "cal_prev_month", "◄", 3, 3, "accent")
    integer title_x = floor((mw - str_display_width(m_title)) / 2)
    cal_tui = print_at(cal_tui, title_x, 3, m_title, C_TEXT, C_BG_CARD)
    cal_tui = draw_button(cal_tui, "cal_next_month", "►", mw - 5, 3, "accent")

    -- Wochentags-Kopfzeile
    sequence dows = {"Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"}
    for i = 1 to 7 do
        integer cx = 4 + (i - 1) * 6
        sequence col_color = iff(i >= 6, C_MUTED, C_CYAN)
        cal_tui = print_at(cal_tui, cx + 1, 5, dows[i], col_color, C_BG_CARD)
    end for
    sequence sep_line = ""
    for i = 1 to mw - 4 do sep_line &= "─" end for
    cal_tui = print_at(cal_tui, 3, 6, sep_line, C_BORDER, C_BG_CARD)

    -- Tage zeichnen
    integer start_dow = day_of_week(year, month, 1)
    integer num_days  = days_in_month(year, month)
    integer cur_dow   = start_dow
    integer cur_y     = 7

    for d = 1 to num_days do
        integer cx = 4 + (cur_dow - 1) * 6
        sequence act = sprintf("cal_select_%d", {d})
        if d = selected_day then
            -- Ausgewählter Tag hervorgehoben
            sequence day_str = sprintf("[%2d]", {d})
            cal_tui = print_at(cal_tui, cx, cur_y, day_str, C_SEL_FG, C_SEL_BG, act)
        else
            sequence day_str = sprintf(" %2d ", {d})
            sequence d_fg = iff(cur_dow >= 6, C_MUTED, C_TEXT)
            cal_tui = print_at(cal_tui, cx, cur_y, day_str, d_fg, C_BG_CARD, act)
        end if

        if cur_dow = 7 then
            cur_dow = 1
            cur_y += 1
        else
            cur_dow += 1
        end if
    end for

    -- Aktionsleiste unten sauber ausgerichtet (cols 4..44 innerhalb mw=48)
    cal_tui = draw_button(cal_tui, "cal_btn_today", "Heute", 4, mh - 1, "accent")
    cal_tui = draw_button(cal_tui, "cal_btn_apply", "💾 Übernehmen", 13, mh - 1, "primary")
    cal_tui = draw_button(cal_tui, "cal_btn_cancel", "✕ Abbrechen", 32, mh - 1, "danger")

    if length(tui) < 7 then
        while length(tui) < 6 do tui &= {{}} end while
        tui &= {cal_tui}
    else
        tui[TUI_OVERLAY] = cal_tui
    end if
    return tui
end function

--**
-- 10. Statuszeile unten: Status-Meldungen, Pfad und Tastaturtipps
public function draw_footer(sequence tui, sequence status_msg, sequence hint_text = "")
    integer w = tui[TUI_WIDTH]
    integer h = tui[TUI_HEIGHT]
    tui = fill(tui, 1, h, w, 1, " ", C_TEXT, C_BG_PANEL)

    -- Status links
    tui = print_at(tui, 2, h, "Status: " & status_msg, C_TEXT, C_BG_PANEL)

    -- Tastaturhilfe / Tipps rechts
    if length(hint_text) = 0 then
        hint_text = "Maus: Klickbar  •  Pfeile: Navigieren  •  Enter: Auswählen  •  Esc: Schließen"
    end if
    integer hx = w - utf8:len(hint_text) - 2
    tui = print_at(tui, hx, h, hint_text, C_MUTED, C_BG_PANEL)

    return tui
end function

-- =============================================================================
-- 5. Vollbild-HTML5 Web-Engine (100vw x 100vh)
-- =============================================================================

--**
-- Rendert ein 2D-Zellenraster in TUI-HTML-Zeilen.
function render_cells_to_html(sequence cells, integer w, integer h)
    sequence html = ""
    for y = 1 to h do
        html &= "<div class=\"vstui-line\">"
        integer x = 1
        while x <= w do
            sequence c = cells[y][x]
            sequence ch = c[Z_CHAR]
            sequence fg = c[Z_FG]
            sequence bg = c[Z_BG]
            sequence act = c[Z_ACT]

            sequence run_text = ch
            integer next_x = x + 1
            while next_x <= w do
                sequence nc = cells[y][next_x]
                if equal(nc[Z_FG], fg) and equal(nc[Z_BG], bg) and equal(nc[Z_ACT], act) then
                    run_text &= nc[Z_CHAR]
                    next_x += 1
                else
                    exit
                end if
            end while

            if search:begins("input:", act) then
                sequence field_id = act[7..$]
                sequence raw_val = text:trim(run_text)
                html &= sprintf("<input type=\"text\" class=\"vstui-input\" id=\"%s\" name=\"%s\" value=\"%s\" style=\"width:%dch; color:%s; background-color:%s;\" autocomplete=\"off\" spellcheck=\"false\" />",
                                {field_id, field_id, escape_html(raw_val), utf8:len(run_text), fg, bg})
            elsif search:begins("numinput:", act) then
                sequence field_id = act[10..$]
                sequence raw_val = text:trim(run_text)
                html &= sprintf("<input type=\"text\" class=\"vstui-input vstui-numinput\" id=\"%s\" name=\"%s\" value=\"%s\" style=\"width:%dch; color:%s; background-color:%s;\" autocomplete=\"off\" spellcheck=\"false\" />",
                                {field_id, field_id, escape_html(raw_val), utf8:len(run_text), fg, bg})
            elsif search:begins("dateinput:", act) then
                sequence field_id = act[11..$]
                sequence raw_val = text:trim(run_text)
                html &= sprintf("<input type=\"text\" class=\"vstui-input\" id=\"%s\" name=\"%s\" value=\"%s\" style=\"width:%dch; color:%s; background-color:%s;\" autocomplete=\"off\" spellcheck=\"false\" />",
                                {field_id, field_id, escape_html(raw_val), utf8:len(run_text), fg, bg})
            elsif search:begins("timeinput:", act) then
                sequence field_id = act[11..$]
                sequence raw_val = text:trim(run_text)
                html &= sprintf("<input type=\"text\" class=\"vstui-input\" id=\"%s\" name=\"%s\" value=\"%s\" style=\"width:%dch; color:%s; background-color:%s;\" autocomplete=\"off\" spellcheck=\"false\" />",
                                {field_id, field_id, escape_html(raw_val), utf8:len(run_text), fg, bg})
            elsif search:begins("combo:", act) then
                sequence field_id = act[7..$]
                sequence raw_val = text:trim(run_text)
                html &= sprintf("<input type=\"text\" class=\"vstui-input vstui-combo\" id=\"%s\" name=\"%s\" value=\"%s\" style=\"width:%dch; color:%s; background-color:%s;\" onclick=\"sendTuiAction('combo_cycle_%s')\" autocomplete=\"off\" spellcheck=\"false\" readonly />",
                                {field_id, field_id, escape_html(raw_val), utf8:len(run_text), fg, bg, field_id})
            elsif search:begins("open_date:", act) then
                sequence field_id = act[11..$]
                html &= sprintf("<span class=\"vstui-cell vstui-interactive\" style=\"color:%s; background-color:%s; cursor:pointer;\" onclick=\"sendTuiAction('open_date_%s')\" title=\"📅 Datum auswählen\"> 📅</span>",
                                {fg, bg, field_id})
            else
                sequence safe_text = escape_html(run_text)
                sequence span_cls = "vstui-cell"
                sequence act_attr = ""
                if length(act) > 0 then
                    span_cls &= " vstui-interactive"
                    act_attr = sprintf(" data-action=\"%s\" onclick=\"sendTuiAction('%s')\"", {act, act})
                end if

                html &= sprintf("<span class=\"%s\" style=\"color:%s; background-color:%s;\"%s>%s</span>",
                                {span_cls, fg, bg, act_attr, safe_text})
            end if

            x = next_x
        end while
        html &= "</div>"
    end for
    return html
end function

--**
-- Rendert den Screen in ein reaktives HTML-Fragment (für AJAX / Patches).
public function render_patch(sequence tui)
    integer w = tui[TUI_WIDTH]
    integer h = tui[TUI_HEIGHT]
    sequence cells = tui[TUI_CELLS]

    sequence html = sprintf("<div class=\"vstui-screen\" data-cols=\"%d\" data-rows=\"%d\">", {w, h})
    html &= render_cells_to_html(cells, w, h)

    -- Registrierte Textareas rendern (pixelgenau im Kasten platziert)
    if length(tui) >= 5 and sequence(tui[5]) then
        sequence tas = tui[5]
        for i = 1 to length(tas) do
            sequence ta = tas[i]
            sequence ta_id = ta[1]
            integer ta_x = ta[2]
            integer ta_y = ta[3]
            integer ta_w = ta[4]
            integer ta_h = ta[5]
            sequence ta_txt = ta[6]

            html &= sprintf("<textarea class=\"vstui-input vstui-textarea\" id=\"%s\" name=\"%s\" style=\"position:absolute; left:calc(%d * 0.602 * var(--tui-fs)); top:calc(%d * var(--tui-lh)); width:calc(%d * 0.602 * var(--tui-fs)); height:calc(%d * var(--tui-lh));\" spellcheck=\"false\">%s</textarea>",
                            {ta_id, ta_id, ta_x - 1, ta_y, ta_w, ta_h, escape_html(ta_txt)})
        end for
    end if

    -- Registrierte Bilder rendern (pixelgenau im TUI-Raster platziert)
    if length(tui) >= 6 and sequence(tui[6]) then
        sequence imgs = tui[6]
        for i = 1 to length(imgs) do
            sequence im = imgs[i]
            sequence im_id = im[1]
            sequence im_src = im[2]
            integer im_x = im[3]
            integer im_y = im[4]
            integer im_w = im[5]
            integer im_h = im[6]
            sequence im_fit = im[7]

            html &= sprintf("<img class=\"vstui-image\" id=\"%s\" src=\"%s\" style=\"position:absolute; left:calc(%d * 0.602 * var(--tui-fs)); top:calc(%d * var(--tui-lh)); width:calc(%d * 0.602 * var(--tui-fs)); height:calc(%d * var(--tui-lh)); object-fit:%s; border-radius:2px; z-index:5; pointer-events:none;\" alt=\"%s\" />",
                            {im_id, im_src, im_x - 1, im_y - 1, im_w, im_h, im_fit, im_id})
        end for
    end if

    html &= "</div>"

    -- 2. Screenebene: Modal-Overlay / Popup (wenn vorhanden)
    if length(tui) >= 7 and sequence(tui[TUI_OVERLAY]) and length(tui[TUI_OVERLAY]) >= 3 then
        sequence ov = tui[TUI_OVERLAY]
        integer ow = ov[TUI_WIDTH]
        integer oh = ov[TUI_HEIGHT]
        sequence ov_cells = ov[TUI_CELLS]

        html &= "<div class=\"vstui-modal-overlay\" onclick=\"if(event.target===this)sendTuiAction('escape')\">"
        html &= sprintf("<div class=\"vstui-modal-window vstui-screen\" data-cols=\"%d\" data-rows=\"%d\" style=\"width:calc(%d * 0.602 * var(--tui-fs)); height:calc(%d * var(--tui-lh));\">",
                        {ow, oh, ow, oh})
        html &= render_cells_to_html(ov_cells, ow, oh)
        html &= "</div></div>"
    end if

    return html
end function

--**
-- Rendert eine vollwertige, moderne Vollbild-Webseite (100vw x 100vh) ohne Ränder und ohne Funktionstasten.
public function render_page(sequence tui, sequence title = "Euphorix TUI Cockpit")
    sequence content = render_patch(tui)
    integer w = tui[TUI_WIDTH]
    integer h = tui[TUI_HEIGHT]

    sequence html = `<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>` & title & `</title>
  <style>
    :root {
      --tui-font: "DejaVu Sans Mono", "Cascadia Code", "JetBrains Mono", "Fira Code", monospace;
      --rows: ` & sprintf("%d", {h}) & `;
      --cols: ` & sprintf("%d", {w}) & `;
      /* Schriftgröße passt sich dynamisch an Breite und Höhe an - kein Überlauf! */
      --tui-fs: min(calc(98vw / (var(--cols) * 0.602)), calc(98vh / var(--rows)));
      --tui-lh: var(--tui-fs);
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    html, body {
      width: 100vw;
      height: 100vh;
      background: ` & C_BG_PAGE & `;
      color: ` & C_TEXT & `;
      font-family: var(--tui-font);
      font-size: var(--tui-fs);
      line-height: var(--tui-lh);
      overflow: hidden;
      user-select: none;
      display: flex;
      justify-content: center;
      align-items: center;
    }
    #vstui_app {
      position: relative;
      width: calc(var(--cols) * 0.602 * var(--tui-fs));
      height: calc(var(--rows) * var(--tui-lh));
      outline: none;
    }
    .vstui-screen {
      position: relative;
      width: 100%;
      height: 100%;
      display: flex;
      flex-direction: column;
      justify-content: stretch;
    }
    .vstui-line {
      height: var(--tui-lh);
      line-height: var(--tui-lh);
      white-space: pre;
      font-size: var(--tui-fs);
      display: flex;
      flex-direction: row;
      margin: 0;
      padding: 0;
      overflow: hidden;
      width: 100%;
    }
    .vstui-cell {
      display: inline-block;
      margin: 0;
      padding: 0;
      font-family: inherit;
      font-size: inherit;
      line-height: var(--tui-lh);
      white-space: pre;
      letter-spacing: 0;
      vertical-align: top;
    }
    .vstui-interactive {
      cursor: pointer;
      transition: filter 0.08s ease;
    }
    .vstui-interactive:hover {
      filter: brightness(1.35) contrast(1.15);
      text-decoration: underline;
    }
    .vstui-interactive:active {
      filter: brightness(0.9);
    }
    .vstui-input {
      font-family: inherit;
      font-size: inherit;
      line-height: var(--tui-lh);
      height: var(--tui-lh);
      border: none;
      outline: none;
      padding: 0;
      margin: 0;
      background-color: ` & C_BG_INPUT & `;
      color: ` & C_TEXT & `;
      caret-color: ` & C_BORDER_ACT & `;
      display: inline-block;
      letter-spacing: 0;
      vertical-align: top;
      box-sizing: border-box;
      user-select: text;
    }
    .vstui-input:focus {
      background-color: #0f172a;
      box-shadow: inset 0 0 0 1px ` & C_BORDER_ACT & `;
    }
    .vstui-numinput {
      text-align: right;
      color: ` & C_GREEN & `;
    }
    .vstui-combo {
      cursor: pointer;
      color: ` & C_CYAN & `;
    }
    .vstui-textarea {
      resize: none;
      font-family: inherit;
      font-size: inherit;
      line-height: var(--tui-lh);
      background-color: ` & C_BG_INPUT & `;
      color: ` & C_TEXT & `;
      border: none;
      outline: none;
      padding: 0 4px;
      margin: 0;
      caret-color: ` & C_BORDER_ACT & `;
      z-index: 10;
    }
    .vstui-textarea:focus {
      background-color: #0f172a;
      box-shadow: inset 0 0 0 1px ` & C_BORDER_ACT & `;
    }
    .vstui-image {
      display: block;
      box-sizing: border-box;
      user-select: none;
    }
    .vstui-modal-overlay {
      position: fixed;
      top: 0;
      left: 0;
      width: 100vw;
      height: 100vh;
      background: rgba(0, 0, 0, 0.72);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 10000;
      pointer-events: auto;
    }
    .vstui-modal-window {
      position: relative;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.95), 0 0 0 1px ` & C_CYAN & `;
      border-radius: 4px;
      overflow: hidden;
      background: ` & C_BG_CARD & `;
      outline: none;
    }
  </style>
</head>
<body>

  <div id="vstui_app" tabindex="0">
    ` & content & `
  </div>

  <script>
    // Audio Feedback bei Klicks (Web Audio API)
    function playClickBeep() {
      try {
        var ctx = new (window.AudioContext || window.webkitAudioContext)();
        var osc = ctx.createOscillator();
        var gain = ctx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(950, ctx.currentTime);
        osc.frequency.exponentialRampToValueAtTime(450, ctx.currentTime + 0.035);
        gain.gain.setValueAtTime(0.02, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.035);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start();
        osc.stop(ctx.currentTime + 0.035);
      } catch(e){}
    }

    // Deutsches Zahlenformat (z.B. 14250.5 -> 14.250,50 €)
    function formatNumDe(val, nk, currency) {
      if (nk === undefined) nk = 2;
      if (currency === undefined) currency = '€';
      var clean = ('' + val).replace(/[^\d,-]/g, '').replace(',', '.');
      var num = parseFloat(clean);
      if (isNaN(num)) return val;
      var fixed = num.toFixed(nk);
      var parts = fixed.split('.');
      var intPart = parts[0];
      var decPart = parts[1] || '';
      var isNeg = intPart.startsWith('-');
      if (isNeg) intPart = intPart.substring(1);
      var grouped = '';
      var count = 0;
      for (var i = intPart.length - 1; i >= 0; i--) {
        if (count > 0 && count % 3 === 0) grouped = '.' + grouped;
        grouped = intPart[i] + grouped;
        count++;
      }
      if (isNeg) grouped = '-' + grouped;
      var res = grouped;
      if (nk > 0) res += ',' + decPart;
      if (currency) res += ' ' + currency;
      return res;
    }

    // Datumsauswahl Popup direkt unter dem Datumsfeld öffnen
    window.openDatePicker = function(id) {
      var target = document.getElementById(id);
      var rect = target ? target.getBoundingClientRect() : { left: window.innerWidth / 2, bottom: window.innerHeight / 2, width: 140 };
      var picker = document.getElementById('picker_' + id);
      if (!picker) {
        picker = document.createElement('input');
        picker.type = 'date';
        picker.id = 'picker_' + id;
        document.body.appendChild(picker);
        picker.addEventListener('change', function() {
          var targetInp = document.getElementById(id);
          if (targetInp) {
            targetInp.value = this.value;
            targetInp.focus();
          }
        });
      }
      picker.style.cssText = 'position:fixed; opacity:0; pointer-events:none; left:' + Math.round(rect.left) + 'px; top:' + Math.round(rect.bottom + 2) + 'px; width:' + Math.round(rect.width || 120) + 'px; height:24px; z-index:99999;';
      if (target && target.value) {
        picker.value = target.value.trim();
      }
      if (picker.showPicker) {
        try { picker.showPicker(); } catch(e){ picker.focus(); picker.click(); }
      } else {
        picker.focus();
        picker.click();
      }
    };

    // Formulardaten sammeln (Inputs + Textareas)
    function collectFormData() {
      var fields = {};
      var inputs = document.querySelectorAll('.vstui-input, .vstui-textarea');
      for (var i = 0; i < inputs.length; i++) {
        var el = inputs[i];
        if (el.id || el.name) {
          fields[el.id || el.name] = el.value;
        }
      }
      return fields;
    }

    // Backend-Event Dispatcher
    window.sendTuiAction = function(action, extra) {
      playClickBeep();
      var fields = collectFormData();
      var payload = Object.assign({ action: action, fields: fields }, extra || {});
      
      var focusedId = (document.activeElement && (document.activeElement.classList.contains('vstui-input') || document.activeElement.classList.contains('vstui-textarea'))) ? document.activeElement.id : null;
      var curStart = (focusedId && document.activeElement.selectionStart !== undefined) ? document.activeElement.selectionStart : 0;
      var curEnd = (focusedId && document.activeElement.selectionEnd !== undefined) ? document.activeElement.selectionEnd : 0;

      fetch('/__tui_event', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=utf-8' },
        body: JSON.stringify(payload)
      })
      .then(function(res) { return res.json(); })
      .then(function(data) {
        if (data && data.html) {
          document.getElementById('vstui_app').innerHTML = data.html;
          attachInputKeyListeners();

          var targetFocus = data.focus_id || focusedId;
          if (targetFocus) {
            var targetEl = document.getElementById(targetFocus);
            if (targetEl && targetEl.focus) {
              targetEl.focus();
              try {
                targetEl.setSelectionRange(curStart, curEnd);
              } catch(e){}
            }
          }
        }
      })
      .catch(function(err) {
        console.error('VS-TUI Bridge Error:', err);
      });
    };

    // Tastatur-Events an Input-Feldern und Textareas
    function attachInputKeyListeners() {
      var inputs = document.querySelectorAll('.vstui-input:not([readonly]), .vstui-textarea');
      inputs.forEach(function(inp, idx) {
        inp.addEventListener('keydown', function(e) {
          if (e.key === 'Enter' && inp.tagName.toLowerCase() !== 'textarea') {
            e.preventDefault();
            if (idx === inputs.length - 1) {
              window.sendTuiAction('btn_save_detail');
            } else {
              inputs[idx + 1].focus();
              if (inputs[idx + 1].select) inputs[idx + 1].select();
            }
          } else if (e.key === 'Escape') {
            e.preventDefault();
            inp.blur();
            var app = document.getElementById('vstui_app');
            if (app) app.focus();
          }
        });
      });

      // Numerische Felder: beim Fokussieren Rohwert, beim Blur sofort deutsches Währungsformat!
      var numInputs = document.querySelectorAll('.vstui-numinput');
      numInputs.forEach(function(inp) {
        inp.addEventListener('focus', function() {
          var raw = this.value.replace(/[^\d,-]/g, '');
          this.value = raw;
          this.select();
        });
        inp.addEventListener('blur', function() {
          this.value = formatNumDe(this.value, 2, '€');
        });
      });
    }

    // Globale Tastaturnavigation für das Terminal (wenn kein Input/Textarea aktiv fokussiert ist)
    document.addEventListener('keydown', function(e) {
      var activeTag = document.activeElement ? document.activeElement.tagName.toLowerCase() : '';
      if (activeTag === 'input' || activeTag === 'textarea') {
        return; // Eingabefeld hat Tastaturkontrolle
      }

      var key = e.key;
      if (key === 'ArrowUp') {
        e.preventDefault();
        window.sendTuiAction('arrow_up');
      } else if (key === 'ArrowDown') {
        e.preventDefault();
        window.sendTuiAction('arrow_down');
      } else if (key === 'ArrowLeft') {
        e.preventDefault();
        window.sendTuiAction('arrow_left');
      } else if (key === 'ArrowRight') {
        e.preventDefault();
        window.sendTuiAction('arrow_right');
      } else if (key === 'Enter') {
        e.preventDefault();
        var firstInp = document.querySelector('.vstui-input:not([readonly])');
        if (firstInp) {
          firstInp.focus();
          firstInp.select();
        } else {
          window.sendTuiAction('enter');
        }
      } else if (key === 'Escape') {
        e.preventDefault();
        window.sendTuiAction('escape');
      } else if (key === '1') {
        e.preventDefault();
        window.sendTuiAction('tab_1');
      } else if (key === '2') {
        e.preventDefault();
        window.sendTuiAction('tab_2');
      } else if (key === '3') {
        e.preventDefault();
        window.sendTuiAction('tab_3');
      } else if (key === '4') {
        e.preventDefault();
        window.sendTuiAction('tab_4');
      } else if (key === '/') {
        e.preventDefault();
        var searchInp = document.querySelector('.vstui-input:not([readonly])');
        if (searchInp) {
          searchInp.focus();
          searchInp.select();
        }
      }
    });

    // Mausrad-Scrolling (butterweich mit Throttling für Tabellen)
    var lastWheelTime = 0;
    document.addEventListener('wheel', function(e) {
      var activeTag = document.activeElement ? document.activeElement.tagName.toLowerCase() : '';
      if (activeTag === 'textarea') return; // Textarea scrollt eigenen Inhalt
      e.preventDefault();
      var now = Date.now();
      if (now - lastWheelTime < 70) return; // 70ms Drosselung
      lastWheelTime = now;
      if (e.deltaY < 0) {
        window.sendTuiAction('wheel_up');
      } else if (e.deltaY > 0) {
        window.sendTuiAction('wheel_down');
      }
    }, { passive: false });

    window.addEventListener('load', function() {
      attachInputKeyListeners();
      var app = document.getElementById('vstui_app');
      if (app) app.focus();
    });
  </script>
</body>
</html>`

    return html
end function
