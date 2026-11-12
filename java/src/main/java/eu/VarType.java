package eu;

public enum VarType {
    Object(0, "object"),
    Atom(1, "atom"),
    Integer(2, "integer"),
    Sequence(3, "sequence");

    private final int id;
    private final String name;

    VarType(int id, String name) {
        this.id = id;
        this.name = name;
    }

    public int id() {
        return id;
    }

    public int code() {
        return id;
    }

    public String typeName() {
        return name;
    }

    public String TypeName() {
        return name;
    }

    public static VarType fromId(int id) {
        return switch (id) {
            case 1 -> Atom;
            case 2 -> Integer;
            case 3 -> Sequence;
            default -> Object;
        };
    }

    public static VarType fromCode(int code) {
        return fromId(code);
    }
}
