/*
 * (c) Volker Schulte volkerschulte@gmail.com
 * Änderungswünsche willkommen.
 *
 */
/**
 *
 * @module vsajax
 */

import vsevent from "./vsevent.js";

export default class vsajax {
    /**
     *
     * synchrones holen einer ressource mit get
     * @param {String} url
     * @returns {String} responsetext
     */
    static get(url) {
        let x = new XMLHttpRequest();
        x.open("GET", url, false);
        x.setRequestHeader("Cache-Control", "no-cache");
        x.send(null);
        return x.responseText;
    }

    /**
     * für pdf-sachen verwendet als arraybuffer
     * @param {*} url 
     * @param {*} cb 
     */
    static getresponse(url, cb) {
        let x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState === 4 && x.status === 200) {
                try {
                    cb(x.response);
                } catch (e) {
                    alert(e);
                }
            }
        };

        x.open("GET", url, true);
        x.setRequestHeader("Cache-Control", "no-cache");
        x.responseType = "arraybuffer";
        x.send(null);
    }
    /**
     *
     *  asynchrones holen einer ressource mit get
     *  event asyncget
     * @param {String} url
     */
    static asyncget(url) {
        let x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState === 4 && x.status === 200) {
                try {
                    vsevent.send("asyncget", url, "nichts", x.responseText);
                } catch (e) {
                    alert(e);
                }
            }
        };

        x.open("GET", url, true);
        x.setRequestHeader("Cache-Control", "no-cache");
        x.send(null);
    }
    /**
     *
     *  synchrones holen einer ressource mit post
     * @param {String} url
     * @param {String} daten (optional)
     * @returns {String} responsetext
     */
    static post(url, daten) {
        let x = new XMLHttpRequest();
        x.open("POST", url, false);
        x.setRequestHeader("Method", "POST " + url + " HTTP/1.1");
        x.setRequestHeader("Content-Type", "text/plain;charset=utf-8");
        x.setRequestHeader("Cache-Control", "no-cache");
        x.send(daten || null);
        return x.responseText;
    }
    /**
     *
     *  asynchrones holen einer ressource mit post
     *  es erfolgt ein publish von url,daten,responsetext, also drei parameter beim subscribe
     *  asyncpost
     * @param {String} url
     * @param {String} daten (optional)
     
     */
    static asyncpost(url, daten) {
        let x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState === 4 && x.status === 200) {
                try {
                    vsevent.send("asyncpost", url, daten, x.responseText);
                } catch (e) {
                    alert(e);
                }
            }
        };

        x.open("POST", url, true);
        x.setRequestHeader("Method", "POST " + url + " HTTP/1.1");
        x.setRequestHeader("Content-Type", "text/plain;charset=utf-8");
        x.setRequestHeader("Cache-Control", "no-cache");
        x.send(daten || null);
        return x.responseText;
    }
    /**
     *
     *  synchrones holen einer ressource mit post im json-format
     *  
     * @param {String} url
     * @param {String} daten (optional)
     * @returns {String} responsetext
     */
    static postJSON(url, daten) {
        let x = new XMLHttpRequest();
        x.open("POST", url, false);
        x.setRequestHeader("Method", "POST " + url + " HTTP/1.1");
        x.setRequestHeader("Content-Type", "application/json;charset=utf-8");
        x.setRequestHeader("Cache-Control", "no-cache");
        x.send(daten || null);

        return x.responseText;
    }
    /**
     *
     *  asynchrones holen einer ressource mit post im json-format.
     * es erfolgt ein publish von url,daten,responsetext, also drei parameter beim subscribe
     * event asyncpostjson
     * @param {String} url
     * @param {String} daten (optional)
     */
    static asyncpostJSON(url, daten) {
        let x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState === 4 && x.status === 200) {
                try {
                    vsevent.send("asyncpostjson", url, daten, x.responseText);
                } catch (e) {
                    alert(e);
                }
            }
        };
        x.open("POST", url, true);
        x.setRequestHeader("Method", "POST " + url + " HTTP/1.1");
        x.setRequestHeader("Content-Type", "application/json;charset=utf-8");
        x.setRequestHeader("Cache-Control", "no-cache");
        x.send(daten || null);
    }
}
