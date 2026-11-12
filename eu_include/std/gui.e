--****
-- == Swing GUI API for OpenEuphoria on Java 25
--
-- Provides a clean, declarative, high-level graphical user interface API
-- powered natively by Java Swing and AWT on Linux 64-bit.
--
-- Every widget handle returned is also a full Java object handle, allowing
-- low-level Swing customisation via std/java.e whenever desired.
--

namespace gui

include std/java.e as java
include std/os.e as os

--**
-- === Layout & Position Constants
public constant
    BORDER_LAYOUT = 1,
    FLOW_LAYOUT   = 2,
    GRID_LAYOUT   = 3,
    
    NORTH  = "North",
    SOUTH  = "South",
    EAST   = "East",
    WEST   = "West",
    CENTER = "Center"

--**
-- === Window Close Operations
public constant
    DO_NOTHING_ON_CLOSE = 0,
    HIDE_ON_CLOSE       = 1,
    DISPOSE_ON_CLOSE    = 2,
    CLOSE_ON_EXIT       = 3

--**
-- === Message Box Icons & Dialog Constants
public constant
    MSG_ERROR    = 0,
    MSG_INFO     = 1,
    MSG_WARN     = 2,
    MSG_QUESTION = 3,
    MSG_PLAIN    = -1

--**
-- === Alignment Constants
public constant
    ALIGN_LEFT   = 2,
    ALIGN_CENTER = 0,
    ALIGN_RIGHT  = 4

atom gui_initialized = 0

--**
-- Initializes the GUI subsystem, applying the native Linux Look and Feel (GTK/System).
public procedure init_gui()
    if gui_initialized then return end if
    gui_initialized = 1
    -- 1. Try native GTK+ Look and Feel first for Linux desktop integration
    java:call_static("javax.swing.UIManager", "setLookAndFeel", {"com.sun.java.swing.plaf.gtk.GTKLookAndFeel"})
    atom laf = java:call_static("javax.swing.UIManager", "getLookAndFeel", {})
    object laf_name = ""
    if laf > 0 then
        laf_name = java:call_method(laf, "getName", {})
    end if
    -- 2. If GTK not active, fall back to Nimbus or System LAF
    if sequence(laf_name) and match("GTK", laf_name) = 0 then
        java:call_static("javax.swing.UIManager", "setLookAndFeel", {"javax.swing.plaf.nimbus.NimbusLookAndFeel"})
    end if
end procedure

--**
-- Sets the UI theme / Look and Feel.
--
-- Supported values for theme_name:
--   # "gtk"           : Native Linux GTK+ Look and Feel
--   # "flatlaf"       : Modern FlatLaf Light
--   # "flatlaf-light" : Modern FlatLaf Light
--   # "flatlaf-dark"  : Modern FlatLaf Dark
--   # "nimbus"        : Modern Nimbus
--   # "system"        : Host System Look and Feel
--
public procedure set_theme(sequence theme_name)
    init_gui()
    if equal(theme_name, "flatlaf") or equal(theme_name, "flatlaf-light") then
        java:call_static("com.formdev.flatlaf.FlatLightLaf", "setup", {})
    elsif equal(theme_name, "flatlaf-dark") or equal(theme_name, "dark") then
        java:call_static("com.formdev.flatlaf.FlatDarkLaf", "setup", {})
    elsif equal(theme_name, "gtk") then
        java:call_static("javax.swing.UIManager", "setLookAndFeel", {"com.sun.java.swing.plaf.gtk.GTKLookAndFeel"})
    elsif equal(theme_name, "nimbus") then
        java:call_static("javax.swing.UIManager", "setLookAndFeel", {"javax.swing.plaf.nimbus.NimbusLookAndFeel"})
    elsif equal(theme_name, "system") then
        object sys_laf = java:call_static("javax.swing.UIManager", "getSystemLookAndFeelClassName", {})
        if sequence(sys_laf) and length(sys_laf) > 0 then
            java:call_static("javax.swing.UIManager", "setLookAndFeel", {sys_laf})
        end if
    else
        java:call_static("javax.swing.UIManager", "setLookAndFeel", {theme_name})
    end if
end procedure

--**
-- Creates a top-level application window (JFrame).
--
-- Parameters:
--   # title: Title string displayed in the window bar
--   # width: Initial window width in pixels (default 600)
--   # height: Initial window height in pixels (default 400)
--   # on_close: Window close action (default CLOSE_ON_EXIT)
--
-- Returns:
--   Window handle (atom).
--
public function window(sequence title = "Euphoria", integer width = 600, integer height = 400, integer on_close = CLOSE_ON_EXIT)
    init_gui()
    atom frame = java:new_object("javax.swing.JFrame", {title})
    java:call_method(frame, "setSize", {width, height})
    java:call_method(frame, "setDefaultCloseOperation", {on_close})
    java:call_method(frame, "setLocationRelativeTo", {0}) -- Center on screen
    return frame
end function

--**
-- Shows a window or component on screen.
public procedure show(atom widget)
    java:call_method(widget, "setVisible", {1})
end procedure

--**
-- Hides a window or component.
public procedure hide(atom widget)
    java:call_method(widget, "setVisible", {0})
end procedure

--**
-- Destroys and disposes a window and releases its graphics resources.
public procedure close_window(atom widget)
    java:call_method(widget, "dispose", {})
end procedure

--**
-- Resizes window to fit the preferred size and layout of its subcomponents.
public procedure pack(atom win)
    java:call_method(win, "pack", {})
end procedure

--**
-- Creates a button widget.
--
-- Parameters:
--   # text: Text label on the button
--   # on_click_rid: Optional Euphoria routine_id called when button is pressed
--
-- Returns:
--   Button handle (atom).
--
public function button(sequence text, integer on_click_rid = -1)
    init_gui()
    atom btn = java:new_object("javax.swing.JButton", {text})
    if on_click_rid >= 0 then
        on_click(btn, on_click_rid)
    end if
    return btn
end function

--**
-- Attaches an on-click action listener to a button or interactive component.
public procedure on_click(atom widget, integer on_click_rid)
    atom listener = java:create_listener("java.awt.event.ActionListener", on_click_rid)
    if listener > 0 then
        java:call_method(widget, "addActionListener", {listener})
    end if
end procedure

--**
-- Creates a text label widget.
public function text_label(sequence text = "", integer align = ALIGN_LEFT)
    init_gui()
    return java:new_object("javax.swing.JLabel", {text, align})
end function

public function create_label(sequence text = "", integer align = ALIGN_LEFT)
    return text_label(text, align)
end function

--**
-- Creates a single-line text input field.
public function text_field(sequence initial_text = "", integer columns = 20)
    init_gui()
    return java:new_object("javax.swing.JTextField", {initial_text, columns})
end function

--**
-- Creates a multi-line text area.
public function text_area(sequence initial_text = "", integer rows = 10, integer cols = 30)
    init_gui()
    return java:new_object("javax.swing.JTextArea", {initial_text, rows, cols})
end function

--**
-- Wraps a component in a scroll pane with horizontal and vertical scrollbars.
public function scroll_pane(atom view_widget)
    init_gui()
    return java:new_object("javax.swing.JScrollPane", {view_widget})
end function

--**
-- Creates a checkbox.
public function check_box(sequence text, integer checked = 0, integer on_change_rid = -1)
    init_gui()
    atom cb = java:new_object("javax.swing.JCheckBox", {text, checked != 0})
    if on_change_rid >= 0 then
        on_click(cb, on_change_rid)
    end if
    return cb
end function

--**
-- Creates a radio button.
public function radio_button(sequence text, integer selected = 0)
    init_gui()
    return java:new_object("javax.swing.JRadioButton", {text, selected != 0})
end function

--**
-- Creates a dropdown selection combo box.
public function combo_box(sequence items = {})
    init_gui()
    atom cb = java:new_object("javax.swing.JComboBox", {})
    for i = 1 to length(items) do
        java:call_method(cb, "addItem", {items[i]})
    end for
    return cb
end function

--**
-- Creates an empty panel container.
public function panel(integer layout_type = FLOW_LAYOUT, integer rows = 0, integer cols = 0, integer hgap = 0, integer vgap = 0)
    init_gui()
    atom p = java:new_object("javax.swing.JPanel", {})
    set_layout(p, layout_type, rows, cols, hgap, vgap)
    return p
end function

--**
-- Creates a progress bar.
public function progress_bar(integer min_val = 0, integer max_val = 100)
    init_gui()
    atom pb = java:new_object("javax.swing.JProgressBar", {min_val, max_val})
    java:call_method(pb, "setStringPainted", {1})
    return pb
end function

--**
-- Creates a slider.
public function slider(integer min_val = 0, integer max_val = 100, integer init_val = 50)
    init_gui()
    return java:new_object("javax.swing.JSlider", {min_val, max_val, init_val})
end function

--**
-- Adds a child component into a container (window, panel).
--
-- Parameters:
--   # container: Parent container (window or panel)
--   # child: Component to add
--   # constraint: Layout constraint (e.g. NORTH, SOUTH, CENTER, or 0)
--
public procedure add(atom container, atom child, object constraint = 0)
    atom target = container
    object cp = java:call_method(container, "getContentPane", {})
    if atom(cp) and cp > 0 then
        target = cp
    end if
    if sequence(constraint) and length(constraint) > 0 then
        java:call_method(target, "add", {child, constraint})
    else
        java:call_method(target, "add", {child})
    end if
end procedure

--**
-- Sets the layout manager of a container.
public procedure set_layout(atom container, integer layout_type, integer rows = 0, integer cols = 0, integer hgap = 0, integer vgap = 0)
    atom target = container
    object cp = java:call_method(container, "getContentPane", {})
    if atom(cp) and cp > 0 then
        target = cp
    end if
    atom lay = 0
    if layout_type = BORDER_LAYOUT then
        if hgap > 0 or vgap > 0 then
            lay = java:new_object("java.awt.BorderLayout", {hgap, vgap})
        else
            lay = java:new_object("java.awt.BorderLayout", {})
        end if
    elsif layout_type = FLOW_LAYOUT then
        if hgap > 0 or vgap > 0 then
            lay = java:new_object("java.awt.FlowLayout", {1, hgap, vgap})
        else
            lay = java:new_object("java.awt.FlowLayout", {})
        end if
    elsif layout_type = GRID_LAYOUT then
        if hgap > 0 or vgap > 0 then
            lay = java:new_object("java.awt.GridLayout", {rows, cols, hgap, vgap})
        else
            lay = java:new_object("java.awt.GridLayout", {rows, cols})
        end if
    end if
    if lay > 0 then
        java:call_method(target, "setLayout", {lay})
    end if
end procedure

--**
-- Sets the text of a widget (label, button, text field, text area).
public procedure set_text(atom widget, sequence text)
    java:call_method(widget, "setText", {text})
end procedure

--**
-- Returns the text of a widget.
public function get_text(atom widget)
    object t = java:call_method(widget, "getText", {})
    if sequence(t) then return t end if
    return ""
end function

--**
-- Sets the integer value of a widget (slider, progress bar).
public procedure set_value(atom widget, integer val)
    java:call_method(widget, "setValue", {val})
end procedure

--**
-- Returns the integer value of a widget (slider, progress bar).
public function get_value(atom widget)
    return java:call_method(widget, "getValue", {})
end function

--**
-- Sets an empty border (padding) on a widget in pixels.
public procedure set_padding(atom widget, integer top, integer left, integer bottom, integer right)
    atom b = java:call_static("javax.swing.BorderFactory", "createEmptyBorder", {top, left, bottom, right})
    if b > 0 then
        java:call_method(widget, "setBorder", {b})
    end if
end procedure

--**
-- Sets the font of a widget.
public procedure set_font(atom widget, sequence name = "Ubuntu", integer size = 13, integer is_bold = 0)
    integer style = 0
    if is_bold then style = 1 end if
    atom f = java:new_object("java.awt.Font", {name, style, size})
    if f > 0 then
        java:call_method(widget, "setFont", {f})
    end if
end procedure

--**
-- Enables or disables a component.
public procedure set_enabled(atom widget, integer enabled)
    java:call_method(widget, "setEnabled", {enabled != 0})
end procedure

--**
-- Returns whether a checkbox or radio button is selected.
public function is_selected(atom widget)
    return java:call_method(widget, "isSelected", {}) != 0
end function

--**
-- Selects or deselects a checkbox or radio button.
public procedure set_selected(atom widget, integer sel)
    java:call_method(widget, "setSelected", {sel != 0})
end procedure

--**
-- Displays a modal informational/error message dialog.
public procedure msgbox(sequence title, sequence message, integer msg_type = MSG_INFO)
    init_gui()
    java:call_static("javax.swing.JOptionPane", "showMessageDialog", {0, message, title, msg_type})
end procedure

--**
-- Displays a modal text input dialog and returns the entered string (or "" on cancel).
public function input_box(sequence title, sequence message)
    init_gui()
    object res = java:call_static("javax.swing.JOptionPane", "showInputDialog", {0, message, title, MSG_QUESTION})
    if sequence(res) then return res end if
    return ""
end function

--**
-- Displays a modal YES/NO confirmation dialog. Returns 1 for YES, 0 for NO/Cancel.
public function confirm_box(sequence title, sequence message)
    init_gui()
    object res = java:call_static("javax.swing.JOptionPane", "showConfirmDialog", {0, message, title, 0})
    return res = 0
end function

--**
-- Displays a native file selection dialog.
--
-- Parameters:
--   # title: Dialog title string
--   # is_save: 1 for Save dialog, 0 for Open dialog
--   # cur_dir: Initial directory (optional)
--
-- Returns:
--   Absolute file path string, or "" if cancelled.
--
public function file_dialog(sequence title = "Datei auswählen", integer is_save = 0, sequence cur_dir = "")
    init_gui()
    atom fc = java:new_object("javax.swing.JFileChooser", {})
    java:call_method(fc, "setDialogTitle", {title})
    if length(cur_dir) > 0 then
        atom cur_file = java:new_object("java.io.File", {cur_dir})
        java:call_method(fc, "setCurrentDirectory", {cur_file})
    end if
    atom res = 0
    if is_save then
        res = java:call_method(fc, "showSaveDialog", {0})
    else
        res = java:call_method(fc, "showOpenDialog", {0})
    end if
    if res = 0 then -- APPROVE_OPTION = 0
        atom sel_file = java:call_method(fc, "getSelectedFile", {})
        if sel_file > 0 then
            object path = java:call_method(sel_file, "getAbsolutePath", {})
            if sequence(path) then return path end if
        end if
    end if
    return ""
end function

--**
-- Blocks execution until the specified window is closed.
public procedure wait_window(atom win)
    while java:call_method(win, "isDisplayable", {}) != 0 do
        os:sleep(0.05)
    end while
end procedure
