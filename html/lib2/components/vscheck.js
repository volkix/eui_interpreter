import { e } from "../../lib2/ldom.js";
import vsevent from "../../lib2/vsevent.js";

/**
 * 
 * @param {type} id
 * @returns {vscheck.elem}
 */

export function vscheck(id) {
    let elem = e("input", {
        "id": id,
        "class": "vs-check",
        "type": "checkbox",
        "func": {
            "setValue": function (b) {
                if (b) {
                    elem.checked = true;
                } else {
                    elem.checked = false;
                }
            },
            "getValue": function () {
                return elem.checked == true;
            }
        },
        "event": {
            "click": function (ev) {
                vsevent.send("check_click", {
                    "id": id,
                    "checked": elem.checked

                })
            }
        }
    });

    return elem;
}