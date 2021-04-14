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
            if lexical_set.empty()
                if ch == '\n'
                    ++pos[1]
                    pos[0] = 0
                end
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
        return make_syntax(syntax_type.repeat, args)
    end
    # a | b | c... ==> {a}, {b}, {c}...
    function cond_or(...args)
        return make_syntax(syntax_type.repeat, args)
    end
end

@begin
var tiny_syntax = {
    # Beginning of Parsing
    "program" : {syntax.ref("stmts")},
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
}
@end

struct parser
    var stack = new array
    function run(grammar, lex_output)
        
    end
end

var ifs = iostream.ifstream(context.cmd_args[1])
var data = new string
while ifs.good()
    data += ifs.getline() + "\n"
end
var lex = (new lexer).run(tiny_lexical, data)
foreach it in lex
    system.out.println("Type: " + it.type + ", Data: " + it.data)
end