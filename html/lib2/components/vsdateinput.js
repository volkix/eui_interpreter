import { e } from "../../lib2/ldom.js";
import vsevent from "../../lib2/vsevent.js";


import vsdate from "../../lib2/vsdate.js";

/**
 * vsdateinput
 * @param {type} id
 * @param {type} text
 * @returns {vsdateinput.elem}
 */
export function vsdateinput(id, text) {
    let elem = e("input", {
        "id": id,
        "class": "vs-date",
        "type": "date",
        "event": {
            "blur": function (e) {

                if (e.target.value != e.target.oldvalue) {
                    vsevent.send("changevalue", {
                        "id": e.target.id,
                        "type": "vs-date",
                        "oldvalue": e.target.oldvalue,
                        "newvalue": e.target.value
                    });
                    e.target.oldvalue = e.target.value

                }
            }

        },
        "func": {
            "setValue": function (/* string */ v) {
                this.value = vsdate.ddpmmpyyyy2yyyyMmmMdd(v);
                vsevent.send("changevalue", {
                    "id": elem.id,
                    "type": "vs-date",
                    "oldvalue": elem.oldvalue,
                    "newvalue": elem.value
                });
            },
            "getValue": function () {
                return vsdate.yyyyMmmMdd2ddpmmpyyyy(elem.value);
            }
        },
        "prop": {
            "value": vsdate.ddpmmpyyyy2yyyyMmmMdd(text),
            "oldvalue": vsdate.ddpmmpyyyy2yyyyMmmMdd(text)
        }

    });



    return elem;
}
