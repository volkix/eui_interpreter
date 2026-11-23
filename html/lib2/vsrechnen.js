export default class vsrechnen {

   /**
    * Setzen eines Wertes als String.
    * Wird in BigInt umgewandelt
    * @param {String} val ("123456,789")
    * @returns vsrechnen
    */
    set(val) {

        val = this.checkvalue(val)
        this.value = BigInt(val)
        return this
    }
    /**
     * 
     * @returns value formatted
     */
    get() {
        let wert = this.value.toString()
        let anz = wert.length
        let ret = this.makegrouping(wert.substring(0, anz - 4) + "," + wert.substring(anz - 4))
        return ret
    }
    /**
     * vergleich des wertes mit einem zweiten wert
     * @param {string} val 
     * @returns int (1 = grösserals, 0 = gleich, -1 = kleiner als)
     */
    cmp(val) {
        let cmpval = BigInt(this.checkvalue(val))
        if (this.value > cmpval) {
            return 1
        }
        if (this.value == cmpval) {
            return 0
        }
        if (this.value < cmpval) {
            return -1
        }
    }
    /**
     * addieren eines wertes
     * @param {string} val 
     * @returns vsrechnen
     */
    add(val) {
        let addval = BigInt(this.checkvalue(val))
        this.value = this.value + addval
        return this
    }
    /**
     * subtrahieren eines wertes
     * @param {string} val 
     * @returns vsrechnen
     */
    sub(val) {
        let subval = BigInt(this.checkvalue(val))
        this.value = this.value - subval
        return this
    }
    /**
     * multiplizieren eines wertes
     * @param {String} val 
     * @returns this
     */
    mul(val) {
        let mulval = BigInt(this.checkvalue(val))
        this.value = this.value * mulval / 10000n
        return this
    }
    /**
     * dividieren eines wertes
     * @param {string} val 
     * @returns this
     */
    div(val) {
        let divval = BigInt(this.checkvalue(val))
        this.value = this.value* 10000n / divval
        console.log(this.value)
        return this

    }
    /**
     * runden auf zwei nachkommastellen
     * @returns string
     */
    rnd2() {

        let wert = this.value.toString().split("")
        let anz = wert.length
        let rnd = parseInt(wert[anz - 2])
        let rnd1 = parseInt(wert[anz - 4] + wert[anz - 3])
        if (rnd > 4) {
            rnd1++
            wert[anz - 4] = `${rnd1}`.charAt(0)
            wert[anz - 3] = `${rnd1}`.charAt(1)
        }

        let ret = this.makegrouping(wert.join("").substring(0, anz - 4) + "," + wert.join("").substring(anz - 4, anz - 2))
        return ret
    }
    /**
     * runden auf drei nachkommastellen
     * @returns string
     */
    rnd3() {
        let wert = this.value.toString().split("")
        let anz = wert.length
        let rnd = parseInt(wert[anz - 1])
        let rnd1 = parseInt(wert[anz - 3] + wert[anz - 2])
        if (rnd > 4) {
            rnd1++
            wert[anz - 3] = `${rnd1}`.charAt(0)
            wert[anz - 2] = `${rnd1}`.charAt(1)
        }

        let ret = this.makegrouping(wert.join("").substring(0, anz - 4) + "," + wert.join("").substring(anz - 4, anz - 1))
        return ret
    }
    /**
     * interne methode
     * @param {string} strval 
     * @returns string
     */
    makegrouping(strval) {
        let i = 0
        let out = ""
        for (let index = (strval.indexOf(",") - 1); index >= 0; index--) {
            i++
            out = strval.charAt(index) + out

            if (i % 3 == 0 && index > 0 && strval.charAt(index - 1) != "-") {
                out = "." + out
            }
        }
        return out + strval.substring(strval.indexOf(","))

    }
    /**
     * interne methode
     * @param {string} strval 
     * @returns string
     */
    checkvalue(strval) {
        strval = strval.replaceAll(".", "")
        try {
            const regex = "(\\+|-)?[0123456789]{1,12},[0123456789]{1,4}"

            strval = (strval.startsWith("-")) ? strval : ("+" + strval)
            strval = strval.replaceAll("++", "+")
            strval = (strval.indexOf(",") > 0) ? strval : (strval + ",0000")
            if (!strval.match(regex)) {
                throw Error("Falscher Parameter")
            }
            let [vk, nk] = strval.split(",")

            strval = "" + vk + (nk + "0000").substring(0, 4)
            return strval
        } catch (error) {
            throw Error("Falscher Parameter")
        }

    }
}