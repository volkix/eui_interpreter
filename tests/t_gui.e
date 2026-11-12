include std/unittest.e
include std/gui.e as gui
include std/java.e as java
include std/text.e

set_test_verbosity(TEST_SHOW_ALL)

-- 1. Window Creation & Configuration
atom win = gui:window("Unit Test Window", 500, 350, gui:DISPOSE_ON_CLOSE)
test_true("window creation", win > 0)

-- 2. Widgets Creation
atom lbl = gui:text_label("Original Label")
test_true("text_label creation", lbl > 0)
test_equal("get_text label", "Original Label", gui:get_text(lbl))
gui:set_text(lbl, "Updated Label")
test_equal("set_text label", "Updated Label", gui:get_text(lbl))
gui:set_text(lbl, "Überprüfung: ä ö ü ß Ä Ö Ü")
test_equal("set_text label UTF-8 umlauts", "Überprüfung: ä ö ü ß Ä Ö Ü", gui:get_text(lbl))

atom txt = gui:text_field("Hello Euphoria", 25)
test_true("text_field creation", txt > 0)
test_equal("get_text text_field", "Hello Euphoria", gui:get_text(txt))
gui:set_text(txt, "Swing Power")
test_equal("set_text text_field", "Swing Power", gui:get_text(txt))

atom area = gui:text_area("Multi\nLine", 5, 20)
test_true("text_area creation", area > 0)
atom scroll = gui:scroll_pane(area)
test_true("scroll_pane creation", scroll > 0)

atom cb = gui:check_box("Accept Terms", 0)
test_true("check_box creation", cb > 0)
test_false("check_box initial unselected", gui:is_selected(cb))
gui:set_selected(cb, 1)
test_true("check_box selected", gui:is_selected(cb))

atom rb = gui:radio_button("Choice A", 1)
test_true("radio_button creation", rb > 0)
test_true("radio_button selected", gui:is_selected(rb))

atom combo = gui:combo_box({"Linux", "FreeBSD", "Euphorix"})
test_true("combo_box creation", combo > 0)
test_equal("combo_box getItemCount", 3, java:call_method(combo, "getItemCount", {}))

atom pnl = gui:panel(gui:FLOW_LAYOUT)
test_true("panel creation", pnl > 0)

atom pbar = gui:progress_bar(0, 100)
test_true("progress_bar creation", pbar > 0)
gui:set_value(pbar, 75)
test_equal("progress_bar value", 75, gui:get_value(pbar))

atom sld = gui:slider(10, 50, 25)
test_true("slider creation", sld > 0)
test_equal("slider initial value", 25, gui:get_value(sld))
gui:set_value(sld, 40)
test_equal("slider updated value", 40, gui:get_value(sld))

-- 3. Layout and Container Hierarchy
gui:set_layout(win, gui:BORDER_LAYOUT)
gui:add(win, lbl, gui:NORTH)
gui:add(win, txt, gui:CENTER)

gui:add(pnl, cb)
gui:add(pnl, rb)
gui:add(win, pnl, gui:SOUTH)

-- 4. Event Handling & Callbacks
integer click_counter = 0
atom clicked_btn_sender = 0

procedure test_click_handler(atom sender)
    click_counter += 1
    clicked_btn_sender = sender
end procedure

atom btn = gui:button("Klick Test", routine_id("test_click_handler"))
test_true("button creation", btn > 0)
gui:add(pnl, btn)

-- Programmatically trigger button click:
java:call_method(btn, "doClick", {})
test_equal("callback invoked once", 1, click_counter)
test_equal("callback sender match", btn, clicked_btn_sender)

java:call_method(btn, "doClick", {})
test_equal("callback invoked twice", 2, click_counter)

-- Clean up
gui:close_window(win)
test_pass("GUI clean teardown")

test_report()
