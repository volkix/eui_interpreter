import { e, n } from "../../lib2/ldom.js";

/**
 * vsmodal - Erstellt ein modales Dialogfenster (HTML5 dialog)
 * @param {string} id - Eindeutige ID
 * @param {HTMLElement|Array|string} inhalt - Inhalt des modalen Fensters
 * @param {number|string} w - Breite in Pixeln
 * @param {number|string} h - Höhe in Pixeln
 * @returns {HTMLDialogElement}
 */
export function vsmodal(id, inhalt, w, h) {
    // 1. Schließen-Schaltfläche (oben rechts)
    const closeBtn = e("button.vs-modal-close-btn", {
        "style": {
            "position": "absolute",
            "top": "8px",
            "right": "12px",
            "background": "none",
            "border": "none",
            "fontSize": "20px",
            "fontWeight": "bold",
            "cursor": "pointer",
            "color": "#9ca3af",
            "padding": "0",
            "lineHeight": "1",
            "zIndex": "1000"
        },
        "event": {
            "click": () => elem.close()
        }
    }, "×");

    // Sicherheitsregel für ldom.js: DOM-Elemente in ein Array wrappen
    const wrappedContent = (inhalt instanceof HTMLElement || inhalt instanceof DocumentFragment)
        ? [inhalt]
        : inhalt;

    const contentContainer = e("div.vs-modal-content", {
        "style": {
            "padding": "20px",
            "height": "100%",
            "boxSizing": "border-box",
            "overflow": "auto"
        }
    }, wrappedContent);

    // 2. Dialog-Element erstellen
    const elem = e("dialog.vsmodal", {
        "id": id,
        "style": {
            "border": "var(--vs-panel-border, 1px solid silver)",
            "backgroundColor": "var(--vs-panel-bgcolor, white)",
            "color": "var(--vs-panel-color, #111827)",
            "fontFamily": "'Courier New', Courier, monospace",
            "padding": "0",
            "boxShadow": "0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)",
            "borderRadius": "4px",
            "outline": "none"
        }
    }, [closeBtn, contentContainer]);

    // Positionieren & Dimensionieren über ldom-Klassen
    n(elem).setXYWH(1, 1, w, h);
    n(elem).centerWinX();
    n(elem).centerWinY();

    // 3. Beim Klick auf den abgedunkelten Hintergrund (Backdrop) schließen
    elem.addEventListener("click", (ev) => {
        const rect = elem.getBoundingClientRect();
        const clickInside = (
            ev.clientX >= rect.left &&
            ev.clientX <= rect.right &&
            ev.clientY >= rect.top &&
            ev.clientY <= rect.bottom
        );
        if (!clickInside) {
            elem.close();
        }
    });

    // 4. Hilfsfunktion zum komfortablen modalen Öffnen & automatischen Einhängen im DOM
    elem.showModalWin = function() {
        if (!elem.isConnected) {
            document.body.appendChild(elem);
        }
        elem.showModal();
        
        // Nach dem Öffnen Zentrierung aktualisieren falls Fenstergröße abweicht
        n(elem).centerWinX();
        n(elem).centerWinY();
    };

    return elem;
}
