import { e } from "../../lib2/ldom.js";
import vsnumber from "../vsnumber.js";

/**
 * vsgrid - Leichtgewichtiges, reaktives Grid mit integrierter Echtzeit-Suche,
 * Spaltensortierung (numerisch/lexikalisch), fixierter Spaltenbreite und Verankerung von Summenzeilen.
 * 
 * @param {string} id - Eindeutige ID
 * @param {Array<Object>} columns - Spaltenkonfiguration [{ title, field, width, align, bindfn, sortable }]
 * @param {Array} initialData - Initiale Datensätze (Array von Objekten oder Array von Arrays)
 * @returns {HTMLElement}
 */
export function vsgrid(id, columns, initialData = []) {
    let sortColIndex = -1;
    let sortAsc = true;

    // Header-Tabelle (für Sticky-Effekt)
    let elem = e("table", {
        "id": id + "_head",
        "class": "vs-table-sticky",
        "style": {
            "borderCollapse": "collapse",
            "position": "sticky",
            "top": "29px",
            "zIndex": "9",
            "tableLayout": "fixed",
            "width": "100%",
            "backgroundColor": "var(--vs-blau, #41518b)",
            "color": "white"
        }
    });
    
    // Daten-Tabelle
    let elem2 = e("table", {
        "id": id + "_data",
        "class": "vs-table vs-table-responsive",
        "style": {
            "borderCollapse": "collapse",
            "tableLayout": "fixed",
            "width": "100%"
        }
    });

    // Berechne Gesamtmindestbreite aller Spalten (falls Pixelbreiten angegeben sind)
    let totalPx = 0;
    (columns || []).forEach(col => {
        let w = col.width || "";
        if (typeof w === "string" && w.endsWith("px")) {
            let px = parseInt(w, 10);
            if (!isNaN(px)) totalPx += px;
        }
    });
    if (totalPx > 0) {
        elem.style.minWidth = totalPx + "px";
        elem2.style.minWidth = totalPx + "px";
    }

    // 1. Sucheingabe
    const searchInput = e("input.vs-spreadsheet-search", {
        "placeholder": " Suchen...",
        "style": { "position": "sticky", "top": "0px", "zIndex": "10", "width": "100%", "boxSizing": "border-box" },
        "event": {
            "input": (ev) => filterRows(ev.target.value)
        }
    });

    // Zeilen filtern
    const filterRows = (queryText) => {
        const query = (queryText || "").toLowerCase();
        const rows = elem2.querySelectorAll("tbody tr");
        
        rows.forEach((tr, r) => {
            const record = grid._data[r];
            
            // Gepinnte Summenzeilen immer anzeigen
            if (record && (record.pinned === "bottom" || record.isTotal === true || record.id === "SUMME")) {
                tr.style.display = "";
                return;
            }

            const cells = tr.querySelectorAll("td");
            const matches = Array.from(cells).some(td => {
                const input = td.querySelector("input, textarea, select");
                const val = (input ? input.value : td.textContent).toLowerCase();
                return val.includes(query);
            });
            tr.style.display = matches ? "" : "none";
        });
    };

    // 2. Spalten-Sortierung (unterstützt Objekte und Arrays)
    const sortByColumn = (c) => {
        const col = grid._columns[c];
        if (!col) return;
        const field = col.field || col.title;
        const isSortable = col.sortable !== false && col.issortable !== false;
        if (!isSortable) return;

        if (sortColIndex === c) {
            sortAsc = !sortAsc;
        } else {
            sortColIndex = c;
            sortAsc = true;
        }

        // Summenzeilen unten verankert halten und von Sortierung ausschließen
        const pinnedBottomRecords = grid._data.filter(item => item && (item.pinned === "bottom" || item.isTotal === true || item.id === "SUMME"));
        const recordsToSort = grid._data.filter(item => !item || (item.pinned !== "bottom" && item.isTotal !== true && item.id !== "SUMME"));

        const isNumeric = (val) => {
            if (val === undefined || val === null || val === "") return false;
            const clean = String(val).trim().replace(/\./gi, "").replace(/,/gi, ".").replace(/[^0-9.-]/g, "");
            return !isNaN(clean) && clean !== "";
        };

        recordsToSort.sort((a, b) => {
            const rawA = Array.isArray(a) ? a[c] : (a ? (a[field] !== undefined ? a[field] : a[c]) : "");
            const rawB = Array.isArray(b) ? b[c] : (b ? (b[field] !== undefined ? b[field] : b[c]) : "");
            const valA = (rawA === undefined || rawA === null) ? "" : rawA;
            const valB = (rawB === undefined || rawB === null) ? "" : rawB;

            const isNumA = isNumeric(valA);
            const isNumB = isNumeric(valB);

            if (isNumA && isNumB) {
                const parseNum = (v) => {
                    if (vsnumber && typeof vsnumber.s2n === 'function') {
                        try { return vsnumber.s2n(String(v), 4); } catch(e){}
                    }
                    var n = parseFloat(String(v).replace(/\./g, "").replace(/,/g, ".").replace(/[^0-9.-]/g, ""));
                    return isNaN(n) ? 0 : n;
                };
                const numA = parseNum(valA);
                const numB = parseNum(valB);
                return sortAsc ? numA - numB : numB - numA;
            }

            return sortAsc 
                ? String(valA).localeCompare(String(valB))
                : String(valB).localeCompare(String(valA));
        });

        grid._data = [...recordsToSort, ...pinnedBottomRecords];
        
        grid.render();
        if (searchInput.value) {
            filterRows(searchInput.value);
        }
    };

    // 3. Grid-Container
    let grid = e("div", {
        "id": id,
        "class": "vsgrid-container",
        "style": { "overflow": "auto", "maxHeight": "480px", "position": "relative" },
        "func": {
            "setData": function (arrdata) {
                grid._data = arrdata;
                grid.render();
                if (searchInput.value) {
                    filterRows(searchInput.value);
                }
            },
            "render": function () {
                elem.innerHTML = "";
                elem2.innerHTML = "";
                
                // Matching colgroup für absolute Pixel-Präzision zwischen Header & Body
                const makeColGroup = () => {
                    let cg = e("colgroup");
                    grid._columns.forEach(col => {
                        let w = col.width || "";
                        let colEl = e("col", w ? { "style": { "width": w }, "width": w } : {});
                        cg.append(colEl);
                    });
                    return cg;
                };

                elem.append(makeColGroup());
                elem2.append(makeColGroup());

                // Header-Zeile bauen
                let thead = e("thead");
                let htr = e("tr", { "class": "vs-thead-tr" });
                grid._columns.forEach((col, c) => {
                    let titleText = col.title;
                    if (sortColIndex === c) {
                        titleText += sortAsc ? " ▲" : " ▼";
                    }

                    const isSortable = col.sortable !== false && col.issortable !== false;

                    let hth = e("th", {
                        "class": "vs-thead-th vs-spreadsheet-col-header",
                        "width": col.width || "",
                        "style": {
                            "width": col.width || "",
                            "cursor": isSortable ? "pointer" : "default",
                            "boxSizing": "border-box"
                        },
                        "event": isSortable ? {
                            "click": () => sortByColumn(c)
                        } : {}
                    }, titleText);
                    htr.append(hth);
                });
                thead.append(htr);
                elem.append(thead);

                // Daten-Zeilen bauen
                let tbody = e("tbody");
                let anzds = grid._data.length;
                for (let i = 0; i < anzds; i++) {
                    let btr = e("tr", { "class": (i % 2 === 0 ? "vs-tbody-tr even" : "vs-tbody-tr odd") });
                    grid._columns.forEach((col, c) => {
                        const field = col.field || col.title;
                        let rawVal;
                        if (Array.isArray(grid._data[i])) {
                            rawVal = grid._data[i][c];
                        } else if (grid._data[i] && typeof grid._data[i] === 'object') {
                            rawVal = grid._data[i][field] !== undefined ? grid._data[i][field] : grid._data[i][c];
                        } else {
                            rawVal = "";
                        }

                        const displayVal = col.bindfn 
                            ? col.bindfn(grid._data[i], i) 
                            : (rawVal ?? "");

                        let btd = e("td", {
                            "class": "vs-tbody-td vs-spreadsheet-cell",
                            "width": col.width || "",
                            "data-label": col.title || field || ("col_" + c),
                            "style": {
                                "textAlign": col.align || "left",
                                "width": col.width || "",
                                "boxSizing": "border-box"
                            }
                        });

                        if (displayVal instanceof HTMLElement || displayVal instanceof DocumentFragment) {
                            btd.appendChild(displayVal);
                        } else if (typeof displayVal === 'string' && (displayVal.indexOf('<') !== -1 || displayVal.indexOf('&') !== -1)) {
                            btd.innerHTML = displayVal;
                        } else {
                            btd.textContent = (displayVal === undefined || displayVal === null) ? "" : String(displayVal);
                        }

                        btr.append(btd);
                    });
                    tbody.append(btr);
                }
                elem2.append(tbody);
            }
        },
        "prop": {
            "_data": JSON.parse(JSON.stringify(initialData || [])),
            "_columns": columns || []
        }
    }, [searchInput, elem, elem2]);

    // Initiales Rendern ausführen
    grid.render();

    return grid;
}
