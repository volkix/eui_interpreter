import { e } from "../../lib2/ldom.js";
import vsevent from "../../lib2/vsevent.js";

import vsnumber from "../../lib2/vsnumber.js";


/**
 * vsnuminput
 * @param {type} id
 * @param {type} text
 * @param {type} nk
 * @returns {vsnuminput.elem}
 */
export function vsnuminput(id, text, nk) {
    let elem = e("input", {
        "id": id,
        "class": "vs-number",
        "type": "text",
        "prop": {
            "nk": nk,
            "value": vsnumber.fz(text, nk),
            "oldvalue": vsnumber.fz(text, nk)
        },
        "event": {
            "blur": function (e) {
                e.target.value = vsnumber.fz(e.target.value, nk)
                if (e.target.value != e.target.oldvalue) {
                    vsevent.send("changevalue", {
                        "id": e.target.id,
                        "type": "vs-number" + nk,
                        "oldvalue": e.target.oldvalue,
                        "newvalue": e.target.value
                    });
                    e.target.oldvalue = e.target.value

                }
            }
        },
        "func": {
            "setValue": function (v) {
                elem.value = vsnumber.fz(v, elem.nk);
                vsevent.send("changevalue", {
                    "id": elem.id,
                    "type": "vs-number" + elem.nk,
                    "oldvalue": elem.oldvalue,
                    "newvalue": elem.value
                });

            },
            "getValue": function () {
                return elem.value;
            },
            "setNumValue": function (v) {
                elem.setValue(vsnumber.n2s(v, elem.nk));

            },
            "getNumValue": function () {
                return vsnumber.s2n(elem.getvalue(), elem.nk);
            }
        }
    });


    return elem;
}