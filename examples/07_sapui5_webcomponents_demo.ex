-- =============================================================================
-- Beispiel 07: Modernes Enterprise-Dashboard mit SAP UI5 Web Components (v2.29)
-- Aufruf: ./euphorix examples/07_sapui5_webcomponents_demo.ex
--
-- Demonstriert:
-- 1) Standardisierte SAP UI5 Web Components v2.29 (<ui5-shellbar>, <ui5-card>,
--    <ui5-table>, <ui5-button>, <ui5-input>, <ui5-badge>, <ui5-toast>, <ui5-dialog>)
-- 2) Echtes SAP Fiori Morning Horizon Design ("sap_horizon")
-- 3) Vollständige serverseitige Steuerung in reinem OpenEuphoria (std/ui5.e)
-- 4) Reaktive Bridge: Klicks und Aktionen aktualisieren DOM-Bereiche per ui5:patch()
-- 5) SQLite-Datenbankanbindung für Datenspeicherung und Live-Tabellen-Reload
-- =============================================================================

include std/ui5.e as ui5
include std/sqlite.e as sqlite
include std/http.e as http
include std/datetime.e as dt

puts(1, "=== Beispiel 07: Enterprise-Dashboard mit SAP UI5 Web Components v2.29 ===\n")

-- 1. In-Memory SQLite-Datenbank für das Demo-System initialisieren
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

        sequence act_btn = ui5:button(sprintf("btn_done_%d", r[1]), "Erledigt", {
            {"design", ui5:DESIGN_TRANSPARENT},
            {"icon", "accept"},
            {"action", "toggle_done"},
            {"data-param-task_id", sprintf("%d", r[1])}
        })

        table_rows = append(table_rows, {id_str, title, prio, date, badge_html, act_btn})
    end for

    sequence cols = {
        {"ID", "80px"},
        {"Aufgabe", ""},
        {"Priorität", "130px"},
        {"Fälligkeit", "140px"},
        {"Status", "160px"},
        {"Aktion", "120px"}
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
        ui5:message_strip("Willkommen im Euphorix Fiori Horizon Dashboard! Angetrieben von Java 25 & UI5 Web Components 2.29.", "Information"),
        "<br/>\n",

        -- KPI Dashboard Grid
        "<div class=\"ui5-grid-2\">\n",

        -- Karte 1: Projekt-Fortschritt
        ui5:card("Projekt-Status", {
            "<p>Gesamtfortschritt der anstehenden Releases:</p>",
            sprintf("<div id=\"progress_container\">%s</div>",
                    {ui5:progress_indicator(pct, sprintf("%d%% (%d von %d erledigt)", {pct, done_count, total_count}), ui5:STATE_SUCCESS)}),
            "<br/>",
            "<div class=\"ui5-flex-row\">",
            ui5:icon("sys-enter-2", {{"style", "color:#107e3e; font-size: 1.5rem;"}}),
            "<span><b>Systemstatus:</b> Alle Virtual-Threads und Microservices operativ</span>",
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

-- 4. Anwendungs-Setup
integer app = ui5:app("Euphorix Fiori Cockpit", 8088, ui5:THEME_HORIZON, "2.29.0")
ui5:page_route(app, "/", routine_id("render_dashboard_page"))
ui5:action(app, "add_task", routine_id("on_add_task"))
ui5:action(app, "toggle_done", routine_id("on_toggle_done"))

-- End-to-End Simulationstest über HttpClient
printf(1, "1. Initialisiere UI5-Server auf Port 8088...\n")
integer srv = ui5:init_server(app)
if srv <= 0 then
    printf(2, "FEHLER: Server konnte nicht gestartet werden: %d\n", {srv})
    abort(1)
end if

-- Server im Hintergrund-Worker starten
integer worker_pid = http:server_background(srv, 3)
printf(1, "2. Hintergrund-Server läuft (Worker-PID: %d)\n", {worker_pid})

-- GET-Request auf "/" absetzen
sequence get_res = http:get("http://127.0.0.1:8088/")
printf(1, "3. GET / -> Status %d (HTML-Länge: %d Bytes, Msg: '%s')\n",
       {get_res[http:STATUS], length(get_res[http:BODY]), get_res[http:BODY]})
if get_res[http:STATUS] != 200 or match("<ui5-shellbar", get_res[http:BODY]) = 0 then
    puts(2, "FEHLER: UI5-HTML wurde nicht korrekt ausgeliefert!\n")
    abort(1)
end if

-- POST-Request auf "/__ui5_action" mit 'add_task' absetzen
sequence post_payload = `{"action":"add_task","values":{"new_title":"Automatisierter Test-Task","new_prio":"Hoch","new_date":"2026-11-28"}}`
sequence post_res = http:post_json("http://127.0.0.1:8088/__ui5_action", post_payload)
printf(1, "4. POST /__ui5_action -> Status %d (JSON: %s)\n", {post_res[http:STATUS], post_res[http:BODY][1..min({60, length(post_res[http:BODY])})]})
if post_res[http:STATUS] != 200 or match("\"type\":\"patch\"", post_res[http:BODY]) = 0 then
    puts(2, "FEHLER: Reaktiver Bridge-Update fehlgeschlagen!\n")
    abort(1)
end if

-- Verifizieren, dass der Eintrag in SQLite angekommen ist
sequence verify_res = sqlite:query(db, "SELECT title FROM tasks WHERE title = 'Automatisierter Test-Task';")
if length(verify_res) != 1 then
    puts(2, "FEHLER: Task wurde nicht in SQLite gefunden!\n")
    abort(1)
end if
printf(1, "5. SQLite-Verifikation: '%s' erfolgreich gespeichert!\n", {verify_res[1][1]})

-- Server-Worker beenden
http:server_close(srv, worker_pid)

puts(1, "=== Alle SAP UI5 Web Components (v2.29) Tests und Demos erfolgreich bestanden! ===\n")
