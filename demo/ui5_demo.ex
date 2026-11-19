--****
-- == Euphorix SAP UI5 Web Components 2.29 Demo Application
--
-- Starten mit: ./euphorix demo/ui5_demo.ex
-- Im Browser öffnen: http://127.0.0.1:8088/
--

include std/ui5.e as ui5
include std/sqlite.e as sqlite
include std/http.e as http

puts(1, "=====================================================================\n")
puts(1, "  Euphorix 1.0 – SAP UI5 Web Components 2.29 Live-Demo Server\n")
puts(1, "=====================================================================\n\n")

-- 1. SQLite In-Memory Datenbank für Demodaten initialisieren
integer db = sqlite:open(":memory:")
sqlite:exec(db, "CREATE TABLE tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, priority TEXT NOT NULL, date TEXT NOT NULL, done INTEGER NOT NULL);")

sqlite:exec(db, "INSERT INTO tasks (title, priority, date, done) VALUES (?, ?, ?, ?);",
            {"Euphorix VM & JIT Optimierung", "Hoch", "2026-11-19", 1})
sqlite:exec(db, "INSERT INTO tasks (title, priority, date, done) VALUES (?, ?, ?, ?);",
            {"SAP UI5 Web Components 2.29 einbinden", "Hoch", "2026-11-20", 1})
sqlite:exec(db, "INSERT INTO tasks (title, priority, date, done) VALUES (?, ?, ?, ?);",
            {"Fiori Horizon Dashboard testen", "Normal", "2026-11-21", 0})
sqlite:exec(db, "INSERT INTO tasks (title, priority, date, done) VALUES (?, ?, ?, ?);",
            {"PostgreSQL SCRAM-SHA-256 Validierung", "Normal", "2026-11-22", 0})
sqlite:exec(db, "INSERT INTO tasks (title, priority, date, done) VALUES (?, ?, ?, ?);",
            {"REST-Microservice Lasttest", "Niedrig", "2026-11-24", 0})

-- Hilfsfunktion: Tabellenzeilen aus der SQLite-Datenbank rendern
function render_task_table_content()
    sequence rows = sqlite:query(db, "SELECT id, title, priority, date, done FROM tasks ORDER BY id ASC;")
    sequence table_rows = {}

    for i = 1 to length(rows) do
        sequence r = rows[i]
        sequence id_str = sprintf("#%d", r[1])
        sequence title  = r[2]
        sequence prio   = r[3]
        sequence date   = r[4]
        integer is_done = r[5]

        sequence badge_html
        if is_done = 1 then
            badge_html = ui5:badge("Erledigt", 8) -- Grün
        elsif equal(prio, "Hoch") then
            badge_html = ui5:badge("Dringend", 2) -- Rot/Orange
        else
            badge_html = ui5:badge("In Bearbeitung", 6) -- Blau
        end if

        sequence act_btn
        if is_done = 0 then
            act_btn = ui5:button(sprintf("btn_done_%d", r[1]), "Erledigt", {
                {"design", ui5:DESIGN_POSITIVE},
                {"icon", "accept"},
                {"action", "toggle_done"},
                {"data-param-task_id", sprintf("%d", r[1])}
            })
        else
            act_btn = ui5:button(sprintf("btn_del_%d", r[1]), "Löschen", {
                {"design", ui5:DESIGN_NEGATIVE},
                {"icon", "delete"},
                {"action", "delete_task"},
                {"data-param-task_id", sprintf("%d", r[1])}
            })
        end if

        table_rows = append(table_rows, {id_str, title, prio, date, badge_html, act_btn})
    end for

    sequence cols = {
        {"ID", "80px"},
        {"Aufgabe", ""},
        {"Priorität", "130px"},
        {"Fälligkeit", "140px"},
        {"Status", "160px"},
        {"Aktion", "140px"}
    }
    return ui5:table(cols, table_rows, {{"id", "tasks_table"}})
end function

-- 2. Hauptseite des SAP Fiori Dashboards
function render_dashboard_page(sequence req)
    integer total_count = sqlite:query_value(db, "SELECT COUNT(*) FROM tasks;", {}, 0)
    integer done_count  = sqlite:query_value(db, "SELECT COUNT(*) FROM tasks WHERE done = 1;", {}, 0)
    integer pct = 0
    if total_count > 0 then
        pct = floor((done_count * 100) / total_count)
    end if

    sequence content = {
        -- Fiori ShellBar
        ui5:shellbar("Euphorix Enterprise Cockpit", "SAP UI5 Web Components v2.29", {
            {"profile", "VS"},
            {"notifications", "1"},
            {"co_pilot", "1"}
        }),

        -- Main Content Area
        "<div class=\"ui5-content-padding\">\n",

        -- Begrüßungs-Banner
        ui5:message_strip("Willkommen im interaktiven Euphorix Fiori Horizon Dashboard! Angetrieben von Java 25 & UI5 Web Components 2.29.", "Information"),
        "<br/>\n",

        -- KPI Dashboard Grid
        "<div class=\"ui5-grid-2\">\n",

        -- Karte 1: Projekt-Fortschritt
        ui5:card("Projekt-Status", {
            "<p>Gesamtfortschritt der anstehenden Tasks:</p>",
            sprintf("<div id=\"progress_container\">%s</div>",
                    {ui5:progress_indicator(pct, sprintf("%d%% (%d von %d erledigt)", {pct, done_count, total_count}), ui5:STATE_SUCCESS)}),
            "<br/>",
            "<div class=\"ui5-flex-row\">",
            ui5:icon("sys-enter-2", {{"style", "color:#107e3e; font-size: 1.5rem;"}}),
            "<span><b>Systemstatus:</b> Alle Virtual-Threads und Microservices operativ</span>",
            "</div>",
            "<br/>",
            "<div style=\"display:flex; gap:0.5rem;\">",
            ui5:button("btn_info", "Architektur-Details", {
                {"design", ui5:DESIGN_TRANSPARENT},
                {"icon", "hint"},
                {"action", "show_info"}
            }),
            "</div>"
        }, {{"subtitle", "Sprint 2026-Q4"}, {"icon", "lead-forecast"}}),

        -- Karte 2: Schnelle Aufgabenerfassung
        ui5:card("Neue Aufgabe erfassen", {
            "<div style=\"display:flex; flex-direction:column; gap:0.75rem;\">",
            ui5:input("new_title", "", {{"placeholder", "Titel der Aufgabe eingeben..."}, {"icon", "edit"}}),
            "<div class=\"ui5-flex-row\">",
            ui5:select("new_prio", {
                {"Normal", "Normal (Prio 2)", 1},
                {"Hoch", "Hoch (Prio 1)", 0},
                {"Niedrig", "Niedrig (Prio 3)", 0}
            }),
            ui5:datepicker("new_date", "2026-11-25"),
            "</div>",
            "<div style=\"display:flex; justify-content:flex-end;\">",
            ui5:button("btn_add_task", "Aufgabe anlegen", {
                {"design", ui5:DESIGN_EMPHASIZED},
                {"icon", "add"},
                {"action", "add_task"}
            }),
            "</div>",
            "</div>"
        }, {{"subtitle", "Direkt in SQLite speichern"}, {"icon", "create-form"}}),

        "</div>\n<br/>\n",

        -- Karte 3: Datentabelle mit UI5-Table
        ui5:card("Aktuelle Aufgabenübersicht", {
            "<div id=\"table_container\">",
            render_task_table_content(),
            "</div>"
        }, {{"subtitle", "Echtzeit-Synchronisation mit Euphorix Backend"}, {"icon", "activity-items"}}),

        -- Toast Notification Element
        ui5:toast("app_toast", "Operation erfolgreich abgeschlossen!", 3000),

        -- Info Dialog Element
        ui5:dialog("info_dialog", "Euphorix & SAP UI5 Web Components 2.29", {
            "<p><b>Architektur-Highlights:</b></p>",
            "<ul>",
            "<li><b>OpenEuphoria Syntax:</b> Reines Euphorix-Backend ohne JavaScript-Buildtools.</li>",
            "<li><b>SAP UI5 Web Components 2.29:</b> Offizielle SAP Custom Elements mit Morning Horizon Theme.</li>",
            "<li><b>Reaktive Bridge:</b> DOM-Patches und Events direkt über den integrierten HTTP-Server.</li>",
            "<li><b>Java 25 Platform:</b> Loom Virtual Threads, FFM C-FFI, JDBC SQLite & PostgreSQL.</li>",
            "</ul>"
        }, ui5:button("btn_close_dlg", "Schließen", {{"design", ui5:DESIGN_EMPHASIZED}, {"action", "close_info"}})),

        "</div>\n"
    }

    return ui5:page("Euphorix Fiori Cockpit", content, {
        {"theme", ui5:THEME_HORIZON},
        {"version", "2.29.0"}
    })
end function

-- 3. Interaktive Action-Handler (Euphorix Reactive Bridge)

-- Action: Aufgabe hinzufügen
function on_add_task(sequence ctx)
    sequence title = ui5:val(ctx, "new_title")
    sequence prio  = ui5:val(ctx, "new_prio", "Normal")
    sequence date  = ui5:val(ctx, "new_date", "2026-11-30")

    if length(title) = 0 then
        return ui5:updates({
            ui5:set_value_state("new_title", ui5:STATE_ERROR, "Bitte geben Sie einen Titel ein!"),
            ui5:toast_show("app_toast", "Fehler: Titel darf nicht leer sein!")
        })
    end if

    -- In SQLite speichern
    sqlite:exec(db, "INSERT INTO tasks (title, priority, date, done) VALUES (?, ?, ?, 0);", {title, prio, date})

    -- Gesamtstatus neu berechnen
    integer total_count = sqlite:query_value(db, "SELECT COUNT(*) FROM tasks;", {}, 0)
    integer done_count  = sqlite:query_value(db, "SELECT COUNT(*) FROM tasks WHERE done = 1;", {}, 0)
    integer pct = floor((done_count * 100) / total_count)

    sequence new_prog = ui5:progress_indicator(pct, sprintf("%d%% (%d von %d erledigt)", {pct, done_count, total_count}), ui5:STATE_SUCCESS)

    -- Reaktive Updates an das Frontend zurücksenden
    return ui5:updates({
        ui5:patch("table_container", render_task_table_content()),
        ui5:patch("progress_container", new_prog),
        ui5:set_val("new_title", ""),
        ui5:set_value_state("new_title", ui5:STATE_NONE),
        ui5:toast_show("app_toast", sprintf("Aufgabe '%s' erfolgreich gespeichert!", {title}))
    })
end function

-- Action: Aufgabe auf "Erledigt" schalten
function on_toggle_done(sequence ctx)
    sequence task_id_str = ui5:val(ctx, "task_id")
    integer task_id = 0
    if length(task_id_str) > 0 then
        object v = value(task_id_str)
        task_id = v[2]
    end if

    if task_id > 0 then
        sqlite:exec(db, "UPDATE tasks SET done = 1 WHERE id = ?;", {task_id})
    end if

    integer total_count = sqlite:query_value(db, "SELECT COUNT(*) FROM tasks;", {}, 0)
    integer done_count  = sqlite:query_value(db, "SELECT COUNT(*) FROM tasks WHERE done = 1;", {}, 0)
    integer pct = floor((done_count * 100) / total_count)
    sequence new_prog = ui5:progress_indicator(pct, sprintf("%d%% (%d von %d erledigt)", {pct, done_count, total_count}), ui5:STATE_SUCCESS)

    return ui5:updates({
        ui5:patch("table_container", render_task_table_content()),
        ui5:patch("progress_container", new_prog),
        ui5:toast_show("app_toast", sprintf("Aufgabe #%d als erledigt markiert!", {task_id}))
    })
end function

-- Action: Aufgabe löschen
function on_delete_task(sequence ctx)
    sequence task_id_str = ui5:val(ctx, "task_id")
    integer task_id = 0
    if length(task_id_str) > 0 then
        object v = value(task_id_str)
        task_id = v[2]
    end if

    if task_id > 0 then
        sqlite:exec(db, "DELETE FROM tasks WHERE id = ?;", {task_id})
    end if

    integer total_count = sqlite:query_value(db, "SELECT COUNT(*) FROM tasks;", {}, 0)
    integer done_count  = sqlite:query_value(db, "SELECT COUNT(*) FROM tasks WHERE done = 1;", {}, 0)
    integer pct = 0
    if total_count > 0 then
        pct = floor((done_count * 100) / total_count)
    end if
    sequence new_prog = ui5:progress_indicator(pct, sprintf("%d%% (%d von %d erledigt)", {pct, done_count, total_count}), ui5:STATE_SUCCESS)

    return ui5:updates({
        ui5:patch("table_container", render_task_table_content()),
        ui5:patch("progress_container", new_prog),
        ui5:toast_show("app_toast", sprintf("Aufgabe #%d gelöscht!", {task_id}))
    })
end function

-- Action: Info Dialog anzeigen
function on_show_info(sequence ctx)
    return ui5:updates({
        ui5:open_dialog("info_dialog")
    })
end function

-- Action: Info Dialog schließen
function on_close_info(sequence ctx)
    return ui5:updates({
        ui5:close_dialog("info_dialog")
    })
end function

-- 4. Anwendungs-Setup & Start
integer app = ui5:app("Euphorix Fiori Cockpit", 8088, ui5:THEME_HORIZON, "2.29.0")
ui5:page_route(app, "/", routine_id("render_dashboard_page"))
ui5:action(app, "add_task", routine_id("on_add_task"))
ui5:action(app, "toggle_done", routine_id("on_toggle_done"))
ui5:action(app, "delete_task", routine_id("on_delete_task"))
ui5:action(app, "show_info", routine_id("on_show_info"))
ui5:action(app, "close_info", routine_id("on_close_info"))

ui5:run(app)
