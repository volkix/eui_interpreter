package eu;

import eu.Bytecode.BuiltinId;
import eu.Bytecode.Instr;
import eu.Bytecode.Op;
import eu.Bytecode.Program;
import eu.Bytecode.RoutineProto;

import javax.net.ssl.*;
import java.io.*;
import java.lang.foreign.*;
import java.lang.invoke.MethodHandle;
import java.lang.invoke.MethodHandles;
import java.lang.invoke.MethodType;
import java.net.*;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.channels.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.nio.file.attribute.BasicFileAttributes;
import java.nio.file.attribute.PosixFileAttributes;
import java.nio.file.attribute.PosixFilePermission;
import java.security.KeyFactory;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.SecureRandom;
import java.security.cert.Certificate;
import java.security.cert.CertificateFactory;
import java.security.spec.PKCS8EncodedKeySpec;
import java.sql.*;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Register-based Virtual Machine for Euphorix on JDK 25 (executing OpenEuphoria syntax).
 */
public final class VM {
    public static final int REGISTER_STACK_SIZE = 65536;
    public static final int MAX_CALL_FRAMES = 2048;

    private static final class VmAbortException extends RuntimeException {
        final int exitCode;
        VmAbortException(int exitCode) {
            super(null, null, true, false);
            this.exitCode = exitCode;
        }
    }

    public static final class CallFrame {
        public RoutineProto routine;
        public int[] code;
        public int ip;
        public int baseReg;
        public int callerRetReg;

        public CallFrame(RoutineProto routine, int ip, int baseReg, int callerRetReg) {
            this.routine = routine;
            this.code = (routine != null) ? routine.fastCode() : null;
            this.ip = ip;
            this.baseReg = baseReg;
            this.callerRetReg = callerRetReg;
        }

        public CallFrame copy() {
            return new CallFrame(routine, ip, baseReg, callerRetReg);
        }
    }

    public enum TaskState { READY, SUSPENDED, TERMINATED }

    public static final class TaskInfo {
        public long id;
        public long routineId = -1;
        public Value args = Value.EMPTY_SEQ;
        public Value schedule = Value.fromInt(0);
        public TaskState state = TaskState.SUSPENDED;
        public boolean started = false;
        public final ArrayList<CallFrame> frames = new ArrayList<>();
        public Value[] regs = null;
    }

    private static final class CFuncDef {
        final MemorySegment fnPtr;
        final long[] argTypes;
        final long retType;
        final boolean isCompatXstat;
        MethodHandle cachedHandle;

        CFuncDef(MemorySegment fnPtr, long[] argTypes, long retType, boolean isCompatXstat) {
            this.fnPtr = fnPtr;
            this.argTypes = argTypes;
            this.retType = retType;
            this.isCompatXstat = isCompatXstat;
        }
    }

    private static final class CompiledRegex {
        final String rawPattern;
        final Pattern pattern;
        final int groupCount;

        CompiledRegex(String rawPattern, Pattern pattern) {
            this.rawPattern = rawPattern;
            this.pattern = pattern;
            this.groupCount = pattern.matcher("").groupCount();
        }
    }

    private static final class ManagedSocket {
        final long id;
        final int family;
        final int sockType;
        SocketChannel tcpClient;
        ServerSocketChannel tcpServer;
        DatagramChannel udpChan;
        boolean reuseAddr = false;
        final Map<Integer, Integer> options = new HashMap<>();

        ManagedSocket(long id, int family, int sockType) {
            this.id = id;
            this.family = family;
            this.sockType = sockType;
        }

        SelectableChannel selectableChannel() {
            if (tcpServer != null) return tcpServer;
            if (tcpClient != null) return tcpClient;
            if (udpChan != null) return udpChan;
            return null;
        }

        void closeQuietly() {
            try { if (tcpClient != null) tcpClient.close(); } catch (IOException ignored) {}
            try { if (tcpServer != null) tcpServer.close(); } catch (IOException ignored) {}
            try { if (udpChan != null) udpChan.close(); } catch (IOException ignored) {}
        }
    }

    private static final class HttpServerInstance {
        final ServerSocket serverSocket;
        final SSLContext sslContext;
        final boolean isTls;

        HttpServerInstance(ServerSocket serverSocket, SSLContext sslContext, boolean isTls) {
            this.serverSocket = serverSocket;
            this.sslContext = sslContext;
            this.isTls = isTls;
        }
    }

    private static final class HttpConnInstance {
        final Socket socket;
        final InputStream in;
        final OutputStream out;

        HttpConnInstance(Socket socket, InputStream in, OutputStream out) {
            this.socket = socket;
            this.in = in;
            this.out = out;
        }
    }

    private static final class SqliteInstance {
        final Connection conn;
        volatile long lastInsertId;
        volatile long lastChanges;

        SqliteInstance(Connection conn) {
            this.conn = conn;
        }
    }

    private static final class PgConnInstance {
        Connection jdbcConn;
        Socket wireSocket;
        InputStream wireIn;
        OutputStream wireOut;
        int serverVer = 160000;
        long lastAffectedRows = 0;

        boolean isValid() {
            return jdbcConn != null || wireSocket != null;
        }

        void closeQuietly() {
            if (jdbcConn != null) {
                try { jdbcConn.close(); } catch (SQLException ignored) {}
                jdbcConn = null;
            }
            if (wireSocket != null) {
                try {
                    wireOut.write(new byte[]{'X', 0, 0, 0, 4});
                    wireOut.flush();
                } catch (IOException ignored) {}
                try { wireSocket.close(); } catch (IOException ignored) {}
                wireSocket = null;
            }
        }
    }

    // Native C-FFI Linker & standard C library lookup via JDK 25 Foreign Function & Memory API
    private static final Linker NATIVE_LINKER = Linker.nativeLinker();
    private static final SymbolLookup DEFAULT_LOOKUP = NATIVE_LINKER.defaultLookup();
    private static final MethodHandle MH_CALLOC;
    private static final MethodHandle MH_FREE;
    private static final MethodHandle MH_SETENV;
    private static final MethodHandle MH_UNSETENV;

    static {
        try {
            Class.forName("org.sqlite.JDBC");
        } catch (ClassNotFoundException ignored) {}
        try {
            Class.forName("org.postgresql.Driver");
        } catch (ClassNotFoundException ignored) {}

        MH_CALLOC = NATIVE_LINKER.downcallHandle(
            DEFAULT_LOOKUP.find("calloc").orElseThrow(),
            FunctionDescriptor.of(ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG)
        );
        MH_FREE = NATIVE_LINKER.downcallHandle(
            DEFAULT_LOOKUP.find("free").orElseThrow(),
            FunctionDescriptor.ofVoid(ValueLayout.JAVA_LONG)
        );
        MethodHandle setenv = null;
        MethodHandle unsetenv = null;
        try {
            var se = DEFAULT_LOOKUP.find("setenv");
            if (se.isPresent()) {
                setenv = NATIVE_LINKER.downcallHandle(
                    se.get(),
                    FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.ADDRESS, ValueLayout.ADDRESS, ValueLayout.JAVA_INT)
                );
            }
            var use = DEFAULT_LOOKUP.find("unsetenv");
            if (use.isPresent()) {
                unsetenv = NATIVE_LINKER.downcallHandle(
                    use.get(),
                    FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.ADDRESS)
                );
            }
        } catch (Throwable ignored) {}
        MH_SETENV = setenv;
        MH_UNSETENV = unsetenv;
    }

    private static final int OP_LOAD_K          = 0;
    private static final int OP_LOAD_IMM        = 1;
    private static final int OP_LOAD_NONE       = 2;
    private static final int OP_MOVE            = 3;
    private static final int OP_GET_GLOBAL      = 4;
    private static final int OP_SET_GLOBAL      = 5;
    private static final int OP_TAKE_GLOBAL     = 6;
    private static final int OP_CHECK_TYPE      = 7;
    private static final int OP_ADD             = 8;
    private static final int OP_SUB             = 9;
    private static final int OP_MUL             = 10;
    private static final int OP_DIV             = 11;
    private static final int OP_CONCAT          = 12;
    private static final int OP_EQ              = 13;
    private static final int OP_NEQ             = 14;
    private static final int OP_LT              = 15;
    private static final int OP_LE              = 16;
    private static final int OP_GT              = 17;
    private static final int OP_GE              = 18;
    private static final int OP_AND             = 19;
    private static final int OP_OR              = 20;
    private static final int OP_XOR             = 21;
    private static final int OP_NEG             = 22;
    private static final int OP_NOT             = 23;
    private static final int OP_EQUAL_OBJ       = 24;
    private static final int OP_NEW_SEQ         = 25;
    private static final int OP_LEN             = 26;
    private static final int OP_GET_IDX         = 27;
    private static final int OP_SET_IDX         = 28;
    private static final int OP_GET_SLICE       = 29;
    private static final int OP_SET_SLICE       = 30;
    private static final int OP_JMP             = 31;
    private static final int OP_JMP_FALSE       = 32;
    private static final int OP_JMP_TRUE        = 33;
    private static final int OP_JMP_IF_NOT_NONE = 34;
    private static final int OP_FOR_PREP        = 35;
    private static final int OP_FOR_LOOP        = 36;
    private static final int OP_CALL            = 37;
    private static final int OP_BUILTIN         = 38;
    private static final int OP_PRINT_Q         = 39;
    private static final int OP_RETURN          = 40;
    private static final int OP_HALT            = 41;

    private Program prog;
    private Value[] fastConstants;
    private RoutineProto[] fastRoutines;
    private VarType[] fastGlobalTypes;
    private final String[] errBox = new String[1];

    // Unboxed parallel register bank: zero heap boxing for int48 & f64!
    private byte[]   regKind;
    private long[]   regInt;
    private double[] regF64;
    private Value[]  regSeq;

    private Value[] globals;
    private final CallFrame[] frameStack = new CallFrame[MAX_CALL_FRAMES];
    private int frameDepth = 0;
    private String errorMsg = "";
    private String crashMsg = "";
    private final long startTimeNanos;
    private final Random rng;
    private boolean isForkedChild = false;

    // Shared or per-VM runtime tables
    private final Map<Long, RandomAccessFile> openFiles;
    private final Map<Long, java.nio.channels.FileLock> fileLocks;
    private final AtomicLong nextFileHandle;
    private final Map<Long, List<Integer>> atomCleanups;
    private final List<SymbolLookup> dllLookups;
    private final List<CFuncDef> cRoutines;
    private final List<CompiledRegex> compiledRegexes;
    private volatile String lastRegexError = "";

    private final Map<String, String> envOverrides;
    private final Set<String> envUnset;

    private final Map<Long, ManagedSocket> openSockets;
    private final AtomicLong nextSocketId;
    private volatile int lastSockErrno = 0;

    private final Map<Long, HttpServerInstance> httpServers;
    private final Map<Long, HttpConnInstance> httpConns;
    private final AtomicLong nextHttpId;

    private final Map<Long, SqliteInstance> sqliteDbs;
    private final AtomicLong nextSqliteId;
    private volatile String lastSqliteError = "";

    private final Map<Long, PgConnInstance> pgDbs;
    private final AtomicLong nextPgId;
    private volatile String lastPgError = "";

    private final Map<Long, Thread> workerThreads;
    private final AtomicLong nextWorkerPid;

    // Java 25 Virtual Threads, Async/Await Futures & Channels
    private final Map<Long, Thread> virtualThreads;
    private final AtomicLong nextThreadId;
    private final Map<Long, CompletableFuture<Value>> asyncJobs;
    private final AtomicLong nextJobId;
    private final Map<Long, BlockingQueue<Value>> channels;
    private final Map<Long, AtomicBoolean> channelClosed;
    private final AtomicLong nextChannelId;
    private Value lastReturnValue = Value.NONE;

    private final Map<Long, TaskInfo> tasks = new ConcurrentHashMap<>();
    private final List<Long> taskIdsOrder = new ArrayList<>();
    private long nextTaskId = 1;
    private long currentTaskId = 0;
    private final Set<Long> allocatedPtrs = ConcurrentHashMap.newKeySet();
    private volatile Path currentWorkingDir;

    public Path resolvePath(String pStr) {
        if (pStr == null || pStr.isEmpty()) return currentWorkingDir;
        Path p = Path.of(pStr);
        if (p.isAbsolute()) return p.normalize();
        return currentWorkingDir.resolve(p).normalize();
    }

    public VM() {
        this.regKind = new byte[REGISTER_STACK_SIZE];
        this.regInt = new long[REGISTER_STACK_SIZE];
        this.regF64 = new double[REGISTER_STACK_SIZE];
        this.regSeq = new Value[REGISTER_STACK_SIZE];
        this.globals = new Value[0];
        this.startTimeNanos = System.nanoTime();
        this.rng = new Random(123456789L);

        this.openFiles = new ConcurrentHashMap<>();
        this.fileLocks = new ConcurrentHashMap<>();
        this.nextFileHandle = new AtomicLong(3);
        this.atomCleanups = new ConcurrentHashMap<>();
        this.dllLookups = Collections.synchronizedList(new ArrayList<>());
        this.cRoutines = Collections.synchronizedList(new ArrayList<>());
        this.compiledRegexes = Collections.synchronizedList(new ArrayList<>());

        this.envOverrides = new ConcurrentHashMap<>();
        this.envUnset = ConcurrentHashMap.newKeySet();

        this.openSockets = new ConcurrentHashMap<>();
        this.nextSocketId = new AtomicLong(100);

        this.httpServers = new ConcurrentHashMap<>();
        this.httpConns = new ConcurrentHashMap<>();
        this.nextHttpId = new AtomicLong(1);

        this.sqliteDbs = new ConcurrentHashMap<>();
        this.nextSqliteId = new AtomicLong(1);

        this.pgDbs = new ConcurrentHashMap<>();
        this.nextPgId = new AtomicLong(1);

        this.workerThreads = new ConcurrentHashMap<>();
        this.nextWorkerPid = new AtomicLong(1000);

        this.virtualThreads = new ConcurrentHashMap<>();
        this.nextThreadId = new AtomicLong(1);
        this.asyncJobs = new ConcurrentHashMap<>();
        this.nextJobId = new AtomicLong(1);
        this.channels = new ConcurrentHashMap<>();
        this.channelClosed = new ConcurrentHashMap<>();
        this.nextChannelId = new AtomicLong(1);
        this.currentWorkingDir = Path.of(System.getProperty("user.dir", ".")).toAbsolutePath().normalize();
    }

    private VM(VM parent, int childResultAbsReg) {
        this.prog = parent.prog;
        this.fastConstants = parent.fastConstants;
        this.fastRoutines = parent.fastRoutines;
        this.fastGlobalTypes = parent.fastGlobalTypes;
        this.startTimeNanos = parent.startTimeNanos;
        this.rng = new Random(123456789L ^ System.nanoTime());
        this.isForkedChild = true;
        this.crashMsg = parent.crashMsg;

        // Deep-copy globals & registers so child thread has independent Sequence refCounts
        this.globals = new Value[parent.globals.length];
        for (int i = 0; i < parent.globals.length; i++) {
            Value copy = deepCopyValue(parent.globals[i]);
            copy.retain();
            this.globals[i] = copy;
        }

        this.regKind = new byte[REGISTER_STACK_SIZE];
        this.regInt = new long[REGISTER_STACK_SIZE];
        this.regF64 = new double[REGISTER_STACK_SIZE];
        this.regSeq = new Value[REGISTER_STACK_SIZE];
        int maxActiveReg = childResultAbsReg + 1;
        if (parent.frameDepth > 0) {
            CallFrame top = parent.frameStack[parent.frameDepth - 1];
            maxActiveReg = Math.max(maxActiveReg, top.baseReg + top.routine.maxRegs + 4);
        }
        maxActiveReg = Math.min(maxActiveReg, REGISTER_STACK_SIZE);
        for (int i = 0; i < maxActiveReg; i++) {
            byte k = parent.regKind[i];
            if (k == Value.KIND_INT) {
                this.regKind[i] = Value.KIND_INT;
                this.regInt[i] = parent.regInt[i];
            } else if (k == Value.KIND_F64) {
                this.regKind[i] = Value.KIND_F64;
                this.regF64[i] = parent.regF64[i];
            } else if (k == Value.KIND_SEQ) {
                Value copy = deepCopyValue(parent.regSeq[i]);
                copy.retain();
                this.regKind[i] = Value.KIND_SEQ;
                this.regSeq[i] = copy;
            }
        }
        setRegInt(childResultAbsReg, 0L);

        for (int i = 0; i < parent.frameDepth; i++) {
            CallFrame cf = parent.frameStack[i];
            pushFrame(cf.routine, cf.ip, cf.baseReg, cf.callerRetReg);
        }

        // Share I/O and resource tables with parent
        this.openFiles = parent.openFiles;
        this.fileLocks = parent.fileLocks;
        this.nextFileHandle = parent.nextFileHandle;
        this.atomCleanups = parent.atomCleanups;
        this.dllLookups = parent.dllLookups;
        this.cRoutines = parent.cRoutines;
        this.compiledRegexes = parent.compiledRegexes;
        this.envOverrides = parent.envOverrides;
        this.envUnset = parent.envUnset;
        this.openSockets = parent.openSockets;
        this.nextSocketId = parent.nextSocketId;
        this.httpServers = parent.httpServers;
        this.httpConns = parent.httpConns;
        this.nextHttpId = parent.nextHttpId;
        this.sqliteDbs = parent.sqliteDbs;
        this.nextSqliteId = parent.nextSqliteId;
        this.pgDbs = parent.pgDbs;
        this.nextPgId = parent.nextPgId;
        this.workerThreads = parent.workerThreads;
        this.nextWorkerPid = parent.nextWorkerPid;

        this.virtualThreads = parent.virtualThreads;
        this.nextThreadId = parent.nextThreadId;
        this.asyncJobs = parent.asyncJobs;
        this.nextJobId = parent.nextJobId;
        this.channels = parent.channels;
        this.channelClosed = parent.channelClosed;
        this.nextChannelId = parent.nextChannelId;
        this.currentWorkingDir = parent.currentWorkingDir;
    }

    private VM(VM parent, RoutineProto routine) {
        this(parent, routine, false);
    }

    private VM(VM parent, RoutineProto routine, boolean isolatedGlobals) {
        this.prog = parent.prog;
        this.fastConstants = parent.fastConstants;
        this.fastRoutines = parent.fastRoutines;
        this.fastGlobalTypes = parent.fastGlobalTypes;
        this.startTimeNanos = parent.startTimeNanos;
        this.rng = parent.rng;
        this.isForkedChild = isolatedGlobals;
        this.crashMsg = parent.crashMsg;

        if (isolatedGlobals) {
            this.globals = new Value[parent.globals.length];
            for (int i = 0; i < parent.globals.length; i++) {
                Value copy = deepCopyValue(parent.globals[i]);
                copy.retain();
                this.globals[i] = copy;
            }
        } else {
            // Share globals directly with parent so GUI callbacks can read/write global variables!
            this.globals = parent.globals;
        }

        this.regKind = new byte[REGISTER_STACK_SIZE];
        this.regInt = new long[REGISTER_STACK_SIZE];
        this.regF64 = new double[REGISTER_STACK_SIZE];
        this.regSeq = new Value[REGISTER_STACK_SIZE];

        // Share I/O and resource tables with parent
        this.openFiles = parent.openFiles;
        this.fileLocks = parent.fileLocks;
        this.nextFileHandle = parent.nextFileHandle;
        this.atomCleanups = parent.atomCleanups;
        this.dllLookups = parent.dllLookups;
        this.cRoutines = parent.cRoutines;
        this.compiledRegexes = parent.compiledRegexes;
        this.envOverrides = parent.envOverrides;
        this.envUnset = parent.envUnset;
        this.openSockets = parent.openSockets;
        this.nextSocketId = parent.nextSocketId;
        this.httpServers = parent.httpServers;
        this.httpConns = parent.httpConns;
        this.nextHttpId = parent.nextHttpId;
        this.sqliteDbs = parent.sqliteDbs;
        this.nextSqliteId = parent.nextSqliteId;
        this.pgDbs = parent.pgDbs;
        this.nextPgId = parent.nextPgId;
        this.workerThreads = parent.workerThreads;
        this.nextWorkerPid = parent.nextWorkerPid;

        this.virtualThreads = parent.virtualThreads;
        this.nextThreadId = parent.nextThreadId;
        this.asyncJobs = parent.asyncJobs;
        this.nextJobId = parent.nextJobId;
        this.channels = parent.channels;
        this.channelClosed = parent.channelClosed;
        this.nextChannelId = parent.nextChannelId;
        this.currentWorkingDir = parent.currentWorkingDir;
    }

    public synchronized Value invokeRoutine(int rid, List<Value> args) {
        if (rid < 1 || rid >= prog.routines.size()) return Value.fromInt(0);
        RoutineProto target = prog.routines.get(rid);
        VM cbVm = new VM(this, target);
        int base = 0;
        int passCount = Math.min(target.arity, args != null ? args.size() : 0);
        for (int i = 0; i < passCount; i++) {
            cbVm.setReg(base + i, args.get(i));
        }
        for (int i = passCount; i < target.arity; i++) {
            cbVm.setReg(base + i, Value.NONE);
        }
        cbVm.frameDepth = 0;
        cbVm.pushFrame(target, 0, base, 0);
        try {
            cbVm.runLoop();
            Value ret = cbVm.lastReturnValue;
            if (ret == null || ret.isNone()) ret = cbVm.getReg(0);
            return ret != null && !ret.isNone() ? ret : Value.fromInt(0);
        } catch (VmAbortException ab) {
            System.exit(ab.exitCode);
            return Value.fromInt(ab.exitCode);
        } catch (Throwable t) {
            return Value.fromInt(0);
        }
    }

    public Value runRoutineDirectly(int rid, List<Value> args) {
        if (rid < 0 || rid >= prog.routines.size()) return Value.fromInt(0);
        RoutineProto target = prog.routines.get(rid);
        VM threadVm = new VM(this, target, true);
        int base = 0;
        int passCount = Math.min(target.arity, args != null ? args.size() : 0);
        for (int i = 0; i < passCount; i++) {
            threadVm.setReg(base + i, deepCopyValue(args.get(i)));
        }
        for (int i = passCount; i < target.arity; i++) {
            threadVm.setReg(base + i, Value.NONE);
        }
        threadVm.frameDepth = 0;
        threadVm.pushFrame(target, 0, base, 0);
        try {
            threadVm.runLoop();
            Value ret = threadVm.lastReturnValue;
            if (ret == null || ret.isNone()) ret = threadVm.getReg(0);
            return (ret != null && !ret.isNone()) ? ret : Value.fromInt(0);
        } catch (VmAbortException ab) {
            return Value.fromInt(ab.exitCode);
        } catch (Throwable t) {
            return Value.fromInt(0);
        }
    }

    private static Value deepCopyValue(Value v) {
        if (v == null || !v.isSeq()) {
            return v == null ? Value.NONE : v;
        }
        Sequence src = v.asSeq();
        int len = src.size();
        Sequence dst = new Sequence(len);
        dst.regexId = src.regexId;
        if (src.cleanupRids != null) {
            dst.cleanupRids = new ArrayList<>(src.cleanupRids);
        }
        for (int i = 0; i < len; i++) {
            dst.setElement(i, deepCopyValue(src.get(i)));
        }
        return Value.fromSeq(dst);
    }

    public String error() {
        return errorMsg;
    }

    private CallFrame pushFrame(RoutineProto routine, int ip, int baseReg, int callerRetReg) {
        CallFrame cf = frameStack[frameDepth];
        if (cf == null) {
            cf = new CallFrame(routine, ip, baseReg, callerRetReg);
            frameStack[frameDepth] = cf;
        } else {
            cf.routine = routine;
            cf.code = routine.fastCode();
            cf.ip = ip;
            cf.baseReg = baseReg;
            cf.callerRetReg = callerRetReg;
        }
        frameDepth++;
        return cf;
    }

    private Value getReg(int absIdx) {
        return switch (regKind[absIdx]) {
            case Value.KIND_INT -> Value.fromInt(regInt[absIdx]);
            case Value.KIND_F64 -> Value.fromF64(regF64[absIdx]);
            case Value.KIND_SEQ -> regSeq[absIdx];
            default -> Value.NONE;
        };
    }

    private void setRegInt(int absIdx, long v) {
        if (regKind[absIdx] == Value.KIND_SEQ) {
            regSeq[absIdx].release();
            regSeq[absIdx] = null;
        }
        if (((v << 16) >> 16) == v) {
            regKind[absIdx] = Value.KIND_INT;
            regInt[absIdx] = v;
        } else {
            regKind[absIdx] = Value.KIND_F64;
            regF64[absIdx] = (double) v;
        }
    }

    private void setRegF64(int absIdx, double d) {
        if (regKind[absIdx] == Value.KIND_SEQ) {
            regSeq[absIdx].release();
            regSeq[absIdx] = null;
        }
        regKind[absIdx] = Value.KIND_F64;
        regF64[absIdx] = d;
    }

    private void setReg(int absIdx, Value newVal) {
        if (newVal == null) {
            if (regKind[absIdx] == Value.KIND_SEQ) {
                regSeq[absIdx].release();
                regSeq[absIdx] = null;
            }
            regKind[absIdx] = Value.KIND_NONE;
            return;
        }
        byte nk = newVal.kind;
        if (nk == Value.KIND_INT) {
            if (regKind[absIdx] == Value.KIND_SEQ) {
                regSeq[absIdx].release();
                regSeq[absIdx] = null;
            }
            regKind[absIdx] = Value.KIND_INT;
            regInt[absIdx] = newVal.intVal;
        } else if (nk == Value.KIND_F64) {
            if (regKind[absIdx] == Value.KIND_SEQ) {
                regSeq[absIdx].release();
                regSeq[absIdx] = null;
            }
            regKind[absIdx] = Value.KIND_F64;
            regF64[absIdx] = newVal.floatVal;
        } else if (nk == Value.KIND_SEQ) {
            newVal.retain();
            if (regKind[absIdx] == Value.KIND_SEQ) {
                regSeq[absIdx].release();
            }
            regKind[absIdx] = Value.KIND_SEQ;
            regSeq[absIdx] = newVal;
        } else {
            if (regKind[absIdx] == Value.KIND_SEQ) {
                regSeq[absIdx].release();
                regSeq[absIdx] = null;
            }
            regKind[absIdx] = Value.KIND_NONE;
        }
    }

    private void setGlobal(int gidx, Value newVal) {
        if (newVal == null) newVal = Value.NONE;
        newVal.retain();
        Value old = globals[gidx];
        if (old != null) {
            old.release();
        }
        globals[gidx] = newVal;
    }

    private Sequence ensureUniqueReg(int absIdx) {
        Value v = regSeq[absIdx];
        Sequence s = v.seqVal;
        if (s.refCount <= 1) {
            return s;
        }
        Sequence cloned = new Sequence(s);
        setReg(absIdx, Value.fromSeq(cloned));
        return cloned;
    }

    private void runtimeError(CallFrame frame, String msg) {
        int line = 0;
        if (frame != null && frame.routine != null) {
            int idx = frame.ip - 1;
            if (idx >= 0 && idx < frame.routine.lines.size()) {
                line = frame.routine.lines.get(idx);
            }
        }
        String rname = (frame != null && frame.routine != null) ? frame.routine.name : "<vm>";
        if (crashMsg != null && !crashMsg.isEmpty()) {
            errorMsg = String.format("[Laufzeitfehler in %s, Zeile %d] %s (%s)", rname, line, crashMsg, msg);
        } else {
            errorMsg = String.format("[Laufzeitfehler in %s, Zeile %d] %s", rname, line, msg);
        }
    }

    public boolean switchToNextTask() {
        if (taskIdsOrder.isEmpty()) return false;

        int curPos = 0;
        for (int i = 0; i < taskIdsOrder.size(); i++) {
            if (taskIdsOrder.get(i) == currentTaskId) {
                curPos = i;
                break;
            }
        }

        long nextTid = -1;
        int n = taskIdsOrder.size();
        for (int offset = 1; offset <= n; offset++) {
            int idx = (curPos + offset) % n;
            long tid = taskIdsOrder.get(idx);
            TaskInfo t = tasks.get(tid);
            if (t != null && t.state == TaskState.READY) {
                nextTid = tid;
                break;
            }
        }

        if (nextTid == -1) {
            return false;
        }
        if (nextTid == currentTaskId) {
            return true;
        }

        // Save current task state if it is still alive
        TaskInfo curTask = tasks.get(currentTaskId);
        if (curTask != null && curTask.state != TaskState.TERMINATED && frameDepth > 0) {
            curTask.frames.clear();
            for (int i = 0; i < frameDepth; i++) {
                curTask.frames.add(frameStack[i].copy());
            }
            if (curTask.regs != null) {
                for (int i = 0; i < REGISTER_STACK_SIZE; i++) {
                    if (curTask.regs[i] != null) curTask.regs[i].release();
                }
            }
            curTask.regs = new Value[REGISTER_STACK_SIZE];
            for (int i = 0; i < REGISTER_STACK_SIZE; i++) {
                Value rv = getReg(i);
                curTask.regs[i] = rv;
                rv.retain();
            }
        }

        currentTaskId = nextTid;
        TaskInfo nextTask = tasks.get(nextTid);
        if (!nextTask.started) {
            nextTask.started = true;
            for (int i = 0; i < REGISTER_STACK_SIZE; i++) {
                setReg(i, Value.NONE);
            }
            JavaInterop.setActiveVm(this);
            frameDepth = 0;
            RoutineProto target = prog.routines.get((int) nextTask.routineId);
            if (nextTask.args.isSeq()) {
                Sequence s = nextTask.args.asSeq();
                for (int i = 0; i < s.size() && i < target.arity; i++) {
                    setReg(i, s.get(i));
                }
            }
            pushFrame(target, 0, 0, 0);
        } else {
            JavaInterop.setActiveVm(this);
            frameDepth = 0;
            for (CallFrame cf : nextTask.frames) {
                pushFrame(cf.routine, cf.ip, cf.baseReg, cf.callerRetReg);
            }
            for (int i = 0; i < REGISTER_STACK_SIZE; i++) {
                setReg(i, nextTask.regs[i]);
            }
        }

        return true;
    }

    public boolean execute(Program prog) {
        this.prog = prog;
        this.errorMsg = "";
        this.fastConstants = prog.constants.toArray(new Value[0]);
        this.fastRoutines = prog.routines.toArray(new RoutineProto[0]);
        int numGlobals = prog.globals.size();
        this.fastGlobalTypes = new VarType[numGlobals];
        for (int i = 0; i < numGlobals; i++) {
            this.fastGlobalTypes[i] = prog.globals.get(i).type;
        }

        tasks.clear();
        taskIdsOrder.clear();
        nextTaskId = 1;
        currentTaskId = 0;

        TaskInfo mainTask = new TaskInfo();
        mainTask.id = 0;
        mainTask.state = TaskState.READY;
        mainTask.started = true;
        tasks.put(0L, mainTask);
        taskIdsOrder.add(0L);

        if (this.globals.length < numGlobals) {
            Value[] nextGlobals = new Value[numGlobals];
            Arrays.fill(nextGlobals, Value.NONE);
            System.arraycopy(this.globals, 0, nextGlobals, 0, this.globals.length);
            this.globals = nextGlobals;
        }
        for (int i = 0; i < numGlobals; i++) {
            setGlobal(i, prog.globals.get(i).initialValue);
        }

        JavaInterop.setActiveVm(this);
        frameDepth = 0;
        RoutineProto mainProto = prog.routines.get(0);
        pushFrame(mainProto, 0, 0, 0);

        try {
            return runLoop();
        } catch (VmAbortException ab) {
            System.exit(ab.exitCode);
            return true;
        }
    }

    private void resumeExecution() {
        try {
            if (!runLoop() && !errorMsg.isEmpty()) {
                System.err.println(errorMsg);
            }
        } catch (VmAbortException ignored) {
            // Normal exit for forked background worker thread via abort(code)
        } catch (Throwable t) {
            if (!errorMsg.isEmpty()) {
                System.err.println(errorMsg);
            } else {
                System.err.println("Worker thread error: " + t.getMessage());
            }
        }
    }

    private void setRegBool(int absIdx, boolean b) {
        if (regKind[absIdx] == Value.KIND_SEQ) {
            regSeq[absIdx].release();
            regSeq[absIdx] = null;
        }
        regKind[absIdx] = Value.KIND_INT;
        regInt[absIdx] = b ? 1L : 0L;
    }

    private void copyReg(int dst, int src) {
        final byte sk = regKind[src];
        if (sk == Value.KIND_INT) {
            if (regKind[dst] == Value.KIND_SEQ) { regSeq[dst].release(); regSeq[dst] = null; }
            regKind[dst] = Value.KIND_INT;
            regInt[dst] = regInt[src];
        } else if (sk == Value.KIND_F64) {
            if (regKind[dst] == Value.KIND_SEQ) { regSeq[dst].release(); regSeq[dst] = null; }
            regKind[dst] = Value.KIND_F64;
            regF64[dst] = regF64[src];
        } else if (sk == Value.KIND_SEQ) {
            final Value sv = regSeq[src];
            sv.seqVal.refCount++;
            if (regKind[dst] == Value.KIND_SEQ) { regSeq[dst].release(); }
            regKind[dst] = Value.KIND_SEQ;
            regSeq[dst] = sv;
        } else {
            if (regKind[dst] == Value.KIND_SEQ) { regSeq[dst].release(); regSeq[dst] = null; }
            regKind[dst] = Value.KIND_NONE;
        }
    }

    private boolean execBinopSlow(int op, int ra, int rb, int rc, CallFrame frame, int ip) {
        final byte kb = regKind[rb], kc = regKind[rc];
        if ((kb == Value.KIND_INT || kb == Value.KIND_F64) && (kc == Value.KIND_INT || kc == Value.KIND_F64)) {
            final double da = (kb == Value.KIND_INT) ? (double) regInt[rb] : regF64[rb];
            final double db = (kc == Value.KIND_INT) ? (double) regInt[rc] : regF64[rc];
            switch (op) {
                case OP_ADD -> { setRegF64(ra, da + db); return true; }
                case OP_SUB -> { setRegF64(ra, da - db); return true; }
                case OP_MUL -> { setRegF64(ra, da * db); return true; }
                case OP_DIV -> {
                    if (db == 0.0) { frame.ip = ip; runtimeError(frame, "Division durch 0 (attempt to divide by 0)"); return false; }
                    setRegF64(ra, da / db); return true;
                }
                case OP_EQ  -> { setRegBool(ra, da == db); return true; }
                case OP_NEQ -> { setRegBool(ra, da != db); return true; }
                case OP_LT  -> { setRegBool(ra, da <  db); return true; }
                case OP_LE  -> { setRegBool(ra, da <= db); return true; }
                case OP_GT  -> { setRegBool(ra, da >  db); return true; }
                case OP_GE  -> { setRegBool(ra, da >= db); return true; }
                case OP_AND -> { setRegBool(ra, da != 0.0 && db != 0.0); return true; }
                case OP_OR  -> { setRegBool(ra, da != 0.0 || db != 0.0); return true; }
                case OP_XOR -> { setRegBool(ra, (da != 0.0) ^ (db != 0.0)); return true; }
            }
        }
        Value.BinOp bop = switch (op) {
            case OP_ADD -> Value.BinOp.Add;
            case OP_SUB -> Value.BinOp.Sub;
            case OP_MUL -> Value.BinOp.Mul;
            case OP_DIV -> Value.BinOp.Div;
            case OP_EQ  -> Value.BinOp.Eq;
            case OP_NEQ -> Value.BinOp.Neq;
            case OP_LT  -> Value.BinOp.Lt;
            case OP_LE  -> Value.BinOp.Le;
            case OP_GT  -> Value.BinOp.Gt;
            case OP_GE  -> Value.BinOp.Ge;
            case OP_AND -> Value.BinOp.And;
            case OP_OR  -> Value.BinOp.Or;
            case OP_XOR -> Value.BinOp.Xor;
            default     -> Value.BinOp.Add;
        };
        errBox[0] = null;
        Value res = Value.evalBinop(bop, getReg(rb), getReg(rc), errBox);
        if (errBox[0] != null) {
            frame.ip = ip;
            runtimeError(frame, errBox[0]);
            return false;
        }
        setReg(ra, res);
        return true;
    }

    private boolean execUnarySlow(int op, int ra, int rb, CallFrame frame, int ip) {
        final byte kb = regKind[rb];
        if (kb == Value.KIND_F64) {
            if (op == OP_NEG) setRegF64(ra, -regF64[rb]);
            else setRegBool(ra, regF64[rb] == 0.0);
            return true;
        }
        errBox[0] = null;
        Value res = Value.evalUnary(op == OP_NEG ? Value.UnaryOp.Neg : Value.UnaryOp.Not, getReg(rb), errBox);
        if (errBox[0] != null) {
            frame.ip = ip;
            runtimeError(frame, errBox[0]);
            return false;
        }
        setReg(ra, res);
        return true;
    }

    private boolean execGetSlice(int ra, int rb, int idxReg, CallFrame frame, int ip) {
        if (regKind[rb] != Value.KIND_SEQ) {
            frame.ip = ip;
            runtimeError(frame, "Slicing 's[a..b]' auf ein Atom angewendet");
            return false;
        }
        final Value startVal = getReg(idxReg);
        final Value endVal = getReg(idxReg + 1);
        if (!startVal.isAtom() || !endVal.isAtom()) {
            frame.ip = ip;
            runtimeError(frame, "Slice-Grenzen müssen Atome sein");
            return false;
        }
        final Sequence s = regSeq[rb].seqVal;
        final long a = startVal.toIntCoerce();
        final long b = endVal.toIntCoerce();
        final int len = s.len;
        if (a == b + 1 && a >= 1 && a <= len + 1) {
            setReg(ra, Value.emptySeq());
            return true;
        }
        if (a < 1 || b < a || b > len) {
            frame.ip = ip;
            runtimeError(frame, String.format("Slice [%d..%d] außerhalb des Bereichs 1..%d", a, b, len));
            return false;
        }
        final int sliceLen = (int) (b - a + 1);
        final Sequence out = new Sequence(sliceLen);
        final int start0 = (int) (a - 1);
        for (int i = 0; i < sliceLen; i++) {
            out.add(s.data[start0 + i]);
        }
        setReg(ra, Value.fromSeq(out));
        return true;
    }

    private boolean execSetSlice(int targetReg, int idxReg, int rc, CallFrame frame, int ip) {
        if (regKind[targetReg] != Value.KIND_SEQ) {
            frame.ip = ip;
            runtimeError(frame, "Slice-Zuweisung 's[a..b] = x' auf ein Atom angewendet");
            return false;
        }
        final Value startVal = getReg(idxReg);
        final Value endVal = getReg(idxReg + 1);
        final Value rhs = getReg(rc);
        final Sequence s = ensureUniqueReg(targetReg);
        final long a = startVal.toIntCoerce();
        final long b = endVal.toIntCoerce();
        final int len = s.len;
        if (a < 1 || b < a - 1 || b > len) {
            frame.ip = ip;
            runtimeError(frame, "Slice-Grenzen bei Zuweisung außerhalb des gültigen Bereichs");
            return false;
        }
        final int sliceLen = (int) (b - a + 1);
        if (rhs.isAtom()) {
            for (int i = 0; i < sliceLen; i++) {
                s.set((int) (a - 1) + i, rhs);
            }
        } else if (rhs.isSeq()) {
            s.replaceRange((int) (a - 1), (int) b, rhs.seqVal);
        }
        return true;
    }

    private boolean execCheckTypeBuiltin(int ra, int bx, CallFrame frame, int ip) {
        final byte k = regKind[ra];
        boolean okType;
        if (bx == 0) {
            okType = (k != Value.KIND_NONE);
        } else if (bx == 1) {
            okType = (k == Value.KIND_INT || k == Value.KIND_F64);
        } else if (bx == 2) {
            if (k == Value.KIND_INT) okType = true;
            else if (k == Value.KIND_F64) {
                double d = regF64[ra];
                okType = (Math.floor(d) == d && d >= (double) Value.INT48_MIN && d <= (double) Value.INT48_MAX);
            } else okType = false;
        } else {
            okType = (k == Value.KIND_SEQ);
        }
        if (!okType) {
            frame.ip = ip;
            VarType vt = VarType.fromCode(bx);
            runtimeError(frame, "Typfehler (type_check failure): Variable erwartet '" + vt.TypeName() + "'");
            return false;
        }
        return true;
    }

    private boolean execReturnToEmpty(byte rk, long ri, double rf, Value rs) {
        Value retVal = (rk == Value.KIND_INT) ? Value.fromInt(ri)
                     : (rk == Value.KIND_F64) ? Value.fromF64(rf)
                     : (rk == Value.KIND_SEQ) ? rs : Value.NONE;
        this.lastReturnValue = deepCopyValue(retVal);
        setReg(0, retVal);
        if (rk == Value.KIND_SEQ && rs != null) rs.release();
        if (currentTaskId != 0) {
            TaskInfo cur = tasks.get(currentTaskId);
            if (cur != null) {
                cur.state = TaskState.TERMINATED;
                cur.frames.clear();
                if (cur.regs != null) {
                    for (int i = 0; i < REGISTER_STACK_SIZE; i++) {
                        if (cur.regs[i] != null) cur.regs[i].release();
                    }
                    cur.regs = null;
                }
                if (cur.args != null) cur.args.release();
            }
            return switchToNextTask();
        }
        return false;
    }

    private boolean runLoop() {
        final byte[] rKind = this.regKind;
        final long[] rInt = this.regInt;
        final double[] rF64 = this.regF64;
        final Value[] rSeq = this.regSeq;
        final Value[] fastK = this.fastConstants;
        final RoutineProto[] fastR = this.fastRoutines;
        final VarType[] fastGT = this.fastGlobalTypes;
        final Value[] globs = this.globals;
        final CallFrame[] fStack = this.frameStack;

        CallFrame frame = fStack[frameDepth - 1];
        int base = frame.baseReg;
        int[] code = frame.code;
        int ip = frame.ip;

        for (;;) {
            final int ins = code[ip++];
            switch (ins & 0xFF) {
                case OP_LOAD_K -> {
                    setReg(base + ((ins >>> 8) & 0xFF), fastK[(ins >>> 16) & 0xFFFF]);
                }
                case OP_LOAD_IMM -> {
                    final int dst = base + ((ins >>> 8) & 0xFF);
                    if (rKind[dst] == Value.KIND_SEQ) { rSeq[dst].release(); rSeq[dst] = null; }
                    rKind[dst] = Value.KIND_INT;
                    rInt[dst] = (short) (ins >>> 16);
                }
                case OP_LOAD_NONE -> {
                    final int dst = base + ((ins >>> 8) & 0xFF);
                    if (rKind[dst] == Value.KIND_SEQ) { rSeq[dst].release(); rSeq[dst] = null; }
                    rKind[dst] = Value.KIND_NONE;
                }
                case OP_MOVE -> {
                    copyReg(base + ((ins >>> 8) & 0xFF), base + ((ins >>> 16) & 0xFF));
                }
                case OP_GET_GLOBAL -> {
                    final int gidx = (ins >>> 16) & 0xFFFF;
                    final Value v = globs[gidx];
                    if (v.kind == Value.KIND_NONE) {
                        frame.ip = ip;
                        runtimeError(frame, "Globale Variable '" + prog.globals.get(gidx).name + "' hat noch keinen Wert");
                        return false;
                    }
                    setReg(base + ((ins >>> 8) & 0xFF), v);
                }
                case OP_SET_GLOBAL -> {
                    final int gidx = (ins >>> 16) & 0xFFFF;
                    final Value val = getReg(base + ((ins >>> 8) & 0xFF));
                    final VarType vt = fastGT[gidx];
                    if (!val.checkVarType(vt)) {
                        frame.ip = ip;
                        runtimeError(frame, "Typfehler (type_check failure): Globale Variable '" +
                            prog.globals.get(gidx).name + "' erwartet '" + vt.TypeName() + "'");
                        return false;
                    }
                    setGlobal(gidx, val);
                }
                case OP_TAKE_GLOBAL -> {
                    final int gidx = (ins >>> 16) & 0xFFFF;
                    final Value v = globs[gidx];
                    final int dst = base + ((ins >>> 8) & 0xFF);
                    if (rKind[dst] == Value.KIND_SEQ) { rSeq[dst].release(); rSeq[dst] = null; }
                    final byte vk = v.kind;
                    rKind[dst] = vk;
                    if (vk == Value.KIND_INT) rInt[dst] = v.intVal;
                    else if (vk == Value.KIND_F64) rF64[dst] = v.floatVal;
                    else if (vk == Value.KIND_SEQ) rSeq[dst] = v;
                    globs[gidx] = Value.NONE;
                }
                case OP_CHECK_TYPE -> {
                    final int ra = base + ((ins >>> 8) & 0xFF);
                    final int bx = (ins >>> 16) & 0xFFFF;
                    if (bx < 4) {
                        if (!execCheckTypeBuiltin(ra, bx, frame, ip)) return false;
                    } else {
                        final int customRid = bx - 4;
                        if (customRid > 0 && customRid < fastR.length) {
                            final RoutineProto tr = fastR[customRid];
                            final int newBase = base + frame.routine.maxRegs + 2;
                            copyReg(newBase, ra);
                            frame.ip = ip;
                            frame = pushFrame(tr, 0, newBase, newBase - 1);
                            base = newBase;
                            code = frame.code;
                            ip = 0;
                        }
                    }
                }
                case OP_ADD -> {
                    final int ra = base + ((ins >>> 8) & 0xFF);
                    final int rb = base + ((ins >>> 16) & 0xFF);
                    final int rc = base + ((ins >>> 24) & 0xFF);
                    if (rKind[rb] == Value.KIND_INT && rKind[rc] == Value.KIND_INT) {
                        final long sum = rInt[rb] + rInt[rc];
                        if (((sum << 16) >> 16) == sum) {
                            if (rKind[ra] == Value.KIND_SEQ) { rSeq[ra].release(); rSeq[ra] = null; }
                            rKind[ra] = Value.KIND_INT;
                            rInt[ra] = sum;
                        } else {
                            if (rKind[ra] == Value.KIND_SEQ) { rSeq[ra].release(); rSeq[ra] = null; }
                            rKind[ra] = Value.KIND_F64;
                            rF64[ra] = (double) sum;
                        }
                    } else if (!execBinopSlow(OP_ADD, ra, rb, rc, frame, ip)) {
                        return false;
                    }
                }
                case OP_SUB -> {
                    final int ra = base + ((ins >>> 8) & 0xFF);
                    final int rb = base + ((ins >>> 16) & 0xFF);
                    final int rc = base + ((ins >>> 24) & 0xFF);
                    if (rKind[rb] == Value.KIND_INT && rKind[rc] == Value.KIND_INT) {
                        final long diff = rInt[rb] - rInt[rc];
                        if (((diff << 16) >> 16) == diff) {
                            if (rKind[ra] == Value.KIND_SEQ) { rSeq[ra].release(); rSeq[ra] = null; }
                            rKind[ra] = Value.KIND_INT;
                            rInt[ra] = diff;
                        } else {
                            if (rKind[ra] == Value.KIND_SEQ) { rSeq[ra].release(); rSeq[ra] = null; }
                            rKind[ra] = Value.KIND_F64;
                            rF64[ra] = (double) diff;
                        }
                    } else if (!execBinopSlow(OP_SUB, ra, rb, rc, frame, ip)) {
                        return false;
                    }
                }
                case OP_MUL -> {
                    final int ra = base + ((ins >>> 8) & 0xFF);
                    final int rb = base + ((ins >>> 16) & 0xFF);
                    final int rc = base + ((ins >>> 24) & 0xFF);
                    if (rKind[rb] == Value.KIND_INT && rKind[rc] == Value.KIND_INT) {
                        final long a = rInt[rb], b = rInt[rc];
                        final long lo = a * b;
                        if (Math.multiplyHigh(a, b) == (lo >> 63) && ((lo << 16) >> 16) == lo) {
                            if (rKind[ra] == Value.KIND_SEQ) { rSeq[ra].release(); rSeq[ra] = null; }
                            rKind[ra] = Value.KIND_INT;
                            rInt[ra] = lo;
                        } else {
                            setRegF64(ra, (double) a * (double) b);
                        }
                    } else if (!execBinopSlow(OP_MUL, ra, rb, rc, frame, ip)) {
                        return false;
                    }
                }
                case OP_DIV -> {
                    final int ra = base + ((ins >>> 8) & 0xFF);
                    final int rb = base + ((ins >>> 16) & 0xFF);
                    final int rc = base + ((ins >>> 24) & 0xFF);
                    if (rKind[rb] == Value.KIND_INT && rKind[rc] == Value.KIND_INT) {
                        final long a = rInt[rb], b = rInt[rc];
                        if (b == 0L) { frame.ip = ip; runtimeError(frame, "Division durch 0 (attempt to divide by 0)"); return false; }
                        if (a % b == 0L) setRegInt(ra, a / b);
                        else setRegF64(ra, (double) a / (double) b);
                    } else if (!execBinopSlow(OP_DIV, ra, rb, rc, frame, ip)) {
                        return false;
                    }
                }
                case OP_CONCAT -> {
                    setReg(base + ((ins >>> 8) & 0xFF),
                        Value.evalConcat(getReg(base + ((ins >>> 16) & 0xFF)), getReg(base + ((ins >>> 24) & 0xFF))));
                }
                case OP_EQ -> {
                    final int ra = base + ((ins >>> 8) & 0xFF);
                    final int rb = base + ((ins >>> 16) & 0xFF);
                    final int rc = base + ((ins >>> 24) & 0xFF);
                    if (rKind[rb] == Value.KIND_INT && rKind[rc] == Value.KIND_INT) setRegBool(ra, rInt[rb] == rInt[rc]);
                    else if (!execBinopSlow(OP_EQ, ra, rb, rc, frame, ip)) return false;
                }
                case OP_NEQ -> {
                    final int ra = base + ((ins >>> 8) & 0xFF);
                    final int rb = base + ((ins >>> 16) & 0xFF);
                    final int rc = base + ((ins >>> 24) & 0xFF);
                    if (rKind[rb] == Value.KIND_INT && rKind[rc] == Value.KIND_INT) setRegBool(ra, rInt[rb] != rInt[rc]);
                    else if (!execBinopSlow(OP_NEQ, ra, rb, rc, frame, ip)) return false;
                }
                case OP_LT -> {
                    final int ra = base + ((ins >>> 8) & 0xFF);
                    final int rb = base + ((ins >>> 16) & 0xFF);
                    final int rc = base + ((ins >>> 24) & 0xFF);
                    if (rKind[rb] == Value.KIND_INT && rKind[rc] == Value.KIND_INT) setRegBool(ra, rInt[rb] < rInt[rc]);
                    else if (!execBinopSlow(OP_LT, ra, rb, rc, frame, ip)) return false;
                }
                case OP_LE -> {
                    final int ra = base + ((ins >>> 8) & 0xFF);
                    final int rb = base + ((ins >>> 16) & 0xFF);
                    final int rc = base + ((ins >>> 24) & 0xFF);
                    if (rKind[rb] == Value.KIND_INT && rKind[rc] == Value.KIND_INT) setRegBool(ra, rInt[rb] <= rInt[rc]);
                    else if (!execBinopSlow(OP_LE, ra, rb, rc, frame, ip)) return false;
                }
                case OP_GT -> {
                    final int ra = base + ((ins >>> 8) & 0xFF);
                    final int rb = base + ((ins >>> 16) & 0xFF);
                    final int rc = base + ((ins >>> 24) & 0xFF);
                    if (rKind[rb] == Value.KIND_INT && rKind[rc] == Value.KIND_INT) setRegBool(ra, rInt[rb] > rInt[rc]);
                    else if (!execBinopSlow(OP_GT, ra, rb, rc, frame, ip)) return false;
                }
                case OP_GE -> {
                    final int ra = base + ((ins >>> 8) & 0xFF);
                    final int rb = base + ((ins >>> 16) & 0xFF);
                    final int rc = base + ((ins >>> 24) & 0xFF);
                    if (rKind[rb] == Value.KIND_INT && rKind[rc] == Value.KIND_INT) setRegBool(ra, rInt[rb] >= rInt[rc]);
                    else if (!execBinopSlow(OP_GE, ra, rb, rc, frame, ip)) return false;
                }
                case OP_AND, OP_OR, OP_XOR -> {
                    final int ra = base + ((ins >>> 8) & 0xFF);
                    final int rb = base + ((ins >>> 16) & 0xFF);
                    final int rc = base + ((ins >>> 24) & 0xFF);
                    if (!execBinopSlow(ins & 0xFF, ra, rb, rc, frame, ip)) return false;
                }
                case OP_NEG -> {
                    final int ra = base + ((ins >>> 8) & 0xFF);
                    final int rb = base + ((ins >>> 16) & 0xFF);
                    if (rKind[rb] == Value.KIND_INT) setRegInt(ra, -rInt[rb]);
                    else if (!execUnarySlow(OP_NEG, ra, rb, frame, ip)) return false;
                }
                case OP_NOT -> {
                    final int ra = base + ((ins >>> 8) & 0xFF);
                    final int rb = base + ((ins >>> 16) & 0xFF);
                    if (rKind[rb] == Value.KIND_INT) setRegBool(ra, rInt[rb] == 0L);
                    else if (!execUnarySlow(OP_NOT, ra, rb, frame, ip)) return false;
                }
                case OP_EQUAL_OBJ -> {
                    final int ra = base + ((ins >>> 8) & 0xFF);
                    final int rb = base + ((ins >>> 16) & 0xFF);
                    final int rc = base + ((ins >>> 24) & 0xFF);
                    final boolean eq = (rKind[rb] == Value.KIND_INT && rKind[rc] == Value.KIND_INT)
                        ? (rInt[rb] == rInt[rc]) : Value.equal(getReg(rb), getReg(rc));
                    setRegBool(ra, eq);
                }
                case OP_NEW_SEQ -> {
                    final int start = (ins >>> 16) & 0xFF;
                    final int count = (ins >>> 24) & 0xFF;
                    final Sequence seq = new Sequence(count);
                    for (int i = 0; i < count; i++) seq.add(getReg(base + start + i));
                    setReg(base + ((ins >>> 8) & 0xFF), Value.fromSeq(seq));
                }
                case OP_LEN -> {
                    final int ra = base + ((ins >>> 8) & 0xFF);
                    final int rb = base + ((ins >>> 16) & 0xFF);
                    final byte kb = rKind[rb];
                    if (kb == Value.KIND_SEQ) setRegInt(ra, rSeq[rb].seqVal.len);
                    else if (kb == Value.KIND_INT || kb == Value.KIND_F64) setRegInt(ra, 1L);
                    else { frame.ip = ip; runtimeError(frame, "length() / '$' erfordert eine Sequenz oder ein Atom"); return false; }
                }
                case OP_GET_IDX -> {
                    final int ra = base + ((ins >>> 8) & 0xFF);
                    final int rb = base + ((ins >>> 16) & 0xFF);
                    final int rc = base + ((ins >>> 24) & 0xFF);
                    if (rKind[rb] != Value.KIND_SEQ) {
                        frame.ip = ip; runtimeError(frame, "Indizierung 's[i]' auf ein Atom angewendet (Sequenz erwartet)"); return false;
                    }
                    final byte ck = rKind[rc];
                    long idx;
                    if (ck == Value.KIND_INT) idx = rInt[rc];
                    else if (ck == Value.KIND_F64) idx = (long) Math.floor(rF64[rc]);
                    else { frame.ip = ip; runtimeError(frame, "Sequenz-Index muss ein Atom (Zahl) sein"); return false; }
                    final Sequence s = rSeq[rb].seqVal;
                    if (idx < 1 || idx > s.len) {
                        frame.ip = ip;
                        runtimeError(frame, String.format("Index %d außerhalb des gültigen Bereichs 1..%d (subscript out of bounds)", idx, s.len));
                        return false;
                    }
                    final Value elem = s.data[(int) idx - 1];
                    if (rKind[ra] == Value.KIND_SEQ) { rSeq[ra].release(); rSeq[ra] = null; }
                    final byte ek = elem.kind;
                    rKind[ra] = ek;
                    if (ek == Value.KIND_INT) {
                        rInt[ra] = elem.intVal;
                    } else if (ek == Value.KIND_F64) {
                        rF64[ra] = elem.floatVal;
                    } else if (ek == Value.KIND_SEQ) {
                        elem.seqVal.refCount++;
                        rSeq[ra] = elem;
                    }
                }
                case OP_SET_IDX -> {
                    final int ra = base + ((ins >>> 8) & 0xFF);
                    final int rb = base + ((ins >>> 16) & 0xFF);
                    final int rc = base + ((ins >>> 24) & 0xFF);
                    if (rKind[ra] != Value.KIND_SEQ) {
                        frame.ip = ip; runtimeError(frame, "Index-Zuweisung 's[i] = x' auf ein Atom angewendet"); return false;
                    }
                    final byte bk = rKind[rb];
                    long idx;
                    if (bk == Value.KIND_INT) idx = rInt[rb];
                    else if (bk == Value.KIND_F64) idx = (long) Math.floor(rF64[rb]);
                    else { frame.ip = ip; runtimeError(frame, "Sequenz-Index muss ein Atom (Zahl) sein"); return false; }
                    Sequence s = rSeq[ra].seqVal;
                    if (s.refCount > 1) s = ensureUniqueReg(ra);
                    if (idx < 1 || idx > s.len) {
                        frame.ip = ip;
                        runtimeError(frame, String.format("Index %d außerhalb des gültigen Bereichs 1..%d bei Zuweisung", idx, s.len));
                        return false;
                    }
                    final int pos = (int) idx - 1;
                    final Value old = s.data[pos];
                    final byte ck = rKind[rc];
                    if (ck == Value.KIND_INT) {
                        final long val = rInt[rc];
                        s.data[pos] = (val == 0) ? Value.ZERO : (val == 1) ? Value.ONE : Value.fromInt(val);
                    } else if (ck == Value.KIND_F64) {
                        s.data[pos] = Value.fromF64(rF64[rc]);
                    } else if (ck == Value.KIND_SEQ) {
                        final Value rhs = rSeq[rc];
                        rhs.seqVal.refCount++;
                        s.data[pos] = rhs;
                    } else {
                        s.data[pos] = Value.NONE;
                    }
                    if (old != null && old.kind == Value.KIND_SEQ) old.release();
                }
                case OP_GET_SLICE -> {
                    if (!execGetSlice(base + ((ins >>> 8) & 0xFF), base + ((ins >>> 16) & 0xFF), base + ((ins >>> 24) & 0xFF), frame, ip)) {
                        return false;
                    }
                }
                case OP_SET_SLICE -> {
                    if (!execSetSlice(base + ((ins >>> 8) & 0xFF), base + ((ins >>> 16) & 0xFF), base + ((ins >>> 24) & 0xFF), frame, ip)) {
                        return false;
                    }
                }
                case OP_JMP -> {
                    ip += (short) (ins >>> 16);
                }
                case OP_JMP_FALSE -> {
                    final int ra = base + ((ins >>> 8) & 0xFF);
                    final byte k = rKind[ra];
                    if (k == Value.KIND_INT) {
                        if (rInt[ra] == 0L) ip += (short) (ins >>> 16);
                    } else if (k == Value.KIND_F64) {
                        if (rF64[ra] == 0.0) ip += (short) (ins >>> 16);
                    } else {
                        frame.ip = ip;
                        runtimeError(frame, "Bedingung in 'if'/'while'/'until' muss ein Atom sein, keine Sequenz!");
                        return false;
                    }
                }
                case OP_JMP_TRUE -> {
                    final int ra = base + ((ins >>> 8) & 0xFF);
                    final byte k = rKind[ra];
                    if (k == Value.KIND_INT) {
                        if (rInt[ra] != 0L) ip += (short) (ins >>> 16);
                    } else if (k == Value.KIND_F64) {
                        if (rF64[ra] != 0.0) ip += (short) (ins >>> 16);
                    } else {
                        frame.ip = ip;
                        runtimeError(frame, "Bedingung muss ein Atom sein");
                        return false;
                    }
                }
                case OP_JMP_IF_NOT_NONE -> {
                    if (rKind[base + ((ins >>> 8) & 0xFF)] != Value.KIND_NONE) ip += (short) (ins >>> 16);
                }
                case OP_FOR_PREP -> {
                    final int r = base + ((ins >>> 8) & 0xFF);
                    final byte k0 = rKind[r], k1 = rKind[r + 1], k2 = rKind[r + 2];
                    if (k0 == Value.KIND_INT && k1 == Value.KIND_INT && k2 == Value.KIND_INT) {
                        final long cur = rInt[r], lim = rInt[r + 1], step = rInt[r + 2];
                        if ((step >= 0L && cur > lim) || (step < 0L && cur < lim)) ip += (short) (ins >>> 16);
                    } else if ((k0 == Value.KIND_INT || k0 == Value.KIND_F64) &&
                               (k1 == Value.KIND_INT || k1 == Value.KIND_F64) &&
                               (k2 == Value.KIND_INT || k2 == Value.KIND_F64)) {
                        final double cur = (k0 == Value.KIND_INT) ? (double) rInt[r] : rF64[r];
                        final double lim = (k1 == Value.KIND_INT) ? (double) rInt[r + 1] : rF64[r + 1];
                        final double step = (k2 == Value.KIND_INT) ? (double) rInt[r + 2] : rF64[r + 2];
                        if ((step >= 0.0 && cur > lim) || (step < 0.0 && cur < lim)) ip += (short) (ins >>> 16);
                    } else {
                        frame.ip = ip; runtimeError(frame, "'for'-Schleifengrenzen und Schrittweite müssen Atome sein"); return false;
                    }
                }
                case OP_FOR_LOOP -> {
                    final int r = base + ((ins >>> 8) & 0xFF);
                    if (rKind[r] == Value.KIND_INT && rKind[r + 1] == Value.KIND_INT && rKind[r + 2] == Value.KIND_INT) {
                        final long step = rInt[r + 2];
                        final long nextVal = rInt[r] + step;
                        if (((nextVal << 16) >> 16) == nextVal) rInt[r] = nextVal;
                        else { rKind[r] = Value.KIND_F64; rF64[r] = (double) nextVal; }
                        if ((step >= 0L && nextVal <= rInt[r + 1]) || (step < 0L && nextVal >= rInt[r + 1])) {
                            ip += (short) (ins >>> 16);
                        }
                    } else {
                        final double cur = (rKind[r] == Value.KIND_INT) ? (double) rInt[r] : rF64[r];
                        final double lim = (rKind[r + 1] == Value.KIND_INT) ? (double) rInt[r + 1] : rF64[r + 1];
                        final double step = (rKind[r + 2] == Value.KIND_INT) ? (double) rInt[r + 2] : rF64[r + 2];
                        final double nextVal = cur + step;
                        rKind[r] = Value.KIND_F64;
                        rF64[r] = nextVal;
                        if ((step >= 0.0 && nextVal <= lim) || (step < 0.0 && nextVal >= lim)) {
                            ip += (short) (ins >>> 16);
                        }
                    }
                }
                case OP_CALL -> {
                    final int dest = (ins >>> 8) & 0xFF;
                    final RoutineProto target = fastR[(ins >>> 16) & 0xFFFF];
                    final int newBase = base + frame.routine.maxRegs + 2;
                    if (newBase + target.maxRegs >= REGISTER_STACK_SIZE || frameDepth >= MAX_CALL_FRAMES) {
                        frame.ip = ip;
                        runtimeError(frame, "Stack-Überlauf (zu tiefe Rekursion)");
                        return false;
                    }
                    final int argBase = base + dest + 1;
                    final int arity = target.arity;
                    for (int i = 0; i < arity; i++) {
                        copyReg(newBase + i, argBase + i);
                    }
                    frame.ip = ip;
                    frame = pushFrame(target, 0, newBase, base + dest);
                    base = newBase;
                    code = frame.code;
                    ip = 0;
                }
                case OP_BUILTIN -> {
                    frame.ip = ip;
                    if (!execBuiltin(BuiltinId.VALUES[(ins >>> 16) & 0xFF], base, (ins >>> 8) & 0xFF, (ins >>> 24) & 0xFF, frame)) {
                        return false;
                    }
                    frame = fStack[frameDepth - 1];
                    base = frame.baseReg;
                    code = frame.code;
                    ip = frame.ip;
                }
                case OP_PRINT_Q -> {
                    getReg(base + ((ins >>> 8) & 0xFF)).printPretty(System.out);
                    System.out.print('\n');
                    System.out.flush();
                }
                case OP_RETURN -> {
                    final boolean hasVal = (((ins >>> 16) & 0xFF) != 0);
                    final boolean wasTypeCheck = frame.routine.isType;
                    final String rname = frame.routine.name;
                    final int retReg = frame.callerRetReg;
                    final int oldBase = base;
                    final int endClear = oldBase + frame.routine.maxRegs;

                    byte rk = Value.KIND_INT;
                    long ri = 0L;
                    double rf = 0.0;
                    Value rs = null;
                    if (hasVal) {
                        final int src = base + ((ins >>> 8) & 0xFF);
                        rk = rKind[src];
                        if (rk == Value.KIND_INT) ri = rInt[src];
                        else if (rk == Value.KIND_F64) rf = rF64[src];
                        else if (rk == Value.KIND_SEQ) { rs = rSeq[src]; rs.seqVal.refCount++; }
                    }

                    frameDepth--;
                    for (int i = oldBase; i < endClear; i++) {
                        if (rKind[i] == Value.KIND_SEQ) { rSeq[i].release(); rSeq[i] = null; }
                        rKind[i] = Value.KIND_NONE;
                    }

                    if (frameDepth == 0) {
                        if (!execReturnToEmpty(rk, ri, rf, rs)) return true;
                        frame = fStack[frameDepth - 1];
                        base = frame.baseReg;
                        code = frame.code;
                        ip = frame.ip;
                        break;
                    }

                    frame = fStack[frameDepth - 1];
                    base = frame.baseReg;
                    code = frame.code;
                    ip = frame.ip;

                    if (wasTypeCheck && retReg == oldBase - 1) {
                        boolean truth = (rk == Value.KIND_INT) ? (ri != 0L) : (rk == Value.KIND_F64 && rf != 0.0);
                        if (rk == Value.KIND_SEQ && rs != null) rs.release();
                        if (!truth) {
                            runtimeError(frame, "Benutzerdefinierte Typprüfung fehlgeschlagen (type_check failure): '" + rname + "'");
                            return false;
                        }
                    } else {
                        if (rKind[retReg] == Value.KIND_SEQ) { rSeq[retReg].release(); rSeq[retReg] = null; }
                        rKind[retReg] = rk;
                        if (rk == Value.KIND_INT) rInt[retReg] = ri;
                        else if (rk == Value.KIND_F64) rF64[retReg] = rf;
                        else if (rk == Value.KIND_SEQ) rSeq[retReg] = rs;
                    }
                }
                case OP_HALT -> {
                    return true;
                }
            }
        }
    }

    private byte[] formatEuphoriaPrintf(String fmt, Value argsVal, CallFrame frame, boolean[] ok) {
        ok[0] = true;
        ByteArrayOutputStream out = new ByteArrayOutputStream(fmt.length() + 32);
        byte[] fmtBytes = fmt.getBytes(StandardCharsets.UTF_8);

        int[] argIdx = {0};
        java.util.function.Supplier<Value> getNextArg = () -> {
            if (argsVal.isSeq()) {
                Sequence s = argsVal.asSeq();
                if (argIdx[0] < s.size()) {
                    return s.get(argIdx[0]++);
                }
                return Value.fromInt(0);
            } else {
                if (argIdx[0] == 0) {
                    argIdx[0]++;
                    return argsVal;
                }
                return Value.fromInt(0);
            }
        };

        for (int i = 0; i < fmtBytes.length; i++) {
            byte b = fmtBytes[i];
            if (b != '%') {
                out.write(b);
                continue;
            }
            if (i + 1 < fmtBytes.length && fmtBytes[i + 1] == '%') {
                out.write('%');
                i++;
                continue;
            }

            int specStart = i;
            i++;
            while (i < fmtBytes.length && (fmtBytes[i] == '-' || fmtBytes[i] == '+' || fmtBytes[i] == '0' ||
                   fmtBytes[i] == '.' || (fmtBytes[i] >= '0' && fmtBytes[i] <= '9'))) {
                i++;
            }
            if (i >= fmtBytes.length) {
                runtimeError(frame, "Unvollständiger Format-Specifier in printf/sprintf");
                ok[0] = false;
                return new byte[0];
            }
            char conv = (char) (fmtBytes[i] & 0xFF);
            String subFmt = new String(fmtBytes, specStart, i - specStart + 1, StandardCharsets.US_ASCII);
            if (subFmt.indexOf('.') >= 0) {
                subFmt = subFmt.replaceAll("\\.([a-zA-Z])", ".0$1");
            }
            Value arg = getNextArg.get();

            switch (conv) {
                case 's' -> {
                    byte[] raw = arg.toRawBytes();
                    if ("%s".equals(subFmt)) {
                        out.write(raw, 0, raw.length);
                    } else {
                        String s = new String(raw, StandardCharsets.UTF_8);
                        byte[] formatted = String.format(Locale.ROOT, subFmt, s).getBytes(StandardCharsets.UTF_8);
                        out.write(formatted, 0, formatted.length);
                    }
                }
                case 'd', 'x', 'X', 'o' -> {
                    byte[] formatted = String.format(Locale.ROOT, subFmt, arg.toIntCoerce()).getBytes(StandardCharsets.US_ASCII);
                    out.write(formatted, 0, formatted.length);
                }
                case 'c' -> {
                    out.write((int) (arg.toIntCoerce() & 0xFF));
                }
                case 'f', 'e', 'E', 'g', 'G' -> {
                    String s;
                    if ("%g".equals(subFmt)) {
                        s = Value.formatG(arg.asF64());
                    } else if (conv == 'g' || conv == 'G') {
                        s = String.format(Locale.ROOT, subFmt, arg.asF64());
                        if (!subFmt.contains("#")) {
                            int eIdx = s.indexOf('e');
                            if (eIdx < 0) eIdx = s.indexOf('E');
                            String mantissa = eIdx >= 0 ? s.substring(0, eIdx) : s;
                            String exp = eIdx >= 0 ? s.substring(eIdx) : "";
                            if (mantissa.indexOf('.') >= 0) {
                                int end = mantissa.length();
                                while (end > 0 && mantissa.charAt(end - 1) == '0') end--;
                                if (end > 0 && mantissa.charAt(end - 1) == '.') end--;
                                mantissa = mantissa.substring(0, end);
                            }
                            s = mantissa + exp;
                        }
                    } else {
                        s = String.format(Locale.ROOT, subFmt, arg.asF64());
                    }
                    byte[] formatted = s.getBytes(StandardCharsets.US_ASCII);
                    out.write(formatted, 0, formatted.length);
                }
                default -> {
                    byte[] raw = subFmt.getBytes(StandardCharsets.UTF_8);
                    out.write(raw, 0, raw.length);
                }
            }
        }
        return out.toByteArray();
    }

    private static long computeEuphoriaHash(Value v, double algo) {
        if (v.isInt()) {
            long x = v.asInt();
            return (x * 2654435761L) & 0x3FFFFFFFL;
        }
        if (v.isF64()) {
            long x = v.rawBits();
            return (((x ^ (x >>> 32)) * 2654435761L)) & 0x3FFFFFFFL;
        }
        if (v.isSeq()) {
            Sequence s = v.asSeq();
            long h = 0x12345678L + s.size();
            for (int i = 0; i < s.size(); i++) {
                h = (h * 33L) ^ computeEuphoriaHash(s.get(i), algo);
            }
            return (algo == -6.0) ? (h & 0x3FFFFFFFL) : (h & 0xFFFFFFFFL);
        }
        return 0L;
    }

    private Value applyFloor(Value v) {
        if (v.isInt()) return v;
        if (v.isF64()) {
            double fl = Math.floor(v.asF64Raw());
            if (fl >= (double) Value.INT48_MIN && fl <= (double) Value.INT48_MAX) {
                return Value.fromInt((long) fl);
            }
            return Value.fromF64(fl);
        }
        Sequence s = v.asSeq();
        Sequence out = new Sequence(s.size());
        for (int i = 0; i < s.size(); i++) {
            out.setElement(i, applyFloor(s.get(i)));
        }
        return Value.fromSeq(out);
    }

    private Value applyMath(BuiltinId id, Value v) {
        if (v.isAtom()) {
            double x = v.asF64();
            return switch (id) {
                case Sqrt   -> Value.fromF64(Math.sqrt(x));
                case Sin    -> Value.fromF64(Math.sin(x));
                case Cos    -> Value.fromF64(Math.cos(x));
                case Tan    -> Value.fromF64(Math.tan(x));
                case Arctan -> Value.fromF64(Math.atan(x));
                case Log    -> Value.fromF64(Math.log(x));
                default     -> v;
            };
        }
        Sequence s = v.asSeq();
        Sequence out = new Sequence(s.size());
        for (int i = 0; i < s.size(); i++) {
            out.setElement(i, applyMath(id, s.get(i)));
        }
        return Value.fromSeq(out);
    }

    private Value applyRand(Value v) {
        if (v.isAtom()) {
            long m = Math.max(1L, v.toIntCoerce());
            long r = Long.remainderUnsigned(rng.nextLong(), m) + 1L;
            return Value.fromInt(r);
        }
        Sequence s = v.asSeq();
        Sequence out = new Sequence(s.size());
        for (int i = 0; i < s.size(); i++) {
            out.setElement(i, applyRand(s.get(i)));
        }
        return Value.fromSeq(out);
    }

    private boolean execBuiltin(BuiltinId id, int base, int dest, int argc, CallFrame frame) {
        int argsIdx = base + dest + 1;

        switch (id) {
            case Length -> {
                Value a0 = getReg(argsIdx);
                if (argc != 1 || (!a0.isSeq() && !a0.isAtom())) {
                    runtimeError(frame, "length(s) erwartet genau 1 Sequenz oder Atom");
                    return false;
                }
                setReg(base + dest, Value.fromInt(a0.isSeq() ? a0.asSeq().size() : 1));
                return true;
            }
            case Append -> {
                Value a0 = getReg(argsIdx);
                if (argc != 2 || !a0.isSeq()) {
                    runtimeError(frame, "append(seq, x) erwartet eine Sequenz als 1. Argument");
                    return false;
                }
                Value elem = getReg(argsIdx + 1);
                elem.retain();
                setReg(base + dest, a0);
                setReg(argsIdx, Value.NONE);
                Sequence s = ensureUniqueReg(base + dest);
                s.addElement(elem);
                elem.release();
                return true;
            }
            case Prepend -> {
                Value a0 = getReg(argsIdx);
                if (argc != 2 || !a0.isSeq()) {
                    runtimeError(frame, "prepend(seq, x) erwartet eine Sequenz als 1. Argument");
                    return false;
                }
                Value elem = getReg(argsIdx + 1);
                elem.retain();
                setReg(base + dest, a0);
                setReg(argsIdx, Value.NONE);
                Sequence s = ensureUniqueReg(base + dest);
                s.insertElement(0, elem);
                elem.release();
                return true;
            }
            case Repeat -> {
                Value a0 = getReg(argsIdx);
                Value a1 = getReg(argsIdx + 1);
                if (argc != 2 || !a1.isAtom()) {
                    runtimeError(frame, "repeat(item, count) erwartet Anzahl als 2. Argument");
                    return false;
                }
                long count = a1.toIntCoerce();
                if (count < 0) {
                    runtimeError(frame, "repeat() Anzahl darf nicht negativ sein");
                    return false;
                }
                Sequence seq = new Sequence((int) count, a0);
                setReg(base + dest, Value.fromSeq(seq));
                return true;
            }
            case Head -> {
                Value a0 = getReg(argsIdx);
                if (argc < 1 || argc > 2 || !a0.isSeq()) {
                    runtimeError(frame, "head(seq [, n]) erwartet eine Sequenz");
                    return false;
                }
                Sequence s = a0.asSeq();
                int n = (argc == 2 && !getReg(argsIdx + 1).isNone())
                    ? (int) Math.max(0L, getReg(argsIdx + 1).toIntCoerce())
                    : 1;
                n = Math.min(n, s.size());
                Sequence out = new Sequence(n);
                for (int i = 0; i < n; i++) out.setElement(i, s.get(i));
                setReg(base + dest, Value.fromSeq(out));
                return true;
            }
            case Tail -> {
                Value a0 = getReg(argsIdx);
                if (argc < 1 || argc > 2 || !a0.isSeq()) {
                    runtimeError(frame, "tail(seq [, n]) erwartet eine Sequenz");
                    return false;
                }
                Sequence s = a0.asSeq();
                int len = s.size();
                int n = (argc == 2 && !getReg(argsIdx + 1).isNone())
                    ? (int) Math.max(0L, getReg(argsIdx + 1).toIntCoerce())
                    : (len > 0 ? len - 1 : 0);
                n = Math.min(n, len);
                Sequence out = new Sequence(n);
                for (int i = 0; i < n; i++) out.setElement(i, s.get(len - n + i));
                setReg(base + dest, Value.fromSeq(out));
                return true;
            }
            case Remove -> {
                Value a0 = getReg(argsIdx);
                if (argc < 2 || argc > 3 || !a0.isSeq()) {
                    runtimeError(frame, "remove(seq, start [, stop]) erwartet eine Sequenz");
                    return false;
                }
                long start = getReg(argsIdx + 1).toIntCoerce();
                long stop = (argc == 3 && !getReg(argsIdx + 2).isNone()) ? getReg(argsIdx + 2).toIntCoerce() : start;
                setReg(base + dest, a0);
                setReg(argsIdx, Value.NONE);
                Sequence s = ensureUniqueReg(base + dest);
                if (start >= 1 && stop >= start && stop <= s.size()) {
                    s.removeRange((int) (start - 1), (int) stop);
                }
                return true;
            }
            case Replace -> {
                Value a0 = getReg(argsIdx);
                if (argc < 3 || argc > 4 || !a0.isSeq()) {
                    runtimeError(frame, "replace(target, replacement, start [, stop]) erwartet eine Sequenz");
                    return false;
                }
                Value repVal = getReg(argsIdx + 1);
                repVal.retain();
                long start = getReg(argsIdx + 2).toIntCoerce();
                long stop = (argc == 4 && !getReg(argsIdx + 3).isNone()) ? getReg(argsIdx + 3).toIntCoerce() : start;
                setReg(base + dest, a0);
                setReg(argsIdx, Value.NONE);
                Sequence s = ensureUniqueReg(base + dest);
                if (start >= 1 && stop >= start - 1 && stop <= s.size()) {
                    if (repVal.isSeq()) {
                        s.replaceRange((int) (start - 1), (int) stop, repVal.asSeq());
                    } else {
                        s.removeRange((int) (start - 1), (int) stop);
                        s.insertElement((int) (start - 1), repVal);
                    }
                }
                repVal.release();
                return true;
            }
            case Insert -> {
                Value a0 = getReg(argsIdx);
                if (argc != 3 || !a0.isSeq()) {
                    runtimeError(frame, "insert(seq, what, index) erwartet 3 Argumente");
                    return false;
                }
                Value what = getReg(argsIdx + 1);
                what.retain();
                long rawIdx = getReg(argsIdx + 2).toIntCoerce();
                setReg(base + dest, a0);
                setReg(argsIdx, Value.NONE);
                Sequence s = ensureUniqueReg(base + dest);
                int idx = (int) Math.clamp(rawIdx, 1L, (long) (s.size() + 1));
                s.insertElement(idx - 1, what);
                what.release();
                return true;
            }
            case Splice -> {
                Value a0 = getReg(argsIdx);
                if (argc != 3 || !a0.isSeq()) {
                    runtimeError(frame, "splice(seq, what, index) erwartet 3 Argumente");
                    return false;
                }
                Value what = getReg(argsIdx + 1);
                what.retain();
                long rawIdx = getReg(argsIdx + 2).toIntCoerce();
                setReg(base + dest, a0);
                setReg(argsIdx, Value.NONE);
                Sequence s = ensureUniqueReg(base + dest);
                int idx = (int) Math.clamp(rawIdx, 1L, (long) (s.size() + 1));
                if (what.isSeq()) {
                    s.insertAll(idx - 1, what.asSeq());
                } else {
                    s.insertElement(idx - 1, what);
                }
                what.release();
                return true;
            }
            case Compare -> {
                if (argc != 2) {
                    runtimeError(frame, "compare(a, b) erwartet 2 Argumente");
                    return false;
                }
                setReg(base + dest, Value.fromInt(Value.compare(getReg(argsIdx), getReg(argsIdx + 1))));
                return true;
            }
            case Equal -> {
                if (argc != 2) {
                    runtimeError(frame, "equal(a, b) erwartet 2 Argumente");
                    return false;
                }
                setReg(base + dest, Value.fromInt(Value.equal(getReg(argsIdx), getReg(argsIdx + 1)) ? 1 : 0));
                return true;
            }
            case Find -> {
                Value needle = getReg(argsIdx);
                Value hayVal = getReg(argsIdx + 1);
                if (argc < 2 || argc > 3 || !hayVal.isSeq()) {
                    runtimeError(frame, "find(needle, haystack [, start]) erwartet eine Sequenz als 2. Argument");
                    return false;
                }
                Sequence hay = hayVal.asSeq();
                int start = (argc == 3 && !getReg(argsIdx + 2).isNone())
                    ? (int) Math.max(1L, getReg(argsIdx + 2).toIntCoerce())
                    : 1;
                long found = 0;
                for (int i = start; i <= hay.size(); i++) {
                    if (Value.equal(needle, hay.get(i - 1))) {
                        found = i;
                        break;
                    }
                }
                setReg(base + dest, Value.fromInt(found));
                return true;
            }
            case Match -> {
                Value needleVal = getReg(argsIdx);
                Value hayVal = getReg(argsIdx + 1);
                if (argc < 2 || argc > 3 || !needleVal.isSeq() || !hayVal.isSeq()) {
                    runtimeError(frame, "match(needle, haystack [, start]) erwartet zwei Sequenzen");
                    return false;
                }
                Sequence needle = needleVal.asSeq();
                Sequence hay = hayVal.asSeq();
                if (needle.size() == 0 || needle.size() > hay.size()) {
                    setReg(base + dest, Value.fromInt(0));
                    return true;
                }
                int start = (argc == 3 && !getReg(argsIdx + 2).isNone())
                    ? (int) Math.max(1L, getReg(argsIdx + 2).toIntCoerce())
                    : 1;
                long found = 0;
                int limit = hay.size() - needle.size() + 1;
                for (int i = start; i <= limit; i++) {
                    boolean ok = true;
                    for (int j = 0; j < needle.size(); j++) {
                        if (!Value.equal(needle.get(j), hay.get(i - 1 + j))) {
                            ok = false;
                            break;
                        }
                    }
                    if (ok) {
                        found = i;
                        break;
                    }
                }
                setReg(base + dest, Value.fromInt(found));
                return true;
            }
            case Hash -> {
                if (argc != 2) {
                    runtimeError(frame, "hash(source, algo) erwartet 2 Argumente");
                    return false;
                }
                long h = computeEuphoriaHash(getReg(argsIdx), getReg(argsIdx + 1).asF64());
                setReg(base + dest, Value.fromInt(h));
                return true;
            }
            case Atom -> {
                setReg(base + dest, Value.fromInt(getReg(argsIdx).isAtom() ? 1 : 0));
                return true;
            }
            case Integer -> {
                setReg(base + dest, Value.fromInt(getReg(argsIdx).isEuphoriaInteger() ? 1 : 0));
                return true;
            }
            case Sequence -> {
                setReg(base + dest, Value.fromInt(getReg(argsIdx).isSeq() ? 1 : 0));
                return true;
            }
            case Object -> {
                Value a0 = getReg(argsIdx);
                if (a0.isNone()) setReg(base + dest, Value.fromInt(0));
                else if (a0.isEuphoriaInteger()) setReg(base + dest, Value.fromInt(1));
                else if (a0.isAtom()) setReg(base + dest, Value.fromInt(2));
                else setReg(base + dest, Value.fromInt(3));
                return true;
            }
            case Floor -> {
                if (argc != 1) {
                    runtimeError(frame, "floor(x) erwartet 1 Argument");
                    return false;
                }
                setReg(base + dest, applyFloor(getReg(argsIdx)));
                return true;
            }
            case Remainder, Power, AndBits, OrBits, XorBits -> {
                if (argc != 2) {
                    runtimeError(frame, "Funktion erwartet 2 Argumente");
                    return false;
                }
                Value.BinOp bop = switch (id) {
                    case Power   -> Value.BinOp.Power;
                    case AndBits -> Value.BinOp.AndBits;
                    case OrBits  -> Value.BinOp.OrBits;
                    case XorBits -> Value.BinOp.XorBits;
                    default      -> Value.BinOp.Remainder;
                };
                String[] err = new String[1];
                Value res = Value.evalBinop(bop, getReg(argsIdx), getReg(argsIdx + 1), err);
                if (err[0] != null) {
                    runtimeError(frame, err[0]);
                    return false;
                }
                setReg(base + dest, res);
                return true;
            }
            case NotBits -> {
                if (argc != 1) {
                    runtimeError(frame, "not_bits(a) erwartet 1 Argument");
                    return false;
                }
                String[] err = new String[1];
                Value res = Value.evalUnary(Value.UnaryOp.NotBits, getReg(argsIdx), err);
                if (err[0] != null) {
                    runtimeError(frame, err[0]);
                    return false;
                }
                setReg(base + dest, res);
                return true;
            }
            case Sqrt, Sin, Cos, Tan, Arctan, Log -> {
                if (argc != 1) {
                    runtimeError(frame, "Mathematische Funktion erwartet 1 Argument");
                    return false;
                }
                setReg(base + dest, applyMath(id, getReg(argsIdx)));
                return true;
            }
            case Rand -> {
                if (argc != 1) {
                    runtimeError(frame, "rand(max) erwartet 1 Argument");
                    return false;
                }
                setReg(base + dest, applyRand(getReg(argsIdx)));
                return true;
            }
            case Puts -> {
                if (argc != 2) {
                    runtimeError(frame, "puts(fn, text) erwartet 2 Argumente");
                    return false;
                }
                long handle = getReg(argsIdx).toIntCoerce();
                if (!writeCharsToHandle(handle, getReg(argsIdx + 1))) {
                    runtimeError(frame, "Ungültiges Datei-Handle in puts()");
                    return false;
                }
                setReg(base + dest, Value.fromInt(0));
                return true;
            }
            case Print -> {
                if (argc != 2) {
                    runtimeError(frame, "print(fn, x) erwartet 2 Argumente");
                    return false;
                }
                long handle = getReg(argsIdx).toIntCoerce();
                if (!writePrettyToHandle(handle, getReg(argsIdx + 1))) {
                    runtimeError(frame, "Ungültiges Datei-Handle in print()");
                    return false;
                }
                setReg(base + dest, Value.fromInt(0));
                return true;
            }
            case Printf -> {
                if (argc < 2 || argc > 3) {
                    runtimeError(frame, "printf(fn, fmt, args) erwartet 2 oder 3 Argumente");
                    return false;
                }
                long handle = getReg(argsIdx).toIntCoerce();
                String fmt = getReg(argsIdx + 1).toUtf8String();
                Value fmtArgs = (argc == 3) ? getReg(argsIdx + 2) : Value.emptySeq();
                boolean[] ok = new boolean[1];
                byte[] formatted = formatEuphoriaPrintf(fmt, fmtArgs, frame, ok);
                if (!ok[0]) return false;
                if (!writeRawBytesToHandle(handle, formatted)) {
                    runtimeError(frame, "Ungültiges Datei-Handle in printf()");
                    return false;
                }
                setReg(base + dest, Value.fromInt(0));
                return true;
            }
            case Sprintf -> {
                if (argc != 2) {
                    runtimeError(frame, "sprintf(fmt, args) erwartet 2 Argumente");
                    return false;
                }
                String fmt = getReg(argsIdx).toUtf8String();
                boolean[] ok = new boolean[1];
                byte[] formatted = formatEuphoriaPrintf(fmt, getReg(argsIdx + 1), frame, ok);
                if (!ok[0]) return false;
                setReg(base + dest, Value.fromRawBytes(formatted));
                return true;
            }
            case Open -> {
                if (argc < 2 || argc > 3) {
                    runtimeError(frame, "open(path, mode [, cleanup]) erwartet 2 oder 3 Argumente");
                    return false;
                }
                String path = getReg(argsIdx).toUtf8String();
                String mode = getReg(argsIdx + 1).toUtf8String();
                try {
                    File file = resolvePath(path).toFile();
                    String rafMode;
                    boolean truncate = false;
                    boolean append = false;
                    if (mode.startsWith("r") && !mode.contains("+")) {
                        if (!file.exists() || file.isDirectory()) {
                            setReg(base + dest, Value.fromInt(-1));
                            return true;
                        }
                        rafMode = file.canWrite() ? "rw" : "r";
                    } else if (mode.startsWith("w")) {
                        rafMode = "rw";
                        truncate = true;
                    } else if (mode.startsWith("a")) {
                        rafMode = "rw";
                        append = true;
                    } else if (mode.startsWith("u") || mode.contains("+")) {
                        if (!file.exists()) {
                            setReg(base + dest, Value.fromInt(-1));
                            return true;
                        }
                        rafMode = "rw";
                    } else {
                        rafMode = "r";
                    }
                    RandomAccessFile raf = new RandomAccessFile(file, rafMode);
                    if (truncate) {
                        raf.setLength(0);
                    } else if (append) {
                        raf.seek(raf.length());
                    }
                    long h = nextFileHandle.getAndIncrement();
                    openFiles.put(h, raf);
                    setReg(base + dest, Value.fromInt(h));
                } catch (IOException e) {
                    setReg(base + dest, Value.fromInt(-1));
                }
                return true;
            }
            case Close -> {
                if (argc != 1) {
                    runtimeError(frame, "close(fn) erwartet 1 Argument");
                    return false;
                }
                long h = getReg(argsIdx).toIntCoerce();
                java.nio.channels.FileLock fl = fileLocks.remove(h);
                if (fl != null) {
                    try { fl.release(); } catch (IOException ignored) {}
                }
                RandomAccessFile raf = openFiles.remove(h);
                if (raf != null) {
                    try { raf.close(); } catch (IOException ignored) {}
                }
                setReg(base + dest, Value.fromInt(0));
                return true;
            }
            case Getc -> {
                if (argc != 1) {
                    runtimeError(frame, "getc(fn) erwartet 1 Argument");
                    return false;
                }
                long h = getReg(argsIdx).toIntCoerce();
                try {
                    if (h == 0) {
                        int c = System.in.read();
                        setReg(base + dest, Value.fromInt(c < 0 ? -1 : c));
                    } else {
                        RandomAccessFile raf = openFiles.get(h);
                        if (raf == null) {
                            setReg(base + dest, Value.fromInt(-1));
                        } else {
                            int c = raf.read();
                            setReg(base + dest, Value.fromInt(c < 0 ? -1 : c));
                        }
                    }
                } catch (IOException e) {
                    setReg(base + dest, Value.fromInt(-1));
                }
                return true;
            }
            case Gets -> {
                if (argc != 1) {
                    runtimeError(frame, "gets(fn) erwartet 1 Argument");
                    return false;
                }
                long h = getReg(argsIdx).toIntCoerce();
                try {
                    ByteArrayOutputStream line = new ByteArrayOutputStream(64);
                    int c = -1;
                    if (h == 0) {
                        while ((c = System.in.read()) != -1) {
                            line.write(c);
                            if (c == '\n') break;
                        }
                    } else {
                        RandomAccessFile raf = openFiles.get(h);
                        if (raf == null) {
                            setReg(base + dest, Value.fromInt(-1));
                            return true;
                        }
                        while ((c = raf.read()) != -1) {
                            line.write(c);
                            if (c == '\n') break;
                        }
                    }
                    if (line.size() == 0 && c == -1) {
                        setReg(base + dest, Value.fromInt(-1));
                    } else {
                        byte[] bytes = line.toByteArray();
                        if (bytes.length > 0 && bytes[bytes.length - 1] != '\n') {
                            byte[] withNl = new byte[bytes.length + 1];
                            System.arraycopy(bytes, 0, withNl, 0, bytes.length);
                            withNl[bytes.length] = '\n';
                            bytes = withNl;
                        }
                        setReg(base + dest, Value.fromRawBytes(bytes));
                    }
                } catch (IOException e) {
                    setReg(base + dest, Value.fromInt(-1));
                }
                return true;
            }
            case GetKey -> {
                setReg(base + dest, Value.fromInt(-1));
                return true;
            }
            case Position -> {
                if (argc == 2) {
                    System.out.printf("\033[%d;%dH", getReg(argsIdx).toIntCoerce(), getReg(argsIdx + 1).toIntCoerce());
                    System.out.flush();
                }
                setReg(base + dest, Value.fromInt(0));
                return true;
            }
            case ClearScreen -> {
                System.out.print("\033[2J\033[H");
                System.out.flush();
                setReg(base + dest, Value.fromInt(0));
                return true;
            }
            case Time -> {
                double elapsed = (System.nanoTime() - startTimeNanos) / 1_000_000_000.0;
                elapsed = Math.floor(elapsed * 100.0) / 100.0;
                setReg(base + dest, Value.fromF64(elapsed));
                return true;
            }
            case Date -> {
                ZonedDateTime now = ZonedDateTime.now();
                Sequence seq = new Sequence(8);
                seq.setElement(0, Value.fromInt(now.getYear() - 1900));
                seq.setElement(1, Value.fromInt(now.getMonthValue()));
                seq.setElement(2, Value.fromInt(now.getDayOfMonth()));
                seq.setElement(3, Value.fromInt(now.getHour()));
                seq.setElement(4, Value.fromInt(now.getMinute()));
                seq.setElement(5, Value.fromInt(now.getSecond()));
                // Sunday = 1 .. Saturday = 7 (matching C tm_wday + 1)
                int dow = (now.getDayOfWeek().getValue() % 7) + 1;
                seq.setElement(6, Value.fromInt(dow));
                seq.setElement(7, Value.fromInt(now.getDayOfYear()));
                setReg(base + dest, Value.fromSeq(seq));
                return true;
            }
            case Getenv -> {
                String varName = getReg(argsIdx).toUtf8String();
                String val;
                if (envUnset.contains(varName)) {
                    val = null;
                } else if (envOverrides.containsKey(varName)) {
                    val = envOverrides.get(varName);
                } else {
                    val = System.getenv(varName);
                }
                if (val == null) {
                    setReg(base + dest, Value.fromInt(-1));
                } else {
                    setReg(base + dest, Value.fromString(val));
                }
                return true;
            }
            case Platform -> {
                String osName = System.getProperty("os.name", "").toLowerCase();
                int plat = osName.contains("win") ? 2 : (osName.contains("mac") || osName.contains("darwin")) ? 5 : 3;
                setReg(base + dest, Value.fromInt(plat));
                return true;
            }
            case CommandLine -> {
                Sequence seq = new Sequence();
                if (prog.cliArgs.isEmpty()) {
                    seq.addElement(Value.fromString("eui"));
                    seq.addElement(Value.fromString("eui"));
                } else {
                    for (String s : prog.cliArgs) {
                        seq.addElement(Value.fromString(s));
                    }
                }
                setReg(base + dest, Value.fromSeq(seq));
                return true;
            }
            case System -> {
                String cmd = getReg(argsIdx).toUtf8String();
                runShellCommand(cmd);
                setReg(base + dest, Value.fromInt(0));
                return true;
            }
            case SystemExec -> {
                String cmd = getReg(argsIdx).toUtf8String();
                int rc = runShellCommand(cmd);
                setReg(base + dest, Value.fromInt(rc));
                return true;
            }
            case Abort -> {
                int code = (argc >= 1) ? (int) getReg(argsIdx).toIntCoerce() : 0;
                throw new VmAbortException(code);
            }
            case OptionSwitches, IncludePaths -> {
                setReg(base + dest, Value.emptySeq());
                return true;
            }
            case Warning, Trace, Profile -> {
                setReg(base + dest, Value.fromInt(0));
                return true;
            }
            case RoutineId -> {
                Value a0 = getReg(argsIdx);
                if (argc != 1 || !a0.isSeq()) {
                    runtimeError(frame, "routine_id(name) erwartet einen String (Sequenz)");
                    return false;
                }
                String rname = a0.toUtf8String();
                int colon = rname.indexOf(':');
                String nsPart = (colon >= 0) ? rname.substring(0, colon) : "";
                String fnPart = (colon >= 0) ? rname.substring(colon + 1) : rname;

                long foundId = -1;
                for (int i = 1; i < prog.routines.size(); i++) {
                    RoutineProto rp = prog.routines.get(i);
                    if (rp.name.equals(fnPart) && (nsPart.isEmpty() || rp.ns.equals(nsPart))) {
                        foundId = i;
                        break;
                    }
                }
                setReg(base + dest, Value.fromInt(foundId));
                return true;
            }
            case CallFunc, CallProc -> {
                Value a0 = getReg(argsIdx);
                if (argc < 1 || argc > 2 || !a0.isAtom()) {
                    runtimeError(frame, "call_func/call_proc(id [, args_seq]) erwartet eine Routine-ID");
                    return false;
                }
                Value argSeqVal = (argc == 2 && !getReg(argsIdx + 1).isNone()) ? getReg(argsIdx + 1) : Value.emptySeq();
                if (!argSeqVal.isSeq()) {
                    runtimeError(frame, "call_func/call_proc erwartet eine Sequenz als 2. Argument");
                    return false;
                }
                long rid = a0.toIntCoerce();
                if (rid < 1 || rid >= prog.routines.size()) {
                    runtimeError(frame, "Ungültige Routine-ID in call_func/call_proc: " + rid);
                    return false;
                }
                RoutineProto target = prog.routines.get((int) rid);
                Sequence argSeq = argSeqVal.asSeq();
                int provided = argSeq.size();
                if (provided < target.minArity || provided > target.arity) {
                    runtimeError(frame, "Falsche Argumentanzahl bei dynamischem Aufruf von '" + target.name + "'");
                    return false;
                }
                int newBase = frame.baseReg + frame.routine.maxRegs + 2;
                if (newBase + target.maxRegs >= REGISTER_STACK_SIZE) {
                    runtimeError(frame, "Register-Stack-Überlauf in call_func/call_proc");
                    return false;
                }
                for (int i = 0; i < target.arity; i++) {
                    Value aval = (i < provided) ? argSeq.get(i) : Value.NONE;
                    setReg(newBase + i, aval);
                }
                int retReg = frame.baseReg + dest;
                pushFrame(target, 0, newBase, retReg);
                return true;
            }
            case DeleteRoutine -> {
                Value a0 = getReg(argsIdx);
                Value a1 = getReg(argsIdx + 1);
                if (argc != 2 || !a1.isAtom()) {
                    runtimeError(frame, "delete_routine(x, rid) erwartet 2 Argumente");
                    return false;
                }
                int rid = (int) a1.toIntCoerce();
                if (a0.isSeq()) {
                    Sequence s = a0.asSeq();
                    if (s.cleanupRids == null) s.cleanupRids = new ArrayList<>(2);
                    s.cleanupRids.add(rid);
                    setReg(base + dest, a0);
                } else if (a0.isAtom()) {
                    atomCleanups.computeIfAbsent(a0.toIntCoerce(), k -> Collections.synchronizedList(new ArrayList<>())).add(rid);
                    setReg(base + dest, a0);
                } else {
                    setReg(base + dest, a0);
                }
                return true;
            }
            case Delete -> {
                if (argc != 1) {
                    runtimeError(frame, "delete(x) erwartet 1 Argument");
                    return false;
                }
                Value a0 = getReg(argsIdx);
                int rid = -1;
                if (a0.isSeq()) {
                    List<Integer> rids = a0.asSeq().cleanupRids;
                    if (rids != null && !rids.isEmpty()) {
                        rid = rids.remove(rids.size() - 1);
                    }
                } else if (a0.isAtom()) {
                    List<Integer> rids = atomCleanups.get(a0.toIntCoerce());
                    if (rids != null && !rids.isEmpty()) {
                        rid = rids.remove(rids.size() - 1);
                    }
                }
                a0.retain();
                setReg(base + dest, Value.fromInt(0));
                if (rid >= 1 && rid < prog.routines.size()) {
                    RoutineProto target = prog.routines.get(rid);
                    int newBase = frame.baseReg + frame.routine.maxRegs + 2;
                    setReg(newBase, a0);
                    for (int i = 1; i < target.arity; i++) setReg(newBase + i, Value.NONE);
                    int retReg = frame.baseReg + dest;
                    pushFrame(target, 0, newBase, retReg);
                }
                a0.release();
                return true;
            }
            case MachineFunc, MachineProc -> {
                long fid = getReg(argsIdx).toIntCoerce();
                Value argV = (argc >= 2 && !getReg(argsIdx + 1).isNone()) ? getReg(argsIdx + 1) : Value.emptySeq();
                Value[] res = new Value[]{Value.fromInt(0)};
                if (!execMachine(fid, argV, res, frame, base + dest)) {
                    return false;
                }
                setReg(base + dest, res[0]);
                return true;
            }
            case Sizeof -> {
                long tc = getReg(argsIdx).toIntCoerce() & 0xFFFFFFFFL;
                long sz = 8;
                if (tc == 0x01000001L || tc == 0x02000001L || tc == 1) sz = 1;
                else if (tc == 0x01000002L || tc == 0x02000002L || tc == 2) sz = 2;
                else if (tc == 0x01000004L || tc == 0x02000004L || tc == 0x03000004L || tc == 4) sz = 4;
                setReg(base + dest, Value.fromInt(sz));
                return true;
            }
            case MemCopy -> {
                if (argc == 3) {
                    long dstAddr = getReg(argsIdx).toIntCoerce();
                    long srcAddr = getReg(argsIdx + 1).toIntCoerce();
                    long len = Math.max(0L, getReg(argsIdx + 2).toIntCoerce());
                    if (dstAddr != 0 && srcAddr != 0 && len > 0) {
                        MemorySegment dstSeg = MemorySegment.ofAddress(dstAddr).reinterpret(len);
                        MemorySegment srcSeg = MemorySegment.ofAddress(srcAddr).reinterpret(len);
                        MemorySegment.copy(srcSeg, 0, dstSeg, 0, len);
                    }
                }
                setReg(base + dest, Value.fromInt(0));
                return true;
            }
            case MemSet -> {
                if (argc == 3) {
                    long dstAddr = getReg(argsIdx).toIntCoerce();
                    byte byteV = (byte) (getReg(argsIdx + 1).toIntCoerce() & 0xFF);
                    long len = Math.max(0L, getReg(argsIdx + 2).toIntCoerce());
                    if (dstAddr != 0 && len > 0) {
                        MemorySegment.ofAddress(dstAddr).reinterpret(len).fill(byteV);
                    }
                }
                setReg(base + dest, Value.fromInt(0));
                return true;
            }
            case Peek, Peeks, Peek2s, Peek2u, Peek4s, Peek4u, Peek8s, Peek8u, PeekPointer -> {
                Value a0 = getReg(argsIdx);
                boolean isSeqArg = a0.isSeq();
                long addr = 0;
                int count = 1;
                if (isSeqArg) {
                    Sequence s = a0.asSeq();
                    if (s.size() >= 2) {
                        addr = s.get(0).toIntCoerce();
                        count = (int) Math.max(0L, s.get(1).toIntCoerce());
                    }
                } else {
                    addr = a0.toIntCoerce();
                }
                int elemSize = switch (id) {
                    case Peek, Peeks -> 1;
                    case Peek2s, Peek2u -> 2;
                    case Peek4s, Peek4u -> 4;
                    default -> 8;
                };
                MemorySegment seg = MemorySegment.ofAddress(addr).reinterpret((long) Math.max(1, count) * elemSize);

                if (!isSeqArg) {
                    setReg(base + dest, readNativeMemory(seg, id, 0));
                } else {
                    Sequence out = new Sequence(count);
                    for (int i = 0; i < count; i++) {
                        out.setElement(i, readNativeMemory(seg, id, i));
                    }
                    setReg(base + dest, Value.fromSeq(out));
                }
                return true;
            }
            case PeekString -> {
                long addr = getReg(argsIdx).toIntCoerce();
                if (addr == 0) {
                    setReg(base + dest, Value.emptySeq());
                } else {
                    MemorySegment seg = MemorySegment.ofAddress(addr).reinterpret(1L << 24);
                    ByteArrayOutputStream bos = new ByteArrayOutputStream(64);
                    long off = 0;
                    for (;;) {
                        byte b = seg.get(ValueLayout.JAVA_BYTE, off++);
                        if (b == 0) break;
                        bos.write(b);
                    }
                    setReg(base + dest, Value.fromRawBytes(bos.toByteArray()));
                }
                return true;
            }
            case Poke, Poke2, Poke4, Poke8, PokePointer -> {
                long addr = getReg(argsIdx).toIntCoerce();
                Value val = getReg(argsIdx + 1);
                int elemSize = switch (id) {
                    case Poke -> 1;
                    case Poke2 -> 2;
                    case Poke4 -> 4;
                    default -> 8;
                };
                int count = val.isSeq() ? val.asSeq().size() : 1;
                MemorySegment seg = MemorySegment.ofAddress(addr).reinterpret((long) Math.max(1, count) * elemSize);
                if (val.isAtom()) {
                    writeNativeMemory(seg, id, 0, valToU64(val));
                } else if (val.isSeq()) {
                    Sequence s = val.asSeq();
                    for (int i = 0; i < s.size(); i++) {
                        writeNativeMemory(seg, id, i, valToU64(s.get(i)));
                    }
                }
                setReg(base + dest, Value.fromInt(0));
                return true;
            }
            case CFunc, CProc -> {
                long cid = getReg(argsIdx).toIntCoerce();
                if (cid < 1 || cid > cRoutines.size()) {
                    runtimeError(frame, "Ungültige C-Routine-ID in c_func/c_proc: " + cid);
                    return false;
                }
                CFuncDef def = cRoutines.get((int) (cid - 1));
                Value cArgsVal = (argc >= 2 && !getReg(argsIdx + 1).isNone()) ? getReg(argsIdx + 1) : Value.emptySeq();
                Sequence s = cArgsVal.isSeq() ? cArgsVal.asSeq() : null;
                long fnAddr = def.fnPtr == null ? 0 : def.fnPtr.address();
                if ((fnAddr & 0xFF000000L) == 0xCB000000L) {
                    int cbRid = (int)(fnAddr & 0x00FFFFFFL);
                    if (cbRid >= 0 && cbRid < prog.routines.size()) {
                        RoutineProto target = prog.routines.get(cbRid);
                        int provided = (s != null) ? s.size() : 0;
                        int newBase = frame.baseReg + frame.routine.maxRegs + 2;
                        if (newBase + target.maxRegs < REGISTER_STACK_SIZE) {
                            for (int i = 0; i < target.arity; ++i) {
                                setReg(newBase + i, (s != null && i < provided) ? s.get(i) : Value.NONE);
                            }
                            int retReg = frame.baseReg + dest;
                            frame = pushFrame(target, 0, newBase, retReg);
                            return true;
                        }
                    }
                }
                try {
                    Value res = invokeNativeCFunc(def, s, id == BuiltinId.CProc);
                    setReg(base + dest, res);
                    return true;
                } catch (Throwable t) {
                    runtimeError(frame, "Fehler beim C-FFI Aufruf: " + t.getMessage());
                    return false;
                }
            }
            case Call -> {
                long addr = getReg(argsIdx).toIntCoerce();
                if ((addr & 0xFF000000L) == 0xCB000000L) {
                    int cbRid = (int)(addr & 0x00FFFFFFL);
                    if (cbRid >= 0 && cbRid < prog.routines.size()) {
                        RoutineProto target = prog.routines.get(cbRid);
                        int newBase = frame.baseReg + frame.routine.maxRegs + 2;
                        if (newBase + target.maxRegs < REGISTER_STACK_SIZE) {
                            for (int i = 0; i < target.arity; ++i) {
                                setReg(newBase + i, Value.NONE);
                            }
                            int retReg = frame.baseReg + dest;
                            frame = pushFrame(target, 0, newBase, retReg);
                            return true;
                        }
                    }
                } else if (addr != 0) {
                    try {
                        MethodHandle mh = NATIVE_LINKER.downcallHandle(
                            MemorySegment.ofAddress(addr),
                            FunctionDescriptor.ofVoid()
                        );
                        mh.invokeExact();
                    } catch (Throwable ignored) {}
                }
                setReg(base + dest, Value.fromInt(0));
                return true;
            }
            case TaskCreate -> {
                if (argc < 1) {
                    runtimeError(frame, "task_create(rid, args) erwartet mindestens ein Argument");
                    return false;
                }
                long rid = getReg(argsIdx).toIntCoerce();
                Value taskArgs = (argc > 1) ? getReg(argsIdx + 1) : Value.EMPTY_SEQ;
                long tid = nextTaskId++;
                TaskInfo t = new TaskInfo();
                t.id = tid;
                t.routineId = rid;
                t.args = taskArgs;
                t.args.retain();
                t.state = TaskState.SUSPENDED;
                tasks.put(tid, t);
                taskIdsOrder.add(tid);
                setReg(base + dest, Value.fromInt(tid));
                return true;
            }
            case TaskSchedule -> {
                if (argc >= 1) {
                    long tid = getReg(argsIdx).toIntCoerce();
                    TaskInfo t = tasks.get(tid);
                    if (t != null && t.state != TaskState.TERMINATED) {
                        t.state = TaskState.READY;
                        if (argc >= 2) t.schedule = getReg(argsIdx + 1);
                    }
                }
                setReg(base + dest, Value.fromInt(0));
                return true;
            }
            case TaskYield -> {
                setReg(base + dest, Value.fromInt(0));
                Thread.yield();
                switchToNextTask();
                return true;
            }
            case TaskSelf -> {
                setReg(base + dest, Value.fromInt(currentTaskId));
                return true;
            }
            case TaskStatus -> {
                if (argc >= 1) {
                    long tid = getReg(argsIdx).toIntCoerce();
                    TaskInfo t = tasks.get(tid);
                    if (t == null || t.state == TaskState.TERMINATED) {
                        setReg(base + dest, Value.fromInt(-1));
                    } else if (t.state == TaskState.SUSPENDED) {
                        setReg(base + dest, Value.fromInt(0));
                    } else {
                        setReg(base + dest, Value.fromInt(1));
                    }
                } else {
                    setReg(base + dest, Value.fromInt(-1));
                }
                return true;
            }
            case TaskList -> {
                List<Value> ids = new ArrayList<>();
                for (Long tid : taskIdsOrder) {
                    TaskInfo t = tasks.get(tid);
                    if (t != null && t.state != TaskState.TERMINATED) {
                        ids.add(Value.fromInt(tid));
                    }
                }
                Sequence s = new Sequence(ids.size(), Value.fromInt(0));
                for (int i = 0; i < ids.size(); i++) {
                    s.setElement(i, ids.get(i));
                }
                setReg(base + dest, Value.fromSeq(s));
                return true;
            }
            case TaskSuspend -> {
                if (argc >= 1) {
                    long tid = getReg(argsIdx).toIntCoerce();
                    TaskInfo t = tasks.get(tid);
                    if (t != null && t.state != TaskState.TERMINATED) {
                        t.state = TaskState.SUSPENDED;
                        if (tid == currentTaskId) {
                            setReg(base + dest, Value.fromInt(0));
                            switchToNextTask();
                            return true;
                        }
                    }
                }
                setReg(base + dest, Value.fromInt(0));
                return true;
            }
            case TaskClockStart -> {
                setReg(base + dest, Value.fromInt(0));
                return true;
            }
            case TaskClockStop -> {
                setReg(base + dest, Value.fromInt(0));
                return true;
            }
        }
        return false;
    }

    private static Value readNativeMemory(MemorySegment seg, BuiltinId id, int index) {
        return switch (id) {
            case Peek   -> Value.fromInt(seg.get(ValueLayout.JAVA_BYTE, index) & 0xFFL);
            case Peeks  -> Value.fromInt(seg.get(ValueLayout.JAVA_BYTE, index));
            case Peek2s -> Value.fromInt(seg.get(ValueLayout.JAVA_SHORT_UNALIGNED, (long) index * 2));
            case Peek2u -> Value.fromInt(seg.get(ValueLayout.JAVA_SHORT_UNALIGNED, (long) index * 2) & 0xFFFFL);
            case Peek4s -> Value.fromInt(seg.get(ValueLayout.JAVA_INT_UNALIGNED, (long) index * 4));
            case Peek4u -> Value.fromInt(seg.get(ValueLayout.JAVA_INT_UNALIGNED, (long) index * 4) & 0xFFFFFFFFL);
            case Peek8u -> {
                long v = seg.get(ValueLayout.JAVA_LONG_UNALIGNED, (long) index * 8);
                if (v < 0) {
                    yield Value.fromFloat((double) (v & 0x7FFFFFFFFFFFFFFFL) + 0x1.0p63);
                }
                yield Value.fromInt(v);
            }
            default     -> Value.fromInt(seg.get(ValueLayout.JAVA_LONG_UNALIGNED, (long) index * 8));
        };
    }

    private static long valToU64(Value v) {
        if (v.isInt()) return v.asInt();
        double d = v.asF64();
        if (d >= 0x1.0p63) {
            return (long)(d - 0x1.0p63) | 0x8000000000000000L;
        }
        return (long) d;
    }

    private static void writeNativeMemory(MemorySegment seg, BuiltinId id, int index, long val) {
        switch (id) {
            case Poke  -> seg.set(ValueLayout.JAVA_BYTE, index, (byte) (val & 0xFF));
            case Poke2 -> seg.set(ValueLayout.JAVA_SHORT_UNALIGNED, (long) index * 2, (short) (val & 0xFFFF));
            case Poke4 -> seg.set(ValueLayout.JAVA_INT_UNALIGNED, (long) index * 4, (int) (val & 0xFFFFFFFFL));
            default    -> seg.set(ValueLayout.JAVA_LONG_UNALIGNED, (long) index * 8, val);
        }
    }

    private static Value invokeNativeCFunc(CFuncDef def, Sequence argsSeq, boolean isProc) throws Throwable {
        if (def.cachedHandle == null) {
            if (def.isCompatXstat) {
                // __xstat(int ver, const char* path, struct stat* buf) -> stat(path, buf)
                MethodHandle statMh = NATIVE_LINKER.downcallHandle(
                    def.fnPtr,
                    FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.JAVA_LONG, ValueLayout.JAVA_LONG)
                );
                def.cachedHandle = MethodHandles.dropArguments(statMh, 0, long.class);
            } else {
                MemoryLayout[] paramLayouts = new MemoryLayout[def.argTypes.length];
                for (int i = 0; i < def.argTypes.length; i++) {
                    long at = def.argTypes[i] & 0xFFFFFFFFL;
                    if (at == 0x03000008L) paramLayouts[i] = ValueLayout.JAVA_DOUBLE;
                    else if (at == 0x03000004L) paramLayouts[i] = ValueLayout.JAVA_FLOAT;
                    else paramLayouts[i] = ValueLayout.JAVA_LONG;
                }
                long rt = def.retType & 0xFFFFFFFFL;
                FunctionDescriptor fd;
                if (isProc || rt == 0) {
                    fd = FunctionDescriptor.ofVoid(paramLayouts);
                } else if (rt == 0x03000008L) {
                    fd = FunctionDescriptor.of(ValueLayout.JAVA_DOUBLE, paramLayouts);
                } else if (rt == 0x03000004L) {
                    fd = FunctionDescriptor.of(ValueLayout.JAVA_FLOAT, paramLayouts);
                } else {
                    fd = FunctionDescriptor.of(ValueLayout.JAVA_LONG, paramLayouts);
                }
                def.cachedHandle = NATIVE_LINKER.downcallHandle(def.fnPtr, fd);
            }
        }

        int n = def.argTypes.length;
        Object[] callArgs = new Object[n];
        for (int i = 0; i < n; i++) {
            Value v = (argsSeq != null && i < argsSeq.size()) ? argsSeq.get(i) : Value.fromInt(0);
            long at = def.argTypes[i] & 0xFFFFFFFFL;
            if (!def.isCompatXstat && at == 0x03000008L) {
                callArgs[i] = v.asF64();
            } else if (!def.isCompatXstat && at == 0x03000004L) {
                callArgs[i] = (float) v.asF64();
            } else {
                callArgs[i] = v.toIntCoerce();
            }
        }

        Object resObj = def.cachedHandle.invokeWithArguments(callArgs);
        long rt = def.retType & 0xFFFFFFFFL;
        if (isProc || rt == 0 || resObj == null) {
            return Value.fromInt(0);
        }
        if (resObj instanceof Double d) {
            return Value.fromF64(d);
        }
        if (resObj instanceof Float f) {
            return Value.fromF64(f.doubleValue());
        }
        long rawRet = ((Number) resObj).longValue();
        return switch ((int) rt) {
            case 0x01000001 -> Value.fromInt((byte) (rawRet & 0xFF));
            case 0x02000001 -> Value.fromInt(rawRet & 0xFFL);
            case 0x01000002 -> Value.fromInt((short) (rawRet & 0xFFFF));
            case 0x02000002 -> Value.fromInt(rawRet & 0xFFFFL);
            case 0x01000004 -> Value.fromInt((int) (rawRet & 0xFFFFFFFFL));
            case 0x02000004 -> Value.fromInt(rawRet & 0xFFFFFFFFL);
            default         -> Value.fromInt(rawRet);
        };
    }

    private boolean writeCharsToHandle(long handle, Value v) {
        try {
            if (handle == 1) {
                v.printChars(System.out);
                System.out.flush();
                return true;
            }
            if (handle == 2) {
                v.printChars(System.err);
                System.err.flush();
                return true;
            }
            RandomAccessFile raf = openFiles.get(handle);
            if (raf == null) return false;
            ByteArrayOutputStream bos = new ByteArrayOutputStream(64);
            v.printChars(bos);
            raf.write(bos.toByteArray());
            return true;
        } catch (IOException e) {
            return false;
        }
    }

    private boolean writePrettyToHandle(long handle, Value v) {
        if (handle == 1) {
            v.printPretty(System.out);
            System.out.flush();
            return true;
        }
        if (handle == 2) {
            v.printPretty(System.err);
            System.err.flush();
            return true;
        }
        RandomAccessFile raf = openFiles.get(handle);
        if (raf == null) return false;
        ByteArrayOutputStream bos = new ByteArrayOutputStream(64);
        PrintStream ps = new PrintStream(bos, true, StandardCharsets.UTF_8);
        v.printPretty(ps);
        ps.flush();
        try {
            raf.write(bos.toByteArray());
            return true;
        } catch (IOException e) {
            return false;
        }
    }

    private boolean writeRawBytesToHandle(long handle, byte[] bytes) {
        if (handle == 1) {
            System.out.write(bytes, 0, bytes.length);
            System.out.flush();
            return true;
        }
        if (handle == 2) {
            System.err.write(bytes, 0, bytes.length);
            System.err.flush();
            return true;
        }
        RandomAccessFile raf = openFiles.get(handle);
        if (raf == null) return false;
        try {
            raf.write(bytes);
            return true;
        } catch (IOException e) {
            return false;
        }
    }

    private int runShellCommand(String cmd) {
        try {
            boolean isWin = System.getProperty("os.name", "").toLowerCase().contains("win");
            ProcessBuilder pb = isWin
                ? new ProcessBuilder("cmd.exe", "/c", cmd)
                : new ProcessBuilder("/bin/sh", "-c", cmd);
            pb.inheritIO();
            Map<String, String> env = pb.environment();
            for (String u : envUnset) env.remove(u);
            env.putAll(envOverrides);
            Process p = pb.start();
            return p.waitFor();
        } catch (Exception e) {
            return -1;
        }
    }

    private static Value makeDirEntry(Path p) {
        String name = p.getFileName() != null ? p.getFileName().toString() : p.toString();
        return makeDirEntryWithName(p, name);
    }

    private static Value makeDirEntryWithName(Path p, String name) {
        StringBuilder attrs = new StringBuilder();
        long size = 0;
        ZonedDateTime mtime = ZonedDateTime.of(1970, 1, 1, 0, 0, 0, 0, ZoneId.systemDefault());
        try {
            BasicFileAttributes bfa = Files.readAttributes(p, BasicFileAttributes.class);
            if (bfa.isDirectory()) attrs.append('d');
            if (!Files.isWritable(p)) attrs.append('r');
            size = bfa.size();
            mtime = bfa.lastModifiedTime().toInstant().atZone(ZoneId.systemDefault());
        } catch (IOException ignored) {}

        Sequence entry = new Sequence(11);
        entry.setElement(0, Value.fromString(name));
        entry.setElement(1, Value.fromString(attrs.toString()));
        entry.setElement(2, Value.fromInt(size));
        entry.setElement(3, Value.fromInt(mtime.getYear()));
        entry.setElement(4, Value.fromInt(mtime.getMonthValue()));
        entry.setElement(5, Value.fromInt(mtime.getDayOfMonth()));
        entry.setElement(6, Value.fromInt(mtime.getHour()));
        entry.setElement(7, Value.fromInt(mtime.getMinute()));
        entry.setElement(8, Value.fromInt(mtime.getSecond()));
        entry.setElement(9, Value.fromInt(0));
        entry.setElement(10, Value.fromInt(0));
        return Value.fromSeq(entry);
    }

    private static String translatePosixRegex(String rawPat) {
        StringBuilder sb = new StringBuilder(rawPat.length() + 8);
        for (int i = 0; i < rawPat.length(); i++) {
            char c = rawPat.charAt(i);
            if (c == '[' && i + 1 < rawPat.length()) {
                // Convert POSIX character classes like [[:space:]] to \p{Space} if needed
                if (rawPat.startsWith("[:space:]", i + 1)) {
                    sb.append("[\\s");
                    i += 9;
                    continue;
                }
                if (rawPat.startsWith("[:digit:]", i + 1)) {
                    sb.append("[0-9");
                    i += 9;
                    continue;
                }
                if (rawPat.startsWith("[:alpha:]", i + 1)) {
                    sb.append("[A-Za-z");
                    i += 9;
                    continue;
                }
                if (rawPat.startsWith("[:alnum:]", i + 1)) {
                    sb.append("[A-Za-z0-9");
                    i += 9;
                    continue;
                }
            }
            sb.append(c);
        }
        return sb.toString();
    }

    private boolean execMachine(long funcId, Value arg, Value[] outRes, CallFrame frame, int destAbsReg) {
        outRes[0] = Value.fromInt(0);
        switch ((int) funcId) {
            case 4 -> { // M_SOCK_INFO
                long kind = arg.toIntCoerce();
                if (kind == 1) { // ESOCK_TYPE_AF: {AF_UNIX=1, AF_INET=2, AF_INET6=10, AF_APPLETALK=5, -9999, AF_UNSPEC=0}
                    Sequence seq = new Sequence(6);
                    seq.setElement(0, Value.fromInt(1));
                    seq.setElement(1, Value.fromInt(2));
                    seq.setElement(2, Value.fromInt(10));
                    seq.setElement(3, Value.fromInt(5));
                    seq.setElement(4, Value.fromInt(-9999));
                    seq.setElement(5, Value.fromInt(0));
                    outRes[0] = Value.fromSeq(seq);
                } else if (kind == 2) { // ESOCK_TYPE_TYPE: {SOCK_STREAM=1, SOCK_DGRAM=2, SOCK_RAW=3, SOCK_RDM=4, SOCK_SEQPACKET=5}
                    Sequence seq = new Sequence(5);
                    seq.setElement(0, Value.fromInt(1));
                    seq.setElement(1, Value.fromInt(2));
                    seq.setElement(2, Value.fromInt(3));
                    seq.setElement(3, Value.fromInt(4));
                    seq.setElement(4, Value.fromInt(5));
                    outRes[0] = Value.fromSeq(seq);
                } else if (kind == 3) { // ESOCK_TYPE_OPTION (59 entries)
                    Sequence seq = new Sequence(59, Value.fromInt(-9999));
                    seq.setElement(0, Value.fromInt(1));  // SOL_SOCKET
                    seq.setElement(1, Value.fromInt(1));  // SO_DEBUG
                    seq.setElement(2, Value.fromInt(30)); // SO_ACCEPTCONN
                    seq.setElement(3, Value.fromInt(2));  // SO_REUSEADDR
                    seq.setElement(4, Value.fromInt(9));  // SO_KEEPALIVE
                    seq.setElement(5, Value.fromInt(5));  // SO_DONTROUTE
                    seq.setElement(6, Value.fromInt(6));  // SO_BROADCAST
                    seq.setElement(7, Value.fromInt(13)); // SO_LINGER
                    seq.setElement(8, Value.fromInt(7));  // SO_SNDBUF
                    seq.setElement(9, Value.fromInt(8));  // SO_RCVBUF
                    seq.setElement(10, Value.fromInt(19)); // SO_SNDLOWAT
                    seq.setElement(11, Value.fromInt(18)); // SO_RCVLOWAT
                    seq.setElement(12, Value.fromInt(21)); // SO_SNDTIMEO
                    seq.setElement(13, Value.fromInt(20)); // SO_RCVTIMEO
                    seq.setElement(14, Value.fromInt(4));  // SO_ERROR
                    seq.setElement(15, Value.fromInt(3));  // SO_TYPE
                    seq.setElement(16, Value.fromInt(10)); // SO_OOBINLINE
                    outRes[0] = Value.fromSeq(seq);
                } else {
                    outRes[0] = Value.fromInt(-1);
                }
                return true;
            }
            case 6, 7, 8, 9, 10 -> {
                return true;
            }
            case 12 -> { // M_TEXTROWS
                outRes[0] = Value.fromInt(25);
                return true;
            }
            case 13 -> { // M_VIDEO_CONFIG
                Sequence seq = new Sequence(8, Value.fromInt(0));
                seq.setElement(0, Value.fromInt(1));
                seq.setElement(1, Value.fromInt(3));
                seq.setElement(2, Value.fromInt(25));
                seq.setElement(3, Value.fromInt(80));
                seq.setElement(7, Value.fromInt(1));
                outRes[0] = Value.fromSeq(seq);
                return true;
            }
            case 16 -> { // M_ALLOC
                long sz = Math.max(1L, arg.toIntCoerce());
                try {
                    long ptr = (long) MH_CALLOC.invokeExact(1L, sz);
                    if (ptr != 0) {
                        allocatedPtrs.add(ptr);
                    }
                    outRes[0] = Value.fromInt(ptr);
                } catch (Throwable t) {
                    outRes[0] = Value.fromInt(0);
                }
                return true;
            }
            case 17 -> { // M_FREE
                long ptr = arg.toIntCoerce();
                if (ptr != 0 && allocatedPtrs.remove(ptr)) {
                    try {
                        MH_FREE.invokeExact(ptr);
                    } catch (Throwable ignored) {}
                }
                return true;
            }
            case 19 -> { // M_SEEK: `{fn, pos}`
                if (arg.isSeq() && arg.asSeq().size() >= 2) {
                    long fn = arg.asSeq().get(0).toIntCoerce();
                    long pos = arg.asSeq().get(1).toIntCoerce();
                    RandomAccessFile raf = openFiles.get(fn);
                    if (raf != null) {
                        try {
                            if (pos == -1) raf.seek(raf.length());
                            else raf.seek(pos);
                            outRes[0] = Value.fromInt(0);
                            return true;
                        } catch (IOException ignored) {}
                    }
                }
                outRes[0] = Value.fromInt(1);
                return true;
            }
            case 20 -> { // M_WHERE: `fn`
                RandomAccessFile raf = openFiles.get(arg.toIntCoerce());
                if (raf != null) {
                    try {
                        outRes[0] = Value.fromInt(raf.getFilePointer());
                        return true;
                    } catch (IOException ignored) {}
                }
                outRes[0] = Value.fromInt(-1);
                return true;
            }
            case 22 -> { // M_DIR: `path`
                String pathStr = arg.toUtf8String();
                if (pathStr.isEmpty()) pathStr = ".";
                Path p = resolvePath(pathStr);
                if (!Files.exists(p)) {
                    outRes[0] = Value.fromInt(-1);
                    return true;
                }
                if (Files.isDirectory(p)) {
                    Sequence list = new Sequence();
                    list.addElement(makeDirEntryWithName(p, "."));
                    Path parent = p.toAbsolutePath().getParent();
                    list.addElement(makeDirEntryWithName(parent != null ? parent : p, ".."));
                    try (DirectoryStream<Path> ds = Files.newDirectoryStream(p)) {
                        for (Path child : ds) {
                            list.addElement(makeDirEntry(child));
                        }
                    } catch (IOException e) {
                        outRes[0] = Value.fromInt(-1);
                        return true;
                    }
                    outRes[0] = Value.fromSeq(list);
                } else {
                    Sequence list = new Sequence(1);
                    list.setElement(0, makeDirEntry(p));
                    outRes[0] = Value.fromSeq(list);
                }
                return true;
            }
            case 23 -> { // M_CURRENT_DIR
                outRes[0] = Value.fromString(currentWorkingDir.toString());
                return true;
            }
            case 25 -> { // M_GET_POSITION
                Sequence seq = new Sequence(2);
                seq.setElement(0, Value.fromInt(1));
                seq.setElement(1, Value.fromInt(1));
                outRes[0] = Value.fromSeq(seq);
                return true;
            }
            case 26 -> { // M_WAIT_KEY
                try {
                    int c = System.in.read();
                    outRes[0] = Value.fromInt(c < 0 ? 27 : c);
                } catch (IOException e) {
                    outRes[0] = Value.fromInt(27);
                }
                return true;
            }
            case 27 -> { // M_CREATE_DIRECTORY: path or {path, mode} or {path, mode, mkparent}
                String pathStr;
                int mode = -1;
                boolean mkparent = true;
                if (arg.isSeq() && arg.asSeq().size() > 0 && arg.asSeq().get(0).isSeq()) {
                    pathStr = arg.asSeq().get(0).toUtf8String();
                    if (arg.asSeq().size() >= 2 && arg.asSeq().get(1).isAtom()) {
                        mode = (int) arg.asSeq().get(1).toIntCoerce();
                    }
                    if (arg.asSeq().size() >= 3 && arg.asSeq().get(2).isAtom()) {
                        mkparent = arg.asSeq().get(2).toIntCoerce() != 0;
                    }
                } else {
                    pathStr = arg.toUtf8String();
                }
                if (pathStr.isEmpty() || pathStr.equals(".") || pathStr.equals("..") || pathStr.endsWith("/..") || pathStr.endsWith("/.")) {
                    outRes[0] = Value.fromInt(0);
                    return true;
                }
                try {
                    Path p = resolvePath(pathStr);
                    if (mkparent) {
                        Files.createDirectories(p);
                    } else {
                        Files.createDirectory(p);
                    }
                    if (mode != -1) {
                        try {
                            Set<PosixFilePermission> perms = new HashSet<>();
                            if ((mode & 0400) != 0) perms.add(PosixFilePermission.OWNER_READ);
                            if ((mode & 0200) != 0) perms.add(PosixFilePermission.OWNER_WRITE);
                            if ((mode & 0100) != 0) perms.add(PosixFilePermission.OWNER_EXECUTE);
                            if ((mode & 0040) != 0) perms.add(PosixFilePermission.GROUP_READ);
                            if ((mode & 0020) != 0) perms.add(PosixFilePermission.GROUP_WRITE);
                            if ((mode & 0010) != 0) perms.add(PosixFilePermission.GROUP_EXECUTE);
                            if ((mode & 0004) != 0) perms.add(PosixFilePermission.OTHERS_READ);
                            if ((mode & 0002) != 0) perms.add(PosixFilePermission.OTHERS_WRITE);
                            if ((mode & 0001) != 0) perms.add(PosixFilePermission.OTHERS_EXECUTE);
                            Files.setPosixFilePermissions(p, perms);
                        } catch (UnsupportedOperationException | SecurityException ignored) {}
                    }
                    outRes[0] = Value.fromInt(1);
                } catch (Exception e) {
                    outRes[0] = Value.fromInt(0);
                }
                return true;
            }
            case 28 -> { // M_REMOVE_DIRECTORY: path
                String pathStr = arg.toUtf8String();
                try {
                    Path p = resolvePath(pathStr);
                    if (Files.isDirectory(p)) {
                        try {
                            Files.delete(p);
                            outRes[0] = Value.fromInt(1);
                            return true;
                        } catch (java.nio.file.AccessDeniedException e) {
                            try {
                                p.toFile().setWritable(true);
                                Files.delete(p);
                                outRes[0] = Value.fromInt(1);
                                return true;
                            } catch (Exception ignored) {}
                        }
                    }
                } catch (Exception ignored) {}
                outRes[0] = Value.fromInt(0);
                return true;
            }
            case 29 -> { // M_DELETE_FILE: path
                String pathStr = arg.toUtf8String();
                try {
                    Path p = resolvePath(pathStr);
                    try {
                        boolean deleted = Files.deleteIfExists(p);
                        outRes[0] = Value.fromInt(deleted ? 1 : 0);
                        return true;
                    } catch (java.nio.file.AccessDeniedException e) {
                        try {
                            p.toFile().setWritable(true);
                            boolean deleted = Files.deleteIfExists(p);
                            outRes[0] = Value.fromInt(deleted ? 1 : 0);
                            return true;
                        } catch (Exception ignored) {}
                    }
                } catch (Exception ignored) {}
                outRes[0] = Value.fromInt(0);
                return true;
            }
            case 30 -> { // M_MOVE_FILE: {src, dst} or {src, dst, overwrite}
                if (arg.isSeq() && arg.asSeq().size() >= 2) {
                    String src = arg.asSeq().get(0).toUtf8String();
                    String dst = arg.asSeq().get(1).toUtf8String();
                    boolean overwrite = arg.asSeq().size() > 2 && arg.asSeq().get(2).toIntCoerce() != 0;
                    try {
                        Path srcP = resolvePath(src);
                        Path dstP = resolvePath(dst);
                        if (!Files.exists(srcP)) {
                            outRes[0] = Value.fromInt(0);
                            return true;
                        }
                        if (Files.exists(dstP) && !overwrite) {
                            outRes[0] = Value.fromInt(0);
                            return true;
                        }
                        if (overwrite) {
                            Files.move(srcP, dstP, StandardCopyOption.REPLACE_EXISTING);
                        } else {
                            Files.move(srcP, dstP);
                        }
                        outRes[0] = Value.fromInt(1);
                        return true;
                    } catch (Exception e) {
                        outRes[0] = Value.fromInt(0);
                        return true;
                    }
                }
                outRes[0] = Value.fromInt(0);
                return true;
            }
            case 31 -> { // M_COPY_FILE: {src, dst} or {src, dst, overwrite}
                if (arg.isSeq() && arg.asSeq().size() >= 2) {
                    String src = arg.asSeq().get(0).toUtf8String();
                    String dst = arg.asSeq().get(1).toUtf8String();
                    boolean overwrite = arg.asSeq().size() > 2 && arg.asSeq().get(2).toIntCoerce() != 0;
                    try {
                        Path srcP = resolvePath(src);
                        Path dstP = resolvePath(dst);
                        if (!Files.exists(srcP) || Files.isDirectory(srcP)) {
                            outRes[0] = Value.fromInt(0);
                            return true;
                        }
                        Path parent = dstP.getParent();
                        if (parent != null && Files.exists(parent) && !Files.isWritable(parent)) {
                            outRes[0] = Value.fromInt(0);
                            return true;
                        }
                        if (Files.exists(dstP) && !overwrite) {
                            outRes[0] = Value.fromInt(0);
                            return true;
                        }
                        if (overwrite) {
                            Files.copy(srcP, dstP, StandardCopyOption.REPLACE_EXISTING);
                        } else {
                            Files.copy(srcP, dstP);
                        }
                        outRes[0] = Value.fromInt(1);
                        return true;
                    } catch (Exception e) {
                        outRes[0] = Value.fromInt(0);
                        return true;
                    }
                }
                outRes[0] = Value.fromInt(0);
                return true;
            }
            case 32 -> { // M_FILE_EXISTS: path
                String pathStr = arg.toUtf8String();
                outRes[0] = Value.fromInt(Files.exists(resolvePath(pathStr)) ? 1 : 0);
                return true;
            }
            case 33 -> { // M_NOW_GMT: returns {year, month, day, hour, min, sec}
                ZonedDateTime utc = Instant.now().atZone(java.time.ZoneOffset.UTC);
                Sequence s = new Sequence(6);
                s.setElement(0, Value.fromInt(utc.getYear()));
                s.setElement(1, Value.fromInt(utc.getMonthValue()));
                s.setElement(2, Value.fromInt(utc.getDayOfMonth()));
                s.setElement(3, Value.fromInt(utc.getHour()));
                s.setElement(4, Value.fromInt(utc.getMinute()));
                s.setElement(5, Value.fromInt(utc.getSecond()));
                outRes[0] = Value.fromSeq(s);
                return true;
            }
            case 34 -> { // M_DISK_SIZE: path -> {total_bytes, used_bytes, free_bytes}
                String pathStr = arg.toUtf8String();
                if (pathStr.isEmpty()) pathStr = ".";
                try {
                    Path p = resolvePath(pathStr);
                    FileStore fs = Files.getFileStore(p);
                    long total = fs.getTotalSpace();
                    long free = fs.getUsableSpace();
                    long used = Math.max(0L, total - free);
                    Sequence s = new Sequence(3);
                    s.setElement(0, Value.fromInt(total));
                    s.setElement(1, Value.fromInt(used));
                    s.setElement(2, Value.fromInt(free));
                    outRes[0] = Value.fromSeq(s);
                } catch (Exception e) {
                    Sequence s = new Sequence(3);
                    s.setElement(0, Value.fromInt(0));
                    s.setElement(1, Value.fromInt(0));
                    s.setElement(2, Value.fromInt(0));
                    outRes[0] = Value.fromSeq(s);
                }
                return true;
            }
            case 35 -> { // M_SET_RAND
                if (arg.isAtom()) {
                    rng.setSeed(arg.toIntCoerce());
                } else if (arg.isSeq() && arg.asSeq().size() >= 2) {
                    long s1 = arg.asSeq().get(0).toIntCoerce();
                    long s2 = arg.asSeq().get(1).toIntCoerce();
                    rng.setSeed(s1 ^ (s2 << 32));
                }
                return true;
            }
            case 37 -> { // M_CRASH_MESSAGE
                crashMsg = arg.toUtf8String();
                return true;
            }
            case 46 -> { // M_A_TO_F64
                long bits = Double.doubleToRawLongBits(arg.asF64());
                Sequence seq = new Sequence(8);
                for (int i = 0; i < 8; i++) {
                    seq.setElement(i, Value.fromInt((bits >>> (i * 8)) & 0xFFL));
                }
                outRes[0] = Value.fromSeq(seq);
                return true;
            }
            case 47 -> { // M_F64_TO_A
                if (arg.isSeq() && arg.asSeq().size() >= 8) {
                    long bits = 0;
                    for (int i = 0; i < 8; i++) {
                        bits |= (arg.asSeq().get(i).toIntCoerce() & 0xFFL) << (i * 8);
                    }
                    outRes[0] = Value.fromF64(Double.longBitsToDouble(bits));
                }
                return true;
            }
            case 48 -> { // M_A_TO_F32
                int bits = Float.floatToRawIntBits((float) arg.asF64());
                Sequence seq = new Sequence(4);
                for (int i = 0; i < 4; i++) {
                    seq.setElement(i, Value.fromInt((bits >>> (i * 8)) & 0xFFL));
                }
                outRes[0] = Value.fromSeq(seq);
                return true;
            }
            case 49 -> { // M_F32_TO_A
                if (arg.isSeq() && arg.asSeq().size() >= 4) {
                    int bits = 0;
                    for (int i = 0; i < 4; i++) {
                        bits |= (int) (arg.asSeq().get(i).toIntCoerce() & 0xFFL) << (i * 8);
                    }
                    outRes[0] = Value.fromF64(Float.intBitsToFloat(bits));
                }
                return true;
            }
            case 50 -> { // M_OPEN_DLL
                String path = arg.toUtf8String();
                if (path.toLowerCase().endsWith(".jar")) {
                    boolean ok = JavaInterop.loadJar(path);
                    outRes[0] = Value.fromInt(ok ? 1 : 0);
                    return true;
                }
                if (path.isEmpty() || path.equals("libc.so") || path.equals("libc.so.6") || path.equals("libc.so.7")) {
                    dllLookups.add(DEFAULT_LOOKUP);
                    outRes[0] = Value.fromInt(dllLookups.size());
                    return true;
                }
                try {
                    SymbolLookup lib = SymbolLookup.libraryLookup(path, Arena.global());
                    dllLookups.add(lib);
                    outRes[0] = Value.fromInt(dllLookups.size());
                } catch (IllegalArgumentException e) {
                    outRes[0] = Value.fromInt(0);
                }
                return true;
            }
            case 51 -> { // M_DEFINE_C: `{lib, routine_name, arg_types, return_type}`
                if (!arg.isSeq() || arg.asSeq().size() < 4) {
                    outRes[0] = Value.fromInt(-1);
                    return true;
                }
                Sequence s = arg.asSeq();
                Value libV = s.get(0);
                Value nameV = s.get(1);
                Value argsV = s.get(2);
                Value retV = s.get(3);

                MemorySegment fnPtr = null;
                boolean isCompatXstat = false;
                if (nameV.isAtom()) {
                    long addr = nameV.toIntCoerce();
                    if (addr != 0) fnPtr = MemorySegment.ofAddress(addr);
                } else if (nameV.isSeq()) {
                    String symName = nameV.toUtf8String();
                    if (!symName.isEmpty() && symName.charAt(0) == '+') {
                        symName = symName.substring(1);
                    }
                    long libId = libV.isAtom() ? libV.toIntCoerce() : 0;
                    if (libId >= 1 && libId <= dllLookups.size()) {
                        fnPtr = dllLookups.get((int) (libId - 1)).find(symName).orElse(null);
                    }
                    if (fnPtr == null) {
                        fnPtr = DEFAULT_LOOKUP.find(symName).orElse(null);
                    }
                    if (fnPtr == null && symName.equals("__xstat")) {
                        fnPtr = DEFAULT_LOOKUP.find("stat").orElse(null);
                        isCompatXstat = (fnPtr != null);
                    }
                }
                if (fnPtr == null) {
                    outRes[0] = Value.fromInt(-1);
                    return true;
                }
                long[] argTypes;
                if (argsV.isSeq()) {
                    Sequence as = argsV.asSeq();
                    argTypes = new long[as.size()];
                    for (int i = 0; i < as.size(); i++) argTypes[i] = as.get(i).toIntCoerce();
                } else {
                    argTypes = new long[0];
                }
                CFuncDef def = new CFuncDef(fnPtr, argTypes, retV.toIntCoerce(), isCompatXstat);
                cRoutines.add(def);
                outRes[0] = Value.fromInt(cRoutines.size());
                return true;
            }
            case 52 -> { // M_CALLBACK
                long rid = 0;
                if (arg.isAtom()) rid = arg.toIntCoerce();
                else if (arg.isSeq() && arg.asSeq().size() >= 2) rid = arg.asSeq().get(1).toIntCoerce();
                outRes[0] = Value.fromInt(0xCB000000L + rid);
                return true;
            }
            case 55 -> { // M_INSTANCE
                outRes[0] = Value.fromInt(ProcessHandle.current().pid());
                return true;
            }
            case 56 -> { // M_DEFINE_VAR: `{lib, var_name}`
                if (!arg.isSeq() || arg.asSeq().size() < 2) {
                    outRes[0] = Value.fromInt(-1);
                    return true;
                }
                Sequence s = arg.asSeq();
                long libId = s.get(0).isAtom() ? s.get(0).toIntCoerce() : 0;
                String vname = s.get(1).toUtf8String();
                if (!vname.isEmpty() && vname.charAt(0) == '+') vname = vname.substring(1);
                MemorySegment seg = null;
                if (libId >= 1 && libId <= dllLookups.size()) {
                    seg = dllLookups.get((int) (libId - 1)).find(vname).orElse(null);
                }
                if (seg == null) {
                    seg = DEFAULT_LOOKUP.find(vname).orElse(null);
                }
                outRes[0] = Value.fromInt(seg != null ? seg.address() : -1L);
                return true;
            }
            case 57, 66, 72 -> {
                outRes[0] = Value.fromInt(0);
                return true;
            }
            case 60 -> { // M_FLUSH
                long h = arg.toIntCoerce();
                if (h == 1) System.out.flush();
                else if (h == 2) System.err.flush();
                else {
                    RandomAccessFile raf = openFiles.get(h);
                    if (raf != null) {
                        try { raf.getFD().sync(); } catch (IOException ignored) {}
                    }
                }
                return true;
            }
            case 61 -> { // M_LOCK_FILE: {fn, lock_type, byte_range}
                if (arg.isSeq() && arg.asSeq().length() >= 2) {
                    long fn = arg.asSeq().get(0).toIntCoerce();
                    long ltype = arg.asSeq().get(1).toIntCoerce();
                    RandomAccessFile raf = openFiles.get(fn);
                    if (raf != null) {
                        try {
                            boolean shared = (ltype == 1);
                            java.nio.channels.FileLock fl = raf.getChannel().tryLock(0L, Long.MAX_VALUE, shared);
                            if (fl != null) {
                                fileLocks.put(fn, fl);
                                outRes[0] = Value.fromInt(1);
                                return true;
                            }
                        } catch (Exception ignored) {
                        }
                    }
                }
                outRes[0] = Value.fromInt(0);
                return true;
            }
            case 62 -> { // M_UNLOCK_FILE: {fn, byte_range}
                long fn = -1;
                if (arg.isSeq() && arg.asSeq().length() >= 1) {
                    fn = arg.asSeq().get(0).toIntCoerce();
                } else if (arg.isAtom()) {
                    fn = arg.toIntCoerce();
                }
                if (fn >= 0) {
                    java.nio.channels.FileLock fl = fileLocks.remove(fn);
                    if (fl != null) {
                        try {
                            fl.release();
                        } catch (Exception ignored) {}
                    }
                }
                outRes[0] = Value.fromInt(1);
                return true;
            }
            case 63 -> { // M_CHDIR
                Path p = resolvePath(arg.toUtf8String());
                if (Files.isDirectory(p)) {
                    this.currentWorkingDir = p;
                    outRes[0] = Value.fromInt(1);
                } else {
                    outRes[0] = Value.fromInt(0);
                }
                return true;
            }
            case 64 -> { // M_SLEEP
                double secs = arg.asF64();
                if (secs > 0.0) {
                    try {
                        Thread.sleep((long) (secs * 1000.0));
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                    }
                }
                return true;
            }
            case 67 -> { // M_CRASH
                runtimeError(frame, "crash(): " + arg.toUtf8String());
                return false;
            }
            case 68 -> { // M_PCRE_COMPILE: `{pattern, options}`
                if (!arg.isSeq() || arg.asSeq().size() < 2) {
                    outRes[0] = Value.fromInt(0);
                    return true;
                }
                String rawPat = arg.asSeq().get(0).toUtf8String();
                String translated = translatePosixRegex(rawPat);
                long opts = arg.asSeq().get(1).toIntCoerce();
                int flags = 0;
                if ((opts & 1) != 0) flags |= Pattern.CASE_INSENSITIVE;
                if ((opts & 2) != 0) flags |= Pattern.MULTILINE;
                if ((opts & 4) != 0) flags |= Pattern.DOTALL;
                if ((opts & 8) != 0) flags |= Pattern.COMMENTS;
                try {
                    Pattern pat = Pattern.compile(translated, flags);
                    lastRegexError = "";
                    CompiledRegex cr = new CompiledRegex(translated, pat);
                    compiledRegexes.add(cr);
                    int reId = compiledRegexes.size() - 1;
                    Value seqV = Value.fromString(translated);
                    seqV.asSeq().regexId = reId;
                    outRes[0] = seqV;
                } catch (Exception e) {
                    lastRegexError = e.getMessage() != null ? e.getMessage() : "Regex compile error";
                    outRes[0] = Value.fromInt(0);
                }
                return true;
            }
            case 70 -> { // M_PCRE_EXEC: `{re, haystack_or_ptr, str_len, options, start_from, size}`
                if (!arg.isSeq() || arg.asSeq().size() < 6) {
                    outRes[0] = Value.fromInt(-1);
                    return true;
                }
                Sequence s = arg.asSeq();
                if (!s.get(0).isSeq()) {
                    outRes[0] = Value.fromInt(-4); // ERROR_BADMAGIC
                    return true;
                }
                int reId = s.get(0).asSeq().regexId;
                if (reId < 0 || reId >= compiledRegexes.size()) {
                    outRes[0] = Value.fromInt(-4);
                    return true;
                }
                CompiledRegex cr = compiledRegexes.get(reId);

                byte[] subjectBytes;
                if (s.get(1).isSeq()) {
                    subjectBytes = s.get(1).toRawBytes();
                } else {
                    long addr = s.get(1).toIntCoerce();
                    int len = (int) Math.max(0L, s.get(2).toIntCoerce());
                    if (addr == 0) {
                        outRes[0] = Value.fromInt(-1);
                        return true;
                    }
                    subjectBytes = MemorySegment.ofAddress(addr).reinterpret(len).toArray(ValueLayout.JAVA_BYTE);
                }

                int startFrom = (int) Math.max(1L, s.get(4).toIntCoerce()) - 1;
                if (startFrom > subjectBytes.length) {
                    outRes[0] = Value.fromInt(-1);
                    return true;
                }

                // Use ISO_8859_1 1:1 byte-to-char mapping so byte offsets match 1-based Euphoria indices
                String hayIso = new String(subjectBytes, StandardCharsets.ISO_8859_1);
                Matcher m = cr.pattern.matcher(hayIso);
                if (!m.find(startFrom)) {
                    outRes[0] = Value.fromInt(-1);
                    return true;
                }
                int nmatch = m.groupCount() + 1;
                Sequence matches = new Sequence(nmatch);
                for (int i = 0; i < nmatch; i++) {
                    Sequence pair = new Sequence(2);
                    int st = m.start(i);
                    int en = m.end(i);
                    if (st >= 0) {
                        pair.setElement(0, Value.fromInt(st + 1));
                        pair.setElement(1, Value.fromInt(en));
                    } else {
                        pair.setElement(0, Value.fromInt(0));
                        pair.setElement(1, Value.fromInt(0));
                    }
                    matches.setElement(i, Value.fromSeq(pair));
                }
                outRes[0] = Value.fromSeq(matches);
                return true;
            }
            case 71 -> { // M_PCRE_REPLACE: `{re, subject, replacement, options, start_from, limit}`
                if (!arg.isSeq() || arg.asSeq().size() < 6) {
                    outRes[0] = Value.fromInt(0);
                    return true;
                }
                Sequence s = arg.asSeq();
                if (!s.get(0).isSeq()) {
                    outRes[0] = Value.fromInt(0);
                    return true;
                }
                int reId = s.get(0).asSeq().regexId;
                if (reId < 0 || reId >= compiledRegexes.size()) {
                    outRes[0] = Value.fromInt(0);
                    return true;
                }
                CompiledRegex cr = compiledRegexes.get(reId);
                String str = new String(s.get(1).toRawBytes(), StandardCharsets.ISO_8859_1);
                String rep = new String(s.get(2).toRawBytes(), StandardCharsets.ISO_8859_1);
                int pos = (int) Math.max(1L, s.get(4).toIntCoerce()) - 1;
                long limit = s.get(5).toIntCoerce();
                if (limit <= 0) limit = Long.MAX_VALUE;

                StringBuilder out = new StringBuilder(str.length() + 16);
                out.append(str, 0, Math.min(pos, str.length()));
                Matcher m = cr.pattern.matcher(str);

                while (pos <= str.length() && limit > 0) {
                    if (!m.find(pos)) break;
                    out.append(str, pos, m.start());
                    int nmatch = m.groupCount() + 1;
                    for (int ri = 0; ri < rep.length(); ri++) {
                        char c = rep.charAt(ri);
                        if (c == '\\' && ri + 1 < rep.length()) {
                            char nc = rep.charAt(++ri);
                            if (nc >= '0' && nc <= '9') {
                                int g = nc - '0';
                                if (g < nmatch && m.start(g) >= 0) {
                                    out.append(str, m.start(g), m.end(g));
                                }
                            } else if (nc == 'n') out.append('\n');
                            else if (nc == 'r') out.append('\r');
                            else if (nc == 't') out.append('\t');
                            else out.append(nc);
                        } else {
                            out.append(c);
                        }
                    }
                    int nextPos = m.end();
                    if (nextPos == pos) {
                        if (pos < str.length()) out.append(str.charAt(pos));
                        pos++;
                    } else {
                        pos = nextPos;
                    }
                    limit--;
                }
                if (pos < str.length()) {
                    out.append(str.substring(pos));
                }
                outRes[0] = Value.fromRawBytes(out.toString().getBytes(StandardCharsets.ISO_8859_1));
                return true;
            }
            case 73 -> { // M_SET_ENV: `{name, val, overwrite}`
                if (arg.isSeq() && arg.asSeq().size() >= 2) {
                    String k = arg.asSeq().get(0).toUtf8String();
                    String v = arg.asSeq().get(1).toUtf8String();
                    int ov = (arg.asSeq().size() >= 3) ? (int) arg.asSeq().get(2).toIntCoerce() : 1;
                    boolean exists = !envUnset.contains(k) && (envOverrides.containsKey(k) || System.getenv(k) != null);
                    if (ov != 0 || !exists) {
                        envUnset.remove(k);
                        envOverrides.put(k, v);
                        if (MH_SETENV != null) {
                            try (Arena arena = Arena.ofConfined()) {
                                MH_SETENV.invokeExact(arena.allocateFrom(k), arena.allocateFrom(v), ov);
                            } catch (Throwable ignored) {}
                        }
                    }
                    outRes[0] = Value.fromInt(1);
                }
                return true;
            }
            case 74 -> { // M_UNSET_ENV: `{name}` or `name`
                Value kVal = (arg.isSeq() && arg.asSeq().size() > 0 && arg.asSeq().get(0).isSeq())
                    ? arg.asSeq().get(0)
                    : arg;
                String k = kVal.toUtf8String();
                envOverrides.remove(k);
                envUnset.add(k);
                if (MH_UNSETENV != null) {
                    try (Arena arena = Arena.ofConfined()) {
                        MH_UNSETENV.invokeExact(arena.allocateFrom(k));
                    } catch (Throwable ignored) {}
                }
                outRes[0] = Value.fromInt(1);
                return true;
            }
            case 75 -> { // M_EU_INFO
                Sequence seq = new Sequence(8);
                seq.setElement(0, Value.fromInt(4));
                seq.setElement(1, Value.fromInt(1));
                seq.setElement(2, Value.fromInt(0));
                seq.setElement(3, Value.fromString("release"));
                seq.setElement(4, Value.fromString("intpret-jdk25"));
                seq.setElement(5, Value.fromInt(1));
                seq.setElement(6, Value.fromString("2026-11-07"));
                seq.setElement(7, Value.fromF64(0.0));
                outRes[0] = Value.fromSeq(seq);
                return true;
            }
            case 76 -> { // M_UNAME
                Sequence seq = new Sequence(6);
                seq.setElement(0, Value.fromString("Linux"));
                String host = "localhost";
                try { host = InetAddress.getLocalHost().getHostName(); } catch (Exception ignored) {}
                seq.setElement(1, Value.fromString(host));
                seq.setElement(2, Value.fromString(System.getProperty("os.version", "6.0")));
                seq.setElement(3, Value.fromString("#1 SMP"));
                seq.setElement(4, Value.fromString(System.getProperty("os.arch", "x86_64")));
                seq.setElement(5, Value.fromString(""));
                outRes[0] = Value.fromSeq(seq);
                return true;
            }
            case 77 -> { // M_SOCK_GETSERVBYNAME
                if (!arg.isSeq() || arg.asSeq().size() == 0 || !arg.asSeq().get(0).isSeq()) {
                    outRes[0] = Value.fromInt(-15);
                    return true;
                }
                Sequence s = arg.asSeq();
                String name = s.get(0).toUtf8String();
                String proto = (s.size() >= 2 && s.get(1).isSeq()) ? s.get(1).toUtf8String() : "tcp";
                int port = switch (name.toLowerCase(Locale.ROOT)) {
                    case "http" -> 80;
                    case "https" -> 443;
                    case "ssh" -> 22;
                    case "telnet" -> 23;
                    case "echo" -> 7;
                    case "ftp" -> 21;
                    case "smtp" -> 25;
                    case "domain", "dns" -> 53;
                    case "postgresql", "postgres" -> 5432;
                    default -> -1;
                };
                if (port < 0) {
                    outRes[0] = Value.fromInt(-28);
                    return true;
                }
                Sequence res = new Sequence(3);
                res.setElement(0, Value.fromString(name));
                res.setElement(1, Value.fromString(proto.isEmpty() ? "tcp" : proto));
                res.setElement(2, Value.fromInt(port));
                outRes[0] = Value.fromSeq(res);
                return true;
            }
            case 78 -> { // M_SOCK_GETSERVBYPORT
                if (!arg.isSeq() || arg.asSeq().size() == 0) {
                    outRes[0] = Value.fromInt(-15);
                    return true;
                }
                Sequence s = arg.asSeq();
                int port = (int) s.get(0).toIntCoerce();
                String proto = (s.size() >= 2 && s.get(1).isSeq()) ? s.get(1).toUtf8String() : "tcp";
                String name = switch (port) {
                    case 80 -> "http";
                    case 443 -> "https";
                    case 22 -> "ssh";
                    case 23 -> "telnet";
                    case 7 -> "echo";
                    case 21 -> "ftp";
                    case 25 -> "smtp";
                    case 53 -> "domain";
                    case 5432 -> "postgresql";
                    default -> "";
                };
                if (name.isEmpty()) {
                    outRes[0] = Value.fromInt(-28);
                    return true;
                }
                Sequence res = new Sequence(3);
                res.setElement(0, Value.fromString(name));
                res.setElement(1, Value.fromString(proto.isEmpty() ? "tcp" : proto));
                res.setElement(2, Value.fromInt(port));
                outRes[0] = Value.fromSeq(res);
                return true;
            }
            case 79, 80 -> { // M_SOCK_GETHOSTBYNAME / M_SOCK_GETHOSTBYADDR
                if (!arg.isSeq() || arg.asSeq().size() == 0 || !arg.asSeq().get(0).isSeq()) {
                    outRes[0] = Value.fromInt(-11);
                    return true;
                }
                String host = arg.asSeq().get(0).toUtf8String();
                try {
                    InetAddress[] addrs = InetAddress.getAllByName(host);
                    if (addrs == null || addrs.length == 0) {
                        outRes[0] = Value.fromInt(-12);
                        return true;
                    }
                    String canon = addrs[0].getCanonicalHostName();
                    int addrType = (addrs[0] instanceof Inet6Address) ? 10 : 2;
                    Sequence ips = new Sequence();
                    Set<String> seen = new HashSet<>();
                    for (InetAddress ia : addrs) {
                        String ip = ia.getHostAddress();
                        if (seen.add(ip)) {
                            ips.addElement(Value.fromString(ip));
                        }
                    }
                    Sequence res = new Sequence(4);
                    res.setElement(0, Value.fromString(canon));
                    res.setElement(1, Value.emptySeq());
                    res.setElement(2, Value.fromSeq(ips));
                    res.setElement(3, Value.fromInt(addrType));
                    outRes[0] = Value.fromSeq(res);
                } catch (UnknownHostException e) {
                    outRes[0] = Value.fromInt(-12);
                }
                return true;
            }
            case 81 -> { // M_SOCK_SOCKET: `{family, sock_type, protocol}` -> `{id, 0}`
                if (arg.isSeq() && arg.asSeq().size() >= 3) {
                    Sequence s = arg.asSeq();
                    int af = (int) s.get(0).toIntCoerce();
                    int type = (int) s.get(1).toIntCoerce();
                    long sockId = nextSocketId.getAndIncrement();
                    ManagedSocket ms = new ManagedSocket(sockId, af, type);
                    try {
                        ProtocolFamily pf = (af == 10) ? StandardProtocolFamily.INET6 : StandardProtocolFamily.INET;
                        if (type == 2) { // SOCK_DGRAM
                            ms.udpChan = DatagramChannel.open(pf);
                            ms.udpChan.configureBlocking(true);
                        } else { // SOCK_STREAM
                            ms.tcpClient = SocketChannel.open(pf);
                            ms.tcpClient.configureBlocking(true);
                        }
                        openSockets.put(sockId, ms);
                        Sequence res = new Sequence(2);
                        res.setElement(0, Value.fromInt(sockId));
                        res.setElement(1, Value.fromInt(0));
                        outRes[0] = Value.fromSeq(res);
                    } catch (IOException e) {
                        outRes[0] = Value.fromInt(-15);
                    }
                }
                return true;
            }
            case 82 -> { // M_SOCK_CLOSE: `{sock}`
                if (arg.isSeq() && arg.asSeq().size() > 0 && arg.asSeq().get(0).isSeq()) {
                    long sockId = arg.asSeq().get(0).asSeq().get(0).toIntCoerce();
                    ManagedSocket ms = openSockets.remove(sockId);
                    if (ms != null) {
                        ms.closeQuietly();
                    }
                    outRes[0] = Value.fromInt(0);
                }
                return true;
            }
            case 83 -> { // M_SOCK_SHUTDOWN: `{sock, method}`
                if (arg.isSeq() && arg.asSeq().size() >= 2 && arg.asSeq().get(0).isSeq()) {
                    long sockId = arg.asSeq().get(0).asSeq().get(0).toIntCoerce();
                    int how = (int) arg.asSeq().get(1).toIntCoerce();
                    ManagedSocket ms = openSockets.get(sockId);
                    if (ms != null && ms.tcpClient != null) {
                        try {
                            if (how == 0 || how == 2) ms.tcpClient.shutdownInput();
                            if (how == 1 || how == 2) ms.tcpClient.shutdownOutput();
                        } catch (IOException ignored) {}
                    }
                    outRes[0] = Value.fromInt(0);
                }
                return true;
            }
            case 84 -> { // M_SOCK_CONNECT: `{sock, address_str, port}`
                if (!arg.isSeq() || arg.asSeq().size() < 3 || !arg.asSeq().get(0).isSeq()) {
                    outRes[0] = Value.fromInt(-15);
                    return true;
                }
                Sequence s = arg.asSeq();
                long sockId = s.get(0).asSeq().get(0).toIntCoerce();
                String host = s.get(1).toUtf8String();
                int port = (int) s.get(2).toIntCoerce();
                ManagedSocket ms = openSockets.get(sockId);
                if (ms == null) {
                    outRes[0] = Value.fromInt(-32);
                    return true;
                }
                try {
                    if (host.isEmpty()) host = (ms.family == 10) ? "::1" : "127.0.0.1";
                    InetSocketAddress isa = new InetSocketAddress(InetAddress.getByName(host), port);
                    if (ms.tcpClient != null) {
                        if (!ms.tcpClient.isOpen()) {
                            ProtocolFamily pf = (ms.family == 10) ? StandardProtocolFamily.INET6 : StandardProtocolFamily.INET;
                            ms.tcpClient = SocketChannel.open(pf);
                            ms.tcpClient.configureBlocking(true);
                        }
                        ms.tcpClient.connect(isa);
                    } else if (ms.udpChan != null) {
                        ms.udpChan.connect(isa);
                    }
                    outRes[0] = Value.fromInt(0);
                } catch (IOException e) {
                    try {
                        if (ms.tcpClient != null) {
                            ProtocolFamily pf = (ms.family == 10) ? StandardProtocolFamily.INET6 : StandardProtocolFamily.INET;
                            ms.tcpClient = SocketChannel.open(pf);
                            ms.tcpClient.configureBlocking(true);
                        }
                    } catch (IOException ignored) {}
                    outRes[0] = Value.fromInt(-8);
                }
                return true;
            }
            case 85 -> { // M_SOCK_SEND: `{sock, data_seq, flags}`
                if (!arg.isSeq() || arg.asSeq().size() < 3 || !arg.asSeq().get(0).isSeq()) {
                    outRes[0] = Value.fromInt(-15);
                    return true;
                }
                Sequence s = arg.asSeq();
                long sockId = s.get(0).asSeq().get(0).toIntCoerce();
                byte[] data = s.get(1).toRawBytes();
                ManagedSocket ms = openSockets.get(sockId);
                if (ms == null || ms.tcpClient == null) {
                    outRes[0] = Value.fromInt(-32);
                    return true;
                }
                try {
                    ByteBuffer buf = ByteBuffer.wrap(data);
                    int total = 0;
                    while (buf.hasRemaining()) {
                        int n = ms.tcpClient.write(buf);
                        if (n <= 0) break;
                        total += n;
                    }
                    outRes[0] = Value.fromInt(total);
                } catch (IOException e) {
                    outRes[0] = Value.fromInt(-9);
                }
                return true;
            }
            case 86 -> { // M_SOCK_RECV: `{sock, flags}`
                if (!arg.isSeq() || arg.asSeq().size() < 2 || !arg.asSeq().get(0).isSeq()) {
                    outRes[0] = Value.fromInt(-15);
                    return true;
                }
                Sequence s = arg.asSeq();
                long sockId = s.get(0).asSeq().get(0).toIntCoerce();
                ManagedSocket ms = openSockets.get(sockId);
                if (ms == null || ms.tcpClient == null) {
                    outRes[0] = Value.fromInt(-32);
                    return true;
                }
                try {
                    ByteBuffer buf = ByteBuffer.allocate(8192);
                    int got = ms.tcpClient.read(buf);
                    if (got < 0) {
                        outRes[0] = Value.emptySeq();
                    } else {
                        byte[] bytes = new byte[got];
                        buf.flip();
                        buf.get(bytes);
                        outRes[0] = Value.fromRawBytes(bytes);
                    }
                } catch (IOException e) {
                    outRes[0] = Value.fromInt(-9);
                }
                return true;
            }
            case 87 -> { // M_SOCK_BIND: `{sock, address_str, port}`
                if (!arg.isSeq() || arg.asSeq().size() < 3 || !arg.asSeq().get(0).isSeq()) {
                    outRes[0] = Value.fromInt(-15);
                    return true;
                }
                Sequence s = arg.asSeq();
                long sockId = s.get(0).asSeq().get(0).toIntCoerce();
                String host = s.get(1).toUtf8String();
                int port = (int) s.get(2).toIntCoerce();
                ManagedSocket ms = openSockets.get(sockId);
                if (ms == null) {
                    outRes[0] = Value.fromInt(-32);
                    return true;
                }
                try {
                    if (host.isEmpty()) host = (ms.family == 10) ? "::" : "0.0.0.0";
                    InetSocketAddress isa = new InetSocketAddress(InetAddress.getByName(host), port);
                    if (ms.sockType == 2 && ms.udpChan != null) {
                        ms.udpChan.setOption(StandardSocketOptions.SO_REUSEADDR, ms.reuseAddr);
                        ms.udpChan.bind(isa);
                    } else {
                        if (ms.tcpClient != null) {
                            ms.tcpClient.close();
                            ms.tcpClient = null;
                        }
                        ProtocolFamily pf = (ms.family == 10) ? StandardProtocolFamily.INET6 : StandardProtocolFamily.INET;
                        ms.tcpServer = ServerSocketChannel.open(pf);
                        ms.tcpServer.configureBlocking(true);
                        ms.tcpServer.setOption(StandardSocketOptions.SO_REUSEADDR, ms.reuseAddr);
                        ms.tcpServer.bind(isa, 64);
                    }
                    outRes[0] = Value.fromInt(0);
                } catch (IOException e) {
                    outRes[0] = Value.fromInt(-2);
                }
                return true;
            }
            case 88 -> { // M_SOCK_LISTEN: `{sock, backlog}`
                if (!arg.isSeq() || arg.asSeq().size() < 2 || !arg.asSeq().get(0).isSeq()) {
                    outRes[0] = Value.fromInt(-15);
                    return true;
                }
                outRes[0] = Value.fromInt(0);
                return true;
            }
            case 89 -> { // M_SOCK_ACCEPT: `{sock}` -> `{{client_id, 0}, client_ip_str}`
                if (!arg.isSeq() || arg.asSeq().size() == 0 || !arg.asSeq().get(0).isSeq()) {
                    outRes[0] = Value.fromInt(-15);
                    return true;
                }
                long srvId = arg.asSeq().get(0).asSeq().get(0).toIntCoerce();
                ManagedSocket srvMs = openSockets.get(srvId);
                if (srvMs == null || srvMs.tcpServer == null) {
                    outRes[0] = Value.fromInt(-32);
                    return true;
                }
                try {
                    SocketChannel clientChan = srvMs.tcpServer.accept();
                    if (clientChan == null) {
                        outRes[0] = Value.fromInt(-5);
                        return true;
                    }
                    clientChan.configureBlocking(true);
                    long clientId = nextSocketId.getAndIncrement();
                    ManagedSocket cliMs = new ManagedSocket(clientId, srvMs.family, 1);
                    cliMs.tcpClient = clientChan;
                    openSockets.put(clientId, cliMs);

                    String clientIp = "127.0.0.1";
                    if (clientChan.getRemoteAddress() instanceof InetSocketAddress raddr && raddr.getAddress() != null) {
                        clientIp = formatIpAddress(raddr.getAddress());
                    }

                    Sequence clientSock = new Sequence(2);
                    clientSock.setElement(0, Value.fromInt(clientId));
                    clientSock.setElement(1, Value.fromInt(0));

                    Sequence res = new Sequence(2);
                    res.setElement(0, Value.fromSeq(clientSock));
                    res.setElement(1, Value.fromString(clientIp));
                    outRes[0] = Value.fromSeq(res);
                } catch (IOException e) {
                    outRes[0] = Value.fromInt(-15);
                }
                return true;
            }
            case 90 -> { // M_SOCK_SETSOCKOPT: `{sock, level, optname, val}`
                if (!arg.isSeq() || arg.asSeq().size() < 4 || !arg.asSeq().get(0).isSeq()) {
                    outRes[0] = Value.fromInt(-15);
                    return true;
                }
                Sequence s = arg.asSeq();
                long sockId = s.get(0).asSeq().get(0).toIntCoerce();
                int optname = (int) s.get(2).toIntCoerce();
                int optval = (int) s.get(3).toIntCoerce();
                ManagedSocket ms = openSockets.get(sockId);
                if (ms != null) {
                    ms.options.put(optname, optval);
                    ms.reuseAddr = (optval != 0);
                }
                outRes[0] = Value.fromInt(1);
                return true;
            }
            case 91 -> { // M_SOCK_GETSOCKOPT: `{sock, level, optname}`
                if (!arg.isSeq() || arg.asSeq().size() < 3 || !arg.asSeq().get(0).isSeq()) {
                    outRes[0] = Value.fromInt(-15);
                    return true;
                }
                Sequence s = arg.asSeq();
                long sockId = s.get(0).asSeq().get(0).toIntCoerce();
                int optname = (int) s.get(2).toIntCoerce();
                ManagedSocket ms = openSockets.get(sockId);
                if (ms != null) {
                    if (optname == 3) { // SO_TYPE
                        outRes[0] = Value.fromInt(ms.sockType);
                    } else {
                        outRes[0] = Value.fromInt(ms.options.getOrDefault(optname, 0));
                    }
                } else {
                    outRes[0] = Value.fromInt(0);
                }
                return true;
            }
            case 92 -> { // M_SOCK_SELECT: `{read_socks, write_socks, err_socks, all_socks, timeout_usec, timeout_sec}`
                if (!arg.isSeq() || arg.asSeq().size() < 6) {
                    outRes[0] = Value.fromInt(-15);
                    return true;
                }
                Sequence s = arg.asSeq();
                Sequence rList = s.get(0).isSeq() ? s.get(0).asSeq() : null;
                Sequence wList = s.get(1).isSeq() ? s.get(1).asSeq() : null;
                Sequence aList = s.get(3).isSeq() ? s.get(3).asSeq() : null;
                long usec = s.get(4).toIntCoerce();
                long sec = s.get(5).toIntCoerce();
                long timeoutMs = Math.max(1L, sec * 1000L + usec / 1000L);

                if (aList == null || aList.size() == 0) {
                    outRes[0] = Value.emptySeq();
                    return true;
                }

                // Wait slightly if needed so loopback connections become ready
                try { Thread.sleep(Math.min(10L, timeoutMs)); } catch (InterruptedException ignored) {}

                Sequence res = new Sequence(aList.size());
                for (int i = 0; i < aList.size(); i++) {
                    Value sockVal = aList.get(i);
                    long id = sockVal.isSeq() && sockVal.asSeq().size() > 0 ? sockVal.asSeq().get(0).toIntCoerce() : -1;
                    boolean wantRead = listContainsSocket(rList, id);
                    boolean wantWrite = listContainsSocket(wList, id);

                    Sequence item = new Sequence(4);
                    item.setElement(0, sockVal);
                    item.setElement(1, Value.fromInt(wantRead ? 1 : 0));
                    item.setElement(2, Value.fromInt(wantWrite ? 1 : 0));
                    item.setElement(3, Value.fromInt(0));
                    res.setElement(i, Value.fromSeq(item));
                }
                outRes[0] = Value.fromSeq(res);
                return true;
            }
            case 93 -> { // M_SOCK_SENDTO: `{sock, data, flags, address_str, port}`
                if (!arg.isSeq() || arg.asSeq().size() < 5 || !arg.asSeq().get(0).isSeq()) {
                    outRes[0] = Value.fromInt(-15);
                    return true;
                }
                Sequence s = arg.asSeq();
                long sockId = s.get(0).asSeq().get(0).toIntCoerce();
                byte[] data = s.get(1).toRawBytes();
                String host = s.get(3).toUtf8String();
                int port = (int) s.get(4).toIntCoerce();
                ManagedSocket ms = openSockets.get(sockId);
                if (ms == null || ms.udpChan == null) {
                    outRes[0] = Value.fromInt(-32);
                    return true;
                }
                try {
                    if (host.isEmpty()) host = (ms.family == 10) ? "::1" : "127.0.0.1";
                    InetSocketAddress target = new InetSocketAddress(InetAddress.getByName(host), port);
                    int sent = ms.udpChan.send(ByteBuffer.wrap(data), target);
                    outRes[0] = Value.fromInt(sent);
                } catch (IOException e) {
                    outRes[0] = Value.fromInt(-15);
                }
                return true;
            }
            case 94 -> { // M_SOCK_RECVFROM: `{sock, flags}` -> `{client_ip, client_port, data}`
                if (!arg.isSeq() || arg.asSeq().size() < 2 || !arg.asSeq().get(0).isSeq()) {
                    outRes[0] = Value.fromInt(-15);
                    return true;
                }
                Sequence s = arg.asSeq();
                long sockId = s.get(0).asSeq().get(0).toIntCoerce();
                ManagedSocket ms = openSockets.get(sockId);
                if (ms == null || ms.udpChan == null) {
                    outRes[0] = Value.fromInt(-32);
                    return true;
                }
                try {
                    ByteBuffer buf = ByteBuffer.allocate(8192);
                    SocketAddress sa = ms.udpChan.receive(buf);
                    if (!(sa instanceof InetSocketAddress isa)) {
                        outRes[0] = Value.fromInt(-15);
                        return true;
                    }
                    buf.flip();
                    byte[] bytes = new byte[buf.remaining()];
                    buf.get(bytes);
                    String peerIp = formatIpAddress(isa.getAddress());
                    Sequence res = new Sequence(3);
                    res.setElement(0, Value.fromString(peerIp));
                    res.setElement(1, Value.fromInt(isa.getPort()));
                    res.setElement(2, Value.fromRawBytes(bytes));
                    outRes[0] = Value.fromSeq(res);
                } catch (IOException e) {
                    outRes[0] = Value.fromInt(-15);
                }
                return true;
            }
            case 95 -> { // M_PCRE_ERROR_MESSAGE
                if (lastRegexError.isEmpty()) {
                    outRes[0] = Value.fromInt(0);
                } else {
                    outRes[0] = Value.fromString(lastRegexError);
                }
                return true;
            }
            case 96 -> { // M_SOCK_ERROR_CODE
                outRes[0] = Value.fromInt(lastSockErrno);
                return true;
            }
            case 97 -> { // M_PCRE_GET_OVECTOR_SIZE
                if (arg.isSeq() && arg.asSeq().size() > 0 && arg.asSeq().get(0).isSeq()) {
                    int reId = arg.asSeq().get(0).asSeq().regexId;
                    if (reId >= 0 && reId < compiledRegexes.size()) {
                        outRes[0] = Value.fromInt(compiledRegexes.get(reId).groupCount);
                        return true;
                    }
                }
                outRes[0] = Value.fromInt(0);
                return true;
            }
            case 98 -> { // M_GET_RAND
                Sequence seq = new Sequence(2);
                long r = rng.nextLong();
                seq.setElement(0, Value.fromInt(r & 0xFFFFFFFFL));
                seq.setElement(1, Value.fromInt((r >>> 32) & 0xFFFFFFFFL));
                outRes[0] = Value.fromSeq(seq);
                return true;
            }
            case 99 -> { // M_HAS_CONSOLE
                outRes[0] = Value.fromInt(1);
                return true;
            }
            case 101 -> { // M_F80_TO_A
                if (arg.isSeq() && arg.asSeq().size() >= 10) {
                    byte[] bytes = new byte[10];
                    for (int i = 0; i < 10; i++) {
                        bytes[i] = (byte) (arg.asSeq().get(i).toIntCoerce() & 0xFF);
                    }
                    outRes[0] = Value.fromF64(f80ToDouble(bytes));
                } else {
                    outRes[0] = Value.fromF64(0.0);
                }
                return true;
            }
            case 102 -> { // M_INFINITY
                outRes[0] = Value.fromF64(Double.POSITIVE_INFINITY);
                return true;
            }
            case 103 -> { // M_CALL_STACK
                Sequence seq = new Sequence();
                for (int fi = 0; fi < frameDepth; fi++) {
                    CallFrame cf = frameStack[fi];
                    if (cf.routine != null) {
                        seq.addElement(Value.fromString(cf.routine.name));
                    }
                }
                outRes[0] = Value.fromSeq(seq);
                return true;
            }
            case 105 -> { // M_A_TO_F80
                byte[] bytes = doubleToF80(arg.asF64());
                Sequence seq = new Sequence(10);
                for (int i = 0; i < 10; i++) {
                    seq.setElement(i, Value.fromInt(bytes[i] & 0xFFL));
                }
                outRes[0] = Value.fromSeq(seq);
                return true;
            }
            case 106 -> { // M_MACHINE_INFO
                Sequence seq = new Sequence(2);
                seq.setElement(0, Value.fromString("X86_64"));
                seq.setElement(1, Value.fromInt(0));
                outRes[0] = Value.fromSeq(seq);
                return true;
            }
            case 200 -> { // M_HTTP_REQUEST
                outRes[0] = execHttpRequest(arg);
                return true;
            }
            case 201 -> { // M_HTTP_SERVER_NEW
                outRes[0] = execHttpServerNew(arg);
                return true;
            }
            case 202 -> { // M_HTTP_SERVER_ACCEPT
                outRes[0] = execHttpServerAccept(arg);
                return true;
            }
            case 203 -> { // M_HTTP_SERVER_REPLY
                outRes[0] = execHttpServerReply(arg);
                return true;
            }
            case 204 -> { // M_HTTP_SERVER_CLOSE
                outRes[0] = execHttpServerClose(arg);
                return true;
            }
            case 205 -> { // M_HTTP_FORK: spawn background worker virtual thread with cloned VM state
                System.out.flush();
                System.err.flush();
                long pid = nextWorkerPid.getAndIncrement();
                VM childVm = new VM(this, destAbsReg);
                Thread t = Thread.ofVirtual().name("eui-worker-" + pid).start(childVm::resumeExecution);
                workerThreads.put(pid, t);
                outRes[0] = Value.fromInt(pid);
                return true;
            }
            case 206 -> { // M_HTTP_KILL_WAIT: `{pid, sig}`
                if (arg.isSeq() && arg.asSeq().size() >= 2) {
                    long pid = arg.asSeq().get(0).toIntCoerce();
                    int sig = (int) arg.asSeq().get(1).toIntCoerce();
                    Thread t = workerThreads.remove(pid);
                    if (t != null) {
                        if (sig > 0) {
                            t.interrupt();
                        }
                        try {
                            t.join(1500);
                        } catch (InterruptedException e) {
                            Thread.currentThread().interrupt();
                        }
                        outRes[0] = Value.fromInt(1);
                        return true;
                    }
                }
                outRes[0] = Value.fromInt(0);
                return true;
            }
            case 210 -> { // M_JSON_PARSE
                outRes[0] = DataEngines.execJsonParse(arg.toUtf8String());
                return true;
            }
            case 211 -> { // M_JSON_STRINGIFY
                if (arg.isSeq() && arg.asSeq().size() >= 2) {
                    int indent = (int) arg.asSeq().get(1).toIntCoerce();
                    outRes[0] = DataEngines.execJsonStringify(arg.asSeq().get(0), indent);
                } else {
                    outRes[0] = DataEngines.execJsonStringify(arg, 0);
                }
                return true;
            }
            case 212 -> { // M_JSON_SCHEMA_VALIDATE
                if (!arg.isSeq() || arg.asSeq().size() < 2) {
                    outRes[0] = Value.fromInt(0);
                    return true;
                }
                outRes[0] = DataEngines.execJsonSchemaValidate(arg.asSeq().get(0), arg.asSeq().get(1));
                return true;
            }
            case 213 -> { // M_JSON_JSONPATH
                if (!arg.isSeq() || arg.asSeq().size() < 2) {
                    outRes[0] = Value.emptySeq();
                    return true;
                }
                outRes[0] = DataEngines.execJsonJsonpath(arg.asSeq().get(0), arg.asSeq().get(1).toUtf8String());
                return true;
            }
            case 220 -> { // M_XML_PARSE
                outRes[0] = DataEngines.execXmlParse(arg.toUtf8String());
                return true;
            }
            case 221 -> { // M_XML_STRINGIFY
                if (arg.isSeq() && arg.asSeq().size() >= 2) {
                    int indent = (int) arg.asSeq().get(1).toIntCoerce();
                    outRes[0] = DataEngines.execXmlStringify(arg.asSeq().get(0), indent);
                } else {
                    outRes[0] = DataEngines.execXmlStringify(arg, 0);
                }
                return true;
            }
            case 222 -> { // M_XML_XPATH
                if (!arg.isSeq() || arg.asSeq().size() < 2) {
                    outRes[0] = Value.emptySeq();
                    return true;
                }
                outRes[0] = DataEngines.execXmlXpath(arg.asSeq().get(0), arg.asSeq().get(1).toUtf8String());
                return true;
            }
            case 223 -> { // M_XML_VALIDATE_XSD
                if (!arg.isSeq() || arg.asSeq().size() < 2) {
                    outRes[0] = Value.fromInt(0);
                    return true;
                }
                outRes[0] = DataEngines.execXmlValidateXsd(arg.asSeq().get(0), arg.asSeq().get(1).toUtf8String());
                return true;
            }
            case 224 -> { // M_XML_VALIDATE_RNG
                if (!arg.isSeq() || arg.asSeq().size() < 2) {
                    outRes[0] = Value.fromInt(0);
                    return true;
                }
                outRes[0] = DataEngines.execXmlValidateRelaxng(arg.asSeq().get(0), arg.asSeq().get(1).toUtf8String());
                return true;
            }
            case 230 -> { // M_SQLITE_OPEN
                outRes[0] = execSqliteOpen(arg);
                return true;
            }
            case 231 -> { // M_SQLITE_CLOSE
                outRes[0] = execSqliteClose(arg);
                return true;
            }
            case 232 -> { // M_SQLITE_EXEC
                outRes[0] = execSqliteCall(arg, false);
                return true;
            }
            case 233 -> { // M_SQLITE_QUERY
                outRes[0] = execSqliteCall(arg, true);
                return true;
            }
            case 234 -> { // M_SQLITE_INFO
                outRes[0] = execSqliteInfo(arg);
                return true;
            }
            case 240 -> { // M_UTF8_VALID
                outRes[0] = DataEngines.execUtf8Valid(arg.toRawBytes());
                return true;
            }
            case 241 -> { // M_UTF8_LEN
                outRes[0] = DataEngines.execUtf8Len(arg.toRawBytes());
                return true;
            }
            case 242 -> { // M_UTF8_SLICE
                if (!arg.isSeq() || arg.asSeq().size() < 3) {
                    outRes[0] = Value.emptySeq();
                    return true;
                }
                Sequence s = arg.asSeq();
                outRes[0] = DataEngines.execUtf8Slice(
                    s.get(0).toRawBytes(),
                    s.get(1).toIntCoerce(),
                    s.get(2).toIntCoerce()
                );
                return true;
            }
            case 243 -> { // M_UTF8_TO_CODEPOINTS
                outRes[0] = DataEngines.execUtf8ToCodepoints(arg.toRawBytes());
                return true;
            }
            case 244 -> { // M_UTF8_FROM_CODEPOINTS
                outRes[0] = DataEngines.execUtf8FromCodepoints(arg);
                return true;
            }
            case 245 -> { // M_UTF8_UPPER
                outRes[0] = DataEngines.execUtf8Case(arg.toRawBytes(), true);
                return true;
            }
            case 246 -> { // M_UTF8_LOWER
                outRes[0] = DataEngines.execUtf8Case(arg.toRawBytes(), false);
                return true;
            }
            case 247 -> { // M_UTF8_FIND
                if (!arg.isSeq() || arg.asSeq().size() < 3) {
                    outRes[0] = Value.fromInt(0);
                    return true;
                }
                Sequence s = arg.asSeq();
                outRes[0] = DataEngines.execUtf8Find(
                    s.get(0).toRawBytes(),
                    s.get(1).toRawBytes(),
                    s.get(2).toIntCoerce()
                );
                return true;
            }
            case 250 -> { // M_PGSQL_OPEN
                outRes[0] = execPgOpen(arg);
                return true;
            }
            case 251 -> { // M_PGSQL_CLOSE
                outRes[0] = execPgClose(arg);
                return true;
            }
            case 252 -> { // M_PGSQL_EXEC
                outRes[0] = execPgCall(arg, false);
                return true;
            }
            case 253 -> { // M_PGSQL_QUERY
                outRes[0] = execPgCall(arg, true);
                return true;
            }
            case 254 -> { // M_PGSQL_INFO
                outRes[0] = execPgInfo(arg);
                return true;
            }
            case 255 -> { // M_PGSQL_ESCAPE
                outRes[0] = execPgEscape(arg);
                return true;
            }
            // =========================================================================
            // JAVA INTEROP (300..307)
            // =========================================================================
            case 300 -> { // M_JAVA_LOAD_JAR: jar_path
                String jarPath = arg.toUtf8String();
                boolean ok = JavaInterop.loadJar(jarPath);
                outRes[0] = Value.fromInt(ok ? 1 : 0);
                return true;
            }
            case 301 -> { // M_JAVA_FIND_CLASS: class_name
                String className = arg.toUtf8String();
                outRes[0] = JavaInterop.findClass(className);
                return true;
            }
            case 302 -> { // M_JAVA_NEW: {class_or_name, args}
                if (!arg.isSeq() || arg.asSeq().size() == 0) {
                    outRes[0] = Value.fromInt(0);
                    return true;
                }
                Sequence s = arg.asSeq();
                Value clsV = s.get(0);
                Object clsOrName = clsV.isAtom() ? clsV.toIntCoerce() : clsV.toUtf8String();
                List<Value> argsList = new ArrayList<>();
                if (s.size() > 1 && s.get(1).isSeq()) {
                    Sequence as = s.get(1).asSeq();
                    for (int i = 0; i < as.size(); i++) argsList.add(as.get(i));
                }
                outRes[0] = JavaInterop.newObject(clsOrName, argsList);
                return true;
            }
            case 303 -> { // M_JAVA_CALL_STATIC: {class_or_name, method_name, args}
                if (!arg.isSeq() || arg.asSeq().size() < 2) {
                    outRes[0] = Value.fromInt(0);
                    return true;
                }
                Sequence s = arg.asSeq();
                Value clsV = s.get(0);
                Object clsOrName = clsV.isAtom() ? clsV.toIntCoerce() : clsV.toUtf8String();
                String mName = s.get(1).toUtf8String();
                List<Value> argsList = new ArrayList<>();
                if (s.size() > 2 && s.get(2).isSeq()) {
                    Sequence as = s.get(2).asSeq();
                    for (int i = 0; i < as.size(); i++) argsList.add(as.get(i));
                }
                outRes[0] = JavaInterop.callStatic(clsOrName, mName, argsList);
                return true;
            }
            case 304 -> { // M_JAVA_CALL_METHOD: {obj_handle, method_name, args}
                if (!arg.isSeq() || arg.asSeq().size() < 2) {
                    outRes[0] = Value.fromInt(0);
                    return true;
                }
                Sequence s = arg.asSeq();
                long objHandle = s.get(0).toIntCoerce();
                String mName = s.get(1).toUtf8String();
                List<Value> argsList = new ArrayList<>();
                if (s.size() > 2 && s.get(2).isSeq()) {
                    Sequence as = s.get(2).asSeq();
                    for (int i = 0; i < as.size(); i++) argsList.add(as.get(i));
                }
                outRes[0] = JavaInterop.callMethod(objHandle, mName, argsList);
                return true;
            }
            case 305 -> { // M_JAVA_GET_FIELD: {target_or_class, field_name}
                if (!arg.isSeq() || arg.asSeq().size() < 2) {
                    outRes[0] = Value.fromInt(0);
                    return true;
                }
                Sequence s = arg.asSeq();
                Value targetV = s.get(0);
                Object target = targetV.isAtom() ? targetV.toIntCoerce() : targetV.toUtf8String();
                String fName = s.get(1).toUtf8String();
                outRes[0] = JavaInterop.getField(target, fName);
                return true;
            }
            case 306 -> { // M_JAVA_SET_FIELD: {target_or_class, field_name, value}
                if (!arg.isSeq() || arg.asSeq().size() < 3) {
                    outRes[0] = Value.fromInt(0);
                    return true;
                }
                Sequence s = arg.asSeq();
                Value targetV = s.get(0);
                Object target = targetV.isAtom() ? targetV.toIntCoerce() : targetV.toUtf8String();
                String fName = s.get(1).toUtf8String();
                Value valV = s.get(2);
                boolean ok = JavaInterop.setField(target, fName, valV);
                outRes[0] = Value.fromInt(ok ? 1 : 0);
                return true;
            }
            case 307 -> { // M_JAVA_TO_STRING: obj_handle
                long objHandle = arg.toIntCoerce();
                outRes[0] = JavaInterop.toStringVal(objHandle);
                return true;
            }
            case 308 -> { // M_JAVA_CREATE_LISTENER: {iface_class_or_name, routine_id}
                if (!arg.isSeq() || arg.asSeq().size() < 2) {
                    outRes[0] = Value.fromInt(0);
                    return true;
                }
                Sequence s = arg.asSeq();
                Value ifaceV = s.get(0);
                Object iface = ifaceV.isAtom() ? ifaceV.toIntCoerce() : ifaceV.toUtf8String();
                int rid = (int) s.get(1).toIntCoerce();
                outRes[0] = JavaInterop.createListener(iface, rid);
                return true;
            }

            // =========================================================================
            // VIRTUAL-THREAD PROCESS & PIPE IO (310..314)
            // =========================================================================
            case 310 -> { // M_PIPE_EXEC: cmd
                String cmd = arg.toUtf8String();
                outRes[0] = JavaInterop.pipeExec(cmd);
                return true;
            }
            case 311 -> { // M_PIPE_READ: {fd, count}
                if (!arg.isSeq() || arg.asSeq().size() < 2) {
                    outRes[0] = Value.emptySeq();
                    return true;
                }
                Sequence s = arg.asSeq();
                long fd = s.get(0).toIntCoerce();
                int count = (int) s.get(1).toIntCoerce();
                outRes[0] = JavaInterop.pipeRead(fd, count);
                return true;
            }
            case 312 -> { // M_PIPE_WRITE: {fd, data}
                if (!arg.isSeq() || arg.asSeq().size() < 2) {
                    outRes[0] = Value.fromInt(-1);
                    return true;
                }
                Sequence s = arg.asSeq();
                long fd = s.get(0).toIntCoerce();
                Value dataV = s.get(1);
                outRes[0] = JavaInterop.pipeWrite(fd, dataV);
                return true;
            }
            case 313 -> { // M_PIPE_CLOSE: fd
                long fd = arg.toIntCoerce();
                outRes[0] = JavaInterop.pipeClose(fd);
                return true;
            }
            case 314 -> { // M_PIPE_KILL: {pid, sig} or pid
                long pid = arg.isSeq() && arg.asSeq().size() > 0 ? arg.asSeq().get(0).toIntCoerce() : arg.toIntCoerce();
                int sig = (arg.isSeq() && arg.asSeq().size() > 1) ? (int) arg.asSeq().get(1).toIntCoerce() : 15;
                JavaInterop.pipeKill(pid, sig);
                outRes[0] = Value.fromInt(0);
                return true;
            }

            // =========================================================================
            // JAVA 25 VIRTUAL THREADS & ASYNC/AWAIT (320..327)
            // =========================================================================
            case 320 -> { // M_THREAD_SPAWN: {rid, args}
                if (!arg.isSeq() || arg.asSeq().size() == 0) {
                    outRes[0] = Value.fromInt(0);
                    return true;
                }
                Sequence s = arg.asSeq();
                int rid = (int) s.get(0).toIntCoerce();
                List<Value> argsList = new ArrayList<>();
                if (s.size() > 1 && s.get(1).isSeq()) {
                    Sequence as = s.get(1).asSeq();
                    for (int i = 0; i < as.size(); i++) argsList.add(as.get(i));
                }
                long tid = nextThreadId.getAndIncrement();
                Thread t = Thread.ofVirtual().name("eui-vthread-" + tid).start(() -> {
                    runRoutineDirectly(rid, argsList);
                });
                virtualThreads.put(tid, t);
                outRes[0] = Value.fromInt(tid);
                return true;
            }
            case 321 -> { // M_THREAD_ASYNC: {rid, args}
                if (!arg.isSeq() || arg.asSeq().size() == 0) {
                    outRes[0] = Value.fromInt(0);
                    return true;
                }
                Sequence s = arg.asSeq();
                int rid = (int) s.get(0).toIntCoerce();
                List<Value> argsList = new ArrayList<>();
                if (s.size() > 1 && s.get(1).isSeq()) {
                    Sequence as = s.get(1).asSeq();
                    for (int i = 0; i < as.size(); i++) argsList.add(as.get(i));
                }
                long jobId = nextJobId.getAndIncrement();
                CompletableFuture<Value> future = new CompletableFuture<>();
                asyncJobs.put(jobId, future);
                Thread.ofVirtual().name("eui-async-" + jobId).start(() -> {
                    try {
                        Value res = runRoutineDirectly(rid, argsList);
                        future.complete(res != null ? res : Value.fromInt(0));
                    } catch (Throwable thr) {
                        future.complete(Value.fromInt(0));
                    }
                });
                outRes[0] = Value.fromInt(jobId);
                return true;
            }
            case 322 -> { // M_THREAD_AWAIT: {jobId, timeout} or jobId
                long jobId = arg.isSeq() && arg.asSeq().size() > 0 ? arg.asSeq().get(0).toIntCoerce() : arg.toIntCoerce();
                double timeoutSec = (arg.isSeq() && arg.asSeq().size() > 1) ? arg.asSeq().get(1).asDouble() : -1.0;
                CompletableFuture<Value> future = asyncJobs.get(jobId);
                if (future == null) {
                    outRes[0] = Value.fromInt(-1);
                    return true;
                }
                try {
                    Value res;
                    if (timeoutSec < 0) {
                        res = future.get();
                    } else {
                        long millis = (long) (timeoutSec * 1000.0);
                        res = future.get(millis, TimeUnit.MILLISECONDS);
                    }
                    outRes[0] = res != null ? res : Value.fromInt(0);
                } catch (TimeoutException te) {
                    outRes[0] = Value.fromString("TIMEOUT");
                } catch (Exception ex) {
                    outRes[0] = Value.fromInt(-1);
                }
                return true;
            }
            case 323 -> { // M_THREAD_IS_DONE: jobId
                long jobId = arg.toIntCoerce();
                CompletableFuture<Value> future = asyncJobs.get(jobId);
                outRes[0] = Value.fromInt((future != null && future.isDone()) ? 1 : 0);
                return true;
            }
            case 324 -> { // M_THREAD_JOIN: {tid, timeout} or tid
                long tid = arg.isSeq() && arg.asSeq().size() > 0 ? arg.asSeq().get(0).toIntCoerce() : arg.toIntCoerce();
                double timeoutSec = (arg.isSeq() && arg.asSeq().size() > 1) ? arg.asSeq().get(1).asDouble() : 0.0;
                Thread t = virtualThreads.get(tid);
                if (t == null) {
                    outRes[0] = Value.fromInt(0);
                    return true;
                }
                try {
                    if (timeoutSec <= 0) {
                        t.join();
                    } else {
                        t.join((long)(timeoutSec * 1000.0));
                    }
                    outRes[0] = Value.fromInt(t.isAlive() ? 0 : 1);
                } catch (InterruptedException e) {
                    outRes[0] = Value.fromInt(0);
                }
                return true;
            }
            case 325 -> { // M_THREAD_SLEEP: seconds
                double sec = arg.asDouble();
                long millis = (long)(sec * 1000.0);
                if (millis > 0) {
                    try {
                        Thread.sleep(millis);
                    } catch (InterruptedException ignored) {}
                }
                outRes[0] = Value.fromInt(0);
                return true;
            }
            case 326 -> { // M_THREAD_CURRENT: dummy
                outRes[0] = Value.fromInt(Thread.currentThread().threadId());
                return true;
            }
            case 327 -> { // M_THREAD_CANCEL: id
                long id = arg.toIntCoerce();
                CompletableFuture<Value> future = asyncJobs.remove(id);
                if (future != null) {
                    future.cancel(true);
                }
                Thread t = virtualThreads.remove(id);
                if (t != null) {
                    t.interrupt();
                }
                outRes[0] = Value.fromInt(1);
                return true;
            }

            // =========================================================================
            // GO-STYLE CHANNELS / CSP (330..337)
            // =========================================================================
            case 330 -> { // M_CHANNEL_NEW: capacity
                int cap = (int) arg.toIntCoerce();
                long cid = nextChannelId.getAndIncrement();
                BlockingQueue<Value> q = (cap <= 0) ? new SynchronousQueue<>() : new LinkedBlockingQueue<>(cap);
                channels.put(cid, q);
                channelClosed.put(cid, new AtomicBoolean(false));
                outRes[0] = Value.fromInt(cid);
                return true;
            }
            case 331 -> { // M_CHANNEL_SEND: {cid, val, timeout}
                if (!arg.isSeq() || arg.asSeq().size() < 2) {
                    outRes[0] = Value.fromInt(-1);
                    return true;
                }
                Sequence s = arg.asSeq();
                long cid = s.get(0).toIntCoerce();
                Value val = s.get(1);
                double timeoutSec = s.size() > 2 ? s.get(2).asDouble() : -1.0;
                BlockingQueue<Value> q = channels.get(cid);
                AtomicBoolean closed = channelClosed.get(cid);
                if (q == null || closed == null || closed.get()) {
                    outRes[0] = Value.fromInt(-1);
                    return true;
                }
                Value toSend = deepCopyValue(val);
                toSend.retain();
                boolean ok = false;
                try {
                    if (timeoutSec < 0) {
                        q.put(toSend);
                        ok = true;
                    } else {
                        ok = q.offer(toSend, (long)(timeoutSec * 1000.0), TimeUnit.MILLISECONDS);
                    }
                } catch (InterruptedException e) {
                    ok = false;
                }
                outRes[0] = Value.fromInt(ok ? 1 : 0);
                return true;
            }
            case 332 -> { // M_CHANNEL_RECEIVE: {cid, timeout} or cid
                long cid = arg.isSeq() && arg.asSeq().size() > 0 ? arg.asSeq().get(0).toIntCoerce() : arg.toIntCoerce();
                double timeoutSec = (arg.isSeq() && arg.asSeq().size() > 1) ? arg.asSeq().get(1).asDouble() : -1.0;
                BlockingQueue<Value> q = channels.get(cid);
                AtomicBoolean closed = channelClosed.get(cid);
                Sequence res = new Sequence(2);
                if (q == null) {
                    res.setElement(0, Value.fromInt(-1));
                    res.setElement(1, Value.fromInt(0));
                    outRes[0] = Value.fromSeq(res);
                    return true;
                }
                try {
                    Value received = null;
                    if (timeoutSec < 0) {
                        while (received == null) {
                            if (closed.get() && q.isEmpty()) break;
                            received = q.poll(50, TimeUnit.MILLISECONDS);
                        }
                    } else {
                        received = q.poll((long)(timeoutSec * 1000.0), TimeUnit.MILLISECONDS);
                    }
                    if (received != null) {
                        res.setElement(0, Value.fromInt(1)); // OK
                        res.setElement(1, received);
                    } else if (closed.get() && q.isEmpty()) {
                        res.setElement(0, Value.fromInt(-1)); // CLOSED
                        res.setElement(1, Value.fromInt(0));
                    } else {
                        res.setElement(0, Value.fromInt(0)); // TIMEOUT
                        res.setElement(1, Value.fromInt(0));
                    }
                } catch (InterruptedException e) {
                    res.setElement(0, Value.fromInt(0));
                    res.setElement(1, Value.fromInt(0));
                }
                outRes[0] = Value.fromSeq(res);
                return true;
            }
            case 333 -> { // M_CHANNEL_TRY_SEND: {cid, val}
                if (!arg.isSeq() || arg.asSeq().size() < 2) {
                    outRes[0] = Value.fromInt(-1);
                    return true;
                }
                Sequence s = arg.asSeq();
                long cid = s.get(0).toIntCoerce();
                Value val = s.get(1);
                BlockingQueue<Value> q = channels.get(cid);
                AtomicBoolean closed = channelClosed.get(cid);
                if (q == null || closed == null || closed.get()) {
                    outRes[0] = Value.fromInt(-1);
                    return true;
                }
                Value toSend = deepCopyValue(val);
                toSend.retain();
                boolean ok = q.offer(toSend);
                outRes[0] = Value.fromInt(ok ? 1 : 0);
                return true;
            }
            case 334 -> { // M_CHANNEL_TRY_RECEIVE: cid
                long cid = arg.toIntCoerce();
                BlockingQueue<Value> q = channels.get(cid);
                AtomicBoolean closed = channelClosed.get(cid);
                Sequence res = new Sequence(2);
                if (q == null) {
                    res.setElement(0, Value.fromInt(-1));
                    res.setElement(1, Value.fromInt(0));
                    outRes[0] = Value.fromSeq(res);
                    return true;
                }
                Value received = q.poll();
                if (received != null) {
                    res.setElement(0, Value.fromInt(1));
                    res.setElement(1, received);
                } else if (closed.get() && q.isEmpty()) {
                    res.setElement(0, Value.fromInt(-1));
                    res.setElement(1, Value.fromInt(0));
                } else {
                    res.setElement(0, Value.fromInt(0));
                    res.setElement(1, Value.fromInt(0));
                }
                outRes[0] = Value.fromSeq(res);
                return true;
            }
            case 335 -> { // M_CHANNEL_CLOSE: cid
                long cid = arg.toIntCoerce();
                AtomicBoolean closed = channelClosed.get(cid);
                if (closed != null) closed.set(true);
                outRes[0] = Value.fromInt(1);
                return true;
            }
            case 336 -> { // M_CHANNEL_SIZE: cid
                long cid = arg.toIntCoerce();
                BlockingQueue<Value> q = channels.get(cid);
                outRes[0] = Value.fromInt(q != null ? q.size() : 0);
                return true;
            }
            case 337 -> { // M_CHANNEL_IS_CLOSED: cid
                long cid = arg.toIntCoerce();
                AtomicBoolean closed = channelClosed.get(cid);
                outRes[0] = Value.fromInt((closed != null && closed.get()) ? 1 : 0);
                return true;
            }
            default -> {
                return true;
            }
        }
    }

    private static boolean listContainsSocket(Sequence list, long targetId) {
        if (list == null) return false;
        for (int i = 0; i < list.size(); i++) {
            Value item = list.get(i);
            if (item.isSeq() && item.asSeq().size() > 0 && item.asSeq().get(0).toIntCoerce() == targetId) {
                return true;
            }
        }
        return false;
    }

    private static String formatIpAddress(InetAddress addr) {
        if (addr == null) return "127.0.0.1";
        if (addr instanceof Inet6Address) {
            byte[] b = addr.getAddress();
            boolean isLoopback = true;
            for (int i = 0; i < 15; i++) {
                if (b[i] != 0) { isLoopback = false; break; }
            }
            if (isLoopback && b[15] == 1) {
                return "::1";
            }
        }
        String ip = addr.getHostAddress();
        int pct = ip.indexOf('%');
        return pct >= 0 ? ip.substring(0, pct) : ip;
    }

    // -------------------------------------------------------------------------
    // HTTP / HTTPS Client & Server (200..204)
    // -------------------------------------------------------------------------
    private static SSLContext createTrustAllSslContext() throws Exception {
        TrustManager[] trustAll = new TrustManager[]{
            new X509ExtendedTrustManager() {
                @Override public void checkClientTrusted(java.security.cert.X509Certificate[] c, String a, Socket s) {}
                @Override public void checkServerTrusted(java.security.cert.X509Certificate[] c, String a, Socket s) {}
                @Override public void checkClientTrusted(java.security.cert.X509Certificate[] c, String a, SSLEngine e) {}
                @Override public void checkServerTrusted(java.security.cert.X509Certificate[] c, String a, SSLEngine e) {}
                @Override public void checkClientTrusted(java.security.cert.X509Certificate[] c, String a) {}
                @Override public void checkServerTrusted(java.security.cert.X509Certificate[] c, String a) {}
                @Override public java.security.cert.X509Certificate[] getAcceptedIssuers() {
                    return new java.security.cert.X509Certificate[0];
                }
            }
        };
        SSLContext ctx = SSLContext.getInstance("TLS");
        ctx.init(null, trustAll, new SecureRandom());
        return ctx;
    }

    private Value execHttpRequest(Value arg) {
        if (!arg.isSeq() || arg.asSeq().size() < 4) {
            return Value.fromInt(-1);
        }
        Sequence reqArgs = arg.asSeq();
        String method = reqArgs.get(0).toUtf8String();
        String url = reqArgs.get(1).toUtf8String();
        byte[] reqBody = reqArgs.get(2).toRawBytes();
        Sequence customHdrs = reqArgs.get(3).isSeq() ? reqArgs.get(3).asSeq() : null;
        long timeoutMs = (reqArgs.size() >= 5) ? reqArgs.get(4).toIntCoerce() : 10000L;
        boolean verifySsl = (reqArgs.size() >= 6) ? (reqArgs.get(5).toIntCoerce() != 0) : true;

        try {
            HttpClient.Builder cb = HttpClient.newBuilder()
                .version(HttpClient.Version.HTTP_1_1)
                .followRedirects(HttpClient.Redirect.NORMAL)
                .connectTimeout(Duration.ofMillis(timeoutMs > 0 ? timeoutMs : 10000L));
            if (!verifySsl) {
                cb.sslContext(createTrustAllSslContext());
            }
            HttpClient client = cb.build();

            HttpRequest.BodyPublisher bodyPub = (reqBody.length > 0 || "POST".equals(method) || "PUT".equals(method) || "PATCH".equals(method))
                ? HttpRequest.BodyPublishers.ofByteArray(reqBody)
                : HttpRequest.BodyPublishers.noBody();

            HttpRequest.Builder rb = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .timeout(Duration.ofMillis(timeoutMs > 0 ? timeoutMs : 10000L))
                .method(method, bodyPub);

            boolean hasUserAgent = false;
            if (customHdrs != null) {
                for (int i = 0; i < customHdrs.size(); i++) {
                    Value h = customHdrs.get(i);
                    if (h.isSeq() && h.asSeq().size() >= 2) {
                        String k = h.asSeq().get(0).toUtf8String();
                        String v = h.asSeq().get(1).toUtf8String();
                        if ("user-agent".equalsIgnoreCase(k)) hasUserAgent = true;
                        rb.header(k, v);
                    }
                }
            }
            if (!hasUserAgent) {
                rb.header("User-Agent", "Euphoria-libcurl/4.1");
            }

            HttpResponse<byte[]> resp = client.send(rb.build(), HttpResponse.BodyHandlers.ofByteArray());
            Sequence respHdrs = new Sequence();
            for (Map.Entry<String, List<String>> entry : resp.headers().map().entrySet()) {
                String k = entry.getKey();
                if (k == null || k.startsWith(":")) continue;
                for (String v : entry.getValue()) {
                    Sequence kv = new Sequence(2);
                    kv.setElement(0, Value.fromString(k));
                    kv.setElement(1, Value.fromString(v));
                    respHdrs.addElement(Value.fromSeq(kv));
                }
            }

            Sequence res = new Sequence(3);
            res.setElement(0, Value.fromInt(resp.statusCode()));
            res.setElement(1, Value.fromRawBytes(resp.body()));
            res.setElement(2, Value.fromSeq(respHdrs));
            return Value.fromSeq(res);
        } catch (Exception e) {
            Sequence res = new Sequence(3);
            res.setElement(0, Value.fromInt(-7));
            String msg = e.getClass().getSimpleName() + ": " + (e.getMessage() != null ? e.getMessage() : "HTTP Request Error");
            res.setElement(1, Value.fromString(msg));
            res.setElement(2, Value.emptySeq());
            return Value.fromSeq(res);
        }
    }

    private static SSLContext createServerSslContextFromPem(String certPemPath, String keyPemPath) throws Exception {
        Certificate cert;
        try (InputStream cis = Files.newInputStream(Path.of(certPemPath))) {
            cert = CertificateFactory.getInstance("X.509").generateCertificate(cis);
        }
        String keyPem = Files.readString(Path.of(keyPemPath), StandardCharsets.US_ASCII);
        String b64 = keyPem
            .replaceAll("-----BEGIN [A-Z0-9 ]+-----", "")
            .replaceAll("-----END [A-Z0-9 ]+-----", "")
            .replaceAll("\\s+", "");
        byte[] der = Base64.getDecoder().decode(b64);
        if (keyPem.contains("BEGIN RSA PRIVATE KEY")) {
            // Wrap PKCS#1 RSA private key in PKCS#8 PrivateKeyInfo
            der = wrapPkcs1ToPkcs8(der);
        }
        PKCS8EncodedKeySpec keySpec = new PKCS8EncodedKeySpec(der);
        PrivateKey privKey;
        try {
            privKey = KeyFactory.getInstance("RSA").generatePrivate(keySpec);
        } catch (Exception e) {
            privKey = KeyFactory.getInstance("EC").generatePrivate(keySpec);
        }

        KeyStore ks = KeyStore.getInstance(KeyStore.getDefaultType());
        ks.load(null, null);
        ks.setKeyEntry("server", privKey, new char[0], new Certificate[]{cert});

        KeyManagerFactory kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
        kmf.init(ks, new char[0]);

        SSLContext sslCtx = SSLContext.getInstance("TLS");
        sslCtx.init(kmf.getKeyManagers(), null, new SecureRandom());
        return sslCtx;
    }

    private static byte[] wrapPkcs1ToPkcs8(byte[] pkcs1) {
        byte[] rsaOid = new byte[]{
            0x30, 0x0d, 0x06, 0x09, 0x2a, (byte) 0x86, 0x48, (byte) 0x86,
            (byte) 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00
        };
        byte[] version = new byte[]{0x02, 0x01, 0x00};
        byte[] octetStr = encodeDerTagLength((byte) 0x04, pkcs1);
        byte[] body = new byte[version.length + rsaOid.length + octetStr.length];
        System.arraycopy(version, 0, body, 0, version.length);
        System.arraycopy(rsaOid, 0, body, version.length, rsaOid.length);
        System.arraycopy(octetStr, 0, body, version.length + rsaOid.length, octetStr.length);
        return encodeDerTagLength((byte) 0x30, body);
    }

    private static byte[] encodeDerTagLength(byte tag, byte[] content) {
        int len = content.length;
        ByteArrayOutputStream bos = new ByteArrayOutputStream(len + 8);
        bos.write(tag);
        if (len < 128) {
            bos.write(len);
        } else if (len < 256) {
            bos.write(0x81);
            bos.write(len);
        } else {
            bos.write(0x82);
            bos.write((len >>> 8) & 0xFF);
            bos.write(len & 0xFF);
        }
        bos.write(content, 0, len);
        return bos.toByteArray();
    }

    private Value execHttpServerNew(Value arg) {
        if (!arg.isSeq() || arg.asSeq().size() < 4) {
            return Value.fromInt(-1);
        }
        Sequence s = arg.asSeq();
        String host = s.get(0).toUtf8String();
        int port = (int) s.get(1).toIntCoerce();
        String certPem = s.get(2).toUtf8String();
        String keyPem = s.get(3).toUtf8String();

        SSLContext sslCtx = null;
        boolean isTls = !certPem.isEmpty() && !keyPem.isEmpty();
        if (isTls) {
            try {
                sslCtx = createServerSslContextFromPem(certPem, keyPem);
            } catch (Exception e) {
                return Value.fromInt(-6);
            }
        }

        try {
            if (host.isEmpty()) host = "0.0.0.0";
            ServerSocket ss = new ServerSocket();
            ss.setReuseAddress(true);
            ss.bind(new InetSocketAddress(InetAddress.getByName(host), port), 64);
            long srvId = nextHttpId.getAndIncrement();
            httpServers.put(srvId, new HttpServerInstance(ss, sslCtx, isTls));
            return Value.fromInt(srvId);
        } catch (IOException e) {
            return Value.fromInt(-4);
        }
    }

    private Value execHttpServerAccept(Value arg) {
        if (!arg.isSeq() || arg.asSeq().size() < 2) {
            return Value.fromInt(-1);
        }
        long srvId = arg.asSeq().get(0).toIntCoerce();
        int timeoutMs = (int) arg.asSeq().get(1).toIntCoerce();
        HttpServerInstance srv = httpServers.get(srvId);
        if (srv == null) {
            return Value.fromInt(-1);
        }

        Socket clientSock = null;
        int waited = 0;
        int step = Math.min(Math.max(10, timeoutMs), 100);
        while (waited < timeoutMs) {
            if (Thread.currentThread().isInterrupted() || srv.serverSocket.isClosed()) {
                return Value.fromInt(-1);
            }
            try {
                srv.serverSocket.setSoTimeout(step);
                clientSock = srv.serverSocket.accept();
                break;
            } catch (SocketTimeoutException ste) {
                waited += step;
            } catch (IOException e) {
                return Value.fromInt(-1);
            }
        }
        if (clientSock == null) {
            return Value.fromInt(0);
        }

        try {
            clientSock.setSoTimeout(5000);
            Socket activeSock = clientSock;
            if (srv.isTls && srv.sslContext != null) {
                SSLSocket sslSock = (SSLSocket) srv.sslContext.getSocketFactory().createSocket(
                    clientSock, clientSock.getInetAddress().getHostAddress(), clientSock.getPort(), true);
                sslSock.setUseClientMode(false);
                sslSock.startHandshake();
                activeSock = sslSock;
            }

            InputStream in = activeSock.getInputStream();
            OutputStream out = activeSock.getOutputStream();

            ByteArrayOutputStream rawReq = new ByteArrayOutputStream(1024);
            int hdrEnd = -1;
            int contentLength = 0;
            byte[] buf = new byte[8192];

            for (;;) {
                int n = in.read(buf);
                if (n <= 0) break;
                rawReq.write(buf, 0, n);
                byte[] cur = rawReq.toByteArray();
                if (hdrEnd < 0) {
                    hdrEnd = findDoubleCrlf(cur);
                    if (hdrEnd >= 0) {
                        String hdrBlock = new String(cur, 0, hdrEnd, StandardCharsets.ISO_8859_1);
                        for (String line : hdrBlock.split("\r\n")) {
                            int col = line.indexOf(':');
                            if (col > 0) {
                                String k = line.substring(0, col).trim();
                                if ("content-length".equalsIgnoreCase(k)) {
                                    try {
                                        contentLength = Math.max(0, Integer.parseInt(line.substring(col + 1).trim()));
                                    } catch (NumberFormatException ignored) {}
                                }
                            }
                        }
                    }
                }
                if (hdrEnd >= 0 && cur.length >= hdrEnd + 4 + contentLength) {
                    break;
                }
            }

            byte[] allBytes = rawReq.toByteArray();
            String hdrPart = (hdrEnd >= 0)
                ? new String(allBytes, 0, hdrEnd, StandardCharsets.UTF_8)
                : new String(allBytes, StandardCharsets.UTF_8);
            byte[] bodyBytes = (hdrEnd >= 0 && allBytes.length >= hdrEnd + 4)
                ? Arrays.copyOfRange(allBytes, hdrEnd + 4, Math.min(allBytes.length, hdrEnd + 4 + contentLength))
                : new byte[0];

            String method = "GET";
            String fullTarget = "/";
            int firstNl = hdrPart.indexOf("\r\n");
            String reqLine = (firstNl >= 0) ? hdrPart.substring(0, firstNl) : hdrPart;
            int sp1 = reqLine.indexOf(' ');
            if (sp1 >= 0) {
                method = reqLine.substring(0, sp1);
                int sp2 = reqLine.indexOf(' ', sp1 + 1);
                fullTarget = (sp2 >= 0) ? reqLine.substring(sp1 + 1, sp2) : reqLine.substring(sp1 + 1);
            }

            String path = fullTarget;
            String query = "";
            int qpos = fullTarget.indexOf('?');
            if (qpos >= 0) {
                path = fullTarget.substring(0, qpos);
                query = fullTarget.substring(qpos + 1);
            }

            Sequence hdrSeq = new Sequence();
            if (firstNl >= 0) {
                String[] lines = hdrPart.substring(firstNl + 2).split("\r\n");
                for (String line : lines) {
                    int col = line.indexOf(':');
                    if (col > 0) {
                        String k = line.substring(0, col);
                        String v = line.substring(col + 1).stripLeading();
                        Sequence kv = new Sequence(2);
                        kv.setElement(0, Value.fromString(k));
                        kv.setElement(1, Value.fromString(v));
                        hdrSeq.addElement(Value.fromSeq(kv));
                    }
                }
            }

            String clientIp = formatIpAddress(clientSock.getInetAddress());
            long connId = nextHttpId.getAndIncrement();
            httpConns.put(connId, new HttpConnInstance(activeSock, in, out));

            Sequence res = new Sequence(7);
            res.setElement(0, Value.fromInt(connId));
            res.setElement(1, Value.fromString(method));
            res.setElement(2, Value.fromString(path));
            res.setElement(3, Value.fromString(query));
            res.setElement(4, Value.fromRawBytes(bodyBytes));
            res.setElement(5, Value.fromSeq(hdrSeq));
            res.setElement(6, Value.fromString(clientIp));
            return Value.fromSeq(res);
        } catch (Exception e) {
            try { clientSock.close(); } catch (IOException ignored) {}
            return Value.fromInt(0);
        }
    }

    private static int findDoubleCrlf(byte[] b) {
        for (int i = 0; i + 3 < b.length; i++) {
            if (b[i] == '\r' && b[i + 1] == '\n' && b[i + 2] == '\r' && b[i + 3] == '\n') {
                return i;
            }
        }
        return -1;
    }

    private Value execHttpServerReply(Value arg) {
        if (!arg.isSeq() || arg.asSeq().size() < 4) {
            return Value.fromInt(-1);
        }
        Sequence s = arg.asSeq();
        long connId = s.get(0).toIntCoerce();
        int status = (int) s.get(1).toIntCoerce();
        byte[] body = s.get(2).toRawBytes();
        String ctype = s.get(3).toUtf8String();
        Sequence extra = (s.size() >= 5 && s.get(4).isSeq()) ? s.get(4).asSeq() : null;

        HttpConnInstance conn = httpConns.remove(connId);
        if (conn == null) {
            return Value.fromInt(-1);
        }

        String reason = switch (status) {
            case 201 -> "Created";
            case 204 -> "No Content";
            case 301 -> "Moved Permanently";
            case 302 -> "Found";
            case 400 -> "Bad Request";
            case 401 -> "Unauthorized";
            case 403 -> "Forbidden";
            case 404 -> "Not Found";
            case 500 -> "Internal Server Error";
            default  -> "OK";
        };

        StringBuilder wire = new StringBuilder(256);
        wire.append("HTTP/1.1 ").append(status).append(' ').append(reason).append("\r\n");
        wire.append("Content-Type: ").append(ctype.isEmpty() ? "text/plain; charset=utf-8" : ctype).append("\r\n");
        wire.append("Content-Length: ").append(body.length).append("\r\n");
        wire.append("Connection: close\r\n");
        if (extra != null) {
            for (int i = 0; i < extra.size(); i++) {
                Value h = extra.get(i);
                if (h.isSeq() && h.asSeq().size() >= 2) {
                    wire.append(h.asSeq().get(0).toUtf8String())
                        .append(": ")
                        .append(h.asSeq().get(1).toUtf8String())
                        .append("\r\n");
                }
            }
        }
        wire.append("\r\n");

        boolean ok = true;
        try {
            conn.out.write(wire.toString().getBytes(StandardCharsets.UTF_8));
            conn.out.write(body);
            conn.out.flush();
        } catch (IOException e) {
            ok = false;
        } finally {
            try { conn.socket.close(); } catch (IOException ignored) {}
        }
        return Value.fromInt(ok ? 1 : 0);
    }

    private Value execHttpServerClose(Value arg) {
        long srvId = (arg.isSeq() && arg.asSeq().size() > 0)
            ? arg.asSeq().get(0).toIntCoerce()
            : arg.toIntCoerce();
        HttpServerInstance srv = httpServers.remove(srvId);
        if (srv != null) {
            try { srv.serverSocket.close(); } catch (IOException ignored) {}
            return Value.fromInt(1);
        }
        return Value.fromInt(0);
    }

    // -------------------------------------------------------------------------
    // SQLite Engine via sqlite-jdbc (230..234)
    // -------------------------------------------------------------------------
    private Value execSqliteOpen(Value arg) {
        String path = arg.isSeq() ? arg.toUtf8String() : ":memory:";
        if (path.isEmpty()) path = ":memory:";
        try {
            Connection conn = DriverManager.getConnection("jdbc:sqlite:" + path);
            lastSqliteError = "";
            long dbId = nextSqliteId.getAndIncrement();
            sqliteDbs.put(dbId, new SqliteInstance(conn));
            return Value.fromInt(dbId);
        } catch (SQLException e) {
            lastSqliteError = e.getMessage() != null ? e.getMessage() : "SQLite open failed";
            return Value.fromInt(-1);
        }
    }

    private Value execSqliteClose(Value arg) {
        long dbId = (arg.isSeq() && arg.asSeq().size() > 0)
            ? arg.asSeq().get(0).toIntCoerce()
            : arg.toIntCoerce();
        SqliteInstance inst = sqliteDbs.remove(dbId);
        if (inst != null) {
            try { inst.conn.close(); } catch (SQLException ignored) {}
            return Value.fromInt(1);
        }
        return Value.fromInt(0);
    }

    private static List<String> splitSqlStatements(String sql) {
        List<String> list = new ArrayList<>();
        StringBuilder cur = new StringBuilder();
        boolean inSQuote = false;
        boolean inDQuote = false;
        for (int i = 0; i < sql.length(); i++) {
            char c = sql.charAt(i);
            if (c == '\'' && !inDQuote) {
                inSQuote = !inSQuote;
                cur.append(c);
            } else if (c == '"' && !inSQuote) {
                inDQuote = !inDQuote;
                cur.append(c);
            } else if (c == ';' && !inSQuote && !inDQuote) {
                String trimmed = cur.toString().trim();
                if (!trimmed.isEmpty()) list.add(trimmed);
                cur.setLength(0);
            } else {
                cur.append(c);
            }
        }
        String tail = cur.toString().trim();
        if (!tail.isEmpty()) list.add(tail);
        return list;
    }

    private Value makeSqliteError(boolean isQuery, String msg) {
        lastSqliteError = msg != null ? msg : "SQLite Error";
        if (isQuery) {
            Sequence r = new Sequence(3);
            r.setElement(0, Value.fromInt(0));
            r.setElement(1, Value.fromString(lastSqliteError));
            r.setElement(2, Value.emptySeq());
            return Value.fromSeq(r);
        }
        return Value.fromInt(0);
    }

    private static void bindJdbcParameters(PreparedStatement pstmt, Sequence params) throws SQLException {
        if (params == null) return;
        for (int i = 0; i < params.size(); i++) {
            int idx = i + 1;
            Value pv = params.get(i);
            if (pv.isInt()) {
                pstmt.setLong(idx, pv.asInt());
            } else if (pv.isF64()) {
                pstmt.setDouble(idx, pv.asF64());
            } else if (pv.isSeq()) {
                Sequence ps = pv.asSeq();
                if ((ps.size() == 1 && ps.get(0).isInt() && ps.get(0).asInt() == 0) ||
                    (ps.size() == 2 && ps.get(0).isInt() && ps.get(0).asInt() == DataEngines.JSON_TAG_NULL)) {
                    pstmt.setNull(idx, Types.NULL);
                } else if (ps.size() == 2 && ps.get(0).isInt() && ps.get(0).asInt() == DataEngines.JSON_TAG_STRING) {
                    pstmt.setString(idx, ps.get(1).toUtf8String());
                } else {
                    pstmt.setString(idx, pv.toUtf8String());
                }
            } else {
                pstmt.setNull(idx, Types.NULL);
            }
        }
    }

    private static void updateSqliteChangesAndRowId(SqliteInstance inst) {
        try (Statement st = inst.conn.createStatement();
             ResultSet rs = st.executeQuery("SELECT last_insert_rowid(), changes()")) {
            if (rs.next()) {
                inst.lastInsertId = rs.getLong(1);
                inst.lastChanges = rs.getLong(2);
            }
        } catch (SQLException ignored) {}
    }

    private Value execSqliteCall(Value arg, boolean isQuery) {
        if (!arg.isSeq() || arg.asSeq().size() < 2) {
            return makeSqliteError(isQuery, "Ungültige Argumente für SQLite-Aufruf");
        }
        Sequence s = arg.asSeq();
        long dbId = s.get(0).toIntCoerce();
        String sql = s.get(1).toUtf8String();
        Sequence params = (s.size() >= 3 && s.get(2).isSeq()) ? s.get(2).asSeq() : null;

        SqliteInstance inst = sqliteDbs.get(dbId);
        if (inst == null || inst.conn == null) {
            return makeSqliteError(isQuery, "Ungültiges SQLite Datenbank-Handle");
        }

        synchronized (inst) {
            if (!isQuery && (params == null || params.size() == 0)) {
                try (Statement st = inst.conn.createStatement()) {
                    for (String stmtSql : splitSqlStatements(sql)) {
                        st.execute(stmtSql);
                    }
                    updateSqliteChangesAndRowId(inst);
                    lastSqliteError = "";
                    return Value.fromInt(1);
                } catch (SQLException e) {
                    return makeSqliteError(false, e.getMessage());
                }
            }

            try (PreparedStatement pstmt = inst.conn.prepareStatement(sql)) {
                bindJdbcParameters(pstmt, params);
                if (!isQuery) {
                    pstmt.execute();
                    updateSqliteChangesAndRowId(inst);
                    lastSqliteError = "";
                    return Value.fromInt(1);
                }

                boolean hasRs = pstmt.execute();
                if (!hasRs) {
                    updateSqliteChangesAndRowId(inst);
                    lastSqliteError = "";
                    Sequence res = new Sequence(3);
                    res.setElement(0, Value.fromInt(1));
                    res.setElement(1, Value.emptySeq());
                    res.setElement(2, Value.emptySeq());
                    return Value.fromSeq(res);
                }

                try (ResultSet rs = pstmt.getResultSet()) {
                    ResultSetMetaData meta = rs.getMetaData();
                    int colCount = meta.getColumnCount();
                    Sequence colNames = new Sequence(colCount);
                    for (int c = 1; c <= colCount; c++) {
                        String cname = meta.getColumnLabel(c);
                        if (cname == null || cname.isEmpty()) cname = meta.getColumnName(c);
                        colNames.setElement(c - 1, Value.fromString(cname != null ? cname : ""));
                    }

                    Sequence rows = new Sequence();
                    while (rs.next()) {
                        Sequence row = new Sequence(colCount);
                        for (int c = 1; c <= colCount; c++) {
                            Object obj = rs.getObject(c);
                            Value cell;
                            if (obj == null) {
                                Sequence nullTag = new Sequence(2);
                                nullTag.setElement(0, Value.fromInt(DataEngines.JSON_TAG_NULL));
                                nullTag.setElement(1, Value.fromInt(0));
                                cell = Value.fromSeq(nullTag);
                            } else if (obj instanceof Integer || obj instanceof Long || obj instanceof Short || obj instanceof Byte) {
                                cell = Value.fromInt(((Number) obj).longValue());
                            } else if (obj instanceof Double || obj instanceof Float) {
                                cell = Value.fromF64(((Number) obj).doubleValue());
                            } else if (obj instanceof byte[] bytes) {
                                cell = Value.fromRawBytes(bytes);
                            } else {
                                cell = Value.fromString(obj.toString());
                            }
                            row.setElement(c - 1, cell);
                        }
                        rows.addElement(Value.fromSeq(row));
                    }

                    lastSqliteError = "";
                    Sequence res = new Sequence(3);
                    res.setElement(0, Value.fromInt(1));
                    res.setElement(1, Value.fromSeq(colNames));
                    res.setElement(2, Value.fromSeq(rows));
                    return Value.fromSeq(res);
                }
            } catch (SQLException e) {
                return makeSqliteError(isQuery, e.getMessage());
            }
        }
    }

    private Value execSqliteInfo(Value arg) {
        if (!arg.isSeq() || arg.asSeq().size() < 2) {
            return Value.fromInt(0);
        }
        long dbId = arg.asSeq().get(0).toIntCoerce();
        long kind = arg.asSeq().get(1).toIntCoerce();
        if (kind == 3) {
            return Value.fromString(lastSqliteError);
        }
        SqliteInstance inst = sqliteDbs.get(dbId);
        if (inst == null || inst.conn == null) {
            return Value.fromInt(-1);
        }
        if (kind == 1) {
            return Value.fromInt(inst.lastInsertId);
        } else if (kind == 2) {
            return Value.fromInt(inst.lastChanges);
        }
        return Value.fromString(lastSqliteError);
    }

    // -------------------------------------------------------------------------
    // PostgreSQL Engine via PgJDBC + Built-in v3 Wire Protocol (250..255)
    // -------------------------------------------------------------------------
    private static final class PgConnParams {
        String host = "127.0.0.1";
        int port = 5432;
        String user = "postgres";
        String pass = "";
        String dbname = "postgres";
    }

    private static PgConnParams parsePgConninfo(String conninfo) {
        PgConnParams p = new PgConnParams();
        if (conninfo.startsWith("postgresql://") || conninfo.startsWith("postgres://")) {
            int schemeEnd = conninfo.indexOf("://") + 3;
            String rest = conninfo.substring(schemeEnd);
            int slash = rest.indexOf('/');
            String authHost = (slash >= 0) ? rest.substring(0, slash) : rest;
            if (slash >= 0 && slash + 1 < rest.length()) {
                String dbPart = rest.substring(slash + 1);
                int q = dbPart.indexOf('?');
                p.dbname = (q >= 0) ? dbPart.substring(0, q) : dbPart;
            }
            int at = authHost.indexOf('@');
            String hostPort = (at >= 0) ? authHost.substring(at + 1) : authHost;
            if (at >= 0) {
                String up = authHost.substring(0, at);
                int col = up.indexOf(':');
                if (col >= 0) {
                    p.user = up.substring(0, col);
                    p.pass = up.substring(col + 1);
                } else {
                    p.user = up;
                }
            }
            int pcol = hostPort.indexOf(':');
            if (pcol >= 0) {
                p.host = hostPort.substring(0, pcol);
                try { p.port = Integer.parseInt(hostPort.substring(pcol + 1)); } catch (NumberFormatException ignored) {}
            } else if (!hostPort.isEmpty()) {
                p.host = hostPort;
            }
            return p;
        }

        int pos = 0;
        int n = conninfo.length();
        while (pos < n) {
            while (pos < n && Character.isWhitespace(conninfo.charAt(pos))) pos++;
            if (pos >= n) break;
            int eq = conninfo.indexOf('=', pos);
            if (eq < 0) break;
            String key = conninfo.substring(pos, eq).trim();
            pos = eq + 1;
            StringBuilder val = new StringBuilder();
            if (pos < n && conninfo.charAt(pos) == '\'') {
                pos++;
                while (pos < n && conninfo.charAt(pos) != '\'') {
                    val.append(conninfo.charAt(pos++));
                }
                if (pos < n) pos++;
            } else {
                while (pos < n && !Character.isWhitespace(conninfo.charAt(pos))) {
                    val.append(conninfo.charAt(pos++));
                }
            }
            String v = val.toString();
            switch (key) {
                case "host", "hostaddr" -> p.host = v;
                case "port" -> { try { p.port = Integer.parseInt(v); } catch (NumberFormatException ignored) {} }
                case "user" -> p.user = v;
                case "password" -> p.pass = v;
                case "dbname" -> p.dbname = v;
            }
        }
        return p;
    }

    private static String translatePgPlaceholders(String sql) {
        StringBuilder out = new StringBuilder(sql.length() + 16);
        boolean inSQuote = false;
        boolean inDQuote = false;
        int paramIdx = 1;
        for (int i = 0; i < sql.length(); i++) {
            char c = sql.charAt(i);
            if (c == '\'' && !inDQuote) {
                inSQuote = !inSQuote;
                out.append(c);
            } else if (c == '"' && !inSQuote) {
                inDQuote = !inDQuote;
                out.append(c);
            } else if (c == '?' && !inSQuote && !inDQuote) {
                out.append('$').append(paramIdx++);
            } else {
                out.append(c);
            }
        }
        return out.toString();
    }

    private static String pgEscapeSqlLiteral(String sv) {
        StringBuilder out = new StringBuilder(sv.length() + 4);
        out.append('\'');
        for (int i = 0; i < sv.length(); i++) {
            char c = sv.charAt(i);
            if (c == '\'') out.append("''");
            else out.append(c);
        }
        out.append('\'');
        return out.toString();
    }

    private static String pgEscapeSqlIdent(String sv) {
        StringBuilder out = new StringBuilder(sv.length() + 4);
        out.append('"');
        for (int i = 0; i < sv.length(); i++) {
            char c = sv.charAt(i);
            if (c == '"') out.append("\"\"");
            else out.append(c);
        }
        out.append('"');
        return out.toString();
    }

    private static String substitutePgParamsForWire(String rawSql, Sequence params) {
        if (params == null || params.size() == 0) {
            return rawSql;
        }
        String sql = translatePgPlaceholders(rawSql);
        String[] rendered = new String[params.size()];
        for (int i = 0; i < params.size(); i++) {
            Value pv = params.get(i);
            if (pv.isInt()) {
                rendered[i] = Long.toString(pv.asInt());
            } else if (pv.isF64()) {
                rendered[i] = Double.toString(pv.asF64());
            } else if (pv.isSeq()) {
                Sequence ps = pv.asSeq();
                if ((ps.size() == 1 && ps.get(0).isInt() && ps.get(0).asInt() == 0) ||
                    (ps.size() == 2 && ps.get(0).isInt() && ps.get(0).asInt() == DataEngines.JSON_TAG_NULL)) {
                    rendered[i] = "NULL";
                } else if (ps.size() == 2 && ps.get(0).isInt() && ps.get(0).asInt() == DataEngines.JSON_TAG_STRING) {
                    rendered[i] = pgEscapeSqlLiteral(ps.get(1).toUtf8String());
                } else {
                    rendered[i] = pgEscapeSqlLiteral(pv.toUtf8String());
                }
            } else {
                rendered[i] = "NULL";
            }
        }

        StringBuilder out = new StringBuilder(sql.length() + 32);
        boolean inSQuote = false;
        boolean inDQuote = false;
        for (int i = 0; i < sql.length(); i++) {
            char c = sql.charAt(i);
            if (c == '\'' && !inDQuote) {
                inSQuote = !inSQuote;
                out.append(c);
            } else if (c == '"' && !inSQuote) {
                inDQuote = !inDQuote;
                out.append(c);
            } else if (c == '$' && !inSQuote && !inDQuote && i + 1 < sql.length() && Character.isDigit(sql.charAt(i + 1))) {
                int j = i + 1;
                int idx = 0;
                while (j < sql.length() && Character.isDigit(sql.charAt(j))) {
                    idx = idx * 10 + (sql.charAt(j) - '0');
                    j++;
                }
                if (idx >= 1 && idx <= rendered.length) {
                    out.append(rendered[idx - 1]);
                    i = j - 1;
                } else {
                    out.append(c);
                }
            } else {
                out.append(c);
            }
        }
        return out.toString();
    }

    private static void writeBe32(ByteArrayOutputStream bos, int v) {
        bos.write((v >>> 24) & 0xFF);
        bos.write((v >>> 16) & 0xFF);
        bos.write((v >>> 8) & 0xFF);
        bos.write(v & 0xFF);
    }

    private static int readBe32(byte[] b, int off) {
        return ((b[off] & 0xFF) << 24)
             | ((b[off + 1] & 0xFF) << 16)
             | ((b[off + 2] & 0xFF) << 8)
             | (b[off + 3] & 0xFF);
    }

    private static int readBe16(byte[] b, int off) {
        return ((b[off] & 0xFF) << 8) | (b[off + 1] & 0xFF);
    }

    private static boolean readExact(InputStream in, byte[] buf, int len) throws IOException {
        int got = 0;
        while (got < len) {
            int n = in.read(buf, got, len - got);
            if (n <= 0) return false;
            got += n;
        }
        return true;
    }

    private Value execPgOpen(Value arg) {
        String conninfo = arg.isSeq() ? arg.toUtf8String() : "";
        PgConnParams cp = parsePgConninfo(conninfo);
        PgConnInstance inst = new PgConnInstance();

        // Try v3 Wire Protocol first (supports mock server in 06_postgresql_datenbank.ex and trust/cleartext auth),
        // and transparently upgrade to PgJDBC (org.postgresql.Driver) if SCRAM-SHA-256 / MD5 / TLS is requested!
        boolean tryJdbcFallback = conninfo.startsWith("jdbc:postgresql:");
        if (!tryJdbcFallback) {
            try {
                Socket sock = new Socket(InetAddress.getByName(cp.host), cp.port);
                sock.setSoTimeout(10000);
                InputStream in = sock.getInputStream();
                OutputStream out = sock.getOutputStream();

                ByteArrayOutputStream body = new ByteArrayOutputStream(128);
                writeBe32(body, 196608); // v3.0
                body.write("user\0".getBytes(StandardCharsets.UTF_8));
                body.write(cp.user.getBytes(StandardCharsets.UTF_8));
                body.write(0);
                body.write("database\0".getBytes(StandardCharsets.UTF_8));
                body.write(cp.dbname.getBytes(StandardCharsets.UTF_8));
                body.write(0);
                body.write("client_encoding\0UTF8\0".getBytes(StandardCharsets.UTF_8));
                body.write(0);

                byte[] bodyBytes = body.toByteArray();
                ByteArrayOutputStream pkt = new ByteArrayOutputStream(bodyBytes.length + 4);
                writeBe32(pkt, bodyBytes.length + 4);
                pkt.write(bodyBytes);
                out.write(pkt.toByteArray());
                out.flush();

                byte[] hdr = new byte[5];
                for (;;) {
                    if (!readExact(in, hdr, 5)) {
                        sock.close();
                        lastPgError = "PostgreSQL Server hat die Verbindung während des Handshakes geschlossen";
                        return Value.fromInt(0);
                    }
                    char type = (char) (hdr[0] & 0xFF);
                    int msgLen = readBe32(hdr, 1);
                    byte[] payload = new byte[Math.max(0, msgLen - 4)];
                    if (payload.length > 0 && !readExact(in, payload, payload.length)) {
                        sock.close();
                        lastPgError = "Unvollständige Antwort vom PostgreSQL Server";
                        return Value.fromInt(0);
                    }
                    if (type == 'R') {
                        int authCode = (payload.length >= 4) ? readBe32(payload, 0) : 99;
                        if (authCode == 0) {
                            continue;
                        } else if (authCode == 3) {
                            byte[] pwBytes = cp.pass.getBytes(StandardCharsets.UTF_8);
                            ByteArrayOutputStream pwPkt = new ByteArrayOutputStream(pwBytes.length + 6);
                            pwPkt.write('p');
                            writeBe32(pwPkt, 4 + pwBytes.length + 1);
                            pwPkt.write(pwBytes);
                            pwPkt.write(0);
                            out.write(pwPkt.toByteArray());
                            out.flush();
                        } else {
                            // SCRAM-SHA-256 (10) or MD5 (5) -> use PostgreSQL JDBC driver!
                            sock.close();
                            tryJdbcFallback = true;
                            break;
                        }
                    } else if (type == 'E') {
                        sock.close();
                        lastPgError = extractPgErrorMessage(payload);
                        return Value.fromInt(0);
                    } else if (type == 'Z') {
                        inst.wireSocket = sock;
                        inst.wireIn = in;
                        inst.wireOut = out;
                        lastPgError = "";
                        long dbId = nextPgId.getAndIncrement();
                        pgDbs.put(dbId, inst);
                        return Value.fromInt(dbId);
                    }
                }
            } catch (IOException e) {
                lastPgError = e.getMessage() != null ? e.getMessage() : "PostgreSQL Verbindungsfehler";
                return Value.fromInt(0);
            }
        }

        if (tryJdbcFallback) {
            try {
                String jdbcUrl = conninfo.startsWith("jdbc:postgresql:")
                    ? conninfo
                    : String.format("jdbc:postgresql://%s:%d/%s", cp.host, cp.port, cp.dbname);
                Properties props = new Properties();
                props.setProperty("user", cp.user);
                props.setProperty("password", cp.pass);
                props.setProperty("preferQueryMode", "simple");
                Connection conn = DriverManager.getConnection(jdbcUrl, props);
                inst.jdbcConn = conn;
                lastPgError = "";
                long dbId = nextPgId.getAndIncrement();
                pgDbs.put(dbId, inst);
                return Value.fromInt(dbId);
            } catch (SQLException e) {
                lastPgError = e.getMessage() != null ? e.getMessage() : "PostgreSQL JDBC Verbindungsfehler";
                return Value.fromInt(0);
            }
        }
        return Value.fromInt(0);
    }

    private static String extractPgErrorMessage(byte[] payload) {
        int pos = 0;
        while (pos < payload.length && payload[pos] != 0) {
            char ftype = (char) (payload[pos++] & 0xFF);
            int end = pos;
            while (end < payload.length && payload[end] != 0) end++;
            if (ftype == 'M') {
                return new String(payload, pos, end - pos, StandardCharsets.UTF_8);
            }
            pos = end + 1;
        }
        return "PostgreSQL SQL-Fehler";
    }

    private Value execPgClose(Value arg) {
        long dbId = (arg.isSeq() && arg.asSeq().size() > 0)
            ? arg.asSeq().get(0).toIntCoerce()
            : arg.toIntCoerce();
        PgConnInstance inst = pgDbs.remove(dbId);
        if (inst != null) {
            inst.closeQuietly();
            return Value.fromInt(1);
        }
        return Value.fromInt(0);
    }

    private Value makePgError(boolean isQuery, String msg) {
        lastPgError = msg != null ? msg : "PostgreSQL Error";
        if (isQuery) {
            Sequence r = new Sequence(3);
            r.setElement(0, Value.fromInt(0));
            r.setElement(1, Value.fromString(lastPgError));
            r.setElement(2, Value.emptySeq());
            return Value.fromSeq(r);
        }
        return Value.fromInt(0);
    }

    private Value execPgCall(Value arg, boolean isQuery) {
        if (!arg.isSeq() || arg.asSeq().size() < 2) {
            return makePgError(isQuery, "Ungültige Argumente für PostgreSQL-Aufruf");
        }
        Sequence s = arg.asSeq();
        long dbId = s.get(0).toIntCoerce();
        String rawSql = s.get(1).toUtf8String();
        Sequence params = (s.size() >= 3 && s.get(2).isSeq()) ? s.get(2).asSeq() : null;

        PgConnInstance inst = pgDbs.get(dbId);
        if (inst == null || !inst.isValid()) {
            return makePgError(isQuery, "Ungültiges PostgreSQL Datenbank-Handle");
        }

        String finalSql = substitutePgParamsForWire(rawSql, params);
        if (inst.wireSocket != null) {
            return execPgWireQuery(inst, finalSql, isQuery);
        }

        // PgJDBC execution path
        try (Statement st = inst.jdbcConn.createStatement()) {
            boolean hasRs = st.execute(finalSql);
            int updateCnt = st.getUpdateCount();
            inst.lastAffectedRows = Math.max(0, updateCnt);
            lastPgError = "";
            if (!isQuery) {
                return Value.fromInt(1);
            }
            if (!hasRs) {
                Sequence outSeq = new Sequence(3);
                outSeq.setElement(0, Value.fromInt(1));
                outSeq.setElement(1, Value.emptySeq());
                outSeq.setElement(2, Value.emptySeq());
                return Value.fromSeq(outSeq);
            }
            try (ResultSet rs = st.getResultSet()) {
                ResultSetMetaData meta = rs.getMetaData();
                int ncols = meta.getColumnCount();
                Sequence colNames = new Sequence(ncols);
                for (int c = 1; c <= ncols; c++) {
                    colNames.setElement(c - 1, Value.fromString(meta.getColumnLabel(c)));
                }
                Sequence rows = new Sequence();
                while (rs.next()) {
                    Sequence row = new Sequence(ncols);
                    for (int c = 1; c <= ncols; c++) {
                        Object obj = rs.getObject(c);
                        Value cell;
                        if (obj == null) {
                            Sequence nullTag = new Sequence(2);
                            nullTag.setElement(0, Value.fromInt(DataEngines.JSON_TAG_NULL));
                            nullTag.setElement(1, Value.fromInt(0));
                            cell = Value.fromSeq(nullTag);
                        } else if (obj instanceof Boolean b) {
                            cell = Value.fromInt(b ? 1 : 0);
                        } else if (obj instanceof Integer || obj instanceof Long || obj instanceof Short) {
                            cell = Value.fromInt(((Number) obj).longValue());
                        } else if (obj instanceof Number num) {
                            cell = Value.fromF64(num.doubleValue());
                        } else {
                            cell = Value.fromString(obj.toString());
                        }
                        row.setElement(c - 1, cell);
                    }
                    rows.addElement(Value.fromSeq(row));
                }
                Sequence outSeq = new Sequence(3);
                outSeq.setElement(0, Value.fromInt(1));
                outSeq.setElement(1, Value.fromSeq(colNames));
                outSeq.setElement(2, Value.fromSeq(rows));
                return Value.fromSeq(outSeq);
            }
        } catch (SQLException e) {
            return makePgError(isQuery, e.getMessage());
        }
    }

    private Value execPgWireQuery(PgConnInstance inst, String sql, boolean isQuery) {
        try {
            byte[] sqlBytes = sql.getBytes(StandardCharsets.UTF_8);
            ByteArrayOutputStream qpkt = new ByteArrayOutputStream(sqlBytes.length + 6);
            qpkt.write('Q');
            writeBe32(qpkt, 4 + sqlBytes.length + 1);
            qpkt.write(sqlBytes);
            qpkt.write(0);
            inst.wireOut.write(qpkt.toByteArray());
            inst.wireOut.flush();

            Sequence outCols = new Sequence();
            Sequence outRows = new Sequence();
            long affected = 0;
            List<Integer> colOids = new ArrayList<>();
            boolean hadError = false;
            String errMsg = "";
            byte[] hdr = new byte[5];

            for (;;) {
                if (!readExact(inst.wireIn, hdr, 5)) {
                    return makePgError(isQuery, "Verbindungsabbruch beim Lesen der PostgreSQL-Antwort");
                }
                char type = (char) (hdr[0] & 0xFF);
                int msgLen = readBe32(hdr, 1);
                byte[] payload = new byte[Math.max(0, msgLen - 4)];
                if (payload.length > 0 && !readExact(inst.wireIn, payload, payload.length)) {
                    return makePgError(isQuery, "Unvollständiges Antwortpaket vom PostgreSQL Server");
                }

                if (type == 'T') {
                    if (payload.length >= 2) {
                        int ncols = readBe16(payload, 0);
                        outCols = new Sequence();
                        colOids.clear();
                        int pos = 2;
                        for (int c = 0; c < ncols && pos < payload.length; c++) {
                            int end = pos;
                            while (end < payload.length && payload[end] != 0) end++;
                            if (end >= payload.length) break;
                            String cname = new String(payload, pos, end - pos, StandardCharsets.UTF_8);
                            pos = end + 1;
                            int oid = 25;
                            if (pos + 18 <= payload.length) {
                                oid = readBe32(payload, pos + 6);
                                pos += 18;
                            }
                            outCols.addElement(Value.fromString(cname));
                            colOids.add(oid);
                        }
                    }
                } else if (type == 'D') {
                    if (payload.length >= 2) {
                        int ncols = readBe16(payload, 0);
                        Sequence row = new Sequence(ncols);
                        int pos = 2;
                        for (int c = 0; c < ncols; c++) {
                            if (pos + 4 > payload.length) break;
                            int clen = readBe32(payload, pos);
                            pos += 4;
                            if (clen < 0) {
                                Sequence nullTag = new Sequence(2);
                                nullTag.setElement(0, Value.fromInt(DataEngines.JSON_TAG_NULL));
                                nullTag.setElement(1, Value.fromInt(0));
                                row.setElement(c, Value.fromSeq(nullTag));
                            } else {
                                byte[] valBytes = new byte[0];
                                if (pos + clen <= payload.length) {
                                    valBytes = Arrays.copyOfRange(payload, pos, pos + clen);
                                    pos += clen;
                                }
                                String valStr = new String(valBytes, StandardCharsets.UTF_8);
                                int oid = (c < colOids.size()) ? colOids.get(c) : 25;
                                if (oid == 16) {
                                    boolean b = !valStr.isEmpty() && (valStr.charAt(0) == 't' || valStr.charAt(0) == '1');
                                    row.setElement(c, Value.fromInt(b ? 1 : 0));
                                } else if (oid == 20 || oid == 21 || oid == 23 || oid == 26) {
                                    long iv = 0;
                                    try { iv = Long.parseLong(valStr.trim()); } catch (NumberFormatException ignored) {}
                                    row.setElement(c, Value.fromInt(iv));
                                } else if (oid == 700 || oid == 701 || oid == 1700) {
                                    double dv = 0.0;
                                    try { dv = Double.parseDouble(valStr.trim()); } catch (NumberFormatException ignored) {}
                                    row.setElement(c, Value.fromF64(dv));
                                } else {
                                    row.setElement(c, Value.fromRawBytes(valBytes));
                                }
                            }
                        }
                        outRows.addElement(Value.fromSeq(row));
                    }
                } else if (type == 'C') {
                    int end = 0;
                    while (end < payload.length && payload[end] != 0) end++;
                    String tag = new String(payload, 0, end, StandardCharsets.UTF_8);
                    int lastSp = tag.lastIndexOf(' ');
                    if (lastSp >= 0 && lastSp + 1 < tag.length() && Character.isDigit(tag.charAt(lastSp + 1))) {
                        try { affected = Long.parseLong(tag.substring(lastSp + 1).trim()); } catch (NumberFormatException ignored) {}
                    }
                } else if (type == 'E') {
                    hadError = true;
                    errMsg = extractPgErrorMessage(payload);
                } else if (type == 'Z') {
                    break;
                }
            }

            if (hadError) {
                return makePgError(isQuery, errMsg);
            }
            inst.lastAffectedRows = affected;
            lastPgError = "";
            if (!isQuery) {
                return Value.fromInt(1);
            }
            Sequence outSeq = new Sequence(3);
            outSeq.setElement(0, Value.fromInt(1));
            outSeq.setElement(1, Value.fromSeq(outCols));
            outSeq.setElement(2, Value.fromSeq(outRows));
            return Value.fromSeq(outSeq);
        } catch (IOException e) {
            return makePgError(isQuery, e.getMessage());
        }
    }

    private Value execPgInfo(Value arg) {
        if (!arg.isSeq() || arg.asSeq().size() < 2) {
            return Value.fromInt(0);
        }
        long dbId = arg.asSeq().get(0).toIntCoerce();
        long kind = arg.asSeq().get(1).toIntCoerce();
        if (kind == 4) {
            return Value.fromInt(1);
        }
        if (kind == 3) {
            return Value.fromString(lastPgError);
        }
        PgConnInstance inst = pgDbs.get(dbId);
        if (inst == null || !inst.isValid()) {
            return Value.fromInt(-1);
        }
        if (kind == 1) {
            return Value.fromInt(inst.lastAffectedRows);
        } else if (kind == 2) {
            return Value.fromInt(inst.serverVer);
        }
        return Value.fromInt(0);
    }

    private Value execPgEscape(Value arg) {
        if (!arg.isSeq() || arg.asSeq().size() < 3) {
            return Value.emptySeq();
        }
        String txt = arg.asSeq().get(1).toUtf8String();
        boolean isIdent = (arg.asSeq().get(2).toIntCoerce() != 0);
        return Value.fromString(isIdent ? pgEscapeSqlIdent(txt) : pgEscapeSqlLiteral(txt));
    }

    private static double f80ToDouble(byte[] b) {
        long mantissa = 0;
        for (int i = 0; i < 8; i++) {
            mantissa |= ((long) (b[i] & 0xFF)) << (i * 8);
        }
        int exp = (b[8] & 0xFF) | ((b[9] & 0x7F) << 8);
        int sign = (b[9] & 0x80) != 0 ? -1 : 1;

        if (exp == 0 && mantissa == 0) {
            return sign < 0 ? -0.0 : 0.0;
        }
        if (exp == 0x7FFF) {
            if ((mantissa & 0x7FFFFFFFFFFFFFFFL) == 0) {
                return sign < 0 ? Double.NEGATIVE_INFINITY : Double.POSITIVE_INFINITY;
            }
            return Double.NaN;
        }

        double mDouble = (mantissa < 0) ? (mantissa >>> 1) * 2.0 + (mantissa & 1) : (double) mantissa;
        int trueExp = exp - 16383 - 63;
        return sign * Math.scalb(mDouble, trueExp);
    }

    private static byte[] doubleToF80(double d) {
        byte[] b = new byte[10];
        if (d == 0.0) {
            if (Double.doubleToRawLongBits(d) < 0) b[9] = (byte) 0x80;
            return b;
        }
        if (Double.isInfinite(d)) {
            b[9] = (byte) ((d < 0 ? 0x80 : 0) | 0x7F);
            b[8] = (byte) 0xFF;
            b[7] = (byte) 0x80;
            return b;
        }
        if (Double.isNaN(d)) {
            b[9] = (byte) 0x7F;
            b[8] = (byte) 0xFF;
            b[7] = (byte) 0xC0;
            return b;
        }
        long bits = Double.doubleToRawLongBits(d);
        boolean neg = (bits < 0);
        int dExp = (int) ((bits >>> 52) & 0x7FFL);
        long dMant = bits & 0xFFFFFFFFFFFFFL;

        int exp80;
        long mant80;
        if (dExp == 0) {
            int shift = Long.numberOfLeadingZeros(dMant) - 11;
            mant80 = (dMant << (shift + 11));
            exp80 = 16383 - 1022 - shift;
        } else {
            mant80 = 0x8000000000000000L | (dMant << 11);
            exp80 = dExp - 1023 + 16383;
        }

        for (int i = 0; i < 8; i++) {
            b[i] = (byte) ((mant80 >>> (i * 8)) & 0xFF);
        }
        b[8] = (byte) (exp80 & 0xFF);
        b[9] = (byte) (((exp80 >>> 8) & 0x7F) | (neg ? 0x80 : 0));
        return b;
    }
}
