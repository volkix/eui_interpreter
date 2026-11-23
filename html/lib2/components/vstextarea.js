import { e } from "../../lib2/ldom.js";
import vsevent from "../../lib2/vsevent.js";



/**
 * vstextarea
 * @param {type} id
 * @param {type} text
 * @returns {vsinput.elem}
 */
export function vstextarea(id, text) {
    let elem = e("textarea", {
        "id": id,
        "event": {
            "blur": function (e) {

                if (e.target.value != e.target.oldvalue) {
                    vsevent.send("changevalue", {
                        "id": e.target.id,
                        "type": "vs-input",
                        "oldvalue": e.target.oldvalue,
                        "newvalue": e.target.value
                    });
                    e.target.oldvalue = e.target.value

                }
            }
        },
        "func": {
            "setValue": function (/* string */ v) {
                elem.value = v;
                vsevent.send("changevalue", {
                    "id": elem.id,
                    "type": "vs-input",
                    "oldvalue": elem.oldvalue,
                    "newvalue": elem.value
                });
            },
            "getValue": function () {
                return elem.value;
            }
        },
        "prop": {
            "value": text,
            "oldvalue": text
        }
    });

    return elem;
}
