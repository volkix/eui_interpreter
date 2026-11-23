import { e } from "../../lib2/ldom.js";

/**
 * vschart - Leichtgewichtige, native SVG-Diagramm-Komponente
 * @param {string} id - Eindeutige ID
 * @param {string} type - 'bar' (Säulen), 'line' (Linien) oder 'pie' (Kuchen)
 * @param {Array<Object>} data - Datenpunkte [{ label, value, color }]
 * @param {Object} [options={}] - Optionale Einstellungen (width, height, title)
 * @returns {HTMLElement}
 */
export function vschart(id, type, data, options = {}) {
    const width = options.width || 400;
    const height = options.height || 300;
    const title = options.title || "";

    // Hilfsfunktion zur Erstellung von SVG-Elementen (SVG benötigt eigenen Namespace!)
    const svgEl = (tag, attrs = {}, children = []) => {
        const el = document.createElementNS("http://www.w3.org/2000/svg", tag);
        for (let k in attrs) {
            if (Object.prototype.hasOwnProperty.call(attrs, k)) {
                if (k === "style" && typeof attrs[k] === "object") {
                    for (let s in attrs[k]) {
                        if (Object.prototype.hasOwnProperty.call(attrs[k], s)) {
                            el.style[s] = attrs[k][s];
                        }
                    }
                } else {
                    el.setAttribute(k, attrs[k]);
                }
            }
        }
        if (Array.isArray(children)) {
            children.forEach(c => {
                if (c instanceof Node) el.appendChild(c);
            });
        }
        return el;
    };

    const container = e("div.vs-chart-container", {
        "id": id,
        "style": {
            "display": "inline-block",
            "background": "#fff",
            "border": "1px solid #ccc",
            "padding": "12px",
            "fontFamily": "'Courier New', Courier, monospace",
            "boxSizing": "border-box"
        }
    });

    // Titel hinzufügen falls vorhanden
    if (title) {
        container.appendChild(e("h4", {
            "style": { "margin": "0 0 10px 0", "textAlign": "center", "color": "#374151" }
        }, title));
    }

    const svg = svgEl("svg", {
        "width": width,
        "height": height,
        "viewBox": `0 0 ${width} ${height}`,
        "style": { "display": "block" }
    });
    container.appendChild(svg);

    const values = data.map(d => d.value);
    const maxVal = Math.max(...values, 1);
    const totalVal = values.reduce((sum, v) => sum + v, 0);

    // --- 1. SÄULENDIAGRAMM (bar) ---
    if (type === "bar") {
        const padding = 40;
        const chartW = width - padding * 2;
        const chartH = height - padding * 2;
        const barGap = 10;
        const barWidth = (chartW / data.length) - barGap;

        // Achsen und Gitterlinien zeichnen
        svg.appendChild(svgEl("line", { x1: padding, y1: height - padding, x2: width - padding, y2: height - padding, stroke: "#9ca3af", "stroke-width": 2 }));
        
        // 4 Gitterlinien
        for (let i = 0; i <= 4; i++) {
            const y = padding + (chartH / 4) * i;
            const gridVal = Math.round(maxVal - (maxVal / 4) * i);
            svg.appendChild(svgEl("line", { x1: padding, y1: y, x2: width - padding, y2: y, stroke: "#e5e7eb", "stroke-dasharray": "4 4" }));
            svg.appendChild(svgEl("text", { x: padding - 8, y: y + 4, "text-anchor": "end", "font-size": "10px", fill: "#4b5563" }, [document.createTextNode(String(gridVal))]));
        }

        data.forEach((d, i) => {
            const x = padding + barGap / 2 + (barWidth + barGap) * i;
            const barH = (d.value / maxVal) * chartH;
            const y = height - padding - barH;
            const color = d.color || "#3b82f6";

            // Säulen-Rechteck
            const rect = svgEl("rect", {
                x: x,
                y: y,
                width: barWidth,
                height: barH,
                fill: color,
                style: { "cursor": "pointer", "transition": "opacity 0.15s" }
            });
            
            // Tooltip-Interaktion
            rect.addEventListener("mouseenter", () => rect.style.opacity = "0.8");
            rect.addEventListener("mouseleave", () => rect.style.opacity = "1");
            rect.appendChild(svgEl("title", {}, [document.createTextNode(`${d.label}: ${d.value}`)]));
            svg.appendChild(rect);

            // Beschriftung unter der Säule
            svg.appendChild(svgEl("text", {
                x: x + barWidth / 2,
                y: height - padding + 16,
                "text-anchor": "middle",
                "font-size": "11px",
                fill: "#374151"
            }, [document.createTextNode(d.label)]));
        });
    }

    // --- 2. LINIENDIAGRAMM (line) ---
    else if (type === "line") {
        const padding = 40;
        const chartW = width - padding * 2;
        const chartH = height - padding * 2;

        // Achsen und Gitterlinien zeichnen
        svg.appendChild(svgEl("line", { x1: padding, y1: height - padding, x2: width - padding, y2: height - padding, stroke: "#9ca3af", "stroke-width": 2 }));
        
        for (let i = 0; i <= 4; i++) {
            const y = padding + (chartH / 4) * i;
            const gridVal = Math.round(maxVal - (maxVal / 4) * i);
            svg.appendChild(svgEl("line", { x1: padding, y1: y, x2: width - padding, y2: y, stroke: "#e5e7eb", "stroke-dasharray": "4 4" }));
            svg.appendChild(svgEl("text", { x: padding - 8, y: y + 4, "text-anchor": "end", "font-size": "10px", fill: "#4b5563" }, [document.createTextNode(String(gridVal))]));
        }

        const points = [];
        const stepX = chartW / (data.length - 1 || 1);

        data.forEach((d, i) => {
            const x = padding + stepX * i;
            const y = height - padding - (d.value / maxVal) * chartH;
            points.push({ x, y, label: d.label, value: d.value, color: d.color });
        });

        // Verbindungslinie zeichnen
        let pathD = `M ${points[0].x} ${points[0].y}`;
        for (let i = 1; i < points.length; i++) {
            pathD += ` L ${points[i].x} ${points[i].y}`;
        }
        svg.appendChild(svgEl("path", {
            d: pathD,
            fill: "none",
            stroke: options.lineColor || "#10b981",
            "stroke-width": 3
        }));

        // Punkte (Dots) auf der Linie zeichnen
        points.forEach((p) => {
            const circle = svgEl("circle", {
                cx: p.x,
                cy: p.y,
                r: 5,
                fill: p.color || "#10b981",
                stroke: "#fff",
                "stroke-width": 2,
                style: { "cursor": "pointer", "transition": "r 0.15s" }
            });

            circle.addEventListener("mouseenter", () => circle.setAttribute("r", "8"));
            circle.addEventListener("mouseleave", () => circle.setAttribute("r", "5"));
            circle.appendChild(svgEl("title", {}, [document.createTextNode(`${p.label}: ${p.value}`)]));
            svg.appendChild(circle);

            // Beschriftung unter dem Punkt
            svg.appendChild(svgEl("text", {
                x: p.x,
                y: height - padding + 16,
                "text-anchor": "middle",
                "font-size": "11px",
                fill: "#374151"
            }, [document.createTextNode(p.label)]));
        });
    }

    // --- 3. KUCHENDIAGRAMM (pie) ---
    else if (type === "pie") {
        const cx = width / 2;
        const cy = height / 2;
        const r = Math.min(width, height) / 2.5;

        let accumAngle = -Math.PI / 2; // Oben starten

        data.forEach((d) => {
            const percentage = d.value / totalVal;
            const angleRange = percentage * Math.PI * 2;
            const startAngle = accumAngle;
            const endAngle = accumAngle + angleRange;
            accumAngle = endAngle;

            // Koordinaten für den Kreissegmentpfad berechnen
            const x1 = cx + r * Math.cos(startAngle);
            const y1 = cy + r * Math.sin(startAngle);
            const x2 = cx + r * Math.cos(endAngle);
            const y2 = cy + r * Math.sin(endAngle);

            const largeArcFlag = angleRange > Math.PI ? 1 : 0;
            const pathD = `M ${cx} ${cy} L ${x1} ${y1} A ${r} ${r} 0 ${largeArcFlag} 1 ${x2} ${y2} Z`;

            const slice = svgEl("path", {
                d: pathD,
                fill: d.color || "#3b82f6",
                stroke: "#fff",
                "stroke-width": 2,
                style: { "cursor": "pointer", "transition": "opacity 0.15s" }
            });

            slice.addEventListener("mouseenter", () => slice.style.opacity = "0.85");
            slice.addEventListener("mouseleave", () => slice.style.opacity = "1");
            slice.appendChild(svgEl("title", {}, [document.createTextNode(`${d.label}: ${d.value} (${Math.round(percentage * 100)}%)`)]));
            svg.appendChild(slice);
        });

        // Legende auf der rechten Seite einblenden, falls Breite ausreicht
        if (width >= 350) {
            const legendGroup = svgEl("g", { transform: `translate(${cx + r + 20}, ${cy - r})` });
            data.forEach((d, i) => {
                const y = i * 20;
                legendGroup.appendChild(svgEl("rect", { x: 0, y: y, width: 12, height: 12, fill: d.color }));
                legendGroup.appendChild(svgEl("text", {
                    x: 18,
                    y: y + 10,
                    "font-size": "11px",
                    fill: "#374151"
                }, [document.createTextNode(`${d.label} (${d.value})`)]));
            });
            svg.appendChild(legendGroup);
        }
    }

    return container;
}
