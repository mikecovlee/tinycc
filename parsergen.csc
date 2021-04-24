import parsergen, regex

constant syntax = parsergen.syntax

@begin
var tiny_lexical = {
    "id"  : regex.build("^[A-Za-z_]\\w*$"),
    "num" : regex.build("^[0-9]+$"),
    "sig" : regex.build("^(\\+|-|\\*|/|=|<|\\(|\\)|;|:=?)$"),
    "ign" : regex.build("^(\\s+|\\{[^\\}]*\\}?)$"),
    "err" : regex.build("^:$")
}.to_hash_map()
@end

@begin
var tiny_syntax = {
    # Beginning of Parsing
    "begin" : {syntax.ref("stmts")},
    "stmts" : {syntax.ref("statement"), syntax.repeat(syntax.term(";"), syntax.ref("statement"))},
    "statement" : {syntax.cond_or(
        {syntax.ref("if-stmt")},
        {syntax.ref("repeat-stmt")},
        {syntax.ref("assign-stmt")},
        {syntax.ref("read-stmt")},
        {syntax.ref("write-stmt")}
    )},
    "if-stmt" : {
        syntax.term("if"), syntax.ref("expr"), syntax.term("then"), syntax.ref("stmts"),
        syntax.optional(syntax.term("else"), syntax.ref("stmts")), syntax.term("end")
    },
    "repeat-stmt" : {
        syntax.term("repeat"), syntax.ref("stmts"), syntax.term("until"), syntax.ref("expr")
    },
    "assign-stmt" : {syntax.token("id"), syntax.term(":="), syntax.ref("expr")},
    "read-stmt" : {syntax.term("read"), syntax.token("id")},
    "write-stmt" : {syntax.term("write"), syntax.ref("expr")},
    "expr" : {syntax.ref("sexp"), syntax.optional(syntax.ref("cmp-op"), syntax.ref("sexp"))},
    "cmp-op" : {syntax.cond_or({syntax.term("<")}, {syntax.term("=")})},
    "sexp" : {syntax.ref("term"), syntax.repeat(syntax.ref("add-op"), syntax.ref("term"))},
    "add-op" : {syntax.cond_or({syntax.term("+")}, {syntax.term("-")})},
    "term" : {syntax.ref("fact"), syntax.repeat(syntax.ref("mul-op"), syntax.ref("fact"))},
    "mul-op" : {syntax.cond_or({syntax.term("*")}, {syntax.term("/")})},
    "fact" : {syntax.cond_or(
        {syntax.term("("), syntax.ref("expr"), syntax.term(")")},
        {syntax.token("num")}, {syntax.token("id")}
    )}
}.to_hash_map()
@end

@begin
var cminus_lexical = {
    "id"  : regex.build("^[A-Za-z_]\\w*$"),
    "num" : regex.build("^[0-9]+$"),
    "sig" : regex.build("^(\\+|-|\\*|/|<|<=|>|>=|=|~=?|==|;|,|\\(|\\)|\\[|\\]|\\{|\\})$"),
    "ign" : regex.build("^(\\s+|/|/\\*([^\\*]|\\*(?!/))*(\\*/)?)$"),
    "err" : regex.build("^~$")
}.to_hash_map()
@end

@begin
var cminus_syntax = {
    # Beginning of Parsing
    "begin" : {
        syntax.ref("declaration"), syntax.repeat(syntax.ref("declaration"))
    },
    "declaration" : {
        syntax.ref("type_specifier"), syntax.token("id"), syntax.ref("declaration_s")
    },
    "declaration_s" : {syntax.cond_or(
        {syntax.term("["), syntax.token("num"), syntax.term("]"), syntax.term(";")},
        {syntax.term("("), syntax.ref("params"), syntax.term(")"), syntax.ref("compound_stmt")}
    )},
    "type_specifier" : {syntax.cond_or(
        {syntax.term("int")},
        {syntax.term("void")}
    )},
    "params" : {syntax.cond_or(
        {syntax.term("void")},
        {syntax.ref("param_list")}
    )},
    "param_list" : {
        syntax.ref("param"), syntax.repeat(syntax.term(","), syntax.ref("param"))
    },
    "param" : {
        syntax.ref("type_specifier"), syntax.token("id"), syntax.optional(syntax.term("["), syntax.term("]"))
    },
    "compound_stmt" : {
        syntax.term("{"),
        syntax.repeat(syntax.cond_or(
            {syntax.ref("var_declaration")},
            {syntax.ref("statement")}
        )),
        syntax.term("}")
    },
    "var_declaration" : {
        syntax.ref("type_specifier"), syntax.token("id"),
        syntax.optional(syntax.term("["), syntax.token("num"), syntax.term("]")),
        syntax.term(";")
    },
    "statement" : {syntax.cond_or(
        {syntax.ref("expression_stmt")},
        {syntax.ref("compound_stmt")},
        {syntax.ref("selection_stmt")},
        {syntax.ref("iteration_stmt")},
        {syntax.ref("return_stmt")}
    )},
    "expression_stmt" : {syntax.cond_or(
        {syntax.term(";")},
        {syntax.ref("expression"), syntax.term(";")}
    )},
    "selection_stmt" : {
        syntax.term("if"), syntax.term("("), syntax.ref("expression"), syntax.term(")"), syntax.ref("statement"),
        syntax.optional(syntax.term("else"), syntax.ref("statement"))
    },
    "iteration_stmt" : {
        syntax.term("while"), syntax.term("("), syntax.ref("expression"), syntax.term(")"), syntax.ref("statement")
    },
    "return_stmt" : {
        syntax.term("return"), syntax.optional(syntax.ref("expression")), syntax.term(";")
    },
    "expression" : {syntax.cond_or(
        {syntax.ref("var"), syntax.term("="), syntax.ref("expression")},
        {syntax.ref("simple_expression")}
    )},
    "var" : {
        syntax.token("id"), syntax.optional(syntax.term("["), syntax.ref("expression"), syntax.term("]"))
    },
    "simple_expression" : {
        syntax.ref("additive_expression"), syntax.optional(syntax.ref("relop"), syntax.ref("additive_expression"))
    },
    "relop" : {syntax.cond_or(
        {syntax.term("<=")},
        {syntax.term("<")},
        {syntax.term(">=")},
        {syntax.term(">")},
        {syntax.term("==")},
        {syntax.term("~=")}
    )},
    "additive_expression" : {
        syntax.ref("term"), syntax.repeat(syntax.ref("addop"), syntax.ref("term"))
    },
    "addop" : {syntax.cond_or(
        {syntax.term("+")},
        {syntax.term("-")}
    )},
    "term" : {
        syntax.ref("factor"), syntax.repeat(syntax.ref("mulop"), syntax.ref("term"))
    },
    "mulop" : {syntax.cond_or(
        {syntax.term("*")},
        {syntax.term("/")}
    )},
    "factor" : {syntax.cond_or(
        {syntax.term("("), syntax.ref("expression"), syntax.term(")")},
        {syntax.token("id"), syntax.optional(syntax.ref("factor_s"))},
        {syntax.token("num")}
    )},
    "factor_s" : {syntax.cond_or(
        {syntax.term("["), syntax.ref("expression"), syntax.term("]")},
        {syntax.term("("), syntax.optional(syntax.ref("args")), syntax.term(")")}
    )},
    "args" : {
        syntax.ref("expression"), syntax.repeat(syntax.term(","), syntax.ref("expression"))
    }
}.to_hash_map()
@end

@begin
var covscript_lexical = {
    "endl" : regex.build("^(;|\\n+)$"),
    "id" : regex.build("^[A-Za-z_]\\w*$"),
    "num" : regex.build("^[0-9]+(\\.[0-9]+)?$"),
    "str" : regex.build("^(\"|\"([^\"]|\\\\\")*\"?)$"),
    "char" : regex.build("^(\'|\'([^\']|\\\\(0|\\\\|\'|\"|\\w))\'?)$"),
    "bsig" : regex.build("^(=|:|\\?|->|\\.\\.|\\.\\.\\.)$"),
    "msig" : regex.build("^(\\+|\\+=|-|-=|\\*|\\*=|/|/=|%|%=|\\^|\\^=|\\+\\+|--)$"),
    "lsig" : regex.build("^(>|<|&|(\\|)|&&|(\\|\\|)|!|==?|!=?|>=?|<=?)$"),
    "brac" : regex.build("^(\\(|\\)|\\[|\\]|\\{|\\}|,|\\.)$"),
    "ign" : regex.build("^([ \\f\\r\\t\\v]+|#.*\\n?|@.*\\n?)$"),
    "err" : regex.build("^(\"|\'|&|(\\|)|\\.\\.)$")
}.to_hash_map()
@end

@begin
var covscript_syntax = {
    # Beginning of Parsing
    "begin" : {
        syntax.ref("stmts")
    },
    "stmts" : {
        syntax.repeat(syntax.ref("statement"), syntax.token("endl"))
    },
    "statement" : {syntax.cond_or(
        {syntax.ref("if-stmt")},
        {syntax.ref("expr")}
    )},
    "if-stmt" : {
        syntax.term("if"), syntax.ref("expr"), syntax.token("endl"),
        syntax.ref("if-stmts"),
        syntax.optional(syntax.term("else"), syntax.optional(syntax.term("if"), syntax.ref("expr")),
            syntax.token("endl"), syntax.ref("if-stmts")), syntax.term("end")
    },
    "if-stmts" : {
        syntax.repeat(syntax.ref("statement"), syntax.token("endl"), syntax.peek(syntax.cond_or({syntax.term("else")}, {syntax.term("end")})))
    },
    "expr" : {syntax.cond_or(
        {syntax.ref("asi-expr")},
        {syntax.ref("simple-expr")}
    )},
    "asi-expr" : {
        syntax.ref("lhs"), syntax.term("="), syntax.ref("expr")
    },
    "lhs" : {syntax.cond_or(
        {syntax.token("id")},
        {syntax.token("id"), syntax.term("["), syntax.ref("expr"), syntax.term("]")}
    )},
    "simple-expr" : {
        syntax.ref("add-expr"), syntax.repeat(syntax.ref("cmp-op"), syntax.ref("add-expr"))
    },
    "cmp-op" : {syntax.cond_or(
        {syntax.term(">")},
        {syntax.term("<")},
        {syntax.term(">=")},
        {syntax.term("<=")},
        {syntax.term("==")},
        {syntax.term("!=")}
    )},
    "add-expr" : {
        syntax.ref("mul-expr"), syntax.repeat(syntax.ref("add-op"), syntax.ref("mul-expr"))
    },
    "add-op" : {syntax.cond_or(
        {syntax.term("+")},
        {syntax.term("-")}
    )},
    "mul-expr" : {
        syntax.ref("factor"), syntax.repeat(syntax.ref("mul-op"), syntax.ref("term"))
    },
    "mul-op" : {syntax.cond_or(
        {syntax.term("*")},
        {syntax.term("/")}
    )},
    "factor" : {syntax.cond_or(
        {syntax.term("("), syntax.ref("expr"), syntax.term(")")},
        {syntax.ref("object"), syntax.optional(syntax.ref("factor_s"))},
        {syntax.token("str")},
        {syntax.token("num")}
    )},
    "object" : {
        syntax.token("id"), syntax.repeat(syntax.term("."), syntax.ref("object"))
    },
    "factor_s" : {syntax.cond_or(
        {syntax.term("["), syntax.ref("expr"), syntax.term("]")},
        {syntax.term("("), syntax.optional(syntax.ref("args")), syntax.term(")")}
    )},
    "args" : {
        syntax.ref("expr"), syntax.repeat(syntax.term(","), syntax.ref("expr"))
    }
}.to_hash_map()
@end

var tiny_grammar = new parsergen.grammar
var cminus_grammar = new parsergen.grammar
var covscript_grammar = new parsergen.grammar
var main = new parsergen.generator

tiny_grammar.lex = tiny_lexical
tiny_grammar.stx = tiny_syntax
tiny_grammar.ext = ".*\\.tny"

cminus_grammar.lex = cminus_lexical
cminus_grammar.stx = cminus_syntax
cminus_grammar.ext = ".*\\.c-"

covscript_grammar.lex = covscript_lexical
covscript_grammar.stx = covscript_syntax
covscript_grammar.ext = ".*\\.(csp|csc)"

main.add_grammar("tiny", tiny_grammar)
main.add_grammar("c-", cminus_grammar)
main.add_grammar("covscript", covscript_grammar)

main.stop_on_error = false
main.enable_log = true

main.from_file(context.cmd_args.at(1))

if main.ast != null
    parsergen.print_ast(main.ast)
end