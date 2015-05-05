{ first, map, fold, zip } = require \prelude-ls
{ atom, list, string } = require \./ast

is-expression = ->
  it.type?match /Expression$/ or it.type in <[ Literal Identifier ]>

statementify = (es-ast-node) ->
  if es-ast-node |> is-expression
    type : \ExpressionStatement expression : es-ast-node
  else es-ast-node

root-macro-table = do

  chained-binary-expr = (type, operator) ->
    macro = (compile, ...args) ->
      | args.length is 1 => compile args.0
      | args.length is 2
        type : type
        operator : operator
        left  : compile args.0
        right : compile args.1
      | arguments.length > 2
        [ head, ...rest ] = args
        macro do
          compile
          macro compile, compile head
          macro.apply null ([ compile ] ++ rest)
      | otherwise =>
        throw Error "binary expression macro `#operator` unexpectedly called \
                     with no arguments"

  unary-expr = (operator) ->
    (compile, arg) ->
      type : \UnaryExpression
      operator : operator
      prefix : true
      argument : compile arg

  n-ary-expr = (operator) ->
    n-ary = chained-binary-expr \BinaryExpression operator
    unary = unary-expr operator
    (compile, ...args) ->
      ( switch args.length | 0 => null
                           | 1 => unary
                           | _ => n-ary
      ).apply null arguments

  update-expression = (operator, {type}) ->
    unless operator in <[ ++ -- ]>
      throw Error "Illegal update expression operator #operator"
    is-prefix = ( type is \prefix )
    (compile, ...arg) ->
      if arg.length isnt 1
        throw Error "Expected `++` expression to get exactly 1 argument but \
                     got #{arguments.length}"
      type : \UpdateExpression
      operator : operator
      prefix : is-prefix
      argument : compile arg.0

  parent : null
  contents :
    \+ : n-ary-expr \+
    \- : n-ary-expr \-
    \* : chained-binary-expr \BinaryExpression \*
    \/ : chained-binary-expr \BinaryExpression \/
    \% : chained-binary-expr \BinaryExpression \%

    \++  : update-expression \++ type : \prefix # Synonym for below
    \++_ : update-expression \++ type : \prefix
    \_++ : update-expression \++ type : \suffix
    \--  : update-expression \-- type : \prefix # Synonym for below
    \--_ : update-expression \-- type : \prefix
    \_-- : update-expression \-- type : \suffix

    \and : chained-binary-expr \LogicalExpression \&&
    \or  : chained-binary-expr \LogicalExpression \||
    \not : unary-expr \!

    \< : chained-binary-expr \BinaryExpression \<
    \> : chained-binary-expr \BinaryExpression \>
    \<= : chained-binary-expr \BinaryExpression \<=
    \>= : chained-binary-expr \BinaryExpression \>=

    \delete : unary-expr \delete
    \typeof : unary-expr \typeof
    \void   : unary-expr \void
    \instanceof : chained-binary-expr \BinaryExpression \instanceof
    \in : chained-binary-expr \BinaryExpression \in

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

    \:=   : chained-binary-expr \AssignmentExpression \=
    \+=   : chained-binary-expr \AssignmentExpression \+=
    \-=   : chained-binary-expr \AssignmentExpression \-=
    \*=   : chained-binary-expr \AssignmentExpression \*=
    \%=   : chained-binary-expr \AssignmentExpression \%=
    \>>=  : chained-binary-expr \AssignmentExpression \>>=
    \<<=  : chained-binary-expr \AssignmentExpression \<<=
    \>>>= : chained-binary-expr \AssignmentExpression \>>>=
    \&=   : chained-binary-expr \AssignmentExpression \&=
    \|=   : chained-binary-expr \AssignmentExpression \|=
    \^=   : chained-binary-expr \AssignmentExpression \^=

    \array : (compile, ...elements) ->
      type : \ArrayExpression
      elements : elements.map compile

    \object : (compile, ...args) ->

      if args.length % 2 isnt 0
        throw Error "Expected even number of arguments to object macro, but \
                     got #{args.length}"

      keys-values = do # [ [k1, v1], [k2, v2] , ... ]
        keys = [] ; values = []
        args.for-each (a, i) -> (if i % 2 then values else keys).push a
        zip keys, values

      type : \ObjectExpression
      properties :
        keys-values.map ([k, v]) ->
          type : \Property kind : \init
          value : compile v
          key : compile k

    \= : do
      declaration = (compile, ...args) ->
        if args.length isnt 2
          throw Error "Expected variable declaration to get 2 arguments, \
                       but got #{arguments.length}."
        type : \VariableDeclaration
        kind : "var"
        declarations : [
          type : \VariableDeclarator
          id : compile args.0
          init : compile args.1
        ]

      declaration

    \if : (compile, test, consequent, alternate) ->
      type : \IfStatement
      test       : compile test
      consequent : statementify compile consequent
      alternate  : statementify compile alternate

    \?: : (compile, test, consequent, alternate) ->
      type : \ConditionalExpression
      test       : compile test
      consequent : compile consequent
      alternate  : compile alternate

    \while : (compile, test, ...body) ->
      type : \WhileStatement
      test : compile test
      body :
        type : \BlockStatement
        body : body.map compile .filter (isnt null) .map statementify

    \for : (compile, init, test, update, ...body) ->
      type : \ForStatement
      init : compile init
      test : compile test
      update : compile update
      body :
        type : \BlockStatement
        body : body.map compile .filter (isnt null) .map statementify

    \break : ->
      type : \BreakStatement
      label : null # TODO?
    \continue : ->
      type : \ContinueStatement
      label : null # TODO?

    \return : (compile, arg) ->
      type : \ReturnStatement
      argument : compile arg

    \. : do

      is-computed-property = (ast-node) ->
        switch ast-node.type
        | \MemberExpression =>
          is-computed-property ast-node.object
        | \Identifier => false
        | otherwise => true

      dot = (compile, ...args) ->
        | args.length is 1 => compile args.0
        | args.length is 2
          property-compiled = compile args.1
          type : \MemberExpression
          computed : is-computed-property property-compiled
          object   : compile args.0
          property : property-compiled
        | arguments.length > 2
          [ ...initial, last ] = args
          dot do
            compile
            dot.apply null ([ compile ] ++ initial)
            dot compile, compile last
        | otherwise =>
          throw Error "dot called with no arguments"
    \lambda : do
      compile-function-body = (compile, nodes) ->

        nodes = nodes
          .map compile
          .filter (isnt null) # in case of macros

        last-node = nodes.pop!
        # Automatically return last node if it's an expression
        nodes.push if is-expression last-node
          type : \ReturnStatement
          argument : last-node
        else last-node

        type : \BlockStatement
        body : nodes.map statementify

      lambda = (compile, params, ...body) ->
        type : \FunctionExpression
        id : null
        params : params.contents!map compile
        body : compile-function-body compile, body
      lambda

    \quote : do
      quote = (compile, ...args) ->
        if args.length > 1
          throw Error "Attempted to quote >1 values, not inside list"
        if args.0
          args.0.as-sm!
        else
          list!as-sm!

    \quasiquote : do

      # Compile an AST node which is part of the body of a quasiquote.  This
      # means we have to resolve lists which first atom is `unquote` or
      # `unquote-splicing` into either an array of values or an identifier to
      # an array of values.
      qq-body = (compile, ast) ->
        recurse-on = (ast-list) ->
          type : \ArrayExpression
          elements : ast-list.contents!
                     |> map qq-body compile, _
                     |> fold (++), []

        unquote = ->
          # Unquoting a list should compile to whatever the list
          [ compile it ]
        unquote-splicing = ->
          # The returned thing should be an array anyway.
          compile it

        if ast instanceof list
          [head, ...rest] = ast.contents!
          if not head? then [ quote compile, list [] ] # empty list
          else if head instanceof atom
            switch head.text!
            | \unquote =>
              if rest.length isnt 1
                throw Error "Expected 1 argument to unquote but got
                             #{rest.length}"
              unquote rest.0
            | \unquote-splicing =>
              if rest.length isnt 1
                throw Error "Expected 1 argument to unquoteSplicing but got
                             #{rest.length}"
              unquote-splicing rest.0
            | otherwise => [ recurse-on ast ]
          else # head wasn't an atom
            [ recurse-on ast ]
        else [ ast.as-sm! ]

      qq = (compile, ...args) ->

        # Each argument (in args) is an atom passed to the quasiquote macro.
        if args.length > 1
          throw Error "Attempted to quasiquote >1 values, not inside list"

        arg = args.0

        if arg instanceof list
          concattable-args = arg.contents!

            # Each argument is resolved by quasiquote's rules.
            |> map qq-body compile, _

            # Each quasiquote-body resolution produces SpiderMonkey AST
            # compiled values, but if there are many of them, it'll produce an
            # array.  We'll convert these into ArrayExpressions so the results
            # are effectively still compiled values.
            |> map ->
              if typeof! it is \Array
                type : \ArrayExpression
                elements : it
              else it

          # Now each should be an array (or a literal that was
          # `unquote-splicing`ed) so they can be assumed to be good for
          # `Array::concat`.

          # We then construct a call to Array::concat with each of the now
          # quasiquote-resolved and compiled things as arguments.  That makes
          # this macro produce a concatenation of the quasiquote-resolved
          # arguments.

          type : \CallExpression
          callee :
            type : \MemberExpression
            object :
              type : \MemberExpression
              object :
                type : \Identifier
                name : \Array
              property :
                type : \Identifier
                name : \prototype
            property :
              type : \Identifer
              name : \concat
          arguments : concattable-args
        else quote compile, arg

module.exports = (ast) ->

  convert = ->
    switch it.type
    | \string => string it.text
    | \atom   => atom it.text
    | \list   => list it.contents.map convert

  statements = ast.contents.map convert
  type : \Program
  body : statements
    .map (.compile root-macro-table)
    .filter (isnt null) # macro definitions emit nothing, hence this
    .map statementify
