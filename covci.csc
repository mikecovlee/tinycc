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
    var lexical = null
    var lexical_set = new hash_set
    var output = new array
    function run(data)
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
    end
end

var ifs = iostream.ifstream(context.cmd_args[1])
var data = new string
while ifs.good()
    data += ifs.getline() + "\n"
end
var lex = new lexer
lex.lexical = tiny_lexical
lex.run(data)
foreach it in lex.output
    system.out.println("Type: " + it.type + ", Data: " + it.data)
end