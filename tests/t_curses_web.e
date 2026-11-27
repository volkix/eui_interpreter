-- Unit Tests für std/curses_web.e (Zeichenbasierte Curses-TUI im Browser)

include std/unittest.e
include std/curses_web.e as tui
include std/search.e

set_test_verbosity(TEST_SHOW_ALL)

-- 1. Screen Erstellung & Abmessungen
sequence scr = tui:new_screen(80, 25, tui:WHITE, tui:BLUE)
test_equal("screen width 80", scr[1], 80)
test_equal("screen height 25", scr[2], 25)
test_equal("screen cells row count", length(scr[3]), 25)
test_equal("screen cells col count", length(scr[3][1]), 80)

-- 2. Zeichen & Text
scr = tui:set_char(scr, 10, 5, "X", tui:YELLOW, tui:RED, "click_x")
sequence cell = scr[3][5][10]
test_equal("cell char", cell[1], "X")
test_equal("cell fg", cell[2], tui:YELLOW)
test_equal("cell bg", cell[3], tui:RED)
test_equal("cell action", cell[4], "click_x")

-- 3. Text mit Tilde-Hotkeys
scr = tui:print_at(scr, 1, 1, "~D~atei", tui:WHITE, tui:BLUE)
test_equal("hotkey D has YELLOW fg", scr[3][1][1][2], tui:YELLOW)
test_equal("regular char a has WHITE fg", scr[3][1][2][2], tui:WHITE)

-- 4. Rahmen & Boxen
scr = tui:draw_box(scr, 5, 5, 20, 10, tui:BORDER_DOUBLE, "Testbox", tui:WHITE, tui:CYAN)
test_equal("box top-left is double", scr[3][5][5][1], "╔")
test_equal("box top-right is double", scr[3][5][24][1], "╗")
test_equal("box bot-left is double", scr[3][14][5][1], "╚")
test_equal("box bot-right is double", scr[3][14][24][1], "╝")

-- 5. Curses Widgets (Window, Button, Input, Table, Menubar, Statusbar)
scr = tui:draw_window(scr, "win_dlg", "Kundenstamm", 2, 2, 76, 20)
scr = tui:draw_menubar(scr, {{"~D~atei", "m_file"}, {"~H~ilfe", "m_help"}})
scr = tui:draw_statusbar(scr, {{"1", "Hilfe"}, {"10", "Ende"}})
scr = tui:draw_button(scr, "btn_save", "Speichern", 10, 18, 1)
scr = tui:draw_input(scr, "txt_nr", "Nummer:", "K-1001", 10, 8, 12, 0)
scr = tui:draw_table(scr, "tbl_data", {{"ID", 6}, {"Name", 20}}, {{"1", "Schulze"}, {"2", "Meyer"}}, 10, 10, 50, 6, 1)

-- 6. HTML Rendering
sequence scr_html = tui:render_screen_html(scr, tui:THEME_DOS_BLUE)
test_true("rendered screen html does not contain raw newline gap", search:match("\n", scr_html) = 0)

sequence html = tui:render_page(scr, "Curses Test", tui:THEME_DOS_BLUE)
test_true("html contains doctype", search:match("<!DOCTYPE html>", html) > 0)
test_true("html contains crt monitor", search:match("class=\"crt-monitor\"", html) > 0)
test_true("html contains tui-screen-buffer", search:match("class=\"tui-screen-buffer", html) > 0)
test_true("html contains box border", search:match("╔", html) > 0)
test_true("html contains button Speichern", search:match("Speichern", html) > 0)
test_true("html contains keyboard event listener", search:match("addEventListener('keydown'", html) > 0)
test_true("html contains tui-interactive", search:match("tui-interactive", html) > 0)
test_true("html contains web audio beep", search:match("playBeep", html) > 0)

-- 7. Unicode Multi-Byte Box Drawing & Alignment Test
sequence test_scr = tui:new_screen(20, 5)
test_scr = tui:print_at(test_scr, 1, 1, "╔═══╗")
test_equal("cell 1 is top-left box", test_scr[3][1][1][1], "╔")
test_equal("cell 2 is horizontal box", test_scr[3][1][2][1], "═")
test_equal("cell 3 is horizontal box", test_scr[3][1][3][1], "═")
test_equal("cell 4 is horizontal box", test_scr[3][1][4][1], "═")
test_equal("cell 5 is top-right box", test_scr[3][1][5][1], "╗")
test_equal("cell 6 is space", test_scr[3][1][6][1], " ")

test_report()
