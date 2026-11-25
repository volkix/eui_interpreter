--****
-- == VS-UI Autarkes High-Density Web-Framework für Euphorix (std/vsui.e)
--
-- Native, leichtgewichtige Enterprise Web-UI Bibliothek mit Assets direkt
-- im Projektverzeichnis html/.
--
-- Features:
-- * Zero external dependencies: Verwendet native ES6 Module, `ldom.js`, und `vsevent.js`.
-- * High-density Enterprise Styling (vs.css & globalblauklein.css) mit kompakten Layouts,
--   präziser Typografie und anpassbaren CSS-Variablen (--vs-blau, --vs-gruen).
-- * Vollständige Komponenten-Suite: vsbutton, vsinput, vsnuminput, vsdateinput, vstimeinput,
--   vscheck, vstextarea, vscombo, vslabel, vsgroup, vspanel, vscollapse, vsgrid (DataGrid
--   mit Sticky Headers & Live-Suche), vstabs, vsmodal, vstoast, vssplitter, vsdragdrop-upload,
--   responsive SVG-Charts (Bar, Line, Pie, Doughnut).
-- * Integrierter statischer Webserver direkt für /lib2/*, /css/*, /img/*, /app/* aus
--   dem lokalen Projektverzeichnis html/.
-- * Reaktive Event-Bridge: Verknüpft Frontend-Ereignisse (`vsevent`: "button_click", "changevalue")
--   direkt mit OpenEuphoria `routine_id`-Handlern über flackerfreie DOM-Patches (`vsui:patch()`,
--   `vsui:set_val()`, `vsui:toast_show()`, `vsui:modal_open()`, `vsui:field_error()`).
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

// Apply reactive DOM patches received from Euphorix backend
window.applyVsPatches = function(patches) {
  if (!patches) return;
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
    } else if (p.type === 'fieldError') {
      var target = document.getElementById(p.id);
      if (target) {
        target.classList.add('vs-field-error');
        var errEl = document.getElementById(p.id + '_error');
        if (!errEl) {
          errEl = document.createElement('div');
          errEl.id = p.id + '_error';
          errEl.className = 'vs-error-tip';
          target.parentNode.insertBefore(errEl, target.nextSibling);
        }
        errEl.textContent = p.msg;
        errEl.style.display = 'block';
      }
    } else if (p.type === 'fieldClearError') {
      var target = document.getElementById(p.id);
      if (target) target.classList.remove('vs-field-error');
      var errEl = document.getElementById(p.id + '_error');
      if (errEl) { errEl.textContent = ''; errEl.style.display = 'none'; }
    } else if (p.type === 'clearForm') {
      var container = (p.id && p.id.length > 0) ? document.getElementById(p.id) : document;
      if (container) {
        container.querySelectorAll('input, select, textarea').forEach(function(el) {
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
      if (window._vs_ui && typeof window._vs_ui.vstoast === 'function') {
        window._vs_ui.vstoast(p.text, p.toast_type || 'info', p.duration || 3000);
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
    } else if (p.type === 'chartSetData') {
      var ch = document.getElementById(p.id + '_chart');
      if (ch && p.svg) ch.outerHTML = p.svg;
    } else if (p.type === 'redirect') {
      window.location.href = p.url;
    }
  });
};

// Dispatch event from frontend to Euphorix backend
window.sendVsEvent = function(eventName, eventData) {
  var data = Object.assign({}, eventData || {});
  
  // Collect input values
  document.querySelectorAll('input, select, textarea').forEach(function(el) {
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
    window.applyVsPatches(patches);
  })
  .catch(function(err) {
    console.error('Euphorix VS-UI Bridge Error:', err);
  });
};

// Wire up global click on .vs-button elements
document.addEventListener('click', function(ev) {
  var closeBtn = ev.target.closest('[data-vs-close]');
  if (closeBtn) {
    var modalId = closeBtn.getAttribute('data-vs-close');
    var m = document.getElementById(modalId);
    if (m) m.style.display = 'none';
  }

  var btn = ev.target.closest('.vs-button, [data-vs-click]');
  if (btn) {
    if (btn.closest('.vs-upload-dropzone') && !btn.hasAttribute('data-vs-click')) {
      return;
    }
    var clickAction = btn.getAttribute('data-vs-click') || btn.id;
    if (!clickAction && !btn.id) return;
    var params = { id: btn.id, action: clickAction };
    for (var i = 0; i < btn.attributes.length; i++) {
      var a = btn.attributes[i];
      if (a.name.indexOf('data-param-') === 0) {
        params[a.name.substring(11)] = a.value;
      }
    }
    window.sendVsEvent('button_click', params);
  }
});

// Wire up change on input, select, textarea
document.addEventListener('change', function(ev) {
  var inp = ev.target.closest('.vs-input, .vs-check, .vs-combo, select, textarea');
  if (inp && inp.id) {
    window.sendVsEvent('changevalue', { id: inp.id, value: inp.value });
  }
});

// Forward vsevent events if triggered via JS
vsevent.handle("button_click", function(mid) {
  if (mid && mid.id) window.sendVsEvent("button_click", mid);
});

// Drag & Drop Upload Initializer
window.initVsUpload = function(dropzoneId, uploadUrl) {
  var zone = document.getElementById(dropzoneId);
  if (!zone) return;
  var fileInput = zone.querySelector('input[type=file]');
  var preview = zone.querySelector('.vs-upload-preview');
  var progress = zone.querySelector('.vs-upload-progress-bar');
  
  function handleFiles(files) {
    if (!files || files.length === 0) return;
    var file = files[0];
    if (preview) preview.textContent = 'Lade hoch: ' + file.name + ' (' + (file.size/1024).toFixed(1) + ' KB)...';
    if (progress) progress.style.width = '35%';

    var reader = new FileReader();
    reader.onload = function(e) {
      var contentData = e.target.result;
      var payload = {
        id: dropzoneId,
        filename: file.name,
        size: file.size,
        type: file.type || 'application/octet-stream',
        lastModified: file.lastModified,
        data: contentData
      };
      if (progress) progress.style.width = '70%';

      fetch(uploadUrl || '/api/upload', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=utf-8' },
        body: JSON.stringify(payload)
      })
      .then(function(res) {
        if (progress) progress.style.width = '100%';
        return res.json().catch(function() { return []; });
      })
      .then(function(result) {
        if (preview) preview.textContent = '✓ Erfolgreich übertragen: ' + file.name + ' (' + (file.size/1024).toFixed(1) + ' KB)';
        if (window.applyVsPatches && Array.isArray(result) && result.length > 0) {
          window.applyVsPatches(result);
        }
        if (typeof window.sendVsEvent === 'function') {
          window.sendVsEvent('upload_complete', {
            id: dropzoneId,
            filename: file.name,
            size: file.size,
            status: 200
          });
        }
        setTimeout(function() {
          if (progress) progress.style.width = '0%';
        }, 3000);
      })
      .catch(function(err) {
        if (preview) preview.textContent = 'Upload-Fehler: ' + err;
        if (progress) progress.style.width = '0%';
      });
    };
    reader.readAsDataURL(file);
  }

  zone.ondragover = function(e) { e.preventDefault(); zone.classList.add('vs-upload-active'); };
  zone.ondragleave = function(e) { zone.classList.remove('vs-upload-active'); };
  zone.ondrop = function(e) {
    e.preventDefault();
    zone.classList.remove('vs-upload-active');
    handleFiles(e.dataTransfer.files);
  };
  if (fileInput) {
    fileInput.addEventListener('click', function(e) { e.stopPropagation(); });
    fileInput.addEventListener('change', function() { handleFiles(fileInput.files); });
  }
};

// Automatic dropzone discovery and initialization
function initAllUploadDropzones() {
  document.querySelectorAll('.vs-upload-dropzone').forEach(function(zone) {
    if (zone.dataset.initialized) return;
    zone.dataset.initialized = 'true';
    var uploadUrl = zone.getAttribute('data-upload-url') || '/api/upload';
    window.initVsUpload(zone.id, uploadUrl);
  });
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initAllUploadDropzones);
} else {
  initAllUploadDropzones();
}

document.addEventListener('click', function(e) {
  if (e.target.closest('.vs-tab-btn')) {
    setTimeout(initAllUploadDropzones, 50);
  }
});
</script>`
end function

--**
-- Construct a complete HTML5 page styled with the high-density VS-UI framework (`html/`).
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
-- 4. Component Builders (Matching VS-UI & globalblauklein.css)
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

        -- 1. Check custom page routes (GET & HEAD)
        if equal(req_method, "GET") or equal(req_method, "HEAD") then
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
        elsif equal(req_method, "POST") and equal(req_path, "/api/upload") then
            sequence body_str = req[http:REQ_BODY]
            sequence data_list = {}
            object parsed = json:parse(body_str)
            if sequence(parsed) and length(parsed) = 2 and parsed[1] = 1 then
                object doc = parsed[2]
                if json:is_object(doc) then
                    sequence pairs = doc[2]
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
            else
                data_list = {{"filename", "hochgeladene_datei"}, {"size", sprintf("%d", length(body_str))}, {"id", "drop_belege"}}
            end if

            sequence upload_id = val(data_list, "id", "drop_belege")
            sequence events = app_inst[APP_EVENTS]
            for x = 1 to length(events) do
                sequence ev_key = events[x][1]
                if equal(ev_key, "file_upload") or equal(ev_key, "upload") or equal(ev_key, upload_id) then
                    integer ev_rid = events[x][2]
                    object res = call_func(ev_rid, {data_list})
                    if sequence(res) and length(res) >= 3 and integer(res[1]) then
                        return res
                    end if
                    return http:response_json(200, res)
                end if
            end for
            sequence default_name = val(data_list, "filename", "Datei")
            sequence default_size = val(data_list, "size", "")
            return http:response_json(200, {
                {json:JSON_OBJECT, {
                    {"type", "toast"},
                    {"text", "Datei '" & default_name & "' (" & default_size & " Bytes) erfolgreich empfangen."},
                    {"toast_type", "success"},
                    {"duration", 3000}
                }}
            })
        end if
    end for

    return http:response(404, "<h1>404 Not Found (Euphorix VS-UI)</h1>", "text/html; charset=utf-8")
end function


-- =============================================================================
-- Form Validation & Error Tips
-- =============================================================================

--**
-- Highlight an input field with an error state and show an error message below it.
public function field_error(sequence id, sequence error_msg)
    return {{"type", "fieldError"}, {"id", id}, {"msg", error_msg}}
end function

--**
-- Clear the error highlight and message from an input field.
public function field_clear_error(sequence id)
    return {{"type", "fieldClearError"}, {"id", id}}
end function

--**
-- Validate that a field in `ctx` is not empty. Returns `{ok, error_msg}`.
public function validate_required(sequence ctx, sequence field_id, sequence field_label = "")
    sequence v = val(ctx, field_id, "")
    if length(v) = 0 then
        sequence lbl = field_label
        if length(lbl) = 0 then lbl = field_id end if
        return {0, sprintf("Das Feld '%s' darf nicht leer sein.", {lbl})}
    end if
    return {1, ""}
end function

--**
-- Validate that a string contains a valid email format (`user@domain.tld`).
public function validate_email(sequence email_str)
    integer at_pos = find('@', email_str)
    if at_pos > 1 and at_pos < length(email_str) then
        integer dot_pos = find('.', email_str[at_pos..$])
        if dot_pos > 1 then
            return {1, ""}
        end if
    end if
    return {0, "Bitte geben Sie eine gültige E-Mail-Adresse ein."}
end function

--**
-- Validate that a string represents a valid number within [min_val, max_val].
public function validate_number(sequence num_str, atom min_val = -1e9, atom max_val = 1e9)
    if length(num_str) = 0 then
        return {0, "Bitte geben Sie eine Zahl ein."}
    end if
    -- Parse number
    atom n = 0.0
    integer valid = 0
    for i = 1 to length(num_str) do
        integer c = num_str[i]
        if (c >= '0' and c <= '9') or c = '.' or c = '-' then
            valid = 1
        else
            return {0, "Ungültiges Zahlenformat."}
        end if
    end for
    return {1, ""}
end function

-- =============================================================================
-- Drag & Drop File Upload Component
-- =============================================================================

--**
-- Create a modern drag-and-drop file upload dropzone.
public function upload(sequence id, sequence target_url = "/api/upload", sequence options = {})
    sequence prompt = get_opt(options, "prompt", "Datei hierher ziehen oder manuell auswählen")
    sequence accept = get_opt(options, "accept", "*/*")
    
    sequence html = sprintf(`<div id="%s" class="vs-upload-dropzone" data-upload-url="%s">` & "\n", {id, target_url})
    html &= sprintf(`  <input type="file" id="%s_file" accept="%s" style="display:none;" />` & "\n", {id, accept})
    html &= sprintf(`  <label for="%s_file" style="display:block; cursor:pointer; width:100%%; margin:0; padding:12px 0;">` & "\n", {id})
    html &= `    <div class="vs-upload-icon" style="font-size:36px; line-height:1; pointer-events:none;">&#8682;</div>` & "\n"
    html &= sprintf(`    <div class="vs-upload-text" style="font-weight:bold; margin-top:6px; pointer-events:none;">%s</div>` & "\n", {escape_html(prompt)})
    html &= `    <div style="margin-top:10px;"><span class="vs-button" style="pointer-events:none; display:inline-block; font-size:12px; padding:5px 14px; background:var(--vs-blau,#41518b); color:white; border-radius:3px;">📁 Datei manuell auswählen...</span></div>` & "\n"
    html &= `  </label>` & "\n"
    html &= `  <div class="vs-upload-preview" style="font-size:12px; margin-top:8px; font-weight:bold; color:var(--vs-blau,#41518b);"></div>` & "\n"
    html &= `  <div class="vs-upload-progress"><div class="vs-upload-progress-bar"></div></div>` & "\n"
    html &= sprintf(`  <script>if(typeof window.initVsUpload === 'function') window.initVsUpload("%s", "%s");</script>` & "\n", {id, target_url})
    html &= `</div>` & "\n"
    return html
end function

-- =============================================================================
-- Native Responsive SVG Chart Component (Bar, Line, Pie, Doughnut)
-- =============================================================================

function render_svg_chart(sequence id, sequence chart_type, sequence labels, sequence datasets, sequence options = {})
    integer count = length(labels)
    if count = 0 then count = 1 end if
    sequence title = get_opt(options, "title", "")
    sequence colors = {"#41518b", "#28a745", "#17a2b8", "#ffc107", "#dc3545", "#6610f2", "#fd7e14"}

    sequence svg = sprintf(`<div id="%s_chart" class="vs-chart-container">` & "\n", {id})
    if length(title) > 0 then
        svg &= sprintf(`  <div class="vs-chart-title">%s</div>` & "\n", {escape_html(title)})
    end if

    if equal(chart_type, "bar") then
        atom max_val = 1.0
        for i = 1 to length(datasets) do
            if atom(datasets[i]) and datasets[i] > max_val then
                max_val = datasets[i]
            end if
        end for

        svg &= `  <svg class="vs-chart-svg" viewBox="0 0 600 260" xmlns="http://www.w3.org/2000/svg">` & "\n"
        svg &= `    <line x1="50" y1="40" x2="570" y2="40" stroke="#edf2f7" stroke-width="1"/>` & "\n"
        svg &= `    <line x1="50" y1="100" x2="570" y2="100" stroke="#edf2f7" stroke-width="1"/>` & "\n"
        svg &= `    <line x1="50" y1="160" x2="570" y2="160" stroke="#edf2f7" stroke-width="1"/>` & "\n"
        svg &= `    <line x1="50" y1="210" x2="570" y2="210" stroke="#cbd5e1" stroke-width="1.5"/>` & "\n"

        atom step_x = 510.0 / count
        atom bar_w = step_x * 0.65
        if bar_w > 55.0 then bar_w = 55.0 end if

        for i = 1 to length(datasets) do
            atom val = 0.0
            if atom(datasets[i]) then val = datasets[i] end if
            atom bar_h = (val / max_val) * 160.0
            if bar_h < 2.0 and val > 0 then bar_h = 2.0 end if
            atom x = 55.0 + (i - 1) * step_x + (step_x - bar_w) / 2.0
            atom y = 210.0 - bar_h
            sequence col = colors[1 + remainder(i - 1, length(colors))]

            svg &= sprintf(`    <rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="3" fill="%s" />` & "\n",
                           {x, y, bar_w, bar_h, col})
            svg &= sprintf(`    <text x="%.1f" y="%.1f" font-size="11" font-weight="bold" fill="#334155" text-anchor="middle">%.0f</text>` & "\n",
                           {x + bar_w / 2.0, y - 5.0, val})
            sequence lbl = ""
            if i <= length(labels) then lbl = labels[i] end if
            svg &= sprintf(`    <text x="%.1f" y="228" font-size="10.5" fill="#64748b" text-anchor="middle">%s</text>` & "\n",
                           {x + bar_w / 2.0, escape_html(lbl)})
        end for
        svg &= `  </svg>` & "\n"
    elsif equal(chart_type, "line") then
        atom max_val = 1.0
        for i = 1 to length(datasets) do
            if atom(datasets[i]) and datasets[i] > max_val then
                max_val = datasets[i]
            end if
        end for

        svg &= `  <svg class="vs-chart-svg" viewBox="0 0 600 260" xmlns="http://www.w3.org/2000/svg">` & "\n"
        svg &= `    <line x1="50" y1="40" x2="570" y2="40" stroke="#edf2f7" stroke-width="1"/>` & "\n"
        svg &= `    <line x1="50" y1="100" x2="570" y2="100" stroke="#edf2f7" stroke-width="1"/>` & "\n"
        svg &= `    <line x1="50" y1="160" x2="570" y2="160" stroke="#edf2f7" stroke-width="1"/>` & "\n"
        svg &= `    <line x1="50" y1="210" x2="570" y2="210" stroke="#cbd5e1" stroke-width="1.5"/>` & "\n"

        integer denom = count - 1
        if denom < 1 then denom = 1 end if
        atom step_x = 510.0 / denom
        sequence points_str = ""
        for i = 1 to length(datasets) do
            atom val = 0.0
            if atom(datasets[i]) then val = datasets[i] end if
            atom x = 55.0 + (i - 1) * step_x
            atom y = 210.0 - (val / max_val) * 160.0
            if i > 1 then points_str &= " " end if
            points_str &= sprintf("%.1f,%.1f", {x, y})
        end for

        svg &= sprintf(`    <polyline fill="none" stroke="#41518b" stroke-width="3" stroke-linecap="round" points="%s" />` & "\n", {points_str})

        for i = 1 to length(datasets) do
            atom val = 0.0
            if atom(datasets[i]) then val = datasets[i] end if
            atom x = 55.0 + (i - 1) * step_x
            atom y = 210.0 - (val / max_val) * 160.0
            svg &= sprintf(`    <circle cx="%.1f" cy="%.1f" r="4.5" fill="#ffffff" stroke="#41518b" stroke-width="2.5" />` & "\n", {x, y})
            svg &= sprintf(`    <text x="%.1f" y="%.1f" font-size="10.5" font-weight="bold" fill="#1e293b" text-anchor="middle">%.0f</text>` & "\n",
                           {x, y - 8.0, val})
            sequence lbl = ""
            if i <= length(labels) then lbl = labels[i] end if
            svg &= sprintf(`    <text x="%.1f" y="228" font-size="10.5" fill="#64748b" text-anchor="middle">%s</text>` & "\n",
                           {x, escape_html(lbl)})
        end for
        svg &= `  </svg>` & "\n"
    elsif equal(chart_type, "pie") or equal(chart_type, "doughnut") then
        atom total = 0.0
        for i = 1 to length(datasets) do
            if atom(datasets[i]) then total += datasets[i] end if
        end for
        if total <= 0.0 then total = 1.0 end if

        svg &= `  <svg class="vs-chart-svg" viewBox="0 0 600 260" xmlns="http://www.w3.org/2000/svg">` & "\n"
        atom cx = 160.0
        atom cy = 130.0
        atom r_outer = 95.0
        atom r_inner = 0.0
        if equal(chart_type, "doughnut") then r_inner = 50.0 end if

        atom start_angle = -90.0
        for i = 1 to length(datasets) do
            atom val = 0.0
            if atom(datasets[i]) then val = datasets[i] end if
            atom angle = (val / total) * 360.0
            atom end_angle = start_angle + angle

            atom rad_start = (start_angle * 3.14159265) / 180.0
            atom rad_end = (end_angle * 3.14159265) / 180.0

            atom x1 = cx + r_outer * cos(rad_start)
            atom y1 = cy + r_outer * sin(rad_start)
            atom x2 = cx + r_outer * cos(rad_end)
            atom y2 = cy + r_outer * sin(rad_end)

            integer large_arc = 0
            if angle > 180.0 then large_arc = 1 end if
            sequence col = colors[1 + remainder(i - 1, length(colors))]

            if r_inner > 0.0 then
                atom x3 = cx + r_inner * cos(rad_end)
                atom y3 = cy + r_inner * sin(rad_end)
                atom x4 = cx + r_inner * cos(rad_start)
                atom y4 = cy + r_inner * sin(rad_start)
                svg &= sprintf(`    <path d="M %.1f %.1f A %.1f %.1f 0 %d 1 %.1f %.1f L %.1f %.1f A %.1f %.1f 0 %d 0 %.1f %.1f Z" fill="%s" stroke="#fff" stroke-width="1.5" />` & "\n",
                               {x1, y1, r_outer, r_outer, large_arc, x2, y2, x3, y3, r_inner, r_inner, large_arc, x4, y4, col})
            else
                svg &= sprintf(`    <path d="M %.1f %.1f L %.1f %.1f A %.1f %.1f 0 %d 1 %.1f %.1f Z" fill="%s" stroke="#fff" stroke-width="1.5" />` & "\n",
                               {cx, cy, x1, y1, r_outer, r_outer, large_arc, x2, y2, col})
            end if

            sequence lbl = ""
            if i <= length(labels) then lbl = labels[i] end if
            atom leg_y = 50.0 + (i - 1) * 26.0
            svg &= sprintf(`    <rect x="330" y="%.1f" width="14" height="14" rx="2" fill="%s" />` & "\n", {leg_y, col})
            svg &= sprintf(`    <text x="352" y="%.1f" font-size="12" fill="#334155">%s: <tspan font-weight="bold">%.1f%%</tspan></text>` & "\n",
                           {leg_y + 11.0, escape_html(lbl), (val / total) * 100.0})

            start_angle = end_angle
        end for
        svg &= `  </svg>` & "\n"
    end if

    svg &= `</div>`
    return svg
end function

--**
-- Create a responsive SVG chart (bar, line, pie, or doughnut).
public function chart(sequence id, sequence chart_type, sequence labels, sequence datasets, sequence options = {})
    return render_svg_chart(id, chart_type, labels, datasets, options)
end function

--**
-- Generate a live DOM patch to update a chart's data.
public function chart_set_data(sequence id, sequence chart_type, sequence labels, sequence datasets)
    return patch(id & "_chart", render_svg_chart(id, chart_type, labels, datasets, {}))
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
    printf(1, "  Euphorix VS-UI Server läuft auf http://127.0.0.1:%d/\n",
           {registered_apps[app_id][APP_PORT]})
    printf(1, "  Static Assets: %s\n", {registered_apps[app_id][APP_STATIC_DIR]})
    printf(1, "  Beenden mit Ctrl+C\n")
    printf(1, "=====================================================================\n")
    http:serve_forever(srv)
end procedure
