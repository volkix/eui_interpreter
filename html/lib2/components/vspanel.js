import { e } from "../../lib2/ldom.js";

/**
 * vspanel - Erstellt ein Container-Panel mit Header und Content-Bereich
 * @param {string} id - Eindeutige ID
 * @param {string|HTMLElement} titel - Titel des Panels (Text oder DOM-Element)
 * @param {string|HTMLElement|Array} inhalt - Inhalt des Panels (Text, DOM-Element oder Array)
 * @param {boolean} [draggable=false] - Wenn true, kann das Panel über den Header verschoben werden
 * @returns {HTMLElement}
 */
export function vspanel(id, titel, inhalt, draggable = false) {
    // Sicherheitsregel für ldom.js: DOM-Elemente in Arrays wrappen, damit sie nicht als Attribut-Objekt interpretiert werden
    const wrappedTitle = (titel instanceof HTMLElement || titel instanceof DocumentFragment) ? [titel] : titel;
    const wrappedContent = (inhalt instanceof HTMLElement || inhalt instanceof DocumentFragment) ? [inhalt] : inhalt;

    const header = e(`.vs-panel-header#${id}_pheader`, wrappedTitle);
    const content = e(`.vs-panel-content#${id}_pcontent`, wrappedContent);
    const panel = e(`.vs-panel#${id}`, [header, content]);

    // Drag & Drop Logik aktivieren, falls erwünscht
    if (draggable === true) {
        header.style.cursor = "move";
        panel.style.position = "absolute";

        header.addEventListener("mousedown", (ev) => {
            // Keine Aktion bei Klicks auf Buttons/Inputs im Header
            if (ev.target.tagName === "BUTTON" || ev.target.tagName === "INPUT" || ev.target.closest("button, input")) {
                return;
            }
            ev.preventDefault();

            // Anfangs-Mausposition ermitteln
            let startX = ev.clientX;
            let startY = ev.clientY;

            // Aktuelle relative Position des Panels bestimmen
            let currentLeft = parseFloat(panel.style.left) || panel.offsetLeft;
            let currentTop = parseFloat(panel.style.top) || panel.offsetTop;

            // Einmalig als Inline-Styles fixieren, falls noch nicht geschehen
            panel.style.left = currentLeft + "px";
            panel.style.top = currentTop + "px";

            // Z-Index erhöhen, damit das gezogene Panel über allen anderen liegt
            const prevZIndex = panel.style.zIndex;
            panel.style.zIndex = "1000";

            const onMouseMove = (moveEv) => {
                const deltaX = moveEv.clientX - startX;
                const deltaY = moveEv.clientY - startY;

                panel.style.left = (currentLeft + deltaX) + "px";
                panel.style.top = (currentTop + deltaY) + "px";
            };

            const onMouseUp = () => {
                document.removeEventListener("mousemove", onMouseMove);
                document.removeEventListener("mouseup", onMouseUp);
                panel.style.zIndex = prevZIndex || "";
            };

            document.addEventListener("mousemove", onMouseMove);
            document.addEventListener("mouseup", onMouseUp);
        });
    }

    return panel;
}
