/*
 * (c) Volker Schulte volkerschulte@gmail.com
 * Änderungswünsche willkommen.
 *
 */

/**
 *
 * @module vstemplate
 */

export default class vstemplate {
  /**
   * @example
   * kleine Templating-Function
   * vs.template.transform("Hello {{who}}!", { who: "JavaScript" });
   *   // "Hello JavaScript!"
   * wenn es sich bei den daten um ein itemarray handelt, dann wird das template für JEDES item ausgeführt
   * statt einem string oder einem anderen wert kann man auch eine  funktion als ersatztext angeben, (return wird verwendet)
   * @description kleine templatefunktion
   * @param {String} s template mit platzhaltern
   * @param {object | array } d  objekt mit daten bzw. ein array davon
   * @returns {String}
   */
  static transform(s, d) {
    if (d instanceof Array) {
      // Template für alle Items im Array ausführen
      let ret = ''
      d.forEach(function (y, i) {
        let x = y
        let tmp = s
        for (let p in x) {
          let t = {}
          let isf = t.toString.call(x[p]) === '[object Function]'
          if (isf === true) {
            tmp = tmp.replace(new RegExp('{{' + p + '}}', 'g'), x[p](x))
          } else {
            tmp = tmp.replace(new RegExp('{{' + p + '}}', 'g'), x[p])
          }
        }
        ret += tmp
      })
      return ret
    }
    for (let p in d) {
      let t = {}
      let isf = t.toString.call(d[p]) === '[object Function]'
      if (isf === true) {
        s = s.replace(new RegExp('{{' + p + '}}', 'g'), d[p](d))
      } else {
        s = s.replace(new RegExp('{{' + p + '}}', 'g'), d[p])
      }
    }
    return s
  }
}
