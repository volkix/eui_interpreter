import vsevent from "../lib2/vsevent.js";
console.log("events werden vorbereitet")

let d = document;
vsevent.setdebug(true)

window.addEventListener("resize", ev => {

    location.reload()   
    
})

console.log("event-vorbereitung abgeschlossen")

 