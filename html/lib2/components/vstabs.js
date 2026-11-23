import { e } from "../../lib2/ldom.js";

/**
 * vstabs - Erstellt ein Tab-Steuerelement zum Umschalten zwischen verschiedenen Ansichten
 * @param {string} id - Eindeutige ID
 * @param {Array<Object>} tabs - Array von Objekten [{ title, content }]
 * @returns {HTMLElement}
 */
export function vstabs(id, tabs) {
    const tabButtons = [];
    const tabPanes = [];

    tabs.forEach((tab, index) => {
        const isActive = index === 0;

        // Tab-Schaltfläche erstellen
        const btn = e("button.vs-tab-btn", {
            "id": `${id}_btn_${index}`,
            "class": isActive ? "active" : "",
            "event": {
                "click": () => selectTab(index)
            }
        }, tab.title);
        tabButtons.push(btn);

        // Sicherheitsregel für ldom.js: DOM-Elemente in Arrays wrappen
        const wrappedContent = (tab.content instanceof HTMLElement || tab.content instanceof DocumentFragment)
            ? [tab.content]
            : tab.content;

        // Inhalt-Container für dieses Tab erstellen
        const pane = e(`div.vs-tab-pane#${id}_pane_${index}`, {
            "class": isActive ? "active" : "",
            "style": { "display": isActive ? "block" : "none" }
        }, wrappedContent);
        tabPanes.push(pane);
    });

    const selectTab = (index) => {
        tabButtons.forEach((btn, idx) => {
            if (idx === index) {
                btn.classList.add("active");
            } else {
                btn.classList.remove("active");
            }
        });

        tabPanes.forEach((pane, idx) => {
            if (idx === index) {
                pane.classList.add("active");
                pane.style.display = "block";
            } else {
                pane.classList.remove("active");
                pane.style.display = "none";
            }
        });
    };

    const headerBar = e("ul.vs-tab-headers", tabButtons.map(btn => e("li", [btn])));
    const contentArea = e("div.vs-tab-contents", tabPanes);

    return e(`div.vs-tabs#${id}`, [headerBar, contentArea]);
}
