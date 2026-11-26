package eu;

import eu.Bytecode.Program;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

/**
 * Minimized CLI Entry Point for the Euphorix Bytecode Runtime ({@code runtime.jar} / {@code euphorix-rt}).
 * <p>
 * This runtime runner contains ONLY the execution engine (VM, Bytecode, Value, Sequence,
 * VarType, DataEngines, JavaInterop) and does NOT contain any compiler, lexer, or Euphoria
 * source code files. It executes precompiled .exb bytecode files directly with near-zero startup overhead.
 */
public final class RuntimeMain {

    private static final String BOUND_PAYLOAD_MARKER = "\n__EUPHORIX_BOUND_PAYLOAD__\n";

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
            System.err.printf("[TIME-BYTECODE-RT] Bytecode-Laden: %.2f ms | VM-Ausführung: %.2f ms | Gesamt: %.2f ms%n",
                    loadMs, execMs, totalMs);
        }

        if (!ok && !vm.error().isEmpty()) {
            System.err.println(vm.error());
        }
        return ok;
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
                System.err.printf("[TIME-BOUND-RT] Payload-Load: %.2f ms | VM-Ausführung: %.2f ms | Gesamt: %.2f ms%n",
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

    public static void main(String[] args) {
        if (System.getProperty("awt.useSystemAAFontSettings") == null) {
            System.setProperty("awt.useSystemAAFontSettings", "lcd");
        }
        if (System.getProperty("swing.aatext") == null) {
            System.setProperty("swing.aatext", "true");
        }

        boolean dumpBytecode = false;
        boolean benchmarkTime = false;
        String runBoundFile = null;
        String filename = null;
        List<String> scriptArgs = new ArrayList<>();

        String selfExe = System.getProperty("eui.bin");
        if (selfExe == null || selfExe.isBlank()) {
            try {
                var cs = RuntimeMain.class.getProtectionDomain().getCodeSource();
                if (cs != null && cs.getLocation() != null) {
                    Path jarDir = Path.of(cs.getLocation().toURI()).getParent();
                    if (jarDir != null) {
                        if (Files.exists(jarDir.resolve("euphorix-rt"))) {
                            selfExe = jarDir.resolve("euphorix-rt").toAbsolutePath().toString();
                        } else if (Files.exists(jarDir.resolve("runtime"))) {
                            selfExe = jarDir.resolve("runtime").toAbsolutePath().toString();
                        } else if (Files.exists(jarDir.resolve("euphorix"))) {
                            selfExe = jarDir.resolve("euphorix").toAbsolutePath().toString();
                        }
                    }
                }
            } catch (Exception ignored) {}
            if (selfExe == null || selfExe.isBlank()) {
                if (Files.exists(Path.of("euphorix-rt"))) {
                    selfExe = "./euphorix-rt";
                } else if (Files.exists(Path.of("runtime"))) {
                    selfExe = "./runtime";
                } else {
                    selfExe = "runtime";
                }
            }
        }
        scriptArgs.add(selfExe);

        for (int i = 0; i < args.length; i++) {
            String arg = args[i];
            if (arg.equals("-batch") || arg.equals("--batch")) {
                continue;
            } else if (arg.equals("-t") || arg.equals("--time")) {
                benchmarkTime = true;
                continue;
            } else if (arg.equals("--run-bound") && i + 1 < args.length) {
                runBoundFile = args[++i];
                continue;
            } else if (arg.equals("-v") || arg.equals("--version")) {
                System.out.println("Euphorix Runtime 1.0.0 (Java 25 VM / Bytecode Runner)");
                System.exit(0);
            } else if (arg.equals("--disasm") || arg.equals("-disasm")) {
                dumpBytecode = true;
            } else if (arg.equals("-h") || arg.equals("--help")) {
                System.out.println("Verwendung: runtime [-t|--time] [--disasm] datei.exb [args...]");
                System.out.println("            runtime --run-bound binärdatei [args...]");
                System.out.println();
                System.out.println("Reine Euphorix Bytecode-Laufzeitumgebung (ohne Compiler/Lexer).");
                System.out.println("Optionen:");
                System.out.println("  -t, --time          Misst Bytecode-Lade- und VM-Ausführungszeit");
                System.out.println("  --disasm            Gibt Bytecode-Instruktionen disassembliert aus");
                System.out.println("  --run-bound <bin>   Führt ein gebundenes Binär-Executable aus");
                System.out.println("  -v, --version       Zeigt die Version der Runtime an");
                System.out.println("  -h, --help          Zeigt diese Hilfe an");
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

        if (filename == null) {
            System.err.println("Fehler: Keine Bytecode-Datei (.exb) angegeben.");
            System.err.println("Verwendung: java -jar runtime.jar [-t] datei.exb [args...]");
            System.err.println("            oder: ./euphorix-rt [-t] datei.exb [args...]");
            System.exit(1);
        }

        Path path = Path.of(filename);
        if (!Files.isRegularFile(path)) {
            System.err.printf("Fehler: Datei '%s' konnte nicht geöffnet werden.%n", filename);
            System.exit(1);
        }

        if (!Program.isBytecodeFile(path) && !filename.toLowerCase().endsWith(".exb")) {
            System.err.printf("Fehler: Datei '%s' ist kein gültiger Euphorix-Bytecode (.exb).%n", filename);
            if (filename.toLowerCase().endsWith(".ex") || filename.toLowerCase().endsWith(".e")) {
                System.err.println();
                System.err.println("Hinweis: Dies ist die reine Runtime (runtime.jar / euphorix-rt) ohne Compiler.");
                System.err.println("Bitte kompilieren Sie die Datei zuerst mit dem Euphorix-Compiler:");
                System.err.printf("    euphorix --compile %s -o %s.exb%n", filename, filename.replaceAll("\\.[^.]+$", ""));
                System.err.println("und führen Sie sie anschließend mit der Runtime aus:");
                System.err.printf("    java -jar runtime.jar %s.exb%n", filename.replaceAll("\\.[^.]+$", ""));
            }
            System.exit(1);
        }

        boolean ok = runBytecode(path, dumpBytecode, benchmarkTime, scriptArgs);
        System.exit(ok ? 0 : 1);
    }
}
