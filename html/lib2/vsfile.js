/**
 * schreiben von daten in eine Datei. Dateiname wird über Picker abgefragt
 * @param {blob} text oder arraybuffer oder was auch immer
 * @returns 
 */

export const saveFile = async (blob) => {
    if (!window.showSaveFilePicker) {
        throw new Error("File System Access API nicht unterstützt in diesem Browser.");
    }
    try {
        const handle = await showSaveFilePicker();
        const writable = await handle.createWritable();
        await writable.write(blob);
        await writable.close();
        return;
    } catch (err) {
        if (err.name !== 'AbortError') {
            console.error("SaveFile Fehler:", err);
            throw err;
        }
    }
}
/**
 * lesen einer Datei aus dem Filesystem. Picker zur Ermittlung des Dateinamens
 * @returns content als text
 */

export const readFile = async () => {
    let [fileHandle] = await window.showOpenFilePicker();

    const file = await fileHandle.getFile();
    const content = await file.text();

    return content
}

/**
 * speichern einer Datei in einem vorher freigegebenen Verzeichnis.
 * Keiner Pickerabfrage für jede Datei
 * @param {*} fsdir 
 * @param {*} fsname 
 * @param {*} data 
 * @returns 
 */
export const saveFileDir = async (fsdir, fsname, data) => {
    try {
        const handle = await fsdir.getFileHandle(fsname, { "create": true });
        const writable = await handle.createWritable();
        await writable.write(data);
        await writable.close();
        return;
    } catch (err) {
        if (err.name !== 'AbortError') {
            console.error("SaveFileDir Fehler:", err);
            throw err;
        }
    }
}
/**
 * Lesen einer Datei aus einem freigegebenen Verzeichnis. Keine Pickerabfrage für jede einzelne Datei.
 * 
 * @param {*} fsdir 
 * @param {*} fsname 
 * @returns text
 */
export const readFileDirAsText = async (fsdir, fsname) => {
    const fileHandle = await fsdir.getFileHandle(fsname, { "create": false });
    const file = await fileHandle.getFile();
    const content = await file.text();
    return content;
}

/**
 * Lesen einer Datei aus einem freigegebenen Verzeichnis. Keine Pickerabfrage für jede einzelne Datei.
 * 
 * @param {*} fsdir 
 * @param {*} fsname 
 * @returns arraybuffer
 */
export const readFileDirAsArrayBuffer = async (fsdir, fsname) => {
    const fileHandle = await fsdir.getFileHandle(fsname, { "create": false });
    const file = await fileHandle.getFile();
    const content = await file.arrayBuffer();
    return content;
}

/**
 * holen eines verzeichnishandles. Isteinmal die Erlaubnis erteilt, können in dem Verzeichnis Daeien und Verzeichnisse
 * angelegt werden.
 * @returns directoryhandle
 */

export const getDir = async () => {
    const dirHandle = await window.showDirectoryPicker({
        "mode": "readwrite"
    });
    return dirHandle

}

/**
 * Feststellen, ob der Anwender bereits eine erlaubnis erteilt hat
 * @param {*} fileHandle 
 * @param {*} readWrite 
 * @returns 
 */
export async function verifyPermission(fileHandle) {
    const options = {};
    options.mode = 'readwrite';

    // Check if permission was already granted. If so, return true.
    if ((await fileHandle.queryPermission(options)) === 'granted') {
        return true;
    }
    // Request permission. If the user grants permission, return true.
    if ((await fileHandle.requestPermission(options)) === 'granted') {
        return true;
    }
    // The user didn't grant permission, so return false.
    return false;
}