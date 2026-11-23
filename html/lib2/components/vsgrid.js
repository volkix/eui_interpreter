import { e } from "../../lib2/ldom.js";
import vsnumber from "../vsnumber.js";

/**
 * vsgrid - Leichtgewichtiges, reaktives Grid mit integrierter Echtzeit-Suche,
 * Spaltensortierung (numerisch/lexikalisch) und Verankerung von Summenzeilen.
 * 
 * @param {string} id - Eindeutige ID
 * @param {Array<Object>} columns - Spaltenkonfiguration [{ title, field, width, align, bindfn }]
 * @returns {HTMLElement}
 */
export function vsgrid(id, columns, initialData = []) {
    let sortColIndex = -1;
    let sortAsc = true;

    // Header-Tabelle (für Sticky-Effekt)
    let elem = e("table", {
        "id": id + "_head",
        "class": "vs-table-sticky",
        "style": { "borderCollapse": "collapse", "position": "sticky", "top": "29px", "zIndex": "9", "tableLayout": "fixed" }
    });
    
    // Daten-Tabelle
    let elem2 = e("table", {
        "id": id + "_data",
        "class": "vs-table",
        "style": { "borderCollapse": "collapse", "tableLayout": "fixed" }
    });

    // 1. Sucheingabe
    const searchInput = e("input.vs-spreadsheet-search", {
        "placeholder": " Suchen...",
        "style": { "position": "sticky", "top": "0px", "zIndex": "10", "width": "calc(100% - 18px)", "boxSizing": "border-box" },
        "event": {
            "input": (ev) => filterRows(ev.target.value)
        }
    });

    // Zeilen filtern
    const filterRows = (queryText) => {
        const query = queryText.toLowerCase();
        const rows = elem2.querySelectorAll("tr");
        
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

    // 2. Spalten-Sortierung
    const sortByColumn = (c) => {
        const col = grid._columns[c];
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
        const pinnedBottomRecords = grid._data.filter(item => item.pinned === "bottom" || item.isTotal === true || item.id === "SUMME");
        const recordsToSort = grid._data.filter(item => item.pinned !== "bottom" && item.isTotal !== true && item.id !== "SUMME");

        const isNumeric = (val) => {
            if (val === undefined || val === null || val === "") return false;
            const clean = String(val).trim().replace(/\./gi, "").replace(/,/gi, ".");
            return !isNaN(clean) && clean !== "";
        };

        recordsToSort.sort((a, b) => {
            const valA = a[field] ?? "";
            const valB = b[field] ?? "";

            const isNumA = isNumeric(valA);
            const isNumB = isNumeric(valB);

            if (isNumA && isNumB) {
                const numA = vsnumber.s2n(valA, 4);
                const numB = vsnumber.s2n(valB, 4);
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
                
                // Header-Zeile bauen
                let htr = e("tr", { "class": "vs-thead-tr" });
                grid._columns.forEach((col, c) => {
                    let titleText = col.title;
                    if (sortColIndex === c) {
                        titleText += sortAsc ? " ▲" : " ▼";
                    }

                    const isSortable = col.sortable !== false && col.issortable !== false;

                    let hth = e("th", {
                        "class": "vs-thead-th vs-spreadsheet-col-header",
                        "style": {
                            "width": col.width,
                            "cursor": isSortable ? "pointer" : "default"
                        },
                        "event": isSortable ? {
                            "click": () => sortByColumn(c)
                        } : {}
                    }, titleText);
                    htr.append(hth);
                });
                elem.append(htr);

                // Daten-Zeilen bauen
                let anzds = grid._data.length;
                for (let i = 0;
                    i < anzds; i++) {
                    let btr = e("tr", { "class": "vs-tbody-tr" });
                    grid._columns.forEach(col => {
                        const field = col.field || col.title;
                        const displayVal = col.bindfn 
                            ? col.bindfn(grid._data[i], i) 
                            : (grid._data[i][field] ?? "");

                        let cellContent;
                        if (displayVal instanceof HTMLElement || displayVal instanceof DocumentFragment) {
                            cellContent = displayVal;
                        } else {
                            cellContent = document.createTextNode(displayVal === undefined || displayVal === null ? "" : String(displayVal));
                        }

                        let btd = e("td", {
                            "class": "vs-tbody-td vs-spreadsheet-cell",
                            "style": {
                                "text-align": col.align,
                                "width": col.width
                            }
                        }, [cellContent]);
                        btr.append(btd);
                    });
                    elem2.append(btr);
                }
            }
        },
        "prop": {
            "_data": JSON.parse(JSON.stringify(initialData)),
            "_columns": columns
        }
    }, [searchInput, elem, elem2]);

    // Initiales Rendern ausführen
    grid.render();

    return grid;
}