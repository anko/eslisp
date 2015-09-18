{ map, zip, concat-map } = require \prelude-ls
{ atom, list, string } = require \./ast
{ is-expression } = require \esutils .ast
statementify = require \./es-statementify
{
  import-macro
  import-capmacro
  import-compilerspace-macro
  multiple-statements
} = require \./import-macro

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

  (env, ...args) ->
    if args.length is 1
      console.log "ERR"
      throw Error "Chained binary expression `#operator` unexpectedly called \
                   with 1 argument"
    else
      macro .apply null arguments

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

quote = ->
  if arguments.length > 1
    throw Error "Too many arguments to quote; \
                 expected 1 but got #{arguments.length}"
  if it then it.as-sm!
  else list!as-sm! # empty list

optionally-implicit-block-statement = ({compile, compile-many}, body) ->
  switch body.length
  | 1 =>
    body-compiled = compile body.0
    if body-compiled.type is \BlockStatement then return body-compiled
    fallthrough # "else"
  | _ =>
    type : \BlockStatement
    body : compile-many body .map statementify

contents =
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

  \&& : chained-binary-expr \LogicalExpression \&&
  \|| : chained-binary-expr \LogicalExpression \||
  \!  : unary-expr \!

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
  \/=   : chained-binary-expr \AssignmentExpression \/=
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
      if args.length > 2
        throw Error "Expected variable declaration to get 1 or 2 arguments, \
                     but got #{arguments.length}."
      type : \VariableDeclaration
      kind : "var"
      declarations : [
        type : \VariableDeclarator
        id : compile args.0
        init : if args.1 then compile args.1 else null
      ]

    declaration

  \block : ({compile, compile-many}, ...statements) ->
    type : \BlockStatement
    body : compile-many statements .map statementify

  \switch : ({compile, compile-many}, discriminant, ...cases) ->
    type : \SwitchStatement
    discriminant : compile discriminant
    cases : cases .map (.contents!)
      .map ([t, ...c]) ->
        type       : \SwitchCase
        test       : do
          t = compile t
          if t.type is \Identifier and t.name is \default
            null # emit "default:" switchcase label
          else t
        consequent : compile-many c .map statementify

  \if : ({compile, compile-many}, test, consequent, alternate) ->
    type : \IfStatement
    test       : compile test
    consequent : statementify compile consequent
    alternate :
      if alternate then statementify compile that
      else null

  \?: : ({compile}, test, consequent, alternate) ->
    type : \ConditionalExpression
    test       : compile test
    consequent : compile consequent
    alternate  : compile alternate

  \while : ({compile, compile-many}:env, test, ...body) ->
    type : \WhileStatement
    test : compile test
    body : optionally-implicit-block-statement env, body

  \dowhile : ({compile, compile-many}:env, test, ...body) ->
    type : \DoWhileStatement
    test : compile test
    body : optionally-implicit-block-statement env, body

  \for : ({compile, compile-many}:env, init, test, update, ...body) ->
    type : \ForStatement
    init : compile init
    test : compile test
    update : compile update
    body : optionally-implicit-block-statement env, body

  \forin : ({compile, compile-many}:env, left, right, ...body) ->
    type : \ForInStatement
    left : compile left
    right : compile right
    body : optionally-implicit-block-statement env, body

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


  \function : ({compile, compile-many}:env, params, ...body) ->
    type : \FunctionExpression
    id : null
    params : params.contents!map compile
    body : optionally-implicit-block-statement env, body

  \new : ({compile}, ...args) ->
    [ newTarget, ...newArgs ] = args

    if not newTarget? then throw Error "No target for `new`"
    # `newArgs` can be empty though

    type : \NewExpression
    callee : compile newTarget
    arguments : newArgs .map compile

  \debugger : (_, ...args) ->
    if args.length
      throw Error "Expected no arguments to `debugger` statement"
    type : \DebuggerStatement

  \throw : ({compile}, ...args) ->

    if args.length isnt 1
      throw Error "Expected 1 argument to `throws`; got #{args.length}"

    type : \ThrowStatement
    argument : compile args.0

  \regex : ({compile}, ...args) ->

    if args.length not in [ 1 2 ]
      throw Error "Expected 1 or 2 arguments to `regex`; got #{args.length}"

    type : \Literal
    value : new RegExp args.0.text!, args.1?text!

  \try : ({compile, compile-many}:env, ...args) ->

    is-part = (thing, clause-name) ->
      first = thing.content.0
      (first instanceof atom) && (first.text! is clause-name)

    catch-part = null
    finally-part = null
    others = []

    args.for-each ->
      if it `is-part` \catch
        if catch-part then throw Error "Duplicate `catch` clause"
        catch-part := it.content.slice 1
      else if it `is-part` \finally
        if finally-part then throw Error "Duplicate `finally` clause"
        finally-part := it.content.slice 1
      else
        others.push it

    catch-clause = if catch-part
      type : \CatchClause
      param : compile catch-part.shift!
      body : optionally-implicit-block-statement env, catch-part
    else null

    finally-clause = if finally-part
      optionally-implicit-block-statement env, finally-part
    else null

    type : \TryStatement
    block :
      type : \BlockStatement
      body : compile-many others .map statementify
    handler : catch-clause
    finalizer : finally-clause

  \macro : (env, ...args) ->

    compile-as-macro = (es-ast) ->
      # This is deliberately defined in the closure here, so it's in scope
      # during the `eval` and available to the code being compiled.
      root-require = require.main.require.bind require.main
      let require = root-require
        eval "(#{env.compile-to-js es-ast})"

    switch args.length
    | 1 =>
      form = args.0
      switch
      | form instanceof atom

        # Mask any macro of that name in the current scope

        import-compilerspace-macro env, form.text!, null

      | otherwise

        # Attempt to compile the argument, hopefully into an object,
        # define macros from its keys

        es-ast = env.compile form

        result = compile-as-macro es-ast

        switch typeof! result
        | \Object =>
          for k, v of result
            import-macro env, k, v
        | \Null => fallthrough
        | \Undefined => # do nothing
        | otherwise =>
          throw Error "Invalid macro source #that (expected to get an Object, \
                       or a name argument and a Function)"
    | 2 =>
      [ name, form ] = args

      switch
      | form instanceof atom

        name = name.text!
        target-name = form.text!

        alias-target-macro = env.find-macro do
          env.macro-table
          target-name

        if not alias-target-macro
          throw Error "Macro alias target `#target-name` is not defined"

        import-compilerspace-macro env, name, alias-target-macro

      | form instanceof list

        userspace-macro = form |> env.compile |> compile-as-macro

        name .= text!
        import-macro env, name, userspace-macro

    | otherwise =>
      throw Error "Bad number of arguments to macro constructor \
                   (expected 1 or 2; got #that)"
    return null

  \capmacro : (env, ...args) ->

    compile-as-macro = (es-ast) ->
      # This is deliberately defined in the closure here, so it's in scope
      # during the `eval` and available to the code being compiled.
      let { require } = require.main
        eval "(#{env.compile-to-js es-ast})"

    switch args.length
    | 1 =>
      es-ast = env.compile args.0

      result = compile-as-macro es-ast

      switch typeof! result
      | \Object =>
        for k, v of result
          import-capmacro env, k, v
      | \Null => fallthrough
      | \Undefined => # do nothing
      | otherwise =>
        throw Error "Invalid macro source #that (expected to get an Object, \
                     or a name argument and a Function)"
    | 2 =>
      [ name, form ] = args

      userspace-macro = form |> env.compile |> compile-as-macro

      name .= text!
      import-capmacro env, name, userspace-macro

    | otherwise =>
      throw Error "Bad number of arguments to macro constructor \
                   (expected 1 or 2; got #that)"
    return null

  \quote : (_, ...args) -> quote.apply null, args

  \quasiquote : do

    # Compile an AST node which is part of the body of a quasiquote.  This
    # means we have to resolve lists which first atom is `unquote` or
    # `unquote-splicing` into either an array of values or an identifier to
    # an array of values.
    qq-body = (compile, ast) ->

      recurse-on = (ast-list) ->
        ast-list.contents!
        |> map qq-body compile, _
        |> generate-concat

      unquote = ->
        if arguments.length isnt 1
          throw Error "Expected 1 argument to unquote but got #{rest.length}"

        # Unquoting should compile to just the thing separated with an array
        # wrapper.
        [ compile it ]

      unquote-splicing = ->
        if arguments.length isnt 1
          throw Error "Expected 1 argument to unquoteSplicing but got
                       #{rest.length}"

        # Splicing should leave it without the array wrapper so concat
        # splices it into the array it's contained in.
        compile it

      switch
      | ast instanceof list
        [head, ...rest] = ast.contents!
        switch
        | not head? => [ quote list [] ] # empty list
        | head instanceof atom =>
          switch head.text!
          | \unquote          => unquote         .apply null rest
          | \unquote-splicing => unquote-splicing.apply null rest
          | _ => [ recurse-on ast ]
        | _   => [ recurse-on ast ]

      | _ => [ quote ast ]

    generate-concat = (concattable-things) ->

      # Each quasiquote-body resolution produces SpiderMonkey AST compiled
      # values, but if there are many of them, it'll produce an array.  We'll
      # convert these into ArrayExpressions so the results are effectively
      # still compiled values.

      concattable-things
      |> map ->
        if typeof! it is \Array
          type : \ArrayExpression elements : it
        else it

      # Now each should be an array (or a literal that was
      # `unquote-splicing`ed) so they can be assumed to be good for
      # `Array::concat`.

      # We then construct a call to Array::concat with each of the now
      # quasiquote-resolved and compiled things as arguments.  That makes
      # this macro produce a concatenation of the quasiquote-resolved
      # arguments.
      |> ->
        type : \CallExpression
        callee :
          type : \MemberExpression
          object :
            type : \MemberExpression
            object   : type : \Identifier name : \Array
            property : type : \Identifier name : \prototype
          property   : type : \Identifier name : \concat
        arguments : it

    qq = ({compile}, ...args) ->

      if args.length > 1
        throw Error "Too many arguments to quasiquote (`); \
                     expected 1, got #{args.length}"
      arg = args.0

      if arg instanceof list and arg.contents!length

        first-arg = arg.contents!0

        if first-arg instanceof atom and first-arg.text! is \unquote
          rest = arg.contents!slice 1 .0
          compile rest

        else
          arg.contents!
          |> map qq-body compile, _
          |> generate-concat

      else quote arg # act like regular quote

module.exports =
  parent : null
  contents : contents
