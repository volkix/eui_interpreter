import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.time.Duration;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.*;
import java.util.regex.*;

/**
 * High-Performance OpenEuphoria Test Runner in Java 25.
 * Replaces the legacy Python test runner (tools/run_all_tests.py).
 *
 * Usage:
 *   java tools/RunAllTests.java [interpreter_bin] [filter_or_files...]
 * Examples:
 *   java tools/RunAllTests.java ./eui-java
 *   java tools/RunAllTests.java ./eui-standalone tests/t_gui.e
 *   java tools/RunAllTests.java ./eui-java concurrency
 */
public class RunAllTests {

    private static final int DEFAULT_TIMEOUT_SECS = 25;
    private static final int JAVA_TIMEOUT_SECS = 50;

    private static final Pattern REPORT_PATTERN = Pattern.compile(
        "(\\d+)\\s+tests?\\s+run,\\s+(\\d+)\\s+passed,\\s+(\\d+)\\s+failed",
        Pattern.CASE_INSENSITIVE
    );

    record UnitTestStats(int total, int passed, int failed) {}

    record TestResult(
        String file,
        String filename,
        String directory,
        int returncode,
        String stdout,
        String stderr,
        double duration,
        boolean timeout,
        boolean crash,
        UnitTestStats stats
    ) {
        String toJson() {
            StringBuilder sb = new StringBuilder();
            sb.append("  {\n");
            sb.append("    \"file\": ").append(jsonEscape(file)).append(",\n");
            sb.append("    \"filename\": ").append(jsonEscape(filename)).append(",\n");
            sb.append("    \"directory\": ").append(jsonEscape(directory)).append(",\n");
            sb.append("    \"returncode\": ").append(returncode).append(",\n");
            sb.append("    \"stdout\": ").append(jsonEscape(stdout)).append(",\n");
            sb.append("    \"stderr\": ").append(jsonEscape(stderr)).append(",\n");
            sb.append("    \"duration\": ").append(String.format(Locale.US, "%.3f", duration)).append(",\n");
            sb.append("    \"timeout\": ").append(timeout).append(",\n");
            sb.append("    \"crash\": ").append(crash).append(",\n");
            sb.append("    \"unittest_stats\": ");
            if (stats != null) {
                sb.append(String.format(Locale.US, "{\"total\": %d, \"passed\": %d, \"failed\": %d}\n",
                    stats.total, stats.passed, stats.failed));
            } else {
                sb.append("null\n");
            }
            sb.append("  }");
            return sb.toString();
        }

        private static String jsonEscape(String s) {
            if (s == null) return "null";
            StringBuilder out = new StringBuilder("\"");
            for (int i = 0; i < s.length(); i++) {
                char c = s.charAt(i);
                switch (c) {
                    case '"' -> out.append("\\\"");
                    case '\\' -> out.append("\\\\");
                    case '\b' -> out.append("\\b");
                    case '\f' -> out.append("\\f");
                    case '\n' -> out.append("\\n");
                    case '\r' -> out.append("\\r");
                    case '\t' -> out.append("\\t");
                    default -> {
                        if (c < 32 || c > 126) {
                            out.append(String.format("\\u%04x", (int) c));
                        } else {
                            out.append(c);
                        }
                    }
                }
            }
            out.append("\"");
            return out.toString();
        }
    }

    record TestCase(Path path, Path cwd) {}

    public static void main(String[] args) {
        Path rootDir = Path.of("").toAbsolutePath();
        if (Files.exists(rootDir.resolve("..").resolve("eu_include")) && !Files.exists(rootDir.resolve("eu_include"))) {
            rootDir = rootDir.resolve("..").normalize().toAbsolutePath();
        }

        Path interpreterBin = rootDir.resolve("eui-java");
        List<String> explicitFiles = new ArrayList<>();
        String filterPattern = null;

        if (args.length > 0 && !args[0].isBlank()) {
            interpreterBin = Path.of(args[0]);
            if (!interpreterBin.isAbsolute()) {
                interpreterBin = rootDir.resolve(interpreterBin).normalize();
            }
        }

        for (int i = 1; i < args.length; i++) {
            String arg = args[i].trim();
            if (arg.endsWith(".e") || arg.endsWith(".ex")) {
                explicitFiles.add(arg);
            } else if (filterPattern == null) {
                filterPattern = arg;
            }
        }

        if (!Files.exists(interpreterBin)) {
            System.err.printf("Fehler: Interpreter '%s' existiert nicht!%n", interpreterBin);
            System.exit(1);
        }

        boolean isJava = interpreterBin.getFileName().toString().toLowerCase().contains("java")
                      || interpreterBin.getFileName().toString().toLowerCase().contains("standalone");
        int timeoutSecs = isJava ? JAVA_TIMEOUT_SECS : DEFAULT_TIMEOUT_SECS;

        List<TestCase> testCases = new ArrayList<>();
        if (!explicitFiles.isEmpty()) {
            for (String fName : explicitFiles) {
                Path p = Path.of(fName);
                if (!p.isAbsolute()) p = rootDir.resolve(p).normalize();
                if (Files.exists(p)) {
                    testCases.add(new TestCase(p, p.getParent()));
                } else {
                    System.err.printf("Warnung: Testdatei '%s' wurde nicht gefunden.%n", fName);
                }
            }
        } else {
            Path[] searchDirs = new Path[] {
                rootDir.resolve("tests"),
                rootDir.resolve("tests").resolve("eutest")
            };
            for (Path dir : searchDirs) {
                if (Files.isDirectory(dir)) {
                    try (DirectoryStream<Path> ds = Files.newDirectoryStream(dir, "t_*.e")) {
                        for (Path p : ds) {
                            if (filterPattern != null && !p.getFileName().toString().contains(filterPattern)) {
                                continue;
                            }
                            testCases.add(new TestCase(p, dir));
                        }
                    } catch (IOException ignored) {}
                }
            }
            testCases.sort(Comparator.comparing(tc -> tc.path.getFileName().toString()));
        }

        System.out.println("============================================================");
        System.out.printf(" OpenEuphoria Test-Suite (Java 25 Runner)%n");
        System.out.printf(" Interpreter : %s%n", interpreterBin);
        System.out.printf(" Testdateien : %d%n", testCases.size());
        System.out.printf(" EUINC       : %s%n", rootDir.resolve("eu_include"));
        System.out.printf(" Timeout     : %d Sekunden%n", timeoutSecs);
        System.out.println("============================================================\n");

        List<TestResult> results = new ArrayList<>();
        int passedFiles = 0;
        int failedFiles = 0;
        int timeoutFiles = 0;
        int crashFiles = 0;

        int unitTotal = 0;
        int unitPassed = 0;
        int unitFailed = 0;

        Path euInclude = rootDir.resolve("eu_include");

        for (int idx = 0; idx < testCases.size(); idx++) {
            TestCase tc = testCases.get(idx);
            TestResult res = runSingleTest(tc, interpreterBin, euInclude, timeoutSecs, rootDir);
            results.add(res);

            if (res.stats != null) {
                unitTotal += res.stats.total;
                unitPassed += res.stats.passed;
                unitFailed += res.stats.failed;
            }

            String statusTag;
            if (res.timeout) {
                statusTag = "[TIMEOUT]";
                timeoutFiles++;
            } else if (res.crash) {
                statusTag = "[CRASH]";
                crashFiles++;
            } else if (res.returncode == 0 && (res.stats == null || res.stats.failed == 0)) {
                statusTag = "[PASS]";
                passedFiles++;
            } else {
                statusTag = "[FAIL]";
                failedFiles++;
            }

            String statsStr = "";
            if (res.stats != null) {
                statsStr = String.format("(%d/%d passed)", res.stats.passed, res.stats.total);
            } else if (res.returncode != 0 && !res.timeout && !res.crash) {
                String err = extractFirstErrorLine(res.stderr, res.stdout);
                if (!err.isEmpty()) statsStr = "[" + err + "]";
            }

            System.out.printf("[%3d/%3d] %-9s %-35s %5.2fs %s%n",
                idx + 1, testCases.size(), statusTag, res.file, res.duration, statsStr);
            System.out.flush();
        }

        // Write JSON results
        String jsonName = interpreterBin.getFileName().toString().equals("eui_orig")
            ? "test_results_original_eui.json"
            : (isJava ? "test_results_java.json" : "test_results.json");
        Path jsonPath = rootDir.resolve(jsonName);
        try (BufferedWriter bw = Files.newBufferedWriter(jsonPath, StandardCharsets.UTF_8)) {
            bw.write("[\n");
            for (int i = 0; i < results.size(); i++) {
                bw.write(results.get(i).toJson());
                if (i < results.size() - 1) bw.write(",\n");
                else bw.write("\n");
            }
            bw.write("]\n");
        } catch (IOException e) {
            System.err.printf("Fehler beim Schreiben von %s: %s%n", jsonPath, e.getMessage());
        }

        System.out.println("\n" + "=".repeat(60));
        System.out.printf(" ZUSAMMENFASSUNG DER TESTERGEBNISSE (%s)%n", interpreterBin.getFileName());
        System.out.println("=".repeat(60));
        System.out.printf("Gesamtanzahl Testdateien  : %d%n", testCases.size());
        System.out.printf("Dateien PASS (Returncode 0): %d%n", passedFiles);
        System.out.printf("Dateien FAIL (Fehlercode)  : %d%n", failedFiles);
        System.out.printf("Dateien CRASH (Signal/Abst): %d%n", crashFiles);
        System.out.printf("Dateien TIMEOUT (> %ds)   : %d%n", timeoutSecs, timeoutFiles);
        if (unitTotal > 0) {
            System.out.println("-".repeat(60));
            System.out.printf("Erfasste Unit-Assertions   : %d%n", unitTotal);
            System.out.printf("  Assertions PASSED        : %d (%.1f%%)%n", unitPassed, (unitPassed * 100.0 / unitTotal));
            System.out.printf("  Assertions FAILED        : %d%n", unitFailed);
        }
        System.out.println("=".repeat(60));
        System.out.printf("Detaillierte JSON-Ergebnisse gespeichert in: %s%n", jsonPath);

        System.exit(failedFiles == 0 && timeoutFiles == 0 && crashFiles == 0 ? 0 : 1);
    }

    private static TestResult runSingleTest(TestCase tc, Path interpreterBin, Path euInclude, int timeoutSecs, Path rootDir) {
        Path relTest = tc.cwd.relativize(tc.path);
        List<String> cmd = List.of(
            interpreterBin.toString(),
            "-batch",
            "-D", "NOINET_TESTS",
            "-i", euInclude.toString(),
            relTest.toString()
        );

        ProcessBuilder pb = new ProcessBuilder(cmd);
        pb.directory(tc.cwd.toFile());
        pb.environment().put("EUINC", euInclude.toString());

        long startNanos = System.nanoTime();
        try {
            Process p = pb.start();
            ByteArrayOutputStream outBytes = new ByteArrayOutputStream();
            ByteArrayOutputStream errBytes = new ByteArrayOutputStream();

            Thread tOut = Thread.ofVirtual().start(() -> pipeStream(p.getInputStream(), outBytes));
            Thread tErr = Thread.ofVirtual().start(() -> pipeStream(p.getErrorStream(), errBytes));

            boolean finished = p.waitFor(timeoutSecs, TimeUnit.SECONDS);
            double duration = (System.nanoTime() - startNanos) / 1_000_000_000.0;

            if (!finished) {
                p.destroyForcibly();
                return new TestResult(
                    rootDir.relativize(tc.path).toString(),
                    tc.path.getFileName().toString(),
                    rootDir.relativize(tc.cwd).toString(),
                    -999,
                    outBytes.toString(StandardCharsets.UTF_8),
                    errBytes.toString(StandardCharsets.UTF_8),
                    duration,
                    true,
                    false,
                    null
                );
            }

            tOut.join(500);
            tErr.join(500);

            int exitCode = p.exitValue();
            String stdout = outBytes.toString(StandardCharsets.UTF_8);
            String stderr = errBytes.toString(StandardCharsets.UTF_8);
            boolean crash = (exitCode < 0 || exitCode == 134 || exitCode == 139);
            UnitTestStats stats = parseReportLine(stdout, stderr);

            return new TestResult(
                rootDir.relativize(tc.path).toString(),
                tc.path.getFileName().toString(),
                rootDir.relativize(tc.cwd).toString(),
                exitCode,
                stdout,
                stderr,
                duration,
                false,
                crash,
                stats
            );

        } catch (Exception e) {
            double duration = (System.nanoTime() - startNanos) / 1_000_000_000.0;
            return new TestResult(
                rootDir.relativize(tc.path).toString(),
                tc.path.getFileName().toString(),
                rootDir.relativize(tc.cwd).toString(),
                -998,
                "",
                e.getMessage(),
                duration,
                false,
                false,
                null
            );
        }
    }

    private static void pipeStream(InputStream in, OutputStream out) {
        try {
            in.transferTo(out);
        } catch (IOException ignored) {}
    }

    private static UnitTestStats parseReportLine(String stdout, String stderr) {
        String combined = (stdout != null ? stdout : "") + "\n" + (stderr != null ? stderr : "");
        Matcher m = REPORT_PATTERN.matcher(combined);
        if (m.find()) {
            return new UnitTestStats(
                Integer.parseInt(m.group(1)),
                Integer.parseInt(m.group(2)),
                Integer.parseInt(m.group(3))
            );
        }
        return null;
    }

    private static String extractFirstErrorLine(String stderr, String stdout) {
        String combined = (stderr != null && !stderr.isBlank()) ? stderr : stdout;
        if (combined == null) return "";
        for (String line : combined.split("\n")) {
            line = line.trim();
            if (!line.isEmpty()) {
                return line.length() > 60 ? line.substring(0, 57) + "..." : line;
            }
        }
        return "";
    }
}
