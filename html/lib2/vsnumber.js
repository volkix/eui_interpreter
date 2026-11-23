/*
 * (c) Volker Schulte volkerschulte@gmail.com
 * Änderungswünsche willkommen.
 *
 */
/* ====================================================================== */
/**
 *
 * @module vsnumber
 *
 */

export default class vsnumber {
  /**
   *
   *  string2number
   * @param {string} mystr String, der in Zahl umgewandelt werden soll
   * @param {number} nk anzahl der Nachkommastellen, auf die gerundet werden soll.
   * @return {number}
   */

  static s2n(mystr, nk) {
    try {
      mystr = mystr.trim();
      if (mystr.length == 0) {
        return parseFloat("0.00");
      }
      mystr = mystr.replace(/\./gi, "");
      mystr = mystr.replace(/,/gi, ".");
      if (isNaN(mystr)) {
        let tt = parseFloat("0.00");
        return parseFloat(tt.toFixed(nk));
      }
      let tmpnr = parseFloat(mystr);
      return parseFloat(tmpnr.toFixed(nk));
    } catch (e) {
      return parseFloat("0.00");
    }
  }
  /**
   *
   *  number2string
   * @param {number} mynr zahl, die in string umgewandelt werden soll
   * @param {number} nk anzahl der Nachkommastellen, auf die gerundet werden soll.
   * @return {string}
   */
  static n2s(mynr, nk) {
    try {
      mynr = Number(mynr).toFixed(nk);
      let mystr = "" + mynr;
      mystr = mystr.replace(/\./gi, ",");
      let comma_pos = mystr.indexOf(",");
      if (comma_pos == -1) {
        comma_pos = mystr.length;
      }
      let tmp_number = mystr.substr(0, comma_pos);
      mystr = mystr.substr(comma_pos, mystr.length);
      while (tmp_number.length > 3) {
        mystr = "." +
          tmp_number.substr(tmp_number.length - 3, tmp_number.length) + mystr;
        tmp_number = tmp_number.substr(0, tmp_number.length - 3);
      }
      mystr = tmp_number + mystr;
      return mystr;
    } catch (error) {
      return "0,00";
    }
  }
  /**
   *
   * [5~ Formatiert einen Wert als Zahl mit den angegebenen Nachkommastellen
   * @param {string} mystr String, der in Zahl umgewandelt werden soll
   * @param {number} nk anzahl der Nachkommastellen, auf die gerundet werden soll.
   * @return {string}
   */
  static fz(mystr, nk) {
    let str = mystr;
    return this.n2s(this.s2n(str, nk), nk);
  }
  /**
   * @param {number} myn zahl
   * @param {number} nk anzahl der Nachkommastellen, auf die gerundet werden soll.
   * 
   */
  static fzn(myn, nk) {
    let mystr = this.n2s(myn, nk);
    let ret = this.s2n(mystr, 2);

    return ret;
  }
}
/* ====================================================================== */
