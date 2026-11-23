/**
 * @module vsevent
 * Event-Bus-System für die Kommunikation zwischen UI-Komponenten.
 */
export default class vsevent {
  // Statische Eigenschaften initialisieren
  static channels = {};
  static chregex = {};
  static debug = false;

  /**
   * Löschen aller Event-Kanäle
   */
  static clear_channels() {
    vsevent.channels = {};
    vsevent.chregex = {};
  }

  /**
   * Senden eines Events an einen Kanal
   * @param {string} kanal - Name des Kanals
   * @param {...any} args - Zusätzliche Argumente, die an Callbacks übergeben werden
   */
  static send(kanal, ...args) {
    if (vsevent.debug) {
      console.log(`[vsevent] Send to: ${kanal}`, args);
    }

    // Callbacks für den exakten Kanal ausführen
    const cbs = vsevent.channels[kanal];
    if (cbs) {
      setTimeout(() => {
        cbs.forEach((cb) => {
          try {
            cb(...args);
          } catch (err) {
            console.error(`Fehler im Callback für Kanal '${kanal}':`, err);
          }
        });
      }, 0);
    }

    // Callbacks für Regex-Kanäle ausführen
    const mykey = Object.keys(vsevent.chregex).find((d) => {
      try {
        return kanal.match(d);
      } catch (e) {
        return false;
      }
    });

    if (mykey) {
      const regcbs = vsevent.chregex[mykey];
      if (regcbs) {
        setTimeout(() => {
          regcbs.forEach((cb) => {
            try {
              cb(...args);
            } catch (err) {
              console.error(`Fehler im Regex-Callback für '${mykey}':`, err);
            }
          });
        }, 0);
      }
    }
  }

  /**
   * Registrieren eines Event-Handlers auf einem Kanal
   * @param {string} channel - Name des Kanals
   * @param {function} callback - Auszuführende Funktion bei Empfang
   * @param {boolean} [multi=false] - Wenn true, können mehrere Handler registriert werden; wenn false, wird der Kanal überschrieben.
   */
  static handle(channel, callback, multi = false) {
    if (!vsevent.channels[channel] || !multi) {
      vsevent.channels[channel] = [];
    }
    vsevent.channels[channel].push(callback);
  }

  /**
   * Registrieren eines Event-Handlers mit Regex-Muster
   * @param {string} chregex - Regex-Muster für den Kanal
   * @param {function} callback - Auszuführende Funktion bei Empfang
   * @param {boolean} [multi=false] - Wenn true, werden mehrere Handler erlaubt; wenn false, wird der Eintrag überschrieben.
   */
  static handle_regex(chregex, callback, multi = false) {
    if (!vsevent.chregex[chregex] || !multi) {
      vsevent.chregex[chregex] = [];
    }
    vsevent.chregex[chregex].push(callback);
  }

  /**
   * Entfernen eines Event-Handlers von einem Kanal.
   * @param {string} channel - Kanalname
   * @param {function} [callback] - Der zu entfernende Callback. Wenn weggelassen, wird der ganze Kanal gelöscht.
   */
  static off(channel, callback) {
    if (!vsevent.channels[channel]) return;

    if (!callback) {
      delete vsevent.channels[channel];
    } else {
      vsevent.channels[channel] = vsevent.channels[channel].filter(cb => cb !== callback);
      if (vsevent.channels[channel].length === 0) {
        delete vsevent.channels[channel];
      }
    }
  }

  /**
   * Alle Eventkanäle zurückgeben
   * @returns {object}
   */
  static getchannels() {
    return vsevent.channels;
  }

  /**
   * Debug-Modus umschalten
   * @param {boolean} val 
   */
  static setdebug(val) {
    vsevent.debug = val;
  }
}
