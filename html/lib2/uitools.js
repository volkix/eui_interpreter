

export function getmaxzindex() {
    var zIndex,
            z = 0,
            all = document.getElementsByTagName("*");
    for (var i = 0, n = all.length; i < n; i++) {
        zIndex = document.defaultView.getComputedStyle(all[i], null)
                .getPropertyValue("z-index");
        zIndex = parseInt(zIndex, 10);
        z = (zIndex) ? Math.max(z, zIndex) : z;
    }
    return z;
}