package eu;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.PrintStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.zip.GZIPInputStream;
import java.util.zip.GZIPOutputStream;

/**
 * 32-bit Register-Based Bytecode Instruction Format & Program Metadata.
 */
public final class Bytecode {
    private Bytecode() {}

    public enum Op {
        // Constants & Moves
        LoadK,
        LoadImm,
        LoadNone,
        Move,

        // Global Variables
        GetGlobal,
        SetGlobal,
        TakeGlobal,
        CheckType,

        // Arithmetic & Logical Operations
        Add,
        Sub,
        Mul,
        Div,
        Concat,
        Eq,
        Neq,
        Lt,
        Le,
        Gt,
        Ge,
        And,
        Or,
        Xor,
        Neg,
        Not,

        // Structural Comparison
        EqualObj,

        // Sequences
        NewSeq,
        Len,
        GetIdx,
        SetIdx,
        GetSlice,
        SetSlice,

        // Control Flow
        Jmp,
        JmpFalse,
        JmpTrue,
        JmpIfNotNone,
        ForPrep,
        ForLoop,

        // Routines & Builtins
        Call,
        Builtin,
        PrintQ,
        Return,
        Halt;

        public static final Op[] VALUES = values();
    }

    public enum BuiltinId {
        // Sequence & Core
        Length,
        Append,
        Prepend,
        Repeat,
        Head,
        Tail,
        Remove,
        Replace,
        Insert,
        Splice,
        Compare,
        Equal,
        Find,
        Match,
        Hash,

        // Type Queries
        Atom,
        Integer,
        Sequence,
        Object,

        // Math & Bitwise
        Floor,
        Remainder,
        Power,
        Sqrt,
        Sin,
        Cos,
        Tan,
        Arctan,
        Log,
        Rand,
        AndBits,
        OrBits,
        XorBits,
        NotBits,

        // I/O & Console
        Puts,
        Print,
        Printf,
        Sprintf,
        Open,
        Close,
        Getc,
        Gets,
        GetKey,
        Position,
        ClearScreen,

        // OS & Runtime
        Time,
        Date,
        Getenv,
        Platform,
        CommandLine,
        System,
        SystemExec,
        Abort,
        OptionSwitches,
        IncludePaths,
        Warning,
        Trace,
        Profile,

        // Dynamic Routine Invocation & Cleanup
        RoutineId,
        CallFunc,
        CallProc,
        DeleteRoutine,
        Delete,

        // Low-Level Memory, Peek/Poke & Machine Bridge
        MachineFunc,
        MachineProc,
        Sizeof,
        MemCopy,
        MemSet,
        Peek,
        Peeks,
        PeekString,
        Peek2s,
        Peek2u,
        Peek4s,
        Peek4u,
        Peek8s,
        Peek8u,
        PeekPointer,
        Poke,
        Poke2,
        Poke4,
        Poke8,
        PokePointer,
        CFunc,
        CProc,
        Call,

        // Euphoria Multitasking
        TaskCreate,
        TaskSchedule,
        TaskYield,
        TaskSelf,
        TaskStatus,
        TaskList,
        TaskSuspend,
        TaskClockStart,
        TaskClockStop;

        public static final BuiltinId[] VALUES = values();
    }

    public static final class Instr {
        private Instr() {}

        public static int makeAbc(Op op, int a, int b, int c) {
            return (op.ordinal() & 0xFF)
                 | ((a & 0xFF) << 8)
                 | ((b & 0xFF) << 16)
                 | ((c & 0xFF) << 24);
        }

        public static int makeAbx(Op op, int a, int bx) {
            return (op.ordinal() & 0xFF)
                 | ((a & 0xFF) << 8)
                 | ((bx & 0xFFFF) << 16);
        }

        public static int makeAsbx(Op op, int a, int sbx) {
            return makeAbx(op, a, sbx & 0xFFFF);
        }

        public static int opOrdinal(int raw) {
            return raw & 0xFF;
        }

        public static Op op(int raw) {
            return Op.VALUES[raw & 0xFF];
        }

        public static int a(int raw) {
            return (raw >>> 8) & 0xFF;
        }

        public static int b(int raw) {
            return (raw >>> 16) & 0xFF;
        }

        public static int c(int raw) {
            return (raw >>> 24) & 0xFF;
        }

        public static int bx(int raw) {
            return (raw >>> 16) & 0xFFFF;
        }

        public static int sbx(int raw) {
            return (short) (raw >>> 16);
        }

        public static int patchSbx(int raw, int sbx) {
            return (raw & 0x0000FFFF) | ((sbx & 0xFFFF) << 16);
        }

        public static int patchB(int raw, int bVal) {
            return (raw & 0xFF00FFFF) | ((bVal & 0xFF) << 16);
        }
    }

    public static final class ParamDefault {
        public boolean hasDefault = false;
        public Value literalVal = Value.NONE;
        public String identOrBuiltin = "";

        public ParamDefault() {}

        public ParamDefault(boolean hasDefault, Value literalVal, String identOrBuiltin) {
            this.hasDefault = hasDefault;
            this.literalVal = literalVal;
            this.identOrBuiltin = identOrBuiltin;
        }
    }

    public static final class RoutineProto {
        public String name = "";
        public String ns = "";
        public String file = "";
        public boolean isFunction = false;
        public boolean isType = false;
        public boolean isDefined = false;
        public boolean isExported = false;
        public boolean isOverride = false;
        public int minArity = 0;
        public int arity = 0;
        public int maxRegs = 0;
        public final List<VarType> paramTypes = new ArrayList<>();
        public final List<Integer> paramCustomTypeRoutine = new ArrayList<>();
        public final List<ParamDefault> paramDefaults = new ArrayList<>();
        public final List<Integer> code = new ArrayList<>();
        public final List<Integer> lines = new ArrayList<>();

        // Cached primitive arrays for fast VM execution
        int[] fastCode = null;
        int[] fastLines = null;

        public int[] fastCode() {
            if (fastCode == null || fastCode.length != code.size()) {
                int n = code.size();
                fastCode = new int[n];
                for (int i = 0; i < n; i++) {
                    fastCode[i] = code.get(i);
                }
            }
            return fastCode;
        }

        public int[] fastLines() {
            if (fastLines == null || fastLines.length != lines.size()) {
                int n = lines.size();
                fastLines = new int[n];
                for (int i = 0; i < n; i++) {
                    fastLines[i] = lines.get(i);
                }
            }
            return fastLines;
        }

        public void invalidateFastCache() {
            fastCode = null;
            fastLines = null;
        }
    }

    public static final class GlobalVarInfo {
        public String name = "";
        public String ns = "";
        public String file = "";
        public VarType type = VarType.Object;
        public int customTypeRoutine = 0;
        public boolean isConstant = false;
        public boolean isExported = false;
        public Value initialValue = Value.NONE;
    }

    public static final class Program {
        public final List<Value> constants = new ArrayList<>();
        public final List<GlobalVarInfo> globals = new ArrayList<>();
        public final List<RoutineProto> routines = new ArrayList<>();
        public final List<String> cliArgs = new ArrayList<>();

        public static String opName(Op op) {
            return switch (op) {
                case LoadK        -> "LOADK";
                case LoadImm      -> "LOADIMM";
                case LoadNone     -> "LOADNONE";
                case Move         -> "MOVE";
                case GetGlobal    -> "GETGLOBAL";
                case SetGlobal    -> "SETGLOBAL";
                case TakeGlobal   -> "TAKEGLOBAL";
                case CheckType    -> "CHECKTYPE";
                case Add          -> "ADD";
                case Sub          -> "SUB";
                case Mul          -> "MUL";
                case Div          -> "DIV";
                case Concat       -> "CONCAT";
                case Eq           -> "EQ";
                case Neq          -> "NEQ";
                case Lt           -> "LT";
                case Le           -> "LE";
                case Gt           -> "GT";
                case Ge           -> "Ge";
                case And          -> "AND";
                case Or           -> "OR";
                case Xor          -> "XOR";
                case Neg          -> "NEG";
                case Not          -> "NOT";
                case EqualObj     -> "EQUALOBJ";
                case NewSeq       -> "NEWSEQ";
                case Len          -> "LEN";
                case GetIdx       -> "GETIDX";
                case SetIdx       -> "SETIDX";
                case GetSlice     -> "GETSLICE";
                case SetSlice     -> "SETSLICE";
                case Jmp          -> "JMP";
                case JmpFalse     -> "JMPFALSE";
                case JmpTrue      -> "JMPTRUE";
                case JmpIfNotNone -> "JMPNOTNONE";
                case ForPrep      -> "FORPREP";
                case ForLoop      -> "FORLOOP";
                case Call         -> "CALL";
                case Builtin      -> "BUILTIN";
                case PrintQ       -> "PRINTQ";
                case Return       -> "RETURN";
                case Halt         -> "HALT";
            };
        }

        public void disassemble(PrintStream out) {
            out.println("=== Euphorix Register-VM Bytecode Dump ===");
            for (RoutineProto r : routines) {
                out.printf("\nRoutine %s (arity=%d..%d, max_regs=%d):\n",
                        r.name, r.minArity, r.arity, r.maxRegs);
                for (int pc = 0; pc < r.code.size(); pc++) {
                    int ins = r.code.get(pc);
                    Op op = Instr.op(ins);
                    out.printf("  %04d [L%03d] %-10s ", pc, r.lines.get(pc), opName(op));
                    switch (op) {
                        case LoadK ->
                            out.printf("R%d, K[%d] (%s)\n", Instr.a(ins), Instr.bx(ins),
                                    constants.get(Instr.bx(ins)).formatDebug());
                        case LoadImm ->
                            out.printf("R%d, %d\n", Instr.a(ins), Instr.sbx(ins));
                        case GetGlobal, SetGlobal, TakeGlobal ->
                            out.printf("R%d, G[%d] (%s)\n", Instr.a(ins), Instr.bx(ins),
                                    globals.get(Instr.bx(ins)).name);
                        case Jmp, JmpFalse, JmpTrue, ForPrep, ForLoop ->
                            out.printf("R%d -> %04d\n", Instr.a(ins), (pc + 1) + Instr.sbx(ins));
                        default ->
                            out.printf("R%d, %d, %d\n", Instr.a(ins), Instr.b(ins), Instr.c(ins));
                    }
                }
            }
        }

        // =========================================================================
        // Bytecode Binary Serialization (EXB Format)
        // =========================================================================

        public static final int MAGIC = 0x45584231; // ASCII 'E', 'X', 'B', '1'
        public static final int FORMAT_VERSION = 1;

        public static boolean isBytecodeFile(Path path) {
            if (!Files.isRegularFile(path)) return false;
            try (InputStream is = Files.newInputStream(path);
                 DataInputStream dis = new DataInputStream(new BufferedInputStream(is))) {
                return dis.readInt() == MAGIC;
            } catch (Exception ignored) {
                return false;
            }
        }

        public void save(Path path) throws IOException {
            try (OutputStream os = new BufferedOutputStream(Files.newOutputStream(path))) {
                save(os);
            }
        }

        public void save(OutputStream outStream) throws IOException {
            DataOutputStream headerOut = new DataOutputStream(outStream);
            headerOut.writeInt(MAGIC);
            headerOut.writeInt(FORMAT_VERSION);
            headerOut.flush();

            GZIPOutputStream gzos = new GZIPOutputStream(outStream);
            BufferedOutputStream bos = new BufferedOutputStream(gzos);
            DataOutputStream out = new DataOutputStream(bos);

            // 1. Constants
            out.writeInt(constants.size());
            for (Value val : constants) {
                saveValue(out, val);
            }

            // 2. Globals
            out.writeInt(globals.size());
            for (GlobalVarInfo g : globals) {
                out.writeUTF(g.name != null ? g.name : "");
                out.writeUTF(g.ns != null ? g.ns : "");
                out.writeUTF(g.file != null ? g.file : "");
                out.writeByte(g.type.id());
                out.writeInt(g.customTypeRoutine);
                out.writeBoolean(g.isConstant);
                out.writeBoolean(g.isExported);
                saveValue(out, g.initialValue);
            }

            // 3. Routines
            out.writeInt(routines.size());
            for (RoutineProto r : routines) {
                out.writeUTF(r.name != null ? r.name : "");
                out.writeUTF(r.ns != null ? r.ns : "");
                out.writeUTF(r.file != null ? r.file : "");
                out.writeBoolean(r.isFunction);
                out.writeBoolean(r.isType);
                out.writeBoolean(r.isDefined);
                out.writeBoolean(r.isExported);
                out.writeBoolean(r.isOverride);
                out.writeInt(r.minArity);
                out.writeInt(r.arity);
                out.writeInt(r.maxRegs);

                out.writeInt(r.paramTypes.size());
                for (VarType vt : r.paramTypes) {
                    out.writeByte(vt.id());
                }

                out.writeInt(r.paramCustomTypeRoutine.size());
                for (int ctr : r.paramCustomTypeRoutine) {
                    out.writeInt(ctr);
                }

                out.writeInt(r.paramDefaults.size());
                for (ParamDefault pd : r.paramDefaults) {
                    out.writeBoolean(pd.hasDefault);
                    saveValue(out, pd.literalVal);
                    out.writeUTF(pd.identOrBuiltin != null ? pd.identOrBuiltin : "");
                }

                int codeLen = r.code.size();
                out.writeInt(codeLen);
                for (int i = 0; i < codeLen; i++) {
                    out.writeInt(r.code.get(i));
                }

                int lineLen = r.lines.size();
                out.writeInt(lineLen);
                for (int i = 0; i < lineLen; i++) {
                    out.writeInt(r.lines.get(i));
                }
            }

            out.flush();
            gzos.finish();
        }

        public static Program load(Path path) throws IOException {
            try (InputStream is = new BufferedInputStream(Files.newInputStream(path))) {
                return load(is);
            }
        }

        public static Program load(InputStream inStream) throws IOException {
            DataInputStream headerIn = new DataInputStream(inStream);
            int magic = headerIn.readInt();
            if (magic != MAGIC) {
                throw new IOException("Ungültiges Euphorix-Bytecode-Format (Magic: 0x" + Integer.toHexString(magic) + ")");
            }
            int version = headerIn.readInt();
            if (version != FORMAT_VERSION) {
                throw new IOException("Inkompatible Bytecode-Version: " + version + " (erwartet: " + FORMAT_VERSION + ")");
            }

            GZIPInputStream gzis = new GZIPInputStream(inStream);
            BufferedInputStream bis = new BufferedInputStream(gzis);
            DataInputStream in = new DataInputStream(bis);

            Program prog = new Program();

            // 1. Constants
            int numConstants = in.readInt();
            for (int i = 0; i < numConstants; i++) {
                Value val = loadValue(in);
                if (val != null && val.kind == Value.KIND_SEQ) {
                    val.retain();
                }
                prog.constants.add(val);
            }

            // 2. Globals
            int numGlobals = in.readInt();
            for (int i = 0; i < numGlobals; i++) {
                GlobalVarInfo g = new GlobalVarInfo();
                g.name = in.readUTF();
                g.ns = in.readUTF();
                g.file = in.readUTF();
                g.type = VarType.fromId(in.readByte());
                g.customTypeRoutine = in.readInt();
                g.isConstant = in.readBoolean();
                g.isExported = in.readBoolean();
                g.initialValue = loadValue(in);
                prog.globals.add(g);
            }

            // 3. Routines
            int numRoutines = in.readInt();
            for (int rIdx = 0; rIdx < numRoutines; rIdx++) {
                RoutineProto r = new RoutineProto();
                r.name = in.readUTF();
                r.ns = in.readUTF();
                r.file = in.readUTF();
                r.isFunction = in.readBoolean();
                r.isType = in.readBoolean();
                r.isDefined = in.readBoolean();
                r.isExported = in.readBoolean();
                r.isOverride = in.readBoolean();
                r.minArity = in.readInt();
                r.arity = in.readInt();
                r.maxRegs = in.readInt();

                int ptCount = in.readInt();
                for (int i = 0; i < ptCount; i++) {
                    r.paramTypes.add(VarType.fromId(in.readByte()));
                }

                int ctrCount = in.readInt();
                for (int i = 0; i < ctrCount; i++) {
                    r.paramCustomTypeRoutine.add(in.readInt());
                }

                int pdCount = in.readInt();
                for (int i = 0; i < pdCount; i++) {
                    ParamDefault pd = new ParamDefault();
                    pd.hasDefault = in.readBoolean();
                    pd.literalVal = loadValue(in);
                    if (pd.literalVal != null && pd.literalVal.kind == Value.KIND_SEQ) {
                        pd.literalVal.retain();
                    }
                    pd.identOrBuiltin = in.readUTF();
                    r.paramDefaults.add(pd);
                }

                int codeLen = in.readInt();
                int[] fastC = new int[codeLen];
                for (int i = 0; i < codeLen; i++) {
                    int c = in.readInt();
                    r.code.add(c);
                    fastC[i] = c;
                }
                r.fastCode = fastC;

                int lineLen = in.readInt();
                int[] fastL = new int[lineLen];
                for (int i = 0; i < lineLen; i++) {
                    int l = in.readInt();
                    r.lines.add(l);
                    fastL[i] = l;
                }
                r.fastLines = fastL;

                prog.routines.add(r);
            }

            return prog;
        }

        private static void saveValue(DataOutputStream out, Value v) throws IOException {
            if (v == null || v.kind == Value.KIND_NONE) {
                out.writeByte(Value.KIND_NONE);
            } else if (v.kind == Value.KIND_INT) {
                out.writeByte(Value.KIND_INT);
                out.writeLong(v.intVal);
            } else if (v.kind == Value.KIND_F64) {
                out.writeByte(Value.KIND_F64);
                out.writeDouble(v.floatVal);
            } else if (v.kind == Value.KIND_SEQ) {
                Sequence seq = v.seqVal;
                int len = (seq != null) ? seq.length() : 0;
                boolean isBytes = (seq != null);
                if (seq != null) {
                    for (int i = 0; i < len; i++) {
                        Value el = seq.get(i);
                        if (el.kind != Value.KIND_INT || el.intVal < 0 || el.intVal > 255) {
                            isBytes = false;
                            break;
                        }
                    }
                }
                if (isBytes && seq != null) {
                    out.writeByte(5); // KIND_RAW_BYTES
                    out.writeInt(len);
                    byte[] buf = new byte[len];
                    for (int i = 0; i < len; i++) {
                        buf[i] = (byte) seq.get(i).intVal;
                    }
                    out.write(buf);
                } else {
                    out.writeByte(Value.KIND_SEQ);
                    out.writeInt(len);
                    if (seq != null) {
                        for (int i = 0; i < len; i++) {
                            saveValue(out, seq.get(i));
                        }
                    }
                }
            } else {
                out.writeByte(Value.KIND_NONE);
            }
        }

        private static Value loadValue(DataInputStream in) throws IOException {
            byte kind = in.readByte();
            return switch (kind) {
                case Value.KIND_NONE -> Value.NONE;
                case Value.KIND_INT -> Value.fromInt(in.readLong());
                case Value.KIND_F64 -> Value.fromFloat(in.readDouble());
                case 5 -> { // KIND_RAW_BYTES
                    int len = in.readInt();
                    byte[] buf = in.readNBytes(len);
                    yield Value.fromRawBytes(buf);
                }
                case Value.KIND_SEQ -> {
                    int len = in.readInt();
                    Sequence seq = new Sequence(len);
                    for (int i = 0; i < len; i++) {
                        seq.add(loadValue(in));
                    }
                    yield Value.fromSeq(seq);
                }
                default -> Value.NONE;
            };
        }
    }
}
