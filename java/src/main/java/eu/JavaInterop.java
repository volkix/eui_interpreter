package eu;

import java.io.*;
import java.lang.reflect.*;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

/**
 * High-performance Java Reflection & Virtual Thread Subprocess Management for OpenEuphoria on Linux 64-bit.
 */
public final class JavaInterop {

    private static final List<URL> JAR_URLS = new CopyOnWriteArrayList<>();
    private static volatile URLClassLoader DYNAMIC_LOADER = new URLClassLoader(new URL[0], JavaInterop.class.getClassLoader());

    private static final AtomicLong NEXT_OBJECT_ID = new AtomicLong(0x10000000L);
    private static final Map<Long, Object> OBJECT_REGISTRY = new ConcurrentHashMap<>();
    private static final Map<Object, Long> REVERSE_OBJECT_REGISTRY = Collections.synchronizedMap(new IdentityHashMap<>());

    private static final AtomicLong NEXT_PIPE_ID = new AtomicLong(0x20000000L);
    private static final Map<Long, PipeChannel> OPEN_PIPE_CHANNELS = new ConcurrentHashMap<>();
    private static final Map<Long, ProcessPipe> MANAGED_PROCESSES = new ConcurrentHashMap<>();

    private static volatile VM activeVm;

    public static void setActiveVm(VM vm) {
        activeVm = vm;
    }

    public static VM getActiveVm() {
        return activeVm;
    }

    private JavaInterop() {}

    // =========================================================================
    // 1. DYNAMIC JAR & CLASS LOADING
    // =========================================================================

    public static synchronized boolean loadJar(String jarPath) {
        if (jarPath == null || jarPath.isBlank()) return false;
        try {
            Path p = Path.of(jarPath).toAbsolutePath();
            if (!Files.exists(p)) return false;
            URL url = p.toUri().toURL();
            if (!JAR_URLS.contains(url)) {
                JAR_URLS.add(url);
                DYNAMIC_LOADER = new URLClassLoader(JAR_URLS.toArray(new URL[0]), JavaInterop.class.getClassLoader());
            }
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    public static Class<?> resolveClass(Object classOrName) throws ClassNotFoundException {
        if (classOrName instanceof Class<?> c) return c;
        if (classOrName instanceof String s) {
            try {
                return Class.forName(s, true, DYNAMIC_LOADER);
            } catch (ClassNotFoundException e) {
                // Try convenience packages (java.lang, javax.swing, java.awt, event packages)
                if (!s.contains(".")) {
                    for (String pkg : List.of("java.lang.", "javax.swing.", "java.awt.", "java.awt.event.", "javax.swing.event.")) {
                        try {
                            return Class.forName(pkg + s, true, DYNAMIC_LOADER);
                        } catch (ClassNotFoundException ignored) {}
                    }
                }
                throw e;
            }
        }
        if (classOrName instanceof Long id) {
            Object obj = OBJECT_REGISTRY.get(id);
            if (obj instanceof Class<?> c) return c;
            if (obj != null) return obj.getClass();
        }
        throw new ClassNotFoundException("Invalid class reference: " + classOrName);
    }

    public static Value findClass(String className) {
        try {
            Class<?> c = resolveClass(className);
            long id = NEXT_OBJECT_ID.getAndIncrement();
            OBJECT_REGISTRY.put(id, c);
            return Value.fromInt(id);
        } catch (ClassNotFoundException e) {
            return Value.fromInt(0);
        }
    }

    public static long registerObject(Object obj) {
        if (obj == null) return 0;
        Long existing = REVERSE_OBJECT_REGISTRY.get(obj);
        if (existing != null) return existing;
        long id = NEXT_OBJECT_ID.getAndIncrement();
        OBJECT_REGISTRY.put(id, obj);
        REVERSE_OBJECT_REGISTRY.put(obj, id);
        return id;
    }

    public static Object getObject(long handle) {
        if (handle == 0) return null;
        return OBJECT_REGISTRY.get(handle);
    }

    public static Value createListener(Object classOrName, int routineId) {
        try {
            Class<?> ifaceClass = resolveClass(classOrName);
            if (!ifaceClass.isInterface()) return Value.fromInt(0);

            Object proxy = Proxy.newProxyInstance(
                DYNAMIC_LOADER,
                new Class<?>[]{ifaceClass},
                (p, method, mArgs) -> {
                    String mName = method.getName();
                    if ("toString".equals(mName)) return "EuphoriaListenerProxy[" + routineId + "]";
                    if ("hashCode".equals(mName)) return System.identityHashCode(p);
                    if ("equals".equals(mName)) return p == (mArgs != null && mArgs.length > 0 ? mArgs[0] : null);

                    VM vm = activeVm;
                    if (vm != null) {
                        List<Value> euArgs = new ArrayList<>();
                        if (mArgs != null) {
                            for (Object ma : mArgs) {
                                if (ma instanceof java.util.EventObject eo && eo.getSource() != null) {
                                    euArgs.add(Value.fromInt(registerObject(eo.getSource())));
                                } else {
                                    euArgs.add(toEuphoriaValue(ma));
                                }
                            }
                        }
                        Value ret = vm.invokeRoutine(routineId, euArgs);
                        return toJavaObject(ret, method.getReturnType());
                    }
                    return null;
                }
            );
            return Value.fromInt(registerObject(proxy));
        } catch (Throwable t) {
            return Value.fromInt(0);
        }
    }

    // =========================================================================
    // 2. REFLECTION: NEW OBJECT, METHOD INVOCATION, FIELD ACCESS
    // =========================================================================

    public static Value newObject(Object classOrName, List<Value> args) {
        try {
            Class<?> cls = resolveClass(classOrName);
            Constructor<?> best = null;
            int bestScore = -1;
            for (Constructor<?> ctor : cls.getConstructors()) {
                if (ctor.getParameterCount() != args.size()) continue;
                int score = scoreMethod(ctor.getParameterTypes(), args);
                if (score > bestScore) {
                    bestScore = score;
                    best = ctor;
                }
            }
            if (best == null) return Value.fromInt(0);
            Object[] javaArgs = convertArgs(args, best.getParameterTypes());
            Object instance = best.newInstance(javaArgs);
            return Value.fromInt(registerObject(instance));
        } catch (Throwable t) {
            return Value.fromInt(0);
        }
    }

    public static Value callStatic(Object classOrName, String methodName, List<Value> args) {
        try {
            Class<?> cls = resolveClass(classOrName);
            Method method = findBestMethod(cls, methodName, args, true);
            if (method == null) return Value.fromInt(0);
            Object[] javaArgs = convertArgs(args, method.getParameterTypes());
            Object result = method.invoke(null, javaArgs);
            return toEuphoriaValue(result);
        } catch (Throwable t) {
            return Value.fromInt(0);
        }
    }

    public static Value callMethod(long handle, String methodName, List<Value> args) {
        try {
            Object target = getObject(handle);
            if (target == null) return Value.fromInt(0);
            Class<?> cls = (target instanceof Class<?> c) ? c : target.getClass();
            Method method = findBestMethod(cls, methodName, args, false);
            if (method == null) {
                // If not found as instance method, check if it is static method called on class handle
                if (target instanceof Class<?>) {
                    method = findBestMethod(cls, methodName, args, true);
                    if (method != null) {
                        Object[] javaArgs = convertArgs(args, method.getParameterTypes());
                        Object result = method.invoke(null, javaArgs);
                        return toEuphoriaValue(result);
                    }
                }
                return Value.fromInt(0);
            }
            Object[] javaArgs = convertArgs(args, method.getParameterTypes());
            Object result = method.invoke(target, javaArgs);
            return toEuphoriaValue(result);
        } catch (Throwable t) {
            return Value.fromInt(0);
        }
    }

    public static Value getField(Object targetOrClass, String fieldName) {
        try {
            if (targetOrClass instanceof String s) {
                Class<?> cls = resolveClass(s);
                Field f = cls.getField(fieldName);
                return toEuphoriaValue(f.get(null));
            }
            if (targetOrClass instanceof Long h) {
                Object obj = getObject(h);
                if (obj instanceof Class<?> cls) {
                    Field f = cls.getField(fieldName);
                    return toEuphoriaValue(f.get(null));
                } else if (obj != null) {
                    Field f = obj.getClass().getField(fieldName);
                    return toEuphoriaValue(f.get(obj));
                }
            }
            return Value.fromInt(0);
        } catch (Throwable t) {
            return Value.fromInt(0);
        }
    }

    public static boolean setField(Object targetOrClass, String fieldName, Value val) {
        try {
            if (targetOrClass instanceof String s) {
                Class<?> cls = resolveClass(s);
                Field f = cls.getField(fieldName);
                f.set(null, toJavaObject(val, f.getType()));
                return true;
            }
            if (targetOrClass instanceof Long h) {
                Object obj = getObject(h);
                if (obj instanceof Class<?> cls) {
                    Field f = cls.getField(fieldName);
                    f.set(null, toJavaObject(val, f.getType()));
                    return true;
                } else if (obj != null) {
                    Field f = obj.getClass().getField(fieldName);
                    f.set(obj, toJavaObject(val, f.getType()));
                    return true;
                }
            }
            return false;
        } catch (Throwable t) {
            return false;
        }
    }

    public static Value toStringVal(long handle) {
        Object obj = getObject(handle);
        if (obj == null) return Value.fromString("null");
        return Value.fromString(obj.toString());
    }

    // =========================================================================
    // 3. TYPE CONVERSIONS & METHOD MATCHING (EUPHORIA <-> JAVA)
    // =========================================================================

    public static Value toEuphoriaValue(Object obj) {
        if (obj == null) return Value.fromInt(0);
        if (obj instanceof Boolean b) return Value.fromInt(b ? 1 : 0);
        if (obj instanceof Byte || obj instanceof Short || obj instanceof Integer || obj instanceof Long) {
            return Value.fromInt(((Number) obj).longValue());
        }
        if (obj instanceof Float || obj instanceof Double) {
            return Value.fromF64(((Number) obj).doubleValue());
        }
        if (obj instanceof Character c) {
            return Value.fromInt(c);
        }
        if (obj instanceof String s) return Value.fromString(s);
        if (obj instanceof byte[] bytes) return Value.fromRawBytes(bytes);
        if (obj instanceof Collection<?> col) {
            Sequence seq = new Sequence(col.size());
            int i = 0;
            for (Object item : col) {
                seq.setElement(i++, toEuphoriaValue(item));
            }
            return Value.fromSeq(seq);
        }
        if (obj instanceof Object[] arr) {
            Sequence seq = new Sequence(arr.length);
            for (int i = 0; i < arr.length; i++) {
                seq.setElement(i, toEuphoriaValue(arr[i]));
            }
            return Value.fromSeq(seq);
        }
        return Value.fromInt(registerObject(obj));
    }

    public static Object toJavaObject(Value v, Class<?> targetType) {
        if (v == null || v.isNone()) return null;
        if (targetType == void.class || targetType == Void.class) return null;
        if (!targetType.isPrimitive() && v.isInt() && v.asInt() == 0) return null;
        if (targetType == boolean.class || targetType == Boolean.class) {
            return v.toIntCoerce() != 0;
        }
        if (targetType == byte.class || targetType == Byte.class) {
            return (byte) v.toIntCoerce();
        }
        if (targetType == short.class || targetType == Short.class) {
            return (short) v.toIntCoerce();
        }
        if (targetType == int.class || targetType == Integer.class) {
            return (int) v.toIntCoerce();
        }
        if (targetType == long.class || targetType == Long.class) {
            return v.toIntCoerce();
        }
        if (targetType == float.class || targetType == Float.class) {
            return (float) v.asF64();
        }
        if (targetType == double.class || targetType == Double.class) {
            return v.asF64();
        }
        if (targetType == char.class || targetType == Character.class) {
            return (char) v.toIntCoerce();
        }
        if (targetType == String.class || targetType == CharSequence.class) {
            return v.toUtf8String();
        }
        if (targetType == byte[].class) {
            if (v.isSeq()) {
                Sequence s = v.asSeq();
                byte[] b = new byte[s.size()];
                for (int i = 0; i < s.size(); i++) {
                    b[i] = (byte) s.get(i).toIntCoerce();
                }
                return b;
            }
            return new byte[0];
        }
        if (v.isInt() && OBJECT_REGISTRY.containsKey(v.asInt())) {
            Object reg = OBJECT_REGISTRY.get(v.asInt());
            if (targetType.isInstance(reg) || targetType == Object.class) {
                return reg;
            }
        }
        if (targetType == Object.class) {
            if (v.isInt()) return v.asInt();
            if (v.isF64()) return v.asF64();
            if (v.isSeq()) return v.toUtf8String();
        }
        return null;
    }

    private static Object[] convertArgs(List<Value> args, Class<?>[] paramTypes) {
        Object[] res = new Object[paramTypes.length];
        for (int i = 0; i < paramTypes.length; i++) {
            Value v = (i < args.size()) ? args.get(i) : Value.NONE;
            Object obj = toJavaObject(v, paramTypes[i]);
            res[i] = obj;
        }
        return res;
    }

    private static int scoreMethod(Class<?>[] paramTypes, List<Value> args) {
        if (paramTypes.length != args.size()) return -1;
        int score = 0;
        for (int i = 0; i < paramTypes.length; i++) {
            Class<?> pt = paramTypes[i];
            Value v = args.get(i);
            if (v.isInt()) {
                long val = v.asInt();
                if (OBJECT_REGISTRY.containsKey(val)) {
                    Object reg = OBJECT_REGISTRY.get(val);
                    if (pt.isInstance(reg)) {
                        score += 100;
                        continue;
                    }
                }
                if (pt == int.class || pt == Integer.class) score += 50;
                else if (pt == long.class || pt == Long.class) score += 45;
                else if (pt == boolean.class || pt == Boolean.class) score += 40;
                else if (pt == short.class || pt == Short.class || pt == byte.class || pt == Byte.class) score += 30;
                else if (pt == double.class || pt == Double.class || pt == float.class || pt == Float.class) score += 20;
                else if (pt == Object.class) score += 10;
                else return -1; // Incompatible
            } else if (v.isF64()) {
                if (pt == double.class || pt == Double.class) score += 50;
                else if (pt == float.class || pt == Float.class) score += 45;
                else if (pt == Object.class) score += 10;
                else return -1; // Incompatible
            } else if (v.isSeq()) {
                if (pt == String.class || pt == CharSequence.class) score += 50;
                else if (pt == byte[].class) score += 45;
                else if (pt == List.class || pt == Collection.class) score += 30;
                else if (pt == Object.class) score += 10;
                else return -1; // Incompatible
            }
        }
        return score;
    }

    private static Method findBestMethod(Class<?> cls, String name, List<Value> args, boolean isStatic) {
        Method best = null;
        int bestScore = -1;
        for (Method m : cls.getMethods()) {
            if (!m.getName().equals(name)) continue;
            if (Modifier.isStatic(m.getModifiers()) != isStatic) continue;
            if (m.getParameterCount() != args.size()) continue;

            int score = scoreMethod(m.getParameterTypes(), args);
            if (score > bestScore) {
                bestScore = score;
                best = m;
            }
        }
        return best;
    }

    // =========================================================================
    // 4. VIRTUAL-THREAD-POWERED SUBPROCESS EXECUTION (NO FORK!)
    // =========================================================================

    public enum PipeType { STDIN, STDOUT, STDERR }

    public record PipeChannel(ProcessPipe pipe, PipeType type) {}

    public static final class ProcessPipe {
        final long pid;
        final Process process;
        final OutputStream stdin;
        final InputStream stdout;
        final InputStream stderr;
        final BlockingQueue<Byte> stdoutQueue = new LinkedBlockingQueue<>();
        final BlockingQueue<Byte> stderrQueue = new LinkedBlockingQueue<>();
        final AtomicBoolean stdoutEof = new AtomicBoolean(false);
        final AtomicBoolean stderrEof = new AtomicBoolean(false);

        public ProcessPipe(Process process) {
            this.process = process;
            this.pid = process.pid();
            this.stdin = process.getOutputStream();
            this.stdout = process.getInputStream();
            this.stderr = process.getErrorStream();

            // Background Virtual Thread pumping STDOUT
            Thread.ofVirtual().name("pipe-stdout-" + pid).start(() -> {
                try {
                    byte[] buf = new byte[4096];
                    int n;
                    while ((n = stdout.read(buf)) != -1) {
                        for (int i = 0; i < n; i++) {
                            stdoutQueue.put(buf[i]);
                        }
                    }
                } catch (Exception ignored) {
                } finally {
                    stdoutEof.set(true);
                }
            });

            // Background Virtual Thread pumping STDERR
            Thread.ofVirtual().name("pipe-stderr-" + pid).start(() -> {
                try {
                    byte[] buf = new byte[4096];
                    int n;
                    while ((n = stderr.read(buf)) != -1) {
                        for (int i = 0; i < n; i++) {
                            stderrQueue.put(buf[i]);
                        }
                    }
                } catch (Exception ignored) {
                } finally {
                    stderrEof.set(true);
                }
            });
        }
    }

    public static Value pipeExec(String cmd) {
        try {
            boolean isWin = System.getProperty("os.name", "").toLowerCase().contains("win");
            ProcessBuilder pb = isWin
                ? new ProcessBuilder("cmd.exe", "/c", cmd)
                : new ProcessBuilder("/bin/sh", "-c", cmd);
            Process proc = pb.start();
            ProcessPipe pp = new ProcessPipe(proc);
            long inFd = NEXT_PIPE_ID.getAndIncrement();
            long outFd = NEXT_PIPE_ID.getAndIncrement();
            long errFd = NEXT_PIPE_ID.getAndIncrement();
            OPEN_PIPE_CHANNELS.put(inFd, new PipeChannel(pp, PipeType.STDIN));
            OPEN_PIPE_CHANNELS.put(outFd, new PipeChannel(pp, PipeType.STDOUT));
            OPEN_PIPE_CHANNELS.put(errFd, new PipeChannel(pp, PipeType.STDERR));
            MANAGED_PROCESSES.put(pp.pid, pp);

            Sequence s = new Sequence(4);
            s.setElement(0, Value.fromInt(inFd));
            s.setElement(1, Value.fromInt(outFd));
            s.setElement(2, Value.fromInt(errFd));
            s.setElement(3, Value.fromInt(pp.pid));
            return Value.fromSeq(s);
        } catch (IOException e) {
            return Value.fromInt(-1);
        }
    }

    public static Value pipeRead(long fd, int count) {
        PipeChannel chan = OPEN_PIPE_CHANNELS.get(fd);
        if (chan == null || count <= 0) return Value.emptySeq();
        BlockingQueue<Byte> q = (chan.type == PipeType.STDERR) ? chan.pipe.stderrQueue : chan.pipe.stdoutQueue;
        AtomicBoolean eof = (chan.type == PipeType.STDERR) ? chan.pipe.stderrEof : chan.pipe.stdoutEof;

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        try {
            while (baos.size() == 0 && !eof.get() && chan.pipe.process.isAlive()) {
                Byte first = q.poll(2000, TimeUnit.MILLISECONDS);
                if (first != null) {
                    baos.write(first);
                    break;
                }
            }
            while (baos.size() < count) {
                Byte b = q.poll(20, TimeUnit.MILLISECONDS);
                if (b == null) break;
                baos.write(b);
            }
        } catch (InterruptedException ignored) {}

        byte[] bytes = baos.toByteArray();
        if (bytes.length == 0 && eof.get() && q.isEmpty()) {
            return Value.emptySeq();
        }
        return Value.fromRawBytes(bytes);
    }

    public static Value pipeWrite(long fd, Value bytesVal) {
        PipeChannel chan = OPEN_PIPE_CHANNELS.get(fd);
        if (chan == null || chan.type != PipeType.STDIN) return Value.fromInt(-1);
        byte[] b;
        if (bytesVal.isSeq()) {
            Sequence s = bytesVal.asSeq();
            b = new byte[s.size()];
            for (int i = 0; i < s.size(); i++) {
                b[i] = (byte) s.get(i).toIntCoerce();
            }
        } else if (bytesVal.isInt()) {
            b = new byte[]{(byte) bytesVal.asInt()};
        } else {
            return Value.fromInt(0);
        }

        try {
            chan.pipe.stdin.write(b);
            chan.pipe.stdin.flush();
            return Value.fromInt(b.length);
        } catch (IOException e) {
            return Value.fromInt(-1);
        }
    }

    public static Value pipeClose(long fd) {
        PipeChannel chan = OPEN_PIPE_CHANNELS.remove(fd);
        if (chan == null) return Value.fromInt(-1);
        try {
            if (chan.type == PipeType.STDIN) {
                chan.pipe.stdin.close();
            }
            return Value.fromInt(0);
        } catch (IOException e) {
            return Value.fromInt(-1);
        }
    }

    public static void pipeKill(long pid, int signal) {
        ProcessPipe pp = MANAGED_PROCESSES.remove(pid);
        if (pp != null) {
            pp.process.destroyForcibly();
        } else {
            ProcessHandle.of(pid).ifPresent(ProcessHandle::destroyForcibly);
        }
    }
}
