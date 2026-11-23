--****
-- == VS-UI / CGIBASH-HTML Framework for Euphorix (std/vsui.e)
--
-- Alternative, lightweight enterprise Web-UI library based on Volker Schulte's
-- cgibash/html framework (/home/volkix/prj/cgibash/html).
--
-- Features:
-- * Zero external dependencies: Uses native ES6 modules, `ldom.js`, and `vsevent.js`.
-- * High-density enterprise styling (vs.css & globalblauklein.css) with compact layouts,
--   monospace / clear typography, and custom CSS variables (--vs-blau, --vs-gruen).
-- * Full component suite: vsbutton, vsinput, vsnuminput, vsdateinput, vstimeinput,
--   vscheck, vstextarea, vscombo, vslabel, vsgroup, vspanel, vscollapse, vsgrid (DataGrid
--   with sticky headers & live search), vstabs, vsmodal, vstoast, vssplitter, vstreeview.
-- * Built-in static file server directly serving /lib2/*, /css/*, /img/*, /app/* from
--   the local /home/volkix/prj/cgibash/html repository.
-- * Reactive Event-Bridge connecting frontend `vsevent` ("button_click", "changevalue")
--   directly to OpenEuphoria `routine_id` handlers with live DOM patches (`vsui:patch()`,
--   `vsui:set_val()`, `vsui:toast_show()`, `vsui:modal_open()`).
--

namespace vsui

include std/http.e as http
include std/json.e as json
include std/io.e as io
include std/filesys.e as filesys
include std/text.e as text

-- =============================================================================
-- 1. Constants & Configuration
-- =============================================================================

public constant
    DEFAULT_STATIC_DIR = "/home/volkix/prj/intpret/html",
    DEFAULT_PORT       = 8089

public constant
    TOAST_INFO    = "info",
    TOAST_SUCCESS = "success",
    TOAST_WARNING = "warning",
    TOAST_ERROR   = "error"

-- Internal App Structure:
-- {title, port, static_dir, srv_id, pages_map, events_map, running}
public constant
    APP_TITLE      = 1,
    APP_PORT       = 2,
    APP_STATIC_DIR = 3,
    APP_SRV_ID     = 4,
    APP_PAGES      = 5,
    APP_EVENTS     = 6,
    APP_RUNNING    = 7

sequence registered_apps = {}

-- =============================================================================
-- 2. Internal Helpers
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

function iff(integer cond, object true_val, object false_val)
    if cond then return true_val else return false_val end if
end function

function get_mime_type(sequence file_path)
    sequence ext = filesys:fileext(file_path)
    sequence lower_ext = ""
    for i = 1 to length(ext) do
        integer c = ext[i]
        if c >= 'A' and c <= 'Z' then c += 32 end if
        lower_ext &= c
    end for

    if equal(lower_ext, "js") or equal(lower_ext, "mjs") then
        return "application/javascript; charset=utf-8"
    elsif equal(lower_ext, "css") then
        return "text/css; charset=utf-8"
    elsif equal(lower_ext, "html") or equal(lower_ext, "htm") then
        return "text/html; charset=utf-8"
    elsif equal(lower_ext, "json") then
        return "application/json; charset=utf-8"
    elsif equal(lower_ext, "jpeg") or equal(lower_ext, "jpg") then
        return "image/jpeg"
    elsif equal(lower_ext, "png") then
        return "image/png"
    elsif equal(lower_ext, "gif") then
        return "image/gif"
    elsif equal(lower_ext, "svg") then
        return "image/svg+xml"
    elsif equal(lower_ext, "ico") then
        return "image/x-icon"
    elsif equal(lower_ext, "woff2") then
        return "font/woff2"
    elsif equal(lower_ext, "woff") then
        return "font/woff"
    elsif equal(lower_ext, "txt") then
        return "text/plain; charset=utf-8"
    else
        return "application/octet-stream"
    end if
end function

-- =============================================================================
-- 3. Page Builder & Client Runtime
-- =============================================================================

function get_client_bridge_js()
    return `<script type="module">
import { e, _, n } from "/lib2/ldom.js";
import * as ui from "/lib2/ui.js";
import vsevent from "/lib2/vsevent.js";

window._vs_e = e;
window._vs__ = _;
window._vs_n = n;
window._vs_ui = ui;
window._vs_vsevent = vsevent;

// Dispatch event from frontend to Euphorix backend
window.sendVsEvent = function(eventName, eventData) {
  var data = Object.assign({}, eventData || {});
  
  // Collect input values (utilizing getValue() if component supports it)
  document.querySelectorAll('input.vs-input, input.vs-check, select.vs-combo, textarea.vs-textarea').forEach(function(el) {
    if (el.id) {
      if (typeof el.getValue === 'function') {
        data[el.id] = el.getValue();
      } else if (el.type === 'checkbox' || el.type === 'radio') {
        data[el.id] = el.checked ? '1' : '0';
      } else {
        data[el.id] = el.value;
      }
    }
  });

  fetch('/__vs_event', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
    body: JSON.stringify({ event: eventName, data: data })
  })
  .then(function(res) { return res.json(); })
  .then(function(patches) {
    if (!Array.isArray(patches)) patches = [patches];
    patches.forEach(function(p) {
      if (!p || !p.type) return;
      if (p.type === 'patch') {
        var target = document.getElementById(p.id);
        if (target) target.innerHTML = p.html;
      } else if (p.type === 'append') {
        var target = document.getElementById(p.id);
        if (target) target.insertAdjacentHTML('beforeend', p.html);
      } else if (p.type === 'setValue') {
        var target = document.getElementById(p.id);
        if (target) {
          target.value = p.val;
          if (typeof target.setValue === 'function') target.setValue(p.val);
        }
      } else if (p.type === 'setFocus') {
        var target = document.getElementById(p.id);
        if (target && typeof target.focus === 'function') target.focus();
      } else if (p.type === 'setEnabled') {
        var target = document.getElementById(p.id);
        if (target) {
          target.disabled = !p.enabled;
          if (p.enabled) target.removeAttribute('disabled');
          else target.setAttribute('disabled', 'disabled');
        }
      } else if (p.type === 'setVisible') {
        var target = document.getElementById(p.id);
        if (target) {
          target.style.display = p.visible ? '' : 'none';
        }
      } else if (p.type === 'setCss') {
        var target = document.getElementById(p.id);
        if (target && target.style) {
          target.style[p.prop] = p.val;
        }
      } else if (p.type === 'setClass') {
        var target = document.getElementById(p.id);
        if (target && target.classList) {
          if (p.action === 'remove') target.classList.remove(p.cls);
          else if (p.action === 'toggle') target.classList.toggle(p.cls);
          else target.classList.add(p.cls);
        }
      } else if (p.type === 'clearForm') {
        var container = (p.id && p.id.length > 0) ? document.getElementById(p.id) : document;
        if (container) {
          container.querySelectorAll('input.vs-input, input.vs-check, select.vs-combo, textarea.vs-textarea').forEach(function(el) {
            if (typeof el.setValue === 'function') {
              el.setValue('');
            } else if (el.type === 'checkbox' || el.type === 'radio') {
              el.checked = false;
            } else {
              el.value = '';
            }
          });
        }
      } else if (p.type === 'gridSetData') {
        var grid = document.getElementById(p.id);
        if (grid && typeof grid.setData === 'function') {
          grid.setData(p.data);
        } else {
          var targetTable = document.getElementById(p.id + '_data') || (grid && grid.querySelector('table.vs-table')) || grid;
          if (targetTable) {
            var tbody = targetTable.querySelector('tbody') || targetTable;
            var html = '';
            var rows = Array.isArray(p.data) ? p.data : [];
            for (var r = 0; r < rows.length; r++) {
              var row = rows[r];
              var trCls = (r % 2 === 0) ? 'vs-tbody-tr even' : 'vs-tbody-tr odd';
              html += '<tr class="' + trCls + '">';
              if (Array.isArray(row)) {
                for (var c = 0; c < row.length; c++) {
                  var cellVal = (row[c] !== null && row[c] !== undefined) ? row[c] : '';
                  var th = document.querySelector('#' + p.id + '_head th:nth-child(' + (c + 1) + ')');
                  var lbl = th ? th.textContent.trim() : '';
                  html += '<td class="vs-tbody-td"' + (lbl ? ' data-label="' + lbl + '"' : '') + '>' + cellVal + '</td>';
                }
              } else if (typeof row === 'object' && row !== null) {
                var keys = Object.keys(row);
                for (var c = 0; c < keys.length; c++) {
                  var cellVal = (row[keys[c]] !== null && row[keys[c]] !== undefined) ? row[keys[c]] : '';
                  html += '<td class="vs-tbody-td" data-label="' + keys[c] + '">' + cellVal + '</td>';
                }
              }
              html += '</tr>';
            }
            tbody.innerHTML = html;
          }
        }
      } else if (p.type === 'toast') {
        if (typeof ui.vstoast === 'function') {
          ui.vstoast(p.text, p.toast_type || 'info', p.duration || 3000);
        } else {
          var t = document.createElement('div');
          t.className = 'vs-toast vs-toast-' + (p.toast_type || 'info') + ' show';
          t.textContent = p.text;
          document.body.appendChild(t);
          setTimeout(function() { t.remove(); }, p.duration || 3000);
        }
      } else if (p.type === 'modalOpen') {
        var m = document.getElementById(p.id);
        if (m) m.style.display = 'flex';
      } else if (p.type === 'modalClose') {
        var m = document.getElementById(p.id);
        if (m) m.style.display = 'none';
      } else if (p.type === 'redirect') {
        window.location.href = p.url;
      }
    });
  })
  .catch(function(err) { console.error('Euphorix VS-UI Bridge Error:', err); });
};

// Wire up global click on .vs-button elements
document.addEventListener('click', function(ev) {
  var btn = ev.target.closest('.vs-button, [data-vs-click]');
  if (btn) {
    var clickAction = btn.getAttribute('data-vs-click') || btn.id;
    var params = { id: btn.id, action: clickAction };
    for (var i = 0; i < btn.attributes.length; i++) {
      var a = btn.attributes[i];
      if (a.name.indexOf('data-param-') === 0) {
        params[a.name.substring(11)] = a.value;
      }
    }
    window.sendVsEvent('button_click', params);
  }

  var closeBtn = ev.target.closest('[data-vs-close]');
  if (closeBtn) {
    var modalId = closeBtn.getAttribute('data-vs-close');
    var m = document.getElementById(modalId);
    if (m) m.style.display = 'none';
  }
});

// Wire up change on input and combo
document.addEventListener('change', function(ev) {
  var inp = ev.target.closest('.vs-input, .vs-check, .vs-combo');
  if (inp && inp.id) {
    window.sendVsEvent('changevalue', { id: inp.id, value: inp.value });
  }
});

// Forward vsevent events if triggered via JS
vsevent.handle("button_click", function(mid) {
  if (mid && mid.id) window.sendVsEvent("button_click", mid);
});
</script>`
end function

--**
-- Construct a complete HTML5 page styled with the user's `cgibash/html` framework.
public function page(sequence title, object content, sequence options = {})
    sequence cont_id = get_opt(options, "container_id", "cont")
    sequence extra_head = get_opt(options, "head", "")
    sequence body_html = to_content_string(content)

    sequence doc = `<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>` & escape_html(title) & `</title>
  <link rel="stylesheet" href="/css/vs.css">
  <link rel="stylesheet" href="/css/globalblauklein.css">
  <link rel="stylesheet" href="/css/vs-mobile.css">
  ` & extra_head & `
</head>
<body>
  <div id="` & cont_id & `">
` & body_html & `
  </div>
` & get_client_bridge_js() & `
</body>
</html>`
    return doc
end function

-- =============================================================================
-- 4. Component Builders (Matching cgibash/html & globalblauklein.css)
-- =============================================================================

--**
-- Construct a .vs-button.
public function button(sequence id, sequence text, sequence options = {})
    sequence action = get_opt(options, "action", id)
    sequence style  = get_opt(options, "style", "")
    integer disabled = equal(get_opt(options, "disabled", "0"), "1")

    sequence html = sprintf("<button id=\"%s\" class=\"vs-button\" data-vs-click=\"%s\"", {id, action})
    if length(style) > 0 then html &= sprintf(" style=\"%s\"", {style}) end if
    if disabled then html &= " disabled" end if

    for i = 1 to length(options) do
        if sequence(options[i]) and length(options[i]) >= 2 then
            sequence k = options[i][1]
            if length(k) > 11 and equal(k[1..11], "data-param-") then
                html &= sprintf(" %s=\"%s\"", {k, escape_html(options[i][2])})
            end if
        end if
    end for

    html &= sprintf(">%s</button>", {escape_html(text)})
    return html
end function

--**
-- Construct an input.vs-input text field.
public function input(sequence id, sequence value = "", sequence options = {})
    sequence ph    = get_opt(options, "placeholder", "")
    sequence style = get_opt(options, "style", "")
    sequence itype = get_opt(options, "type", "text")
    integer readonly = equal(get_opt(options, "readonly", "0"), "1")

    sequence html = sprintf("<input id=\"%s\" class=\"vs-input\" type=\"%s\" value=\"%s\"",
                            {id, itype, escape_html(value)})
    if length(ph) > 0 then html &= sprintf(" placeholder=\"%s\"", {escape_html(ph)}) end if
    if length(style) > 0 then html &= sprintf(" style=\"%s\"", {style}) end if
    if readonly then html &= " readonly" end if
    html &= " />"
    return html
end function

--**
-- Construct a numeric input.vs-input.
public function numinput(sequence id, atom value = 0, sequence options = {})
    sequence style = get_opt(options, "style", "")
    return sprintf("<input id=\"%s\" class=\"vs-input\" type=\"number\" value=\"%g\" style=\"%s\" />",
                   {id, value, style})
end function

--**
-- Construct a date input.vs-input.
public function dateinput(sequence id, sequence value = "", sequence options = {})
    sequence style = get_opt(options, "style", "")
    return sprintf("<input id=\"%s\" class=\"vs-input\" type=\"date\" value=\"%s\" style=\"%s\" />",
                   {id, escape_html(value), style})
end function

--**
-- Construct a time input.vs-input.
public function timeinput(sequence id, sequence value = "", sequence options = {})
    sequence style = get_opt(options, "style", "")
    return sprintf("<input id=\"%s\" class=\"vs-input\" type=\"time\" value=\"%s\" style=\"%s\" />",
                   {id, escape_html(value), style})
end function

--**
-- Construct an input.vs-check checkbox with label.
public function check(sequence id, sequence label_text, integer checked = 0, sequence options = {})
    sequence html = sprintf("<label class=\"vs-label\" style=\"display:inline-flex; align-items:center; gap:4px; cursor:pointer;\">" &
                            "<input id=\"%s\" class=\"vs-check\" type=\"checkbox\"%s /><span>%s</span></label>",
                            {id, iff(checked, " checked", ""), escape_html(label_text)})
    return html
end function

--**
-- Construct a textarea.vs-input.
public function textarea(sequence id, sequence value = "", integer rows = 4, sequence options = {})
    sequence ph    = get_opt(options, "placeholder", "")
    sequence style = get_opt(options, "style", "height:auto; min-height:80px;")
    return sprintf("<textarea id=\"%s\" class=\"vs-input\" rows=\"%d\" placeholder=\"%s\" style=\"%s\">%s</textarea>",
                   {id, rows, escape_html(ph), style, escape_html(value)})
end function

--**
-- Construct a select.vs-combo dropdown.
public function combo(sequence id, sequence options_list, sequence selected_val = "", sequence options = {})
    sequence style = get_opt(options, "style", "")
    sequence html = sprintf("<select id=\"%s\" class=\"vs-input vs-combo\"", {id})
    if length(style) > 0 then html &= sprintf(" style=\"%s\"", {style}) end if
    html &= ">\n"
    for i = 1 to length(options_list) do
        sequence itm = options_list[i]
        sequence opt_val = itm[1]
        sequence opt_lbl = itm[2]
        integer is_sel = equal(opt_val, selected_val)
        if length(itm) >= 3 and is_sel = 0 then is_sel = itm[3] end if
        html &= sprintf("  <option value=\"%s\"%s>%s</option>\n",
                        {escape_html(opt_val), iff(is_sel, " selected", ""), escape_html(opt_lbl)})
    end for
    html &= "</select>"
    return html
end function

--**
-- Construct a label.vs-label.
public function ui_label(sequence text, sequence for_id = "", sequence options = {})
    sequence style = get_opt(options, "style", "")
    sequence html = "<label class=\"vs-label\""
    if length(for_id) > 0 then html &= sprintf(" for=\"%s\"", {for_id}) end if
    if length(style) > 0 then html &= sprintf(" style=\"%s\"", {style}) end if
    html &= sprintf(">%s</label>", {escape_html(text)})
    return html
end function

--**
-- Construct a fieldset.vs-group container.
public function group(sequence legend_text, object content, sequence options = {})
    sequence style = get_opt(options, "style", "margin: 8px 0; padding: 10px; border: 1px solid silver;")
    sequence html = sprintf("<fieldset class=\"vs-group\" style=\"%s\">\n", {style})
    html &= sprintf("  <legend class=\"vs-legend\" style=\"padding: 0 6px; font-weight: bold; color: var(--vs-blau, #41518b);\">%s</legend>\n",
                    {escape_html(legend_text)})
    html &= to_content_string(content)
    html &= "\n</fieldset>\n"
    return html
end function

--**
-- Construct a .vs-panel container.
public function panel(sequence id, sequence title, object content, sequence options = {})
    sequence style = get_opt(options, "style", "margin-bottom: 12px;")
    sequence html = sprintf("<div id=\"%s\" class=\"vs-panel\" style=\"%s\">\n", {id, style})
    html &= sprintf("  <div class=\"vs-panel-header\" style=\"padding: 6px 12px; font-weight: bold;\">%s</div>\n",
                    {escape_html(title)})
    html &= "  <div class=\"vs-panel-content\" style=\"padding: 12px; background: white;\">\n"
    html &= to_content_string(content)
    html &= "\n  </div>\n</div>\n"
    return html
end function

--**
-- Construct a .vscollapse collapsible details section.
public function collapse(sequence id, sequence sections, integer open_first = 1, sequence options = {})
    sequence html = sprintf("<div id=\"%s\" class=\"vs-collapse\">\n", {id})
    for i = 1 to length(sections) do
        sequence sec = sections[i]
        sequence hdr = sec[1]
        object inhalt = sec[2]
        integer is_open = iff(i = 1 and open_first, 1, 0)
        if length(sec) >= 3 then is_open = sec[3] end if
        html &= sprintf("  <details class=\"vscollapsedetail\"%s style=\"margin-bottom: 4px;\">\n",
                        {iff(is_open, " open", "")})
        html &= sprintf("    <summary class=\"vscollapsesummary\" style=\"padding: 6px 10px; cursor: pointer; background: var(--vs-blau, #41518b); color: white; font-weight: bold;\">%s</summary>\n",
                        {escape_html(hdr)})
        html &= "    <div class=\"detailbox\" style=\"padding: 10px; border: 1px solid silver; border-top: none; background: white;\">\n"
        html &= to_content_string(inhalt)
        html &= "\n    </div>\n  </details>\n"
    end for
    html &= "</div>\n"
    return html
end function

--**
-- Construct a vsgrid (DataGrid matching `vsgrid.js`).
-- Features sticky header, live search, alternating row styling, and mobile responsive card-views.
public function grid(sequence id, sequence columns, sequence rows, sequence options = {})
    sequence style = get_opt(options, "style", "width: 100%; border-collapse: collapse;")
    sequence filter_fn_name = "filterVsGrid_" & id

    sequence html = sprintf("<div id=\"%s_container\" class=\"vsgrid-container\" style=\"overflow:auto; max-height:480px; position:relative;\">\n", {id})
    
    -- Live search input
    html &= sprintf("  <input type=\"text\" class=\"vs-spreadsheet-search\" placeholder=\" Suchen...\" " &
                    "style=\"position:sticky; top:0; z-index:10; width:100%%; box-sizing:border-box; margin-bottom:2px;\" " &
                    "oninput=\"%s(this.value)\" />\n", {filter_fn_name})

    -- Header table (sticky)
    html &= sprintf("  <table id=\"%s_head\" class=\"vs-table-sticky\" style=\"%s position:sticky; top:28px; z-index:9; background:var(--vs-blau,#41518b); color:white;\">\n",
                    {id, style})
    html &= "    <thead>\n      <tr class=\"vs-thead-tr\">\n"
    sequence col_titles = {}
    for i = 1 to length(columns) do
        sequence col_name = ""
        sequence col_width = ""
        if sequence(columns[i]) and length(columns[i]) >= 1 and sequence(columns[i][1]) then
            col_name = columns[i][1]
            if length(columns[i]) >= 2 then col_width = columns[i][2] end if
        else
            col_name = to_content_string(columns[i])
        end if
        col_titles = append(col_titles, col_name)
        html &= "        <th class=\"vs-thead-th\""
        if length(col_width) > 0 then html &= sprintf(" style=\"width: %s;\"", {col_width}) end if
        html &= sprintf(">%s</th>\n", {escape_html(col_name)})
    end for
    html &= "      </tr>\n    </thead>\n  </table>\n"

    -- Data table (with responsive card styling on mobile)
    html &= sprintf("  <table id=\"%s_data\" class=\"vs-table vs-table-responsive\" style=\"%s\">\n    <tbody>\n", {id, style})
    for r = 1 to length(rows) do
        sequence row = rows[r]
        sequence tr_cls = iff(remainder(r, 2) = 0, "vs-tbody-tr even", "vs-tbody-tr odd")
        html &= sprintf("      <tr class=\"%s\">\n", {tr_cls})
        for c = 1 to length(row) do
            sequence col_title = ""
            if c <= length(col_titles) then
                col_title = col_titles[c]
            end if
            html &= sprintf("        <td class=\"vs-tbody-td\" data-label=\"%s\">%s</td>\n",
                            {escape_html(col_title), to_content_string(row[c])})
        end for
        html &= "      </tr>\n"
    end for
    html &= "    </tbody>\n  </table>\n"

    -- Client-side instant filter script
    html &= sprintf("<script>\nfunction %s(q) {\n" &
                    "  var rows = document.querySelectorAll('#%s_data tbody tr');\n" &
                    "  var filter = (q || '').toLowerCase();\n" &
                    "  rows.forEach(function(tr) {\n" &
                    "    var text = tr.textContent.toLowerCase();\n" &
                    "    tr.style.display = (filter === '' || text.indexOf(filter) !== -1) ? '' : 'none';\n" &
                    "  });\n" &
                    "}\n</script>\n", {filter_fn_name, id})

    html &= "</div>\n"
    return html
end function

--**
-- Construct a .vs-tabs component.
public function tabs(sequence id, sequence tabs_list, sequence options = {})
    sequence html = sprintf("<div id=\"%s\" class=\"vs-tabs\">\n", {id})
    html &= "  <div class=\"vs-tab-headers\" style=\"display:flex; gap:2px; border-bottom:2px solid var(--vs-blau, #41518b);\">\n"
    for i = 1 to length(tabs_list) do
        sequence t = tabs_list[i]
        sequence title = t[1]
        integer is_act = iff(i = 1, 1, 0)
        if length(t) >= 3 then is_act = t[3] end if
        html &= sprintf("    <button type=\"button\" class=\"vs-tab-btn%s\" style=\"padding:6px 14px; cursor:pointer; font-weight:bold;\" " &
                        "onclick=\"(function(btn){" &
                        "  var p=btn.closest('.vs-tabs');" &
                        "  p.querySelectorAll('.vs-tab-btn').forEach(function(b){b.classList.remove('active');});" &
                        "  p.querySelectorAll('.vs-tab-pane').forEach(function(pan){pan.style.display='none';});" &
                        "  btn.classList.add('active');" &
                        "  p.querySelector('#%s_pane_%d').style.display='block';" &
                        "})(this)\">%s</button>\n",
                        {iff(is_act, " active", ""), id, i, escape_html(title)})
    end for
    html &= "  </div>\n  <div class=\"vs-tab-contents\" style=\"padding:12px; background:white; border:1px solid silver; border-top:none;\">\n"
    for i = 1 to length(tabs_list) do
        sequence t = tabs_list[i]
        object cnt = t[2]
        integer is_act = iff(i = 1, 1, 0)
        if length(t) >= 3 then is_act = t[3] end if
        html &= sprintf("    <div id=\"%s_pane_%d\" class=\"vs-tab-pane%s\" style=\"display:%s;\">%s</div>\n",
                        {id, i, iff(is_act, " active", ""), iff(is_act, "block", "none"), to_content_string(cnt)})
    end for
    html &= "  </div>\n</div>\n"
    return html
end function

--**
-- Construct a .vs-modal dialog overlay.
public function modal(sequence id, sequence title, object content, object footer_buttons = {}, sequence options = {})
    sequence html = sprintf("<div id=\"%s\" class=\"blocker\" style=\"display:none; position:fixed; top:0; left:0; width:100vw; height:100vh; " &
                            "background:rgba(0,0,0,0.5); z-index:9999; align-items:center; justify-content:center;\">\n", {id})
    html &= "  <div class=\"vs-panel\" style=\"background:white; border:2px solid var(--vs-blau,#41518b); width:90%; max-width:560px; box-shadow:0 6px 20px rgba(0,0,0,0.4);\">\n"
    html &= sprintf("    <div class=\"vs-panel-header\" style=\"display:flex; justify-content:space-between; align-items:center; padding:8px 12px; background:var(--vs-blau,#41518b); color:white;\">\n" &
                    "      <span>%s</span><button type=\"button\" data-vs-close=\"%s\" style=\"all:unset; cursor:pointer; font-weight:bold; font-size:16px;\">✕</button>\n" &
                    "    </div>\n", {escape_html(title), id})
    html &= sprintf("    <div class=\"vs-panel-content\" style=\"padding:16px; font-size:13px; line-height:1.5;\">%s</div>\n",
                    {to_content_string(content)})
    if length(to_content_string(footer_buttons)) > 0 then
        html &= sprintf("    <div style=\"padding:8px 12px; background:#f5f5f5; border-top:1px solid silver; display:flex; justify-content:flex-end; gap:8px;\">%s</div>\n",
                        {to_content_string(footer_buttons)})
    end if
    html &= "  </div>\n</div>\n"
    return html
end function

--**
-- Construct a .vs-splitter container with left & right panes.
public function splitter(sequence id, object left_content, object right_content, integer split_pct = 50, sequence options = {})
    sequence html = sprintf("<div id=\"%s\" class=\"vs-splitter-container\" style=\"display:flex; width:100%%; min-height:400px; border:1px solid silver;\">\n", {id})
    html &= sprintf("  <div class=\"vs-splitter-pane\" style=\"width:%d%%; padding:10px; overflow:auto;\">%s</div>\n",
                    {split_pct, to_content_string(left_content)})
    html &= "  <div class=\"vs-splitter-bar\" style=\"width:6px; background:#e0e0e0; cursor:col-resize;\"></div>\n"
    html &= sprintf("  <div class=\"vs-splitter-pane\" style=\"width:%d%%; padding:10px; overflow:auto;\">%s</div>\n",
                    {100 - split_pct, to_content_string(right_content)})
    html &= "</div>\n"
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

--**
-- Send updated data rows to a vsgrid component or table,
-- causing it to re-render smoothly without rebuilding the entire page.
public function grid_set_data(sequence id, sequence data)
    return {{"type", "gridSetData"}, {"id", id}, {"data", data}}
end function

--**
-- Set input focus to the specified element ID.
public function set_focus(sequence id)
    return {{"type", "setFocus"}, {"id", id}}
end function

--**
-- Enable or disable an input or button element.
public function set_enabled(sequence id, integer is_enabled)
    return {{"type", "setEnabled"}, {"id", id}, {"enabled", is_enabled}}
end function

--**
-- Show or hide an element (via display: none vs display: '').
public function set_visible(sequence id, integer is_visible)
    return {{"type", "setVisible"}, {"id", id}, {"visible", is_visible}}
end function

--**
-- Set a specific CSS style property on an element (e.g., border-color, color, background).
public function set_css(sequence id, sequence prop, sequence val)
    return {{"type", "setCss"}, {"id", id}, {"prop", prop}, {"val", val}}
end function

--**
-- Add, remove, or toggle a CSS class on an element (action: "add", "remove", or "toggle").
public function set_class(sequence id, sequence class_name, sequence action = "add")
    return {{"type", "setClass"}, {"id", id}, {"cls", class_name}, {"action", action}}
end function

--**
-- Clear all input, select, and textarea values within a container (or entire page if empty).
public function clear_form(sequence container_id = "")
    return {{"type", "clearForm"}, {"id", container_id}}
end function

public function toast_show(sequence text, sequence toast_type = TOAST_INFO, integer duration = 3000)
    return {{"type", "toast"}, {"text", text}, {"toast_type", toast_type}, {"duration", duration}}
end function

public function modal_open(sequence id)
    return {{"type", "modalOpen"}, {"id", id}}
end function

public function modal_close(sequence id)
    return {{"type", "modalClose"}, {"id", id}}
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

function resolve_static_dir(sequence given_dir)
    if length(given_dir) > 0 and filesys:file_exists(given_dir & "/lib2/ldom.js") then
        return given_dir
    end if
    -- Check local relative directory: html
    if filesys:file_exists("html/lib2/ldom.js") then
        return filesys:canonical_path("html")
    end if
    -- Check intpret repository
    if filesys:file_exists("/home/volkix/prj/intpret/html/lib2/ldom.js") then
        return "/home/volkix/prj/intpret/html"
    end if
    -- Fallback to cgibash/html if present
    if filesys:file_exists("/home/volkix/prj/cgibash/html/lib2/ldom.js") then
        return "/home/volkix/prj/cgibash/html"
    end if
    return given_dir
end function

public function app(sequence title, integer port = DEFAULT_PORT, sequence static_dir = DEFAULT_STATIC_DIR)
    sequence resolved_dir = resolve_static_dir(static_dir)
    sequence instance = {
        title,          -- APP_TITLE
        port,           -- APP_PORT
        resolved_dir,   -- APP_STATIC_DIR
        -1,             -- APP_SRV_ID
        {},             -- APP_PAGES
        {},             -- APP_EVENTS
        0               -- APP_RUNNING
    }
    registered_apps = append(registered_apps, instance)
    return length(registered_apps)
end function

public procedure page_route(integer app_id, sequence path, integer handler_rid)
    if app_id < 1 or app_id > length(registered_apps) then return end if
    registered_apps[app_id][APP_PAGES] = append(registered_apps[app_id][APP_PAGES], {path, handler_rid})
end procedure

public procedure on_event(integer app_id, sequence event_name, integer handler_rid)
    if app_id < 1 or app_id > length(registered_apps) then return end if
    registered_apps[app_id][APP_EVENTS] = append(registered_apps[app_id][APP_EVENTS], {event_name, handler_rid})
end procedure

public procedure on_click(integer app_id, sequence button_id, integer handler_rid)
    on_event(app_id, button_id, handler_rid)
end procedure

function internal_route_handler(sequence req)
    sequence req_path = req[http:REQ_PATH]
    sequence req_method = req[http:REQ_METHOD]

    for a = 1 to length(registered_apps) do
        sequence app_inst = registered_apps[a]
        sequence static_dir = app_inst[APP_STATIC_DIR]

        -- 1. Check custom page routes (GET)
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

            -- 2. Serve static files from static_dir (/lib2/*, /css/*, /img/*, /app/*)
            sequence target_file = static_dir & req_path
            if filesys:file_exists(target_file) then
                object file_bytes = io:read_file(target_file)
                if sequence(file_bytes) then
                    sequence mime = get_mime_type(target_file)
                    return http:response(200, file_bytes, mime, {{"Cache-Control", "no-cache"}})
                end if
            end if
        elsif equal(req_method, "POST") and equal(req_path, "/__vs_event") then
            sequence body_str = req[http:REQ_BODY]
            object parsed = json:parse(body_str)
            if sequence(parsed) and length(parsed) = 2 and parsed[1] = 1 then
                object doc = parsed[2]
                sequence ev_name = json:get(doc, "event", "")
                object raw_data  = json:get(doc, "data", 0)
                sequence data_list = {}
                if json:is_object(raw_data) then
                    sequence pairs = raw_data[2]
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
                            data_list = append(data_list, {pair[1], v_str})
                        end if
                    end for
                end if

                sequence action_id = val(data_list, "id", "")
                sequence action_name = val(data_list, "action", "")
                sequence events = app_inst[APP_EVENTS]
                for x = 1 to length(events) do
                    sequence ev_key = events[x][1]
                    if equal(ev_key, ev_name) or equal(ev_key, action_id) or equal(ev_key, action_name) then
                        integer ev_rid = events[x][2]
                        object res = call_func(ev_rid, {data_list})
                        if sequence(res) and length(res) >= 3 and integer(res[1]) then
                            return res
                        end if
                        return http:response_json(200, res)
                    end if
                end for
                return http:response_json(200, `[]`)
            end if
            return http:response_json(400, `{"error":"invalid json"}`)
        end if
    end for

    return http:response(404, "<h1>404 Not Found (Euphorix VS-UI)</h1>", "text/html; charset=utf-8")
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
        printf(2, "FEHLER: VS-UI Server konnte auf Port %d nicht gestartet werden!\n",
               {registered_apps[app_id][APP_PORT]})
        return
    end if
    printf(1, "=====================================================================\n")
    printf(1, "  Euphorix VS-UI (cgibash/html) Server läuft auf http://127.0.0.1:%d/\n",
           {registered_apps[app_id][APP_PORT]})
    printf(1, "  Static Assets: %s\n", {registered_apps[app_id][APP_STATIC_DIR]})
    printf(1, "  Beenden mit Ctrl+C\n")
    printf(1, "=====================================================================\n")
    http:serve_forever(srv)
end procedure
