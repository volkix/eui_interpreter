package eu;

import eu.Bytecode.Program;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

/**
 * CLI Entry Point & REPL for the Euphorix Virtual Machine (OpenEuphoria syntax) ({@code euphorix}).
 */
public final class Main {

    private static boolean runSource(String src, String filePath, boolean dumpBytecode, boolean benchmarkTime,
                                     List<String> cliArgs, List<String> includeDirs, List<String> defines) {
        long t0 = System.nanoTime();
        Compiler compiler = new Compiler(src, filePath);
        for (String dir : includeDirs) {
            compiler.addIncludeDir(dir);
        }
        for (String def : defines) {
            compiler.defineSymbol(def);
        }

        Program prog = new Program();
        prog.cliArgs.addAll(cliArgs);
        if (!compiler.compile(prog)) {
            System.err.println(compiler.errorMessage());
            return false;
        }
        long t1 = System.nanoTime();

        if (dumpBytecode) {
            prog.disassemble(System.out);
        }

        VM vm = new VM();
        boolean ok = vm.execute(prog);
        long t2 = System.nanoTime();

        if (benchmarkTime) {
            double compileMs = (t1 - t0) / 1_000_000.0;
            double execMs = (t2 - t1) / 1_000_000.0;
            double totalMs = (t2 - t0) / 1_000_000.0;
            System.err.printf("[TIME-INTERPRETER] Lexer & Compiler: %.2f ms | VM-Ausführung: %.2f ms | Gesamt: %.2f ms%n",
                    compileMs, execMs, totalMs);
        }

        if (!ok && !vm.error().isEmpty()) {
            System.err.println(vm.error());
        }
        return ok;
    }

    private static boolean runBytecode(Path path, boolean dumpBytecode, boolean benchmarkTime, List<String> cliArgs) {
        long t0 = System.nanoTime();
        Program prog;
        try {
            prog = Program.load(path);
        } catch (IOException e) {
            System.err.println("Fehler beim Laden der Bytecode-Datei: " + e.getMessage());
            return false;
        }
        long t1 = System.nanoTime();
        prog.cliArgs.addAll(cliArgs);

        if (dumpBytecode) {
            prog.disassemble(System.out);
        }

        VM vm = new VM();
        boolean ok = vm.execute(prog);
        long t2 = System.nanoTime();

        if (benchmarkTime) {
            double loadMs = (t1 - t0) / 1_000_000.0;
            double execMs = (t2 - t1) / 1_000_000.0;
            double totalMs = (t2 - t0) / 1_000_000.0;
            System.err.printf("[TIME-BYTECODE] Bytecode-Laden: %.2f ms | VM-Ausführung: %.2f ms | Gesamt: %.2f ms%n",
                    loadMs, execMs, totalMs);
        }

        if (!ok && !vm.error().isEmpty()) {
            System.err.println(vm.error());
        }
        return ok;
    }

    private static boolean compileToBytecode(String src, String srcPath, String outPath,
                                             List<String> includeDirs, List<String> defines, boolean dumpBytecode) {
        Compiler compiler = new Compiler(src, srcPath);
        for (String dir : includeDirs) {
            compiler.addIncludeDir(dir);
        }
        for (String def : defines) {
            compiler.defineSymbol(def);
        }

        Program prog = new Program();
        if (!compiler.compile(prog)) {
            System.err.println(compiler.errorMessage());
            return false;
        }

        if (dumpBytecode) {
            prog.disassemble(System.out);
        }

        Path out = Path.of(outPath);
        try {
            prog.save(out);
            long sz = Files.size(out);
            System.out.printf("[BYTECODE] Kompiliert: %s -> %s (%d Bytes, %d Konstanten, %d Routinen)%n",
                    srcPath, outPath, sz, prog.constants.size(), prog.routines.size());
            return true;
        } catch (IOException e) {
            System.err.println("Fehler beim Speichern der Bytecode-Datei: " + e.getMessage());
            return false;
        }
    }

    private static final String BOUND_PAYLOAD_MARKER = "\n__EUPHORIX_BOUND_PAYLOAD__\n";

    private static boolean bindToExecutable(String src, String srcPath, String outPath,
                                            List<String> includeDirs, List<String> defines) {
        Compiler compiler = new Compiler(src, srcPath);
        for (String dir : includeDirs) {
            compiler.addIncludeDir(dir);
        }
        for (String def : defines) {
            compiler.defineSymbol(def);
        }

        Program prog = new Program();
        if (!compiler.compile(prog)) {
            System.err.println(compiler.errorMessage());
            return false;
        }

        Path out = Path.of(outPath);
        try (java.io.ByteArrayOutputStream baos = new java.io.ByteArrayOutputStream()) {
            prog.save(baos);
            byte[] bytecode = baos.toByteArray();

            String stub = """
                #!/bin/sh
                # Euphorix Bound Executable Stub (Self-Executing Bytecode)
                SELF="$0"
                if command -v euphorix-rt >/dev/null 2>&1; then
                    exec euphorix-rt --run-bound "$SELF" "$@"
                elif command -v runtime >/dev/null 2>&1; then
                    exec runtime --run-bound "$SELF" "$@"
                elif command -v euphorix >/dev/null 2>&1; then
                    exec euphorix --run-bound "$SELF" "$@"
                fi
                DIR="$(cd "$(dirname "$0")" && pwd)"
                if [ -x "$DIR/euphorix-rt" ]; then
                    exec "$DIR/euphorix-rt" --run-bound "$SELF" "$@"
                elif [ -f "$DIR/runtime.jar" ]; then
                    exec java -jar "$DIR/runtime.jar" --run-bound "$SELF" "$@"
                elif [ -f "$DIR/euphorix-rt.jar" ]; then
                    exec java -jar "$DIR/euphorix-rt.jar" --run-bound "$SELF" "$@"
                elif [ -x "$DIR/euphorix" ]; then
                    exec "$DIR/euphorix" --run-bound "$SELF" "$@"
                elif [ -f "$DIR/euphorix.jar" ]; then
                    exec java -jar "$DIR/euphorix.jar" --run-bound "$SELF" "$@"
                elif [ -f "$HOME/.cache/euphorix/java25-runtime/runtime.jar" ]; then
                    exec java -jar "$HOME/.cache/euphorix/java25-runtime/runtime.jar" --run-bound "$SELF" "$@"
                elif [ -f "$HOME/.cache/euphorix/java25-runtime/euphorix.jar" ]; then
                    exec java -jar "$HOME/.cache/euphorix/java25-runtime/euphorix.jar" --run-bound "$SELF" "$@"
                elif [ -x "/home/volkix/prj/intpret/euphorix-rt" ]; then
                    exec "/home/volkix/prj/intpret/euphorix-rt" --run-bound "$SELF" "$@"
                elif [ -x "/home/volkix/prj/intpret/euphorix" ]; then
                    exec "/home/volkix/prj/intpret/euphorix" --run-bound "$SELF" "$@"
                fi
                echo "Fehler: Euphorix-Laufzeitumgebung ('euphorix-rt', 'runtime.jar' oder 'euphorix') nicht im Pfad gefunden!" >&2
                exit 127
                __EUPHORIX_BOUND_PAYLOAD__
                """;

            try (java.io.FileOutputStream fos = new java.io.FileOutputStream(out.toFile())) {
                fos.write(stub.getBytes(StandardCharsets.UTF_8));
                fos.write(bytecode);
            }
            out.toFile().setExecutable(true, false);
            long sz = Files.size(out);
            System.out.printf("[BIND] Ausführbare Binärdatei erstellt: %s (%d Bytes)%n", outPath, sz);
            return true;
        } catch (IOException e) {
            System.err.println("Fehler beim Erstellen der gebundenen Binärdatei: " + e.getMessage());
            return false;
        }
    }

    private static boolean runBoundExecutable(String boundFile, boolean dumpBytecode, boolean benchmarkTime, List<String> cliArgs) {
        Path p = Path.of(boundFile);
        if (!Files.isRegularFile(p)) {
            System.err.println("Fehler: Gebundene Datei nicht gefunden: " + boundFile);
            return false;
        }
        long t0 = System.nanoTime();
        byte[] markerBytes = BOUND_PAYLOAD_MARKER.getBytes(StandardCharsets.UTF_8);
        try {
            byte[] all = Files.readAllBytes(p);
            int offset = -1;
            for (int i = 0; i <= all.length - markerBytes.length; i++) {
                boolean match = true;
                for (int j = 0; j < markerBytes.length; j++) {
                    if (all[i + j] != markerBytes[j]) {
                        match = false;
                        break;
                    }
                }
                if (match) {
                    offset = i + markerBytes.length;
                    break;
                }
            }
            if (offset < 0) {
                System.err.println("Fehler: Kein Euphorix-Bytecode-Payload in '" + boundFile + "' gefunden.");
                return false;
            }

            java.io.ByteArrayInputStream bais = new java.io.ByteArrayInputStream(all, offset, all.length - offset);
            Program prog = Program.load(bais);
            long t1 = System.nanoTime();
            prog.cliArgs.addAll(cliArgs);

            if (dumpBytecode) {
                prog.disassemble(System.out);
            }

            VM vm = new VM();
            boolean ok = vm.execute(prog);
            long t2 = System.nanoTime();

            if (benchmarkTime) {
                double loadMs = (t1 - t0) / 1_000_000.0;
                double execMs = (t2 - t1) / 1_000_000.0;
                double totalMs = (t2 - t0) / 1_000_000.0;
                System.err.printf("[TIME-BOUND] Payload-Load: %.2f ms | VM-Ausführung: %.2f ms | Gesamt: %.2f ms%n",
                        loadMs, execMs, totalMs);
            }

            if (!ok && !vm.error().isEmpty()) {
                System.err.println(vm.error());
            }
            return ok;
        } catch (IOException e) {
            System.err.println("Fehler beim Ausführen der gebundenen Datei: " + e.getMessage());
            return false;
        }
    }

    private static void runRepl(boolean dumpBytecode, List<String> includeDirs, List<String> defines) {
        System.out.println("Euphorix 1.0.0 (Java 25 VM für OpenEuphoria-Syntax)");
        System.out.println("Tippe Euphoria-Anweisungen ein (oder 'exit' zum Beenden):");

        try (BufferedReader reader = new BufferedReader(new InputStreamReader(System.in, StandardCharsets.UTF_8))) {
            for (;;) {
                System.out.print("euphorix> ");
                System.out.flush();
                String line = reader.readLine();
                if (line == null) {
                    System.out.println();
                    break;
                }
                if (line.equals("exit") || line.equals("quit")) {
                    break;
                }
                if (line.isBlank()) continue;

                runSource(line, "<repl>", dumpBytecode, false, List.of("euphorix", "<repl>"), includeDirs, defines);
            }
        } catch (IOException ignored) {}
    }

    public static void main(String[] args) {
        if (System.getProperty("awt.useSystemAAFontSettings") == null) {
            System.setProperty("awt.useSystemAAFontSettings", "lcd");
        }
        if (System.getProperty("swing.aatext") == null) {
            System.setProperty("swing.aatext", "true");
        }

        boolean dumpBytecode = false;
        boolean watchMode = false;
        boolean compileMode = false;
        boolean bindMode = false;
        boolean benchmarkTime = false;
        String runBoundFile = null;
        String outFile = null;
        String filename = null;
        String evalCode = null;
        List<String> includeDirs = new ArrayList<>();
        List<String> defines = new ArrayList<>();
        List<String> scriptArgs = new ArrayList<>();

        String selfExe = System.getProperty("eui.bin");
        if (selfExe == null || selfExe.isBlank()) {
            try {
                var cs = Main.class.getProtectionDomain().getCodeSource();
                if (cs != null && cs.getLocation() != null) {
                    Path jarDir = Path.of(cs.getLocation().toURI()).getParent();
                    if (jarDir != null) {
                        if (Files.exists(jarDir.resolve("euphorix"))) {
                            selfExe = jarDir.resolve("euphorix").toAbsolutePath().toString();
                        } else if (Files.exists(jarDir.resolve("eui-java"))) {
                            selfExe = jarDir.resolve("eui-java").toAbsolutePath().toString();
                        }
                    }
                }
            } catch (Exception ignored) {}
            if (selfExe == null || selfExe.isBlank()) {
                if (Files.exists(Path.of("euphorix"))) {
                    selfExe = "./euphorix";
                } else if (Files.exists(Path.of("eui-java"))) {
                    selfExe = "./eui-java";
                } else {
                    selfExe = "euphorix";
                }
            }
        }
        scriptArgs.add(selfExe);

        String euinc = System.getenv("EUPHORIX_INC");
        if (euinc == null || euinc.isBlank()) {
            euinc = System.getenv("EUINC");
        }
        if (euinc != null && !euinc.isBlank()) {
            for (String p : euinc.split(java.util.regex.Pattern.quote(java.io.File.pathSeparator))) {
                if (!p.isBlank()) includeDirs.add(p.trim());
            }
        }

        for (int i = 0; i < args.length; i++) {
            String arg = args[i];
            if (arg.equals("-batch") || arg.equals("--batch")) {
                continue;
            } else if (arg.equals("-w") || arg.equals("--watch")) {
                watchMode = true;
                continue;
            } else if (arg.equals("-t") || arg.equals("--time")) {
                benchmarkTime = true;
                continue;
            } else if (arg.equals("-b") || arg.equals("--compile")) {
                compileMode = true;
                continue;
            } else if (arg.equals("--bind")) {
                bindMode = true;
                continue;
            } else if (arg.equals("--run-bound") && i + 1 < args.length) {
                runBoundFile = args[++i];
                continue;
            } else if (arg.equals("-o") && i + 1 < args.length) {
                outFile = args[++i];
                continue;
            } else if (arg.startsWith("-o=")) {
                outFile = arg.substring(3);
                continue;
            } else if (arg.equals("-v") || arg.equals("--version")) {
                System.out.println("Euphorix 1.0.0 (Java 25 VM / OpenEuphoria 4.x Syntax)");
                System.exit(0);
            } else if (arg.equals("--lsp") || arg.equals("-lsp")) {
                LspServer.runStdio();
                System.exit(0);
            } else if (arg.equals("--disasm") || arg.equals("-disasm")) {
                dumpBytecode = true;
            } else if (arg.equals("-e") && i + 1 < args.length) {
                evalCode = args[++i];
            } else if (arg.equals("-c") && i + 1 < args.length) {
                loadCfgFile(args[++i], includeDirs, defines);
            } else if (arg.startsWith("-c=")) {
                loadCfgFile(arg.substring(3), includeDirs, defines);
            } else if ((arg.equals("-i") || arg.equals("-I")) && i + 1 < args.length) {
                includeDirs.add(args[++i]);
            } else if (arg.startsWith("-i=") || arg.startsWith("-I=")) {
                includeDirs.add(arg.substring(3));
            } else if (arg.startsWith("-d=") || arg.startsWith("-D=")) {
                defines.add(arg.substring(3));
            } else if ((arg.equals("-d") || arg.equals("-D")) && i + 1 < args.length) {
                defines.add(args[++i]);
            } else if ((arg.startsWith("-D") || arg.startsWith("-d")) && arg.length() > 2) {
                defines.add(arg.substring(2));
            } else if (arg.equals("-h") || arg.equals("--help")) {
                System.out.println("Verwendung: euphorix [-batch] [--watch] [--disasm] [--time] [-b|--compile] [--bind] [-o out] [-i dir] [-D TAG] [-e \"code\"] [datei.ex|.exb [args...]]");
                System.out.println("Optionen:");
                System.out.println("  -b, --compile       Kompiliert Euphoria-Quellcode (.ex) in Standalone-Bytecode (.exb)");
                System.out.println("  --bind              Bündet Quellcode & Bytecode in ein selbst-ausführendes Executable");
                System.out.println("  -o <datei>          Ausgabedateiname für --compile oder --bind");
                System.out.println("  -t, --time          Misst Parse/Compile- vs. VM-Ausführungszeit (Benchmark)");
                System.out.println("  --disasm            Gibt Bytecode-Instruktionen disassembliert im Klartext aus");
                System.out.println("  --lsp               Startet den Language Server Protocol (LSP) Dienst (für NetBeans/VSCode)");
                System.out.println("  -w, --watch         Auto-Reload bei Änderungen der Quelldateien");
                System.out.println("  -i <dir>            Fügt ein Verzeichnis zu den Include-Pfaden hinzu");
                System.out.println("  -D <TAG>            Definiert ein Präprozessor-Symbol");
                System.out.println("  -e \"code\"           Führt einen Euphoria-Code-Schnipsel direkt aus");
                System.exit(0);
            } else if (filename == null) {
                filename = arg;
                scriptArgs.add(filename);
            } else {
                scriptArgs.add(arg);
            }
        }

        if (runBoundFile != null) {
            boolean ok = runBoundExecutable(runBoundFile, dumpBytecode, benchmarkTime, scriptArgs);
            System.exit(ok ? 0 : 1);
        }

        if (evalCode != null) {
            scriptArgs.add("-e");
            boolean ok = runSource(evalCode, "<eval>", dumpBytecode, benchmarkTime, scriptArgs, includeDirs, defines);
            System.exit(ok ? 0 : 1);
        }

        if (filename == null) {
            runRepl(dumpBytecode, includeDirs, defines);
            System.exit(0);
        }

        Path path = Path.of(filename);
        if (!Files.isRegularFile(path)) {
            System.err.printf("Fehler: Datei '%s' konnte nicht geöffnet werden.%n", filename);
            System.exit(1);
        }

        // 1. Direct bytecode execution (.exb or MAGIC file)
        if (!compileMode && !bindMode && (filename.toLowerCase().endsWith(".exb") || Program.isBytecodeFile(path))) {
            boolean ok = runBytecode(path, dumpBytecode, benchmarkTime, scriptArgs);
            System.exit(ok ? 0 : 1);
        }

        String source;
        try {
            try {
                source = Files.readString(path, StandardCharsets.UTF_8);
            } catch (java.nio.charset.MalformedInputException mie) {
                source = Files.readString(path, StandardCharsets.ISO_8859_1);
            }
        } catch (IOException e) {
            System.err.printf("Fehler: Datei '%s' konnte nicht geöffnet werden.%n", filename);
            System.exit(1);
            return;
        }

        // 2. Compile-only mode (Save to .exb)
        if (compileMode) {
            String targetOut = outFile;
            if (targetOut == null || targetOut.isBlank()) {
                int dotIdx = filename.lastIndexOf('.');
                targetOut = (dotIdx > 0 ? filename.substring(0, dotIdx) : filename) + ".exb";
            }
            boolean ok = compileToBytecode(source, filename, targetOut, includeDirs, defines, dumpBytecode);
            System.exit(ok ? 0 : 1);
        }

        // 3. Bind mode (Create executable binary with attached payload)
        if (bindMode) {
            String targetOut = outFile;
            if (targetOut == null || targetOut.isBlank()) {
                int dotIdx = filename.lastIndexOf('.');
                targetOut = (dotIdx > 0 ? filename.substring(0, dotIdx) : filename);
            }
            boolean ok = bindToExecutable(source, filename, targetOut, includeDirs, defines);
            System.exit(ok ? 0 : 1);
        }

        // 4. Normal run
        if (watchMode) {
            runWatchLoop(filename, dumpBytecode, scriptArgs, includeDirs, defines);
            System.exit(0);
        }

        boolean ok = runSource(source, filename, dumpBytecode, benchmarkTime, scriptArgs, includeDirs, defines);
        System.exit(ok ? 0 : 1);
    }

    private static void runWatchLoop(String filename, boolean dumpBytecode,
                                     List<String> scriptArgs, List<String> includeDirs, List<String> defines) {
        Path scriptPath = Path.of(filename).toAbsolutePath();
        Path watchDir = scriptPath.getParent();
        if (watchDir == null) watchDir = Path.of(".");

        System.out.println("[WATCH] Beobachte '" + filename + "' und Verzeichnis '" + watchDir + "' auf Änderungen...");
        System.out.println("[WATCH] Drücke Strg+C zum Beenden.");

        final Path finalWatchDir = watchDir;
        java.util.concurrent.atomic.AtomicReference<Thread> currentWorker = new java.util.concurrent.atomic.AtomicReference<>();
        java.util.concurrent.atomic.AtomicBoolean running = new java.util.concurrent.atomic.AtomicBoolean(true);

        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            running.set(false);
            Thread t = currentWorker.get();
            if (t != null) t.interrupt();
        }));

        java.util.function.Consumer<String> starter = (reason) -> {
            Thread old = currentWorker.getAndSet(null);
            if (old != null) {
                old.interrupt();
                try { old.join(1000); } catch (InterruptedException ignored) {}
            }
            if (reason != null) {
                System.out.println("\n[WATCH] " + reason + " -> Starte Anwendung neu...");
            }
            Thread worker = Thread.ofVirtual().name("watch-worker").start(() -> {
                try {
                    String source;
                    try {
                        source = Files.readString(scriptPath, StandardCharsets.UTF_8);
                    } catch (java.nio.charset.MalformedInputException mie) {
                        source = Files.readString(scriptPath, StandardCharsets.ISO_8859_1);
                    }
                    runSource(source, filename, dumpBytecode, false, scriptArgs, includeDirs, defines);
                } catch (Exception e) {
                    System.err.println("[WATCH] Ausführungsfehler: " + e.getMessage());
                }
            });
            currentWorker.set(worker);
        };

        starter.accept(null);

        java.util.Map<Path, Long> lastModified = getDirectorySnapshots(finalWatchDir);

        while (running.get()) {
            try {
                Thread.sleep(600);
            } catch (InterruptedException e) {
                break;
            }

            java.util.Map<Path, Long> current = getDirectorySnapshots(finalWatchDir);
            String changedFile = null;

            for (var entry : current.entrySet()) {
                Long oldTs = lastModified.get(entry.getKey());
                if (oldTs == null || !oldTs.equals(entry.getValue())) {
                    changedFile = entry.getKey().getFileName().toString();
                    break;
                }
            }
            if (changedFile == null) {
                for (var oldKey : lastModified.keySet()) {
                    if (!current.containsKey(oldKey)) {
                        changedFile = oldKey.getFileName().toString() + " (gelöscht)";
                        break;
                    }
                }
            }

            if (changedFile != null) {
                lastModified = current;
                starter.accept("Änderung erkannt in '" + changedFile + "'");
            }
        }
    }

    private static java.util.Map<Path, Long> getDirectorySnapshots(Path dir) {
        java.util.Map<Path, Long> map = new java.util.HashMap<>();
        try {
            Files.walkFileTree(dir, java.util.Set.of(), 3, new java.nio.file.SimpleFileVisitor<Path>() {
                @Override
                public java.nio.file.FileVisitResult visitFile(Path file, java.nio.file.attribute.BasicFileAttributes attrs) {
                    String name = file.getFileName().toString().toLowerCase();
                    if (name.endsWith(".ex") || name.endsWith(".e") || name.endsWith(".html") || name.endsWith(".css") || name.endsWith(".js")) {
                        map.put(file, attrs.lastModifiedTime().toMillis());
                    }
                    return java.nio.file.FileVisitResult.CONTINUE;
                }

                @Override
                public java.nio.file.FileVisitResult visitFileFailed(Path file, IOException exc) {
                    return java.nio.file.FileVisitResult.SKIP_SUBTREE;
                }
            });
        } catch (Exception ignored) {}
        return map;
    }

    private static void loadCfgFile(String pathStr, List<String> includeDirs, List<String> defines) {
        Path p = Path.of(pathStr);
        if (!Files.exists(p)) return;
        try {
            for (String line : Files.readAllLines(p)) {
                line = line.trim();
                if (line.isEmpty() || line.startsWith("--")) continue;
                String[] tokens = line.split("\\s+");
                for (int i = 0; i < tokens.length; i++) {
                    String t = tokens[i];
                    if ((t.equals("-d") || t.equals("-D")) && i + 1 < tokens.length) {
                        defines.add(tokens[++i]);
                    } else if (t.startsWith("-d=") || t.startsWith("-D=")) {
                        defines.add(t.substring(3));
                    } else if ((t.startsWith("-D") || t.startsWith("-d")) && t.length() > 2) {
                        defines.add(t.substring(2));
                    } else if ((t.equals("-i") || t.equals("-I")) && i + 1 < tokens.length) {
                        includeDirs.add(tokens[++i]);
                    } else if (t.startsWith("-i=") || t.startsWith("-I=")) {
                        includeDirs.add(t.substring(3));
                    }
                }
            }
        } catch (IOException ignored) {}
    }
}
