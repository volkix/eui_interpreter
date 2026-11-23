import { e } from "../../lib2/ldom.js";

/**
 * vscontextmenu - Bindet ein benutzerdefiniertes Rechtsklick-Kontextmenü an ein Element
 * @param {HTMLElement} targetElement - Das Ziel-Element, auf das geklickt wird
 * @param {Array<Object>} items - Menü-Einträge [{ label, action, divider }]
 */
export function vscontextmenu(targetElement, items) {
    if (!targetElement) return;

    targetElement.addEventListener("contextmenu", (ev) => {
        ev.preventDefault();
        ev.stopPropagation();

        // Bestehendes Kontextmenü entfernen falls vorhanden
        removeMenu();

        // 1. Menü-Container erstellen
        const menu = e("div.vs-context-menu");

        // 2. Einträge erzeugen
        items.forEach(item => {
            if (item.divider === true) {
                menu.appendChild(e("div.vs-context-menu-divider"));
            } else {
                const menuItem = e("div.vs-context-menu-item", {
                    "event": {
                        "click": (clickEv) => {
                            clickEv.stopPropagation();
                            removeMenu();
                            if (typeof item.action === "function") {
                                // Ausführen der Aktion mit Bezug auf das Target und das Original-Event
                                item.action(ev);
                            }
                        }
                    }
                }, item.label);
                menu.appendChild(menuItem);
            }
        });

        // 3. Im DOM einhängen und an der Maus positionieren
        document.body.appendChild(menu);
        
        // Verhindern, dass das Menü aus dem Viewport ragt
        const menuW = menu.offsetWidth || 150;
        const menuH = menu.offsetHeight || 100;
        const x = (ev.clientX + menuW > window.innerWidth) ? (window.innerWidth - menuW - 10) : ev.clientX;
        const y = (ev.clientY + menuH > window.innerHeight) ? (window.innerHeight - menuH - 10) : ev.clientY;

        menu.style.left = x + "px";
        menu.style.top = y + "px";

        // 4. Klick-Handler zum Schließen bei Klick außerhalb
        const onDocumentClick = () => {
            removeMenu();
        };

        // Timeout, damit der aktuelle Klick das Menü nicht direkt wieder schließt
        setTimeout(() => {
            document.addEventListener("click", onDocumentClick, { once: true });
        }, 10);
    });

    const removeMenu = () => {
        const activeMenus = document.querySelectorAll(".vs-context-menu");
        activeMenus.forEach(m => m.remove());
    };
}
