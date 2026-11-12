package eu;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Reference-Counted, Copy-on-Write Dynamic Array of Values for OpenEuphoria.
 */
public final class Sequence {
    public int refCount = 0;
    public int regexId = -1;
    public List<Integer> cleanupRids = null;
    private final ArrayList<Value> elements;

    public Sequence() {
        this.elements = new ArrayList<>();
    }

    public Sequence(int capacity) {
        this.elements = new ArrayList<>(Math.max(0, capacity));
    }

    public Sequence(int size, Value fill) {
        this.elements = new ArrayList<>(Math.max(0, size));
        for (int i = 0; i < size; i++) {
            fill.retain();
            this.elements.add(fill);
        }
    }

    /**
     * Copy constructor for Copy-on-Write cloning.
     */
    public Sequence(Sequence other) {
        this.regexId = other.regexId;
        this.elements = new ArrayList<>(other.elements.size());
        for (int i = 0; i < other.elements.size(); i++) {
            Value v = other.elements.get(i);
            v.retain();
            this.elements.add(v);
        }
    }

    public int length() {
        return elements.size();
    }

    public int size() {
        return elements.size();
    }

    public boolean isEmpty() {
        return elements.isEmpty();
    }

    public void ensureCapacity(int minCapacity) {
        elements.ensureCapacity(minCapacity);
    }

    public Value get(int index) {
        return elements.get(index);
    }

    public void set(int index, Value newVal) {
        newVal.retain();
        Value oldVal = elements.set(index, newVal);
        if (oldVal != null) {
            oldVal.release();
        }
    }

    public void setElement(int index, Value newVal) {
        if (index == elements.size()) {
            add(newVal);
        } else if (index > elements.size()) {
            while (elements.size() < index) {
                elements.add(Value.NONE);
            }
            add(newVal);
        } else {
            set(index, newVal);
        }
    }

    public void add(Value val) {
        val.retain();
        elements.add(val);
    }

    public void addElement(Value val) {
        add(val);
    }

    public void add(int index, Value val) {
        val.retain();
        elements.add(index, val);
    }

    public void insertElement(int index, Value val) {
        add(index, val);
    }

    public void addAll(Sequence other) {
        elements.ensureCapacity(elements.size() + other.elements.size());
        for (int i = 0; i < other.elements.size(); i++) {
            Value v = other.elements.get(i);
            v.retain();
            elements.add(v);
        }
    }

    public void addAll(int index, Sequence other) {
        elements.ensureCapacity(elements.size() + other.elements.size());
        for (int i = 0; i < other.elements.size(); i++) {
            Value v = other.elements.get(i);
            v.retain();
            elements.add(index + i, v);
        }
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
            elements.get(i).release();
        }
        elements.subList(fromIndex, toIndex).clear();
    }

    public void removeAt(int index) {
        Value old = elements.remove(index);
        if (old != null) {
            old.release();
        }
    }

    public void clear() {
        for (int i = 0; i < elements.size(); i++) {
            elements.get(i).release();
        }
        elements.clear();
    }

    public List<Value> rawList() {
        return Collections.unmodifiableList(elements);
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
