import { e, n } from "../lib2/ldom.js";
import * as ui from "../lib2/ui.js";


export const defs = {
    "grid1": [
        {
            "title": "vorname",
            "align": "left",
            "width": "40%",
            "bindfn": function (d, i) {
                return e("span", d.vorname)
            }
        },
        {
            "title": "nachname",
            "align": "left",
            "width": "40%",
            "bindfn": function (d, i) {
                return e("h5", d.nachname)
            }

        },
        {
            "title": "tool",
            "align": "center",
            "width": "20%",
            "bindfn": function (d, i) {
                let b = ui.vsbutton("b" + i, "");
                n(b).setstyle({
                    "width": "20px",
                    "height": "20px"
                })

                return b
            }

        }
    ]
}
