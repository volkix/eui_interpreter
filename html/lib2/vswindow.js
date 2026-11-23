/*
 * (c) Volker Schulte volkerschulte@gmail.com
 * Änderungswünsche willkommen.
 *
 */

/**
 *
 * @module vsdui_window
 */
export default class vswindow {
  /**
   *
   * @returns {Number|Window.innerWidth}
   *  breite des fensters
   */
  static getwidth() {
    return window.innerWidth;
  }
  /**
   *
   *  höhe des fensters
   * @returns {Window.innerHeight|Number}
   */
  static getheight() {
    return window.innerHeight;
  }
  /**
   *
   *  pixel von dokumentstart nach unten
   * @returns {Number|Window.pageYOffset}
   */
  static getvonoben() {
    return window.scrollY;
  }
  /**
   *
   *  pixel von dokumentstart links nach rechts
   * @returns {Number|Window.pageXOffset}
   */
  static getvonlinks() {
    return window.scrollX;
  }
  /**
   *
   *  dokumentenhöhe
   * @returns {Number}
   */
  static getscrollheight() {
    return document.body.scrollHeight;
  }

 
  /**
   * Eine Desktop-Notiz absenden
   *
   * @static
   * @param {String} noti
   * @memberof vsdui_window
   */
  static notiz(noti) {
    // Let's check if the browser supports notifications
    if (!("Notification" in window)) {
      alert("This browser does not support desktop notification");
    } // Let's check whether notification permissions have alredy been granted
    else if (Notification.permission === "granted") {
      // If it's okay let's create a notification
      var notification = new Notification(noti);
    } // Otherwise, we need to ask the user for permission
    else if (Notification.permission !== "denied") {
      Notification.requestPermission(function (permission) {
        // If the user accepts, let's create a notification
        if (permission === "granted") {
          var notification = new Notification(noti);
        }
      });
    } else {
      alert(noti);
    }

    // At last, if the user has denied notifications, and you
    // want to be respectful there is no need to bother them any more.
  }
}
