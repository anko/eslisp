# Takes in an S-expression.
# Puts out a corresponding SpiderMonkey AST.

{
  lists-to-obj,
  compact,
  Obj : compact : obj-compact
  first
  even
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
      if ast.contents.length is 0
        type : \EmptyStatement
      else
        { contents:[ head, ...rest ]:contents } = ast
        switch head.text
        | \quote =>
          rest.0
        | \lambda =>
          [ params, ...body ] = rest
          type : \FunctionExpression
          id : null
          params : params.contents.map -> compile it, macro-table
          body :
            compile-function-body body
        | otherwise => # must be a function or macro call then
          if find-macro macro-table, head.text

            console.log "Found macro #{head.text}"
            # This is a little subtle: The macro table is passed as `this` in the
            # function application, to avoid shifting parameters when passing
            # them to the macro.
            m = that.apply macro-table, rest

            console.log "macro result" m
            compile m
          else

            # TODO could do a compile-time check here for whether the callee is
            # ofa sensible type (e.g. error when calling a string)

            type : \CallExpression
            callee : compile head, macro-table
            arguments : rest .map -> compile it, macro-table

    | otherwise =>
      ast

  quote = (thing) ->
    type : \list
    contents :
      * type : \atom text : \quote
      * thing


  statementify = (es-ast-node) ->
    if es-ast-node.type .match /Expression$/                # if expression
      type : \ExpressionStatement expression : es-ast-node  # wrap it
    else es-ast-node                                        # else OK as-is

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

      ":=" : do
        equals = (name, value) ->
          type : \AssignmentExpression
          operator : "="
          left : compile name, this
          right : compile value, this
        equals >> quote

      "=" : do
        declaration = ->
          if arguments.length isnt 2
            throw Error "Expected variable declaration to get 2 arguments, \
                         but got #{arguments.length}."
          type : \VariableDeclaration
          kind : "var"
          declarations : [
            type : \VariableDeclarator
            id : compile arguments.0, this
            init : compile arguments.1, this
          ]

        declaration >> quote

      "if" : do
        if-statement = (test, consequent, alternate) ->
          type : \IfStatement
          test       : compile test, this
          consequent : statementify compile consequent, this
          alternate  : statementify compile alternate, this
        if-statement >> quote

      "." : do
        dot = ->
          | arguments.length is 1 # dotting just one thing makes no sense?
            compile (first arguments), this # eh whatever, just return it
          | arguments.length is 2
            type : \MemberExpression
            computed : false
            object   : compile arguments.0, this
            property : compile arguments.1, this
          | arguments.length > 2
            [ ...initial, last ] = arguments
            plus do
              dot.apply this, initial.map -> compile it, this
              compile last, this

        dot >> quote

  type : \Program
  body : [ statementify compile ast, root-macro-table ]
