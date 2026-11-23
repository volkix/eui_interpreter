import { e, n } from "../../lib2/ldom.js";
import vsevent from "../../lib2/vsevent.js";



/**
 * 
 * @param {type} id
 * @param {array of object} combo
 * @returns {vscombo.elem}
 */
export function vscombo(id, combo) {
    let elem = e("select", {
        "id": id,
        "class": "vs-combo",
        "event": {
            "change": function (ele) {
                vsevent.send("changeselect", {
                    id: id,
                    value: ele.target.value,
                });
            }
        },
        "func": {
            "setLabel": function (v) {
                for (let option of elem.options) {
                    if (option.label == "" + v) {
                        option.selected = true;
                        return;
                    }
                }
            },
            "setValue": function (v) {
                for (let option of elem.options) {
                    if (option.value == "" + v) {
                        option.selected = true;
                        return;
                    }
                }
            },
            "getLabel": function () {

                for (let option of elem.options) {
                    if (option.selected == true) {

                        return option.label;
                    }
                }

                return this.value;
            },
            "getValue": function () {

                for (let option of elem.options) {
                    if (option.selected == true) {

                        return option.value;
                    }
                }

                return this.value;
            }
        }

    });

    combo.forEach((ele) => {
        let tmp = e("option", {
            "label": ele.label,
            "value": ele.value,
            "selected": false
        })
        n(elem).append(tmp);
    })



    return elem;
}
