-- ==============================================================================
-- Euphorix 1.0 Demo: VSUI mit Formularen, Drag & Drop Upload & SVG-Charts
-- ==============================================================================

include std/vsui.e as vsui

integer my_app = vsui:app("Euphorix Intranet Dashboard", 8092)

function render_dashboard(sequence req)
    sequence months = {"Q1", "Q2", "Q3", "Q4"}
    sequence umsatz = {42000, 58000, 63000, 89000}

    sequence page_content = ""

    -- 1. SVG Diagramme
    page_content &= vsui:panel("pnl_charts", "Echtzeit-Statistiken (Responsive SVG Charts)", {
        vsui:chart("chart_umsatz", "bar", months, umsatz, {{"title", "Umsatz pro Quartal (EUR)"}}),
        vsui:chart("chart_verteilung", "doughnut", {"Support", "Entwicklung", "Vertrieb"}, {35, 45, 20}, {{"title", "Kostenverteilung"}})
    })

    -- 2. Drag & Drop Datei-Upload
    page_content &= vsui:panel("pnl_upload", "Dokumenten- & Beleg-Upload", {
        vsui:upload("drop_belege", "/api/upload", {{"prompt", "Rechnungen & Belege hierher ziehen oder durchsuchen"}})
    })

    -- 3. Formular mit Validierung
    page_content &= vsui:panel("pnl_form", "Benutzerdaten & Validierung", {
        vsui:ui_label("Benutzername:", "txt_user"),
        vsui:input("txt_user", "max_muster"),
        vsui:ui_label("E-Mail Adresse:", "txt_mail"),
        vsui:input("txt_mail", "falsche-email"),
        vsui:button("btn_save", "Daten Speichern", {{"style", "margin-top: 10px;"}})
    })

    return vsui:page("Euphorix Intranet", page_content)
end function

-- Upload Event Handler
function on_file_upload(sequence ctx)
    sequence fname = vsui:val(ctx, "filename", "datei.dat")
    sequence fsize = vsui:val(ctx, "size", "0")
    return vsui:updates({
        vsui:toast_show("Datei empfangen: " & fname & " (" & fsize & " Bytes)", vsui:TOAST_SUCCESS, 3500)
    })
end function

-- Formular-Validierungs Event Handler
function on_save_clicked(sequence ctx)
    sequence email = vsui:val(ctx, "txt_mail")
    sequence check_email = vsui:validate_email(email)

    if check_email[1] = 0 then
        -- Zeige Fehlermeldung direkt am Eingabefeld an
        return vsui:updates({
            vsui:field_error("txt_mail", check_email[2]),
            vsui:toast_show("Bitte Eingaben korrigieren!", vsui:TOAST_WARNING)
        })
    else
        -- Eingabe gültig -> Fehler aufheben & Toast Erfolgsmeldung
        return vsui:updates({
            vsui:field_clear_error("txt_mail"),
            vsui:toast_show("Benutzerdaten erfolgreich aktualisiert!", vsui:TOAST_SUCCESS)
        })
    end if
end function

vsui:page_route(my_app, "/", routine_id("render_dashboard"))
vsui:on_click(my_app, "btn_save", routine_id("on_save_clicked"))
vsui:on_event(my_app, "file_upload", routine_id("on_file_upload"))
vsui:on_event(my_app, "upload_complete", routine_id("on_file_upload"))

-- Hinweis: run() startet den Webserver
if length(command_line()) > 2 and equal(command_line()[3], "--run") then
    vsui:run(my_app)
else
    puts(1, "VSUI Demo syntaktisch validiert. Zum Starten des Webservers:\n")
    puts(1, "  ./euphorix examples/11_vsui_charts_und_upload_demo.ex --run\n")
end if
