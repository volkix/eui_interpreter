package eu;

import java.io.PrintStream;
import java.util.ArrayList;
import java.util.List;

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
        private int[] fastCode = null;
        private int[] fastLines = null;

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
    }
}
