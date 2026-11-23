/* ====================================================================== 
 * (c) Volker Schulte volkerschulte@gmail.com
 * Änderungswünsche willkommen.
 *
 */
/* ====================================================================== */
/**
 * hallo vsdate
 * @module vsdate
 *
 */
export default class vsdate {
  /**
   *
   *  formatieren eines datetimeobjektes
   * @param {time} t
   * @returns {object} mit attributen gesamt,stunde,minute,sekunde
   */
  static formatTime(t) {
    try {
      const nullen = '00'
      let std = nullen + t.getHours()
      std = std.substr(std.length - 2)
      std = std.replace(/NaN/, '00')
      let mi = nullen + t.getMinutes()
      mi = mi.substr(mi.length - 2)
      mi = mi.replace(/NaN/, '00')
      let se = nullen + t.getSeconds()
      se = se.substr(se.length - 2)
      se = se.replace(/NaN/, '00')
      return {
        gesamt: std + ':' + mi + ':' + se,
        stunde: std,
        minute: mi,
        sekunde: se
      }
    } catch (exception) {
    }
  }
  /**
   *
   *  vsdate
   *  parsen eines Strings zu einem datetime-objektes
   * @param {string} strwert
   * @returns {datetime}
   */
  static parseTime(strwert) {
    const punkte = strwert.includes(':')
    const nullen = '00'
    let akt = new Date()
    if (punkte) {
      // es sind doppelpunkte da
      const arr = strwert.split(':'),
        std = nullen + arr[0],
        mi = nullen + arr[1]
      akt.setHours(std, mi)
      return akt
    } else {
      if (strwert.length === 4) {
        akt.setHours(strwert.substr(0, 2), strwert.substr(2))
        return akt
      }
    }
    return new Date()
  }
  /**
   *
   *  vsdate
   *  parsen eines Strings zu einem date-objekt
   * @param {string} strwert
   * @returns {date}
   */
  static parseDate(strwert) {
    try {
      const strop = strwert.replace(/\./g, '')
      let punkte = false
      punkte = strwert.includes('.')
      if (punkte) {
        if (strop.length !== (strwert.length - 2)) {
          /*
           * falsches format, weil keine zwei punkte!
           */
          throw new Error("no valid date")
        }
        if (strwert.length > 10) {
          // wenn schon  punkte, dann MÜSSEN es weniger als 11 stellen sein
          throw new Error("no valid date")
        }
        let arrstr = strwert.split('.')
        let dt = new Date()
        let nr = parseFloat(arrstr[1])
        nr = nr - 1
        dt.setMonth(nr, arrstr[0])
        dt.setYear(arrstr[2])
        return dt
      } else {
        if (strwert.length !== 8) {
          // wenn schon keine punkte, dann MÜSSEN es 8 stellen sein
          return new Date()
        }
        let dt = new Date()
        nr = parseFloat(strwert.substr(2, 2))
        nr = nr - 1
        dt.setMonth(nr, strwert.substr(0, 2))
        dt.setYear(strwert.substr(4))
        return dt
      }
    } catch (exception) {
      throw new Error("no valid date")
    }
  }
  /**
   *
   *  vsdate
   *  formatieren eines Strings zu einem datumstring
   * @param {string} strwert
   * @returns {String}
   */
  static formatDate(strwert) {
    /*
     * 8 stellen ohne punkte oder mit zwei punkten
     * 10 stellen mit punkte komplettes datum
     *
     */
    try {
      let nullen = '0000'
      let strop = strwert.replace(/\./g, '')
      let punkte = false
      punkte = strwert.includes('.')
      if (punkte) {
        if (strop.length !== (strwert.length - 2)) {
          /*
           * falsches format, weil keine zwei punkte!
           */
          return ''
        }
        if (strwert.length > 10) {
          // wenn schon  punkte, dann MÜSSEN es weniger als 11 stellen sein
          return ''
        }
        let arrstr = strwert.split('.')
        let dt = new Date()
        let nr = parseFloat(arrstr[1])
        nr = nr - 1
        dt.setMonth(nr, arrstr[0])
        dt.setYear(arrstr[2])
        let dd = (nullen + dt.getDate()).substr((nullen + dt.getDate()).length - 2)
        let mm = (nullen + (dt.getMonth() + 1)).substr((nullen + (dt.getMonth() + 1)).length - 2)
        let yyyy = (nullen + dt.getFullYear()).substr((nullen + dt.getFullYear()).length - 4)
        return dd + '.' + mm + '.' + yyyy
      } else {
        if (strwert.length !== 8) {
          // wenn schon keine punkte, dann MÜSSEN es 8 stellen sein
          return ''
        }
        let dt = new Date()
        let nr = parseFloat(strwert.substr(2, 2))
        nr = nr - 1
        dt.setMonth(nr, strwert.substr(0, 2))
        dt.setYear(strwert.substr(4))
        let dd = (nullen + dt.getDate()).substr((nullen + dt.getDate()).length - 2)
        let mm = (nullen + (dt.getMonth() + 1)).substr((nullen + (dt.getMonth() + 1)).length - 2)
        let yyyy = (nullen + dt.getFullYear()).substr((nullen + dt.getFullYear()).length - 4)
        return dd + '.' + mm + '.' + yyyy
      }
    } catch (exception) {

    }
  }
  /**
   *
   *  vsdate
   *  heutiges datum als string zurückgeben
   * @returns {datetime}
   */
  static heute(plusmonat) {
    let nullen = '0000'
    let dt = new Date()
    if (plusmonat) {
      dt.setMonth(dt.getMonth()+plusmonat)
    }

    let dd = (nullen + dt.getDate()).substr((nullen + dt.getDate()).length - 2)
    let mm = (nullen + (dt.getMonth() + 1)).substr((nullen + (dt.getMonth() + 1)).length - 2)
    let yyyy = (nullen + dt.getFullYear()).substr((nullen + dt.getFullYear()).length - 4)
    return dd + '.' + mm + '.' + yyyy
  }

  /**
   *
   *  datum zu deutschen datumstring
   * @param {date} dt
   * @returns {String}
   */
  static dateToDEString(dt) {
    let nullen = '0000'
    let dd = (nullen + dt.getDate()).substr((nullen + dt.getDate()).length - 2)
    let mm = (nullen + (dt.getMonth() + 1)).substr((nullen + (dt.getMonth() + 1)).length - 2)
    let yyyy = (nullen + dt.getFullYear()).substr((nullen + dt.getFullYear()).length - 4)
    return dd + '.' + mm + '.' + yyyy
  }
  /**
   *
   *  vsdate
   *  anzahl der tage im angegebenen monat zurückgeben
   * @param {number} jahr
   * @param {number} monat
   * @returns {Number}
   */
  static getAnzTageImMonat(jahr, monat) {
    let d = new Date(jahr, monat, 0)
    return d.getDate()
  }
  /**
   *
   *  vsdate
   *  wochentag als string zurückgeben
   * @param {date} ddatum
   * @returns {String}
   */
  static getTagAsString(ddatum) {
    let t = [
      'Sonntag', 'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag'
    ]
    if (ddatum) {
      return t[ddatum.getDay()]
    }
    return ''
  }
  /**
   *
   * @param {string} strdate  "dd.mm.yyyy" nach yyyymmdd
   * @returns {string}
   */
  static ddpmmpyyyy2yyyymmdd(strdate) {
    return strdate.substr(6) + strdate.substr(3, 2) + strdate.substr(0, 2)
  }
  /**
   *
   * @param {string} strdate als "yyyymmdd"
   * @returns {string}
   */
  static yyyymmdd2ddpmmpyyyy(strdate) {
    return (strdate.substr(6) + '.' + strdate.substr(4, 2) + '.' + strdate.substr(0, 4))
  }
  static yyyyMmmMdd2ddpmmpyyyy(strdate) {
    try {
      return (strdate.substr(8) + "." + strdate.substr(5, 2) + "." + strdate.substr(0, 4))

    } catch (error) {
      return "";
    }

  }
  static ddpmmpyyyy2yyyyMmmMdd(strdate) {
    try {
      return (strdate.substr(6) + "-" + strdate.substr(3, 2) + "-" + strdate.substr(0, 2))

    } catch (error) {
      return "";
    }
  }
}
