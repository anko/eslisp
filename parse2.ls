# Takes in an S-expression.
# Puts out a corresponding SpiderMonkey AST.

{
  lists-to-obj,
  compact,
  Obj : compact : obj-compact
  first
} = require \prelude-ls
es-generate = (require \escodegen).generate _

find-macro = (macro-table, name) ->
  switch macro-table.contents[name]
  | null => null                          # deliberately masks parent; fail
  | undefined =>                          # not defined at this level
    if macro-table.parent
      find-macro macro-table.parent, name # ask parent
    else return null                      # no parent to ask; fail
  | otherwise => that                     # defined at this level; succeed

module.exports = (ast) ->

  es-evaluate = (es-ast) ->
    eval es-generate es-ast

  compile = (ast, parent-macro-table) ->

    console.log ast

    macro-table = contents : {}, parent : parent-macro-table

    compile-function-body = ([...nodes,last-node]) ->
      nodes .= map -> compile it, macro-table
      last-node =
        type : \ReturnStatement
        argument : compile last-node, macro-table
      nodes.push last-node
      #return nodes
      return
        type : \BlockStatement
        body : nodes

    switch ast.type
    | \atom =>
      if ast.text.match /\d+(\.\d+)?/ # looks like a number
        type  : \Literal
        value : Number ast.text
        raw   : ast.text
      else
        type : \Identifier
        name : ast.text
    | \string =>
      type : \Literal
      value : ast.text
      raw : '"' + ast.text + '"'
    | \list =>
      { contents:[ head, ...rest ]:contents } = ast
      switch head.text
      | \quote =>
        rest.0
      | \do =>
      | \if =>
      | \lambda =>
        [ params, ...body ] = rest
        type : \FunctionExpression
        id : null
        params : params.contents.map -> compile it, macro-table
        body :
          compile-function-body body
      | otherwise => # must be a function or macro call then
        if find-macro macro-table, head.text

          # This is a little subtle: The macro table is passed as `this` in the
          # function application, to avoid shifting parameters when passing
          # them to the macro.
          m = that.apply macro-table, rest

          console.log "macro result" m
          compile m
        else
          console.error "function call"
          ...
    | otherwise =>
      ast

  quote = (thing) ->
    type : \list
    contents :
      * type : \atom text : \quote
      * thing

  root-macro-table =
    parent : null
    contents :
      "+" : do
        plus = ->
          | arguments.length is 1
            compile (first arguments), this
          | arguments.length is 2
            type : \BinaryExpression
            operator : "+"
            left  : compile arguments.0, this
            right : compile arguments.1, this
          | arguments.length > 2
            [ head, ...rest ] = arguments
            plus do
              compile head, this
              plus.apply this, rest.map -> compile it, this
          | otherwise =>
            ... # TODO return (+), as in plus as a function

        plus >> quote

  type : \Program body : [
    type : \ExpressionStatement # TODO generalise
    expression : compile ast, root-macro-table
  ]

