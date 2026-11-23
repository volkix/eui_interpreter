import { e } from "../../lib2/ldom.js";

/**
 * vsblocker
 * @param {string} id
 * @param {number|string} zindex
 * @returns {undefined}
 */
export function vsblocker(id, zindex) {
    let elem = e(`.blocker#${id}`, {
        "style": {
            "z-index": zindex
        }
    });
    document.body.append(elem);
}