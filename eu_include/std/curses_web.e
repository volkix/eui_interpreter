--****
-- == Curses Web: Zeichenbasierte Benutzeroberfläche (TUI) im Webbrowser
--
-- Inspiriert von Turbo Vision (Borland Pascal), Norton Commander, Curses und VT100.
-- Bietet eine vollwertige, tastatur- und mausgesteuerte Zeichenzellen-Oberfläche (80x25, 120x40 etc.)
-- direkt im modernen Webbrowser ohne externe Abhängigkeiten.
--
-- Unterstützt:
--   * Echte Box-Drawing-Rahmen (╔══╗, ┌──┐, ░▒▓ Schatten) mit nativer Unicode-Präzision
--   * Fenster, Dialoge, Drop-Down-Menüleisten, Buttons, Eingabefelder, Tabellen
--   * CRT-Phosphor-Filter (DOS Blau/Grau, VT100 Grün, IBM 3270 Amber)
--   * Tastaturnavigation (Pfeiltasten, Tab, Enter, Esc, F1–F12, Hotkeys)
--   * Reaktive Mausbedienung (Klicks auf Menüs, Buttons, Tabellenzeilen)
--
-- Author: OpenEuphoria / Euphorix Team
--****

namespace curses_web

include std/search.e
include std/types.e
include std/text.e
include std/map.e
include std/utf8.e as utf8
include std/json.e as json
include std/http.e as http

-- =============================================================================
-- 1. Farb- und Stilkonstanten (Klassische 16-Farben-Palette)
-- =============================================================================

public constant
    BLACK         = "#000000",
    BLUE          = "#0000AA",
    GREEN         = "#00AA00",
    CYAN          = "#00AAAA",
    RED           = "#AA0000",
    MAGENTA       = "#AA00AA",
    BROWN         = "#AA5500",
    LIGHT_GRAY    = "#AAAAAA",
    DARK_GRAY     = "#555555",
    LIGHT_BLUE    = "#5555FF",
    LIGHT_GREEN   = "#55FF55",
    LIGHT_CYAN    = "#55FFFF",
    LIGHT_RED     = "#FF5555",
    LIGHT_MAGENTA = "#FF55FF",
    YELLOW        = "#FFFF55",
    WHITE         = "#FFFFFF"

-- Rahmenstile
public constant
    BORDER_SINGLE = 1,  -- ┌ ─ ┐ │ └ ┘ ├ ┤ ┬ ┴ ┼
    BORDER_DOUBLE = 2,  -- ╔ ═ ╗ ║ ╚ ╝ ╠ ╣ ╦ ╩ ╬
    BORDER_ASCII  = 3   -- + - + | + - + | + + +

-- Farbschemata (Themes)
public constant
    THEME_DOS_BLUE    = "dos_blue",   -- Turbo Pascal / Norton Commander (Blau/Cyan/Gelb)
    THEME_CRT_GREEN   = "crt_green",  -- VT100 / Matrix Phosphorgrün
    THEME_CRT_AMBER   = "crt_amber",  -- IBM 3270 Bernstein-Phosphor
    THEME_DARK_MODERN = "dark"        -- Modernes Anthrazit/Türkis

-- Screen-Datenstruktur Indizes
constant
    SCR_WIDTH     = 1,
    SCR_HEIGHT    = 2,
    SCR_CELLS     = 3,
    SCR_DEF_FG    = 4,
    SCR_DEF_BG    = 5,
    SCR_TITLE     = 6

-- Zell-Datenstruktur Indizes
constant
    CELL_CHAR     = 1,
    CELL_FG       = 2,
    CELL_BG       = 3,
    CELL_ACTION   = 4,
    CELL_HOTKEY   = 5

-- =============================================================================
-- 2. Screen-Puffer-Verwaltung
-- =============================================================================

--**
-- Erzeugt einen neuen Screen-Puffer mit angegebener Zeichenbreite und -höhe.
-- Standardmäßig 80x25 (klassische DOS-Auflösung) im Turbo-Vision-Blau.
public function new_screen(integer width = 80, integer height = 25, sequence fg = WHITE, sequence bg = BLUE)
    sequence cells = repeat(repeat({" ", fg, bg, "", 0}, width), height)
    return {width, height, cells, fg, bg, "Euphorix Curses Web"}
end function

--**
-- Löscht den gesamten Screen-Puffer mit der angegebenen Hintergrundfarbe.
public function clear(sequence screen, sequence bg = BLUE)
    integer w = screen[SCR_WIDTH]
    integer h = screen[SCR_HEIGHT]
    sequence fg = screen[SCR_DEF_FG]
    screen[SCR_CELLS] = repeat(repeat({" ", fg, bg, "", 0}, w), h)
    return screen
end function

--**
-- Setzt ein einzelnes Zeichen an Koordinate (x, y). (1-basiert)
public function set_char(sequence screen, integer x, integer y, sequence ch, sequence fg = "", sequence bg = "", sequence action = "")
    integer w = screen[SCR_WIDTH]
    integer h = screen[SCR_HEIGHT]
    if x < 1 or x > w or y < 1 or y > h then return screen end if
    if length(fg) = 0 then fg = screen[SCR_DEF_FG] end if
    if length(bg) = 0 then bg = screen[SCR_DEF_BG] end if
    screen[SCR_CELLS][y][x] = {ch, fg, bg, action, 0}
    return screen
end function

--**
-- Schreibt einen Text ab Position (x, y).
-- Verwendet Unicode-Codepoints, damit UTF-8-Zeichen (╔, ═, ║, ä, ö, ü, € etc.) exakt EINE Zelle belegen!
-- Unterstützt Tilde-Hotkeys wie "~D~atei" (der Buchstabe zwischen den Tilden wird hervorgehoben).
public function print_at(sequence screen, integer x, integer y, sequence text, sequence fg = "", sequence bg = "", sequence action = "")
    integer w = screen[SCR_WIDTH]
    integer h = screen[SCR_HEIGHT]
    if y < 1 or y > h then return screen end if
    if length(fg) = 0 then fg = screen[SCR_DEF_FG] end if
    if length(bg) = 0 then bg = screen[SCR_DEF_BG] end if

    integer cx = x
    integer in_hotkey = 0

    sequence cps = utf8:to_codepoints(text)
    for i = 1 to length(cps) do
        integer cp = cps[i]
        if cp = '~' then
            in_hotkey = not in_hotkey
        else
            if cx >= 1 and cx <= w then
                sequence cell_fg = iff(in_hotkey, YELLOW, fg)
                sequence ch = utf8:from_codepoints(cp)
                screen[SCR_CELLS][y][cx] = {ch, cell_fg, bg, action, in_hotkey}
            end if
            cx += 1
        end if
    end for
    return screen
end function

-- =============================================================================
-- 3. Rahmen, Schatten & Geometrie
-- =============================================================================

--**
-- Zeichnet einen Rahmen (Single, Double oder ASCII) mit optionalem Titel.
public function draw_box(sequence screen, integer x, integer y, integer w, integer h,
                         integer border_style = BORDER_DOUBLE, sequence title = "",
                         sequence fg = "", sequence bg = "")
    if length(fg) = 0 then fg = screen[SCR_DEF_FG] end if
    if length(bg) = 0 then bg = screen[SCR_DEF_BG] end if

    sequence c_tl = "╔", c_tr = "╗", c_bl = "╚", c_br = "╝", c_h = "═", c_v = "║"
    if border_style = BORDER_SINGLE then
        c_tl = "┌"  c_tr = "┐"  c_bl = "└"  c_br = "┘"  c_h = "─"  c_v = "│"
    elsif border_style = BORDER_ASCII then
        c_tl = "+"  c_tr = "+"  c_bl = "+"  c_br = "+"  c_h = "-"  c_v = "|"
    end if

    -- Ecken
    screen = set_char(screen, x, y, c_tl, fg, bg)
    screen = set_char(screen, x + w - 1, y, c_tr, fg, bg)
    screen = set_char(screen, x, y + h - 1, c_bl, fg, bg)
    screen = set_char(screen, x + w - 1, y + h - 1, c_br, fg, bg)

    -- Horizontale Linien
    for col = x + 1 to x + w - 2 do
        screen = set_char(screen, col, y, c_h, fg, bg)
        screen = set_char(screen, col, y + h - 1, c_h, fg, bg)
    end for

    -- Vertikale Linien
    for row = y + 1 to y + h - 2 do
        screen = set_char(screen, x, row, c_v, fg, bg)
        screen = set_char(screen, x + w - 1, row, c_v, fg, bg)
    end for

    -- Titel zentriert im oberen Rahmen
    if length(title) > 0 and w > (utf8:len(title) + 4) then
        integer title_x = x + floor((w - utf8:len(title) - 2) / 2)
        screen = print_at(screen, title_x, y, " " & title & " ", YELLOW, bg)
    end if

    return screen
end function

--**
-- Zeichnet einen DOS-typischen 3D-Halbton-Schatten (░) rechts und unterhalb eines Fensters.
public function draw_shadow(sequence screen, integer x, integer y, integer w, integer h)
    integer sw = screen[SCR_WIDTH]
    integer sh = screen[SCR_HEIGHT]

    -- Rechter Schatten
    for row = y + 1 to y + h do
        if row <= sh and (x + w) <= sw then
            screen[SCR_CELLS][row][x + w] = {"░", DARK_GRAY, BLACK, "", 0}
            if (x + w + 1) <= sw then
                screen[SCR_CELLS][row][x + w + 1] = {"░", DARK_GRAY, BLACK, "", 0}
            end if
        end if
    end for

    -- Unterer Schatten
    if (y + h) <= sh then
        for col = x + 2 to x + w + 1 do
            if col <= sw then
                screen[SCR_CELLS][y + h][col] = {"░", DARK_GRAY, BLACK, "", 0}
            end if
        end for
    end if

    return screen
end function

--**
-- Füllt einen rechteckigen Bereich mit Zeichen und Farben.
public function fill_rect(sequence screen, integer x, integer y, integer w, integer h, sequence ch = " ", sequence fg = "", sequence bg = "")
    if length(fg) = 0 then fg = screen[SCR_DEF_FG] end if
    if length(bg) = 0 then bg = screen[SCR_DEF_BG] end if
    for row = y to y + h - 1 do
        for col = x to x + w - 1 do
            screen = set_char(screen, col, row, ch, fg, bg)
        end for
    end for
    return screen
end function

-- =============================================================================
-- 4. High-Level Curses / Turbo-Vision Widgets
-- =============================================================================

--**
-- Zeichnet ein vollwertiges Fenster mit Hintergrund, Rahmen, Titel und 3D-Schatten.
public function draw_window(sequence screen, sequence id, sequence title, integer x, integer y, integer w, integer h, sequence options = {})
    sequence win_fg = WHITE
    sequence win_bg = CYAN
    integer border = BORDER_DOUBLE
    integer has_shadow = 1

    -- Fensterkörper ausfüllen (innen)
    screen = fill_rect(screen, x, y, w, h, " ", win_fg, win_bg)

    -- Rahmen
    screen = draw_box(screen, x, y, w, h, border, title, win_fg, win_bg)

    -- Schließen-Symbol [■] oben links
    screen = print_at(screen, x + 2, y, "[~■~]", WHITE, win_bg, "close_" & id)

    -- 3D-Schatten
    if has_shadow then
        screen = draw_shadow(screen, x, y, w, h)
    end if

    return screen
end function

--**
-- Zeichnet einen interaktiven Button: [ OK ] oder < Abbrechen >
public function draw_button(sequence screen, sequence id, sequence text, integer x, integer y, integer is_focused = 0, sequence options = {})
    sequence btn_fg = BLACK
    sequence btn_bg = LIGHT_GRAY
    if is_focused then
        btn_fg = WHITE
        btn_bg = GREEN
    end if

    sequence full_text = iff(is_focused, "► " & text & " ◄", "[ " & text & " ]")
    screen = print_at(screen, x, y, full_text, btn_fg, btn_bg, id)
    return screen
end function

--**
-- Zeichnet ein Eingabefeld mit Label: "Kundennummer: [K-1001       ]"
public function draw_input(sequence screen, sequence id, sequence label_text, sequence value, integer x, integer y, integer field_w, integer is_focused = 0)
    sequence lbl_fg = WHITE
    sequence lbl_bg = CYAN
    sequence inp_fg = YELLOW
    sequence inp_bg = BLUE

    if is_focused then
        inp_fg = WHITE
        inp_bg = DARK_GRAY
    end if

    -- Label zeichnen
    if length(label_text) > 0 then
        screen = print_at(screen, x, y, label_text, lbl_fg, lbl_bg)
        x += utf8:len(label_text) + 1
    end if

    -- Eingabefeld mit Klammern
    screen = print_at(screen, x, y, "[", WHITE, lbl_bg)
    sequence val_padded = value
    if utf8:len(val_padded) < field_w then
        val_padded &= repeat(' ', field_w - utf8:len(val_padded))
    elsif utf8:len(val_padded) > field_w then
        val_padded = utf8:slice(val_padded, 1, field_w)
    end if

    screen = print_at(screen, x + 1, y, val_padded, inp_fg, inp_bg, id)
    screen = print_at(screen, x + 1 + field_w, y, "]", WHITE, lbl_bg)
    return screen
end function

--**
-- Zeichnet eine tabellarische Datenübersicht (DataGrid) im Curses-Look mit Auswahbalken.
public function draw_table(sequence screen, sequence id, sequence headers, sequence rows,
                           integer x, integer y, integer w, integer h,
                           integer selected_row = 1)
    integer num_cols = length(headers)
    if num_cols = 0 then return screen end if

    -- Berechne Spaltenbreiten so, dass sie exakt in w passen
    sequence col_widths = repeat(0, num_cols)
    for c = 1 to num_cols do
        integer cw = 12
        if length(headers[c]) >= 2 and integer(headers[c][2]) then
            cw = headers[c][2]
        end if
        col_widths[c] = cw
    end for

    -- Nutze exakte Breitenanpassung: Rahmen benötigt 2 (links/rechts) + (num_cols - 1) Trennstriche
    integer avail_w = w - 2 - (num_cols - 1)
    if avail_w < num_cols then avail_w = num_cols end if
    integer allocated = 0
    for c = 1 to num_cols - 1 do
        allocated += col_widths[c]
    end for
    if avail_w > allocated then
        col_widths[num_cols] = avail_w - allocated
    end if

    -- 1. Oberer Rahmen: ╔════╤════╤════╗
    screen = set_char(screen, x, y, "╔", WHITE, BLUE)
    integer col_pos = x + 1
    for c = 1 to num_cols do
        for k = 1 to col_widths[c] do
            screen = set_char(screen, col_pos, y, "═", WHITE, BLUE)
            col_pos += 1
        end for
        if c < num_cols then
            screen = set_char(screen, col_pos, y, "╤", WHITE, BLUE)
            col_pos += 1
        end if
    end for
    screen = set_char(screen, x + w - 1, y, "╗", WHITE, BLUE)

    -- 2. Header-Zeile: ║ Spalte 1 │ Spalte 2 ║
    screen = set_char(screen, x, y + 1, "║", WHITE, BLUE)
    col_pos = x + 1
    for c = 1 to num_cols do
        sequence title = headers[c][1]
        integer cw = col_widths[c]
        sequence padded = title
        if utf8:len(padded) < cw then
            padded &= repeat(' ', cw - utf8:len(padded))
        else
            padded = utf8:slice(padded, 1, cw)
        end if
        screen = print_at(screen, col_pos, y + 1, padded, YELLOW, BLUE)
        col_pos += cw
        if c < num_cols then
            screen = set_char(screen, col_pos, y + 1, "│", WHITE, BLUE)
            col_pos += 1
        end if
    end for
    screen = set_char(screen, x + w - 1, y + 1, "║", WHITE, BLUE)

    -- 3. Header-Trennlinie: ╠════╪════╪════╣
    screen = set_char(screen, x, y + 2, "╠", WHITE, BLUE)
    col_pos = x + 1
    for c = 1 to num_cols do
        for k = 1 to col_widths[c] do
            screen = set_char(screen, col_pos, y + 2, "═", WHITE, BLUE)
            col_pos += 1
        end for
        if c < num_cols then
            screen = set_char(screen, col_pos, y + 2, "╪", WHITE, BLUE)
            col_pos += 1
        end if
    end for
    screen = set_char(screen, x + w - 1, y + 2, "╣", WHITE, BLUE)

    -- 4. Datenzeilen (ab y + 3 bis y + h - 2)
    integer max_data_rows = h - 4
    for r = 1 to max_data_rows do
        integer row_idx = r
        integer curr_y = y + 2 + r
        integer is_sel = (row_idx = selected_row)
        sequence row_fg = iff(is_sel, BLACK, WHITE)
        sequence row_bg = iff(is_sel, GREEN, BLUE)
        sequence row_action = sprintf("%s_row_%d", {id, row_idx})

        screen = set_char(screen, x, curr_y, "║", WHITE, BLUE)
        col_pos = x + 1

        if row_idx <= length(rows) then
            sequence row_data = rows[row_idx]
            for c = 1 to num_cols do
                sequence cell_val = ""
                if c <= length(row_data) then
                    cell_val = to_string(row_data[c])
                end if
                integer cw = col_widths[c]
                sequence val_display = cell_val
                if c = 1 and is_sel then
                    val_display = "►" & cell_val
                end if
                sequence padded = val_display
                if utf8:len(padded) < cw then
                    padded &= repeat(' ', cw - utf8:len(padded))
                else
                    padded = utf8:slice(padded, 1, cw)
                end if
                screen = print_at(screen, col_pos, curr_y, padded, row_fg, row_bg, row_action)
                col_pos += cw
                if c < num_cols then
                    screen = set_char(screen, col_pos, curr_y, "│", WHITE, BLUE)
                    col_pos += 1
                end if
            end for
        else
            -- Leere Zeile
            for c = 1 to num_cols do
                integer cw = col_widths[c]
                screen = fill_rect(screen, col_pos, curr_y, cw, 1, " ", DARK_GRAY, BLUE)
                col_pos += cw
                if c < num_cols then
                    screen = set_char(screen, col_pos, curr_y, "│", DARK_GRAY, BLUE)
                    col_pos += 1
                end if
            end for
        end if
        screen = set_char(screen, x + w - 1, curr_y, "║", WHITE, BLUE)
    end for

    -- 5. Unterer Rahmen: ╚════╧════╧════╝
    screen = set_char(screen, x, y + h - 1, "╚", WHITE, BLUE)
    col_pos = x + 1
    for c = 1 to num_cols do
        for k = 1 to col_widths[c] do
            screen = set_char(screen, col_pos, y + h - 1, "═", WHITE, BLUE)
            col_pos += 1
        end for
        if c < num_cols then
            screen = set_char(screen, col_pos, y + h - 1, "╧", WHITE, BLUE)
            col_pos += 1
        end if
    end for
    screen = set_char(screen, x + w - 1, y + h - 1, "╝", WHITE, BLUE)

    return screen
end function

--**
-- Zeichnet die klassische Turbo-Vision-Menüleiste am oberen Bildschirmrand (Zeile 1).
public function draw_menubar(sequence screen, sequence menu_items, integer active_idx = 0)
    integer w = screen[SCR_WIDTH]
    screen = fill_rect(screen, 1, 1, w, 1, " ", BLACK, LIGHT_GRAY)
    integer cx = 2
    for i = 1 to length(menu_items) do
        sequence itm = menu_items[i]
        sequence m_label = itm[1]
        sequence action = "menu_" & m_label
        if length(itm) >= 2 then action = itm[2] end if
        integer is_act = (i = active_idx)
        sequence m_fg = iff(is_act, WHITE, BLACK)
        sequence m_bg = iff(is_act, GREEN, LIGHT_GRAY)

        screen = print_at(screen, cx, 1, " " & m_label & " ", m_fg, m_bg, action)
        cx += utf8:len(m_label) + 2
    end for
    return screen
end function

--**
-- Zeichnet die klassische Funktionstastenleiste am unteren Bildschirmrand (Zeile 25).
-- z.B. "1 Hilfe  2 Speichern  3 Suchen  7 Filter  10 Beenden"
public function draw_statusbar(sequence screen, sequence fkeys)
    integer w = screen[SCR_WIDTH]
    integer h = screen[SCR_HEIGHT]
    screen = fill_rect(screen, 1, h, w, 1, " ", BLACK, LIGHT_GRAY)
    integer cx = 1

    for i = 1 to length(fkeys) do
        sequence fk = fkeys[i]
        sequence key_num = fk[1]
        sequence key_label = fk[2]
        sequence action = "fkey_" & key_num
        if length(fk) >= 3 then action = fk[3] end if

        -- Tasten-Nummer schwarz auf hellgrau, Text weiß auf schwarz
        screen = print_at(screen, cx, h, key_num, BLACK, LIGHT_GRAY, action)
        cx += utf8:len(key_num)
        screen = print_at(screen, cx, h, key_label & " ", WHITE, BLACK, action)
        cx += utf8:len(key_label) + 2
    end for
    return screen
end function

-- =============================================================================
-- 5. Web-Rendering-Engine (HTML, CSS, CRT-Filter & Client-Bridge)
-- =============================================================================

function to_string(object o)
    if sequence(o) then return o end if
    return sprintf("%v", {o})
end function

--**
-- Rendert den Screen-Puffer in einen reaktiven HTML-Block (z.B. für Patches oder iframe).
-- WICHTIG: Keine Zeilenumbrüche zwischen den HTML-Tags, damit keine unerwünschten Zwischenräume entstehen!
public function render_screen_html(sequence screen, sequence theme = THEME_DOS_BLUE)
    integer w = screen[SCR_WIDTH]
    integer h = screen[SCR_HEIGHT]
    sequence cells = screen[SCR_CELLS]

    sequence html = sprintf("<div class=\"tui-screen-buffer theme-%s\" data-cols=\"%d\" data-rows=\"%d\">", {theme, w, h})

    for y = 1 to h do
        html &= "<div class=\"tui-line\">"
        integer x = 1
        while x <= w do
            sequence c = cells[y][x]
            sequence ch = c[CELL_CHAR]
            sequence fg = c[CELL_FG]
            sequence bg = c[CELL_BG]
            sequence act = c[CELL_ACTION]
            integer hotkey = c[CELL_HOTKEY]

            -- Suche zusammenhängende Zeichen mit identischen Attributen für optimiertes HTML
            sequence run_text = ch
            integer next_x = x + 1
            while next_x <= w do
                sequence nc = cells[y][next_x]
                if equal(nc[CELL_FG], fg) and equal(nc[CELL_BG], bg) and equal(nc[CELL_ACTION], act) and equal(nc[CELL_HOTKEY], hotkey) then
                    run_text &= nc[CELL_CHAR]
                    next_x += 1
                else
                    exit
                end if
            end while

            -- Escape HTML entities (<, >, &, ")
            sequence safe_text = ""
            for i = 1 to length(run_text) do
                object char_val = run_text[i]
                if equal(char_val, '<') then safe_text &= "&lt;"
                elsif equal(char_val, '>') then safe_text &= "&gt;"
                elsif equal(char_val, '&') then safe_text &= "&amp;"
                elsif equal(char_val, '"') then safe_text &= "&quot;"
                else safe_text &= char_val
                end if
            end for

            sequence span_cls = "tui-cell"
            if length(act) > 0 then span_cls &= " tui-interactive" end if
            if hotkey then span_cls &= " tui-hotkey" end if

            sequence act_attr = ""
            if length(act) > 0 then
                act_attr = sprintf(" data-action=\"%s\" onclick=\"sendTuiEvent('click', '%s')\"", {act, act})
            end if

            html &= sprintf("<span class=\"%s\" style=\"color:%s; background-color:%s;\"%s>%s</span>",
                            {span_cls, fg, bg, act_attr, safe_text})
            x = next_x
        end while
        html &= "</div>"
    end for
    html &= "</div>"
    return html
end function

--**
-- Rendert eine vollständige, autarke HTML5-Webseite mit Tastatur-Engine, CRT-Scanlines und Audio-Feedback.
public function render_page(sequence screen, sequence title, sequence theme = THEME_DOS_BLUE, sequence options = {})
    sequence screen_content = render_screen_html(screen, theme)
    integer w = screen[SCR_WIDTH]
    integer h = screen[SCR_HEIGHT]

    sequence html = `<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>` & title & ` - Euphorix Web-Curses TUI</title>
  <style>
    :root {
      --tui-font-family: "DejaVu Sans Mono", "Liberation Mono", "Noto Sans Mono", "Courier New", "Consolas", monospace;
      --tui-cell-h: 18px;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: #000;
      color: #aaa;
      font-family: var(--tui-font-family);
      font-size: 15px;
      line-height: 1;
      height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      overflow: hidden;
      user-select: none;
    }
    .crt-monitor {
      position: relative;
      background: #080808;
      padding: 12px 14px;
      border-radius: 8px;
      box-shadow: 0 0 40px rgba(0, 0, 0, 0.95), inset 0 0 10px rgba(255, 255, 255, 0.05);
      border: 3px solid #333;
    }
    /* CRT Scanline Filter */
    .crt-monitor::after {
      content: " ";
      display: block;
      position: absolute;
      top: 0; left: 0; bottom: 0; right: 0;
      background: linear-gradient(rgba(18, 16, 16, 0) 50%, rgba(0, 0, 0, 0.22) 50%), linear-gradient(90deg, rgba(255, 0, 0, 0.02), rgba(0, 255, 0, 0.01), rgba(0, 0, 255, 0.02));
      background-size: 100% 3px, 6px 100%;
      pointer-events: none;
      border-radius: 6px;
    }
    .tui-screen-buffer {
      display: block;
      margin: 0 auto;
      cursor: default;
      outline: none;
      font-family: var(--tui-font-family);
      font-size: 15px;
      line-height: var(--tui-cell-h);
      letter-spacing: 0;
      font-variant-ligatures: none;
      border: 1px solid #1a1a1a;
      box-shadow: 0 0 25px rgba(0, 80, 220, 0.3);
    }
    .tui-line {
      display: block;
      height: var(--tui-cell-h);
      line-height: var(--tui-cell-h);
      white-space: pre;
      margin: 0;
      padding: 0;
      overflow: hidden;
    }
    .tui-cell {
      display: inline;
      margin: 0;
      padding: 0;
      font-family: inherit;
      font-size: 15px;
      line-height: var(--tui-cell-h);
      letter-spacing: 0;
      white-space: pre;
    }
    .tui-interactive {
      cursor: pointer;
    }
    .tui-interactive:hover {
      filter: brightness(1.35) contrast(1.15);
      text-decoration: underline;
    }
    .tui-hotkey {
      font-weight: bold;
      text-decoration: underline;
    }
    /* Controls Footer */
    .tui-info-footer {
      margin-top: 10px;
      display: flex;
      justify-content: space-between;
      width: 100%;
      font-size: 12px;
      color: #777;
    }
    .tui-badge {
      background: #111;
      padding: 3px 8px;
      border-radius: 4px;
      border: 1px solid #333;
    }
  </style>
</head>
<body>

  <div class="crt-monitor">
    <div id="tui_container" tabindex="0">
      ` & screen_content & `
    </div>
    <div class="tui-info-footer">
      <span class="tui-badge">⌨️ Curses-TUI Engine: ` & sprintf("%dx%d", {w, h}) & `</span>
      <span class="tui-badge">Navigation: Pfeiltasten, Tab, Enter, Esc, F1–F10 | Maus: Klickbar</span>
      <span class="tui-badge">Euphorix VM &bull; Zero-Build</span>
    </div>
  </div>

  <script>
    // Audio Beeper für Retro-Soundeffekte (Web Audio API)
    function playBeep(freq = 880, duration = 40) {
      try {
        var ctx = new (window.AudioContext || window.webkitAudioContext)();
        var osc = ctx.createOscillator();
        var gain = ctx.createGain();
        osc.type = 'square';
        osc.frequency.value = freq;
        gain.gain.setValueAtTime(0.04, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration / 1000);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start();
        osc.stop(ctx.currentTime + duration / 1000);
      } catch(e){}
    }

    // Event Dispatcher an Euphorix Backend
    window.sendTuiEvent = function(type, action, extra) {
      playBeep(type === 'click' ? 1200 : 750, 30);
      var payload = Object.assign({ type: type, action: action }, extra || {});
      
      fetch('/__tui_event', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=utf-8' },
        body: JSON.stringify(payload)
      })
      .then(function(res) { return res.json(); })
      .then(function(data) {
        if (data && data.html) {
          document.getElementById('tui_container').innerHTML = data.html;
        }
      })
      .catch(function(err) {
        console.error('TUI Event Error:', err);
      });
    };

    // Globale Tastaturnavigation
    document.addEventListener('keydown', function(e) {
      var key = e.key;
      var fKeyMatch = key.match(/^F([1-9]|1[0-2])$/);
      
      if (fKeyMatch) {
        e.preventDefault();
        window.sendTuiEvent('fkey', 'fkey_' + fKeyMatch[1]);
        return;
      }
      
      if (key === 'ArrowUp' || key === 'ArrowDown' || key === 'ArrowLeft' || key === 'ArrowRight' ||
          key === 'Enter' || key === 'Escape' || key === 'Tab') {
        e.preventDefault();
        window.sendTuiEvent('key', key.toLowerCase());
      }
    });

    // Automatischer Fokus
    window.addEventListener('load', function() {
      var c = document.getElementById('tui_container');
      if (c) c.focus();
    });
  </script>
</body>
</html>`

    return html
end function
