import { e, _, n } from "../lib2/ldom.js";
import * as ui from "../lib2/ui.js";

import { defs } from "./defs.js";


import "./events.js";
import "./handler.js";


let mybutt = ui.vsbutton("mybutt", [e("h3", "meinbutton")]);
let tabelle = n(ui.vsgrid("tab", defs.grid1)).setXYWH(100, 400, 400, 400).elem()
console.log(tabelle)
tabelle.setData([
    {
        "vorname": "volker",
        "nachname": "schulte"
    },
    {
        "vorname": "volker2",
        "nachname": "schulte"
    }

])
tabelle.render();
tabelle.render();


_("cont").append(mybutt,
    tabelle,
    
    ui.vscollapse("mycoll",[{
                "header":"hallo header",
                "inhalt" :[ui.vscollapse("xxx",[{
                        "header":"hallo header",
                        "inhalt" :[e("div",{"style":{
                                "padding-top":"5px"
                        }},"jkfkfkf")]
                },{
                        "header":"hallo header",
                        "inhalt" : "<h4>hallo inhalt</h4>"
                },{
                        "header":"hallo header",
                        "inhalt" : "<h4>hallo inhalt</h4>"
                }],true)]
        },{
                "header":"hallo header",
                "inhalt" : "<h4>hallo inhalt</h4>"
        },{
                "header":"hallo header",
                "inhalt" : "<h4>hallo inhalt</h4>"
        }],true)
);








