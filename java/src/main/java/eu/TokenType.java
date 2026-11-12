package eu;

public enum TokenType {
    // End of file & Error
    Eof("EOF"),
    Error("ERROR"),

    // Literals & Identifiers
    Identifier("Identifier"),
    IntLiteral("IntLiteral"),
    FloatLiteral("FloatLiteral"),
    StringLiteral("StringLiteral"),

    // Built-in Type Keywords
    KwAtom("atom"),
    KwInteger("integer"),
    KwSequence("sequence"),
    KwObject("object"),

    // Declarations & Scoping Keywords (OpenEuphoria 4.x)
    KwConstant("constant"),
    KwEnum("enum"),
    KwGlobal("global"),
    KwPublic("public"),
    KwExport("export"),
    KwOverride("override"),
    KwNamespace("namespace"),
    KwInclude("include"),
    KwAs("as"),
    KwWith("with"),
    KwWithout("without"),

    // Routines
    KwProcedure("procedure"),
    KwFunction("function"),
    KwType("type"),
    KwReturn("return"),
    KwEnd("end"),

    // Control Flow (OpenEuphoria 4.x)
    KwIf("if"),
    KwThen("then"),
    KwElsif("elsif"),
    KwElse("else"),
    KwWhile("while"),
    KwDo("do"),
    KwFor("for"),
    KwTo("to"),
    KwBy("by"),
    KwSwitch("switch"),
    KwCase("case"),
    KwFallthru("fallthru"),
    KwLoop("loop"),
    KwUntil("until"),
    KwBlock("block"),
    KwExit("exit"),
    KwBreak("break"),
    KwContinue("continue"),
    KwRetry("retry"),
    KwEntry("entry"),
    KwLabel("label"),
    KwGoto("goto"),
    KwIfdef("ifdef"),
    KwElsifdef("elsifdef"),
    KwElsedef("elsedef"),
    KwRoutine("routine"),
    KwDeprecate("deprecate"),

    // Logical Operators (Keyword-based in Euphoria)
    KwAnd("and"),
    KwOr("or"),
    KwXor("xor"),
    KwNot("not"),

    // Punctuation & Symbols
    Plus("+"),
    Minus("-"),
    Star("*"),
    Slash("/"),
    Ampersand("&"),
    Question("?"),
    Dollar("$"),
    Dot("."),
    DotDot(".."),
    Colon(":"),

    // Assignment & Compound Assignment
    Equal("="),
    PlusEq("+="),
    MinusEq("-="),
    StarEq("*="),
    SlashEq("/="),
    AmpEq("&="),

    // Comparisons
    NotEqual("!="),
    Less("<"),
    LessEq("<="),
    Greater(">"),
    GreaterEq(">="),

    // Delimiters
    LParen("("),
    RParen(")"),
    LBrace("{"),
    RBrace("}"),
    LBracket("["),
    RBracket("]"),
    Comma(",");

    private final String label;

    TokenType(String label) {
        this.label = label;
    }

    public String tokenName() {
        return label;
    }
}
