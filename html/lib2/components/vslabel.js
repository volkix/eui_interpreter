import { e } from "../../lib2/ldom.js";

/**
 * vslabel
 * @param {string} id
 * @param {string} text
 * @returns {HTMLElement}
 */
export function vslabel(id, text) {
    return e(`.vs-label#${id}`, text);
}