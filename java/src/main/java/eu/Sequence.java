package eu;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

/**
 * Reference-Counted, Copy-on-Write Dynamic Array of Values for Euphorix (OpenEuphoria syntax).
 * Backed directly by a flat Value[] array for zero-overhead VM indexing and fast repeat().
 */
public final class Sequence {
    private static final Value[] EMPTY_DATA = new Value[0];

    public int refCount = 0;
    public int regexId = -1;
    public List<Integer> cleanupRids = null;

    Value[] data;
    int len;

    public Sequence() {
        this.data = EMPTY_DATA;
        this.len = 0;
    }

    public Sequence(int capacity) {
        this.data = (capacity > 0) ? new Value[capacity] : EMPTY_DATA;
        this.len = 0;
    }

    public Sequence(int size, Value fill) {
        if (size <= 0) {
            this.data = EMPTY_DATA;
            this.len = 0;
            return;
        }
        this.data = new Value[size];
        this.len = size;
        Arrays.fill(this.data, fill);
        if (fill.kind == Value.KIND_SEQ && fill.seqVal != null) {
            fill.seqVal.refCount += size;
        }
    }

    /**
     * Copy constructor for Copy-on-Write cloning.
     */
    public Sequence(Sequence other) {
        this.regexId = other.regexId;
        int n = other.len;
        this.len = n;
        if (n == 0) {
            this.data = EMPTY_DATA;
            return;
        }
        Value[] src = other.data;
        Value[] dst = new Value[n];
        System.arraycopy(src, 0, dst, 0, n);
        for (int i = 0; i < n; i++) {
            Value v = dst[i];
            if (v.kind == Value.KIND_SEQ && v.seqVal != null) {
                v.seqVal.refCount++;
            }
        }
        this.data = dst;
    }

    public int length() {
        return len;
    }

    public int size() {
        return len;
    }

    public boolean isEmpty() {
        return len == 0;
    }

    public void ensureCapacity(int minCapacity) {
        if (minCapacity <= data.length) return;
        int newCap = Math.max(minCapacity, Math.max(8, data.length + (data.length >>> 1)));
        data = Arrays.copyOf(data, newCap);
    }

    public Value get(int index) {
        return data[index];
    }

    public void set(int index, Value newVal) {
        if (newVal.kind == Value.KIND_SEQ && newVal.seqVal != null) {
            newVal.seqVal.refCount++;
        }
        Value oldVal = data[index];
        data[index] = newVal;
        if (oldVal != null && oldVal.kind == Value.KIND_SEQ && oldVal.seqVal != null) {
            oldVal.release();
        }
    }

    public void setElement(int index, Value newVal) {
        if (index == len) {
            add(newVal);
        } else if (index > len) {
            ensureCapacity(index + 1);
            while (len < index) {
                data[len++] = Value.NONE;
            }
            add(newVal);
        } else {
            set(index, newVal);
        }
    }

    public void add(Value val) {
        if (val.kind == Value.KIND_SEQ && val.seqVal != null) {
            val.seqVal.refCount++;
        }
        if (len == data.length) {
            ensureCapacity(len + 1);
        }
        data[len++] = val;
    }

    public void addElement(Value val) {
        add(val);
    }

    public void add(int index, Value val) {
        if (val.kind == Value.KIND_SEQ && val.seqVal != null) {
            val.seqVal.refCount++;
        }
        if (len == data.length) {
            ensureCapacity(len + 1);
        }
        if (index < len) {
            System.arraycopy(data, index, data, index + 1, len - index);
        }
        data[index] = val;
        len++;
    }

    public void insertElement(int index, Value val) {
        add(index, val);
    }

    public void addAll(Sequence other) {
        int otherLen = other.len;
        if (otherLen == 0) return;
        ensureCapacity(len + otherLen);
        Value[] src = other.data;
        System.arraycopy(src, 0, data, len, otherLen);
        for (int i = 0; i < otherLen; i++) {
            Value v = src[i];
            if (v.kind == Value.KIND_SEQ && v.seqVal != null) {
                v.seqVal.refCount++;
            }
        }
        len += otherLen;
    }

    public void addAll(int index, Sequence other) {
        int otherLen = other.len;
        if (otherLen == 0) return;
        ensureCapacity(len + otherLen);
        if (index < len) {
            System.arraycopy(data, index, data, index + otherLen, len - index);
        }
        Value[] src = other.data;
        System.arraycopy(src, 0, data, index, otherLen);
        for (int i = 0; i < otherLen; i++) {
            Value v = src[i];
            if (v.kind == Value.KIND_SEQ && v.seqVal != null) {
                v.seqVal.refCount++;
            }
        }
        len += otherLen;
    }

    public void insertAll(int index, Sequence other) {
        addAll(index, other);
    }

    public void replaceRange(int fromIndex, int toIndex, Sequence replacement) {
        Sequence rep = (replacement == this) ? new Sequence(this) : replacement;
        removeRange(fromIndex, toIndex);
        addAll(fromIndex, rep);
    }

    public void removeRange(int fromIndex, int toIndex) {
        if (fromIndex >= toIndex) return;
        for (int i = fromIndex; i < toIndex; i++) {
            Value old = data[i];
            if (old != null && old.kind == Value.KIND_SEQ && old.seqVal != null) {
                old.release();
            }
        }
        int numMoved = len - toIndex;
        if (numMoved > 0) {
            System.arraycopy(data, toIndex, data, fromIndex, numMoved);
        }
        int newLen = len - (toIndex - fromIndex);
        Arrays.fill(data, newLen, len, null);
        len = newLen;
    }

    public void removeAt(int index) {
        Value old = data[index];
        int numMoved = len - index - 1;
        if (numMoved > 0) {
            System.arraycopy(data, index + 1, data, index, numMoved);
        }
        data[--len] = null;
        if (old != null && old.kind == Value.KIND_SEQ && old.seqVal != null) {
            old.release();
        }
    }

    public void clear() {
        for (int i = 0; i < len; i++) {
            Value old = data[i];
            if (old != null && old.kind == Value.KIND_SEQ && old.seqVal != null) {
                old.release();
            }
            data[i] = null;
        }
        len = 0;
    }

    public List<Value> rawList() {
        return Collections.unmodifiableList(Arrays.asList(Arrays.copyOf(data, len)));
    }

    public void addCleanupRid(int rid) {
        if (cleanupRids == null) {
            cleanupRids = new ArrayList<>(2);
        }
        cleanupRids.add(rid);
    }

    public int popCleanupRid() {
        if (cleanupRids == null || cleanupRids.isEmpty()) {
            return -1;
        }
        return cleanupRids.remove(cleanupRids.size() - 1);
    }
}
