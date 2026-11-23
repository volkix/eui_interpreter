import { e } from "../../lib2/ldom.js";

/**
 * vstooltip - Bindet einen schwebenden Tooltip an ein beliebiges DOM-Element
 * @param {HTMLElement} targetElement - Das Ziel-Element für den Tooltip
 * @param {string} text - Der anzuzeigende Tooltip-Text
 */
export function vstooltip(targetElement, text) {
    if (!targetElement || !text) return;

    let tooltip = null;

    targetElement.addEventListener("mouseenter", () => {
        // Falls bereits ein Tooltip existiert, entfernen
        removeTooltip();

        // 1. Tooltip-Element erstellen
        tooltip = e("div.vs-tooltip", text);
        document.body.appendChild(tooltip);

        // 2. Position berechnen (Zentriert über dem Ziel-Element)
        const targetRect = targetElement.getBoundingClientRect();
        
        // Reflow erzwingen, um die tatsächlichen Dimensionen des Tooltips auslesen zu können
        const tooltipW = tooltip.offsetWidth;
        const tooltipH = tooltip.offsetHeight;

        let left = targetRect.left + (targetRect.width - tooltipW) / 2;
        let top = targetRect.top - tooltipH - 8;

        // Ränder-Checks (nicht aus dem Bildschirm schieben)
        if (left < 10) left = 10;
        if (left + tooltipW > window.innerWidth) {
            left = window.innerWidth - tooltipW - 10;
        }
        if (top < 10) {
            // Falls oben kein Platz ist, unter dem Element anzeigen
            top = targetRect.bottom + 8;
        }

        tooltip.style.left = left + "px";
        tooltip.style.top = top + "px";

        // 3. Sichtbar machen
        requestAnimationFrame(() => {
            if (tooltip) tooltip.classList.add("show");
        });
    });

    targetElement.addEventListener("mouseleave", () => {
        removeTooltip();
    });

    // Sicherheitshalber auch beim Klicken schließen
    targetElement.addEventListener("click", () => {
        removeTooltip();
    });

    const removeTooltip = () => {
        if (tooltip) {
            tooltip.remove();
            tooltip = null;
        }
    };
}
