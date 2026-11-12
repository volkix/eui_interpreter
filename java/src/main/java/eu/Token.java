package eu;

public final class Token {
    public TokenType type;
    public String lexeme;
    public int line;
    public int col;
    public long intVal;
    public double floatVal;
    public String strVal;
    public java.util.List<Long> seqVals;

    public Token() {
        this.type = TokenType.Eof;
        this.lexeme = "";
        this.line = 1;
        this.col = 1;
        this.intVal = 0L;
        this.floatVal = 0.0;
        this.strVal = "";
        this.seqVals = null;
    }

    public Token(TokenType type, String lexeme, int line, int col) {
        this.type = type;
        this.lexeme = lexeme;
        this.line = line;
        this.col = col;
        this.intVal = 0L;
        this.floatVal = 0.0;
        this.strVal = "";
        this.seqVals = null;
    }

    public Token copy() {
        Token t = new Token(this.type, this.lexeme, this.line, this.col);
        t.intVal = this.intVal;
        t.floatVal = this.floatVal;
        t.strVal = this.strVal;
        if (this.seqVals != null) {
            t.seqVals = new java.util.ArrayList<>(this.seqVals);
        }
        return t;
    }
}
