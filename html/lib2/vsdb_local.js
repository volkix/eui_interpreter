/**
 * Datenbankroutine, alle daten liegen im speicher als json
 *
 * @export
 * @class dbtable
 */

import * as vsfs from './vsfile.js'
import { vsonValidate } from './vson_validate.js'

export default class vsdb_local {

    /**
     * erzeugen einer tabelle
     * @param {String} dirhandle 
     * @param {String} name 
     * @param {json} tjson 
     */
    async create(dirhandle,name, dbjson) {
        let tjson = {}
        dbjson.forEach(element => {
            tjson[element.name]=element.default
        });


        let data = {
            _id: 0,
            _template: tjson,
            _daten: []
        }
        try {
         
            await vsfs.saveFileDir(dirhandle,name,JSON.stringify(data))
            return {
                error: false,
                errortext: ""
            }
        } catch (err) {
            return {
                error: true,
                errortext: err
            }
        }
    }
    /**
     * öffnet die tabelle
     * @param {String} dirhandle
     * @param {String} pfad 
     */
    async open(dirhandle,name) {
        try {
            this._table = JSON.parse(await vsfs.readFileDirAsText(dirhandle,name))
    
            this._pfad = name
            return {
                error: false,
                errortext: ""
            }

        } catch (err) {
            return {
                error: true,
                errortext: err
            }
        }
    }
    /**
    * speichert  die tabelle
    * @param {String} pfad 
    */
    async save(dirhandle) {
        try {
            // Nur die Attribute aus dem Template und das Pflichtfeld 'id' zulassen
            const templateKeys = Object.keys(this.gettemplate());
            const allowedKeys = templateKeys.includes('id') ? templateKeys : [...templateKeys, 'id'];
            this._table._daten = JSON.parse(JSON.stringify(this._table._daten, allowedKeys));

            await vsfs.saveFileDir(dirhandle, this._pfad, JSON.stringify(this._table));

            return {
                error: false,
                errortext: ""
            }
        } catch (err) {
            return {
                error: true,
                errortext: err
            }
        }
    }
    /**
     * schreiben eines neuen datensatzes
     * @param {json} djson 
     * @returns {number} datensatzid
     */
    insert(djson) {
        let datensatz = {
            ...this._table._template, ...djson
        }
        let newid = ++this._table._id
        datensatz.id = newid
        this._table._id = newid
        this._table._daten.push(datensatz)
        return newid
    }
    /**
     * datensatz erneuern, daten werden gemischt mit den neu übergebenen daten
     * @param {number} id 
     * @param {json} daten 
     */
    update(id, daten) {
        let index = this._table._daten.findIndex((e) => {
            return e.id == id
        })
        if (index < 0) {
            return false
        }
        let datensatz = {
            ...this._table._daten[index], ...daten
        }
        this._table._daten[index] = datensatz
        return true
    }
    /**
     * löschen eines datensatzes
     * @param {number} id 
     */
    delete(id) {
        let index = this._table._daten.findIndex((e) => {
            return e.id == id
        })
        if (index < 0) {
            return false
        }
        this._table._daten.splice(index, 1)
        return true;
    }
    /**
    * suchen eines datensatzes
    * @param {number} id 
    */
    search_id(id) {
        return this._table._daten.filter((e) => {
            return e.id == id
        })
    }
    /**
     * suchfunktion mit 'schema'
     */
    search(schema) {
        let ret = [];
        let s1 = {
            "type": "object",
            "properties": schema
        };
        this._table._daten.forEach(_ => {
            try {
                const errors = vsonValidate(s1, _);
                if (errors.length === 0) {
                    ret.push(_);
                }
            } catch (e) {
                // ignorieren bei Fehlern
            }
        });
        return ret;
    }
  
    /**
     * datensatzanzahl
     */
    size() {
        return this._table._daten.length
    }
    /**
     * tabellentemplate zurückgeben wegen nummernhochzählen
     */
    gettemplate() {
        return this._table._template
    }
    /**
     * neues template setzen
     * @param {json} template 
     */
    settemplate(template) {
        this._table._template = template
    }
    alldata() {
        return this._table._daten;
    }
}

