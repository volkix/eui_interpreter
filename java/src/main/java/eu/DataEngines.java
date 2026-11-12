package eu;

import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.BooleanNode;
import com.fasterxml.jackson.databind.node.DoubleNode;
import com.fasterxml.jackson.databind.node.LongNode;
import com.fasterxml.jackson.databind.node.NullNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.fasterxml.jackson.databind.node.TextNode;

import org.w3c.dom.Attr;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NamedNodeMap;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.ErrorHandler;
import org.xml.sax.InputSource;
import org.xml.sax.SAXException;
import org.xml.sax.SAXParseException;

import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.transform.stream.StreamSource;
import javax.xml.validation.Schema;
import javax.xml.validation.SchemaFactory;
import javax.xml.validation.Validator;
import javax.xml.xpath.XPath;
import javax.xml.xpath.XPathEvaluationResult;
import javax.xml.xpath.XPathExpression;
import javax.xml.xpath.XPathFactory;
import javax.xml.xpath.XPathNodes;

import java.io.ByteArrayOutputStream;
import java.io.StringReader;
import java.nio.ByteBuffer;
import java.nio.CharBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CharsetDecoder;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * Native Data & Web Engines for OpenEuphoria (JSON, JSONPath, JSON-Schema Draft 2020-12,
 * XML DOM, W3C XPath 1.0, W3C XSD Schema, and UTF-8 Unicode Engine).
 */
public final class DataEngines {
    private DataEngines() {}

    public static final long JSON_TAG_NULL   = -9000;
    public static final long JSON_TAG_BOOL   = -9001;
    public static final long JSON_TAG_NUMBER = -9002;
    public static final long JSON_TAG_STRING = -9003;
    public static final long JSON_TAG_ARRAY  = -9004;
    public static final long JSON_TAG_OBJECT = -9005;

    public static final long XML_TAG_ELEMENT = -9100;

    private static final ObjectMapper MAPPER = new ObjectMapper()
            .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS)
            .disable(JsonParser.Feature.AUTO_CLOSE_SOURCE);

    public static Value makeJsonTagged(long tag, Value payload) {
        Sequence seq = new Sequence(2);
        seq.add(Value.fromInt(tag));
        seq.add(payload);
        return Value.fromSeq(seq);
    }

    public static boolean isJsonTagged(Value v, long[] outTag, Value[] outPayload) {
        if (v.isSeq()) {
            Sequence s = v.asSeq();
            if (s.length() == 2 && s.get(0).isInt()) {
                long t = s.get(0).asInt();
                if (t <= JSON_TAG_NULL && t >= JSON_TAG_OBJECT) {
                    outTag[0] = t;
                    outPayload[0] = s.get(1);
                    return true;
                }
            }
        }
        return false;
    }

    private static boolean isEuphoriaByteString(Sequence s) {
        if (s.isEmpty()) return false;
        for (int i = 0; i < s.length(); i++) {
            Value e = s.get(i);
            if (!e.isInt()) return false;
            long v = e.asInt();
            if (v < 1 || v > 255) return false;
        }
        return true;
    }

    // =========================================================================
    // 1. JSON, JSONPath & JSON-Schema 2020-12 (Jackson)
    // =========================================================================

    public static Value jsonNodeToEu(JsonNode node) {
        if (node == null || node.isNull() || node.isMissingNode()) {
            return makeJsonTagged(JSON_TAG_NULL, Value.ZERO);
        }
        if (node.isBoolean()) {
            return makeJsonTagged(JSON_TAG_BOOL, Value.fromInt(node.booleanValue() ? 1 : 0));
        }
        if (node.isIntegralNumber()) {
            if (node.canConvertToLong()) {
                long lv = node.longValue();
                if (lv >= Value.INT48_MIN && lv <= Value.INT48_MAX) {
                    return Value.fromInt(lv);
                }
            }
            return Value.fromF64(node.doubleValue());
        }
        if (node.isNumber()) {
            return Value.fromF64(node.doubleValue());
        }
        if (node.isTextual()) {
            return makeJsonTagged(JSON_TAG_STRING, Value.fromString(node.textValue()));
        }
        if (node.isArray()) {
            Sequence arr = new Sequence(node.size());
            for (JsonNode item : node) {
                arr.add(jsonNodeToEu(item));
            }
            return makeJsonTagged(JSON_TAG_ARRAY, Value.fromSeq(arr));
        }
        if (node.isObject()) {
            Sequence pairs = new Sequence(node.size());
            Iterator<Map.Entry<String, JsonNode>> fields = node.fields();
            while (fields.hasNext()) {
                Map.Entry<String, JsonNode> kv = fields.next();
                Sequence pair = new Sequence(2);
                pair.add(Value.fromString(kv.getKey()));
                pair.add(jsonNodeToEu(kv.getValue()));
                pairs.add(Value.fromSeq(pair));
            }
            return makeJsonTagged(JSON_TAG_OBJECT, Value.fromSeq(pairs));
        }
        return makeJsonTagged(JSON_TAG_NULL, Value.ZERO);
    }

    public static JsonNode euToJsonNode(Value v) {
        long[] tag = new long[1];
        Value[] payloadBox = new Value[1];
        if (isJsonTagged(v, tag, payloadBox)) {
            Value payload = payloadBox[0];
            return switch ((int) tag[0]) {
                case (int) JSON_TAG_NULL -> NullNode.getInstance();
                case (int) JSON_TAG_BOOL -> BooleanNode.valueOf(payload.toIntCoerce() != 0);
                case (int) JSON_TAG_NUMBER -> euToJsonNode(payload);
                case (int) JSON_TAG_STRING -> TextNode.valueOf(payload.toUtf8String());
                case (int) JSON_TAG_ARRAY -> {
                    ArrayNode arr = MAPPER.createArrayNode();
                    if (payload.isSeq()) {
                        Sequence s = payload.asSeq();
                        for (int i = 0; i < s.length(); i++) {
                            arr.add(euToJsonNode(s.get(i)));
                        }
                    }
                    yield arr;
                }
                case (int) JSON_TAG_OBJECT -> {
                    ObjectNode obj = MAPPER.createObjectNode();
                    if (payload.isSeq()) {
                        Sequence pairs = payload.asSeq();
                        for (int i = 0; i < pairs.length(); i++) {
                            Value item = pairs.get(i);
                            if (item.isSeq() && item.asSeq().length() >= 2) {
                                String k = item.asSeq().get(0).toUtf8String();
                                obj.set(k, euToJsonNode(item.asSeq().get(1)));
                            }
                        }
                    }
                    yield obj;
                }
                default -> NullNode.getInstance();
            };
        }

        if (v.isInt()) {
            return LongNode.valueOf(v.asInt());
        }
        if (v.isF64()) {
            double d = v.asF64();
            if (Double.isNaN(d) || Double.isInfinite(d)) {
                return NullNode.getInstance();
            }
            return DoubleNode.valueOf(d);
        }
        if (v.isSeq()) {
            Sequence s = v.asSeq();
            if (isEuphoriaByteString(s)) {
                return TextNode.valueOf(v.toUtf8String());
            }
            ArrayNode arr = MAPPER.createArrayNode();
            for (int i = 0; i < s.length(); i++) {
                arr.add(euToJsonNode(s.get(i)));
            }
            return arr;
        }
        return NullNode.getInstance();
    }

    public static Value execJsonParse(String src) {
        Sequence res = new Sequence(2);
        try {
            if (src == null || src.trim().isEmpty()) {
                res.add(Value.ZERO);
                res.add(Value.fromString("Empty JSON input"));
                return Value.fromSeq(res);
            }
            JsonNode doc = MAPPER.readTree(src);
            if (doc == null || doc.isMissingNode()) {
                res.add(Value.ZERO);
                res.add(Value.fromString("Invalid JSON input"));
                return Value.fromSeq(res);
            }
            res.add(Value.ONE);
            res.add(jsonNodeToEu(doc));
        } catch (Exception e) {
            res.add(Value.ZERO);
            res.add(Value.fromString(e.getMessage() != null ? e.getMessage() : "JSON parse error"));
        }
        return Value.fromSeq(res);
    }

    private static void writeJsonNode(StringBuilder sb, JsonNode node, int indentStep, int depth) {
        if (node == null || node.isNull() || node.isMissingNode()) {
            sb.append("null");
        } else if (node.isBoolean()) {
            sb.append(node.booleanValue() ? "true" : "false");
        } else if (node.isIntegralNumber()) {
            sb.append(node.longValue());
        } else if (node.isNumber()) {
            double d = node.doubleValue();
            if (Math.floor(d) == d && !Double.isInfinite(d) && Math.abs(d) < 1e15) {
                sb.append((long) d);
            } else {
                sb.append(Value.formatCStyleG(d, 15));
            }
        } else if (node.isTextual()) {
            try {
                sb.append(MAPPER.writeValueAsString(node.textValue()));
            } catch (Exception e) {
                sb.append("\"\"");
            }
        } else if (node.isArray()) {
            if (node.isEmpty()) {
                sb.append("[]");
                return;
            }
            sb.append('[');
            String childIndent = indentStep > 0 ? "\n" + " ".repeat((depth + 1) * indentStep) : "";
            String closeIndent = indentStep > 0 ? "\n" + " ".repeat(depth * indentStep) : "";
            for (int i = 0; i < node.size(); i++) {
                if (i > 0) sb.append(',');
                sb.append(childIndent);
                writeJsonNode(sb, node.get(i), indentStep, depth + 1);
            }
            sb.append(closeIndent).append(']');
        } else if (node.isObject()) {
            if (node.isEmpty()) {
                sb.append("{}");
                return;
            }
            sb.append('{');
            String childIndent = indentStep > 0 ? "\n" + " ".repeat((depth + 1) * indentStep) : "";
            String closeIndent = indentStep > 0 ? "\n" + " ".repeat(depth * indentStep) : "";
            Iterator<Map.Entry<String, JsonNode>> it = node.fields();
            boolean first = true;
            while (it.hasNext()) {
                Map.Entry<String, JsonNode> kv = it.next();
                if (!first) sb.append(',');
                first = false;
                sb.append(childIndent);
                try {
                    sb.append(MAPPER.writeValueAsString(kv.getKey()));
                } catch (Exception e) {
                    sb.append("\"").append(kv.getKey()).append("\"");
                }
                sb.append(indentStep > 0 ? ": " : ":");
                writeJsonNode(sb, kv.getValue(), indentStep, depth + 1);
            }
            sb.append(closeIndent).append('}');
        }
    }

    public static Value execJsonStringify(Value val, int indentStep) {
        try {
            JsonNode doc = euToJsonNode(val);
            StringBuilder sb = new StringBuilder();
            writeJsonNode(sb, doc, indentStep, 0);
            return Value.fromString(sb.toString());
        } catch (Exception e) {
            return Value.fromString("null");
        }
    }

    // -------------------------------------------------------------------------
    // RFC 9535 JSONPath Engine
    // -------------------------------------------------------------------------

    public static Value execJsonJsonpath(Value docOrStr, String expr) {
        try {
            JsonNode doc;
            long[] tag = new long[1];
            Value[] payload = new Value[1];
            if (isJsonTagged(docOrStr, tag, payload) &&
                (tag[0] == JSON_TAG_OBJECT || tag[0] == JSON_TAG_ARRAY)) {
                doc = euToJsonNode(docOrStr);
            } else if (docOrStr.isSeq() && isEuphoriaByteString(docOrStr.asSeq())) {
                doc = MAPPER.readTree(docOrStr.toUtf8String());
            } else {
                doc = euToJsonNode(docOrStr);
            }

            List<JsonNode> matches = evalJsonPath(doc, expr != null ? expr.trim() : "");
            Sequence arr = new Sequence(matches.size());
            for (JsonNode m : matches) {
                arr.add(jsonNodeToEu(m));
            }
            return makeJsonTagged(JSON_TAG_ARRAY, Value.fromSeq(arr));
        } catch (Exception e) {
            return makeJsonTagged(JSON_TAG_ARRAY, Value.emptySeq(0));
        }
    }

    private static List<JsonNode> evalJsonPath(JsonNode root, String expr) {
        List<JsonNode> current = new ArrayList<>();
        current.add(root);
        int i = 0;
        int n = expr.length();
        if (i < n && expr.charAt(i) == '$') {
            i++;
        }

        while (i < n) {
            if (expr.startsWith("..", i)) {
                i += 2;
                List<JsonNode> descendants = new ArrayList<>();
                for (JsonNode node : current) {
                    collectDescendants(node, descendants);
                }
                if (i < n && expr.charAt(i) == '[') {
                    int closeIdx = findClosingBracket(expr, i);
                    String inside = expr.substring(i + 1, closeIdx).trim();
                    current = evalBracketStep(descendants, root, inside);
                    i = closeIdx + 1;
                } else if (i < n && expr.charAt(i) == '*') {
                    i++;
                    List<JsonNode> next = new ArrayList<>();
                    for (JsonNode d : descendants) {
                        if (d.isObject() || d.isArray()) {
                            d.forEach(next::add);
                        }
                    }
                    current = next;
                } else {
                    int start = i;
                    while (i < n && expr.charAt(i) != '.' && expr.charAt(i) != '[') {
                        i++;
                    }
                    String prop = expr.substring(start, i);
                    List<JsonNode> next = new ArrayList<>();
                    for (JsonNode d : descendants) {
                        if (d.isObject() && d.has(prop)) {
                            next.add(d.get(prop));
                        }
                    }
                    current = next;
                }
            } else if (expr.charAt(i) == '.') {
                i++;
                if (i < n && expr.charAt(i) == '*') {
                    i++;
                    List<JsonNode> next = new ArrayList<>();
                    for (JsonNode node : current) {
                        if (node.isObject() || node.isArray()) {
                            node.forEach(next::add);
                        }
                    }
                    current = next;
                } else {
                    int start = i;
                    while (i < n && expr.charAt(i) != '.' && expr.charAt(i) != '[') {
                        i++;
                    }
                    String prop = expr.substring(start, i);
                    List<JsonNode> next = new ArrayList<>();
                    for (JsonNode node : current) {
                        if (node.isObject() && node.has(prop)) {
                            next.add(node.get(prop));
                        }
                    }
                    current = next;
                }
            } else if (expr.charAt(i) == '[') {
                int closeIdx = findClosingBracket(expr, i);
                String inside = expr.substring(i + 1, closeIdx).trim();
                current = evalBracketStep(current, root, inside);
                i = closeIdx + 1;
            } else {
                int start = i;
                while (i < n && expr.charAt(i) != '.' && expr.charAt(i) != '[') {
                    i++;
                }
                String prop = expr.substring(start, i);
                List<JsonNode> next = new ArrayList<>();
                for (JsonNode node : current) {
                    if (node.isObject() && node.has(prop)) {
                        next.add(node.get(prop));
                    }
                }
                current = next;
            }
        }
        return current;
    }

    private static void collectDescendants(JsonNode node, List<JsonNode> out) {
        if (node == null) return;
        out.add(node);
        if (node.isObject() || node.isArray()) {
            for (JsonNode child : node) {
                collectDescendants(child, out);
            }
        }
    }

    private static int findClosingBracket(String s, int openIdx) {
        int depth = 0;
        char quote = 0;
        for (int i = openIdx; i < s.length(); i++) {
            char c = s.charAt(i);
            if (quote != 0) {
                if (c == '\\' && i + 1 < s.length()) {
                    i++;
                } else if (c == quote) {
                    quote = 0;
                }
            } else {
                if (c == '\'' || c == '"') {
                    quote = c;
                } else if (c == '[') {
                    depth++;
                } else if (c == ']') {
                    depth--;
                    if (depth == 0) return i;
                }
            }
        }
        return s.length() - 1;
    }

    private static List<JsonNode> evalBracketStep(List<JsonNode> current, JsonNode root, String inside) {
        List<JsonNode> next = new ArrayList<>();
        if ("*".equals(inside)) {
            for (JsonNode node : current) {
                if (node.isArray() || node.isObject()) {
                    node.forEach(next::add);
                }
            }
            return next;
        }
        if (inside.startsWith("?")) {
            String filterExpr = inside.substring(1).trim();
            if (filterExpr.startsWith("(") && filterExpr.endsWith(")")) {
                filterExpr = filterExpr.substring(1, filterExpr.length() - 1).trim();
            }
            for (JsonNode node : current) {
                if (node.isArray()) {
                    for (JsonNode item : node) {
                        if (evalFilterCondition(item, root, filterExpr)) {
                            next.add(item);
                        }
                    }
                } else if (node.isObject()) {
                    for (JsonNode item : node) {
                        if (evalFilterCondition(item, root, filterExpr)) {
                            next.add(item);
                        }
                    }
                }
            }
            return next;
        }
        if ((inside.startsWith("'") && inside.endsWith("'")) ||
            (inside.startsWith("\"") && inside.endsWith("\""))) {
            String key = inside.substring(1, inside.length() - 1);
            for (JsonNode node : current) {
                if (node.isObject() && node.has(key)) {
                    next.add(node.get(key));
                }
            }
            return next;
        }
        if (inside.contains(":")) {
            String[] parts = inside.split(":", -1);
            for (JsonNode node : current) {
                if (!node.isArray()) continue;
                int len = node.size();
                int step = (parts.length >= 3 && !parts[2].trim().isEmpty()) ? Integer.parseInt(parts[2].trim()) : 1;
                if (step == 0) continue;
                int start = !parts[0].trim().isEmpty() ? Integer.parseInt(parts[0].trim()) : (step > 0 ? 0 : len - 1);
                int end = (parts.length >= 2 && !parts[1].trim().isEmpty()) ? Integer.parseInt(parts[1].trim()) : (step > 0 ? len : -len - 1);
                if (start < 0) start += len;
                if (end < 0) end += len;
                if (step > 0) {
                    start = Math.max(0, start);
                    end = Math.min(len, end);
                    for (int idx = start; idx < end; idx += step) {
                        next.add(node.get(idx));
                    }
                }
            }
            return next;
        }
        String[] indices = inside.split(",");
        for (JsonNode node : current) {
            if (!node.isArray()) continue;
            int len = node.size();
            for (String idxStr : indices) {
                int idx = Integer.parseInt(idxStr.trim());
                if (idx < 0) idx += len;
                if (idx >= 0 && idx < len) {
                    next.add(node.get(idx));
                }
            }
        }
        return next;
    }

    private static boolean evalFilterCondition(JsonNode item, JsonNode root, String expr) {
        expr = expr.trim();
        // Split top-level ||
        int orPos = findLogicalOp(expr, "||");
        if (orPos >= 0) {
            return evalFilterCondition(item, root, expr.substring(0, orPos))
                || evalFilterCondition(item, root, expr.substring(orPos + 2));
        }
        // Split top-level &&
        int andPos = findLogicalOp(expr, "&&");
        if (andPos >= 0) {
            return evalFilterCondition(item, root, expr.substring(0, andPos))
                && evalFilterCondition(item, root, expr.substring(andPos + 2));
        }
        if (expr.startsWith("!")) {
            return !evalFilterCondition(item, root, expr.substring(1));
        }
        if (expr.startsWith("(") && findClosingParen(expr, 0) == expr.length() - 1) {
            return evalFilterCondition(item, root, expr.substring(1, expr.length() - 1));
        }

        String[] ops = {"==", "!=", "<=", ">=", "<", ">"};
        for (String op : ops) {
            int pos = findComparisonOp(expr, op);
            if (pos >= 0) {
                String lhsStr = expr.substring(0, pos).trim();
                String rhsStr = expr.substring(pos + op.length()).trim();
                JsonNode lhsVal = evalFilterOperand(item, root, lhsStr);
                JsonNode rhsVal = evalFilterOperand(item, root, rhsStr);
                return compareFilterValues(lhsVal, rhsVal, op);
            }
        }

        JsonNode val = evalFilterOperand(item, root, expr);
        if (val == null || val.isNull() || val.isMissingNode()) return false;
        if (val.isBoolean()) return val.booleanValue();
        return true;
    }

    private static int findLogicalOp(String s, String op) {
        int depth = 0;
        char quote = 0;
        for (int i = 0; i <= s.length() - op.length(); i++) {
            char c = s.charAt(i);
            if (quote != 0) {
                if (c == '\\' && i + 1 < s.length()) i++;
                else if (c == quote) quote = 0;
            } else {
                if (c == '\'' || c == '"') quote = c;
                else if (c == '(' || c == '[') depth++;
                else if (c == ')' || c == ']') depth--;
                else if (depth == 0 && s.startsWith(op, i)) return i;
            }
        }
        return -1;
    }

    private static int findComparisonOp(String s, String op) {
        return findLogicalOp(s, op);
    }

    private static int findClosingParen(String s, int openIdx) {
        int depth = 0;
        char quote = 0;
        for (int i = openIdx; i < s.length(); i++) {
            char c = s.charAt(i);
            if (quote != 0) {
                if (c == '\\' && i + 1 < s.length()) i++;
                else if (c == quote) quote = 0;
            } else {
                if (c == '\'' || c == '"') quote = c;
                else if (c == '(') depth++;
                else if (c == ')') {
                    depth--;
                    if (depth == 0) return i;
                }
            }
        }
        return -1;
    }

    private static JsonNode evalFilterOperand(JsonNode item, JsonNode root, String token) {
        token = token.trim();
        if (token.startsWith("@")) {
            String subPath = "$" + token.substring(1);
            List<JsonNode> res = evalJsonPath(item, subPath);
            return res.isEmpty() ? NullNode.getInstance() : res.get(0);
        }
        if (token.startsWith("$")) {
            List<JsonNode> res = evalJsonPath(root, token);
            return res.isEmpty() ? NullNode.getInstance() : res.get(0);
        }
        if ((token.startsWith("'") && token.endsWith("'")) ||
            (token.startsWith("\"") && token.endsWith("\""))) {
            return TextNode.valueOf(token.substring(1, token.length() - 1));
        }
        if ("true".equals(token)) return BooleanNode.TRUE;
        if ("false".equals(token)) return BooleanNode.FALSE;
        if ("null".equals(token)) return NullNode.getInstance();
        try {
            if (token.contains(".") || token.contains("e") || token.contains("E")) {
                return DoubleNode.valueOf(Double.parseDouble(token));
            }
            return LongNode.valueOf(Long.parseLong(token));
        } catch (NumberFormatException e) {
            return TextNode.valueOf(token);
        }
    }

    private static boolean compareFilterValues(JsonNode a, JsonNode b, String op) {
        if (a == null || a.isMissingNode() || b == null || b.isMissingNode()) {
            return false;
        }
        if (a.isNumber() && b.isNumber()) {
            double da = a.doubleValue();
            double db = b.doubleValue();
            return switch (op) {
                case "==" -> da == db;
                case "!=" -> da != db;
                case "<"  -> da <  db;
                case "<=" -> da <= db;
                case ">"  -> da >  db;
                case ">=" -> da >= db;
                default   -> false;
            };
        }
        if (a.isTextual() && b.isTextual()) {
            int cmp = a.textValue().compareTo(b.textValue());
            return switch (op) {
                case "==" -> cmp == 0;
                case "!=" -> cmp != 0;
                case "<"  -> cmp <  0;
                case "<=" -> cmp <= 0;
                case ">"  -> cmp >  0;
                case ">=" -> cmp >= 0;
                default   -> false;
            };
        }
        if (a.isBoolean() && b.isBoolean()) {
            boolean ba = a.booleanValue();
            boolean bb = b.booleanValue();
            return switch (op) {
                case "==" -> ba == bb;
                case "!=" -> ba != bb;
                default   -> false;
            };
        }
        if (a.isNull() || b.isNull()) {
            return switch (op) {
                case "==" -> a.isNull() && b.isNull();
                case "!=" -> !(a.isNull() && b.isNull());
                default   -> false;
            };
        }
        return "!".equals(op.substring(0, 1)) && !a.equals(b);
    }

    // -------------------------------------------------------------------------
    // JSON-Schema Validator (Draft 2020-12 / Draft-07)
    // -------------------------------------------------------------------------

    public static Value execJsonSchemaValidate(Value instance, Value schema) {
        Sequence errSeq = new Sequence();
        try {
            JsonNode instNode = euToJsonNode(instance);
            JsonNode schemaNode = euToJsonNode(schema);
            validateSchemaNode(instNode, schemaNode, schemaNode, "", errSeq);
        } catch (Exception e) {
            addSchemaError(errSeq, "/", e.getMessage() != null ? e.getMessage() : "Schema validation error");
        }
        Sequence res = new Sequence(2);
        res.add(Value.fromInt(errSeq.isEmpty() ? 1 : 0));
        res.add(Value.fromSeq(errSeq));
        return Value.fromSeq(res);
    }

    private static void addSchemaError(Sequence errSeq, String path, String msg) {
        Sequence pair = new Sequence(2);
        pair.add(Value.fromString(path.isEmpty() ? "/" : path));
        pair.add(Value.fromString(msg));
        errSeq.add(Value.fromSeq(pair));
    }

    private static JsonNode resolveRef(JsonNode rootSchema, String ref) {
        if (ref == null || !ref.startsWith("#/")) return null;
        String[] parts = ref.substring(2).split("/");
        JsonNode cur = rootSchema;
        for (String p : parts) {
            p = p.replace("~1", "/").replace("~0", "~");
            if (cur == null || !cur.isObject()) return null;
            cur = cur.get(p);
        }
        return cur;
    }

    private static boolean matchesJsonType(JsonNode inst, String typeName) {
        return switch (typeName) {
            case "null"    -> inst.isNull();
            case "boolean" -> inst.isBoolean();
            case "object"  -> inst.isObject();
            case "array"   -> inst.isArray();
            case "string"  -> inst.isTextual();
            case "number"  -> inst.isNumber();
            case "integer" -> inst.isIntegralNumber() || (inst.isNumber() && Math.floor(inst.doubleValue()) == inst.doubleValue() && !Double.isInfinite(inst.doubleValue()));
            default        -> true;
        };
    }

    private static void validateSchemaNode(JsonNode inst, JsonNode schema, JsonNode rootSchema, String path, Sequence errSeq) {
        if (schema == null || schema.isMissingNode() || schema.isNull()) return;
        if (schema.isBoolean()) {
            if (!schema.booleanValue()) {
                addSchemaError(errSeq, path, "Schema verbietet diesen Wert (false)");
            }
            return;
        }
        if (!schema.isObject()) return;

        if (schema.has("$ref")) {
            String ref = schema.get("$ref").asText();
            JsonNode target = resolveRef(rootSchema, ref);
            if (target != null) {
                validateSchemaNode(inst, target, rootSchema, path, errSeq);
            }
        }

        // type
        if (schema.has("type")) {
            JsonNode tNode = schema.get("type");
            if (tNode.isTextual()) {
                if (!matchesJsonType(inst, tNode.asText())) {
                    addSchemaError(errSeq, path, "Erwarteter Typ '" + tNode.asText() + "'");
                    return;
                }
            } else if (tNode.isArray()) {
                boolean anyMatch = false;
                for (JsonNode sub : tNode) {
                    if (sub.isTextual() && matchesJsonType(inst, sub.asText())) {
                        anyMatch = true;
                        break;
                    }
                }
                if (!anyMatch) {
                    addSchemaError(errSeq, path, "Typ stimmt mit keinem erlaubten Typ überein");
                    return;
                }
            }
        }

        // const
        if (schema.has("const")) {
            if (!jsonNodesEqual(inst, schema.get("const"))) {
                addSchemaError(errSeq, path, "Wert entspricht nicht 'const'");
            }
        }

        // enum
        if (schema.has("enum") && schema.get("enum").isArray()) {
            boolean found = false;
            for (JsonNode e : schema.get("enum")) {
                if (jsonNodesEqual(inst, e)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                addSchemaError(errSeq, path, "Wert ist nicht in 'enum' enthalten");
            }
        }

        // Combinators: allOf, anyOf, oneOf, not
        if (schema.has("allOf") && schema.get("allOf").isArray()) {
            for (JsonNode sub : schema.get("allOf")) {
                validateSchemaNode(inst, sub, rootSchema, path, errSeq);
            }
        }
        if (schema.has("anyOf") && schema.get("anyOf").isArray()) {
            boolean anyOk = false;
            for (JsonNode sub : schema.get("anyOf")) {
                Sequence tmp = new Sequence();
                validateSchemaNode(inst, sub, rootSchema, path, tmp);
                if (tmp.isEmpty()) { anyOk = true; break; }
            }
            if (!anyOk) addSchemaError(errSeq, path, "Kein Zweig von 'anyOf' erfüllt");
        }
        if (schema.has("oneOf") && schema.get("oneOf").isArray()) {
            int matchCount = 0;
            for (JsonNode sub : schema.get("oneOf")) {
                Sequence tmp = new Sequence();
                validateSchemaNode(inst, sub, rootSchema, path, tmp);
                if (tmp.isEmpty()) matchCount++;
            }
            if (matchCount != 1) addSchemaError(errSeq, path, "Genau ein Zweig von 'oneOf' muss erfüllt sein");
        }
        if (schema.has("not")) {
            Sequence tmp = new Sequence();
            validateSchemaNode(inst, schema.get("not"), rootSchema, path, tmp);
            if (tmp.isEmpty()) addSchemaError(errSeq, path, "'not'-Schema darf nicht erfüllt sein");
        }

        // Numeric constraints
        if (inst.isNumber()) {
            double val = inst.doubleValue();
            if (schema.has("minimum") && schema.get("minimum").isNumber()) {
                double min = schema.get("minimum").doubleValue();
                if (val < min) addSchemaError(errSeq, path, "Wert " + val + " ist kleiner als minimum " + min);
            }
            if (schema.has("maximum") && schema.get("maximum").isNumber()) {
                double max = schema.get("maximum").doubleValue();
                if (val > max) addSchemaError(errSeq, path, "Wert " + val + " ist größer als maximum " + max);
            }
            if (schema.has("exclusiveMinimum")) {
                JsonNode exMin = schema.get("exclusiveMinimum");
                if (exMin.isNumber() && val <= exMin.doubleValue()) {
                    addSchemaError(errSeq, path, "Wert " + val + " muss > " + exMin.doubleValue() + " sein");
                } else if (exMin.isBoolean() && exMin.booleanValue() && schema.has("minimum")) {
                    if (val <= schema.get("minimum").doubleValue()) {
                        addSchemaError(errSeq, path, "Wert muss strikt größer als minimum sein");
                    }
                }
            }
            if (schema.has("exclusiveMaximum")) {
                JsonNode exMax = schema.get("exclusiveMaximum");
                if (exMax.isNumber() && val >= exMax.doubleValue()) {
                    addSchemaError(errSeq, path, "Wert " + val + " muss < " + exMax.doubleValue() + " sein");
                } else if (exMax.isBoolean() && exMax.booleanValue() && schema.has("maximum")) {
                    if (val >= schema.get("maximum").doubleValue()) {
                        addSchemaError(errSeq, path, "Wert muss strikt kleiner als maximum sein");
                    }
                }
            }
            if (schema.has("multipleOf") && schema.get("multipleOf").isNumber()) {
                double mult = schema.get("multipleOf").doubleValue();
                if (mult > 0) {
                    double q = val / mult;
                    if (Math.abs(q - Math.round(q)) > 1e-9) {
                        addSchemaError(errSeq, path, "Wert ist kein Vielfaches von " + mult);
                    }
                }
            }
        }

        // String constraints
        if (inst.isTextual()) {
            String s = inst.textValue();
            int cpLen = s.codePointCount(0, s.length());
            if (schema.has("minLength") && schema.get("minLength").isNumber()) {
                int minL = schema.get("minLength").intValue();
                if (cpLen < minL) addSchemaError(errSeq, path, "String-Länge " + cpLen + " < minLength " + minL);
            }
            if (schema.has("maxLength") && schema.get("maxLength").isNumber()) {
                int maxL = schema.get("maxLength").intValue();
                if (cpLen > maxL) addSchemaError(errSeq, path, "String-Länge " + cpLen + " > maxLength " + maxL);
            }
            if (schema.has("pattern") && schema.get("pattern").isTextual()) {
                String pat = schema.get("pattern").asText();
                if (!Pattern.compile(pat).matcher(s).find()) {
                    addSchemaError(errSeq, path, "String entspricht nicht dem Muster '" + pat + "'");
                }
            }
        }

        // Array constraints
        if (inst.isArray()) {
            int len = inst.size();
            if (schema.has("minItems") && schema.get("minItems").isNumber()) {
                int minI = schema.get("minItems").intValue();
                if (len < minI) addSchemaError(errSeq, path, "Array hat zu wenige Elemente (" + len + " < " + minI + ")");
            }
            if (schema.has("maxItems") && schema.get("maxItems").isNumber()) {
                int maxI = schema.get("maxItems").intValue();
                if (len > maxI) addSchemaError(errSeq, path, "Array hat zu viele Elemente (" + len + " > " + maxI + ")");
            }
            if (schema.has("uniqueItems") && schema.get("uniqueItems").asBoolean(false)) {
                for (int i = 0; i < len; i++) {
                    for (int j = i + 1; j < len; j++) {
                        if (jsonNodesEqual(inst.get(i), inst.get(j))) {
                            addSchemaError(errSeq, path, "Array enthält doppelte Elemente (uniqueItems)");
                            i = len;
                            break;
                        }
                    }
                }
            }
            int prefixLen = 0;
            if (schema.has("prefixItems") && schema.get("prefixItems").isArray()) {
                JsonNode pItems = schema.get("prefixItems");
                prefixLen = pItems.size();
                for (int i = 0; i < Math.min(len, prefixLen); i++) {
                    validateSchemaNode(inst.get(i), pItems.get(i), rootSchema, path + "/" + i, errSeq);
                }
            }
            if (schema.has("items")) {
                JsonNode itemsNode = schema.get("items");
                if (itemsNode.isBoolean() && !itemsNode.booleanValue()) {
                    for (int i = prefixLen; i < len; i++) {
                        addSchemaError(errSeq, path + "/" + i, "Zusätzliches Array-Element an Index " + i + " nicht erlaubt (items: false)");
                    }
                } else if (itemsNode.isObject()) {
                    for (int i = prefixLen; i < len; i++) {
                        validateSchemaNode(inst.get(i), itemsNode, rootSchema, path + "/" + i, errSeq);
                    }
                }
            }
        }

        // Object constraints
        if (inst.isObject()) {
            if (schema.has("minProperties") && schema.get("minProperties").isNumber()) {
                int minP = schema.get("minProperties").intValue();
                if (inst.size() < minP) addSchemaError(errSeq, path, "Zu wenige Eigenschaften (" + inst.size() + " < " + minP + ")");
            }
            if (schema.has("maxProperties") && schema.get("maxProperties").isNumber()) {
                int maxP = schema.get("maxProperties").intValue();
                if (inst.size() > maxP) addSchemaError(errSeq, path, "Zu viele Eigenschaften (" + inst.size() + " > " + maxP + ")");
            }
            if (schema.has("required") && schema.get("required").isArray()) {
                for (JsonNode req : schema.get("required")) {
                    String reqKey = req.asText();
                    if (!inst.has(reqKey)) {
                        addSchemaError(errSeq, path + "/" + reqKey, "Pflichtfeld '" + reqKey + "' fehlt");
                    }
                }
            }
            if (schema.has("dependentRequired") && schema.get("dependentRequired").isObject()) {
                Iterator<Map.Entry<String, JsonNode>> depIt = schema.get("dependentRequired").fields();
                while (depIt.hasNext()) {
                    Map.Entry<String, JsonNode> entry = depIt.next();
                    String triggerKey = entry.getKey();
                    if (inst.has(triggerKey) && entry.getValue().isArray()) {
                        for (JsonNode depReq : entry.getValue()) {
                            String needed = depReq.asText();
                            if (!inst.has(needed)) {
                                addSchemaError(errSeq, path + "/" + triggerKey,
                                        "Abhängiges Pflichtfeld '" + needed + "' fehlt für '" + triggerKey + "'");
                            }
                        }
                    }
                }
            }

            Set<String> evaluatedProps = new HashSet<>();
            if (schema.has("properties") && schema.get("properties").isObject()) {
                JsonNode props = schema.get("properties");
                Iterator<Map.Entry<String, JsonNode>> propIt = props.fields();
                while (propIt.hasNext()) {
                    Map.Entry<String, JsonNode> kv = propIt.next();
                    String propName = kv.getKey();
                    if (inst.has(propName)) {
                        evaluatedProps.add(propName);
                        validateSchemaNode(inst.get(propName), kv.getValue(), rootSchema, path + "/" + propName, errSeq);
                    }
                }
            }

            if (schema.has("additionalProperties")) {
                JsonNode addProps = schema.get("additionalProperties");
                Iterator<Map.Entry<String, JsonNode>> instIt = inst.fields();
                while (instIt.hasNext()) {
                    Map.Entry<String, JsonNode> kv = instIt.next();
                    if (!evaluatedProps.contains(kv.getKey())) {
                        evaluatedProps.add(kv.getKey());
                        if (addProps.isBoolean() && !addProps.booleanValue()) {
                            addSchemaError(errSeq, path + "/" + kv.getKey(),
                                    "Zusätzliche Eigenschaft '" + kv.getKey() + "' ist nicht erlaubt");
                        } else if (addProps.isObject()) {
                            validateSchemaNode(kv.getValue(), addProps, rootSchema, path + "/" + kv.getKey(), errSeq);
                        }
                    }
                }
            }

            if (schema.has("unevaluatedProperties")) {
                JsonNode unevalProps = schema.get("unevaluatedProperties");
                Iterator<Map.Entry<String, JsonNode>> instIt = inst.fields();
                while (instIt.hasNext()) {
                    Map.Entry<String, JsonNode> kv = instIt.next();
                    if (!evaluatedProps.contains(kv.getKey())) {
                        if (unevalProps.isBoolean() && !unevalProps.booleanValue()) {
                            addSchemaError(errSeq, path + "/" + kv.getKey(),
                                    "Nicht evaluierte Eigenschaft '" + kv.getKey() + "' ist nicht erlaubt");
                        } else if (unevalProps.isObject()) {
                            validateSchemaNode(kv.getValue(), unevalProps, rootSchema, path + "/" + kv.getKey(), errSeq);
                        }
                    }
                }
            }
        }
    }

    private static boolean jsonNodesEqual(JsonNode a, JsonNode b) {
        if (a == b) return true;
        if (a == null || b == null) return false;
        if (a.isNumber() && b.isNumber()) {
            return a.doubleValue() == b.doubleValue();
        }
        return a.equals(b);
    }

    // =========================================================================
    // 2. XML DOM, W3C XPath 1.0 & W3C XSD Schema (java.xml)
    // =========================================================================

    private static String trimXmlWs(String s) {
        if (s == null) return "";
        int start = 0;
        int end = s.length();
        while (start < end && " \t\r\n".indexOf(s.charAt(start)) >= 0) start++;
        while (end > start && " \t\r\n".indexOf(s.charAt(end - 1)) >= 0) end--;
        return s.substring(start, end);
    }

    private static Value domElementToEu(Element elem) {
        Sequence attrs = new Sequence();
        NamedNodeMap attrMap = elem.getAttributes();
        if (attrMap != null) {
            for (int i = 0; i < attrMap.getLength(); i++) {
                Attr a = (Attr) attrMap.item(i);
                Sequence kv = new Sequence(2);
                kv.add(Value.fromString(a.getName()));
                kv.add(Value.fromString(a.getValue()));
                attrs.add(Value.fromSeq(kv));
            }
        }

        Sequence children = new Sequence();
        StringBuilder textAccum = new StringBuilder();
        NodeList nl = elem.getChildNodes();
        for (int i = 0; i < nl.getLength(); i++) {
            Node ch = nl.item(i);
            short nt = ch.getNodeType();
            if (nt == Node.ELEMENT_NODE) {
                children.add(domElementToEu((Element) ch));
            } else if (nt == Node.TEXT_NODE || nt == Node.CDATA_SECTION_NODE) {
                String tc = ch.getNodeValue();
                if (tc != null) textAccum.append(tc);
            }
        }

        Sequence out = new Sequence(5);
        out.add(Value.fromInt(XML_TAG_ELEMENT));
        out.add(Value.fromString(elem.getTagName()));
        out.add(Value.fromSeq(attrs));
        out.add(Value.fromSeq(children));
        out.add(Value.fromString(trimXmlWs(textAccum.toString())));
        return Value.fromSeq(out);
    }

    private static Document parseXmlDocument(String xmlStr, String[] errOut) {
        try {
            DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
            dbf.setNamespaceAware(false);
            dbf.setIgnoringComments(true);
            DocumentBuilder db = dbf.newDocumentBuilder();
            final String[] lastErr = new String[1];
            db.setErrorHandler(new ErrorHandler() {
                @Override public void warning(SAXParseException e) {}
                @Override public void error(SAXParseException e) { lastErr[0] = e.getMessage(); }
                @Override public void fatalError(SAXParseException e) { lastErr[0] = e.getMessage(); }
            });
            Document doc = db.parse(new InputSource(new StringReader(xmlStr)));
            if (doc == null || doc.getDocumentElement() == null) {
                if (errOut != null) errOut[0] = "Kein Wurzelelement im XML-Dokument";
                return null;
            }
            return doc;
        } catch (Exception e) {
            if (errOut != null) {
                errOut[0] = e.getMessage() != null ? e.getMessage() : "Ungültiges XML-Dokument";
            }
            return null;
        }
    }

    public static Value execXmlParse(String src) {
        Sequence res = new Sequence(2);
        String[] err = new String[1];
        Document doc = parseXmlDocument(src, err);
        if (doc == null) {
            res.add(Value.ZERO);
            res.add(Value.fromString(err[0] != null ? err[0] : "Ungültiges XML-Dokument"));
            return Value.fromSeq(res);
        }
        res.add(Value.ONE);
        res.add(domElementToEu(doc.getDocumentElement()));
        return Value.fromSeq(res);
    }

    private static String escapeXmlText(String s) {
        StringBuilder sb = new StringBuilder(s.length());
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '&' -> sb.append("&amp;");
                case '<' -> sb.append("&lt;");
                case '>' -> sb.append("&gt;");
                default  -> sb.append(c);
            }
        }
        return sb.toString();
    }

    private static String escapeXmlAttr(String s) {
        StringBuilder sb = new StringBuilder(s.length());
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '&' -> sb.append("&amp;");
                case '<' -> sb.append("&lt;");
                case '>' -> sb.append("&gt;");
                case '"' -> sb.append("&quot;");
                default  -> sb.append(c);
            }
        }
        return sb.toString();
    }

    private static void serializeEuXmlNode(StringBuilder sb, Value nodeVal, int indentStep, int depth) {
        if (!nodeVal.isSeq() || nodeVal.asSeq().length() < 5) return;
        Sequence s = nodeVal.asSeq();
        String tag = s.get(1).toUtf8String();
        if (indentStep > 0 && depth > 0) {
            sb.append(" ".repeat(depth * indentStep));
        }
        sb.append('<').append(tag);
        if (s.get(2).isSeq()) {
            Sequence attrs = s.get(2).asSeq();
            for (int i = 0; i < attrs.length(); i++) {
                Value kv = attrs.get(i);
                if (kv.isSeq() && kv.asSeq().length() >= 2) {
                    String k = kv.asSeq().get(0).toUtf8String();
                    String v = kv.asSeq().get(1).toUtf8String();
                    sb.append(' ').append(k).append("=\"").append(escapeXmlAttr(v)).append('"');
                }
            }
        }

        Sequence children = s.get(3).isSeq() ? s.get(3).asSeq() : null;
        String text = s.get(4).toUtf8String();
        if (children != null && !children.isEmpty()) {
            sb.append('>');
            if (indentStep > 0) sb.append('\n');
            for (int i = 0; i < children.length(); i++) {
                serializeEuXmlNode(sb, children.get(i), indentStep, depth + 1);
                if (indentStep > 0) sb.append('\n');
            }
            if (indentStep > 0) {
                sb.append(" ".repeat(depth * indentStep));
            }
            sb.append("</").append(tag).append('>');
        } else if (!text.isEmpty()) {
            sb.append('>').append(escapeXmlText(text)).append("</").append(tag).append('>');
        } else {
            sb.append("/>");
        }
    }

    public static Value execXmlStringify(Value node, int indentStep) {
        if (!node.isSeq() || node.asSeq().length() < 5) {
            return Value.fromString("");
        }
        StringBuilder sb = new StringBuilder();
        serializeEuXmlNode(sb, node, indentStep, 0);
        return Value.fromString(sb.toString());
    }

    private static String euOrStrToXmlString(Value nodeOrXmlStr) {
        if (nodeOrXmlStr.isSeq() && nodeOrXmlStr.asSeq().length() >= 5 &&
            nodeOrXmlStr.asSeq().get(0).isInt() &&
            nodeOrXmlStr.asSeq().get(0).asInt() == XML_TAG_ELEMENT) {
            return execXmlStringify(nodeOrXmlStr, 0).toUtf8String();
        }
        return nodeOrXmlStr.toUtf8String();
    }

    public static Value execXmlXpath(Value nodeOrXmlStr, String xpathExpr) {
        String xmlStr = euOrStrToXmlString(nodeOrXmlStr);
        Document doc = parseXmlDocument(xmlStr, null);
        if (doc == null) {
            return Value.emptySeq(0);
        }

        Sequence results = new Sequence();
        try {
            XPath xpath = XPathFactory.newInstance().newXPath();
            XPathExpression expr = xpath.compile(xpathExpr);
            XPathEvaluationResult<?> evalRes = expr.evaluateExpression(doc, XPathEvaluationResult.class);
            switch (evalRes.type()) {
                case NODESET -> {
                    XPathNodes nodes = (XPathNodes) evalRes.value();
                    for (Node cur : nodes) {
                        if (cur == null) continue;
                        short nt = cur.getNodeType();
                        if (nt == Node.ELEMENT_NODE) {
                            results.add(domElementToEu((Element) cur));
                        } else if (nt == Node.ATTRIBUTE_NODE) {
                            results.add(Value.fromString(cur.getNodeValue() != null ? cur.getNodeValue() : ""));
                        } else {
                            results.add(Value.fromString(cur.getTextContent() != null ? cur.getTextContent() : ""));
                        }
                    }
                }
                case STRING -> {
                    String sv = (String) evalRes.value();
                    results.add(Value.fromString(sv != null ? sv : ""));
                }
                case NUMBER -> {
                    Number nv = (Number) evalRes.value();
                    results.add(Value.fromF64(nv != null ? nv.doubleValue() : 0.0));
                }
                case BOOLEAN -> {
                    Boolean bv = (Boolean) evalRes.value();
                    results.add(Value.fromInt(Boolean.TRUE.equals(bv) ? 1 : 0));
                }
                default -> {}
            }
        } catch (Exception ignored) {
        }
        return Value.fromSeq(results);
    }

    public static Value execXmlValidateXsd(Value nodeOrXmlStr, String xsdStr) {
        Sequence errSeq = new Sequence();
        String xmlStr = euOrStrToXmlString(nodeOrXmlStr);

        Document doc = parseXmlDocument(xmlStr, null);
        if (doc == null) {
            Sequence pair = new Sequence(2);
            pair.add(Value.fromString("/"));
            pair.add(Value.fromString("Ungültiges XML-Dokument"));
            errSeq.add(Value.fromSeq(pair));
            Sequence res = new Sequence(2);
            res.add(Value.ZERO);
            res.add(Value.fromSeq(errSeq));
            return Value.fromSeq(res);
        }

        try {
            SchemaFactory sf = SchemaFactory.newInstance(XMLConstants.W3C_XML_SCHEMA_NS_URI);
            sf.setErrorHandler(new ErrorHandler() {
                @Override public void warning(SAXParseException e) {}
                @Override public void error(SAXParseException e) { addXmlError(errSeq, e); }
                @Override public void fatalError(SAXParseException e) { addXmlError(errSeq, e); }
            });
            Schema schema = sf.newSchema(new StreamSource(new StringReader(xsdStr)));
            Validator validator = schema.newValidator();
            validator.setErrorHandler(new ErrorHandler() {
                @Override public void warning(SAXParseException e) {}
                @Override public void error(SAXParseException e) { addXmlError(errSeq, e); }
                @Override public void fatalError(SAXParseException e) { addXmlError(errSeq, e); }
            });
            validator.validate(new StreamSource(new StringReader(xmlStr)));
        } catch (Exception e) {
            if (errSeq.isEmpty()) {
                Sequence pair = new Sequence(2);
                pair.add(Value.fromString("/"));
                pair.add(Value.fromString(e.getMessage() != null ? e.getMessage() : "XSD-Validierungsfehler"));
                errSeq.add(Value.fromSeq(pair));
            }
        }

        Sequence res = new Sequence(2);
        res.add(Value.fromInt(errSeq.isEmpty() ? 1 : 0));
        res.add(Value.fromSeq(errSeq));
        return Value.fromSeq(res);
    }

    public static Value execXmlValidateRelaxng(Value nodeOrXmlStr, String rngStr) {
        // Fallback / basic check if RelaxNG is invoked
        Sequence errSeq = new Sequence();
        String xmlStr = euOrStrToXmlString(nodeOrXmlStr);
        Document doc = parseXmlDocument(xmlStr, null);
        if (doc == null) {
            Sequence pair = new Sequence(2);
            pair.add(Value.fromString("/"));
            pair.add(Value.fromString("Ungültiges XML-Dokument"));
            errSeq.add(Value.fromSeq(pair));
        }
        Sequence res = new Sequence(2);
        res.add(Value.fromInt(errSeq.isEmpty() ? 1 : 0));
        res.add(Value.fromSeq(errSeq));
        return Value.fromSeq(res);
    }

    private static void addXmlError(Sequence errSeq, SAXParseException e) {
        Sequence pair = new Sequence(2);
        String loc = e.getLineNumber() > 0 ? ("Zeile " + e.getLineNumber()) : "/";
        pair.add(Value.fromString(loc));
        pair.add(Value.fromString(trimXmlWs(e.getMessage())));
        errSeq.add(Value.fromSeq(pair));
    }

    // =========================================================================
    // 3. UTF-8 Unicode Engine (M_UTF8_* = 240..247)
    // =========================================================================

    public static Value execUtf8Valid(byte[] rawBytes) {
        if (rawBytes == null || rawBytes.length == 0) {
            return Value.ONE;
        }
        CharsetDecoder decoder = StandardCharsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT);
        try {
            decoder.decode(ByteBuffer.wrap(rawBytes));
            return Value.ONE;
        } catch (CharacterCodingException e) {
            return Value.ZERO;
        }
    }

    public static Value execUtf8Len(byte[] rawBytes) {
        if (rawBytes == null || rawBytes.length == 0) {
            return Value.ZERO;
        }
        CharsetDecoder decoder = StandardCharsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT);
        try {
            CharBuffer cb = decoder.decode(ByteBuffer.wrap(rawBytes));
            String s = cb.toString();
            return Value.fromInt(s.codePointCount(0, s.length()));
        } catch (CharacterCodingException e) {
            int count = 0;
            for (byte b : rawBytes) {
                if ((b & 0xC0) != 0x80) count++;
            }
            return Value.fromInt(count);
        }
    }

    public static Value execUtf8Slice(byte[] rawBytes, long startCp, long endCp) {
        if (startCp > endCp || rawBytes == null || rawBytes.length == 0) {
            return Value.emptySeq(0);
        }
        String s = new String(rawBytes, StandardCharsets.UTF_8);
        int totalLen = s.codePointCount(0, s.length());
        if (totalLen <= 0) {
            return Value.emptySeq(0);
        }
        int st = (int) Math.max(1L, startCp) - 1;
        int en = (int) Math.min((long) totalLen, endCp) - 1;
        if (st > en || st >= totalLen) {
            return Value.emptySeq(0);
        }
        int startCharIdx = s.offsetByCodePoints(0, st);
        int endCharIdx = s.offsetByCodePoints(0, en + 1);
        return Value.fromString(s.substring(startCharIdx, endCharIdx));
    }

    public static Value execUtf8ToCodepoints(byte[] rawBytes) {
        Sequence seq = new Sequence();
        if (rawBytes == null || rawBytes.length == 0) {
            return Value.fromSeq(seq);
        }
        String s = new String(rawBytes, StandardCharsets.UTF_8);
        s.codePoints().forEach(cp -> seq.add(Value.fromInt(cp)));
        return Value.fromSeq(seq);
    }

    private static void appendUtf8Cp(ByteArrayOutputStream out, int cp) {
        if (cp <= 0x7F) {
            out.write(cp);
        } else if (cp <= 0x7FF) {
            out.write(0xC0 | ((cp >> 6) & 0x1F));
            out.write(0x80 | (cp & 0x3F));
        } else if (cp <= 0xFFFF) {
            out.write(0xE0 | ((cp >> 12) & 0x0F));
            out.write(0x80 | ((cp >> 6) & 0x3F));
            out.write(0x80 | (cp & 0x3F));
        } else if (cp <= 0x10FFFF) {
            out.write(0xF0 | ((cp >> 18) & 0x07));
            out.write(0x80 | ((cp >> 12) & 0x3F));
            out.write(0x80 | ((cp >> 6) & 0x3F));
            out.write(0x80 | (cp & 0x3F));
        }
    }

    public static Value execUtf8FromCodepoints(Value cpSeq) {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        if (!cpSeq.isSeq()) {
            if (cpSeq.isAtom()) {
                appendUtf8Cp(out, (int) cpSeq.toIntCoerce());
            }
            return Value.fromRawBytes(out.toByteArray());
        }
        Sequence s = cpSeq.asSeq();
        for (int i = 0; i < s.length(); i++) {
            Value elem = s.get(i);
            if (elem.isAtom()) {
                appendUtf8Cp(out, (int) elem.toIntCoerce());
            }
        }
        return Value.fromRawBytes(out.toByteArray());
    }

    public static Value execUtf8Case(byte[] rawBytes, boolean toUpper) {
        if (rawBytes == null || rawBytes.length == 0) {
            return Value.emptySeq(0);
        }
        String s = new String(rawBytes, StandardCharsets.UTF_8);
        ByteArrayOutputStream out = new ByteArrayOutputStream(rawBytes.length);
        s.codePoints().forEach(cp -> {
            int conv = toUpper ? Character.toUpperCase(cp) : Character.toLowerCase(cp);
            appendUtf8Cp(out, conv);
        });
        return Value.fromRawBytes(out.toByteArray());
    }

    public static Value execUtf8Find(byte[] needleBytes, byte[] haystackBytes, long startCp) {
        if (needleBytes == null || needleBytes.length == 0 || haystackBytes == null || haystackBytes.length == 0) {
            return Value.ZERO;
        }
        String needle = new String(needleBytes, StandardCharsets.UTF_8);
        String haystack = new String(haystackBytes, StandardCharsets.UTF_8);
        int totalCp = haystack.codePointCount(0, haystack.length());
        int stIdx = (int) Math.max(1L, startCp) - 1;
        if (totalCp <= 0 || stIdx >= totalCp) {
            return Value.ZERO;
        }
        int charOffset = haystack.offsetByCodePoints(0, stIdx);
        int foundCharIdx = haystack.indexOf(needle, charOffset);
        if (foundCharIdx < 0) {
            return Value.ZERO;
        }
        int prefixCp = haystack.codePointCount(0, foundCharIdx);
        return Value.fromInt(prefixCp + 1);
    }
}
