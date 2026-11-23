-- ==============================================================================
-- Euphorix 1.0 - Systemd Service Unit Generator (tools/make_service.ex)
-- ==============================================================================
-- Generates a production-ready Linux systemd service configuration for running
-- Euphorix applications as continuous background daemons with automatic restarts,
-- journal logging, and process isolation.
--
-- Usage:
--   ./euphorix tools/make_service.ex [script.ex] [service_name] [description] [user]
-- Example:
--   ./euphorix tools/make_service.ex examples/05_rest_api_microservice.ex euphorix-api "Euphorix REST API" volkix
-- ==============================================================================

include std/console.e
include std/filesys.e
include std/text.e
include std/io.e

sequence args = command_line()
-- args[1] = interpreter, args[2] = make_service.ex, args[3..] = user args
sequence script_args = {}
if length(args) >= 3 then
    script_args = args[3..$]
end if

puts(1, "=====================================================================\n")
puts(1, "  Euphorix 1.0 - Systemd Service Unit Generator\n")
puts(1, "=====================================================================\n\n")

if length(script_args) < 1 then
    puts(1, "Verwendung:\n")
    puts(1, "  ./euphorix tools/make_service.ex <script.ex> [service-name] [description] [user]\n\n")
    puts(1, "Beispiel:\n")
    puts(1, "  ./euphorix tools/make_service.ex examples/08_cgibash_html_demo.ex euphorix-web \"Euphorix Intranet App\" volkix\n\n")
    abort(1)
end if

sequence target_script = script_args[1]
sequence abs_script = canonical_path(target_script)

if file_exists(abs_script) != 1 then
    printf(2, "FEHLER: Skriptdatei '%s' wurde nicht gefunden!\n", {target_script})
    abort(1)
end if

sequence script_dir = dirname(abs_script)
sequence script_base = filename(abs_script)

-- Derive default service name from script name if omitted
sequence service_name = ""
if length(script_args) >= 2 and length(script_args[2]) > 0 then
    service_name = script_args[2]
else
    service_name = script_base
    integer dot = find('.', service_name)
    if dot > 1 then service_name = service_name[1..dot - 1] end if
    service_name = "euphorix-" & service_name
end if

-- Description
sequence description = ""
if length(script_args) >= 3 and length(script_args[3]) > 0 then
    description = script_args[3]
else
    description = "Euphorix Daemon Service (" & script_base & ")"
end if

-- User
sequence service_user = ""
if length(script_args) >= 4 and length(script_args[4]) > 0 then
    service_user = script_args[4]
else
    object u = getenv("USER")
    if sequence(u) and length(u) > 0 then
        service_user = u
    else
        service_user = "volkix"
    end if
end if

-- Interpreter path
sequence interp_path = canonical_path("euphorix")
if file_exists(interp_path) != 1 then
    interp_path = canonical_path("euphorix-standalone")
end if

-- Generate systemd unit content
sequence unit_content = sprintf(
    "[Unit]\n" &
    "Description=%s\n" &
    "After=network.target network-online.target\n" &
    "Wants=network-online.target\n\n" &
    "[Service]\n" &
    "Type=simple\n" &
    "User=%s\n" &
    "WorkingDirectory=%s\n" &
    "ExecStart=%s %s\n" &
    "Restart=always\n" &
    "RestartSec=5s\n" &
    "LimitNOFILE=65536\n" &
    "Environment=EUPHORIX_ENV=production\n" &
    "StandardOutput=journal\n" &
    "StandardError=journal\n" &
    "SyslogIdentifier=%s\n\n" &
    "[Install]\n" &
    "WantedBy=multi-user.target\n",
    {description, service_user, script_dir, interp_path, abs_script, service_name}
)

sequence out_filename = service_name & ".service"
integer fn = open(out_filename, "wb")
if fn < 0 then
    printf(2, "FEHLER: Service-Datei '%s' konnte nicht geschrieben werden!\n", {out_filename})
    abort(1)
end if
puts(fn, unit_content)
close(fn)

printf(1, "✓ Service-Unit erfolgreich generiert: '%s'\n\n", {out_filename})
puts(1, "---------------------------------------------------------------------\n")
puts(1, unit_content)
puts(1, "---------------------------------------------------------------------\n\n")

printf(1, "Installation & Aktivierung auf dem System:\n\n")
printf(1, "  1. Datei nach systemd kopieren:\n")
printf(1, "     sudo cp %s /etc/systemd/system/\n\n", {out_filename})
printf(1, "  2. Systemd neu laden:\n")
printf(1, "     sudo systemctl daemon-reload\n\n")
printf(1, "  3. Service aktivieren und sofort starten:\n")
printf(1, "     sudo systemctl enable --now %s\n\n", {service_name})
printf(1, "  4. Status prüfen:\n")
printf(1, "     sudo systemctl status %s\n\n", {service_name})
printf(1, "  5. Live-Logs ansehen:\n")
printf(1, "     journalctl -u %s -f\n\n", {service_name})
