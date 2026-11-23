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

    private static boolean runSource(String src, String filePath, boolean dumpBytecode,
                                     List<String> cliArgs, List<String> includeDirs, List<String> defines) {
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

        if (dumpBytecode) {
            prog.disassemble(System.out);
        }

        VM vm = new VM();
        if (!vm.execute(prog)) {
            System.err.println(vm.error());
            return false;
        }
        return true;
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

                runSource(line, "<repl>", dumpBytecode, List.of("euphorix", "<repl>"), includeDirs, defines);
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
            if (filename == null && (arg.equals("-batch") || arg.equals("--batch"))) {
                continue;
            } else if (filename == null && (arg.equals("-w") || arg.equals("--watch"))) {
                watchMode = true;
                continue;
            } else if (filename == null && (arg.equals("-v") || arg.equals("--version"))) {
                System.out.println("Euphorix 1.0.0 (Java 25 VM / OpenEuphoria 4.x Syntax)");
                System.exit(0);
            } else if (filename == null && (arg.equals("--disasm") || arg.equals("-disasm"))) {
                dumpBytecode = true;
            } else if (filename == null && arg.equals("-e") && i + 1 < args.length) {
                evalCode = args[++i];
            } else if (filename == null && arg.equals("-c") && i + 1 < args.length) {
                loadCfgFile(args[++i], includeDirs, defines);
            } else if (filename == null && arg.startsWith("-c=")) {
                loadCfgFile(arg.substring(3), includeDirs, defines);
            } else if (filename == null && (arg.equals("-i") || arg.equals("-I")) && i + 1 < args.length) {
                includeDirs.add(args[++i]);
            } else if (filename == null && (arg.startsWith("-i=") || arg.startsWith("-I="))) {
                includeDirs.add(arg.substring(3));
            } else if (filename == null && (arg.startsWith("-d=") || arg.startsWith("-D="))) {
                defines.add(arg.substring(3));
            } else if (filename == null && (arg.equals("-d") || arg.equals("-D")) && i + 1 < args.length) {
                defines.add(args[++i]);
            } else if (filename == null && (arg.startsWith("-D") || arg.startsWith("-d")) && arg.length() > 2) {
                defines.add(arg.substring(2));
            } else if (filename == null && (arg.equals("-h") || arg.equals("--help"))) {
                System.out.println("Verwendung: euphorix [-batch] [--watch] [--disasm] [-i dir] [-D TAG] [-e \"code\"] [datei.ex [args...]]");
                System.exit(0);
            } else if (filename == null) {
                filename = arg;
                scriptArgs.add(filename);
            } else {
                scriptArgs.add(arg);
            }
        }

        if (evalCode != null) {
            scriptArgs.add("-e");
            boolean ok = runSource(evalCode, "<eval>", dumpBytecode, scriptArgs, includeDirs, defines);
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

        if (watchMode) {
            runWatchLoop(filename, dumpBytecode, scriptArgs, includeDirs, defines);
            System.exit(0);
        }

        try {
            String source;
            try {
                source = Files.readString(path, StandardCharsets.UTF_8);
            } catch (java.nio.charset.MalformedInputException mie) {
                source = Files.readString(path, StandardCharsets.ISO_8859_1);
            }
            boolean ok = runSource(source, filename, dumpBytecode, scriptArgs, includeDirs, defines);
            System.exit(ok ? 0 : 1);
        } catch (IOException e) {
            System.err.printf("Fehler: Datei '%s' konnte nicht geöffnet werden.%n", filename);
            System.exit(1);
        }
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
                    runSource(source, filename, dumpBytecode, scriptArgs, includeDirs, defines);
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
