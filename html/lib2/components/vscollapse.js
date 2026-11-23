import { e } from "../../lib2/ldom.js";

/**
 * vscollapse - Akkordeon / Collapsible-Komponente basierend auf HTML5 details/summary
 * @param {string} id - Eindeutige ID des Wrappers
 * @param {Array<Object>} inhalte - Array von Objekten [{ header, inhalt }]
 * @param {boolean} [notmultiple=false] - Wenn true, verhalten sich die Boxen als exklusives Akkordeon
 * @returns {HTMLElement}
 */
export function vscollapse(id, inhalte, notmultiple = false) {
    const detailElements = inhalte.map((element, i) => {
        const detailAttrs = {
            "id": `${id}_detail${i}`,
            "class": "vscollapsedetail"
        };
        
        // Exklusives Akkordeon-Gruppe über das name-Attribut binden
        if (notmultiple === true) {
            detailAttrs.name = `${id}_detail_group`;
        }

        // Sicherheitsregel für ldom.js: DOM-Objekte (Typ 'object') müssen in ein Array
        // gewrappt werden, da ldom.js sie sonst fälschlicherweise als Attribut-Objekt interpretiert.
        const wrappedContent = (element.inhalt instanceof HTMLElement || element.inhalt instanceof DocumentFragment)
            ? [element.inhalt]
            : element.inhalt;

        return e("details", detailAttrs, [
            e("summary.vscollapsesummary", { "id": `${id}_summary${i}` }, element.header),
            e("div", { "style": { "padding-left": "10px" } }, wrappedContent)
        ]);
    });

    return e("div.detailbox", { "id": id }, detailElements);
}