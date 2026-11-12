-- =============================================================================
-- Beispiel 05: Vollständiger REST-Microservice (HTTP + JSON-Schema 2020-12 + SQLite)
-- Aufruf: ./eui examples/05_rest_api_microservice.ex
-- =============================================================================
include std/http.e
include std/json.e
include std/json_schema.e
include std/sqlite.e
include std/text.e

procedure assert_eq(sequence name, object actual, object expected)
    if not equal(actual, expected) then
        printf(2, "FEHLER in %s!\n  Erwartet: %s\n  Erhalten: %s\n", {name, sprint(expected), sprint(actual)})
        abort(1)
    end if
end procedure

puts(1, "=== Beispiel 05: REST-API Microservice (HTTP + JSON-Schema 2020-12 + SQLite) ===\n")

-- 1. SQLite In-Memory Datenbank initialisieren
integer db = sqlite:open(":memory:")
sqlite:exec(db, "CREATE TABLE tasks (id INTEGER PRIMARY KEY, title TEXT NOT NULL, priority INTEGER NOT NULL);")
sqlite:exec(db, "INSERT INTO tasks (title, priority) VALUES (?, ?);", {"Server-Deployment prüfen", 1})

-- 2. JSON-Schema Draft 2020-12 für eingehende POST-Requests definieren
sequence task_schema = `{
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "type": "object",
    "required": ["title", "priority"],
    "properties": {
        "title":    {"type": "string",  "minLength": 3, "maxLength": 100},
        "priority": {"type": "integer", "minimum": 1,   "maximum": 5}
    },
    "additionalProperties": false
}`

-- 3. HTTP Route-Handler definieren
function handle_list_tasks(sequence req)
    sequence tasks = sqlite:query_assoc(db, "SELECT id, title, priority FROM tasks ORDER BY id;")
    return http:response_json(200, json:stringify(json:array(tasks)))
end function

function handle_create_task(sequence req)
    sequence body = req[http:REQ_BODY]
    -- Eingehendes JSON gegen Draft 2020-12 Schema prüfen:
    sequence val = json_schema:validate(body, task_schema)
    if not val[json_schema:VALID] then
        sequence errs = json_schema:format_errors(val)
        object err_obj = json:object_new({
            {"error", "Schema-Validierung fehlgeschlagen"},
            {"details", errs[1]}
        })
        return http:response_json(400, json:stringify(err_obj))
    end if

    object payload = json:decode(body)
    sequence title = json:get(payload, "title")
    integer prio   = json:get(payload, "priority")

    sqlite:exec(db, "INSERT INTO tasks (title, priority) VALUES (?, ?);", {title, prio})
    integer new_id = sqlite:last_insert_id(db)

    object created = json:object_new({
        {"id", new_id},
        {"title", title},
        {"priority", prio}
    })
    return http:response_json(201, json:stringify(created))
end function

-- 4. Server starten (bedient 3 Requests im Hintergrundprozess)
integer port = 18095
integer srv  = http:server_create("127.0.0.1", port)
http:route(srv, "GET",  "/api/tasks", routine_id("handle_list_tasks"))
http:route(srv, "POST", "/api/tasks", routine_id("handle_create_task"))

integer bg_pid = http:server_background(srv, 3)
sequence base_url = sprintf("http://127.0.0.1:%d/api/tasks", {port})

-- Request 1: Ungültiger Task (priority = 99 verstößt gegen maximum: 5) -> 400 Bad Request
sequence r_bad = http:post_json(base_url, `{"title":"Zu hohe Prio","priority":99}`)
assert_eq("POST ungültig -> Status 400", r_bad[http:STATUS], 400)
puts(1, "  [OK] POST /api/tasks (ungültiges JSON) -> 400 Bad Request (JSON-Schema 2020-12)\n")

-- Request 2: Gültiger Task -> 201 Created in SQLite
sequence r_ok = http:post_json(base_url, `{"title":"Dokumentation fertigstellen","priority":2}`)
assert_eq("POST gültig -> Status 201", r_ok[http:STATUS], 201)
object created_doc = json:decode(r_ok[http:BODY])
assert_eq("Erstellte Task-ID == 2", json:get(created_doc, "id"), 2)
puts(1, "  [OK] POST /api/tasks (gültiges JSON)   -> 201 Created (in SQLite gespeichert)\n")

-- Request 3: Alle Tasks als JSON-Array abrufen -> 200 OK
sequence r_list = http:get(base_url)
assert_eq("GET /api/tasks -> Status 200", r_list[http:STATUS], 200)
object list_doc = json:decode(r_list[http:BODY])
assert_eq("Anzahl Tasks == 2", json:size(list_doc), 2)
assert_eq("Task 2 Titel", json:get(list_doc, "[2].title"), "Dokumentation fertigstellen")
puts(1, "  [OK] GET  /api/tasks                   -> 200 OK (2 Tasks aus SQLite geladen)\n")

http:server_close(srv, bg_pid)
sqlite:close(db)
puts(1, "=== REST-API Microservice Ende-zu-Ende Test erfolgreich! ===\n")
