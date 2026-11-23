import { e } from "../../lib2/ldom.js";

/**
 * vssplitter - Erstellt ein geteiltes Layout mit einer verschiebbaren Trennlinie
 * @param {string} id - Eindeutige ID
 * @param {HTMLElement} leftPane - Linke oder obere Ansicht
 * @param {HTMLElement} rightPane - Rechte oder untere Ansicht
 * @param {string} [direction='horizontal'] - 'horizontal' (Spalten) oder 'vertical' (Zeilen)
 * @param {string} [initialSize='250px'] - Startbreite bzw. Starthöhe des ersten Panels
 * @returns {HTMLElement}
 */
export function vssplitter(id, leftPane, rightPane, direction = "horizontal", initialSize = "250px") {
    const isHoriz = direction === "horizontal";

    // Sicherheitsregel für ldom.js: DOM-Elemente in ein Array wrappen
    const wrappedLeft = (leftPane instanceof HTMLElement || leftPane instanceof DocumentFragment) ? [leftPane] : leftPane;
    const wrappedRight = (rightPane instanceof HTMLElement || rightPane instanceof DocumentFragment) ? [rightPane] : rightPane;

    // 1. Die Pane-Container erstellen
    const pane1 = e(`div.vs-splitter-pane#${id}_pane1`, {
        "style": {
            "flex": "0 0 auto",
            "position": "relative",
            [isHoriz ? "width" : "height"]: initialSize
        }
    }, wrappedLeft);

    const bar = e(`div.vs-splitter-bar#${id}_bar`, {
        "style": {
            [isHoriz ? "width" : "height"]: "6px",
            "cursor": isHoriz ? "col-resize" : "row-resize"
        }
    });

    const pane2 = e(`div.vs-splitter-pane#${id}_pane2`, {
        "style": {
            "flex": "1 1 0%",
            "position": "relative",
            [isHoriz ? "width" : "height"]: "0" // Erlaubt korrektes Schrumpfen
        }
    }, wrappedRight);

    // 2. Drag & Drop Listener an der Bar registrieren
    bar.addEventListener("mousedown", (ev) => {
        ev.preventDefault();

        const startX = ev.clientX;
        const startY = ev.clientY;
        const startSize = isHoriz ? pane1.offsetWidth : pane1.offsetHeight;

        const onMouseMove = (moveEv) => {
            const delta = isHoriz ? (moveEv.clientX - startX) : (moveEv.clientY - startY);
            const newSize = Math.max(50, startSize + delta); // Minimalgröße 50px
            pane1.style[isHoriz ? "width" : "height"] = newSize + "px";
        };

        const onMouseUp = () => {
            document.removeEventListener("mousemove", onMouseMove);
            document.removeEventListener("mouseup", onMouseUp);
        };

        document.addEventListener("mousemove", onMouseMove);
        document.addEventListener("mouseup", onMouseUp);
    });

    // 3. Haupt-Container zurückgeben
    return e(`div.vs-splitter-container#${id}`, {
        "style": {
            "display": "flex",
            "flexDirection": isHoriz ? "row" : "column",
            "width": "100%",
            "height": "100%"
        }
    }, [pane1, bar, pane2]);
}
