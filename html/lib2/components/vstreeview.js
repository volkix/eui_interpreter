import { e } from "../../lib2/ldom.js";

/**
 * vstreeview
 * @param {string} id - Eindeutige ID
 * @param {Array<Object>|Object} treeData - Hierarchisches Knoten-Array oder einzelner Wurzelknoten
 * @returns {HTMLElement}
 */
export function vstreeview(id, treeData) {
    const data = Array.isArray(treeData) ? treeData : [treeData];

    // Rekursive Funktion zum Aufbau eines einzelnen Knotens
    const buildNode = (nodeData, index, prefixId) => {
        const nodeId = `${prefixId}_node_${index}`;
        const hasChildren = Array.isArray(nodeData.children) && nodeData.children.length > 0;
        const hasContent = nodeData.content instanceof HTMLElement;
        const isExpandable = hasChildren || hasContent;
        const isExpanded = nodeData.expanded === true;

        // 1. Knotenelement erstellen
        const li = e("li.vs-treeview-node", { id: nodeId });

        // 2. Header-Zeile (Pfeil + Label)
        const toggle = e("span.vs-treeview-toggle", "▼");
        if (!isExpandable) {
            toggle.classList.add("empty");
        } else if (!isExpanded) {
            toggle.classList.add("collapsed");
        }

        const labelContainer = e("div.vs-treeview-label-container");
        if (nodeData.label instanceof HTMLElement) {
            labelContainer.appendChild(nodeData.label);
        } else {
            labelContainer.textContent = String(nodeData.label || "");
        }

        const header = e("div.vs-treeview-header", [toggle, labelContainer]);
        li.appendChild(header);

        // 3. Untergeordneter Bereich (Container für Kinder oder Inhalt)
        if (isExpandable) {
            const contentContainer = e("div.vs-treeview-content-container");
            if (!isExpanded) {
                contentContainer.classList.add("collapsed");
            }

            // Kinder rekursiv einbetten
            if (hasChildren) {
                const ul = e("ul");
                nodeData.children.forEach((childNode, childIdx) => {
                    ul.appendChild(buildNode(childNode, childIdx, nodeId));
                });
                contentContainer.appendChild(ul);
            }

            // Beliebigen Inhalt (z.B. vsspreadsheetgrid) direkt einhängen
            if (hasContent) {
                contentContainer.appendChild(nodeData.content);
            }

            li.appendChild(contentContainer);

            // 4. Klick-Handler zum Auf- und Zuklappen
            header.addEventListener("click", (ev) => {
                // Klicks auf interaktive Formularelemente/Buttons innerhalb des Labels nicht stören
                if (ev.target.tagName === "BUTTON" || 
                    ev.target.tagName === "INPUT" || 
                    ev.target.tagName === "SELECT" || 
                    ev.target.closest("button, input, select")) {
                    return;
                }

                toggle.classList.toggle("collapsed");
                contentContainer.classList.toggle("collapsed");
            });
        }

        return li;
    };

    // Haupt-Wrapper (Wurzel-Liste)
    const rootUl = e("ul.vs-treeview", { id: id });
    data.forEach((nodeData, idx) => {
        rootUl.appendChild(buildNode(nodeData, idx, id));
    });

    return rootUl;
}
