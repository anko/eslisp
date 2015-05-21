{ first, map, fold, zip, concat-map } = require \prelude-ls
{ atom, list, string } = require \./ast

is-expression = ->
  it.type?match /Expression$/ or it.type in <[ Literal Identifier ]>

statementify = (es-ast-node) ->
  if es-ast-node |> is-expression
    type : \ExpressionStatement expression : es-ast-node
  else es-ast-node

root-macro-table = do

  chained-binary-expr = (type, operator) ->
    macro = (env, ...args) ->
      | args.length is 1 => env.compile args.0
      | args.length is 2
        type : type
        operator : operator
        left  : env.compile args.0
        right : env.compile args.1
      | arguments.length > 2
        [ head, ...rest ] = args
        macro do
          env
          macro env, env.compile head
          macro.apply null ([ env ] ++ rest)
      | otherwise =>
        throw Error "binary expression macro `#operator` unexpectedly called \
                     with no arguments"

  unary-expr = (operator) ->
    ({ compile }, arg) ->
      type : \UnaryExpression
      operator : operator
      prefix : true
      argument : compile arg

  n-ary-expr = (operator) ->
    n-ary = chained-binary-expr \BinaryExpression operator
    unary = unary-expr operator
    ({compile}, ...args) ->
      ( switch args.length | 0 => null
                           | 1 => unary
                           | _ => n-ary
      ).apply null arguments

  update-expression = (operator, {type}) ->
    unless operator in <[ ++ -- ]>
      throw Error "Illegal update expression operator #operator"
    is-prefix = ( type is \prefix )
    ({ compile }, ...arg) ->
      if arg.length isnt 1
        throw Error "Expected `++` expression to get exactly 1 argument but \
                     got #{arguments.length}"
      type : \UpdateExpression
      operator : operator
      prefix : is-prefix
      argument : compile arg.0

  # This is only used to let macros return multiple statements, in a way
  # detectable as different from other return types with an
  # `instanceof`-check.
  class multiple-statements
    (@statements) ~>

  compile-to-function = (env, function-args) ->

    # function-args is the forms that go after the `lambda` keyword, so
    # including parameter list and function body.

    es-ast = env.compile list ([ atom \lambda ] ++ function-args)

    userspace-function = do
      let (evaluate = -> it |> env.compile |> env.compile-to-js |> eval)
        let (multireturn = (...args) -> multiple-statements args)
          eval "(#{env.compile-to-js es-ast})"

  import-macro = (env, name, func) ->

    # macro function form → internal compiler-form
    #
    # To make user-defined macros simpler to write, they may return just plain
    # JS values, which we'll read back here as AST nodes.  This makes macros
    # easier to write and a little more tolerant of silliness.
    convert = (ast) ->
      if ast instanceof [ string, atom ] then return ast
      if ast instanceof list then return list ast.contents!map convert
      if ast instanceof multiple-statements then return ast.statements.map convert
      switch typeof! ast
      # Arrays represent lists
      | \Array  => list ast.map convert
      # Objects are turned into lists too
      | \Object =>
        [ keys, values ] = obj-to-lists ast
        keys   .= map convert
        values .= map convert
        keys-values = zip keys, values
        list ([ \object ] ++ keys-values)
      | \String => string ast
      | \Number => atom ("" + ast)
      # Undefined and null represent nothing
      | \Undefined => fallthrough
      | \Null      => null
      # Everything else is an error
      | otherwise =>
        throw Error "Unexpected return type #that"

    compilerspace-macro = ({compile, compile-many}, ...args) ->
      args .= map ->
        if it instanceof list
          it.contents!
        else it
      userspace-macro-result = func.apply null, args

      internal-ast-form = convert userspace-macro-result

      return switch
      | internal-ast-form is null => null
      | typeof! internal-ast-form is \Array => compile-many internal-ast-form
      | otherwise => compile internal-ast-form

    env.macro-table.parent.contents[name] = compilerspace-macro

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

    \seq : ({ compile }, ...expressions) ->
      type : \SequenceExpression
      expressions : expressions .map compile

    \array : ({ compile }, ...elements) ->
      type : \ArrayExpression
      elements : elements.map compile

    \object : ({ compile }, ...args) ->

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
      declaration = ({compile}, ...args) ->
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

    \switch : ({compile, compile-many}, discriminant, ...cases) ->

      if cases.length % 2 isnt 0
        throw Error "Switch conditional without a matching consequent"

      tests-consequents = do # [ [t1, c1], [t2, c2] , ... ]
        tests = [] ; consequents = []
        cases.for-each (a, i) -> (if i % 2 then consequents else tests).push a
        zip tests, consequents

      type : \SwitchStatement
      discriminant : compile discriminant
      cases : tests-consequents
        .map ([t, c]) ->
          type       : \SwitchCase
          test       : do
            t = compile t
            if t.type is \Identifier and t.name is \default
              null # emit "default:" switchcase label
            else t
          consequent : compile-many c.content .map statementify

    \if : ({compile}, test, consequent, alternate) ->
      type : \IfStatement
      test       : compile test
      consequent : statementify compile consequent
      alternate  : statementify compile alternate

    \?: : ({compile}, test, consequent, alternate) ->
      type : \ConditionalExpression
      test       : compile test
      consequent : compile consequent
      alternate  : compile alternate

    \while : ({compile, compile-many}, test, ...body) ->
      type : \WhileStatement
      test : compile test
      body :
        type : \BlockStatement
        body : compile-many body .map statementify

    \for : ({compile, compile-many}, init, test, update, ...body) ->
      type : \ForStatement
      init : compile init
      test : compile test
      update : compile update
      body :
        type : \BlockStatement
        body : compile-many body .map statementify

    \break : ->
      type : \BreakStatement
      label : null # TODO?
    \continue : ->
      type : \ContinueStatement
      label : null # TODO?

    \return : ({compile}, arg) ->
      type : \ReturnStatement
      argument : compile arg

    \. : do

      is-computed-property = (ast-node) ->
        switch ast-node.type
        | \MemberExpression =>
          is-computed-property ast-node.object
        | \Identifier => false
        | otherwise => true

      dot = ({compile}:env, ...args) ->
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
            env
            dot.apply null ([ env ] ++ initial)
            dot env, compile last
        | otherwise =>
          throw Error "dot called with no arguments"

    \get : do
      get = ({compile}:env, ...args) ->
        | args.length is 1 => compile args.0
        | args.length is 2
          property-compiled = compile args.1
          type : \MemberExpression
          computed : true # `get` is always computed
          object   : compile args.0
          property : property-compiled
        | arguments.length > 2
          [ ...initial, last ] = args
          get do
            env
            get.apply null ([ env ] ++ initial)
            get env, compile last
        | otherwise =>
          throw Error "dot called with no arguments"


    \lambda : do
      compile-function-body = (compile-many, nodes) ->

        nodes = compile-many nodes

        last-node = nodes.pop!
        # Automatically return last node if it's an expression
        nodes.push if is-expression last-node
          type : \ReturnStatement
          argument : last-node
        else last-node

        type : \BlockStatement
        body : nodes.map statementify

      lambda = ({compile, compile-many}, params, ...body) ->
        type : \FunctionExpression
        id : null
        params : params.contents!map compile
        body : compile-function-body compile-many, body
      lambda

    \macro : (env, name, ...function-args) ->

      # TODO error checking

      userspace-macro = compile-to-function env, function-args

      name .= text!
      import-macro env, name, userspace-macro
      return null

    \macros : (env, ...body) ->

      # Compile the body as if it were a function with no parameters
      body-as-function = compile-to-function do
        env
        ([list [] ] ++ body) # prepend empty parameter list

      # Run it
      ret = body-as-function!

      switch typeof! ret
      | \Undefined => fallthrough
      | \Null =>
        return null
      | \Object
        for name, func of ret
          # sanity: no space or parens in macro name
          if name.match /[\s()]/ isnt null
            throw Error "`macros` return has illegal characters in return name"
          if typeof func isnt \function
            throw Error """`macros` return object value wasn't a function
                           (got `#{typeof! func}`)"""

          import-macro env, name, func
        return null
      | otherwise
        throw Error "Non-object return from `macros`! (got `#{typeof! ret}`)"

    \quote : do
      quote = ({compile}, ...args) ->
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

      qq = ({compile}, ...args) ->

        # Each argument (in args) is an atom passed to the quasiquote macro.
        if args.length > 1
          throw Error "Attempted to quasiquote >1 values, not inside list"

        arg = args.0

        if arg instanceof list and arg.contents!length
          if arg.contents!0 instanceof atom and arg.contents!0.text! is \unquote
            rest = arg.contents!slice 1 .0
            compile rest
          else
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
    |> concat-map (.compile root-macro-table)
    |> (.filter (isnt null)) # macro definitions emit nothing, hence this
    |> (.map statementify)
