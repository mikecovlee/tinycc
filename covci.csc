# Covariant Compiler Interpreter

import regex

# Lexer

struct token_type
    var pos = {0, 0}
    var type = null
    var data = null
end

function make_token(pos, type, data)
    var t = new token_type
    t.pos = pos
    --t.pos[0]
    t.type = type
    t.data = data
    return move(t)
end

struct lex_error
    var text = new string
    var pos = {0, 0}
end

class lexer
    var error_log = new array
    var data = null
    var pos = {0, 0, 0}
    function cursor_forward()
        ++pos[2]
        if pos[2] != data.size
            if data[pos[2]] == '\n'
                ++pos[1]
                pos[0] = 0
            else
                ++pos[0]
            end
        end
    end
    function error(str, pos)
        var err = new lex_error
        err.text = str
        err.pos = pos
        --err.pos[0]
        error_log.push_back(move(err))
    end
    function run(lexical, text)
        var lexical_set = new hash_set
        var output = new array
        var buff = new string
        var wpos = {0, 0}
        data = text
        while pos[2] != data.size
            var ch = data[pos[2]]
            if lexical_set.empty()
                var nbuff = to_string(ch)
                foreach it in lexical
                    if !it.second.match(nbuff).empty()
                        lexical_set.insert(it.first)
                    end
                end
                if !lexical_set.empty()
                    wpos = pos
                    buff = nbuff
                else
                    error("Unknown character \'" + nbuff + "\'", pos)
                end
                cursor_forward()
            else
                var nbuff = buff + ch
                var nset = new hash_set
                foreach it in lexical_set
                    if lexical[it].match(nbuff).empty()
                        nset.insert(it)
                    end
                end
                nset = hash_set.subtract(lexical_set, nset)
                if nset.empty()
                    if lexical_set.size > 1
                        if lexical_set.exist("err")
                            error("Unexpected input \"" + buff + "\"", pos)
                        else
                            error("Ambiguous lexical \"" + buff + "\"", pos)
                        end
                        lexical_set = new hash_set
                        continue
                    end
                    var rule = null
                    foreach it in lexical_set do rule = it
                    if rule != "ign"
                        output.push_back(make_token(wpos, rule, buff))
                    end
                    lexical_set = new hash_set
                else
                    lexical_set = nset
                    buff = nbuff
                    cursor_forward()
                end
            end
        end
        return output
    end
end

# Parser

struct syntax_impl
    var type = null
    var data = null
end

namespace syntax_type
@begin
    constant
        token  = 1,
        term   = 2,
        ref    = 3,
        repeat = 4,
        opt    = 5,
        cond   = 6
@end
end

function make_syntax(type, data)
    var s = new syntax_impl
    s.type = type
    s.data = data
    return move(s)
end

namespace syntax
    function token(data)
        return make_syntax(syntax_type.token, data)
    end
    function term(data)
        return make_syntax(syntax_type.term, data)
    end
    function ref(name)
        return make_syntax(syntax_type.ref, name)
    end
    # {...}
    function repeat(...args)
        return make_syntax(syntax_type.repeat, args)
    end
    # [...]
    function optional(...args)
        return make_syntax(syntax_type.opt, args)
    end
    # a | b | c... ==> {a}, {b}, {c}...
    function cond_or(...args)
        return make_syntax(syntax_type.cond, args)
    end
end

struct syntax_tree
    var root = new string
    var nodes = new array
end

struct parse_stage
    var product = new syntax_tree
    var cursor = 0
end

struct parse_error
    var cursor = 0
    var text = new string
    var pos = {0, 0}
end

struct parser
    # Error Reporting
    var error_log = new array
    var max_cursor = 0
    # Parsing
    var stack = new array
    var syn = null
    var lex = null
    # Logging
    var log_indent = 0
    var log = false
    # Parsing Stage
    function push_stage(root)
        var prev_cursor = 0
        if !stack.empty()
            prev_cursor = stack.front.cursor
        end
        stack.push_front(new parse_stage)
        stack.front.product.root = root
        stack.front.cursor = prev_cursor
    end
    function pop_stage()
        return stack.pop_front()
    end
    # Parsing Product
    function push(val)
        stack.front.product.nodes.push_back(val)
    end
    # Token Streams
    function cursor()
        return stack.front.cursor
    end
    function eof()
        return cursor() >= lex.size
    end
    function peek()
        if eof()
            throw runtime.exception("EOF")
        end
        return lex[cursor()]
    end
    function get()
        if eof()
            throw runtime.exception("EOF")
        end
        return lex[cursor()++]
    end
    # Error & Logs
    function error(str, pos)
        var err = new parse_error
        err.cursor = cursor()
        err.text = str
        err.pos = pos
        if err.cursor > max_cursor
            max_cursor = err.cursor
        end
        error_log.push_back(move(err))
    end
    # N: Error Level
    function get_log(n)
        var set = new hash_set
        var arr = new array
        foreach it in error_log
            if it.cursor >= max_cursor - n && !set.exist(it.text)
                set.insert(it.text)
                arr.push_back(it)
            end
        end
        return move(arr)
    end
    # SS: Stack Size
    # CP: Cursor Position
    function parse_log(txt)
        if log
            @begin
            system.out.print(
                "SS = " + stack.size + "\t" +
                "CP = " + cursor() + "\t"
            )
            @end
            foreach i in range(log_indent) do system.out.print("  ")
            system.out.println(txt)
        end
    end
    # Parsing Methods
    function accept()
        var new_cursor = cursor()
        var dat = pop_stage().product
        push(dat)
        cursor() = new_cursor
    end
    function merge()
        var new_cursor = cursor()
        var dat = pop_stage().product
        foreach it in dat.nodes do push(it)
        cursor() = new_cursor
    end
    # Return Values
    # 1: Success
    # 0: Failed
    #-1: End of Input
    function match_syntax(seq)
        foreach it in seq
            var result = this.match(it)
            if result != 1
                return result
            end
        end
        return 1
    end
    # Match:  Terminal Symbols
    # Deduct: Unstarred Nonterminals
    # Accept: Matching Successfully
    # Reject: Matching Failed, Rollback
    function match(it)
        if eof()
            return -1
        end
        switch it.type
            case syntax_type.token
                parse_log("Match  " + it.data)
                if peek().type == it.data
                    parse_log("Accept " + it.data)
                    push(get())
                else
                    parse_log("Reject " + it.data)
                    error("Unexpected Token \'" + peek().data + "\'", peek().pos)
                    return 0
                end
            end
            case syntax_type.term
                parse_log("Match  " + it.data)
                if peek().data == it.data
                    parse_log("Accept " + it.data)
                    push(get())
                else
                    parse_log("Reject " + it.data)
                    error("Unexpected Token \'" + peek().data + "\'", peek().pos)
                    return 0
                end
            end
            case syntax_type.ref
                push_stage(it.data)
                parse_log("Deduct " + it.data)
                ++log_indent
                if match_syntax(syn[it.data]) == 1
                    --log_indent
                    parse_log("Accept " + it.data)
                    accept()
                else
                    --log_indent
                    parse_log("Reject " + it.data)
                    pop_stage()
                    return 0
                end
            end
            case syntax_type.repeat
                loop
                    push_stage("repeat")
                    if match_syntax(it.data) != 1
                        pop_stage()
                        break
                    else
                        merge()
                    end
                end
            end
            case syntax_type.opt
                push_stage("optional")
                if match_syntax(it.data) == 1
                    merge()
                else
                    pop_stage()
                end
            end
            case syntax_type.cond
                var matched = false
                foreach seq in it.data
                    push_stage("cond_or")
                    if match_syntax(seq) == 1
                        matched = true
                        merge()
                        break
                    else
                        pop_stage()
                    end
                end
                if !matched
                    error("No matching syntax", peek().pos)
                    return 0
                end
            end
        end
        return 1
    end
    function run(grammar, lex_output)
        syn = grammar
        lex = lex_output
        push_stage("begin")
        return match_syntax(syn.begin) != 0 && eof()
    end
end

# Main Program

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
    "ign" : regex.build("^(\\s+|/|/\\*[^/]*(\\*/)?)$"),
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

var ifs = iostream.ifstream(context.cmd_args[1])
var code = new array
var data = new string

function print_header(txt)
    foreach i in range(txt.size) do system.out.print('#')
    system.out.println("")
    system.out.println(txt)
    foreach i in range(txt.size) do system.out.print('#')
    system.out.println("")
end

function print_error(err)
    foreach it in err
        system.out.print("File \"" + context.cmd_args[1] + "\", line " + it.pos[1] + ": ")
        system.out.println(it.text)
        system.out.println("> " + code[it.pos[1]])
        foreach i in range(it.pos[0] + 2) do system.out.print(' ')
        system.out.print("^")
        system.out.println("\n")
    end
end

while ifs.good()
    var line = ifs.getline()
    data += line + "\n"
    for i = 0, i < line.size, ++i
        if line[i] == '\t'
            line.assign(i, ' ')
        end
    end
    code.push_back(line)
end

print_header("Begin Lexical Analysis...")
var l = new lexer
var lex = l.run(cminus_lexical, data)

print_header("Lexer Output")
foreach it in lex do system.out.println("Type = " + it.type + "\tData = " + it.data + "\tPos = (" + it.pos[0] + ", " + it.pos[1] + ")")

function print_ast(indent, tree)
    if tree == null
        return
    end
    system.out.println(tree.root)
    foreach it in tree.nodes
        foreach i in range(indent + 2) do system.out.print(' ')
        system.out.print(tree.root + " -> ")
        if typeid it == typeid syntax_tree
            print_ast(indent + 2, it)
        end
        if typeid it == typeid token_type
            system.out.println("\"" + it.data + "\"")
        end
    end
end

var p = new parser
p.log = true

print_header("Begin Syntactic Analysis...")
var result = p.run(cminus_syntax, lex)

if result
    if !l.error_log.empty()
        print_header("Compilation Warning")
        print_error(l.error_log)
    end
    print_header("Parser Output")
    var indent = 0
    foreach ss in p.stack do print_ast(indent, ss.product)
else
    print_header("Compilation Error")
    var err = {(l.error_log)..., (p.get_log(0))...}
    err.sort([](lhs, rhs)->lhs.pos[1] < rhs.pos[1])
    print_error(err)
end