# Covariant Compiler Interpreter

import regex

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
var cminus_lexical = {
    "id"  : regex.build("^[A-Za-z_]\\w*$"),
    "num" : regex.build("^[0-9]+$"),
    "sig" : regex.build("^(\\+|-|\\*|/|<|<=|>|>=|=|~=?|==|;|,|\\(|\\)|\\[|\\]|\\{|\\})$"),
    "ign" : regex.build("^(\\s+|/|/\\*[^/]*(\\*/)?)$"),
    "err" : regex.build("^~$")
}.to_hash_map()
@end

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

class lexer
    function run(lexical, data)
        var lexical_set = new hash_set
        var output = new array
        var buff = new string
        var pos = {0, 0}
        for i = 0, i < data.size, null
            var ch = data[i]
            if ch == '\n'
                ++pos[1]
                pos[0] = 0
            end
            if lexical_set.empty()
                var nbuff = to_string(ch)
                foreach it in lexical
                    if !it.second.match(nbuff).empty()
                        lexical_set.insert(it.first)
                    end
                end
                if !lexical_set.empty()
                    buff = nbuff
                else
                    system.out.println("Unknown Character: " + nbuff)
                end
                ++pos[0]
                ++i
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
                            system.out.println("Unexpected Input: " + buff)
                        else
                            system.out.println("Ambiguous Lexical: " + buff)
                        end
                        lexical_set = new hash_set
                        continue
                    end
                    var rule = null
                    foreach it in lexical_set do rule = it
                    if rule != "ign"
                        output.push_back(make_token(pos, rule, buff))
                    end
                    lexical_set = new hash_set
                else
                    lexical_set = nset
                    buff = nbuff
                    ++pos[0]
                    ++i
                end
            end
        end
        return output
    end
end

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

struct parse_stage
    var cursor = 0
    var product = new array
    var error = new array
end

struct syntax_tree
    var root = new string
    var nodes = new array
end

struct parser
    var stack = new array
    var log_indent = 0
    var log = false
    var syn = null
    var lex = null
    # Parsing Stage
    function push_stage()
        var prev_cursor = 0
        if !stack.empty()
            prev_cursor = stack.front.cursor
        end
        stack.push_front(new parse_stage)
        stack.front.cursor = prev_cursor
    end
    function pop_stage()
        return stack.pop_front()
    end
    # Parsing Product
    function push(val)
        stack.front.product.push_back(val)
    end
    function pop()
        return stack.front.product.pop_front()
    end
    function top()
        return stack.front.product
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
        stack.front.error.push_back(str : pos)
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
        switch it.type
            case syntax_type.token
                parse_log("Match  " + it.data)
                if eof()
                    return -1
                end
                if peek().type == it.data
                    parse_log("Accept " + it.data)
                    push(get())
                else
                    parse_log("Reject " + it.data)
                    error("Unexpected Lexical Token, expected " + it.data, peek().pos)
                    return 0
                end
            end
            case syntax_type.term
                parse_log("Match  " + it.data)
                if eof()
                    return -1
                end
                if peek().data == it.data
                    parse_log("Accept " + it.data)
                    push(get())
                else
                    parse_log("Reject " + it.data)
                    error("Unexpected Terminal Symbol, expected " + it.data, peek().pos)
                    return 0
                end
            end
            case syntax_type.ref
                parse_log("Deduct " + it.data)
                ++log_indent
                push_stage()
                if match_syntax(syn[it.data]) == 1
                    --log_indent
                    parse_log("Accept " + it.data)
                    accept()
                else
                    --log_indent
                    parse_log("Reject " + it.data)
                    error("Deduction Failed: " + it.data, peek().pos)
                    pop_stage()
                    return 0
                end
            end
            case syntax_type.repeat
                loop
                    if match_syntax(it.data) != 1
                        break
                    end
                end
            end
            case syntax_type.opt
                match_syntax(it.data)
            end
            case syntax_type.cond
                var matched = false
                foreach seq in it.data
                    if match_syntax(seq) == 1
                        matched = true
                        break
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
        push_stage()
        return match_syntax(syn.begin) != 0
    end
end

var ifs = iostream.ifstream(context.cmd_args[1])
var code = new array
var data = new string
while ifs.good()
    var line = ifs.getline()
    data += line + "\n"
    code.push_back(line)
end

function print_header(txt)
    foreach i in range(txt.size) do system.out.print('#')
    system.out.println("")
    system.out.println(txt)
    foreach i in range(txt.size) do system.out.print('#')
    system.out.println("")
end

print_header("Begin Lexical Analysis...")
var lex = (new lexer).run(tiny_lexical, data)

print_header("Lexical Analysis Results")
foreach it in lex do system.out.println("Type = " + it.type + "\tData = " + it.data + "\tPos = (" + it.pos[0] + ", " + it.pos[1] + ")")

function dfs(indent, t)
    if t == null
        return
    end
    if typeid t == typeid array
        if t.size == 1
            dfs(indent, t[0])
        else
            foreach it in t do dfs(indent + 1, it)
        end
    else
        foreach i in range(indent) do system.out.print(' ')
        system.out.println(t.data)
    end
end

var p = new parser
p.log = true

print_header("Begin Parsing...")
var result = p.run(tiny_syntax, lex)

print_header("Parsing Results")

if result
    var indent = 0
    foreach ss in p.stack
        foreach it in ss.product do dfs(indent, it)
    end
else
    foreach it in p.stack.front.error
        system.out.println(it.first)
        system.out.println("\t" + code[it.second[1]])
        system.out.print("\t")
        foreach i in range(it.second[0]) do system.out.print(' ')
        system.out.print("^")
        system.out.println("\n")
    end
end