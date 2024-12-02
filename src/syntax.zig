pub const Kind = enum {
    kw_auto,
    kw_extrn,
    kw_if,
    kw_else,
    kw_for,
    kw_while,
    kw_repeat,
    kw_switch,
    kw_do,
    kw_return,
    kw_break,
    kw_goto,
    kw_next,
    kw_case,
    kw_default,

    @"~",
    @"}",
    @"||",
    @"|=",
    @"|",
    @"{",
    @"^=",
    @"^",
    @"]",
    @"[",
    @"@",
    @"?",
    @">>=",
    @">>",
    @">=",
    @">",
    @"==",
    @"=",
    @"<=",
    @"<<=",
    @"<<",
    @"<",
    @";",
    @"::",
    @":",
    @"/=",
    @"/",
    @"-=",
    @"--",
    @"-",
    @",",
    @"+=",
    @"++",
    @"+",
    @"*=",
    @"*",
    @")",
    @"(",
    @"&=",
    @"&&",
    @"&",
    @"%=",
    @"%",
    @"#>=",
    @"#>",
    @"#==",
    @"#<=",
    @"#<",
    @"#/",
    @"#-",
    @"#+",
    @"#*",
    @"##",
    @"#!=",
    @"#",
    @"!=",
    @"!",

    identifier,
    number,
    string_literal,
    character_literal,
    bcd_literal,

    document,
    global_declaration,
    vector_size,
    vector_initializer,
    function,
    function_parameters,
    null_statement,
    compound_statement,
    auto,
    extrn,
    @"if",
    @"while",
    expression_statement,
    variable,
    parenthesized_expression,
    function_call,
    arguments,
    prefix_operation,
    postfix_operation,
    infix_operation,
    rhs,

    trivia,
    @"error",
    eof,
};
