package eu;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static eu.Bytecode.*;

/**
 * Single-Pass OpenEuphoria 4.x Bytecode Compiler targeting the 32-bit Register VM.
 */
public final class Compiler {

    private static final class LocalVar {
        String name;
        int reg;
        int reservedRegs;
        VarType type;
        int customTypeRoutine;
        boolean isConstant;
        int depth;

        LocalVar(String name, int reg, int reservedRegs, VarType type, int customTypeRoutine, boolean isConstant, int depth) {
            this.name = name;
            this.reg = reg;
            this.reservedRegs = reservedRegs;
            this.type = type;
            this.customTypeRoutine = customTypeRoutine;
            this.isConstant = isConstant;
            this.depth = depth;
        }
    }

    private static final class LoopContext {
        String label;
        boolean isForLoop;
        boolean isSwitchOrIf;
        int scopeDepth;
        int continueTarget;
        int retryTarget;
        final List<Integer> exitJumps = new ArrayList<>();
        final List<Integer> continueJumps = new ArrayList<>();
        final List<Integer> retryJumps = new ArrayList<>();
        final List<Integer> entryJumps = new ArrayList<>();

        LoopContext(String label, boolean isForLoop, boolean isSwitchOrIf, int scopeDepth, int continueTarget, int retryTarget) {
            this.label = label;
            this.isForLoop = isForLoop;
            this.isSwitchOrIf = isSwitchOrIf;
            this.scopeDepth = scopeDepth;
            this.continueTarget = continueTarget;
            this.retryTarget = retryTarget;
        }
    }

    private static final class IncludeFrame {
        String filePath;
        String currentNs;
        Lexer lexer;
        Token curr;
        Token prev;

        IncludeFrame(String filePath, String currentNs, Lexer lexer, Token curr, Token prev) {
            this.filePath = filePath;
            this.currentNs = currentNs;
            this.lexer = lexer;
            this.curr = curr;
            this.prev = prev;
        }
    }

    private static final class PendingGoto {
        final String label;
        final int jmpOffset;

        PendingGoto(String label, int jmpOffset) {
            this.label = label;
            this.jmpOffset = jmpOffset;
        }
    }

    private static final class SavedDefaultExpr {
        final int paramReg;
        final Lexer lexer;
        final Token curr;

        SavedDefaultExpr(int paramReg, Lexer lexer, Token curr) {
            this.paramReg = paramReg;
            this.lexer = lexer.copyState();
            this.curr = curr;
        }
    }

    private static final class AccessStep {
        final boolean isSlice;
        final int seqReg;
        final int idxReg;

        AccessStep(boolean isSlice, int seqReg, int idxReg) {
            this.isSlice = isSlice;
            this.seqReg = seqReg;
            this.idxReg = idxReg;
        }
    }

    private static final Map<String, BuiltinId> BUILTINS = new HashMap<>();
    static {
        BUILTINS.put("length",          BuiltinId.Length);
        BUILTINS.put("append",          BuiltinId.Append);
        BUILTINS.put("prepend",         BuiltinId.Prepend);
        BUILTINS.put("repeat",          BuiltinId.Repeat);
        BUILTINS.put("head",            BuiltinId.Head);
        BUILTINS.put("tail",            BuiltinId.Tail);
        BUILTINS.put("remove",          BuiltinId.Remove);
        BUILTINS.put("replace",         BuiltinId.Replace);
        BUILTINS.put("insert",          BuiltinId.Insert);
        BUILTINS.put("splice",          BuiltinId.Splice);
        BUILTINS.put("compare",         BuiltinId.Compare);
        BUILTINS.put("equal",           BuiltinId.Equal);
        BUILTINS.put("find",            BuiltinId.Find);
        BUILTINS.put("find_from",       BuiltinId.Find);
        BUILTINS.put("match",           BuiltinId.Match);
        BUILTINS.put("match_from",      BuiltinId.Match);
        BUILTINS.put("hash",            BuiltinId.Hash);

        BUILTINS.put("atom",            BuiltinId.Atom);
        BUILTINS.put("integer",         BuiltinId.Integer);
        BUILTINS.put("sequence",        BuiltinId.Sequence);
        BUILTINS.put("object",          BuiltinId.Object);

        BUILTINS.put("floor",           BuiltinId.Floor);
        BUILTINS.put("remainder",       BuiltinId.Remainder);
        BUILTINS.put("power",           BuiltinId.Power);
        BUILTINS.put("sqrt",            BuiltinId.Sqrt);
        BUILTINS.put("sin",             BuiltinId.Sin);
        BUILTINS.put("cos",             BuiltinId.Cos);
        BUILTINS.put("tan",             BuiltinId.Tan);
        BUILTINS.put("arctan",          BuiltinId.Arctan);
        BUILTINS.put("log",             BuiltinId.Log);
        BUILTINS.put("rand",            BuiltinId.Rand);
        BUILTINS.put("and_bits",        BuiltinId.AndBits);
        BUILTINS.put("or_bits",         BuiltinId.OrBits);
        BUILTINS.put("xor_bits",        BuiltinId.XorBits);
        BUILTINS.put("not_bits",        BuiltinId.NotBits);

        BUILTINS.put("puts",            BuiltinId.Puts);
        BUILTINS.put("print",           BuiltinId.Print);
        BUILTINS.put("printf",          BuiltinId.Printf);
        BUILTINS.put("sprintf",         BuiltinId.Sprintf);
        BUILTINS.put("open",            BuiltinId.Open);
        BUILTINS.put("close",           BuiltinId.Close);
        BUILTINS.put("getc",            BuiltinId.Getc);
        BUILTINS.put("gets",            BuiltinId.Gets);
        BUILTINS.put("get_key",         BuiltinId.GetKey);
        BUILTINS.put("position",        BuiltinId.Position);
        BUILTINS.put("clear_screen",    BuiltinId.ClearScreen);

        BUILTINS.put("time",            BuiltinId.Time);
        BUILTINS.put("date",            BuiltinId.Date);
        BUILTINS.put("getenv",          BuiltinId.Getenv);
        BUILTINS.put("platform",        BuiltinId.Platform);
        BUILTINS.put("command_line",    BuiltinId.CommandLine);
        BUILTINS.put("system",          BuiltinId.System);
        BUILTINS.put("system_exec",     BuiltinId.SystemExec);
        BUILTINS.put("abort",           BuiltinId.Abort);
        BUILTINS.put("option_switches", BuiltinId.OptionSwitches);
        BUILTINS.put("include_paths",   BuiltinId.IncludePaths);
        BUILTINS.put("warning",         BuiltinId.Warning);
        BUILTINS.put("trace",           BuiltinId.Trace);
        BUILTINS.put("profile",         BuiltinId.Profile);
        BUILTINS.put("task_create",      BuiltinId.TaskCreate);
        BUILTINS.put("task_schedule",    BuiltinId.TaskSchedule);
        BUILTINS.put("task_yield",       BuiltinId.TaskYield);
        BUILTINS.put("task_self",        BuiltinId.TaskSelf);
        BUILTINS.put("task_status",      BuiltinId.TaskStatus);
        BUILTINS.put("task_list",        BuiltinId.TaskList);
        BUILTINS.put("task_suspend",     BuiltinId.TaskSuspend);
        BUILTINS.put("task_clock_start", BuiltinId.TaskClockStart);
        BUILTINS.put("task_clock_stop",  BuiltinId.TaskClockStop);

        BUILTINS.put("routine_id",      BuiltinId.RoutineId);
        BUILTINS.put("call_func",       BuiltinId.CallFunc);
        BUILTINS.put("call_proc",       BuiltinId.CallProc);
        BUILTINS.put("delete_routine",  BuiltinId.DeleteRoutine);
        BUILTINS.put("delete",          BuiltinId.Delete);

        BUILTINS.put("machine_func",    BuiltinId.MachineFunc);
        BUILTINS.put("machine_proc",    BuiltinId.MachineProc);
        BUILTINS.put("sizeof",          BuiltinId.Sizeof);
        BUILTINS.put("mem_copy",        BuiltinId.MemCopy);
        BUILTINS.put("mem_set",         BuiltinId.MemSet);
        BUILTINS.put("peek",            BuiltinId.Peek);
        BUILTINS.put("peeks",           BuiltinId.Peeks);
        BUILTINS.put("peek_string",     BuiltinId.PeekString);
        BUILTINS.put("peek2s",          BuiltinId.Peek2s);
        BUILTINS.put("peek2u",          BuiltinId.Peek2u);
        BUILTINS.put("peek4s",          BuiltinId.Peek4s);
        BUILTINS.put("peek4u",          BuiltinId.Peek4u);
        BUILTINS.put("peek8s",          BuiltinId.Peek8s);
        BUILTINS.put("peek8u",          BuiltinId.Peek8u);
        BUILTINS.put("peek_longs",      BuiltinId.Peek8s);
        BUILTINS.put("peek_longu",      BuiltinId.Peek8u);
        BUILTINS.put("peek_pointer",    BuiltinId.PeekPointer);
        BUILTINS.put("poke",            BuiltinId.Poke);
        BUILTINS.put("poke2",           BuiltinId.Poke2);
        BUILTINS.put("poke4",           BuiltinId.Poke4);
        BUILTINS.put("poke8",           BuiltinId.Poke8);
        BUILTINS.put("poke_long",       BuiltinId.Poke8);
        BUILTINS.put("poke_pointer",    BuiltinId.PokePointer);
        BUILTINS.put("c_func",          BuiltinId.CFunc);
        BUILTINS.put("c_proc",          BuiltinId.CProc);
        BUILTINS.put("call",            BuiltinId.Call);
    }

    private Lexer lexer;
    private final String initialSource;
    private Token curr;
    private Token prev;
    private String currentFile;
    private String currentNs = "";
    private boolean hadError = false;
    private String errorMsg = "";

    private List<IncludeFrame> includeStack = new ArrayList<>();
    private final Set<String> includedFiles = new HashSet<>();
    private final List<String> includeDirs = new ArrayList<>();
    private final Set<String> definedSymbols = new HashSet<>();
    private final Map<String, String> nsAliases = new HashMap<>();
    private final Map<String, Set<String>> fileDirectIncludes = new HashMap<>();
    private final Set<String> unaliasedIncludedFiles = new HashSet<>();

    private Program prog = null;
    private int currentRoutineIdx = 0;
    private boolean inCondition = false;
    private boolean currentDeclExported = false;
    private boolean currentDeclOverride = false;

    private List<LocalVar> locals = new ArrayList<>();
    private int scopeDepth = 0;
    private int nextReg = 0;
    private int maxReg = 0;
    private List<LoopContext> loops = new ArrayList<>();
    private final List<Integer> dollarSeqStack = new ArrayList<>();

    private Map<String, Integer> labelTargets = new HashMap<>();
    private List<PendingGoto> pendingGotos = new ArrayList<>();
    private final Set<String> scannedIncludeFiles = new HashSet<>();

    public Compiler(String source, String filePath) {
        this.lexer = new Lexer(source);
        this.initialSource = source;
        this.currentFile = filePath != null ? filePath : "<main>";

        definedSymbols.add("EU4");
        definedSymbols.add("EU4_1");
        definedSymbols.add("EU4_1_0");

        String osName = System.getProperty("os.name", "").toLowerCase();
        boolean isWin = osName.contains("win");
        if (isWin) {
            definedSymbols.add("WINDOWS");
            definedSymbols.add("WIN32");
        } else {
            definedSymbols.add("UNIX");
            if (osName.contains("linux")) {
                definedSymbols.add("LINUX");
            } else if (osName.contains("mac") || osName.contains("darwin")) {
                definedSymbols.add("OSX");
            } else if (osName.contains("bsd")) {
                definedSymbols.add("FREEBSD");
            }
        }

        definedSymbols.add("BITS64");
        definedSymbols.add("LONG64");
        definedSymbols.add("X86_64");
        definedSymbols.add("EUI");
        definedSymbols.add("JAVA");

        includeDirs.add(".");
        includeDirs.add("eu_include");
        try {
            var codeSource = Compiler.class.getProtectionDomain().getCodeSource();
            if (codeSource != null && codeSource.getLocation() != null) {
                Path jarPath = Paths.get(codeSource.getLocation().toURI()).toAbsolutePath();
                Path parent = jarPath.getParent();
                if (parent != null) {
                    includeDirs.add(parent.resolve("eu_include").toString());
                    if (parent.getParent() != null) {
                        includeDirs.add(parent.getParent().resolve("eu_include").toString());
                    }
                }
            }
        } catch (Exception ignored) {
        }

        advance();
    }

    public Compiler(String source) {
        this(source, "<main>");
    }

    public void addIncludeDir(String dir) {
        includeDirs.add(dir);
    }

    public void defineSymbol(String sym) {
        definedSymbols.add(sym);
    }

    public String errorMessage() {
        return errorMsg;
    }

    private RoutineProto currentRoutine() {
        return prog.routines.get(currentRoutineIdx);
    }

    private void advance() {
        prev = curr;
        for (;;) {
            curr = lexer.nextToken();
            if (curr.type == TokenType.Eof && !includeStack.isEmpty()) {
                IncludeFrame parent = includeStack.remove(includeStack.size() - 1);
                lexer = parent.lexer;
                curr = parent.curr;
                currentFile = parent.filePath;
                currentNs = parent.currentNs;
                if (curr.type != TokenType.Eof) break;
                continue;
            }
            if (curr.type != TokenType.Error) break;
            errorAt(curr, curr.lexeme);
        }
    }

    private boolean check(TokenType t) {
        return curr != null && curr.type == t;
    }

    private boolean match(TokenType t) {
        if (!check(t)) return false;
        advance();
        return true;
    }

    private void consume(TokenType t, String msg) {
        if (check(t)) {
            advance();
            return;
        }
        errorAt(curr, msg);
    }

    private void errorAt(Token tok, String msg) {
        if (hadError) return;
        hadError = true;
        int line = tok != null ? tok.line : 0;
        int col = tok != null ? tok.col : 0;
        String lex = tok != null ? tok.lexeme : "";
        errorMsg = String.format("[%s:%d:%d] Syntaxfehler bei '%s': %s",
                currentFile, line, col, lex, msg);
    }

    private void error(String msg) {
        errorAt(prev != null ? prev : curr, msg);
    }

    private static String lookupEmbeddedStdlib(String relPath) {
        String norm = relPath.replace('\\', '/');
        while (norm.startsWith("./")) {
            norm = norm.substring(2);
        }
        String resourcePath = "/eu_include/" + norm;
        try (InputStream in = Compiler.class.getResourceAsStream(resourcePath)) {
            if (in != null) {
                return new String(in.readAllBytes(), StandardCharsets.UTF_8);
            }
        } catch (IOException ignored) {
        }
        return "";
    }

    private String resolveIncludePath(String rawPath) {
        try {
            Path p = Paths.get(rawPath.replace('\\', '/'));
            if (p.isAbsolute() && Files.exists(p)) {
                return p.toRealPath().toString();
            }
            if (!"<main>".equals(currentFile) && !currentFile.startsWith("<embedded>/")) {
                Path curDir = Paths.get(currentFile).getParent();
                if (curDir != null) {
                    Path candidate = curDir.resolve(p);
                    if (Files.exists(candidate)) {
                        return candidate.toRealPath().toString();
                    }
                }
            }
            for (String dir : includeDirs) {
                Path candidate = Paths.get(dir).resolve(p);
                if (Files.exists(candidate)) {
                    return candidate.toRealPath().toString();
                }
            }
            if (currentFile.startsWith("<embedded>/")) {
                Path curRel = Paths.get(currentFile.substring(11)).getParent();
                Path relCandPath = (curRel != null ? curRel.resolve(p) : p).normalize();
                String relCand = relCandPath.toString().replace('\\', '/');
                if (!lookupEmbeddedStdlib(relCand).isEmpty()) {
                    return "<embedded>/" + relCand;
                }
            }
            String normRel = p.normalize().toString().replace('\\', '/');
            if (!lookupEmbeddedStdlib(normRel).isEmpty()) {
                return "<embedded>/" + normRel;
            }
        } catch (Exception ignored) {
        }
        return "";
    }

    private static boolean isBinOp(TokenType t) {
        return switch (t) {
            case Plus, Minus, Star, Slash, Ampersand,
                 Equal, NotEqual, Less, LessEq, Greater, GreaterEq,
                 KwAnd, KwOr, KwXor -> true;
            default -> false;
        };
    }

    private String readFileContent(String path) {
        if (path.startsWith("<embedded>/")) {
            return lookupEmbeddedStdlib(path.substring(11));
        }
        try {
            return Files.readString(Paths.get(path), StandardCharsets.UTF_8);
        } catch (java.nio.charset.MalformedInputException mie) {
            try {
                return Files.readString(Paths.get(path), StandardCharsets.ISO_8859_1);
            } catch (IOException e) {
                return "";
            }
        } catch (IOException e) {
            return "";
        }
    }

    private void prescanFileRoutines(String src, String filePath, String defaultNs) {
        Lexer scan = new Lexer(src);
        Token[] tokBox = new Token[]{ scan.nextToken() };
        String ns = defaultNs;
        boolean nextExported = false;
        boolean nextOverride = false;

        Runnable adv = () -> tokBox[0] = scan.nextToken();

        class ScanHelper {
            boolean evalScanIfdef() {
                boolean res = parseAtom();
                while (tokBox[0].type == TokenType.KwAnd || tokBox[0].type == TokenType.KwOr || tokBox[0].type == TokenType.KwXor) {
                    TokenType op = tokBox[0].type;
                    adv.run();
                    boolean rhs = parseAtom();
                    if (op == TokenType.KwAnd) res = res && rhs;
                    else if (op == TokenType.KwOr) res = res || rhs;
                    else res = (res != rhs);
                }
                if (tokBox[0].type == TokenType.KwThen) adv.run();
                return res;
            }

            boolean parseAtom() {
                boolean inv = false;
                if (tokBox[0].type == TokenType.KwNot) {
                    inv = true;
                    adv.run();
                }
                if (tokBox[0].type == TokenType.LParen) {
                    adv.run();
                    boolean inner = evalScanIfdef();
                    if (tokBox[0].type == TokenType.RParen) adv.run();
                    return inv ? !inner : inner;
                }
                if (tokBox[0].type == TokenType.Identifier || tokBox[0].type == TokenType.IntLiteral) {
                    String sym = tokBox[0].lexeme;
                    adv.run();
                    boolean def = definedSymbols.contains(sym);
                    return inv ? !def : def;
                }
                adv.run();
                return false;
            }

            boolean skipScanIfdef() {
                int depth = 0;
                while (tokBox[0].type != TokenType.Eof) {
                    if (tokBox[0].type == TokenType.KwIfdef) {
                        depth++;
                        adv.run();
                    } else if (depth == 0 && (tokBox[0].type == TokenType.KwElsifdef || tokBox[0].type == TokenType.KwElsedef)) {
                        return false;
                    } else if (tokBox[0].type == TokenType.KwEnd) {
                        adv.run();
                        if (tokBox[0].type == TokenType.KwIfdef) {
                            adv.run();
                            if (depth == 0) return true;
                            depth--;
                        }
                    } else {
                        adv.run();
                    }
                }
                return true;
            }

            void skipBalanced() {
                int depth = 1;
                adv.run();
                while (tokBox[0].type != TokenType.Eof && depth > 0) {
                    TokenType tt = tokBox[0].type;
                    if (tt == TokenType.LParen || tt == TokenType.LBrace || tt == TokenType.LBracket) {
                        depth++;
                    } else if (tt == TokenType.RParen || tt == TokenType.RBrace || tt == TokenType.RBracket) {
                        depth--;
                    }
                    adv.run();
                }
            }

            void skipExpr() {
                for (;;) {
                    while (tokBox[0].type == TokenType.Plus || tokBox[0].type == TokenType.Minus || tokBox[0].type == TokenType.KwNot) {
                        adv.run();
                    }
                    TokenType tt = tokBox[0].type;
                    if (tt == TokenType.LParen || tt == TokenType.LBrace) {
                        skipBalanced();
                    } else if (tt == TokenType.Identifier || tt == TokenType.KwObject ||
                               tt == TokenType.KwAtom || tt == TokenType.KwInteger ||
                               tt == TokenType.KwSequence) {
                        adv.run();
                        if (tokBox[0].type == TokenType.Colon) {
                            adv.run();
                            if (tokBox[0].type == TokenType.Identifier) adv.run();
                        }
                    } else if (tt == TokenType.IntLiteral || tt == TokenType.FloatLiteral ||
                               tt == TokenType.StringLiteral || tt == TokenType.Dollar ||
                               tt == TokenType.Question) {
                        adv.run();
                    } else {
                        break;
                    }
                    while (tokBox[0].type == TokenType.LParen || tokBox[0].type == TokenType.LBracket) {
                        skipBalanced();
                    }
                    if (isBinOp(tokBox[0].type)) {
                        adv.run();
                    } else {
                        break;
                    }
                }
            }

            void addGlobalStub(String gname, String gns, boolean exported) {
                for (GlobalVarInfo g : prog.globals) {
                    if (g.name.equals(gname) && g.file.equals(filePath)) {
                        if (exported) g.isExported = true;
                        return;
                    }
                }
                GlobalVarInfo info = new GlobalVarInfo();
                info.name = gname;
                info.ns = gns;
                info.file = filePath;
                info.type = VarType.Object;
                info.customTypeRoutine = 0;
                info.isConstant = false;
                info.isExported = exported;
                info.initialValue = Value.NONE;
                prog.globals.add(info);
            }
        }

        ScanHelper helper = new ScanHelper();
        List<Boolean> ifdefTakenStack = new ArrayList<>();

        while (tokBox[0].type != TokenType.Eof) {
            Token tok = tokBox[0];
            if (tok.type == TokenType.KwNamespace) {
                adv.run();
                if (tokBox[0].type == TokenType.Identifier) {
                    ns = tokBox[0].lexeme;
                    adv.run();
                }
                continue;
            }
            if (tok.type == TokenType.KwInclude) {
                adv.run();
                StringBuilder incName = new StringBuilder();
                if (tokBox[0].type == TokenType.StringLiteral) {
                    incName.append(tokBox[0].strVal);
                    adv.run();
                } else {
                    while (tokBox[0].type == TokenType.Identifier || tokBox[0].type == TokenType.Slash || tokBox[0].type == TokenType.Dot) {
                        incName.append(tokBox[0].lexeme);
                        adv.run();
                    }
                }
                String incAlias = "";
                if (tokBox[0].type == TokenType.KwAs) {
                    adv.run();
                    if (tokBox[0].type == TokenType.Identifier) {
                        incAlias = tokBox[0].lexeme;
                        adv.run();
                    }
                }
                String resolved = resolveIncludePath(incName.toString());
                if (!resolved.isEmpty()) {
                    if (incAlias.isEmpty()) {
                        unaliasedIncludedFiles.add(resolved);
                    } else {
                        nsAliases.put(incAlias, resolved);
                    }
                    fileDirectIncludes.computeIfAbsent(filePath, k -> new HashSet<>()).add(resolved);
                    if (scannedIncludeFiles.add(resolved)) {
                        String content = readFileContent(resolved);
                        if (!content.isEmpty()) {
                            prescanFileRoutines(content, resolved, incAlias);
                        }
                    }
                }
                continue;
            }
            if (tok.type == TokenType.KwWith) {
                int line = tok.line;
                adv.run();
                if (tokBox[0].line == line && "define".equals(tokBox[0].lexeme)) {
                    adv.run();
                    if (tokBox[0].line == line && tokBox[0].type == TokenType.Identifier) {
                        definedSymbols.add(tokBox[0].lexeme);
                    }
                }
                while (tokBox[0].type != TokenType.Eof && tokBox[0].line == line) adv.run();
                continue;
            }
            if (tok.type == TokenType.KwWithout) {
                int line = tok.line;
                while (tokBox[0].type != TokenType.Eof && tokBox[0].line == line) adv.run();
                continue;
            }
            if (tok.type == TokenType.KwIfdef) {
                adv.run();
                boolean cond = helper.evalScanIfdef();
                if (cond) {
                    ifdefTakenStack.add(true);
                } else {
                    if (!helper.skipScanIfdef()) {
                        ifdefTakenStack.add(false);
                    }
                }
                continue;
            }
            if (tok.type == TokenType.KwElsifdef) {
                adv.run();
                boolean taken = !ifdefTakenStack.isEmpty() && ifdefTakenStack.get(ifdefTakenStack.size() - 1);
                boolean cond = helper.evalScanIfdef();
                if (!taken && cond) {
                    if (!ifdefTakenStack.isEmpty()) ifdefTakenStack.set(ifdefTakenStack.size() - 1, true);
                } else {
                    if (helper.skipScanIfdef()) {
                        if (!ifdefTakenStack.isEmpty()) ifdefTakenStack.remove(ifdefTakenStack.size() - 1);
                    }
                }
                continue;
            }
            if (tok.type == TokenType.KwElsedef) {
                adv.run();
                boolean taken = !ifdefTakenStack.isEmpty() && ifdefTakenStack.get(ifdefTakenStack.size() - 1);
                if (taken) {
                    if (helper.skipScanIfdef()) {
                        if (!ifdefTakenStack.isEmpty()) ifdefTakenStack.remove(ifdefTakenStack.size() - 1);
                    }
                }
                continue;
            }
            if (tok.type == TokenType.KwEnd) {
                adv.run();
                if (tokBox[0].type == TokenType.KwIfdef) {
                    if (!ifdefTakenStack.isEmpty()) ifdefTakenStack.remove(ifdefTakenStack.size() - 1);
                }
                adv.run();
                nextExported = false;
                nextOverride = false;
                continue;
            }

            if (tok.type == TokenType.KwGlobal || tok.type == TokenType.KwPublic || tok.type == TokenType.KwExport) {
                nextExported = true;
                adv.run();
                continue;
            }
            if (tok.type == TokenType.KwOverride) {
                nextExported = true;
                nextOverride = true;
                adv.run();
                continue;
            }
            if (tok.type == TokenType.KwDeprecate) {
                adv.run();
                continue;
            }

            if (tok.type == TokenType.KwConstant) {
                adv.run();
                while (tokBox[0].type != TokenType.Eof) {
                    if (tokBox[0].type == TokenType.Dollar) { adv.run(); break; }
                    if (tokBox[0].type != TokenType.Identifier) break;
                    helper.addGlobalStub(tokBox[0].lexeme, ns, nextExported);
                    adv.run();
                    if (tokBox[0].type == TokenType.Equal) {
                        adv.run();
                        helper.skipExpr();
                    }
                    if (tokBox[0].type == TokenType.Comma) {
                        adv.run();
                    } else {
                        break;
                    }
                }
                nextExported = false;
                nextOverride = false;
                continue;
            }

            if (tok.type == TokenType.KwEnum) {
                adv.run();
                boolean isEnumType = false;
                if (tokBox[0].type == TokenType.KwBy) {
                    adv.run();
                    if (tokBox[0].type == TokenType.Plus || tokBox[0].type == TokenType.Minus ||
                        tokBox[0].type == TokenType.Star || tokBox[0].type == TokenType.Slash) adv.run();
                    adv.run();
                }
                if (tokBox[0].type == TokenType.KwType) {
                    isEnumType = true;
                    adv.run();
                    if (tokBox[0].type == TokenType.Identifier) {
                        String tname = tokBox[0].lexeme;
                        boolean exists = false;
                        for (int i = 1; i < prog.routines.size(); i++) {
                            if (prog.routines.get(i).name.equals(tname) && prog.routines.get(i).file.equals(filePath)) {
                                exists = true;
                                break;
                            }
                        }
                        if (!exists) {
                            RoutineProto stub = new RoutineProto();
                            stub.name = tname;
                            stub.ns = ns;
                            stub.file = filePath;
                            stub.isFunction = true;
                            stub.isType = true;
                            stub.isDefined = false;
                            stub.isExported = nextExported;
                            stub.isOverride = nextOverride;
                            stub.minArity = 1;
                            stub.arity = 1;
                            prog.routines.add(stub);
                        }
                        adv.run();
                    }
                    if (tokBox[0].type == TokenType.KwBy) {
                        adv.run();
                        if (tokBox[0].type == TokenType.Plus || tokBox[0].type == TokenType.Minus ||
                            tokBox[0].type == TokenType.Star || tokBox[0].type == TokenType.Slash) adv.run();
                        adv.run();
                    }
                }
                while (tokBox[0].type != TokenType.Eof) {
                    if (tokBox[0].type == TokenType.Dollar) { adv.run(); break; }
                    if (tokBox[0].type != TokenType.Identifier) break;
                    helper.addGlobalStub(tokBox[0].lexeme, ns, nextExported);
                    adv.run();
                    if (tokBox[0].type == TokenType.Equal) {
                        adv.run();
                        helper.skipExpr();
                    }
                    if (tokBox[0].type == TokenType.Comma) {
                        adv.run();
                    } else {
                        break;
                    }
                }
                if (isEnumType) {
                    while (tokBox[0].type != TokenType.Eof) {
                        if (tokBox[0].type == TokenType.KwEnd) {
                            adv.run();
                            if (tokBox[0].type == TokenType.KwType) { adv.run(); break; }
                        } else {
                            adv.run();
                        }
                    }
                }
                nextExported = false;
                nextOverride = false;
                continue;
            }

            if (tok.type == TokenType.KwObject || tok.type == TokenType.KwAtom ||
                tok.type == TokenType.KwInteger || tok.type == TokenType.KwSequence) {
                adv.run();
                if (tokBox[0].type == TokenType.Identifier) {
                    while (tokBox[0].type != TokenType.Eof) {
                        if (tokBox[0].type == TokenType.Dollar) { adv.run(); break; }
                        if (tokBox[0].type != TokenType.Identifier) break;
                        helper.addGlobalStub(tokBox[0].lexeme, ns, nextExported);
                        adv.run();
                        if (tokBox[0].type == TokenType.Equal) {
                            adv.run();
                            helper.skipExpr();
                        }
                        if (tokBox[0].type == TokenType.Comma) {
                            adv.run();
                        } else {
                            break;
                        }
                    }
                    nextExported = false;
                    nextOverride = false;
                    continue;
                }
            }

            if (tok.type == TokenType.Identifier) {
                TokenType nextTt = scan.peekToken().type;
                if (nextTt == TokenType.Colon) {
                    adv.run();
                    adv.run();
                    nextTt = scan.peekToken().type;
                }
                if (nextTt == TokenType.Identifier) {
                    adv.run();
                    while (tokBox[0].type != TokenType.Eof) {
                        if (tokBox[0].type == TokenType.Dollar) { adv.run(); break; }
                        if (tokBox[0].type != TokenType.Identifier) break;
                        helper.addGlobalStub(tokBox[0].lexeme, ns, nextExported);
                        adv.run();
                        if (tokBox[0].type == TokenType.Equal) {
                            adv.run();
                            helper.skipExpr();
                        }
                        if (tokBox[0].type == TokenType.Comma) {
                            adv.run();
                        } else {
                            break;
                        }
                    }
                    nextExported = false;
                    nextOverride = false;
                    continue;
                }
            }

            if (tok.type == TokenType.KwProcedure || tok.type == TokenType.KwFunction || tok.type == TokenType.KwType) {
                TokenType kind = tok.type;
                adv.run();
                if (kind == TokenType.KwType && tokBox[0].type == TokenType.KwEnum) {
                    adv.run();
                    if (tokBox[0].type == TokenType.Identifier) {
                        String tname = tokBox[0].lexeme;
                        boolean exists = false;
                        for (int i = 1; i < prog.routines.size(); i++) {
                            if (prog.routines.get(i).name.equals(tname) && prog.routines.get(i).file.equals(filePath)) {
                                exists = true;
                                break;
                            }
                        }
                        if (!exists) {
                            RoutineProto stub = new RoutineProto();
                            stub.name = tname;
                            stub.ns = ns;
                            stub.file = filePath;
                            stub.isFunction = true;
                            stub.isType = true;
                            stub.isDefined = false;
                            stub.isExported = nextExported;
                            stub.isOverride = nextOverride;
                            stub.minArity = 1;
                            stub.arity = 1;
                            prog.routines.add(stub);
                        }
                        adv.run();
                    }
                    if (tokBox[0].type == TokenType.KwBy) {
                        adv.run();
                        if (tokBox[0].type == TokenType.Plus || tokBox[0].type == TokenType.Minus ||
                            tokBox[0].type == TokenType.Star || tokBox[0].type == TokenType.Slash) adv.run();
                        adv.run();
                    }
                    while (tokBox[0].type != TokenType.Eof) {
                        if (tokBox[0].type == TokenType.Dollar) { adv.run(); break; }
                        if (tokBox[0].type != TokenType.Identifier) break;
                        helper.addGlobalStub(tokBox[0].lexeme, ns, nextExported);
                        adv.run();
                        if (tokBox[0].type == TokenType.Equal) {
                            adv.run();
                            helper.skipExpr();
                        }
                        if (tokBox[0].type == TokenType.Comma) {
                            adv.run();
                        } else {
                            break;
                        }
                    }
                    while (tokBox[0].type != TokenType.Eof) {
                        if (tokBox[0].type == TokenType.KwEnd) {
                            adv.run();
                            if (tokBox[0].type == TokenType.KwType) { adv.run(); break; }
                        } else {
                            adv.run();
                        }
                    }
                    nextExported = false;
                    nextOverride = false;
                    continue;
                }
                if (tokBox[0].type == TokenType.Identifier) {
                    String rname = tokBox[0].lexeme;
                    adv.run();
                    if (tokBox[0].type == TokenType.LParen) {
                        adv.run();
                        int minAr = 0;
                        int maxAr = 0;
                        boolean seenDef = false;
                        if (tokBox[0].type != TokenType.RParen && tokBox[0].type != TokenType.Dollar) {
                            for (;;) {
                                if (tokBox[0].type == TokenType.Dollar || tokBox[0].type == TokenType.RParen || tokBox[0].type == TokenType.Eof) break;
                                maxAr++;
                                int pdepth = 0;
                                boolean paramHasEq = false;
                                while (tokBox[0].type != TokenType.Eof) {
                                    TokenType pt = tokBox[0].type;
                                    if (pt == TokenType.LParen || pt == TokenType.LBrace || pt == TokenType.LBracket) {
                                        pdepth++;
                                    } else if (pt == TokenType.RParen || pt == TokenType.RBrace || pt == TokenType.RBracket) {
                                        if (pdepth == 0) break;
                                        pdepth--;
                                    } else if (pdepth == 0 && pt == TokenType.Equal) {
                                        paramHasEq = true;
                                    } else if (pdepth == 0 && pt == TokenType.Comma) {
                                        break;
                                    }
                                    adv.run();
                                }
                                if (paramHasEq) seenDef = true;
                                if (!seenDef) minAr++;
                                if (tokBox[0].type == TokenType.Comma) adv.run();
                                else break;
                            }
                        }

                        boolean exists = false;
                        for (int i = 1; i < prog.routines.size(); i++) {
                            RoutineProto r = prog.routines.get(i);
                            if (r.name.equals(rname) && r.file.equals(filePath)) {
                                exists = true;
                                break;
                            }
                        }
                        if (!exists) {
                            RoutineProto stub = new RoutineProto();
                            stub.name = rname;
                            stub.ns = ns;
                            stub.file = filePath;
                            stub.isFunction = (kind != TokenType.KwProcedure);
                            stub.isType = (kind == TokenType.KwType);
                            stub.isDefined = false;
                            stub.isExported = nextExported;
                            stub.isOverride = nextOverride;
                            stub.minArity = minAr;
                            stub.arity = maxAr;
                            prog.routines.add(stub);
                        }

                        while (tokBox[0].type != TokenType.Eof) {
                            if (tokBox[0].type == TokenType.KwEnd) {
                                adv.run();
                                if (tokBox[0].type == kind) {
                                    adv.run();
                                    break;
                                }
                            } else {
                                adv.run();
                            }
                        }
                    }
                }
                nextExported = false;
                nextOverride = false;
                continue;
            }

            nextExported = false;
            nextOverride = false;
            adv.run();
        }
    }

    private void parseIncludeDirective() {
        StringBuilder rawPath = new StringBuilder();
        int incLine = prev.line;

        if (match(TokenType.StringLiteral)) {
            rawPath.append(prev.strVal);
        } else {
            while (!check(TokenType.Eof) && curr.line == incLine && !check(TokenType.KwAs)) {
                rawPath.append(curr.lexeme);
                advance();
            }
        }

        String alias = "";
        if (curr.line == incLine && match(TokenType.KwAs)) {
            consume(TokenType.Identifier, "Erwartet Namespace-Alias nach 'as'");
            alias = prev.lexeme;
        }

        String resolved = resolveIncludePath(rawPath.toString());
        if (resolved.isEmpty()) {
            error("Include-Datei nicht gefunden: '" + rawPath + "'");
            return;
        }

        if (!alias.isEmpty()) {
            nsAliases.put(alias, resolved);
        } else {
            unaliasedIncludedFiles.add(resolved);
        }
        fileDirectIncludes.computeIfAbsent(currentFile, k -> new HashSet<>()).add(resolved);

        if (includedFiles.contains(resolved)) {
            return;
        }
        includedFiles.add(resolved);

        String fileContent;
        if (resolved.startsWith("<embedded>/")) {
            String emb = lookupEmbeddedStdlib(resolved.substring(11));
            if (emb.isEmpty()) {
                error("Eingebettete Include-Datei konnte nicht geladen werden: '" + resolved + "'");
                return;
            }
            fileContent = emb;
        } else {
            try {
                fileContent = Files.readString(Paths.get(resolved), StandardCharsets.UTF_8);
            } catch (java.nio.charset.MalformedInputException mie) {
                try {
                    fileContent = Files.readString(Paths.get(resolved), StandardCharsets.ISO_8859_1);
                } catch (IOException e) {
                    error("Include-Datei konnte nicht gelesen werden: '" + resolved + "'");
                    return;
                }
            } catch (IOException e) {
                error("Include-Datei konnte nicht gelesen werden: '" + resolved + "'");
                return;
            }
        }

        includeStack.add(new IncludeFrame(currentFile, currentNs, lexer, curr, prev));
        if (scannedIncludeFiles.add(resolved)) {
            prescanFileRoutines(fileContent, resolved, alias);
        }

        currentFile = resolved;
        currentNs = alias;
        lexer = new Lexer(fileContent);
        advance();
    }

    private boolean evalIfdefExpr() {
        boolean res = parseIfdefAtom();
        while (match(TokenType.KwAnd) || match(TokenType.KwOr) || match(TokenType.KwXor)) {
            TokenType op = prev.type;
            boolean rhs = parseIfdefAtom();
            if (op == TokenType.KwAnd) res = res && rhs;
            else if (op == TokenType.KwOr) res = res || rhs;
            else res = (res != rhs);
        }
        return res;
    }

    private boolean parseIfdefAtom() {
        boolean inv = false;
        if (match(TokenType.KwNot)) {
            inv = true;
        }
        if (match(TokenType.LParen)) {
            boolean inner = evalIfdefExpr();
            consume(TokenType.RParen, "Erwartet ')' in 'ifdef'-Bedingung");
            return inv ? !inner : inner;
        }
        if (match(TokenType.Identifier) || match(TokenType.IntLiteral)) {
            String sym = prev.lexeme;
            boolean def = definedSymbols.contains(sym);
            return inv ? !def : def;
        }
        errorAt(curr, "Erwartet Bezeichner in 'ifdef'-Bedingung");
        return false;
    }

    private boolean evalIfdefCondition() {
        boolean res = evalIfdefExpr();
        consume(TokenType.KwThen, "Erwartet 'then' nach 'ifdef'-Bedingung");
        return res;
    }

    private boolean skipIfdefBranch() {
        int depth = 0;
        while (!check(TokenType.Eof)) {
            if (check(TokenType.KwIfdef)) {
                depth++;
                advance();
            } else if (depth == 0 && (check(TokenType.KwElsifdef) || check(TokenType.KwElsedef))) {
                return false;
            } else if (check(TokenType.KwEnd)) {
                advance();
                if (match(TokenType.KwIfdef)) {
                    if (depth == 0) {
                        return true;
                    }
                    depth--;
                }
            } else {
                advance();
            }
        }
        return true;
    }

    private void parseBranchBody() {
        while (!check(TokenType.KwElsifdef) && !check(TokenType.KwElsedef) &&
               !check(TokenType.KwEnd) && !check(TokenType.Eof) && !hadError) {
            if (currentRoutineIdx == 0 && scopeDepth == 0) {
                parseTopLevel();
            } else {
                parseStatement();
            }
        }
    }

    private void parseIfdefStatement() {
        boolean taken = false;
        boolean cond = evalIfdefCondition();

        if (cond) {
            taken = true;
            parseBranchBody();
        } else {
            if (skipIfdefBranch()) return;
        }

        while (match(TokenType.KwElsifdef)) {
            boolean econd = evalIfdefCondition();
            if (!taken && econd) {
                taken = true;
                parseBranchBody();
            } else {
                if (skipIfdefBranch()) return;
            }
        }

        if (match(TokenType.KwElsedef)) {
            if (!taken) {
                parseBranchBody();
            } else {
                if (skipIfdefBranch()) return;
            }
        }

        if (match(TokenType.KwEnd)) {
            consume(TokenType.KwIfdef, "Erwartet 'ifdef' nach 'end'");
        }
    }

    private int allocReg() {
        if (nextReg >= 250) {
            error("Zu viele lokale Register / temporäre Ausdrücke in einer Routine (>250)");
            return 0;
        }
        int r = nextReg++;
        if (nextReg > maxReg) maxReg = nextReg;
        currentRoutine().maxRegs = maxReg;
        return r;
    }

    private void freeRegsTo(int reg) {
        nextReg = reg;
    }

    private int addConstant(Value v) {
        if (!v.isSeq()) {
            for (int i = 0; i < prog.constants.size(); i++) {
                Value c = prog.constants.get(i);
                if (!c.isSeq() && c.isInt() == v.isInt() && c.isF64() == v.isF64()) {
                    if (v.isInt() && c.asInt() == v.asInt()) return i;
                    if (v.isF64() && Double.doubleToRawLongBits(c.asF64Raw()) == Double.doubleToRawLongBits(v.asF64Raw())) return i;
                }
            }
        } else {
            v.retain();
        }
        prog.constants.add(v);
        return prog.constants.size() - 1;
    }

    private int emit(int ins) {
        RoutineProto r = currentRoutine();
        r.code.add(ins);
        r.lines.add(prev != null ? prev.line : 1);
        r.invalidateFastCache();
        return r.code.size() - 1;
    }

    private int emitAbc(Op op, int a, int b, int c) {
        return emit(Instr.makeAbc(op, a, b, c));
    }

    private int emitAbx(Op op, int a, int bx) {
        return emit(Instr.makeAbx(op, a, bx));
    }

    private int emitAsbx(Op op, int a, int sbx) {
        return emit(Instr.makeAsbx(op, a, sbx));
    }

    private int emitJump(Op op, int a) {
        return emitAsbx(op, a, 0);
    }

    private void patchJump(int offset) {
        patchJumpTo(offset, currentRoutine().code.size());
    }

    private void patchJumpTo(int offset, int target) {
        List<Integer> code = currentRoutine().code;
        int delta = target - (offset + 1);
        if (delta < Short.MIN_VALUE || delta > Short.MAX_VALUE) {
            error("Sprungdistanz zu groß für 16-Bit Offset");
            return;
        }
        code.set(offset, Instr.patchSbx(code.get(offset), delta));
        currentRoutine().invalidateFastCache();
    }

    private int resolveLocal(String name) {
        for (int i = locals.size() - 1; i >= 0; i--) {
            if (locals.get(i).name.equals(name)) return i;
        }
        return -1;
    }

    private int resolveGlobal(String name, String ns) {
        if (ns != null && !ns.isEmpty()) {
            String mappedFile = nsAliases.getOrDefault(ns, "");
            for (int i = prog.globals.size() - 1; i >= 0; i--) {
                GlobalVarInfo g = prog.globals.get(i);
                if (g.name.equals(name) &&
                    (g.ns.equals(ns) ||
                     (!mappedFile.isEmpty() && g.file.equals(mappedFile)) ||
                     "eu".equals(ns))) {
                    return i;
                }
            }
        }
        for (int i = prog.globals.size() - 1; i >= 0; i--) {
            GlobalVarInfo g = prog.globals.get(i);
            if (g.name.equals(name) && g.file.equals(currentFile)) {
                return i;
            }
        }
        Set<String> dirSetG = fileDirectIncludes.get(currentFile);
        if (dirSetG != null) {
            for (int i = prog.globals.size() - 1; i >= 0; i--) {
                GlobalVarInfo g = prog.globals.get(i);
                if (g.name.equals(name) && g.isExported && dirSetG.contains(g.file)) {
                    return i;
                }
            }
        }
        for (int i = prog.globals.size() - 1; i >= 0; i--) {
            GlobalVarInfo g = prog.globals.get(i);
            if (g.name.equals(name) && g.isExported && unaliasedIncludedFiles.contains(g.file)) {
                return i;
            }
        }
        for (int i = prog.globals.size() - 1; i >= 0; i--) {
            GlobalVarInfo g = prog.globals.get(i);
            if (g.name.equals(name) && g.isExported) {
                return i;
            }
        }
        for (int i = prog.globals.size() - 1; i >= 0; i--) {
            GlobalVarInfo g = prog.globals.get(i);
            if (g.name.equals(name)) return i;
        }
        return -1;
    }

    private int resolveGlobal(String name) {
        return resolveGlobal(name, "");
    }

    private int resolveRoutine(String name, String ns) {
        if (ns != null && !ns.isEmpty()) {
            if ("eu".equals(ns)) return -1;
            String mappedFile = nsAliases.getOrDefault(ns, "");
            for (int i = prog.routines.size() - 1; i >= 1; i--) {
                RoutineProto r = prog.routines.get(i);
                if (r.name.equals(name) &&
                    (r.ns.equals(ns) || (!mappedFile.isEmpty() && r.file.equals(mappedFile)))) {
                    return i;
                }
            }
            for (int i = prog.routines.size() - 1; i >= 1; i--) {
                if (prog.routines.get(i).name.equals(name)) return i;
            }
            return -1;
        }

        for (int i = prog.routines.size() - 1; i >= 1; i--) {
            RoutineProto r = prog.routines.get(i);
            if (r.name.equals(name) && r.file.equals(currentFile)) {
                return i;
            }
        }
        for (int i = prog.routines.size() - 1; i >= 1; i--) {
            RoutineProto r = prog.routines.get(i);
            if (r.name.equals(name) && r.isOverride) {
                return i;
            }
        }
        if (BUILTINS.containsKey(name)) {
            return -1;
        }
        Set<String> dirSetR = fileDirectIncludes.get(currentFile);
        if (dirSetR != null) {
            for (int i = prog.routines.size() - 1; i >= 1; i--) {
                RoutineProto r = prog.routines.get(i);
                if (r.name.equals(name) && r.isExported && dirSetR.contains(r.file)) {
                    return i;
                }
            }
        }
        for (int i = prog.routines.size() - 1; i >= 1; i--) {
            RoutineProto r = prog.routines.get(i);
            if (r.name.equals(name) && r.isExported && unaliasedIncludedFiles.contains(r.file)) {
                return i;
            }
        }
        for (int i = prog.routines.size() - 1; i >= 1; i--) {
            RoutineProto r = prog.routines.get(i);
            if (r.name.equals(name) && r.isExported) {
                return i;
            }
        }
        for (int i = prog.routines.size() - 1; i >= 1; i--) {
            if (prog.routines.get(i).name.equals(name)) return i;
        }
        return -1;
    }

    private int resolveRoutine(String name) {
        return resolveRoutine(name, "");
    }

    private int getOrDeclareForwardRoutine(String name, boolean isFunction) {
        for (int i = prog.routines.size() - 1; i >= 1; i--) {
            RoutineProto r = prog.routines.get(i);
            if (r.name.equals(name) && r.file.equals(currentFile)) {
                return i;
            }
        }
        int existing = resolveRoutine(name);
        if (existing >= 0) return existing;

        RoutineProto stub = new RoutineProto();
        stub.name = name;
        stub.ns = currentNs;
        stub.file = currentFile;
        stub.isFunction = isFunction;
        stub.isDefined = false;
        prog.routines.add(stub);
        return prog.routines.size() - 1;
    }

    private BuiltinId resolveBuiltin(String name) {
        return BUILTINS.get(name);
    }

    private int declareLocal(String name, VarType type, boolean isConst, int customType) {
        int r = allocReg();
        locals.add(new LocalVar(name, r, 1, type, customType, isConst, scopeDepth));
        return r;
    }

    private int declareGlobal(String name, VarType type, boolean isConst, int customType) {
        for (int i = prog.globals.size() - 1; i >= 0; i--) {
            GlobalVarInfo g = prog.globals.get(i);
            if (g.name.equals(name) && g.file.equals(currentFile)) {
                g.ns = currentNs;
                g.type = type;
                g.customTypeRoutine = customType;
                g.isConstant = g.isConstant || isConst;
                g.isExported = g.isExported || currentDeclExported;
                return i;
            }
        }
        GlobalVarInfo info = new GlobalVarInfo();
        info.name = name;
        info.ns = currentNs;
        info.file = currentFile;
        info.type = type;
        info.customTypeRoutine = customType;
        info.isConstant = isConst;
        info.isExported = currentDeclExported;
        info.initialValue = Value.NONE;
        prog.globals.add(info);
        return prog.globals.size() - 1;
    }

    private void beginScope() {
        scopeDepth++;
    }

    private void endScope() {
        scopeDepth--;
        while (!locals.isEmpty() && locals.get(locals.size() - 1).depth > scopeDepth) {
            locals.remove(locals.size() - 1);
        }
        if (locals.isEmpty()) {
            nextReg = 0;
        } else {
            LocalVar last = locals.get(locals.size() - 1);
            nextReg = last.reg + last.reservedRegs;
        }
    }

    public boolean compile(Program outProg) {
        this.prog = outProg;
        prog.constants.clear();
        prog.globals.clear();
        prog.routines.clear();

        RoutineProto mainProto = new RoutineProto();
        mainProto.name = "<main>";
        mainProto.file = currentFile;
        mainProto.isFunction = false;
        mainProto.isDefined = true;
        prog.routines.add(mainProto);
        currentRoutineIdx = 0;

        prescanFileRoutines(initialSource, currentFile, currentNs);

        while (!check(TokenType.Eof) && !hadError) {
            parseTopLevel();
        }

        for (int i = 1; i < prog.routines.size(); i++) {
            if (!prog.routines.get(i).isDefined &&
                (prog.routines.get(i).file.equals(currentFile) || includedFiles.contains(prog.routines.get(i).file)) &&
                !hadError) {
                hadError = true;
                errorMsg = "Nicht aufgelöste Routine (Forward-Referenz ohne Definition): '" +
                           prog.routines.get(i).name + "'";
                return false;
            }
        }

        for (PendingGoto pg : pendingGotos) {
            Integer target = labelTargets.get(pg.label);
            if (target == null) {
                error("Goto-Ziel-Label '" + pg.label + "' nicht gefunden");
            } else {
                patchJumpTo(pg.jmpOffset, target);
            }
        }

        emitAbc(Op.Halt, 0, 0, 0);
        return !hadError;
    }

    private void consumeDeclModifiers() {
        currentDeclExported = false;
        currentDeclOverride = false;
        while (match(TokenType.KwGlobal) || match(TokenType.KwPublic) ||
               match(TokenType.KwExport) || match(TokenType.KwOverride) ||
               match(TokenType.KwDeprecate)) {
            if (prev.type == TokenType.KwGlobal || prev.type == TokenType.KwPublic ||
                prev.type == TokenType.KwExport) {
                currentDeclExported = true;
            } else if (prev.type == TokenType.KwOverride) {
                currentDeclExported = true;
                currentDeclOverride = true;
            }
        }
    }

    private void skipWithWithoutDirective() {
        int dirLine = prev.line;
        if (prev.type == TokenType.KwWith && curr.line == dirLine && "define".equals(curr.lexeme)) {
            advance();
            if (curr.line == dirLine && check(TokenType.Identifier)) {
                definedSymbols.add(curr.lexeme);
            }
        }
        while (!check(TokenType.Eof) && curr.line == dirLine) {
            advance();
        }
    }

    private void parseTopLevel() {
        consumeDeclModifiers();

        if (match(TokenType.KwWith) || match(TokenType.KwWithout)) {
            skipWithWithoutDirective();
            return;
        }

        if (match(TokenType.KwNamespace)) {
            consume(TokenType.Identifier, "Erwartet Namespace-Bezeichner nach 'namespace'");
            currentNs = prev.lexeme;
            nsAliases.put(currentNs, currentFile);
            return;
        }

        if (match(TokenType.KwInclude)) {
            parseIncludeDirective();
            return;
        }

        if (match(TokenType.KwIfdef)) {
            parseIfdefStatement();
            return;
        }

        if (match(TokenType.KwProcedure)) {
            parseRoutineDeclaration(false, false);
            return;
        }
        if (match(TokenType.KwFunction)) {
            parseRoutineDeclaration(true, false);
            return;
        }
        if (match(TokenType.KwType)) {
            if (check(TokenType.KwEnum)) {
                parseEnumDeclaration(true);
            } else {
                parseRoutineDeclaration(true, true);
            }
            return;
        }

        parseStatement();
    }

    private void parseStatement() {
        if (match(TokenType.KwGlobal) || match(TokenType.KwPublic) ||
            match(TokenType.KwExport) || match(TokenType.KwOverride) ||
            match(TokenType.KwDeprecate)) {
            if (prev.type == TokenType.KwGlobal || prev.type == TokenType.KwPublic ||
                prev.type == TokenType.KwExport) {
                currentDeclExported = true;
            } else if (prev.type == TokenType.KwOverride) {
                currentDeclExported = true;
                currentDeclOverride = true;
            }
            while (match(TokenType.KwGlobal) || match(TokenType.KwPublic) ||
                   match(TokenType.KwExport) || match(TokenType.KwOverride) ||
                   match(TokenType.KwDeprecate)) {
                if (prev.type == TokenType.KwOverride) currentDeclOverride = true;
                currentDeclExported = true;
            }
        }

        if (match(TokenType.KwWith) || match(TokenType.KwWithout)) {
            skipWithWithoutDirective();
            return;
        }

        if (match(TokenType.KwInclude)) {
            parseIncludeDirective();
            return;
        }
        if (match(TokenType.KwIfdef)) {
            parseIfdefStatement();
            return;
        }

        boolean isGlobal = (currentRoutineIdx == 0 && scopeDepth == 0);
        if (isGlobal) {
            if (match(TokenType.KwProcedure)) { parseRoutineDeclaration(false, false); return; }
            if (match(TokenType.KwFunction))  { parseRoutineDeclaration(true,  false); return; }
            if (match(TokenType.KwType)) {
                if (check(TokenType.KwEnum)) {
                    parseEnumDeclaration(isGlobal);
                } else {
                    parseRoutineDeclaration(true, true);
                }
                return;
            }
        }

        if (check(TokenType.KwAtom) || check(TokenType.KwInteger) ||
            check(TokenType.KwSequence) || check(TokenType.KwObject)) {
            Lexer peekLex = lexer.copy();
            Token lookahead = peekLex.nextToken();
            if (lookahead.type == TokenType.LParen) {
                advance();
                parseIdentStatement();
                return;
            }
        }

        if (match(TokenType.KwObject))   { parseVarDeclaration(VarType.Object,   isGlobal, 0); return; }
        if (match(TokenType.KwAtom))     { parseVarDeclaration(VarType.Atom,     isGlobal, 0); return; }
        if (match(TokenType.KwInteger))  { parseVarDeclaration(VarType.Integer,  isGlobal, 0); return; }
        if (match(TokenType.KwSequence)) { parseVarDeclaration(VarType.Sequence, isGlobal, 0); return; }
        if (match(TokenType.KwConstant)) { parseConstantDeclaration(isGlobal); return; }
        if (match(TokenType.KwEnum))     { parseEnumDeclaration(isGlobal); return; }

        if (match(TokenType.KwIf))       { parseIfStatement(); return; }
        if (match(TokenType.KwWhile))    { parseWhileStatement(); return; }
        if (match(TokenType.KwFor))      { parseForStatement(); return; }
        if (match(TokenType.KwLoop))     { parseLoopUntilStatement(); return; }
        if (match(TokenType.KwSwitch))   { parseSwitchStatement(); return; }
        if (match(TokenType.KwBlock))    { parseBlockStatement(); return; }
        if (match(TokenType.LBrace))     { parseMultiAssignment(); return; }
        if (match(TokenType.KwExit) || match(TokenType.KwContinue) ||
            match(TokenType.KwRetry) || match(TokenType.KwBreak)) {
            parseExitOrContinue(prev.type);
            return;
        }
        if (match(TokenType.KwLabel)) {
            consume(TokenType.StringLiteral, "Erwartet String-Literal nach 'label'");
            labelTargets.put(prev.strVal, currentRoutine().code.size());
            return;
        }
        if (match(TokenType.KwGoto)) {
            parseGotoStatement();
            return;
        }
        if (match(TokenType.KwReturn))   { parseReturnStatement(); return; }

        if (match(TokenType.Question)) {
            int base = nextReg;
            int reg = parseExpr();
            emitAbc(Op.PrintQ, reg, 0, 0);
            freeRegsTo(base);
            return;
        }

        if (match(TokenType.Identifier)) {
            int rIdx = resolveRoutine(prev.lexeme);
            if (rIdx >= 0 && prog.routines.get(rIdx).isType && check(TokenType.Identifier)) {
                parseVarDeclaration(VarType.Object, isGlobal, rIdx);
                return;
            }
            parseIdentStatement();
            return;
        }

        errorAt(curr, "Unerwartetes Token am Anfang einer Anweisung");
        advance();
    }

    private void parseVarDeclaration(VarType type, boolean isGlobal, int customTypeRoutine) {
        do {
            if (check(TokenType.Dollar)) {
                advance();
                break;
            }
            consume(TokenType.Identifier, "Erwartet Variablennamen nach Typ-Deklaration");
            String name = prev.lexeme;

            if (isGlobal) {
                int gidx = declareGlobal(name, type, false, customTypeRoutine);
                if (match(TokenType.Equal)) {
                    int base = nextReg;
                    int r = parseExpr();
                    if (customTypeRoutine > 0) {
                        emitAbx(Op.CheckType, r, customTypeRoutine + 4);
                    }
                    emitAbx(Op.SetGlobal, r, gidx);
                    freeRegsTo(base);
                }
            } else {
                int reg = declareLocal(name, type, false, customTypeRoutine);
                if (match(TokenType.Equal)) {
                    int exprReg = parseExpr();
                    if (exprReg != reg) {
                        emitAbc(Op.Move, reg, exprReg, 0);
                    }
                    if (type != VarType.Object || customTypeRoutine > 0) {
                        emitAbx(Op.CheckType, reg, customTypeRoutine > 0 ? (customTypeRoutine + 4) : type.ordinal());
                    }
                    freeRegsTo(reg + 1);
                }
            }
        } while (match(TokenType.Comma));
    }

    private void parseConstantDeclaration(boolean isGlobal) {
        do {
            if (check(TokenType.Dollar)) {
                advance();
                break;
            }
            consume(TokenType.Identifier, "Erwartet Konstantennamen nach 'constant'");
            String name = prev.lexeme;
            consume(TokenType.Equal, "Erwartet '=' nach Konstantennamen");

            if (isGlobal) {
                int gidx = declareGlobal(name, VarType.Object, false, 0);
                int base = nextReg;
                int r = parseExpr();
                emitAbx(Op.SetGlobal, r, gidx);
                prog.globals.get(gidx).isConstant = true;
                List<Integer> code = currentRoutine().code;
                if (code.size() >= 2) {
                    int last = code.get(code.size() - 2);
                    if (Instr.op(last) == Op.LoadImm && Instr.a(last) == r) {
                        prog.globals.get(gidx).initialValue = Value.fromInt(Instr.sbx(last));
                    } else if (Instr.op(last) == Op.LoadK && Instr.a(last) == r) {
                        prog.globals.get(gidx).initialValue = prog.constants.get(Instr.bx(last));
                    }
                }
                freeRegsTo(base);
            } else {
                int reg = declareLocal(name, VarType.Object, true, 0);
                int exprReg = parseExpr();
                if (exprReg != reg) {
                    emitAbc(Op.Move, reg, exprReg, 0);
                }
                freeRegsTo(reg + 1);
            }
        } while (match(TokenType.Comma));
    }

    private void parseEnumDeclaration(boolean isGlobal) {
        boolean isEnumType = (prev.type == TokenType.KwType);
        String enumTypeName = "";
        if (isEnumType) {
            consume(TokenType.KwEnum, "Erwartet 'enum' nach 'type'");
            consume(TokenType.Identifier, "Erwartet Typnamen nach 'type enum'");
            enumTypeName = prev.lexeme;
        } else if (match(TokenType.KwType)) {
            isEnumType = true;
            consume(TokenType.Identifier, "Erwartet Typnamen nach 'enum type'");
            enumTypeName = prev.lexeme;
        }

        char stepOp = '+';
        double stepVal = 1.0;
        if (match(TokenType.KwBy)) {
            if (match(TokenType.Plus))       stepOp = '+';
            else if (match(TokenType.Minus)) stepOp = '-';
            else if (match(TokenType.Star))  stepOp = '*';
            else if (match(TokenType.Slash)) stepOp = '/';
            if (match(TokenType.IntLiteral)) {
                stepVal = (double) prev.intVal;
            } else if (match(TokenType.FloatLiteral)) {
                stepVal = prev.floatVal;
            } else {
                error("Erwartet Schrittweite nach 'enum by'");
            }
        }
        if (!isEnumType && match(TokenType.KwType)) {
            isEnumType = true;
            consume(TokenType.Identifier, "Erwartet Typnamen nach 'enum by ... type'");
            enumTypeName = prev.lexeme;
        }

        double currentVal = 1.0;
        List<Value> enumVals = new ArrayList<>();
        do {
            if (check(TokenType.Dollar)) {
                advance();
                break;
            }
            if (check(TokenType.KwEnd)) break;

            consume(TokenType.Identifier, "Erwartet Bezeichner in 'enum'");
            String name = prev.lexeme;
            if (match(TokenType.Equal)) {
                class ConstEval {
                    boolean evalPrimary(double[] outP) {
                        boolean neg = match(TokenType.Minus);
                        if (match(TokenType.IntLiteral)) {
                            outP[0] = neg ? -prev.intVal : prev.intVal;
                            return true;
                        }
                        if (match(TokenType.FloatLiteral)) {
                            outP[0] = neg ? -prev.floatVal : prev.floatVal;
                            return true;
                        }
                        if (match(TokenType.Identifier)) {
                            int g = resolveGlobal(prev.lexeme);
                            if (g >= 0 && !prog.globals.get(g).initialValue.isNone()) {
                                double v = prog.globals.get(g).initialValue.asDouble();
                                outP[0] = neg ? -v : v;
                                return true;
                            }
                        }
                        return false;
                    }
                }
                ConstEval ce = new ConstEval();
                double[] accumBox = new double[1];
                boolean constOk = ce.evalPrimary(accumBox);
                if (constOk) {
                    while (check(TokenType.Plus) || check(TokenType.Minus) ||
                           check(TokenType.Star) || check(TokenType.Slash)) {
                        TokenType op = curr.type;
                        advance();
                        double[] rhsBox = new double[1];
                        if (!ce.evalPrimary(rhsBox)) {
                            constOk = false;
                            break;
                        }
                        if (op == TokenType.Plus) accumBox[0] += rhsBox[0];
                        else if (op == TokenType.Minus) accumBox[0] -= rhsBox[0];
                        else if (op == TokenType.Star) accumBox[0] *= rhsBox[0];
                        else if (op == TokenType.Slash && rhsBox[0] != 0.0) accumBox[0] /= rhsBox[0];
                    }
                }
                if (constOk) {
                    currentVal = accumBox[0];
                } else {
                    int base = nextReg;
                    int r = parseExpr();
                    if (isGlobal) {
                        int gidx = declareGlobal(name, VarType.Atom, true, 0);
                        emitAbx(Op.SetGlobal, r, gidx);
                    }
                    freeRegsTo(base);
                    continue;
                }
            }
            Value enumV = (currentVal == Math.floor(currentVal) && !Double.isInfinite(currentVal))
                          ? Value.fromInt((long) currentVal) : Value.fromFloat(currentVal);
            if (isEnumType) {
                enumVals.add(enumV);
            }
            if (isGlobal) {
                int gidx = declareGlobal(name, VarType.Atom, false, 0);
                prog.globals.get(gidx).initialValue = enumV;
                int base = nextReg;
                int r = allocReg();
                if (enumV.isInt() && enumV.asInt() >= Short.MIN_VALUE && enumV.asInt() <= Short.MAX_VALUE) {
                    emitAsbx(Op.LoadImm, r, (int) enumV.asInt());
                } else {
                    int k = addConstant(enumV);
                    emitAbx(Op.LoadK, r, k);
                }
                emitAbx(Op.SetGlobal, r, gidx);
                prog.globals.get(gidx).isConstant = true;
                freeRegsTo(base);
            } else {
                int reg = declareLocal(name, VarType.Atom, true, 0);
                if (enumV.isInt() && enumV.asInt() >= Short.MIN_VALUE && enumV.asInt() <= Short.MAX_VALUE) {
                    emitAsbx(Op.LoadImm, reg, (int) enumV.asInt());
                } else {
                    int k = addConstant(enumV);
                    emitAbx(Op.LoadK, reg, k);
                }
            }

            switch (stepOp) {
                case '+' -> currentVal += stepVal;
                case '-' -> currentVal -= stepVal;
                case '*' -> currentVal *= stepVal;
                case '/' -> { if (stepVal != 0.0) currentVal /= stepVal; }
            }
        } while (match(TokenType.Comma));

        if (isEnumType) {
            consume(TokenType.KwEnd, "Erwartet 'end type' nach 'enum type'");
            consume(TokenType.KwType, "Erwartet 'type' nach 'end'");
            int rIdx = getOrDeclareForwardRoutine(enumTypeName, true);
            RoutineProto rt = prog.routines.get(rIdx);
            rt.isFunction = true;
            rt.isType = true;
            rt.isDefined = true;
            rt.minArity = 1;
            rt.arity = 1;
            rt.maxRegs = 4;
            rt.paramTypes.clear();
            rt.paramTypes.add(VarType.Object);
            rt.paramCustomTypeRoutine.clear();
            rt.paramCustomTypeRoutine.add(0);
            rt.paramDefaults.clear();
            rt.paramDefaults.add(new ParamDefault());
            rt.code.clear();
            rt.lines.clear();
            Sequence seq = new Sequence(enumVals.size());
            for (Value v : enumVals) seq.add(v);
            int k = addConstant(Value.fromSeq(seq));
            rt.code.add(Instr.makeAbc(Op.Move, 2, 0, 0));
            rt.lines.add(prev.line);
            rt.code.add(Instr.makeAbx(Op.LoadK, 3, k));
            rt.lines.add(prev.line);
            rt.code.add(Instr.makeAbc(Op.Builtin, 1, BuiltinId.Find.ordinal(), 2));
            rt.lines.add(prev.line);
            rt.code.add(Instr.makeAbc(Op.Return, 1, 1, 0));
            rt.lines.add(prev.line);
            rt.invalidateFastCache();
        }
    }

    private void parseRoutineDeclaration(boolean isFunction, boolean isType) {
        consume(TokenType.Identifier, "Erwartet Routinennamen");
        String rname = prev.lexeme;

        int existingIdx = -1;
        for (int i = prog.routines.size() - 1; i >= 1; i--) {
            RoutineProto r = prog.routines.get(i);
            if (r.name.equals(rname) && r.file.equals(currentFile) && !r.isDefined) {
                existingIdx = i;
                break;
            }
        }

        int routineIdx;
        if (existingIdx >= 0) {
            routineIdx = existingIdx;
        } else {
            RoutineProto proto = new RoutineProto();
            proto.name = rname;
            routineIdx = prog.routines.size();
            prog.routines.add(proto);
        }

        RoutineProto rt = prog.routines.get(routineIdx);
        rt.name = rname;
        rt.ns = currentNs;
        rt.file = currentFile;
        rt.isFunction = isFunction;
        rt.isType = isType;
        rt.isDefined = true;
        rt.isExported = rt.isExported || currentDeclExported;
        rt.isOverride = rt.isOverride || currentDeclOverride;
        rt.minArity = 0;
        rt.arity = 0;
        rt.paramTypes.clear();
        rt.paramCustomTypeRoutine.clear();
        rt.paramDefaults.clear();
        rt.code.clear();
        rt.lines.clear();
        rt.invalidateFastCache();

        int savedRoutine = currentRoutineIdx;
        List<LocalVar> savedLocals = locals;
        int savedDepth = scopeDepth;
        int savedNext = nextReg;
        int savedMax = maxReg;
        List<LoopContext> savedLoops = loops;
        Map<String, Integer> savedLabels = labelTargets;
        List<PendingGoto> savedGotos = pendingGotos;

        currentRoutineIdx = routineIdx;
        locals = new ArrayList<>();
        scopeDepth = 1;
        nextReg = 0;
        maxReg = 0;
        loops = new ArrayList<>();
        labelTargets = new HashMap<>();
        pendingGotos = new ArrayList<>();

        List<SavedDefaultExpr> savedDefaults = new ArrayList<>();

        consume(TokenType.LParen, "Erwartet '(' nach Routinennamen");
        if (!check(TokenType.RParen)) {
            boolean seenDefault = false;
            do {
                if (check(TokenType.Dollar)) {
                    advance();
                    break;
                }
                VarType ptype = VarType.Object;
                int customT = 0;
                if (match(TokenType.KwObject))        ptype = VarType.Object;
                else if (match(TokenType.KwAtom))     ptype = VarType.Atom;
                else if (match(TokenType.KwInteger))  ptype = VarType.Integer;
                else if (match(TokenType.KwSequence)) ptype = VarType.Sequence;
                else if (check(TokenType.Identifier)) {
                    advance();
                    String tname = prev.lexeme;
                    String tns = "";
                    if (match(TokenType.Colon)) {
                        tns = tname;
                        if (match(TokenType.Identifier) || match(TokenType.KwObject) ||
                            match(TokenType.KwAtom) || match(TokenType.KwInteger) ||
                            match(TokenType.KwSequence)) {
                            tname = prev.lexeme;
                        }
                    }
                    int tid = resolveRoutine(tname, tns);
                    if (tid >= 0 && prog.routines.get(tid).isType) {
                        customT = tid;
                    }
                    ptype = VarType.Object;
                } else {
                    errorAt(curr, "Erwartet Parametertyp (integer, atom, sequence, object)");
                }

                consume(TokenType.Identifier, "Erwartet Parameternamen");
                int preg = declareLocal(prev.lexeme, ptype, false, customT);

                ParamDefault pdef = new ParamDefault();
                if (match(TokenType.Equal)) {
                    seenDefault = true;
                    pdef.hasDefault = true;
                    savedDefaults.add(new SavedDefaultExpr(preg, lexer, curr));

                    int pdepth = 0;
                    while (!check(TokenType.Eof)) {
                        if (check(TokenType.LParen) || check(TokenType.LBrace) || check(TokenType.LBracket)) {
                            pdepth++;
                            advance();
                        } else if (check(TokenType.RParen) || check(TokenType.RBrace) || check(TokenType.RBracket)) {
                            if (pdepth == 0) break;
                            pdepth--;
                            advance();
                        } else if (pdepth == 0 && check(TokenType.Comma)) {
                            break;
                        } else {
                            advance();
                        }
                    }
                }

                currentRoutine().paramTypes.add(ptype);
                currentRoutine().paramCustomTypeRoutine.add(customT);
                currentRoutine().paramDefaults.add(pdef);
                if (!seenDefault) {
                    currentRoutine().minArity++;
                }
                currentRoutine().arity++;
            } while (match(TokenType.Comma));
        }
        consume(TokenType.RParen, "Erwartet ')' nach Parameterliste");

        if (!savedDefaults.isEmpty()) {
            Lexer bodyLexer = lexer.copyState();
            Token bodyCurr = curr;
            Token bodyPrev = prev;
            List<IncludeFrame> savedIncStack = includeStack;
            includeStack = new ArrayList<>();

            for (SavedDefaultExpr sdef : savedDefaults) {
                lexer = sdef.lexer.copyState();
                curr = sdef.curr;
                int skipJmp = emitJump(Op.JmpIfNotNone, sdef.paramReg);
                int base = nextReg;
                int valReg = parseExpr();
                if (valReg != sdef.paramReg) {
                    emitAbc(Op.Move, sdef.paramReg, valReg, 0);
                }
                freeRegsTo(base);
                patchJump(skipJmp);
            }

            includeStack = savedIncStack;
            lexer = bodyLexer;
            curr = bodyCurr;
            prev = bodyPrev;
        }

        for (int i = 0; i < currentRoutine().arity; i++) {
            VarType pt = currentRoutine().paramTypes.get(i);
            int ct = currentRoutine().paramCustomTypeRoutine.get(i);
            if (pt != VarType.Object || ct > 0) {
                emitAbx(Op.CheckType, i, ct > 0 ? (ct + 4) : pt.ordinal());
            }
        }

        while (!check(TokenType.KwEnd) && !check(TokenType.Eof) && !hadError) {
            parseStatement();
        }

        consume(TokenType.KwEnd, "Erwartet 'end' am Ende der Routine");
        if (isType) {
            consume(TokenType.KwType, "Erwartet 'type' nach 'end'");
        } else if (isFunction) {
            consume(TokenType.KwFunction, "Erwartet 'function' nach 'end'");
        } else {
            consume(TokenType.KwProcedure, "Erwartet 'procedure' nach 'end'");
        }

        for (PendingGoto pg : pendingGotos) {
            Integer target = labelTargets.get(pg.label);
            if (target == null) {
                error("Goto-Ziel-Label '" + pg.label + "' nicht in Routine gefunden");
            } else {
                patchJumpTo(pg.jmpOffset, target);
            }
        }

        emitAbc(Op.Return, 0, 0, 0);

        currentRoutineIdx = savedRoutine;
        locals = savedLocals;
        scopeDepth = savedDepth;
        nextReg = savedNext;
        maxReg = savedMax;
        loops = savedLoops;
        labelTargets = savedLabels;
        pendingGotos = savedGotos;
    }

    private void parseIfStatement() {
        List<Integer> endJumps = new ArrayList<>();

        int base = nextReg;
        int condReg = parseCondition();

        String label = "";
        if (match(TokenType.KwLabel)) {
            consume(TokenType.StringLiteral, "Erwartet String-Literal nach 'label'");
            label = prev.strVal;
        }
        consume(TokenType.KwThen, "Erwartet 'then' nach 'if'-Bedingung");
        if (match(TokenType.KwLabel)) {
            consume(TokenType.StringLiteral, "Erwartet String-Literal nach 'label'");
            label = prev.strVal;
        }

        loops.add(new LoopContext(label, false, true, scopeDepth, 0, 0));

        int falseJmp = emitJump(Op.JmpFalse, condReg);
        freeRegsTo(base);

        beginScope();
        while (!check(TokenType.KwElsif) && !check(TokenType.KwElse) &&
               !check(TokenType.KwEnd) && !check(TokenType.Eof) && !hadError) {
            parseStatement();
        }
        endScope();

        while (match(TokenType.KwElsif)) {
            endJumps.add(emitJump(Op.Jmp, 0));
            patchJump(falseJmp);

            int ebase = nextReg;
            int econd = parseCondition();
            consume(TokenType.KwThen, "Erwartet 'then' nach 'elsif'-Bedingung");
            falseJmp = emitJump(Op.JmpFalse, econd);
            freeRegsTo(ebase);

            beginScope();
            while (!check(TokenType.KwElsif) && !check(TokenType.KwElse) &&
                   !check(TokenType.KwEnd) && !check(TokenType.Eof) && !hadError) {
                parseStatement();
            }
            endScope();
        }

        if (match(TokenType.KwElse)) {
            endJumps.add(emitJump(Op.Jmp, 0));
            patchJump(falseJmp);

            beginScope();
            while (!check(TokenType.KwEnd) && !check(TokenType.Eof) && !hadError) {
                parseStatement();
            }
            endScope();
        } else {
            patchJump(falseJmp);
        }

        LoopContext ctx = loops.remove(loops.size() - 1);

        consume(TokenType.KwEnd, "Erwartet 'end' nach 'if'-Block");
        consume(TokenType.KwIf, "Erwartet 'if' nach 'end'");

        for (int jmp : endJumps) {
            patchJump(jmp);
        }
        for (int jmp : ctx.exitJumps) {
            patchJump(jmp);
        }
    }

    private void parseWhileStatement() {
        boolean hasWithEntry = false;
        String label = "";

        if (match(TokenType.KwWith)) {
            consume(TokenType.KwEntry, "Erwartet 'entry' nach 'with' in 'while'");
            hasWithEntry = true;
        } else if (match(TokenType.KwEntry)) {
            hasWithEntry = true;
        }

        int entryJmp = emitJump(Op.Jmp, 0);
        int loopStart = currentRoutine().code.size();

        int base = nextReg;
        int condReg = parseCondition();

        while (match(TokenType.KwWith) || match(TokenType.KwEntry) || match(TokenType.KwLabel)) {
            if (prev.type == TokenType.KwWith) {
                consume(TokenType.KwEntry, "Erwartet 'entry' nach 'with'");
                hasWithEntry = true;
            } else if (prev.type == TokenType.KwEntry) {
                hasWithEntry = true;
            } else {
                consume(TokenType.StringLiteral, "Erwartet String-Literal nach 'label'");
                label = prev.strVal;
            }
        }
        consume(TokenType.KwDo, "Erwartet 'do' nach 'while'-Bedingung");
        if (match(TokenType.KwLabel)) {
            consume(TokenType.StringLiteral, "Erwartet String-Literal nach 'label'");
            label = prev.strVal;
        }

        if (!hasWithEntry) {
            patchJumpTo(entryJmp, loopStart);
        }

        int exitJmp = emitJump(Op.JmpFalse, condReg);
        freeRegsTo(base);

        int bodyStart = currentRoutine().code.size();
        beginScope();
        loops.add(new LoopContext(label, false, false, scopeDepth, loopStart, bodyStart));

        boolean patchedEntry = !hasWithEntry;
        while (!check(TokenType.KwEnd) && !check(TokenType.Eof) && !hadError) {
            if (match(TokenType.KwEntry)) {
                if (!patchedEntry) {
                    patchJump(entryJmp);
                    patchedEntry = true;
                }
                continue;
            }
            parseStatement();
        }
        if (!patchedEntry) {
            patchJumpTo(entryJmp, loopStart);
        }

        LoopContext ctx = loops.remove(loops.size() - 1);
        endScope();

        consume(TokenType.KwEnd, "Erwartet 'end' nach 'while'-Schleife");
        consume(TokenType.KwWhile, "Erwartet 'while' nach 'end'");

        int backJmp = emitJump(Op.Jmp, 0);
        patchJumpTo(backJmp, loopStart);
        patchJump(exitJmp);

        for (int jmp : ctx.exitJumps) {
            patchJump(jmp);
        }
        for (int jmp : ctx.continueJumps) {
            patchJumpTo(jmp, loopStart);
        }
        for (int jmp : ctx.retryJumps) {
            patchJumpTo(jmp, bodyStart);
        }
    }

    private void parseForStatement() {
        consume(TokenType.Identifier, "Erwartet Laufvariable nach 'for'");
        String varName = prev.lexeme;
        consume(TokenType.Equal, "Erwartet '=' nach Laufvariable in 'for'");

        beginScope();
        int loopReg = declareLocal(varName, VarType.Atom, false, 0);
        locals.get(locals.size() - 1).reservedRegs = 3;
        int limitReg = allocReg();
        int stepReg = allocReg();

        int startVal = parseExpr();
        if (startVal != loopReg) {
            emitAbc(Op.Move, loopReg, startVal, 0);
        }
        freeRegsTo(stepReg + 1);

        consume(TokenType.KwTo, "Erwartet 'to' in 'for'-Schleife");
        int limVal = parseExpr();
        if (limVal != limitReg) {
            emitAbc(Op.Move, limitReg, limVal, 0);
        }
        freeRegsTo(stepReg + 1);

        if (match(TokenType.KwBy)) {
            int stVal = parseExpr();
            if (stVal != stepReg) {
                emitAbc(Op.Move, stepReg, stVal, 0);
            }
            freeRegsTo(stepReg + 1);
        } else {
            emitAsbx(Op.LoadImm, stepReg, 1);
        }

        String label = "";
        if (match(TokenType.KwLabel)) {
            consume(TokenType.StringLiteral, "Erwartet String-Literal nach 'label'");
            label = prev.strVal;
        }
        consume(TokenType.KwDo, "Erwartet 'do' in 'for'-Schleife");
        if (match(TokenType.KwLabel)) {
            consume(TokenType.StringLiteral, "Erwartet String-Literal nach 'label'");
            label = prev.strVal;
        }

        int prepJmp = emitJump(Op.ForPrep, loopReg);
        int bodyStart = currentRoutine().code.size();

        loops.add(new LoopContext(label, true, false, scopeDepth, 0, bodyStart));

        while (!check(TokenType.KwEnd) && !check(TokenType.Eof) && !hadError) {
            parseStatement();
        }

        LoopContext ctx = loops.remove(loops.size() - 1);

        consume(TokenType.KwEnd, "Erwartet 'end' nach 'for'-Schleife");
        consume(TokenType.KwFor, "Erwartet 'for' nach 'end'");

        int stepPos = currentRoutine().code.size();
        int loopJmp = emitJump(Op.ForLoop, loopReg);
        patchJumpTo(loopJmp, bodyStart);
        patchJump(prepJmp);

        for (int jmp : ctx.continueJumps) {
            patchJumpTo(jmp, stepPos);
        }
        for (int jmp : ctx.retryJumps) {
            patchJumpTo(jmp, bodyStart);
        }
        for (int jmp : ctx.exitJumps) {
            patchJump(jmp);
        }

        endScope();
    }

    private void parseLoopUntilStatement() {
        String label = "";
        boolean hasEntry = false;
        while (match(TokenType.KwWith) || match(TokenType.KwEntry) || match(TokenType.KwLabel)) {
            if (prev.type == TokenType.KwWith) {
                match(TokenType.KwEntry);
                hasEntry = true;
            } else if (prev.type == TokenType.KwEntry) {
                hasEntry = true;
            } else {
                consume(TokenType.StringLiteral, "Erwartet String-Literal nach 'label'");
                label = prev.strVal;
            }
        }
        consume(TokenType.KwDo, "Erwartet 'do' nach 'loop'");
        if (match(TokenType.KwLabel)) {
            consume(TokenType.StringLiteral, "Erwartet String-Literal nach 'label'");
            label = prev.strVal;
        }

        int entryJmp = -1;
        if (hasEntry) {
            entryJmp = emitJump(Op.Jmp, 0);
        }

        int bodyStart = currentRoutine().code.size();
        beginScope();
        loops.add(new LoopContext(label, false, false, scopeDepth, 0, bodyStart));

        int entryPos = -1;
        while (!check(TokenType.KwUntil) && !check(TokenType.KwEnd) && !check(TokenType.Eof) && !hadError) {
            if (match(TokenType.KwEntry)) {
                entryPos = currentRoutine().code.size();
                continue;
            }
            parseStatement();
        }

        if (hasEntry && entryJmp >= 0) {
            patchJumpTo(entryJmp, (entryPos >= 0) ? entryPos : bodyStart);
        }

        int condReg = -1;
        int condPos = currentRoutine().code.size();
        if (match(TokenType.KwUntil)) {
            condPos = currentRoutine().code.size();
            int base = nextReg;
            condReg = parseCondition();
            freeRegsTo(base);
        }

        consume(TokenType.KwEnd, "Erwartet 'end loop'");
        consume(TokenType.KwLoop, "Erwartet 'loop' nach 'end'");

        LoopContext ctx = loops.remove(loops.size() - 1);
        endScope();

        if (condReg >= 0) {
            int backJmp = emitJump(Op.JmpFalse, condReg);
            patchJumpTo(backJmp, bodyStart);
        } else {
            int backJmp = emitJump(Op.Jmp, 0);
            patchJumpTo(backJmp, bodyStart);
        }

        for (int jmp : ctx.continueJumps) {
            patchJumpTo(jmp, condPos);
        }
        for (int jmp : ctx.retryJumps) {
            patchJumpTo(jmp, bodyStart);
        }
        for (int jmp : ctx.exitJumps) {
            patchJump(jmp);
        }
    }

    private void parseBlockStatement() {
        beginScope();
        while (!check(TokenType.Eof) && !check(TokenType.KwEnd)) {
            parseStatement();
        }
        consume(TokenType.KwEnd, "Erwartet 'end block'");
        consume(TokenType.KwBlock, "Erwartet 'block' nach 'end'");
        endScope();
    }

    private void parseMultiAssignment() {
        List<String> targetVars = new ArrayList<>();
        List<Integer> skipIndices = new ArrayList<>();
        int elemIdx = 1;
        do {
            if (match(TokenType.Question)) {
                skipIndices.add(elemIdx);
                targetVars.add("");
            } else {
                consume(TokenType.Identifier, "Erwartet Variablenname in Mehrfachzuweisung");
                targetVars.add(prev.lexeme);
            }
            elemIdx++;
        } while (match(TokenType.Comma));
        consume(TokenType.RBrace, "Erwartet '}' nach Mehrfachzuweisung");
        consume(TokenType.Equal, "Erwartet '=' nach '{...}'");

        int rhsReg = parseExpr();
        for (int i = 0; i < targetVars.size(); ++i) {
            if (targetVars.get(i).isEmpty()) continue;
            String vname = targetVars.get(i);
            int idxVal = i + 1;
            int idxReg = allocReg();
            emitAsbx(Op.LoadImm, idxReg, (short)idxVal);
            int elemReg = allocReg();
            emitAbc(Op.GetIdx, elemReg, rhsReg, idxReg);

            int loc = resolveLocal(vname);
            if (loc >= 0) {
                emitAbc(Op.Move, locals.get(loc).reg, elemReg, 0);
            } else {
                int glob = resolveGlobal(vname);
                if (glob >= 0) {
                    emitAbx(Op.SetGlobal, elemReg, glob);
                } else {
                    error("Unbekannte Variable '" + vname + "' in Mehrfachzuweisung");
                }
            }
        }
    }

    private void parseSwitchStatement() {
        int exprReg = parseExpr();
        beginScope();
        int switchReg = declareLocal("", VarType.Object, true, 0);
        if (exprReg != switchReg) {
            emitAbc(Op.Move, switchReg, exprReg, 0);
        }

        boolean defaultFallthru = false;
        String label = "";
        while (match(TokenType.KwWith) || match(TokenType.KwWithout) || match(TokenType.KwLabel)) {
            if (prev.type == TokenType.KwWith) {
                consume(TokenType.KwFallthru, "Erwartet 'fallthru' nach 'with'");
                defaultFallthru = true;
            } else if (prev.type == TokenType.KwWithout) {
                consume(TokenType.KwFallthru, "Erwartet 'fallthru' nach 'without'");
                defaultFallthru = false;
            } else {
                consume(TokenType.StringLiteral, "Erwartet String-Literal nach 'label'");
                label = prev.strVal;
            }
        }
        consume(TokenType.KwDo, "Erwartet 'do' in 'switch'-Anweisung");
        if (match(TokenType.KwLabel)) {
            consume(TokenType.StringLiteral, "Erwartet String-Literal nach 'label'");
            label = prev.strVal;
        }

        loops.add(new LoopContext(label, false, true, scopeDepth, 0, 0));
        List<Integer> nextCaseJumps = new ArrayList<>();
        List<Integer> fallthruJumps = new ArrayList<>();

        while (check(TokenType.KwCase) || check(TokenType.KwIfdef) ||
               check(TokenType.KwElsifdef) || check(TokenType.KwElsedef) ||
               (check(TokenType.KwEnd) && lexer.copy().nextToken().type == TokenType.KwIfdef)) {
            if (match(TokenType.KwIfdef)) {
                boolean cond = evalIfdefCondition();
                if (!cond) {
                    skipIfdefBranch();
                }
                continue;
            }
            if (match(TokenType.KwElsifdef) || match(TokenType.KwElsedef)) {
                skipIfdefBranch();
                continue;
            }
            if (check(TokenType.KwEnd) && lexer.copy().nextToken().type == TokenType.KwIfdef) {
                advance();
                advance();
                continue;
            }
            advance(); // consume KwCase
            for (int jmp : nextCaseJumps) {
                patchJump(jmp);
            }
            nextCaseJumps.clear();

            if (match(TokenType.KwElse)) {
                match(TokenType.KwThen);
                for (int fjmp : fallthruJumps) {
                    patchJump(fjmp);
                }
                fallthruJumps.clear();

                beginScope();
                while (!check(TokenType.KwCase) && !check(TokenType.KwEnd) && !check(TokenType.Eof) && !hadError) {
                    parseStatement();
                }
                endScope();
                break;
            }

            List<Integer> bodyJumps = new ArrayList<>();
            do {
                int cbase = nextReg;
                int valReg = parseExpr();
                int cmpReg = allocReg();
                emitAbc(Op.EqualObj, cmpReg, switchReg, valReg);
                bodyJumps.add(emitJump(Op.JmpTrue, cmpReg));
                freeRegsTo(cbase);
            } while (match(TokenType.Comma));

            consume(TokenType.KwThen, "Erwartet 'then' nach 'case'-Werten");
            nextCaseJumps.add(emitJump(Op.Jmp, 0));

            for (int bjmp : bodyJumps) {
                patchJump(bjmp);
            }
            for (int fjmp : fallthruJumps) {
                patchJump(fjmp);
            }
            fallthruJumps.clear();

            boolean caseHasFallthru = defaultFallthru;
            beginScope();
            while (!check(TokenType.KwCase) && !check(TokenType.KwEnd) && !check(TokenType.Eof) && !hadError) {
                if (check(TokenType.KwIfdef) || check(TokenType.KwElsifdef) || check(TokenType.KwElsedef)) {
                    break;
                }
                if (match(TokenType.KwFallthru)) {
                    caseHasFallthru = true;
                    continue;
                }
                parseStatement();
            }
            endScope();

            if (caseHasFallthru) {
                fallthruJumps.add(emitJump(Op.Jmp, 0));
            } else {
                loops.get(loops.size() - 1).exitJumps.add(emitJump(Op.Jmp, 0));
            }
        }

        for (int jmp : nextCaseJumps) {
            patchJump(jmp);
        }
        for (int fjmp : fallthruJumps) {
            patchJump(fjmp);
        }

        LoopContext ctx = loops.remove(loops.size() - 1);

        consume(TokenType.KwEnd, "Erwartet 'end' nach 'switch'");
        consume(TokenType.KwSwitch, "Erwartet 'switch' nach 'end'");

        for (int jmp : ctx.exitJumps) {
            patchJump(jmp);
        }
        endScope();
    }

    private void parseExitOrContinue(TokenType kind) {
        if (loops.isEmpty()) {
            error("Sprunganweisung außerhalb einer Schleife oder eines Blocks");
            return;
        }

        int targetIdx = -1;
        boolean hasDepth = false;
        long depth = 0;

        if (match(TokenType.StringLiteral)) {
            String targetLabel = prev.strVal;
            for (int i = loops.size() - 1; i >= 0; i--) {
                if (targetLabel.equals(loops.get(i).label)) {
                    targetIdx = i;
                    break;
                }
            }
            if (targetIdx < 0) {
                error("Block-/Schleifen-Label '" + targetLabel + "' nicht gefunden");
                return;
            }
        } else {
            if (match(TokenType.Minus)) {
                consume(TokenType.IntLiteral, "Erwartet Zahl nach '-'");
                hasDepth = true;
                depth = -prev.intVal;
            } else if (match(TokenType.IntLiteral)) {
                hasDepth = true;
                depth = prev.intVal;
            }

            List<Integer> candidates = new ArrayList<>();
            for (int i = 0; i < loops.size(); i++) {
                if (kind == TokenType.KwBreak) {
                    if (loops.get(i).isSwitchOrIf) candidates.add(i);
                } else {
                    if (!loops.get(i).isSwitchOrIf) candidates.add(i);
                }
            }
            if (candidates.isEmpty()) {
                candidates.add(loops.size() - 1);
            }

            if (hasDepth) {
                if (depth == 0) {
                    targetIdx = candidates.get(0);
                } else if (depth > 0) {
                    int idx = candidates.size() - (int)depth;
                    if (idx < 0) idx = 0;
                    targetIdx = candidates.get(idx);
                } else {
                    int idx = candidates.size() - 1 + (int)depth;
                    if (idx < 0) idx = 0;
                    targetIdx = candidates.get(idx);
                }
            } else {
                targetIdx = candidates.get(candidates.size() - 1);
            }
        }

        int jmp = emitJump(Op.Jmp, 0);
        if (kind == TokenType.KwExit || kind == TokenType.KwBreak) {
            loops.get(targetIdx).exitJumps.add(jmp);
        } else if (kind == TokenType.KwContinue) {
            loops.get(targetIdx).continueJumps.add(jmp);
        } else if (kind == TokenType.KwRetry) {
            loops.get(targetIdx).retryJumps.add(jmp);
        }
    }

    private void parseGotoStatement() {
        consume(TokenType.StringLiteral, "Erwartet Label-String nach 'goto'");
        String targetLbl = prev.strVal;
        int jmp = emitJump(Op.Jmp, 0);
        pendingGotos.add(new PendingGoto(targetLbl, jmp));
    }

    private void parseReturnStatement() {
        if (currentRoutineIdx == 0) {
            emitAbc(Op.Halt, 0, 0, 0);
            return;
        }
        if (currentRoutine().isFunction) {
            int base = nextReg;
            int r = parseExpr();
            emitAbc(Op.Return, r, 1, 0);
            freeRegsTo(base);
        } else {
            emitAbc(Op.Return, 0, 0, 0);
        }
    }

    private void emitRoutineCall(int rIdx, int dest, List<Integer> argRegs, List<Boolean> omitted) {
        RoutineProto rt = prog.routines.get(rIdx);
        int totalArgs = argRegs.size();
        if (rt.arity > totalArgs) {
            totalArgs = rt.arity;
        }

        for (int i = 0; i < totalArgs; i++) {
            int targetArgReg = allocReg();
            boolean isOmitted = (i >= argRegs.size()) || (i < omitted.size() && omitted.get(i));
            if (!isOmitted) {
                if (argRegs.get(i) != targetArgReg) {
                    emitAbc(Op.Move, targetArgReg, argRegs.get(i), 0);
                }
            } else {
                emitAbc(Op.LoadNone, targetArgReg, 0, 0);
            }
        }

        emitAbx(Op.Call, dest, rIdx);
    }

    private static Op compoundTokenToOp(TokenType t) {
        return switch (t) {
            case PlusEq  -> Op.Add;
            case MinusEq -> Op.Sub;
            case StarEq  -> Op.Mul;
            case SlashEq -> Op.Div;
            case AmpEq   -> Op.Concat;
            default      -> Op.Add;
        };
    }

    private void parseIdentStatement() {
        String name = prev.lexeme;
        String ns = "";

        if (match(TokenType.Colon)) {
            ns = name;
            if (match(TokenType.Identifier) || match(TokenType.KwObject) ||
                match(TokenType.KwAtom) || match(TokenType.KwInteger) || match(TokenType.KwSequence)) {
                name = prev.lexeme;
            } else {
                errorAt(curr, "Erwartet Bezeichner nach Namespace ':'");
            }
        }

        if (check(TokenType.Identifier)) {
            int rType = resolveRoutine(name, ns);
            if (rType >= 0 && prog.routines.get(rType).isType) {
                boolean isGlobal = (currentRoutineIdx == 0 && scopeDepth == 0);
                parseVarDeclaration(VarType.Object, isGlobal, rType);
                return;
            }
        }

        if (match(TokenType.LParen)) {
            int base = nextReg;
            List<Integer> argRegs = new ArrayList<>();
            List<Boolean> omitted = new ArrayList<>();
            if (!check(TokenType.RParen)) {
                do {
                    if (check(TokenType.Comma) || check(TokenType.RParen)) {
                        int slot = allocReg();
                        emitAbc(Op.LoadNone, slot, 0, 0);
                        argRegs.add(slot);
                        omitted.add(true);
                    } else if (match(TokenType.Question)) {
                        int slot = allocReg();
                        emitAbc(Op.LoadNone, slot, 0, 0);
                        argRegs.add(slot);
                        omitted.add(true);
                    } else {
                        int r = parseExpr();
                        int slot = allocReg();
                        if (r != slot) {
                            emitAbc(Op.Move, slot, r, 0);
                        }
                        argRegs.add(slot);
                        omitted.add(false);
                    }
                } while (match(TokenType.Comma));
            }
            consume(TokenType.RParen, "Erwartet ')' nach Argumentliste");

            int dest = allocReg();
            int argc = argRegs.size();

            int rIdx = "eu".equals(ns) ? -1 : resolveRoutine(name, ns);
            BuiltinId bid = resolveBuiltin(name);
            if (rIdx >= 0) {
                emitRoutineCall(rIdx, dest, argRegs, omitted);
            } else if (bid != null) {
                for (int i = 0; i < argc; i++) {
                    int targetArgReg = allocReg();
                    if (omitted.get(i)) {
                        emitAbc(Op.LoadNone, targetArgReg, 0, 0);
                    } else if (argRegs.get(i) != targetArgReg) {
                        emitAbc(Op.Move, targetArgReg, argRegs.get(i), 0);
                    }
                }
                emitAbc(Op.Builtin, dest, bid.ordinal(), argc);
            } else {
                int fwdIdx = getOrDeclareForwardRoutine(name, false);
                emitRoutineCall(fwdIdx, dest, argRegs, omitted);
            }
            freeRegsTo(base);
            return;
        }

        int localIdx = ns.isEmpty() ? resolveLocal(name) : -1;
        int globalIdx = (localIdx < 0) ? resolveGlobal(name, ns) : -1;
        if (localIdx < 0 && globalIdx < 0) {
            error("Nicht deklarierte Variable: '" + name + "'");
            return;
        }

        if ((localIdx >= 0 && locals.get(localIdx).isConstant) ||
            (globalIdx >= 0 && prog.globals.get(globalIdx).isConstant)) {
            error("Konstante '" + name + "' kann nicht verändert werden");
            return;
        }

        int base = nextReg;
        int targetReg = (localIdx >= 0) ? locals.get(localIdx).reg : allocReg();

        if (match(TokenType.LBracket)) {
            List<AccessStep> chain = new ArrayList<>();

            if (globalIdx >= 0) {
                emitAbx(Op.GetGlobal, targetReg, globalIdx);
            }
            int curSeq = targetReg;
            for (;;) {
                dollarSeqStack.add(curSeq);
                int idx1 = allocReg();
                int e1 = parseExpr();
                if (e1 != idx1) emitAbc(Op.Move, idx1, e1, 0);
                freeRegsTo(idx1 + 1);

                boolean isSlice = false;
                if (match(TokenType.DotDot)) {
                    isSlice = true;
                    int idx2 = allocReg();
                    int e2 = parseExpr();
                    if (e2 != idx2) emitAbc(Op.Move, idx2, e2, 0);
                    freeRegsTo(idx2 + 1);
                }
                dollarSeqStack.remove(dollarSeqStack.size() - 1);
                consume(TokenType.RBracket, "Erwartet ']' nach Index oder Slice");

                chain.add(new AccessStep(isSlice, curSeq, idx1));

                if (match(TokenType.LBracket)) {
                    int nextSeq = allocReg();
                    if (isSlice) {
                        emitAbc(Op.GetSlice, nextSeq, curSeq, idx1);
                    } else {
                        emitAbc(Op.GetIdx, nextSeq, curSeq, idx1);
                    }
                    curSeq = nextSeq;
                } else {
                    break;
                }
            }

            TokenType assignTok = curr.type;
            if (match(TokenType.Equal) || match(TokenType.PlusEq) || match(TokenType.MinusEq) ||
                match(TokenType.StarEq) || match(TokenType.SlashEq) || match(TokenType.AmpEq)) {

                int rhsReg = parseExpr();
                AccessStep last = chain.get(chain.size() - 1);

                if (assignTok != TokenType.Equal) {
                    int oldVal = allocReg();
                    if (last.isSlice) {
                        emitAbc(Op.GetSlice, oldVal, last.seqReg, last.idxReg);
                    } else {
                        emitAbc(Op.GetIdx, oldVal, last.seqReg, last.idxReg);
                    }
                    emitAbc(compoundTokenToOp(assignTok), oldVal, oldVal, rhsReg);
                    rhsReg = oldVal;
                }

                if (globalIdx >= 0) {
                    emitAbx(Op.TakeGlobal, targetReg, globalIdx);
                }

                if (last.isSlice) {
                    emitAbc(Op.SetSlice, last.seqReg, last.idxReg, rhsReg);
                } else {
                    emitAbc(Op.SetIdx, last.seqReg, last.idxReg, rhsReg);
                }

                for (int i = chain.size() - 2; i >= 0; i--) {
                    AccessStep step = chain.get(i);
                    int modifiedChild = chain.get(i + 1).seqReg;
                    if (step.isSlice) {
                        emitAbc(Op.SetSlice, step.seqReg, step.idxReg, modifiedChild);
                    } else {
                        emitAbc(Op.SetIdx, step.seqReg, step.idxReg, modifiedChild);
                    }
                }

                if (globalIdx >= 0) {
                    emitAbx(Op.SetGlobal, targetReg, globalIdx);
                }
                freeRegsTo(base);
                return;
            }
            errorAt(curr, "Erwartet Zuweisungsoperator ('=', '+=', etc.) nach Sequenz-Index");
            freeRegsTo(base);
            return;
        }

        TokenType assignTok = curr.type;
        if (match(TokenType.Equal) || match(TokenType.PlusEq) || match(TokenType.MinusEq) ||
            match(TokenType.StarEq) || match(TokenType.SlashEq) || match(TokenType.AmpEq)) {

            int rhs = parseExpr();
            if (assignTok == TokenType.Equal) {
                if (localIdx >= 0) {
                    if (rhs != targetReg) {
                        emitAbc(Op.Move, targetReg, rhs, 0);
                    }
                    VarType vt = locals.get(localIdx).type;
                    int ct = locals.get(localIdx).customTypeRoutine;
                    if (vt != VarType.Object || ct > 0) {
                        emitAbx(Op.CheckType, targetReg, ct > 0 ? (ct + 4) : vt.ordinal());
                    }
                } else {
                    int ct = prog.globals.get(globalIdx).customTypeRoutine;
                    if (ct > 0) {
                        emitAbx(Op.CheckType, rhs, ct + 4);
                    }
                    emitAbx(Op.SetGlobal, rhs, globalIdx);
                }
            } else {
                if (globalIdx >= 0) {
                    emitAbx(Op.GetGlobal, targetReg, globalIdx);
                }
                Op bop = compoundTokenToOp(assignTok);
                emitAbc(bop, targetReg, targetReg, rhs);
                if (localIdx >= 0) {
                    VarType vt = locals.get(localIdx).type;
                    int ct = locals.get(localIdx).customTypeRoutine;
                    if (vt != VarType.Object || ct > 0) {
                        emitAbx(Op.CheckType, targetReg, ct > 0 ? (ct + 4) : vt.ordinal());
                    }
                } else {
                    int ct = prog.globals.get(globalIdx).customTypeRoutine;
                    if (ct > 0) {
                        emitAbx(Op.CheckType, targetReg, ct + 4);
                    }
                    emitAbx(Op.SetGlobal, targetReg, globalIdx);
                }
            }
            freeRegsTo(base);
            return;
        }

        errorAt(curr, "Erwartet '=' oder '(' nach Bezeichner '" + name + "'");
    }

    private int parseCondition() {
        boolean saved = inCondition;
        inCondition = true;
        int res = parseOr();
        inCondition = saved;
        return res;
    }

    private int parseExpr() {
        boolean saved = inCondition;
        inCondition = false;
        int res = parseOr();
        inCondition = saved;
        return res;
    }

    private int parseOr() {
        int lhs = parseAnd();
        if (inCondition && check(TokenType.KwOr)) {
            int dst = allocReg();
            if (lhs != dst) emitAbc(Op.Move, dst, lhs, 0);
            List<Integer> trueJumps = new ArrayList<>();
            while (match(TokenType.KwOr)) {
                trueJumps.add(emitJump(Op.JmpTrue, dst));
                int rhs = parseAnd();
                if (rhs != dst) emitAbc(Op.Move, dst, rhs, 0);
            }
            for (int j : trueJumps) patchJump(j);
            return dst;
        }
        while (match(TokenType.KwOr) || match(TokenType.KwXor)) {
            Op op = (prev.type == TokenType.KwOr) ? Op.Or : Op.Xor;
            int rhs = parseAnd();
            int dst = allocReg();
            emitAbc(op, dst, lhs, rhs);
            lhs = dst;
        }
        return lhs;
    }

    private int parseAnd() {
        int lhs = parseComparison();
        if (inCondition && check(TokenType.KwAnd)) {
            int dst = allocReg();
            if (lhs != dst) emitAbc(Op.Move, dst, lhs, 0);
            List<Integer> falseJumps = new ArrayList<>();
            while (match(TokenType.KwAnd)) {
                falseJumps.add(emitJump(Op.JmpFalse, dst));
                int rhs = parseComparison();
                if (rhs != dst) emitAbc(Op.Move, dst, rhs, 0);
            }
            for (int j : falseJumps) patchJump(j);
            return dst;
        }
        while (match(TokenType.KwAnd)) {
            int rhs = parseComparison();
            int dst = allocReg();
            emitAbc(Op.And, dst, lhs, rhs);
            lhs = dst;
        }
        return lhs;
    }

    private int parseComparison() {
        int lhs = parseConcat();
        while (match(TokenType.Equal) || match(TokenType.NotEqual) ||
               match(TokenType.Less)  || match(TokenType.LessEq)   ||
               match(TokenType.Greater) || match(TokenType.GreaterEq)) {
            TokenType t = prev.type;
            int rhs = parseConcat();
            int dst = allocReg();
            Op op = switch (t) {
                case Equal     -> Op.Eq;
                case NotEqual  -> Op.Neq;
                case Less      -> Op.Lt;
                case LessEq    -> Op.Le;
                case Greater   -> Op.Gt;
                case GreaterEq -> Op.Ge;
                default        -> Op.Eq;
            };
            emitAbc(op, dst, lhs, rhs);
            lhs = dst;
        }
        return lhs;
    }

    private int parseConcat() {
        int lhs = parseTerm();
        while (match(TokenType.Ampersand)) {
            int rhs = parseTerm();
            int dst = allocReg();
            emitAbc(Op.Concat, dst, lhs, rhs);
            lhs = dst;
        }
        return lhs;
    }

    private int parseTerm() {
        int lhs = parseFactor();
        while (match(TokenType.Plus) || match(TokenType.Minus)) {
            Op op = (prev.type == TokenType.Plus) ? Op.Add : Op.Sub;
            int rhs = parseFactor();
            int dst = allocReg();
            emitAbc(op, dst, lhs, rhs);
            lhs = dst;
        }
        return lhs;
    }

    private int parseFactor() {
        int lhs = parseUnary();
        while (match(TokenType.Star) || match(TokenType.Slash)) {
            Op op = (prev.type == TokenType.Star) ? Op.Mul : Op.Div;
            int rhs = parseUnary();
            int dst = allocReg();
            emitAbc(op, dst, lhs, rhs);
            lhs = dst;
        }
        return lhs;
    }

    private int parseUnary() {
        if (match(TokenType.Minus)) {
            int operand = parseUnary();
            int dst = allocReg();
            emitAbc(Op.Neg, dst, operand, 0);
            return dst;
        }
        if (match(TokenType.Plus)) {
            return parseUnary();
        }
        if (match(TokenType.KwNot)) {
            int operand = parseUnary();
            int dst = allocReg();
            emitAbc(Op.Not, dst, operand, 0);
            return dst;
        }
        return parsePrimary();
    }

    private int parsePrimary() {
        if (match(TokenType.IntLiteral)) {
            int dst = allocReg();
            long v = prev.intVal;
            if (v >= Short.MIN_VALUE && v <= Short.MAX_VALUE) {
                emitAsbx(Op.LoadImm, dst, (int) v);
            } else {
                int k = addConstant(Value.fromInt(v));
                emitAbx(Op.LoadK, dst, k);
            }
            return parsePostfix(dst);
        }

        if (match(TokenType.FloatLiteral)) {
            int dst = allocReg();
            int k = addConstant(Value.fromF64(prev.floatVal));
            emitAbx(Op.LoadK, dst, k);
            return parsePostfix(dst);
        }

        if (match(TokenType.StringLiteral)) {
            int dst = allocReg();
            int k;
            if (prev.seqVals != null && !prev.seqVals.isEmpty()) {
                Sequence s = new Sequence(prev.seqVals.size(), Value.fromInt(0));
                for (int i = 0; i < prev.seqVals.size(); i++) {
                    s.setElement(i, Value.fromInt(prev.seqVals.get(i)));
                }
                k = addConstant(Value.fromSeq(s));
            } else {
                k = addConstant(Value.fromString(prev.strVal));
            }
            emitAbx(Op.LoadK, dst, k);
            return parsePostfix(dst);
        }

        if (match(TokenType.Dollar)) {
            if (dollarSeqStack.isEmpty()) {
                error("'$' darf nur innerhalb eines Sequenz-Index 's[...]' verwendet werden");
                return allocReg();
            }
            int dst = allocReg();
            emitAbc(Op.Len, dst, dollarSeqStack.get(dollarSeqStack.size() - 1), 0);
            return dst;
        }

        if (match(TokenType.LBrace)) {
            int seqReg = parseSequenceLiteral();
            return parsePostfix(seqReg);
        }

        if (match(TokenType.LParen)) {
            int reg = parseOr();
            consume(TokenType.RParen, "Erwartet ')' nach Ausdruck");
            return parsePostfix(reg);
        }

        if (match(TokenType.KwAtom) || match(TokenType.KwInteger) ||
            match(TokenType.KwSequence) || match(TokenType.KwObject) ||
            match(TokenType.Identifier)) {
            String name = prev.lexeme;
            String ns = "";
            if (match(TokenType.Colon)) {
                ns = name;
                if (match(TokenType.Identifier) || match(TokenType.KwAtom) ||
                    match(TokenType.KwInteger) || match(TokenType.KwSequence) ||
                    match(TokenType.KwObject)) {
                    name = prev.lexeme;
                } else {
                    errorAt(curr, "Erwartet Bezeichner nach ':'");
                }
            }

            if (match(TokenType.LParen)) {
                List<Integer> argRegs = new ArrayList<>();
                List<Boolean> omitted = new ArrayList<>();
                if (!check(TokenType.RParen)) {
                    do {
                        if (check(TokenType.Comma) || check(TokenType.RParen)) {
                            int slot = allocReg();
                            emitAbc(Op.LoadNone, slot, 0, 0);
                            argRegs.add(slot);
                            omitted.add(true);
                        } else if (match(TokenType.Question)) {
                            int slot = allocReg();
                            emitAbc(Op.LoadNone, slot, 0, 0);
                            argRegs.add(slot);
                            omitted.add(true);
                        } else {
                            int r = parseExpr();
                            int slot = allocReg();
                            if (r != slot) {
                                emitAbc(Op.Move, slot, r, 0);
                            }
                            argRegs.add(slot);
                            omitted.add(false);
                        }
                    } while (match(TokenType.Comma));
                }
                consume(TokenType.RParen, "Erwartet ')' nach Argumentliste");

                int dest = allocReg();
                int argc = argRegs.size();

                int rIdx = "eu".equals(ns) ? -1 : resolveRoutine(name, ns);
                BuiltinId bid = resolveBuiltin(name);
                if (rIdx >= 0) {
                    emitRoutineCall(rIdx, dest, argRegs, omitted);
                } else if (bid != null) {
                    for (int i = 0; i < argc; i++) {
                        int targetArgReg = allocReg();
                        if (omitted.get(i)) {
                            emitAbc(Op.LoadNone, targetArgReg, 0, 0);
                        } else if (argRegs.get(i) != targetArgReg) {
                            emitAbc(Op.Move, targetArgReg, argRegs.get(i), 0);
                        }
                    }
                    emitAbc(Op.Builtin, dest, bid.ordinal(), argc);
                } else {
                    int fwdIdx = getOrDeclareForwardRoutine(name, true);
                    emitRoutineCall(fwdIdx, dest, argRegs, omitted);
                }
                freeRegsTo(dest + 1);
                return parsePostfix(dest);
            }

            int localIdx = ns.isEmpty() ? resolveLocal(name) : -1;
            if (localIdx >= 0) {
                return parsePostfix(locals.get(localIdx).reg);
            }
            int globalIdx = resolveGlobal(name, ns);
            if (globalIdx >= 0) {
                int dst = allocReg();
                emitAbx(Op.GetGlobal, dst, globalIdx);
                return parsePostfix(dst);
            }

            error("Nicht deklarierte Variable: '" + name + "'");
            return allocReg();
        }

        errorAt(curr, "Ausdruck erwartet");
        advance();
        return allocReg();
    }

    private int parsePostfix(int baseReg) {
        int cur = baseReg;
        while (match(TokenType.LBracket)) {
            dollarSeqStack.add(cur);
            int idx1 = allocReg();
            int e1 = parseExpr();
            if (e1 != idx1) emitAbc(Op.Move, idx1, e1, 0);
            freeRegsTo(idx1 + 1);

            if (match(TokenType.DotDot)) {
                int idx2 = allocReg();
                int e2 = parseExpr();
                if (e2 != idx2) emitAbc(Op.Move, idx2, e2, 0);
                freeRegsTo(idx2 + 1);

                dollarSeqStack.remove(dollarSeqStack.size() - 1);
                consume(TokenType.RBracket, "Erwartet ']' nach Slice-Bereich");

                emitAbc(Op.GetSlice, idx1, cur, idx1);
                freeRegsTo(idx1 + 1);
                cur = idx1;
            } else {
                dollarSeqStack.remove(dollarSeqStack.size() - 1);
                consume(TokenType.RBracket, "Erwartet ']' nach Sequenz-Index");

                emitAbc(Op.GetIdx, idx1, cur, idx1);
                freeRegsTo(idx1 + 1);
                cur = idx1;
            }
        }
        return cur;
    }

    private int parseSequenceLiteral() {
        int dest = allocReg();
        int firstElem = nextReg;
        int count = 0;
        boolean hasAccum = false;

        if (!check(TokenType.RBrace)) {
            do {
                if (check(TokenType.RBrace) || check(TokenType.Dollar)) {
                    match(TokenType.Dollar);
                    break;
                }
                if (count == 32) {
                    if (!hasAccum) {
                        emitAbc(Op.NewSeq, dest, firstElem, count);
                        hasAccum = true;
                    } else {
                        emitAbc(Op.NewSeq, firstElem, firstElem, count);
                        emitAbc(Op.Concat, dest, dest, firstElem);
                    }
                    count = 0;
                    freeRegsTo(firstElem);
                }
                int target = allocReg();
                int val = parseExpr();
                if (val != target) {
                    emitAbc(Op.Move, target, val, 0);
                }
                freeRegsTo(target + 1);
                count++;
            } while (match(TokenType.Comma));
        }
        consume(TokenType.RBrace, "Erwartet '}' am Ende des Sequenz-Literals");

        if (!hasAccum) {
            emitAbc(Op.NewSeq, dest, firstElem, count);
        } else if (count > 0) {
            emitAbc(Op.NewSeq, firstElem, firstElem, count);
            emitAbc(Op.Concat, dest, dest, firstElem);
        }
        freeRegsTo(dest + 1);
        return dest;
    }
}
