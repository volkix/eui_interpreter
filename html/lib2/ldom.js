function isString(x) {
    return (typeof x == 'string' || typeof x == 'object' && x.toUpperCase && x.substr && x.charAt && x.trim && x.replace ? true : false);
}
/**
 * benutzung wie e() aber rückgabe das outerhtml-template
 * @param {type} elem
 * @param {type} args
 * @returns {e.newelem.outerHTML}
 */
export function t(elem, ...args) {
    return e(elem, ...args).outerHTML;
}
/**
 * 
 * @param {string} elem 
 * @param  {...any} args 
 * @returns HTMLElement
 */
export function e(elem, ...args) {
    let tagName = 'div';
    let id = null;
    let classes = [];

    if (typeof elem === 'string') {
        const parts = elem.split(/(?=[.#])/);
        if (parts[0] && !parts[0].startsWith('.') && !parts[0].startsWith('#')) {
            tagName = parts[0];
        }
        parts.forEach(part => {
            if (part.startsWith('#')) {
                id = part.slice(1);
            } else if (part.startsWith('.')) {
                classes.push(part.slice(1));
            }
        });
    } else {
        tagName = String(elem);
    }

    let newelem = document.createElement(tagName);
    if (id) {
        newelem.id = id;
    }
    if (classes.length > 0) {
        newelem.className = classes.join(' ');
    }

    args.forEach(element => {

        if (Array.isArray(element)) {

            element.forEach(e => {

                newelem.appendChild(e)
            })

        } else if (typeof element == 'object') {
            let att = element
            for (let v in att) {
                if (v === 'style') {
                    let ss = att[v]
                    for (let vv in ss) {
                        try {
                            newelem.style[vv] = ss[vv]
                        } catch (exception) {
                            //ignorieren
                        }
                    }
                } else if (v === 'event') {

                    let ss = att[v]
                    for (let vv in ss) {
                        try {
                            newelem.addEventListener(vv, ss[vv]);
                        } catch (exception) {
                            console.log("ex " + exception)
                        }
                    }

                } else if (v === 'prop') {

                    let ss = att[v]
                    for (let vv in ss) {
                        try {
                            newelem[vv] = ss[vv];
                        } catch (exception) {
                            console.log("ex " + exception)
                        }
                    }

                } else if (v === 'func') {

                    let ss = att[v]
                    for (let vv in ss) {
                        try {
                            newelem[vv] = ss[vv];
                        } catch (exception) {
                            console.log("ex " + exception)
                        }
                    }

                } else if (v === 'class') {
                    const existing = newelem.className;
                    newelem.className = existing ? existing + ' ' + att[v] : att[v];
                } else {
                    console.log("vs "+v+" "+att[v])
                    newelem.setAttribute(v, att[v])
                }
            }

        } else if (isString(element)) {
            newelem.innerHTML += element
        }


    });

    return newelem
}

/**
 * element holen per id
 * @param {string} id
 * @returns {null|Element}
 */
export function _(id) {
    return document.getElementById(id);
}
/**
 * element holen per id und dann in vsnode umwandeln
 * @param {string} selector
 * @returns {vsnodes}
 */
export function _n(selector) {
    let elem = _(selector);
    let arr = Array.of(elem);
    let vsn = new vsnodes(arr);
    return vsn;
}
/**
 * element in vsnode umwandeln
 * @param {type} elem
 * @returns {vsnodes}
 */
export function n(elem) {
    let arr = Array.of(elem);
    let vsn = new vsnodes(arr);
    return vsn;
}
/**
 * suche mit queryselector, rückgabe vsnodes
 * @param {type} selector
 * @param {type} startelement
 * @returns {vsnodes}
 */
export function $(selector, startelement = document) {
    return new vsnodes(startelement.querySelectorAll(selector))
}
/**
 * suche mit queryselector, rückgabe Nodelist Element
 * @param {type} selector
 * @param {type} startelement
 * @returns {Array of elements}
 */
export function $$(selector, startelement = document) {
    return [...startelement.querySelectorAll(selector)];
}
/**
 * ganz viele nützliche methoden
 * @type vsnodes
 */
export class vsnodes {
    #nodes
    constructor(nodes) {
        this.#nodes = nodes;
    }
    all(myfunction) {
        this.#nodes.forEach(myfunction);
        return this;
    }
    one() {
        return this.#nodes[0];
    }
    elem() {
        return this.#nodes[0];
    }
    setattr(obj) {
        this.#nodes.forEach(element => {
            for (let v in obj) {
                element.setAttribute(v, obj[v]);
            }
        });
        return this;
    }
    delattr(...arr) {
        this.#nodes.forEach(element => {
            arr.forEach(el => {
                element.removeAttribute(el)
            });
        });
        return this;
    }
    addclass(...arr) {
        this.#nodes.forEach(element => {
            arr.forEach(el => {

                if (!element.classList.contains(el)) {
                    element.classList.add(el)
                }
            });
        });
        return this;
    }
    removeclass(...arr) {
        this.#nodes.forEach(element => {
            arr.forEach(el => {

                if (element.classList.contains(el)) {
                    element.classList.remove(el)
                }
            });
        });
        return this;
    }
    toggleclass(...arr) {
        this.#nodes.forEach(element => {
            arr.forEach(el => {
                element.classList.toggle(el)

            });
        });
        return this;
    }
    setclass(str) {
        this.#nodes.forEach(element => {
            element.className = str
        });
        return this;
    }
    centerX() {
        this.#nodes.forEach(element => {
            let el = element.style.width.replace("px", "");
            let ep = element.parentNode.style.width.replace("px", "");
            let links = (ep - el) / 2;
            element.style.position = "absolute";
            element.style.left = links + "px";
        });
        return this
    }
    centerY() {
        this.#nodes.forEach(element => {
            let el = element.style.height.replace("px", "");
            let ep = element.parentNode.style.height.replace("px", "");
            let oben = (ep - el) / 2;
            element.style.position = "absolute";
            element.style.top = oben + "px";
        });
        return this;
    }
    centerWinX() {
        this.#nodes.forEach(element => {
            let el = element.style.width.replace("px", "");
            let ep = window.innerWidth;
            console.log("--> " + el + "#" + ep);
            let links = (ep - el) / 2;
            element.style.position = "absolute";
            element.style.left = links + "px";
        });
        return this;
    }
    centerWinY() {
        this.#nodes.forEach(element => {
            let el = element.style.height.replace("px", "");
            let ep = window.innerHeight;
            console.log("--> " + el + "#" + ep);
            let oben = (ep - el) / 2;
            element.style.position = "absolute";
            element.style.top = oben + "px";
        });
        return this;
    }
    setX(nr) {
        this.#nodes.forEach(element => {
            element.style.position = "absolute";
            element.style.left = nr + "px";
        });
        return this;
    }
    setY(nr) {
        this.#nodes.forEach(element => {
            element.style.position = "absolute";
            element.style.top = nr + "px";
        });
        return this;
    }
    setW(nr) {
        this.#nodes.forEach(element => {
            element.style.position = "absolute";
            element.style.width = nr + "px";
        });
        return this;
    }
    setH(nr) {
        this.#nodes.forEach(element => {
            element.style.position = "absolute";
            element.style.height = nr + "px";
        });
        return this;
    }
    getX() {
        let x;
        this.#nodes.forEach(element => {
            x = element.style.left.replace("px", "");
        });
        return x;
    }
    getY() {
        let x;
        this.#nodes.forEach(element => {
            x = element.style.top.replace("px", "");
        });
        return x;
    }
    getW() {
        let x;
        this.#nodes.forEach(element => {
            x = element.style.width.replace("px", "");
        });
        return x;
    }
    getH() {
        let x;
        this.#nodes.forEach(element => {
            x = element.style.height.replace("px", "");
        });
        return x;
    }
    getPosition() {

        let x;
        let y;
        let w;
        let h;
        this.#nodes.forEach(element => {
            x = element.style.left.replace("px", "");
            y = element.style.top.replace("px", "");
            w = element.style.width.replace("px", "");
            h = element.style.height.replace("px", "");
        });

        return {
            "x": x,
            "y": y,
            "w": w,
            "h": h
        };

    }
    setPosition(obj) {
        this.#nodes.forEach(element => {
            element.style.position = "absolute";
            element.style.left = obj.x + "px";
            element.style.top = obj.y + "px";
            element.style.width = obj.w + "px";
            element.style.height = obj.h + "px";
        });
        return this;
    }
    setXYWH(x, y, w, h) {
        this.#nodes.forEach(element => {
            element.style.position = "absolute";
            element.style.left = x + "px";
            element.style.top = y + "px";
            element.style.width = w + "px";
            element.style.height = h + "px";
        });
        return this;
    }
    setstyle(obj) {
        this.#nodes.forEach(element => {
            for (let v in obj) {
                try {
                    element.style[v] = obj[v]
                } catch (exception) {
                }
            }
        });
        return this;
    }
    delstyle(...arr) {
        this.#nodes.forEach(element => {
            arr.forEach(el => {
                try {
                    element.style[el] = ''
                } catch (exception) {
                }
            });
        });
        return this;
    }
    sethtml(...s) {
        this.#nodes.forEach(element => {
            let _s = "";
            s.forEach(ss => _s += ss)
            element.innerHTML = _s
        });
        return this;
    }
    appendhtml(...s) {
        this.#nodes.forEach(element => {
            let _s = ""
            s.forEach(ss => _s += ss)
            element.innerHTML += _s
        });
        return this;
    }
    append(...e) {
        this.#nodes.forEach(element => {
            e.forEach(ee => element.append(ee))
        });
        return this;

    }

    remove(...e) {
        this.#nodes.forEach(element => {
            e.forEach(ee => element.removeChild(ee))
        });
        return this;
    }
    removeself() {
        this.#nodes.forEach(element => {
            element.remove();
        });
        return this;
    }

    removeAllChilds() {
        this.#nodes.forEach(element => {
            while (element.firstChild) {
                element.removeChild(element.firstChild);
            }
        }
        );
        return this;

    }
}