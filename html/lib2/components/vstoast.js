import { e } from "../../lib2/ldom.js";

/**
 * vstoast - Blendete eine nicht-blockierende Benachrichtigung ein (Toast)
 * @param {string|HTMLElement} message - Nachricht
 * @param {string} [type='info'] - 'info', 'success', 'warning' oder 'error'
 * @param {number} [duration=3000] - Dauer der Anzeige in Millisekunden
 */
export function vstoast(message, type = "info", duration = 3000) {
    // 1. Container für Toasts suchen oder erstellen
    let container = document.getElementById("vs-toast-container");
    if (!container) {
        container = e("div#vs-toast-container");
        document.body.appendChild(container);
    }

    const wrappedMessage = (message instanceof HTMLElement || message instanceof DocumentFragment)
        ? [message]
        : message;

    // 2. Toast-Element erstellen
    const toast = e(`div.vs-toast.vs-toast-${type}`, {
        "event": {
            "click": () => dismissToast()
        }
    }, wrappedMessage);

    container.appendChild(toast);

    // Reflow erzwingen und CSS-Transition via show-Klasse auslösen
    requestAnimationFrame(() => {
        toast.classList.add("show");
    });

    let autoCloseTimer = setTimeout(() => {
        dismissToast();
    }, duration);

    // Toast weich ausblenden und aus dem DOM entfernen
    const dismissToast = () => {
        clearTimeout(autoCloseTimer);
        toast.classList.remove("show");
        toast.addEventListener("transitionend", () => {
            toast.remove();
        });
    };
}
