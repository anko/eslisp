# Takes in an S-expression in the internal format.
# Puts out a corresponding SpiderMonkey AST.

{ first } = require \prelude-ls
es-generate = (require \escodegen).generate _

find-macro = (macro-table, name) ->
  switch macro-table.contents[name]
  | null => null                          # deliberately masks parent; fail
  | undefined =>                          # not defined at this level
    if macro-table.parent
      find-macro macro-table.parent, name # ask parent
    else return null                      # no parent to ask; fail
  | otherwise => that                     # defined at this level; succeed

compile = (ast, parent-macro-table) ->

  macro-table = contents : {}, parent : parent-macro-table

  define-macro = (
    macro-args-array,
    macro-table-for-compiling,
    macro-table-to-add-to
  ) ->
    # To make user-defined macros simpler to write, they encode s-expressions
    # as nested arrays.  This means we have to take their return values and
    # convert them to the internal nested-objects form before compiling.
    to-internal-ast-form = (user-macro-ast-form) ->

      u = user-macro-ast-form
      switch typeof! u
      | \Array =>
        type : \list
        contents : u.map to-internal-ast-form
      | \Object =>
        type : \atom
        text : u.text
      | \String => fallthrough
      | \Number =>
        type : \Literal
        value : u

    [ name, ...function-args ] = macro-args-array

    es-ast-macro-fun = compile do
      * type : \list
        contents : [ { type : \atom text : \lambda } ] ++ function-args
      * macro-table-for-compiling

    userspace-macro = eval ("(" + (es-generate es-ast-macro-fun) + ")")
    # need those parentheses to get eval to accept a function expression

    compilerspace-macro = userspace-macro >> to-internal-ast-form

    console.log "adding macro " name.text, compilerspace-macro
    macro-table-to-add-to.contents[name.text] = compilerspace-macro

    # TODO lots of error checking

    return null

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
    if ast.contents.length is 0 then type : \EmptyStatement
    else
      { contents:[ head, ...rest ]:contents } = ast
      if head.type is \atom and head.text is \macro
        define-macro rest, macro-table, macro-table.parent
        return null
      if find-macro macro-table, head.text

        console.log "Found macro #{head.text}"
        # This is a little subtle: The macro table is passed as `this` in the
        # function application, to avoid shifting parameters when passing
        # them to the macro.
        m = that.apply macro-table, rest

        console.log "macro result" m
        compile m, macro-table
      else

        # TODO could do a compile-time check here for whether the callee is
        # ofa sensible type (e.g. error when calling a string)

        type : \CallExpression
        callee : compile head, macro-table
        arguments : rest .map -> compile it, macro-table

  | otherwise => ast

statementify = (es-ast-node) ->
  is-expression = -> it.type.match /Expression$/ or it.type is \Literal
  if es-ast-node |> is-expression
    type : \ExpressionStatement expression : es-ast-node
  else es-ast-node

root-macro-table = do

  chained-binary-expr = (type, operator) ->
    macro = ->
      | arguments.length is 1
        compile arguments.0, this
      | arguments.length is 2
        type : type
        operator : operator
        left  : compile arguments.0, this
        right : compile arguments.1, this
      | arguments.length > 2
        [ head, ...rest ] = arguments
        macro do
          compile head, this
          macro.apply this, rest.map -> compile it, this
      | otherwise =>
        throw Error "binary expression macro `#operator` unexpectedly called \
                     with no arguments"
    macro

  unary-expr = (operator) ->
    (arg) ->
      type : \UnaryExpression
      operator : operator
      prefix : true
      argument :
        compile arg, this

  n-ary-expr = (operator) ->
    n-ary = chained-binary-expr \BinaryExpression operator
    unary = unary-expr operator
    ->
      ( switch arguments.length | 0 => null # TODO
                                | 1 => unary
                                | _ => n-ary
      ).apply this, arguments

  update-expression = (operator, {type}) ->
    unless operator in <[ ++ -- ]>
      throw Error "Illegal update expression operator #operator"
    is-prefix = ( type is \prefix )
    (arg) ->
      if arguments.length isnt 1
        throw Error "Expected `++` expression to get exactly 1 argument but \
                     got #{arguments.length}"
      type : \UpdateExpression
      operator : operator
      prefix : is-prefix
      argument : compile arg, this

  parent : null
  contents :
    \+ : n-ary-expr \+
    \- : n-ary-expr \-
    \* : chained-binary-expr \BinaryExpression \*
    \/ : chained-binary-expr \BinaryExpression \/

    \++  : update-expression \++ type : \prefix # Synonym for below
    \++_ : update-expression \++ type : \prefix
    \_++ : update-expression \++ type : \suffix
    \--  : update-expression \-- type : \prefix # Synonym for below
    \--_ : update-expression \-- type : \prefix
    \_-- : update-expression \-- type : \suffix

    \and : chained-binary-expr \LogicalExpression \&&
    \or  : chained-binary-expr \LogicalExpression \||
    \not : unary-expr \!

    \delete : unary-expr \delete
    \typeof : unary-expr \typeof
    \void   : unary-expr \void

    \& : chained-binary-expr \BinaryExpression \&
    \| : chained-binary-expr \BinaryExpression \|
    \^ : chained-binary-expr \BinaryExpression \^
    \>>  : chained-binary-expr \BinaryExpression \>>
    \<<  : chained-binary-expr \BinaryExpression \<<
    \>>> : chained-binary-expr \BinaryExpression \>>>
    \~ : unary-expr \~

    \==  : chained-binary-expr \BinaryExpression \==
    \!=  : chained-binary-expr \BinaryExpression \!=
    \=== : chained-binary-expr \BinaryExpression \===
    \!== : chained-binary-expr \BinaryExpression \!==

    \:= : do
      equals = (name, value) ->
        type : \AssignmentExpression
        operator : "="
        left : compile name, this
        right : compile value, this
      equals

    \= : do
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

      declaration

    \if : do
      if-statement = (test, consequent, alternate) ->
        type : \IfStatement
        test       : compile test, this
        consequent : statementify compile consequent, this
        alternate  : statementify compile alternate, this
      if-statement

    \?: : do
      ternary = (test, consequent, alternate) ->
        type : \ConditionalExpression
        test       : compile test, this
        consequent : compile consequent, this
        alternate  : compile alternate, this
      ternary

    \. : do
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
      dot

    \lambda : do
      compile-function-body = ([...nodes,last-node], macro-table) ->
        nodes .= map -> compile it, macro-table
        last-node =
          type : \ReturnStatement
          argument : compile last-node, macro-table
        nodes.push last-node
        console.error nodes
        type : \BlockStatement
        body : nodes.map statementify

      lambda = (params, ...body) ->
        macro-table = this
        type : \FunctionExpression
        id : null
        params : params.contents.map -> compile it, macro-table
        body : compile-function-body body, macro-table
      lambda

    \quote : do
      quote-one = (ast) ->
        switch ast.type
        | \atom =>
          if ast.text.match /\d+(\.\d+)?/ # looks like a number
            type  : \Literal
            value : Number ast.text
            raw   : ast.text
          else
            type : \ObjectExpression
            properties :
              * type  : \Property
                key   : { type : \Literal value : \type }
                value : { type : \Literal value : \atom }
              * type  : \Property
                key   : { type : \Literal value : \text }
                value : { type : \Literal value : ast.text }
        | \string =>
          type : \Literal
          value : ast.text
          raw : '"' + ast.text + '"'
        | \list =>
          type : \ArrayExpression
          elements : ast.contents.map quote-one

      quote = (...args) ->
        macro-table = this

        type : \ArrayExpression
        elements : args.map quote-one

module.exports = (ast) ->
  statements = ast.contents
  type : \Program
  body : statements
    .map -> compile it, root-macro-table
    .filter (isnt null) # macro definitions emit nothing, hence this
    .map statementify
