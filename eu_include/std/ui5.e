--****
-- == SAP UI5 Web Components Framework for Euphorix (std/ui5.e)
--
-- Powered by SAP UI5 Web Components (targeting version 2.29) and native
-- Euphorix HTTP Server & JSON engine.
--
-- Features:
-- * Zero Node.js / zero build-step: Pure OpenEuphoria syntax generating standardized
--   HTML5 Web Components (<ui5-shellbar>, <ui5-table>, <ui5-card>, <ui5-button>, etc.).
-- * Comprehensive component catalog: Buttons, Inputs, Steppers, Sliders, Rating,
--   Switches, Checkboxes, Radios, Selects, Comboboxes, Date/Time/Range Pickers,
--   ColorPicker, FileUploader, Tables, Lists, Trees, Tabs, Breadcrumbs, Bars,
--   Avatars, BusyIndicators, Timelines, IllustratedMessages, Forms, SideNav, etc.
-- * SAP Fiori Horizon ("sap_horizon" & "sap_horizon_dark") and Fiori 3 design themes.
-- * Full client-server reactivity with built-in Euphorix Bridge JS: Events (click, change)
--   are dispatched directly to Euphoria routine_id handlers and update the DOM
--   via `ui5:patch()`, `ui5:toast_show()`, `ui5:open_dialog()`, etc. without page reloads.
-- * Self-contained: Includes embedded CSS & native component enhancement for 100% reliable
--   offline and cross-browser styling (buttons, inputs, tables, badges, cards always visible).
--

namespace ui5

include std/http.e as http
include std/json.e as json
include std/text.e as text

-- =============================================================================
-- 1. Constants & Enums
-- =============================================================================

-- Default UI5 Web Components release stream (targeting 2.29)
public constant
    DEFAULT_VERSION = "2.29.0",
    DEFAULT_CDN_BASE = "https://cdn.jsdelivr.net/npm"

-- Design Themes
public constant
    THEME_HORIZON      = "sap_horizon",
    THEME_HORIZON_DARK = "sap_horizon_dark",
    THEME_HORIZON_HCB  = "sap_horizon_hcb",
    THEME_HORIZON_HCW  = "sap_horizon_hcw",
    THEME_FIORI_3      = "sap_fiori_3",
    THEME_FIORI_3_DARK = "sap_fiori_3_dark"

-- Button & Component Designs
public constant
    DESIGN_DEFAULT     = "Default",
    DESIGN_EMPHASIZED  = "Emphasized",
    DESIGN_POSITIVE    = "Positive",
    DESIGN_NEGATIVE    = "Negative",
    DESIGN_TRANSPARENT = "Transparent",
    DESIGN_ATTENTION   = "Attention"

-- Value States (Inputs, Badges, Status Indicators)
public constant
    STATE_NONE        = "None",
    STATE_SUCCESS     = "Success",
    STATE_WARNING     = "Warning",
    STATE_ERROR       = "Error",
    STATE_INFORMATION = "Information"

-- Title Levels
public constant
    TITLE_H1 = "H1",
    TITLE_H2 = "H2",
    TITLE_H3 = "H3",
    TITLE_H4 = "H4",
    TITLE_H5 = "H5",
    TITLE_H6 = "H6"

-- Avatar Shapes & Sizes
public constant
    AVATAR_CIRCLE = "Circle",
    AVATAR_SQUARE = "Square",
    AVATAR_XS     = "XS",
    AVATAR_S      = "S",
    AVATAR_M      = "M",
    AVATAR_L      = "L",
    AVATAR_XL     = "XL"

-- Bar Designs
public constant
    BAR_HEADER          = "Header",
    BAR_SUBHEADER       = "SubHeader",
    BAR_FOOTER          = "Footer",
    BAR_FLOATING_FOOTER = "FloatingFooter"

-- List Modes
public constant
    LIST_NONE          = "None",
    LIST_SINGLE_SELECT = "SingleSelect",
    LIST_MULTI_SELECT  = "MultiSelect",
    LIST_DELETE        = "Delete"

-- Link Designs
public constant
    LINK_DEFAULT    = "Default",
    LINK_SUBTLE     = "Subtle",
    LINK_EMPHASIZED = "Emphasized"

-- Busy Indicator Sizes
public constant
    BUSY_SMALL  = "Small",
    BUSY_MEDIUM = "Medium",
    BUSY_LARGE  = "Large"

-- Table Popin Modes
public constant
    POPIN_BLOCK  = "Block",
    POPIN_INLINE = "Inline"

-- Internal App Structure:
-- {title, port, theme, version, cdn_base, srv_id, pages_map, actions_map, running}
public constant
    APP_TITLE       = 1,
    APP_PORT        = 2,
    APP_THEME       = 3,
    APP_VERSION     = 4,
    APP_CDN_BASE    = 5,
    APP_SRV_ID      = 6,
    APP_PAGES       = 7,
    APP_ACTIONS     = 8,
    APP_RUNNING     = 9

-- Active app instances registry
sequence registered_apps = {}

-- =============================================================================
-- 2. Internal Utility Helpers & Icons
-- =============================================================================

function escape_html(sequence s)
    sequence out = ""
    for i = 1 to length(s) do
        integer c = s[i]
        if c = '&' then
            out &= "&amp;"
        elsif c = '<' then
            out &= "&lt;"
        elsif c = '>' then
            out &= "&gt;"
        elsif c = '"' then
            out &= "&quot;"
        elsif c = '\'' then
            out &= "&#39;"
        else
            out &= c
        end if
    end for
    return out
end function

function to_content_string(object item)
    if atom(item) then
        return sprintf("%d", item)
    end if
    -- Check if item is a sequence of characters (string)
    integer is_flat_str = 1
    for i = 1 to length(item) do
        if not integer(item[i]) then
            is_flat_str = 0
            exit
        end if
    end for
    if is_flat_str then
        return item
    end if
    -- Sequence of fragments / sub-components
    sequence res = ""
    for i = 1 to length(item) do
        res &= to_content_string(item[i])
    end for
    return res
end function

function get_opt(sequence opts, sequence key, sequence default_val = "")
    for i = 1 to length(opts) do
        if sequence(opts[i]) and length(opts[i]) >= 2 and equal(opts[i][1], key) then
            if sequence(opts[i][2]) then
                return opts[i][2]
            else
                return sprintf("%d", opts[i][2])
            end if
        end if
    end for
    return default_val
end function

function iff(integer cond, sequence true_val, sequence false_val)
    if cond then return true_val else return false_val end if
end function

function to_lower_ascii(sequence s)
    sequence out = s
    for i = 1 to length(out) do
        integer c = out[i]
        if c >= 'A' and c <= 'Z' then out[i] = c + 32 end if
    end for
    return out
end function

function get_icon_svg(sequence name)
    if equal(name, "add") then
        return "<svg width=\"14\" height=\"14\" viewBox=\"0 0 16 16\" fill=\"currentColor\"><path d=\"M8 2a1 1 0 0 1 1 1v4h4a1 1 0 1 1 0 2H9v4a1 1 0 1 1-2 0V9H3a1 1 0 0 1 0-2h4V3a1 1 0 0 1 1-1z\"/></svg>"
    elsif equal(name, "accept") then
        return "<svg width=\"14\" height=\"14\" viewBox=\"0 0 16 16\" fill=\"currentColor\"><path d=\"M13.7 4.3a1 1 0 0 1 0 1.4l-6.5 6.5a1 1 0 0 1-1.4 0L2.3 8.7a1 1 0 0 1 1.4-1.4L6.5 10.1l5.8-5.8a1 1 0 0 1 1.4 0z\"/></svg>"
    elsif equal(name, "delete") then
        return "<svg width=\"14\" height=\"14\" viewBox=\"0 0 16 16\" fill=\"currentColor\"><path d=\"M5.5 5.5A.5.5 0 0 1 6 6v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm2.5 0a.5.5 0 0 1 .5.5v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm3 .5a.5.5 0 0 0-1 0v6a.5.5 0 0 0 1 0V6z\"/><path fill-rule=\"evenodd\" d=\"M14.5 3a1 1 0 0 1-1 1H13v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V4h-.5a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1H6a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1h3.5a1 1 0 0 1 1 1v1zM4.118 4 4 4.059V13a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1V4.059L11.882 4H4.118zM2.5 3V2h11v1h-11z\"/></svg>"
    elsif equal(name, "edit") then
        return "<svg width=\"14\" height=\"14\" viewBox=\"0 0 16 16\" fill=\"currentColor\"><path d=\"M12.854.146a.5.5 0 0 0-.707 0L10.5 1.793 14.207 5.5l1.647-1.646a.5.5 0 0 0 0-.708l-3-3zm.646 6.061L9.793 2.5 3.293 9H3.5a.5.5 0 0 1 .5.5v.5h.5a.5.5 0 0 1 .5.5v.5h.5a.5.5 0 0 1 .5.5v.5h.5a.5.5 0 0 1 .5.5v.207l6.5-6.5zm-7.468 7.468A.5.5 0 0 1 6 13.5V13h-.5a.5.5 0 0 1-.5-.5V12h-.5a.5.5 0 0 1-.5-.5V11h-.5a.5.5 0 0 1-.5-.5V10h-.5a.499.499 0 0 1-.175-.032l-.179.178a.5.5 0 0 0-.11.168l-2 5a.5.5 0 0 0 .65.65l5-2a.5.5 0 0 0 .168-.11l.178-.178z\"/></svg>"
    elsif equal(name, "save") then
        return "<svg width=\"14\" height=\"14\" viewBox=\"0 0 16 16\" fill=\"currentColor\"><path d=\"M2 1a1 1 0 0 0-1 1v12a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V4.414a1 1 0 0 0-.293-.707l-2.414-2.414A1 1 0 0 0 11.586 1H2zm2 1h7v3H4V2zm8 12H4V8h8v6z\"/></svg>"
    elsif equal(name, "hint") then
        return "<svg width=\"14\" height=\"14\" viewBox=\"0 0 16 16\" fill=\"currentColor\"><path d=\"M8 15A7 7 0 1 1 8 1a7 7 0 0 1 0 14zm0 1A8 8 0 1 0 8 0a8 8 0 0 0 0 16z\"/><path d=\"m8.93 6.588-2.29.287-.082.38.45.083c.294.07.352.176.288.469l-.738 3.468c-.194.897.105 1.319.808 1.319.545 0 1.178-.252 1.465-.598l.088-.416c-.2.176-.492.246-.686.246-.275 0-.375-.193-.304-.533L8.93 6.588zM9 4.5a1 1 0 1 1-2 0 1 1 0 0 1 2 0z\"/></svg>"
    elsif equal(name, "upload") then
        return "<svg width=\"14\" height=\"14\" viewBox=\"0 0 16 16\" fill=\"currentColor\"><path d=\"M.5 9.9a.5.5 0 0 1 .5.5v2.5a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-2.5a.5.5 0 0 1 1 0v2.5a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2v-2.5a.5.5 0 0 1 .5-.5z\"/><path d=\"M7.646 1.146a.5.5 0 0 1 .708 0l3 3a.5.5 0 0 1-.708.708L8.5 2.707V10.5a.5.5 0 0 1-1 0V2.707L5.354 4.854a.5.5 0 1 1-.708-.708l3-3z\"/></svg>"
    elsif equal(name, "download") then
        return "<svg width=\"14\" height=\"14\" viewBox=\"0 0 16 16\" fill=\"currentColor\"><path d=\"M.5 9.9a.5.5 0 0 1 .5.5v2.5a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-2.5a.5.5 0 0 1 1 0v2.5a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2v-2.5a.5.5 0 0 1 .5-.5z\"/><path d=\"M7.646 11.854a.5.5 0 0 0 .708 0l3-3a.5.5 0 0 0-.708-.708L8.5 10.293V1.5a.5.5 0 0 0-1 0v8.793L5.354 8.146a.5.5 0 1 0-.708.708l3 3z\"/></svg>"
    elsif equal(name, "refresh") then
        return "<svg width=\"14\" height=\"14\" viewBox=\"0 0 16 16\" fill=\"currentColor\"><path fill-rule=\"evenodd\" d=\"M8 3a5 5 0 1 0 4.546 2.914.5.5 0 0 1 .908-.417A6 6 0 1 1 8 2v1z\"/><path d=\"M8 4.466V.534a.25.25 0 0 1 .41-.192l2.36 1.966c.12.1.12.284 0 .384L8.41 4.658A.25.25 0 0 1 8 4.466z\"/></svg>"
    elsif equal(name, "search") then
        return "<svg width=\"14\" height=\"14\" viewBox=\"0 0 16 16\" fill=\"currentColor\"><path d=\"M11.742 10.344a6.5 6.5 0 1 0-1.397 1.398h-.001c.03.04.062.078.098.115l3.85 3.85a1 1 0 0 0 1.415-1.414l-3.85-3.85a1.007 1.007 0 0 0-.115-.1zM12 6.5a5.5 5.5 0 1 1-11 0 5.5 5.5 0 0 1 11 0z\"/></svg>"
    elsif equal(name, "filter") then
        return "<svg width=\"14\" height=\"14\" viewBox=\"0 0 16 16\" fill=\"currentColor\"><path d=\"M6 10.5a.5.5 0 0 1 .5-.5h3a.5.5 0 0 1 0 1h-3a.5.5 0 0 1-.5-.5zm-2-3a.5.5 0 0 1 .5-.5h7a.5.5 0 0 1 0 1h-7a.5.5 0 0 1-.5-.5zm-2-3a.5.5 0 0 1 .5-.5h11a.5.5 0 0 1 0 1h-11a.5.5 0 0 1-.5-.5z\"/></svg>"
    elsif equal(name, "lead-forecast") then
        return "<svg width=\"16\" height=\"16\" viewBox=\"0 0 16 16\" fill=\"currentColor\"><path d=\"M1 11a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v3a1 1 0 0 1-1 1H2a1 1 0 0 1-1-1v-3zm5-4a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v7a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V7zm5-5a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1h-2a1 1 0 0 1-1-1V2z\"/></svg>"
    elsif equal(name, "create-form") then
        return "<svg width=\"16\" height=\"16\" viewBox=\"0 0 16 16\" fill=\"currentColor\"><path d=\"M14 1a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H2a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1h12zM2 0a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V2a2 2 0 0 0-2-2H2z\"/><path d=\"M4 4h8v2H4V4zm0 3h8v2H4V7zm0 3h5v2H4v-2z\"/></svg>"
    elsif equal(name, "activity-items") then
        return "<svg width=\"16\" height=\"16\" viewBox=\"0 0 16 16\" fill=\"currentColor\"><path d=\"M0 2a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2V2zm15 2h-14v10a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V4zm-14-1h14V2a1 1 0 0 0-1-1H2a1 1 0 0 0-1 1v1z\"/><path d=\"M3 6.5a.5.5 0 0 1 .5-.5h9a.5.5 0 0 1 0 1h-9a.5.5 0 0 1-.5-.5zm0 3a.5.5 0 0 1 .5-.5h9a.5.5 0 0 1 0 1h-9a.5.5 0 0 1-.5-.5zm0 3a.5.5 0 0 1 .5-.5h5a.5.5 0 0 1 0 1h-5a.5.5 0 0 1-.5-.5z\"/></svg>"
    elsif equal(name, "sys-enter-2") then
        return "<svg width=\"16\" height=\"16\" viewBox=\"0 0 16 16\" fill=\"#107e3e\"><path d=\"M16 8A8 8 0 1 1 0 8a8 8 0 0 1 16 0zm-3.97-3.03a.75.75 0 0 0-1.08.022L7.477 9.417 5.384 7.323a.75.75 0 0 0-1.06 1.06L6.97 11.03a.75.75 0 0 0 1.079-.02l3.992-4.99a.75.75 0 0 0-.01-1.05z\"/></svg>"
    else
        return "<svg width=\"14\" height=\"14\" viewBox=\"0 0 16 16\" fill=\"currentColor\"><circle cx=\"8\" cy=\"8\" r=\"4\"/></svg>"
    end if
end function

-- =============================================================================
-- 3. UI5 Bridge Runtime JS & Comprehensive Horizon CSS
-- =============================================================================

function get_bridge_javascript()
    return `<script>
(function() {
  var svgIcons = {
    add: '<svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor"><path d="M8 2a1 1 0 0 1 1 1v4h4a1 1 0 1 1 0 2H9v4a1 1 0 1 1-2 0V9H3a1 1 0 0 1 0-2h4V3a1 1 0 0 1 1-1z"/></svg>',
    accept: '<svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor"><path d="M13.7 4.3a1 1 0 0 1 0 1.4l-6.5 6.5a1 1 0 0 1-1.4 0L2.3 8.7a1 1 0 0 1 1.4-1.4L6.5 10.1l5.8-5.8a1 1 0 0 1 1.4 0z"/></svg>',
    delete: '<svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor"><path d="M5.5 5.5A.5.5 0 0 1 6 6v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm2.5 0a.5.5 0 0 1 .5.5v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm3 .5a.5.5 0 0 0-1 0v6a.5.5 0 0 0 1 0V6z"/><path fill-rule="evenodd" d="M14.5 3a1 1 0 0 1-1 1H13v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V4h-.5a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1H6a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1h3.5a1 1 0 0 1 1 1v1zM4.118 4 4 4.059V13a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1V4.059L11.882 4H4.118zM2.5 3V2h11v1h-11z"/></svg>',
    edit: '<svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor"><path d="M12.854.146a.5.5 0 0 0-.707 0L10.5 1.793 14.207 5.5l1.647-1.646a.5.5 0 0 0 0-.708l-3-3zm.646 6.061L9.793 2.5 3.293 9H3.5a.5.5 0 0 1 .5.5v.5h.5a.5.5 0 0 1 .5.5v.5h.5a.5.5 0 0 1 .5.5v.5h.5a.5.5 0 0 1 .5.5v.207l6.5-6.5zm-7.468 7.468A.5.5 0 0 1 6 13.5V13h-.5a.5.5 0 0 1-.5-.5V12h-.5a.5.5 0 0 1-.5-.5V11h-.5a.5.5 0 0 1-.5-.5V10h-.5a.499.499 0 0 1-.175-.032l-.179.178a.5.5 0 0 0-.11.168l-2 5a.5.5 0 0 0 .65.65l5-2a.5.5 0 0 0 .168-.11l.178-.178z"/></svg>',
    save: '<svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor"><path d="M2 1a1 1 0 0 0-1 1v12a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V4.414a1 1 0 0 0-.293-.707l-2.414-2.414A1 1 0 0 0 11.586 1H2zm2 1h7v3H4V2zm8 12H4V8h8v6z"/></svg>',
    hint: '<svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor"><path d="M8 15A7 7 0 1 1 8 1a7 7 0 0 1 0 14zm0 1A8 8 0 1 0 8 0a8 8 0 0 0 0 16z"/><path d="m8.93 6.588-2.29.287-.082.38.45.083c.294.07.352.176.288.469l-.738 3.468c-.194.897.105 1.319.808 1.319.545 0 1.178-.252 1.465-.598l.088-.416c-.2.176-.492.246-.686.246-.275 0-.375-.193-.304-.533L8.93 6.588zM9 4.5a1 1 0 1 1-2 0 1 1 0 0 1 2 0z"/></svg>',
    upload: '<svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor"><path d="M.5 9.9a.5.5 0 0 1 .5.5v2.5a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-2.5a.5.5 0 0 1 1 0v2.5a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2v-2.5a.5.5 0 0 1 .5-.5z"/><path d="M7.646 1.146a.5.5 0 0 1 .708 0l3 3a.5.5 0 0 1-.708.708L8.5 2.707V10.5a.5.5 0 0 1-1 0V2.707L5.354 4.854a.5.5 0 1 1-.708-.708l3-3z"/></svg>',
    refresh: '<svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor"><path fill-rule="evenodd" d="M8 3a5 5 0 1 0 4.546 2.914.5.5 0 0 1 .908-.417A6 6 0 1 1 8 2v1z"/><path d="M8 4.466V.534a.25.25 0 0 1 .41-.192l2.36 1.966c.12.1.12.284 0 .384L8.41 4.658A.25.25 0 0 1 8 4.466z"/></svg>',
    search: '<svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor"><path d="M11.742 10.344a6.5 6.5 0 1 0-1.397 1.398h-.001c.03.04.062.078.098.115l3.85 3.85a1 1 0 0 0 1.415-1.414l-3.85-3.85a1.007 1.007 0 0 0-.115-.1zM12 6.5a5.5 5.5 0 1 1-11 0 5.5 5.5 0 0 1 11 0z"/></svg>',
    filter: '<svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor"><path d="M6 10.5a.5.5 0 0 1 .5-.5h3a.5.5 0 0 1 0 1h-3a.5.5 0 0 1-.5-.5zm-2-3a.5.5 0 0 1 .5-.5h7a.5.5 0 0 1 0 1h-7a.5.5 0 0 1-.5-.5zm-2-3a.5.5 0 0 1 .5-.5h11a.5.5 0 0 1 0 1h-11a.5.5 0 0 1-.5-.5z"/></svg>',
    "lead-forecast": '<svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor"><path d="M1 11a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v3a1 1 0 0 1-1 1H2a1 1 0 0 1-1-1v-3zm5-4a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v7a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V7zm5-5a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1h-2a1 1 0 0 1-1-1V2z"/></svg>',
    "create-form": '<svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor"><path d="M14 1a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H2a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1h12zM2 0a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V2a2 2 0 0 0-2-2H2z"/><path d="M4 4h8v2H4V4zm0 3h8v2H4V7zm0 3h5v2H4v-2z"/></svg>',
    "activity-items": '<svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor"><path d="M0 2a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2V2zm15 2h-14v10a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V4zm-14-1h14V2a1 1 0 0 0-1-1H2a1 1 0 0 0-1 1v1z"/><path d="M3 6.5a.5.5 0 0 1 .5-.5h9a.5.5 0 0 1 0 1h-9a.5.5 0 0 1-.5-.5zm0 3a.5.5 0 0 1 .5-.5h9a.5.5 0 0 1 0 1h-9a.5.5 0 0 1-.5-.5zm0 3a.5.5 0 0 1 .5-.5h5a.5.5 0 0 1 0 1h-5a.5.5 0 0 1-.5-.5z"/></svg>',
    "sys-enter-2": '<svg width="16" height="16" viewBox="0 0 16 16" fill="#107e3e"><path d="M16 8A8 8 0 1 1 0 8a8 8 0 0 1 16 0zm-3.97-3.03a.75.75 0 0 0-1.08.022L7.477 9.417 5.384 7.323a.75.75 0 0 0-1.06 1.06L6.97 11.03a.75.75 0 0 0 1.079-.02l3.992-4.99a.75.75 0 0 0-.01-1.05z"/></svg>'
  };

  function getSvg(name) {
    return svgIcons[name] || '<svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor"><circle cx="8" cy="8" r="4"/></svg>';
  }

  // Enhance custom elements so fields and buttons are immediately visible
  // and interactive in all browsers, offline and online without waiting for CDN.
  function enhanceUI5() {
    // 1. Inputs
    document.querySelectorAll('ui5-input').forEach(function(el) {
      if (!el.querySelector('input') && !el.shadowRoot) {
        var inp = document.createElement('input');
        inp.type = (el.getAttribute('type') || 'text').toLowerCase();
        inp.className = 'ui5-native-input';
        inp.value = el.getAttribute('value') || '';
        inp.placeholder = el.getAttribute('placeholder') || '';
        if (el.hasAttribute('readonly')) inp.readOnly = true;
        inp.addEventListener('input', function() { el.setAttribute('value', inp.value); });
        el.appendChild(inp);
      }
    });

    // 2. Step Inputs
    document.querySelectorAll('ui5-step-input').forEach(function(el) {
      if (!el.querySelector('.ui5-step-inner') && !el.shadowRoot) {
        var val = parseFloat(el.getAttribute('value') || '0');
        var min = el.hasAttribute('min') ? parseFloat(el.getAttribute('min')) : -Infinity;
        var max = el.hasAttribute('max') ? parseFloat(el.getAttribute('max')) : Infinity;
        var step = el.hasAttribute('step') ? parseFloat(el.getAttribute('step')) : 1;
        var wrap = document.createElement('div');
        wrap.className = 'ui5-step-inner';
        wrap.style.display = 'inline-flex';
        wrap.style.alignItems = 'center';
        wrap.style.width = '100%';

        var btnDec = document.createElement('button');
        btnDec.type = 'button';
        btnDec.className = 'ui5-step-btn';
        btnDec.textContent = '-';

        var inp = document.createElement('input');
        inp.type = 'number';
        inp.className = 'ui5-native-input';
        inp.style.textAlign = 'center';
        inp.value = val;

        var btnInc = document.createElement('button');
        btnInc.type = 'button';
        btnInc.className = 'ui5-step-btn';
        btnInc.textContent = '+';

        btnDec.addEventListener('click', function(e) {
          e.stopPropagation();
          var v = parseFloat(inp.value) - step;
          if (v >= min) { inp.value = v; el.setAttribute('value', v); }
        });
        btnInc.addEventListener('click', function(e) {
          e.stopPropagation();
          var v = parseFloat(inp.value) + step;
          if (v <= max) { inp.value = v; el.setAttribute('value', v); }
        });
        inp.addEventListener('input', function() { el.setAttribute('value', inp.value); });

        wrap.appendChild(btnDec);
        wrap.appendChild(inp);
        wrap.appendChild(btnInc);
        el.appendChild(wrap);
      }
    });

    // 3. Sliders
    document.querySelectorAll('ui5-slider').forEach(function(el) {
      if (!el.querySelector('input[type="range"]') && !el.shadowRoot) {
        var inp = document.createElement('input');
        inp.type = 'range';
        inp.className = 'ui5-native-range';
        inp.min = el.getAttribute('min') || '0';
        inp.max = el.getAttribute('max') || '100';
        inp.step = el.getAttribute('step') || '1';
        inp.value = el.getAttribute('value') || '0';
        inp.style.width = '100%';
        inp.addEventListener('input', function() { el.setAttribute('value', inp.value); });
        el.appendChild(inp);
      }
    });

    // 4. Rating Indicator
    document.querySelectorAll('ui5-rating-indicator').forEach(function(el) {
      if (!el.querySelector('.ui5-rating-star') && !el.shadowRoot) {
        var max = parseInt(el.getAttribute('max') || '5');
        var val = parseFloat(el.getAttribute('value') || '0');
        el.innerHTML = '';
        for (var i = 1; i <= max; i++) {
          var star = document.createElement('span');
          star.className = 'ui5-rating-star' + (i <= val ? ' active' : '');
          star.setAttribute('data-val', i);
          star.textContent = i <= val ? '★' : '☆';
          star.addEventListener('click', function(e) {
            e.stopPropagation();
            var newVal = this.getAttribute('data-val');
            el.setAttribute('value', newVal);
            enhanceUI5();
          });
          el.appendChild(star);
        }
      }
    });

    // 5. Radio Buttons
    document.querySelectorAll('ui5-radio-button').forEach(function(el) {
      if (!el.querySelector('input[type="radio"]') && !el.shadowRoot) {
        var name = el.getAttribute('name') || '';
        var text = el.getAttribute('text') || '';
        var val = el.getAttribute('value') || '';
        var chk = el.hasAttribute('checked');
        var lbl = document.createElement('label');
        lbl.style.display = 'inline-flex';
        lbl.style.alignItems = 'center';
        lbl.style.gap = '0.4rem';
        lbl.style.cursor = 'pointer';
        var r = document.createElement('input');
        r.type = 'radio';
        r.name = name;
        r.value = val;
        r.checked = chk;
        r.addEventListener('change', function() {
          document.querySelectorAll('ui5-radio-button[name="' + name + '"]').forEach(function(other) {
            other.removeAttribute('checked');
          });
          if (r.checked) el.setAttribute('checked', '');
        });
        lbl.appendChild(r);
        lbl.appendChild(document.createTextNode(text));
        el.appendChild(lbl);
      }
    });

    // 6. Selects
    document.querySelectorAll('ui5-select').forEach(function(el) {
      if (!el.querySelector('select') && !el.shadowRoot) {
        var sel = document.createElement('select');
        sel.className = 'ui5-native-select';
        el.querySelectorAll('ui5-option').forEach(function(opt) {
          var o = document.createElement('option');
          o.value = opt.getAttribute('value') || '';
          o.textContent = opt.textContent;
          if (opt.hasAttribute('selected')) o.selected = true;
          sel.appendChild(o);
        });
        sel.addEventListener('change', function() { el.setAttribute('value', sel.value); });
        el.appendChild(sel);
      }
    });

    // 7. Comboboxes
    document.querySelectorAll('ui5-combobox').forEach(function(el) {
      if (!el.querySelector('input') && !el.shadowRoot) {
        var dlId = 'dl_' + Math.random().toString(36).substr(2, 9);
        var inp = document.createElement('input');
        inp.className = 'ui5-native-input';
        inp.setAttribute('list', dlId);
        inp.value = el.getAttribute('value') || '';
        inp.placeholder = el.getAttribute('placeholder') || '';
        var dl = document.createElement('datalist');
        dl.id = dlId;
        el.querySelectorAll('ui5-cb-item').forEach(function(item) {
          var opt = document.createElement('option');
          opt.value = item.getAttribute('text') || '';
          dl.appendChild(opt);
        });
        inp.addEventListener('input', function() { el.setAttribute('value', inp.value); });
        el.appendChild(inp);
        el.appendChild(dl);
      }
    });

    // 8. DatePickers & TimePickers
    document.querySelectorAll('ui5-datepicker').forEach(function(el) {
      if (!el.querySelector('input') && !el.shadowRoot) {
        var inp = document.createElement('input');
        inp.type = 'date';
        inp.className = 'ui5-native-date';
        inp.value = el.getAttribute('value') || '';
        inp.addEventListener('input', function() { el.setAttribute('value', inp.value); });
        el.appendChild(inp);
      }
    });
    document.querySelectorAll('ui5-time-picker').forEach(function(el) {
      if (!el.querySelector('input') && !el.shadowRoot) {
        var inp = document.createElement('input');
        inp.type = 'time';
        inp.className = 'ui5-native-input';
        inp.value = el.getAttribute('value') || '';
        inp.addEventListener('input', function() { el.setAttribute('value', inp.value); });
        el.appendChild(inp);
      }
    });
    document.querySelectorAll('ui5-datetime-picker').forEach(function(el) {
      if (!el.querySelector('input') && !el.shadowRoot) {
        var inp = document.createElement('input');
        inp.type = 'datetime-local';
        inp.className = 'ui5-native-input';
        inp.value = el.getAttribute('value') || '';
        inp.addEventListener('input', function() { el.setAttribute('value', inp.value); });
        el.appendChild(inp);
      }
    });

    // 9. Buttons (attach icon if specified)
    document.querySelectorAll('ui5-button, ui5-toggle-button, ui5-menu-button').forEach(function(el) {
      var iconName = el.getAttribute('icon');
      if (iconName && !el.querySelector('.ui5-btn-icon') && !el.shadowRoot) {
        var span = document.createElement('span');
        span.className = 'ui5-btn-icon';
        span.style.display = 'inline-flex';
        span.style.alignItems = 'center';
        span.style.marginRight = '0.4rem';
        span.innerHTML = getSvg(iconName);
        el.insertBefore(span, el.firstChild);
      }
    });

    // 10. Segmented Buttons
    document.querySelectorAll('ui5-segmented-button').forEach(function(el) {
      el.querySelectorAll('ui5-segmented-button-item').forEach(function(item) {
        item.onclick = function() {
          el.querySelectorAll('ui5-segmented-button-item').forEach(function(i) { i.removeAttribute('selected'); });
          item.setAttribute('selected', '');
          el.setAttribute('value', item.getAttribute('id') || item.textContent);
        };
      });
    });

    // 11. TabContainers
    document.querySelectorAll('ui5-tabcontainer').forEach(function(el) {
      if (!el.querySelector('.ui5-tab-strip') && !el.shadowRoot) {
        var tabs = el.querySelectorAll('ui5-tab');
        if (tabs.length > 0) {
          var strip = document.createElement('div');
          strip.className = 'ui5-tab-strip';
          tabs.forEach(function(tab, idx) {
            var btn = document.createElement('div');
            btn.className = 'ui5-tab-btn' + (tab.hasAttribute('selected') || idx === 0 ? ' active' : '');
            btn.textContent = tab.getAttribute('text') || ('Tab ' + (idx + 1));
            btn.onclick = function() {
              strip.querySelectorAll('.ui5-tab-btn').forEach(function(b) { b.classList.remove('active'); });
              btn.classList.add('active');
              tabs.forEach(function(t) { t.style.display = 'none'; t.removeAttribute('selected'); });
              tab.style.display = 'block';
              tab.setAttribute('selected', '');
            };
            strip.appendChild(btn);
            tab.style.display = (tab.hasAttribute('selected') || idx === 0) ? 'block' : 'none';
          });
          el.insertBefore(strip, el.firstChild);
        }
      }
    });

    // 12. ShellBar
    document.querySelectorAll('ui5-shellbar').forEach(function(el) {
      if (!el.querySelector('.ui5-shellbar-inner') && !el.shadowRoot) {
        var pTitle = el.getAttribute('primary-title') || '';
        var sTitle = el.getAttribute('secondary-title') || '';
        var initials = el.getAttribute('initials') || '';
        var hasNotif = el.hasAttribute('show-notifications');
        var html = '<div class="ui5-shellbar-inner" style="display:flex; justify-content:space-between; align-items:center; width:100%;">';
        html += '<div style="display:flex; align-items:center;">';
        html += '<span class="ui5-shellbar-title">' + pTitle + '</span>';
        if (sTitle) html += '<span class="ui5-shellbar-subtitle">' + sTitle + '</span>';
        html += '</div><div style="display:flex; align-items:center; gap:0.75rem;">';
        if (hasNotif) html += '<span style="color:#8da2b5; cursor:pointer;" title="Notifications">' + getSvg('hint') + '</span>';
        if (initials) html += '<div class="ui5-shellbar-avatar">' + initials + '</div>';
        html += '</div></div>';
        el.innerHTML = html;
      }
    });

    // 13. Card Header
    document.querySelectorAll('ui5-card-header').forEach(function(el) {
      if (!el.querySelector('.ui5-card-header-inner') && !el.shadowRoot) {
        var title = el.getAttribute('title-text') || '';
        var sub = el.getAttribute('subtitle-text') || '';
        var stat = el.getAttribute('status') || '';
        var icon = el.querySelector('ui5-icon[slot="avatar"]');
        var iconName = icon ? icon.getAttribute('name') : '';
        var h = '<div class="ui5-card-header-inner" style="display:flex; align-items:center; justify-content:space-between; width:100%;">';
        h += '<div style="display:flex; align-items:center; gap:0.75rem;">';
        if (iconName) h += '<span style="color:#0070f2; font-size:1.25rem; display:inline-flex;">' + getSvg(iconName) + '</span>';
        h += '<div><div class="ui5-card-title">' + title + '</div>';
        if (sub) h += '<div class="ui5-card-subtitle">' + sub + '</div>';
        h += '</div></div>';
        if (stat) h += '<span class="ui5-card-status">' + stat + '</span>';
        h += '</div>';
        el.innerHTML = h;
      }
    });

    // 14. Progress Indicator
    document.querySelectorAll('ui5-progress-indicator').forEach(function(el) {
      if (!el.querySelector('.ui5-progress-bar') && !el.shadowRoot) {
        var val = el.getAttribute('value') || '0';
        var txt = el.getAttribute('display-value') || (val + '%');
        el.innerHTML = '<div class="ui5-progress-bar" style="width:' + val + '%;"></div><span class="ui5-progress-label">' + txt + '</span>';
      }
    });

    // 15. Dialog layout
    document.querySelectorAll('ui5-dialog').forEach(function(el) {
      if (!el.querySelector('.ui5-dialog-modal') && !el.shadowRoot) {
        var hText = el.getAttribute('header-text') || '';
        var footer = el.querySelector('[slot="footer"]');
        var fHtml = footer ? footer.innerHTML : '';
        if (footer) footer.remove();
        var bodyHtml = el.innerHTML;
        var modal = '<div class="ui5-dialog-modal">';
        modal += '<div class="ui5-dialog-header">' + hText + '</div>';
        modal += '<div class="ui5-dialog-body">' + bodyHtml + '</div>';
        if (fHtml) modal += '<div class="ui5-dialog-footer">' + fHtml + '</div>';
        modal += '</div>';
        el.innerHTML = modal;
      }
    });
  }

  window.euphorixUI5 = {
    enhance: enhanceUI5,
    triggerAction: function(actionName, extraParams) {
      var data = Object.assign({}, extraParams || {});
      // 1. Inputs
      document.querySelectorAll('ui5-input, ui5-step-input, ui5-slider, ui5-rating-indicator').forEach(function(el) {
        var id = el.id;
        if (id) {
          var inp = el.querySelector('input');
          data[id] = inp ? inp.value : (el.value || el.getAttribute('value') || '');
        }
      });
      // 2. Selects
      document.querySelectorAll('ui5-select').forEach(function(el) {
        var id = el.id;
        if (id) {
          var sel = el.querySelector('select');
          data[id] = sel ? sel.value : (el.value || el.getAttribute('value') || '');
        }
      });
      // 3. DatePickers & TimePickers
      document.querySelectorAll('ui5-datepicker, ui5-time-picker, ui5-datetime-picker, ui5-combobox').forEach(function(el) {
        var id = el.id;
        if (id) {
          var inp = el.querySelector('input');
          data[id] = inp ? inp.value : (el.value || el.getAttribute('value') || '');
        }
      });
      // 4. Textareas
      document.querySelectorAll('ui5-textarea').forEach(function(el) {
        var id = el.id;
        if (id) {
          var txt = el.querySelector('textarea');
          data[id] = txt ? txt.value : (el.value || el.textContent || '');
        }
      });
      // 5. Switches & Checkboxes & Radios
      document.querySelectorAll('ui5-switch, ui5-checkbox, ui5-radio-button').forEach(function(el) {
        var id = el.id;
        if (id) {
          var chk = el.querySelector('input[type="checkbox"], input[type="radio"]');
          data[id] = chk ? (chk.checked ? '1' : '0') : (el.hasAttribute('checked') ? '1' : '0');
        }
      });
      // 6. Segmented Buttons
      document.querySelectorAll('ui5-segmented-button').forEach(function(el) {
        var id = el.id;
        if (id) {
          var sel = el.querySelector('ui5-segmented-button-item[selected]');
          data[id] = sel ? (sel.id || sel.textContent) : (el.getAttribute('value') || '');
        }
      });

      fetch('/__ui5_action', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=utf-8' },
        body: JSON.stringify({ action: actionName, values: data })
      })
      .then(function(res) { return res.json(); })
      .then(function(patches) {
        if (!Array.isArray(patches)) patches = [patches];
        patches.forEach(function(p) {
          if (!p || !p.type) return;
          if (p.type === 'patch') {
            var target = document.getElementById(p.id);
            if (target) {
              target.innerHTML = p.html;
              enhanceUI5();
            }
          } else if (p.type === 'append') {
            var target = document.getElementById(p.id);
            if (target) {
              target.insertAdjacentHTML('beforeend', p.html);
              enhanceUI5();
            }
          } else if (p.type === 'setValue') {
            var target = document.getElementById(p.id);
            if (target) {
              target.setAttribute('value', p.val);
              var inp = target.querySelector('input, select, textarea');
              if (inp) inp.value = p.val;
            }
          } else if (p.type === 'setValueState') {
            var target = document.getElementById(p.id);
            if (target) {
              target.setAttribute('value-state', p.state);
              var msg = target.querySelector('.ui5-val-state-msg');
              if (p.message) {
                if (!msg) {
                  msg = document.createElement('div');
                  msg.className = 'ui5-val-state-msg';
                  target.appendChild(msg);
                }
                msg.textContent = p.message;
              } else if (msg) {
                msg.remove();
              }
            }
          } else if (p.type === 'toast') {
            var t = document.getElementById(p.id);
            if (t) {
              if (p.text) t.textContent = p.text;
              t.classList.add('ui5-toast-show');
              setTimeout(function() { t.classList.remove('ui5-toast-show'); }, parseInt(t.getAttribute('duration') || '3000'));
            }
          } else if (p.type === 'dialogOpen') {
            var d = document.getElementById(p.id);
            if (d) d.classList.add('ui5-dialog-open');
          } else if (p.type === 'dialogClose') {
            var d = document.getElementById(p.id);
            if (d) d.classList.remove('ui5-dialog-open');
          } else if (p.type === 'redirect') {
            window.location.href = p.url;
          }
        });
      })
      .catch(function(err) { console.error('Euphorix UI5 Bridge Error:', err); });
    }
  };

  document.addEventListener('click', function(e) {
    var btn = e.target.closest('[data-ui5-action]');
    if (btn) {
      var act = btn.getAttribute('data-ui5-action');
      var params = {};
      for (var i = 0; i < btn.attributes.length; i++) {
        var a = btn.attributes[i];
        if (a.name.indexOf('data-param-') === 0) {
          params[a.name.substring(11)] = a.value;
        }
      }
      window.euphorixUI5.triggerAction(act, params);
    }
    var closeBtn = e.target.closest('[data-ui5-close]');
    if (closeBtn) {
      var dlgId = closeBtn.getAttribute('data-ui5-close');
      var d = document.getElementById(dlgId);
      if (d) d.classList.remove('ui5-dialog-open');
    }
  });

  // Run initial enhancement
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', enhanceUI5);
  } else {
    enhanceUI5();
  }
})();
</script>`
end function

function get_horizon_base_css(sequence theme)
    sequence bg_color = "#f5f6f7"
    sequence text_color = "#1d2d3e"
    sequence card_bg = "#ffffff"
    sequence border_color = "#d9e0e7"
    sequence primary_color = "#0070f2"

    if equal(theme, THEME_HORIZON_DARK) then
        bg_color = "#12171c"
        text_color = "#eaecee"
        card_bg = "#1d232a"
        border_color = "#2e3842"
    end if

    return sprintf(`<style>
  :root {
    --sapBackgroundColor: %s;
    --sapTextColor: %s;
    --sapCardBackground: %s;
    --sapBorderColor: %s;
    --sapHighlightColor: %s;
    --sapFontFamily: "72", "Open Sans", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
    --sapButtonHeight: 2.25rem;
    --sapBorderRadius: 0.5rem;
  }
  html, body {
    margin: 0;
    padding: 0;
    background-color: var(--sapBackgroundColor);
    color: var(--sapTextColor);
    font-family: var(--sapFontFamily);
    font-size: 14px;
    line-height: 1.5;
    min-height: 100vh;
    -webkit-font-smoothing: antialiased;
  }
  .ui5-content-padding {
    padding: 1.5rem 2rem;
    max-width: 1400px;
    margin: 0 auto;
  }
  .ui5-card-margin {
    margin-bottom: 1.5rem;
  }
  .ui5-flex-row {
    display: flex;
    flex-direction: row;
    align-items: center;
    gap: 0.75rem;
    flex-wrap: wrap;
  }
  .ui5-grid-2 {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(360px, 1fr));
    gap: 1.5rem;
  }
  .ui5-grid-3 {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 1.25rem;
  }

  /* Typography & Titles */
  ui5-title {
    display: block;
    font-family: inherit;
    font-weight: 700;
    color: #1d2d3e;
    margin: 0 0 0.5rem 0;
  }
  ui5-title[level="H1"] { font-size: 1.75rem; }
  ui5-title[level="H2"] { font-size: 1.35rem; }
  ui5-title[level="H3"] { font-size: 1.15rem; }
  ui5-title[level="H4"] { font-size: 1rem; }
  ui5-label {
    display: inline-flex;
    align-items: center;
    font-size: 0.875rem;
    font-weight: 600;
    color: #556b82;
    margin-bottom: 0.25rem;
  }
  ui5-label[required]::after {
    content: " *";
    color: #b00;
  }
  ui5-link {
    color: #0070f2;
    text-decoration: none;
    cursor: pointer;
    font-weight: 500;
    font-size: 0.875rem;
  }
  ui5-link:hover { text-decoration: underline; }
  ui5-text {
    display: inline-block;
    color: #1d2d3e;
    font-size: 0.875rem;
    line-height: 1.5;
  }

  /* ShellBar */
  ui5-shellbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: #1d2d3e;
    color: #ffffff;
    height: 3.25rem;
    padding: 0 1.5rem;
    box-shadow: 0 2px 6px rgba(0,0,0,0.2);
    position: sticky;
    top: 0;
    z-index: 100;
    box-sizing: border-box;
  }
  .ui5-shellbar-title {
    font-size: 1.125rem;
    font-weight: 700;
    color: #ffffff;
    letter-spacing: 0.2px;
  }
  .ui5-shellbar-subtitle {
    font-size: 0.8125rem;
    color: #8da2b5;
    margin-left: 0.75rem;
    font-weight: 400;
  }
  .ui5-shellbar-avatar {
    width: 2rem;
    height: 2rem;
    border-radius: 50%;
    background: #0070f2;
    color: #ffffff;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.8125rem;
    font-weight: 700;
    cursor: pointer;
  }

  /* Cards */
  ui5-card {
    display: block;
    background: var(--sapCardBackground);
    border: 1px solid var(--sapBorderColor);
    border-radius: 0.75rem;
    box-shadow: 0 2px 8px rgba(0,0,0,0.05);
    overflow: hidden;
    margin-bottom: 1.5rem;
    transition: box-shadow 0.2s ease;
  }
  ui5-card:hover {
    box-shadow: 0 4px 14px rgba(0,0,0,0.08);
  }
  ui5-card-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 1.25rem;
    border-bottom: 1px solid #edf1f5;
    background: #fafbfc;
    box-sizing: border-box;
  }
  .ui5-card-title {
    font-size: 1rem;
    font-weight: 700;
    color: #1d2d3e;
    margin: 0;
  }
  .ui5-card-subtitle {
    font-size: 0.8125rem;
    color: #556b82;
    margin-top: 0.15rem;
  }
  .ui5-card-status {
    font-size: 0.8125rem;
    font-weight: 600;
    color: #556b82;
  }
  .ui5-card-body {
    padding: 1.25rem;
  }

  /* Buttons */
  ui5-button, ui5-toggle-button, ui5-menu-button {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    height: var(--sapButtonHeight);
    padding: 0 1.25rem;
    border-radius: var(--sapBorderRadius);
    font-family: inherit;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    box-sizing: border-box;
    transition: all 0.15s ease;
    user-select: none;
    border: 1px solid #0070f2;
    background: #ffffff;
    color: #0070f2;
    vertical-align: middle;
  }
  ui5-button:hover, ui5-toggle-button:hover, ui5-menu-button:hover {
    background: #f0f6ff;
    border-color: #0056b3;
  }
  ui5-button:active, ui5-toggle-button:active {
    transform: translateY(1px);
  }
  ui5-toggle-button[pressed] {
    background: #0070f2;
    color: #ffffff;
    border-color: #0070f2;
  }
  ui5-button[design="Emphasized"] {
    background: #0070f2;
    color: #ffffff;
    border-color: #0070f2;
    box-shadow: 0 2px 4px rgba(0,112,242,0.25);
  }
  ui5-button[design="Emphasized"]:hover {
    background: #005bca;
    border-color: #005bca;
  }
  ui5-button[design="Positive"] {
    background: #107e3e;
    color: #ffffff;
    border-color: #107e3e;
    box-shadow: 0 2px 4px rgba(16,126,62,0.25);
  }
  ui5-button[design="Positive"]:hover {
    background: #0d6833;
  }
  ui5-button[design="Negative"] {
    background: #b00;
    color: #ffffff;
    border-color: #b00;
  }
  ui5-button[design="Negative"]:hover {
    background: #900;
  }
  ui5-button[design="Transparent"] {
    background: transparent;
    color: #0070f2;
    border-color: transparent;
  }
  ui5-button[design="Transparent"]:hover {
    background: rgba(0,112,242,0.08);
  }
  ui5-button[disabled] {
    opacity: 0.5;
    cursor: not-allowed;
    pointer-events: none;
  }

  /* Segmented Button */
  ui5-segmented-button {
    display: inline-flex;
    border-radius: var(--sapBorderRadius);
    overflow: hidden;
    border: 1px solid #0070f2;
    vertical-align: middle;
  }
  ui5-segmented-button-item {
    display: inline-flex;
    align-items: center;
    padding: 0.4rem 1rem;
    cursor: pointer;
    background: #ffffff;
    color: #0070f2;
    font-weight: 600;
    font-size: 0.875rem;
    user-select: none;
    border-right: 1px solid #0070f2;
    transition: all 0.15s ease;
  }
  ui5-segmented-button-item:last-child { border-right: none; }
  ui5-segmented-button-item[selected] {
    background: #0070f2;
    color: #ffffff;
  }

  /* Inputs & Forms */
  ui5-input, ui5-step-input, ui5-combobox, ui5-multi-combobox {
    display: inline-flex;
    align-items: center;
    position: relative;
    width: 100%;
    box-sizing: border-box;
    vertical-align: middle;
  }
  .ui5-native-input, ui5-input input, ui5-combobox input {
    display: inline-flex;
    align-items: center;
    height: var(--sapButtonHeight);
    padding: 0 0.85rem;
    border-radius: var(--sapBorderRadius);
    border: 1px solid #8996a2;
    background: #ffffff;
    color: #1d2d3e;
    font-family: inherit;
    font-size: 0.875rem;
    box-sizing: border-box;
    outline: none;
    width: 100%;
    transition: border-color 0.15s, box-shadow 0.15s;
  }
  .ui5-native-input:focus, ui5-input input:focus, ui5-combobox input:focus {
    border-color: #0070f2;
    box-shadow: 0 0 0 2px rgba(0,112,242,0.2);
  }
  ui5-input[value-state="Success"] .ui5-native-input,
  ui5-input[value-state="Success"] input {
    border-color: #107e3e;
    background: #f7fdf9;
  }
  ui5-input[value-state="Error"] .ui5-native-input,
  ui5-input[value-state="Error"] input {
    border-color: #b00;
    background: #fff8f8;
  }
  .ui5-val-state-msg {
    position: absolute;
    bottom: -1.25rem;
    left: 0;
    font-size: 0.75rem;
    color: #b00;
    font-weight: 500;
  }

  /* Step Input */
  .ui5-step-btn {
    all: unset;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 2.25rem;
    height: 2.25rem;
    background: #f5f6f7;
    color: #0070f2;
    cursor: pointer;
    font-size: 1.1rem;
    font-weight: 700;
    border: 1px solid #8996a2;
    box-sizing: border-box;
  }
  .ui5-step-btn:first-child { border-radius: var(--sapBorderRadius) 0 0 var(--sapBorderRadius); border-right: none; }
  .ui5-step-btn:last-child { border-radius: 0 var(--sapBorderRadius) var(--sapBorderRadius) 0; border-left: none; }

  /* Sliders & Rating */
  ui5-slider, ui5-range-slider {
    display: flex;
    align-items: center;
    height: 2.25rem;
    width: 100%;
  }
  ui5-rating-indicator {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    cursor: pointer;
    color: #e9a100;
    font-size: 1.35rem;
    vertical-align: middle;
  }

  /* Select */
  ui5-select {
    display: inline-flex;
    vertical-align: middle;
    min-width: 150px;
    box-sizing: border-box;
  }
  .ui5-native-select, ui5-select select {
    display: inline-flex;
    align-items: center;
    height: var(--sapButtonHeight);
    padding: 0 1.75rem 0 0.85rem;
    border-radius: var(--sapBorderRadius);
    border: 1px solid #8996a2;
    background: #ffffff;
    color: #1d2d3e;
    font-family: inherit;
    font-size: 0.875rem;
    cursor: pointer;
    box-sizing: border-box;
    outline: none;
    width: 100%;
    transition: border-color 0.15s;
  }

  /* DatePickers & TimePickers */
  ui5-datepicker, ui5-time-picker, ui5-datetime-picker, ui5-daterange-picker {
    display: inline-flex;
    vertical-align: middle;
    min-width: 160px;
    box-sizing: border-box;
  }
  .ui5-native-date, ui5-datepicker input, ui5-time-picker input {
    display: inline-flex;
    align-items: center;
    height: var(--sapButtonHeight);
    padding: 0 0.85rem;
    border-radius: var(--sapBorderRadius);
    border: 1px solid #8996a2;
    background: #ffffff;
    color: #1d2d3e;
    font-family: inherit;
    font-size: 0.875rem;
    box-sizing: border-box;
    outline: none;
    width: 100%;
    transition: border-color 0.15s;
  }

  /* Switch & Checkbox & Radio */
  ui5-switch, ui5-checkbox, ui5-radio-button {
    display: inline-flex;
    align-items: center;
    vertical-align: middle;
  }

  /* Table */
  ui5-table {
    display: table;
    width: 100%;
    border-collapse: collapse;
    background: #ffffff;
    border-radius: 0.5rem;
    overflow: hidden;
    box-shadow: 0 1px 3px rgba(0,0,0,0.06);
    box-sizing: border-box;
  }
  ui5-table-column {
    display: table-cell;
    padding: 0.85rem 1rem;
    background: #f5f6f7;
    font-weight: 700;
    font-size: 0.8125rem;
    color: #556b82;
    border-bottom: 2px solid #eaedf1;
    vertical-align: middle;
    box-sizing: border-box;
  }
  ui5-table-row {
    display: table-row;
    border-bottom: 1px solid #f0f2f5;
    transition: background 0.15s;
  }
  ui5-table-row:hover {
    background: #f8fafd;
  }
  ui5-table-cell {
    display: table-cell;
    padding: 0.85rem 1rem;
    font-size: 0.875rem;
    color: #1d2d3e;
    vertical-align: middle;
    box-sizing: border-box;
  }

  /* Lists */
  ui5-list {
    display: block;
    background: #ffffff;
    border: 1px solid var(--sapBorderColor);
    border-radius: 0.5rem;
    overflow: hidden;
    box-sizing: border-box;
  }
  ui5-li {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.85rem 1rem;
    border-bottom: 1px solid #edf1f5;
    font-size: 0.875rem;
    box-sizing: border-box;
    transition: background 0.15s;
  }
  ui5-li:hover { background: #f8fafd; }
  ui5-li:last-child { border-bottom: none; }

  /* TabContainer */
  ui5-tabcontainer {
    display: block;
    background: #ffffff;
    border: 1px solid var(--sapBorderColor);
    border-radius: 0.5rem;
    overflow: hidden;
    margin-bottom: 1.5rem;
  }
  .ui5-tab-strip {
    display: flex;
    border-bottom: 2px solid #eaedf1;
    background: #fafbfc;
  }
  .ui5-tab-btn {
    padding: 0.75rem 1.25rem;
    cursor: pointer;
    font-weight: 600;
    font-size: 0.875rem;
    color: #556b82;
    border-bottom: 2px solid transparent;
    margin-bottom: -2px;
    transition: all 0.15s ease;
  }
  .ui5-tab-btn.active {
    color: #0070f2;
    border-bottom-color: #0070f2;
  }
  ui5-tab {
    display: block;
    padding: 1.25rem;
  }

  /* Breadcrumbs */
  ui5-breadcrumbs {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.875rem;
    color: #556b82;
    margin-bottom: 0.75rem;
  }
  ui5-breadcrumbs-item {
    display: inline-flex;
    align-items: center;
  }
  ui5-breadcrumbs-item:not(:last-child)::after {
    content: "/";
    margin-left: 0.5rem;
    color: #8da2b5;
  }

  /* Bar */
  ui5-bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    height: 3rem;
    padding: 0 1.25rem;
    background: #ffffff;
    border-bottom: 1px solid var(--sapBorderColor);
    box-sizing: border-box;
  }

  /* Avatar */
  ui5-avatar {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 2.5rem;
    height: 2.5rem;
    border-radius: 50%;
    background: #0070f2;
    color: #ffffff;
    font-weight: 700;
    font-size: 0.875rem;
    vertical-align: middle;
  }
  ui5-avatar[shape="Square"] { border-radius: 0.35rem; }
  ui5-avatar[size="XS"] { width: 1.5rem; height: 1.5rem; font-size: 0.7rem; }
  ui5-avatar[size="S"]  { width: 2rem; height: 2rem; font-size: 0.8rem; }
  ui5-avatar[size="L"]  { width: 3.5rem; height: 3.5rem; font-size: 1.1rem; }
  ui5-avatar[size="XL"] { width: 4.5rem; height: 4.5rem; font-size: 1.4rem; }

  /* Badges & Tags */
  ui5-badge, ui5-tag {
    display: inline-flex;
    align-items: center;
    padding: 0.2rem 0.65rem;
    border-radius: 1rem;
    font-size: 0.75rem;
    font-weight: 700;
    letter-spacing: 0.3px;
    background: #e5f0ff;
    color: #0070f2;
    vertical-align: middle;
  }
  ui5-tag { border-radius: 0.35rem; font-weight: 600; }
  ui5-badge[color-scheme="8"], ui5-tag[color-scheme="8"] { background: #e8f5e9; color: #107e3e; }
  ui5-badge[color-scheme="2"], ui5-tag[color-scheme="2"] { background: #ffebee; color: #b00; }
  ui5-badge[color-scheme="6"], ui5-tag[color-scheme="6"] { background: #e5f0ff; color: #0070f2; }

  /* Progress Indicator */
  ui5-progress-indicator {
    display: block;
    position: relative;
    width: 100%;
    height: 1.25rem;
    background: #e2e8f0;
    border-radius: 0.5rem;
    overflow: hidden;
    box-sizing: border-box;
  }
  .ui5-progress-bar {
    height: 100%;
    background: linear-gradient(90deg, #0070f2, #107e3e);
    border-radius: 0.5rem;
    transition: width 0.4s ease;
  }
  .ui5-progress-label {
    position: absolute;
    top: 0; left: 0; width: 100%; height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.75rem;
    font-weight: 700;
    color: #1d2d3e;
  }

  /* Timeline */
  ui5-timeline {
    display: flex;
    flex-direction: column;
    position: relative;
    padding-left: 2rem;
    margin: 1rem 0;
  }
  ui5-timeline::before {
    content: "";
    position: absolute;
    left: 0.75rem;
    top: 0.5rem;
    bottom: 0.5rem;
    width: 2px;
    background: #eaedf1;
  }
  ui5-timeline-item {
    display: block;
    position: relative;
    margin-bottom: 1.5rem;
  }
  ui5-timeline-item::before {
    content: "";
    position: absolute;
    left: -1.55rem;
    top: 0.25rem;
    width: 0.65rem;
    height: 0.65rem;
    border-radius: 50%;
    background: #0070f2;
    box-shadow: 0 0 0 3px #ffffff;
  }

  /* Toast */
  ui5-toast {
    position: fixed;
    bottom: 2rem;
    left: 50%;
    transform: translateX(-50%) translateY(20px);
    background: #1d2d3e;
    color: #ffffff;
    padding: 0.85rem 1.75rem;
    border-radius: 0.5rem;
    font-size: 0.875rem;
    font-weight: 600;
    box-shadow: 0 4px 16px rgba(0,0,0,0.3);
    z-index: 10000;
    opacity: 0;
    pointer-events: none;
    transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
  }
  ui5-toast.ui5-toast-show {
    transform: translateX(-50%) translateY(0);
    opacity: 1;
    pointer-events: auto;
  }

  /* Dialog */
  ui5-dialog {
    position: fixed;
    top: 0; left: 0; width: 100vw; height: 100vh;
    background: rgba(29, 45, 62, 0.6);
    backdrop-filter: blur(2px);
    display: none;
    align-items: center;
    justify-content: center;
    z-index: 9999;
  }
  ui5-dialog.ui5-dialog-open {
    display: flex;
  }
  .ui5-dialog-modal {
    background: #ffffff;
    border-radius: 0.75rem;
    box-shadow: 0 8px 32px rgba(0,0,0,0.25);
    width: 90%;
    max-width: 520px;
    overflow: hidden;
    animation: ui5DialogIn 0.2s ease-out;
  }
  @keyframes ui5DialogIn {
    from { opacity: 0; transform: scale(0.95); }
    to { opacity: 1; transform: scale(1); }
  }
  .ui5-dialog-header {
    padding: 1rem 1.25rem;
    border-bottom: 1px solid #eaedf1;
    font-weight: 700;
    font-size: 1.125rem;
    color: #1d2d3e;
  }
  .ui5-dialog-body {
    padding: 1.25rem;
    font-size: 0.875rem;
    line-height: 1.6;
  }
  .ui5-dialog-footer {
    padding: 0.75rem 1.25rem;
    border-top: 1px solid #eaedf1;
    display: flex;
    justify-content: flex-end;
    gap: 0.5rem;
    background: #fafbfc;
  }

  /* Message Strip */
  ui5-message-strip {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.85rem 1.25rem;
    border-radius: 0.5rem;
    background: #e5f0ff;
    color: #0070f2;
    border: 1px solid #b3d7ff;
    font-size: 0.875rem;
    font-weight: 500;
    margin-bottom: 1rem;
  }
</style>`, {bg_color, text_color, card_bg, border_color, primary_color})
end function

-- =============================================================================
-- 4. Component Builders
-- =============================================================================

--**
-- Construct a complete HTML5 UI5 Web Components page (v2.29).
public function page(sequence title, object content, sequence options = {})
    sequence theme = get_opt(options, "theme", THEME_HORIZON)
    sequence version = get_opt(options, "version", DEFAULT_VERSION)
    sequence cdn_base = get_opt(options, "cdn", DEFAULT_CDN_BASE)
    sequence body_html = to_content_string(content)

    sequence doc = `<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>` & escape_html(title) & `</title>
  <script data-ui5-config type="application/json">
  {
    "theme": "` & theme & `",
    "language": "de"
  }
  </script>
  ` & get_horizon_base_css(theme) & `
  <script src="` & cdn_base & `/@ui5/webcomponents@` & version & `/dist/webcomponents.min.js"></script>
  <script src="` & cdn_base & `/@ui5/webcomponents-fiori@` & version & `/dist/webcomponents-fiori.min.js"></script>
  <script src="` & cdn_base & `/@ui5/webcomponents-icons@` & version & `/dist/AllIcons.js"></script>
</head>
<body class="ui5-body">
` & body_html & `
` & get_bridge_javascript() & `
</body>
</html>`
    return doc
end function

-- -----------------------------------------------------------------------------
-- Typography, Labels & Basic Text
-- -----------------------------------------------------------------------------

--**
-- Construct a <ui5-title> heading element.
public function title(sequence text, sequence level = TITLE_H2, sequence options = {})
    return sprintf("<ui5-title level=\"%s\">%s</ui5-title>\n", {level, escape_html(text)})
end function

--**
-- Construct a <ui5-label> element.
public function ui_label(sequence text, sequence for_id = "", integer required = 0, sequence options = {})
    sequence html = sprintf("<ui5-label", {})
    if length(for_id) > 0 then html &= sprintf(" for=\"%s\"", {for_id}) end if
    if required then html &= " required" end if
    html &= sprintf(">%s</ui5-label>", {escape_html(text)})
    return html
end function

public function form_label(sequence text, sequence for_id = "", integer required = 0, sequence options = {})
    return ui_label(text, for_id, required, options)
end function

--**
-- Construct a <ui5-link> hyperlink.
public function link(sequence text, sequence href = "#", sequence design = LINK_DEFAULT, sequence options = {})
    sequence target = get_opt(options, "target", "")
    sequence html = sprintf("<ui5-link href=\"%s\" design=\"%s\"", {escape_html(href), design})
    if length(target) > 0 then html &= sprintf(" target=\"%s\"", {target}) end if
    html &= sprintf(">%s</ui5-link>", {escape_html(text)})
    return html
end function

--**
-- Construct a <ui5-text> paragraph text.
public function text_block(sequence text, sequence options = {})
    return sprintf("<ui5-text>%s</ui5-text>", {escape_html(text)})
end function

-- -----------------------------------------------------------------------------
-- ShellBar, Headers & Navigation
-- -----------------------------------------------------------------------------

--**
-- Construct a <ui5-shellbar> top header component.
public function shellbar(sequence primary_title, sequence secondary_title = "", sequence options = {})
    sequence profile_name = get_opt(options, "profile", "")
    integer show_notif    = equal(get_opt(options, "notifications", "1"), "1")
    integer show_co_pilot = equal(get_opt(options, "co_pilot", "0"), "1")

    sequence html = sprintf("<ui5-shellbar primary-title=\"%s\"", {escape_html(primary_title)})
    if length(secondary_title) > 0 then
        html &= sprintf(" secondary-title=\"%s\"", {escape_html(secondary_title)})
    end if
    if length(profile_name) > 0 then
        sequence initials = profile_name[1..min({2, length(profile_name)})]
        html &= sprintf(" initials=\"%s\"", {escape_html(initials)})
    end if
    if show_notif then
        html &= " show-notifications"
    end if
    if show_co_pilot then
        html &= " show-co-pilot"
    end if
    html &= "></ui5-shellbar>\n"
    return html
end function

--**
-- Construct a <ui5-breadcrumbs> navigation bar.
public function breadcrumbs(sequence items, sequence options = {})
    sequence html = "<ui5-breadcrumbs>\n"
    for i = 1 to length(items) do
        sequence itm = items[i]
        sequence txt = itm[1]
        sequence href = "#"
        if length(itm) >= 2 then href = itm[2] end if
        html &= sprintf("  <ui5-breadcrumbs-item href=\"%s\">%s</ui5-breadcrumbs-item>\n",
                        {escape_html(href), escape_html(txt)})
    end for
    html &= "</ui5-breadcrumbs>\n"
    return html
end function

--**
-- Construct a <ui5-bar> Fiori bar layout.
public function bar(object start_content, object middle_content = {}, object end_content = {},
                    sequence design = BAR_HEADER, sequence options = {})
    sequence html = sprintf("<ui5-bar design=\"%s\">\n", {design})
    if length(to_content_string(start_content)) > 0 then
        html &= sprintf("  <div slot=\"startContent\">%s</div>\n", {to_content_string(start_content)})
    end if
    if length(to_content_string(middle_content)) > 0 then
        html &= sprintf("  <div slot=\"middleContent\">%s</div>\n", {to_content_string(middle_content)})
    end if
    if length(to_content_string(end_content)) > 0 then
        html &= sprintf("  <div slot=\"endContent\">%s</div>\n", {to_content_string(end_content)})
    end if
    html &= "</ui5-bar>\n"
    return html
end function

-- -----------------------------------------------------------------------------
-- Containers: Cards, Panels & Tabs
-- -----------------------------------------------------------------------------

--**
-- Construct a <ui5-card> container with header and content.
public function card(sequence title, object content, sequence options = {})
    sequence subtitle = get_opt(options, "subtitle", "")
    sequence status   = get_opt(options, "status", "")
    sequence icon_name = get_opt(options, "icon", "")
    sequence id_attr  = get_opt(options, "id", "")
    sequence cls_attr = get_opt(options, "class", "ui5-card-margin")

    sequence html = "<ui5-card"
    if length(id_attr) > 0 then html &= sprintf(" id=\"%s\"", {id_attr}) end if
    if length(cls_attr) > 0 then html &= sprintf(" class=\"%s\"", {cls_attr}) end if
    html &= ">\n"

    -- Card Header
    html &= sprintf("  <ui5-card-header slot=\"header\" title-text=\"%s\"", {escape_html(title)})
    if length(subtitle) > 0 then
        html &= sprintf(" subtitle-text=\"%s\"", {escape_html(subtitle)})
    end if
    if length(status) > 0 then
        html &= sprintf(" status=\"%s\"", {escape_html(status)})
    end if
    html &= ">\n"
    if length(icon_name) > 0 then
        html &= sprintf("    <ui5-icon name=\"%s\" slot=\"avatar\"></ui5-icon>\n", {icon_name})
    end if
    html &= "  </ui5-card-header>\n"

    -- Card Body Content
    html &= "  <div class=\"ui5-card-body\">\n"
    html &= to_content_string(content)
    html &= "\n  </div>\n</ui5-card>\n"
    return html
end function

--**
-- Construct an expandable/collapsible <ui5-panel>.
public function panel(sequence header_text, object content, integer collapsed = 0, sequence options = {})
    sequence html = sprintf("<ui5-panel header-text=\"%s\"", {escape_html(header_text)})
    if collapsed then html &= " collapsed" end if
    html &= ">\n"
    html &= to_content_string(content)
    html &= "\n</ui5-panel>\n"
    return html
end function

--**
-- Construct a <ui5-tabcontainer> with <ui5-tab> elements.
public function tab_container(sequence tabs, sequence options = {})
    sequence id_attr = get_opt(options, "id", "")
    sequence html = "<ui5-tabcontainer"
    if length(id_attr) > 0 then html &= sprintf(" id=\"%s\"", {id_attr}) end if
    html &= ">\n"
    for i = 1 to length(tabs) do
        sequence t = tabs[i]
        sequence tab_txt = t[1]
        object tab_cnt  = t[2]
        sequence icon_nm = ""
        integer is_sel   = 0
        if length(t) >= 3 then icon_nm = t[3] end if
        if length(t) >= 4 then is_sel = t[4] end if
        html &= sprintf("  <ui5-tab text=\"%s\"", {escape_html(tab_txt)})
        if length(icon_nm) > 0 then html &= sprintf(" icon=\"%s\"", {icon_nm}) end if
        if is_sel then html &= " selected" end if
        html &= ">\n    " & to_content_string(tab_cnt) & "\n  </ui5-tab>\n"
    end for
    html &= "</ui5-tabcontainer>\n"
    return html
end function

-- -----------------------------------------------------------------------------
-- Data Presentation: Tables, Lists & Trees
-- -----------------------------------------------------------------------------

--**
-- Construct a responsive <ui5-table> with columns and rows.
public function table(sequence columns, sequence rows, sequence options = {})
    sequence id_attr = get_opt(options, "id", "")
    sequence no_data = get_opt(options, "no_data_text", "Keine Datensätze gefunden")
    sequence mode    = get_opt(options, "mode", "")

    sequence html = "<ui5-table"
    if length(id_attr) > 0 then html &= sprintf(" id=\"%s\"", {id_attr}) end if
    if length(mode) > 0 then html &= sprintf(" mode=\"%s\"", {mode}) end if
    html &= sprintf(" no-data-text=\"%s\">\n", {escape_html(no_data)})

    -- Columns
    for i = 1 to length(columns) do
        sequence col_name = ""
        sequence col_width = ""
        if sequence(columns[i]) and length(columns[i]) > 0 and sequence(columns[i][1]) then
            col_name = columns[i][1]
            if length(columns[i]) >= 2 then col_width = columns[i][2] end if
        else
            col_name = to_content_string(columns[i])
        end if
        html &= "  <ui5-table-column slot=\"columns\""
        if length(col_width) > 0 then
            html &= sprintf(" style=\"width: %s;\"", {col_width})
        end if
        html &= sprintf("><span>%s</span></ui5-table-column>\n", {escape_html(col_name)})
    end for

    -- Rows
    for r = 1 to length(rows) do
        sequence row = rows[r]
        html &= "  <ui5-table-row>\n"
        for c = 1 to length(row) do
            html &= sprintf("    <ui5-table-cell><span>%s</span></ui5-table-cell>\n", {to_content_string(row[c])})
        end for
        html &= "  </ui5-table-row>\n"
    end for

    html &= "</ui5-table>\n"
    return html
end function

--**
-- Helper to format database query rows directly into a UI5 table.
public function table_from_query(sequence headers, sequence query_rows, sequence options = {})
    return table(headers, query_rows, options)
end function

--**
-- Construct a <ui5-list> with <ui5-li> items.
public function list(sequence items, sequence options = {})
    sequence hdr = get_opt(options, "header", "")
    sequence mode = get_opt(options, "mode", LIST_NONE)
    sequence html = "<ui5-list"
    if length(hdr) > 0 then html &= sprintf(" header-text=\"%s\"", {escape_html(hdr)}) end if
    if not equal(mode, LIST_NONE) then html &= sprintf(" mode=\"%s\"", {mode}) end if
    html &= ">\n"
    for i = 1 to length(items) do
        sequence itm = items[i]
        sequence title = ""
        sequence desc = ""
        sequence icn = ""
        sequence extra = ""
        if sequence(itm) and length(itm) >= 1 and sequence(itm[1]) then
            title = itm[1]
            if length(itm) >= 2 then desc = itm[2] end if
            if length(itm) >= 3 then icn = itm[3] end if
            if length(itm) >= 4 then extra = itm[4] end if
        else
            title = to_content_string(itm)
        end if
        html &= "  <ui5-li"
        if length(desc) > 0 then html &= sprintf(" description=\"%s\"", {escape_html(desc)}) end if
        if length(icn) > 0 then html &= sprintf(" icon=\"%s\"", {icn}) end if
        if length(extra) > 0 then html &= sprintf(" additional-text=\"%s\"", {escape_html(extra)}) end if
        html &= sprintf(">%s</ui5-li>\n", {escape_html(title)})
    end for
    html &= "</ui5-list>\n"
    return html
end function

--**
-- Construct a <ui5-tree> with hierarchical items.
public function tree(sequence items, sequence options = {})
    sequence html = "<ui5-tree>\n"
    for i = 1 to length(items) do
        sequence itm = items[i]
        sequence txt = itm[1]
        sequence icn = ""
        integer exp = 0
        if length(itm) >= 2 then icn = itm[2] end if
        if length(itm) >= 3 then exp = itm[3] end if
        html &= sprintf("  <ui5-tree-item text=\"%s\"", {escape_html(txt)})
        if length(icn) > 0 then html &= sprintf(" icon=\"%s\"", {icn}) end if
        if exp then html &= " expanded" end if
        if length(itm) >= 4 and sequence(itm[4]) and length(itm[4]) > 0 then
            html &= ">\n"
            sequence sub = itm[4]
            for j = 1 to length(sub) do
                html &= sprintf("    <ui5-tree-item text=\"%s\"></ui5-tree-item>\n", {escape_html(sub[j][1])})
            end for
            html &= "  </ui5-tree-item>\n"
        else
            html &= "></ui5-tree-item>\n"
        end if
    end for
    html &= "</ui5-tree>\n"
    return html
end function

-- -----------------------------------------------------------------------------
-- Buttons & Segmented Controls
-- -----------------------------------------------------------------------------

--**
-- Construct a <ui5-button>.
public function button(sequence id, sequence text, sequence options = {})
    sequence design   = get_opt(options, "design", DESIGN_DEFAULT)
    sequence icon_name = get_opt(options, "icon", "")
    sequence action   = get_opt(options, "action", "")
    integer disabled  = equal(get_opt(options, "disabled", "0"), "1")

    sequence html = sprintf("<ui5-button id=\"%s\" design=\"%s\"", {id, design})
    if length(icon_name) > 0 then html &= sprintf(" icon=\"%s\"", {icon_name}) end if
    if length(action) > 0 then html &= sprintf(" data-ui5-action=\"%s\"", {action}) end if
    if disabled then html &= " disabled" end if

    -- Forward extra data-param-* attributes
    for i = 1 to length(options) do
        if sequence(options[i]) and length(options[i]) >= 2 then
            sequence k = options[i][1]
            if length(k) > 11 and equal(k[1..11], "data-param-") then
                html &= sprintf(" %s=\"%s\"", {k, escape_html(options[i][2])})
            end if
        end if
    end for

    html &= sprintf(">%s</ui5-button>", {escape_html(text)})
    return html
end function

--**
-- Construct a <ui5-toggle-button>.
public function toggle_button(sequence id, sequence text, integer pressed = 0, sequence options = {})
    sequence design = get_opt(options, "design", DESIGN_DEFAULT)
    sequence icon_nm = get_opt(options, "icon", "")
    sequence action = get_opt(options, "action", "")
    sequence html = sprintf("<ui5-toggle-button id=\"%s\" design=\"%s\"", {id, design})
    if pressed then html &= " pressed" end if
    if length(icon_nm) > 0 then html &= sprintf(" icon=\"%s\"", {icon_nm}) end if
    if length(action) > 0 then html &= sprintf(" data-ui5-action=\"%s\"", {action}) end if
    html &= sprintf(">%s</ui5-toggle-button>", {escape_html(text)})
    return html
end function

--**
-- Construct a <ui5-menu-button>.
public function menu_button(sequence id, sequence text, sequence options = {})
    sequence design = get_opt(options, "design", DESIGN_DEFAULT)
    sequence icon_nm = get_opt(options, "icon", "")
    sequence html = sprintf("<ui5-menu-button id=\"%s\" design=\"%s\"", {id, design})
    if length(icon_nm) > 0 then html &= sprintf(" icon=\"%s\"", {icon_nm}) end if
    html &= sprintf(">%s</ui5-menu-button>", {escape_html(text)})
    return html
end function

--**
-- Construct a <ui5-segmented-button> with items.
public function segmented_button(sequence id, sequence items, sequence options = {})
    sequence html = sprintf("<ui5-segmented-button id=\"%s\">\n", {id})
    for i = 1 to length(items) do
        sequence itm = items[i]
        sequence item_id = itm[1]
        sequence item_txt = itm[2]
        integer is_sel = 0
        sequence icn = ""
        if length(itm) >= 3 then is_sel = itm[3] end if
        if length(itm) >= 4 then icn = itm[4] end if
        html &= sprintf("  <ui5-segmented-button-item id=\"%s\"", {item_id})
        if is_sel then html &= " selected" end if
        if length(icn) > 0 then html &= sprintf(" icon=\"%s\"", {icn}) end if
        html &= sprintf(">%s</ui5-segmented-button-item>\n", {escape_html(item_txt)})
    end for
    html &= "</ui5-segmented-button>"
    return html
end function

-- -----------------------------------------------------------------------------
-- Form Inputs, Steppers, Sliders & Selectors
-- -----------------------------------------------------------------------------

--**
-- Construct a <ui5-input> field.
public function input(sequence id, sequence value = "", sequence options = {})
    sequence ph     = get_opt(options, "placeholder", "")
    sequence itype  = get_opt(options, "type", "Text")
    sequence state  = get_opt(options, "value_state", STATE_NONE)
    sequence style  = get_opt(options, "style", "")
    integer readonly = equal(get_opt(options, "readonly", "0"), "1")

    sequence html = sprintf("<ui5-input id=\"%s\" value=\"%s\" type=\"%s\" value-state=\"%s\"",
                            {id, escape_html(value), itype, state})
    if length(ph) > 0 then html &= sprintf(" placeholder=\"%s\"", {escape_html(ph)}) end if
    if length(style) > 0 then html &= sprintf(" style=\"%s\"", {style}) end if
    if readonly then html &= " readonly" end if
    html &= "></ui5-input>"
    return html
end function

--**
-- Construct a numeric <ui5-step-input>.
public function step_input(sequence id, atom value = 0, atom min_val = 0, atom max_val = 100,
                           atom step_val = 1, sequence options = {})
    sequence state = get_opt(options, "value_state", STATE_NONE)
    return sprintf("<ui5-step-input id=\"%s\" value=\"%g\" min=\"%g\" max=\"%g\" step=\"%g\" value-state=\"%s\"></ui5-step-input>",
                   {id, value, min_val, max_val, step_val, state})
end function

--**
-- Construct a <ui5-slider>.
public function slider(sequence id, atom value = 0, atom min_val = 0, atom max_val = 100,
                       atom step_val = 1, sequence options = {})
    return sprintf("<ui5-slider id=\"%s\" value=\"%g\" min=\"%g\" max=\"%g\" step=\"%g\" show-tickmarks show-tooltip></ui5-slider>",
                   {id, value, min_val, max_val, step_val})
end function

--**
-- Construct a <ui5-range-slider>.
public function range_slider(sequence id, atom start_val = 20, atom end_val = 80,
                             atom min_val = 0, atom max_val = 100, atom step_val = 1, sequence options = {})
    return sprintf("<ui5-range-slider id=\"%s\" start-value=\"%g\" end-value=\"%g\" min=\"%g\" max=\"%g\" step=\"%g\"></ui5-range-slider>",
                   {id, start_val, end_val, min_val, max_val, step_val})
end function

--**
-- Construct a <ui5-rating-indicator> star rating component.
public function rating_indicator(sequence id, atom value = 3, integer max_val = 5, sequence options = {})
    return sprintf("<ui5-rating-indicator id=\"%s\" value=\"%g\" max=\"%d\"></ui5-rating-indicator>",
                   {id, value, max_val})
end function

--**
-- Construct a <ui5-textarea> multiline text field.
public function textarea(sequence id, sequence value = "", sequence options = {})
    sequence ph    = get_opt(options, "placeholder", "")
    sequence style = get_opt(options, "style", "")
    integer rows   = 4
    if length(get_opt(options, "rows", "")) > 0 then
        rows = get_opt(options, "rows", "")
    end if

    sequence html = sprintf("<ui5-textarea id=\"%s\" rows=\"%d\"", {id, rows})
    if length(ph) > 0 then html &= sprintf(" placeholder=\"%s\"", {escape_html(ph)}) end if
    if length(style) > 0 then html &= sprintf(" style=\"%s\"", {style}) end if
    html &= sprintf(">%s</ui5-textarea>", {escape_html(value)})
    return html
end function

--**
-- Construct a <ui5-checkbox>.
public function checkbox(sequence id, sequence text, integer checked = 0, sequence options = {})
    sequence html = sprintf("<ui5-checkbox id=\"%s\" text=\"%s\"", {id, escape_html(text)})
    if checked then html &= " checked" end if
    html &= "></ui5-checkbox>"
    return html
end function

--**
-- Construct a <ui5-radio-button>.
public function radio_button(sequence id, sequence name, sequence text, sequence value = "",
                             integer checked = 0, sequence options = {})
    sequence html = sprintf("<ui5-radio-button id=\"%s\" name=\"%s\" text=\"%s\" value=\"%s\"",
                            {id, name, escape_html(text), escape_html(value)})
    if checked then html &= " checked" end if
    html &= "></ui5-radio-button>"
    return html
end function

--**
-- Construct a <ui5-switch>.
public function switch_btn(sequence id, sequence text_on = "Ein", sequence text_off = "Aus",
                           integer checked = 0, sequence options = {})
    sequence html = sprintf("<ui5-switch id=\"%s\" text-on=\"%s\" text-off=\"%s\"",
                            {id, escape_html(text_on), escape_html(text_off)})
    if checked then html &= " checked" end if
    html &= "></ui5-switch>"
    return html
end function

--**
-- Construct a <ui5-select> dropdown with <ui5-option> entries.
public function select(sequence id, sequence options_list, sequence options = {})
    sequence html = sprintf("<ui5-select id=\"%s\">\n", {id})
    for i = 1 to length(options_list) do
        sequence item = options_list[i]
        sequence opt_val = item[1]
        sequence opt_lbl = item[2]
        integer is_sel = 0
        if length(item) >= 3 then is_sel = item[3] end if
        html &= sprintf("  <ui5-option value=\"%s\"", {escape_html(opt_val)})
        if is_sel then html &= " selected" end if
        html &= sprintf(">%s</ui5-option>\n", {escape_html(opt_lbl)})
    end for
    html &= "</ui5-select>"
    return html
end function

--**
-- Construct a <ui5-combobox> with auto-complete items.
public function combobox(sequence id, sequence value = "", sequence items = {}, sequence options = {})
    sequence ph = get_opt(options, "placeholder", "")
    sequence html = sprintf("<ui5-combobox id=\"%s\" value=\"%s\" placeholder=\"%s\">\n",
                            {id, escape_html(value), escape_html(ph)})
    for i = 1 to length(items) do
        sequence itm = items[i]
        sequence itm_txt = ""
        sequence add_txt = ""
        if sequence(itm) and length(itm) >= 1 and sequence(itm[1]) then
            itm_txt = itm[1]
            if length(itm) >= 2 then add_txt = itm[2] end if
        else
            itm_txt = to_content_string(itm)
        end if
        html &= sprintf("  <ui5-cb-item text=\"%s\"", {escape_html(itm_txt)})
        if length(add_txt) > 0 then html &= sprintf(" additional-text=\"%s\"", {escape_html(add_txt)}) end if
        html &= "></ui5-cb-item>\n"
    end for
    html &= "</ui5-combobox>"
    return html
end function

--**
-- Construct a <ui5-multi-combobox> for multiple token selection.
public function multi_combobox(sequence id, sequence items = {}, sequence options = {})
    sequence ph = get_opt(options, "placeholder", "")
    sequence html = sprintf("<ui5-multi-combobox id=\"%s\" placeholder=\"%s\">\n",
                            {id, escape_html(ph)})
    for i = 1 to length(items) do
        sequence itm = items[i]
        sequence txt = itm[1]
        integer is_sel = 0
        if length(itm) >= 2 then is_sel = itm[2] end if
        html &= sprintf("  <ui5-mcb-item text=\"%s\"", {escape_html(txt)})
        if is_sel then html &= " selected" end if
        html &= "></ui5-mcb-item>\n"
    end for
    html &= "</ui5-multi-combobox>"
    return html
end function

--**
-- Construct a <ui5-datepicker>.
public function datepicker(sequence id, sequence value = "", sequence options = {})
    sequence pattern = get_opt(options, "format", "yyyy-MM-dd")
    sequence state   = get_opt(options, "value_state", STATE_NONE)
    sequence html = sprintf("<ui5-datepicker id=\"%s\" value=\"%s\" format-pattern=\"%s\" value-state=\"%s\"></ui5-datepicker>",
                            {id, escape_html(value), pattern, state})
    return html
end function

--**
-- Construct a <ui5-time-picker>.
public function time_picker(sequence id, sequence value = "", sequence options = {})
    sequence pattern = get_opt(options, "format", "HH:mm:ss")
    return sprintf("<ui5-time-picker id=\"%s\" value=\"%s\" format-pattern=\"%s\"></ui5-time-picker>",
                   {id, escape_html(value), pattern})
end function

--**
-- Construct a <ui5-datetime-picker>.
public function datetime_picker(sequence id, sequence value = "", sequence options = {})
    return sprintf("<ui5-datetime-picker id=\"%s\" value=\"%s\"></ui5-datetime-picker>",
                   {id, escape_html(value)})
end function

--**
-- Construct a <ui5-daterange-picker>.
public function daterange_picker(sequence id, sequence value = "", sequence options = {})
    return sprintf("<ui5-daterange-picker id=\"%s\" value=\"%s\"></ui5-daterange-picker>",
                   {id, escape_html(value)})
end function

--**
-- Construct a <ui5-file-uploader>.
public function file_uploader(sequence id, sequence placeholder = "Datei auswählen...", sequence options = {})
    return sprintf("<ui5-file-uploader id=\"%s\" placeholder=\"%s\"><ui5-button icon=\"upload\">Durchsuchen</ui5-button></ui5-file-uploader>",
                   {id, escape_html(placeholder)})
end function

--**
-- Construct a <ui5-color-picker>.
public function color_picker(sequence id, sequence color = "#0070f2", sequence options = {})
    return sprintf("<ui5-color-picker id=\"%s\" color=\"%s\"></ui5-color-picker>",
                   {id, color})
end function

-- -----------------------------------------------------------------------------
-- Indicators, Badges, Tags & Overlays
-- -----------------------------------------------------------------------------

--**
-- Construct a modal <ui5-dialog>.
public function dialog(sequence id, sequence header_text, object content,
                       object footer_buttons = {}, sequence options = {})
    sequence html = sprintf("<ui5-dialog id=\"%s\" header-text=\"%s\">\n",
                            {id, escape_html(header_text)})
    html &= "  <div class=\"ui5-dialog-content\">\n"
    html &= to_content_string(content)
    html &= "\n  </div>\n"
    if length(footer_buttons) > 0 then
        html &= "  <div slot=\"footer\">\n"
        html &= to_content_string(footer_buttons)
        html &= "\n  </div>\n"
    end if
    html &= "</ui5-dialog>\n"
    return html
end function

--**
-- Construct a <ui5-popover>.
public function popover(sequence id, sequence header_text, object content,
                        object footer_buttons = {}, sequence options = {})
    sequence html = sprintf("<ui5-popover id=\"%s\" header-text=\"%s\">\n",
                            {id, escape_html(header_text)})
    html &= "  <div>\n" & to_content_string(content) & "\n  </div>\n"
    if length(footer_buttons) > 0 then
        html &= "  <div slot=\"footer\">\n" & to_content_string(footer_buttons) & "\n  </div>\n"
    end if
    html &= "</ui5-popover>\n"
    return html
end function

--**
-- Construct a <ui5-toast> notification element.
public function toast(sequence id, sequence text = "", integer duration = 3000)
    return sprintf("<ui5-toast id=\"%s\" duration=\"%d\">%s</ui5-toast>\n",
                   {id, duration, escape_html(text)})
end function

--**
-- Construct a <ui5-badge> with SAP Horizon color scheme (1 to 10).
public function badge(sequence text, integer color_scheme = 1, sequence options = {})
    return sprintf("<ui5-badge color-scheme=\"%d\">%s</ui5-badge>",
                   {color_scheme, escape_html(text)})
end function

--**
-- Construct a <ui5-tag> (SAP UI5 2.0+ semantic tag).
public function tag(sequence text, integer color_scheme = 1, sequence options = {})
    return sprintf("<ui5-tag color-scheme=\"%d\">%s</ui5-tag>",
                   {color_scheme, escape_html(text)})
end function

--**
-- Construct a <ui5-icon>.
public function icon(sequence name, sequence options = {})
    sequence style = get_opt(options, "style", "")
    return sprintf("<span class=\"ui5-icon\" style=\"display:inline-flex; vertical-align:middle; %s\">%s</span>",
                   {style, get_icon_svg(name)})
end function

--**
-- Construct a <ui5-avatar>.
public function avatar(sequence initials_or_src, sequence size = AVATAR_M,
                       sequence shape = AVATAR_CIRCLE, sequence options = {})
    return sprintf("<ui5-avatar initials=\"%s\" size=\"%s\" shape=\"%s\"></ui5-avatar>",
                   {escape_html(initials_or_src), size, shape})
end function

--**
-- Construct a <ui5-busy-indicator>.
public function busy_indicator(integer active = 1, sequence size = BUSY_MEDIUM,
                               sequence text = "", object content = {}, sequence options = {})
    sequence html = sprintf("<ui5-busy-indicator size=\"%s\"", {size})
    if active then html &= " active" end if
    if length(text) > 0 then html &= sprintf(" text=\"%s\"", {escape_html(text)}) end if
    html &= ">" & to_content_string(content) & "</ui5-busy-indicator>"
    return html
end function

--**
-- Construct a <ui5-progress-indicator>.
public function progress_indicator(integer value_pct, sequence display_value = "",
                                   sequence state = STATE_NONE, sequence options = {})
    if length(display_value) = 0 then
        display_value = sprintf("%d%%", value_pct)
    end if
    return sprintf("<ui5-progress-indicator value=\"%d\" display-value=\"%s\" value-state=\"%s\"></ui5-progress-indicator>",
                   {value_pct, escape_html(display_value), state})
end function

--**
-- Construct an informational <ui5-message-strip>.
public function message_strip(sequence text, sequence design = "Information", sequence options = {})
    return sprintf("<ui5-message-strip design=\"%s\">%s</ui5-message-strip>",
                   {design, escape_html(text)})
end function

--**
-- Construct a <ui5-timeline> event log.
public function timeline(sequence items, sequence options = {})
    sequence html = "<ui5-timeline>\n"
    for i = 1 to length(items) do
        sequence itm = items[i]
        sequence title = itm[1]
        sequence sub   = ""
        sequence icn   = ""
        sequence name  = ""
        if length(itm) >= 2 then sub = itm[2] end if
        if length(itm) >= 3 then icn = itm[3] end if
        if length(itm) >= 4 then name = itm[4] end if
        html &= sprintf("  <ui5-timeline-item title-text=\"%s\"", {escape_html(title)})
        if length(sub) > 0 then html &= sprintf(" subtitle-text=\"%s\"", {escape_html(sub)}) end if
        if length(icn) > 0 then html &= sprintf(" icon=\"%s\"", {icn}) end if
        if length(name) > 0 then html &= sprintf(" name=\"%s\"", {escape_html(name)}) end if
        html &= "></ui5-timeline-item>\n"
    end for
    html &= "</ui5-timeline>\n"
    return html
end function

--**
-- Construct a <ui5-illustrated-message> empty-state indicator.
public function illustrated_message(sequence name = "NoData", sequence title_text = "Keine Daten vorhanden",
                                    sequence subtitle_text = "", sequence options = {})
    sequence html = sprintf("<ui5-illustrated-message name=\"%s\" title-text=\"%s\"",
                            {name, escape_html(title_text)})
    if length(subtitle_text) > 0 then
        html &= sprintf(" subtitle-text=\"%s\"", {escape_html(subtitle_text)})
    end if
    html &= "></ui5-illustrated-message>\n"
    return html
end function

-- =============================================================================
-- 5. Reactive Patch & Bridge Helpers
-- =============================================================================

public function patch(sequence id, sequence html)
    return {{"type", "patch"}, {"id", id}, {"html", html}}
end function

public function append_html(sequence id, sequence html)
    return {{"type", "append"}, {"id", id}, {"html", html}}
end function

public function set_val(sequence id, sequence value)
    return {{"type", "setValue"}, {"id", id}, {"val", value}}
end function

public function set_value_state(sequence id, sequence state, sequence message = "")
    return {{"type", "setValueState"}, {"id", id}, {"state", state}, {"message", message}}
end function

public function toast_show(sequence id, sequence text = "")
    return {{"type", "toast"}, {"id", id}, {"text", text}}
end function

public function open_dialog(sequence id)
    return {{"type", "dialogOpen"}, {"id", id}}
end function

public function close_dialog(sequence id)
    return {{"type", "dialogClose"}, {"id", id}}
end function

public function redirect(sequence url)
    return {{"type", "redirect"}, {"url", url}}
end function

public function updates(sequence patches_list)
    sequence out_arr = {}
    for i = 1 to length(patches_list) do
        sequence p = patches_list[i]
        out_arr = append(out_arr, {json:JSON_OBJECT, p})
    end for
    return {200, json:encode({json:JSON_ARRAY, out_arr}), "application/json; charset=utf-8"}
end function

public function val(sequence ctx, sequence key, sequence default_val = "")
    for i = 1 to length(ctx) do
        if sequence(ctx[i]) and length(ctx[i]) >= 2 and equal(ctx[i][1], key) then
            if sequence(ctx[i][2]) then
                return ctx[i][2]
            else
                return sprintf("%d", ctx[i][2])
            end if
        end if
    end for
    return default_val
end function

-- =============================================================================
-- 6. Application Lifecycle & HTTP Server Integration
-- =============================================================================

public function app(sequence title, integer port = 8080,
                    sequence theme = THEME_HORIZON,
                    sequence version = DEFAULT_VERSION,
                    sequence cdn = DEFAULT_CDN_BASE)
    sequence instance = {
        title,          -- APP_TITLE
        port,           -- APP_PORT
        theme,          -- APP_THEME
        version,        -- APP_VERSION
        cdn,            -- APP_CDN_BASE
        -1,             -- APP_SRV_ID
        {},             -- APP_PAGES
        {},             -- APP_ACTIONS
        0               -- APP_RUNNING
    }
    registered_apps = append(registered_apps, instance)
    return length(registered_apps)
end function

public procedure page_route(integer app_id, sequence path, integer handler_rid)
    if app_id < 1 or app_id > length(registered_apps) then return end if
    registered_apps[app_id][APP_PAGES] = append(registered_apps[app_id][APP_PAGES], {path, handler_rid})
end procedure

public procedure action(integer app_id, sequence action_name, integer handler_rid)
    if app_id < 1 or app_id > length(registered_apps) then return end if
    registered_apps[app_id][APP_ACTIONS] = append(registered_apps[app_id][APP_ACTIONS], {action_name, handler_rid})
end procedure

function internal_route_handler(sequence req)
    sequence req_path = req[http:REQ_PATH]
    sequence req_method = req[http:REQ_METHOD]

    for a = 1 to length(registered_apps) do
        sequence app_inst = registered_apps[a]
        if equal(req_method, "GET") then
            sequence pages = app_inst[APP_PAGES]
            for p = 1 to length(pages) do
                if equal(pages[p][1], req_path) then
                    integer rid = pages[p][2]
                    object page_content = call_func(rid, {req})
                    if sequence(page_content) and length(page_content) >= 3 and
                       integer(page_content[1]) and sequence(page_content[2]) and sequence(page_content[3]) then
                        return page_content
                    end if
                    return http:response(200, to_content_string(page_content), "text/html; charset=utf-8")
                end if
            end for
        elsif equal(req_method, "POST") and equal(req_path, "/__ui5_action") then
            sequence body_str = req[http:REQ_BODY]
            object parsed = json:parse(body_str)
            if sequence(parsed) and length(parsed) = 2 and parsed[1] = 1 then
                object doc = parsed[2]
                sequence act_name = json:get(doc, "action", "")
                object raw_values = json:get(doc, "values", 0)
                sequence values_list = {}
                if json:is_object(raw_values) then
                    sequence pairs = raw_values[2]
                    for k = 1 to length(pairs) do
                        sequence pair = pairs[k]
                        if sequence(pair) and length(pair) = 2 and sequence(pair[1]) then
                            sequence v_str = ""
                            object unwrapped_val = json:unwrap(pair[2])
                            if sequence(unwrapped_val) then
                                v_str = unwrapped_val
                            elsif atom(unwrapped_val) then
                                v_str = sprintf("%g", unwrapped_val)
                            end if
                            values_list = append(values_list, {pair[1], v_str})
                        end if
                    end for
                end if
                sequence actions = app_inst[APP_ACTIONS]
                for x = 1 to length(actions) do
                    if equal(actions[x][1], act_name) then
                        integer act_rid = actions[x][2]
                        object res = call_func(act_rid, {values_list})
                        if sequence(res) and length(res) >= 3 and integer(res[1]) then
                            return res
                        end if
                        return http:response_json(200, res)
                    end if
                end for
                return http:response_json(404, `{"error":"action not found"}`)
            end if
            return http:response_json(400, `{"error":"invalid json"}`)
        end if
    end for

    return http:response(404, "<h1>404 Not Found (Euphorix UI5)</h1>", "text/html; charset=utf-8")
end function

public function init_server(integer app_id)
    if app_id < 1 or app_id > length(registered_apps) then return -1 end if
    integer port = registered_apps[app_id][APP_PORT]
    integer srv = http:server_create("0.0.0.0", port)
    if srv <= 0 then return srv end if
    registered_apps[app_id][APP_SRV_ID] = srv
    integer handler_rid = routine_id("internal_route_handler")
    http:route(srv, "*", "*", handler_rid)
    return srv
end function

public procedure run(integer app_id)
    if app_id < 1 or app_id > length(registered_apps) then return end if
    integer srv = init_server(app_id)
    if srv <= 0 then
        printf(2, "FEHLER: UI5 Server konnte auf Port %d nicht gestartet werden!\n",
               {registered_apps[app_id][APP_PORT]})
        return
    end if
    printf(1, "=====================================================================\n")
    printf(1, "  Euphorix SAP UI5 Server läuft auf http://127.0.0.1:%d/\n",
           {registered_apps[app_id][APP_PORT]})
    printf(1, "  Morning Horizon Theme: %s | UI5 Version: %s\n",
           {registered_apps[app_id][APP_THEME], registered_apps[app_id][APP_VERSION]})
    printf(1, "  Beenden mit Ctrl+C\n")
    printf(1, "=====================================================================\n")
    http:serve_forever(srv)
end procedure
