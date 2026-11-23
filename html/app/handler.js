import vsevent from "../lib2/vsevent.js";
import { _ } from "../lib2/ldom.js";
console.log("handler werden vorbereitet")

let butt = {

    c_(mid) {
      
        switch (mid.id) {
            case "mybutt":
                _("inp").setValue("11.11.2011")
                break;

            default:
                console.log(mid);
                break;
        }


    }
}

vsevent.handle("button_click", mid => {

    butt["c_"](mid);
})
console.log("handler-vorbereitung beendet")
