import { e } from "../../lib2/ldom.js";
import vsevent from "../../lib2/vsevent.js";

/**
 * vsbutton
 * @param {string} id
 * @param {string} text
 * @returns {HTMLElement}
 */
export function vsbutton(id, text) {
    return e(`button.vs-button#${id}`, {
        "event": {
            "click": function () {
                vsevent.send("button_click", { "id": id });
            }
        }
    }, text);
}