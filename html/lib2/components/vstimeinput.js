import { e } from "../../lib2/ldom.js";
import vsevent from "../../lib2/vsevent.js";


/**
 * vstimeinput
 * @param {type} id
 * @param {type} text
 * @returns {vsdateinput.elem}
 */
export function vstimeinput(id, text) {
    let elem = e("input", {
        "id": id,
        "class": "vs-time",
        "type": "time",
        "event": {
            "blur": function (e) {

                if (e.target.value != e.target.oldvalue) {
                    vsevent.send("changevalue", {
                        "id": e.target.id,
                        "type": "vs-time",
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
                    "type": "vs-time",
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
