package eu;

import java.io.IOException;
import java.io.OutputStream;
import java.io.PrintStream;
import java.math.BigInteger;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CharsetDecoder;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.util.Locale;

/**
 * Euphorix Value representation for OpenEuphoria syntax (48-bit signed Integer, IEEE-754 double Atom,
 * Reference-Counted Copy-on-Write Sequence, or NONE).
 */
public final class Value {
    public static final byte KIND_NONE = 0;
    public static final byte KIND_INT  = 1;
    public static final byte KIND_F64  = 2;
    public static final byte KIND_SEQ  = 3;

    // 48-bit signed integer limits: [-140737488355328, +140737488355327]
    public static final long INT48_MIN = -(1L << 47);
    public static final long INT48_MAX =  (1L << 47) - 1L;

    public static final Value NONE = new Value(KIND_NONE, 0L, 0.0, null);

    private static final int CACHE_MIN = -1024;
    private static final int CACHE_MAX = 65535;
    private static final Value[] INT_CACHE = new Value[CACHE_MAX - CACHE_MIN + 1];

    static {
        for (int i = CACHE_MIN; i <= CACHE_MAX; i++) {
            INT_CACHE[i - CACHE_MIN] = new Value(KIND_INT, i, 0.0, null);
        }
    }

    public static final Value ZERO = fromInt(0);
    public static final Value ONE  = fromInt(1);
    public static final Value EMPTY_SEQ = new Value(KIND_SEQ, 0L, 0.0, new Sequence(0));

    private final byte kind;
    private final long intVal;
    private final double floatVal;
    private final Sequence seqVal;

    private Value(byte kind, long intVal, double floatVal, Sequence seqVal) {
        this.kind = kind;
        this.intVal = intVal;
        this.floatVal = floatVal;
        this.seqVal = seqVal;
    }

    public static Value fromInt(long v) {
        if (v >= CACHE_MIN && v <= CACHE_MAX) {
            return INT_CACHE[(int) v - CACHE_MIN];
        }
        if (v >= INT48_MIN && v <= INT48_MAX) {
            return new Value(KIND_INT, v, 0.0, null);
        }
        return fromF64((double) v);
    }

    public static Value fromF64(double d) {
        return new Value(KIND_F64, 0L, d, null);
    }

    public static Value fromFloat(double d) {
        return fromF64(d);
    }

    public static Value fromSeq(Sequence seq) {
        return new Value(KIND_SEQ, 0L, 0.0, seq);
    }

    public static Value fromString(String str) {
        if (str == null || str.isEmpty()) {
            return emptySeq(0);
        }
        byte[] bytes = str.getBytes(StandardCharsets.UTF_8);
        return fromRawBytes(bytes, 0, bytes.length);
    }

    public static Value fromRawBytes(byte[] bytes) {
        if (bytes == null || bytes.length == 0) {
            return emptySeq(0);
        }
        return fromRawBytes(bytes, 0, bytes.length);
    }

    public static Value fromRawBytes(byte[] bytes, int off, int len) {
        Sequence seq = new Sequence(len);
        for (int i = 0; i < len; i++) {
            seq.add(fromInt(bytes[off + i] & 0xFF));
        }
        return fromSeq(seq);
    }

    public static Value emptySeq(int capacity) {
        return fromSeq(new Sequence(capacity));
    }

    public static Value emptySeq() {
        return emptySeq(0);
    }

    public long rawBits() {
        return Double.doubleToRawLongBits(asF64());
    }

    public static String formatG(double d) {
        return formatCStyleG(d, 6);
    }

    public void retain() {
        if (kind == KIND_SEQ && seqVal != null) {
            seqVal.refCount++;
        }
    }

    public void release() {
        if (kind == KIND_SEQ && seqVal != null) {
            int rc = --seqVal.refCount;
            if (rc == 0) {
                seqVal.clear();
            }
        }
    }

    public Value deepCopy() {
        if (kind == KIND_SEQ && seqVal != null) {
            Sequence copy = new Sequence(seqVal.length());
            copy.regexId = seqVal.regexId;
            if (seqVal.cleanupRids != null) {
                for (int rid : seqVal.cleanupRids) {
                    copy.addCleanupRid(rid);
                }
            }
            for (int i = 0; i < seqVal.length(); i++) {
                copy.add(seqVal.get(i).deepCopy());
            }
            return fromSeq(copy);
        }
        return this;
    }

    public boolean isNone() { return kind == KIND_NONE; }
    public boolean isInt()  { return kind == KIND_INT; }
    public boolean isSeq()  { return kind == KIND_SEQ; }
    public boolean isF64()  { return kind == KIND_F64; }
    public boolean isAtom() { return kind == KIND_INT || kind == KIND_F64; }

    public boolean isEuphoriaInteger() {
        if (kind == KIND_INT) return true;
        if (kind != KIND_F64) return false;
        double d = floatVal;
        return Math.floor(d) == d && d >= (double) INT48_MIN && d <= (double) INT48_MAX;
    }

    public boolean checkVarType(VarType t) {
        return switch (t) {
            case Object   -> !isNone();
            case Atom     -> isAtom();
            case Integer  -> isEuphoriaInteger();
            case Sequence -> isSeq();
        };
    }

    public long asInt() {
        return intVal;
    }

    public double asF64Raw() {
        return floatVal;
    }

    public double asF64() {
        return kind == KIND_INT ? (double) intVal : floatVal;
    }

    public double asDouble() {
        return asF64();
    }

    public long toIntCoerce() {
        return kind == KIND_INT ? intVal : (long) floatVal;
    }

    public Sequence asSeq() {
        return seqVal;
    }

    /**
     * Condition truthiness in Euphoria (for `if` / `while`: must be an atom != 0).
     * Sets okOut[0] = false if this Value is a Sequence or None.
     */
    public boolean isTruthy(boolean[] okOut) {
        if (kind == KIND_INT) {
            okOut[0] = true;
            return intVal != 0;
        }
        if (kind == KIND_F64) {
            okOut[0] = true;
            return floatVal != 0.0;
        }
        okOut[0] = false;
        return false;
    }

    public static int compare(Value a, Value b) {
        if (a.isAtom() && b.isAtom()) {
            if (a.isInt() && b.isInt()) {
                return Long.compare(a.intVal, b.intVal);
            }
            double fa = a.asF64();
            double fb = b.asF64();
            return (fa < fb) ? -1 : (fa > fb ? 1 : 0);
        }
        if (a.isAtom() && b.isSeq()) return -1;
        if (a.isSeq() && b.isAtom()) return 1;
        if (a.isSeq() && b.isSeq()) {
            Sequence sa = a.seqVal;
            Sequence sb = b.seqVal;
            if (sa == sb) return 0;
            int minLen = Math.min(sa.length(), sb.length());
            for (int i = 0; i < minLen; i++) {
                int cmp = compare(sa.get(i), sb.get(i));
                if (cmp != 0) return cmp;
            }
            return Integer.compare(sa.length(), sb.length());
        }
        return 0;
    }

    public static boolean equal(Value a, Value b) {
        if (a == b) return true;
        if (a.kind == KIND_INT && b.kind == KIND_INT) {
            return a.intVal == b.intVal;
        }
        return compare(a, b) == 0;
    }

    public static String formatCStyleG(double d, int precision) {
        if (Double.isNaN(d)) return "nan";
        if (Double.isInfinite(d)) return d < 0 ? "-inf" : "inf";
        String s = String.format(Locale.US, "%." + precision + "g", d);
        int eIdx = s.indexOf('e');
        if (eIdx < 0) eIdx = s.indexOf('E');
        String mantissa = eIdx >= 0 ? s.substring(0, eIdx) : s;
        String exp = eIdx >= 0 ? s.substring(eIdx) : "";
        if (mantissa.indexOf('.') >= 0) {
            int end = mantissa.length();
            while (end > 0 && mantissa.charAt(end - 1) == '0') {
                end--;
            }
            if (end > 0 && mantissa.charAt(end - 1) == '.') {
                end--;
            }
            mantissa = mantissa.substring(0, end);
        }
        return mantissa + exp;
    }

    public void printPretty(PrintStream out) {
        if (kind == KIND_INT) {
            out.print(intVal);
        } else if (kind == KIND_F64) {
            out.print(formatCStyleG(floatVal, 10));
        } else if (kind == KIND_SEQ) {
            out.print('{');
            for (int i = 0; i < seqVal.length(); i++) {
                if (i > 0) out.print(',');
                seqVal.get(i).printPretty(out);
            }
            out.print('}');
        } else {
            out.print("<unassigned>");
        }
    }

    public void printChars(OutputStream out) throws IOException {
        if (isAtom()) {
            out.write((int) (toIntCoerce() & 0xFF));
        } else if (isSeq()) {
            for (int i = 0; i < seqVal.length(); i++) {
                Value elem = seqVal.get(i);
                if (elem.isAtom()) {
                    out.write((int) (elem.toIntCoerce() & 0xFF));
                } else {
                    elem.printChars(out);
                }
            }
        }
    }

    public byte[] toRawBytes() {
        if (isAtom()) {
            return new byte[]{ (byte) (toIntCoerce() & 0xFF) };
        }
        if (isSeq()) {
            int count = 0;
            for (int i = 0; i < seqVal.length(); i++) {
                if (seqVal.get(i).isAtom()) count++;
            }
            byte[] res = new byte[count];
            int idx = 0;
            for (int i = 0; i < seqVal.length(); i++) {
                Value elem = seqVal.get(i);
                if (elem.isAtom()) {
                    res[idx++] = (byte) (elem.toIntCoerce() & 0xFF);
                }
            }
            return res;
        }
        return new byte[0];
    }

    public String toUtf8String() {
        if (isAtom()) {
            return String.valueOf((char) toIntCoerce());
        }
        if (!isSeq()) {
            return "";
        }
        Sequence s = asSeq();
        int len = s.length();
        if (len == 0) return "";

        boolean hasCodePointAbove255 = false;
        boolean allAtoms = true;
        for (int i = 0; i < len; i++) {
            Value el = s.get(i);
            if (!el.isAtom()) {
                allAtoms = false;
                break;
            }
            long val = el.toIntCoerce();
            if (val > 255 || val < 0) {
                hasCodePointAbove255 = true;
            }
        }

        if (allAtoms && hasCodePointAbove255) {
            StringBuilder sb = new StringBuilder(len);
            for (int i = 0; i < len; i++) {
                int cp = (int) s.get(i).toIntCoerce();
                if (Character.isValidCodePoint(cp)) {
                    sb.appendCodePoint(cp);
                } else {
                    sb.append((char) (cp & 0xFFFF));
                }
            }
            return sb.toString();
        }

        byte[] raw = toRawBytes();
        try {
            CharsetDecoder decoder = StandardCharsets.UTF_8.newDecoder();
            decoder.onMalformedInput(CodingErrorAction.REPORT);
            decoder.onUnmappableCharacter(CodingErrorAction.REPORT);
            return decoder.decode(ByteBuffer.wrap(raw)).toString();
        } catch (CharacterCodingException e) {
            // Fallback to ISO-8859-1 for non-UTF-8 single-byte strings
            return new String(raw, StandardCharsets.ISO_8859_1);
        }
    }

    /**
     * Converts sequence of char codes (0..255) to a String where each byte is mapped
     * as UTF-8, matching C++ Value::to_string() for UTF-8 strings.
     */
    @Override
    public String toString() {
        return toUtf8String();
    }

    public String formatDebug() {
        if (kind == KIND_INT) {
            return Long.toString(intVal);
        }
        if (kind == KIND_F64) {
            return formatCStyleG(floatVal, 10);
        }
        if (kind == KIND_SEQ) {
            boolean isPrintableStr = !seqVal.isEmpty() && seqVal.length() <= 64;
            for (int i = 0; i < seqVal.length(); i++) {
                Value el = seqVal.get(i);
                if (!el.isInt()) { isPrintableStr = false; break; }
                long c = el.asInt();
                if (c < 32 || c > 126) { isPrintableStr = false; break; }
            }
            if (isPrintableStr) {
                return "\"" + toUtf8String() + "\"";
            }
            StringBuilder sb = new StringBuilder();
            sb.append('{');
            for (int i = 0; i < seqVal.length(); i++) {
                if (i > 0) sb.append(", ");
                if (i >= 16) { sb.append("..."); break; }
                sb.append(seqVal.get(i).formatDebug());
            }
            sb.append('}');
            return sb.toString();
        }
        return "<novalue>";
    }

    public enum BinOp {
        Add, Sub, Mul, Div,
        Remainder, Power,
        Eq, Neq, Lt, Le, Gt, Ge,
        And, Or, Xor,
        AndBits, OrBits, XorBits
    }

    public enum UnaryOp {
        Neg, Not, NotBits
    }

    private static Value evalScalarBinop(BinOp op, Value lhs, Value rhs, String[] errMsg) {
        if (lhs.isInt() && rhs.isInt()) {
            long a = lhs.intVal;
            long b = rhs.intVal;
            return switch (op) {
                case Add -> fromInt(a + b);
                case Sub -> fromInt(a - b);
                case Mul -> {
                    BigInteger prod = BigInteger.valueOf(a).multiply(BigInteger.valueOf(b));
                    if (prod.compareTo(BigInteger.valueOf(INT48_MIN)) >= 0
                            && prod.compareTo(BigInteger.valueOf(INT48_MAX)) <= 0) {
                        yield fromInt(prod.longValue());
                    }
                    yield fromF64((double) a * (double) b);
                }
                case Div -> {
                    if (b == 0) {
                        errMsg[0] = "Division durch 0 (attempt to divide by 0)";
                        yield NONE;
                    }
                    if (a % b == 0) {
                        yield fromInt(a / b);
                    }
                    yield fromF64((double) a / (double) b);
                }
                case Remainder -> {
                    if (b == 0) {
                        errMsg[0] = "remainder() Division durch 0";
                        yield NONE;
                    }
                    yield fromInt(a % b);
                }
                case Power -> {
                    double r = Math.pow((double) a, (double) b);
                    if (Math.floor(r) == r && r >= (double) INT48_MIN && r <= (double) INT48_MAX) {
                        yield fromInt((long) r);
                    }
                    yield fromF64(r);
                }
                case Eq      -> fromInt(a == b ? 1 : 0);
                case Neq     -> fromInt(a != b ? 1 : 0);
                case Lt      -> fromInt(a <  b ? 1 : 0);
                case Le      -> fromInt(a <= b ? 1 : 0);
                case Gt      -> fromInt(a >  b ? 1 : 0);
                case Ge      -> fromInt(a >= b ? 1 : 0);
                case And     -> fromInt((a != 0 && b != 0) ? 1 : 0);
                case Or      -> fromInt((a != 0 || b != 0) ? 1 : 0);
                case Xor     -> fromInt(((a != 0) ^ (b != 0)) ? 1 : 0);
                case AndBits -> fromInt(a & b);
                case OrBits  -> fromInt(a | b);
                case XorBits -> fromInt(a ^ b);
            };
        }

        double a = lhs.asF64();
        double b = rhs.asF64();
        return switch (op) {
            case Add -> fromF64(a + b);
            case Sub -> fromF64(a - b);
            case Mul -> fromF64(a * b);
            case Div -> {
                if (b == 0.0) {
                    errMsg[0] = "Division durch 0 (attempt to divide by 0)";
                    yield NONE;
                }
                yield fromF64(a / b);
            }
            case Remainder -> {
                if (b == 0.0) {
                    errMsg[0] = "remainder() Division durch 0";
                    yield NONE;
                }
                yield fromF64(a % b);
            }
            case Power   -> fromF64(Math.pow(a, b));
            case Eq      -> fromInt(a == b ? 1 : 0);
            case Neq     -> fromInt(a != b ? 1 : 0);
            case Lt      -> fromInt(a <  b ? 1 : 0);
            case Le      -> fromInt(a <= b ? 1 : 0);
            case Gt      -> fromInt(a >  b ? 1 : 0);
            case Ge      -> fromInt(a >= b ? 1 : 0);
            case And     -> fromInt((a != 0.0 && b != 0.0) ? 1 : 0);
            case Or      -> fromInt((a != 0.0 || b != 0.0) ? 1 : 0);
            case Xor     -> fromInt(((a != 0.0) ^ (b != 0.0)) ? 1 : 0);
            case AndBits -> fromInt((long) a & (long) b);
            case OrBits  -> fromInt((long) a | (long) b);
            case XorBits -> fromInt((long) a ^ (long) b);
        };
    }

    public static Value evalBinop(BinOp op, Value lhs, Value rhs, String[] errMsg) {
        if (lhs.isAtom() && rhs.isAtom()) {
            return evalScalarBinop(op, lhs, rhs, errMsg);
        }
        if (lhs.isSeq() && rhs.isAtom()) {
            Sequence sa = lhs.seqVal;
            Sequence out = new Sequence(sa.length());
            for (int i = 0; i < sa.length(); i++) {
                Value r = evalBinop(op, sa.get(i), rhs, errMsg);
                if (errMsg[0] != null) {
                    out.clear();
                    return NONE;
                }
                out.add(r);
            }
            return fromSeq(out);
        }
        if (lhs.isAtom() && rhs.isSeq()) {
            Sequence sb = rhs.seqVal;
            Sequence out = new Sequence(sb.length());
            for (int i = 0; i < sb.length(); i++) {
                Value r = evalBinop(op, lhs, sb.get(i), errMsg);
                if (errMsg[0] != null) {
                    out.clear();
                    return NONE;
                }
                out.add(r);
            }
            return fromSeq(out);
        }
        if (lhs.isSeq() && rhs.isSeq()) {
            Sequence sa = lhs.seqVal;
            Sequence sb = rhs.seqVal;
            if (sa.length() != sb.length()) {
                errMsg[0] = "Sequenz-Längen stimmen bei einer Operation nicht überein (sequence lengths are not the same)";
                return NONE;
            }
            Sequence out = new Sequence(sa.length());
            for (int i = 0; i < sa.length(); i++) {
                Value r = evalBinop(op, sa.get(i), sb.get(i), errMsg);
                if (errMsg[0] != null) {
                    out.clear();
                    return NONE;
                }
                out.add(r);
            }
            return fromSeq(out);
        }
        errMsg[0] = "Operation mit nicht-initialisiertem Wert";
        return NONE;
    }

    public static Value fromUnsigned64(long u) {
        if (u >= 0) {
            return fromInt(u);
        } else {
            double d = (double) (u & 0x7FFFFFFFFFFFFFFFL) + 9223372036854775808.0;
            return fromF64(d);
        }
    }

    public static Value evalUnary(UnaryOp op, Value val, String[] errMsg) {
        if (val.isInt()) {
            long v = val.intVal;
            return switch (op) {
                case Neg     -> fromInt(-v);
                case Not     -> fromInt(v == 0 ? 1 : 0);
                case NotBits -> fromUnsigned64(~v);
            };
        }
        if (val.isF64()) {
            double v = val.floatVal;
            long lv;
            if (v >= 0.0 && v <= 18446744073709551615.0) {
                if (v >= 9223372036854775808.0) {
                    lv = ((long) (v - 9223372036854775808.0)) | 0x8000000000000000L;
                } else {
                    lv = (long) v;
                }
            } else {
                lv = (long) v;
            }
            return switch (op) {
                case Neg     -> fromF64(-v);
                case Not     -> fromInt(v == 0.0 ? 1 : 0);
                case NotBits -> fromUnsigned64(~lv);
            };
        }
        if (val.isSeq()) {
            Sequence s = val.seqVal;
            Sequence out = new Sequence(s.length());
            for (int i = 0; i < s.length(); i++) {
                Value r = evalUnary(op, s.get(i), errMsg);
                if (errMsg[0] != null) {
                    out.clear();
                    return NONE;
                }
                out.add(r);
            }
            return fromSeq(out);
        }
        errMsg[0] = "Unäre Operation mit nicht-initialisiertem Wert";
        return NONE;
    }

    public static Value evalConcat(Value lhs, Value rhs) {
        if (lhs.isSeq() && rhs.isSeq()) {
            Sequence sa = lhs.seqVal;
            Sequence sb = rhs.seqVal;
            Sequence out = new Sequence(sa.length() + sb.length());
            out.addAll(sa);
            out.addAll(sb);
            return fromSeq(out);
        } else if (lhs.isSeq() && rhs.isAtom()) {
            Sequence sa = lhs.seqVal;
            Sequence out = new Sequence(sa.length() + 1);
            out.addAll(sa);
            out.add(rhs);
            return fromSeq(out);
        } else if (lhs.isAtom() && rhs.isSeq()) {
            Sequence sb = rhs.seqVal;
            Sequence out = new Sequence(1 + sb.length());
            out.add(lhs);
            out.addAll(sb);
            return fromSeq(out);
        } else {
            Sequence out = new Sequence(2);
            out.add(lhs);
            out.add(rhs);
            return fromSeq(out);
        }
    }
}
