export default class typechecker {
  static isString(x) {
    if (x == null) {
      return false;
    }
    return (typeof x == "string" ||
        typeof x == "object" && x.toUpperCase && x.substr && x.charAt &&
          x.trim &&
          x.replace
      ? true
      : false);
  }
  static isInteger(value) {
    return Number.isInteger(value);
  }
  static isDouble(value) {
    return !!(value % 1);
  }
  static isBoolean(x) {
    if (x == null) {
      return false;
    }
    return (typeof x == "boolean");
  }
  static isArray(x){
    return Array.isArray(x);
  }
  static isObject(x){
    return (typeof x == "object" && !(x.toUpperCase && x.substr && x.charAt &&
          x.trim &&
          x.replace));
  }
}
