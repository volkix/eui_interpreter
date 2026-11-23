import { e } from "../../lib2/ldom.js";

/**
 * vsgroup - Erstellt eine Feldbereichs-Gruppe (fieldset/legend)
 * @param {string} id - Eindeutige ID
 * @param {string|HTMLElement} titel - Titel der Gruppe
 * @param {HTMLElement|Array|string} inhalt - Inhalt der Gruppe (einzelnes Widget, Array oder Text)
 * @returns {HTMLElement}
 */
export function vsgroup(id, titel, inhalt) {
    // Sicherheitsregel für ldom.js: DOM-Objekte im Titel in ein Array wrappen
    const wrappedTitle = (titel instanceof HTMLElement || titel instanceof DocumentFragment) 
        ? [titel] 
        : titel;

    const legend = e(`legend#${id}_legend`, wrappedTitle);
    const children = [legend];
    
    // Inhalt normalisieren und alle Nicht-Nodes (z.B. Strings) in valide TextNodes umwandeln
    const rawInhalt = Array.isArray(inhalt) ? inhalt : [inhalt];
    const processedContent = rawInhalt.map(item => {
        if (item instanceof HTMLElement || item instanceof DocumentFragment) {
            return item;
        }
        // Verwandelt rohe Strings/Nummern in TextNodes, damit ldom.js nicht abstürzt
        return document.createTextNode(String(item === undefined || item === null ? "" : item));
    });

    children.push(...processedContent);

    return e(`fieldset#${id}`, children);
}
