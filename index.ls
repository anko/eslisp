#!/usr/bin/env lsc

es = require \escodegen
lex = require \./lex.ls
parse = require \./parse.ls
concat = require \concat-stream

process.stdin .pipe lex! .pipe concat (tokens) ->
  tree = parse tokens
  console.log tree
  console.log es.generate tree


#ast |> es.generate |> console.log

# Read a list
# Read an atom or a list
#   If the first element is an atom, check if it's in the environment
#   If it's not in the environment
#     If it's not a macro definition, error out
#     If it's a macro definition, eval it and add it to the compilation env
#   If it is in the compilation function env, eval args and call
#   If it is in the compilation fexpr env, don't eval args and call

/*

(expr-stmt
  (call-expr (member-expr (ident console) (ident log))
             (literal 42)))

((. console log) 42)

(= sfx (= construct
  (fun (buffer volume)
       (do (= play (fun ()

expr =  do
  type : \ExpressionStatement
  expression :
    type : "CallExpression"
    callee :
      type : \MemberExpression
      object :
        type : \Identifier
        name : "console"
      property :
        type : \Identifier
        name : "log"
    arguments :
      * type : \Literal
        value : 42
        ...

ast.body.push expr

console.log expr

console.log es.generate ast
