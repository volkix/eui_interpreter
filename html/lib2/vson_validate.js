/**
 * JSON Schema Validator for JavaScript / Browser
 * Mirrors the behavior of the PostgreSQL PL/pgSQL validator (vson_validate).
 */

/**
 * Deep equality check for constants and enum arrays.
 */
function deepEqual(a, b) {
    if (a === b) return true;
    if (a && b && typeof a === 'object' && typeof b === 'object') {
        if (Array.isArray(a) !== Array.isArray(b)) return false;
        if (Array.isArray(a)) {
            if (a.length !== b.length) return false;
            for (let i = 0; i < a.length; i++) {
                if (!deepEqual(a[i], b[i])) return false;
            }
            return true;
        }
        const keysA = Object.keys(a);
        const keysB = Object.keys(b);
        if (keysA.length !== keysB.length) return false;
        for (const k of keysA) {
            if (!Object.prototype.hasOwnProperty.call(b, k)) return false;
            if (!deepEqual(a[k], b[k])) return false;
        }
        return true;
    }
    return false;
}

/**
 * Helper to get the schema-compatible type of a value.
 */
function getType(val) {
    if (val === null) return 'null';
    if (Array.isArray(val)) return 'array';
    const t = typeof val;
    if (t === 'number') return 'number';
    if (t === 'string') return 'string';
    if (t === 'boolean') return 'boolean';
    if (t === 'object') return 'object';
    return t;
}

/**
 * Validates data against a JSON Schema.
 * 
 * @param {*} schema The JSON Schema (object or boolean).
 * @param {*} data The data to validate.
 * @param {string} path The current path (defaults to '$').
 * @returns {Array<{error_path: string, error_message: string}>} Array of errors. Empty array means valid.
 */
export function vsonValidate(schema, data, path = '$') {
    const errors = [];

    // --- 0. Boolean Schemata (true/false) ---
    if (typeof schema === 'boolean') {
        if (schema === false) {
            errors.push({
                error_path: path,
                error_message: 'Validierung gegen "false"-Schema fehlgeschlagen'
            });
        }
        return errors;
    }

    // Wenn das Schema kein Objekt ist, überspringen wir
    if (schema === null || typeof schema !== 'object') {
        return errors;
    }

    // --- 1. Typ-Validierung ---
    if ('type' in schema) {
        const actualType = getType(data);
        let typeValid = false;
        const expectedType = schema.type;

        const checkSingleType = (expected) => {
            if (expected === 'integer') {
                return actualType === 'number' && Number.isInteger(data);
            }
            return actualType === expected;
        };

        if (typeof expectedType === 'string') {
            typeValid = checkSingleType(expectedType);
        } else if (Array.isArray(expectedType)) {
            typeValid = expectedType.some(t => checkSingleType(t));
        }

        if (!typeValid) {
            errors.push({
                error_path: path,
                error_message: `Typ ungültig. Erwartet: ${JSON.stringify(expectedType)}, erhalten: ${actualType}`
            });
            // Abbruch für diesen Knoten, wenn der Basistyp schon nicht stimmt
            return errors;
        }
    }

    // --- 2. Konstanten und Enums ---
    if ('const' in schema) {
        if (!deepEqual(data, schema.const)) {
            errors.push({
                error_path: path,
                error_message: 'Wert entspricht nicht der Konstante'
            });
        }
    }

    // enum
    if ('enum' in schema && Array.isArray(schema.enum)) {
        const isMatch = schema.enum.some(item => deepEqual(data, item));
        if (!isMatch) {
            errors.push({
                error_path: path,
                error_message: 'Wert ist nicht in der Liste der erlaubten Werte (enum)'
            });
        }
    }

    // --- 3. Objekt-Validierung ---
    if (getType(data) === 'object') {
        const dataKeys = Object.keys(data);
        const propCount = dataKeys.length;

        // Required
        if ('required' in schema && Array.isArray(schema.required)) {
            for (const reqKey of schema.required) {
                if (!(reqKey in data)) {
                    errors.push({
                        error_path: path,
                        error_message: `Erforderliches Feld fehlt: '${reqKey}'`
                    });
                }
            }
        }

        // dependentRequired
        if ('dependentRequired' in schema && typeof schema.dependentRequired === 'object' && schema.dependentRequired !== null) {
            for (const [propKey, depArr] of Object.entries(schema.dependentRequired)) {
                if (propKey in data && Array.isArray(depArr)) {
                    for (const reqKey of depArr) {
                        if (!(reqKey in data)) {
                            errors.push({
                                error_path: path,
                                error_message: `Abhängigkeitsfehler: Da '${propKey}' vorhanden ist, wird auch '${reqKey}' benötigt.`
                            });
                        }
                    }
                }
            }
        }

        // Properties, patternProperties & Additional Properties
        const addPropSchema = schema.additionalProperties;
        for (const [dataKey, dataVal] of Object.entries(data)) {
            let matchedAny = false;

            // Normale Properties
            if (schema.properties && (dataKey in schema.properties)) {
                const propSchema = schema.properties[dataKey];
                errors.push(...vsonValidate(propSchema, dataVal, `${path}.${dataKey}`));
                matchedAny = true;
            }

            // patternProperties
            if (schema.patternProperties && typeof schema.patternProperties === 'object' && schema.patternProperties !== null) {
                for (const [patKey, patSchema] of Object.entries(schema.patternProperties)) {
                    try {
                        const regex = new RegExp(patKey);
                        if (regex.test(dataKey)) {
                            errors.push(...vsonValidate(patSchema, dataVal, `${path}.${dataKey}`));
                            matchedAny = true;
                        }
                    } catch (e) {
                        // Ungültige Regex ignorieren
                    }
                }
            }

            // additionalProperties
            if (!matchedAny && addPropSchema !== undefined) {
                errors.push(...vsonValidate(addPropSchema, dataVal, `${path}.${dataKey}`));
            }
        }

        // propertyNames
        if ('propertyNames' in schema) {
            for (const dataKey of dataKeys) {
                errors.push(...vsonValidate(schema.propertyNames, dataKey, `${path}{key:${dataKey}}`));
            }
        }

        // minProperties / maxProperties
        if ('minProperties' in schema) {
            const min = parseInt(schema.minProperties, 10);
            if (!isNaN(min) && propCount < min) {
                errors.push({
                    error_path: path,
                    error_message: `Zu wenige Eigenschaften (min: ${min})`
                });
            }
        }
        if ('maxProperties' in schema) {
            const max = parseInt(schema.maxProperties, 10);
            if (!isNaN(max) && propCount > max) {
                errors.push({
                    error_path: path,
                    error_message: `Zu viele Eigenschaften (max: ${max})`
                });
            }
        }
    }

    // --- 4. Array-Validierung ---
    if (getType(data) === 'array') {
        const arrCount = data.length;
        let prefixLen = 0;

        // prefixItems
        if ('prefixItems' in schema && Array.isArray(schema.prefixItems)) {
            prefixLen = schema.prefixItems.length;
            const limit = Math.min(arrCount, prefixLen);
            for (let i = 0; i < limit; i++) {
                errors.push(...vsonValidate(schema.prefixItems[i], data[i], `${path}[${i}]`));
            }
        }

        // items
        if ('items' in schema) {
            for (let i = prefixLen; i < arrCount; i++) {
                errors.push(...vsonValidate(schema.items, data[i], `${path}[${i}]`));
            }
        }

        // minItems / maxItems
        if ('minItems' in schema) {
            const min = parseInt(schema.minItems, 10);
            if (!isNaN(min) && arrCount < min) {
                errors.push({
                    error_path: path,
                    error_message: `Array zu kurz (min: ${min})`
                });
            }
        }
        if ('maxItems' in schema) {
            const max = parseInt(schema.maxItems, 10);
            if (!isNaN(max) && arrCount > max) {
                errors.push({
                    error_path: path,
                    error_message: `Array zu lang (max: ${max})`
                });
            }
        }

        // uniqueItems
        if ('uniqueItems' in schema && schema.uniqueItems === true) {
            const uniqueElements = [];
            for (const item of data) {
                if (!uniqueElements.some(el => deepEqual(el, item))) {
                    uniqueElements.push(item);
                }
            }
            if (uniqueElements.length < arrCount) {
                errors.push({
                    error_path: path,
                    error_message: 'Array-Elemente sind nicht eindeutig (uniqueItems)'
                });
            }
        }
    }

    // --- 5. String/Number Validierung ---
    if (getType(data) === 'number') {
        const d = data;

        if ('minimum' in schema) {
            const min = Number(schema.minimum);
            if (!isNaN(min) && d < min) {
                errors.push({ error_path: path, error_message: `Wert < Minimum (${min})` });
            }
        }
        if ('maximum' in schema) {
            const max = Number(schema.maximum);
            if (!isNaN(max) && d > max) {
                errors.push({ error_path: path, error_message: `Wert > Maximum (${max})` });
            }
        }
        if ('exclusiveMinimum' in schema) {
            const exMin = Number(schema.exclusiveMinimum);
            if (!isNaN(exMin) && d <= exMin) {
                errors.push({ error_path: path, error_message: `Wert <= exclusiveMinimum (${exMin})` });
            }
        }
        if ('exclusiveMaximum' in schema) {
            const exMax = Number(schema.exclusiveMaximum);
            if (!isNaN(exMax) && d >= exMax) {
                errors.push({ error_path: path, error_message: `Wert >= exclusiveMaximum (${exMax})` });
            }
        }
        if ('multipleOf' in schema) {
            const m = Number(schema.multipleOf);
            if (!isNaN(m) && m > 0) {
                const div = d / m;
                if (Math.abs(div - Math.round(div)) > 1e-11) {
                    errors.push({ error_path: path, error_message: `Wert ist kein Vielfaches von ${m}` });
                }
            }
        }
    }

    if (getType(data) === 'string') {
        const s = data;
        const sLen = s.length;

        if ('minLength' in schema) {
            const min = parseInt(schema.minLength, 10);
            if (!isNaN(min) && sLen < min) {
                errors.push({ error_path: path, error_message: 'String zu kurz' });
            }
        }
        if ('maxLength' in schema) {
            const max = parseInt(schema.maxLength, 10);
            if (!isNaN(max) && sLen > max) {
                errors.push({ error_path: path, error_message: 'String zu lang' });
            }
        }
        if ('pattern' in schema) {
            try {
                const regex = new RegExp(schema.pattern);
                if (!regex.test(s)) {
                    errors.push({ error_path: path, error_message: 'Pattern-Match fehlgeschlagen' });
                }
            } catch (e) {
                // Ignoriere fehlerhafte regex
            }
        }

        // format
        if ('format' in schema) {
            const fmt = schema.format;
            let formatValid = true;

            try {
                if (fmt === 'date-time') {
                    const regex = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/;
                    if (!regex.test(s) || isNaN(Date.parse(s))) formatValid = false;
                } else if (fmt === 'date') {
                    const regex = /^\d{4}-\d{2}-\d{2}$/;
                    if (!regex.test(s) || isNaN(Date.parse(s))) formatValid = false;
                } else if (fmt === 'time') {
                    const regex = /^\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})?$/;
                    if (!regex.test(s)) formatValid = false;
                } else if (fmt === 'uuid') {
                    const regex = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
                    if (!regex.test(s)) formatValid = false;
                } else if (fmt === 'ipv4') {
                    const regex = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
                    if (!regex.test(s)) formatValid = false;
                } else if (fmt === 'ipv6') {
                    const regex = /^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$/;
                    if (!regex.test(s)) formatValid = false;
                } else if (fmt === 'email') {
                    const regex = /^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+\.[A-Za-z]+$/;
                    if (!regex.test(s)) formatValid = false;
                } else if (fmt === 'uri') {
                    const regex = /^[a-zA-Z][a-zA-Z0-9+.-]*:.*/;
                    if (!regex.test(s)) formatValid = false;
                }
            } catch (e) {
                formatValid = false;
            }

            if (!formatValid) {
                errors.push({
                    error_path: path,
                    error_message: `Format-Validierung fehlgeschlagen. Erwartet: ${fmt}`
                });
            }
        }
    }

    // --- 6. Logische Operatoren ---
    if ('allOf' in schema && Array.isArray(schema.allOf)) {
        for (const sub of schema.allOf) {
            errors.push(...vsonValidate(sub, data, path));
        }
    }

    if ('anyOf' in schema && Array.isArray(schema.anyOf)) {
        let anyMatch = false;
        for (const sub of schema.anyOf) {
            const subErrors = vsonValidate(sub, data, path);
            if (subErrors.length === 0) {
                anyMatch = true;
                break;
            }
        }
        if (!anyMatch) {
            errors.push({
                error_path: path,
                error_message: 'Kein Schema in "anyOf" erfüllt'
            });
        }
    }

    if ('oneOf' in schema && Array.isArray(schema.oneOf)) {
        let matches = 0;
        for (const sub of schema.oneOf) {
            const subErrors = vsonValidate(sub, data, path);
            if (subErrors.length === 0) {
                matches++;
            }
        }
        if (matches !== 1) {
            errors.push({
                error_path: path,
                error_message: `Erwartet genau 1 Treffer in "oneOf", aber gefunden: ${matches}`
            });
        }
    }

    if ('not' in schema) {
        const subErrors = vsonValidate(schema.not, data, path);
        if (subErrors.length === 0) {
            errors.push({
                error_path: path,
                error_message: 'Daten dürfen dem "not"-Schema nicht entsprechen'
            });
        }
    }

    // --- 7. Bedingungen (if/then/else) ---
    if ('if' in schema) {
        const ifErrors = vsonValidate(schema.if, data, path);
        if (ifErrors.length === 0) {
            if ('then' in schema) {
                errors.push(...vsonValidate(schema.then, data, path));
            }
        } else {
            if ('else' in schema) {
                errors.push(...vsonValidate(schema.else, data, path));
            }
        }
    }

    return errors;
}
