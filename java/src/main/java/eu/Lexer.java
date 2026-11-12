package eu;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public final class Lexer {
    private final String src;
    private int pos;
    private int line;
    private int col;
    private boolean hasPeek;
    private Token peeked;

    private static final Map<String, TokenType> KEYWORDS = Map.ofEntries(
        Map.entry("atom",      TokenType.KwAtom),
        Map.entry("integer",   TokenType.KwInteger),
        Map.entry("sequence",  TokenType.KwSequence),
        Map.entry("object",    TokenType.KwObject),
        Map.entry("constant",  TokenType.KwConstant),
        Map.entry("enum",      TokenType.KwEnum),
        Map.entry("global",    TokenType.KwGlobal),
        Map.entry("public",    TokenType.KwPublic),
        Map.entry("export",    TokenType.KwExport),
        Map.entry("override",  TokenType.KwOverride),
        Map.entry("namespace", TokenType.KwNamespace),
        Map.entry("include",   TokenType.KwInclude),
        Map.entry("as",        TokenType.KwAs),
        Map.entry("with",      TokenType.KwWith),
        Map.entry("without",   TokenType.KwWithout),
        Map.entry("procedure", TokenType.KwProcedure),
        Map.entry("function",  TokenType.KwFunction),
        Map.entry("type",      TokenType.KwType),
        Map.entry("return",    TokenType.KwReturn),
        Map.entry("end",       TokenType.KwEnd),
        Map.entry("if",        TokenType.KwIf),
        Map.entry("then",      TokenType.KwThen),
        Map.entry("elsif",     TokenType.KwElsif),
        Map.entry("else",      TokenType.KwElse),
        Map.entry("while",     TokenType.KwWhile),
        Map.entry("do",        TokenType.KwDo),
        Map.entry("for",       TokenType.KwFor),
        Map.entry("to",        TokenType.KwTo),
        Map.entry("by",        TokenType.KwBy),
        Map.entry("switch",    TokenType.KwSwitch),
        Map.entry("case",      TokenType.KwCase),
        Map.entry("fallthru",  TokenType.KwFallthru),
        Map.entry("loop",      TokenType.KwLoop),
        Map.entry("until",     TokenType.KwUntil),
        Map.entry("exit",      TokenType.KwExit),
        Map.entry("break",     TokenType.KwBreak),
        Map.entry("continue",  TokenType.KwContinue),
        Map.entry("retry",     TokenType.KwRetry),
        Map.entry("entry",     TokenType.KwEntry),
        Map.entry("label",     TokenType.KwLabel),
        Map.entry("goto",      TokenType.KwGoto),
        Map.entry("ifdef",     TokenType.KwIfdef),
        Map.entry("elsifdef",  TokenType.KwElsifdef),
        Map.entry("elsedef",   TokenType.KwElsedef),
        Map.entry("routine",   TokenType.KwRoutine),
        Map.entry("deprecate", TokenType.KwDeprecate),
        Map.entry("and",       TokenType.KwAnd),
        Map.entry("or",        TokenType.KwOr),
        Map.entry("xor",       TokenType.KwXor),
        Map.entry("not",       TokenType.KwNot)
    );

    public Lexer(String source) {
        this.src = source != null ? source : "";
        this.pos = 0;
        this.line = 1;
        this.col = 1;
        this.hasPeek = false;
        this.peeked = new Token();
    }

    public Lexer copy() {
        Lexer copy = new Lexer(this.src);
        copy.pos = this.pos;
        copy.line = this.line;
        copy.col = this.col;
        copy.hasPeek = this.hasPeek;
        copy.peeked = this.peeked != null ? this.peeked.copy() : new Token();
        return copy;
    }

    public Lexer copyState() {
        return copy();
    }

    private boolean isAtEnd() {
        return pos >= src.length();
    }

    private char peek() {
        return isAtEnd() ? '\0' : src.charAt(pos);
    }

    private char peekNext() {
        return (pos + 1 >= src.length()) ? '\0' : src.charAt(pos + 1);
    }

    private char advance() {
        char c = src.charAt(pos++);
        if (c == '\n') {
            line++;
            col = 1;
        } else {
            col++;
        }
        return c;
    }

    private boolean match(char expected) {
        if (isAtEnd() || src.charAt(pos) != expected) {
            return false;
        }
        advance();
        return true;
    }

    private static boolean isAlpha(char c) {
        return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
    }

    private static boolean isDigit(char c) {
        return c >= '0' && c <= '9';
    }

    private static boolean isHexDigit(char c) {
        return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
    }

    private static boolean isAlphaNumeric(char c) {
        return isAlpha(c) || isDigit(c);
    }

    private void skipWhitespaceAndComments() {
        for (;;) {
            char c = peek();
            if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
                advance();
            } else if (c == '-' && peekNext() == '-') {
                advance();
                advance();
                if (peek() == '/' && peekNext() == '*') {
                    advance();
                    advance();
                    while (!isAtEnd()) {
                        if (peek() == '*' && peekNext() == '/') {
                            advance();
                            advance();
                            break;
                        }
                        advance();
                    }
                } else {
                    while (!isAtEnd() && peek() != '\n') {
                        advance();
                    }
                }
            } else if (c == '/' && peekNext() == '*') {
                advance();
                advance();
                int depth = 1;
                while (!isAtEnd() && depth > 0) {
                    if (peek() == '/' && peekNext() == '*') {
                        advance();
                        advance();
                        depth++;
                    } else if (peek() == '*' && peekNext() == '/') {
                        advance();
                        advance();
                        depth--;
                    } else {
                        advance();
                    }
                }
            } else if (c == '#' && pos == 0 && peekNext() == '!') {
                while (!isAtEnd() && peek() != '\n') {
                    advance();
                }
            } else {
                break;
            }
        }
    }

    private Token makeToken(TokenType type, int startPos, int startLine, int startCol) {
        return new Token(type, src.substring(startPos, pos), startLine, startCol);
    }

    private Token errorToken(String msg, int startLine, int startCol) {
        return new Token(TokenType.Error, msg, startLine, startCol);
    }

    public Token peekToken() {
        if (!hasPeek) {
            peeked = nextToken();
            hasPeek = true;
        }
        return peeked;
    }

    public Token nextToken() {
        if (hasPeek) {
            hasPeek = false;
            return peeked;
        }

        skipWhitespaceAndComments();
        int startPos = pos;
        int startLine = line;
        int startCol = col;

        if (isAtEnd()) {
            return makeToken(TokenType.Eof, startPos, startLine, startCol);
        }

        char c = advance();

        if ((c == 'b' || c == 'B') && peek() == '"') {
            advance();
            return lexBinaryString(startPos, startLine, startCol);
        }
        if ((c == 'x' || c == 'X') && peek() == '"') {
            advance();
            return lexHexSeqString(startPos, startLine, startCol, 2);
        }
        if (c == 'u' && peek() == '"') {
            advance();
            return lexHexSeqString(startPos, startLine, startCol, 4);
        }
        if (c == 'U' && peek() == '"') {
            advance();
            return lexHexSeqString(startPos, startLine, startCol, 8);
        }

        if (isAlpha(c)) {
            return lexIdentifierOrKeyword(startPos, startLine, startCol);
        }

        if (isDigit(c) || (c == '#' && isHexDigit(peek()))) {
            return lexNumber(startPos, startLine, startCol);
        }

        return switch (c) {
            case '(' -> makeToken(TokenType.LParen, startPos, startLine, startCol);
            case ')' -> makeToken(TokenType.RParen, startPos, startLine, startCol);
            case '{' -> makeToken(TokenType.LBrace, startPos, startLine, startCol);
            case '}' -> makeToken(TokenType.RBrace, startPos, startLine, startCol);
            case '[' -> makeToken(TokenType.LBracket, startPos, startLine, startCol);
            case ']' -> makeToken(TokenType.RBracket, startPos, startLine, startCol);
            case ',' -> makeToken(TokenType.Comma, startPos, startLine, startCol);
            case '?' -> makeToken(TokenType.Question, startPos, startLine, startCol);
            case '$' -> makeToken(TokenType.Dollar, startPos, startLine, startCol);
            case ':' -> makeToken(TokenType.Colon, startPos, startLine, startCol);
            case '.' -> {
                if (match('.')) yield makeToken(TokenType.DotDot, startPos, startLine, startCol);
                if (isDigit(peek())) yield lexNumber(startPos, startLine, startCol);
                yield makeToken(TokenType.Dot, startPos, startLine, startCol);
            }
            case '+' -> makeToken(match('=') ? TokenType.PlusEq : TokenType.Plus, startPos, startLine, startCol);
            case '-' -> makeToken(match('=') ? TokenType.MinusEq : TokenType.Minus, startPos, startLine, startCol);
            case '*' -> makeToken(match('=') ? TokenType.StarEq : TokenType.Star, startPos, startLine, startCol);
            case '/' -> makeToken(match('=') ? TokenType.SlashEq : TokenType.Slash, startPos, startLine, startCol);
            case '&' -> makeToken(match('=') ? TokenType.AmpEq : TokenType.Ampersand, startPos, startLine, startCol);
            case '=' -> makeToken(TokenType.Equal, startPos, startLine, startCol);
            case '!' -> {
                if (match('=')) yield makeToken(TokenType.NotEqual, startPos, startLine, startCol);
                yield errorToken("Erwartet '=' nach '!' (nutze 'not' für logische Negation)", startLine, startCol);
            }
            case '<' -> makeToken(match('=') ? TokenType.LessEq : TokenType.Less, startPos, startLine, startCol);
            case '>' -> makeToken(match('=') ? TokenType.GreaterEq : TokenType.Greater, startPos, startLine, startCol);
            case '"' -> {
                if (peek() == '"' && peekNext() == '"') {
                    advance();
                    advance();
                    yield lexRawString(startPos, startLine, startCol);
                }
                yield lexString(startPos, startLine, startCol, '"');
            }
            case '\'' -> lexCharLiteral(startPos, startLine, startCol);
            case '`' -> lexRawString(startPos, startLine, startCol);
            default -> errorToken("Unerwartetes Zeichen im Quelltext", startLine, startCol);
        };
    }

    private Token lexIdentifierOrKeyword(int startPos, int startLine, int startCol) {
        while (!isAtEnd() && isAlphaNumeric(peek())) {
            advance();
        }
        String text = src.substring(startPos, pos);
        TokenType kw = KEYWORDS.get(text);
        if (kw != null) {
            return makeToken(kw, startPos, startLine, startCol);
        }
        return makeToken(TokenType.Identifier, startPos, startLine, startCol);
    }

    private static int hexVal(char ch) {
        if (ch >= '0' && ch <= '9') return ch - '0';
        if (ch >= 'a' && ch <= 'f') return ch - 'a' + 10;
        if (ch >= 'A' && ch <= 'F') return ch - 'A' + 10;
        return 0;
    }

    private Token lexNumber(int startPos, int startLine, int startCol) {
        if (src.charAt(startPos) == '#') {
            long val = 0L;
            while (!isAtEnd() && (isHexDigit(peek()) || peek() == '_')) {
                char ch = advance();
                if (ch == '_') continue;
                val = (val << 4) | hexVal(ch);
            }
            if (Long.compareUnsigned(val, 0x3FFFFFFFFFFFFFFFL) > 0) {
                Token tok = makeToken(TokenType.FloatLiteral, startPos, startLine, startCol);
                tok.floatVal = (double) (val & 0x7FFFFFFFFFFFFFFFL) + (val < 0 ? 0x1.0p63 : 0.0);
                return tok;
            }
            Token tok = makeToken(TokenType.IntLiteral, startPos, startLine, startCol);
            tok.intVal = val;
            return tok;
        }

        if (src.charAt(startPos) == '0' &&
            (peek() == 'x' || peek() == 'X' || peek() == 'b' || peek() == 'B' || peek() == 't' || peek() == 'T' || peek() == 'd' || peek() == 'D')) {
            char baseCh = Character.toLowerCase(advance());
            int base = (baseCh == 'x') ? 16 : (baseCh == 'b' ? 2 : (baseCh == 't' ? 8 : 10));
            long val = 0L;
            while (!isAtEnd() && (isHexDigit(peek()) || peek() == '_')) {
                char ch = advance();
                if (ch == '_') continue;
                val = val * base + hexVal(ch);
            }
            if (Long.compareUnsigned(val, 0x3FFFFFFFFFFFFFFFL) > 0) {
                Token tok = makeToken(TokenType.FloatLiteral, startPos, startLine, startCol);
                tok.floatVal = (double) (val & 0x7FFFFFFFFFFFFFFFL) + (val < 0 ? 0x1.0p63 : 0.0);
                return tok;
            }
            Token tok = makeToken(TokenType.IntLiteral, startPos, startLine, startCol);
            tok.intVal = val;
            return tok;
        }

        boolean isFloat = (src.charAt(startPos) == '.');
        while (!isAtEnd() && (isDigit(peek()) || peek() == '_')) {
            advance();
        }

        if (!isFloat && peek() == '.' && peekNext() != '.') {
            isFloat = true;
            advance();
            while (!isAtEnd() && (isDigit(peek()) || peek() == '_')) {
                advance();
            }
        }

        if (peek() == 'e' || peek() == 'E') {
            isFloat = true;
            advance();
            if (peek() == '+' || peek() == '-') advance();
            while (!isAtEnd() && (isDigit(peek()) || peek() == '_')) {
                advance();
            }
        }

        StringBuilder clean = new StringBuilder(pos - startPos);
        for (int i = startPos; i < pos; i++) {
            char ch = src.charAt(i);
            if (ch != '_') clean.append(ch);
        }

        String s = clean.toString();
        if (isFloat) {
            Token tok = makeToken(TokenType.FloatLiteral, startPos, startLine, startCol);
            try {
                tok.floatVal = Double.parseDouble(s);
            } catch (NumberFormatException e) {
                tok.floatVal = 0.0;
            }
            return tok;
        } else {
            Token tok = makeToken(TokenType.IntLiteral, startPos, startLine, startCol);
            try {
                tok.intVal = Long.parseLong(s, 10);
            } catch (NumberFormatException e) {
                tok.intVal = (long) Double.parseDouble(s);
            }
            return tok;
        }
    }

    private Token lexCharLiteral(int startPos, int startLine, int startCol) {
        if (isAtEnd()) {
            return errorToken("Nicht geschlossener Character-Literal vor Zeilenende", startLine, startCol);
        }
        char c = advance();
        long val = 0;
        if (c == '\\') {
            if (isAtEnd()) {
                return errorToken("Nicht geschlossener Escape-Character", startLine, startCol);
            }
            char esc = advance();
            if (esc == 'b') {
                while (!isAtEnd() && peek() != '\'') {
                    char d = advance();
                    if (d == '_') continue;
                    if (d == '0' || d == '1') {
                        val = (val << 1) | (d - '0');
                    } else {
                        return errorToken("Ungültige Binärziffer in Character-Literal", startLine, startCol);
                    }
                }
            } else if (esc == 'x' || esc == 'u' || esc == 'U') {
                while (!isAtEnd() && peek() != '\'') {
                    char d = advance();
                    if (d == '_') continue;
                    if (isHexDigit(d)) {
                        val = (val << 4) | hexVal(d);
                    } else {
                        return errorToken("Ungültige Hex-Ziffer in Character-Literal", startLine, startCol);
                    }
                }
            } else if (esc == 'e' || esc == 'E') {
                val = 27;
            } else if (esc == 'n') {
                val = 10;
            } else if (esc == 'r') {
                val = 13;
            } else if (esc == 't') {
                val = 9;
            } else if (esc == '0') {
                val = 0;
            } else if (esc == '\\') {
                val = 92;
            } else if (esc == '\'') {
                val = 39;
            } else if (esc == '"') {
                val = 34;
            } else {
                val = (long) esc;
            }
        } else {
            if (Character.isHighSurrogate(c) && !isAtEnd() && Character.isLowSurrogate(peek())) {
                char low = advance();
                val = Character.toCodePoint(c, low);
            } else {
                val = (long) c;
            }
        }

        if (isAtEnd() || peek() != '\'') {
            return errorToken("Nicht geschlossener Character-Literal (erwartet single quote)", startLine, startCol);
        }
        advance(); // closing '
        Token tok = makeToken(TokenType.IntLiteral, startPos, startLine, startCol);
        tok.intVal = val;
        return tok;
    }

    private Token lexString(int startPos, int startLine, int startCol, char quote) {
        Token tok = makeToken(TokenType.StringLiteral, startPos, startLine, startCol);
        StringBuilder decoded = new StringBuilder();
        tok.seqVals = new ArrayList<>();
        while (!isAtEnd() && peek() != quote) {
            char c = advance();
            if (c == '\n') {
                return errorToken("Nicht geschlossener String vor Zeilenende", startLine, startCol);
            }
            if (c == '\\' && !isAtEnd()) {
                char esc = advance();
                if (esc == 'e' || esc == 'E') {
                    decoded.append((char) 27);
                    tok.seqVals.add(27L);
                } else if (esc == 'n') {
                    decoded.append('\n');
                    tok.seqVals.add(10L);
                } else if (esc == 'r') {
                    decoded.append('\r');
                    tok.seqVals.add(13L);
                } else if (esc == 't') {
                    decoded.append('\t');
                    tok.seqVals.add(9L);
                } else if (esc == '0') {
                    decoded.append('\0');
                    tok.seqVals.add(0L);
                } else if (esc == '\\') {
                    decoded.append('\\');
                    tok.seqVals.add(92L);
                } else if (esc == '"') {
                    decoded.append('"');
                    tok.seqVals.add(34L);
                } else if (esc == '\'') {
                    decoded.append('\'');
                    tok.seqVals.add(39L);
                } else if (esc == 'x' || esc == 'u' || esc == 'U') {
                    int maxDigits = (esc == 'x') ? 2 : (esc == 'u') ? 4 : 8;
                    long hval = 0;
                    int count = 0;
                    while (count < maxDigits && !isAtEnd() && isHexDigit(peek())) {
                        char d = advance();
                        hval = (hval << 4) | hexVal(d);
                        count++;
                    }
                    if (esc == 'x') {
                        decoded.append((char) (hval & 0xFF));
                        tok.seqVals.add(hval & 0xFF);
                    } else {
                        int cp = (int) hval;
                        if (Character.isValidCodePoint(cp)) {
                            decoded.append(Character.toChars(cp));
                            byte[] utf8 = new String(Character.toChars(cp)).getBytes(StandardCharsets.UTF_8);
                            for (byte b : utf8) {
                                tok.seqVals.add((long) (b & 0xFF));
                            }
                        } else {
                            decoded.append((char) (hval & 0xFFFF));
                            tok.seqVals.add(hval);
                        }
                    }
                } else {
                    decoded.append(esc);
                    if (esc > 127) {
                        byte[] utf8 = Character.toString(esc).getBytes(StandardCharsets.UTF_8);
                        for (byte b : utf8) {
                            tok.seqVals.add((long) (b & 0xFF));
                        }
                    } else {
                        tok.seqVals.add((long) esc);
                    }
                }
            } else {
                if (Character.isHighSurrogate(c) && !isAtEnd() && Character.isLowSurrogate(peek())) {
                    char low = advance();
                    decoded.append(c).append(low);
                    int cp = Character.toCodePoint(c, low);
                    byte[] utf8 = new String(Character.toChars(cp)).getBytes(StandardCharsets.UTF_8);
                    for (byte b : utf8) {
                        tok.seqVals.add((long) (b & 0xFF));
                    }
                } else if (c > 127) {
                    decoded.append(c);
                    byte[] utf8 = Character.toString(c).getBytes(StandardCharsets.UTF_8);
                    for (byte b : utf8) {
                        tok.seqVals.add((long) (b & 0xFF));
                    }
                } else {
                    decoded.append(c);
                    tok.seqVals.add((long) c);
                }
            }
        }

        if (isAtEnd()) {
            return errorToken("Nicht geschlossener String am Dateiende", startLine, startCol);
        }
        advance(); // closing quote
        tok.strVal = decoded.toString();
        return tok;
    }

    private Token lexBinaryString(int startPos, int startLine, int startCol) {
        Token tok = makeToken(TokenType.StringLiteral, startPos, startLine, startCol);
        tok.seqVals = new ArrayList<>();
        StringBuilder currentNum = new StringBuilder();
        while (!isAtEnd() && peek() != '"') {
            char c = advance();
            if (Character.isWhitespace(c)) {
                if (currentNum.length() > 0) {
                    tok.seqVals.add(Long.parseLong(currentNum.toString(), 2));
                    currentNum.setLength(0);
                }
            } else if (c == '_') {
                // ignore
            } else if (c == '0' || c == '1') {
                currentNum.append(c);
            }
        }
        if (currentNum.length() > 0) {
            tok.seqVals.add(Long.parseLong(currentNum.toString(), 2));
        }
        if (isAtEnd()) {
            return errorToken("Nicht geschlossener Binär-String am Dateiende", startLine, startCol);
        }
        advance(); // closing "
        return tok;
    }

    private Token lexHexSeqString(int startPos, int startLine, int startCol, int chunkSize) {
        Token tok = makeToken(TokenType.StringLiteral, startPos, startLine, startCol);
        tok.seqVals = new ArrayList<>();
        StringBuilder word = new StringBuilder();
        Runnable flushWord = () -> {
            if (word.length() == 0) return;
            int i = 0;
            while (i < word.length()) {
                int remaining = word.length() - i;
                int take = Math.min(chunkSize, remaining);
                String chunk = word.substring(i, i + take);
                tok.seqVals.add(Long.parseUnsignedLong(chunk, 16));
                i += take;
            }
            word.setLength(0);
        };

        while (!isAtEnd() && peek() != '"') {
            char c = advance();
            if (Character.isWhitespace(c)) {
                flushWord.run();
            } else if (c == '_') {
                // ignore
            } else if (isHexDigit(c)) {
                word.append(c);
            }
        }
        flushWord.run();
        if (isAtEnd()) {
            return errorToken("Nicht geschlossener Hex-String am Dateiende", startLine, startCol);
        }
        advance(); // closing "
        return tok;
    }

    private static String processMultilineRawString(String s) {
        boolean startsWithNl = false;
        if (s.startsWith("\r\n")) {
            s = s.substring(2);
            startsWithNl = true;
        } else if (s.startsWith("\n")) {
            s = s.substring(1);
            startsWithNl = true;
        }

        int eol = s.indexOf('\n');
        String line1 = (eol != -1) ? s.substring(0, eol) : s;
        if (line1.endsWith("\r")) line1 = line1.substring(0, line1.length() - 1);

        int margin = 0;
        while (margin < line1.length() && line1.charAt(margin) == '_') {
            margin++;
        }

        boolean stripTrailing = startsWithNl;
        boolean onlyUnderscores = false;
        if (margin > 0) {
            onlyUnderscores = (margin == line1.length());
            if (!onlyUnderscores) {
                stripTrailing = false;
            }
        }

        if (stripTrailing) {
            if (s.endsWith("\r\n")) {
                s = s.substring(0, s.length() - 2);
            } else if (s.endsWith("\n")) {
                s = s.substring(0, s.length() - 1);
            }
        }

        if (margin > 0) {
            StringBuilder sb = new StringBuilder();
            String[] lines = s.split("\r?\n");
            for (int i = 0; i < lines.length; i++) {
                String line = lines[i];
                if (i == 0) {
                    if (onlyUnderscores) {
                        continue;
                    } else {
                        line = line.substring(margin);
                    }
                } else {
                    int spaces = 0;
                    while (spaces < margin && spaces < line.length() && line.charAt(spaces) == ' ') {
                        spaces++;
                    }
                    line = line.substring(spaces);
                }
                if (sb.length() > 0) {
                    sb.append('\n');
                }
                sb.append(line);
            }
            if (!stripTrailing && s.endsWith("\n")) {
                sb.append('\n');
            }
            s = sb.toString();
        }
        return s;
    }

    private Token lexRawString(int startPos, int startLine, int startCol) {
        boolean triple = (src.charAt(startPos) == '"');
        StringBuilder decoded = new StringBuilder();
        while (!isAtEnd()) {
            if (triple) {
                if (peek() == '"' && peekNext() == '"' && (pos + 2 < src.length() && src.charAt(pos + 2) == '"')) {
                    advance();
                    advance();
                    advance();
                    Token tok = makeToken(TokenType.StringLiteral, startPos, startLine, startCol);
                    tok.strVal = processMultilineRawString(decoded.toString());
                    tok.seqVals = new ArrayList<>();
                    for (byte b : tok.strVal.getBytes(StandardCharsets.UTF_8)) {
                        tok.seqVals.add((long) (b & 0xFF));
                    }
                    return tok;
                }
            } else {
                if (peek() == '`') {
                    advance();
                    Token tok = makeToken(TokenType.StringLiteral, startPos, startLine, startCol);
                    tok.strVal = processMultilineRawString(decoded.toString());
                    tok.seqVals = new ArrayList<>();
                    for (byte b : tok.strVal.getBytes(StandardCharsets.UTF_8)) {
                        tok.seqVals.add((long) (b & 0xFF));
                    }
                    return tok;
                }
            }
            decoded.append(advance());
        }
        return errorToken("Nicht geschlossener Raw-String am Dateiende", startLine, startCol);
    }
}
