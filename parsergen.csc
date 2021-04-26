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
    "endl" : regex.build("^\\n+$"),
    "id" : regex.build("^[A-Za-z_]\\w*$"),
    "num" : regex.build("^[0-9]+(\\.[0-9]+)?$"),
    "str" : regex.build("^(\"|\"([^\"]|\\\\\")*\"?)$"),
    "char" : regex.build("^(\'|\'([^\']|\\\\(0|\\\\|\'|\"|\\w))\'?)$"),
    "bsig" : regex.build("^(;|:|\\?|\\.\\.?|\\.\\.\\.)$"),
    "msig" : regex.build("^(\\+(\\+|=)?|-(-|=|>)?|\\*=?|/=?|%=?|\\^=?)$"),
    "lsig" : regex.build("^(>|<|&|(\\|)|&&|(\\|\\|)|!|==?|!=?|>=?|<=?)$"),
    "brac" : regex.build("^(\\(|\\)|\\[|\\]|\\{|\\}|,)$"),
    "ign" : regex.build("^([ \\f\\r\\t\\v]+|#.*\\n?|@.*\\n?)$"),
    "err" : regex.build("^(\"|\'|&|(\\|)|\\.\\.)$")
}.to_hash_map()
@end

@begin
var covscript_syntax = {
    # Beginning of Parsing
    "begin" : {
        syntax.repeat(syntax.ref("statement"), syntax.repeat(syntax.token("endl")))
    },
    # Ignore if not match initiatively
    "ignore" : {
        syntax.token("endl")
    },
    # End of Line
    "endline" : {syntax.cond_or(
        {syntax.token("endl")},
        {syntax.term(";")}
    )},
    # Bootstrap
    "statement" : {syntax.cond_or(
        {syntax.ref("import-stmt")},
        {syntax.ref("var-stmt")},
        {syntax.ref("block-stmt")},
        {syntax.ref("namespace-stmt")},
        {syntax.ref("using-stmt")},
        {syntax.ref("if-stmt")},
        {syntax.ref("switch-stmt")},
        {syntax.ref("while-stmt")},
        {syntax.ref("loop-stmt")},
        {syntax.ref("for-stmt")},
        {syntax.ref("foreach-stmt")},
        {syntax.ref("control-stmt")},
        {syntax.ref("expr-stmt")}
    )},
    "declaration" : {syntax.cond_or(
        {syntax.ref("namespace-stmt")},
        {syntax.ref("var-stmt")},
        {syntax.ref("using-stmt")}
    )},
    # Statements
    "import-stmt" : {
        syntax.term("import"), syntax.ref("import-list"), syntax.ref("endline")
    },
    "module-list" : {
        syntax.token("id"), syntax.optional(syntax.term("."), syntax.cond_or({syntax.term("*")}, {syntax.ref("module-list")}))
    },
    "import-list" : {
        syntax.ref("module-list"), syntax.optional(syntax.term("as"), syntax.token("id")), syntax.optional(syntax.term(","), syntax.ref("import-list"))
    },
    "var-def" : {
        syntax.cond_or({syntax.ref("var-bind"), syntax.term("="), syntax.ref("asi-expr")}, {syntax.ref("var-list")})
    },
    "var-stmt" : {
        syntax.cond_or({syntax.term("var")}, {syntax.term("constant")}), syntax.ref("var-def"), syntax.ref("endline")
    },
    "var-bind" : {
        syntax.term("("), syntax.ref("var-bind-list"), syntax.repeat(syntax.term(","), syntax.ref("var-bind-list")), syntax.term(")")
    },
    "var-bind-list" : {syntax.cond_or(
        {syntax.token("id")},
        {syntax.token("...")},
        {syntax.ref("var-bind")}
    )},
    "var-list" : {
        syntax.token("id"), syntax.term("="), syntax.ref("asi-expr"), syntax.optional(syntax.term(","), syntax.ref("var-list"))
    },
    "block-stmt" : {
        syntax.term("block"), syntax.token("endl"), syntax.repeat(syntax.ref("statement"), syntax.repeat(syntax.token("endl")), syntax.nlook(syntax.term("end"))), syntax.term("end"), syntax.token("endl")
    },
    "namespace-stmt" : {
        syntax.term("namespace"), syntax.token("id"), syntax.token("endl"), syntax.repeat(syntax.ref("declaration"), syntax.repeat(syntax.token("endl")), syntax.nlook(syntax.term("end"))), syntax.term("end"), syntax.token("endl")
    },
    "using-stmt" : {
        syntax.term("using"), syntax.ref("using-list"), syntax.ref("endline")
    },
    "using-list" : {
        syntax.ref("module-list"), syntax.optional(syntax.term(","), syntax.ref("using-list"))
    },
    "if-stmt" : {
        syntax.term("if"), syntax.ref("expr"), syntax.token("endl"),
        syntax.optional(syntax.nlook(syntax.term("end")), syntax.ref("if-stmts")),
        syntax.repeat(syntax.term("else"), syntax.optional(syntax.term("if"), syntax.ref("expr")),
        syntax.token("endl"), syntax.optional(syntax.nlook(syntax.term("end")), syntax.ref("if-stmts"))), syntax.term("end"), syntax.token("endl")
    },
    "if-stmts" : {
        syntax.repeat(syntax.ref("statement"), syntax.repeat(syntax.token("endl")), syntax.nlook(syntax.cond_or({syntax.term("else")}, {syntax.term("end")})))
    },
    "switch-stmt" : {
        syntax.term("switch"), syntax.ref("expr"), syntax.token("endl"), syntax.ref("switch-stmts"), syntax.term("end"), syntax.token("endl")
    },
    "switch-stmts" : {
        syntax.repeat(syntax.cond_or({syntax.ref("switch-case")}, {syntax.ref("switch-default")}), syntax.repeat(syntax.token("endl")), syntax.nlook(syntax.term("end")))
    },
    "switch-case" : {
        syntax.term("case"), syntax.ref("expr"), syntax.token("endl"), syntax.optional(syntax.nlook(syntax.term("end")), syntax.ref("case-stmts")), syntax.term("end"), syntax.token("endl")
    },
    "switch-default" : {
        syntax.term("default"), syntax.token("endl"), syntax.optional(syntax.nlook(syntax.term("end")), syntax.ref("case-stmts")), syntax.term("end"), syntax.token("endl")
    },
    "case-stmts" : {
        syntax.repeat(syntax.ref("statement"), syntax.repeat(syntax.token("endl")), syntax.nlook(syntax.term("end")))
    },
    "while-stmt" : {
        syntax.term("block"), syntax.ref("expr"), syntax.token("endl"), syntax.repeat(syntax.ref("statement"), syntax.repeat(syntax.token("endl")), syntax.nlook(syntax.term("end"))), syntax.term("end"), syntax.token("endl")
    },
    "loop-stmt" : {
        syntax.term("loop"), syntax.token("endl"), syntax.repeat(syntax.ref("statement"), syntax.repeat(syntax.token("endl")), syntax.nlook(syntax.cond_or({syntax.term("until")}, {syntax.term("end")}))),
        syntax.cond_or({syntax.term("until"), syntax.ref("expr")}, {syntax.term("end")}), syntax.token("endl")
    },
    "for-stmt" : {
        syntax.term("for"), syntax.optional(syntax.ref("var-def")), syntax.term(";"), syntax.optional(syntax.ref("expr")), syntax.term(";"), syntax.optional(syntax.ref("expr")),
        syntax.cond_or(
            {syntax.term("do"), syntax.ref("expr"), syntax.ref("endline")},
            {syntax.token("endl"), syntax.repeat(syntax.ref("statement"), syntax.repeat(syntax.token("endl")), syntax.nlook(syntax.term("end"))), syntax.term("end"), syntax.token("endl")}
        )
    },
    "foreach-stmt" : {
        syntax.term("foreach"), syntax.optional(syntax.nlook(syntax.term("in")), syntax.token("id")), syntax.term("in"), syntax.ref("expr"),
        syntax.cond_or(
            {syntax.term("do"), syntax.ref("expr"), syntax.ref("endline")},
            {syntax.token("endl"), syntax.repeat(syntax.ref("statement"), syntax.repeat(syntax.token("endl")), syntax.nlook(syntax.term("end"))), syntax.term("end"), syntax.token("endl")}
        )
    },
    "control-stmt" : {
        syntax.cond_or({syntax.term("break")}, {syntax.term("continue")}), syntax.ref("endline")
    },
    "expr-stmt" : {
        syntax.ref("expr"), syntax.ref("endline")
    },
    # Expression
    "expr" : {
        syntax.ref("asi-expr"), syntax.optional(syntax.term(","), syntax.ref("expr"))
    },
    "asi-expr" : {syntax.cond_or(
        {syntax.ref("var-bind"), syntax.term("="), syntax.ref("cond-expr")},
        {syntax.ref("unary-expr"), syntax.ref("asi-op"), syntax.ref("asi-expr")},
        {syntax.ref("lambda-expr")},
        {syntax.ref("cond-expr")}
    )},
    "asi-op" : {syntax.cond_or(
        {syntax.term("=")},
        {syntax.term("+=")},
        {syntax.term("-=")},
        {syntax.term("*=")},
        {syntax.term("/=")},
        {syntax.term("%=")},
        {syntax.term("^=")}
    )},
    "lambda-expr" : {
        syntax.term("["), syntax.optional(syntax.ref("capture-list")), syntax.term("]"), syntax.term("("), syntax.ref("argument-list"), syntax.term(")"), syntax.ref("lambda-body")
    },
    "capture-list" : {
        syntax.optional(syntax.term("=")), syntax.token("id"), syntax.repeat(syntax.term(","), syntax.ref("capture-list"))
    },
    "argument-list" : {syntax.cond_or(
        {syntax.term("..."), syntax.token("id")},
        {syntax.optional(syntax.term("=")), syntax.token("id"), syntax.optional(syntax.term(":"), syntax.ref("visit-expr")), syntax.repeat(syntax.term(","), syntax.ref("argument-list"))}
    )},
    "lambda-body" : {syntax.cond_or(
        {syntax.term("{"), syntax.repeat(syntax.ref("statement"), syntax.repeat(syntax.token("endl"))), syntax.term("}")},
        {syntax.term("->"), syntax.ref("cond-expr")}
    )},
    "cond-expr" : {
        syntax.ref("logic-or-expr"), syntax.optional(syntax.term("?"), syntax.ref("expr"), syntax.term(":"), syntax.ref("cond-expr"))
    },
    "pair-expr" : {
        syntax.ref("logic-or-expr"), syntax.optional(syntax.term(":"), syntax.ref("logic-or-expr"))
    },
    "logic-or-expr" : {
        syntax.ref("logic-and-expr"), syntax.optional(syntax.cond_or({syntax.term("||")}, {syntax.term("or")}), syntax.ref("logic-or-expr"))
    },
    "logic-and-expr" : {
        syntax.ref("equal-expr"), syntax.optional(syntax.cond_or({syntax.term("&&")}, {syntax.term("and")}), syntax.ref("logic-and-expr"))
    },
    "equal-expr" : {
        syntax.ref("relat-expr"), syntax.optional(syntax.cond_or({syntax.term("==")}, {syntax.term("!=")}), syntax.ref("equal-expr"))
    },
    "relat-expr" : {
        syntax.ref("add-expr"), syntax.optional(syntax.cond_or({syntax.term(">")}, {syntax.term("<")}, {syntax.term(">=")}, {syntax.term("<=")}), syntax.ref("relat-expr"))
    },
    "add-expr" : {
        syntax.ref("mul-expr"), syntax.optional(syntax.cond_or({syntax.term("+")}, {syntax.term("-")}), syntax.ref("add-expr"))
    },
    "mul-expr" : {
        syntax.ref("unary-expr"), syntax.optional(syntax.nlook(syntax.token("endl")), syntax.cond_or({syntax.term("*")}, {syntax.term("/")}, {syntax.term("%")}, {syntax.term("^")}), syntax.ref("mul-expr"))
    },
    "unary-expr" : {syntax.cond_or(
        {syntax.ref("unary-op"), syntax.ref("unary-expr")},
        {
            syntax.cond_or({syntax.term("new")}, {syntax.term("gcnew")}), syntax.ref("unary-expr"),
            syntax.optional(syntax.term("{"), syntax.optional(syntax.ref("expr")), syntax.term("}"))
        },
        {syntax.ref("prim-expr"), syntax.optional(syntax.ref("postfix-expr"))}
    )},
    "unary-op" : {syntax.cond_or(
        {syntax.term("typeid")},
        {syntax.term("++")},
        {syntax.term("--")},
        {syntax.term("*")},
        {syntax.term("-")},
        {syntax.term("!")}
    )},
    "postfix-expr" : {
        syntax.cond_or({syntax.term("++")}, {syntax.term("--")}, {syntax.term("...")}), syntax.optional(syntax.ref("postfix-expr"))
    },
    "prim-expr" : {syntax.cond_or(
        {syntax.ref("visit-expr")},
        {syntax.ref("constant")}
    )},
    "visit-expr" : {
        syntax.ref("object"), syntax.optional(syntax.cond_or({syntax.term("->")}, {syntax.term(".")}), syntax.ref("visit-expr"))
    },
    "object" : {syntax.cond_or(
        {syntax.ref("array"), syntax.optional(syntax.ref("index"))},
        {syntax.token("str"), syntax.optional(syntax.ref("index"))},
        {syntax.term("local")},
        {syntax.term("global")},
        {syntax.ref("element")},
        {syntax.token("char")}
    )},
    "element" : {
        syntax.cond_or({syntax.token("id")}, {syntax.term("("), syntax.ref("expr"), syntax.term(")")}),
        syntax.repeat(syntax.cond_or({syntax.ref("fcall")}, {syntax.ref("index")}))
    },
    "constant" : {syntax.cond_or(
        {syntax.token("num")},
        {syntax.term("null")},
        {syntax.term("true")},
        {syntax.term("false")}
    )},
    "array" : {
        syntax.term("{"), syntax.optional(syntax.ref("expr")), syntax.term("}")
    },
    "fcall" : {
        syntax.term("("), syntax.optional(syntax.ref("expr")), syntax.term(")")
    },
    "index" : {
        syntax.term("["), syntax.ref("asi-expr"), syntax.term("]")
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
covscript_grammar.ext = ".*\\.(csp|csc|ecs)"

main.add_grammar("tiny", tiny_grammar)
main.add_grammar("c-", cminus_grammar)
main.add_grammar("covscript", covscript_grammar)

main.stop_on_error = false
# main.enable_log = true

main.from_file(context.cmd_args.at(1))

function compress_ast(n)
    foreach it in n.nodes
        while typeid it == typeid parsergen.syntax_tree && it.nodes.size == 1
            it = it.nodes.front
        end
        if typeid it == typeid parsergen.syntax_tree
            compress_ast(it)
        else
            if it.type == "endl"
                it.data = "\\n"
            end
        end
    end
end

if main.ast != null
    compress_ast(main.ast)
    parsergen.print_ast(main.ast)
end