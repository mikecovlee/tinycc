if a > 0
    system.out.println("a")
else
    if a == 0 &&
         b != 0 &&!
           c >= 0
    system.out.println("b")
else
    system.out.println("c"); {syntax.cond_or(
        {syntax.term("("), syntax.ref("expr"), syntax.term(")")},
        {syntax.ref("object"), syntax.optional(syntax.ref("factor_s"))},
        {syntax.term("{"), syntax.optional(syntax.ref("args")), syntax.term("}")},
        {syntax.token("str")},
        {syntax.token("num")}
    )}
    a.b(c[0], d.e())["Hello"].world()
    *(a->hello)("World!").text
end
